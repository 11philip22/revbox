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
ARG BUNDLETOOL_VERSION=1.18.3
ARG BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils-multiarch ca-certificates curl graphviz libsmali-java \
        openjdk-21-jdk-headless python3-venv ripgrep unzip \
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
RUN python3 -m venv /opt/hermes-dec \
    && /opt/hermes-dec/bin/pip install --no-cache-dir \
        "hermes-dec==$HERMES_DEC_VERSION" \
        "androguard==$ANDROGUARD_VERSION" "apkid==$APKID_VERSION" \
    && /opt/hermes-dec/bin/pip check \
    && ln -s /opt/hermes-dec/bin/hbc-decompiler /usr/local/bin/hermes-dec

RUN mkdir -p /opt/bundletool \
    && curl -fsSL --retry 3 "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" -o /opt/bundletool/bundletool.jar \
    && echo "$BUNDLETOOL_SHA256  /opt/bundletool/bundletool.jar" | sha256sum -c - \
    && printf '%s\n' '#!/bin/sh' 'exec java -jar /opt/bundletool/bundletool.jar "$@"' > /usr/local/bin/bundletool \
    && chmod +x /usr/local/bin/bundletool

# BuildKit supplies TARGETARCH to select Joern's matching native binaries.
ARG TARGETARCH
ARG JOERN_VERSION=4.0.634
ARG JOERN_AMD64_SHA256=b446f639786eb4c2eccc5a73f62ad20c9d82aff1ba8f3870506d8034fb042577
ARG JOERN_ARM64_SHA256=de6bb0532aab501044e71336e2332428001e22ae3696d33092e0849ac59182d3
ARG JOERN_QUERYDB_SHA256=7a0d61a571795855fb7d7d95797a1f0dc8db2c26e37682896ee8ef1c12c9bf80

RUN case "$TARGETARCH" in \
        amd64) joern_arch=x86_64; joern_sha256="$JOERN_AMD64_SHA256" ;; \
        arm64) joern_arch=arm64; joern_sha256="$JOERN_ARM64_SHA256" ;; \
        *) echo "Unsupported Joern architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && curl -fsSL --retry 3 "https://github.com/joernio/joern/releases/download/v${JOERN_VERSION}/joern-cli-linux-${joern_arch}.zip" -o /tmp/joern.zip \
    && echo "$joern_sha256  /tmp/joern.zip" | sha256sum -c - \
    && unzip -q /tmp/joern.zip -d /opt \
    && rm /tmp/joern.zip

# Bundle the default queries used by joern-scan.
RUN curl -fsSL --retry 3 "https://github.com/joernio/joern/releases/download/v${JOERN_VERSION}/querydb.zip" -o /tmp/querydb.zip \
    && echo "$JOERN_QUERYDB_SHA256  /tmp/querydb.zip" | sha256sum -c - \
    && /opt/joern-cli/joern --add-plugin /tmp/querydb.zip \
    && rm /tmp/querydb.zip

COPY --from=ilspy /opt/ilspy /opt/ilspy
ENV PATH="/opt/joern-cli:/opt/ilspy:/opt/hermes-dec/bin:${PATH}"

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
    && readelf --version \
    && objdump --version \
    && nm --version \
    && strings --version \
    && rg --version \
    && bundletool version \
    && joern --help > /dev/null \
    && joern-parse --help > /dev/null \
    && joern-export --help > /dev/null \
    && joern-scan --dump-to /tmp/joern-queries.json \
    && python3 -c 'import json; assert json.load(open("/tmp/joern-queries.json"))' \
    && rm /tmp/joern-queries.json /tmp/joern-scan-log.txt

CMD ["bash"]
