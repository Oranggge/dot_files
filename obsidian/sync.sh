#!/usr/bin/env bash
# Wrapper exec'd by obsidian-sync.service. Sources nvm so the systemd user
# service can find `ob` regardless of which Node version is currently default
# (the npm-global bin dir lives under ~/.nvm/versions/node/<ver>/bin/).
set -euo pipefail

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"

cd "$HOME/Documents/knowledge"
exec ob sync --continuous
