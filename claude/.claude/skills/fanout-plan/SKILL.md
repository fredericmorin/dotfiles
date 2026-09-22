---
name: fanout-plan
description: Use when writing a plan or spec to a docs/specs file, and the work splits into several independently-shippable units — sequential steps, each either one unit or a group of parts that can be worked in parallel — writes the plan plus one sidecar prompt file per unit, each ready to paste into a separate Claude session on its own branch
---

# Fan-out plans with sidecar session prompts

Write the plan to the repo's spec directory. When the work splits into three or more
units that each merit their own branch and MR, also write one sidecar per unit: a
self-contained prompt for a fresh Claude session with zero conversational context. Below
that threshold, write one plan with ordered phases and no sidecars. When the gate passes,
the sidecars are part of the deliverable.

## Vocabulary

Use these terms consistently in the plan, sidecars, filenames, and branches:

- **Step** — must land before the next step starts. Sequential.
- **Group** — the parts of one step that can run in parallel, conflicting only on a small
  named set of shared files (registry, index, aggregate root).
- **Part** — one member of a group: one branch, one MR, one session. Lands in any order.

A single-unit step has no parts; its sidecar is the step itself.

## Shaping

Derive the shape from real dependencies. Anything that blocks on another unit goes in a
later step; anything that only conflicts mechanically is a part of the same step. Every
step boundary costs a merge wait, so each needs a nameable dependency. A pure chain with
no groups is a valid outcome — say so. Keep parts comparable in size, keep edits to the
same file within one part, and order parts by difficulty so the user can start with the
mechanical one.

## Layout

Follow the repo's spec filename convention (check `CLAUDE.md`, existing specs, and any
lint that guards the directory). Sidecars are flat siblings of the plan, never a
subdirectory, and no README index:

```
docs/specs/2026-08-07_<title>.md
docs/specs/2026-08-07_<title>_step1.md
docs/specs/2026-08-07_<title>_step2_part1.md
docs/specs/2026-08-07_<title>_step2_part2.md
```

Numbering starts at 1, unpadded.

## The plan file

Standard spec prose, plus:

- Where things stand: what already landed, evidence of what is left, linked prior specs.
- A step table in landing order: step, part, sidecar link, scope, size, difficulty.
- One line per step boundary naming the dependency that forces it.
- The shared files each group touches.
- Out of scope, with reasons, including near-misses.
- Acceptance: the commands proving a unit is done and the measurement to record in its MR.

## Each sidecar

`/fanout-spawn` parses the filename, the `Branch:` line, and the `## Prompt` heading, so
keep this header exact:

```markdown
# Step 2 — Part 1 — <what it covers>

Branch: `<prefix>_step2_part1`

---

## Prompt

<paste target>
```

A single-unit step uses `# Step 3 — <what it covers>` and branch `<prefix>_step3`.

The prompt must stand alone. Cover:

- The task, and repo-relative paths to the plan and background specs.
- Its place in the sequence: for step N > 1, what it waits on and to branch from `master`
  only after that MR merges; for a part, its siblings and the shared files.
- A worked example to copy, ideally a commit sha.
- The exact work list (paths, symbols, line numbers flagged as "confirm, they drift") and
  the command that re-derives it.
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

Run the docs lint, check sidecar links resolve, and reread one sidecar as a stranger.
Report the file list and step table, and tell the user `/fanout-spawn <plan>` launches
one worktree and session per sidecar of the current step once they have reviewed it.
