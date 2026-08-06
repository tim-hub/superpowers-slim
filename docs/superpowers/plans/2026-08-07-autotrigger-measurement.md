# Autotrigger Measurement — Implementation Plan

Spec: `docs/superpowers/specs/2026-08-07-autotrigger-measurement-design.md`
Issue: [#1](https://github.com/tim-hub/superpowers-slim/issues/1)
Branch: `fix/autotrigger-measurement`

## Goal

Make the behavioral harness measure whether this plugin's skills autotrigger, then measure four
configurations at 15 runs each and replace the refuted numbers in
`docs/superpowers/baseline/2026-08-04-after.md`.

## Architecture

Two shell layers. `tests/claude-code/measure-autotrigger.sh` runs one tree N times and prints a rate,
asserting nothing about whether the skill fired — that is probabilistic and cannot gate a repository.
`tests/claude-code/measure-configs.sh` builds four git worktrees and calls the first script once per
configuration. The explicit-request suite in `tests/explicit-skill-requests/` stays a pass/fail gate.

## Tech stack

Bash 3.2+ (macOS system bash), `jq`, `git worktree`, the `claude` CLI at 2.1.223 or later. No new
dependencies. Lint with `scripts/lint-shell.sh`.

## Global Constraints

Copied verbatim from the spec. Every task must honour these.

- **Neutral working directory.** No agent under measurement sees `superpowers`, a skill name, or `test`
  in its working directory. Workspaces live at `${TMPDIR:-/tmp}/ws-<ts>-<pid>-<i>`, outside the log
  directory.
- **`--setting-sources project` on every `claude` invocation in `tests/`.** It drops personal skills,
  the user's SessionStart hooks, and the global `~/.claude/CLAUDE.md`. Measured: 88 registered slash
  commands drop to 54, bare `brainstorming` disappears leaving only `superpowers:brainstorming`, user
  hooks fired drops from 1 to 0, and a CLAUDE.md phrase probe flips from "Yes" to "No".
- **Never touch `HOME`.** Authentication depends on it and there is nothing to seed. An empty `HOME`, one
  seeded with `oauthAccount`/`userID`/`hasCompletedOnboarding`, and one with the whole `~/.claude.json`
  copied in all return `"Not logged in · Please run /login"`.
- **A skill invocation counts only when prefixed `superpowers:`.**
- **Every measurement run executes outside the command sandbox.** Inside one, a plugin SessionStart hook
  fails with `EPERM: operation not permitted, mkdir '/Users/hbai/.claude/plugins/data/superpowers-inline'`
  and the injection never reaches the model.
- **A run whose plugin hook failed is discarded, not counted.** Assert
  `hook_response.outcome == "success"` on any tree that ships `hooks/hooks.json`.
- **`--verbose` alongside `--print` and `--output-format stream-json`.** Without it the CLI exits
  immediately and the harness reports a FAIL that looks behavioral but is not.
- **N=15 per configuration, `--max-turns 8`.**
- **Success is trustworthy numbers, not `brainstorming` firing.** All four configurations reading 0/15 is
  a successful outcome.

## Pre-existing dead code — mention, do not touch

`tests/claude-code/test-helpers.sh` is sourced by no live file. Its `run_claude` at line 19 uses a bare
`timeout`. Task 1 fixes that one line for portability because issue #1 names it, but the function has no
callers and the fix changes no behavior. Do not delete the file; it predates this work.

---

## Task 1: Restore the reverted harness fix

`a757bc2` already implements the neutral cwd, portable `timeout` resolution, a `$$` suffix against
same-second log collisions, and the correction of `run-test.sh`'s false "isolated HOME" comment. It was
reverted by `efefef4` for sequencing. Restore it.

### Files

- Modified: `tests/claude-code/test-brainstorming-autotrigger.sh`
- Modified: `tests/explicit-skill-requests/run-test.sh`
- Modified: `tests/explicit-skill-requests/run-multiturn-test.sh`
- Modified: `tests/explicit-skill-requests/run-haiku-test.sh`
- Modified: `tests/explicit-skill-requests/run-extended-multiturn-test.sh`
- Modified: `tests/claude-code/test-helpers.sh`

### Interfaces

Consumes nothing from earlier tasks.

Later tasks rely on:

- `TIMEOUT_BIN` — a shell variable set by `TIMEOUT_BIN=$(command -v gtimeout || command -v timeout || true)`,
  used as `${TIMEOUT_BIN:+$TIMEOUT_BIN 300}` immediately before `claude`. Empty means run unwrapped.
- Workspace path convention `${TMPDIR:-/tmp}/ws-${TIMESTAMP}-$$`, always outside `OUTPUT_DIR`.
- Log path convention `${TMPDIR:-/tmp}/superpowers-tests/${TIMESTAMP}-$$/<test>/`.

### Steps

- [ ] Confirm you are on the right branch and the tree is clean:

```bash
git rev-parse --abbrev-ref HEAD   # expect: fix/autotrigger-measurement
git status --porcelain            # expect: no output
```

- [ ] Cherry-pick the reverted fix:

```bash
git cherry-pick a757bc2
```

Expected: `[fix/autotrigger-measurement <sha>] fix(tests): stop the harness leaking the answer into the agent's cwd`
followed by `5 files changed, 28 insertions(+), 16 deletions(-)`.

- [ ] Verify all five scripts changed and the cwd leak is gone from the two that matter:

```bash
git show --stat HEAD | tail -8
grep -n 'PROJECT_DIR=' tests/claude-code/test-brainstorming-autotrigger.sh \
  tests/explicit-skill-requests/run-test.sh
```

Expected: `PROJECT_DIR` is `${TMPDIR:-/tmp}/ws-${TIMESTAMP}-$$` in both, with no `$OUTPUT_DIR` in the
value.

- [ ] Verify the false HOME comment is gone:

```bash
grep -c "Uses isolated HOME" tests/explicit-skill-requests/run-test.sh
```

Expected: `0`.

- [ ] Fix the one remaining bare `timeout`, in the unreachable helper. Replace line 19 of
  `tests/claude-code/test-helpers.sh`:

```bash
    # Run Claude in headless mode with timeout
    if timeout "$timeout" "${cmd[@]}" > "$output_file" 2>&1; then
```

with:

```bash
    # Run Claude in headless mode with timeout. macOS has no timeout(1) unless
    # coreutils is installed, so resolve gtimeout first and run unwrapped if neither exists.
    local timeout_bin
    timeout_bin=$(command -v gtimeout || command -v timeout || true)
    if ${timeout_bin:+$timeout_bin "$timeout"} "${cmd[@]}" > "$output_file" 2>&1; then
```

- [ ] Verify no bare `timeout` invocation remains anywhere in `tests/`:

```bash
grep -rn '^\s*timeout \|[^_a-zA-Z]timeout "' tests/ --include='*.sh' | grep -v 'timeout_bin\|TIMEOUT_BIN\|local timeout'
```

Expected: only `tests/claude-code/run-skill-tests.sh` lines 103 and 123. That file is deleted in Task 3.

- [ ] Lint and commit:

```bash
bash scripts/lint-shell.sh
git add tests/claude-code/test-helpers.sh
git commit -m "fix(tests): resolve gtimeout before timeout in the unreachable run_claude helper

Issue #1 names test-helpers.sh:19 among the bare timeout call sites. The
function has no callers, so this changes no behavior; it stops the last
non-portable invocation in tests/ outside the file Task 3 deletes."
```

Expected: `lint-shell.sh` exits 0.

---

## Task 2: Exclude the user setting source, require the prefix, fix the turn budget

The explicit-request suite currently accepts an unprefixed skill invocation, so a personal
`~/.claude/skills` copy of the same name satisfies its assertion. Pass `--setting-sources project` so the
personal copy is not loaded, and require the `superpowers:` prefix so the plugin is provably the answerer.

Doing only that turns one of the four tests red, and it was measured before this plan was written.
`use-systematic-debugging` fails at `run-test.sh`'s default `MAX_TURNS=3` with `error_max_turns` at
`num_turns 4`: `superpowers:systematic-debugging` is registered, but its prompt
(`use systematic-debugging to figure out what's wrong`) names no actual bug, so the model spends the
budget exploring — 2 `Bash` calls and 1 `Read` — before it can invoke anything. At `--max-turns 8` the
skill fired in 3 of 3 runs. So the third change here is the turn budget, and the gate ends green.

Measured probe, `--setting-sources project`, prefix-anchored, current tree:

```
executing-plans-please          max-turns 3   superpowers:executing-plans        fired
use-systematic-debugging        max-turns 3   nothing fired, error_max_turns     FAILED
please-use-brainstorming        max-turns 3   superpowers:brainstorming          fired
mid-conversation-execute-plan   max-turns 3   superpowers:executing-plans        fired
use-systematic-debugging        max-turns 8   superpowers:systematic-debugging   fired 3/3
```

### Files

- Modified: `tests/explicit-skill-requests/run-test.sh`
- Modified: `tests/explicit-skill-requests/run-multiturn-test.sh`
- Modified: `tests/explicit-skill-requests/run-haiku-test.sh`
- Modified: `tests/explicit-skill-requests/run-extended-multiturn-test.sh`

### Interfaces

Consumes from Task 1: `TIMEOUT_BIN`, and the `PROJECT_DIR` workspace convention.

Later tasks rely on: the flag string `--setting-sources project` appearing on every `claude` invocation
under `tests/`, the pass pattern shape `'"skill":"superpowers:'"${SKILL_NAME}"'"'`, and
`run-test.sh`'s third positional argument `MAX_TURNS` defaulting to `8`.

### Steps

- [ ] In `tests/explicit-skill-requests/run-test.sh`, replace the comment block at lines 8-9 (restored by
  Task 1) with a statement of the new mechanism. Replace:

```bash
# HOME is NOT isolated: runs inherit ~/.claude, so a personal skill of the same name
# shadows the plugin's and the log records it unprefixed.
```

with:

```bash
# --setting-sources project excludes ~/.claude, so personal skills of the same name are
# not loaded and the plugin's own hooks and CLAUDE.md are the only ones in play. HOME is
# left alone: authentication depends on it and there is nothing to seed.
```

- [ ] In the same file, add the flag to the `claude` invocation. Replace:

```bash
${TIMEOUT_BIN:+$TIMEOUT_BIN 300} claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --dangerously-skip-permissions \
```

with:

```bash
${TIMEOUT_BIN:+$TIMEOUT_BIN 300} claude -p "$PROMPT" \
    --plugin-dir "$PLUGIN_DIR" \
    --setting-sources project \
    --dangerously-skip-permissions \
```

- [ ] In the same file, tighten the pass pattern. Replace:

```bash
# Check if skill was triggered (look for Skill tool invocation)
# Match either "skill":"skillname" or "skill":"namespace:skillname"
SKILL_PATTERN='"skill":"([^"]*:)?'"${SKILL_NAME}"'"'
```

with:

```bash
# Only a superpowers:-prefixed invocation counts. An unprefixed match would be a
# personal ~/.claude/skills copy of the same name answering instead of this plugin.
SKILL_PATTERN='"skill":"superpowers:'"${SKILL_NAME}"'"'
```

- [ ] Add a pollution guard after the log is written, immediately before the
  `if grep -q '"name":"Skill"'` block. Insert:

```bash
# If a bare skill name is registered, --setting-sources project did not take and the
# measurement is meaningless. Note the leading quote: "superpowers:brainstorming" has a
# colon before the name and does not match this pattern.
if grep -m1 '"subtype":"init"' "$LOG_FILE" | grep -q "\"${SKILL_NAME}\""; then
    echo "HARNESS ERROR: bare '${SKILL_NAME}' is registered — personal skills are in play." >&2
    echo "  --setting-sources project did not take effect. Aborting." >&2
    exit 2
fi
```

- [ ] Raise the default turn budget in `tests/explicit-skill-requests/run-test.sh`. Replace:

```bash
MAX_TURNS="${3:-3}"
```

with:

```bash
# 3 is too low. use-systematic-debugging names no actual bug, so the model spends the
# budget exploring before it can invoke anything: measured, it ends on error_max_turns at
# num_turns 4 with nothing fired. At 8 the skill fired in 3 of 3 runs.
MAX_TURNS="${3:-8}"
```

- [ ] Make a turn-budget cutoff legible rather than reading as a behavioral failure. In the same file,
  immediately after the `echo "=== Results ==="` line, insert:

```bash
if grep -q '"subtype":"error_max_turns"' "$LOG_FILE"; then
    echo "NOTE: run ended on error_max_turns at --max-turns $MAX_TURNS."
    echo "      A FAIL below may be a turn-budget artifact, not behavior."
fi
```

- [ ] Add `--setting-sources project` to the `claude` invocation in each of
  `run-multiturn-test.sh`, `run-haiku-test.sh`, and `run-extended-multiturn-test.sh`, on the line
  immediately after `--plugin-dir "$PLUGIN_DIR" \`.

- [ ] Verify the flag reaches every `claude` invocation in the suite:

```bash
grep -c "setting-sources project" tests/explicit-skill-requests/*.sh
```

Expected: `run-test.sh:2` (comment plus flag), `run-multiturn-test.sh:1`, `run-haiku-test.sh:1`,
`run-extended-multiturn-test.sh:1`, `run-all.sh:0` (it shells out to `run-test.sh`).

- [ ] Verify the flag has the measured effect. This run needs network and must be outside the sandbox:

```bash
REPO=$(pwd)
WS=$(mktemp -d)/ws && mkdir -p "$WS" && cd "$WS"
claude -p "hi" --max-turns 1 --plugin-dir "$REPO" --setting-sources project \
  --output-format stream-json --verbose 2>/dev/null \
  | grep -m1 '"subtype":"init"' \
  | jq -r '.slash_commands[]' | grep -E "^(superpowers:)?brainstorming$"
cd "$REPO"
```

Expected exactly one line: `superpowers:brainstorming`. If a bare `brainstorming` also appears, the flag
did not take and Task 2 is not done.

- [ ] Verify the default turn budget changed:

```bash
grep -n 'MAX_TURNS="${3:-' tests/explicit-skill-requests/run-test.sh
```

Expected: `MAX_TURNS="${3:-8}"`.

- [ ] Run the gate. It must be green:

```bash
bash tests/explicit-skill-requests/run-all.sh
echo "exit=$?"
```

Expected: `Passed: 4`, `Failed: 0`, `exit=0`, and every `Skills triggered in this run:` line showing a
`superpowers:`-prefixed name. A `NOTE: run ended on error_max_turns` line alongside a PASS is fine — the
skill fired before the budget ran out.

If a test FAILs, do not weaken the assertion or drop the prefix requirement. Read the log path the runner
prints and check three things in order: is the skill registered in the `init` line, did the run end on
`error_max_turns`, and did any tool run before the `Skill` call. The first two are harness problems; only
the third is behavioral.

- [ ] Lint and commit:

```bash
bash scripts/lint-shell.sh
git add tests/explicit-skill-requests/
git commit -m "test: measure this plugin, not the user's personal skills

The explicit-request suite accepted an unprefixed skill invocation, so a
personal ~/.claude/skills copy of the same name satisfied its assertion.
Issue #1 recorded 3 of 4 passing tests invoking the personal copy.

--setting-sources project stops ~/.claude loading at all: measured, the
registered slash commands drop from 88 to 54, bare brainstorming disappears
leaving only superpowers:brainstorming, the user's own SessionStart hook stops
firing, and a phrase probe for the global CLAUDE.md flips from Yes to No.
Requiring the superpowers: prefix then proves the plugin answered, and an init
line carrying a bare skill name aborts the run.

HOME is left alone. Isolating it breaks authentication with nothing to seed:
an empty HOME, one seeded with oauthAccount/userID/hasCompletedOnboarding, and
one with the whole .claude.json copied in all return Not logged in.

Removing the crutch exposed one real harness defect. use-systematic-debugging
failed at the default MAX_TURNS=3, ending on error_max_turns at num_turns 4
with nothing fired: its prompt names no actual bug, so the model spent the
budget exploring first. At 8 turns the skill fired in 3 of 3 runs. Default
raised to 8, and a turn-budget cutoff now prints a NOTE so it stops reading as
a behavioral failure.

run-all.sh is 4 pass, 0 fail, every hit superpowers:-prefixed."

---

## Task 3: Turn the acceptance test into a measurement script

Autotriggering is a probabilistic model behavior; a single sample cannot gate a repository. Replace the
pass/fail test with a script that runs N times and reports a rate. Deleting the firing assertion orphans
`run-skill-tests.sh`, whose `tests=()` array holds only that one entry, so it goes too.

### Files

- Created: `tests/claude-code/measure-autotrigger.sh`
- Deleted: `tests/claude-code/test-brainstorming-autotrigger.sh`
- Deleted: `tests/claude-code/run-skill-tests.sh`
- Modified: `tests/claude-code/README.md`
- Modified: `docs/testing.md`

### Interfaces

Consumes from Task 1: the `TIMEOUT_BIN` resolution idiom and the `ws-`/`superpowers-tests` path split.
Consumes from Task 2: the flag string `--setting-sources project`.

Later tasks rely on `measure-autotrigger.sh` with exactly this contract:

```
measure-autotrigger.sh [-n RUNS] [-t MAX_TURNS] [-p PLUGIN_DIR]
  -n RUNS        number of runs, default 1
  -t MAX_TURNS   --max-turns value, default 8
  -p PLUGIN_DIR  tree to load, default the repo root two levels up

stdout, one block:
  === <basename of PLUGIN_DIR> ===
  runs:       <N>
  fired:      <k>/<N>
  premature:  <k>/<N>
  truncated:  <k>/<N>
  hook ok:    <k>/<N>        (only when the tree ships hooks/hooks.json)

exit 0  all N runs completed
exit 1  harness failure: empty log, bare skill name registered, or a hook that did not succeed
exit 2  bad arguments
```

### Steps

- [ ] Create `tests/claude-code/measure-autotrigger.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Measures how often brainstorming autotriggers on a given tree, over N runs.
#
# This reports a rate. It asserts nothing about whether the skill fired: autotriggering is
# a probabilistic model behavior and one sample cannot gate a repository. Only broken
# plumbing is an error.
#
# Usage: ./measure-autotrigger.sh [-n RUNS] [-t MAX_TURNS] [-p PLUGIN_DIR]
#
# MUST run outside a command sandbox. Inside one, a plugin SessionStart hook fails with
# EPERM under ~/.claude and the injection never reaches the model, so the run measures a
# broken hook while reporting the hook as present.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNS=1
MAX_TURNS=8
PLUGIN_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

while [ $# -gt 0 ]; do
    case "$1" in
        -n) RUNS="$2"; shift 2 ;;
        -t) MAX_TURNS="$2"; shift 2 ;;
        -p) PLUGIN_DIR="$(cd "$2" && pwd)"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [-n RUNS] [-t MAX_TURNS] [-p PLUGIN_DIR]"
            exit 0
            ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

PROMPT="Let's make a react todo list"
TIMESTAMP=$(date +%s)
OUTPUT_DIR="${TMPDIR:-/tmp}/superpowers-tests/${TIMESTAMP}-$$/autotrigger"
mkdir -p "$OUTPUT_DIR"

TIMEOUT_BIN=$(command -v gtimeout || command -v timeout || true)

# A tree that ships hooks/hooks.json must produce a successful hook, or the run measures a
# broken hook rather than a present one.
HOOK_EXPECTED=false
[ -f "$PLUGIN_DIR/hooks/hooks.json" ] && HOOK_EXPECTED=true

fired=0
premature=0
truncated=0
hook_ok=0
polluted=0

for i in $(seq 1 "$RUNS"); do
    # The agent sees its cwd. Any "superpowers", skill name or "test" in that path cues the
    # skill call this script is trying to measure, so the workspace sits outside OUTPUT_DIR.
    WS="${TMPDIR:-/tmp}/ws-${TIMESTAMP}-$$-${i}"
    mkdir -p "$WS"
    LOG="$OUTPUT_DIR/run-${i}.json"

    ( cd "$WS" && ${TIMEOUT_BIN:+$TIMEOUT_BIN 300} claude -p "$PROMPT" \
        --plugin-dir "$PLUGIN_DIR" \
        --setting-sources project \
        --dangerously-skip-permissions \
        --max-turns "$MAX_TURNS" \
        --output-format stream-json \
        --verbose ) > "$LOG" 2>&1 || true

    if [ ! -s "$LOG" ]; then
        echo "HARNESS ERROR: run $i produced no output at $LOG" >&2
        exit 1
    fi

    # "superpowers:brainstorming" has a colon before the name and does not match this.
    if grep -m1 '"subtype":"init"' "$LOG" | grep -q '"brainstorming"'; then
        polluted=$((polluted + 1))
    fi

    if grep -qE '"skill":"superpowers:brainstorming"' "$LOG"; then
        fired=$((fired + 1))
    fi

    first_skill_line=$(grep -n '"name":"Skill"' "$LOG" | head -1 | cut -d: -f1)
    if [ -n "$first_skill_line" ]; then
        if head -n "$first_skill_line" "$LOG" | grep '"type":"tool_use"' \
            | grep -qE '"name":"(Write|Edit|NotebookEdit)"'; then
            premature=$((premature + 1))
        fi
    elif grep '"type":"tool_use"' "$LOG" | grep -qE '"name":"(Write|Edit|NotebookEdit)"'; then
        premature=$((premature + 1))
    fi

    if grep -q '"subtype":"error_max_turns"' "$LOG"; then
        truncated=$((truncated + 1))
    fi

    if [ "$HOOK_EXPECTED" = true ]; then
        if grep -m1 '"subtype":"hook_response"' "$LOG" | grep -q '"outcome":"success"'; then
            hook_ok=$((hook_ok + 1))
        fi
    fi
done

echo "=== $(basename "$PLUGIN_DIR") ==="
echo "runs:       $RUNS"
echo "fired:      $fired/$RUNS"
echo "premature:  $premature/$RUNS"
echo "truncated:  $truncated/$RUNS"
if [ "$HOOK_EXPECTED" = true ]; then
    echo "hook ok:    $hook_ok/$RUNS"
fi
echo "logs:       $OUTPUT_DIR"

if [ "$polluted" -gt 0 ]; then
    echo "HARNESS ERROR: bare 'brainstorming' registered in $polluted of $RUNS runs." >&2
    echo "  --setting-sources project did not take effect; personal skills are in play." >&2
    exit 1
fi

if [ "$HOOK_EXPECTED" = true ] && [ "$hook_ok" -ne "$RUNS" ]; then
    echo "HARNESS ERROR: the plugin hook succeeded in only $hook_ok of $RUNS runs." >&2
    echo "  A present-but-broken hook measures as 'hook present'. Are you inside a sandbox?" >&2
    exit 1
fi

exit 0
```

- [ ] Make it executable and delete the two files it replaces:

```bash
chmod +x tests/claude-code/measure-autotrigger.sh
git rm tests/claude-code/test-brainstorming-autotrigger.sh tests/claude-code/run-skill-tests.sh
```

- [ ] Smoke test it at 3 runs on the current tree. Outside the sandbox, needs network:

```bash
bash tests/claude-code/measure-autotrigger.sh -n 3
echo "exit=$?"
```

Expected: a block reporting `runs: 3` with `fired:`, `premature:` and `truncated:` lines, no `hook ok:`
line because `master` ships no `hooks/hooks.json`, and `exit=0`. The `fired:` value is data — `0/3` is a
valid and expected result, not a failure.

- [ ] Verify the hook assertion fires on a tree that does ship a hook, and that it passes outside the
  sandbox:

```bash
WT=$(mktemp -d)/cfg1 && git worktree add "$WT" 615dc8a >/dev/null 2>&1
bash tests/claude-code/measure-autotrigger.sh -n 1 -p "$WT"
echo "exit=$?"
git worktree remove "$WT" --force
```

Expected: the block includes `hook ok:    1/1` and `exit=0`. If it reports `hook ok: 0/1` and exits 1,
you are inside a command sandbox — rerun outside it.

- [ ] Replace lines 31-50 of `tests/claude-code/README.md`. Replace:

```markdown
### test-brainstorming-autotrigger.sh

The acceptance test for this skill set. Sends exactly `Let's make a react todo list` and asserts:

1. `brainstorming` was invoked through the Skill tool.
2. No `Write`, `Edit`, or `NotebookEdit` call happened before that invocation.

The second assertion is the one that matters. This skill set has no session-start hook and no
binding language in any description, so nothing forces a skill call before the model starts working.
If this test regresses, that design decision is what regressed. Before/after results are recorded in
`docs/superpowers/baseline/`.

It takes an optional plugin-dir argument, which is how the after-measurement compares a modified tree
against the current one:

```bash
./test-brainstorming-autotrigger.sh /path/to/some/other/checkout
```

One run is one sample. A single pass is weak evidence — run it three times when the result informs a
decision.
```

with:

```markdown
### measure-autotrigger.sh

Sends exactly `Let's make a react todo list` N times against one tree and reports how often
`superpowers:brainstorming` fired, how often a file was written before any skill call, and how often the
run was cut off by the turn budget.

It is not a pass/fail test. Autotriggering is a probabilistic model behavior, so it reports a rate and
exits 0 whenever the runs completed. It exits non-zero only on broken plumbing: an empty log, a bare
skill name in the registered commands (meaning `--setting-sources project` did not take and a personal
`~/.claude/skills` copy is in play), or a plugin hook that did not succeed.

```bash
./measure-autotrigger.sh -n 15                        # current tree, 15 runs
./measure-autotrigger.sh -n 15 -p /path/to/other      # compare another checkout
./measure-autotrigger.sh -n 3 -t 3                    # lower turn budget
```

**Run it outside any command sandbox.** Inside one, a plugin SessionStart hook fails with EPERM under
`~/.claude` and the injection never reaches the model, so the run measures a broken hook while reporting
the hook as present.

`brainstorming` carries `"You MUST use this before any creative work..."` in its description, so binding
language is present; there is no session-start hook. Recorded measurements live in
`docs/superpowers/baseline/`.
```

- [ ] Remove the `run-skill-tests.sh` invocations from `tests/claude-code/README.md` lines 22-27.
  Replace:

```markdown
```bash
./run-skill-tests.sh                 # all tests
./run-skill-tests.sh --verbose       # show full Claude output
./run-skill-tests.sh --timeout 1800  # raise the per-test budget
./run-skill-tests.sh --test test-brainstorming-autotrigger.sh
```
```

with:

```markdown
```bash
./measure-autotrigger.sh -n 15
```

There is no aggregate runner. `run-skill-tests.sh` was deleted when the one test it wrapped became a
measurement script.
```

- [ ] Replace lines 33-44 of `docs/testing.md`. Replace:

```markdown
### The acceptance test

```bash
bash tests/claude-code/test-brainstorming-autotrigger.sh
```

Sends exactly `Let's make a react todo list` and asserts `brainstorming` fires with no file written
first. This is the load-bearing measurement for this skill set: there is no session-start hook and no
binding language in any description, so nothing forces a first skill call. If this regresses, that is
the decision that regressed.

See `tests/claude-code/README.md` for the optional plugin-dir argument, used to compare two trees.
```

with:

```markdown
### Measuring autotrigger rate

```bash
bash tests/claude-code/measure-autotrigger.sh -n 15
```

Sends exactly `Let's make a react todo list` N times and reports how often
`superpowers:brainstorming` fired, how often a file was written before any skill call, and how often the
turn budget cut the run off.

This is a measurement, not a gate. It exits 0 whenever the runs completed — a `0/15` firing rate is data,
not a failure. It exits non-zero only on broken plumbing. There is no session-start hook in this skill
set, and `brainstorming`'s description does carry binding language
(`"You MUST use this before any creative work..."`), so what actually drives a first skill call is an
open question rather than a settled one.

Run it outside any command sandbox: inside one, a plugin SessionStart hook fails with EPERM under
`~/.claude`, so the run measures a broken hook.

See `tests/claude-code/README.md` for the `-p` flag, used to compare two trees.
```

- [ ] Verify both false claims are gone and no live file references the deleted scripts:

```bash
grep -rn "no binding language in any description" docs/ tests/ ; echo "---"
grep -rln "test-brainstorming-autotrigger\|run-skill-tests" docs/ tests/
```

Expected: the first grep prints nothing. The second prints only
`docs/superpowers/plans/2026-08-04-slim-superpowers.md` and
`docs/superpowers/baseline/2026-08-04-before.md` — executed historical records, deliberately untouched.

- [ ] Lint, run the structural gate, and commit:

```bash
bash scripts/lint-shell.sh
bash tests/skills/check-skills.sh
git add -A tests/claude-code/ docs/testing.md
git commit -m "test: report the autotrigger rate instead of asserting it

test-brainstorming-autotrigger.sh asserted that brainstorming fires. That is a
probabilistic model behavior and one sample cannot gate a repository, so the
assertion made the suite either red forever or quietly wrong.

measure-autotrigger.sh runs a tree N times and reports fired, premature-write
and truncated counts. It exits 0 whenever the runs completed; 0/15 is data. It
exits non-zero only on broken plumbing: an empty log, a bare skill name in the
registered commands, or a plugin hook that did not succeed. That last check
matters because inside a command sandbox the hook fails with EPERM and the
injection never reaches the model, which would measure a broken hook as a
present one.

run-skill-tests.sh wrapped exactly one test, the one demoted here, so it is
deleted rather than left wrapping nothing.

Also corrects the claim that no description carries binding language, which
appeared in both docs/testing.md and tests/claude-code/README.md.
brainstorming's description opens with You MUST use this before any creative
work."
```

Expected: both commands exit 0.

---

## Task 4: Build the configuration sweep driver

Four worktrees, one `measure-autotrigger.sh` call each. This script is scaffolding for one sweep, not a
durable tool.

### Files

- Created: `tests/claude-code/measure-configs.sh`

### Interfaces

Consumes from Task 3: `measure-autotrigger.sh` with the contract given in Task 3's Interfaces block —
`-n RUNS`, `-p PLUGIN_DIR`, a stdout block, exit 0 on completion.

Later tasks rely on: a per-configuration summary file at `$WT_ROOT/<config>.txt` and the four
configuration names `cfg1-hook-original`, `cfg2-nohook-original`, `cfg3-slim-binding`,
`cfg4-slim-neutral`.

### Configuration facts, verified

| name | commit | skills | brainstorming description | ships hooks |
|---|---|---|---|---|
| `cfg1-hook-original` | `615dc8a` | 14 | binding | yes |
| `cfg2-nohook-original` | `f49f0d7` | 14 | binding | no |
| `cfg3-slim-binding` | `HEAD` | 9 | binding | no |
| `cfg4-slim-neutral` | `HEAD` + swap | 9 | neutral | no |

### Steps

- [ ] Create `tests/claude-code/measure-configs.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# One-time sweep over the four configurations in
# docs/superpowers/specs/2026-08-07-autotrigger-measurement-design.md.
#
# Scaffolding, not a durable tool. measure-autotrigger.sh is the piece worth keeping.
#
# Usage: ./measure-configs.sh [-n RUNS]      (default 15)
#
# MUST run outside a command sandbox: cfg1 ships a SessionStart hook that fails with
# EPERM inside one.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

RUNS=15
if [ "${1:-}" = "-n" ]; then
    RUNS="$2"
fi

BINDING_MARKER="You MUST use this before any creative work"
NEUTRAL='description: Use when turning an idea, feature request, or vague goal into a design, before writing code'

WT_ROOT="${TMPDIR:-/tmp}/autotrigger-configs-$$"
mkdir -p "$WT_ROOT"

echo "worktrees: $WT_ROOT"
echo "runs per configuration: $RUNS"
echo ""

git -C "$REPO" worktree add "$WT_ROOT/cfg1-hook-original"   615dc8a >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg2-nohook-original" f49f0d7 >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg3-slim-binding"    HEAD    >/dev/null
git -C "$REPO" worktree add "$WT_ROOT/cfg4-slim-neutral"    HEAD    >/dev/null

# cfg4 is cfg3 with only the description swapped. Nothing else may differ.
SKILL="$WT_ROOT/cfg4-slim-neutral/skills/brainstorming/SKILL.md"
awk -v repl="$NEUTRAL" '!swapped && /^description:/ { print repl; swapped=1; next } { print }' \
    "$SKILL" > "$SKILL.tmp" && mv "$SKILL.tmp" "$SKILL"

if grep -q "$BINDING_MARKER" "$SKILL"; then
    echo "ERROR: cfg4 still carries the binding description" >&2
    exit 1
fi
if ! grep -qF "$NEUTRAL" "$SKILL"; then
    echo "ERROR: cfg4 does not carry the neutral description" >&2
    exit 1
fi

# Guard the premise of the whole matrix: only cfg4's description may differ.
for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding; do
    if ! grep -q "$BINDING_MARKER" "$WT_ROOT/$cfg/skills/brainstorming/SKILL.md"; then
        echo "ERROR: $cfg does not carry the binding description" >&2
        exit 1
    fi
done

for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding cfg4-slim-neutral; do
    echo "########## $cfg ##########"
    bash "$SCRIPT_DIR/measure-autotrigger.sh" -n "$RUNS" -p "$WT_ROOT/$cfg" \
        | tee "$WT_ROOT/$cfg.txt"
    status=${PIPESTATUS[0]}
    if [ "$status" -ne 0 ]; then
        echo "ABORTING: $cfg reported a harness failure (exit $status)." >&2
        echo "  Summaries so far are in $WT_ROOT/*.txt" >&2
        exit "$status"
    fi
    echo ""
done

echo "########## summaries ##########"
cat "$WT_ROOT"/*.txt

echo ""
echo "Remove the worktrees when the numbers are recorded:"
for cfg in cfg1-hook-original cfg2-nohook-original cfg3-slim-binding cfg4-slim-neutral; do
    echo "  git -C $REPO worktree remove $WT_ROOT/$cfg --force"
done
```

- [ ] Make it executable:

```bash
chmod +x tests/claude-code/measure-configs.sh
```

- [ ] Dry-run the worktree construction and the description guards at 1 run per configuration. Outside
  the sandbox, needs network. This is 4 runs, not 60:

```bash
bash tests/claude-code/measure-configs.sh -n 1
echo "exit=$?"
```

Expected: four `##########` blocks, `hook ok:    1/1` in the `cfg1-hook-original` block only, no
`ERROR:` lines, and `exit=0`. If `cfg1` reports `hook ok: 0/1`, you are inside a sandbox.

- [ ] Remove the dry-run worktrees using the commands the script printed.

- [ ] Lint and commit:

```bash
bash scripts/lint-shell.sh
git add tests/claude-code/measure-configs.sh
git commit -m "test: add the four-configuration autotrigger sweep

Builds a worktree per configuration and calls measure-autotrigger.sh once each:
615dc8a (14 skills, hook present), f49f0d7 (14 skills, no hook), HEAD (9
skills), and HEAD with only brainstorming's description swapped to the neutral
text.

All four carry the binding description except the last, so 1 vs 2 isolates the
hook, 3 vs 4 isolates the description, and 2 vs 3 isolates the rewrite. The
script asserts that premise before measuring and aborts if any tree carries the
wrong description, because the old table's decisive comparison moved three
variables at once and drew a causal conclusion from it.

Scaffolding for one sweep. measure-autotrigger.sh is the durable piece."
```

Expected: `lint-shell.sh` exits 0.

---

## Task 5: Run the sweep and rewrite the baseline document

60 runs, serial, roughly 60 to 90 minutes. Then replace the refuted numbers in place.

### Files

- Modified: `docs/superpowers/baseline/2026-08-04-after.md`

### Interfaces

Consumes from Task 4: `measure-configs.sh`, and the four summary files at `$WT_ROOT/<config>.txt`.

Produces nothing later tasks consume. This is the last task.

### Steps

- [ ] Run the full sweep outside the sandbox. Capture everything:

```bash
bash tests/claude-code/measure-configs.sh -n 15 2>&1 | tee /tmp/sweep-2026-08-07.txt
echo "exit=$?"
```

Expected: four blocks, `hook ok:    15/15` in the `cfg1-hook-original` block, and `exit=0`. If any
configuration reports a harness failure the script aborts and prints where the partial summaries are —
fix the cause and rerun that configuration rather than recording a partial table.

- [ ] If any configuration reports more than 3 of 15 truncated, rerun that configuration at a higher turn
  budget and use the rerun. A truncated run measures the turn budget, not the model:

```bash
bash tests/claude-code/measure-autotrigger.sh -n 15 -t 12 -p "<WT_ROOT>/<config>"
```

- [ ] Replace the entire content of `docs/superpowers/baseline/2026-08-04-after.md` with the following,
  substituting every `<...>` placeholder with an observed number. Leave no angle brackets in the file:

```markdown
# After — post-rewrite measurements and comparison

**Tree measured:** four configurations, see the table
**Claude Code:** 2.1.223
**Originally written:** 2026-08-04
**Re-measured:** 2026-08-07 on a corrected harness

## Verdict

The 2026-08-04 numbers in this file measured the harness, not the skill set. They are replaced below.

Three defects invalidated them. The agent's working directory contained `superpowers-tests`, which cued
the very skill call the test was sampling — varying only the directory name gave 6/6 fired with the
string present against 0/15 with a neutral name. The runs inherited `~/.claude`, so personal skills
sharing the plugin's names answered instead of the plugin, and the pass condition accepted an unprefixed
match. And every run happened inside a command sandbox where the plugin's SessionStart hook fails with
EPERM, so the hook-present configuration measured a broken hook.

This file's earlier reasoning that the EPERM was "a uniform degradation, not the discriminator" was the
specific error: uniform across rows it may have been, but it destroyed the one variable the
hook-present row existed to test.

## The four configurations

Each row is the same prompt, `Let's make a react todo list`, 15 runs, `--max-turns 8`, on a harness with
a neutral working directory, `--setting-sources project`, and a required `superpowers:` prefix, run
outside the sandbox.

| # | configuration | commit | skills | description | fired | premature write | truncated |
|---|---|---|---|---|---|---|---|
| 1 | hook present, original bodies | `615dc8a` | 14 | binding | <N>/15 | <N>/15 | <N>/15 |
| 2 | hook removed, original bodies | `f49f0d7` | 14 | binding | <N>/15 | <N>/15 | <N>/15 |
| 3 | slim tree as shipped | `HEAD` | 9 | binding | <N>/15 | <N>/15 | <N>/15 |
| 4 | slim tree, neutral description | `HEAD`+swap | 9 | neutral | <N>/15 | <N>/15 | <N>/15 |

Configuration 1 reported `hook ok: <N>/15`.

## What each comparison licenses

Configurations 1, 2 and 3 all carry the same binding description; only 4 differs. That is what makes
these readable.

- **1 vs 2 — the hook.** <one or two sentences stating the observed difference and what it licenses.>
- **3 vs 4 — the description.** <one or two sentences. This is the comparison that governs whether
  `c4ffad9`'s restoration of the binding description was justified.>
- **2 vs 3 — the rewrite.** 14 skills to 9 with every body rewritten, description held constant. Two
  variables move, so this is reported as a number with no causal claim attached.

<A short paragraph stating the verdict these numbers support: whether the slim set autotriggers at all,
whether the binding description earns its place, and whether hook removal is vindicated. If a comparison
is flat, say it is flat.>

## Sample size

15 runs per configuration separates roughly 0% from roughly 50%. It does not resolve a 6/15 against a
9/15. Any conclusion drawn here that depends on a difference smaller than that is not supported by these
numbers.

## What replaced the old harness

- `tests/claude-code/measure-autotrigger.sh` — reports a rate over N runs; exits non-zero only on broken
  plumbing. Replaced `test-brainstorming-autotrigger.sh`, which asserted firing.
- `tests/claude-code/measure-configs.sh` — the sweep driver for this table.
- `run-skill-tests.sh` — deleted; it wrapped only the demoted test.

`docs/superpowers/plans/2026-08-04-slim-superpowers.md` and `2026-08-04-before.md` still name
`test-brainstorming-autotrigger.sh`. They are executed historical records and were left alone
deliberately.

## Explicit skill requests

`tests/explicit-skill-requests/run-all.sh` reported 4/4 passing on the old harness, but 3 of those 4
invoked a personal `~/.claude/skills` copy rather than this plugin. With `--setting-sources project` and
a required `superpowers:` prefix it reports 4/4 with every hit attributable to this plugin.

Removing the crutch exposed one real harness defect. `use-systematic-debugging` failed at the old default
`MAX_TURNS=3`, ending on `error_max_turns` at `num_turns 4` with nothing fired: its prompt names no
actual bug, so the model spent the budget exploring. At 8 turns the skill fired in 3 of 3 runs. The
default is now 8 and a cutoff prints a NOTE, so it no longer reads as behavioral.
```

- [ ] Verify no placeholder survived:

```bash
grep -n "<N>\|<one or two\|<A short" docs/superpowers/baseline/2026-08-04-after.md
```

Expected: no output.

- [ ] Verify the refuted claims are gone from the file:

```bash
grep -c "vindicated\|3/3" docs/superpowers/baseline/2026-08-04-after.md
```

Expected: `0`, unless the new numbers independently support such a claim and you wrote it deliberately.

- [ ] Remove the sweep worktrees using the commands `measure-configs.sh` printed.

- [ ] Run the full gate:

```bash
bash tests/skills/check-skills.sh
bash tests/shell-lint/test-lint-shell.sh
bash tests/systematic-debugging/test-find-polluter.sh
```

Expected: all three exit 0.

- [ ] Commit:

```bash
git add docs/superpowers/baseline/2026-08-04-after.md
git commit -m "docs(baseline): re-measure autotriggering on a corrected harness

The 2026-08-04 numbers measured the harness. The agent's cwd contained
superpowers-tests, which cued the skill call the test was sampling; runs
inherited ~/.claude so personal skills answered instead of the plugin; and every
run happened inside a sandbox where the plugin hook fails with EPERM.

This file's own reasoning that the EPERM was a uniform degradation rather than
the discriminator was the specific error. Uniform across rows it may have been,
but it destroyed the one variable the hook-present row existed to test.

Four configurations at 15 runs each, neutral cwd, --setting-sources project,
superpowers: prefix required, outside the sandbox. Configurations 1, 2 and 3 all
carry the binding description and only 4 differs, so the description comparison
is 3 vs 4 rather than the old table's 2 vs 3, which moved three variables at
once."
```

---

## Requirement coverage

Every spec success criterion maps to a task.

| spec criterion | task |
|---|---|
| 1. neutral working directory | 1, and Task 3's `WS=` line |
| 2. no personal skills, CLAUDE.md, or user hooks | 2, 3 |
| 3. `superpowers:` prefix required | 2, 3 |
| 4. outside the sandbox, failed hook discarded | 3, 4, 5 |
| 5. four configurations at N=15, comparisons labelled | 4, 5 |
| 6. no "no binding language" claim in live docs | 3 |

Spec decisions 1 through 7 map to tasks 2, 1, 3, 4/5, 5, 3, and 3/4/5 respectively.

## Out of scope

- Whether `brainstorming` needs a wording change, and whether the binding description stays. That is
  decided from Task 5's numbers, in its own spec. Issue #1 goal 3.
- Restoring `4a69588` (todo mechanization). It measured flat.
- `tests/claude-code/test-helpers.sh` beyond the one-line `timeout` fix in Task 1. It has no callers and
  predates this work.
