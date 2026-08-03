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
./run-skill-tests.sh                 # all tests
./run-skill-tests.sh --verbose       # show full Claude output
./run-skill-tests.sh --timeout 1800  # raise the per-test budget
./run-skill-tests.sh --test test-brainstorming-autotrigger.sh
```

## Current Tests

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
2. Source `test-helpers.sh` if you need the assertions.
3. Add the filename to the `tests` array in `run-skill-tests.sh`.
4. `chmod +x test-<name>.sh`.

## Related

- `tests/skills/check-skills.sh` — structural gate (skill set, frontmatter, ceilings, references)
- `tests/explicit-skill-requests/` — does a skill still fire when the user names it under resistance
  framing
- `docs/testing.md` — how the two tiers relate
