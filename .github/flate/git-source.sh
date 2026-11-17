#!/usr/bin/env bash
# Points a checkout's Flux objects at this Git repository instead of the
# published OCI artifact. flate only renders a Git source from the working tree;
# an OCIRepository root leaves every Kustomization blocked. Idempotent.
set -euo pipefail

root="${1:?usage: git-source.sh <checkout>}"

grep -rlZ --include='*.yaml' 'kind: OCIRepository' "${root}/kubernetes" \
    | xargs -0 --no-run-if-empty perl -0pi -e \
        's/(sourceRef:\n\s+)kind: OCIRepository(\n\s+name: flux-system\n)/$1kind: GitRepository$2/g'

# Replaces the whole FluxInstance sync block, comments included.
perl -0pi -e '
    s{\n( +)sync:\n(?:\1  .*\n)+}{\n$1sync:\n$1  kind: GitRepository\n$1  url: "https://github.com/xnilsit/home-ops.git"\n$1  ref: "refs/heads/main"\n$1  path: kubernetes/flux/cluster\n}
' "${root}/kubernetes/apps/flux-system/flux-instance/app/helmrelease.yaml"
