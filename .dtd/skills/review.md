# Skill: review

> Loaded into worker prompt when task `<capability>` is `review`.

You are reviewing code or artifacts in this turn. You are NOT writing
production code — your output is a structured review note.

## Output target

Write your review to a file path provided in the task (e.g.
`docs/review-001.md`). Use the `===FILE:===` block:

```
===FILE: docs/review-001.md===
```

If no path is provided, default to `.dtd/log/exec-{run_id}-task-{task_id}.review.md`.

## Review structure

Use this skeleton:

```markdown
# Review — <subject>

**Reviewed**: <files / commits / paths>
**Reviewer**: <your model-id>
**Target grade**: <NORMAL | GOOD | GREAT | BEST>
**Verdict**: <NORMAL | GOOD | GREAT | BEST>
**Pass / Retry / Block**: <recommendation>

## Findings

### P1 (must fix before pass)
- <finding 1 with file:line if applicable>
- <finding 2>

### P2 (should fix, not blocking)
- <finding>

### P3 (optional / nits)
- <finding>

## What's good

- <2-4 bullets — what was done well; supports "GREAT" claims>

## Verdict rationale

<2-4 sentences explaining why the verdict matches the target grade.
Be specific about what would move it up or down a tier.>
```

## Grade meanings (consistent with DTD spec)

- **NORMAL** — requirements satisfied, but meaningful debt remains
- **GOOD** — usable, major tests/checks pass, low known risk
- **GREAT** — clean, edge cases considered, maintainable
- **BEST** — ship candidate; further iteration has low marginal value

## Rules

- Be concrete. Cite file paths and line numbers if available.
- Severity: P1 blocks pass, P2/P3 do not. Don't inflate severity.
- Don't rewrite the code. Identify and recommend; controller / next iteration fixes.
- Don't grade as `BEST` lightly — `BEST` claims trigger a separate eval file. Only mark `BEST` if you've actually checked edge cases.
- Don't mark grade above target unless you have specific evidence.

## Done

After writing the review file, output the summary line:

```
::done:: review verdict=<grade> recommend=<pass|retry|block>
```

Or if you cannot review (insufficient info):

```
::blocked:: cannot review — <reason ≤ 80 chars>
```
