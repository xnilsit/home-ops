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
ARG MISE_VERSION=v2026.10.19
# renovate: datasource=npm depName=@opencode/cli
ARG OPENCODE_VERSION=2.1.4
# renovate: datasource=npm depName=opencode-with-claude
ARG OPENCODE_WITH_CLAUDE_VERSION=1.11.2
# Drives both the Claude Code plugin (repo tag) and @eleboucher/opencode-memini-v2 (same version on npm).
# renovate: datasource=github-tags depName=eleboucher/memini
ARG MEMINI_VERSION=v0.7.37

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
    npm install -g \
        "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
        "@opencode/cli@${OPENCODE_VERSION}" \
        "opencode-with-claude@${OPENCODE_WITH_CLAUDE_VERSION}" \
        "@eleboucher/opencode-memini-v2@${MEMINI_VERSION#v}"; \
    npm cache clean --force; \
    claude --version; opencode --version; kubectl version --client; flux version --client; gh --version; mise --version

# OpenCode 2 loads a plugin directory through its own index.js or server.js, ignoring package.json main/exports.
RUN set -eux; \
    modules="$(npm root -g)"; \
    mkdir -p /opt/opencode-plugins/opencode-with-claude /opt/opencode-plugins/memini; \
    echo "export { default } from \"${modules}/opencode-with-claude/dist/index.js\";" > /opt/opencode-plugins/opencode-with-claude/index.js; \
    echo "export { default } from \"${modules}/@eleboucher/opencode-memini-v2/dist/index.js\";" > /opt/opencode-plugins/memini/index.js

# Meridian (behind opencode-with-claude) refuses to start without a machine-id, which gVisor does not provide.
RUN od -An -tx1 -N16 /dev/urandom | tr -d ' \n' > /etc/machine-id

# Paseo merges its bridge plugin into this, and opencode-with-claude points the placeholder baseURL at its Meridian port.
ENV OPENCODE_CONFIG_CONTENT='{"plugins":["/opt/opencode-plugins/opencode-with-claude","/opt/opencode-plugins/memini"],"providers":{"anthropic":{"settings":{"baseURL":"http://127.0.0.1:3456/v1","apiKey":"dummy"}}}}'
# The npm installs are read-only, plugins included.
ENV OPENCODE_DISABLE_AUTOUPDATE=1
ENV MEMINI_AUTO_UPDATE=false

# Claude Code loads directory-marketplace plugins in place, so they live outside the ~/.claude volume.
RUN set -eux; \
    mkdir -p /opt/claude-plugins/memini /etc/claude-code/managed-settings.d; \
    curl -fsSL "https://github.com/eleboucher/memini/archive/refs/tags/${MEMINI_VERSION}.tar.gz" \
        | tar -xzf - -C /opt/claude-plugins/memini --strip-components=1 \
            "memini-${MEMINI_VERSION#v}/.claude-plugin" "memini-${MEMINI_VERSION#v}/plugin"; \
    printf '%s\n' '{"extraKnownMarketplaces":{"memini":{"source":{"source":"directory","path":"/opt/claude-plugins/memini"}}},"enabledPlugins":{"memini@memini":true}}' \
        > /etc/claude-code/managed-settings.d/10-memini.json; \
    claude plugin validate /opt/claude-plugins/memini
