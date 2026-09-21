---
name: fanout-spawn
description: Spawn one Supacode worktree and one Claude Code session per sidecar prompt of a fan-out plan written with fanout-plan. Use after the user has reviewed the plan and says go, spawn, fan out, or launch the sessions; also for "/fanout-spawn <plan>".
argument-hint: "<docs/specs/plan.md> [--only 1,3] [-B base-ref] [--fork] [--background]"
---

# Fan out a reviewed plan into Supacode worktrees

`~/.claude/skills/fanout-spawn/spawn.sh` reads a fan-out plan's sidecars
(`<plan-stem>_group_<N>_*.md`, each with a `Branch:` line and a `## Prompt`
section), and for each one:

1. creates a Supacode worktree on that branch from the base ref
   (`supacode repo worktree-new`), which runs the repo's Supacode setup script;
2. opens a tab in that worktree running `claude -n <branch> "<prompt>"`, where
   the prompt is the sidecar's `## Prompt` body with a short preamble naming the
   plan, the sidecar, the branch, and the instruction to ship via
   `commit-and-open-mr`.

Sessions start fresh by default, because sidecars are written for zero
context. `--fork` forks the current session into each worktree instead.

## Procedure

1. Run `spawn.sh <plan> --dry-run` (plus any `--only`/`-B` the user gave) and
   show the table: group, branch, action, sidecar. `SKIP (branch exists)` rows
   mean that unit was already spawned or started by hand.
2. If the plan or sidecars are uncommitted, the dry run still works: the
   preamble then points the sessions at the absolute paths in this checkout.
   Mention it; committing the plan first is cleaner but not required.
3. If the user's request already gave the go, run for real immediately with the
   same flags. Otherwise stop after the dry run and wait for the go.
4. Report the SPAWNED rows with worktree paths. Each session opens its own MR.
   The user follows progress in the Supacode sidebar.

Never `git worktree add`, never create branches by hand, never start `claude`
directly: Supacode must create the worktree so its setup script runs.
