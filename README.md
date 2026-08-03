# Superpowers (slim)

A software development methodology for Claude Code, delivered as 9 composable skills.

This is a reduced derivative of [obra/superpowers](https://github.com/obra/superpowers) by
[Jesse Vincent](https://blog.fsck.com) and Prime Radiant, trimmed for Claude 5 generation models
following Anthropic's
[new rules of context engineering](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models).
Upstream supports eleven harnesses and fourteen skills with a session-start hook; this fork targets
Claude Code alone, carries nine skills, and has no hook.

## What changed from upstream

- **No session-start hook.** Claude Code discovers `skills/` by convention, so skills are invocable
  without injecting a bootstrap into every session. Removing it also removes the only always-on
  context cost.
- **Five skills removed** — `using-superpowers` (the bootstrap), `using-git-worktrees` (worktree
  choice is a judgement call, not a procedure), `subagent-driven-development` (runtime token cost),
  `dispatching-parallel-agents`, and `writing-skills`.
- **Nine skills rewritten as pure recipes** — numbered workflow steps plus a terminal-state line.
  No Iron Law fences, rationalization tables, or red-flag lists. `SKILL.md` prose went from 8,751
  words to 2,521, a 71% reduction, with no workflow step dropped.
- **Claude Code only.** The six other harness manifests, their tests, and the porting docs are gone.

Before/after behavioral measurements are in `docs/superpowers/baseline/`. The design rationale and
the accepted risks are in `docs/superpowers/specs/2026-08-04-slim-superpowers-design.md`.

## Installation

```bash
/plugin marketplace add <your-remote>
/plugin install superpowers
```

For local development, point Claude Code at this checkout:

```bash
claude --plugin-dir /path/to/superpowers
```

## The workflow

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

systematic-debugging ──▶ test-driven-development   (lock the fix with a regression test)
```

Each skill ends by naming the next one. Nothing coordinates the chain from always-on context.

## Skills

| Skill | When it applies |
|---|---|
| `brainstorming` | Turning an idea into a design, before writing code |
| `writing-plans` | Turning a spec into a task-by-task plan |
| `executing-plans` | Working through a written plan |
| `test-driven-development` | Implementing any feature or bugfix |
| `systematic-debugging` | Any bug, test failure, or unexpected behavior |
| `requesting-code-review` | Work is implemented and needs review |
| `receiving-code-review` | Review feedback has arrived |
| `verification-before-completion` | About to claim work is complete |
| `finishing-a-development-branch` | Implementation done, work needs integrating |

## Philosophy

- Design before code
- Write tests first, always
- Root cause before fixes
- Evidence before claims

## Contributing

See `CLAUDE.md` for the skill-authoring contract and `docs/testing.md` for how skill changes get
tested. Run `bash tests/skills/check-skills.sh` after any skill edit.

Upstream does not accept changes of this kind by policy, so do not send these commits to
obra/superpowers.

## License

MIT — see `LICENSE`. Copyright retained from the upstream project.
