#!/bin/sh
# Pins the global speed limits in qBittorrent.conf to UP_LIMIT_KIB and
# DL_LIMIT_KIB (KiB/s).
set -eu
conf=/config/qBittorrent/qBittorrent.conf
if [ ! -f "$conf" ]; then
    mkdir -p "${conf%/*}"
    cp /defaults/qBittorrent.conf "$conf"
fi
grep -q '^\[BitTorrent\]$' "$conf" || printf '\n[BitTorrent]\n' >> "$conf"
pin() {
    sed -i "/^Session\\\\$1=/d" "$conf"
    sed -i "s/^\[BitTorrent\]\$/&\nSession\\\\$1=$2/" "$conf"
}
pin GlobalUPSpeedLimit "$UP_LIMIT_KIB"
pin GlobalDLSpeedLimit "$DL_LIMIT_KIB"
