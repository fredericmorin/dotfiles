---
name: herdr-new
description: Start a fresh Claude Code session (no history) in a new Herdr tab of the same space and folder, with a new narrowly scoped prompt as its first message. Use when the user asks to start, spawn, or hand off a task to a new session in Herdr without forking this one; also for "/herdr-new -- prompt".
argument-hint: "[-n name] [-m model] [--effort level] [--background] [-- prompt...]"
---

# Start a fresh session in a new Herdr tab

Runs `~/.claude/skills/herdr-fork/fork.sh` with `--fresh`. The new session sees
only the prompt, never this conversation. It opens in the same space and the
folder this session started in.

1. **Prompt.** Use the prompt from the arguments verbatim. If the user asked
   you to write it, make it self-contained: the goal, the files and docs
   involved, what is already decided or ruled out, and how to verify.
2. **Name.** Use the given `-n`. If none was given, pick a short name
   (lowercase, dashes, ≤ 30 chars) that describes the prompt's task. It names
   the Herdr tab and the Claude session.
3. **Run** with the Bash tool, passing everything through stdin so the prompt
   reaches the session verbatim. Options go before the first standalone `--`,
   the prompt after it. `--args-stdin` must be the script's only command-line
   argument, so `--fresh` goes in stdin.

   ```bash
   ~/.claude/skills/herdr-fork/fork.sh --args-stdin 2>&1 <<'HERDR_NEW_ARGS_EOF'
   --fresh -n <name> [other options] -- <prompt>
   HERDR_NEW_ARGS_EOF
   ```

4. Relay in one or two lines: the new tab and terminal, and the prompt. On
   failure, quote the error and suggest a fix; don't retry.

Never start `claude` directly or with `hc run`; the script opens the tab
through Herdr's `tab.new`.
