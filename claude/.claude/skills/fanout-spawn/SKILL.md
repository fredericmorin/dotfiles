---
name: fanout-spawn
description: Spawn one Supacode worktree and one Claude Code session per sidecar prompt of one step of a fan-out plan written with fanout-plan. Use after the user has reviewed the plan and says go, spawn, fan out, or launch the sessions; also for "/fanout-spawn <plan>".
argument-hint: "<docs/specs/plan.md> [--step N] [--only 1,3] [-B base-ref] [--fork] [--background]"
---

# Fan out one step of a reviewed plan into Supacode worktrees

`~/.claude/skills/fanout-spawn/spawn.sh` reads a fan-out plan's sidecars
(`<plan-stem>_step<N>.md` for a single-unit step, `<plan-stem>_step<N>_part<M>.md`
for each part of a parallel group, each with a `Branch:` line and a `## Prompt`
section), picks **one step**, and for each sidecar of that step:

1. creates a Supacode worktree on that branch from the base ref
   (`supacode repo worktree-new`), which runs the repo's Supacode setup script;
2. opens a tab in that worktree running `claude -n <branch> "<prompt>"`, where
   the prompt is the sidecar's `## Prompt` body with a short preamble naming the
   plan, the sidecar, the step and part, the branch, and the instruction to ship
   via `commit-and-open-mr`.

Steps are sequential: step N+1 is written against the tree after step N merged,
so only one step is spawned per run. Without `--step` the script picks the lowest
step that still has an unspawned sidecar. Parts of a step are parallel and all
spawn together unless `--only` narrows them.

Sessions start fresh by default, because sidecars are written for zero
context. `--fork` forks the current session into each worktree instead.

## Procedure

1. Run `spawn.sh <plan> --dry-run` (plus any `--step`/`--only`/`-B` the user
   gave) and show the table: step, part, branch, action, sidecar. `SKIP (branch
   exists)` rows mean that unit was already spawned or started by hand.
2. If the chosen step is > 1, the base must already contain the previous step.
   Check that the previous step's MR(s) merged, then pass `-B origin/master`
   (after `git fetch`) unless the user gave a base. Say so if it has not merged
   yet and stop.
3. If the plan or sidecars are uncommitted, the dry run still works: the
   preamble then points the sessions at the absolute paths in this checkout.
   Mention it; committing the plan first is cleaner but not required.
4. If the user's request already gave the go, run for real immediately with the
   same flags. Otherwise stop after the dry run and wait for the go.
5. Report the SPAWNED rows with worktree paths. Each session opens its own MR.
   The user follows progress in the Supacode sidebar, and comes back with
   `/fanout-spawn <plan>` for the next step once this one has merged.

Never `git worktree add`, never create branches by hand, never start `claude`
directly: Supacode must create the worktree so its setup script runs.
