---
name: test-driven-development
description: Use when implementing any feature or bugfix, before writing implementation code
---

# Test-Driven Development

1. Write one small test for one behaviour. Name it after the behaviour, not the function.
2. Run it. Confirm it fails, and that it fails because the feature is missing rather than from a typo or a broken setup. A test that passes at this point is testing something that already works — fix the test.
3. Write the simplest code that makes it pass. No extra options, no unrelated cleanup, nothing the test does not ask for.
4. Run it again. Confirm it passes, the rest of the suite still passes, and the output is clean with no stray errors or warnings. If it fails, fix the code rather than the test.
5. Refactor while green: remove duplication, improve names, extract helpers. Add no behaviour.
6. Repeat for the next behaviour.

Production code that exists without a test that failed first: delete it and start at step 1. Keeping it as reference and adapting it while writing tests is testing after.

Assert on real behaviour, not on mock behaviour. Match test style to the surrounding suite. If a test is hard to write, the interface is probably hard to use — treat that as a design signal.

For a bug: write a test that reproduces it, watch it fail, then fix it. The test is what stops the bug coming back.

Terminal state: invoke requesting-code-review.

Depth: writing-good-tests.md
