# DTD Help Topics

> One-line description per topic. Drill into any topic with
> `/dtd help <topic>`. v0.2.0d topic system.

| Topic | Covers |
|---|---|
| `start` | first-run flow: workers add → test → mode on → plan → approve → run |
| `observe` | read-only commands: status, plan show, doctor, workers list |
| `recover` | when stuck: incident list/show/resolve, pause, stop |
| `workers` | worker registry + basic test |
| `stuck` | incident-specific recovery + decision capsule options |
| `update` | self-update flow: check / --dry-run / apply / rollback |
| `plan` | planning commands: plan, plan show, plan worker |
| `run` | running + bounded execution: run, run --until, pause, resume |
| `steer` | steering / patches mid-run |

R2 gate: `/dtd r2 readiness` (full ref: `v030-r2-0-readiness-checklist`).

Default `/dtd help` shows the lifecycle overview (≤ 25 lines).
Topic help is ≤ 50 lines unless `--full` is specified.
