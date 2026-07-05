#!/bin/bash
# Compat fixes for JackA1ltman v2.2.0 patch + wshamroukh KSU-Next legacy-susfs

# 1. fsnotify_add_inode_mark compat (5.9+ function, 4.19 doesn't have it)
# 4.19 fsnotify_add_mark signature: (mark, connp, type, allow_dups)
cat >> include/linux/susfs_def.h << 'EOF'

/* Compat: fsnotify_add_inode_mark introduced in 5.9, not in 4.19 */
#ifndef fsnotify_add_inode_mark
static inline int fsnotify_add_inode_mark_compat(struct fsnotify_mark *mark, struct inode *inode, int allow_dups)
{
    return fsnotify_add_mark(mark, &inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, allow_dups);
}
#define fsnotify_add_inode_mark(mark, inode, allow_dups) fsnotify_add_inode_mark_compat(mark, inode, allow_dups)
#endif

/* Alias: wshamroukh uses _ALL_PROCS, JackA1ltman uses _NON_SU_PROCS */
#define CMD_SUSFS_HIDE_SUS_MNTS_FOR_ALL_PROCS CMD_SUSFS_HIDE_SUS_MNTS_FOR_NON_SU_PROCS
EOF

# 2. Add missing function declarations (wshamroukh references these)
cat >> include/linux/susfs.h << 'EOF'

/* wshamroukh KSU-Next legacy-susfs compatibility */
void susfs_set_hide_sus_mnts_for_all_procs(void __user **user_info);
void susfs_set_i_state_on_external_dir(void __user **user_info);
void susfs_add_try_umount(void __user **user_info);
EOF

# 3. Add missing function stubs to susfs.c
cat >> fs/susfs.c << 'EOF'

/* wshamroukh KSU-Next legacy-susfs compatibility stubs */
void susfs_set_hide_sus_mnts_for_all_procs(void __user **user_info) {
    susfs_set_hide_sus_mnts_for_non_su_procs(user_info);
}
void susfs_set_i_state_on_external_dir(void __user **user_info) { }
void susfs_add_try_umount(void __user **user_info) { }
EOF

# 4. Fix task_mmu.c - ensure susfs_def.h is included (hunk #1 fails on Pixel 5 kernel)
if ! grep -q "susfs_def.h" fs/proc/task_mmu.c 2>/dev/null; then
    echo "=== Adding susfs_def.h include to task_mmu.c ==="
    # Insert at line 1 (before any other includes)
    sed -i '1s/^/#if defined(CONFIG_KSU_SUSFS_SUS_KSTAT) || defined(CONFIG_KSU_SUSFS_SUS_MAP) || defined(CONFIG_KSU_SUSFS_OPEN_REDIRECT)\n#include <linux\/susfs_def.h>\n#endif\n/' fs/proc/task_mmu.c
    grep -q "susfs_def.h" fs/proc/task_mmu.c && echo "=== task_mmu.c fixed ===" || echo "=== WARNING: task_mmu.c fix failed ==="
fi

# 5. Fix open.c - ensure susfs_def.h is included (normal_patches.sh may have overwritten it)
if ! grep -q "susfs_def.h" fs/open.c 2>/dev/null; then
    echo "=== Adding susfs_def.h include to open.c ==="
    sed -i '1s/^/#ifdef CONFIG_KSU_SUSFS\n#include <linux\/susfs_def.h>\n#endif\n/' fs/open.c
fi

# 6. Fix any other file that uses SUSFS_IS_INODE_* macros but missing susfs_def.h include
for f in fs/namei.c fs/namespace.c fs/stat.c fs/readdir.c fs/statfs.c fs/proc/fd.c fs/proc_namespace.c fs/notify/fdinfo.c; do
    if grep -q "SUSFS_IS_INODE\|susfs_def.h" "$f" 2>/dev/null && ! grep -q "susfs_def.h" "$f" 2>/dev/null; then
        echo "=== Adding susfs_def.h to $f ==="
        sed -i '1s/^/#ifdef CONFIG_KSU_SUSFS\n#include <linux\/susfs_def.h>\n#endif\n/' "$f"
    fi
done

echo "=== All compat fixes applied ==="
