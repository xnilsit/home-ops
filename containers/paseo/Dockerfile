# Paseo daemon with Claude Code and the CLIs agents need against home-ops.
# renovate: datasource=docker depName=ghcr.io/getpaseo/paseo
ARG BASE=ghcr.io/getpaseo/paseo:0.14.0@sha256:2a370238230689406d7123e44b218ede221fd77dd23200a18672ed03873682b0

# Neovim with its plugins, LSPs and parsers prebuilt, the final image has neither compilers nor a writable rootfs.
# Same base as the final stage: Mason's Python venvs link /usr/bin/python3.
FROM ${BASE} AS nvim

# renovate: datasource=github-releases depName=neovim/neovim
ARG NEOVIM_VERSION=v0.12.6

USER root

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends build-essential jq python3-venv ripgrep unzip xz-utils; \
    rm -rf /var/lib/apt/lists/*

# Neovim publishes no checksum file, GitHub records each asset's digest.
RUN set -eux; \
    cd /tmp; \
    nvim="nvim-linux-x86_64.tar.gz"; \
    curl -fsSLO "https://github.com/neovim/neovim/releases/download/${NEOVIM_VERSION}/${nvim}"; \
    digest="$(curl -fsSL "https://api.github.com/repos/neovim/neovim/releases/tags/${NEOVIM_VERSION}" | jq -r --arg name "${nvim}" '.assets[] | select(.name == $name) | .digest')"; \
    echo "${digest#sha256:}  ${nvim}" | sha256sum -c -; \
    tar -xzf "${nvim}" -C /opt; \
    ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim; \
    rm "${nvim}"

COPY rootfs/etc/xdg/nvim/ /etc/xdg/nvim/
COPY nvim-bake.lua /tmp/nvim-bake.lua

# Installs into /usr/local/share/nvim; the throwaway XDG dirs keep the user config out of the way.
RUN set -eux; \
    export HOME=/tmp/bake XDG_CONFIG_HOME=/tmp/bake/config XDG_DATA_HOME=/tmp/bake/data XDG_STATE_HOME=/tmp/bake/state XDG_CACHE_HOME=/tmp/bake/cache; \
    PASEO_NVIM_BAKE=1 nvim -u /etc/xdg/nvim/init.lua -l /tmp/nvim-bake.lua; \
    rm -rf /tmp/bake /tmp/nvim-bake.lua

FROM ${BASE}

# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.314
# renovate: datasource=github-releases depName=kubernetes/kubernetes
ARG KUBECTL_VERSION=v1.37.2
# renovate: datasource=github-releases depName=fluxcd/flux2
ARG FLUX_VERSION=v2.10.0
# renovate: datasource=github-releases depName=cli/cli
ARG GH_VERSION=v2.103.3
# renovate: datasource=github-releases depName=jdx/mise
ARG MISE_VERSION=v2026.10.24
# renovate: datasource=npm depName=@opencode/cli
ARG OPENCODE_VERSION=2.2.5
# renovate: datasource=npm depName=opencode-with-claude
ARG OPENCODE_WITH_CLAUDE_VERSION=1.11.2
# Drives both the Claude Code plugin (repo tag) and @eleboucher/opencode-memini-v2 (same version on npm).
# renovate: datasource=github-tags depName=eleboucher/memini
ARG MEMINI_VERSION=v0.7.37
# renovate: datasource=github-releases depName=helm/helm
ARG HELM_VERSION=v4.3.1
# renovate: datasource=git-refs depName=https://github.com/ohmyzsh/ohmyzsh branch=master
ARG OHMYZSH_COMMIT=17a2b4c3a5855524ad4772a17ada0dc474e2fdf3
# renovate: datasource=git-refs depName=https://github.com/djui/alias-tips branch=master
ARG ALIAS_TIPS_COMMIT=41cb143ccc3b8cc444bf20257276cb43275f65c4

USER root

# Archive formats mise unpacks for the home-ops toolchain, zsh for the terminals, python3 for alias-tips and Mason's venvs.
# agnoster draws its Powerline glyphs under LC_CTYPE=en_US.UTF-8, which the slim base does not ship.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends jq less locales python3 ripgrep unzip xz-utils zsh zstd; \
    rm -rf /var/lib/apt/lists/*; \
    sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen; \
    locale-gen

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
    helm="helm-${HELM_VERSION}-linux-amd64.tar.gz"; \
    curl -fsSLO "https://get.helm.sh/${helm}"; \
    curl -fsSL "https://get.helm.sh/${helm}.sha256sum" | sha256sum -c -; \
    tar -xzf "${helm}" --strip-components=1 -C /usr/local/bin linux-amd64/helm; \
    rm -rf /tmp/*

COPY --from=nvim /opt/nvim-linux-x86_64 /opt/nvim-linux-x86_64
# Owned by the paseo user so git, which lazy.nvim and blink.cmp run in the plugin dirs, does not flag them as dubious.
COPY --from=nvim --chown=1000:1000 /usr/local/share/nvim /usr/local/share/nvim
RUN ln -s /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim

# Paseo starts terminals with $SHELL, the login shell covers kubectl exec and the like.
# Without newuser zsh skips its setup menu, which every shell would hit as the zshrc lives in /etc/zsh rather than the home volume.
# tar as root keeps the archives' group-writable modes, which oh-my-zsh's compaudit rejects.
RUN set -eux; \
    mkdir -p /usr/share/oh-my-zsh/custom/plugins/alias-tips; \
    curl -fsSL "https://github.com/ohmyzsh/ohmyzsh/archive/${OHMYZSH_COMMIT}.tar.gz" \
        | tar -xzf - -C /usr/share/oh-my-zsh --strip-components=1; \
    curl -fsSL "https://github.com/djui/alias-tips/archive/${ALIAS_TIPS_COMMIT}.tar.gz" \
        | tar -xzf - -C /usr/share/oh-my-zsh/custom/plugins/alias-tips --strip-components=1; \
    chmod -R g-w,o-w /usr/share/oh-my-zsh; \
    rm -f /usr/share/zsh/*/scripts/newuser; \
    completions=/usr/local/share/zsh/site-functions; \
    mkdir -p "${completions}"; \
    kubectl completion zsh > "${completions}/_kubectl"; \
    flux completion zsh > "${completions}/_flux"; \
    helm completion zsh > "${completions}/_helm"; \
    usermod --shell /usr/bin/zsh paseo
ENV SHELL=/usr/bin/zsh

COPY rootfs/ /

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
    claude --version; opencode --version; kubectl version --client; flux version --client; gh --version; mise --version; helm version; zsh --version

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
