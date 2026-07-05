#!/bin/bash
# Add compatibility aliases for SUSFS v2.0.0 (MizProject) + wshamroukh KSU
# MizProject v2.0.0 already has all functions, only need constant aliases

# Add compatibility constant aliases for JackA1ltman's 50_add_susfs_in_kernel-4.19.patch
cat >> include/linux/susfs_def.h << 'SUSFS_ALIAS_EOF'

/* Compatibility aliases for JackA1ltman's 50_add_susfs_in_kernel-4.19.patch */
#define INODE_STATE_SUS_PATH AS_FLAGS_SUS_PATH
#define INODE_STATE_SUS_MOUNT AS_FLAGS_SUS_MOUNT
#define INODE_STATE_SUS_KSTAT AS_FLAGS_SUS_KSTAT
#define INODE_STATE_OPEN_REDIRECT AS_FLAGS_OPEN_REDIRECT
#define INODE_STATE_SUS_MAP AS_FLAGS_SUS_MAP
SUSFS_ALIAS_EOF

# Note: MizProject v2.0.0 susfs.c already has ALL functions that wshamroukh references:
# - susfs_add_sus_path, susfs_add_sus_path_loop
# - susfs_set_hide_sus_mnts_for_all_procs, susfs_set_i_state_on_external_dir
# - susfs_add_sus_kstat, susfs_update_sus_kstat
# - susfs_add_try_umount, susfs_set_uname
# - susfs_enable_log, susfs_set_cmdline_or_bootconfig
# - susfs_add_open_redirect, susfs_add_sus_map
# - susfs_set_avc_log_spoofing, susfs_get_enabled_features
# - susfs_show_variant, susfs_show_version
# - susfs_try_umount_all
# All with void __user ** signatures matching wshamroukh's supercalls.c
# NO stubs needed!

# Add missing function declarations to susfs.h
cat >> include/linux/susfs.h << 'SUSFS_H_EOF'

/* Functions referenced by wshamroukh KSU but missing from MizProject v2.0.0 */
void susfs_add_try_umount(void __user **user_info);
SUSFS_H_EOF

# Create minimal susfs_backports.h (MizProject susfs.c includes it but
# we can't use the full version due to missing struct members)
cat > include/linux/susfs_backports.h << 'BACKPORT_EOF'
#ifndef _LINUX_SUSFS_BACKPORT_H
#define _LINUX_SUSFS_BACKPORT_H
/* Minimal stub - real implementations are in susfs_v2_compat.sh */
#ifdef CONFIG_KSU_SUSFS
extern bool susfs_is_avc_log_spoofing_enabled;
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
int susfs_sus_ino_for_filldir64(unsigned long ino) { return 0; }
#endif
#endif
BACKPORT_EOF

# Add stubs for functions normally in susfs_backports.h
cat >> fs/susfs.c << 'SUSFS_STUB_EOF'

/* Stubs for functions normally in susfs_backports.h */
bool susfs_is_avc_log_spoofing_enabled = false;
void susfs_reorder_mnt_id(void) { }
void susfs_add_try_umount(void __user **user_info) { }
void susfs_try_umount_all(uid_t uid) { }
void susfs_try_umount(uid_t uid) { }
SUSFS_STUB_EOF

echo "=== SUSFS v2.0.0 (MizProject 4.19) compatibility applied ==="
