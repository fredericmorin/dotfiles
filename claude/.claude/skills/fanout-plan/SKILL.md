---
name: fanout-plan
description: Use when writing a fan-out plan: the work splits into several independently-shippable units — sequential steps, each either one unit or a group of parts that can be worked in parallel — writes the plan plus one sidecar prompt file per unit, each ready to paste into a separate Claude session on its own branch
---

# Fan-out plans with sidecar session prompts

Write the plan to `tmp/` at the repo root. When the work splits into three or more
units that each merit their own branch and MR, also write one sidecar per unit: a
self-contained prompt for a fresh Claude session with zero conversational context. Below
that threshold, write one plan with ordered phases and no sidecars. When the gate passes,
the sidecars are part of the deliverable.

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

Plans go in `tmp/` at the repo root. Sidecars are flat siblings of the plan, never a
subdirectory, and no README index:

```
tmp/<title>.md
tmp/<title>_step1.md
tmp/<title>_step2_part1.md
tmp/<title>_step2_part2.md
```

Numbering starts at 1, unpadded.

## The plan file

Standard plan prose, plus:

- Where things stand: what already landed, evidence of what is left, linked prior plans or docs.
- A step table in landing order: step, part, sidecar link, scope, size, difficulty.
- Under the table, one launch line per step, as the script command so it runs without a
  Claude turn: `~/.claude/skills/fanout-run-step/spawn.sh tmp/<plan>.md --step 1`
  for step 1, and `git fetch origin && ~/.claude/skills/fanout-run-step/spawn.sh
  tmp/<plan>.md --step N -B origin/master` for later steps, run only after step
  N−1's MRs merge.
- One line per step boundary naming the dependency that forces it.
- The shared files each group touches.
- Out of scope, with reasons, including near-misses.
- Acceptance: the commands proving a unit is done and the measurement to record in its MR.

## Each sidecar

`/fanout-run-step` parses the filename, the `Branch:` line, and the `## Prompt` heading, so
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

- The task, the absolute path to the plan (`tmp/` is not in other worktrees), and
  repo-relative paths to background docs.
- Its place in the sequence: for step N > 1, what it waits on and to branch from `master`
  only after that MR merges; for a part, its siblings and the shared files.
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

Check sidecar links resolve and reread one sidecar as a stranger.
Report the file list, the step table, and the per-step launch lines. Each one starts one
worktree and session per sidecar of that step, once the user has reviewed it.
