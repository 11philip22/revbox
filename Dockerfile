# Install ILSpy with the SDK; only the runtime is needed in the final image.
FROM mcr.microsoft.com/dotnet/sdk:10.0-noble AS ilspy

ARG ILSPYCMD_VERSION=11.0.0.9375
RUN dotnet tool install ilspycmd --tool-path /opt/ilspy --version "$ILSPYCMD_VERSION"

FROM mcr.microsoft.com/dotnet/runtime:10.0-noble

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        binutils-multiarch build-essential ca-certificates curl git graphviz jq \
        libsmali-java lz4 openjdk-21-jdk-headless pkg-config python3-dev \
        python3-venv ripgrep unzip \
    && rm -rf /var/lib/apt/lists/*

ARG JADX_VERSION=1.5.6
ARG JADX_SHA256=545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974
RUN curl -fsSL --retry 3 "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip" -o /tmp/jadx.zip \
    && echo "$JADX_SHA256  /tmp/jadx.zip" | sha256sum -c - \
    && unzip -q /tmp/jadx.zip -d /opt/jadx \
    && rm /tmp/jadx.zip \
    && chmod +x /opt/jadx/bin/jadx \
    && ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx \
    && ln -s /opt/jadx/bin/jadx /usr/local/bin/jadx-cli

ARG APKTOOL_VERSION=3.0.3
ARG APKTOOL_SHA256=dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423
RUN mkdir -p /opt/apktool \
    && curl -fsSL --retry 3 "https://github.com/iBotPeaches/Apktool/releases/download/v${APKTOOL_VERSION}/apktool_${APKTOOL_VERSION}.jar" -o /opt/apktool/apktool.jar \
    && echo "$APKTOOL_SHA256  /opt/apktool/apktool.jar" | sha256sum -c - \
    && printf '%s\n' '#!/bin/sh' 'exec java -jar /opt/apktool/apktool.jar "$@"' > /usr/local/bin/apktool \
    && chmod +x /usr/local/bin/apktool

# Share one virtual environment across the Python tools.
ARG HERMES_DEC_VERSION=0.1.7
ARG ANDROGUARD_VERSION=4.1.4
ARG APKID_VERSION=3.1.0
ARG LZ4_VERSION=4.4.5
ARG DNFILE_VERSION=0.18.0
ARG PYELFTOOLS_VERSION=0.33
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir \
        "hermes-dec==$HERMES_DEC_VERSION" \
        "androguard==$ANDROGUARD_VERSION" "apkid==$APKID_VERSION" \
        "lz4==$LZ4_VERSION" "dnfile==$DNFILE_VERSION" "pyelftools==$PYELFTOOLS_VERSION" \
        uv ruff mypy \
    && /opt/venv/bin/pip check \
    && ln -s /opt/venv/bin/hbc-decompiler /usr/local/bin/hermes-dec

ARG BUNDLETOOL_VERSION=1.18.3
ARG BUNDLETOOL_SHA256=a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29
RUN mkdir -p /opt/bundletool \
    && curl -fsSL --retry 3 "https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/bundletool-all-${BUNDLETOOL_VERSION}.jar" -o /opt/bundletool/bundletool.jar \
    && echo "$BUNDLETOOL_SHA256  /opt/bundletool/bundletool.jar" | sha256sum -c - \
    && printf '%s\n' '#!/bin/sh' 'exec java -jar /opt/bundletool/bundletool.jar "$@"' > /usr/local/bin/bundletool \
    && chmod +x /usr/local/bin/bundletool

ARG GHIDRA_VERSION=12.1.3
ARG GHIDRA_DATE=20260817
ARG GHIDRA_SHA256=93a5d11a9ad510622acaaf908c556a7b9b764d338e78a7567f3689bf5081fd54
ARG TARGETARCH
RUN curl -fsSL --retry 3 \
        "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_DATE}.zip" \
        -o /tmp/ghidra.zip \
    && echo "$GHIDRA_SHA256  /tmp/ghidra.zip" | sha256sum -c - \
    && unzip -q /tmp/ghidra.zip -d /opt \
    && mv "/opt/ghidra_${GHIDRA_VERSION}_PUBLIC" /opt/ghidra \
    && rm /tmp/ghidra.zip \
    && mkdir -p /opt/ghidra/Ghidra/Extensions \
    && unzip -q /opt/ghidra/Extensions/Ghidra/*_Jython.zip -d /opt/ghidra/Ghidra/Extensions \
    && case "$TARGETARCH" in \
        amd64) test -x /opt/ghidra/Ghidra/Features/Decompiler/os/linux_x86_64/decompile ;; \
        arm64) cd /opt/ghidra/support/gradle \
            && GRADLE_USER_HOME=/tmp/ghidra-gradle ./gradlew --no-daemon buildNatives \
            && test -x /opt/ghidra/Ghidra/Features/Decompiler/build/os/linux_arm_64/decompile \
            && rm -rf /tmp/ghidra-gradle /opt/ghidra/support/gradle/.gradle ;; \
        *) echo "Unsupported Ghidra architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac \
    && ln -s /opt/ghidra/support/analyzeHeadless /usr/local/bin/analyzeHeadless

ENV GHIDRA_HOME=/opt/ghidra \
    REFORGE_GHIDRA_HOME=/opt/ghidra

COPY --from=ilspy /opt/ilspy /opt/ilspy
ENV PATH="/opt/ilspy:/opt/venv/bin:${PATH}"

# Run analysis as the base image's unprivileged app user.
WORKDIR /work
RUN chown app:app /work
USER app

CMD ["bash"]
