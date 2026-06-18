#!/bin/bash
# ShellX Full Installer
# Includes complete shellx.py + sccc_full.py source

set -e

echo "📦 Installing ShellX (Full)..."
echo ""
echo "execute in home directory(~/)"

# Create directories
mkdir -p ~/.local/bin
mkdir -p ~/.shellx/plugins
mkdir -p ~/.shellx/deps
mkdir -p ~/.shellx/bak

# ============================================================
# Install shellx (full source embedded)
# ============================================================
cat > ~/.local/bin/shellx << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ShellX - 命令行智能增强引擎 v3.0
"""

import os
import sys
import json
import zlib
import base64
import struct
import shutil
import subprocess
from pathlib import Path
from datetime import datetime

VERSION = "3.0.0"
HOME = str(Path.home())
SHELLX_DIR = f"{HOME}/.shellx"
PLUGINS_DIR = f"{SHELLX_DIR}/plugins"
DEPS_DIR = f"{SHELLX_DIR}/deps"
BACKUP_DIR = f"{SHELLX_DIR}/bak"
CONFIG_FILE = f"{SHELLX_DIR}/config.json"

def init_dirs():
    for d in [SHELLX_DIR, PLUGINS_DIR, DEPS_DIR, BACKUP_DIR]:
        os.makedirs(d, exist_ok=True)

def load_config():
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    return {"enabled": True, "plugins": []}

def save_config(config):
    with open(CONFIG_FILE, "w") as f:
        json.dump(config, f, indent=2)

def detect_shell():
    shell = os.environ.get("SHELL", "")
    return ("zsh", "~/.zshrc") if "zsh" in shell else ("bash", "~/.bashrc")

# ============================================================
# SCD 动态库管理
# ============================================================
def install_scd(scd_path):
    if not os.path.exists(scd_path):
        return False, f"文件不存在: {scd_path}"
    name = os.path.basename(scd_path)
    dest = os.path.join(DEPS_DIR, name)
    shutil.copy2(scd_path, dest)
    return True, f"✅ 已安装动态库: {name}"

def list_scd():
    if os.path.exists(DEPS_DIR):
        return [f for f in os.listdir(DEPS_DIR) if f.endswith(".scd")]
    return []

# ============================================================
# SCP 插件管理
# ============================================================
def install_scp(scp_path):
    if not os.path.exists(scp_path):
        return False, f"文件不存在: {scp_path}"

    with open(scp_path, "rb") as f:
        data = f.read()

    if data[:4] != b"SCP\x00":
        return False, "无效的 .scp 文件"

    compressed_len = struct.unpack("<I", data[4:8])[0]
    compressed = data[8:8+compressed_len]
    manifest = json.loads(zlib.decompress(compressed).decode())

    info = manifest.get("config", {})
    name = info.get("name", "unknown")

    print(f"📦 安装插件: {name}")

    # 解压 .scd
    scd_data = base64.b64decode(manifest.get("scd", ""))
    if scd_data:
        scd_path = os.path.join(DEPS_DIR, f"{name}.scd")
        with open(scd_path, "wb") as f:
            f.write(scd_data)
        print(f"   ✅ 已安装动态库: {name}.scd")

    # 解压 .scv 脚本
    scv_data = base64.b64decode(manifest.get("scv", ""))
    if scv_data:
        plugin_dir = os.path.join(PLUGINS_DIR, name)
        os.makedirs(plugin_dir, exist_ok=True)
        scv_path = os.path.join(plugin_dir, "main.scv")
        with open(scv_path, "wb") as f:
            f.write(scv_data)
        print(f"   ✅ 已保存脚本: main.scv")

        # 生成可执行命令
        bin_dir = os.path.expanduser("~/.local/bin")
        os.makedirs(bin_dir, exist_ok=True)
        cmd_path = os.path.join(bin_dir, name)
        with open(cmd_path, "w") as f:
            f.write(f"""#!/bin/bash
# ShellX plugin: {name}
SCRIPT_DIR="{plugin_dir}"
bash "$SCRIPT_DIR/main.scv"
""")
        os.chmod(cmd_path, 0o755)
        print(f"   ✅ 已生成命令: {name}")

    # 保存插件信息
    plugin_dir = os.path.join(PLUGINS_DIR, name)
    os.makedirs(plugin_dir, exist_ok=True)
    with open(os.path.join(plugin_dir, "plugin.json"), "w") as f:
        json.dump(info, f, indent=2)

    # 如果是 shell 插件，加载到 .bashrc
    if info.get("type") == "shell":
        main_sh = os.path.join(plugin_dir, "main.sh")
        if os.path.exists(main_sh):
            with open(main_sh, "r") as f:
                content = f.read()
            shell, rcfile = detect_shell()
            rcfile_expanded = os.path.expanduser(rcfile)
            with open(rcfile_expanded, "a") as f:
                f.write(f"\n# ShellX Plugin: {name}\n{content}\n")
            print(f"   ✅ 已加载到 {rcfile}")

    config = load_config()
    if name not in config.get("plugins", []):
        config.setdefault("plugins", []).append(name)
        save_config(config)

    return True, f"✅ 插件 {name} 安装成功!"

def list_scp():
    plugins = []
    if os.path.exists(PLUGINS_DIR):
        for p in os.listdir(PLUGINS_DIR):
            info_file = os.path.join(PLUGINS_DIR, p, "plugin.json")
            if os.path.exists(info_file):
                with open(info_file, "r") as f:
                    plugins.append(json.load(f))
    return plugins

def apply_plugin(name):
    """应用单个插件"""
    cmd_path = os.path.expanduser(f"~/.local/bin/{name}")
    if os.path.exists(cmd_path):
        subprocess.run([cmd_path])
        return True, f"✅ 已执行: {name}"
    return False, f"❌ 命令不存在: {name}"

# ============================================================
# 备份与恢复
# ============================================================
def backup_file(filepath):
    if not os.path.exists(filepath):
        return None
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    basename = os.path.basename(filepath)
    bak_path = os.path.join(BACKUP_DIR, f"{basename}.{timestamp}.bak")
    shutil.copy2(filepath, bak_path)
    return bak_path

def restore_all():
    if not os.path.exists(BACKUP_DIR):
        return 0, 0
    restored = 0
    failed = 0
    for f in os.listdir(BACKUP_DIR):
        if not f.endswith(".bak"):
            continue
        parts = f.rsplit(".", 2)
        if len(parts) != 3:
            continue
        original_name = parts[0]
        bak_path = os.path.join(BACKUP_DIR, f)
        if original_name == "bashrc":
            target = os.path.expanduser("~/.bashrc")
        elif original_name == "zshrc":
            target = os.path.expanduser("~/.zshrc")
        elif original_name == "colors.properties":
            target = os.path.expanduser("~/.termux/colors.properties")
        elif original_name == "font.ttf":
            target = os.path.expanduser("~/.termux/font.ttf")
        else:
            continue
        try:
            shutil.copy2(bak_path, target)
            restored += 1
        except:
            failed += 1
    return restored, failed

# ============================================================
# 主入口
# ============================================================
def main():
    init_dirs()

    if len(sys.argv) < 2:
        print(f"ShellX v{VERSION}")
        print("")
        print("用法:")
        print("  shellx plugin install <file.scp>   安装插件")
        print("  shellx plugin list                 列出已安装插件")
        print("  shellx scd list                    列出已安装动态库")
        print("  shellx apply                       应用所有插件")
        print("  shellx apply <name>                应用单个插件")
        print("  shellx backup <file>               备份文件")
        print("  shellx restore                     恢复所有备份")
        return

    cmd = sys.argv[1]

    if cmd == "plugin":
        if len(sys.argv) < 3:
            print("用法: shellx plugin install <file.scp>")
            print("      shellx plugin list")
            return
        subcmd = sys.argv[2]
        if subcmd == "install" and len(sys.argv) > 3:
            ok, msg = install_scp(sys.argv[3])
            print(msg)
        elif subcmd == "list":
            plugins = list_scp()
            if plugins:
                print("📦 已安装插件:")
                for p in plugins:
                    print(f"   - {p.get('name')} v{p.get('version')}")
            else:
                print("📭 没有已安装的插件")
        else:
            print("❌ 未知插件命令")

    elif cmd == "scd":
        if len(sys.argv) < 3:
            print("用法: shellx scd list")
            return
        if sys.argv[2] == "list":
            deps = list_scd()
            if deps:
                print("📦 已安装动态库:")
                for d in deps:
                    print(f"   - {d}")
            else:
                print("📭 没有已安装的动态库")

    elif cmd == "apply":
        if len(sys.argv) > 2:
            name = sys.argv[2]
            ok, msg = apply_plugin(name)
            print(msg)
            return
        plugins = list_scp()
        if not plugins:
            print("📭 没有已安装的插件")
            return
        print("🔧 应用所有插件:")
        for p in plugins:
            name = p.get("name")
            ok, msg = apply_plugin(name)
            print(f"   {msg}")

    elif cmd == "backup":
        if len(sys.argv) > 2:
            bak = backup_file(sys.argv[2])
            if bak:
                print(f"✅ 已备份到: {bak}")
            else:
                print("❌ 备份失败")
        else:
            print("用法: shellx backup <文件路径>")

    elif cmd == "restore":
        restored, failed = restore_all()
        print(f"📋 恢复完成: {restored} 成功, {failed} 失败")

    else:
        print(f"❌ 未知命令: {cmd}")

if __name__ == "__main__":
    main()
EOF

# ============================================================
# Install sccc (full source embedded)
# ============================================================
cat > ~/.local/bin/sccc << 'EOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sccc - ShellX 打包工具 v9.0
"""

import os
import sys
import json
import zlib
import base64
import struct
import subprocess
import tempfile
import shutil
import argparse
from datetime import datetime

VERSION = "9.0.0"
MAGIC_SCP = b"SCP\x00"

def pack_scv(scv_path, config, output_path):
    if not os.path.exists(scv_path):
        return False, f"脚本不存在: {scv_path}"
    with open(scv_path, "rb") as f:
        scv_data = f.read()
    if isinstance(config, str):
        if os.path.exists(config):
            with open(config, "r") as f:
                config_data = json.load(f)
        else:
            config_data = {"name": os.path.basename(scv_path).replace(".scv", ""), "version": "1.0"}
    else:
        config_data = config
    manifest = {
        "magic": "SCP\x00",
        "version": 1,
        "config": config_data,
        "scv": base64.b64encode(scv_data).decode(),
        "src_type": "scv",
        "timestamp": datetime.now().isoformat()
    }
    json_data = json.dumps(manifest).encode()
    compressed = zlib.compress(json_data, 9)
    with open(output_path, "wb") as f:
        f.write(MAGIC_SCP)
        f.write(struct.pack("<I", len(compressed)))
        f.write(compressed)
    return True, f"✅ 打包完成: {output_path}"

def pack_py(py_path, config, output_path):
    """打包 .py 为 .scp (Cython 编译为 .scd)"""
    if not os.path.exists(py_path):
        return False, f"脚本不存在: {py_path}"

    # 检查 Cython
    try:
        subprocess.run([sys.executable, "-c", "import Cython"], capture_output=True, check=True)
    except:
        return False, "Cython 未安装，请执行: pip install cython"

    name = os.path.basename(py_path).replace(".py", "")

    # 用 Cython 编译 .py → .so → .scd
    with tempfile.TemporaryDirectory() as tmpdir:
        setup_path = os.path.join(tmpdir, "setup.py")
        with open(setup_path, "w") as f:
            f.write(f'''
from setuptools import setup
from Cython.Build import cythonize
setup(name="{name}", ext_modules=cythonize(["{py_path}"]))
''')
        subprocess.run([sys.executable, setup_path, "build_ext", "--inplace"], cwd=tmpdir, capture_output=True)

        # 找 .so
        so_path = None
        for root, _, files in os.walk(tmpdir):
            for fn in files:
                if fn.endswith(".so"):
                    so_path = os.path.join(root, fn)
                    break
            if so_path:
                break

        if not so_path:
            return False, "编译失败，找不到 .so"

        with open(so_path, "rb") as f:
            so_data = f.read()

        scd_data = bytearray()
        scd_data.extend(b"SCD\x00")
        scd_data.extend(struct.pack("<I", 1))
        name_bytes = name.encode("utf-8")[:16].ljust(16, b"\x00")
        scd_data.extend(name_bytes)
        scd_data.extend(struct.pack("<I", 0))
        scd_data.extend(struct.pack("<I", len(so_data)))
        scd_data.extend(so_data)

        # 临时 .scd
        scd_path = os.path.join(tmpdir, f"{name}.scd")
        with open(scd_path, "wb") as f:
            f.write(scd_data)

        # 读取配置
        if isinstance(config, str):
            if os.path.exists(config):
                with open(config, "r") as f:
                    config_data = json.load(f)
            else:
                config_data = {"name": name, "version": "1.0"}
        else:
            config_data = config

        # 打包 .scp
        manifest = {
            "magic": "SCP\x00",
            "version": 1,
            "config": config_data,
            "scd": base64.b64encode(scd_data).decode(),
            "src_type": "python",
            "timestamp": datetime.now().isoformat()
        }
        json_data = json.dumps(manifest).encode()
        compressed = zlib.compress(json_data, 9)
        with open(output_path, "wb") as f:
            f.write(MAGIC_SCP)
            f.write(struct.pack("<I", len(compressed)))
            f.write(compressed)

    return True, f"✅ 打包完成: {output_path} (Python → .scp)"

def init_plugin(name):
    os.makedirs(f"{name}_plugin", exist_ok=True)
    with open(f"{name}_plugin/plugin.json", "w") as f:
        json.dump({"name": name, "version": "1.0", "author": "your_name"}, f, indent=2)
    with open(f"{name}_plugin/main.scv", "w") as f:
        f.write(f"main() {{ echo 'Hello from {name}!' }}\nmain")
    print(f"✅ 已创建: {name}_plugin/")

def info_scp(scp_path):
    if not os.path.exists(scp_path):
        return False, f"文件不存在: {scp_path}"
    with open(scp_path, "rb") as f:
        data = f.read()
    if data[:4] != MAGIC_SCP:
        return False, "无效的 .scp 文件"
    compressed_len = struct.unpack("<I", data[4:8])[0]
    manifest = json.loads(zlib.decompress(data[8:8+compressed_len]).decode())
    config = manifest.get("config", {})
    print(f"📋 SCP 信息:")
    print(f"   插件名: {config.get('name', 'unknown')}")
    print(f"   版本: {config.get('version', '1.0')}")
    print(f"   作者: {config.get('author', 'unknown')}")
    print(f"   类型: {manifest.get('src_type', 'unknown')}")
    print(f"   大小: {len(data)} 字节")
    return True, ""

def main():
    if len(sys.argv) < 2:
        print(f"sccc v{VERSION}")
        print("")
        print("用法:")
        print("  sccc pack <main.scv> -c plugin.json -o plugin.scp")
        print("  sccc pack <main.py> -c plugin.json -o plugin.scp   (Python → .scp)")
        print("  sccc init <name>")
        print("  sccc info <plugin.scp>")
        return

    cmd = sys.argv[1]

    if cmd == "pack":
        if len(sys.argv) < 3:
            print("❌ 请指定源文件")
            return
        src = sys.argv[2]
        config = "plugin.json"
        output = src.replace(".scv", ".scp").replace(".py", ".scp")
        for i, arg in enumerate(sys.argv):
            if arg == "-c" and i+1 < len(sys.argv):
                config = sys.argv[i+1]
            elif arg == "-o" and i+1 < len(sys.argv):
                output = sys.argv[i+1]

        if src.endswith(".scv"):
            ok, msg = pack_scv(src, config, output)
        elif src.endswith(".py"):
            ok, msg = pack_py(src, config, output)
        else:
            print(f"❌ 不支持: {src}")
            return
        print(msg)

    elif cmd == "init":
        if len(sys.argv) < 3:
            print("❌ 请指定插件名")
            return
        init_plugin(sys.argv[2])

    elif cmd == "info":
        if len(sys.argv) < 3:
            print("❌ 请指定 .scp 文件")
            return
        ok, msg = info_scp(sys.argv[2])
        if not ok:
            print(f"❌ {msg}")

    else:
        print(f"❌ 未知命令: {cmd}")

if __name__ == "__main__":
    main()
EOF

# ============================================================
# Set permissions
# ============================================================
chmod +x ~/.local/bin/shellx
chmod +x ~/.local/bin/sccc

# Add to PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# ============================================================
# Done
# ============================================================
echo ""
echo "✅ ShellX (Full) installed successfully!"
echo ""
echo "📦 Installed commands:"
echo "  shellx  - plugin manager"
echo "  sccc    - plugin packer"
echo ""
echo "Usage:"
echo "  shellx plugin install <plugin.scp>   install plugin"
echo "  shellx plugin list                   list plugins"
echo "  shellx scd list                      list dynamic libs"
echo "  shellx apply                         apply all plugins"
echo "  shellx apply <name>                  apply single plugin"
echo "  shellx backup <file>                 backup file"
echo "  shellx restore                       restore all backups"
echo ""
echo "Packer:"
echo "  sccc pack main.scv -o plugin.scp     pack .scv plugin"
echo "  sccc pack main.py -o plugin.scp      pack .py plugin (Cython)"
echo "  sccc init <name>                     create plugin template"
echo "  sccc info <plugin.scp>               show plugin info"
EOF

chmod +x install.sh
./install.sh
source ~/.bashrc