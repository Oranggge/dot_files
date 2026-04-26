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
- Modules: `xworkspaces | (center) date | cpu memory headphones pulseaudio net vpn battery`
- CPU/RAM turn alert-red above 80% via `format-warn`
- Icons from JetBrainsMono Nerd Font
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

## Layout

- **i3 config:** `./i3/config` — **symlinked** to `~/.config/i3/config`. `./i3/lock.sh` is **symlinked** to `~/.config/i3/lock.sh`. X11 idle blanking/DPMS is disabled while unlocked; `./i3/lock.sh` temporarily enables DPMS while locked so the display can power off only behind the lock screen.
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

## Bootstrap a fresh machine

```
# Clone
git clone git@github.com:Oranggge/dot_files.git ~/gits/dot_files
cd ~/gits/dot_files

# Create parent dirs that might not exist yet
mkdir -p ~/.config/{nvim,polybar,rofi,ghostty,i3}

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
ln -sf ~/gits/dot_files/rofi/config.rasi      ~/.config/rofi/config.rasi
ln -sf ~/gits/dot_files/rofi/gruvbox-dark.rasi ~/.config/rofi/gruvbox-dark.rasi

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
