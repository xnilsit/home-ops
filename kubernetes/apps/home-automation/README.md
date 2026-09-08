# home-automation

Home Assistant, Zigbee2MQTT and Mosquitto, migrated out of a Home Assistant OS
VM at `192.168.1.30`. This file is the migration runbook; delete it once the VM
is gone and the stack is boring.

## What the VM was running

HA `2026.8.1` under Supervisor `2026.08.0`, with the Mosquitto broker,
Zigbee2MQTT, Matter Server, ESPHome Device Builder and Advanced SSH add-ons
installed. 54 config entries, 111 devices, 2094 entities.

Three things about that inventory decided the scope:

- **`zha` is `source: ignore`** — a *dismissed discovery* for a Sonoff USB
  dongle, with 0 devices and 0 entities. There is no ZHA network, so no USB
  passthrough is needed anywhere. The same is true of `apple_tv` (×5), `hue`,
  `sonos`, `nuki`, `webostv`, `powerfox`, `homekit_controller` and three of the
  four `synology_dsm` entries.
- **`matter` and `thread` have 0 devices.** The Matter Server add-on was running
  with nothing commissioned, so it is not migrated. Add
  `python-matter-server` the day something needs it.
- **ESPHome** has no config entries at all — the add-on was only ever the
  firmware builder. Not migrated.

## The Zigbee coordinator is on the network, not on USB

SMLIGHT **SLZB-MR1U** at `192.168.1.22`, SLZB OS `v3.3.1`, `coordMode: 1`, two
radios on two TCP ports:

| chip | radio | port | baud | used by |
|---|---|---|---|---|
| 0 | EFR32MG21 (`ember`) | 6638 | 460800 | nothing |
| 1 | CC2652P7 (`zstack`) | 7638 | 115200 | **this network** |

`socket.useMultiClients` is `false` — **one TCP client at a time**. The add-on
must be stopped before the new Zigbee2MQTT connects, and the new one must be
stopped before any rollback. A half-open session survives a stopped add-on; if
the pod logs a refused connection, reboot the SLZB from its web UI.

## MQTT credentials

- **`homeassistant`** is byte-identical to the password the add-on issued
  (verified against the add-on's `/data/system_user.json`, which matches what HA
  stores in `.storage/core.config_entries`). Keeping it means HA's MQTT config
  entry needs only its `broker` host changed — no new `entry_id`, so every
  MQTT-discovered device and entity keeps its identity.
- **`zigbee2mqtt`** is new. The add-on authenticated as the HA *user* `mqtt`
  with the password `mqtt` through the Supervisor auth plugin, which does not
  exist here. Zigbee2MQTT reads its credential from the environment, which
  overrides its own `configuration.yaml`, so this one was free to be replaced.

Both live in `mosquitto/app/secret.sops.yaml` as plaintext `user:password` lines
and are hashed in place at startup by the `passwd-hash` initContainer.

## Runbook

Phase 1 ships with `replicas: 0` on `home-assistant` and `zigbee2mqtt` and
`suspend: true` on both SnapshotPolicies. Everything up to step 4 is reversible
in seconds.

### 1. Snapshot the VM

On the Proxmox host at `192.168.1.5`. This is the rollback.

### 2. Land phase 1 and check what came up

```sh
just kube test && just kube diff
# merge, then
just kube reconcile
kubectl -n home-automation get pvc,restore,snapshotpolicy,pods
kubectl -n database get database,databaserole home-assistant
```

Both kopiur PVCs must reach `Bound` — empty, via the populator's
`onMissingSnapshot: Continue`. Both SnapshotPolicies must show suspended.
Mosquitto must be `Running`; prove it before touching the VM:

```sh
kubectl -n home-automation exec deploy/mosquitto -- \
  mosquitto_pub -h localhost -u homeassistant -P "$P" -t test/ping -m ok
# and that anonymous is refused
kubectl -n home-automation exec deploy/mosquitto -- \
  mosquitto_pub -h localhost -t test/ping -m nope
```

### 3. Stop the old stack, in this order

In the HA UI: **stop the Zigbee2MQTT add-on** (releases `192.168.1.22:7638`),
then the Mosquitto add-on, then

```sh
ssh nilsit@192.168.1.30 'sudo ha core stop'
```

`ha core stop` rather than a poweroff: a clean shutdown checkpoints and removes
the SQLite WAL. Confirm `/homeassistant/home-assistant_v2.db-wal` is gone or
zero-length before copying.

### 4. Extract

```sh
ssh nilsit@192.168.1.30 "sudo tar -C /homeassistant -cf - \
  --exclude=./home-assistant_v2.db --exclude=./home-assistant_v2.db-wal \
  --exclude=./home-assistant_v2.db-shm \
  --exclude=./home-assistant.log --exclude=./home-assistant.log.1 \
  --exclude=./home-assistant.log.old --exclude=./home-assistant.log.fault \
  --exclude=./backups --exclude=./deps --exclude=./tts --exclude=./.cache \
  --exclude=./.ha_run.lock ." > ha-config.tar

ssh nilsit@192.168.1.30 'sudo tar -C /homeassistant/zigbee2mqtt -cf - .' > z2m-data.tar
```

The recorder database is deliberately left behind — see *History* below.
`deps/` is HA's legacy pre-venv dependency directory, built against the VM's
interpreter, and is superseded by `/config/.venv`.

Everything the migration needs is reachable this way. The add-on's own `/data`
directories are not visible from the SSH add-on, but nothing in them is needed:
Zigbee2MQTT keeps its data in `/homeassistant/zigbee2mqtt`, and Mosquitto's
`/data` holds only retained messages and the two system-user passwords, both
already accounted for. (The docker socket *is* reachable via `sudo` from the SSH
add-on if that ever changes.)

### 5. Edit, then seed

Unpack locally and edit before anything touches a PVC.

`.storage/core.config_entries`:

- `mqtt` entry: `data.broker` → `mosquitto.home-automation.svc.cluster.local`.
  Leave `port`, `username` and `password` alone.
- delete the `hassio` entry — there is no Supervisor. HA prunes the orphaned
  registry rows itself on the first start; expect a few "removed orphaned
  entity" lines and do not mistake them for data loss.
- delete the `matter` entry (`use_addon: true`, 0 devices) and the `thread` entry.

`configuration.yaml`:

- add `10.42.0.0/16` and `fd2e:9a41:6b8c:4200::/56` to `http.trusted_proxies`.
  It currently lists `192.168.0.0/23`, which was right when Envoy reached the VM
  over the LAN and is wrong now that Envoy reaches a pod. HA **refuses to start**
  if `use_x_forwarded_for` is true and `trusted_proxies` is empty.
- add the recorder, which reads the env var the HelmRelease sets:

  ```yaml
  recorder:
    db_url: !env_var HA_RECORDER_DB_URL
  ```

`zigbee2mqtt/configuration.yaml`: delete `frontend.host`. It was set for the
Supervisor Ingress and cannot be cleared from the environment, because an empty
`ZIGBEE2MQTT_CONFIG_*` is falsy and skipped. Everything else in the file is
either overridden by the HelmRelease or must be left exactly as it is — the
`advanced.network_key`, `pan_id`, `ext_pan_id` and `devices:` block are what
keep every device paired.

Then seed. Both claims are RWO and both workloads are at 0 replicas, so one pod
can mount both. `PodSecurity` admission is disabled cluster-wide
(`talos/patches/controller/cluster.yaml`), so a root pod needs no namespace label.

```sh
kubectl -n home-automation apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata: {name: seed}
spec:
  restartPolicy: Never
  securityContext: {runAsUser: 0}
  containers:
    - name: seed
      image: mirror.gcr.io/library/busybox:latest
      command: ["sh", "-c", "sleep 86400"]
      volumeMounts:
        - {name: ha, mountPath: /ha}
        - {name: z2m, mountPath: /z2m}
  volumes:
    - {name: ha, persistentVolumeClaim: {claimName: home-assistant}}
    - {name: z2m, persistentVolumeClaim: {claimName: zigbee2mqtt}}
EOF

kubectl -n home-automation wait pod/seed --for=condition=Ready --timeout=5m
kubectl -n home-automation exec -i seed -- tar -C /ha  -xf - < ha-config.tar
kubectl -n home-automation exec -i seed -- tar -C /z2m -xf - < z2m-data.tar
# The VM's files are uid 0; both workloads and both kopiur movers are 1000.
kubectl -n home-automation exec seed -- chown -R 1000:1000 /ha /z2m
kubectl -n home-automation exec seed -- find /ha /z2m ! -user 1000   # must be empty
kubectl -n home-automation delete pod seed
```

### 6. Power the VM off

Not optional, and it comes before the pods start: the VM still holds
`192.168.1.30`, and the macvlan attachment claims that address statically. Also
disable autostart, so a later reboot cannot bring up a second Zigbee2MQTT
contending for the SLZB and a second HA publishing to the same discovery topics.
**Do not delete the disk** — keep it for at least two `keepDaily` cycles.

Free `192.168.1.30` in the UniFi DHCP pool while you are there.

### 7. Cutover — one commit

- `replicas: 0` → `1` on both controllers
- drop `suspend: true` from both SnapshotPolicy patches
- delete the `home-assistant` `Backend` and `HTTPRoute` from
  `kubernetes/apps/network/external-services/app/{backends,httproutes}.yaml`

All in the same commit. external-dns runs `policy: sync`, so as long as
`ha.${SECRET_DOMAIN}` is claimed by *some* HTTPRoute on `envoy-external` at
every observation, the Cloudflare record is never deleted and recreated. Flux
applies a Kustomization in one pass, so the window is sub-second. Splitting it
across two commits is what would drop the record.

Watch Zigbee2MQTT first:

```sh
kubectl -n home-automation logs -f deploy/zigbee2mqtt
```

`guard-data: ok`, then the coordinator handshake, then a `pan_id`/`ext_pan_id`
matching the old add-on's. **A log line about generating a network key means
stop immediately** — the guard should have prevented it, and continuing unpairs
the house.

Then HA. The first start builds `/config/.venv` and pip-installs each HACS
component's requirements, so give the startup probe its full 15 minutes.

### 8. Verify

```sh
# The LAN attachment
kubectl -n home-automation exec deploy/home-assistant -- ip -4 addr show net1
# From a LAN host
curl -sI http://192.168.1.30:8123/ | head -1
avahi-browse -rt _home-assistant._tcp

# Zigbee: the device count must match the old add-on's exactly
kubectl -n home-automation exec deploy/mosquitto -- \
  mosquitto_sub -h localhost -u homeassistant -P "$P" -t 'zigbee2mqtt/bridge/devices' -C 1 \
  | jq 'map(select(.type != "Coordinator")) | length'

# HA
curl -sH "Authorization: Bearer $T" https://ha.${SECRET_DOMAIN}/api/config \
  | jq '{version, state, mqtt: (.components|index("mqtt")!=null),
         hassio: (.components|index("hassio")!=null)}'
curl -sH "Authorization: Bearer $T" https://ha.${SECRET_DOMAIN}/api/states | jq length
curl -sH "Authorization: Bearer $T" https://ha.${SECRET_DOMAIN}/api/error_log | tail -200
```

Expect `state: RUNNING`, `mqtt: true`, **`hassio: false`**, 16 MQTT devices, and
an entity count close to the 2094 the VM had (the `hassio` platform's 57 go away
with the Supervisor).

Then force the first backup and confirm it landed, in the kopia UI at
`kopia.${SECRET_DOMAIN}`, before declaring success:

```sh
kubectl -n home-automation get snapshots.kopiur.home-operations.com -w
```

Until that is true, the only copy of the Zigbee database is one Ceph RBD image.

### Rollback

Revert the cutover commit, scale **zigbee2mqtt to 0 first** and confirm the pod
is gone (the SLZB takes one client), then power the VM back on and start
Mosquitto → Zigbee2MQTT → `ha core start`. The VM's `.storage` and recorder are
exactly as they were at `ha core stop`, so a rollback loses only whatever the
new HA recorded after cutover.

## Things worth knowing afterwards

**History.** The recorder moved to `pg-shared`, and HA has no supported
SQLite-to-Postgres migration, so the pre-cutover history and long-term
statistics are gone. Everything users think of as configuration — registries,
automations, dashboards, areas, HACS — lives in `.storage` and did carry over.
The VM's 329 MB `home-assistant_v2.db` is still on the kept disk image if that
turns out to matter.

**`configuration.yaml` lives on the PVC**, deliberately, for the first
deployment: a ConfigMap mount shadows the volume, so a transcription that
dropped one `!include` would fail silently. Once the file is known good it
should move into `configMaps:` and be mounted read-only, the way blocky mounts
`config.yml`.

**macvlan cannot reach its own host.** The HA pod cannot talk to the node it
runs on at `192.168.1.10x`. Nothing it integrates with is a cluster node, and
kubelet probes are unaffected (Cilium routes host-to-pod traffic through
`cilium_host`, so they arrive from `10.42.x.x`). It is still the first thing to
check if something on the LAN turns out to be unreachable.

**Talos upgrades** re-create the `/opt` overlay, so after each node upgrade a
macvlan pod cannot start until the Multus DaemonSet has reinstalled the plugin
binaries. Not an outage, but it makes node upgrades noisier.

**Renovate** cannot follow the Multus or CNI-plugins tags (a `-thick` suffix and
a build date), so both are bumped by hand, like `squat/generic-device-plugin`.

**`cloudflared` caps request bodies at 100 MB**, so HA's Backup integration
upload/download through `ha.${SECRET_DOMAIN}` fails above that. Use
`http://192.168.1.30:8123` on the LAN, or add a second route on
`envoy-external-direct` with `gatus.home-operations.com/enabled: "false"`.

**Follow-ups**, each its own PR: move `configuration.yaml` into a ConfigMap; pin
`network_key`/`pan_id`/`ext_pan_id` in SOPS as a third guard against an empty
volume (only after diffing them against the seeded file — a wrong value silently
forms a different network); bump HA off `2026.8.1`.
