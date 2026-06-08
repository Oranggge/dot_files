#!/usr/bin/env bash
# speak-summary.sh — Stop hook
# Extracts the "🗣️ <summary>" line from Claude's last message and speaks it
# via a LOCAL Piper TTS model (CPU, offline). Fails silent (always exits 0) so
# it can never block or break the session.
#
# Per-project voices: each git project gets its own deterministic voice (so you
# can tell by ear which project is talking); non-repo dirs use DEFAULT_VOICE.
# Override per project with <cwd>/.claude/speak-voice (a voice name) or per
# shell with SPEAK_VOICE=<name>. Synthesis + playback run detached.
#
# Voices live in $VOICES_DIR as <name>.onnx (+ .onnx.json), downloaded with:
#   ~/tts/bin/python -m piper.download_voices <name>
# Debug: tail -f ~/.claude/speak-summary.log

set -uo pipefail

VENV_PY="$HOME/tts/bin/python"          # piper-tts installed in this venv
VOICES_DIR="$HOME/tts-voices"           # where <voice>.onnx files live
DEFAULT_VOICE="en_GB-alba-medium"       # the favorite; used outside git repos

# Pool used to auto-assign a distinct voice per git project (mix of
# gender + US/GB accent so they're easy to tell apart by ear).
VOICE_POOL=(
  en_GB-alba-medium
  en_GB-northern_english_male-medium
  en_US-amy-medium
  en_US-ryan-high
  en_GB-cori-high
  en_US-joe-medium
  en_US-kristin-medium
  en_US-hfc_male-medium
)

LOG_FILE="$HOME/.claude/speak-summary.log"
STATE_DIR="$HOME/.claude/speak-summary-state"
SID=""
log(){ printf '%s [stop%s] %s\n' "$(date '+%F %T')" "${SID:+:$SID}" "$*" >> "$LOG_FILE" 2>/dev/null; }
done_exit(){ log "$1"; exit 0; }

# --- read hook payload from stdin -------------------------------------------
input="$(cat)"
transcript="$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)"
cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"; [ -n "$cwd" ] || cwd="$PWD"
session_id="$(printf '%s' "$input" | jq -r '.session_id // "default"' 2>/dev/null)"
SID="${session_id:0:8}"
log "FIRED"
[ -n "$transcript" ] && [ -f "$transcript" ] || done_exit "skip: no transcript path"

# --- enable/disable (first match wins) --------------------------------------
#   1. env var   SPEAK_SUMMARY=on|off   (per shell/session)
#   2. project   <cwd>/.claude/speak-summary   containing on|off
#   3. global    ~/.claude/speak-summary        containing on|off
#   4. default   on
resolve_state() {
  case "${SPEAK_SUMMARY:-}" in on|1|true) echo on; return;; off|0|false) echo off; return;; esac
  [ -r "$cwd/.claude/speak-summary" ]  && { tr -d '[:space:]' < "$cwd/.claude/speak-summary";  return; }
  [ -r "$HOME/.claude/speak-summary" ] && { tr -d '[:space:]' < "$HOME/.claude/speak-summary"; return; }
  echo on
}
[ "$(resolve_state)" = "off" ] && done_exit "skip: disabled by toggle"

# --- per-session dedup state ------------------------------------------------
# Track the uuid of the last message we spoke, so we never re-speak the
# previous answer's 🗣️ line (which is what's still in the transcript during the
# brief window before the *current* answer's final message is flushed to disk).
mkdir -p "$STATE_DIR" 2>/dev/null
find "$STATE_DIR" -type f -mtime +14 -delete 2>/dev/null   # prune old sessions
STATE_FILE="$STATE_DIR/$session_id"
prev_uuid="$(cat "$STATE_FILE" 2>/dev/null)"
log "baseline prev_uuid=${prev_uuid:-none}"

# Return "<uuid>\t<🗣️ line>" for the LAST assistant message that contains a
# line starting with the marker. uuid lets us tell a new answer from the old.
get_marker_msg() {
  jq -rs '
    [ .[]
      | select(.type=="assistant" and (.message.content | type=="array"))
      | { uuid: (.uuid // ""),
          sp: ( [ .message.content[] | select(.type=="text") | .text ]
                | join("\n") | split("\n")
                | map(select(test("^[[:space:]]*🗣"))) | last // "" ) }
      | select(.sp != "")
    ] | last // empty
    | "\(.uuid)\t\(.sp)"
  ' "$transcript" 2>/dev/null
}

# --- poll for a NEW marker (handles the post-Stop transcript flush race) ----
uuid=""; line=""; last_seen=""; polls=0
for _ in $(seq 1 15); do          # up to ~3s
  res="$(get_marker_msg)"
  polls=$((polls+1))
  if [ -n "$res" ]; then
    u="${res%%$'\t'*}"
    raw="${res#*$'\t'}"
    [ "$u" = "null" ] && u="$raw"          # uuid missing → fall back to text identity
    last_seen="$u"
    if [ "$u" != "$prev_uuid" ]; then
      cand="$(printf '%s' "$raw" | sed -E 's/^[[:space:]]*🗣️[[:space:]]*//; s/^[A-Za-z0-9_ -]{1,20}:[[:space:]]*//')"
      if [ "${#cand}" -ge 5 ]; then uuid="$u"; line="$cand"; break; fi
    fi
  fi
  sleep 0.2
done

if [ -z "$uuid" ] || [ -z "$line" ]; then
  done_exit "skip: no new summary after ${polls} polls (prev_uuid=${prev_uuid:-none} last_seen=${last_seen:-none})"
fi
log "match uuid=${uuid:0:8} after ${polls} polls"

# --- pick the voice for this project ----------------------------------------
#   1. env var   SPEAK_VOICE=<name>
#   2. project   <cwd>/.claude/speak-voice   (a voice name)
#   3. auto      git repo  → deterministic pick from VOICE_POOL by repo path
#                non-repo  → DEFAULT_VOICE
resolve_voice() {
  if [ -n "${SPEAK_VOICE:-}" ]; then printf '%s' "$SPEAK_VOICE"; return; fi
  if [ -r "$cwd/.claude/speak-voice" ]; then
    tr -d '[:space:]' < "$cwd/.claude/speak-voice"; return
  fi
  local root
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$root" ]; then
    local n idx
    n="$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
    idx=$(( n % ${#VOICE_POOL[@]} ))
    printf '%s' "${VOICE_POOL[$idx]}"; return
  fi
  printf '%s' "$DEFAULT_VOICE"
}
VOICE="$(resolve_voice)"
voice_path="$VOICES_DIR/$VOICE.onnx"
if [ ! -f "$voice_path" ]; then
  log "warn: voice '$VOICE' not found, falling back to $DEFAULT_VOICE"
  VOICE="$DEFAULT_VOICE"; voice_path="$VOICES_DIR/$VOICE.onnx"
fi
[ -f "$voice_path" ] || done_exit "fail: no voice file ($voice_path)"
[ -x "$VENV_PY" ]    || done_exit "fail: piper venv python not found ($VENV_PY)"

# mark this message as spoken so it is never repeated
printf '%s' "$uuid" > "$STATE_FILE" 2>/dev/null

# --- cross-session playback coordination ------------------------------------
# Several agents (separate sessions) can hit Stop at the same instant; without
# coordination their ffplay processes overlap into mush. We serialize playback
# through a single global flock so exactly ONE summary is audible at a time —
# they queue and play in turn (the per-project voices make that sound like
# people taking turns). To stop a burst becoming a monologue, a summary that
# has waited longer than MAX_WAIT in the queue is dropped instead of played.
#
# While a summary plays we also mark its tmux window (prepend 🔊 to the name)
# and flash a status-line banner, so you can see WHICH answer is talking right
# now. Because playback is serialized, the lit window is a clean 1:1 signal for
# the current voice. Set SPEAK_FOCUS=on to also jump focus to that window.
LOCK_FILE="$HOME/.claude/speak-summary.lock"
MAX_WAIT="${SPEAK_MAX_WAIT:-25}"          # drop summaries queued longer than this (s)
START_EPOCH="$(date +%s)"
FOCUS="off"; case "${SPEAK_FOCUS:-}" in on|1|true) FOCUS="on";; esac
TPANE=""; [ -n "${TMUX:-}" ] && TPANE="${TMUX_PANE:-}"
PROJECT="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")")"

# --- synthesize + play, fully detached so it never blocks the prompt --------
# Synthesis happens BEFORE the lock (parallel across sessions is fine); only
# ffplay + the tmux marker are serialized, so playback starts the instant the
# lock frees with no synth delay.
log "speaking (uuid=${uuid:0:8}, voice=$VOICE): $line"
( setsid bash -c '
    py="$1"; vp="$2"; txt="$3"; lock="$4"; maxw="$5"; t0="$6";
    pane="$7"; proj="$8"; focus="$9";

    tmp="$(mktemp --suffix=.wav)";
    "$py" -m piper -m "$vp" -f "$tmp" -- "$txt" >/dev/null 2>&1 || { rm -f "$tmp"; exit 0; }

    # serialize: wait our turn behind any other speaking session
    exec 9>"$lock";
    flock 9;

    # staleness: if we waited too long in the queue, skip (its answer is old)
    now="$(date +%s)";
    [ $((now - t0)) -gt "$maxw" ] && { rm -f "$tmp"; exit 0; }

    # tmux attention: light up the window that is about to speak
    win=""; oldname=""; oldauto="on";
    if [ -n "$pane" ] && command -v tmux >/dev/null 2>&1; then
      win="$(tmux display-message -p -t "$pane" "#{window_id}" 2>/dev/null)";
      if [ -n "$win" ]; then
        oldname="$(tmux display-message -p -t "$win" "#{window_name}" 2>/dev/null)";
        oldauto="$(tmux show-options -wv -t "$win" automatic-rename 2>/dev/null)"; [ -n "$oldauto" ] || oldauto=on;
        tmux set-window-option -t "$win" automatic-rename off 2>/dev/null;
        tmux rename-window -t "$win" "🔊 $oldname" 2>/dev/null;
        tmux display-message "🔊 $proj: $txt" 2>/dev/null;
        [ "$focus" = "on" ] && tmux select-window -t "$win" 2>/dev/null;
      fi
    fi

    ffplay -nodisp -autoexit -loglevel quiet "$tmp" >/dev/null 2>&1;

    # restore the window name + automatic-rename state
    if [ -n "$win" ]; then
      tmux rename-window -t "$win" "$oldname" 2>/dev/null;
      tmux set-window-option -t "$win" automatic-rename "$oldauto" 2>/dev/null;
    fi
    rm -f "$tmp";
  ' _ "$VENV_PY" "$voice_path" "$line" "$LOCK_FILE" "$MAX_WAIT" "$START_EPOCH" \
       "$TPANE" "$PROJECT" "$FOCUS" >/dev/null 2>&1 & )

done_exit "ok: piper voice=$VOICE (detached, serialized)"
