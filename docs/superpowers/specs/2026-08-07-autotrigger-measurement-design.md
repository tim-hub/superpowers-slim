# Autotrigger Measurement — Design

**Date:** 2026-08-07
**Status:** Approved, pending plan
**Branch:** `master`
**Issue:** [#1](https://github.com/tim-hub/superpowers-slim/issues/1)

## Goal

Make the behavioral harness measure whether this plugin's skills autotrigger, then re-measure the four
configurations that the shipped design decisions rest on, and correct the documents carrying refuted
numbers.

Success is **trustworthy numbers**, not `brainstorming` firing. If all four configurations read 0/15,
this work succeeded.

Success criteria:

1. No agent under measurement sees `superpowers`, a skill name, or `test` in its working directory.
2. No agent under measurement inherits `~/.claude/skills`, `~/.claude/CLAUDE.md`, or the user's own
   SessionStart hooks.
3. A skill invocation counts only when prefixed `superpowers:`, proving the plugin answered.
4. Every run executes outside the command sandbox, and a run whose plugin hook failed is discarded
   rather than counted.
5. Four configurations measured at N=15 each, with clean comparisons identified as clean and confounded
   comparisons identified as confounded.
6. Zero occurrences of the false claim "no binding language in any description" remain in live docs.

## Context

Issue #1 reports that `brainstorming` appears to batch clarifying questions, and traces the real cause
to the skill never firing. Verification of its claims against this tree:

| claim | verdict |
|---|---|
| cwd leaks the answer into the agent's context | confirmed — `run-test.sh:28,64`, `test-brainstorming-autotrigger.sh:20,31` |
| `HOME` is not isolated despite the comment saying so | confirmed — `run-test.sh:8` asserts it, no `HOME=` anywhere in `tests/`. Fixed by `--setting-sources project`, not by isolating `HOME`; see Spike results |
| `docs/testing.md` claims no description carries binding language | confirmed false — `skills/brainstorming/SKILL.md:3` carries `"You MUST use this..."` |
| `timeout(1)` is absent on macOS, causing false negatives | refuted on this machine — `/opt/homebrew/bin/timeout` and `gtimeout` both resolve |
| personal skills differ in size from the plugin's (1494 vs 293 words) | stale — both now measure 293/293 and 371/371, synced since |

The cwd defect is the load-bearing one. `a757bc2` recorded a controlled comparison varying only the
directory name: 6/6 fired with `superpowers-tests` in the path, 0/15 with a neutral name. That number
was not independently reproduced during this design and remains the issue author's measurement.

Two findings shaped this design beyond the issue's own analysis.

**Most of goal 1 already exists.** `a757bc2` (reverted by `efefef4`) implements the neutral cwd, portable
`gtimeout`/`timeout`/unwrapped resolution, a `$$` suffix fixing same-second log collisions, and the
corrected HOME comment, across five harness scripts. It deliberately left `HOME` alone, on the grounds
that isolating it changes what the suite measures.

**The old table's decisive comparison is confounded, independently of the cwd leak.**
`docs/superpowers/baseline/2026-08-04-after.md` attributes a 3/3-versus-2/3 difference to
`brainstorming`'s description. Between those two rows the skill count went from 14 to 9, every body was
rewritten, and the description changed. Three variables moved. `c4ffad9`'s justification for restoring
the binding description is therefore unsupported on two counts, not one.

### Spike results, measured 2026-08-07

Both risks flagged in the first draft of this design were investigated before planning. Claude Code
2.1.223.

**Isolating `HOME` breaks authentication.** Three variants failed with
`"Not logged in · Please run /login"`: an empty `HOME`; one seeded with `oauthAccount`, `userID` and
`hasCompletedOnboarding`; and one with the whole `~/.claude.json` copied in. A control run under the real
`HOME` returned `exit 0`. There is no `~/.claude/.credentials.json` to seed — the keychain holds
`Claude Code-credentials-66a5adee` and similar suffixed entries, so the lookup key appears derived from
the config location rather than being HOME-independent.

**`--setting-sources project` does the job instead, with authentication intact.** Measured against the
default sources:

| pollution source | default | `--setting-sources project` |
|---|---|---|
| personal skills | 88 slash commands, both `brainstorming` and `superpowers:brainstorming` registered | 54, prefixed only |
| personal SessionStart hooks | 1 fired | 0 |
| global `~/.claude/CLAUDE.md` | model answers "Yes" to a phrase probe | "No" |

`--bare` was rejected: it skips hooks and never reads the keychain, so it cannot measure configuration 1
and cannot authenticate. `--safe-mode` was rejected: it disables plugins, which `--plugin-dir` needs.

**The plugin's SessionStart hook fires under `--plugin-dir`, but only succeeds outside the sandbox.**

| environment | hook outcome | injection reached the model |
|---|---|---|
| inside the command sandbox | `exit_code 1`, `EPERM mkdir '/Users/hbai/.claude/plugins/data/superpowers-inline'` | no |
| outside the sandbox | `exit_code 0`, `outcome success` | yes, confirmed by phrase probe |

Configuration 1 is therefore measurable, and the sweep must run outside the sandbox.

### Two further confounds, not in issue #1

- **The user's own SessionStart hook fired in every prior measurement.** It injects context at exactly
  the moment the measurement samples whether a skill fires.
- **EPERM breaks the hook, so it is not a uniform degradation.** `2026-08-04-after.md` records the EPERM
  and reasons that because it appears in all 10 logs it is "a uniform degradation, not the
  discriminator". For the hook-present configuration that reasoning fails: EPERM under `~/.claude/`
  breaks the hook itself, which is the one variable that configuration exists to test. The document did
  note the numbers "would want re-measuring outside the sandbox before being treated as final".

## Decisions

1. **Exclude the user setting source and assert the `superpowers:` prefix.** `--setting-sources project`
   removes the 17-name skill collision, the user's SessionStart hooks and the global CLAUDE.md in one
   flag, with authentication untouched. The prefix assertion proves the plugin answered. Isolating `HOME`
   was the original plan and is rejected: it breaks authentication with no seedable fallback.
2. **Start from `git cherry-pick a757bc2`, then extend.** The revert was for sequencing, not because the
   code was wrong. Reuses working code and keeps its evidence trail in history.
3. **Demote the autotrigger test to a measurement script.** Autotriggering is a probabilistic model
   behavior. A single sample cannot gate a repository.
4. **Four configurations at N=15**, dropping the old table's duplicate turn-budget row.
5. **Rewrite `2026-08-04-after.md` in place.** The audit trail lives in git history; two contradictory
   verdicts in one file violate CLAUDE.md's "delete it or update it, never leave both".
6. **Delete `run-skill-tests.sh`.** Its `tests=()` array holds exactly one entry — the demoted script.
   Removing that entry orphans the runner, and CLAUDE.md requires removing orphans the change creates.
7. **Run every measurement outside the command sandbox, and verify the hook succeeded.** Inside the
   sandbox the plugin hook fails with EPERM, which would make configuration 1 measure a broken hook
   rather than a present one.

### Accepted risks

- **N=15 is still a small sample.** It separates 0% from roughly 50%. It cannot read a 6/15 versus 9/15
  split as signal, and the new document must say so rather than repeating the old one's overreach.
- **`--setting-sources project` makes the measurement less representative of real use.** It measures the
  plugin alone, not the plugin inside this user's configuration. That is the correct trade for
  attribution, and it is the same trade HOME isolation was chosen for.
- **Running outside the sandbox gives 60 nested agents unrestricted filesystem access.** Each runs with
  `--dangerously-skip-permissions` in a scratch working directory. The prompt is fixed and benign, but
  nothing constrains what a run does. Accepted because the hook cannot be measured any other way.

## Architecture

Two layers. The spike that gated the first draft is resolved; see Spike results.

```
  tests/claude-code/measure-autotrigger.sh     DURABLE
    --plugin-dir <path>  -n <runs>  --max-turns <n>
    one tree, N runs, prints a rate
    │
    ▼
  tests/claude-code/measure-configs.sh         DISPOSABLE
    builds 4 worktrees, loops the above
    │
    ▼
  a markdown table pasted into 2026-08-04-after.md
```

The inner script is what survives this work: it answers "does this tree autotrigger" for any future
tree. The driver is scaffolding for one sweep.

### What `measure-autotrigger.sh` reports

It asserts nothing about firing.

| observation | how counted |
|---|---|
| `superpowers:brainstorming` invoked | prefix-anchored grep, per run |
| `Write`/`Edit`/`NotebookEdit` before the first `Skill` call | per run |
| run ended `error_max_turns` | per run, printed as a caveat |
| `hook_response.outcome` when the tree ships a hook | per run; a failed hook discards the run |

Exit 0 whenever all N runs complete. Exit non-zero only on broken plumbing — no log produced, `claude`
missing, worktree unreadable. Behavior is data; only plumbing is an error.

### Per-run isolation

```
cwd=$TMPDIR/ws-<ts>-$$-<i>       neutral name, outside OUTPUT_DIR
--setting-sources project        drops personal skills, user hooks, global CLAUDE.md
--plugin-dir <tree>              the only source of skills
--dangerously-skip-permissions   no settings.json present to grant permissions
outside the command sandbox      otherwise the plugin hook fails with EPERM
```

`HOME` is left alone. Authentication depends on it and there is nothing to seed.

Logs stay under `$OUTPUT_DIR/superpowers-tests/...` with descriptive names. The agent never sees that
path. This is `a757bc2`'s split, kept.

### Changes on top of the cherry-pick

- rename `test-brainstorming-autotrigger.sh` to `measure-autotrigger.sh`, drop the firing assertion,
  add `-n`
- pass `--setting-sources project` in every harness script that invokes `claude`
- require the `superpowers:` prefix in `measure-autotrigger.sh` and in `run-test.sh`:

```
# before, run-test.sh:84
SKILL_PATTERN='"skill":"([^"]*:)?'"${SKILL_NAME}"'"'
# after
SKILL_PATTERN='"skill":"superpowers:'"${SKILL_NAME}"'"'
```

## Configuration matrix

| # | configuration | source | mutation |
|---|---|---|---|
| 1 | hook present, original bodies | worktree @ `615dc8a` | none |
| 2 | hook removed, original bodies | worktree @ `f49f0d7` | none |
| 3 | slim tree, binding description | worktree @ `master` | none |
| 4 | slim tree, neutral description | worktree @ `master` | one-line frontmatter swap |

Both historical commits carry `.claude-plugin/` and `skills/`, so `--plugin-dir` resolves against
either. `f49f0d7` contains zero hook files.

Configuration 4's swap, verbatim from `c4ffad9` reversed:

```
-description: "You MUST use this before any creative work - creating features, building components,
-  adding functionality, or modifying behavior. Explores user intent, requirements and design before
-  implementation."
+description: Use when turning an idea, feature request, or vague goal into a design, before writing code
```

15 runs per configuration, 60 total, serial, `--max-turns 8`. The old table's 3-turn rows are dropped:
it showed 3 turns can end a run before any skill call, which measures the turn budget rather than the
model.

### Which comparisons are clean

All four configurations carry the same `brainstorming` description except configuration 4. Verified:
`615dc8a`, `f49f0d7` and `master` all ship the binding text, at 14, 14 and 9 skills respectively.

```
1 vs 2   hook only; 14 skills and binding description both held   CLEAN
3 vs 4   description only; 9 skills and bodies both held          CLEAN
2 vs 3   rewrite only: 14 skills to 9, bodies rewritten;          CONFOUNDED
         description held constant                                (2 variables)
```

The new document reports 2 versus 3 as a number with no causal claim, and answers the description
question from 3 versus 4, where one variable moves.

This differs from the old table, whose corresponding pair also moved the description — three variables
at once. Holding the description constant across 1, 2 and 3 is what makes 3 versus 4 interpretable.

## Data flow, one run

```
"Let's make a react todo list"
   │
   ▼  claude -p --plugin-dir <cfg> --setting-sources project
   │     --output-format stream-json --verbose --max-turns 8
   │     cwd=<neutral>, outside the sandbox
   ▼
stream-json log ──> $OUTPUT_DIR/<cfg>/run-<i>.json
   │
   ├─ grep '"skill":"superpowers:brainstorming"'      → fired?
   ├─ grep Write|Edit|NotebookEdit before 1st Skill   → premature write?
   ├─ grep '"subtype":"error_max_turns"'              → truncated?
   └─ jq hook_response.outcome (cfg 1 only)           → hook healthy?
   │
   ▼
tally per configuration → "fired 0/15, premature 0/15, truncated 2/15, hook ok 15/15"
```

## Testing

### What stays a pass/fail gate

| suite | status |
|---|---|
| `tests/skills/check-skills.sh` | unchanged — structural gate |
| `tests/shell-lint/test-lint-shell.sh` | unchanged |
| `tests/systematic-debugging/test-find-polluter.sh` | unchanged |
| `tests/explicit-skill-requests/run-all.sh` (4 tests) | stays a gate, gains `--setting-sources project` and the prefix assertion |

### What becomes a measurement

`measure-autotrigger.sh` alone.

`run-all.sh` loses its crutch. Issue #1 found 3 of its 4 passing tests invoked the personal skill copy
rather than the plugin; excluding the user source and requiring the prefix removes that. Red there is a
genuine defect — the user named a skill and the plugin did not answer — so it is fixed, not demoted, and
the fix lands in this work rather than a follow-up.

Measured before planning: with the flag and the prefix requirement, 3 of the 4 pass and
`use-systematic-debugging` fails on the turn budget, not on behavior. It ends `error_max_turns` at
`num_turns 4` under `run-test.sh`'s default `MAX_TURNS=3` — its prompt names no actual bug, so the model
spends the budget exploring before it can invoke anything. At `--max-turns 8` the skill fired in 3 of 3
runs. The default becomes 8, and a cutoff prints a NOTE so it stops reading as a behavioral failure.

## Error handling

| what breaks | response |
|---|---|
| `hook_response.outcome` is not `success` in configuration 1 | discard the run and stop. A present-but-broken hook measured as "hook present" is the exact error `2026-08-04-after.md` made. Most likely cause is running inside the sandbox |
| a run reports `"Not logged in"` | the harness is touching `HOME`. Nothing should; see decision 1 |
| bare `brainstorming` appears in the `init` line's `slash_commands` | `--setting-sources project` was not passed. Abort the sweep — the personal skill is in play |
| run ends `error_max_turns` | counted, reported beside the rate. More than 3 of 15 in one configuration → re-run that configuration at a higher turn budget |
| worktree path already exists | fail loudly. Never reuse: a stale tree silently measures the wrong commit |
| `claude` missing, rate limited, log absent | harness error, exit non-zero, no table emitted |
| sweep dies mid-way | per-configuration tallies written as each configuration finishes, so run 43 of 60 does not lose the first two |

## Document and script changes

The false claim appears twice, not once as issue #1 states:

| location | text |
|---|---|
| `docs/testing.md:39-40` | "no session-start hook and no binding language in any description" |
| `tests/claude-code/README.md:38-39` | same sentence |

| file | change |
|---|---|
| `docs/superpowers/baseline/2026-08-04-after.md` | rewrite in place: new table, new verdict. Drop "decision 4 is vindicated" unless 1 vs 2 earns it; replace the description causal claim with 3 vs 4 |
| `docs/testing.md:33-44` | rename the script, drop "asserts", drop "load-bearing measurement", fix the binding-language claim. Becomes "Measuring autotrigger rate" under Behavioral, not an acceptance gate |
| `tests/claude-code/README.md:26,31-40` | the same four corrections |
| `tests/claude-code/run-skill-tests.sh` | delete — orphaned once its single test is demoted |

### Deliberately untouched

- `docs/superpowers/plans/2026-08-04-slim-superpowers.md` — 13 references to the old script name. An
  executed historical plan; rewriting it would falsify the record of what was done.
- `docs/superpowers/baseline/2026-08-04-before.md:112` — records the criterion applied at the time.

Both keep the old script name. The new verdict carries one line saying so, otherwise the stale names
read as an oversight.

## Verification

```
1. cherry-pick a757bc2
   → verify: 5 scripts changed, check-skills.sh exits 0

2. add --setting-sources project and the superpowers: prefix assertion
   → verify: the init line lists superpowers:brainstorming and NOT bare
             brainstorming; zero hook_started events from the user config;
             a phrase probe for the global CLAUDE.md answers "No"

3. rename to measure-autotrigger.sh, drop the firing assertion, add -n
   → verify: -n 3 on master exits 0 and prints a rate;
             scripts/lint-shell.sh clean on both new scripts

4. delete run-skill-tests.sh
   → verify: no live file references it

5. build 4 worktrees
   → verify: each has .claude-plugin/ and skills/;
             configuration 4's description is the neutral string

6. run the sweep, outside the sandbox
   → verify: 60 logs on disk, 4 tallies printed;
             configuration 1 reports hook outcome success in 15 of 15

7. rewrite the documents
   → verify: grep "no binding language in any description" → 0 hits
             grep the old script name → hits only in plans/ and before.md

8. full gate
   → verify: check-skills.sh and test-lint-shell.sh exit 0
```

## Out of scope

- **Whether `brainstorming` needs a wording change, and whether the binding description stays.** That
  decision is made from these numbers, in its own spec. Issue #1's goal 3.
- **Restoring `4a69588`** (todo mechanization). It measured flat — its step 1 never called a todo tool
  in 3 of 3 runs. Not to be repeated without new evidence.
