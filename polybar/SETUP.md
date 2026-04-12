# Polybar — One-time Setup Steps

Manual steps needed for some polybar features. Run these once when you're ready.

## VPN module (`vpn.sh`)

The module detects tailscale or wireguard and shows a coloured icon.
Click actions need some prep.

### Tailscale

**1. Allow non-root control (one-time):**
```sh
sudo tailscale set --operator=$USER
```
After this, `tailscale up` / `tailscale down` work without sudo, so polybar
left-click (up) and right-click (down) will work.

**2. Initial login (one-time, because you're currently logged out):**
```sh
sudo tailscale up
```
Visit the printed URL, authenticate at login.tailscale.com, done.
From then on, the polybar indicator will turn green (`ts`) when connected.

### Wireguard

Detection works out of the box — the script checks for any `wg*` interface
in UP state via `ip link show`. No setup needed for the indicator itself.

**Click-to-toggle for wireguard is NOT wired up** because `wg-quick up/down`
needs root and there's no built-in operator mode like tailscale's. Options
when you want it:

- **Option A — sudoers NOPASSWD** (simplest):
  Add to `/etc/sudoers.d/wg-quick` (use `sudo visudo -f`):
  ```
  fedouser ALL=(root) NOPASSWD: /usr/bin/wg-quick up *, /usr/bin/wg-quick down *
  ```
  Then edit `polybar/vpn.sh` to add `sudo wg-quick up/down <iface>` click handlers.

- **Option B — systemd user service** with a specific wg config, toggled by
  `systemctl --user start/stop wg-<name>`. Cleaner but more setup.

- **Option C — leave it display-only.** Bring wg up/down from the terminal
  as you do today; polybar will reflect state automatically.

Default: **Option C** until you have a wg config you actually use regularly.

## Checklist

- [ ] `sudo tailscale set --operator=$USER`
- [ ] `sudo tailscale up` (first-time auth)
- [ ] Decide wireguard click-handling (A / B / C)
