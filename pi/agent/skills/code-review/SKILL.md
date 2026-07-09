---
name: code-review
description: Pi-native code review of changes since a fixed point. Uses the subagent tool to run isolated Standards and Spec review tracks, then reports them separately. Use when the user asks for /code-review, code review, review this branch, review since main, or PR/WIP review.
---

# Pi Code Review

Review the diff between `HEAD` and a fixed point supplied by the user.

Keep two axes separate:
- **Standards** — does the diff follow this repo's documented coding standards?
- **Spec** — does the diff implement the originating issue / PRD / spec without omissions or scope creep?

## Process

### 1. Pin the fixed point

If the user did not specify a fixed point, ask for one. Examples: `main`, `origin/main`, a commit SHA, branch, tag, or `HEAD~5`.

Validate before delegating:

```bash
git rev-parse <fixed-point>
git diff <fixed-point>...HEAD --stat
git log <fixed-point>..HEAD --oneline
```

Use the three-dot diff command for all review work:

```bash
git diff <fixed-point>...HEAD
```

If the ref is invalid or the diff is empty, stop and report that.

### 2. Identify the spec source

Look for the originating spec, in this order:
1. Issue references in commit messages (`#123`, `Closes #45`, GitLab `!67`, etc.). If repo tooling/docs explain issue fetching, follow them.
2. A path the user passed as an argument.
3. A PRD/spec file under `docs/`, `specs/`, `.scratch/`, or similar matching the branch name or feature.
4. If nothing is found, ask where the spec is. If the user says there is no spec, skip the Spec axis and report `no spec available`.

### 3. Identify standards sources

Find repository standards docs such as `AGENTS.md`, `CLAUDE.md`, `CODING_STANDARDS.md`, `CONTRIBUTING.md`, style guides, architecture docs, or framework-specific best-practices docs.

### 4. Delegate with Pi subagents

Use the `subagent` tool. Prefer parallel mode when both axes are available:

```json
{
  "tasks": [
    {
      "agent": "reviewer",
      "task": "Standards review. Use diff command: git diff <fixed-point>...HEAD. Commits: <commit-list>. Standards sources: <paths>. Report per file/hunk every place the diff violates a documented standard. Cite the standard file and rule. Distinguish hard violations from judgment calls. Skip anything tooling enforces. Under 400 words."
    },
    {
      "agent": "reviewer",
      "task": "Spec review. Use diff command: git diff <fixed-point>...HEAD. Commits: <commit-list>. Spec source: <path or pasted/fetched contents>. Report: (a) requirements missing or partial; (b) behavior not asked for; (c) requirements implemented incorrectly. Quote the spec line for each finding. Under 400 words."
    }
  ]
}
```

If no spec is available, run only the Standards subagent.

### 5. Aggregate

Present the two reports under:

```markdown
## Standards
...

## Spec
...
```

Do not merge or rerank findings across axes. End with one line: finding count per axis and worst issue within each axis, if any.
