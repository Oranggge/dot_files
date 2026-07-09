#!/usr/bin/env bash
# speak-summary.sh — Stop hook
# Extracts the "🗣️ <summary>" line from Claude's last message and speaks it
# via a LOCAL TTS engine (CPU, offline). Fails silent (always exits 0) so it
# can never block or break the session.
#
# Engines (since 2026-06-11, dispatched per summary by script detection):
#   English  → Kokoro-82M  (~/tts-kokoro venv + tts-kokoro.py wrapper)
#   Cyrillic → Silero v5   (~/tts-silero venv + tts-silero.py wrapper)
#   fallback → Piper       (~/tts venv) if the Kokoro venv/model is missing
#
# Per-project voices: each git project gets its own deterministic voice in
# EACH language (so you can tell by ear which project is talking); non-repo
# dirs use the defaults. Override per project with <cwd>/.claude/speak-voice
# (English) / <cwd>/.claude/speak-voice-ru (Russian), or per shell with
# SPEAK_VOICE= / SPEAK_VOICE_RU=. Voice names imply their engine:
# af_*/am_*/bf_*/bm_* = Kokoro, aidar|baya|kseniya|eugene|xenia = Silero,
# anything else (en_GB-…) = Piper — old Piper pins keep working.
# Synthesis + playback run detached.
# Debug: tail -f ~/.claude/speak-summary.log

set -uo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIPER_PY="$HOME/tts/bin/python"           # piper-tts venv (legacy fallback)
KOKORO_PY="$HOME/tts-kokoro/bin/python"   # kokoro-onnx venv (English)
SILERO_PY="$HOME/tts-silero/bin/python"   # silero v5 venv (Russian)
VOICES_DIR="$HOME/tts-voices"             # piper <voice>.onnx files
KOKORO_MODEL="$HOME/tts-models/kokoro/kokoro-v1.0.onnx"
SILERO_MODEL="$HOME/tts-models/silero/v5_ru.pt"

DEFAULT_VOICE="bf_emma"                   # English default (GB female, Kokoro)
PIPER_FALLBACK_VOICE="en_GB-alba-medium"  # used only if Kokoro is unavailable

# Pool used to auto-assign a distinct ENGLISH voice per git project (mix of
# gender + US/GB accent so they're easy to tell apart by ear). Kokoro names:
# a=US b=GB, f=female m=male.
VOICE_POOL=(
  bf_emma
  am_michael
  af_heart
  bm_george
  af_bella
  am_puck
  bf_isabella
  am_fenrir
)

DEFAULT_VOICE_RU="xenia"                  # Russian default (Silero v5)
VOICE_POOL_RU=( xenia aidar baya eugene kseniya )

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

# --- pick the engine + voice for this summary --------------------------------
# Language: any Cyrillic in the line → Russian (Silero), else English (Kokoro).
# Voice precedence per language:
#   1. env var   SPEAK_VOICE= / SPEAK_VOICE_RU=
#   2. project   <cwd>/.claude/speak-voice / speak-voice-ru
#   3. auto      git repo  → deterministic pick from the language's pool
#                non-repo  → the language's default
# The voice NAME implies the engine, so an old Piper pin (en_GB-…) still
# routes to Piper.
engine_for_voice() {
  case "$1" in
    aidar|baya|kseniya|eugene|xenia) echo silero;;
    af_*|am_*|bf_*|bm_*)             echo kokoro;;
    *)                               echo piper;;
  esac
}

pool_pick() {  # $1.. = pool; deterministic per git repo, else first entry
  local pool=("$@") root n idx
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$root" ]; then
    n="$(printf '%s' "$root" | cksum | cut -d' ' -f1)"
    idx=$(( n % ${#pool[@]} ))
    printf '%s' "${pool[$idx]}"
  else
    printf '%s' "${pool[0]}"
  fi
}

if printf '%s' "$line" | LC_ALL=C.UTF-8 grep -qP '\p{Cyrillic}' 2>/dev/null; then
  LANG_TAG=ru
  if   [ -n "${SPEAK_VOICE_RU:-}" ];           then VOICE="$SPEAK_VOICE_RU"
  elif [ -r "$cwd/.claude/speak-voice-ru" ];   then VOICE="$(tr -d '[:space:]' < "$cwd/.claude/speak-voice-ru")"
  else
    root_check="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$root_check" ]; then VOICE="$(pool_pick "${VOICE_POOL_RU[@]}")"
    else VOICE="$DEFAULT_VOICE_RU"; fi
  fi
else
  LANG_TAG=en
  if   [ -n "${SPEAK_VOICE:-}" ];              then VOICE="$SPEAK_VOICE"
  elif [ -r "$cwd/.claude/speak-voice" ];      then VOICE="$(tr -d '[:space:]' < "$cwd/.claude/speak-voice")"
  else
    root_check="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    if [ -n "$root_check" ]; then VOICE="$(pool_pick "${VOICE_POOL[@]}")"
    else VOICE="$DEFAULT_VOICE"; fi
  fi
fi
ENGINE="$(engine_for_voice "$VOICE")"

# --- verify the chosen engine is actually usable; degrade where possible -----
PIPER_MODEL=""   # full .onnx path, only used by the piper branch
case "$ENGINE" in
  kokoro)
    if [ ! -x "$KOKORO_PY" ] || [ ! -f "$KOKORO_MODEL" ]; then
      log "warn: kokoro unavailable, falling back to piper $PIPER_FALLBACK_VOICE"
      ENGINE=piper; VOICE="$PIPER_FALLBACK_VOICE"
    fi;;
  silero)
    if [ ! -x "$SILERO_PY" ] || [ ! -f "$SILERO_MODEL" ]; then
      done_exit "fail: silero unavailable for russian summary ($SILERO_PY / $SILERO_MODEL)"
    fi;;
esac
if [ "$ENGINE" = "piper" ]; then
  PIPER_MODEL="$VOICES_DIR/$VOICE.onnx"
  if [ ! -f "$PIPER_MODEL" ]; then
    log "warn: piper voice '$VOICE' not found, falling back to $PIPER_FALLBACK_VOICE"
    VOICE="$PIPER_FALLBACK_VOICE"; PIPER_MODEL="$VOICES_DIR/$VOICE.onnx"
  fi
  [ -f "$PIPER_MODEL" ] || done_exit "fail: no piper voice file ($PIPER_MODEL)"
  [ -x "$PIPER_PY" ]    || done_exit "fail: piper venv python not found ($PIPER_PY)"
fi

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
# While a summary plays we also mark the window/space it came from, so you can
# see WHICH answer is talking right now. Because playback is serialized, the lit
# window is a clean 1:1 signal for the current voice.
#
#   tmux  — prepend 🔊 to the window name + flash a status-line banner, then
#           restore both afterwards.
#   herdr — `pane report-metadata` on the speaking pane. Strictly better than the
#           tmux rename: metadata is layered per --source (so the speak-summary
#           layer never clobbers herdr's own herdr:claude layer, and clearing it
#           reveals what was underneath) and it carries a ttl_ms, so a hook that
#           dies mid-playback can't strand a 🔊 the way rename/restore could.
#           The explicit clear below is the normal path; the ttl is the backstop.
#
#           ONE field, not two. The agent panel renders a row as
#               <space label> / <state> · <display_agent> · <custom_status>
#           so setting both display_agent and custom_status printed the emoji
#           TWICE (`done · 🔊 claude · 🔊 hermes`) and repeated the space label
#           that already sits on the line above. custom_status is the right field:
#           it exists for exactly this kind of ephemeral status, while
#           display_agent exists to RENAME the agent (using it would also hardcode
#           the name "claude"). The clear below still clears display_agent too, to
#           sweep marks left by the two-field version.
#           NOTE: custom_status is hard-truncated at 32 chars server-side. Moot
#           now that the mark is a single emoji, but it rules out ever putting the
#           spoken sentence here.
#
# The mark leads the audio by SPEAK_MARK_LEAD seconds and lingers SPEAK_MARK_LAG
# seconds past it, so the eye lands on the space before the voice starts and can
# still find it after the voice stops. Both waits sit INSIDE the lock, which is
# what keeps "exactly one 🔊 on screen" true.
#
# Set SPEAK_FOCUS=on to also jump focus to the speaking window/space. Under herdr
# you usually don't want that: herdr/speak-focus.py (bound to prefix+o) jumps to
# the current — or most recent — speaker on demand instead.
LOCK_FILE="$HOME/.claude/speak-summary.lock"
MAX_WAIT="${SPEAK_MAX_WAIT:-25}"          # drop summaries queued longer than this (s)
START_EPOCH="$(date +%s)"
FOCUS="off"; case "${SPEAK_FOCUS:-}" in on|1|true) FOCUS="on";; esac
TPANE=""; [ -n "${TMUX:-}" ] && TPANE="${TMUX_PANE:-}"
PROJECT="$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd")")"

# --- herdr marking ----------------------------------------------------------
# The hook inherits Claude's environment, so HERDR_PANE_ID is set iff this
# session lives in a herdr pane. Resolve the binary explicitly: a hook's PATH is
# not a login shell's.
SPK_HERDR_BIN=""
if [ -n "${HERDR_PANE_ID:-}" ]; then
  SPK_HERDR_BIN="$(command -v herdr 2>/dev/null)" || SPK_HERDR_BIN=""
  [ -n "$SPK_HERDR_BIN" ] || { [ -x "$HOME/.local/bin/herdr" ] && SPK_HERDR_BIN="$HOME/.local/bin/herdr"; }
fi
SPK_HPANE=""; [ -n "$SPK_HERDR_BIN" ] && SPK_HPANE="${HERDR_PANE_ID:-}"
SPK_MARK="${SPEAK_MARK:-🔊}"
SPK_LEAD="${SPEAK_MARK_LEAD:-0.6}"        # seconds the mark precedes the audio
SPK_LAG="${SPEAK_MARK_LAG:-1.5}"          # seconds the mark outlives the audio
SPK_SPEAKER_FILE="$HOME/.claude/speak-summary-speaker"
# Millisecond forms for the ttl arithmetic. Converted HERE, in the outer script,
# because the detached block below is a single-quoted string: a lone ' anywhere
# inside it (an awk program, an '' empty-string case pattern) silently ends the
# quote and spills the rest into this shell. `bash -n` still passes. Keep that
# block free of single quotes.
SPK_LEAD_MS="$(awk -v s="$SPK_LEAD" 'BEGIN{printf "%d", s*1000}')"
SPK_LAG_MS="$(awk -v s="$SPK_LAG" 'BEGIN{printf "%d", s*1000}')"
export SPK_HERDR_BIN SPK_HPANE SPK_MARK SPK_LEAD SPK_LAG SPK_SPEAKER_FILE \
       SPK_LEAD_MS SPK_LAG_MS

# --- synthesize + play, fully detached so it never blocks the prompt --------
# Synthesis happens BEFORE the lock (parallel across sessions is fine); only
# ffplay + the tmux marker are serialized, so playback starts the instant the
# lock frees with no synth delay. Engine config reaches the detached subshell
# via exported SPK_* vars (it inherits our environment).
export SPK_HOOKS_DIR="$HOOKS_DIR" SPK_PIPER_PY="$PIPER_PY" \
       SPK_KOKORO_PY="$KOKORO_PY" SPK_SILERO_PY="$SILERO_PY" \
       SPK_PIPER_MODEL="$PIPER_MODEL"
log "speaking (uuid=${uuid:0:8}, lang=$LANG_TAG, engine=$ENGINE, voice=$VOICE): $line"
( setsid bash -c '
    eng="$1"; voice="$2"; txt="$3"; lock="$4"; maxw="$5"; t0="$6";
    pane="$7"; proj="$8"; focus="$9";

    tmp="$(mktemp --suffix=.wav)";
    case "$eng" in
      kokoro) "$SPK_KOKORO_PY" "$SPK_HOOKS_DIR/tts-kokoro.py" "$voice" "$tmp" "$txt" >/dev/null 2>&1;;
      silero) "$SPK_SILERO_PY" "$SPK_HOOKS_DIR/tts-silero.py" "$voice" "$tmp" "$txt" >/dev/null 2>&1;;
      *)      "$SPK_PIPER_PY" -m piper -m "$SPK_PIPER_MODEL" -f "$tmp" -- "$txt" >/dev/null 2>&1;;
    esac
    [ -s "$tmp" ] || { rm -f "$tmp"; exit 0; }

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
        tmux rename-window -t "$win" "$SPK_MARK $oldname" 2>/dev/null;
        tmux display-message "$SPK_MARK $proj: $txt" 2>/dev/null;
        [ "$focus" = "on" ] && tmux select-window -t "$win" 2>/dev/null;
      fi
    fi

    # herdr attention: mark the pane (and therefore its space) for the whole of
    # lead + audio + lag. ttl_ms is sized to that window plus slack, so it only
    # ever fires if we die before the explicit clear below.
    # NB: no single quotes below — see the SPK_LEAD_MS comment above.
    if [ -n "$SPK_HPANE" ]; then
      dur_s="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$tmp" 2>/dev/null)";
      dur_s="${dur_s%%.*}";
      case "$dur_s" in ""|*[!0-9]*) dur_s=8;; esac;
      ttl=$(( SPK_LEAD_MS + (dur_s + 1) * 1000 + SPK_LAG_MS + 3000 ));
      "$SPK_HERDR_BIN" pane report-metadata "$SPK_HPANE" --source speak-summary \
        --custom-status "$SPK_MARK" --ttl-ms "$ttl" >/dev/null 2>&1;
      # remember who is talking, so speak-focus.py can jump here on prefix+o
      printf "%s %s %s %s\n" "${SPK_HPANE%%:*}" "$SPK_HPANE" "$(date +%s)" "$proj" \
        > "$SPK_SPEAKER_FILE" 2>/dev/null;
      [ "$focus" = "on" ] && "$SPK_HERDR_BIN" workspace focus "${SPK_HPANE%%:*}" >/dev/null 2>&1;
      sleep "$SPK_LEAD";
    fi

    ffplay -nodisp -autoexit -loglevel quiet "$tmp" >/dev/null 2>&1;

    # let the mark outlive the voice, then take it down explicitly
    if [ -n "$SPK_HPANE" ]; then
      sleep "$SPK_LAG";
      "$SPK_HERDR_BIN" pane report-metadata "$SPK_HPANE" --source speak-summary \
        --clear-custom-status --clear-display-agent >/dev/null 2>&1;
    fi

    # restore the window name + automatic-rename state
    if [ -n "$win" ]; then
      tmux rename-window -t "$win" "$oldname" 2>/dev/null;
      tmux set-window-option -t "$win" automatic-rename "$oldauto" 2>/dev/null;
    fi
    rm -f "$tmp";
  ' _ "$ENGINE" "$VOICE" "$line" "$LOCK_FILE" "$MAX_WAIT" "$START_EPOCH" \
       "$TPANE" "$PROJECT" "$FOCUS" >/dev/null 2>&1 & )

done_exit "ok: engine=$ENGINE voice=$VOICE (detached, serialized)"
