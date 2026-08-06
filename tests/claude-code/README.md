# Claude Code Skills Tests

Behavioral tests for the skills, driven through the Claude Code CLI.

## Overview

These tests invoke Claude Code in headless mode (`claude -p`) against this checkout loaded via
`--plugin-dir`, then inspect the JSON stream to see which skills fired and what the model did before
they fired. They test behavior, not file contents — the structural contract is checked separately by
`tests/skills/check-skills.sh`.

## Requirements

- Claude Code CLI in PATH (`claude --version` should work)
- `jq`

Note that `--output-format stream-json` requires `--verbose` when combined with `--print`. Without it
the CLI exits immediately and a test reports a FAIL that looks behavioral but is not.

## Running Tests

```bash
./measure-autotrigger.sh -n 15
```

There is no aggregate runner. `run-skill-tests.sh` was deleted when the one test it wrapped became a
measurement script.

## Current Tests

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

### measure-configs.sh

Scaffolding for one sweep: builds a worktree per configuration and calls `measure-autotrigger.sh` once
each. See `docs/superpowers/baseline/2026-08-04-after.md` for what it produced.

## Test Structure

### test-helpers.sh

Shared functions:

- `run_claude "prompt" [timeout]` — run Claude with a prompt
- `assert_contains output pattern name` — verify a pattern exists
- `assert_not_contains output pattern name` — verify a pattern is absent
- `assert_count output pattern count name` — verify an exact count
- `assert_order output pattern_a pattern_b name` — verify ordering
- `create_test_project` — create a temp test directory
- `create_test_plan project_dir` — create a sample plan file

### analyze-token-usage.py

Token telemetry over a captured JSON stream.

## Adding New Tests

1. Create `test-<name>.sh`, writing output under `${TMPDIR:-/tmp}` — a hardcoded `/tmp` is not
   writable in every environment.
2. Keep the agent's working directory out of that log path. It sees its cwd, so `superpowers`, a skill
   name, or `test` in the path cues the behavior you are trying to measure.
3. Pass `--setting-sources project` so `~/.claude` skills, hooks and CLAUDE.md stay out of the run, and
   require the `superpowers:` prefix when matching a skill invocation.
4. `chmod +x test-<name>.sh`.

There is no runner to register with. Invoke the script directly.

## Related

- `tests/skills/check-skills.sh` — structural gate (skill set, frontmatter, ceilings, references)
- `tests/explicit-skill-requests/` — does a skill still fire when the user names it under resistance
  framing
- `docs/testing.md` — how the two tiers relate
