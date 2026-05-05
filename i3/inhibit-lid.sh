#!/usr/bin/env bash
# Hold a block:handle-lid-switch inhibitor for the life of the i3 session.
# See i3/config and CLAUDE.md "Layout" for the why.
#
# This lives in its own script (not inline in i3/config) on purpose: pkill -f
# matches against full command lines, so if the pattern below is present in
# the calling process's argv, pkill SIGTERMs the parent shell before exec
# can run. With the logic in a script file, the caller's argv is just the
# script path — pkill only matches the orphaned old inhibitor, not us.
set -eu

PATTERN='systemd-inhibit --what=handle-lid-switch --who=i3'

# Clean up an orphaned inhibitor from a previous i3 session (e.g. after
# $mod+Shift+C restart), then take its place.
pkill -f "$PATTERN" 2>/dev/null || true

exec systemd-inhibit \
  --what=handle-lid-switch \
  --who=i3 \
  --why="external monitors" \
  --mode=block \
  sleep infinity
