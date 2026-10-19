# vaultwarden

Standby of the production Vaultwarden in the rra-team cluster
(`git.nilsit.dev/rra.team/apps/vaultwarden`, Argo CD). `VAULTWARDEN_MODE` in
`kubernetes/flux/meta/settings/cluster-settings.yaml` decides which side serves
`bitwarden|bw|vaultwarden|vw.hoeller-en.de`.

| | `standby` (default) | `primary` |
|---|---|---|
| `vaultwarden-postgres` | CNPG replica cluster of rra-team's `vaultwarden-db`, following its B2 WAL archive (lag ≈ 5 min) | promoted, read-write |
| `vaultwarden` Deployment | 0 replicas, no route | 2 replicas, hoeller-en.de hostnames on `envoy-external` |
| `/data` PVC | `vaultwarden-pull` mirrors rra-team's `vaultwarden-data` RGW bucket every 5 min | pull suspended; live data |
| `bw.${SECRET_DOMAIN}` | read-only copy (LAN), refreshed every 3h | gone |
| DNS | rra-team's external-dns owns the A/AAAA records | `vaultwarden-dns-takeover` deletes them; `cloudflare-dns` publishes CNAMEs |

Both sides back up independently: rra-team to B2 (barman + volsync/restic),
home-ops to Garage (barman + kopiur). rra-team cannot reach Garage, so data
only flows from rra-team to home-ops on its own. Going back is the manual
procedure below.

Vaultwarden cannot run on a replica cluster: its startup migration check
issues `CREATE TABLE IF NOT EXISTS`, which a hot standby rejects. That is why
the read-only copy runs on its own scratch database.

## Switch to home-ops

Set up a shell for both clusters first:

```sh
krra() { kubectl --context rra-team -n vaultwarden "$@"; }
khome() { kubectl --kubeconfig ~/dev/private/home-ops/kubeconfig -n vaultwarden "$@"; }
```

### Planned (rra-team still up)

Nothing may be written on rra-team after step 1, or it is lost.

1. Stop Vaultwarden on rra-team: `controllers.main.replicas: 0` in the
   rra-team repo's `values.yaml`, push. A `kubectl scale` would be undone by
   Argo's self-heal.
2. Close the current WAL segment so it gets archived, and note the LSN:

   ```sh
   krra exec $(krra get pod -l cnpg.io/cluster=vaultwarden-db,cnpg.io/instanceRole=primary -o name) \
     -c postgres -- psql -Atc "select pg_switch_wal(), pg_current_wal_lsn()"
   ```

3. Wait until home-ops has replayed at least that LSN:

   ```sh
   khome exec $(khome get pod -l cnpg.io/cluster=vaultwarden-postgres,cnpg.io/instanceRole=primary -o name) \
     -c postgres -- psql -Atc "select pg_last_wal_replay_lsn()"
   ```

4. Wait for one more `vaultwarden-pull` run after step 1 (every 5 min, or
   `khome create job --from=cronjob/vaultwarden-pull pull-final`), so `/data`
   carries the last attachments.
5. Set `VAULTWARDEN_MODE: primary`, push to main. Flux applies it within
   seconds through the GitHub webhook.

### rra-team is down

Step 5 only. Writes from the last ≈ 5 minutes before the outage (WAL not yet
archived to B2) and attachments from the last ≈ 5 minutes (not yet pulled) are
lost.

### After the switch

- `khome get cluster vaultwarden-postgres` shows a primary, no longer a
  designated primary.
- `khome logs job/vaultwarden-dns-takeover` lists the deleted A/AAAA records.
  `dig bitwarden.hoeller-en.de` resolves to Cloudflare within a minute or two.
- Clients keep working unchanged: same hostnames, and the same `rsa_key.pem`,
  so existing sessions stay valid.
- If rra-team comes back while home-ops is primary, its Vaultwarden starts on
  its own outdated database. DNS stays here (Cloudflare refuses rra-team's
  A record next to the CNAME), but set `replicas: 0` on rra-team as soon as it
  is reachable, so no client that still resolves the old address writes there.

`VAULTWARDEN_PROMOTION_TOKEN` stays empty. A CNPG demotion token only helps
when the old primary can follow the new one afterwards, and rra-team cannot
read this cluster's Garage archive.

## Back to rra-team

rra-team cannot be re-cloned from here, so the database moves as a dump.

1. Freeze writes on home-ops. The HelmRelease has drift detection, so suspend
   it before scaling:

   ```sh
   flux --kubeconfig ~/dev/private/home-ops/kubeconfig -n vaultwarden suspend hr vaultwarden
   khome scale deploy vaultwarden --replicas 0
   ```

2. Make sure rra-team's Vaultwarden is at 0 replicas (see above).
3. Move the database:

   ```sh
   khome exec $(khome get pod -l cnpg.io/cluster=vaultwarden-postgres,cnpg.io/instanceRole=primary -o name) \
     -c postgres -- pg_dump -Fc -d vaultwarden > vaultwarden.dump
   krra exec -i $(krra get pod -l cnpg.io/cluster=vaultwarden-db,cnpg.io/instanceRole=primary -o name) \
     -c postgres -- pg_restore --clean --if-exists --no-owner --role=vaultwarden \
     --single-transaction -d vaultwarden < vaultwarden.dump
   ```

4. Move `/data` (attachments, `config.json`, `rsa_key.pem`) into rra-team's
   `vaultwarden-data` PVC, for example by streaming a tar between two pods
   that mount the PVCs (`vaultwarden` here, `vaultwarden-data` there).
5. Scale rra-team back up (`replicas: 2`), check login and an attachment.
6. Set `VAULTWARDEN_MODE: standby`, push, then `flux resume hr vaultwarden`.
   home-ops drops its route, `cloudflare-dns` deletes its CNAMEs, and
   rra-team's external-dns re-creates the A/AAAA records within a minute.
7. Re-clone the standby. The promoted `vaultwarden-postgres` is on its own
   timeline and cannot follow rra-team again. A new Cluster refuses to
   archive into a non-empty prefix, so empty its Garage archive first;
   rra-team holds the data and its backups by now.

   Through `s3.<SECRET_DOMAIN>` Envoy breaks the request signature
   (`signed header accept-encoding is not present`), so go through a
   port-forward:

   ```sh
   kubectl --kubeconfig ~/dev/private/home-ops/kubeconfig -n garage port-forward svc/garage 13900:3900 &
   export RCLONE_CONFIG_G_TYPE=s3 RCLONE_CONFIG_G_PROVIDER=Other \
     RCLONE_CONFIG_G_ENDPOINT=http://127.0.0.1:13900 RCLONE_CONFIG_G_REGION=eu-central-1 \
     RCLONE_CONFIG_G_ACCESS_KEY_ID=$(khome get secret vaultwarden-postgres-backup -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d) \
     RCLONE_CONFIG_G_SECRET_ACCESS_KEY=$(khome get secret vaultwarden-postgres-backup -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)
   rclone purge g:vaultwarden-postgres-backup/vaultwarden-postgres
   khome delete cluster vaultwarden-postgres
   flux --kubeconfig ~/dev/private/home-ops/kubeconfig reconcile ks vaultwarden -n flux-system
   ```

   The re-created Cluster restores from rra-team's B2 archive and follows it
   again; its PVCs go with the deleted Cluster.
