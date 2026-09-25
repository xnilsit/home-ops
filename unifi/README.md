# UniFi Dream Machine Pro

The gateway is a UDM Pro at `192.168.0.1` running UniFi OS 5 (Debian 11). Almost everything is
set in the Network UI; this directory holds the few things that live on the box itself, plus
notes on what the UI settings actually put on the wire.

SSH as `root` with a key from `/root/.ssh/authorized_keys`, enabled under Console Settings → SSH.

## What survives what

The root filesystem is an overlay whose writable layer sits on `/dev/boot6`. Everything
written survives a reboot. A firmware update keeps only `/data`, and UniFi's own dpkg cache in
`/persistent` restores only UniFi's packages — anything installed with apt, and anything under
`/etc`, is gone afterwards.

## IPv6 router advertisements

UniFi's dnsmasq sends RA on `br0` with `constructor:br0,ra-only,64,86400`: every /64 on the
interface is advertised, on-link and autonomous. The LAN network's IPv6 settings are
`Interface Type: Prefix Delegation` with the ULA under **Additional IPs**, which puts
`fd2e:9a41:6b8c:1::/64` on `br0` (the UDM itself answers on `fd2e:9a41:6b8c:1::`).

Measured 2026-09-26 with tcpdump on `br0`:

| Field | Value |
| --- | --- |
| `2001:9e8:*::/64` (Telekom PD) | on-link, auto, valid 86400s, preferred 86400s |
| `fd2e:9a41:6b8c:1::/64` | on-link, auto, valid 86400s, preferred 86400s |
| Router | preference high, lifetime 1800s, MTU 1500 |
| RDNSS | `fd2e:9a41:6b8c:1::53`, lifetime 1800s |

The on-link ULA prefix is what makes the cluster's IPv6 service VIPs reachable:
`fd2e:9a41:6b8c:1::53` (blocky) and `fd2e:9a41:6b8c:1::150` (envoy-internal) are announced by
Cilium over NDP. Without a ULA source address from SLAAC, RFC 6724 source selection would not
pair a GUA source with those ULA destinations.

`kube-system/slaac-janitor` assumes a rotated-away Telekom prefix is simply dropped from RA,
never re-advertised with `preferred_lft 0`. That was measured on the previous USG; it has not
been re-checked against the UDM's dnsmasq.

## NTP server

UniFi OS only runs `systemd-timesyncd` as a client. `on_boot.d/10-chrony.sh` installs Debian's
chrony, which replaces timesyncd, and loads `chrony/chrony.conf`: PTB and Cloudflare upstreams
over NTS, serving udp/123 to the networks in its `allow` lines on `192.168.0.1` and
`fd2e:9a41:6b8c:1::`.

Containers are not an option here: the UDM kernel has no `CONFIG_USER_NS`, and bullseye's
podman 3.0.1 fails every start on the missing `/proc/self/uid_map`.

`udm-boot.service` is [unifi-common](https://github.com/unifi-utilities/unifi-common)'s unit at
`f3a02bec`: it runs every executable in `/data/on_boot.d` once per boot.

```sh
ssh root@192.168.0.1 'mkdir -p /data/on_boot.d /data/chrony'
scp chrony/chrony.conf root@192.168.0.1:/data/chrony/
scp on_boot.d/10-chrony.sh root@192.168.0.1:/data/on_boot.d/
scp udm-boot.service root@192.168.0.1:/etc/systemd/system/
ssh root@192.168.0.1 'chmod 755 /data/on_boot.d/10-chrony.sh && systemctl daemon-reload && systemctl enable --now udm-boot'
```

After a firmware update, repeat the `udm-boot.service` copy and the `systemctl` line; the
script reinstalls chrony by itself.

Check with `chronyc -N sources` and `chronyc -N authdata` on the UDM, or
`talosctl -n <node> time --check 192.168.0.1` from the cluster.

## Port forwards

Two WAN port-forwards, 80 and 443, both to `192.168.1.152` — the `envoy-external-direct`
Gateway. That is the ingress path for the hostnames the Cloudflare tunnel cannot carry, because
it caps request bodies at 100 MB. Port 80 exists only for the https redirect; cert-manager
solves DNS-01 and never needs it.

Everything else public still arrives through cloudflared, which is outbound-only and needs no
forward at all.

## Keep in sync

- The RDNSS server (`fd2e:9a41:6b8c:1::53`) is set in the Network UI. If the blocky VIP moves,
  change it there too.
- The `allow` lines in `chrony/chrony.conf` list the LAN and VLAN subnets by hand.
