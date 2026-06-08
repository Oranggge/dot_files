# Skills to try — personal action list

Reference for klim. Generated from the 2026-04-19 skill walkthrough.
Organized by what YOU need to do to make use of each skill.

---

## 1. Try deliberately in a real scenario

These only prove themselves when you deliberately run them in a real
moment. Don't wait for me to prompt.

- [ ] **`/qa-only`** — next time a videoclient5 feature is "done" and
      you're about to `/ship`, run `/qa-only` first. If the bug report
      is useful, graduate to full `/qa` (auto-fix loop) on the next
      feature.
- [ ] **`/retro`** — run it once for the last 7 days before your next
      weekly boss call. If the output shape is useful as talking
      points, we build the `/boss-update` wrapper around it. If not,
      reshape first.
- [ ] **`/feature-dev`** *(parked)* — try it on the next mid-sized
      feature that's too small for a full `/gsd` phase but too big to
      just dive into. Then decide: adopt or drop.

## 2. Evaluate a competing tool first

- [ ] **Playwright CLI** — evaluate for CI-runnable regression tests on
      videoclient5. Outcome decides two parked skills:
  - `/browse` → adopt for quick chat-driven checks if Playwright alone
    feels too heavy for conversational exploration
  - `/qa` (full auto-fix mode) → adopt only if `/qa-only` trial succeeds

## 3. Remember to invoke explicitly

These are user-driven (no proactive firing). Remember they exist.

- [ ] **`/checkpoint`** — when a session is going sideways or getting
      noisy, before `/clear`:
      1. `/checkpoint "summary of where you are"`
      2. `/clear`
      3. `/checkpoint resume` in the new session
- [ ] **`/office-hours`** — when you catch yourself saying *"is this
      worth building"* or *"maybe I should do X or maybe Y"* — pressure-
      test the idea before 2 hours of implementation.

## 4. Will happen automatically (no action needed)

For awareness only — these fire proactively next time you hit the
trigger. Memories saved in
`~/.claude/projects/-home-fedouser-gits-dot-files/memory/`.

- **`/ship`** — on "commit and push", "create a PR", "ship it", "this
  is ready". Runs after `/simplify` + `/review` + `/codex:review` pass.
- **`/land-and-deploy`** — on "land it", "merge it", "watch the
  pipeline", "check the jobs" (after `/ship` created a PR).
- **`/design-review`** — on "not centered", "looks off", "move it
  left", pasted-screenshot visual complaints.
- **`/investigate`** — on error reports, stack traces, "why is X
  broken", "it was working yesterday", symptom-describing prompts.
- **`codex:/rescue`** — suggested after 3+ corrections on the same
  problem or when `/investigate` stalls.
- **`/learn`** — queried when you say "didn't we fix this before".
  Passive: other skills auto-record lessons.

## 5. To be built in Phase 4

New skills we agreed to create on top of existing ones.

- [ ] **`/analyze-sessions`** — wraps the whole extract+analyze+deep-
      analyze+skills-audit pipeline into one command. Re-runnable.
      Surfaces deltas vs. the last run, not the full report every time.
- [ ] **`/boss-update`** — wraps `/retro` output into boss-friendly
      sections (Shipped / In Progress / Blocked / Next Week). Build
      only after `/retro` manual trial confirms the base output.

---

## Out of scope (decided no)

For your reference — these were evaluated and skipped. If any later
feels useful, we revisit.

- `/canary` — redundant with `/land-and-deploy`'s canary check
- `/design-html` — raw HTML output doesn't fit Angular workflow
- `/careful` / `/guard` / `/freeze` — conflicts with your YOLO mode

---

_Files related to this exercise:
`~/.claude/conversation-analysis/{PLAN,LOG,REPORT,DEEP_REPORT,
UNUSED_SKILLS,SKILL_INTRODUCTIONS,TO_TRY}.md` + memory files under
`~/.claude/projects/-home-fedouser-gits-dot-files/memory/`._
