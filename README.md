# ShellX

> Native C command-line enhancement engine. Plugin-based. Zero dependencies.

---

## Features

- ⚡ **Native C** — no Python, no runtime, instant startup
- 🔌 **Plugin system** — `.scp` packages, install with one command
- 🎨 **Smart prompt** — time, path, Git branch, exit code
- 🧠 **Command enhancement** — smart completion, error translation, timer
- 🛠️ **Dev tool** — `sccc` packer, create plugin in 30s
- 📱 **Termux ready** — runs on Android

---

## Install

```bash
git clone https://github.com/oprt-tish/arm64-ShellX
cd arm64-ShellX
./install.sh
```
---
## Usage
```bash
shellx plugin install <plugin.scp>   # install plugin
shellx plugin list                   # list installed
shellx apply <name>                  # run plugin
```
---
## Pack plugin
```bash
sccc pack main.scv -o plugin.scp
```
---
## License
GPL v3.0

