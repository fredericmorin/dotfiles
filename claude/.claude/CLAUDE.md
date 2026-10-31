
## Core Principles

- **Simplest solution that works**: Prefer plain, boring code over clever code: several clear statements beat one dense expression, unless the dense version is much faster. Touch as little code as possible.
- **Stay in scope**: Change only what the task requires. No drive-by refactors, no unrequested extras. If the current design makes the change awkward, finish the minimal version, then say so and offer the refactor as an option. Don't do the refactor unless I ask.
- **Fix root causes**: No band-aids, no workarounds, no silent `TODO`s. Hold yourself to a senior engineer's standard.
- **Ask when the answer changes the outcome**: If a request can be read two ways that lead to different results, ask. For small details, pick the conventional option and mention it.

## Requests

- Match the action to the verb I use:
  - Questions ("why", "what", "is there", "would it"): answer the question and don't edit anything.
  - Analysis ("check", "review", "analyze", "evaluate", "propose"): report what you find and don't edit anything.
  - Actions ("add", "fix", "change", "implement", "clean up"): make the edit.
- Back up claims with evidence such as a file and line, command output, or a doc link. If something is a guess, label it as one.
- Report in short bullet points rather than long prose.

## Code

- Never edit generated files. Edit the generator's input, then ask before running the generator.
- Assume all text can be UTF-8, including file names, file contents, user input, and downloaded data.
- Comments: write a short one-liner only where a design decision needs explaining.

## Safety

- Never escalate privileges (`sudo`, docker tricks, and so on). If a task needs them, say so and stop.

## Git Worktrees and Branches

- **Work where the session started**: never run `git worktree add`, never switch to another checkout, and never create a branch by hand — even on a detached HEAD or when every worktree shows as `locked` (those locks belong to the worktree manager, not to other sessions).
- If the working directory is genuinely not a git checkout, say so and ask where to work instead of fixing it yourself.

## Shell (zsh)

- **zsh does not word-split unquoted `$var`** (unlike bash): `list="a b c"; for x in $list` runs once with `x="a b c"`. Use an array (`list=(a b c); for x in $list`), write the words inline (`for x in a b c`), or force splitting with `${=list}`. Same trap when passing `$args` to a command: it arrives as one argument.
