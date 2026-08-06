---
name: brainstorming
description: "You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
---

# Brainstorming

1. Read the project context first — files, docs, recent commits.
2. Check scope. If the request spans several independent subsystems, decompose it before refining details, then brainstorm only the first sub-project. Each sub-project gets its own spec.
3. Ask clarifying questions one at a time, one question per message. Prefer multiple choice. Cover purpose, constraints, and success criteria.
4. Propose 2-3 approaches with their trade-offs. Lead with your recommendation and say why. Cut anything speculative from every approach.
5. Present the design in sections, each scaled to its complexity — a few sentences when it is straightforward. Ask after each section whether it holds before continuing. Cover architecture, components, data flow, error handling, and testing.
6. Give each unit one responsibility and a defined interface. For every unit, be able to say what it does, how it is used, and what it depends on. If someone cannot tell what a unit does without reading its internals, the boundary is wrong.
7. In an existing codebase, follow the established patterns. Include targeted cleanup where existing code blocks this work; leave unrelated problems alone and mention them instead.
8. Get explicit approval on the design before anything gets built.
9. Write the spec to `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` and commit it.
10. Re-read the spec: no placeholders, no sections contradicting each other, scope small enough for one plan, no requirement readable two ways. Fix inline.
11. Ask your partner to review the committed spec. Make any changes they ask for and re-check.

Terminal state: invoke writing-plans. Invoke no other skill from here.

Depth: spec-document-reviewer-prompt.md
