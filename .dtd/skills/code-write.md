# Skill: code-write

> Loaded by controller into worker prompt when task `<capability>` is `code-write` or `code-refactor`.
> Inserted after `worker-system.md` and `PROJECT.md`, before task-specific section.
> Cache-friendly position (provider prompt cache).

You are writing production code in this turn.

## Output requirements

- Output **complete, runnable code** for each file in the task. No stubs, no `// TODO: implement` placeholders unless the task explicitly says so.
- Match the existing code style of the project (indentation, quote style, import order). If `<context-files>` shows examples, mirror them.
- Do not introduce new top-level dependencies (npm packages, pip packages, etc.) unless the task explicitly authorizes them.
- Do not delete existing public APIs. If a refactor changes behavior, add a deprecation comment and keep the old signature working.

## Per-file output

Each file goes in its own `===FILE: <path>===` block (per `worker-system.md`). For new files, include the full content. For modified files:

- If the change is small (< 30% of the file), output the **full updated file** anyway — DTD's controller does not reliably parse partial diffs.
- If the change is large, output the **full updated file**.

In both cases: full file content, not a diff.

## Formatting

- Final newline at end of each file.
- Encoding: UTF-8.
- Line endings: match the project's existing convention (LF for cross-platform projects, CRLF only if windows-only).

## Tests

- If the project has a tests directory and the task adds new functionality, also add at least one test file demonstrating the new behavior. Output it in its own `===FILE:===` block.
- Do not modify existing test files unless the task asks for that.

## Imports

- Group imports per the project's existing convention.
- No unused imports.
- Prefer explicit named imports over wildcard imports unless the project uses wildcards.

## Error handling

- For functions that can fail, decide between throwing and returning a result type, matching the project's existing pattern.
- Do not add try/catch around code that cannot fail.
- Do not swallow errors silently. Either propagate, log, or transform.

## Comments

- Default to no comments. Names should explain the code.
- Add a comment ONLY when the WHY is non-obvious (constraint, invariant, workaround for a known bug). Never explain WHAT.
- Do not include comments that reference the task ("added for issue #42", "TODO from sprint planning"). Those belong in commit messages, not code.

## Done

When complete, output the summary line per `worker-system.md`:

```
::done:: <one-line summary, ≤ 80 chars>
```

If you cannot complete (missing dependency, ambiguous spec):

```
::blocked:: <reason, ≤ 80 chars>
```

Do not guess and ship broken code. The controller will route a `::blocked::` to escalation.
