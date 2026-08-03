# Testing

Two tiers, and the distinction matters: one checks the shape of the skills, the other checks what an
agent actually does when they load.

- **Structural** — is the skill set well-formed? Fast, deterministic, no API calls. Run on every edit.
- **Behavioral** — does an agent invoke the right skill at the right moment? Slow, one sample per run,
  needs a working `claude` CLI.

## Structural gate

```bash
bash tests/skills/check-skills.sh
```

Checks that the skill set is exactly the nine expected skills, each `SKILL.md` has frontmatter with
exactly `name` and `description` under 1024 characters, no `@`-link force-loads another skill, no file
under `skills/` references a deleted skill, and each `SKILL.md` is within its word ceiling. Exits 0 or
prints one `FAIL:` line per violation.

Word ceilings live in the `budget()` function in that script. When a skill genuinely needs more room,
raise its ceiling there — do not drop a workflow step to fit.

Also: `bash tests/shell-lint/test-lint-shell.sh` covers `scripts/lint-shell.sh`, and
`bash tests/systematic-debugging/test-find-polluter.sh` covers that skill's bisection helper.

## Behavioral tests

Both suites load this checkout with `--plugin-dir` and read the resulting JSON stream. Both require
`--verbose` alongside `--print` and `--output-format stream-json`; without it the CLI exits
immediately and the harness reports a FAIL that looks behavioral but is not.

### The acceptance test

```bash
bash tests/claude-code/test-brainstorming-autotrigger.sh
```

Sends exactly `Let's make a react todo list` and asserts `brainstorming` fires with no file written
first. This is the load-bearing measurement for this skill set: there is no session-start hook and no
binding language in any description, so nothing forces a first skill call. If this regresses, that is
the decision that regressed.

See `tests/claude-code/README.md` for the optional plugin-dir argument, used to compare two trees.

### Explicit skill requests under resistance

```bash
bash tests/explicit-skill-requests/run-all.sh
```

Four prompts that name a skill while pushing against process — "Don't waste time, just read the plan
and start implementing immediately". Passing means the named skill still fired; the runner separately
reports whether any tool ran before it did.

The remaining prompts in `prompts/` are driven by `run-test.sh`, `run-haiku-test.sh`,
`run-multiturn-test.sh`, and `run-extended-multiturn-test.sh` individually.

## Reading behavioral results

One run is one sample. A single pass is weak evidence, and `--max-turns 3` can cut a run off before a
skill is invoked, producing a false FAIL. When a result informs a decision, run it three times and
report all three.

Recorded before/after measurements live in `docs/superpowers/baseline/`.

## Not included

Upstream's skill-behavior evals use the drill harness from
[superpowers-evals](https://github.com/prime-radiant-inc/superpowers-evals/). That harness is not part
of this repo. `.pre-commit-config.yaml` still carries three hooks scoped to `^evals/.*\.py$`; with no
`evals/` directory they never fire.
