#!/bin/bash
# frida_hide_patch.sh — 在内核源码中添加frida隐藏功能
# 修改: fs/proc/task_mmu.c (show_map_vma过滤), fs/proc/base.c (进程隐藏)
# 不需要KPM/KPatch，直接编译进内核

KSU_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KERNEL_ROOT="$1"

if [ -z "$KERNEL_ROOT" ]; then
    echo "Usage: $0 <kernel_source_root>"
    exit 1
fi

echo "=== Applying frida hide patches to kernel source ==="

# 1. 修改 fs/proc/task_mmu.c — show_map_vma过滤frida映射
TASK_MMU="$KERNEL_ROOT/fs/proc/task_mmu.c"
if [ -f "$TASK_MMU" ]; then
    # 检查是否已经patch过
    if grep -q "bypass_show_map_vma" "$TASK_MMU"; then
        echo "=== task_mmu.c already patched ==="
    else
        # 在show_map_vma函数前添加bypass函数
        sed -i '/^static void$/i\
static int bypass_show_map_vma(struct vm_area_struct *vma) {\
    struct file *file = vma->vm_file;\
    vm_flags_t flags = vma->vm_flags;\
    if (file && file->f_path.dentry) {\
        const char *name = file->f_path.dentry->d_iname;\
        if (strstr(name, "frida-") ||\
            strstr(name, "gum-js") ||\
            strstr(name, "linjector") ||\
            strstr(name, "re.frida") ||\
            strstr(name, "frida-agent") ||\
            strstr(name, "frida-gadget") ||\
            strstr(name, "libgum"))\
            return 1;\
    }\
    if (file && file->f_path.dentry && (flags & VM_EXEC)) {\
        const char *name = file->f_path.dentry->d_iname;\
        if (strstr(name, "memfd:") &&\
            (strstr(name, "frida") || strstr(name, "jit") || strstr(name, "agent") || strstr(name, "gum")))\
            return 1;\
    }\
    return 0;\
}' "$TASK_MMU"

        # 在show_map_vma函数体开头添加bypass检查
        sed -i '/^show_map_vma(struct seq_file \*m, struct vm_area_struct \*vma)$/,/^{$/{
            /^{$/a\
    if (bypass_show_map_vma(vma)) return;
' "$TASK_MMU"

        # 在show_smap函数中也添加bypass检查
        sed -i '/^static int show_smap/,/^{$/{
            /^{$/a\
    if (bypass_show_map_vma(vma)) return 0;
' "$TASK_MMU"

        echo "=== task_mmu.c patched (show_map_vma + show_smap) ==="
    fi
else
    echo "WARNING: $TASK_MMU not found"
fi

# 2. 修改 fs/proc/base.c — 隐藏frida相关进程
PROC_BASE="$KERNEL_ROOT/fs/proc/base.c"
if [ -f "$PROC_BASE" ]; then
    if grep -q "bypass_proc_task" "$PROC_BASE"; then
        echo "=== base.c already patched ==="
    else
        # 在get_proc_task函数前添加bypass
        sed -i '/^static struct task_struct \*get_proc_task/,/^{$/{
            /^{$/i\
static int is_frida_process(struct task_struct *p) {\
    char tcomm[64];\
    if (!p) return 0;\
    if (p->flags & PF_WQ_WORKER)\
        wq_worker_comm(tcomm, sizeof(tcomm), p);\
    else\
        __get_task_comm(tcomm, sizeof(tcomm), p);\
    if (strstr(tcomm, "frida") || strstr(tcomm, "gmain") ||\
        strstr(tcomm, "gum-js") || strstr(tcomm, "linjector") ||\
        strstr(tcomm, "gdbus") || strstr(tcomm, "pool-frida") ||\
        strstr(tcomm, "agent-main") || strstr(tcomm, "v8:"))\
        return 1;\
    return 0;\
}
' "$PROC_BASE"
        echo "=== base.c patched (is_frida_process) ==="
    fi
else
    echo "WARNING: $PROC_BASE not found"
fi

# 3. 修改 fs/proc/array.c — TracerPid改0
PROC_ARRAY="$KERNEL_ROOT/fs/proc/array.c"
if [ -f "$PROC_ARRAY" ]; then
    if grep -q "bypass_tracerpid" "$PROC_ARRAY"; then
        echo "=== array.c already patched ==="
    else
        # 在TracerPid输出处添加bypass
        sed -i '/TracerPid:/s/ptrace_may_access(p, PTRACE_MODE_READ_FSCREDS)/0/' "$PROC_ARRAY"
        echo "=== array.c patched (TracerPid bypass) ==="
    fi
else
    echo "WARNING: $PROC_ARRAY not found"
fi

echo "=== Frida hide patches applied ==="
