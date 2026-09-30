# revbox

A Docker toolbox for inspecting Android apps.

| Tool | Version | Commands |
| --- | --- | --- |
| [JADX](https://github.com/skylot/jadx/releases/tag/v1.5.6) | 1.5.6 | `jadx`, `jadx-cli` |
| [hermes-dec](https://pypi.org/project/hermes-dec/0.1.7/) | 0.1.7 | `hermes-dec`, `hbc-decompiler`, `hbc-disassembler`, `hbc-file-parser` |
| [ILSpy CLI](https://www.nuget.org/packages/ilspycmd/11.0.0.9375) | 11.0.0.9375 | `ilspycmd` |
| [Apktool](https://github.com/iBotPeaches/Apktool/releases/tag/v3.0.3) | 3.0.3 | `apktool` |
| [smali / baksmali](https://packages.ubuntu.com/noble/libsmali-java) | Ubuntu package (2.5.2) | `smali`, `baksmali` |
| [Androguard](https://pypi.org/project/androguard/4.1.4/) | 4.1.4 | `androguard` |
| [APKiD](https://pypi.org/project/apkid/3.1.0/) | 3.1.0 | `apkid` |
| [LZ4 CLI](https://packages.ubuntu.com/noble/lz4) | Ubuntu package (1.9.4) | `lz4` |
| [lz4](https://pypi.org/project/lz4/4.4.5/) | 4.4.5 | Python: `import lz4.block`, `import lz4.frame` |
| [dnfile](https://pypi.org/project/dnfile/0.18.0/) | 0.18.0 | Python: `import dnfile` |
| [pyelftools](https://pypi.org/project/pyelftools/0.33/) | 0.33 | Python: `from elftools.elf.elffile import ELFFile` |
| [GNU Binutils](https://packages.ubuntu.com/noble/binutils-multiarch) | Ubuntu package (2.42) | `readelf`, `objdump`, `nm`, `strings` |
| [ripgrep](https://packages.ubuntu.com/noble/ripgrep) | Ubuntu package (14.1.0) | `rg` |
| [uv](https://pypi.org/project/uv/) | Latest at build time | `uv`, `uvx` |
| [Ruff](https://pypi.org/project/ruff/) | Latest at build time | `ruff` (linting, formatting, import sorting) |
| [mypy](https://pypi.org/project/mypy/) | Latest at build time | `mypy` |
| Development utilities | Ubuntu packages | `git`, `curl`, `jq`, `unzip` |
| Native build tools | Ubuntu packages | `gcc`, `g++`, `make`, `pkg-config`; Python headers |
| [bundletool](https://github.com/google/bundletool/releases/tag/1.18.3) | 1.18.3 | `bundletool` |

`jadx-cli` aliases `jadx`; `hermes-dec` aliases `hbc-decompiler`.
The image includes the Java 21 JDK, Python 3, .NET 10, `unzip`, and Graphviz for
Androguard graphs. Binutils supports multiple target architectures.
Python tools and libraries share `/opt/venv`, with `python3` and `pip` on `PATH`.
`uv` manages project packages, virtual environments, and dependency locks.
`build-essential`, `python3-dev`, and `pkg-config` support compiling native extensions.

## Pull

```sh
docker pull philipwold/revbox
```

## Build

```sh
docker build -t philipwold/revbox .
```

The build verifies the JADX, Apktool, and bundletool download checksums and
runs a startup check for every tool. The .NET SDK is used only in the build stage.

## Run

Open a shell with the current directory mounted at `/work`:

```sh
docker run --rm -it -v "$PWD:/work" philipwold/revbox
```

Or run a tool directly (replace the input filenames with your own):

```sh
docker run --rm -v "$PWD:/work" philipwold/revbox jadx-cli -d java-output app.apk
docker run --rm -v "$PWD:/work" philipwold/revbox apktool d app.apk -o apk-output
docker run --rm -v "$PWD:/work" philipwold/revbox hermes-dec index.android.bundle hermes-output.js
docker run --rm -v "$PWD:/work" philipwold/revbox ilspycmd -p -o dotnet-output assembly.dll
docker run --rm -v "$PWD:/work" philipwold/revbox baksmali disassemble classes.dex -o smali-output
docker run --rm -v "$PWD:/work" philipwold/revbox smali assemble smali-output -o rebuilt.dex
docker run --rm -v "$PWD:/work" philipwold/revbox androguard apkid app.apk
docker run --rm -v "$PWD:/work" philipwold/revbox apkid app.apk
docker run --rm -v "$PWD:/work" philipwold/revbox lz4 -d input.lz4 output.bin
docker run --rm -v "$PWD:/work" philipwold/revbox readelf -h libnative.so
docker run --rm -v "$PWD:/work" philipwold/revbox objdump -d libnative.so
docker run --rm -v "$PWD:/work" philipwold/revbox nm -D libnative.so
docker run --rm -v "$PWD:/work" philipwold/revbox strings libnative.so
docker run --rm -v "$PWD:/work" philipwold/revbox rg -n 'https?://' java-output
docker run --rm -v "$PWD:/work" philipwold/revbox bundletool validate --bundle=app.aab
```
Outputs in `/work` are saved to the host directory. The container runs as the
unprivileged `app` user; the mounted directory must be writable by that user.
Use `--help` (or `bundletool help`) for options. Hermes decompilation produces pseudocode.
