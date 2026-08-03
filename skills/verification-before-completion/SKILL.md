---
name: verification-before-completion
description: Use when about to claim work is complete, fixed, or passing, before committing or creating a PR
---

# Verification Before Completion

Before any statement that work is done, fixed, passing, or good:

1. Name the command that would prove the claim.
2. Run it fresh and in full — not a subset, not a remembered earlier run.
3. Read the whole output. Check the exit code. Count the failures.
4. State the claim together with that evidence, or state the actual status together with that evidence.

What each claim actually requires:

| Claim | Evidence |
|---|---|
| Tests pass | Test command output showing 0 failures |
| Linter clean | Linter output showing 0 errors |
| Build succeeds | Build command exiting 0 |
| Bug fixed | The original symptom retested, now passing |
| Regression test works | Reverted the fix, watched the test fail, restored it |
| A subagent finished | The VCS diff, not the agent's report |
| Requirements met | The requirements re-read line by line |

This covers paraphrases, synonyms, and any wording that implies success — including expressions of satisfaction offered before the command has run.

Terminal state: invoke finishing-a-development-branch once the whole branch is done.
