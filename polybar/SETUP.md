# Polybar — One-time Setup Steps

Manual steps for the polybar VPN module. Run these once when you're ready.

## How the VPN module works

- **`vpn.sh`** — display only. Polls every 1s and shows the current state:
  green `ts` if tailscale is up, green `<wg-iface>` if any wireguard
  interface is up, grey `off` otherwise. Uses unprivileged `ip link show`
  and `tailscale status`, so no sudo needed for display.
- **`vpn-menu.sh`** — left-click handler. Opens a rofi menu listing all
  known VPNs (tailscale + every `.conf` in `/etc/wireguard/`) with their
  current on/off state. Selecting a row toggles that VPN.
- **`vpn-toggle.sh down`** — right-click handler. Quick disconnect.

## Tailscale (already set up)

Done on 2026-04-13:
- `sudo tailscale set --operator=$USER` — lets the user control tailscale
  without sudo, so polybar clicks work.
- `sudo tailscale up --operator=fedouser` — first-time auth.

## Wireguard — three setup commands

All three are one-time. Run as yourself; each will prompt for sudo.

**1. Let your user list `/etc/wireguard/` so the menu can find configs:**
```sh
sudo chgrp $USER /etc/wireguard
sudo chmod g+rx /etc/wireguard
```
The `.conf` files themselves stay `600 root:root` — your keys aren't exposed.

**1a. Fix SELinux labels if configs were copied from `~`:**
If any `.conf` was originally copied from your home dir, it may have
the wrong SELinux context (`user_home_t` instead of `etc_t`), and
wg-quick will fail with "Permission denied" even as root. Fix:
```sh
sudo restorecon -Rv /etc/wireguard
```

**2. Narrow sudoers entry for systemctl start/stop on wg-quick units:**
```sh
echo "$USER ALL=(root) NOPASSWD: /usr/bin/systemctl start wg-quick@*.service, /usr/bin/systemctl stop wg-quick@*.service" | sudo tee /etc/sudoers.d/polybar-wg
sudo chmod 440 /etc/sudoers.d/polybar-wg
sudo visudo -cf /etc/sudoers.d/polybar-wg
```
The last command validates the file — it should print "parsed OK". If
anything's wrong, remove the file: `sudo rm /etc/sudoers.d/polybar-wg`.

This only allows starting/stopping `wg-quick@<name>.service`. Nothing else.
New wg configs dropped into `/etc/wireguard/` are supported automatically.

**3. Verify it works:**
```sh
sudo -n /usr/bin/systemctl start wg-quick@aspang.service
ip -br link show aspang
sudo -n /usr/bin/systemctl stop wg-quick@aspang.service
```
The `sudo -n` flag means "non-interactive" — if it prompts, the sudoers
entry is wrong.

## Checklist

- [x] `sudo tailscale set --operator=$USER`
- [x] `sudo tailscale up` (first-time auth)
- [ ] `sudo chgrp $USER /etc/wireguard && sudo chmod g+rx /etc/wireguard`
- [ ] Install `/etc/sudoers.d/polybar-wg` (see step 2 above)
- [ ] Verify with `sudo -n systemctl start wg-quick@aspang.service`

Once all boxes are ticked, left-click the polybar VPN module → rofi menu
lists tailscale + every wg config, pick one, toggle. Done.
