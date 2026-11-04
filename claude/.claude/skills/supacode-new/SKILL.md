---
name: supacode-new
description: Start a fresh Claude Code session (no history) in a new Supacode worktree, with a new narrowly scoped prompt as its first message. Use when the user asks to start, spawn, or hand off a task to a new session or worktree without forking this one; also for "/supacode-new [branch] -- prompt".
argument-hint: "[branch] [-B base-ref] [-n session-name] [-s|--same] [-m model] [--background] [-- prompt...]"
---

# Start a fresh session in a new worktree

Runs `~/.claude/skills/supacode-fork/fork.sh` with `--fresh`. The new session sees
only the prompt, never this conversation.

1. **Prompt.** Use the prompt from the arguments verbatim. If the user asked
   you to write it, make it self-contained: the goal, the files and docs
   involved, what is already decided or ruled out, and how to verify. Use
   absolute paths for files that are not committed on the base.
2. **Branch.** Use the given branch. If none was given, pick a short
   name `fred_<topic>` (lowercase, underscores, ≤ 40 chars) that
   describes the prompt's task, and make sure it does not exist yet
   (`git show-ref --verify --quiet refs/heads/<name>`). Skip this with `--same`.
3. **Run** with the Bash tool, passing everything through stdin so the prompt
   reaches the session verbatim. Options go before the first standalone `--`,
   the prompt after it. `--args-stdin` must be the script's only command-line
   argument, so `--fresh` goes in stdin. Default `-n` to the branch name.

   ```bash
   ~/.claude/skills/supacode-fork/fork.sh --args-stdin 2>&1 <<'SUPACODE_NEW_ARGS_EOF'
   --fresh <branch> -n <branch> [other options] -- <prompt>
   SUPACODE_NEW_ARGS_EOF
   ```

4. Relay in one or two lines: worktree path, branch, new tab, and the prompt
   file. On failure, quote the error and suggest a fix; don't retry.

Only Supacode creates the worktree, so its setup script runs. Never use
`git worktree add`, create branches by hand, or start `claude` directly.
