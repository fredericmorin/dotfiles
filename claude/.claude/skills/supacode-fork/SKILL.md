---
name: supacode-fork
description: Fork the current Claude Code session into a new Supacode-created worktree (setup scripts run automatically) and open the fork in a new Supacode tab there. Use for "/supacode-fork", "fork this session into a new worktree", or "continue this conversation in a separate worktree".
argument-hint: "[branch] [-B base-ref] [-n session-name] [--background]"
disable-model-invocation: true
---

Fork result:

!`~/.claude/skills/supacode-fork/fork.sh $ARGUMENTS 2>&1`

Report the result above to the user in one or two lines: the new worktree
path, branch, and that the forked session is starting in a new Supacode tab.
If it failed, quote the error and say how to fix it. Do not retry and do not
run any other command.
