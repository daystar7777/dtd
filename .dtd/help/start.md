# DTD help: start

## Summary

First-run flow. Goes from a fresh install to a completed run in 5-7
commands. Use `/dtd help workers` if worker setup is unclear, or
`/dtd help stuck` if you hit a blocker.

## Quick examples

```text
/dtd workers add                 register your first worker LLM
/dtd workers test <id>           basic connectivity probe
/dtd mode on                     enable DTD mode
/dtd plan "<your goal>"          generate a phased plan (DRAFT)
/dtd approve                     lock the plan
/dtd run                         execute
```

## Canonical commands

- `/dtd workers add` — interactive wizard.
- `/dtd workers test <id>` — basic probe (env + endpoint + auth + model).
- `/dtd mode on` — controller starts loading `.dtd/instructions.md`.
- `/dtd plan "<goal>"` — controller produces DRAFT plan with worker assignments.
- `/dtd approve` — DRAFT → APPROVED.
- `/dtd run` — APPROVED → RUNNING; dispatches per phase.

## State / config fields

- `state.md.mode: dtd` — required for run loop.
- `state.md.host_mode: assisted|full` — required for actual file writes.
- `config.md.context-budget.default_failure_threshold: 3` — retry count.

## Doctor checks

- `state.md.mode: dtd` matches install state.
- At least one enabled worker in `workers.md`.
- `PROJECT.md` not pure-TODO.

## Next topics

- `/dtd help workers` — worker registry detail.
- `/dtd help run` — running + bounded execution.
- `/dtd help stuck` — when something blocks.
