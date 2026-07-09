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

**Keys mirror `.tmux.conf`** so there is nothing to relearn, with three
deliberate exceptions, all documented inline in `config.toml`. The theme of all
three: **the cheap keys index spaces, not tabs**, because the space is the unit
of work here (one repo / one project) and tabs are barely used.

- `prefix+c` makes a new **space**, not a new tab (new tab moved to `prefix+t`).
  tmux's `prefix c` = new-window is the muscle memory being broken.
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

- **herdr:** `./herdr/config.toml` — **symlinked** to `~/.config/herdr/config.toml`.
  `./herdr/move-space.py` is **not** symlinked; `config.toml` calls it by absolute
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
