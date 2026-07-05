#!/bin/bash
# Add compatibility aliases between v1.5.x patch constants and v2.2.0 susfs_def.h
# JackA1ltman's 50_add_susfs_in_kernel-4.19.patch uses old constant names
# manipvlator's v2.2.0 susfs_def.h uses new constant names
# This script bridges the naming gap

# Add missing v2.0.0 constants not in manipvlator's v2.2.0
cat >> include/linux/susfs_def.h << 'SUSFS_ALIAS_EOF'

/* Compatibility aliases for JackA1ltman's 50_add_susfs_in_kernel-4.19.patch */
#define INODE_STATE_SUS_PATH AS_FLAGS_SUS_PATH
#define INODE_STATE_SUS_MOUNT AS_FLAGS_SUS_MOUNT
#define INODE_STATE_SUS_KSTAT AS_FLAGS_SUS_KSTAT
#define INODE_STATE_OPEN_REDIRECT AS_FLAGS_OPEN_REDIRECT
#define INODE_STATE_SUS_MAP AS_FLAGS_SUS_MAP
#define TASK_STRUCT_NON_ROOT_USER_APP_PROC TIF_PROC_UMOUNTED

/* v2.0.0 constants used by wshamroukh but not in manipvlator v2.2.0 */
#define CMD_SUSFS_HIDE_SUS_MNTS_FOR_ALL_PROCS CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS
SUSFS_ALIAS_EOF

# Add missing function declarations to susfs.h
cat >> include/linux/susfs.h << 'SUSFS_H_EOF'

/* v2.0.0 functions used by wshamroukh but not in manipvlator v2.2.0 */
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info);
void susfs_set_i_state_on_external_dir(void __user *user_info);
SUSFS_H_EOF

# Add missing function stubs to susfs.c
cat >> fs/susfs.c << 'SUSFS_C_EOF'

/* v2.0.0 stub implementations for wshamroukh legacy-susfs */
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info) { }
void susfs_set_i_state_on_external_dir(void __user *user_info) { }

/* v1.5.x function name aliases (JackA1ltman patch references these) */
void susfs_sus_ino_for_generic_fillattr(unsigned long ino, struct kstat *stat) {
    susfs_generic_fillattr_spoofer(NULL, stat);
}
void susfs_sus_ino_for_show_map_vma(unsigned long ino, dev_t *out_dev, unsigned long *out_ino) {
    susfs_show_map_vma_spoofer(NULL, out_dev, out_ino);
}
struct filename* susfs_get_redirected_path(unsigned long ino) { return NULL; }
void susfs_sus_ino_for_filldir64(unsigned long ino) { }

/* v2.0.0 functions used by wshamroukh KSU code but not in manipvlator v2.2.0 */
void susfs_try_umount_all(uid_t uid) { }
void susfs_reorder_mnt_id(void) { }
/* wshamroukh calls susfs_run_sus_path_loop(uid_t uid), v2.2.0 has static void (void) */
void susfs_run_sus_path_loop(uid_t uid) { susfs_run_sus_path_loop_internal(); }

/* susfs_is_avc_log_spoofing_enabled is extern bool in v2.2.0, defined in avc.c */
/* But JackA1ltman's v1.5.x patch doesn't define it, so we define it here */
bool susfs_is_avc_log_spoofing_enabled = false;
SUSFS_C_EOF

# Add pragma to suppress fsnotify type mismatch in susfs.c (4.19 kernel API differs from v2.2.0)
sed -i '1i #pragma clang diagnostic ignored "-Wincompatible-function-pointer-types"' fs/susfs.c
sed -i '2i #pragma clang diagnostic ignored "-Wincompatible-pointer-types"' fs/susfs.c
sed -i '3i #pragma clang diagnostic ignored "-Wint-conversion"' fs/susfs.c

# Fix susfs_run_sus_path_loop signature mismatch:
# v2.2.0: static void susfs_run_sus_path_loop(void)
# wshamroukh: extern void susfs_run_sus_path_loop(uid_t uid)
# Rename v2.2.0's static version and add a wrapper with uid arg
sed -i 's/static void susfs_run_sus_path_loop(void)/static void susfs_run_sus_path_loop_internal(void)/g' fs/susfs.c
sed -i 's/susfs_run_sus_path_loop();/susfs_run_sus_path_loop_internal();/g' fs/susfs.c

# Add compiler flags to KSU Kbuild for type mismatches
KSU_KBUILD="drivers/kernelsu/Kbuild"
if [ -f "$KSU_KBUILD" ]; then
    REAL_KBUILD=$(readlink -f "$KSU_KBUILD")
    if ! grep -q "Wno-incompatible-pointer-types" "$REAL_KBUILD"; then
        sed -i 's/-Wno-declaration-after-statement/-Wno-declaration-after-statement -Wno-incompatible-pointer-types -Wno-incompatible-function-pointer-types -Wno-int-conversion/g' "$REAL_KBUILD"
        echo "=== Added compiler flags to Kbuild ==="
    fi
fi

echo "=== SUSFS v2.2.0 compatibility aliases applied ==="


echo "=== SUSFS v2.2.0 compatibility aliases applied ==="


echo "=== SUSFS v2.0.0 compatibility patches applied ==="


