---
name: commit-and-open-mr
description: Commit the current changes, push, and open a GitHub PR (gh) or GitLab MR (glab) from the current branch, without creating a worktree or branch. Use when the user asks to commit and open a PR or MR, or to send the work for review; also for "/commit-and-open-mr".
---

# Commit and open a PR/MR

Work in the current checkout, on the current branch. Never create a worktree.
Create a branch only in the case below, and only once the user has picked a name.

## Branch check

If HEAD is detached (`git symbolic-ref -q HEAD` fails) or on the default
branch, stop and ask the user what to do; don't commit yet.

- If HEAD is in the history of `origin/main` or `origin/master`
  (`git merge-base --is-ancestor HEAD origin/<main|master>`), suggest a branch
  name. Otherwise ask without one.
- Once the user picks a name, `git switch -c <name>`; uncommitted changes
  carry over.

Suggested names follow `<user>_<area>_<words>`, lowercase with underscores,
and must not exist locally or on origin:

- `<user>`: the logged-in OS user (`whoami`).
- `<area>`: one word for the code area or theme, e.g. `db`, `refactor`,
  `bugfix`, `lint`, `deps`, `mcp`.
- `<words>`: up to 5 words describing the work.

Example: `fred_db_add_user_active_column`.

## Commit

- Stage the changes that belong to this work. Ask before including anything
  that looks unrelated or might hold secrets.
- Match the repo's commit message style (`git log --oneline -10`).
- If a hook fails, fix the cause and commit again. Never `--no-verify`.
- Nothing to commit and nothing unpushed: say so and stop.

## Push and open

- Pick the CLI from the `origin` URL: GitHub → `gh`, GitLab → `glab`. For a
  self-hosted host, use whichever CLI is logged in to it (`gh auth status`,
  `glab auth status`); if neither is, ask.
- `git push -u origin HEAD`. Never force-push.
- If the branch already has an open PR/MR (`gh pr view`, `glab mr view`), the
  push updated it: report its URL and stop.
- Otherwise open one against the default branch
  (`git symbolic-ref --short refs/remotes/origin/HEAD`). The title and body
  cover every commit on the branch (`git log origin/<default>..HEAD`), not only
  the last one. Fill in the repo's PR/MR template if it has one.
  - `gh pr create --base <default> --title <title> --body-file <file>`
  - `glab mr create --target-branch <default> --title <title> --description <body> --yes`
- Report the commit(s) and the PR/MR URL.
