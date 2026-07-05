#!/bin/bash
# Add v2.0.0 compatibility shims for wshamroukh legacy-susfs branch

cat >> include/linux/susfs_def.h << 'SUSFS_DEF_EOF'

/* v2.0.0+ additions for wshamroukh legacy-susfs compatibility */
#define SUSFS_MAGIC 0xFAFAFAFA
#define CMD_SUSFS_ADD_SUS_PATH_LOOP 0x55553
#define CMD_SUSFS_SET_ANDROID_DATA_ROOT_PATH 0x55551
#define CMD_SUSFS_SET_SDCARD_ROOT_PATH 0x55552
#define CMD_SUSFS_HIDE_SUS_MNTS_FOR_ALL_PROCS 0x55561
#define CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS 0x55561
#define CMD_SUSFS_ENABLE_AVC_LOG_SPOOFING 0x60010
#define TIF_PROC_UMOUNTED 33

#include <linux/cred.h>
static inline bool susfs_is_current_proc_umounted(void) {
    return test_ti_thread_flag(&current->thread_info, TIF_PROC_UMOUNTED);
}
static inline void susfs_set_current_proc_umounted(void) {
    set_ti_thread_flag(&current->thread_info, TIF_PROC_UMOUNTED);
}
static inline bool susfs_is_current_proc_umounted_app(void) {
    return (susfs_is_current_proc_umounted() && from_kuid(&init_user_ns, current_uid()) >= 10000);
}
SUSFS_DEF_EOF

cat >> include/linux/susfs.h << 'SUSFS_H_EOF'

/* v2.0.0+ function declarations for wshamroukh legacy-susfs compatibility */
#ifdef CONFIG_KSU_SUSFS_SUS_PATH
void susfs_add_sus_path(void __user *user_info);
void susfs_add_sus_path_loop(void __user *user_info);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info);
void susfs_set_i_state_on_external_dir(void __user *user_info);
#endif
#ifdef CONFIG_KSU_SUSFS_SUS_KSTAT
void susfs_add_sus_kstat(void __user *user_info);
void susfs_update_sus_kstat(void __user *user_info);
#endif
#ifdef CONFIG_KSU_SUSFS_TRY_UMOUNT
void susfs_add_try_umount(void __user *user_info);
#endif
#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME
void susfs_set_uname(void __user *user_info);
#endif
#ifdef CONFIG_KSU_SUSFS_ENABLE_LOG
void susfs_enable_log(void __user *user_info);
#endif
void susfs_set_avc_log_spoofing(void __user *user_info);
void susfs_get_enabled_features(void __user *user_info);
void susfs_show_variant(void __user *user_info);
void susfs_show_version(void __user *user_info);
SUSFS_H_EOF

cat >> fs/susfs.c << 'SUSFS_C_EOF'

/* v2.0.0+ stub implementations for wshamroukh legacy-susfs compatibility */
void susfs_add_sus_path(void __user *user_info) { }
void susfs_add_sus_path_loop(void __user *user_info) { }
void susfs_set_hide_sus_mnts_for_all_procs(void __user *user_info) { }
void susfs_set_i_state_on_external_dir(void __user *user_info) { }
void susfs_add_sus_kstat(void __user *user_info) { }
void susfs_update_sus_kstat(void __user *user_info) { }
void susfs_add_try_umount(void __user *user_info) { }
void susfs_set_uname(void __user *user_info) { }
void susfs_enable_log(void __user *user_info) { }
void susfs_set_avc_log_spoofing(void __user *user_info) { }
void susfs_get_enabled_features(void __user *user_info) { }
void susfs_show_variant(void __user *user_info) { }
void susfs_show_version(void __user *user_info) { }
SUSFS_C_EOF

echo "=== SUSFS v2.0.0 compatibility patches applied ==="

