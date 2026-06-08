#!/bin/sh
# Polybar network indicator (event-driven tail script).
# Shows the active internet link: prefers wired, falls back to wireless.
#   default mode : <icon> <ip>
#   speed  mode  : <icon> 󰇚 <down>/s   󰕒 <up>/s
# Left-click flips the mode (via the `toggle` subcommand).
#
# Idle cost: instead of polling, the loop blocks in `inotifywait` on the mode
# file, so a click wakes it instantly (no CPU spent waiting). It only wakes on
# a timer to (a) refresh the byte-rate every 1s *while in speed mode*, and
# (b) re-check connectivity every 10s otherwise. So when you're showing the IP
# and not clicking, it does ~6 cheap wakes/minute — not 240.
# Icons: ethernet (wired), wifi (wireless), wifi-off (offline)

SECONDARY='#8ec07c'
DISABLED='#928374'
MODE_FILE=/tmp/polybar-net-mode   # "ip" (default) or "speed"

# click-left handler: flip mode and exit; the running loop wakes on the write.
if [ "$1" = toggle ]; then
    [ "$(cat "$MODE_FILE" 2>/dev/null)" = speed ] && echo ip > "$MODE_FILE" || echo speed > "$MODE_FILE"
    exit 0
fi

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

# Discover active interface (prefer wired, else wireless).
# Echoes "<iface> <icon>", or nothing when offline.
active_iface() {
    wired=""; wireless=""
    for path in /sys/class/net/*; do
        name=${path##*/}
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
    if   [ -n "$wired" ];    then echo "$wired 󰈀"
    elif [ -n "$wireless" ]; then echo "$wireless 󰖩"
    fi
}

emit() {  # print only when the line actually changed, so polybar redraws minimally
    [ "$1" != "$last_out" ] && { printf '%s\n' "$1"; last_out="$1"; }
}

last_out=""
last_rx=""; last_tx=""; last_t=0
down='   - KB/s'; up='   - KB/s'

[ -f "$MODE_FILE" ] || echo ip > "$MODE_FILE"

while :; do
    now=$(date +%s)
    set -- $(active_iface)
    active=$1; icon=$2
    read -r mode < "$MODE_FILE" 2>/dev/null || mode=ip

    if [ -z "$active" ]; then
        last_rx=""; last_tx=""; down='   - KB/s'; up='   - KB/s'
        emit "$(printf '%%{F%s}󰖪 offline%%{F-}' "$DISABLED")"
    else
        read -r rx < "/sys/class/net/$active/statistics/rx_bytes"
        read -r tx < "/sys/class/net/$active/statistics/tx_bytes"
        dt=$((now - last_t))
        if [ -n "$last_rx" ] && [ "$dt" -gt 0 ] && [ "$rx" -ge "$last_rx" ] && [ "$tx" -ge "$last_tx" ]; then
            down="$(human $(( (rx - last_rx) / dt )))/s"
            up="$(human $(( (tx - last_tx) / dt )))/s"
        fi
        last_rx=$rx; last_tx=$tx; last_t=$now

        if [ "$mode" = speed ]; then
            emit "$(printf '%%{F%s}%s 󰇚 %s   󰕒 %s%%{F-}' "$SECONDARY" "$icon" "$down" "$up")"
        else
            ip_addr=$(ip -4 -o addr show "$active" | awk '{print $4}' | cut -d/ -f1 | head -1)
            emit "$(printf '%%{F%s}%s %s%%{F-}' "$SECONDARY" "$icon" "$ip_addr")"
        fi
    fi

    # Block until the mode file is written (instant toggle) or a timer fires:
    # 1s while showing speed (to refresh the rate), 10s otherwise.
    [ "$mode" = speed ] && timeout=1 || timeout=10
    inotifywait -qq -t "$timeout" -e modify -e close_write "$MODE_FILE" 2>/dev/null
done
