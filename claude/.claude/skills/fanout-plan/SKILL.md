---
name: fanout-plan
description: Use when writing a plan or spec to a docs/specs file, and the work splits into several independently-shippable units that could be worked in parallel — writes the plan plus one sidecar prompt file per unit, each ready to paste into a separate Claude session on its own branch
---

# Fan-out plans with sidecar session prompts

## Overview

Write the plan to the repo's spec directory. **If** the work splits into several units
that can be worked in parallel, also write one sidecar file per unit next to the plan,
each holding a self-contained prompt ready to paste into a fresh Claude session on its own
branch.

The user drives the sessions themselves, one unit at a time or several at once, or fans
them all out with `/fanout-spawn <plan>`, which starts one Supacode worktree and Claude
session per sidecar. The sidecars are the handoff, so they must survive having zero
conversational context.

## The fan-out gate

Split only when **both** hold:

1. **Enough work** — more than a few phases, steps, or items. Rule of thumb: three or more
   units that each make sense as their own branch and MR.
2. **Genuinely parallelizable** — the units can be worked simultaneously without waiting
   on each other. Small mechanical conflicts in a handful of shared files are fine and
   expected; a unit that cannot start until another lands is not parallel.

If the second condition fails, **write one plan file with ordered phases and no sidecars.**
Sequential work split across sessions produces sessions that block on each other and
merge in the wrong order. Say plainly that the work is sequential rather than fanning it
out anyway.

Ask the gate question explicitly before writing anything. Judge it from the actual
dependency structure, not from how many bullet points the work has.

### Finding the unit boundaries

A unit is independent when its edits are confined to files no other unit needs to touch,
**except** for a small named set of shared files (a registry, an aggregate root, an index).
Group by "what has to land together", then:

- **Name the shared files in the plan.** Every session will conflict on them; say which
  ones so each expects a rebase-resolve rather than being surprised.
- **Keep units comparable in size** where you can. One unit holding half the work defeats
  the point.
- **Group by coherence, not just by count.** Items that touch the same file belong in the
  same unit even if that makes it bigger — otherwise two sessions edit that file twice.
- **Order units by difficulty** and say which is the mechanical one. That is where the user
  starts, and it validates the pattern before the hard units run.

## Naming and layout

**Discover the repo's convention — do not assume.** Check `CLAUDE.md`, the existing files
in the spec directory, and any lint script that guards it (`grep -rl "docs/specs" ci/ bin/`
or similar). A repo may enforce the filename with a regex and reject anything else.

**Sidecars are flat siblings of the plan, never a subdirectory.** A spec-directory lint
that requires every entry to be a file will fail on a subdirectory, and that failure only
shows up in CI. Give the sidecars the plan's filename as a prefix so they sort directly
under it:

```
docs/specs/2026-08-07_<title>.md
docs/specs/2026-08-07_<title>_group_1_<slug>.md
docs/specs/2026-08-07_<title>_group_2_<slug>.md
```

Skip a `README.md` index in the spec directory — it will not match the required filename
pattern, and the plan file is already the index.

Run the repo's docs lint locally before committing.

## The plan file

Standard spec prose, plus:

- **Where things stand.** What already landed, and the measurement or evidence that says
  what is left. Link the specs this follows.
- **A unit table** — one row per unit, with a markdown link to its sidecar, what it covers,
  its size, and its difficulty or shape. Say up front: one branch and one MR each,
  independent, runnable in any order.
- **The shared files** every unit touches, so rebase conflicts are expected.
- **Out of scope**, with reasons. Anything you considered and rejected goes here, so the
  next person does not re-derive it. This is also where near-miss items live — the ones
  that almost qualified and why they did not.
- **Acceptance** — the command(s) that prove a unit is done, and the number or output to
  record in its MR.

## Each sidecar prompt

The reader is a fresh session with no context. No "as we discussed", no pronouns pointing
at this conversation, no assumed knowledge of the analysis.

Open with the branch name and a `## Prompt` heading, so what to paste is unambiguous:

```markdown
# Group 3 — <what it covers>

Branch: `<prefix>_group3`

---

## Prompt

<everything below is the paste target>
```

Include, in roughly this order:

1. **The task in one or two sentences**, then pointers to the plan and background specs to
   read. Name them by repo-relative path.
2. **A worked example to copy** — a commit sha that did the same thing (`git show <sha>`)
   is worth more than any amount of description. If a prior unit of the same wave landed,
   that is the example.
3. **The exact work list.** A table of items with file paths, symbol names, and line
   numbers — plus the instruction to **confirm the line numbers rather than trust them**,
   since they drift after the branch point.
4. **The command that re-derives the list.** The grep or query you used to build the table.
   Analysis goes stale; give the reader the means to check it and to notice an item that
   gained a consumer and must be dropped.
5. **A code template** for the thing being created, filled in with one real example from
   this unit.
6. **The shared-file steps** — registering in the index, deleting from the aggregate root,
   whatever the pattern requires. These are the steps most easily forgotten because they
   are not in the unit's own directory.
7. **Hazards specific to this unit**, spelled out concretely: the build-system constraint,
   the resolve mismatch, the visibility rule, the test helper that must be swapped. If you
   found it during analysis, write it down — the session will otherwise rediscover it the
   hard way. Say what to do if a hazard turns into a real fight (usually: drop that item,
   keep the rest, note it).
8. **Verify commands** — format/lint, typecheck, the specific test targets, and the
   measurement from the plan's acceptance section. Call out *the one test that catches the
   classic mistake* for this pattern and what its failure means.
9. **Repo conventions** — style rules that a fresh session will not infer, and the ones in
   `CLAUDE.md` worth repeating (comment policy, import ordering, line length).
10. **Commit and MR guidance** — how to split commits, and what the MR description must state
    (the judgment calls taken, the acceptance measurement). Tell the session to open the MR
    with the `commit-and-open-mr` skill rather than driving `git` and `glab` by hand, so every
    group's MR lands with the same shape.

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
- Grep for links to paths you moved or renamed — a plan whose unit links 404 is worse than
  no links.
- Re-read one sidecar as if you knew nothing about the task. Anything that only makes sense
  from this conversation is a defect.
- Report the file list and the unit table to the user. They are choosing where to start.
- Tell the user that once they have reviewed the plan, `/fanout-spawn <plan>` (or "go, spawn
  them") creates one Supacode worktree per sidecar and starts a Claude session in each with
  that sidecar's prompt. That skill relies on the `Branch:` line and the `## Prompt` heading,
  so keep both exactly as specified above.

## Common mistakes

- **Fanning out sequential work.** The gate has two conditions and the second is the one
  that gets skipped.
- **Sidecars in a subdirectory.** Fails spec-directory lints, and only in CI.
- **A sidecar that reads like notes rather than a prompt.** If it does not stand alone, it
  is not a handoff.
- **Line numbers presented as fact.** Always paired with "confirm these".
- **A work list with no way to re-derive it.** It is stale the moment the plan lands.
- **Hazards discovered during analysis but not written down.** The most valuable content in
  a sidecar is the thing that would otherwise cost the session an hour.
- **Omitting the shared-file steps** because they live outside the unit's directory.
- **Units of wildly uneven size**, so one session does most of the work.
- **No acceptance measurement**, so nobody can tell whether a unit achieved its purpose.
- **Writing the plan and stopping.** If the gate passes, the sidecars are part of the
  deliverable, not a follow-up.
