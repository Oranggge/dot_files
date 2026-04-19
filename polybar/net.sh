#!/bin/sh
# Polybar network indicator
# Shows the active internet link: prefers wired, falls back to wireless.
# Output: <icon> <ip>  <down>/s  <up>/s
# Icons: ethernet (wired), wifi (wireless), wifi-off (offline)

SECONDARY='#8ec07c'
DISABLED='#928374'
STATE_FILE=/tmp/polybar-net-last

human() {
    b=$1
    if   [ "$b" -lt 1024 ];       then printf '%4d  B' "$b"
    elif [ "$b" -lt 1048576 ];    then printf '%4d KB' "$((b / 1024))"
    elif [ "$b" -lt 1073741824 ]; then
        whole=$((b / 1048576))
        frac=$(( (b % 1048576) * 10 / 1048576 ))
        printf '%2d.%d MB' "$whole" "$frac"
    else
        whole=$((b / 1073741824))
        frac=$(( (b % 1073741824) * 10 / 1073741824 ))
        printf '%2d.%d GB' "$whole" "$frac"
    fi
}

# Discover active interface: prefer wired, else wireless
wired=""
wireless=""
for path in /sys/class/net/*; do
    name=$(basename "$path")
    case "$name" in
        lo|docker*|br-*|veth*|tun*|tailscale*|vbox*|vmnet*|wg*|virbr*) continue ;;
    esac
    [ "$(cat "$path/operstate" 2>/dev/null)" = "up" ] || continue
    ip -4 addr show "$name" 2>/dev/null | grep -q 'inet ' || continue
    if [ -d "$path/wireless" ]; then
        [ -z "$wireless" ] && wireless="$name"
    else
        [ -z "$wired" ] && wired="$name"
    fi
done

if [ -n "$wired" ]; then
    active="$wired"
    icon="󰈀"
elif [ -n "$wireless" ]; then
    active="$wireless"
    icon="󰖩"
else
    printf '%%{F%s}󰖪 offline%%{F-}\n' "$DISABLED"
    rm -f "$STATE_FILE"
    exit 0
fi

ip_addr=$(ip -4 -o addr show "$active" | awk '{print $4}' | cut -d/ -f1 | head -1)
now=$(date +%s)
rx=$(cat "/sys/class/net/$active/statistics/rx_bytes")
tx=$(cat "/sys/class/net/$active/statistics/tx_bytes")

down='   - KB/s'
up='   - KB/s'

if [ -f "$STATE_FILE" ]; then
    read last_iface last_time last_rx last_tx < "$STATE_FILE"
    dt=$((now - last_time))
    if [ "$last_iface" = "$active" ] && [ "$dt" -gt 0 ] && [ "$rx" -ge "$last_rx" ] && [ "$tx" -ge "$last_tx" ]; then
        drx=$(( (rx - last_rx) / dt ))
        dtx=$(( (tx - last_tx) / dt ))
        down="$(human "$drx")/s"
        up="$(human "$dtx")/s"
    fi
fi

echo "$active $now $rx $tx" > "$STATE_FILE"

printf '%%{F%s}%s %s   󰇚 %s   󰕒 %s%%{F-}\n' "$SECONDARY" "$icon" "$ip_addr" "$down" "$up"
