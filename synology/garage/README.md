# Garage on the Synology NAS

S3-compatible object storage at `192.168.0.200`, holding the CNPG backups that used to live in the
cluster's own Ceph RGW. Buckets, keys and permissions are **not** managed here — they are declared
in `kubernetes/apps/garage/` and applied by
[garage-operator](https://github.com/rajsinghtech/garage-operator) through Garage's Admin API.

Cluster clients do not talk to the NAS directly. Two edge gateways run in the cluster
(`GarageCluster` `edge-a` and `edge-b`): Garage nodes with a capacity-less role that store nothing
and forward every request here over RPC. They are reached at
`garage.garage.svc.cluster.local:3900` in-cluster and `s3.${SECRET_DOMAIN}` /
`<bucket>.s3.${SECRET_DOMAIN}` on the LAN. Each advertises its own LAN address for RPC so this node
can dial it back:

| Gateway | RPC address |
| ------- | ----------- |
| edge-a  | `192.168.1.154:3901` |
| edge-b  | `192.168.1.155:3901` |

| Port | What |
| ---- | ---- |
| 3900 | S3 API — only the gateways and ad-hoc LAN tooling use it directly |
| 3901 | RPC — the gateways' link to this node, in both directions |
| 3903 | Admin API — the operator's only channel |

## First-time setup

1. On the NAS, create the directories:

   ```sh
   mkdir -p /volume1/docker/garage/meta /volume1/garage/data
   ```

2. doco-cd deploys `compose.yaml` with `garage.toml` from this directory (see
   `synology/README.md`). `secret.sops.env` holds the RPC secret and admin token, which must match
   `kubernetes/apps/garage/garage/app/secret.sops.yaml` byte for byte, or the operator cannot talk
   to Garage and derived GarageKeys break.

3. Apply a layout. **Garage stores nothing until this is done** — a node with no role silently
   rejects writes:

   ```sh
   docker exec garage /garage status                        # note the node id
   docker exec garage /garage layout assign -z nas -c 500GB <node-id>
   docker exec garage /garage layout apply --version 1
   docker exec garage /garage status                        # node now shows capacity
   ```

   This assigns the NAS's own role only. garage-operator adds and removes the gateways'
   capacity-less roles itself, committing further layout versions, so `garage layout show` lists
   versions this README never applied. Always apply `<current version + 1>`.

   `-c` is a byte size, suffixes `B KB MB GB TB PB` (decimal) or `KiB MiB GiB TiB` (binary) —
   a bare `2T` does not parse. It is the weight Garage spreads partitions by, not a quota: with
   one node every partition lands here whatever the number, and Garage keeps accepting writes
   past it until `/volume1` is actually full. Size it off what the backups weigh
   (`kubectl rook-ceph radosgw-admin bucket stats --bucket=cnpg-backup`) times roughly 3 for
   retention churn, and re-run `layout assign` plus `layout apply --version <n+1>` to change it.

4. Check the Admin API answers from a cluster node, which is what the operator needs:

   ```sh
   curl -sH "Authorization: Bearer $GARAGE_ADMIN_TOKEN" \
     http://192.168.0.200:3903/v2/GetClusterStatus | jq
   ```

## Day-to-day

`garage.${SECRET_DOMAIN}` (garage-ui, in the `garage` namespace, LAN-only behind envoy-internal)
shows the same cluster, bucket and key state in a browser, with an S3 object browser on top. It
holds the admin token, so it can read every S3 secret key Garage stores — hence its own authentik
login, restricted to the `home-ops` group, and no external route.

Nothing to set up in the UI: the endpoints, the region and the admin token come from
`kubernetes/apps/garage/garage-ui/app/helmrelease.yaml` and the `garage-credentials` Secret.
Cluster layout is not manageable from the browser — that is the CLI below.

```sh
docker exec garage /garage status              # node health and layout
docker exec garage /garage bucket list         # what the operator has created
docker exec garage /garage bucket info cnpg-backup
docker exec garage /garage stats               # object counts, disk usage
```

Do not create or delete buckets and keys by hand: the operator reconciles them from the
`GarageBucket` / `GarageKey` CRs and will undo the change.

## Upgrades

Renovate opens PRs against the `dxflrs/garage` tag in `compose.yaml` and, separately, in
`kubernetes/apps/garage/garage-gateway/app/gateway.yaml`. Keep the two on the same version. doco-cd
rolls the NAS container once the bump is merged.

Keep it at Garage 2.x: garage-operator's Admin API client targets v2.
