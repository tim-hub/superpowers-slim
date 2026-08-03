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
- `.pre-commit-config.yaml` only has hooks scoped to `^evals/.*\.py$`, and `evals/` is not part of this
  repo. Those hooks never fire here.

## Testing

`bash tests/skills/check-skills.sh` is the structural gate — run it after any skill edit.

Behavioral tests and how to interpret them: `docs/testing.md`.
