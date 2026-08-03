---
name: requesting-code-review
description: Use when work is implemented and needs review before merging
---

# Requesting Code Review

1. Capture the range: `BASE_SHA=$(git rev-parse HEAD~1)` — or `origin/main` for a whole branch — and `HEAD_SHA=$(git rev-parse HEAD)`.
2. Dispatch a `general-purpose` subagent using the template in `code-reviewer.md`, filling in what you built, what it was supposed to do, and the two SHAs.
3. Give the reviewer that crafted context and nothing else — never your session history. The diff and the reading of it stay in the reviewer's context; only the findings come back into yours.
4. Fix Critical findings before anything else, Important findings before moving on, and note Minor ones.
5. Where the reviewer is wrong, push back with technical reasoning and point at the tests or code that prove it.

Terminal state: invoke receiving-code-review to work through the findings.

Depth: code-reviewer.md
