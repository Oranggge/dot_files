# Claude Code spoken answer summaries (local TTS: Kokoro EN + Silero RU)

Set up 2026-05-24. Makes Claude Code **speak a one-sentence summary of each
answer** out loud, using **local, offline TTS models** (CPU only — no GPU, no
cloud, no API key). Output-side companion to the mic notes in this folder's
`README.md`.

History: built on Inworld cloud TTS → switched to local Piper 2026-05-24 →
**upgraded 2026-06-11 to Kokoro-82M (English) + Silero v5 (Russian)** for
clearly better naturalness and Russian support; Piper is kept only as the
fallback engine if Kokoro is missing. The old Inworld version is kept as
`~/.claude/hooks/speak-summary.sh.inworld.bak`.

## Why

Inspired by Daniel Miessler's Personal AI Infrastructure (PAI) repo
(`github.com/danielmiessler/Personal_AI_Infrastructure`), which speaks a short
summary after each response. The appeal: you can look away from the screen and
still know *what* the answer was / that it finished. PAI's own implementation is
a heavy Bun/TypeScript stack hardwired to ElevenLabs + macOS `say` + PAI's
directory layout — not worth vendoring. What's reusable is the *design*, which
this reproduces in plain bash for Linux, now with a fully local TTS engine.

## How it works

The summary is **not** a second AI call. Claude writes its own summary as the
last line of every answer (`🗣️ …`), and two cooperating hooks turn it into speech:

1. **Instruction** (`~/.claude/CLAUDE.md`) tells Claude to end substantive
   responses with a line: `🗣️ <one-sentence factual summary, ≤16 words>`.
2. **Baseline hook** — `UserPromptSubmit` runs `speak-summary-baseline.sh` the
   instant you submit a prompt (before Claude answers). It records the uuid of
   the *previous* answer's 🗣️ message into
   `~/.claude/speak-summary-state/<session_id>`. This is the anchor that lets the
   Stop hook tell "new answer" from "the one already spoken."
3. **Stop hook** — runs `speak-summary.sh` after each response. It reads the
   transcript and **polls up to ~3 s** for a 🗣️ line in an assistant message
   whose uuid differs from the baseline, then strips the marker.
4. It detects the summary's language (any Cyrillic → Russian), picks an engine
   + voice (see below), then **synthesizes + plays detached**: a `setsid`
   subshell runs the engine's wrapper (`tts-kokoro.py` / `tts-silero.py`, or
   `python -m piper` on the fallback path) and plays the WAV with `ffplay`, so
   the prompt is never blocked by the ~3–5 s CPU synthesis. Every error path
   exits 0 → can never block or break a session.
5. **Playback is serialized across sessions** (see below) so simultaneous
   finishers take turns instead of overlapping, and the **tmux window / herdr
   space of the currently-speaking answer is marked** so you can see which one is
   talking. Under herdr, `prefix+o` jumps to it.

### TTS engines (since 2026-06-11)

Three engines, one per role; the hook dispatches per summary by detecting
Cyrillic in the 🗣️ line (`\p{Cyrillic}`):

| Role | Engine | Venv | Models | Speed (i7-1355U) |
|---|---|---|---|---|
| **English** | [Kokoro-82M](https://github.com/thewh1teagle/kokoro-onnx) via `kokoro-onnx` (ONNX, StyleTTS2-class) | `~/tts-kokoro/` | `~/tts-models/kokoro/` (~340 MB) | ~4 s per one-liner incl. model load |
| **Russian** | [Silero v5](https://github.com/snakers4/silero-models) (torch CPU; auto stress/ударение + homographs) | `~/tts-silero/` | `~/tts-models/silero/v5_ru.pt` (~140 MB) | ~4–5 s per one-liner incl. torch load |
| **Fallback** | [`piper-tts`](https://pypi.org/project/piper-tts/) (used only if Kokoro venv/model is missing) | `~/tts/` | `~/tts-voices/*.onnx` | ~3–5 s |

Why this pair (researched 2026-06-11): Kokoro is the biggest naturalness jump
over Piper that still runs ~2× real-time on CPU, but has **no Russian**.
Silero v5 is the best local Russian — its automatic stress placement is exactly
where Piper's `ru_RU` voices fail — but its English (v3) is dated. Single-engine
alternatives lost: Supertonic 3 (en+ru, fast, but ≈Piper-level naturalness),
Chatterbox Multilingual (great quality, RTF >1 on CPU — too slow), XTTS/F5-TTS
(GPU-class). `edge-tts` (free Azure voices, needs network) would beat both but
breaks the offline design; noted as an option, not wired in.

- Engines are invoked through tiny wrappers next to the hook:
  `~/.claude/hooks/tts-kokoro.py <voice> <out.wav> <text>` and
  `~/.claude/hooks/tts-silero.py <speaker> <out.wav> <text>` (vendored in
  `audio/`).
- Silero v5_ru license is **CC BY-NC** (fine for this personal hook); Kokoro
  model is Apache-2.0.
- Venv recreate commands are in "Reproduce on a new machine" below. The
  legacy Piper venv:
  ```sh
  uv python install 3.14                                  # uv-managed standalone build
  uv venv ~/tts --managed-python --python 3.14
  uv pip install --python ~/tts/bin/python piper-tts
  ```
- **Why `--managed-python` and not the system Python (set 2026-06-08).** A plain
  `uv venv` links the venv to `/usr/bin/python3.XX`, which a Fedora **major**
  upgrade *deletes* — the 42→44 bump took system Python 3.13→3.14 and removed
  `/usr/bin/python3.13`, leaving `~/tts/bin/python` a dangling symlink. The Stop
  hook then hits its `fail: piper venv python not found` guard and the summaries
  go **silent with no error** (the hook always exits 0). `--managed-python` links
  the venv to a uv standalone build under
  `~/.local/share/uv/python/cpython-3.14…/` instead, which lives in `$HOME` and
  `dnf` never touches — so the venv survives OS upgrades. Confirm the decoupling
  in `~/tts/pyvenv.cfg`: `home =` must point under `~/.local/share/uv/python/`,
  **not** `/usr/bin`.
  - Tradeoff: the managed Python is ~30 MB and uv (not dnf) owns its updates —
    fine for an offline CPU-only tool. uv 0.8.15's catalog only ships
    `3.14.0rc2`, so that's what gets linked; functionally irrelevant for Piper.
    To move to a newer 3.14.x later: `uv self update && uv python install 3.14`
    then rebuild the venv with the block above.
  - If it ever does break (e.g. you rebuilt with plain `uv venv`), the repair is
    the same three commands above; voices in `~/tts-voices/` are untouched, so no
    re-download.
- Voice files (`<name>.onnx` + `<name>.onnx.json`, ~60 MB each) live in
  `~/tts-voices/`. Download more with
  `~/tts/bin/python -m piper.download_voices <name>` (browse names at the
  HuggingFace `rhasspy/piper-voices` repo).
- License: Piper is GPL-3.0-or-later; voices are mostly permissive (per-voice).

### Per-project voices (per language)

Each git project speaks in **its own voice in each language** so you can tell
by ear which project is talking. Resolution precedence (first match wins),
applied to the language the detector picked:

1. **env** `SPEAK_VOICE=<name>` (English) / `SPEAK_VOICE_RU=<name>` (Russian).
2. **project file** `<cwd>/.claude/speak-voice` / `<cwd>/.claude/speak-voice-ru`
   — a single voice name. Pin a project this way.
3. **auto** — if `cwd` is inside a **git repo**, a deterministic voice is chosen
   from that language's pool by `cksum` of the repo's toplevel path (same repo →
   same voice every time). If **not** in a repo, the language default is used.

The voice **name implies the engine**: `af_*/am_*/bf_*/bm_*` → Kokoro
(a=US/b=GB, f/m=gender), `aidar|baya|kseniya|eugene|xenia` → Silero, anything
else (`en_GB-…`) → Piper — so an old Piper pin file keeps working unchanged.

`DEFAULT_VOICE="bf_emma"` (Kokoro GB female; the top-rated Kokoro voice is
`af_heart`, US female, if you prefer it). `DEFAULT_VOICE_RU="xenia"`.
`VOICE_POOL` (8 Kokoro voices, mixed gender/accent) and `VOICE_POOL_RU`
(all 5 Silero speakers) are edited at the top of `speak-summary.sh`.

### Cross-session serialization + tmux attention (added 2026-05-29)

Several agents in different sessions can hit `Stop` in the same instant; before
this, each fired its own `ffplay` immediately and the voices overlapped into
mush. The detached block now coordinates across **all** sessions:

- **Serialize.** Synthesis still runs unsynchronized (parallel CPU is fine), but
  playback is wrapped in a global `flock` on `~/.claude/speak-summary.lock`, so
  exactly **one** summary is audible at a time. Simultaneous finishers queue and
  play in turn — and because each project has its own voice, that sounds like
  people taking turns rather than noise. Waiting costs the session nothing (the
  block is already detached).
- **Staleness cap.** A burst of finishers shouldn't become a 30-second monologue
  about answers that are already old. Each request is stamped with an epoch when
  the hook fires; if it has sat in the queue longer than `MAX_WAIT` (default 25 s,
  override `SPEAK_MAX_WAIT`) by the time it gets the lock, it is **dropped**
  unspoken. Self-limiting pileup.
- **tmux marker.** While a summary plays, its tmux window name is prepended with
  `🔊` (`3:dot_files` → `3:🔊 dot_files`) and a one-shot status-line banner
  `🔊 <project>: <line>` is flashed. Restored on finish. Because playback is
  serialized, the lit window is a clean **1:1** signal for the voice you're
  hearing right now. Uses `$TMUX_PANE` (inherited from the shell that launched
  Claude); no-op outside tmux. `automatic-rename` is snapshotted and toggled off
  during the marker so tmux doesn't clobber it, then restored. This is
  **orthogonal** to `tmux-agent-indicator`, which drives window *colors* — names
  and colors don't collide, and the 🔊 complements its "done" flip.
- **`SPEAK_FOCUS=on`** (off by default) additionally `select-window`s to the
  speaking window — stronger "show me which one," but it hijacks your cursor, so
  it's opt-in.

### herdr marker (added 2026-07-09)

Under [herdr](../herdr/) there is no `$TMUX`, so the tmux block above silently
no-ops and a summary used to play with **zero visual attribution** — worst case
with six agents up, two of which sit in identically-named spaces (two `hermes`
worktrees), where even the per-project voice can't disambiguate them.

The hook now marks the speaking pane via `herdr pane report-metadata`. This is a
better primitive than `rename-window`, for two reasons:

- **Layered per `--source`.** The `speak-summary` layer sits on top of herdr's own
  `herdr:claude` layer rather than overwriting it, and clearing ours reveals what
  was underneath. Nothing to snapshot, nothing to restore — contrast the tmux path,
  which has to save/restore both the window name *and* `automatic-rename`.
- **`--ttl-ms` is a dead-man's switch.** The mark expires by itself. A hook killed
  between mark and clear cannot strand a `🔊` the way rename/restore could. The
  explicit clear is the normal path; the ttl is sized to `lead + audio + lag + 3 s`
  and only ever fires if we die. `speak-summary-baseline.sh` sweeps the pane once
  more on `UserPromptSubmit` (before its own transcript guard, so it fires even on
  the bail-out paths) — belt and braces.

What you see: a single `🔊` appended to that pane's row in the agent panel.

**One field, not two.** The panel renders a row as
`<space label>` / `<state> · <display_agent> · <custom_status>`, so setting both
printed the emoji twice and repeated the space label right below itself:

```
hermes                            hermes
done · 🔊 claude · 🔊 hermes  ->   done · claude · 🔊
```

`custom_status` is the right field — it exists for exactly this kind of ephemeral
status, whereas `display_agent` exists to *rename* the agent (and using it would
hardcode the name `claude`). The clear still clears `display_agent` too, to sweep
marks left behind by the two-field version. **`custom_status` is hard-truncated at
32 chars server-side**; moot for a one-emoji mark, but it rules out ever putting
the spoken sentence there.

The mark **leads** the audio by `SPEAK_MARK_LEAD` (0.6 s) and **lingers**
`SPEAK_MARK_LAG` (1.5 s) past it, so your eye lands on the space before the voice
starts and can still find it once the voice stops. Both waits sit *inside* the
`flock`, which is what keeps "exactly one 🔊 on screen" true. The emoji itself is
`SPEAK_MARK` (default `🔊`).

- **`prefix+o` → [`herdr/speak-focus.py`](../herdr/speak-focus.py)** jumps to the
  space that is speaking, or — once it has fallen silent — the one that spoke last
  (from `~/.claude/speak-summary-speaker`, rewritten under the lock, so last-writer
  really is the last speaker). This supersedes `SPEAK_FOCUS=on` under herdr: focus
  stays where you put it and you chase the voice only when you want to. `SPEAK_FOCUS=on`
  still works (it calls `herdr workspace focus`) if you want the old teleport.
- **Not herdr's own `open_notification_target`**, which is what `prefix+o` does by
  default. That action jumps to the target of herdr's *last notification*, and the
  target is set by herdr's internal agent-state notifications. `notification.show`
  — the only notification a CLI can raise — takes `title`/`body`/`position`/`sound`
  and **no target at all**, so a toast fired by this hook could never aim the key.
  The config unbinds it (`open_notification_target = ""`) and rebinds `prefix+o`
  to the script. (`[ui.toast] delivery` is off here anyway, so the key was dead.)

> **Editing warning.** The playback block is a single-quoted string passed to
> `setsid bash -c '…'`. A lone `'` anywhere inside it — an `awk '{…}'` program, an
> `''` empty-string `case` pattern — **ends the quote** and spills the remainder
> into the outer shell. `bash -n` still passes; it fails at runtime with something
> unrelated-looking like `$1: unbound variable`. Keep that block free of single
> quotes: float→ms conversion happens in the outer script (`SPK_LEAD_MS`,
> `SPK_LAG_MS`) precisely so the inner block needs no `awk`.

### Why the two-hook / uuid / poll dance

Two transcript-timing bugs forced this design, both now fixed:
- **Flush race:** the final 🗣️ line lands in the transcript JSONL a beat *after*
  the Stop hook fires → the poll waits for it instead of reading once.
- **Repeat-previous-answer:** during that window the newest marker in the file is
  the *previous* answer's. Matching only lines that **start** with 🗣️ (not inline
  mentions) plus the **uuid baseline** set at prompt-submit means the old summary
  is recognised as already-spoken and skipped — never re-played.

## Logging / tracing

Both hooks append to `~/.claude/speak-summary.log` (tags `[baseline]` and
`[stop:<sid>]`). A healthy turn looks like:
```
… [baseline] session=2638ff16 baseline(prev summary uuid)=<uuidA>
… [stop:2638ff16] FIRED
… [stop:2638ff16] baseline prev_uuid=<uuidA>
… [stop:2638ff16] match uuid=<uuidB> after 3 polls
… [stop:2638ff16] speaking (uuid=<uuidB>, lang=en, engine=kokoro, voice=bf_emma): <the sentence>
… [stop:2638ff16] ok: engine=kokoro voice=bf_emma (detached, serialized)
```
Skips log the reason + `prev_uuid`/`last_seen` so an off-by-one or missed flush is
diagnosable. `tail -f ~/.claude/speak-summary.log` to watch live.

## Files

These live in `~/.claude/` as **real files** (NOT symlinked from this repo —
unlike `.zshrc` etc.), so they are vendored here as reference copies:

| Real path | This repo's copy |
|---|---|
| `~/.claude/hooks/speak-summary.sh` (Stop) | `audio/speak-summary.sh` |
| `~/.claude/hooks/speak-summary-baseline.sh` (UserPromptSubmit) | `audio/speak-summary-baseline.sh` |
| `~/.claude/hooks/tts-kokoro.py` (English synth wrapper) | `audio/tts-kokoro.py` |
| `~/.claude/hooks/tts-silero.py` (Russian synth wrapper) | `audio/tts-silero.py` |
| `~/.claude/CLAUDE.md` (the 🗣️ instruction block) | quoted in that file |
| `~/.claude/settings.json` → `hooks.Stop[]` + `hooks.UserPromptSubmit[]` | snippets below |

`herdr/speak-focus.py` is the exception: it is **not** a hook, and **not**
symlinked. `~/.config/herdr/config.toml` (which *is* symlinked) calls it by
absolute repo path from a `[[keys.command]]`, same pattern as
`herdr/move-space.py` and `tmux/claude-spinner.sh`. Clone to `~/gits/dot_files`
and it works. Generated state that stays local: `~/.claude/speak-summary-speaker`
(the last speaker, for `prefix+o`), `~/.claude/speak-summary.lock`,
`~/.claude/speak-summary-state/`.

`settings.json` entries:
```json
// hooks.Stop[]
{ "hooks": [ { "type": "command",
  "command": "bash /home/fedouser/.claude/hooks/speak-summary.sh", "timeout": 25 } ] }
// hooks.UserPromptSubmit[]
{ "hooks": [ { "type": "command",
  "command": "bash /home/fedouser/.claude/hooks/speak-summary-baseline.sh", "timeout": 10 } ] }
```

## No API key needed

All three engines run entirely locally — there is nothing to authenticate and
nothing secret to keep out of this repo. (The old Inworld key at
`~/.config/credentials/inworld_api_key` is no longer used by the active hook.)

## Enable / disable (precedence: env → project → global → default ON)

```sh
echo off > ~/.claude/speak-summary            # off globally (echo on / rm to re-enable)
echo off > <project>/.claude/speak-summary    # off for one project (overrides global)
SPEAK_SUMMARY=off claude                       # off for one session
```

Playback-coordination knobs (see "Cross-session serialization" above):

```sh
SPEAK_MAX_WAIT=25 claude     # drop summaries queued behind others longer than N s (default 25)
SPEAK_FOCUS=on claude        # also jump focus to the speaking tmux window / herdr space (default off)
SPEAK_MARK=🔊 claude          # the marker emoji (default 🔊)
SPEAK_MARK_LEAD=0.6 claude   # seconds the marker appears BEFORE the audio (default 0.6)
SPEAK_MARK_LAG=1.5 claude    # seconds the marker lingers AFTER the audio (default 1.5)
```

## Change / pin voices

- Defaults + pools: edit `DEFAULT_VOICE`/`VOICE_POOL` (English, Kokoro) and
  `DEFAULT_VOICE_RU`/`VOICE_POOL_RU` (Russian, Silero) at the top of
  `speak-summary.sh`.
- Pin one project: `echo af_heart > <project>/.claude/speak-voice` and/or
  `echo baya > <project>/.claude/speak-voice-ru`.
- One session: `SPEAK_VOICE=bm_george SPEAK_VOICE_RU=aidar claude`.
- Kokoro voice list: see `VOICES.md` in the `hexgrad/Kokoro-82M` HF repo (all
  ~28 English voices ship inside `voices-v1.0.bin`, nothing to download).
  Silero v5_ru speakers: aidar, baya, kseniya, eugene, xenia.
- Piper voices (fallback only): `~/tts/bin/python -m piper.download_voices
  <name>` (lands in `~/tts-voices/`), then reference it by its `en_GB-…` name.

## Reproduce on a new machine

1. Create the engine venvs (use `--managed-python` so the venvs link to a uv
   standalone build in `$HOME`, not `/usr/bin` — see "Why `--managed-python`"
   above; a system-Python venv dies on the next OS major upgrade). The torch
   `--index-url …/cpu` matters: the default wheel drags in ~2.5 GB of CUDA.
   ```sh
   uv python install 3.12
   # English — Kokoro
   uv venv ~/tts-kokoro --managed-python --python 3.12
   uv pip install --python ~/tts-kokoro/bin/python kokoro-onnx soundfile
   # Russian — Silero (torch CPU-only)
   uv venv ~/tts-silero --managed-python --python 3.12
   uv pip install --python ~/tts-silero/bin/python torch --index-url https://download.pytorch.org/whl/cpu
   uv pip install --python ~/tts-silero/bin/python soundfile numpy scipy
   # Fallback — Piper (optional but recommended)
   uv python install 3.14
   uv venv ~/tts --managed-python --python 3.14
   uv pip install --python ~/tts/bin/python piper-tts
   ```
2. Download the models:
   ```sh
   mkdir -p ~/tts-models/kokoro ~/tts-models/silero
   cd ~/tts-models/kokoro
   curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
   curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
   curl -L -o ~/tts-models/silero/v5_ru.pt https://models.silero.ai/models/tts/ru/v5_ru.pt
   # Piper fallback voice:
   mkdir -p ~/tts-voices && cd ~/tts-voices
   ~/tts/bin/python -m piper.download_voices en_GB-alba-medium
   ```
3. Copy the scripts and mark executable:
   ```sh
   cp audio/speak-summary.sh audio/speak-summary-baseline.sh \
      audio/tts-kokoro.py audio/tts-silero.py ~/.claude/hooks/
   chmod +x ~/.claude/hooks/speak-summary*.sh ~/.claude/hooks/tts-*.py
   ```
4. Add the `hooks.Stop[]` **and** `hooks.UserPromptSubmit[]` entries above to
   `~/.claude/settings.json`.
5. Add the 🗣️ instruction (including the language rule: summary in the
   conversation's language, Russian or English) to `~/.claude/CLAUDE.md`.
6. Ensure `jq`, `ffmpeg`/`ffplay`, `git` are installed. **Restart** Claude (hooks
   load at session start).
