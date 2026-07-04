import re
import sys

filepath = sys.argv[1] if len(sys.argv) > 1 else 'kernel/reboot.c'

with open(filepath, 'r') as f:
    content = f.read()

extern_block = '#ifdef CONFIG_KSU\nextern int ksu_handle_sys_reboot(int magic1, int magic2, unsigned int cmd, void __user **arg);\n#endif\n'

content = re.sub(
    r'(SYSCALL_DEFINE4\(reboot,)',
    extern_block + r'\1',
    content,
    count=1
)

content = re.sub(
    r'(int ret = 0;\s*\n)',
    r'\1#ifdef CONFIG_KSU\n\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n#endif\n',
    content,
    count=1
)

if 'ksu_handle_sys_reboot' not in content:
    content = re.sub(
        r'(char buffer\[256\];\s*\n)',
        r'\1#ifdef CONFIG_KSU\n\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n#endif\n',
        content,
        count=1
    )

if 'ksu_handle_sys_reboot' not in content:
    content = re.sub(
        r'(SYSCALL_DEFINE4\(reboot,[^{]*?\{)',
        r'\1\n#ifdef CONFIG_KSU\n\tksu_handle_sys_reboot(magic1, magic2, cmd, &arg);\n#endif',
        content,
        count=1,
        flags=re.DOTALL
    )

with open(filepath, 'w') as f:
    f.write(content)

print('reboot.c patched successfully')
