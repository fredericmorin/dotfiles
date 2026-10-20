
## Core Principles

- **Simplest solution that works**: Prefer the straightforward approach over the clever one. Touch as little code as possible.
- **Stay in scope**: Change only what the task requires. No drive-by refactors, no unrequested extras.
- **Fix root causes**: No band-aids, no workarounds, no silent `TODO`s. Hold yourself to a senior engineer's standard.

## Git Worktrees and Branches

- **Work where the session started**: never run `git worktree add`, never switch to another checkout, and never create a branch by hand — even on a detached HEAD or when every worktree shows as `locked` (those locks belong to the worktree manager, not to other sessions).
- If the working directory is genuinely not a git checkout, say so and ask where to work instead of fixing it yourself.

## Shell (zsh)

- **zsh does not word-split unquoted `$var`** (unlike bash): `list="a b c"; for x in $list` runs once with `x="a b c"`. Use an array (`list=(a b c); for x in $list`), write the words inline (`for x in a b c`), or force splitting with `${=list}`. Same trap when passing `$args` to a command: it arrives as one argument.
