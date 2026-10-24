# Paseo daemon with Claude Code and the CLIs agents need against home-ops.
# renovate: datasource=docker depName=ghcr.io/getpaseo/paseo
ARG BASE=ghcr.io/getpaseo/paseo:0.13.0@sha256:9832cb6bcc904bb7fd6c0b22f1880cde38b592a26ecd38ba66c7fcc76fa0d43e

FROM ${BASE}

# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.310
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.1
# renovate: datasource=github-releases depName=fluxcd/flux2
ARG FLUX_VERSION=v2.9.6
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=v2.103.2
# renovate: datasource=github-releases depName=jdx/mise
ARG MISE_VERSION=v2026.10.18

USER root

# Archive formats mise unpacks for the home-ops toolchain.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends jq less ripgrep unzip xz-utils zstd; \
    rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    cd /tmp; \
    curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    echo "$(curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256")  kubectl" | sha256sum -c -; \
    install -m 0755 kubectl /usr/local/bin/kubectl; \
    flux="flux_${FLUX_VERSION#v}_linux_amd64.tar.gz"; \
    curl -fsSLO "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/${flux}"; \
    curl -fsSL "https://github.com/fluxcd/flux2/releases/download/${FLUX_VERSION}/flux_${FLUX_VERSION#v}_checksums.txt" | grep " ${flux}\$" | sha256sum -c -; \
    tar -xzf "${flux}" -C /usr/local/bin flux; \
    gh="gh_${GH_VERSION#v}_linux_amd64"; \
    curl -fsSLO "https://github.com/cli/cli/releases/download/${GH_VERSION}/${gh}.tar.gz"; \
    curl -fsSL "https://github.com/cli/cli/releases/download/${GH_VERSION}/gh_${GH_VERSION#v}_checksums.txt" | grep " ${gh}.tar.gz\$" | sha256sum -c -; \
    tar -xzf "${gh}.tar.gz" --strip-components=2 -C /usr/local/bin "${gh}/bin/gh"; \
    mise="mise-${MISE_VERSION}-linux-x64"; \
    curl -fsSLO "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/${mise}"; \
    curl -fsSL "https://github.com/jdx/mise/releases/download/${MISE_VERSION}/SHASUMS256.txt" | grep " \./${mise}\$" | sed 's# \./# #' | sha256sum -c -; \
    install -m 0755 "${mise}" /usr/local/bin/mise; \
    rm -rf /tmp/*

# Agent shells are non-interactive, so mise is reached through its shims rather than `mise activate`.
ENV MISE_DATA_DIR=/home/paseo/.cache/mise
ENV PATH="${MISE_DATA_DIR}/shims:${PATH}"

RUN set -eux; \
    npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}"; \
    npm cache clean --force; \
    claude --version; kubectl version --client; flux version --client; gh --version; mise --version
