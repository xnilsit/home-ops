#!/bin/sh
# NTP server for the LAN: Debian chrony with the config from /data/chrony.
set -eu

# Firmware updates drop apt-installed packages; only /data survives.
if ! command -v chronyd >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y chrony
fi

mkdir -p /data/chrony/nts
chown -R _chrony:_chrony /data/chrony
install -m 0644 /data/chrony/chrony.conf /etc/chrony/chrony.conf
systemctl restart chrony
