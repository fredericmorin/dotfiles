---
name: fanout-plan
description: Use when writing a plan or spec to a docs/specs file, and the work splits into several independently-shippable units — sequential steps, each either one unit or a group of parts that can be worked in parallel — writes the plan plus one sidecar prompt file per unit, each ready to paste into a separate Claude session on its own branch
---

# Fan-out plans with sidecar session prompts

## Overview

Write the plan to the repo's spec directory. **If** the work splits into several units,
also write one sidecar file per unit next to the plan, each holding a self-contained
prompt ready to paste into a fresh Claude session on its own branch.

The user drives the sessions themselves, one unit at a time or a whole group at once, or
fans a step out with `/fanout-spawn <plan>`, which starts one Supacode worktree and Claude
session per sidecar of that step. The sidecars are the handoff, so they must survive
having zero conversational context.

## Vocabulary

Use these three words exactly, in the plan, the sidecars, the filenames, and the branches:

- **Step** — a unit of work that must land **before** the next step starts. Steps are
  sequential: step 2 is written against the tree as it stands once step 1 has merged.
  Use a step whenever parallel work is not possible, or the landing order matters to
  some degree (a migration before the code that uses it, a registry before the entries,
  a refactor before the callers).
- **Group** — the set of parts inside one step that can be worked **in parallel** with low
  friction. Low friction means the only conflicts are small and mechanical: import
  ordering, adjacent lines in a registry, a shared index file. A group is a property of a
  step, not a file of its own.
- **Part** — one member of a group. One branch, one MR, one session. Parts of the same
  step can land in any order.

A step with a single unit of work has no parts: its sidecar is the step itself. A step
whose work splits into parallel units has one sidecar per part.

## The fan-out gate

Split into sidecars only when there is **enough work** — more than a few phases or items.
Rule of thumb: three or more units that each make sense as their own branch and MR. Below
that, write one plan file with ordered phases and no sidecars.

Then decide the shape from the actual dependency structure, not from how many bullet points
the work has:

1. **Anything that cannot start until something else lands goes in a later step.** Never
   put two units that block on each other in the same group — the sessions block on each
   other and merge in the wrong order.
2. **Anything that can run alongside its neighbours with only mechanical conflicts becomes
   a part of the same step.** Do not serialize work into steps just to be safe: every step
   boundary is a wait for a merge, and a plan that is all single-unit steps has no
   parallelism left.
3. **Say plainly which it is.** If the whole thing is one chain of steps with no groups,
   say so — that is a legitimate outcome, and the user should know no fan-out is coming.

### Finding the part boundaries inside a step

A part is independent when its edits are confined to files no other part of the step needs
to touch, **except** for a small named set of shared files (a registry, an aggregate root,
an index). Group by "what has to land together", then:

- **Name the shared files in the plan.** Every session of the group will conflict on them;
  say which ones so each expects a rebase-resolve rather than being surprised.
- **Keep parts comparable in size** where you can. One part holding half the step defeats
  the point.
- **Group by coherence, not just by count.** Items that touch the same file belong in the
  same part even if that makes it bigger — otherwise two sessions edit that file twice.
- **Order parts by difficulty** and say which is the mechanical one. That is where the
  user starts, and it validates the pattern before the hard parts run.

## Naming and layout

**Discover the repo's convention — do not assume.** Check `CLAUDE.md`, the existing files
in the spec directory, and any lint script that guards it (`grep -rl "docs/specs" ci/ bin/`
or similar). A repo may enforce the filename with a regex and reject anything else.

**Sidecars are flat siblings of the plan, never a subdirectory.** A spec-directory lint
that requires every entry to be a file will fail on a subdirectory, and that failure only
shows up in CI. Give the sidecars the plan's filename as a prefix, then `_step<N>` and,
for a part of a group, `_part<M>`, so they sort directly under the plan in landing order:

```
docs/specs/2026-08-07_<title>.md
docs/specs/2026-08-07_<title>_step1.md
docs/specs/2026-08-07_<title>_step2_part1.md
docs/specs/2026-08-07_<title>_step2_part2.md
docs/specs/2026-08-07_<title>_step3.md
```

Step 1 above is a single unit; step 2 is a group of two parts; step 3 is a single unit
again. No slug in the filename — the title is the first line of the sidecar. Number steps
and parts from 1, without zero padding.

Skip a `README.md` index in the spec directory — it will not match the required filename
pattern, and the plan file is already the index.

Run the repo's docs lint locally before committing.

## The plan file

Standard spec prose, plus:

- **Where things stand.** What already landed, and the measurement or evidence that says
  what is left. Link the specs this follows.
- **A step table** — one row per sidecar, in landing order, with the step number, the part
  number if any, a markdown link to the sidecar, what it covers, its size, and its
  difficulty or shape. Say up front: one branch and one MR each; steps land in order; parts
  of the same step are independent and land in any order.
- **Why each step boundary exists** — one line per boundary naming the dependency that
  forces it. If you cannot name one, the boundary should not be there.
- **The shared files** the parts of each group touch, so rebase conflicts are expected.
- **Out of scope**, with reasons. Anything you considered and rejected goes here, so the
  next person does not re-derive it. This is also where near-miss items live — the ones
  that almost qualified and why they did not.
- **Acceptance** — the command(s) that prove a unit is done, and the number or output to
  record in its MR.

## Each sidecar prompt

The reader is a fresh session with no context. No "as we discussed", no pronouns pointing
at this conversation, no assumed knowledge of the analysis.

Open with the branch name and a `## Prompt` heading, so what to paste is unambiguous. The
branch carries the same `_step<N>` / `_part<M>` suffix as the file:

```markdown
# Step 2 — Part 1 — <what it covers>

Branch: `<prefix>_step2_part1`

---

## Prompt

<everything below is the paste target>
```

For a single-unit step, the heading is `# Step 3 — <what it covers>` and the branch
`<prefix>_step3`.

Include, in roughly this order:

1. **The task in one or two sentences**, then pointers to the plan and background specs to
   read. Name them by repo-relative path.
2. **Where this sits in the sequence.** For step N > 1: which step it depends on, what that
   step landed, and the instruction to branch from `master` only after that step's MR has
   merged. For a part: the sibling parts running alongside it and the shared files they
   will all touch.
3. **A worked example to copy** — a commit sha that did the same thing (`git show <sha>`)
   is worth more than any amount of description. If a prior step or a sibling part of the
   same pattern landed, that is the example.
4. **The exact work list.** A table of items with file paths, symbol names, and line
   numbers — plus the instruction to **confirm the line numbers rather than trust them**,
   since they drift after the branch point.
5. **The command that re-derives the list.** The grep or query you used to build the table.
   Analysis goes stale; give the reader the means to check it and to notice an item that
   gained a consumer and must be dropped.
6. **A code template** for the thing being created, filled in with one real example from
   this unit.
7. **The shared-file steps** — registering in the index, deleting from the aggregate root,
   whatever the pattern requires. These are the edits most easily forgotten because they
   are not in the unit's own directory.
8. **Hazards specific to this unit**, spelled out concretely: the build-system constraint,
   the resolve mismatch, the visibility rule, the test helper that must be swapped. If you
   found it during analysis, write it down — the session will otherwise rediscover it the
   hard way. Say what to do if a hazard turns into a real fight (usually: drop that item,
   keep the rest, note it).
9. **Verify commands** — format/lint, typecheck, the specific test targets, and the
   measurement from the plan's acceptance section. Call out *the one test that catches the
   classic mistake* for this pattern and what its failure means.
10. **Repo conventions** — style rules that a fresh session will not infer, and the ones in
    `CLAUDE.md` worth repeating (comment policy, import ordering, line length).
11. **Commit and MR guidance** — how to split commits, and what the MR description must state
    (the judgment calls taken, the acceptance measurement). Tell the session to open the MR
    with the `commit-and-open-mr` skill rather than driving `git` and `glab` by hand, so every
    unit's MR lands with the same shape.

### Two things that make sidecars much better

**Do not pre-decide judgment calls.** Where the right answer depends on something
measurable, say so, give the command that measures it, and give the criterion. Deciding it
yourself from less information than the session will have is worse than handing over the
decision with the means to make it.

**Let a unit legitimately produce nothing.** If a unit's value is uncertain, make the
measurement step 1 and give an explicit stop condition, stated as an acceptable outcome.
Otherwise a session will grind out a change that should not land, because the prompt
implied a change was expected.

## Before finishing

- Run the repo's docs lint.
- Grep for links to paths you moved or renamed — a plan whose sidecar links 404 is worse
  than no links.
- Re-read one sidecar as if you knew nothing about the task. Anything that only makes sense
  from this conversation is a defect.
- Report the file list and the step table to the user. They are choosing where to start.
- Tell the user that once they have reviewed the plan, `/fanout-spawn <plan>` (or "go, spawn
  them") creates one Supacode worktree per sidecar of the current step and starts a Claude
  session in each with that sidecar's prompt; later steps are spawned the same way once the
  previous step has merged. That skill relies on the `_step<N>[_part<M>]` filenames, the
  `Branch:` line, and the `## Prompt` heading, so keep all three exactly as specified above.

## Common mistakes

- **Putting dependent units in the same group.** Sessions block on each other and merge in
  the wrong order. If one cannot start until another lands, it is the next step.
- **Serializing parallel work into steps.** Each step boundary is a wait for a merge; a
  boundary with no nameable dependency is wasted wall-clock.
- **Sidecars in a subdirectory.** Fails spec-directory lints, and only in CI.
- **A sidecar that reads like notes rather than a prompt.** If it does not stand alone, it
  is not a handoff.
- **A step N > 1 sidecar that does not say what it waits on.** The session branches from a
  tree that lacks the previous step and rediscovers the dependency the hard way.
- **Line numbers presented as fact.** Always paired with "confirm these".
- **A work list with no way to re-derive it.** It is stale the moment the plan lands.
- **Hazards discovered during analysis but not written down.** The most valuable content in
  a sidecar is the thing that would otherwise cost the session an hour.
- **Omitting the shared-file steps** because they live outside the unit's directory.
- **Parts of wildly uneven size**, so one session does most of the step.
- **No acceptance measurement**, so nobody can tell whether a unit achieved its purpose.
- **Writing the plan and stopping.** If the gate passes, the sidecars are part of the
  deliverable, not a follow-up.
