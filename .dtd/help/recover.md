# DTD help: recover

## Summary

When stuck. Incident commands let you inspect blockers and choose
recovery options. `pause` halts the run gracefully; `stop` is
destructive (terminates the active plan).

## Quick examples

```text
/dtd pause                          halt at next task boundary
/dtd incident list                  see what is blocking
/dtd incident show <id>             detailed failure + options
/dtd incident resolve <id> retry    choose a recovery option
/dtd stop                           force-end the active plan (destructive)
```

## Canonical commands

- `/dtd pause` — RUNNING → PAUSED on next task boundary. Non-terminal.
- `/dtd incident list [--all|--blocking|--recent]` — observational.
- `/dtd incident show <id>` — observational.
- `/dtd incident resolve <id> <option>` — mutating; closes capsule.
- `/dtd stop` — destructive; calls `finalize_run(STOPPED)`.

## Destructive options always confirm

These recovery options ALWAYS confirm regardless of intent confidence:
- `stop` (terminates run via `finalize_run(STOPPED)`)
- `purge`, `delete`, `force_overwrite`, `revert_partial`, `terminal_finalize`

NL phrases like `"그 에러 멈춰"` or `"incident X stop"` route to
`incident resolve <id> stop` and trigger the confirmation prompt.

## Decision capsule recovery options

When an incident is `blocked` severity, the decision capsule contains
recovery options like `[retry, switch_worker, manual_paste, stop]`.
Pick via `/dtd incident resolve <id> <option>`.

## Next topics

- `/dtd help stuck` — incident-specific recovery flow.
- `/dtd help observe` — status commands.
