---
name: herdr-fork
description: Fork this Claude Code session, history included, into a new Herdr worktree space (a new branch, set up by the project's projects.json setup). Use when the user asks to fork or clone the session in Herdr; to start a fresh session with a new prompt instead, use herdr-new.
argument-hint: "[-b branch] [-B base-ref] [-n name] [-m model] [--effort level] [--background] [-- prompt...]"
---

```!
~/.claude/skills/herdr-fork/fork.sh --args-stdin 2>&1 <<'HERDR_FORK_ARGS_EOF'
$ARGUMENTS
HERDR_FORK_ARGS_EOF
```

Relay this in one or two lines: the branch, the worktree path, and the prompt
handed to the fork when there is one. On failure, quote the error and suggest a fix;
don't retry.
