#!/usr/bin/env bash
# speak-summary-baseline.sh — UserPromptSubmit hook
# Companion to speak-summary.sh. Fires the instant you submit a prompt (i.e.
# BEFORE Claude responds) and records the uuid of the LAST 🗣️-bearing assistant
# message that exists right now — that's the *previous* answer's summary.
#
# The Stop hook then waits until a 🗣️ line appears in a message with a DIFFERENT
# (newer) uuid, so it can never re-speak the previous answer during the brief
# window before the current answer's final line is flushed to the transcript.
# Fails silent (always exits 0).

set -uo pipefail

STATE_DIR="$HOME/.claude/speak-summary-state"
LOG_FILE="$HOME/.claude/speak-summary.log"
log(){ printf '%s [baseline] %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE" 2>/dev/null; }

input="$(cat)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null)"

# Belt-and-braces: drop any speak-summary mark left on this herdr pane. The Stop
# hook clears its own mark and sizes a ttl_ms as backstop, so a survivor here
# means something died in an unusual way (SIGKILL between mark and clear, a
# server restart that replayed old metadata). You are submitting a new prompt,
# so nothing in this pane can still be speaking the previous answer.
# Runs BEFORE the transcript guard below — it needs no transcript, and the
# whole point is to fire on paths where the rest of this hook bails out.
if [ -n "${HERDR_PANE_ID:-}" ]; then
  herdr_bin="$(command -v herdr 2>/dev/null)" || herdr_bin=""
  [ -n "$herdr_bin" ] || { [ -x "$HOME/.local/bin/herdr" ] && herdr_bin="$HOME/.local/bin/herdr"; }
  [ -n "$herdr_bin" ] && "$herdr_bin" pane report-metadata "$HERDR_PANE_ID" \
    --source speak-summary --clear-custom-status --clear-display-agent >/dev/null 2>&1
fi

[ -n "$transcript" ] && [ -f "$transcript" ] || { log "skip: no transcript"; exit 0; }

mkdir -p "$STATE_DIR" 2>/dev/null

# uuid of the last assistant message that contains a line starting with 🗣️
baseline="$(jq -rs '
  [ .[]
    | select(.type=="assistant" and (.message.content | type=="array"))
    | { uuid: (.uuid // ""),
        sp: ( [ .message.content[] | select(.type=="text") | .text ]
              | join("\n") | split("\n")
              | map(select(test("^[[:space:]]*🗣"))) | last // "" ) }
    | select(.sp != "")
    | .uuid
  ] | last // empty
' "$transcript" 2>/dev/null)"

printf '%s' "$baseline" > "$STATE_DIR/$session_id" 2>/dev/null
log "session=${session_id:0:8} baseline(prev summary uuid)=${baseline:-none}"
exit 0
