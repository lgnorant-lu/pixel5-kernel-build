#!/bin/bash
# Port selinux_hide from FlopKernel to wshamroukh legacy-susfs
# Based on: FlopKernel-Series/flop_exynos2100_kernel commit fd9d912
# Original: KernelSU-Next PR #1254 by 5ec1cff/pershoot

KSU_DIR="drivers/kernelsu"
WSHAMROUKH_KERNEL="KernelSU-Next/kernel"

cd $KSU_DIR/kernel

# 1. Add KSU_FEATURE_SELINUX_HIDE_STATUS to feature.h
if ! grep -q "KSU_FEATURE_SELINUX_HIDE_STATUS" feature.h; then
    sed -i 's/KSU_FEATURE_KERNEL_UMOUNT = 1,/KSU_FEATURE_KERNEL_UMOUNT = 1,\n\tKSU_FEATURE_SELINUX_HIDE_STATUS = 4,/' feature.h
    echo "=== Added KSU_FEATURE_SELINUX_HIDE_STATUS to feature.h ==="
fi

# 2. Create selinux_hide.h
cat > selinux_hide.h << 'EOF'
#ifndef __KSU_H_SELINUX_HIDE
#define __KSU_H_SELINUX_HIDE

#include <linux/types.h>

void ksu_selinux_hide_init(void);
void ksu_selinux_hide_exit(void);
void ksu_selinux_hide_handle_second_stage(void);

#endif
EOF

# 3. Create selinux_hide.c (adapted from FlopKernel for wshamroukh legacy-susfs)
cat > selinux_hide.c << 'HIDEEOF'
#include <linux/fs.h>
#include <linux/jump_label.h>
#include <linux/mm.h>
#include <linux/mutex.h>
#include <linux/slab.h>
#include <asm/set_memory.h>
#include <linux/namei.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include "feature.h"
#include "ksu.h"
#include "selinux/selinux.h"
#include "selinux_hide.h"

static struct page *fake_status = NULL;
static DEFINE_MUTEX(fake_status_init_mutex);

static bool ksu_selinux_hide_is_enabled __read_mostly = true;
static u32 ksu_sid __read_mostly = 0;
static u32 priv_app_sid __read_mostly = 0;

static int ksu_selinux_get_sids(void)
{
	int err1 = security_secctx_to_secid("u:r:su:s0", strlen("u:r:su:s0"), &ksu_sid);
	int err2 = security_secctx_to_secid("u:r:priv_app:s0:c512,c768",
					    strlen("u:r:priv_app:s0:c512,c768"), &priv_app_sid);
	if (!err1) pr_info("ksu_selinux_hide: ksu_sid=%u\n", ksu_sid);
	if (!err2) pr_info("ksu_selinux_hide: priv_app_sid=%u\n", priv_app_sid);
	return (!ksu_sid || !priv_app_sid) ? -1 : 0;
}

static void ksu_selinux_hide_enable(void)
{
	if (ksu_selinux_get_sids())
		pr_warn("ksu_selinux_hide: sid grab failed\n");
}

static void ksu_selinux_hide_disable(void)
{
}

static void initialize_fake_status(void)
{
	if (READ_ONCE(fake_status))
		return;

	mutex_lock(&fake_status_init_mutex);
	if (fake_status)
		goto out;

#ifdef KSU_COMPAT_USE_SELINUX_STATE
	struct page *real_page = selinux_kernel_status_page(&selinux_state);
#else
	struct page *real_page = selinux_kernel_status_page();
#endif
	if (!real_page) {
		pr_warn("ksu_selinux_hide: status_page not exists\n");
		goto out;
	}

	struct selinux_kernel_status *status = page_address(real_page);
	if (!status->enforcing) {
		pr_info("ksu_selinux_hide: not enforcing yet, creating fake status anyway\n");
	}

	struct page *new_page = alloc_page(GFP_KERNEL | __GFP_ZERO);
	if (!new_page) {
		pr_err("ksu_selinux_hide: failed to allocate fake status page\n");
		goto out;
	}

	struct selinux_kernel_status *new_status = page_address(new_page);
	memcpy(new_status, status, sizeof(*status));

	WRITE_ONCE(fake_status, new_page);
	pr_info("ksu_selinux_hide: fake status ready: sequence=%d policyload=%d enforcing=%d\n",
		new_status->sequence, new_status->policyload,
		new_status->enforcing);
out:
	mutex_unlock(&fake_status_init_mutex);
}

typedef int (*sel_open_handle_status_fn)(struct inode *inode, struct file *filp);
static sel_open_handle_status_fn orig_sel_open_handle_status = NULL;

static int __nocfi my_sel_open_handle_status(struct inode *inode, struct file *filp)
{
	if (likely(test_thread_flag(TIF_SECCOMP) &&
		   current_uid().val >= 10000 &&
		   ksu_selinux_hide_is_enabled)) {
		struct page *data = READ_ONCE(fake_status);
		if (data) {
			filp->private_data = page_address(data);
			return 0;
		}
	}
	return orig_sel_open_handle_status(inode, filp);
}

#define FORCE_VOLATILE(x) *(volatile typeof(x) *)&(x)

static int patch_fops_open(struct file_operations *ops,
			   sel_open_handle_status_fn new_open)
{
	unsigned long addr = (unsigned long)&ops->open;
	unsigned long base = addr & PAGE_MASK;
	unsigned long offset = addr & ~PAGE_MASK;
	struct page *page = phys_to_page(__pa(base));
	if (!page)
		return -EFAULT;

	void *writable_addr = vmap(&page, 1, VM_MAP, PAGE_KERNEL);
	if (!writable_addr)
		return -ENOMEM;

	void **target_slot = (void **)((unsigned long)writable_addr + offset);
	preempt_disable();
	local_irq_disable();
	FORCE_VOLATILE(*target_slot) = (void *)new_open;
	local_irq_enable();
	preempt_enable();

	vunmap(writable_addr);
	smp_mb();
	return 0;
}

static int resolve_fops(const char *path_str, struct file_operations **out_fops)
{
	struct path path;
	int error = kern_path(path_str, LOOKUP_FOLLOW, &path);
	if (error) {
		pr_err("ksu_selinux_hide: kern_path(%s) failed: %d\n", path_str, error);
		return error;
	}
	int ret = -ENOENT;
	if (!path.dentry || !d_inode(path.dentry))
		goto out;
	*out_fops = (struct file_operations *)d_inode(path.dentry)->i_fop;
	if (!*out_fops)
		goto out;
	ret = 0;
out:
	path_put(&path);
	return ret;
}

static void hook_selinux_status_open(void)
{
	if (orig_sel_open_handle_status)
		return;
	struct file_operations *ops = NULL;
	if (resolve_fops("/sys/fs/selinux/status", &ops)) {
		pr_err("ksu_selinux_hide: sel_handle_status_ops not found\n");
		return;
	}
	if (!ops->open) {
		pr_err("ksu_selinux_hide: sel_handle_status_ops->open is NULL\n");
		return;
	}
	orig_sel_open_handle_status = ops->open;
	patch_fops_open(ops, my_sel_open_handle_status);
	pr_info("ksu_selinux_hide: hooked sel_handle_status_ops->open\n");
}

void ksu_selinux_hide_handle_second_stage(void)
{
	initialize_fake_status();
}

static int ksu_hide_init_thread(void *data)
{
	set_user_nice(current, 19);
	msleep(5000);
	if (ksu_selinux_hide_is_enabled)
		ksu_selinux_hide_enable();
	int tries = 0;
try_again:
	initialize_fake_status();
	if (READ_ONCE(fake_status))
		goto page_ok;
	msleep(1000);
	if (++tries > 10) {
		pr_warn("ksu_selinux_hide: giving up after %d tries\n", tries);
		return 0;
	}
	goto try_again;
page_ok:
	hook_selinux_status_open();
	return 0;
}

static int selinux_hide_status_feature_get(u64 *value)
{
	*value = ksu_selinux_hide_is_enabled ? 1 : 0;
	return 0;
}

static int selinux_hide_status_feature_set(u64 value)
{
	bool enable = !!value;
	if (enable == ksu_selinux_hide_is_enabled)
		return 0;
	ksu_selinux_hide_is_enabled = enable;
	if (!ksu_selinux_hide_is_enabled)
		ksu_selinux_hide_disable();
	else
		ksu_selinux_hide_enable();
	pr_info("ksu_selinux_hide: set to %d\n", enable);
	return 0;
}

static const struct ksu_feature_handler selinux_hide_status_handler = {
	.feature_id = KSU_FEATURE_SELINUX_HIDE_STATUS,
	.name = "selinux_hide_status",
	.get_handler = selinux_hide_status_feature_get,
	.set_handler = selinux_hide_status_feature_set,
};

void __init ksu_selinux_hide_init(void)
{
	if (ksu_register_feature_handler(&selinux_hide_status_handler))
		pr_err("ksu_selinux_hide: failed to register feature handler\n");
	kthread_run(ksu_hide_init_thread, NULL, "ksu_selinux_hide_init");
}

void __exit ksu_selinux_hide_exit(void)
{
	ksu_unregister_feature_handler(KSU_FEATURE_SELINUX_HIDE_STATUS);
	if (orig_sel_open_handle_status) {
		struct file_operations *ops = NULL;
		if (!resolve_fops("/sys/fs/selinux/status", &ops))
			patch_fops_open(ops, orig_sel_open_handle_status);
		orig_sel_open_handle_status = NULL;
	}
	ksu_selinux_hide_disable();
	mutex_lock(&fake_status_init_mutex);
	if (fake_status) {
		__free_page(fake_status);
		fake_status = NULL;
	}
	mutex_unlock(&fake_status_init_mutex);
}
HIDEEOF

# 4. Add to Kbuild
if ! grep -q "selinux_hide.o" Kbuild; then
    sed -i '/kernelsu-objs += feature.o/a kernelsu-objs += selinux_hide.o' Kbuild
    echo "=== Added selinux_hide.o to Kbuild ==="
fi

# 5. Add init/exit calls to ksu.c
if ! grep -q "ksu_selinux_hide_init" ksu.c; then
    sed -i '/ksu_feature_init();/a\\tksu_selinux_hide_init();' ksu.c
    sed -i '/ksu_feature_exit();/i\\tksu_selinux_hide_exit();' ksu.c
    # Add include
    sed -i '1i #include "selinux_hide.h"' ksu.c
    echo "=== Added selinux_hide init/exit to ksu.c ==="
fi

# 6. Add second_stage hook to ksud.c
if ! grep -q "ksu_selinux_hide_handle_second_stage" ksud.c 2>/dev/null; then
    # Add include at top
    sed -i '1i #include "selinux_hide.h"' ksud.c 2>/dev/null || true
    # Add call before apply_kernelsu_rules
    sed -i '/apply_kernelsu_rules();/i\\tksu_selinux_hide_handle_second_stage();' ksud.c 2>/dev/null || true
    echo "=== Added second_stage hook to ksud.c ==="
fi

echo "=== selinux_hide port complete ==="
grep -c "selinux_hide" Kbuild
grep -c "selinux_hide" ksu.c
