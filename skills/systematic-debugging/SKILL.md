---
name: systematic-debugging
description: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
---

# Systematic Debugging

## Find the root cause

1. Read the error and the full stack trace. Note line numbers, paths, and codes. The answer is often already in there.
2. Reproduce it. Establish the exact steps and whether it happens every time. Not reproducible means gather more data, not guess.
3. Check what changed — recent commits, new dependencies, config, environment.
4. In a system with multiple components, instrument every boundary before proposing anything: log what enters each component, what leaves it, and whether config and environment propagated. Run once, then read the evidence to find which layer breaks.
5. Trace the bad value backward — where it originated, what passed it in — until you reach the source. Fix there, not at the symptom.

## Compare against what works

6. Find similar working code in this codebase.
7. If you are applying a pattern, read the reference implementation completely. Skimming it produces bugs.
8. List every difference between the working case and the broken one, however small.

## Test one hypothesis

9. State it plainly: X is the root cause because Y.
10. Make the smallest change that tests it. One variable at a time.
11. If it did not work, form a new hypothesis. Do not stack another fix on top of the last one.
12. Say plainly when you do not understand something rather than proceeding as if you do.

## Fix at the source

13. Write a failing test that reproduces the bug, before fixing anything.
14. Make one change, at the root cause. No bundled refactoring, no while-I-am-here improvements.
15. Verify: the test passes, nothing else broke, the original symptom is gone.
16. Count your failed fixes. At three, stop fixing and question the architecture with your partner. Fixes that each surface a new problem somewhere else mean the design is wrong, not the hypothesis.

If investigation shows the cause is genuinely environmental, timing-dependent, or external, document what you ruled out, add appropriate handling and monitoring, and say so explicitly.

Terminal state: invoke test-driven-development to lock the fix in with a regression test.

Depth: root-cause-tracing.md, defense-in-depth.md, condition-based-waiting.md
