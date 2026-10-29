# Talos custom kernel

Builds Talos installers that carry a newer Linux kernel than Talos ships. Adapted from
[Tanguille/cluster](https://github.com/Tanguille/cluster/tree/main/docker/talos-kernel)
(MIT); their README has the long-form reasoning behind each step.

## Why

Talos 1.14 ships Linux 6.18. After the upgrade to Ceph v21.2.0 (umbrella), the 6.18 kernel
CephFS client **silently loses writes**: `write()`/`fsync()` succeed, but the data never
reaches RADOS, so every other client reads zeros. The MDS never grants the 6.18 client a
writable range (the inode's `client_ranges` stays empty). Linux 7.2.11 and ceph-fuse write
correctly against the same cluster. RBD, librados and RGW are unaffected.

No Talos release ships 7.x yet, so this builds one.

## Pipeline

```text
containers/talos-kernel/Dockerfile  ->  ghcr.io/xnilsit/kernel:<version>
ghcr.io/siderolabs/linux-firmware   ->  ghcr.io/xnilsit/linux-firmware:<version>   (mirrored)
siderolabs/extensions @ <talos>     ->  ghcr.io/xnilsit/{amdgpu,i915,mei}           (rebuilt)
siderolabs/talos @ <talos>          ->  ghcr.io/xnilsit/{installer-base,imager}:<version>
imager installer                    ->  ghcr.io/xnilsit/talos-installer/<schematic>:<version>
```

`<version>` is `v<talos>-k<kernel>`, e.g. `v1.14.5-k7.2.13`. It is also what the node reports
as its Talos version, which is what tuppr compares against its target.

- **Kernel**: kernel.org tarball (verified against Greg Kroah-Hartman's key), Talos's kernel
  config from the `siderolabs/pkgs` commit the Talos release pins, built with Sidero's own
  toolchain images. `olddefconfig` fills in new options. Notably, 7.x switches
  `PREEMPT_NONE` to `PREEMPT`.
- **amdgpu, i915, mei** ship kernel modules, signed with a key the kernel build generates
  fresh each time (`module.sig_enforce=1`). They are rebuilt from the same kernel build every
  time and pinned by digest. All other extensions are reused from upstream by digest.
- **Module allowlist**: `hack/modules-amd64.txt` is reconciled against the built kernel
  (moved and dropped modules, closed over `modules.dep`), since Talos 1.14 fails the build on
  any dangling module.

One installer per schematic (`intel`, `amd`, `um790`), matching `talos/schematic-*.yaml`.

## Build

```sh
just talos kernel-build
```

Needs `docker login ghcr.io` with `write:packages`, about 40 GB of disk, and a while: the
ThinLTO kernel link is the long, memory-heavy part.

New GHCR packages start **private**. Nodes pull without credentials, so each
`talos-installer/<schematic>` package must be made public once (GitHub → Packages → package
settings). The intermediates can stay private.

## Rollout

The first move off Image Factory is manual, one node at a time:

```sh
talosctl -n <ip> upgrade --image ghcr.io/xnilsit/talos-installer/<schematic>:<version> \
    --reboot-mode powercycle
```

Wait for the node to be `Ready` with its Cilium pod up, and for Ceph to be `HEALTH_OK`,
before moving to the next one. Afterwards each node's `machine.install.image` must point at
its `talos-installer/<schematic>` repo, and the tuppr CR at `<version>`. Otherwise the next
Talos bump silently reinstalls the stock kernel from Image Factory.
