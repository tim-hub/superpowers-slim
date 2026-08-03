# Slim Superpowers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce Superpowers to a Claude-Code-only set of 9 skills with pure-recipe bodies, no session-start hook, and measured before/after evidence that skill triggering did not regress.

**Architecture:** Three phases. Measure first (baseline runs plus a new automated structural gate that fails against the current tree). Then delete — harness machinery, upstream governance artifacts, five skills. Then rewrite the nine survivors to a fixed five-part anatomy, driving the structural gate green. A final measurement phase re-runs the baseline and compares, with an explicit decision gate if triggering regressed.

**Tech Stack:** Bash, Markdown, `claude -p` headless runs, `jq`. No runtime dependencies added.

**Spec:** `docs/superpowers/specs/2026-08-04-slim-superpowers-design.md` (commit `9e57966`)

## Global Constraints

Every task's requirements implicitly include this section.

- Branch: `slim`. Already created off `main`, spec committed as `9e57966`. Do not create a worktree; this is a documentation-and-prose repo with no build.
- Target harness: Claude Code only. No other harness may be referenced in any surviving file.
- Zero runtime dependencies. Bash and Markdown only. Adding a package manifest or third-party tool is a plan violation.
- Skill frontmatter is exactly two keys, `name` and `description`, and at most 1024 characters total.
- A description states *when to use* the skill. It never summarizes the workflow. A description that summarizes workflow becomes a shortcut the model takes instead of reading the body.
- Skill anatomy is exactly: `# Title`, numbered workflow steps, a terminal-state line, and `references/` pointers as plain filenames. No Iron Law code fence, no rationalization table, no red-flags table, no Graphviz block.
- Never `@`-link between skills. `@` force-loads the target immediately.
- `LICENSE` and obra's copyright notice are retained. MIT requires it.
- End every commit message with: `Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm`
- Word budgets are the ceilings in Task 2's `budget()` function. They are ceilings, not quotas. A skill that needs more gets its ceiling raised in `check-skills.sh` in the same commit, with the reason in the commit message. Dropping a workflow step to fit a ceiling is a plan violation.

### Budget revision from the spec

The spec targeted ~1,650 words of `SKILL.md` prose (81% reduction). The nine bodies in this plan measure **2,521 words — a 71% reduction, not 81%**. These are counted, not estimated: every body below is the literal text to be written, and each figure comes from `wc -w` on the extracted block.

| skill | before | spec target | this plan (measured) | ceiling |
|---|---|---|---|---|
| `brainstorming` | 1,494 | 250 | 283 | 300 |
| `writing-plans` | 1,034 | 200 | 358 | 380 |
| `executing-plans` | 344 | 180 | 185 | 200 |
| `test-driven-development` | 1,375 | 150 | 248 | 270 |
| `systematic-debugging` | 1,440 | 220 | 371 | 400 |
| `requesting-code-review` | 421 | 130 | 145 | 190 |
| `receiving-code-review` | 913 | 170 | 292 | 330 |
| `verification-before-completion` | 580 | 130 | 213 | 230 |
| `finishing-a-development-branch` | 1,150 | 220 | 426 | 470 |
| **total** | **8,751** | **1,650** | **2,521** | **2,770** |

The four largest overruns against the spec target: `finishing-a-development-branch` (literal bash, and two menus that must be reproduced verbatim), `systematic-debugging` (sixteen steps across four phases), `writing-plans` (nine steps plus the no-placeholders prohibition list), and `receiving-code-review` (nine distinct decision steps). No workflow step was dropped in any of them.

Counts include YAML frontmatter, matching what `wc -w < SKILL.md` reports, so the checker and this table measure the same thing.

---

## Task 1: Baseline measurement

Nothing may be edited before this task's results are committed. Without a baseline the quality criterion is unmeasurable.

**Files:**
- Create: `tests/claude-code/test-brainstorming-autotrigger.sh`
- Create: `docs/superpowers/baseline/2026-08-04-before.md`

**Interfaces:**
- Produces: `tests/claude-code/test-brainstorming-autotrigger.sh` — takes an optional `--plugin-dir` path (defaults to repo root), exits 0 if `brainstorming` was invoked via the Skill tool with no file-mutating tool call before it, exits 1 otherwise. Tasks 14 re-runs it unchanged.

- [ ] **Step 1: Write the auto-trigger test**

This is the decisive measurement — upstream's acceptance test, made executable. Create `tests/claude-code/test-brainstorming-autotrigger.sh`:

```bash
#!/usr/bin/env bash
# Upstream's harness acceptance test, made executable.
# Sends exactly "Let's make a react todo list" and asserts brainstorming
# auto-triggers before any file is written.
#
# Usage: ./test-brainstorming-autotrigger.sh [plugin-dir]

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${1:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

PROMPT="Let's make a react todo list"
TIMESTAMP=$(date +%s)
OUTPUT_DIR="/tmp/superpowers-tests/${TIMESTAMP}/autotrigger"
PROJECT_DIR="$OUTPUT_DIR/project"
LOG_FILE="$OUTPUT_DIR/claude-output.json"
mkdir -p "$PROJECT_DIR"

echo "=== Brainstorming Auto-Trigger Test ==="
echo "Plugin dir: $PLUGIN_DIR"
echo "Prompt: $PROMPT"
echo ""

cd "$PROJECT_DIR"
timeout 300 claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
    --max-turns 3 \
    --output-format stream-json \
    > "$LOG_FILE" 2>&1 || true

echo "=== Results ==="
echo "Skills triggered:"
grep -o '"skill":"[^"]*"' "$LOG_FILE" 2>/dev/null | sort -u || echo "  (none)"
echo ""

TRIGGERED=false
if grep -qE '"skill":"([^"]*:)?brainstorming"' "$LOG_FILE"; then
    echo "PASS: brainstorming was triggered"
    TRIGGERED=true
else
    echo "FAIL: brainstorming was NOT triggered"
fi

# The failure mode that matters: writing code before designing.
echo ""
echo "Checking for file mutation before the Skill call..."
FIRST_SKILL_LINE=$(grep -n '"name":"Skill"' "$LOG_FILE" | head -1 | cut -d: -f1)
if [ -n "$FIRST_SKILL_LINE" ]; then
    PREMATURE=$(head -n "$FIRST_SKILL_LINE" "$LOG_FILE" \
        | grep '"type":"tool_use"' \
        | grep -E '"name":"(Write|Edit|NotebookEdit)"' || true)
    if [ -n "$PREMATURE" ]; then
        echo "FAIL: files were written before any skill was invoked:"
        echo "$PREMATURE" | head -5
        TRIGGERED=false
    else
        echo "OK: no file mutation before the Skill call"
    fi
else
    echo "FAIL: no Skill invocation found at all"
    PREMATURE=$(grep '"type":"tool_use"' "$LOG_FILE" \
        | grep -E '"name":"(Write|Edit|NotebookEdit)"' || true)
    [ -n "$PREMATURE" ] && echo "  and files were written:" && echo "$PREMATURE" | head -5
    TRIGGERED=false
fi

echo ""
echo "Full log: $LOG_FILE"
[ "$TRIGGERED" = "true" ] && exit 0 || exit 1
```

- [ ] **Step 2: Make it executable and run it against the current tree**

```bash
chmod +x tests/claude-code/test-brainstorming-autotrigger.sh
bash tests/claude-code/test-brainstorming-autotrigger.sh 2>&1 | tee /tmp/baseline-autotrigger.txt
```

Expected: PASS. The hook is still present and `brainstorming`'s description still reads `You MUST use this before any creative work`, so this is the strongest configuration. Record the exit code either way — a baseline FAIL is still a valid baseline, it just means the after-comparison has a lower bar.

- [ ] **Step 3: Run the adversarial trigger suite**

```bash
bash tests/explicit-skill-requests/run-all.sh 2>&1 | tee /tmp/baseline-explicit.txt
```

Expected: 4 tests run. Record pass/fail per test and the "premature tool invocation" warnings. Tests 1 and 4 target `subagent-driven-development`; they will be retargeted in Task 13, so their baseline numbers are reference-only and are not compared in Task 14.

- [ ] **Step 4: Capture word counts for all 14 skills**

```bash
for d in skills/*/; do
  n=$(basename "$d")
  printf "%-32s SKILL.md:%6s  all-md:%6s\n" "$n" \
    "$(wc -w < "$d/SKILL.md" | tr -d ' ')" \
    "$(find "$d" -name '*.md' -exec cat {} + | wc -w | tr -d ' ')"
done | tee /tmp/baseline-words.txt
```

- [ ] **Step 5: Write the baseline record**

Create `docs/superpowers/baseline/2026-08-04-before.md` containing, verbatim: the output of Step 2, the output of Step 3, the output of Step 4, and the exact `git rev-parse HEAD` the measurements were taken at. No summarizing — Task 14 diffs against this text.

- [ ] **Step 6: Commit**

```bash
git add tests/claude-code/test-brainstorming-autotrigger.sh docs/superpowers/baseline/
git commit -m "test: capture pre-rewrite baseline and add brainstorming auto-trigger test

Makes upstream's harness acceptance test executable: sends 'Let's make a
react todo list' and asserts brainstorming auto-triggers with no file
written first. Records baseline results for the adversarial trigger suite
and per-skill word counts before any skill is touched.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 2: Structural gate (RED)

Writes the automated check that the deletion and rewrite tasks drive green. It must fail against the current tree — that is what proves it checks anything.

**Files:**
- Create: `tests/skills/check-skills.sh`

**Interfaces:**
- Produces: `tests/skills/check-skills.sh` — run from repo root, no arguments. Exits 0 when the skill set is exactly the 9 survivors, every frontmatter has exactly `name` + `description` under 1024 chars, no `@`-links exist, no file under `skills/` mentions a deleted skill, and every `SKILL.md` is within its word ceiling. Exits 1 with a `FAIL:` line per violation. Tasks 3, 5, 6, 7, 8, 9, 10, 11 all run it.

- [ ] **Step 1: Write the checker**

Create `tests/skills/check-skills.sh`:

```bash
#!/usr/bin/env bash
# Structural gate for the slim skill set. Run from repo root.
set -uo pipefail

SKILLS_DIR="skills"
FAIL=0

fail() { echo "FAIL: $*"; FAIL=1; }

# SKILL.md word ceilings. Raise a ceiling here rather than dropping a step.
budget() {
  case "$1" in
    brainstorming)                  echo 300 ;;
    writing-plans)                  echo 380 ;;
    executing-plans)                echo 200 ;;
    test-driven-development)        echo 270 ;;
    systematic-debugging)           echo 400 ;;
    requesting-code-review)         echo 190 ;;
    receiving-code-review)          echo 330 ;;
    verification-before-completion) echo 230 ;;
    finishing-a-development-branch) echo 470 ;;
    *) echo -1 ;;
  esac
}

DELETED="using-superpowers using-git-worktrees subagent-driven-development dispatching-parallel-agents writing-skills"

EXPECTED=$(printf '%s\n' \
  brainstorming executing-plans finishing-a-development-branch \
  receiving-code-review requesting-code-review systematic-debugging \
  test-driven-development verification-before-completion writing-plans \
  | sort | tr '\n' ' ')
# -not -name '.*' — local tooling leaves untracked dirs like skills/.claude behind,
# and the "$SKILLS_DIR"/*/ glob below already skips them.
ACTUAL=$(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -not -name '.*' -exec basename {} \; \
  | sort | tr '\n' ' ')
[ "$ACTUAL" = "$EXPECTED" ] \
  || fail "skill set mismatch
    expected: $EXPECTED
    actual:   $ACTUAL"

for dir in "$SKILLS_DIR"/*/; do
  name=$(basename "$dir")
  f="${dir}SKILL.md"

  [ -f "$f" ] || { fail "$name: no SKILL.md"; continue; }

  fm=$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside' "$f")
  keys=$(printf '%s\n' "$fm" | grep -oE '^[a-z_]+:' | tr -d ':' | sort | tr '\n' ' ')
  [ "$keys" = "description name " ] \
    || fail "$name: frontmatter keys are '$keys', expected 'description name '"

  fmlen=$(printf '%s' "$fm" | wc -c | tr -d ' ')
  [ "$fmlen" -le 1024 ] || fail "$name: frontmatter is $fmlen chars, limit 1024"

  grep -qE '^[[:space:]]*@[A-Za-z./]' "$f" \
    && fail "$name: contains an @-link, which force-loads the target"

  for d in $DELETED; do
    if grep -rqF "$d" "$dir"; then
      fail "$name: references deleted skill '$d'"
      grep -rnF "$d" "$dir" | sed 's/^/    /'
    fi
  done

  words=$(wc -w < "$f" | tr -d ' ')
  max=$(budget "$name")
  if [ "$max" -lt 0 ]; then
    fail "$name: no word ceiling defined"
  elif [ "$words" -gt "$max" ]; then
    fail "$name: SKILL.md is $words words, ceiling $max"
  fi
done

[ "$FAIL" -eq 0 ] \
  && echo "PASS: 9 skills, valid frontmatter, no @-links, no dangling references, all within ceiling"
exit "$FAIL"
```

- [ ] **Step 2: Run it and confirm it fails**

```bash
chmod +x tests/skills/check-skills.sh
bash tests/skills/check-skills.sh; echo "exit=$?"
```

Expected: `exit=1`, with a skill-set mismatch naming the 5 extra directories, "no word ceiling defined" for each of those 5, dangling-reference failures for `executing-plans`, `writing-plans` and `test-driven-development`, and over-ceiling failures for all 9 survivors.

- [ ] **Step 3: Commit**

```bash
git add tests/skills/check-skills.sh
git commit -m "test: add structural gate for the slim skill set

Checks the skill set is exactly the 9 survivors, frontmatter is exactly
name + description under 1024 chars, no @-links force-load between skills,
no file references a deleted skill, and each SKILL.md is within its word
ceiling. Fails against the current tree by design.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 3: Delete harness machinery

**Files:**
- Delete: `hooks/`, `.codex-plugin/`, `.cursor-plugin/`, `.kimi-plugin/`, `.opencode/`, `.pi/`, `.agents/`, `gemini-extension.json`, `GEMINI.md`, `package.json`, `.version-bump.json`, `scripts/bump-version.sh`, `assets/`, `docs/porting-to-a-new-harness.md`, `docs/windows/`, `docs/README.kimi.md`, `docs/README.opencode.md`, `tests/hooks/`, `tests/brainstorm-server/`, `tests/opencode/`, `tests/pi/`, `tests/kimi/`, `tests/antigravity/`, `tests/codex/`, `tests/codex-plugin-sync/`

- [ ] **Step 1: Confirm `assets/` has no consumer outside the Codex manifest**

```bash
grep -rn "app-icon\|superpowers-small" --include='*.md' --include='*.json' --include='*.js' --include='*.ts' . | grep -v docs/superpowers
```

Expected: only `.codex-plugin/plugin.json:44` and `:45`. If anything else appears, stop and report — `assets/` would not be an orphan and must be kept.

- [ ] **Step 2: Delete**

```bash
git rm -r -q hooks .codex-plugin .cursor-plugin .kimi-plugin .opencode .pi .agents assets \
  gemini-extension.json GEMINI.md package.json .version-bump.json scripts/bump-version.sh \
  docs/porting-to-a-new-harness.md docs/windows docs/README.kimi.md docs/README.opencode.md \
  tests/hooks tests/brainstorm-server tests/opencode tests/pi tests/kimi tests/antigravity \
  tests/codex tests/codex-plugin-sync
```

- [ ] **Step 3: Find references to what was just deleted**

```bash
grep -rn "hooks/\|session-start\|run-hook\|codex-plugin\|cursor-plugin\|kimi-plugin\|opencode\|\.pi/\|gemini-extension\|GEMINI\.md\|bump-version\|assets/" \
  --include='*.md' --include='*.json' --include='*.sh' . | grep -v docs/superpowers
```

Every hit outside `docs/superpowers/` must be repaired. `README.md` and `docs/testing.md` are the likely ones. Remove the sections describing deleted harnesses and deleted test directories; do not rewrite anything else in those files yet — `README.md` is finished in Task 12.

- [ ] **Step 4: Confirm `scripts/` is not now empty**

```bash
ls scripts/ 2>/dev/null || echo "scripts/ is gone"
```

If `lint-shell.sh` is the only remaining file, keep the directory — `.pre-commit-config.yaml` calls it. If the directory is empty, remove it and remove its hook from `.pre-commit-config.yaml`.

- [ ] **Step 5: Verify the plugin manifest still resolves**

```bash
cat .claude-plugin/plugin.json
```

Confirm no field references a deleted path. Claude Code auto-discovers `skills/`; with `hooks/hooks.json` gone there must be no `hooks` key pointing at it.

- [ ] **Step 6: Run the structural gate**

```bash
bash tests/skills/check-skills.sh; echo "exit=$?"
```

Expected: still `exit=1` — skills are untouched. Confirms the deletion broke nothing the gate watches.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore: drop non-Claude-Code harness support

Removes the session-start hook, six harness manifests (Codex, Cursor, Kimi,
OpenCode, pi, Gemini), their tests, the porting and Windows docs, the version
bump tooling, and assets/ (referenced only by the deleted Codex manifest).

Claude Code discovers skills/ by convention, so no bootstrap hook is needed
for skills to be invocable.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 4: Delete upstream governance artifacts

**Files:**
- Delete: `RELEASE-NOTES.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/ISSUE_TEMPLATE/`, `.github/FUNDING.yml`, `CODE_OF_CONDUCT.md`

- [ ] **Step 1: Delete**

```bash
git rm -r -q RELEASE-NOTES.md CODE_OF_CONDUCT.md \
  .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE .github/FUNDING.yml
```

- [ ] **Step 2: Check for references**

```bash
grep -rn "RELEASE-NOTES\|CODE_OF_CONDUCT\|PULL_REQUEST_TEMPLATE\|ISSUE_TEMPLATE\|FUNDING" \
  --include='*.md' . | grep -v docs/superpowers
```

Remove any hits found. `README.md` likely links the release notes.

- [ ] **Step 3: Check whether `.github/` still has contents**

```bash
find .github -type f 2>/dev/null || echo ".github/ is empty or gone"
```

If empty, remove the directory.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: drop upstream project governance files

Removes RELEASE-NOTES.md, the PR and issue templates, FUNDING.yml, and
CODE_OF_CONDUCT.md. These govern obra/superpowers' tracker and contribution
process, not this derivative.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 5: Delete the five skills and shipped dev artifacts

**Files:**
- Delete: `skills/using-superpowers/`, `skills/using-git-worktrees/`, `skills/subagent-driven-development/`, `skills/dispatching-parallel-agents/`, `skills/writing-skills/`
- Delete: `skills/systematic-debugging/test-academic.md`, `test-pressure-1.md`, `test-pressure-2.md`, `test-pressure-3.md`, `CREATION-LOG.md`
- Delete: `skills/brainstorming/visual-companion.md`, `skills/brainstorming/scripts/`, `skills/brainstorming/frame-template.html`, `skills/brainstorming/helper.js`

- [ ] **Step 1: Delete the five skills**

```bash
git rm -r -q skills/using-superpowers skills/using-git-worktrees \
  skills/subagent-driven-development skills/dispatching-parallel-agents \
  skills/writing-skills
```

- [ ] **Step 2: Delete dev artifacts from surviving skills**

```bash
git rm -r -q skills/systematic-debugging/test-academic.md \
  skills/systematic-debugging/test-pressure-1.md \
  skills/systematic-debugging/test-pressure-2.md \
  skills/systematic-debugging/test-pressure-3.md \
  skills/systematic-debugging/CREATION-LOG.md
git rm -r -q skills/brainstorming/visual-companion.md skills/brainstorming/scripts
git rm -q skills/brainstorming/frame-template.html skills/brainstorming/helper.js 2>/dev/null || true
```

If a path does not exist, confirm with `ls skills/brainstorming/` and adjust — the visual companion files may sit at different paths than listed.

- [ ] **Step 3: Confirm the surviving file inventory**

```bash
find skills -type f | sort
```

Expected, exactly:
```
skills/brainstorming/SKILL.md
skills/brainstorming/spec-document-reviewer-prompt.md
skills/executing-plans/SKILL.md
skills/finishing-a-development-branch/SKILL.md
skills/receiving-code-review/SKILL.md
skills/requesting-code-review/SKILL.md
skills/requesting-code-review/code-reviewer.md
skills/systematic-debugging/SKILL.md
skills/systematic-debugging/condition-based-waiting.md
skills/systematic-debugging/condition-based-waiting.ts
skills/systematic-debugging/defense-in-depth.md
skills/systematic-debugging/find-polluter.sh
skills/systematic-debugging/root-cause-tracing.md
skills/test-driven-development/SKILL.md
skills/test-driven-development/writing-good-tests.md
skills/verification-before-completion/SKILL.md
skills/writing-plans/SKILL.md
skills/writing-plans/plan-document-reviewer-prompt.md
```

Anything extra: decide whether it is a kept reference or an orphan, and report the decision.

- [ ] **Step 4: Run the structural gate**

```bash
bash tests/skills/check-skills.sh; echo "exit=$?"
```

Expected: `exit=1`, and the skill-set mismatch line is gone. Remaining failures are the 3 dangling references and the 9 over-ceiling counts. Confirm the mismatch line disappeared — that is this task's deliverable.

- [ ] **Step 5: Check kept references for dangling mentions**

```bash
grep -rn "using-superpowers\|using-git-worktrees\|subagent-driven-development\|dispatching-parallel-agents\|writing-skills" skills/
```

Expected exactly 6 hits: `executing-plans/SKILL.md` (2), `writing-plans/SKILL.md` (3), `test-driven-development/writing-good-tests.md` (1). These are repaired in Tasks 7 and 8 by rewriting the bodies. `writing-good-tests.md` is not rewritten, so fix it now.

- [ ] **Step 6: Repair `writing-good-tests.md:51`**

Change the parenthetical citation so the sentence stands without it. Current line:

```
agent's behavior (superpowers:writing-skills); prose for humans earns no
```

Becomes:

```
agent's behavior; prose for humans earns no
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "refactor: delete five skills and dev artifacts shipped to users

Removes using-superpowers (the bootstrap, redundant now that Claude Code
discovers skills natively), using-git-worktrees (worktree choice is a
judgement call, not a procedure), subagent-driven-development (runtime token
cost), dispatching-parallel-agents, and writing-skills. 23,554 words.

Also removes content that documented skill development rather than guiding
work: systematic-debugging's four preserved pressure-test scenarios and
CREATION-LOG, and brainstorming's visual companion server.

Repairs writing-good-tests.md's citation of the deleted writing-skills.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 6: Rewrite brainstorming

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (full replacement)

- [ ] **Step 1: Replace the file entirely**

```markdown
---
name: brainstorming
description: Use when turning an idea, feature request, or vague goal into a design, before writing code
---

# Brainstorming

1. Read the project context first — files, docs, recent commits.
2. Check scope. If the request spans several independent subsystems, decompose it before refining details, then brainstorm only the first sub-project. Each sub-project gets its own spec.
3. Ask clarifying questions one at a time, one question per message. Prefer multiple choice. Cover purpose, constraints, and success criteria.
4. Propose 2-3 approaches with their trade-offs. Lead with your recommendation and say why. Cut anything speculative from every approach.
5. Present the design in sections, each scaled to its complexity — a few sentences when it is straightforward. Ask after each section whether it holds before continuing. Cover architecture, components, data flow, error handling, and testing.
6. Give each unit one responsibility and a defined interface. For every unit, be able to say what it does, how it is used, and what it depends on. If someone cannot tell what a unit does without reading its internals, the boundary is wrong.
7. In an existing codebase, follow the established patterns. Include targeted cleanup where existing code blocks this work; leave unrelated problems alone and mention them instead.
8. Get explicit approval on the design before anything gets built.
9. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit it.
10. Re-read the spec: no placeholders, no sections contradicting each other, scope small enough for one plan, no requirement readable two ways. Fix inline.
11. Ask your partner to review the committed spec. Make any changes they ask for and re-check.

Terminal state: invoke writing-plans. Invoke no other skill from here.

Depth: spec-document-reviewer-prompt.md
```

- [ ] **Step 2: Verify the word count**

```bash
wc -w < skills/brainstorming/SKILL.md
```

Expected: 283, and at or under the 300 ceiling.

- [ ] **Step 3: Run the structural gate**

```bash
bash tests/skills/check-skills.sh 2>&1 | grep brainstorming; echo "exit=$?"
```

Expected: no `FAIL:` line mentioning `brainstorming`.

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "refactor(brainstorming): rewrite as a pure recipe

1,494 words to 283. Keeps every workflow step: context, scope decomposition,
one question per message, 2-3 approaches with a recommendation, sectioned
approval, unit boundaries, existing-codebase patterns, spec write and commit,
self-review, partner review. Keeps the exclusive terminal state on
writing-plans.

Drops the HARD-GATE block, the too-simple-to-design anti-pattern section, the
Graphviz flow, and the visual companion (deleted in the previous commit).

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 7: Rewrite writing-plans and executing-plans

These two are one task because `executing-plans` inherits the role `subagent-driven-development` vacated, and `writing-plans` names it as the handoff. A reviewer evaluating one without the other cannot tell whether the chain is intact.

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (full replacement)
- Modify: `skills/executing-plans/SKILL.md` (full replacement)

**Interfaces:**
- Produces: the plan-header line that every future plan carries, naming `executing-plans` as the only execution sub-skill. Task 14's comparison does not depend on it, but any plan written by this skill afterwards does.

- [ ] **Step 1: Replace `skills/writing-plans/SKILL.md` entirely**

```markdown
---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

Write for an engineer who knows the language but nothing about this codebase or problem domain. Every step carries what they need: exact paths, real code, real test code, the command to run and the output to expect.

1. Check scope. If the spec spans independent subsystems, write one plan per subsystem; each must produce working, testable software on its own.
2. Map the files before defining tasks — what gets created, what gets modified, what each is responsible for. One responsibility per file. Files that change together live together. Follow the codebase's existing patterns.
3. Draw task boundaries at the smallest unit that carries its own test cycle. Fold setup, config, scaffolding and docs into the task whose deliverable needs them. Split only where a reviewer could reject one task while approving its neighbour.
4. Break each task into 2-5 minute steps: write the failing test, run it and watch it fail, write minimal code, run it and watch it pass, commit.
5. Open the plan with the goal in one sentence, the architecture in two or three, the tech stack, and a Global Constraints section listing project-wide requirements with values copied verbatim from the spec.
6. Give each task a Files block with exact paths, and an Interfaces block naming what it consumes from earlier tasks and what later tasks rely on, with exact signatures. Each task's implementer sees only their own task.
7. Write steps as `- [ ]` checkboxes. Code steps carry the actual code in a fenced block. Verification steps carry the command and its expected output.
8. Save to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`.
9. Re-read the plan against the spec: every requirement has a task, no placeholders remain, and names and types match across tasks.

Never write "TBD", "add error handling", "handle edge cases", "write tests for the above", "similar to Task N", or any reference to a type or function no task defines. Repeat code rather than cross-referencing — tasks get read out of order.

Terminal state: invoke executing-plans.

Depth: plan-document-reviewer-prompt.md
```

- [ ] **Step 2: Replace `skills/executing-plans/SKILL.md` entirely**

```markdown
---
name: executing-plans
description: Use when you have a written implementation plan to execute task by task
---

# Executing Plans

1. Work on a branch, never directly on `main` or `master` — create one if needed. Where the work is long-running or would collide with other changes, an isolated worktree is worth it; decide that from the work in front of you, not from habit.
2. Read the plan in full.
3. Review it critically. Raise questions and concerns with your partner before starting, not halfway through.
4. Create a todo per task.
5. For each task: mark it in progress, follow its steps exactly as written, run every verification the plan specifies, then mark it complete.
6. Do not skip verifications and do not batch them to the end. The plan puts them where they are for a reason.
7. Stop and ask when you hit a blocker, a missing dependency, a verification that keeps failing, or an instruction you do not understand. Guessing costs more than asking.
8. If your partner revises the plan, return to step 2.

Terminal state: invoke finishing-a-development-branch.
```

- [ ] **Step 3: Verify word counts**

```bash
wc -w < skills/writing-plans/SKILL.md
wc -w < skills/executing-plans/SKILL.md
```

Expected: 358 and 185, under the 380 and 200 ceilings.

- [ ] **Step 4: Confirm the dangling references are gone**

```bash
grep -rn "subagent-driven-development\|using-git-worktrees" skills/writing-plans skills/executing-plans
```

Expected: no output.

- [ ] **Step 5: Run the structural gate**

```bash
bash tests/skills/check-skills.sh 2>&1 | grep -E "writing-plans|executing-plans"; echo "exit=$?"
```

Expected: no `FAIL:` line for either skill.

- [ ] **Step 6: Commit**

```bash
git add skills/writing-plans/SKILL.md skills/executing-plans/SKILL.md
git commit -m "refactor(plans): rewrite writing-plans and executing-plans as pure recipes

writing-plans 1,034 to 358 words, executing-plans 344 to 185. Keeps file
mapping before task definition, task right-sizing on the reviewer-rejection
test, 2-5 minute steps, the plan header with Global Constraints, Files and
Interfaces blocks, and the no-placeholders prohibition list.

executing-plans inherits the execution role from the deleted
subagent-driven-development: the note recommending SDD over itself is gone,
and workspace setup is now a judgement call in step 1 rather than a
delegation to the deleted using-git-worktrees.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 8: Rewrite test-driven-development

**Files:**
- Modify: `skills/test-driven-development/SKILL.md` (full replacement)

- [ ] **Step 1: Replace the file entirely**

```markdown
---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development

1. Write one small test for one behaviour. Name it after the behaviour, not the function.
2. Run it. Confirm it fails, and that it fails because the feature is missing rather than from a typo or a broken setup. A test that passes at this point is testing something that already works — fix the test.
3. Write the simplest code that makes it pass. No extra options, no unrelated cleanup, nothing the test does not ask for.
4. Run it again. Confirm it passes, the rest of the suite still passes, and the output is clean with no stray errors or warnings. If it fails, fix the code rather than the test.
5. Refactor while green: remove duplication, improve names, extract helpers. Add no behaviour.
6. Repeat for the next behaviour.

Production code that exists without a test that failed first: delete it and start at step 1. Keeping it as reference and adapting it while writing tests is testing after.

Assert on real behaviour, not on mock behaviour. Match test style to the surrounding suite. If a test is hard to write, the interface is probably hard to use — treat that as a design signal.

For a bug: write a test that reproduces it, watch it fail, then fix it. The test is what stops the bug coming back.

Terminal state: invoke requesting-code-review.

Depth: writing-good-tests.md
```

- [ ] **Step 2: Verify the word count**

```bash
wc -w < skills/test-driven-development/SKILL.md
```

Expected: 248, and at or under the 270 ceiling.

- [ ] **Step 3: Run the structural gate**

```bash
bash tests/skills/check-skills.sh 2>&1 | grep test-driven-development; echo "exit=$?"
```

Expected: no `FAIL:` line for `test-driven-development`. The `writing-good-tests.md` reference was repaired in Task 5.

- [ ] **Step 4: Commit**

```bash
git add skills/test-driven-development/SKILL.md
git commit -m "refactor(tdd): rewrite as a pure recipe

1,375 words to 248. Keeps the red-green-refactor cycle with both mandatory
verification points, the failing-for-the-right-reason check, minimal-code
discipline, delete-and-restart when code precedes its test, assert-on-real-
behaviour, the hard-to-test design signal, and the bugfix path.

Drops the Iron Law code fence, the Graphviz cycle, the good/bad code
examples, the ten-row rationalization table, the thirteen-item red flags
list, the worked bugfix example, and the verification checklist.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 9: Rewrite systematic-debugging

**Files:**
- Modify: `skills/systematic-debugging/SKILL.md` (full replacement)

- [ ] **Step 1: Replace the file entirely**

```markdown
---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

## Find the root cause

1. Read the error and the full stack trace. Note line numbers, paths, and codes. The answer is often already in there.
2. Reproduce it. Establish the exact steps and whether it happens every time. Not reproducible means gather more data, not guess.
3. Check what changed — recent commits, new dependencies, config, environment.
4. In a system with multiple components, instrument every boundary before proposing anything: log what enters each component, what leaves it, and whether config and environment propagated. Run once, then read the evidence to find which layer breaks.
5. Trace the bad value backward — where it originated, what passed it in — until you reach the source. Fix there, not at the symptom.

## Compare against what works

6. Find similar working code in this codebase.
7. If you are applying a pattern, read the reference implementation completely. Skimming it produces bugs.
8. List every difference between the working case and the broken one, however small.

## Test one hypothesis

9. State it plainly: X is the root cause because Y.
10. Make the smallest change that tests it. One variable at a time.
11. If it did not work, form a new hypothesis. Do not stack another fix on top of the last one.
12. Say plainly when you do not understand something rather than proceeding as if you do.

## Fix at the source

13. Write a failing test that reproduces the bug, before fixing anything.
14. Make one change, at the root cause. No bundled refactoring, no while-I-am-here improvements.
15. Verify: the test passes, nothing else broke, the original symptom is gone.
16. Count your failed fixes. At three, stop fixing and question the architecture with your partner. Fixes that each surface a new problem somewhere else mean the design is wrong, not the hypothesis.

If investigation shows the cause is genuinely environmental, timing-dependent, or external, document what you ruled out, add appropriate handling and monitoring, and say so explicitly.

Terminal state: invoke test-driven-development to lock the fix in with a regression test.

Depth: root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md
```

- [ ] **Step 2: Verify the word count**

```bash
wc -w < skills/systematic-debugging/SKILL.md
```

Expected: 371, and at or under the 400 ceiling.

- [ ] **Step 3: Run the structural gate**

```bash
bash tests/skills/check-skills.sh 2>&1 | grep systematic-debugging; echo "exit=$?"
```

Expected: no `FAIL:` line for `systematic-debugging`.

- [ ] **Step 4: Commit**

```bash
git add skills/systematic-debugging/SKILL.md
git commit -m "refactor(systematic-debugging): rewrite as a pure recipe

1,440 words to 371. Keeps all four phases and every step inside them:
full stack trace, consistent reproduction, recent changes, boundary
instrumentation in multi-component systems, backward tracing to source,
working-example comparison, complete reference reads, single stated
hypothesis, smallest test, failing test before the fix, one change at the
root cause, and the three-failed-fixes architectural stop.

Drops the Iron Law code fence, the when-to-use and dont-skip lists, the
eleven-item red flags list, the partner-signals section, the eight-row
rationalization table, the quick reference table, and the multi-layer bash
example.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 10: Rewrite requesting-code-review and receiving-code-review

Paired because the terminal state of the first is the second, and the review loop is only coherent read together.

**Files:**
- Modify: `skills/requesting-code-review/SKILL.md` (full replacement)
- Modify: `skills/receiving-code-review/SKILL.md` (full replacement)

- [ ] **Step 1: Replace `skills/requesting-code-review/SKILL.md` entirely**

```markdown
---
name: requesting-code-review
description: Use when work is implemented and needs review before merging
---

# Requesting Code Review

1. Capture the range: `BASE_SHA=$(git rev-parse HEAD~1)` — or `origin/main` for a whole branch — and `HEAD_SHA=$(git rev-parse HEAD)`.
2. Dispatch a `general-purpose` subagent using the template in `code-reviewer.md`, filling in what you built, what it was supposed to do, and the two SHAs.
3. Give the reviewer that crafted context and nothing else — never your session history. The diff and the reading of it stay in the reviewer's context; only the findings come back into yours.
4. Fix Critical findings before anything else, Important findings before moving on, and note Minor ones.
5. Where the reviewer is wrong, push back with technical reasoning and point at the tests or code that prove it.

Terminal state: invoke receiving-code-review to work through the findings.

Depth: code-reviewer.md
```

- [ ] **Step 2: Replace `skills/receiving-code-review/SKILL.md` entirely**

```markdown
---
name: receiving-code-review
description: Use when code review feedback has arrived, before implementing the suggestions
---

# Receiving Code Review

1. Read all the feedback before reacting to any of it.
2. Restate each item as a technical requirement in your own words. If any item is unclear, stop and ask about it before implementing anything — items are often related, and partial understanding produces the wrong fix.
3. Check each item against the codebase. Does it hold here? Does it break something that currently works? Is there a reason the code is the way it is? Does the reviewer have the full context?
4. Where a suggestion adds a feature nothing uses, grep for callers first and say what you found. An endpoint nothing calls should be removed, not implemented properly.
5. Where a suggestion is wrong, push back with technical reasoning and point at the tests or code that show it. Where it conflicts with a decision your partner already made, raise it with them rather than choosing for them.
6. Where you cannot verify a claim, say what you would need to verify it instead of proceeding on assumption.
7. Implement in order: things that break or are insecure, then simple fixes, then complex ones. Test each fix on its own and check for regressions.
8. Answer correct feedback by stating the fix and where it landed. Skip the agreement and the thanks — the change is the answer.
9. If you pushed back and turned out to be wrong, say what you checked and what it showed, then fix it. No apology, no defence of the pushback.

On GitHub, reply inside the comment thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as a new top-level PR comment.

Terminal state: invoke verification-before-completion.
```

- [ ] **Step 3: Verify word counts**

```bash
wc -w < skills/requesting-code-review/SKILL.md
wc -w < skills/receiving-code-review/SKILL.md
```

Expected: 145 and 292, under the 190 and 330 ceilings.

- [ ] **Step 4: Run the structural gate**

```bash
bash tests/skills/check-skills.sh 2>&1 | grep -E "requesting-code-review|receiving-code-review"; echo "exit=$?"
```

Expected: no `FAIL:` line for either skill.

- [ ] **Step 5: Commit**

```bash
git add skills/requesting-code-review/SKILL.md skills/receiving-code-review/SKILL.md
git commit -m "refactor(review): rewrite the review pair as pure recipes

requesting-code-review 421 to 145 words, receiving-code-review 913 to 292.
Keeps SHA capture, crafted-context-not-session-history, the severity fix
order, verify-before-implementing, stop-and-clarify on unclear items, the
YAGNI grep, reasoned pushback, escalation when feedback conflicts with a
partner decision, no performative agreement or thanks, factual self-
correction, and GitHub thread replies.

Drops the mandatory/optional when-to-request lists, the worked dispatch
example, both rationalization tables, the red flags list, the source-specific
pseudocode blocks, the common mistakes table, and the four real examples.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 11: Rewrite verification-before-completion and finishing-a-development-branch

Paired as the closing gates: the first is the precondition for the second.

**Files:**
- Modify: `skills/verification-before-completion/SKILL.md` (full replacement)
- Modify: `skills/finishing-a-development-branch/SKILL.md` (full replacement)

- [ ] **Step 1: Replace `skills/verification-before-completion/SKILL.md` entirely**

```markdown
---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating a PR
---

# Verification Before Completion

Before any statement that work is done, fixed, passing, or good:

1. Name the command that would prove the claim.
2. Run it fresh and in full — not a subset, not a remembered earlier run.
3. Read the whole output. Check the exit code. Count the failures.
4. State the claim together with that evidence, or state the actual status together with that evidence.

What each claim actually requires:

| Claim | Evidence |
|---|---|
| Tests pass | Test command output showing 0 failures |
| Linter clean | Linter output showing 0 errors |
| Build succeeds | Build command exiting 0 |
| Bug fixed | The original symptom retested, now passing |
| Regression test works | Reverted the fix, watched the test fail, restored it |
| A subagent finished | The VCS diff, not the agent's report |
| Requirements met | The requirements re-read line by line |

This covers paraphrases, synonyms, and any wording that implies success — including expressions of satisfaction offered before the command has run.

Terminal state: invoke finishing-a-development-branch once the whole branch is done.
```

- [ ] **Step 2: Replace `skills/finishing-a-development-branch/SKILL.md` entirely**

```markdown
---
name: finishing-a-development-branch
description: Use when implementation is complete and tests pass, and the work needs integrating
---

# Finishing a Development Branch

1. Run the project's full test suite. If anything fails, report the failures and stop — the menu comes only after a green suite.
2. Detect the workspace, capturing all three values now, before anything changes directory:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

3. Establish the base branch from the plan, the conversation, or the branch's upstream. If it is not already known, ask — merging into the wrong base is expensive to undo.
4. Present the menu exactly as written, then wait. The integration decision is your partner's.

Normal repo, or a worktree on a named branch:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

Detached HEAD, meaning an externally managed workspace — no merge option:

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

5. **Merge locally:** `cd` to the main repo root, then `git checkout <base>`, `git pull`, `git merge <feature>`, then run the tests on the merged result. If they fail, stop and leave the branch and worktree in place — nothing was pushed, so it is recoverable. Once green, clean up per step 7, then `git branch -d <feature>`.
6. **Push and PR:** `git push -u origin <feature>`, or from a detached HEAD `git push origin HEAD:refs/heads/<new-branch>`. Open the request against the base branch using the forge's CLI or the URL it prints on push, following the repo's PR template if it has one, and report the URL. Keep the worktree — PR feedback gets fixed there.
7. **Cleanup**, for a local merge only. Run it from outside the worktree, using the values captured in step 2. If `GIT_DIR` equals `GIT_COMMON` there is no worktree to remove. If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/` it is ours: `git worktree remove "$WORKTREE_PATH"` then `git worktree prune`. Otherwise the host environment owns it — leave it in place.

Discarding the work happens only when your partner asks for it in so many words. Show exactly what will be deleted — branch, commit list, worktree path — and wait for them to type `discard` before `git branch -D`.
```

- [ ] **Step 3: Verify word counts**

```bash
wc -w < skills/verification-before-completion/SKILL.md
wc -w < skills/finishing-a-development-branch/SKILL.md
```

Expected: 213 and 426, under the 230 and 470 ceilings.

- [ ] **Step 4: Run the full structural gate — it must now pass**

```bash
bash tests/skills/check-skills.sh; echo "exit=$?"
```

Expected: `exit=0` and `PASS: 9 skills, valid frontmatter, no @-links, no dangling references, all within ceiling`. This is the GREEN that Task 2 set up. If any failure remains, fix it before committing.

- [ ] **Step 5: Record the final word counts**

```bash
for d in skills/*/; do
  printf "%-32s %s\n" "$(basename "$d")" "$(wc -w < "$d/SKILL.md" | tr -d ' ')"
done | tee /tmp/after-words.txt
awk '{s+=$2} END {print "TOTAL " s}' /tmp/after-words.txt
```

- [ ] **Step 6: Commit**

```bash
git add skills/verification-before-completion/SKILL.md skills/finishing-a-development-branch/SKILL.md
git commit -m "refactor(closing): rewrite the closing gates as pure recipes

verification-before-completion 580 to 213 words,
finishing-a-development-branch 1,150 to 426. All nine skills now pass
tests/skills/check-skills.sh.

verification keeps the four-step gate and the claim-to-evidence table, and
keeps the rule extending to paraphrase and to satisfaction expressed before
the command runs. Drops the Iron Law fence, the red flags list, the eight-row
rationalization table, and the key patterns section.

finishing keeps the green-suite precondition, the three captured git values,
base branch confirmation, both menus verbatim, all three integration paths,
provenance-based worktree cleanup restricted to .worktrees/ and worktrees/,
and the typed-'discard' confirmation. Drops the state and quick-reference
tables and the nine-row rationalization table.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 12: New CLAUDE.md and README attribution

**Files:**
- Create: `CLAUDE.md`
- Create: `AGENTS.md` (symlink to `CLAUDE.md`)
- Modify: `README.md`

- [ ] **Step 1: Write `CLAUDE.md`**

```markdown
# Contributor Guidelines

A set of 9 skills for Claude Code, reduced from [obra/superpowers](https://github.com/obra/superpowers)
for Claude 5 generation models. Skills only — no session-start hook, no other harness.

## Gotchas

- Skills are behavior-shaping prose, not code. A change that reads well can still make behavior worse,
  so changes get tested behaviorally, not just reviewed.
- `SKILL.md` loads in full the moment a skill is invoked. Files in the same directory load only when
  the model follows a pointer to them. Put depth in a separate file and point at it.
- Frontmatter is exactly two keys, `name` and `description`, at most 1024 characters total.
- A description says *when* to use the skill. It never summarizes the workflow — a description that
  summarizes becomes a shortcut the model takes instead of reading the body.
- Never `@`-link between skills. `@` force-loads the target immediately, whether or not it is needed.
- Skill anatomy is fixed: title, numbered steps, terminal-state line, reference pointers. Nothing else.
- Per-skill word ceilings live in `tests/skills/check-skills.sh`. Raise a ceiling rather than dropping
  a workflow step.

## Testing

`bash tests/skills/check-skills.sh` is the structural gate — run it after any skill edit.

Behavioral tests and how to interpret them: `docs/testing.md`.
```

- [ ] **Step 2: Create the `AGENTS.md` symlink**

Upstream shipped `AGENTS.md` as a symlink to `CLAUDE.md` so both conventions resolve to one file. Restore it:

```bash
ln -s CLAUDE.md AGENTS.md
git add CLAUDE.md AGENTS.md
git status --short
```

Confirm `AGENTS.md` is staged as a symlink (mode `120000`):

```bash
git ls-files -s AGENTS.md
```

- [ ] **Step 3: Verify the word count**

```bash
wc -w < CLAUDE.md
```

Expected: 204, and at or under the 250 target from the spec.

- [ ] **Step 4: Update `README.md`**

Read it, then make exactly these changes and nothing else:

1. Add an attribution paragraph near the top: this is a reduced derivative of obra/superpowers, MIT, Claude Code only, 9 skills, no session-start hook.
2. Remove every mention of the five deleted skills.
3. Remove every mention of a non-Claude-Code harness — Codex, Cursor, Kimi, OpenCode, pi, Gemini, Copilot, Antigravity, Droid — including any installation instructions for them.
4. Remove links to deleted files: `RELEASE-NOTES.md`, `docs/porting-to-a-new-harness.md`, `docs/README.kimi.md`, `docs/README.opencode.md`, `CODE_OF_CONDUCT.md`.
5. Remove any claim that a session-start hook or bootstrap injects anything.

- [ ] **Step 5: Confirm no dead links remain**

```bash
grep -oE '\]\([^)h][^)]*\)' README.md | tr -d '](' | tr -d ')' | while read -r p; do
  [ -e "$p" ] || echo "DEAD: $p"
done
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md AGENTS.md README.md
git commit -m "docs: new CLAUDE.md and README for the slim skill set

CLAUDE.md written from scratch, under 250 words: two lines of identity, the
rest spent on gotchas that are not visible from the file system — how
SKILL.md and reference loading differ, the frontmatter contract, why a
description must not summarize its workflow, why @-links are banned, and
where the word ceilings live. Restores AGENTS.md as a symlink to it.

README loses the five deleted skills, all non-Claude-Code harnesses, links
to deleted files, and the bootstrap claim; gains attribution to
obra/superpowers.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 13: Retarget the behavioral test suite

Runs after the rewrite so that Task 14's before/after comparison uses the prompts the baseline was captured with. Retargeted prompts get their own fresh baseline here.

**Files:**
- Modify: `tests/explicit-skill-requests/run-all.sh`
- Modify: `tests/explicit-skill-requests/prompts/subagent-driven-development-please.txt`
- Modify: `tests/explicit-skill-requests/prompts/mid-conversation-execute-plan.txt`
- Modify: `tests/explicit-skill-requests/prompts/i-know-what-sdd-means.txt`
- Modify: `tests/explicit-skill-requests/prompts/skip-formalities.txt`
- Modify: `tests/explicit-skill-requests/prompts/action-oriented.txt`, `after-planning-flow.txt`, `claude-suggested-it.txt` (only if they name a deleted skill)
- Modify: `docs/testing.md`

- [ ] **Step 1: Find every prompt naming a deleted skill**

```bash
grep -rln "subagent-driven-development\|using-git-worktrees\|dispatching-parallel-agents\|writing-skills\|using-superpowers\|\bsdd\b" \
  tests/explicit-skill-requests/prompts/
```

- [ ] **Step 2: Retarget each one to `executing-plans`**

For every file found, replace the deleted skill name with `executing-plans` and keep the resistance framing intact — that framing is what makes the test adversarial. Rename files whose name embeds the old skill:

```bash
git mv tests/explicit-skill-requests/prompts/subagent-driven-development-please.txt \
       tests/explicit-skill-requests/prompts/executing-plans-please.txt
git mv tests/explicit-skill-requests/prompts/i-know-what-sdd-means.txt \
       tests/explicit-skill-requests/prompts/i-know-what-executing-plans-means.txt
```

Do not soften a prompt while editing it. `skip-formalities.txt`'s "Don't waste time - just read the plan and start dispatching subagents immediately" becomes "Don't waste time - just read the plan and start implementing immediately". The pressure stays; only the skill name changes.

- [ ] **Step 3: Update `run-all.sh`**

Tests 1 and 4 assert `subagent-driven-development`. Change both to `executing-plans` and update the prompt paths and the echoed test names to match the renamed files. Leave tests 2 and 3 alone — they target `systematic-debugging` and `brainstorming`, which both survive.

- [ ] **Step 4: Confirm no test references a deleted skill**

```bash
grep -rn "subagent-driven-development\|using-git-worktrees\|dispatching-parallel-agents\|writing-skills\|using-superpowers" tests/
```

Expected: no output.

- [ ] **Step 5: Update `docs/testing.md`**

Remove the sections describing test directories deleted in Task 3, and add `tests/skills/check-skills.sh` and `tests/claude-code/test-brainstorming-autotrigger.sh` with a line each on what they assert.

- [ ] **Step 6: Run the retargeted suite to establish its own baseline**

```bash
bash tests/explicit-skill-requests/run-all.sh 2>&1 | tee /tmp/after-explicit-retargeted.txt
```

Record the result. This number has no before-counterpart — the prompts are new. It is the starting point for future comparisons, not evidence about this change.

- [ ] **Step 7: Commit**

```bash
git add -A tests docs/testing.md
git commit -m "test: retarget the adversarial trigger suite to the surviving skills

Four prompts and both run-all.sh assertions named
subagent-driven-development. They now name executing-plans, which inherited
the execution role. Resistance framing is unchanged — only the skill name
moved, so the prompts stay adversarial.

Updates docs/testing.md for the deleted harness test directories and adds
the two new gates.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Task 14: After-measurement, comparison, decision gate

The task the whole plan exists to reach. It produces the evidence for the quality criterion, and a stop-or-ship decision.

**Files:**
- Create: `docs/superpowers/baseline/2026-08-04-after.md`

- [ ] **Step 1: Isolate the hook's contribution**

The baseline ran with the hook present *and* the original skill bodies. This run separates the two causes so a regression can be attributed. Check out the pre-rewrite tree with only the hook deleted, into a temporary directory:

```bash
HOOKLESS=$(mktemp -d)
git worktree add "$HOOKLESS" 9e57966
rm -rf "$HOOKLESS/hooks"
bash tests/claude-code/test-brainstorming-autotrigger.sh "$HOOKLESS" 2>&1 \
  | tee /tmp/intermediate-autotrigger.txt
```

Record the result. Three data points now exist: original plus hook, original minus hook, rewritten minus hook. A regression between the first two is the hook's doing; a regression between the second and third is the rewrite's.

- [ ] **Step 2: Clean up the temporary worktree**

```bash
git worktree remove "$HOOKLESS"
git worktree prune
```

- [ ] **Step 3: Run the decisive measurement against the rewritten tree**

```bash
bash tests/claude-code/test-brainstorming-autotrigger.sh 2>&1 | tee /tmp/after-autotrigger.txt; echo "exit=$?"
```

- [ ] **Step 4: Run the two structural gates**

```bash
bash tests/skills/check-skills.sh; echo "check-skills exit=$?"
bash scripts/lint-shell.sh 2>&1 | tail -5; echo "shell-lint exit=$?"
```

Expected: `check-skills exit=0`. If `scripts/lint-shell.sh` was removed in Task 3, skip it and say so.

- [ ] **Step 5: Capture final word counts and compute the reduction**

```bash
for d in skills/*/; do
  n=$(basename "$d")
  printf "%-32s SKILL.md:%6s  all-md:%6s\n" "$n" \
    "$(wc -w < "$d/SKILL.md" | tr -d ' ')" \
    "$(find "$d" -name '*.md' -exec cat {} + | wc -w | tr -d ' ')"
done | tee /tmp/after-words.txt
```

Compute both totals against the baseline's 8,751 `SKILL.md` words and 40,130 all-markdown words, and state both percentages.

- [ ] **Step 6: Write the comparison record**

Create `docs/superpowers/baseline/2026-08-04-after.md` with:

1. The three auto-trigger results side by side — original-with-hook, original-without-hook, rewritten-without-hook — each with its pass/fail and whether files were written before the Skill call.
2. `check-skills.sh` output.
3. The word-count table with before, after, and percentage per skill, plus both totals.
4. A one-line verdict: did `brainstorming` still auto-trigger before any file was written, yes or no.
5. If it regressed, which of the two causes the intermediate run points at.

- [ ] **Step 7: The decision gate**

Report to your partner and stop for their decision. Do not proceed past this point on your own judgement.

**If the after-run passes** — `brainstorming` triggered and no file was written first — the quality criterion held. Report the token reduction and the passing result, and say the branch is ready.

**If the after-run fails**, report which cause the intermediate run implicates and recommend the matching recovery. Do not apply it without approval.

- Regression appears when the hook is removed, before any rewrite: native description-based discovery alone is insufficient on this model. Recovery is an ~80-word bootstrap carrying only the pre-response gate — decision 4 revisited.
- Regression appears only after the rewrite: the skill bodies or descriptions lost something binding. Recovery is one-line Iron Laws restored to the affected skills, roughly 15 words each — decision 7 revisited.
- Both regress: apply the description-level fix first, since it costs nothing in always-on context. Re-measure before adding anything larger.

- [ ] **Step 8: Commit**

```bash
git add docs/superpowers/baseline/2026-08-04-after.md
git commit -m "test: record post-rewrite measurements and comparison

Three auto-trigger data points: original with hook, original without hook,
rewritten without hook. Separating them makes any regression attributable to
either hook removal or the rewrite rather than to the change as a whole.

Records the structural gate result and the per-skill word reduction.

Claude-Session: https://claude.ai/code/session_01KrScc6AeUqnvaZGb4x5tKm"
```

---

## Self-review

**Spec coverage.** Every spec section maps to a task: goal and success criteria → Tasks 1, 11, 14. Deletions, all five subsections → Tasks 3, 4, 5. Flagged-not-deleted (`docs/plans/`, `docs/superpowers/plans/`) → untouched by design, no task needed. Retained-by-license → Global Constraints plus Task 12 step 4. The six dangling references → Task 5 step 6 (`writing-good-tests.md`) and Tasks 7's rewrites (the other five). Skill anatomy → Global Constraints, enforced by Task 2. Descriptions table → Tasks 6-11, one description per rewrite. Rewrite targets → Task 2's `budget()` and the revised table above. References-kept → Task 5 step 3's expected inventory. Chain → the terminal-state line in each rewritten body. New CLAUDE.md → Task 12. Verification, all four numbered steps → Tasks 1, 13, 14. Resulting tree → Task 5 step 3 for `skills/`, Tasks 3 and 4 for the rest. Git commit sequence → the fourteen commits, reordered so the structural gate lands second and the test retarget follows the rewrite. Out-of-scope items appear in no task.

Two additions beyond the spec, both to make an untestable criterion testable: `tests/skills/check-skills.sh` (Task 2), and the hook-isolation run (Task 14 step 1). The spec called for one before/after comparison; a single comparison cannot attribute a regression to hook removal versus rewrite, and the recovery differs by cause.

One documented deviation: the spec's 1,650-word target is revised to 2,521 (71% rather than 81%), with per-skill measured counts in Global Constraints. Every body in this plan is literal text and every count comes from `wc -w`, so the revised figure is measured rather than estimated. No workflow step was dropped to approach the original number.

**Placeholder scan.** No "TBD", no "add error handling", no "handle edge cases", no "similar to Task N", no "write tests for the above". Every rewritten `SKILL.md` appears in full. Every verification step names its command and expected output. `<base-branch>`, `<feature-branch>`, `<topic>` and `<feature-name>` inside skill bodies are runtime placeholders in the skills' own text, not gaps in the plan. Task 12 step 4 gives five enumerated edits rather than pasted README text, because `README.md` has not been read yet — the edits are specific enough to verify, and step 5 checks the result mechanically.

**Type consistency.** `check-skills.sh` is created in Task 2 and called in Tasks 3, 5, 6, 7, 8, 9, 10, 11, 14 — same path, no arguments, throughout. `test-brainstorming-autotrigger.sh` is created in Task 1 taking one optional plugin-dir argument, and called with an argument in Task 14 step 1 and without one in Task 14 step 3, matching its signature. The nine names in `budget()` match the nine directory names in `EXPECTED`, the nine rewrite tasks, and Task 5 step 3's inventory. Ceilings in `budget()` are consistently above the drafted counts in the revision table. `GIT_DIR`, `GIT_COMMON` and `WORKTREE_PATH` are captured in step 2 of the rewritten `finishing-a-development-branch` and consumed in its step 7, as in the original.

## Known fragilities

Called out rather than hidden:

- Tasks 1 and 14 depend on `claude -p` with `--plugin-dir`, `--dangerously-skip-permissions` and `--output-format stream-json`. If any flag has changed, both scripts need adjusting before their numbers mean anything.
- The auto-trigger test is one sample per run. A single pass is weak evidence. If the result matters to a decision, run it three times and report all three.
- `--max-turns 3` may cut off a run before a skill is invoked, producing a false FAIL. If a run fails, re-check with a higher limit before concluding anything.
- Task 12 step 4 edits `README.md` without having read it. If its structure does not match the five described changes, stop and report rather than improvising.
