#!/bin/sh
# Publishes the WAN IPv4 address LiveKit has to advertise in its ICE
# candidates. LiveKit only learns it once, at startup, and the PPPoE session
# hands out a new one at least daily. Reloader restarts LiveKit when NODE_IP
# changes here.
#
# The source is home.$DOMAIN, which cloudflare-ddns keeps on the WAN address,
# asked of Cloudflare directly so no resolver cache sits in between.
while :; do
  ip=$(curl -fsS --max-time 10 -H 'accept: application/dns-json' \
    "https://cloudflare-dns.com/dns-query?name=home.$DOMAIN&type=A" \
    | jq -r '[.Answer[]? | select(.type == 1) | .data] | first // empty')

  if ! echo "$ip" | grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$'; then
    echo "no usable A record for home.$DOMAIN: '$ip'"
  else
    cur=$(kubectl get configmap livekit-node-ip -o jsonpath='{.data.NODE_IP}' 2>/dev/null)
    if [ "$ip" != "$cur" ]; then
      echo "NODE_IP $cur -> $ip"
      kubectl patch configmap livekit-node-ip --type=merge \
        -p '{"data":{"NODE_IP":"'"$ip"'"}}' || true
    fi
  fi
  sleep 60
done
