---
name: finishing-a-development-branch
description: Use when implementation is complete and tests pass, and the work needs integrating
---

# Finishing a Development Branch

1. Run the project's full test suite. If anything fails, report the failures and stop — the menu comes only after a green suite.
2. Detect the workspace, capturing all three values now, before anything changes directory:

```bash
GIT_DIR=$(cd "$(git rev-parse --git-dir)" 2>/dev/null && pwd -P)
GIT_COMMON=$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd -P)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
```

3. Establish the base branch from the plan, the conversation, or the branch's upstream. If it is not already known, ask — merging into the wrong base is expensive to undo.
4. Present the menu exactly as written, then wait. The integration decision is your partner's.

Normal repo, or a worktree on a named branch:

```
Implementation complete. What would you like to do?

1. Merge back to <base-branch> locally
2. Push and create a Pull Request
3. Keep the branch as-is (I'll handle it later)

Which option?
```

Detached HEAD, meaning an externally managed workspace — no merge option:

```
Implementation complete. You're on a detached HEAD (externally managed workspace).

1. Push as new branch and create a Pull Request
2. Keep as-is (I'll handle it later)

Which option?
```

5. **Merge locally:** `cd` to the main repo root, then `git checkout <base>`, `git pull`, `git merge <feature>`, then run the tests on the merged result. If they fail, stop and leave the branch and worktree in place — nothing was pushed, so it is recoverable. Once green, clean up per step 7, then `git branch -d <feature>`.
6. **Push and PR:** `git push -u origin <feature>`, or from a detached HEAD `git push origin HEAD:refs/heads/<new-branch>`. Open the request against the base branch using the forge's CLI or the URL it prints on push, following the repo's PR template if it has one, and report the URL. Keep the worktree — PR feedback gets fixed there.
7. **Cleanup**, for a local merge only. Run it from outside the worktree, using the values captured in step 2. If `GIT_DIR` equals `GIT_COMMON` there is no worktree to remove. If `WORKTREE_PATH` is under `.worktrees/` or `worktrees/` it is ours: `git worktree remove "$WORKTREE_PATH"` then `git worktree prune`. Otherwise the host environment owns it — leave it in place.

Discarding the work happens only when your partner asks for it in so many words. Show exactly what will be deleted — branch, commit list, worktree path — and wait for them to type `discard` before `git branch -D`.
