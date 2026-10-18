# Garage on the Unraid server

Second storage node of the Garage cluster, at `192.168.0.250`, deployed by Unraid's doco-cd (see
`unraid/README.md`). With `replication_factor = 2` every block lives once on the NAS
(`synology/garage`) and once here, each node in its own zone. Buckets, keys and the edge gateways
are unchanged — see `synology/garage/README.md` for those.

With two copies and the default `consistent` mode a write needs both nodes. While either the NAS
or this box is down, reads keep working and writes fail.

| Port | What |
| ---- | ---- |
| 3900 | S3 API — unused, clients go through the edge gateways |
| 3901 | RPC — to the NAS and the gateways |
| 3903 | Admin API and `/metrics` |

## Paths

| On Unraid | In the container |
| --------- | ---------------- |
| `/mnt/cache/garage-meta` | `/var/lib/garage/meta` |
| `/mnt/user/garage` | `/var/lib/garage/data` |

`garage-meta` holds the sqlite database. It is a cache-only share on the `cache` pool, mounted by its
pool path: exclusive shares are off, so `/mnt/user/garage-meta` would go through shfs (FUSE), which
sqlite's WAL does not cope with well. Data blocks are fine on `/mnt/user`.

## Joining the cluster

Needs doco-cd running on both the NAS and Unraid first.

Changing `replication_factor` is only possible by rebuilding the layout from scratch, with every
node stopped. S3 is unavailable from step 2 to step 7; CNPG WAL archiving, kopiur and the other
clients retry until it is back.

1. On Unraid, create the shares `garage-meta` (cache-only on `cache`, see above) and `garage`.

2. Take the gateways down and drop their identities. Their metadata PVCs hold only the node key and
   table copies, no blocks:

   ```sh
   flux suspend ks garage-gateway -n flux-system
   kubectl -n garage delete garagecluster edge-a edge-b
   kubectl -n garage delete pvc metadata-edge-a-gateway-0 metadata-edge-b-gateway-0
   ```

3. On the NAS, keep doco-cd out of the way, snapshot and back up the metadata, then stop Garage and
   delete its layout:

   ```sh
   docker stop $(docker ps -aq -f label=com.docker.compose.service=doco-cd)
   docker exec garage /garage meta snapshot
   docker stop garage
   cp -a /volume1/docker/garage/meta /volume1/docker/garage/meta.rf1
   rm /volume1/docker/garage/meta/cluster_layout
   ```

4. Merge the PR that switches the NAS, this node and the gateways to `replication_factor = 2`. Then
   make both doco-cds poll right away; the NAS recreates Garage with the new config and Unraid
   starts it for the first time, dialling the NAS through `bootstrap_peers`:

   ```sh
   docker start $(docker ps -aq -f label=com.docker.compose.service=doco-cd)      # NAS
   docker restart $(docker ps -aq -f label=com.docker.compose.service=doco-cd)    # Unraid
   docker exec garage /garage status   # either node: both listed, no roles yet
   ```

5. Assign both storage roles and apply a fresh layout. With two copies and two zones each node
   holds everything, so usable capacity is the smaller of the two `-c` values:

   ```sh
   docker exec garage /garage layout assign -z nas -c 4TB 6f5f585f1a30d045
   docker exec garage /garage layout assign -z unraid -c 4TB <unraid-node-id>
   docker exec garage /garage layout apply --version 1
   ```

6. Bring the gateways back. The operator recreates them with new identities and adds their
   capacity-less roles:

   ```sh
   flux resume ks garage-gateway -n flux-system
   kubectl -n garage get garagecluster
   ```

7. Check on the NAS that all four nodes are up and in the layout. The operator's
   `GatewayConnected` condition can read True while the NAS cannot dial a gateway back:

   ```sh
   docker exec garage /garage status
   ```

8. Let Unraid copy every block from the NAS. Follow `block_resync_queue_length` on
   `instance=unraid` and `docker exec garage /garage worker list`. If the queue stays empty but
   `garage stats` shows far fewer blocks here than on the NAS:

   ```sh
   docker exec garage /garage repair --all-nodes --yes tables
   docker exec garage /garage repair --all-nodes --yes blocks
   ```

Once the resync is done and backups have run, delete `meta.rf1` on the NAS.

## Upgrades

Renovate bumps the tag in `compose.yaml` together with the NAS and the gateways (the `garage`
group), and doco-cd rolls the container once that is merged.
