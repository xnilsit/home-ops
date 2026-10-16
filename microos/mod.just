set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

host := env('MICROOS_HOST', 'nilsit@192.168.1.112')

[private]
default:
    just microos -l

[doc('Install packages and node config into a new snapshot, then reboot')]
[group('microos')]
[script]
provision:
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    cp -r files install.sh "$tmp/"
    mkdir -p "$tmp/files/etc/containerd/conf.d"
    sops -d ../talos/patches/all/60-registry.sops.yaml \
        | yq 'select(.kind == "RegistryAuthConfig")
            | "[plugins.\"io.containerd.cri.v1.images\".registry.configs.\"" + .name + "\".auth]\n"
            + "  username = \"" + .username + "\"\n"
            + "  password = \"" + .password + "\""' \
        > "$tmp/files/etc/containerd/conf.d/registry-auth.toml"
    tar -C "$tmp" -cz . | ssh {{ host }} 'rm -rf /var/tmp/microos && mkdir -p /var/tmp/microos && tar -C /var/tmp/microos -xz'
    ssh {{ host }} 'sudo transactional-update --non-interactive run bash /var/tmp/microos/install.sh; rc=$?; rm -rf /var/tmp/microos; exit $rc'
    ssh {{ host }} 'sudo systemctl reboot' || true

[doc('Join the node to the cluster with the Talos bootstrap token')]
[group('microos')]
[script]
join:
    worker="$(yq '[.nodes[] | select(.role == "worker")][0].ip' ../talos/topf.yaml)"
    talosctl -n "$worker" cat /etc/kubernetes/pki/ca.crt \
        | ssh {{ host }} 'sudo install -D -m 644 /dev/stdin /etc/kubernetes/pki/ca.crt'
    talosctl -n "$worker" cat /etc/kubernetes/bootstrap-kubeconfig \
        | ssh {{ host }} 'sudo install -D -m 600 /dev/stdin /etc/kubernetes/bootstrap-kubeconfig'
    ssh {{ host }} 'sudo systemctl enable --now kubelet.service'
