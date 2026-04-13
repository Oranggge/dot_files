#!/bin/sh
# Polybar VPN indicator: tailscale > wireguard > off
# Colors: gruvbox secondary (green) when up, disabled (grey) when off

GREEN='#8ec07c'
GREY='#928374'
YELLOW='#fabd2f'
FLAG=/tmp/polybar-vpn-loading

if [ -f "$FLAG" ]; then
    action=$(cat "$FLAG" 2>/dev/null)
    printf '%%{F%s}\uf250 %s…%%{F-}\n' "$YELLOW" "$action"
elif tailscale status >/dev/null 2>&1; then
    printf '%%{F%s}\uf023 ts%%{F-}\n' "$GREEN"
elif ip -br link show 2>/dev/null | grep -qE '^wg[0-9]+.*UP'; then
    wgif=$(ip -br link show | awk '/^wg[0-9]+/ && /UP/ {print $1; exit}')
    printf '%%{F%s}\uf023 %s%%{F-}\n' "$GREEN" "$wgif"
else
    printf '%%{F%s}\uf023 off%%{F-}\n' "$GREY"
fi
