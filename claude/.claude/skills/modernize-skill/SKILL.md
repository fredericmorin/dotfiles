---
name: modernize-skill
description: Refactor an existing Claude skill for current-generation models — strip hand-holding and legacy guardrails, keep intent, boundaries, and output formats, and cut its length by at least half. Use when asked to modernize, slim down, trim, or refactor a skill; also for "/modernize-skill <name>".
argument-hint: "<skill-name or path to SKILL.md>"
disable-model-invocation: true
---

# Modernize a skill

Resolve the argument to a skill directory (`~/.claude/skills/<name>/`, a
project `.claude/skills/<name>/`, or a given path). Read its SKILL.md and any
supporting files it references, then rewrite SKILL.md in place:

- Remove step-by-step hand-holding, micromanagement, and defensive guardrails
  that only existed to correct weaker models.
- Keep the high-level goal, core intent, essential boundaries, and required
  output formats.
- Make the body at least 50% shorter. Prefer short declarative statements to
  long explanations.
- Where the logic is deterministic or has many steps, point to the script or
  file that already holds it (e.g. its `--help`) instead of writing it out.
- Leave the frontmatter alone unless it's wrong. Don't change supporting
  scripts.

Report what was removed and what was kept, with the before/after length.
