# Dot Files Notes

Context for future sessions working on this dotfiles repo.

## System

- **OS:** Fedora 42
- **WM:** i3 (config at `./config`, deployed as `~/.config/i3/config`)
- **Bar:** polybar 3.7.2 (config at `./polybar/`)
- **Terminal editor:** neovim (gruvbox theme, `./init.vim`)
- **Multiplexer:** tmux (minimal grey status, `./.tmux.conf`)
- **Shell:** zsh (`./.zshrc`)
- **Font:** JetBrainsMono Nerd Font (installed at `~/.local/share/fonts/JetBrainsMonoNF/`)

## Aesthetic

Gruvbox Dark Hard palette everywhere. Minimal — no clutter, no decorative modules.
Matches nvim (gruvbox) + tmux (no left/right status) philosophy.

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

- **i3 config:** `./i3/config` (canonical, mirrors `~/.config/i3/config`)
- **Polybar:** `./polybar/` (canonical source, NOT symlinked to `~/.config/polybar/`)
- **Rofi:** `./rofi/` (canonical source)
- **Ghostty:** `./ghostty/config` (canonical source)
- **nvim:** `./init.vim`
- **tmux:** `./.tmux.conf`
- **zsh:** `./.zshrc` — NOTE: the live `~/.zshrc` has drifted slightly
  (extra lines for Go PATH, lazygit alias). Reconcile manually when editing.

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

Polybar is NOT symlinked — changes in `./polybar/config.ini` must be copied to
`~/.config/polybar/config.ini` and polybar restarted:

```
cp polybar/config.ini ~/.config/polybar/config.ini
polybar-msg cmd quit
nohup polybar main >/tmp/polybar.log 2>&1 & disown
```
