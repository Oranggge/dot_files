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
