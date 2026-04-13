#!/bin/sh
# Polybar VPN indicator
# Shows tailscale and wireguard independently. Green = up, grey = down.
# If nothing is up, shows a single grey "off".

GREEN='#8ec07c'
GREY='#928374'
YELLOW='#fabd2f'
FLAG=/tmp/polybar-vpn-loading

# Loading spinner during click-driven toggles
if [ -f "$FLAG" ]; then
    action=$(cat "$FLAG" 2>/dev/null)
    printf '%%{F%s}\uf250 %s…%%{F-}\n' "$YELLOW" "$action"
    exit 0
fi

# Detect tailscale
ts_up=0
if tailscale status >/dev/null 2>&1; then
    ts_up=1
fi

# Detect wireguard interfaces by iterating /etc/wireguard/*.conf and
# checking if an interface with that name exists in /sys/class/net
# (readable without root; `wg show interfaces` would need CAP_NET_ADMIN).
wg_names=""
if [ -d /etc/wireguard ] && [ -r /etc/wireguard ]; then
    for conf in /etc/wireguard/*.conf; do
        [ -e "$conf" ] || continue
        name=$(basename "$conf" .conf)
        if [ -d "/sys/class/net/$name" ]; then
            wg_names="${wg_names}${name} "
        fi
    done
fi

parts=""

if [ "$ts_up" = 1 ]; then
    parts="${parts}%{F${GREEN}}\uf023 ts%{F-}"
fi

if [ -n "$wg_names" ]; then
    for name in $wg_names; do
        [ -n "$parts" ] && parts="${parts} "
        parts="${parts}%{F${GREEN}}\uf023 ${name}%{F-}"
    done
fi

if [ -z "$parts" ]; then
    parts="%{F${GREY}}\uf023 off%{F-}"
fi

printf '%b\n' "$parts"
