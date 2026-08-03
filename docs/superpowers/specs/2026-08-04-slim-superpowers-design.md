# Slim Superpowers — Design

**Date:** 2026-08-04
**Status:** Approved, pending plan
**Branch:** `slim` off `main` (obra/superpowers history retained)

## Goal

Cut Superpowers to a Claude-Code-only skill set sized for Claude 5 generation models, following
[The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)
(Thariq Shihipar, Anthropic, 2026-07-24). Fewer skills, less context per invocation, no session-start
injection — while the workflow chain that gives Superpowers its value stays intact.

Success criteria:

1. 9 skills remain, each independently discoverable and invocable.
2. Total `SKILL.md` prose drops from 8,751 words to ~1,650 (81%).
3. No session-start hook. Skills trigger through native description-based discovery alone.
4. Baseline test results captured before the rewrite and compared after, with the delta recorded.

## Context

The article's diagnosis is over-constraint: *"we were overconstraining Claude Code, both through our
system prompt and in our CLAUDE.md files and skills."* The stated cost is wasted deliberation —
*"Claude must think more carefully about these overlapping and conflicting messages before deciding
what to do."* Anthropic removed over 80% of Claude Code's system prompt.

Three findings shaped this design:

- **`origin` is `obra/superpowers` directly, not a fork.** Upstream rejects this change class by
  policy ("Fork-specific changes"; skill rewrites require eval evidence). This work is not
  upstreamable. History is kept; `origin` gets re-pointed to a personal remote later.
- **The injection hook is already redundant in practice.** Skills copied to `~/.claude/skills/` are
  discovered and invoked natively with no `<EXTREMELY_IMPORTANT>` block present.
- **Deleting a skill saves little always-on context.** Only `using-superpowers` (481 words) was
  preloaded. Everything else is on-demand, so cuts pay off per invocation, not per session. The
  large win from dropping `subagent-driven-development` is runtime — N implementer plus N reviewer
  agents per plan — not its 6,697 words of prose.

## Decisions

| # | Decision | Choice |
|---|---|---|
| 1 | Deliverable location | Edit this clone on a branch, keep obra history, re-point `origin` later |
| 2 | Compression depth | Full rewrite per the article (~70%+ reduction) |
| 3 | Skill count | Keep the 9 survivors separate; no merging |
| 4 | Triggering mechanism | Pure native discovery; nothing added to always-on context |
| 5 | Repo scope | Claude Code only; visual companion dropped |
| 6 | Verification | Reuse in-repo tests, baseline captured first |
| 7 | Skill anatomy | Pure recipe — no Iron Law, no rationalization table, no red-flags table |

### Accepted risks

Decisions 2, 4 and 7 together remove every binding mechanism from always-on context and from skill
bodies. Superpowers' own eval note (`writing-skills/SKILL.md:459`) reports that for *discipline*
failures, prohibition-shaped guidance outperformed recipe-shaped guidance in head-to-head wording
tests. This design bets that Claude 5 judgement covers the gap, per the article's Rule 1: *"newer
models have better judgement and can handle these decisions well without explicit rules."*

That bet is untested on Opus 5. The verification phase exists to measure it. Specifically at risk:

- Nothing in always-on context compels a first skill call before the model starts working.
- `brainstorming`'s description loses `"You MUST use this before any creative work"`, so the
  design-before-code gate becomes step ordering inside the skill rather than a trigger-time
  instruction.
- TDD, root-cause, and verification gates lose their anti-rationalization content entirely.

If the after-run regresses against baseline, the cheapest recovery is restoring one-line Iron Laws
(~15 words per skill) before anything larger.

## Deletions

### Skills (5) — 23,554 words

`using-superpowers` · `using-git-worktrees` · `subagent-driven-development` ·
`dispatching-parallel-agents` · `writing-skills`

`using-git-worktrees` goes because worktree creation is a judgement call the model makes from
context, not a procedure needing a skill. `subagent-driven-development` goes for runtime token cost.

### Harness machinery

`hooks/` · `.codex-plugin/` · `.cursor-plugin/` · `.kimi-plugin/` · `.opencode/` · `.pi/` ·
`.agents/` · `gemini-extension.json` · `GEMINI.md` · `package.json` · `.version-bump.json` ·
`scripts/bump-version.sh` · `docs/porting-to-a-new-harness.md` · `docs/windows/` ·
`docs/README.kimi.md` · `docs/README.opencode.md`

`package.json` exists only to declare the OpenCode `main` entry and the pi `extensions`/`skills`
fields; with both harnesses gone it has no remaining purpose.

### Upstream project artifacts

`RELEASE-NOTES.md` (91 KB) · `.github/PULL_REQUEST_TEMPLATE.md` · `.github/ISSUE_TEMPLATE/` ·
`.github/FUNDING.yml` · `CODE_OF_CONDUCT.md`

### Dev artifacts currently shipped to users

`skills/systematic-debugging/test-academic.md` · `test-pressure-1.md` · `test-pressure-2.md` ·
`test-pressure-3.md` · `CREATION-LOG.md` · `skills/brainstorming/visual-companion.md` ·
`skills/brainstorming/scripts/` · `frame-template.html` · `helper.js`

### Tests

Keep `tests/claude-code/`, `tests/explicit-skill-requests/`, `tests/systematic-debugging/`,
`tests/shell-lint/`.

Delete `tests/hooks/`, `tests/brainstorm-server/`, `tests/opencode/`, `tests/pi/`, `tests/kimi/`,
`tests/antigravity/`, `tests/codex/`, `tests/codex-plugin-sync/`.

### Flagged, not deleted

`docs/plans/` (4 files) and `docs/superpowers/plans/` (11 files) are upstream's historical
implementation plans. They cost nothing at runtime and document why current skills look the way they
do. Kept unless you say otherwise.

`assets/` is **deleted**, not kept. `app-icon.png` and `superpowers-small.svg` are referenced only by
`.codex-plugin/plugin.json:44-45` (`composerIcon`, `logo`); nothing else in the repo — including
`README.md` — links them. Deleting the Codex manifest orphans them, so they go with it.

### Retained by license

`LICENSE` and obra's copyright notice stay. MIT requires it. `README.md` gets an attribution line
naming obra/superpowers as the origin and stating that this is a reduced, Claude-Code-only
derivative.

## Dangling references to repair

Six, all confirmed by grep:

| File:line | Current content | Repair |
|---|---|---|
| `executing-plans/SKILL.md:14` | Tells the reader to use `subagent-driven-development` instead of this skill | Delete the note. `executing-plans` becomes the only execution skill |
| `executing-plans/SKILL.md:19` | Step 1 delegates workspace setup to `using-git-worktrees` | Replace with a plain step: work in an isolated workspace if the change warrants one |
| `writing-plans/SKILL.md:16` | Says the worktree "should have been created via the `using-git-worktrees` skill" | Delete the note |
| `writing-plans/SKILL.md:61` | Plan-template line: `REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans` | Point at `executing-plans` only |
| `writing-plans/SKILL.md:163` | `**REQUIRED SUB-SKILL:** Use subagent-driven-development` | Point at `executing-plans` |
| `test-driven-development/writing-good-tests.md:51` | Parenthetical cites `superpowers:writing-skills` | Drop the citation, keep the sentence |

## Skill anatomy

Every rewritten `SKILL.md` uses the same five-part shape and nothing else:

1. `# Title` (H1)
2. Numbered workflow steps — imperative, one action per line
3. Terminal-state line naming the next skill to invoke
4. `references/` pointers for depth, as plain filenames (never `@`-linked — `@` force-loads)
5. Nothing else. No Iron Law, no rationalization table, no red-flags table, no letter/spirit closure,
   no Graphviz flowchart, no "your human partner" framing where a plain imperative works.

Reference shape:

```markdown
# Test-Driven Development

1. Write the smallest failing test. Run it. Watch it fail.
2. Write the minimum code to pass. Run it.
3. Refactor. Run again.
4. Match test style to the surrounding suite.

Terminal state: invoke requesting-code-review.

Depth: writing-good-tests.md
```

Frontmatter stays exactly two fields, `name` and `description`, under 1024 characters combined.

## Descriptions

All 9 descriptions become neutral when-to-use clauses — the trigger moment only, never a workflow
summary. The workflow-summary prohibition is retained from upstream because it has measured backing:
a description summarizing the workflow becomes a shortcut the model takes instead of reading the
body (upstream observed one review performed where the body specified two).

| skill | description |
|---|---|
| `brainstorming` | Use when turning an idea, feature request, or vague goal into a design, before writing code |
| `writing-plans` | Use when you have a spec or requirements for a multi-step task, before touching code |
| `executing-plans` | Use when you have a written implementation plan to execute task by task |
| `test-driven-development` | Use when implementing any feature or bugfix, before writing implementation code |
| `systematic-debugging` | Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes |
| `requesting-code-review` | Use when work is implemented and needs review before merging |
| `receiving-code-review` | Use when code review feedback has arrived, before implementing the suggestions |
| `verification-before-completion` | Use when about to claim work is complete, fixed, or passing, before committing or creating a PR |
| `finishing-a-development-branch` | Use when implementation is complete and tests pass, and the work needs integrating |

## Rewrite targets

| skill | `SKILL.md` now | target | cut |
|---|---|---|---|
| `brainstorming` | 1,494 | 250 | 83% |
| `systematic-debugging` | 1,440 | 220 | 85% |
| `test-driven-development` | 1,375 | 150 | 89% |
| `finishing-a-development-branch` | 1,150 | 220 | 81% |
| `writing-plans` | 1,034 | 200 | 81% |
| `receiving-code-review` | 913 | 170 | 81% |
| `verification-before-completion` | 580 | 130 | 78% |
| `requesting-code-review` | 421 | 130 | 69% |
| `executing-plans` | 344 | 180 | 48% |
| **total** | **8,751** | **~1,650** | **81%** |

Repo-wide, including `references/`: 40,130 → ~6,400 words (84%).

Targets are budgets, not quotas. A skill that lands under budget with its workflow intact is a pass.
A skill that cannot express its workflow within budget gets the budget raised, recorded in the plan —
not its steps dropped.

### References kept

Loaded only when a pointer is followed, so they do not count against per-invocation cost:

`test-driven-development/writing-good-tests.md` · `systematic-debugging/root-cause-tracing.md` ·
`defense-in-depth.md` · `condition-based-waiting.md` + its `.ts` example · `find-polluter.sh` ·
`requesting-code-review/code-reviewer.md` · `writing-plans/plan-document-reviewer-prompt.md` ·
`brainstorming/spec-document-reviewer-prompt.md`

## Chain

Chaining lives only in terminal-state lines inside skill bodies. Nothing coordinates it from
always-on context.

```
brainstorming ──▶ writing-plans ──▶ executing-plans ──┐
                                                      │ per task
                                   test-driven-development
                                                      │
                         requesting-code-review ◀──────┘
                                   │
                         receiving-code-review
                                   │
                    verification-before-completion
                                   │
                    finishing-a-development-branch

systematic-debugging ──▶ test-driven-development   (lock the fix with a failing test)
```

`brainstorming`'s terminal state stays `writing-plans` exclusively — that constraint is retained
because it stops the model from jumping from design straight into an implementation skill.

## New CLAUDE.md

Written from scratch. Under 250 words. Article-shaped: light on identity, most tokens on gotchas,
progressive disclosure for anything longer.

Sections:

- **What this is** — two lines. A Claude-Code-only skill set derived from obra/superpowers.
- **Gotchas** — skills are behavior-shaping prose, not code, so changes need behavioral testing, not
  just review; `SKILL.md` loads in full on invoke while `references/` load only when a pointer is
  followed, so put depth in references; frontmatter is exactly `name` + `description` under 1024
  chars; a description states when to use the skill and never summarizes its workflow; never `@`-link
  between skills because `@` force-loads; per-skill word budgets are in this spec.
- **Testing** — pointer to `docs/testing.md`.

Upstream's anti-slop PR section is dropped. It governs obra's issue tracker, not this repo.

## Verification

Same harness for both runs, or the comparison means nothing. `tests/explicit-skill-requests/run-all.sh`
already runs against an isolated `HOME`; both runs use it.

```
1. BASELINE — before any edit lands
   a. tests/explicit-skill-requests/run-all.sh          → record pass/fail per prompt
   b. claude -p "Let's make a react todo list"          → does brainstorming fire before any code?
   c. word-count table for all 14 skills
   → commit results to docs/superpowers/baseline/2026-08-04-before.md

2. REWRITE — deletions, ref repairs, 9 rewrites, new CLAUDE.md, test trim

3. AFTER — re-run 1a, 1b, 1c unchanged
   → commit to docs/superpowers/baseline/2026-08-04-after.md, with a diff summary

4. RETARGET — the 9 prompt files in tests/explicit-skill-requests/prompts/ name skills including
   deleted ones. Rewrite them against the 9 survivors, keeping the resistance framing that makes
   them adversarial (for example "just start coding, skip the formalities").
```

Step 4 runs after step 3 so the before/after comparison uses identical prompts. Retargeted prompts
get their own baseline run, recorded separately.

The decisive measurement is 1b. If `brainstorming` fires before code in the before-run and not in the
after-run, the design has failed its quality criterion and Iron Laws come back.

## Resulting tree

```
skills/                      9 dirs, ~1,650 words of SKILL.md
  brainstorming/             SKILL.md, spec-document-reviewer-prompt.md
  writing-plans/             SKILL.md, plan-document-reviewer-prompt.md
  executing-plans/           SKILL.md
  test-driven-development/   SKILL.md, writing-good-tests.md
  systematic-debugging/      SKILL.md, root-cause-tracing.md, defense-in-depth.md,
                             condition-based-waiting.md + .ts, find-polluter.sh
  requesting-code-review/    SKILL.md, code-reviewer.md
  receiving-code-review/     SKILL.md
  verification-before-completion/  SKILL.md
  finishing-a-development-branch/  SKILL.md
tests/                       claude-code, explicit-skill-requests, systematic-debugging, shell-lint
docs/                        testing.md, superpowers/{specs,plans,baseline}, plans/
.claude-plugin/              plugin.json, marketplace.json
README.md  CLAUDE.md  LICENSE  .pre-commit-config.yaml  .gitattributes  .gitignore
```

## Git

Branch `slim` off `main`. Commit sequence:

1. Capture baseline results (`docs/superpowers/baseline/`)
2. Delete harness machinery and upstream project artifacts
3. Delete the 5 skills, repair the 6 dangling references
4. Rewrite the 9 `SKILL.md` files
5. New `CLAUDE.md`, README attribution line
6. Trim tests
7. Capture after-results, record the diff

`origin` re-pointing is a manual step you run when the remote exists:
`git remote set-url origin git@github.com:tim-hub/<repo>.git`

## Out of scope

- The `drill` eval harness (`prime-radiant-inc/superpowers-evals`). Rejected as a second project.
- Merging or splitting any of the 9 skills.
- Any always-on injection mechanism — hook, `CLAUDE.md` gate lines, or description-embedded
  imperatives.
- Multi-harness support. Restoring it later means restoring `hooks/`, since the hook is the bootstrap
  for every non-Codex harness.
