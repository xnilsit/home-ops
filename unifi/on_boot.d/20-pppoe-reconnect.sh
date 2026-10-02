#!/bin/sh
# Daily PPPoE reconnect at 04:00, resetting Telekom's 24h forced disconnect.
set -eu

echo '0 4 * * * root /usr/bin/pkill -HUP -x pppd' > /etc/cron.d/pppoe-reconnect
