#!/bin/bash
# Compat fixes for JackA1ltman v2.2.0 patch + wshamroukh KSU-Next legacy-susfs

# 1. fsnotify_add_inode_mark compat (5.9+ function, 4.19 doesn't have it)
cat >> include/linux/susfs_def.h << 'EOF'

/* Compat: fsnotify_add_inode_mark introduced in 5.9, not in 4.19 */
#ifndef fsnotify_add_inode_mark
#define fsnotify_add_inode_mark(mark, inode, allow_dups) \
        fsnotify_add_mark(mark, &inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, allow_dups)
#endif

/* Alias: wshamroukh uses _ALL_PROCS, JackA1ltman uses _NON_SU_PROCS */
#define CMD_SUSFS_HIDE_SUS_MNTS_FOR_ALL_PROCS CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS
EOF

# 2. Add missing function declarations (wshamroukh references these)
cat >> include/linux/susfs.h << 'EOF'

/* wshamroukh KSU-Next legacy-susfs compatibility */
void susfs_set_hide_sus_mnts_for_all_procs(void __user **user_info);
void susfs_set_i_state_on_external_dir(void __user **user_info);
EOF

# 3. Add missing function stubs to susfs.c
cat >> fs/susfs.c << 'EOF'

/* wshamroukh KSU-Next legacy-susfs compatibility stubs */
void susfs_set_hide_sus_mnts_for_all_procs(void __user **user_info) {
    susfs_set_hide_sus_mnts_for_non_su_procs(user_info);
}
void susfs_set_i_state_on_external_dir(void __user **user_info) { }
EOF

# 4. Fix task_mmu.c - ensure susfs_def.h is included (hunk #1 may fail on some 4.19 kernels)
if ! grep -q "susfs_def.h" fs/proc/task_mmu.c 2>/dev/null; then
    echo "=== Adding susfs_def.h include to task_mmu.c ==="
    # Try multiple anchor points
    sed -i '/#include <linux\/ctype.h>/a #if defined(CONFIG_KSU_SUSFS_SUS_KSTAT) || defined(CONFIG_KSU_SUSFS_SUS_MAP) || defined(CONFIG_KSU_SUSFS_OPEN_REDIRECT)\n#include <linux/susfs_def.h>\n#endif' fs/proc/task_mmu.c 2>/dev/null || \
    sed -i '/#include <linux\/uaccess.h>/a #if defined(CONFIG_KSU_SUSFS_SUS_KSTAT) || defined(CONFIG_KSU_SUSFS_SUS_MAP) || defined(CONFIG_KSU_SUSFS_OPEN_REDIRECT)\n#include <linux/susfs_def.h>\n#endif' fs/proc/task_mmu.c 2>/dev/null || \
    sed -i '1i #if defined(CONFIG_KSU_SUSFS_SUS_KSTAT) || defined(CONFIG_KSU_SUSFS_SUS_MAP) || defined(CONFIG_KSU_SUSFS_OPEN_REDIRECT)\n#include <linux/susfs_def.h>\n#endif' fs/proc/task_mmu.c
    grep -q "susfs_def.h" fs/proc/task_mmu.c && echo "=== task_mmu.c fixed ===" || echo "=== WARNING: task_mmu.c fix failed ==="
fi

echo "=== All compat fixes applied ==="
