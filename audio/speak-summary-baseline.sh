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
