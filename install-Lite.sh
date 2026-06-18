#!/bin/bash
# ShellX installer (Lite version)
# Only core plugin management, no Python C extension support

set -e

echo "📦 Installing ShellX (Lite)..."
echo "ℹ️  Lite version: plugin install/list/apply only"
echo ""

mkdir -p ~/.local/bin
mkdir -p ~/.shellx/plugins

cat > ~/.local/bin/shellx << 'END'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ShellX - Command-line enhancement engine (Lite)
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

VERSION = "3.0.0-lite"
HOME = str(Path.home())
PLUGINS_DIR = f"{HOME}/.shellx/plugins"
BIN_DIR = f"{HOME}/.local/bin"

def list_plugins():
    plugins = []
    if os.path.exists(PLUGINS_DIR):
        for p in os.listdir(PLUGINS_DIR):
            info_file = os.path.join(PLUGINS_DIR, p, "plugin.json")
            if os.path.exists(info_file):
                with open(info_file, "r") as f:
                    plugins.append(json.load(f))
    return plugins

def install_plugin(scp_path):
    if not os.path.exists(scp_path):
        return False, f"File not found: {scp_path}"

    with open(scp_path, "rb") as f:
        data = f.read()

    if data[:4] != b"SCP\x00":
        return False, "Invalid .scp file"

    compressed_len = struct.unpack("<I", data[4:8])[0]
    compressed = data[8:8+compressed_len]
    manifest = json.loads(zlib.decompress(compressed).decode())

    info = manifest.get("config", {})
    name = info.get("name", "unknown")

    print(f"📦 Installing: {name}")

    plugin_dir = os.path.join(PLUGINS_DIR, name)
    os.makedirs(plugin_dir, exist_ok=True)

    scv_data = base64.b64decode(manifest.get("scv", ""))
    if scv_data:
        scv_path = os.path.join(plugin_dir, "main.scv")
        with open(scv_path, "wb") as f:
            f.write(scv_data)
        print(f"   ✅ Script saved: main.scv")

        cmd_path = os.path.join(BIN_DIR, name)
        with open(cmd_path, "w") as f:
            f.write(f"""#!/bin/bash
# ShellX plugin: {name}
SCRIPT_DIR="{plugin_dir}"
bash "$SCRIPT_DIR/main.scv"
""")
        os.chmod(cmd_path, 0o755)
        print(f"   ✅ Command: {name}")

    with open(os.path.join(plugin_dir, "plugin.json"), "w") as f:
        json.dump(info, f, indent=2)

    return True, f"✅ Plugin {name} installed!"

def apply_plugin(name):
    cmd_path = os.path.join(BIN_DIR, name)
    if os.path.exists(cmd_path):
        subprocess.run([cmd_path])
        return True, f"✅ Executed: {name}"
    return False, f"Command not found: {name}"

def main():
    if len(sys.argv) < 2:
        print(f"ShellX {VERSION} (Lite)")
        print("")
        print("Usage:")
        print("  shellx plugin install <file.scp>   install plugin")
        print("  shellx plugin list                 list installed")
        print("  shellx apply <name>                run plugin")
        return

    cmd = sys.argv[1]

    if cmd == "plugin":
        if len(sys.argv) < 3:
            print("Usage: shellx plugin install <file.scp>")
            return
        if sys.argv[2] == "install" and len(sys.argv) > 3:
            ok, msg = install_plugin(sys.argv[3])
            print(msg)
        elif sys.argv[2] == "list":
            plugins = list_plugins()
            if plugins:
                print("📦 Installed plugins:")
                for p in plugins:
                    print(f"   - {p.get('name')} v{p.get('version')}")
            else:
                print("📭 No plugins installed")

    elif cmd == "apply":
        if len(sys.argv) > 2:
            name = sys.argv[2]
            ok, msg = apply_plugin(name)
            print(msg)
        else:
            print("Usage: shellx apply <plugin_name>")

    else:
        print(f"❌ Unknown: {cmd}")

if __name__ == "__main__":
    main()
END

chmod +x ~/.local/bin/shellx

# install sccc packer
cat > ~/.local/bin/sccc << 'END'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
sccc - ShellX plugin packer (Lite)
"""

import os
import sys
import json
import zlib
import base64
import struct
from datetime import datetime

VERSION = "5.0.0-lite"

def pack(scv_path, config, output_path):
    if not os.path.exists(scv_path):
        return False, f"Script not found: {scv_path}"

    with open(scv_path, "rb") as f:
        scv_data = f.read()

    if os.path.exists(config):
        with open(config, "r") as f:
            config_data = json.load(f)
    else:
        config_data = {"name": os.path.basename(scv_path).replace(".scv", ""), "version": "1.0"}

    manifest = {
        "magic": "SCP\x00",
        "version": 1,
        "config": config_data,
        "scv": base64.b64encode(scv_data).decode(),
        "timestamp": datetime.now().isoformat()
    }

    json_data = json.dumps(manifest).encode()
    compressed = zlib.compress(json_data, 9)

    with open(output_path, "wb") as f:
        f.write(b"SCP\x00")
        f.write(struct.pack("<I", len(compressed)))
        f.write(compressed)

    print(f"✅ Packed: {output_path}")
    return True, output_path

def main():
    if len(sys.argv) < 2:
        print("sccc - ShellX plugin packer (Lite)")
        print("Usage: sccc pack <main.scv> [-c config.json] [-o output.scp]")
        return

    if sys.argv[1] == "pack" and len(sys.argv) > 2:
        scv = sys.argv[2]
        config = "plugin.json"
        output = scv.replace(".scv", ".scp")
        for i, arg in enumerate(sys.argv):
            if arg == "-c" and i+1 < len(sys.argv):
                config = sys.argv[i+1]
            elif arg == "-o" and i+1 < len(sys.argv):
                output = sys.argv[i+1]
        ok, msg = pack(scv, config, output)
        if not ok:
            print(f"❌ {msg}")

if __name__ == "__main__":
    main()
END

chmod +x ~/.local/bin/sccc

# add to PATH
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

echo ""
echo "✅ ShellX (Lite) installed!"
echo "ℹ️  Lite version: plugin install/list/apply only"
echo ""
echo "Usage:"
echo "  shellx plugin install <plugin.scp>   install plugin"
echo "  shellx plugin list                   list plugins"
echo "  shellx apply <name>                  run plugin"
echo ""
echo "Packer:"
echo "  sccc pack main.scv -o plugin.scp     pack plugin"
