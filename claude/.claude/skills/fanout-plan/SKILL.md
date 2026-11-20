---
name: fanout-plan
description: Use when writing a fan-out plan: the work splits into several independently-shippable units — sequential steps (blocking milestones such as an MR merged and deployed, a script run, a migration applied; not MRs), each either one unit or a group of parts that can be worked in parallel — of three kinds (code: a branch and MR; command: something a developer runs by hand; wait: a read-only check). Writes the plan plus one sidecar prompt file per code unit, each ready to paste into a separate Claude session on its own branch, and the exact command for each unit run by hand
---

# Fan-out plans with sidecar session prompts

Write the plan to `tmp/` at the repo root. When the work has two or more code units
(units that each merit their own branch and MR), also write one sidecar per code unit: a
self-contained prompt for a fresh Claude session with zero conversational context. With a
single code unit, write the same plan without sidecars. The threshold decides only whether
sidecars are written, never the shape: steps, groups, parts, kinds and the full step table
apply either way. When the gate passes, the sidecars are part of the deliverable.

## Session mode

Invoking this skill is the user's request, and approval, to write the plan. That satisfies
any repo rule to use plan mode for plans or specs, so never call `EnterPlanMode` yourself.

- Not in plan mode: write the files directly.
- In plan mode: writes are blocked. Shape in the plan file (plan prose, step table, a
  one-line outline per sidecar: header, branch, scope) and call `ExitPlanMode`. Once
  approved, write the plan and sidecars to `tmp/` without asking again.
- A plan already exists in the session: reshape it into steps, groups, and parts. Don't
  re-explore what it already settles.

## Research budget

Write from what the session already knows. Look something up only when a wrong guess
would change the shape: step boundaries, the part split, shared files. For everything
else, put the discovery command in the sidecar and let that session run it. Use at most
one Explore agent, and only for those shape-changing gaps.

## Vocabulary

Use these terms consistently in the plan, sidecars, filenames, and branches:

- **Step** — a blocking milestone: all of it is completely done, and proven done, before
  the next step starts. Sequential. A step is not an MR. Every step states its exit
  condition: what must be observably true for it to count as done.
- **Group** — the parts of one step that can run in parallel, conflicting at most on a
  small named set of shared files (registry, index, aggregate root).
- **Part** — one member of a group, of any kind. Parts land in any order.
- **Unit** — a single-unit step, or one part. Every unit has exactly one kind.

## Unit kinds

| Kind | Carried out by | Artifact | Done when |
|---|---|---|---|
| Code | a session: one branch, one MR | sidecar `…_step<N>[_part<M>].md` (none below the threshold) | merged *and* running where the next step needs it: deployed, applied, migrated |
| Command | the user: any write to a shared system outside an MR (admin `kubectl`, `tofu apply`, psql `--write`, `pyrolite alembic migrate`, a Grafana push, a script run) | the exact command in its table row, or a script `…_step<N>[_part<M>].<ext>` (`.sql`, `.sh`, …) next to the plan when one line is not enough | its check passes, verified read-only by Claude once the user says done |
| Wait | Claude, read-only | the check in its table row | the named check passes: a soak, a metric, a backlog drained |

Command and wait units have no sidecar, and never a `.md` file named like one:
`fanout-run-step` would spawn a session for it. Write commands ready to paste, with paths
from the repo root or absolute, and the read-only check that proves them done.

The follow-through of a code unit's own change (its deploy, the apply of the stack it
edits, its migration) stays in that unit's done-when, with who runs each action. Anything
else that must happen between two units is a command or wait unit of its own.

## Shaping

Derive the shape from real dependencies, never from urgency or from the order the units
came to mind:

- A unit that needs another unit's exit condition goes in a later step.
- Units with no dependency between them are parts of the same step, whatever their kinds
  and whether or not they share files. Shared files only make the landing mechanical:
  name them.
- Every step boundary costs a wait, so each needs a nameable dependency: a unit of step
  N+1 that needs a named exit condition of step N.
- Urgency never creates a step boundary. Put the deadline in the unit's done-when and list
  the urgent part first.
- A pure chain with no groups is a valid outcome — say so.

Keep code parts comparable in size, and keep edits to the same file within one part.
Order parts by urgency, then by difficulty, so the user can start with the mechanical one.

Merging is rarely the exit condition. For a code unit, ask what the next step actually
needs: usually the change running in production (deployed, migrated, applied), which
comes after the merge. Whatever else must happen after one unit and before another — a
script run, a migration command, a soak — is a command or wait unit, never a footnote in
an MR description.

## Layout

Plans go in `tmp/` at the repo root. Sidecars and scripts are flat siblings of the plan,
never a subdirectory, and no README index:

```
tmp/<title>.md                 the plan
tmp/<title>_step1_part1.md     code part: sidecar
                               (step 1 part 2 is a one-line command: no file)
tmp/<title>_step2.sql          command step: script the user runs
tmp/<title>_step3.md           code step: sidecar
```

Numbering starts at 1, unpadded. Parts are numbered within their step across all kinds.

Each code unit's branch is `<prefix>_step<N>[_part<M>]`. `<prefix>` is the branch of the
session writing the plan (`git branch --show-current`), never one derived from the plan's
title, so every unit's branch and worktree is named after the one the plan came from. When
that branch is a poor prefix (`master`, a detached HEAD, a `claude/…` scratch name, a name
for unrelated work), propose a new prefix in the plan, for the user to accept along with
the plan.

## The plan file

Standard plan prose, plus:

- Where things stand: what already landed, evidence of what is left, linked prior plans or docs.
- The branch prefix (see Layout): the session's branch, or the proposed replacement and
  why the session's branch does not fit.
- A step table in order of execution, one row per unit: step, part, kind, who carries it
  out, artifact (sidecar link, script link, or the exact command), scope, done when, size,
  difficulty.
- Under the table, one launch line per step that has sidecars, as the script command so
  it runs without a Claude turn:
  `~/.claude/skills/fanout-run-step/spawn.sh tmp/<plan>.md --step 1 --model opus --effort medium --background`
  for step 1, and `git fetch origin && ~/.claude/skills/fanout-run-step/spawn.sh
  tmp/<plan>.md --step N -B origin/master --model opus --effort medium --background`
  for later steps, run only once step N−1 is done by its own exit condition.
  Always pass `--step`: the script's default skips steps that have no sidecar.
  Keep `--model opus --effort medium --background` unless the user asks for
  another model, effort, or a foreground launch. A launch line spawns only the step's
  code units: its command and wait units are carried out from their rows, and the step
  is done only when every unit meets its done-when. A step without sidecars has no
  launch line.
- One line per step boundary naming the dependency that forces it.
- The shared files each group touches.
- Out of scope, with reasons, including near-misses.
- Acceptance: the commands proving a unit is done and the measurement to record in its MR.

## Each sidecar

Code units only. `/fanout-run-step` parses the filename, the `Branch:` line, and the
`## Prompt` heading, so keep this header exact:

```markdown
# Step 2 — Part 1 — <what it covers>

Branch: `<prefix>_step2_part1`

---

## Prompt

<paste target>
```

A single-unit step uses `# Step 3 — <what it covers>` and branch `<prefix>_step3`, with
`<prefix>` the plan's branch prefix.

The prompt must stand alone. Cover:

- The task, the absolute path to the plan (`tmp/` is not in other worktrees), and
  repo-relative paths to background docs.
- Its place in the sequence: for step N > 1, the step it waits on, that step's exit
  condition, and to branch from `master` only once it holds; for a part, its siblings
  (command parts included: what the user runs alongside it) and the shared files.
- Its own exit condition: what must be true beyond the MR merging (deployed, migrated,
  verified) before the next step may start, and who does each of those.
- A worked example to copy: a commit sha when one is known, otherwise the `git log`
  command that finds it.
- The work list as precisely as the session knows it, plus the command that re-derives
  it. The sidecar session confirms paths and line numbers.
- The shared-file edits, which are the easiest to forget.
- Hazards found during analysis, and the fallback if one becomes a fight (usually drop
  the item and note it).
- Verify commands, acceptance measurement, and the one test that catches this pattern's
  classic mistake.
- Repo conventions a fresh session will not infer.
- Commit split and required MR content; open the MR with the `commit-and-open-mr` skill.

Hand over judgment calls that depend on measurement, with the command and criterion,
rather than pre-deciding them. When a unit's value is uncertain, measure first and state
a stop condition as an acceptable outcome.

## Finishing

Check the shape first, with or without sidecars:

- For each boundary N → N+1, name the unit of step N+1 and the exit condition of step N
  it needs. If you cannot, or if the plan says "any order", "blocks nothing" or "in
  parallel" about units in different steps, merge the two steps.
- Every row has every column of the step table, one kind, and a done-when check that can
  be run.
- Every command unit has a command ready to paste or a script file, and no `.md` file.

Then check that sidecar and script links resolve, and reread one sidecar as a stranger.
Report the file list, the step table, the branch prefix (say so when it is a proposed
replacement), the per-step launch lines, and the commands the user runs. Each launch line
starts one worktree and session per sidecar of that step, once the user has reviewed it.
