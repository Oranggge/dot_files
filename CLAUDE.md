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
- Modules: `xworkspaces | (center) date | cpu memory pulseaudio wlan vpn battery`
- CPU/RAM turn alert-red above 80% via `format-warn`
- Icons from JetBrainsMono Nerd Font
- VPN module uses `polybar/vpn.sh` — detects tailscale then wireguard (see `polybar/SETUP.md`)

## Rofi (launcher)

- Installed 2026-04-13. Replaces dmenu as `$mod+d` launcher.
- Configs in `./rofi/` (`config.rasi` + `gruvbox-dark.rasi` theme, matches polybar)
- Modes: `drun` (GUI apps), `run` (any `$PATH` binary), `window` (focus existing)
- Only GUI apps with `.desktop` files show in `drun`. Manually-installed ones
  (like qutebrowser at `/usr/local/bin/qutebrowser`) need a desktop entry —
  see `./applications/qutebrowser.desktop` for the pattern.

## Layout

- **i3 config:** `./i3/config` — **symlinked** to `~/.config/i3/config`
- **Polybar:** `./polybar/config.ini` — **symlinked** to `~/.config/polybar/config.ini`
  (still needs polybar restart after edit, see Deploy workflow)
- **Rofi:** `./rofi/` — **symlinked** (`config.rasi` + `gruvbox-dark.rasi` both link
  into `~/.config/rofi/`)
- **Ghostty:** `./ghostty/config` — **symlinked** to `~/.config/ghostty/config`
- **nvim:** `./init.vim` — **symlinked** to `~/.config/nvim/init.vim`
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
ln -sf ~/gits/dot_files/ghostty/config        ~/.config/ghostty/config
ln -sf ~/gits/dot_files/polybar/config.ini    ~/.config/polybar/config.ini
ln -sf ~/gits/dot_files/rofi/config.rasi      ~/.config/rofi/config.rasi
ln -sf ~/gits/dot_files/rofi/gruvbox-dark.rasi ~/.config/rofi/gruvbox-dark.rasi

# Tmux plugins (manual, no TPM)
git clone https://github.com/azorng/tmux-smooth-scroll ~/.tmux/plugins/tmux-smooth-scroll
```

## Tmux plugins

Manual install (no TPM). Plugins live under `~/.tmux/plugins/` and are loaded
by explicit `run-shell` lines at the bottom of `.tmux.conf`.

- **[azorng/tmux-smooth-scroll](https://github.com/azorng/tmux-smooth-scroll)** —
  animates wheel + Ctrl-U/D + PgUp/Dn in copy mode. Settings (`speed/easing/normal`)
  and full rationale are documented inline in `.tmux.conf`.

Reinstall step is in the Bootstrap section above.
