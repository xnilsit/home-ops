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
interface. Without an on-link ULA prefix in RA, clients learn the ULA DNS server from RDNSS but
have no ULA source address, and RFC 6724 source-address selection will not pair a GUA source with
a ULA destination, so the queries never leave the host.

This is what makes the cluster's IPv6 service VIPs reachable —
`fd2e:9a41:6b8c:1::53` (blocky) and `fd2e:9a41:6b8c:1::150` (envoy-internal) are announced by
Cilium over NDP and must look on-link to LAN clients.

The lifetimes here are the RFC 4861 defaults: 30 days valid, 7 days preferred.

#### This stanza may now be redundant — verify before relying on it

It was added because **Additional IPs** did not put the ULA into RA, "verified on the wire, where
RA carried only the two delegated Telekom GUA prefixes". That is no longer what the wire shows.
Re-measured 2026-09-09 with `rdisc6 -1 enp1s0f0` from a host-network pod, the RA carries:

| Prefix | Valid | Preferred | Source |
| --- | --- | --- | --- |
| one `2001:9e8:*::/64` | 86400 | 14400 | Telekom PD |
| `fd2e:9a41:6b8c:1::/64` | 86400 | 14400 | UniFi, i.e. **Additional IPs now does advertise it** |
| `fd2e:9a41:6b8c:1::/64` | 2592000 | 604800 | this fragment |

So the ULA is advertised **twice, with conflicting lifetimes**, and only **one** Telekom prefix is
delegated now rather than two. Nothing is broken — the kernel keeps the longer pair, and nodes show
`valid_lft 2591630` — but the justification above no longer holds. Do not delete the stanza on the
strength of this note alone: confirm on the wire first, since a UniFi upgrade could revert the
behaviour and dropping it would then silently break every ULA VIP on the LAN.

Router lifetime is 1800s, which is how long a client keeps the default route without a further RA.

#### Rotated-away Telekom prefixes are not re-advertised

Also measured, and load-bearing for `kube-system/slaac-janitor`: when the delegated prefix rotates,
the previous one simply stops appearing in RA. It is never re-advertised with `preferred_lft 0`, so
nodes deprecate the old address and count its `valid_lft` down from 86400 — up to 24h during which
a stale, no-longer-routed GUA is still present on the interface. Deleting such an address is
therefore permanent; no RA puts it back. That is what the janitor relies on.

### `interfaces.ethernet.eth0.address`

Both addresses must be restated here. The fragment replaces the interface's address list rather
than appending to it, so dropping `192.168.0.1/23` would take the LAN gateway offline.

### `system.ntp.server`

PTB's three stratum-1 servers plus Cloudflare, replacing UniFi's defaults. The `"''"` values are
how EdgeOS expresses an option with no sub-settings; they are not a placeholder to fill in.

## Set in the Network UI, not here

Two WAN port-forwards, 80 and 443, both to `192.168.1.152` — the
`envoy-external-direct` Gateway. That is the ingress path for the hostnames the
Cloudflare tunnel cannot carry, because it caps request bodies at 100 MB. Port
80 exists only for the https redirect; cert-manager solves DNS-01 and never
needs it.

Everything else public still arrives through cloudflared, which is outbound-only
and needs no forward at all.

## Keep in sync

The DNS server handed out in RA (`fd2e:9a41:6b8c:1::53`) is set in the Network UI, not here.
If the blocky VIP ever moves, both places need the change.
