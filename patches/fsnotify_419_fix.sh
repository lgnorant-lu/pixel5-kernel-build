#!/bin/bash
# Patch susfs.c fsnotify functions for 4.19 kernel API compatibility
# v2.2.0 susfs.c uses 5.x fsnotify API, needs backport to 4.19

# 1. Replace susfs_handle_sdcard_inode_event signature (5.x -> 4.19)
# 5.x: int susfs_handle_sdcard_inode_event(struct fsnotify_group *group, struct inode *inode, struct fsnotify_mark *inode_mark, struct fsnotify_mark *vfsmount_mark, u32 mask, const void *data, int data_type, const unsigned char *file_name, u32 cookie, struct fsnotify_iter_info *iter_info)
# 4.19: static int susfs_handle_sdcard_inode_event(struct fsnotify_mark *mark, u32 mask, struct inode *inode, struct inode *dir, const struct qstr *file_name, u32 cookie)

sed -i '/int susfs_handle_sdcard_inode_event/,/^{/{
    s/int susfs_handle_sdcard_inode_event(struct fsnotify_group \*group, struct inode \*inode, struct fsnotify_mark \*inode_mark, struct fsnotify_mark \*vfsmount_mark, u32 mask, const void \*data, int data_type, const unsigned char \*file_name, u32 cookie, struct fsnotify_iter_info \*iter_info)/static int susfs_handle_sdcard_inode_event(struct fsnotify_mark *mark, u32 mask, struct inode *inode, struct inode *dir, const struct qstr *file_name, u32 cookie)/
}' fs/susfs.c

# 2. Replace the ops struct initializer (5.x has .handle_event, 4.19 also uses .handle_event but different type)
# The struct fsnotify_ops_type for 4.19 uses different callback type
# Need to cast or use a compatible wrapper

# 3. Fix fsnotify_add_mark call (5.x -> 4.19)
# 5.x: fsnotify_add_mark(m, inode, NULL, 0)
# 4.19: fsnotify_add_mark(mark, &inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, 0)
sed -i 's/fsnotify_add_mark(m, inode, NULL, 0)/fsnotify_add_mark(m, \&inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, 0)/g' fs/susfs.c
# Also fix any other variant
sed -i 's/fsnotify_add_mark(m, inode, g)/fsnotify_add_mark(m, \&inode->i_fsnotify_marks, FSNOTIFY_OBJ_TYPE_INODE, 0)/g' fs/susfs.c

# 4. Fix any remaining 5.x-only parameters in the event handler body
# The handler body references data_type and iter_info which don't exist in 4.19
# Need to remove or comment out those references

echo "=== fsnotify 4.19 API patch applied ==="
grep -n "susfs_handle_sdcard_inode_event" fs/susfs.c | head -5
grep -n "fsnotify_add_mark" fs/susfs.c | head -5
