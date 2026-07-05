#!/bin/bash
# Add compatibility aliases between v1.5.x patch constants and v2.2.0 susfs_def.h
# JackA1ltman's 50_add_susfs_in_kernel-4.19.patch uses old constant names
# manipvlator's v2.2.0 susfs_def.h uses new constant names
# This script bridges the naming gap

cat >> include/linux/susfs_def.h << 'SUSFS_ALIAS_EOF'

/* Compatibility aliases for JackA1ltman's 50_add_susfs_in_kernel-4.19.patch */
#define INODE_STATE_SUS_PATH AS_FLAGS_SUS_PATH
#define INODE_STATE_SUS_MOUNT AS_FLAGS_SUS_MOUNT
#define INODE_STATE_SUS_KSTAT AS_FLAGS_SUS_KSTAT
#define INODE_STATE_OPEN_REDIRECT AS_FLAGS_OPEN_REDIRECT
#define INODE_STATE_SUS_MAP AS_FLAGS_SUS_MAP
#define TASK_STRUCT_NON_ROOT_USER_APP_PROC TIF_PROC_UMOUNTED
SUSFS_ALIAS_EOF

# Add -Wno-incompatible-pointer-types to KSU Kbuild
KSU_KBUILD="drivers/kernelsu/Kbuild"
if [ -f "$KSU_KBUILD" ]; then
    REAL_KBUILD=$(readlink -f "$KSU_KBUILD")
    if ! grep -q "Wno-incompatible-pointer-types" "$REAL_KBUILD"; then
        sed -i 's/-Wno-declaration-after-statement/-Wno-declaration-after-statement -Wno-incompatible-pointer-types/g' "$REAL_KBUILD"
        echo "=== Added -Wno-incompatible-pointer-types to Kbuild ==="
    fi
fi

echo "=== SUSFS v2.2.0 compatibility aliases applied ==="


echo "=== SUSFS v2.0.0 compatibility patches applied ==="


