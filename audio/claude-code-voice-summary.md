# Claude Code spoken answer summaries (local Piper TTS)

Set up 2026-05-24. Makes Claude Code **speak a one-sentence summary of each
answer** out loud, using a **local, offline Piper TTS model** (CPU only — no
GPU, no cloud, no API key). Output-side companion to the mic notes in this
folder's `README.md`.

Originally built on Inworld's cloud TTS; switched to local Piper on 2026-05-24
(favorite voice `en_GB-alba-medium`). The old Inworld version is kept as
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
4. It picks a voice (see below), then **synthesizes + plays detached**: a
   `setsid` subshell runs `python -m piper -m <voice>.onnx -f <tmp>.wav -- "<text>"`
   and plays the WAV with `ffplay`, so the prompt is never blocked by the ~3–5 s
   CPU synthesis. Every error path exits 0 → can never block or break a session.

### TTS engine — local Piper

- Engine: [`piper-tts`](https://pypi.org/project/piper-tts/) (OHF-Voice
  piper1-gpl), CPU-only ONNX VITS. ~7× faster than real-time on the i7-1355U.
- Installed in a dedicated venv: `~/tts/` (`~/tts/bin/python -m piper …`).
  Recreate with `uv venv -p 3.13 ~/tts && uv pip install --python ~/tts/bin/python piper-tts`.
- Voice files (`<name>.onnx` + `<name>.onnx.json`, ~60 MB each) live in
  `~/tts-voices/`. Download more with
  `~/tts/bin/python -m piper.download_voices <name>` (browse names at the
  HuggingFace `rhasspy/piper-voices` repo).
- License: Piper is GPL-3.0-or-later; voices are mostly permissive (per-voice).

### Per-project voices

Each git project speaks in **its own voice** so you can tell by ear which
project is talking. Resolution precedence (first match wins):

1. **env** `SPEAK_VOICE=<name>` — per shell/session.
2. **project file** `<cwd>/.claude/speak-voice` — a single voice name. Pin a
   project to a specific voice this way.
3. **auto** — if `cwd` is inside a **git repo**, a deterministic voice is chosen
   from `VOICE_POOL` by `cksum` of the repo's toplevel path (same repo → same
   voice every time). If **not** in a repo, `DEFAULT_VOICE` is used.

`DEFAULT_VOICE="en_GB-alba-medium"` (the favorite). `VOICE_POOL` is a mix of
gender + US/GB accents for easy differentiation; edit both at the top of
`speak-summary.sh`. If a resolved voice file is missing it falls back to
`DEFAULT_VOICE`. Any voice you reference must exist in `~/tts-voices/`.

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
… [stop:2638ff16] speaking (uuid=<uuidB>, voice=en_GB-alba-medium): <the sentence>
… [stop:2638ff16] ok: piper voice=en_GB-alba-medium (detached)
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
| `~/.claude/CLAUDE.md` (the 🗣️ instruction block) | quoted in that file |
| `~/.claude/settings.json` → `hooks.Stop[]` + `hooks.UserPromptSubmit[]` | snippets below |

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

Piper runs entirely locally — there is nothing to authenticate and nothing
secret to keep out of this repo. (The old Inworld key at
`~/.config/credentials/inworld_api_key` is no longer used by the active hook.)

## Enable / disable (precedence: env → project → global → default ON)

```sh
echo off > ~/.claude/speak-summary            # off globally (echo on / rm to re-enable)
echo off > <project>/.claude/speak-summary    # off for one project (overrides global)
SPEAK_SUMMARY=off claude                       # off for one session
```

## Change / pin voices

- Default + pool: edit `DEFAULT_VOICE` and `VOICE_POOL` at the top of
  `speak-summary.sh`.
- Pin one project: `echo en_US-ryan-high > <project>/.claude/speak-voice`.
- One session: `SPEAK_VOICE=en_GB-cori-high claude`.
- Add a voice: `~/tts/bin/python -m piper.download_voices <name>` (lands in
  `~/tts-voices/`), then reference it.

## Reproduce on a new machine

1. Create the Piper venv and install the engine:
   ```sh
   uv venv -p 3.13 ~/tts
   uv pip install --python ~/tts/bin/python piper-tts
   ```
2. Download the voices you want into `~/tts-voices/`:
   ```sh
   mkdir -p ~/tts-voices && cd ~/tts-voices
   for v in en_GB-alba-medium en_GB-northern_english_male-medium en_US-amy-medium \
            en_US-ryan-high en_GB-cori-high en_US-joe-medium en_US-kristin-medium \
            en_US-hfc_male-medium; do ~/tts/bin/python -m piper.download_voices "$v"; done
   ```
3. Copy both scripts and mark executable:
   ```sh
   cp audio/speak-summary.sh audio/speak-summary-baseline.sh ~/.claude/hooks/
   chmod +x ~/.claude/hooks/speak-summary*.sh
   ```
4. Add the `hooks.Stop[]` **and** `hooks.UserPromptSubmit[]` entries above to
   `~/.claude/settings.json`.
5. Add the 🗣️ instruction to `~/.claude/CLAUDE.md`.
6. Ensure `jq`, `ffmpeg`/`ffplay`, `git` are installed. **Restart** Claude (hooks
   load at session start).
