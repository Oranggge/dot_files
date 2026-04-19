# TODO

## yazi archive preview — improve or replace

Current state: `./yazi/plugins/archive.yazi/main.lua` (copy at `~/.config/yazi/plugins/archive.yazi/main.lua`)
uses `7z l -ba` via blocking `:output()`. Works, but:

- Blocks yazi UI for huge archives (100k+ entries) — should stream via `:spawn()` + `read_line`
  loop with early termination once `job.area.h` rows are filled.
- No caching — re-runs 7z on every hover. Yazi's `preload` hook could cache the listing.
- Reinvents the wheel. Community standard is `ndtoan96/ouch.yazi` — battle-tested, streamed,
  cached. Requires installing `ouch` (Rust CLI). Check if Fedora packages it:
  `dnf search ouch`. If yes: `sudo dnf install ouch && ya pkg add ndtoan96/ouch` and delete
  the custom plugin.
- Also: the yazi config dir (`~/.config/yazi/`) isn't tracked in this dotfiles repo yet.
  Canonical source should live at `./yazi/` per the repo conventions in CLAUDE.md.

Decision to make: replace with ouch.yazi (best) vs polish the custom plugin (keeps deps minimal).

## ~~Battery performance~~ — investigated 2026-04-16, no action needed

Investigated thoroughly with clean measurements and overnight suspend drain test.

**Findings:**
- Clean idle draw: **5.18 W** → ~7h runtime (normal for i7-1355U on Linux)
- Suspend (s2idle) drain: **0.23 W** overnight (8.65h) → excellent, laptop survives ~7 days suspended
- Power stack: `tuned` with `balanced-battery` profile, `powersave` governor, EPP `balance_power` — all sensible defaults
- BT on vs off: ~0.25 W delta (marginal)
- Backlight at 50%, no wasteful kernel params

**Root cause of "feels worse":** charge cap (75–80%) + battery degraded to 81% health (46.18 / 57 Wh design).
Effective usable capacity is ~37 Wh — that's 65% of original, limiting runtime by physics not software.

**No changes made.** Nothing is misconfigured. Optional low-value tweaks:
- `powertop --auto-tune` via systemd unit (diminishing returns, risk of USB autosuspend issues)
- Turn off BT when unused (~10 min/charge gained)
- Raise charge cap to 100% before travel days for more runtime

