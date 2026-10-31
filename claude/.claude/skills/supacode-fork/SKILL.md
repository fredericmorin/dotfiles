---
name: supacode-fork
description: Fork this Claude Code session into a new Supacode tab, in a new worktree (default) or the current one (--same).
argument-hint: "[branch] [-B base-ref] [-n session-name] [-s|--same] [--background] [-- prompt...]"
disable-model-invocation: true
---

```!
~/.claude/skills/supacode-fork/fork.sh --args-stdin 2>&1 <<'SUPACODE_FORK_ARGS_EOF'
$ARGUMENTS
SUPACODE_FORK_ARGS_EOF
```

Relay this in one or two lines: worktree path, branch, new tab, and the
prompt file handed to the fork when there is one. On failure,
quote the error and suggest a fix; don't retry.
