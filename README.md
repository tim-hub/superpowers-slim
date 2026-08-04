# Superpowers (slim)

A software development methodology for Claude Code, delivered as 9 composable skills.

This is a reduced derivative of [obra/superpowers](https://github.com/obra/superpowers) by
[Jesse Vincent](https://blog.fsck.com) and Prime Radiant, trimmed for Claude 5 generation models
following Anthropic's
[new rules of context engineering](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models).
Upstream supports eleven harnesses and fourteen skills with a session-start hook; this fork targets
Claude Code alone, carries nine skills, and has no hook.

## Why fork, and why slim

Everything here follows from one post by Anthropic:
[The new rules of context engineering for Claude 5 generation models](https://claude.com/blog/the-new-rules-of-context-engineering-for-claude-5-generation-models)
(Thariq Shihipar, July 2026). Its subtitle is the summary:

> We removed over 80% of Claude Code's system prompt for more advanced models. How to apply the
> lessons we learned to your own context engineering in Claude Code and with your own agents.

Its diagnosis names skills explicitly, not just system prompts:

> Overall, we found that we were overconstraining Claude Code, both through our system prompt and in
> our CLAUDE.md files and skills.

And the cost it names is not disobedience — it is wasted deliberation, the model reconciling
instructions that fight each other before it can act:

> we see several conflicting messages in a single request like "leave documentation as appropriate,"
> or "DO NOT add comments" as our system prompt, skills, and user requests clash with each other.
> Generally, Claude can interpret the user's intent to get to the right answer, but Claude must think
> more carefully about these overlapping and conflicting messages before deciding what to do.

### Why a fork rather than a patch upstream

The post's own guidance on skills answers this:

> It's best when skills encode particular opinions, knowledge, or best practices that are particular to
> you, your team, or product.

Skills are opinions. This fork holds a different one from upstream's, and upstream's is deliberate and
tested — their contributing guidelines require extensive eval evidence before behavior-shaping content
changes, and reject reformatting toward Anthropic's published guidance without it. That is a reasonable
position for a library eleven harnesses depend on. A fork is the honest unit for a differing opinion,
not a pull request.

### The rules, and what each one changed here

| The post says | What that meant here |
|---|---|
| **Let Claude use judgement**, not rules. Its example replaces "Never write multi-line comment blocks" with "Write code that reads like the surrounding code: match its comment density, naming, and idiom." | Dropped every Iron Law fence, rationalization table, and red-flag list. Deleted `using-git-worktrees` outright — whether to make a worktree is judgement, not procedure. `test-driven-development` now ends "Match test style to the surrounding suite", which is the post's own replacement line applied to tests. |
| **Design interfaces, not examples.** "giving examples actually constrains them to a certain exploration space." | Dropped the good/bad code pairs and worked bugfix example from `test-driven-development`, the dispatch example from `requesting-code-review`, and the multi-layer bash example from `systematic-debugging`. |
| **Progressive disclosure.** "For long skills, try and use progressive disclosure as much as possible — divide it into many files and split them out." | `SKILL.md` is workflow steps only; depth lives in sibling files that load only when a pointer is followed. Deleted the session-start hook, which force-fed a bootstrap into every session whether or not it was wanted. |
| **Don't repeat yourself across layers.** Earlier models "could sometimes need repeated instructions or be more likely to listen to instructions at the end of their context window than at the start." | That recency bias is the reason the bootstrap existed. With it gone, each instruction has one home: the skill body, or the description, never both. |
| **Keep CLAUDE.md light.** "spend most of the tokens on gotchas inside of the codebase… Avoid stating 'the obvious' things Claude should know by looking at your file system or your repo." | `CLAUDE.md` was rewritten from scratch: two lines of identity, the rest gotchas that are invisible from the file tree — how `SKILL.md` and sibling-file loading differ, the frontmatter contract, why `@`-links are banned. |
| **Skills are lightweight guides.** "Avoid making them overconstrained, except in highly important areas." | The general case: nine skills, 71% less prose, no exhortation. The carve-out is the next section. |

Two of the post's rules do not apply here. Auto-memory replaces manual `#` writes to `CLAUDE.md`, and
this plugin stores no memories. Rich references — specs as test suites, HTML mockups, rubrics — is about
what you hand Claude, not how skills are written; `brainstorming` and `writing-plans` already emit specs
and plans as real artifacts under `docs/superpowers/`.

### Where the post needed its own caveat

"Except in highly important areas" turned out to be load-bearing, and measurement found where.

Same prompt each time — `Let's make a react todo list` — asking whether `brainstorming` fires before any
file is written:

| configuration | hook | skill bodies | fires |
|---|---|---|---|
| upstream | present | original | 1/1 |
| control | removed | original | 3/3 |
| first attempt | removed | rewritten, neutral description | 4/6 |
| shipped | removed | rewritten, binding description | 3/3 |

Removing the hook cost nothing: 3/3 with skills untouched. Rewriting the bodies cost nothing either.
But replacing `brainstorming`'s `You MUST use this before any creative work` with a neutral when-to-use
clause dropped triggering to 4/6, and restoring that one frontmatter field brought it back to 3/3 with
all nine rewritten bodies kept.

So the post's advice holds for everything a skill says *after* it loads, and breaks for the one line that
decides *whether* it loads. Descriptions are always in context — they are the only text present when the
model chooses whether to invoke anything — which makes them the wrong place to economise and exactly the
"highly important area" the carve-out is pointing at. Full evidence, including three confounds that each
looked like a result first, is in `docs/superpowers/baseline/`.

The one motive not from the post: `subagent-driven-development` dispatches a fresh implementer and two
reviewers per task, and that runtime cost dominates everything else these skills do. Removing the pattern
removes the cost; deleting its 6,697 words of prose was almost incidental.

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
