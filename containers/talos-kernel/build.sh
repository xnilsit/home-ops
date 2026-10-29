#!/usr/bin/env bash
# Build Talos installers carrying a custom Linux kernel, without forking siderolabs.
# Adapted from https://github.com/Tanguille/cluster (scripts/talos-kernel-build.sh, MIT).
#
# Why: Ceph v21 (umbrella) silently drops writes from the 6.18 kernel CephFS client that
# Talos 1.14 ships; 7.2.x writes correctly. See README.md.
#
# Inputs are all derived from the tree: the Talos version from talos/topf.yaml, the kernel from
# the ARG in containers/talos-kernel/Dockerfile, the toolchain and kernel-config pins from the
# Talos release's own Makefile, and the schematics from the nodes in talos/topf.yaml.
#
# Publishes one installer per schematic: ghcr.io/xnilsit/talos-installer/<schematic>:<version>
# with <version> = v<talos>-k<kernel>.
set -euo pipefail

REGISTRY="${REGISTRY:-ghcr.io}"
USERNAME="${USERNAME:-xnilsit}"
PREFIX="${REGISTRY}/${USERNAME}"
REPO_ROOT="$(git rev-parse --show-toplevel)"
TOPF="${REPO_ROOT}/talos/topf.yaml"
CTX="${REPO_ROOT}/containers/talos-kernel"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

# Extensions that ship kernel modules. They copy signed .ko files out of the kernel package,
# the kernel generates a fresh signing key per build and module.sig_enforce=1 rejects any
# other, so they must be rebuilt from THIS kernel build, every time. Everything else in the
# schematics (ucode, firmware, userspace) is reused from upstream by digest.
KMOD_EXTENSIONS=(amdgpu i915 mei)

TALOS_VERSION="$(yq -r '.talosVersion' "${TOPF}")"
KERNEL_VERSION="$(sed -nE 's/^ARG KERNEL_VERSION=(.*)$/\1/p' "${CTX}/Dockerfile")"
VERSION="${TALOS_VERSION}-k${KERNEL_VERSION}"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

# GHCR intermittently answers DENIED to the first manifest push into a package that is being
# created by that same push; the identical retry succeeds.
retry() {
    local n
    for n in 1 2 3; do
        "$@" && return 0
        echo "    attempt ${n} failed: $*" >&2
        sleep $((n * 5))
    done
    return 1
}

# Schematic files in use, by short name: talos/schematic-intel.yaml -> intel.
mapfile -t SCHEMATICS < <(yq -r '.nodes[].schematicId' "${TOPF}" | sed -E 's/^@schematic-(.*)\.yaml$/\1/' | sort -u)
((${#SCHEMATICS[@]})) || {
    echo "no schematics found in ${TOPF}" >&2
    exit 1
}
installer_ref() { echo "${PREFIX}/talos-installer/$1:${VERSION}"; }

# Tags in talos-installer/* are never reused: one tag is one build. A rerun is a no-op.
missing=0
for s in "${SCHEMATICS[@]}"; do
    ref="$(installer_ref "${s}")"
    if crane manifest "${ref}" >/dev/null 2>&1; then
        echo "    exists: ${ref}"
    else
        echo "    missing: ${ref}"
        missing=1
    fi
done
if ((missing == 0)); then
    log "every installer for ${VERSION} is already published, nothing to build"
    exit 0
fi

log "talos ${TALOS_VERSION} + linux ${KERNEL_VERSION} -> ${VERSION}"
git clone -q --depth 1 --branch "${TALOS_VERSION}" https://github.com/siderolabs/talos.git "${WORK}/talos"
TOOLS_REV="$(sed -nE 's/^TOOLS \?= (.*)$/\1/p' "${WORK}/talos/Makefile")"
PKGS_REV="$(sed -nE 's/^PKGS \?= (.*)$/\1/p' "${WORK}/talos/Makefile")"
PKGS_SHA="${PKGS_REV##*-g}"
[[ "${PKGS_SHA}" =~ ^[0-9a-f]{7,40}$ ]] || {
    echo "PKGS pin '${PKGS_REV}' did not yield a sha (got '${PKGS_SHA}')" >&2
    exit 1
}
echo "    derived TOOLS=${TOOLS_REV} PKGS=${PKGS_REV}"

# Every stage (kernel, extensions, talos) runs on one docker-container builder: the default
# docker driver cannot export a registry cache.
export BUILDX_BUILDER="${BUILDX_BUILDER:-talos-kernel}"
docker buildx inspect "${BUILDX_BUILDER}" >/dev/null 2>&1 ||
    docker buildx create --name "${BUILDX_BUILDER}" --driver docker-container --bootstrap >/dev/null

log "kernel package"
cache_from=(--cache-from "type=registry,ref=${PREFIX}/kernel:buildcache")
# A workstation build can seed from a local cache dir (KERNEL_LOCAL_CACHE) to skip the compile.
[[ -n "${KERNEL_LOCAL_CACHE:-}" ]] && cache_from+=(--cache-from "type=local,src=${KERNEL_LOCAL_CACHE}")
docker buildx build \
    --build-arg "KERNEL_VERSION=${KERNEL_VERSION}" \
    --build-arg "TOOLS_REV=${TOOLS_REV}" \
    --build-arg "PKGS_SHA=${PKGS_SHA}" \
    "${cache_from[@]}" \
    --cache-to "type=registry,ref=${PREFIX}/kernel:buildcache,mode=min" \
    -t "${PREFIX}/kernel:${VERSION}" --push "${CTX}"

# amdgpu and i915 want kernel and linux-firmware at the same prefix and tag. Firmware is
# kernel-independent, so mirror upstream's blobs rather than rebuilding them.
log "linux-firmware (mirrored, not rebuilt)"
retry crane copy "ghcr.io/siderolabs/linux-firmware:${PKGS_REV}" "${PREFIX}/linux-firmware:${VERSION}"

# Only the module extensions some schematic actually uses.
WANTED_EXT=()
for e in "${KMOD_EXTENSIONS[@]}"; do
    for s in "${SCHEMATICS[@]}"; do
        if yq -e ".customization.systemExtensions.officialExtensions[] | select(. == \"siderolabs/${e}\")" \
            "${REPO_ROOT}/talos/schematic-${s}.yaml" >/dev/null 2>&1; then
            WANTED_EXT+=("${e}")
            break
        fi
    done
done

log "module extensions: ${WANTED_EXT[*]:-none}"
git clone -q --depth 1 --branch "${TALOS_VERSION}" https://github.com/siderolabs/extensions.git "${WORK}/extensions"
declare -A EXT_REF=()
if ((${#WANTED_EXT[@]})); then
    make -C "${WORK}/extensions" "${WANTED_EXT[@]}" PUSH=true PLATFORM=linux/amd64 \
        REGISTRY="${REGISTRY}" USERNAME="${USERNAME}" \
        PKGS_PREFIX="${PREFIX}" PKGS="${VERSION}"
    # Pin by digest from the build metadata: the extensions pick their own tags (mei is just
    # v<talos>), which the next rebuild against a different kernel build would overwrite.
    for e in "${WANTED_EXT[@]}"; do
        meta="${WORK}/extensions/_out/${e}.metadata.json"
        name="$(jq -r '."image.name"' "${meta}" | cut -d, -f1)"
        digest="$(jq -r '."containerimage.digest"' "${meta}")"
        [[ "${name}" == "${PREFIX}/${e}:"* && "${digest}" == sha256:* ]] || {
            echo "unexpected build metadata for ${e}: ${name} ${digest}" >&2
            exit 1
        }
        EXT_REF["${e}"]="${name}@${digest}"
        echo "    ${EXT_REF[${e}]}"
    done
fi

# The talos Dockerfile installs every module in hack/modules-amd64.txt by exact path and the
# 1.14 build fails on any `depmod --errsyms` output, so reconcile the list against what this
# kernel produced: rewrite moved paths, drop vanished modules, close over modules.dep.
log "reconciling module allowlist"
KIMG="${PREFIX}/kernel:${VERSION}"
MODS="$(crane export "${KIMG}" - | tar -tf - | sed -n 's|^usr/lib/modules/[^/]*/||p')"
DEPS="$(crane export "${KIMG}" - | tar -xO --wildcards 'usr/lib/modules/*/modules.dep')"
LIST="${WORK}/talos/hack/modules-amd64.txt"

while IFS= read -r entry; do
    [[ -n "${entry}" ]] || continue
    if grep -qxF "${entry}" <<<"${MODS}"; then
        printf '%s\n' "${entry}"
    elif hits="$(grep -F "/${entry##*/}" <<<"${MODS}")" && [[ "${hits}" != *$'\n'* ]]; then
        echo "    MOVED   ${entry} -> ${hits}" >&2
        printf '%s\n' "${hits}"
    else
        echo "    DROPPED ${entry}" >&2
    fi
done <"${LIST}" >"${LIST}.stage1"

declare -A DEPOF=() WANT=()
while IFS= read -r line; do
    [[ "${line}" == *:* ]] || continue
    DEPOF["${line%%:*}"]="${line#*:}"
done <<<"${DEPS}"
queue=()
while IFS= read -r e; do [[ -n "${e}" ]] && queue+=("${e}"); done <"${LIST}.stage1"
while ((${#queue[@]})); do
    e="${queue[-1]}"
    unset 'queue[-1]'
    [[ -n "${WANT[${e}]:-}" ]] && continue
    WANT["${e}"]=1
    for d in ${DEPOF[${e}]:-}; do
        [[ -n "${WANT[${d}]:-}" ]] || queue+=("${d}")
    done
done
cp "${LIST}.stage1" "${LIST}"
for m in "${!WANT[@]}"; do
    grep -qxF "${m}" "${LIST}.stage1" && continue
    echo "    ADDED   ${m} (dependency)" >&2
    printf '%s\n' "${m}" >>"${LIST}"
done
rm -f "${LIST}.stage1"

# Committed so talos' `git describe --dirty` does not stamp "-dirty" into the version.
if ! git -C "${WORK}/talos" diff --quiet -- hack/modules-amd64.txt; then
    git -C "${WORK}/talos" -c user.email=noreply@local -c user.name=build \
        commit -qam "reconcile module list for ${KERNEL_VERSION}"
else
    echo "    module list unchanged"
fi

# TAG is what the node reports as its Talos version, and what tuppr compares against its
# target, so the kernel has to be part of it for a kernel-only bump to be visible at all.
log "installer-base + imager"
make -C "${WORK}/talos" installer-base imager PUSH=true PLATFORM=linux/amd64 \
    INSTALLER_ARCH=targetarch TAG="${VERSION}" \
    REGISTRY="${REGISTRY}" USERNAME="${USERNAME}" \
    PKG_KERNEL="${PREFIX}/kernel:${VERSION}"

DIGESTS="$(crane export "ghcr.io/siderolabs/extensions:${TALOS_VERSION}" - | tar -xO image-digests)"
# Pre-created so it is owned by us, not by the root docker creates bind-mount targets as.
mkdir -p "${WORK}/out"
PUBLISHED=()
for s in "${SCHEMATICS[@]}"; do
    schematic="${REPO_ROOT}/talos/schematic-${s}.yaml"
    dst="$(installer_ref "${s}")"
    if crane manifest "${dst}" >/dev/null 2>&1; then
        log "installer ${s}: already published"
        continue
    fi
    log "installer ${s}"
    # Assignments, not process substitution, so a failing yq aborts under set -e instead of
    # silently producing an installer without extensions.
    kargs="$(yq -r '.customization.extraKernelArgs // [] | .[] | "--extra-kernel-arg=" + .' "${schematic}")"
    exts="$(yq -r '.customization.systemExtensions.officialExtensions[]' "${schematic}")"
    [[ -n "${exts}" ]] || {
        echo "no extensions in ${schematic}" >&2
        exit 1
    }
    args=()
    [[ -n "${kargs}" ]] && mapfile -t args <<<"${kargs}"
    while read -r ext; do
        short="${ext#siderolabs/}"
        if [[ -n "${EXT_REF[${short}]:-}" ]]; then
            args+=(--system-extension-image "${EXT_REF[${short}]}")
        else
            digest="$(grep -m1 -F "ghcr.io/${ext}:" <<<"${DIGESTS}")"
            args+=(--system-extension-image "${digest}")
        fi
    done <<<"${exts}"
    rm -f "${WORK}/out/installer-amd64.tar"
    docker run --rm -v "${WORK}/out:/out" \
        -v "${HOME}/.docker:/dockercfg:ro" -e DOCKER_CONFIG=/dockercfg \
        "${PREFIX}/imager:${VERSION}" installer \
        --arch amd64 --base-installer-image "${PREFIX}/installer-base:${VERSION}" "${args[@]}"
    retry crane push "${WORK}/out/installer-amd64.tar" "${dst}"
    PUBLISHED+=("${dst}")
done

{
    echo "### Talos custom kernel"
    echo "Linux \`${KERNEL_VERSION}\` on Talos \`${TALOS_VERSION}\`"
    echo
    for ref in "${PUBLISHED[@]}"; do echo "- \`${ref}\`"; done
} >>"${GITHUB_STEP_SUMMARY:-/dev/stdout}"
