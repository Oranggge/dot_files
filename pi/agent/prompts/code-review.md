---
description: Review changes since a fixed point using isolated Standards and Spec subagents
argument-hint: "<fixed-point> [spec path or notes]"
---
Run the Pi-native code-review workflow.

Fixed point / extra args: $@

If no fixed point was provided, ask me for it. Otherwise validate the ref, inspect the diff and commits, identify standards/spec sources, then use the `subagent` tool to run isolated review tracks. Keep the final report split into `## Standards` and `## Spec`.
