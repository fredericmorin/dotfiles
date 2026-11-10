---
name: supacode-fork
description: Fork this Claude Code session, history included, into a new Supacode tab, in a new worktree (default) or the current one (--same). Use when the user asks to fork the session; to start a fresh session with a new prompt instead, use supacode-new.
argument-hint: "[branch] [-B base-ref] [-n session-name] [-s|--same] [-m model] [--effort level] [--background] [-- prompt...]"
---

```!
~/.claude/skills/supacode-fork/fork.sh --args-stdin 2>&1 <<'SUPACODE_FORK_ARGS_EOF'
$ARGUMENTS
SUPACODE_FORK_ARGS_EOF
```

Relay this in one or two lines: worktree path, branch, new tab, and the
prompt file handed to the fork when there is one. On failure,
quote the error and suggest a fix; don't retry.
