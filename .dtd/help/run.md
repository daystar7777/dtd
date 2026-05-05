# DTD help: run

## Summary

Run loop commands. `run` executes; bounded execution via `--until`;
`pause` is non-terminal; `resume` is `run` from PAUSED. v0.2.0f adds
silent + decision-mode flags for sleep-friendly autonomy.

## Quick examples

```text
/dtd run                              execute APPROVED plan
/dtd run --until phase:3              run until end of phase 3, then pause
/dtd run --until task:2.1             run until task 2.1 completes
/dtd run --until before:review        run until before review phase
/dtd run --until next-decision        run until any decision capsule fires
/dtd run --silent=4h                  silent autonomy for 4h (v0.2.0f)
/dtd run --decision auto              max safe forward progress (v0.2.0f)
/dtd pause                            halt at next task boundary
/dtd run                              resume from PAUSED
```

## Canonical commands

- `/dtd run [--until <boundary>] [--decision <mode>] [--silent[=<duration>] | --interactive]`
- `/dtd pause` — RUNNING → PAUSED. Non-terminal; finalize_run NOT called.
- `/dtd resume` — alias for `/dtd run` from PAUSED.

## --until boundaries

| Form | Meaning |
|---|---|
| `phase:<id>` | run until end of phase |
| `task:<id>` | run until task completes |
| `before:<phase-name>` | pause before phase named `<phase-name>` |
| `next-decision` | pause when any decision capsule fires |

## v0.2.0f autonomy flags

- `--silent=<duration>` — defer non-urgent blockers; max 8h default.
  Never auto-runs destructive / paid / external-path / partial-apply.
- `--decision plan|permission|auto` — how often to ask:
  - `plan`: ask at plan/phase boundaries
  - `permission`: default; ask for permission/destructive
  - `auto`: max forward progress (still confirms destructive)
- `--interactive` — explicit interactive mode (default).

## State machine

```
DRAFT ──/dtd approve──> APPROVED ──/dtd run──> RUNNING
RUNNING ──/dtd pause──> PAUSED
PAUSED ──/dtd run──> RUNNING
RUNNING ──(all phases pass)──> COMPLETED (terminal)
RUNNING ──/dtd stop──> STOPPED (terminal)
RUNNING ──(all workers dead)──> FAILED (terminal)
```

## NL phrases

- `"실행해"` / `"돌려"` / `"시작"` → `/dtd run`
- `"3페이즈까지만"` → `/dtd run --until phase:3`
- `"잠깐 멈춰"` → `/dtd pause`
- `"4시간 조용히 자동으로"` → `/dtd run --silent=4h --decision auto` (v0.2.0f)

## Next topics

- `/dtd help observe` — status during run.
- `/dtd help steer` — change direction mid-run.
- `/dtd help recover` — when blocked.
