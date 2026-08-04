# Contributor Guidelines

A set of 9 skills for Claude Code, reduced from [obra/superpowers](https://github.com/obra/superpowers)
for Claude 5 generation models. Skills only — no session-start hook, no other harness.

## Gotchas

- Skills are behavior-shaping prose, not code. A change that reads well can still make behavior worse,
  so changes get tested behaviorally, not just reviewed.
- `SKILL.md` loads in full the moment a skill is invoked. Files in the same directory load only when
  the model follows a pointer to them. Put depth in a separate file and point at it.
- A description says *when* to use the skill. It never summarizes the workflow — a description that
  summarizes becomes a shortcut the model takes instead of reading the body. Nothing checks this one
  mechanically, so it is the rule you have to hold yourself to.
- Skill anatomy is fixed: title, numbered steps, terminal-state line, reference pointers. Nothing else.
- When a skill outgrows its word ceiling, raise the ceiling in `tests/skills/check-skills.sh`. Never
  drop a workflow step to fit.

## Testing

`bash tests/skills/check-skills.sh` is the structural gate — run it after any skill edit. It is also
the source of truth for the mechanical contract: frontmatter keys and size, the `@`-link ban, and the
word ceilings. Read its failure output rather than looking for those rules here.

Behavioral tests and how to interpret them: `docs/testing.md`.
