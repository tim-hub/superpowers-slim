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
