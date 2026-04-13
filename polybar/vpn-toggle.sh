#!/bin/sh
# Polybar VPN toggle wrapper — shows a loading indicator during the action
# Usage: vpn-toggle.sh up | down

FLAG=/tmp/polybar-vpn-loading
ACTION="$1"

echo "$ACTION" > "$FLAG"
# Nudge polybar to re-poll the vpn module immediately so the spinner appears
polybar-msg action "#vpn.module_show" >/dev/null 2>&1 || true

case "$ACTION" in
    up)   tailscale up   >/dev/null 2>&1 ;;
    down) tailscale down >/dev/null 2>&1 ;;
esac

rm -f "$FLAG"
