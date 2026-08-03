# Superpowers (slim)

A software development methodology for Claude Code, delivered as 9 composable skills.

This is a reduced derivative of [obra/superpowers](https://github.com/obra/superpowers) by
[Jesse Vincent](https://blog.fsck.com) and Prime Radiant, trimmed for Claude 5 generation models
following Anthropic's
[new rules of context engineering](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models).
Upstream supports eleven harnesses and fourteen skills with a session-start hook; this fork targets
Claude Code alone, carries nine skills, and has no hook.

## Why it's slim

Upstream was built for models that needed to be argued with. Its skills carry Iron Laws, tables of
rationalizations to pre-empt, red-flag lists of thoughts to catch yourself having, and a hook that
injects a bootstrap into every session so none of it can be skipped. That machinery exists because it
was measured to work — on the models of the time.

Anthropic's own position on Claude 5 generation models is that this shape now costs more than it buys:

> Overall, we found that we were overconstraining Claude Code, both through our system prompt and in
> our CLAUDE.md files and skills.

The cost they name is not disobedience but wasted deliberation — the model spends effort reconciling
instructions that contradict each other before it can act:

> we see several conflicting messages in a single request like "leave documentation as appropriate,"
> or "DO NOT add comments" as our system prompt, skills, and user requests clash with each other.

They removed over 80% of Claude Code's own system prompt on that basis. This fork applies the same
reasoning to the skills: keep every workflow step, drop the argument around it. A skill becomes
numbered steps plus a line naming the next skill, and nothing else.

The second motive is narrower. `subagent-driven-development` dispatches a fresh implementer and two
reviewers per task; that runtime cost dominates everything else these skills do. Removing the pattern
removes the cost — deleting its 6,697 words of prose was almost incidental.

### What the measurements showed

The rewrite was not taken on faith. Before/after runs of the same prompt — `Let's make a react todo
list` — asking whether `brainstorming` fires before any file gets written:

| configuration | hook | skill bodies | fires |
|---|---|---|---|
| upstream | present | original | 1/1 |
| control | removed | original | 3/3 |
| first attempt | removed | rewritten, neutral description | 4/6 |
| shipped | removed | rewritten, binding description | 3/3 |

Two findings, and they point in opposite directions:

**The hook was redundant.** With it deleted and skills untouched, triggering held at 3/3. Claude Code
discovers `skills/` by convention, so the bootstrap was buying nothing — and it was the only always-on
context cost in the whole plugin.

**The description was not.** Rewriting the bodies was free, but replacing `brainstorming`'s
`You MUST use this before any creative work` with a neutral when-to-use clause dropped triggering to
4/6. Restoring that one frontmatter field returned it to 3/3, with all nine rewritten bodies kept.

So progressive disclosure works on skill bodies, while the always-on surface still needs authority
framing. Descriptions are the one text present at the moment the model decides whether to invoke
anything; that is the wrong place to economise. The full evidence, including three confounds that each
looked like a result first, is in `docs/superpowers/baseline/`.

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

Net effect on context: `SKILL.md` prose went from 8,751 words to 2,531 (71%), all skill markdown from
16,576 to 6,753 (59%), and always-on context from 481 words to zero. Measured against all fourteen
upstream skills rather than the nine kept, `SKILL.md` prose is down 87%.

Cost is per invocation, not per session — `SKILL.md` loads in full when a skill is invoked, and files
beside it load only if the model follows a pointer. So the number that matters is the size of the
skills you actually use in a given session, not the total.

Design rationale and the risks accepted going in:
`docs/superpowers/specs/2026-08-04-slim-superpowers-design.md`.

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
