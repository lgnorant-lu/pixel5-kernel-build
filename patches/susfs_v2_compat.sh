#!/bin/bash
# Add compatibility aliases for SUSFS v2.0.0 (MizProject) + wshamroukh KSU
# MizProject v2.0.0 is 4.19 native but may miss some v2.0.0 functions
# that wshamroukh's KSU code references

# Add compatibility constant aliases
cat >> include/linux/susfs_def.h << 'SUSFS_ALIAS_EOF'

/* Compatibility aliases for JackA1ltman's 50_add_susfs_in_kernel-4.19.patch */
#define INODE_STATE_SUS_PATH AS_FLAGS_SUS_PATH
#define INODE_STATE_SUS_MOUNT AS_FLAGS_SUS_MOUNT
#define INODE_STATE_SUS_KSTAT AS_FLAGS_SUS_KSTAT
#define INODE_STATE_OPEN_REDIRECT AS_FLAGS_OPEN_REDIRECT
#define INODE_STATE_SUS_MAP AS_FLAGS_SUS_MAP
#define TASK_STRUCT_NON_ROOT_USER_APP_PROC TIF_PROC_UMOUNTED
SUSFS_ALIAS_EOF

# Add missing function declarations to susfs.h
cat >> include/linux/susfs.h << 'SUSFS_H_EOF'

/* v2.0.0 functions used by wshamroukh but may not be in MizProject */
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info);
void susfs_set_i_state_on_external_dir(void __user *user_info);
void susfs_add_sus_path_loop(void __user *user_info);
void susfs_add_sus_map(void __user *user_info);
SUSFS_H_EOF

# Add missing function stubs to susfs.c
cat >> fs/susfs.c << 'SUSFS_C_EOF'

/* Stubs for functions referenced by wshamroukh KSU but not in MizProject v2.0.0 */
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info) { }
void susfs_set_i_state_on_external_dir(void __user *user_info) { }
void susfs_add_sus_path_loop(void __user *user_info) { }
void susfs_add_sus_map(void __user *user_info) { }
void susfs_try_umount_all(uid_t uid) { }
SUSFS_C_EOF

# Add -Wno-incompatible-pointer-types to KSU Kbuild
KSU_KBUILD="drivers/kernelsu/Kbuild"
if [ -f "$KSU_KBUILD" ]; then
    REAL_KBUILD=$(readlink -f "$KSU_KBUILD")
    if ! grep -q "Wno-incompatible-pointer-types" "$REAL_KBUILD"; then
        sed -i 's/-Wno-declaration-after-statement/-Wno-declaration-after-statement -Wno-incompatible-pointer-types/g' "$REAL_KBUILD"
        echo "=== Added compiler flags to Kbuild ==="
    fi
fi

echo "=== SUSFS v2.0.0 (MizProject 4.19) compatibility applied ==="
