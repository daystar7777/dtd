# DTD help: observe

## Summary

Read-only commands that don't change run state. Use these to check
status, inspect plans, validate health, or list workers without
affecting the active run.

## Quick examples

```text
/dtd status                      polished dashboard (compact)
/dtd status --full               + history + steering + active patches
/dtd plan show                   active plan summary
/dtd doctor                      health check (ERROR / WARN / INFO)
/dtd workers list                registered workers + status
```

## Canonical commands

- `/dtd status [--compact|--full|--plan|--history|--eval]`
- `/dtd plan show [--task N|--phase N|--brief|--patches|--workers|--paths]`
- `/dtd doctor [--takeover]`
- `/dtd workers [list|test]`
- `/dtd incident list/show <id>` (v0.2.0a)
- `/dtd perf [--phase|--worker|--tokens|--cost]` (v0.2.0f)
- `/dtd consensus show <task_id|--active>` (v0.3.0c)
- `/dtd session-sync show` (v0.3.0d)
- `/dtd loop-guard show` / `rehash --dry-run` (v0.3.0a)
- `/dtd r2 readiness` (v0.3 R2 entry gate)

## Observational read isolation

These commands MUST NOT mutate run memory:
- No `notepad.md` append.
- No `steering.md` append.
- No `phase-history.md` append.
- No `attempts/run-NNN.md` append.
- No `state.md.last_update` change.

Status checks stay cheap and don't pollute notepad/handoff.

## Next topics

- `/dtd help stuck` — recovery from blockers.
- `/dtd help workers` — worker registry detail.
