
## Core Principles

- **Simplest solution that works**: Prefer the straightforward approach over the clever one. Touch as little code as possible.
- **Stay in scope**: Change only what the task requires. No drive-by refactors, no unrequested extras.
- **Fix root causes**: No band-aids, no workarounds, no silent `TODO`s. Hold yourself to a senior engineer's standard.

## Git Worktrees and Branches

- **Work where the session started**: never run `git worktree add`, never switch to another checkout, and never create a branch by hand — even on a detached HEAD or when every worktree shows as `locked` (those locks belong to the worktree manager, not to other sessions).
- The `commit-and-open-mr` skill creates the branch when one is missing, commits, pushes, and opens the MR. Let it.
- If the working directory is genuinely not a git checkout, say so and ask where to work instead of fixing it yourself.
