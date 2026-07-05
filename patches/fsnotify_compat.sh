#!/bin/bash
# Add fsnotify_add_inode_mark compat for 4.19 kernel
# The SUSFS v2.2.0 patch uses #if >= 4.18.0 which includes 4.19,
# but fsnotify_add_inode_mark was actually introduced in 5.9

cat >> include/linux/susfs_def.h << 'EOF'

/* Compat: fsnotify_add_inode_mark introduced in 5.9, not in 4.19 */
#ifndef fsnotify_add_inode_mark
#define fsnotify_add_inode_mark(mark, inode, allow_dups) \
        fsnotify_add_mark(mark, &inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, allow_dups)
#endif
EOF

echo "=== Added fsnotify_add_inode_mark compat define ==="
