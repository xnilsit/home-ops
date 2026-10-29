#!/bin/sh
# NTP server for the LAN: Debian chrony with the config from /data/chrony.
set -eu

# Firmware updates drop apt-installed packages; only /data survives.
# Retries for up to 10 minutes, since udm-boot runs before PPPoE and DNS are up.
if ! command -v chronyd >/dev/null 2>&1; then
  tries=0
  until apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y chrony; do
    tries=$((tries + 1))
    [ "$tries" -lt 30 ] || exit 1
    sleep 20
  done
fi

# Hooks run `chronyc onoffline`, which finds no main-table default route and leaves sources offline.
rm -f /etc/ppp/ip-up.d/chrony /etc/ppp/ip-down.d/chrony \
  /etc/network/if-up.d/chrony /etc/network/if-post-down.d/chrony \
  /usr/lib/networkd-dispatcher/off.d/chrony-onoffline \
  /usr/lib/networkd-dispatcher/routable.d/chrony-onoffline \
  /usr/lib/NetworkManager/dispatcher.d/20-chrony-onoffline \
  /etc/dhcp/dhclient-exit-hooks.d/chrony

mkdir -p /data/chrony/nts
chown -R _chrony:_chrony /data/chrony
install -m 0644 /data/chrony/chrony.conf /etc/chrony/chrony.conf
systemctl restart chrony
