#!/bin/sh
# NTP server for the LAN: Debian chrony with the config from /data/chrony.
set -eu

# Firmware updates drop apt-installed packages; only /data survives.
if ! command -v chronyd >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y chrony
fi

# Hooks run `chronyc onoffline`, which finds no main-table default route and leaves sources offline.
rm -f /etc/ppp/ip-up.d/chrony /etc/ppp/ip-down.d/chrony \
  /etc/network/if-up.d/chrony /etc/network/if-post-down.d/chrony

mkdir -p /data/chrony/nts
chown -R _chrony:_chrony /data/chrony
install -m 0644 /data/chrony/chrony.conf /etc/chrony/chrony.conf
systemctl restart chrony
