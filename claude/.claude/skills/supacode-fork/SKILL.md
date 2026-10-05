---
name: supacode-fork
description: Fork this Claude Code session into a new Supacode worktree and open it in a new Supacode tab.
argument-hint: "[branch] [-B base-ref] [-n session-name] [--background] [-- prompt...]"
disable-model-invocation: true
---

!`~/.claude/skills/supacode-fork/fork.sh $ARGUMENTS 2>&1`

Relay this in one or two lines: worktree path, branch, new tab, and the
prompt handed to the fork when there is one. On failure,
quote the error and suggest a fix; don't retry.
