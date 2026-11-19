---
name: fanout-run-step
description: Spawn one worktree and one Claude Code session per sidecar prompt of one step of a fan-out plan written with fanout-plan. Use after the user has reviewed the plan and says go, spawn, fan out, or launch the sessions; also for "/fanout-run-step <plan>".
argument-hint: "<tmp/plan.md> [--step N] [--only 1,3] [-B base-ref] [--fork] [--background] [--model m] [--effort level]"
---

# Fan out one step of a reviewed plan

`~/.claude/skills/fanout-run-step/spawn.sh` (flags: `--help`) spawns one step's
sidecars. For each one it creates a worktree on the sidecar's branch and starts
a fresh `claude` session with the sidecar prompt in it. It defaults to the
lowest step that has not been spawned yet.

It works in the app it runs in, shown as `app:` in its output:
- **Supacode** (`SUPACODE_REPO_ID` set): a Supacode worktree and tab per unit.
- **Herdr** (the terminal has a `herdr.space` label): a worktree space per unit,
  listed under the repo's space in the sidebar (when the main checkout has one),
  made by Herdr's worktree dialog (`my-worktree`, opened through the
  `worktree-request` mod) so the project's `projects.json` setup runs. The
  script makes the branch at the base ref first, because the dialog has no
  base option. `--background` has no effect there: each new space is shown.

- Pass `--model opus --effort medium --background` by default, unless the user
  asks for another model, effort, or a foreground launch.
- Dry-run first and show the table. `SKIP` rows are already spawned.
  Launch for real only once the user has given the go, which may already be
  in the request.
- Steps are sequential. Before spawning step N > 1, confirm step N−1 is done
  by the plan's own exit condition (merged is often not enough: deployed,
  migrated, a script run), then use `-B origin/master` after a fetch. If it
  is not done, say so and stop.
- Only code units have sidecars. A step's command and wait units are run
  from their rows in the plan's step table, not spawned, and the step is done
  only once they pass their checks too. A step with no sidecar is never
  spawned: hand over its commands from the plan instead.
- Uncommitted plans still work, because the sessions get absolute paths.
- Report the spawned branches and worktree paths. Each session opens its own MR.
- When you hand over the next step, give the script command, not the
  `/fanout-run-step` prompt, so the user can run it without a Claude turn:
  `! git fetch origin && ~/.claude/skills/fanout-run-step/spawn.sh <plan.md> --step N -B origin/master --model opus --effort medium --background`
  (add `--dry-run` to preview). The script does not check that the previous
  step is done, so tell the user to confirm that first.
- Only the app creates the worktrees (Supacode, or Herdr's worktree dialog),
  so the setup script runs. Never use `git worktree add`, create branches by
  hand, or start `claude` directly.
