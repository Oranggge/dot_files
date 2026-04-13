#!/bin/sh
# Polybar VPN menu — rofi picker listing tailscale + every wireguard config
# with current state. Selecting an entry toggles that VPN.

FLAG=/tmp/polybar-vpn-loading
WG_DIR=/etc/wireguard

# -------- build menu entries --------
entries=""

# Tailscale
if tailscale status >/dev/null 2>&1; then
    entries="${entries}  tailscale  [on]\n"
else
    entries="${entries}  tailscale  [off]\n"
fi

# Wireguard configs
if [ -d "$WG_DIR" ] && [ -r "$WG_DIR" ]; then
    for conf in "$WG_DIR"/*.conf; do
        [ -e "$conf" ] || continue
        name=$(basename "$conf" .conf)
        if ip -br link show "$name" 2>/dev/null | grep -q .; then
            entries="${entries}  wg ${name}  [on]\n"
        else
            entries="${entries}  wg ${name}  [off]\n"
        fi
    done
fi

# -------- show rofi menu --------
choice=$(printf "$entries" | rofi -dmenu -i -p "VPN" -theme gruvbox-dark -no-custom -format s)
[ -z "$choice" ] && exit 0

# -------- act on selection --------
# choice looks like "  tailscale  [on]" or "  wg aspang  [off]"
action_state=$(printf '%s' "$choice" | grep -oE '\[(on|off)\]$' | tr -d '[]')

case "$choice" in
    *tailscale*)
        if [ "$action_state" = "on" ]; then
            echo "tailscale down" > "$FLAG"
            tailscale down >/dev/null 2>&1
        else
            echo "tailscale up" > "$FLAG"
            tailscale up >/dev/null 2>&1
        fi
        ;;
    *"wg "*)
        name=$(printf '%s' "$choice" | sed -E 's/.*wg ([a-zA-Z0-9_-]+).*/\1/')
        if [ "$action_state" = "on" ]; then
            echo "wg ${name} down" > "$FLAG"
            sudo -n /usr/bin/systemctl stop "wg-quick@${name}.service" >/dev/null 2>&1
        else
            echo "wg ${name} up" > "$FLAG"
            sudo -n /usr/bin/systemctl start "wg-quick@${name}.service" >/dev/null 2>&1
        fi
        ;;
esac

rm -f "$FLAG"
