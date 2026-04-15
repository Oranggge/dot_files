#!/usr/bin/env bash
# Pick Pixel Buds Pro ANC mode via rofi. Uses pbpctrl.

set -e

PBPCTRL="${PBPCTRL:-$HOME/.cargo/bin/pbpctrl}"
if ! command -v "$PBPCTRL" >/dev/null 2>&1 && [ ! -x "$PBPCTRL" ]; then
  notify-send "ANC" "pbpctrl not found"
  exit 1
fi

current=$("$PBPCTRL" get anc 2>/dev/null || echo "unknown")

options="off
active
aware"

choice=$(printf '%s\n' "$options" | rofi -dmenu -i -p "anc ($current)" | awk '{print $NF}')
[ -z "$choice" ] && exit 0

if "$PBPCTRL" set anc "$choice" >/dev/null 2>&1; then
  notify-send "ANC" "→ $choice"
else
  notify-send "ANC" "failed to set $choice (buds connected?)"
fi
