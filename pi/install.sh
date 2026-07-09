#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
AGENT_DIR="$HOME/.pi/agent"
GLOBAL_AGENTS_DIR="$HOME/.agents"

mkdir -p \
  "$AGENT_DIR/extensions" \
  "$AGENT_DIR/agents" \
  "$AGENT_DIR/prompts" \
  "$AGENT_DIR/skills" \
  "$GLOBAL_AGENTS_DIR"

link_force() {
  local src="$1"
  local dst="$2"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    local backup="$dst.backup.$(date +%Y%m%d-%H%M%S)"
    mv "$dst" "$backup"
    echo "Backed up existing $dst -> $backup"
  fi
  ln -sfn "$src" "$dst"
}

# Pi global config. Does not include auth, sessions, MCP OAuth tokens, caches, etc.
link_force "$ROOT/agent/settings.json" "$AGENT_DIR/settings.json"
link_force "$ROOT/agent/AGENTS.md" "$AGENT_DIR/AGENTS.md"
link_force "$ROOT/agent/mcp.json" "$AGENT_DIR/mcp.json"

# Extensions and supporting resources.
link_force "$ROOT/agent/extensions/clear-alias.ts" "$AGENT_DIR/extensions/clear-alias.ts"
link_force "$ROOT/agent/extensions/exit-alias.ts" "$AGENT_DIR/extensions/exit-alias.ts"
link_force "$ROOT/agent/extensions/subagent" "$AGENT_DIR/extensions/subagent"
link_force "$ROOT/agent/extensions/quiet-tools" "$AGENT_DIR/extensions/quiet-tools"

for f in "$ROOT"/agent/agents/*.md; do
  link_force "$f" "$AGENT_DIR/agents/$(basename "$f")"
done

for f in "$ROOT"/agent/prompts/*.md; do
  link_force "$f" "$AGENT_DIR/prompts/$(basename "$f")"
done

mkdir -p "$AGENT_DIR/skills/code-review"
link_force "$ROOT/agent/skills/code-review/SKILL.md" "$AGENT_DIR/skills/code-review/SKILL.md"

# Agent Skills are shared by Pi and other agents, and Pi auto-discovers ~/.agents/skills.
link_force "$REPO_ROOT/.agents/skills" "$GLOBAL_AGENTS_DIR/skills"
link_force "$REPO_ROOT/.agents/.skill-lock.json" "$GLOBAL_AGENTS_DIR/.skill-lock.json"

echo "Pi dotfiles installed. Restart pi or run /reload in an existing session."
