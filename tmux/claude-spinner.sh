#!/usr/bin/env bash
# Animated "Claude is working" spinner for tmux tabs.
#
# Pure tmux formats can't animate (no clock/tick variable), so this tiny daemon
# supplies the motion: it advances a global tmux option `@cc_spin_frame` and
# forces a status redraw. window-status-format renders that frame ONLY for
# windows whose active pane is a working Claude (see .tmux.conf predicate), so
# all busy tabs spin in sync and everything else stays blank.
#
# Lifecycle: single always-on instance (flock), launched by a `run-shell -b`
# line in .tmux.conf. Adaptive — ~8fps animation while any Claude tab is
# thinking, otherwise a cheap 1s idle poll. Exits when the tmux server is gone.
# Fails silent so it can never wedge tmux.

LOCK="${TMPDIR:-/tmp}/tmux-claude-spinner.lock"
exec 9>"$LOCK" 2>/dev/null || exit 0
flock -n 9 || exit 0   # another instance is already animating

# Spinner frames. Classic braille "dots" set (matches the approved preview).
# For a chunkier, more eye-catching block, swap to the heavy set:
#   frames=(⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷)
frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
n=${#frames[@]}
i=0

# Count windows whose active pane is a working Claude: command == claude AND the
# pane title is NOT the idle "✳ …" marker (i.e. it's the live thinking spinner).
count_working() {
  tmux list-windows -a \
    -F '#{?#{&&:#{==:claude,#{pane_current_command}},#{?#{m:✳*,#{pane_title}},0,1}},x,}' \
    2>/dev/null | grep -c x
}

while tmux has-session 2>/dev/null; do
  if [ "$(count_working)" -gt 0 ]; then
    tmux set -g @cc_spin_frame "${frames[i]}" 2>/dev/null
    tmux refresh-client -S 2>/dev/null   # redraw status now (faster than status-interval)
    i=$(( (i + 1) % n ))
    sleep 0.12
  else
    tmux set -g @cc_spin_frame '' 2>/dev/null   # clear; status-interval redraws it away
    sleep 1
  fi
done
