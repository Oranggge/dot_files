#!/usr/bin/env bash
# Gruvbox Dark Hard themed lock wrapper.
# Screenshots the current screen, pixelates + dims it, then locks.
#
# Robust across i3lock variants:
#   * i3lock-color (the fork with --clock / --ring-color / --radius …) -> full
#     themed lock with clock + ring indicator.
#   * vanilla upstream i3lock (e.g. i3lock 2.16, which the Fedora 44 upgrade
#     swapped in for i3lock-color) -> minimal flag set so locking STILL works.
#     You keep the blurred/dimmed screenshot background via -i; you only lose
#     the clock + ring overlay until i3lock-color is reinstalled, at which point
#     this script auto-upgrades back to the full theme. No edit needed either way.

set -eu

# Guard against re-entry. xss-lock can fire lock.sh on overlapping triggers
# (PrepareForSleep + LockSession in quick succession), so without this we'd
# stack two i3locks and flash the lock screen.
if pgrep -x i3lock >/dev/null; then
  exit 0
fi

# Auto-suspend 30 min after locking. Self-cancels if user unlocks before then
# (i3lock exits -> pgrep finds nothing -> systemctl suspend skipped). Time-based,
# not idle-based, because X idle is unreliable on this machine. Covers the case
# where lid is open + screen locked + AC pulled, which logind alone can't see.
(sleep 1800; pgrep -x i3lock >/dev/null && systemctl suspend) </dev/null >/dev/null 2>&1 &
disown

CACHE="${XDG_RUNTIME_DIR:-/tmp}/i3lock-shot.png"

# Capture -> pixelate (fast) -> dim toward gruvbox bg0_h.
# Pixelate via downscale+upscale is ~10x faster than gaussian blur
# and looks great at this aesthetic. Prefer ImageMagick 7's `magick`; fall
# back to the legacy `convert` shim on older ImageMagick.
maim --hidecursor "$CACHE"
if command -v magick >/dev/null 2>&1; then IM=magick; else IM=convert; fi
"$IM" "$CACHE" \
  -scale 10% -scale 1000% \
  -fill '#1d2021' -colorize 45% \
  "$CACHE"

# i3lock-color advertises --clock in its help; vanilla i3lock does not. Use that
# as the capability probe. On a miss we degrade rather than fail, so a future
# package swap in either direction can never leave the screen unlockable.
if i3lock --help 2>&1 | grep -q -- '--clock'; then
  # --- i3lock-color: full gruvbox theme ---------------------------------------
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
else
  # --- vanilla upstream i3lock: minimal, guaranteed flags only ----------------
  # Short flags from the i3lock 2.16 syntax line: -n nofork, -e ignore-empty,
  # -f show-failed-attempts, -i image (PNG), -t tile, -c bg color (RRGGBB, the
  # bg0_h fallback shown only if the screenshot fails to load).
  exec i3lock \
    -n \
    -e \
    -f \
    -i "$CACHE" \
    -t \
    -c 1d2021
fi
