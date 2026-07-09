# User workflow preferences

The user often dictates short, typo-heavy prompts. Infer intent from repository state,
recent context, and git status. Ask at most one clarifying question when blocked.

For coding work:
- Start by inspecting git status and relevant files.
- Prefer small, direct edits.
- Run the narrowest useful verification.
- Before commit/push/MR, verify status and summarize what changed.
- If the user says "commit/push/mr", treat that as permission to proceed.

For reviews:
- Separate must-fix bugs from acceptable tradeoffs.
- Do not over-polish if the user says "as intended for now" or "leave it".

For writing/PDF/life-admin:
- Do not invent facts.
- Mark uncertainty explicitly.
- Preserve user wording unless asked to rewrite.

For research:
- Prefer Context7/MCP for official library/framework docs when available.
- Use web_search for current internet research and broad discovery.
- Use fetch_content for specific URLs, GitHub repos, PDFs, and videos.
- Use gh for GitHub repos/issues/PRs when appropriate.
- Use npm view/search for package metadata.

Keep final answers concise, with:
- what changed
- verification
- next action if any
