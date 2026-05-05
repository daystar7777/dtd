# DTD help: run

## Summary

Run an approved DTD plan. Use bounded runs when you want DTD to stop at a
phase, task, or decision boundary for review.

## Quick examples

```text
/dtd run                         execute APPROVED plan
/dtd run --until phase:3         pause after phase 3
/dtd run --until task:2.1        pause after task 2.1
/dtd run --until before:review   pause before review phase
/dtd run --until next-decision   pause at next decision capsule
/dtd pause                       pause at next safe boundary
/dtd run                         resume from PAUSED
```

## Canonical commands

- `/dtd run [--until <boundary>]`
- `/dtd pause`: RUNNING to PAUSED. Non-terminal; no `finalize_run`.
- `/dtd resume`: alias for `/dtd run` from PAUSED.

## Boundaries

- `phase:<id>`: run until that phase passes, then pause.
- `task:<id>`: run until that task completes, then pause.
- `before:<phase-name>`: pause before entering the named phase.
- `next-decision`: pause when any decision capsule fires.

## State

- `DRAFT -> APPROVED -> RUNNING -> COMPLETED` is the happy path.
- `RUNNING -> PAUSED -> RUNNING` is resumable.
- `STOPPED` and `FAILED` are terminal and call `finalize_run`.
- Worker phase completion or retry starts a fresh worker context from the
  latest compact task brief, not from the prior worker transcript.

## Next topics

- `/dtd help observe`: status during a run.
- `/dtd help steer`: change direction mid-run.
- `/dtd help recover`: blockers and incidents.
