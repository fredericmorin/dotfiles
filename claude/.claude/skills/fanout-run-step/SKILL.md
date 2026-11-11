---
name: fanout-run-step
description: Spawn one Supacode worktree and one Claude Code session per sidecar prompt of one step of a fan-out plan written with fanout-plan. Use after the user has reviewed the plan and says go, spawn, fan out, or launch the sessions; also for "/fanout-run-step <plan>".
argument-hint: "<docs/specs/plan.md> [--step N] [--only 1,3] [-B base-ref] [--fork] [--background] [--model m] [--effort level]"
---

# Fan out one step of a reviewed plan

`~/.claude/skills/fanout-run-step/spawn.sh` (flags: `--help`) spawns one step's
sidecars. For each one it creates a Supacode worktree on the sidecar's branch
and starts a fresh `claude` session with the sidecar prompt in it. It defaults
to the lowest step that has not been spawned yet.

- Dry-run first and show the table. `SKIP` rows are already spawned.
  Launch for real only once the user has given the go, which may already be
  in the request.
- Steps are sequential. Before spawning step N > 1, confirm step N−1 is done
  by the plan's own exit condition (merged is often not enough: deployed,
  migrated, a script run), then use `-B origin/master` after a fetch. If it
  is not done, say so and stop.
- Uncommitted plans still work, because the sessions get absolute paths.
- Report the spawned branches and worktree paths. Each session opens its own MR.
- When you hand over the next step, give the script command, not the
  `/fanout-run-step` prompt, so the user can run it without a Claude turn:
  `! git fetch origin && ~/.claude/skills/fanout-run-step/spawn.sh <plan.md> --step N -B origin/master`
  (add `--dry-run` to preview). The script does not check that the previous
  step is done, so tell the user to confirm that first.
- Only Supacode creates the worktrees, so its setup script runs. Never use
  `git worktree add`, create branches by hand, or start `claude` directly.
