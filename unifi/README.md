# UniFi gateway config override

`config.gateway.json` is a raw EdgeOS config fragment the UniFi controller merges into the
gateway's own config on every provision. It exists for settings the Network UI cannot express.

## Deploying

Copy it onto the controller, then force a provision:

```sh
scp config.gateway.json root@192.168.0.100:/usr/lib/unifi/data/sites/default/
```

Nothing happens until the gateway re-provisions — the controller only reads the file at
provision time. Trigger it from the UI (Devices → the gateway → Settings → Manage → Provision),
or by making any trivial config change.

If the gateway does not come back, the file is malformed: the controller silently keeps the last
good config and the settings here never appear. Check the merged result on the gateway with
`mca-ctrl -t dump-cfg` before assuming the fragment is wrong.

## What is in it, and why it cannot live in the UI

### `interfaces.ethernet.eth0.ipv6.router-advert.prefix`

Advertises `fd2e:9a41:6b8c:1::/64` on the LAN with the on-link and autonomous flags set, so
clients SLAAC an address in it and treat the whole /64 as directly reachable.

The Network UI's IPv6 settings for this network are `Interface Type: Prefix Delegation` with the
ULA entered under **Additional IPs**. That puts `fd2e:9a41:6b8c:1::1/64` on the gateway's own
interface but does **not** add the prefix to the router advertisements — verified on the wire,
where RA carried only the two delegated Telekom GUA prefixes. Without the on-link prefix, clients
learn the ULA DNS server from RDNSS but have no ULA source address, and RFC 6724 source-address
selection will not pair a GUA source with a ULA destination, so the queries never leave the host.

This is what makes the cluster's IPv6 service VIPs reachable —
`fd2e:9a41:6b8c:1::53` (blocky) and `fd2e:9a41:6b8c:1::150` (envoy-internal) are announced by
Cilium over NDP and must look on-link to LAN clients.

The lifetimes are the RFC 4861 defaults: 30 days valid, 7 days preferred.

### `interfaces.ethernet.eth0.address`

Both addresses must be restated here. The fragment replaces the interface's address list rather
than appending to it, so dropping `192.168.0.1/23` would take the LAN gateway offline.

### `system.ntp.server`

PTB's three stratum-1 servers plus Cloudflare, replacing UniFi's defaults. The `"''"` values are
how EdgeOS expresses an option with no sub-settings; they are not a placeholder to fill in.

## Keep in sync

The DNS server handed out in RA (`fd2e:9a41:6b8c:1::53`) is set in the Network UI, not here.
If the blocky VIP ever moves, both places need the change.
