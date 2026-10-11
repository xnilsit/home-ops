# home-ops

![Talos](https://kromgo.nilsit.de/badges/talos_version)
![Kubernetes](https://kromgo.nilsit.de/badges/kubernetes_version)
![Nodes](https://kromgo.nilsit.de/badges/nodes)
![Uptime](https://kromgo.nilsit.de/badges/uptime)
![Pods](https://kromgo.nilsit.de/badges/pods)

GitOps repository for my home Kubernetes cluster, reconciled by Flux.

## Cluster

Four-node [Talos](https://www.talos.dev) cluster: three control-plane nodes that also run workloads, with the API served behind a shared VIP, plus one dedicated worker. Networking is Cilium, ingress is Envoy Gateway, exposure to the internet goes through a Cloudflare tunnel.

**Cluster resources**

![CPU](https://kromgo.nilsit.de/badges/cpu_cores)
![CPU usage](https://kromgo.nilsit.de/badges/cpu_usage)

![Memory](https://kromgo.nilsit.de/badges/memory_capacity)
![Memory usage](https://kromgo.nilsit.de/badges/memory_usage)

### Storage

![Node storage](https://kromgo.nilsit.de/badges/node_storage_capacity)
![Node storage usage](https://kromgo.nilsit.de/badges/node_storage_usage)

![Ceph](https://kromgo.nilsit.de/badges/ceph_capacity)
![Ceph usage](https://kromgo.nilsit.de/badges/ceph_usage)
![Ceph health](https://kromgo.nilsit.de/badges/ceph_health)

The control-plane nodes share the same storage layout:

- **SD card/USB stick**: Talos system disk
- **960 GB NVMe** (Samsung PM983): `/var`, for container images, logs and ephemeral volumes
- **1 TB NVMe** (WD Black SN770): `local-path` volumes for workloads that replicate themselves, such as CloudNativePG Postgres clusters
- **1.92 TB SSD**: Ceph OSD, managed by Rook. Block, filesystem and object pools are all 3× replicated, so usable capacity is about a third of the raw figure above.

The worker `kube-wrk-01` has no Ceph OSD:

- **USB stick**: Talos system disk
- **2× 2 TB NVMe** (Kingston KC3000) in a RAID1 mirror: 300 GiB `/var`, the rest `local-path`

### Networking

Every node has a single link, 10 GbE on the control-plane nodes and 2.5 GbE on the worker, which carries pod traffic and Ceph replication alike. The network is dual-stack (IPv4 and IPv6). Cilium replaces kube-proxy, routes pod traffic natively without an overlay, and announces LoadBalancer IPs over L2.

### Nodes

| Node | Hardware | CPU / RAM | Ceph OSD | Status | CPU | Memory | Disk | Ceph | Uptime |
|---|---|---|---|---|---|---|---|---|---|
| `kube-srv-01` | Intel Core i3-N305 | 8 threads / 32 GB | 1.92 TB SATA SSD | ![](https://kromgo.nilsit.de/badges/kube-srv-01_status) | ![](https://kromgo.nilsit.de/badges/kube-srv-01_cpu) | ![](https://kromgo.nilsit.de/badges/kube-srv-01_memory) | ![](https://kromgo.nilsit.de/badges/kube-srv-01_storage) | ![](https://kromgo.nilsit.de/badges/kube-srv-01_ceph) | ![](https://kromgo.nilsit.de/badges/kube-srv-01_uptime) |
| `kube-srv-02` | Minisforum MS-A2, AMD Ryzen 7 7745HX | 16 threads / 64 GB | 1.92 TB NVMe | ![](https://kromgo.nilsit.de/badges/kube-srv-02_status) | ![](https://kromgo.nilsit.de/badges/kube-srv-02_cpu) | ![](https://kromgo.nilsit.de/badges/kube-srv-02_memory) | ![](https://kromgo.nilsit.de/badges/kube-srv-02_storage) | ![](https://kromgo.nilsit.de/badges/kube-srv-02_ceph) | ![](https://kromgo.nilsit.de/badges/kube-srv-02_uptime) |
| `kube-srv-03` | Intel Core i3-N305 | 8 threads / 32 GB | 1.92 TB SATA SSD | ![](https://kromgo.nilsit.de/badges/kube-srv-03_status) | ![](https://kromgo.nilsit.de/badges/kube-srv-03_cpu) | ![](https://kromgo.nilsit.de/badges/kube-srv-03_memory) | ![](https://kromgo.nilsit.de/badges/kube-srv-03_storage) | ![](https://kromgo.nilsit.de/badges/kube-srv-03_ceph) | ![](https://kromgo.nilsit.de/badges/kube-srv-03_uptime) |
| `kube-wrk-01` | Minisforum UM790 Pro, AMD Ryzen 9 7940HS | 16 threads / 32 GB | – | ![](https://kromgo.nilsit.de/badges/kube-wrk-01_status) | ![](https://kromgo.nilsit.de/badges/kube-wrk-01_cpu) | ![](https://kromgo.nilsit.de/badges/kube-wrk-01_memory) | ![](https://kromgo.nilsit.de/badges/kube-wrk-01_storage) | – | ![](https://kromgo.nilsit.de/badges/kube-wrk-01_uptime) |

Disk is `/var` plus `local-path` combined. Badges are served by [kromgo](https://github.com/home-operations/kromgo) from the cluster's VictoriaMetrics.
