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

# susfs_backports.h (included at end of susfs.c) provides:
# - susfs_is_avc_log_spoofing_enabled (bool variable)
# - susfs_sus_ino_for_filldir64 (for readdir.c)
# - susfs_reorder_mnt_id (4.19-specific, for setuid_hook.c)

echo "=== SUSFS v2.0.0 (MizProject 4.19) compatibility applied ==="
