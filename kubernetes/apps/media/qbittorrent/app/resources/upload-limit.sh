#!/bin/sh
# Pins the global upload limit in qBittorrent.conf to UP_LIMIT_KIB (KiB/s).
set -eu
conf=/config/qBittorrent/qBittorrent.conf
if [ ! -f "$conf" ]; then
    mkdir -p "${conf%/*}"
    cp /defaults/qBittorrent.conf "$conf"
fi
sed -i '/^Session\\GlobalUPSpeedLimit=/d' "$conf"
grep -q '^\[BitTorrent\]$' "$conf" || printf '\n[BitTorrent]\n' >> "$conf"
sed -i "s/^\[BitTorrent\]\$/&\nSession\\\\GlobalUPSpeedLimit=${UP_LIMIT_KIB}/" "$conf"
