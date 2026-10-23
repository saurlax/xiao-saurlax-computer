# syntax=docker/dockerfile:1
# Only the daemon is copied from this headless image. Pin both architectures
# together so an upstream dev tag cannot silently change our runtime contract.
FROM ghcr.io/converge-ai-labs/a13n-sandbox:dev-slim@sha256:a8c3ac9c30651e5cba99200bb9289ea9c4ad099c48ffed355fb592c8823119a4 AS envd
FROM node:24-trixie-slim AS node

FROM python:3.13-slim-trixie

LABEL org.opencontainers.image.title="xiao-saurlax-computer" \
      org.opencontainers.image.description="A headless Debian toolbox with a13n-envd, Python, Node.js, and AnyCap" \
      org.opencontainers.image.source="https://github.com/saurlax/xiao-saurlax-computer" \
      ai.a13n.environment.user="sandbox"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    ANYCAP_NO_UPDATE=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash bash-completion ca-certificates curl dnsutils fd-find file git \
        iproute2 iputils-ping jq less nano netcat-openbsd openssh-client procps \
        libgcc-s1 ripgrep sqlite3 tini tree unzip util-linux vim-tiny wget xz-utils zip zsh \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Verified against the upstream v0.6.4 release checksums. No credentials are
# accepted as build arguments or stored in the image.
ARG TARGETARCH
RUN set -eu; \
    case "$TARGETARCH" in \
        amd64) checksum=ff31687c8f210d8dc5848e98df3a8be2de9cdb486b4de8b28688ee5aa4c95b41 ;; \
        arm64) checksum=f8d39d1c0094f50f86bc5d7df30149f034260be2fff90c4bf2442f5016fbda16 ;; \
        *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
    esac; \
    curl --fail --show-error --location --retry 3 \
        "https://github.com/anycap-ai/anycap/releases/download/v0.6.4/anycap_0.6.4_linux_${TARGETARCH}.tar.gz" \
        --output /tmp/anycap.tar.gz; \
    printf '%s  /tmp/anycap.tar.gz\n' "$checksum" | sha256sum --check --strict; \
    tar -xzf /tmp/anycap.tar.gz -C /usr/local/bin anycap; \
    chmod 0755 /usr/local/bin/anycap; \
    rm /tmp/anycap.tar.gz; \
    anycap --version

# The daemon stays root; EIP sessions execute as sandbox (UID/GID 1000), as
# required by the a13n Modal provider. No desktop or browser packages are added.
RUN groupadd --gid 1000 sandbox \
    && useradd --uid 1000 --gid sandbox --create-home --shell /bin/bash sandbox \
    && install -d -o sandbox -g sandbox /workspace /tmp/a13n \
    && install -d -m 0700 /var/lib/a13n-envd /run/a13n-envd-state
COPY --from=envd /usr/local/bin/a13n-envd /usr/local/bin/a13n-envd
COPY --chmod=0755 runtime/a13n-sandbox-entrypoint runtime/a13n-sandbox-init /usr/local/bin/
COPY runtime/LICENSE.a13n /usr/share/licenses/a13n-envd/LICENSE
RUN a13n-envd --version

ENV A13N_ENVD_EXECUTION_UID=1000 \
    A13N_ENVD_EXECUTION_GID=1000 \
    A13N_ENVD_FULL_CONTROL=true \
    A13N_ENVD_STATE_DIR=/var/lib/a13n-envd \
    A13N_ENVD_RUNTIME_DIR=/run/a13n-envd-state

USER root
WORKDIR /workspace
ENTRYPOINT ["tini", "--", "a13n-sandbox-entrypoint"]
CMD ["/bin/bash"]
