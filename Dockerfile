# Install ILSpy with the SDK; only the runtime is needed in the final image.
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS ilspy

ARG ILSPYCMD_VERSION=11.0.0.9375
RUN dotnet tool install ilspycmd --tool-path /opt/ilspy --version "$ILSPYCMD_VERSION"

FROM mcr.microsoft.com/dotnet/runtime:10.0-noble

ARG JADX_VERSION=1.5.6
ARG JADX_SHA256=545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974
ARG APKTOOL_VERSION=3.0.3
ARG APKTOOL_SHA256=dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423
ARG HERMES_DEC_VERSION=0.1.7
ARG ANDROGUARD_VERSION=4.1.4
ARG APKID_VERSION=3.1.0
ARG LZ4_VERSION=4.4.5
ARG DNFILE_VERSION=0.18.0
ARG PYELFTOOLS_VERSION=0.33
ARG BUNDLETOOL_VERSION=1.18.3
ARG BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils-multiarch build-essential ca-certificates curl git graphviz jq \
        libsmali-java lz4 openjdk-21-jdk-headless pkg-config python3-dev \
        python3-venv ripgrep unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL --retry 3 "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" -o /tmp/jadx.zip \
    && echo "$JADX_SHA256  /tmp/jadx.zip" | sha256sum -c - \
    && unzip -q /tmp/jadx.zip -d /opt/jadx \
    && rm /tmp/jadx.zip \
    && chmod +x /opt/jadx/bin/jadx \
    && ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx \
    && ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx-cli

RUN mkdir -p /opt/apktool \
    && curl -fsSL --retry 3 "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar" -o /opt/apktool/apktool.jar \
    && echo "$APKTOOL_SHA256  /opt/apktool/apktool.jar" | sha256sum -c - \
    && printf '%s\n' '#!/bin/sh' 'exec java -jar /opt/apktool/apktool.jar "$@"' > /usr/local/bin/apktool \
    && chmod +x /usr/local/bin/apktool

# Share one virtual environment across the Python tools.
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
        "hermes-dec==$HERMES_DEC_VERSION" \
        "androguard==$ANDROGUARD_VERSION" "apkid==$APKID_VERSION" \
        "lz4==$LZ4_VERSION" "dnfile==$DNFILE_VERSION" "pyelftools==$PYELFTOOLS_VERSION" \
        uv ruff mypy \
    && /opt/venv/bin/pip check \
    && ln -s /opt/venv/bin/hbc-decompiler /usr/local/bin/hermes-dec

RUN mkdir -p /opt/bundletool \
    && curl -fsSL --retry 3 "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" -o /opt/bundletool/bundletool.jar \
    && echo "$BUNDLETOOL_SHA256  /opt/bundletool/bundletool.jar" | sha256sum -c - \
    && printf '%s\n' '#!/bin/sh' 'exec java -jar /opt/bundletool/bundletool.jar "$@"' > /usr/local/bin/bundletool \
    && chmod +x /usr/local/bin/bundletool

COPY --from=ilspy /opt/ilspy /opt/ilspy
ENV PATH="/opt/ilspy:/opt/venv/bin:${PATH}"

# Run analysis as the base image's unprivileged app user.
WORKDIR /work
RUN chown app:app /work
USER app

# Fail the build if a tool or its runtime is missing.
RUN jadx --version \
    && jadx-cli --version \
    && hermes-dec --help > /dev/null \
    && hbc-disassembler --help > /dev/null \
    && hbc-file-parser --help > /dev/null \
    && ilspycmd --version \
    && apktool --version \
    && smali --version \
    && baksmali --version \
    && androguard --version \
    && apkid --help > /dev/null \
    && lz4 --version \
    && python3 -c 'import dnfile, lz4.block, lz4.frame; from elftools.elf.elffile import ELFFile' \
    && readelf --version \
    && objdump --version \
    && nm --version \
    && strings --version \
    && uv --version \
    && ruff --version \
    && mypy --version \
    && git --version \
    && curl --version \
    && jq --version \
    && rg --version \
    && unzip -v \
    && gcc --version \
    && g++ --version \
    && make --version \
    && pkg-config --version \
    && pkg-config --modversion python3 \
    && bundletool version

CMD ["bash"]
