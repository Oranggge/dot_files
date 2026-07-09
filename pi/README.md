# Pi agent config

Personal Pi coding-agent configuration.

Tracked here:
- `agent/settings.json` — non-secret UI/model/resource settings.
- `agent/AGENTS.md` — global Pi workflow instructions.
- `agent/mcp.json` — MCP server config without OAuth tokens/cache.
- `agent/extensions/clear-alias.ts` and `agent/extensions/exit-alias.ts` — local command aliases.
- `agent/extensions/subagent/` — Pi subagent extension, vendored from Pi examples so it survives Node/Pi install path changes.
- `agent/extensions/quiet-tools/` — overrides built-in tool rendering so collapsed tool calls/results are hidden entirely; `Ctrl+O` expands them when needed.
- `agent/agents/` — user-level subagents (`scout`, `planner`, `reviewer`, `worker`).
- `agent/prompts/` — workflow prompt templates (`/code-review`, `/implement`, `/scout-and-plan`, `/implement-and-review`).
- `agent/skills/code-review/` — Pi-native code review skill.
- `../.agents/skills/` and `../.agents/.skill-lock.json` — shared Agent Skills that Pi auto-discovers from `~/.agents/skills`.

Not tracked:
- `~/.pi/agent/auth.json`
- sessions
- MCP OAuth/cache files
- package installs under `~/.pi/agent/npm/` (recreated from `settings.json` packages)
- generated backup files (`*.backup.*`, `extension-backups/`)
- `~/.pi/agent/trust.json` and other machine-local secrets/state

Install/sync on a machine:

```bash
~/gits/dot_files/pi/install.sh
```

Then restart Pi, or run `/reload` in an existing session.
