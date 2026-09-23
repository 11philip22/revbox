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
| [GNU Binutils](https://packages.ubuntu.com/noble/binutils-multiarch) | Ubuntu package (2.42) | `readelf`, `objdump`, `nm`, `strings` |
| [bundletool](https://github.com/google/bundletool/releases/tag/1.18.3) | 1.18.3 | `bundletool` |

`jadx-cli` aliases `jadx`; `hermes-dec` aliases `hbc-decompiler`.
The image includes Java 21, Python 3, .NET 10, `unzip`, and Graphviz for Androguard
graphs. Binutils supports multiple target architectures.

## Build

Start Docker, then run:

```sh
docker build -t revbox .
```

The build verifies the JADX, Apktool, and bundletool download checksums and runs a
startup check for every tool. The .NET SDK is used only in the build stage.

## Run

Open a shell with the current directory mounted at `/work`:

```sh
docker run --rm -it -v "$PWD:/work" revbox
```

Or run a tool directly (replace the input filenames with your own):

```sh
docker run --rm -v "$PWD:/work" revbox jadx-cli -d java-output app.apk
docker run --rm -v "$PWD:/work" revbox apktool d app.apk -o apk-output
docker run --rm -v "$PWD:/work" revbox hermes-dec index.android.bundle hermes-output.js
docker run --rm -v "$PWD:/work" revbox ilspycmd -p -o dotnet-output assembly.dll
docker run --rm -v "$PWD:/work" revbox baksmali disassemble classes.dex -o smali-output
docker run --rm -v "$PWD:/work" revbox smali assemble smali-output -o rebuilt.dex
docker run --rm -v "$PWD:/work" revbox androguard apkid app.apk
docker run --rm -v "$PWD:/work" revbox apkid app.apk
docker run --rm -v "$PWD:/work" revbox readelf -h libnative.so
docker run --rm -v "$PWD:/work" revbox objdump -d libnative.so
docker run --rm -v "$PWD:/work" revbox nm -D libnative.so
docker run --rm -v "$PWD:/work" revbox strings libnative.so
docker run --rm -v "$PWD:/work" revbox bundletool validate --bundle=app.aab
```
Outputs in `/work` are saved to the host directory. The container runs as the
unprivileged `app` user; the mounted directory must be writable by that user.
Use `--help` (or `bundletool help`) for options. Hermes decompilation produces pseudocode.

Downloaded tool versions are pinned in `Dockerfile`. To upgrade JADX, Apktool, or
bundletool, update both the version and its SHA-256 checksum. The base image and
OS packages receive updates when rebuilding with
`docker build --pull --no-cache -t revbox .`.
