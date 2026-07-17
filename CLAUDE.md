# Dot Files Notes

Context for future sessions working on this dotfiles repo.

## System

- **OS:** Fedora 42
- **WM:** i3 (config at `./config`, deployed as `~/.config/i3/config`)
- **Bar:** polybar 3.7.2 (config at `./polybar/`)
- **Terminal editor:** neovim (gruvbox theme, `./init.vim`)
- **Multiplexer:** tmux (gruvbox-themed status bar with session pill + clock, `./.tmux.conf`, symlinked to `~/.tmux.conf`)
- **Shell:** zsh (`./.zshrc`)
- **Font:** JetBrainsMono Nerd Font (installed at `~/.local/share/fonts/JetBrainsMonoNF/`)

## Aesthetic

Gruvbox Dark Hard palette everywhere. Minimal — no clutter, no decorative modules
in polybar/rofi. Tmux is the one place that *does* carry gruvbox styling in the
status bar (session pill + window list + clock) since the extra info earns its spot
in an always-visible bar.

## Polybar

- Bar name: `main` (not the default `example`)
- Modules: `xworkspaces | (center) date | psi load ram disk temp headphones pulseaudio net vpn battery`
- Icons from JetBrainsMono Nerd Font
- **System health philosophy (rebuilt 2026-05-15):** the previous `cpu` + `memory`
  modules were ambient-noise — they turned red above 80% just because the box was
  busy with browsers and AI agents, training the eye to ignore the alert. They've
  been replaced with four modules that only fire when something is actually
  *actionable*:
  - `polybar/psi.sh` — hidden by default. Reads `/proc/pressure/{io,memory,cpu}`
    (Linux PSI: tasks actually being stalled). Fires red on `io full avg60 >= 10`,
    `memory full avg60 >= 5`, or `cpu some avg60 >= 30`. Priority order IO → MEM →
    CPU, showing only the worst. **This is the signal that means "your machine is
    grinding, look at it" — much sharper than aggregate CPU%.**
  - `polybar/load.sh` — `load5 / nproc` ratio. Foreground <0.7, yellow 0.7–1.0,
    red ≥1.0. Independent of iowait, so it shows true CPU contention.
  - `polybar/ram.sh` — working-set used %, computed as
    `(MemTotal − MemAvailable) / MemTotal`. This excludes buff/cache (Linux
    happily reclaims it), so it reflects what apps actually hold rather than
    the misleading "80% used" the old `internal/memory` module always reported.
    Foreground <70, yellow 70–85, red ≥85.
  - `polybar/disk.sh` — `/` used %. Foreground <70, yellow 70–90, red ≥90.
    Uses `/usr/bin/df` because `df` is aliased to `duf` in `.zshrc`.
  - `polybar/temp.sh` — first available `x86_pkg_temp` / `coretemp` / `TCPU`
    thermal zone. Foreground <75°C, yellow 75–85, red ≥85.
- Net module uses `polybar/net.sh` — prefers wired link when an ethernet
  interface has an IPv4 address, falls back to wireless, else ` offline`.
  Shows `<icon> <ip>  󰇚 <down>  󰕒 <up>` with a 2s sample. Interface detection
  is auto (skips lo, docker*, br-*, veth*, tun*, tailscale*, wg*, virbr*).
- VPN module uses `polybar/vpn.sh` — detects tailscale then wireguard (see `polybar/SETUP.md`)

## Rofi (launcher)

- Installed 2026-04-13. Replaces dmenu as `$mod+d` launcher.
- Configs in `./rofi/` (`config.rasi` + `gruvbox-dark.rasi` theme, matches polybar)
- Modes: `drun` (GUI apps), `run` (any `$PATH` binary), `window` (focus existing)
- Only GUI apps with `.desktop` files show in `drun`. Manually-installed ones
  (like qutebrowser at `/usr/local/bin/qutebrowser`) need a desktop entry —
  see `./applications/qutebrowser.desktop` for the pattern.

## Screenshots (flameshot) — READ THIS FIRST IF IT "TAKES THE WRONG SCREEN"

`$mod+Shift+s` / `$mod+Shift+a` → `flameshot gui`.

**If flameshot captures the wrong screen / black / another monitor: do NOT debug
flameshot. It is the display layout.** Three commands, in this order:

```
xrandr --listmonitors     # is SOME monitor at +0+0? is the bounding box cleanly tiled?
autorandr --current       # prints nothing => layout matches NO profile => this is it
autorandr --load docked   # the fix
```

Diagnosed 2026-07-17, after an afternoon spent debugging the wrong layer. The layout
was visible in the very first `xrandr` and got treated as a given instead of a
suspect. Don't repeat that.

- **What actually fires it: eDP-1 ON while the lid is shut.** logind's
  `HandleLidSwitchDocked=lock` (`./logind/lid.conf`) only *locks* — it never powers the
  panel off, and the `docked` autorandr profile that does (`output eDP-1 off`) does not
  always get applied. With eDP-1 live at `+0+1320` both externals get shoved to
  `x=1920`, the root window becomes 4480x2520 with a **dead 1920x1320 corner at the
  origin**, and **nothing sits at (0,0)** → every screen captures wrong. Correct docked
  layout: DP-3-1 `+0+0`, DP-3-2 `+0+1080`, eDP-1 off, root 2560x2520 fully tiled.
- **Why the layout matters:** flameshot 13.3.0 + Qt6 only computes screen geometry
  correctly when a monitor is at `(0,0)`. Qt6 changed grab semantics and flameshot's
  per-screen path crops with *global* desktop coords inside a *screen-local* image —
  valid region is `(W − origin_x) × (H − origin_y)`, the rest is black. Upstream, open,
  spans v12–v14 (flameshot-org/flameshot#4043, #4155, #4337).
- **Timeline:** Qt6 arrived with the **F42→F44 upgrade on 2026-06-08** (`fedora-release`
  and `qt6-qtbase-6.11.1` installed 57 seconds apart — the same upgrade that broke the
  i3lock theming). That *armed* the bug; it stayed invisible for a month until the
  layout drifted. Not the kernel (kernels moved 3x after, and maim/`flameshot full` are
  fine on the same one).
- **`flameshot gui` — what the keys use — works in the correct layout**, because it
  grabs the whole root with no per-screen crop. `flameshot full` always worked, same
  reason. `flameshot screen` stays broken on any monitor not at the origin even when
  docked (DP-3-2 at `+0+1080` → 75% black); that's upstream's bug, not worth chasing.
- **Ruled out — do not retry:** restarting the daemon (`flameshot gui` only D-Bus-pings
  the existing one — which is why "kill and restart" never helps, and D-Bus re-activates
  it from `/usr/share/dbus-1/services/`); Qt HiDPI env vars (`QT_ENABLE_HIGHDPI_SCALING`
  is Qt5-only, ignored by Qt6; every scaling var gave byte-identical breakage despite the
  162/96/122 DPI spread); xrandr transforms (all identity); **rebuilding Fedora's SRPM
  against matching Qt 6.11.1** (reproduces the bug exactly — it is *not* an ABI mismatch,
  despite the binary reporting "Compiled with Qt 6.10.1"); **the flatpak** (v14 captures
  via xdg-desktop-portal, which cannot start under i3 — `graphical-session.target` never
  activates and the GTK backend delegates to GNOME Shell; it also hijacks flameshot's
  D-Bus name and breaks the working `full`); **building v13 against Qt5** (v13 is Qt6-only
  in C++ — `QStringDecoder`, `QEnterEvent` overrides; only v12 had a Qt5 build).
- **Layout automation (fixed 2026-07-17 — this is what stops it recurring):** nothing
  used to re-apply a profile, so a drifted layout stayed drifted forever. Now covered on
  all four paths:
  - **session start** — `exec_always --no-startup-id autorandr --change` in `./i3/config`.
    `exec_always`, so `$mod+Shift+R` re-applies it; it's a no-op when the profile already
    matches (autorandr skips a profile that is already `(current)`), so no flicker.
  - **dock/undock** — `/usr/lib/udev/rules.d/40-monitor-hotplug.rules` runs
    `systemctl start autorandr.service` on any DRM change. This works even though the
    unit reads "disabled" — an explicit `start` ignores the enable state.
  - **lid open/close** — `autorandr-lid-listener.service` (**enabled by hand**). A lid
    toggle is *not* a DRM hotplug — eDP-1 stays `connected` either way — so udev never
    fires and this unit is the only thing that can catch it. It was disabled, which is
    exactly how eDP-1 stayed lit behind a shut lid.
  - **resume from sleep** — `autorandr.service` (**enabled by hand**, `WantedBy=sleep.target`).

  Both units are *system* units enabled manually — not tracked here, so re-enable them on
  a fresh machine (see Bootstrap).
- **Consequence worth knowing:** autorandr matches profiles by the EDIDs of *connected*
  outputs, which are identical whether the lid is open or shut. So while docked, opening
  the lid will **not** light up eDP-1 — `docked` says `output eDP-1 off`, and that is what
  gets re-applied. Intended here, and the reason the layout is now stable.
- **Ground truth for testing:** `maim -u -g WxH+X+Y` captures correctly on every layout.
  Compare against it instead of eyeballing — a broken flameshot grab is mostly black, and
  the black % pins the origin arithmetic exactly (6.25% ⇒ origin `+1920+1080`, 75% ⇒ one
  axis off). Structural metrics (NCC/RMSE) misled repeatedly here; look at the image.

### ksnip (installed 2026-07-17, fallback)

Qt5, so structurally immune to the Qt6 regression — captures correctly *even in the
broken layout*. Kept installed as a fallback; **not bound to any key**. `ksnip -r` =
region select → editor. `~/.config/ksnip/ksnip.conf` is **not tracked** (ksnip rewrites
it on exit, mixing settings with generated state). Settings that matter, under
`[Application]`: `AutoCopyToClipboardNewCaptures=true`, `UseTrayIcon=false` +
`MinimizeToTray`/`CloseToTray`/`StartMinimizedToTray=false` (**no systray on this box** —
with the tray on ksnip hangs invisibly), `UseSingleInstance=false` (otherwise a stale
instance silently swallows the CLI flags and the keybinding no-ops). Plus
`[ImageGrabber] CaptureCursor=false`.

## Obsidian Sync (headless)

Vault `~/Documents/knowledge/` (remote vault `knowledge`, id
`afea1e3f01942dce3cc2a06afd6631bb`) stays continuously synced via
[`obsidian-headless`](https://github.com/obsidianmd/obsidian-headless) — the
official `ob` CLI from Obsidian (npm package, requires Node 22+). Runs as a
systemd **user** service so sync continues whenever the user is logged in,
GUI Obsidian closed or not. Bidirectional, conflict-strategy=`merge`,
device-name=`fedora-main`. Auth lives in the GNOME keyring (Secret Service)
once `ob login` has been run interactively.

- Wrapper: `./obsidian/sync.sh` — sources nvm before `exec ob sync --continuous`
  so the service finds `ob` regardless of which Node version is current.
- Service: `./systemd/user/obsidian-sync.service` — symlinked to
  `~/.config/systemd/user/obsidian-sync.service`. `Restart=on-failure`,
  `RestartSec=10s`, `StartLimitBurst=5/300s` to back off if auth breaks.
- **desk24** also runs `obsidian-headless` continuously in `bidirectional` mode
  (set up 2026-05-06). Wrapper + unit live directly on desk24 at
  `~/.local/bin/obsidian-sync.sh` and `~/.config/systemd/user/obsidian-sync.service`
  (vault path there is `~/Obsidian/`, not the laptop's `~/Documents/knowledge/`,
  hence no shared dotfiles for that piece).
- **Recovery convention** (when a machine has been offline long enough that
  local files have drifted from remote — e.g. desk24 had a 15-day gap on
  2026-05-06): tar a backup of the local vault, flip to `mirror-remote`
  for ONE pass to overwrite local with remote (`ob sync-config --mode
  mirror-remote && ob sync`), verify, then flip back to `bidirectional`
  and restart the service. Do not leave a regularly-used machine on
  `mirror-remote` permanently — local edits there get silently reverted.

Tail the journal: `journalctl --user -u obsidian-sync.service -f`.

## Audio & Voice

Full notes live in `./audio/` — this is just the map.

- **Input (dictation):** USB condenser mic (MUSIC-BOOST MB-306) → **openwhispr**
  (Groq Whisper backend) for speech-to-text. Gain tuning, port/dock quirks, and
  the mute-button gotcha are documented in `audio/README.md`. Mic gain is **not**
  persisted across reboot — re-apply by hand if dictation starts missing words.
- **Output (spoken answer summaries):** Claude Code **speaks a one-sentence
  summary after every answer**, using **local, offline TTS models** (CPU only,
  no GPU, no API key). Set up 2026-05-24 (Inworld cloud → local Piper same
  day); **upgraded 2026-06-11 to Kokoro-82M for English + Silero v5 for
  Russian** (better naturalness; Russian gets correct ударение). Full design
  in `audio/claude-code-voice-summary.md`. In short:
  - Claude ends substantive answers with a `🗣️ <≤16-word summary>` line, **in
    the conversation's language — Russian or English** (instructed in
    `~/.claude/CLAUDE.md`). Two hooks
    (`audio/speak-summary-baseline.sh` on `UserPromptSubmit`,
    `audio/speak-summary.sh` on `Stop`) detect the new 🗣️ line, route it by
    script (Cyrillic → Silero, else Kokoro, Piper only as fallback) via the
    `audio/tts-kokoro.py` / `audio/tts-silero.py` wrappers, played detached
    with `ffplay`. Fails silent (always exits 0) so it can never block a
    session.
  - **No-overlap (added 2026-05-29):** playback is serialized across all
    sessions via a global `flock` so simultaneous finishers take turns instead
    of speaking over each other (stale ones queued >`SPEAK_MAX_WAIT`=25s are
    dropped), and the **tmux window of the talking answer is marked** (`🔊 ` name
    prefix + status banner) so you can see which one it is. `SPEAK_FOCUS=on`
    also jumps focus to it. Full design in `audio/claude-code-voice-summary.md`.
  - **Which space is talking, under herdr (added 2026-07-09):** there is no
    `$TMUX` in herdr, so the tmux marker above silently no-ops and summaries used
    to play with zero visual attribution — bad with six agents up, two of them in
    identically-named `hermes` spaces where even the per-project voice can't tell
    you which is which. The Stop hook now marks the speaking pane with
    `herdr pane report-metadata`, setting **`custom_status` = `🔊` and nothing
    else**. The panel renders a row as `<state> · <display_agent> · <custom_status>`,
    so setting both fields printed the emoji twice (`done · 🔊 claude · 🔊 hermes`)
    and repeated the space label above it; `custom_status` is the field meant for
    ephemeral status, while `display_agent` is for *renaming* the agent. Better
    than `rename-window` on two counts: metadata is **layered
    per `--source`** (our layer never clobbers herdr's own `herdr:claude` one, and
    clearing reveals it again — nothing to snapshot/restore), and **`--ttl-ms` is a
    dead-man's switch**, so a hook killed mid-playback cannot strand a `🔊`.
    `custom_status` is **hard-truncated at 32 chars** server-side. The mark leads
    the audio by `SPEAK_MARK_LEAD` (0.6s) and lingers `SPEAK_MARK_LAG` (1.5s) past
    it — both waits *inside* the flock, which is what keeps "exactly one 🔊 on
    screen" true. **`prefix+o` → `herdr/speak-focus.py`** jumps to the speaking
    space, or the last one to speak; it replaces `SPEAK_FOCUS=on` as the way to
    chase a voice. **Editing hazard:** the playback block is a single-quoted
    `setsid bash -c '…'` string — a lone `'` inside it (an `awk '{…}'`, an `''`
    case pattern) ends the quote and spills into the outer shell; `bash -n` passes
    and it fails at runtime as `$1: unbound variable`. Keep that block quote-free.
  - **Engines:** Kokoro in venv `~/tts-kokoro/` (model in `~/tts-models/kokoro/`,
    ~340 MB), Silero in `~/tts-silero/` (CPU torch; model
    `~/tts-models/silero/v5_ru.pt`, ~140 MB), legacy Piper fallback in `~/tts/`
    + `~/tts-voices/`. A one-liner synthesizes in ~4–5 s either language.
  - **Per-project voices (per language):** each git repo gets its own
    deterministic voice in each language (so you can tell by ear which project
    is talking); non-repo dirs use `bf_emma` (EN) / `xenia` (RU). Override with
    `SPEAK_VOICE=` / `SPEAK_VOICE_RU=` or `<project>/.claude/speak-voice` /
    `speak-voice-ru` files. Pools + defaults are edited at the top of
    `speak-summary.sh`; voice names imply the engine (old Piper pins still work).
  - **Toggle:** `echo off > ~/.claude/speak-summary` (global), per-project file,
    or `SPEAK_SUMMARY=off claude` (session).
- **Not symlinked:** like the tmux-agent-indicator hooks, the hook scripts
  (`speak-summary*.sh`, `tts-kokoro.py`, `tts-silero.py`) are **real files** in
  `~/.claude/hooks/` (vendored here as reference copies), and the venvs/models
  in `~/tts*/` + `~/tts-models/` + `~/tts-voices/` are not in the repo. See
  `audio/claude-code-voice-summary.md` → "Reproduce on a new machine" for the
  rebuild steps.

## herdr (agent multiplexer)

Installed 2026-07-09, v0.7.3, pinned by hand from the GitHub release (**not**
the `curl | sh` installer). Config at `./herdr/config.toml` — **symlinked** to
`~/.config/herdr/config.toml`. Its own header comments carry the full rationale
for every setting; the notes below are only what the config can't say about
itself.

**Model.** A *space* (the CLI/socket API calls it a `workspace`) contains tabs,
which contain panes. The sidebar's *agents* section is not a container — it's an
index of panes where herdr detected an AI agent, each entry pointing back at a
`pane_id`/`tab_id`/`workspace_id`. With `agent_panel_sort = "priority"` that
list re-sorts to blocked → done → working → idle, which makes `prefix+a` a
triage queue rather than a directory walk.

**Keys mirror `.tmux.conf`** so there is nothing to relearn, with four
deliberate exceptions, all documented inline in `config.toml`. The theme of all
four: **the cheap keys index spaces, not tabs**, because the space is the unit
of work here (one repo / one project) and tabs are barely used.

- `prefix+c` makes a new **space**, not a new tab (new tab moved to `prefix+t`).
  tmux's `prefix c` = new-window is the muscle memory being broken.
- `prefix+,` renames the **space**, not the tab (tmux's `prefix ,` =
  rename-window). Tab rename keeps herdr's stock `prefix+shift+t`. Unlike
  `workspace.move`, this needed no script: `rename_workspace` *is* a real key
  action (stock `prefix+shift+w`, kept as an alias) — it was simply never bound
  to the key the fingers reach for.
- `prefix+1..9` jumps to **space** N; tabs move to `prefix+shift+1..9`. In tmux
  `prefix <n>` selects a window (= a herdr tab). Note `prefix+1..9` indexes the
  sidebar *order*, which is exactly what `move-space.py` rearranges.
- `prefix+shift+j` / `prefix+shift+k` move the focused space down/up, borrowed
  from qutebrowser's move-tab. In tmux the same chord is `resize-pane` — the one
  place the two tools disagree.

**`herdr/move-space.py`** exists because herdr has no `move_workspace` key action
and no `herdr workspace move` CLI subcommand: reordering is reachable *only* as
the raw socket method `workspace.move`. A `[[keys.command]]` entry
(`type = "shell"`) shells out to it. Referenced by absolute repo path from
`config.toml`, same as `tmux/claude-spinner.sh`, so it needs no Bootstrap symlink.

**`herdr/speak-focus.py`** (`prefix+o`) jumps to the space whose Claude summary is
speaking — or, once it's silent, the one that spoke last. It reads the `🔊` mark
that the Stop hook writes via `pane.report_metadata` (see Audio & Voice), falling
back to `~/.claude/speak-summary-speaker`. Same absolute-path `[[keys.command]]`
pattern as `move-space.py`. It does **not** use herdr's stock `prefix+o`
(`open_notification_target`), which jumps to the target of the last *notification*:
that target is set by herdr's internal agent-state notifications, and
`notification.show` — the only notification a CLI can raise — takes
`title`/`body`/`position`/`sound` and **no target**, so an externally-fired toast
can never aim it. `config.toml` unbinds it (`open_notification_target = ""`) and
takes the key. (`[ui.toast] delivery` is off anyway, so the key was dead.)

`workspace.move`'s `insert_index` is **0-based against the list as it currently
is** — "put this space where the space now at `insert_index` sits". Because
removing the space shifts everything after it left by one, a *downward* move
needs `target + 1` while an upward move needs plain `target`. Passing `target`
for a downward move is a **silent no-op, not an error**. This is the whole
reason the script is 60 lines and not 5.

**Validation.** `herdr server reload-config` returns
`{"status": "applied", "diagnostics": []}` on success and `"status": "partial"`
with a diagnostics array on a bad key. Trust the diagnostics — a silent
`applied` really does mean the binding took. Beware the failure mode: an invalid
key **disables that one binding** (`invalid keybinding: keys.switch_tab = "…";
disabling binding`) rather than refusing the reload, so a typo costs you a key
silently unless you read `diagnostics`.

**Updates are deliberate.** `version_check` and `manifest_check` are both off;
`herdr update` would `rename(2)` a new binary over `~/.local/bin/herdr` with TLS
as its only integrity check, since the manifest ships no sha256 for unix assets.
Re-download the pinned release and verify the hash by hand.

## Layout

- **i3 config:** `./i3/config` — **symlinked** to `~/.config/i3/config`. `./i3/lock.sh` is **symlinked** to `~/.config/i3/lock.sh`. lock.sh deliberately does **not** touch DPMS — earlier versions scheduled `xset dpms force standby` 30s after locking, but that fed an infinite loop: forcing DPMS-standby fires the XSS screen-saver-activate callback, which xss-lock interprets as a fresh lock trigger and re-runs lock.sh. The `pgrep -x i3lock` re-entry guard isn't enough because i3lock can briefly exit between the cycles. Screen stays on while locked; press any key to wake the i3lock UI if it sleeps via the monitor's own power-save. **lock.sh is i3lock-variant-aware (since the Fedora 44 upgrade):** F44 swapped the `i3lock-color` fork for vanilla upstream `i3lock` 2.16, which rejects every themed flag (`--clock`, `--ring-color`, `--time-str`, …) and so silently failed to lock. lock.sh now probes `i3lock --help` for `--clock`: present → full gruvbox theme (clock + ring); absent → minimal `-n -e -f -i -t -c` set that still locks with the blurred screenshot, just no clock/ring overlay. It auto-upgrades back to the themed branch the moment `i3lock-color` is reinstalled — no edit needed. To restore the full theme, reinstall `i3lock-color` (not in F44 main repos or the enabled coprs; build from `Raymo111/i3lock-color` or a F44 copr). The image pipeline also prefers ImageMagick 7's `magick` over the legacy `convert` shim. Lid-close behavior is handled entirely by logind via `./logind/lid.conf`, **copied** (not symlinked) to `/etc/systemd/logind.conf.d/lid.conf`. Symlink doesn't work here: SELinux confines `systemd-logind` to `systemd_logind_t`, which can't traverse `user_home_dir_t` (your `0700` home dir) to follow a symlink into the repo. Copy gets the correct `systemd_conf_t` context automatically. Re-deploy after editing the repo file with the `logind` row in the Deploy table. Per `logind.conf(5)`, when more than one display is connected (`/sys/class/drm/*/status`) logind uses `HandleLidSwitchDocked=` regardless of ACPI dock state — so the USB-C/TB "not classified docked" issue is moot as long as external monitors are attached. Drop-in sets `HandleLidSwitchDocked=lock`: docked → screen locks, no suspend; undocked → default `HandleLidSwitch=suspend` fires, `xss-lock` locks before the suspend. **Do not re-introduce a `block:handle-lid-switch` inhibitor** — that swallows lid events entirely (no suspend, no lock) and was the cause of the 2026-05 dead-battery incident.
- **Polybar:** `./polybar/config.ini` — **symlinked** to `~/.config/polybar/config.ini`
  (still needs polybar restart after edit, see Deploy workflow)
- **Rofi:** `./rofi/` — **symlinked** (`config.rasi` + `gruvbox-dark.rasi` both link
  into `~/.config/rofi/`)
- **Ghostty:** `./ghostty/config` — **symlinked** to `~/.config/ghostty/config`
- **nvim:** `./init.vim` — **symlinked** to `~/.config/nvim/init.vim`. `vi`/`nvim`
  is a zsh **function** (not bare nvim) that pairs with `<leader>cd` to drop the
  shell into the folder under cursor on exit. Target is the nvim-tree node under
  cursor (dir → itself, file → parent), netrw's `b:netrw_curdir`, or `getcwd()`.
  Same temp-file pattern as `y()` for yazi.
- **tmux:** `./.tmux.conf` — **symlinked** to `~/.tmux.conf` (edits to the repo
  file take effect after `tmux source-file ~/.tmux.conf`). Decision log for
  copy-mode scroll UX lives inline in the config as the single source of truth.
- **zsh:** `./.zshrc` — **symlinked** to `~/.zshrc`
- **zsh env:** `./.zshenv` — **symlinked** to `~/.zshenv`. Sourced for ALL zsh
  invocations (login, interactive, scripts). Sets PATH here (not `.zshrc`) so
  GUI-launched apps like nvim-from-i3 inherit nvm's default node — otherwise
  language servers (`ngserver`, `typescript-language-server`) living under
  `~/.nvm/versions/node/<ver>/bin` aren't findable.
- **Pi coding agent:** `./pi/agent/` is **symlinked** into `~/.pi/agent/` by
  `./pi/install.sh` (settings, AGENTS.md, mcp.json, extensions, prompts,
  subagents, and the Pi-native code-review skill). Shared Agent Skills live in
  `./.agents/` and are symlinked to `~/.agents/` by the same installer. Secrets
  and generated state stay local: `auth.json`, sessions, MCP OAuth/cache files,
  `trust.json`, and package installs under `~/.pi/agent/npm/`.
  **`.agents/skills/` is gitignored** — every skill in it comes from an upstream
  repo and is pinned by the tracked `.agents/.skill-lock.json`. On a fresh clone
  the directory does not exist, so `install.sh`'s `~/.agents/skills` symlink
  dangles until you reinstall them (`npx skills add …`, see `find-skills`).
- **herdr:** `./herdr/config.toml` — **symlinked** to `~/.config/herdr/config.toml`.
  `./herdr/move-space.py` and `./herdr/speak-focus.py` are **not** symlinked;
  `config.toml` calls them by absolute
  repo path (same pattern as `tmux/claude-spinner.sh`). The `herdr` binary itself
  lives at `~/.local/bin/herdr` and is not in the repo — reinstall it by hand from
  the pinned release. Session state (`session.json`, sockets, logs) stays in
  `~/.config/herdr/` and is deliberately untracked.

**Everything is now symlinked.** Editing any repo file affects the live system
immediately. Disaster recovery: clone this repo and run the bootstrap commands
(see below) to restore a machine from scratch.

### Open decisions

- **Systray** — removed on 2026-04-13. Rationale: user uses `nmcli` not nm-applet,
  and the running tray apps didn't earn their spot. Reconsider if a truly
  useful background app appears (Syncthing, VPN, KeePassXC, etc.) — then
  re-add `systray` to `modules-right` in `polybar/config.ini`.
- **Compositor** — no `picom` installed. Could add for transparency/shadows,
  but current minimal aesthetic doesn't demand it.
- **Wireguard click-toggle** — see `polybar/SETUP.md` (currently wired up
  for any config under `/etc/wireguard/` via a narrow sudoers entry).

## Deploy workflow

All configs are symlinked, so edits to repo files are live immediately. Some
services still need an explicit reload/restart for the new config to take effect:

| Config  | Apply change with                                        |
| ------- | -------------------------------------------------------- |
| tmux    | `tmux source-file ~/.tmux.conf`                          |
| i3      | `$mod+Shift+R` (or `i3-msg reload`)                      |
| polybar | `polybar-msg cmd quit && nohup polybar main >/tmp/polybar.log 2>&1 & disown` |
| nvim    | reopen, or `:source $MYVIMRC`                            |
| zsh     | `source ~/.zshrc` or open a new shell                    |
| rofi    | no reload — reads config on every invocation             |
| ghostty | applies to new windows; existing windows keep old config |
| pi      | `~/gits/dot_files/pi/install.sh`, then restart Pi or run `/reload` |
| herdr   | `herdr server reload-config` (check `diagnostics` is `[]`)        |
| logind  | `sudo install -m 644 ~/gits/dot_files/logind/lid.conf /etc/systemd/logind.conf.d/lid.conf && sudo systemctl reload systemd-logind` |
| obsidian-sync | `systemctl --user daemon-reload && systemctl --user restart obsidian-sync.service` |

## Bootstrap a fresh machine

```
# Clone
git clone git@github.com:Oranggge/dot_files.git ~/gits/dot_files
cd ~/gits/dot_files

# Create parent dirs that might not exist yet
mkdir -p ~/.config/{nvim,polybar,rofi,ghostty,i3,herdr}

# Lock-screen dependencies (i3/lock.sh)
#   maim + ImageMagick    -> the blurred/dimmed screenshot pipeline
#   i3lock-color (NOT i3lock) -> the themed clock+ring lock screen
# lock.sh is variant-aware: if only vanilla `i3lock` is present it still
# locks (minimal flags, no clock/ring), but the full gruvbox theme needs the
# i3lock-color FORK. The fork is NOT in Fedora's main repos — install from a
# COPR or build from source. A plain `dnf install i3lock` gives you vanilla
# i3lock and the degraded lock (this is exactly what the F42->F44 upgrade did).
sudo dnf install -y maim ImageMagick
# Themed lock (pick one):
#   sudo dnf copr enable <user>/i3lock-color && sudo dnf install i3lock-color
#   -- or build from https://github.com/Raymo111/i3lock-color (see its README
#      for the -devel build deps). Verify with: i3lock --help | grep -- --clock

# Screenshot tool. ksnip is the Qt5 fallback; its config is not tracked --
# set it up from the settings in the Screenshots section if you ever need it.
sudo dnf install -y flameshot ksnip

# Monitor layout automation. WITHOUT THESE the layout silently drifts (eDP-1 stays
# lit behind a shut lid) and flameshot starts capturing the wrong screen -- see the
# Screenshots section. The udev hotplug rule ships with the package; these two do not
# get enabled on their own, and the lid one is the whole point.
sudo dnf install -y autorandr
sudo systemctl enable --now autorandr-lid-listener.service   # lid open/close
sudo systemctl enable autorandr.service                      # resume from sleep
# then save the profiles once, per machine:
#   docked:  externals on, eDP-1 off  -> autorandr --save docked
#   mobile:  eDP-1 on, externals off  -> autorandr --save mobile

# Symlink everything
ln -sf ~/gits/dot_files/.tmux.conf            ~/.tmux.conf
ln -sf ~/gits/dot_files/.zshrc                ~/.zshrc
ln -sf ~/gits/dot_files/.zshenv               ~/.zshenv
ln -sf ~/gits/dot_files/init.vim              ~/.config/nvim/init.vim
ln -sf ~/gits/dot_files/i3/config             ~/.config/i3/config
ln -sf ~/gits/dot_files/i3/lock.sh            ~/.config/i3/lock.sh
ln -sf ~/gits/dot_files/ghostty/config        ~/.config/ghostty/config
ln -sf ~/gits/dot_files/polybar/config.ini    ~/.config/polybar/config.ini
ln -sf ~/gits/dot_files/polybar/net.sh        ~/.config/polybar/net.sh
ln -sf ~/gits/dot_files/polybar/psi.sh        ~/.config/polybar/psi.sh
ln -sf ~/gits/dot_files/polybar/load.sh       ~/.config/polybar/load.sh
ln -sf ~/gits/dot_files/polybar/ram.sh        ~/.config/polybar/ram.sh
ln -sf ~/gits/dot_files/polybar/disk.sh       ~/.config/polybar/disk.sh
ln -sf ~/gits/dot_files/polybar/temp.sh       ~/.config/polybar/temp.sh
ln -sf ~/gits/dot_files/rofi/config.rasi      ~/.config/rofi/config.rasi
ln -sf ~/gits/dot_files/rofi/gruvbox-dark.rasi ~/.config/rofi/gruvbox-dark.rasi
ln -sf ~/gits/dot_files/herdr/config.toml     ~/.config/herdr/config.toml

# herdr — the binary is NOT in the repo. Download the pinned release by hand and
# verify the hash (the manifest ships no sha256, so `herdr update` trusts TLS
# alone). v0.7.3 sha256 043ef43ecbabda28465dcff1eec3184518150d567b8b8f20cda9c6c88770641d
# into ~/.local/bin/herdr, then: herdr server reload-config

# Pi coding-agent config and shared Agent Skills
~/gits/dot_files/pi/install.sh

# logind drop-in (lid behavior — needs sudo, copy not symlink, see Layout)
sudo mkdir -p /etc/systemd/logind.conf.d/
sudo install -m 644 ~/gits/dot_files/logind/lid.conf /etc/systemd/logind.conf.d/lid.conf
sudo systemctl reload systemd-logind

# Obsidian Sync (headless) — requires Node 22+ via nvm and an Obsidian Sync subscription
npm install -g obsidian-headless
ob login                                   # interactive: email + password + MFA
cd ~/Documents/knowledge && ob sync-setup --vault knowledge
mkdir -p ~/.config/systemd/user
ln -sf ~/gits/dot_files/systemd/user/obsidian-sync.service ~/.config/systemd/user/obsidian-sync.service
systemctl --user daemon-reload
systemctl --user enable --now obsidian-sync.service

# Tmux plugins (manual, no TPM)
git clone https://github.com/azorng/tmux-smooth-scroll ~/.tmux/plugins/tmux-smooth-scroll
git clone https://github.com/accessd/tmux-agent-indicator ~/.tmux/plugins/tmux-agent-indicator
```

The `tmux-agent-indicator` plugin needs Claude Code hooks installed in
`~/.claude/settings.json` (NOT a symlinked dotfile — it's the global Claude
Code config). The hooks fire on `UserPromptSubmit` (running), `PermissionRequest`
(needs-input), and `Stop` (done), each calling
`~/.tmux/plugins/tmux-agent-indicator/scripts/agent-state.sh --agent claude --state <state>`.
On a fresh machine, either re-add those entries by hand from the live config, or
run the plugin's installer (`bash ~/.tmux/plugins/tmux-agent-indicator/install.sh`).
Do **not** run the curl-pipe-bash one-liner — it'd touch other files (`~/.codex/config.toml`,
`~/.config/opencode/`) we don't currently want it to manage.

## Tmux plugins

Manual install (no TPM). Plugins live under `~/.tmux/plugins/` and are loaded
by explicit `run-shell` lines at the bottom of `.tmux.conf`.

- **[azorng/tmux-smooth-scroll](https://github.com/azorng/tmux-smooth-scroll)** —
  animates wheel + Ctrl-U/D + PgUp/Dn in copy mode. Settings (`speed/easing/normal`)
  and full rationale are documented inline in `.tmux.conf`.
- **[accessd/tmux-agent-indicator](https://github.com/accessd/tmux-agent-indicator)** —
  visual feedback for AI agent states. Pane border + window-title color flip
  to gruvbox yellow on `needs-input` and gruvbox green/red on `done`, so you
  can see across panes/windows when an agent finished or is waiting on you.
  Tmux config (palette overrides, `reset-on-focus`, animation off) is in
  `.tmux.conf`. Claude Code hook config lives in `~/.claude/settings.json`
  (UserPromptSubmit / PermissionRequest / Stop) — see Bootstrap below.

Reinstall step is in the Bootstrap section above.

## Tmux Claude "working" spinner

An animated blue braille spinner appears in the tmux status bar on any tab where
Claude Code is **actively thinking**, so you can see across tabs which sessions
are busy. Distinct from `tmux-agent-indicator` (which colours tabs on
*needs-input*/*done* — i.e. after Claude stops); the two never overlap in time.

- **Detection (no hooks):** Claude continuously animates a spinner into its
  *pane title* (`#{pane_title}`) while thinking, and uses `✳ …` as the idle
  marker. So "working" = active pane's `pane_current_command == claude` **AND**
  pane title does **not** match `✳*`. This predicate is inlined into both
  `window-status-format` / `window-status-current-format` in `.tmux.conf` (tmux
  has no format variables, hence the duplication). It gates the spinner per-window.
- **Animation:** pure tmux formats can't animate (no clock/tick var), so
  `tmux/claude-spinner.sh` supplies motion — a single-instance (`flock`) daemon
  that advances the global `@cc_spin_frame` option ~8fps and `refresh-client -S`s
  the status, but only while a Claude tab is working (else it drops to a cheap 1s
  idle poll). Launched by `run-shell -b ~/gits/dot_files/tmux/claude-spinner.sh`
  at the bottom of `.tmux.conf`. If the daemon isn't running the format falls
  back to `#{=1:pane_title}` (Claude's own live but tiny single-dot braille frame).
- **Not symlinked:** `claude-spinner.sh` is referenced by absolute repo path from
  `.tmux.conf` (which *is* symlinked), so no Bootstrap symlink is needed — clone
  the repo to `~/gits/dot_files` and it just works.
- **Tweaks:** spinner frames (incl. a chunkier `⣾⣽⣻⢿⡿⣟⣯⣷` set), colour
  (`#83a598`), and fps (`sleep 0.12`) are all at the top of the formats /
  `claude-spinner.sh`. `status-interval` was lowered to `1` for prompt
  appear/clear.
