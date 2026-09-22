---
name: fanout-spawn
description: Spawn one Supacode worktree and one Claude Code session per sidecar prompt of one step of a fan-out plan written with fanout-plan. Use after the user has reviewed the plan and says go, spawn, fan out, or launch the sessions; also for "/fanout-spawn <plan>".
argument-hint: "<docs/specs/plan.md> [--step N] [--only 1,3] [-B base-ref] [--fork] [--background]"
---

# Fan out one step of a reviewed plan

`~/.claude/skills/fanout-spawn/spawn.sh` (flags: `--help`) spawns one step's
sidecars. For each one it creates a Supacode worktree on the sidecar's branch
and starts a fresh `claude` session with the sidecar prompt in it. It defaults
to the lowest step that has not been spawned yet.

- Dry-run first and show the table. `SKIP` rows are already spawned.
  Launch for real only once the user has given the go, which may already be
  in the request.
- Steps are sequential. Before spawning step N > 1, confirm step N−1's MRs
  have merged, then use `-B origin/master` after a fetch. If they haven't
  merged, say so and stop.
- Uncommitted plans still work, because the sessions get absolute paths.
- Report the spawned branches and worktree paths. Each session opens its own MR.
- Only Supacode creates the worktrees, so its setup script runs. Never use
  `git worktree add`, create branches by hand, or start `claude` directly.
