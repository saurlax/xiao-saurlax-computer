# syntax=docker/dockerfile:1
FROM node:24-bookworm-slim AS node

FROM python:3.13-slim-bookworm

LABEL org.opencontainers.image.title="xiao-saurlax-computer" \
      org.opencontainers.image.description="A compact Debian toolbox with Python, Node.js, and AnyCap" \
      org.opencontainers.image.source="https://github.com/saurlax/xiao-saurlax-computer"

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    ANYCAP_NO_UPDATE=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash bash-completion ca-certificates curl dnsutils fd-find file git \
        iproute2 iputils-ping jq less nano netcat-openbsd openssh-client procps \
        ripgrep sqlite3 tini tree unzip vim-tiny wget xz-utils zip zsh \
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

WORKDIR /workspace
CMD ["/bin/bash"]
