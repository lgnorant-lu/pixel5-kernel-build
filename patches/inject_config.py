#!/usr/bin/env python3
"""Inject KSU/SUSFS config into build.config.redbull.vintf's update_config function."""
import sys

config_file = sys.argv[1]
ksu_opts = sys.argv[2]  # e.g. "-e KSU --disable KSU_MANUAL_HOOK -e KSU_SUSFS"

with open(config_file, 'r') as f:
    content = f.read()

if 'KSU_SUSFS_SUS_PATH' in content:
    print('=== build.config already has KSU config ===')
    sys.exit(0)

# Build the injection block — ${KERNEL_DIR} and ${OUT_DIR} must be preserved literally
# They are bash variables expanded at runtime by update_config()
inject = (
    '    ${KERNEL_DIR}/scripts/config --file ${OUT_DIR}/.config \\\n'
    '    ' + ksu_opts + ' \\\n'
    '    -e KSU_SUSFS_SUS_PATH -e KSU_SUSFS_SUS_MOUNT -e KSU_SUSFS_SUS_KSTAT \\\n'
    '    -e KSU_SUSFS_TRY_UMOUNT -e KSU_SUSFS_SPOOF_UNAME -e KSU_SUSFS_ENABLE_LOG \\\n'
    '    -e KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS -e KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG \\\n'
    '    -e KSU_SUSFS_OPEN_REDIRECT -e KSU_SUSFS_SUS_MAP\n'
)

# Insert before olddefconfig) in update_config function
target = 'olddefconfig)\n}'
if target in content:
    content = content.replace(target, inject + '    ' + target, 1)
    with open(config_file, 'w') as f:
        f.write(content)
    print('=== Config injected into build.config ===')
else:
    print('WARNING: olddefconfig) not found in build.config')
    sys.exit(1)
