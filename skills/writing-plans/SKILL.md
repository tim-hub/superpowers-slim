---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing Plans

Write for an engineer who knows the language but nothing about this codebase or problem domain. Every step carries what they need: exact paths, real code, real test code, the command to run and the output to expect.

1. Check scope. If the spec spans independent subsystems, write one plan per subsystem; each must produce working, testable software on its own.
2. Map the files before defining tasks — what gets created, what gets modified, what each is responsible for. One responsibility per file. Files that change together live together. Follow the codebase's existing patterns.
3. Draw task boundaries at the smallest unit that carries its own test cycle. Fold setup, config, scaffolding and docs into the task whose deliverable needs them. Split only where a reviewer could reject one task while approving its neighbour.
4. Break each task into 2-5 minute steps: write the failing test, run it and watch it fail, write minimal code, run it and watch it pass, commit.
5. Open the plan with the goal in one sentence, the architecture in two or three, the tech stack, and a Global Constraints section listing project-wide requirements with values copied verbatim from the spec.
6. Give each task a Files block with exact paths, and an Interfaces block naming what it consumes from earlier tasks and what later tasks rely on, with exact signatures. Each task's implementer sees only their own task.
7. Write steps as `- [ ]` checkboxes. Code steps carry the actual code in a fenced block. Verification steps carry the command and its expected output.
8. Save to `docs/superpowers/plans/YYYY-MM-DD-<feature-name>.md`.
9. Re-read the plan against the spec: every requirement has a task, no placeholders remain, and names and types match across tasks.

Never write "TBD", "add error handling", "handle edge cases", "write tests for the above", "similar to Task N", or any reference to a type or function no task defines. Repeat code rather than cross-referencing — tasks get read out of order.

Terminal state: invoke executing-plans.

Depth: plan-document-reviewer-prompt.md
