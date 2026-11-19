---
name: herdr-new
description: Start a fresh Claude Code session (no history) in a new Herdr worktree space (a new branch, set up by the project's projects.json setup), with a new narrowly scoped prompt as its first message. Use when the user asks to start, spawn, or hand off a task to a new session in Herdr without forking this one; also for "/herdr-new -- prompt".
argument-hint: "[-b branch] [-B base-ref] [-n name] [-m model] [--effort level] [--background] [-- prompt...]"
---

# Start a fresh session in a new Herdr worktree

Runs `~/.claude/skills/herdr-fork/fork.sh` with `--fresh`. The new session sees
only the prompt, never this conversation. It opens in a new worktree of this
session's repo, on a new branch from origin's default branch (or `-B <base-ref>`),
as a new space made by Herdr's worktree dialog, so the project's setup runs
before Claude starts.

1. **Prompt.** Use the prompt from the arguments verbatim. If the user asked
   you to write it, make it self-contained: the goal, the files and docs
   involved, what is already decided or ruled out, and how to verify.
2. **Name.** Use the given `-n`. If none was given, pick a short name
   (lowercase, dashes, ≤ 30 chars) that describes the prompt's task. It names
   the branch (unless `-b` is given), the Herdr tab and the Claude session.
3. **Run** with the Bash tool, passing everything through stdin so the prompt
   reaches the session verbatim. Options go before the first standalone `--`,
   the prompt after it. `--args-stdin` must be the script's only command-line
   argument, so `--fresh` goes in stdin.

   ```bash
   ~/.claude/skills/herdr-fork/fork.sh --args-stdin 2>&1 <<'HERDR_NEW_ARGS_EOF'
   --fresh -n <name> [other options] -- <prompt>
   HERDR_NEW_ARGS_EOF
   ```

4. Relay in one or two lines: the branch, the worktree path, and the prompt. On
   failure, quote the error and suggest a fix; don't retry.

Never start `claude` directly, with `hc run`, or after `git worktree add`; the
script has Herdr's worktree dialog make the checkout so the setup runs.
