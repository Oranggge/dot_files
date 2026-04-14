#!/usr/bin/env bash
# Gruvbox Dark Hard themed i3lock-color wrapper.
# Screenshots the current screen, blurs + dims it, then locks.

set -eu

CACHE="${XDG_RUNTIME_DIR:-/tmp}/i3lock-shot.png"

# Capture -> pixelate (fast) -> dim toward gruvbox bg0_h.
# Pixelate via downscale+upscale is ~10x faster than gaussian blur
# and looks great at this aesthetic.
maim --hidecursor "$CACHE"
convert "$CACHE" \
  -scale 10% -scale 1000% \
  -fill '#1d2021' -colorize 45% \
  "$CACHE"

# Gruvbox palette (RRGGBBAA)
RING='3c3836ff'
INSIDE='28282899'
VERIF='8ec07cff'
WRONG='fb4934ff'
KEY='fabd2fff'
BSHL='fe8019ff'
FG='ebdbb2ff'
BEZEL='00000000'

exec i3lock \
  --nofork \
  --ignore-empty-password \
  --show-failed-attempts \
  --image="$CACHE" \
  --tiling \
  --clock \
  --indicator \
  --radius=110 \
  --ring-width=6 \
  --inside-color="$INSIDE" \
  --ring-color="$RING" \
  --line-color="$BEZEL" \
  --separator-color="$BEZEL" \
  --insidever-color="$INSIDE" \
  --ringver-color="$VERIF" \
  --insidewrong-color="$INSIDE" \
  --ringwrong-color="$WRONG" \
  --keyhl-color="$KEY" \
  --bshl-color="$BSHL" \
  --verif-color="$FG" \
  --wrong-color="$WRONG" \
  --layout-color="$FG" \
  --time-color="$FG" \
  --date-color="$FG" \
  --time-str="%H:%M" \
  --date-str="%a %d %b" \
  --verif-text="verifying…" \
  --wrong-text="nope" \
  --noinput-text="" \
  --lock-text="locking…" \
  --lockfailed-text="lock failed" \
  --time-font="JetBrainsMono Nerd Font" \
  --date-font="JetBrainsMono Nerd Font" \
  --verif-font="JetBrainsMono Nerd Font" \
  --wrong-font="JetBrainsMono Nerd Font" \
  --time-size=44 \
  --date-size=18 \
  --verif-size=20 \
  --wrong-size=20
