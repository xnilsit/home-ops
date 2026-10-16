#!/bin/bash
# Runs inside `transactional-update run`, so everything lands in the next snapshot
set -euxo pipefail
cd "$(dirname "$0")"

# Tumbleweed only ships containerd 1.7, which kubelet 1.36+ no longer supports
if ! zypper lr virt-containers >/dev/null 2>&1; then
  zypper --non-interactive addrepo --refresh --priority 90 \
    https://download.opensuse.org/repositories/Virtualization:/containers/openSUSE_Tumbleweed/ virt-containers
fi
zypper --non-interactive --gpg-auto-import-keys refresh
zypper --non-interactive install --allow-vendor-change \
  containerd cri-tools haproxy kubernetes1.37-kubelet

cp -r files/etc/. /etc/
chmod 600 /etc/containerd/conf.d/*.toml

grep -q 'registry.nilsit.de' /etc/hosts || echo '192.168.1.152 registry.nilsit.de' >> /etc/hosts

systemctl enable containerd.service haproxy.service
