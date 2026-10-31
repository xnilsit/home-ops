# Garage on syn1621

Third storage node of the Garage cluster, on the syn1621 Synology at `192.168.0.216`, deployed by its
doco-cd (see `syn1621/README.md`). The cluster keeps `replication_factor = 2`: every block lives on
two of the three storage nodes (the NAS, Unraid and this one), each in its own zone. Buckets, keys
and the edge gateways are unchanged; see `synology/garage/README.md` for those.

A third node adds capacity, not availability. With two copies and the default `consistent` mode a
write needs both nodes holding that partition, so while any one storage node is down, reads keep
working and most writes fail.

| Port | What |
| ---- | ---- |
| 3900 | S3 API, unused: clients go through the edge gateways |
| 3901 | RPC, to the other storage nodes and the gateways |
| 3903 | Admin API and `/metrics` |

## Paths

| On the NAS | In the container |
| ---------- | ---------------- |
| `/volume1/docker/garage/meta` | `/var/lib/garage/meta` |
| `/volume1/garage/data` | `/var/lib/garage/data` |

## Joining the cluster

Adding a node at the same replication factor is an ordinary layout change: no downtime and no
rebuild. Garage moves a share of the partitions here and the NAS and Unraid drop their copies once
this node holds them.

1. On the NAS, create the directories:

   ```sh
   mkdir -p /volume1/docker/garage/meta /volume1/garage/data
   ```

2. Bootstrap doco-cd (see `syn1621/README.md`). It starts Garage, which dials the NAS through
   `bootstrap_peers` and learns the rest of the cluster from it. `secret.sops.env` holds the same
   RPC secret and admin token as the other nodes. Garage rejects peers with a different RPC secret.

3. Check that the node is connected and has no role yet:

   ```sh
   docker exec garage /garage status
   ```

4. Give it a storage role, preview the new layout and apply it as `<current version + 1>`.
   garage-operator commits layout versions for the gateways too, so read the current one from
   `layout show` instead of guessing:

   ```sh
   docker exec garage /garage layout assign -z syn1621 -c 4TB <syn1621-node-id>
   docker exec garage /garage layout show       # staged changes, partition moves, new version
   docker exec garage /garage layout apply --version <n+1>
   ```

   With two copies over three zones, `-c` now matters: Garage spreads partitions by it, and each
   partition lands in two different zones. Usable capacity is about the smaller of half the total
   and the total minus the largest node. Set `-c` close to each node's real free space; re-run
   `layout assign` for the NAS or Unraid if their values need adjusting in the same version.

5. Follow the rebalance: `block_resync_queue_length` on `instance=syn1621` in the Garage dashboard,
   or `docker exec garage /garage worker list`. Once the queue drains on all three nodes,
   `docker exec garage /garage stats` on each shows its share of the blocks.

## Upgrades

Renovate bumps the tag in `compose.yaml` together with the other storage nodes and the gateways
(the `garage` group), and doco-cd rolls the container once that is merged.
