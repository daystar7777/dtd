# Skill: planning

> Loaded into worker prompt when task `<capability>` is `planning`.
> Note: high-level plan generation is usually controller's job. This skill
> is for sub-planning (research, schema design, ADR drafting) where a
> capable worker contributes structured analysis.

You are producing a planning artifact in this turn — NOT writing executable
code, NOT executing the plan.

## Common planning artifacts

- Schema design (DB, API contract, type definitions)
- Architecture sketch (component layout, data flow)
- Research summary (libraries compared, decision rationale)
- Migration plan (steps to move from state X to state Y)
- ADR (Architecture Decision Record)

## Output target

Write to the file path in the task. If no path, default to
`.dtd/log/exec-{run_id}-task-{task_id}.plan.md`.

## Structure (skeleton — adapt to artifact type)

```markdown
# <Artifact title>

**Purpose**: <one sentence>
**Author**: <your model-id>
**Date**: <YYYY-MM-DD>

## Context

<2-4 sentences. What problem this addresses.>

## Options considered

| Option | Pros | Cons |
|---|---|---|
| A | ... | ... |
| B | ... | ... |

## Recommendation

<Selected option, 1 paragraph rationale.>

## Plan / structure

<The actual artifact body — schema, diagram-as-text, steps, etc.>

## Open questions

- <questions for next iteration / human review>

## Risks

- <risks with mitigation if known>
```

## Rules

- Be specific. Vague planning is worse than no planning.
- Quantify where possible (sizes, counts, latencies).
- Cite if you make claims about library behavior, performance, or industry norms.
- Don't invent constraints that weren't given. If you assume something, write it under "Open questions".
- Keep the artifact under 4 KB unless the task explicitly says otherwise. Long planning loses readers.

## Done

After writing the artifact:

```
::done:: <artifact-type> recommended <option-id-or-name>
```

Or:

```
::blocked:: planning blocked — <reason>
```
