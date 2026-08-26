# Garage on the Synology NAS

S3-compatible object storage at `192.168.0.200`, holding the CNPG backups that used to live in the
cluster's own Ceph RGW. Buckets, keys and permissions are **not** managed here — they are declared
in `kubernetes/apps/garage/` and applied by
[garage-operator](https://github.com/rajsinghtech/garage-operator) through Garage's Admin API.

| Port | What |
| ---- | ---- |
| 3900 | S3 API — barman writes here, also `s3.${SECRET_DOMAIN}` via envoy-internal |
| 3901 | RPC (cluster mesh; single node today) |
| 3903 | Admin API — the operator's only channel |

## First-time setup

1. On the NAS, create the directories:

   ```sh
   mkdir -p /volume1/docker/garage/meta /volume1/garage/data
   ```

2. Copy `garage.toml` and `docker-compose.yaml` to `/volume1/docker/garage/`.

3. Create `/volume1/docker/garage/.env` from `.env.example`. The values must match
   `kubernetes/apps/garage/garage/app/secret.sops.yaml` exactly — decrypt it with
   `sops -d` to read them rather than generating new ones.

4. Start it, either `docker compose up -d` in that directory or by importing the directory as a
   Container Manager project.

5. Apply a layout. **Garage stores nothing until this is done** — a node with no role silently
   rejects writes:

   ```sh
   docker exec garage /garage status                        # note the node id
   docker exec garage /garage layout assign -z nas -c 500GB <node-id>
   docker exec garage /garage layout apply --version 1
   docker exec garage /garage status                        # node now shows capacity
   ```

   `-c` is a byte size, suffixes `B KB MB GB TB PB` (decimal) or `KiB MiB GiB TiB` (binary) —
   a bare `2T` does not parse. It is the weight Garage spreads partitions by, not a quota: with
   one node every partition lands here whatever the number, and Garage keeps accepting writes
   past it until `/volume1` is actually full. Size it off what the backups weigh
   (`kubectl rook-ceph radosgw-admin bucket stats --bucket=cnpg-backup`) times roughly 3 for
   retention churn, and re-run `layout assign` plus `layout apply --version <n+1>` to change it.

6. Check the Admin API answers from a cluster node, which is what the operator needs:

   ```sh
   curl -sH "Authorization: Bearer $GARAGE_ADMIN_TOKEN" \
     http://192.168.0.200:3903/v2/GetClusterStatus | jq
   ```

## Day-to-day

```sh
docker exec garage /garage status              # node health and layout
docker exec garage /garage bucket list         # what the operator has created
docker exec garage /garage bucket info cnpg-backup
docker exec garage /garage stats               # object counts, disk usage
```

Do not create or delete buckets and keys by hand: the operator reconciles them from the
`GarageBucket` / `GarageKey` CRs and will undo the change.

## Upgrades

Renovate opens PRs against the `dxflrs/garage` tag in `docker-compose.yaml`. Bumping it here does
not deploy anything — pull the new tag on the NAS afterwards:

```sh
docker compose pull && docker compose up -d
```

Keep it at Garage 2.x: garage-operator's Admin API client targets v2.
