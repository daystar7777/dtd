# DTD Run Notepad

> Compact wisdom capsule for the active run. Updated by the controller at every
> phase boundary. Workers receive ONLY the `<handoff>` section as part of their
> prompt prefix — not the full notepad.
>
> Replaces "send entire phase log to next worker" (token-expensive) with a
> curated summary that survives session boundaries.
>
> One file per project (active run). On `plan_status: COMPLETED` (or
> `STOPPED`/`FAILED`), the controller **deterministically**:
>   1. archives this file to `.dtd/runs/run-NNN-notepad.md`
>   2. resets this file to template state for the next run
>
> See dtd.md §Per-Run Notepad for full lifecycle.

## Format

Five sections, all append-mostly. Controller prunes/compacts older entries when
the file grows past ~4 KB.

### learnings

Conventions and patterns the controller (or workers) discovered about THIS
project. Things a fresh session would otherwise have to rediscover.

(empty — populates as run progresses)

### decisions

Choices made during the run with one-line rationale. Future workers reference
these to avoid re-deciding settled questions.

(empty)

### issues

Known blockers, gotchas, weird behaviors. Each entry: what / where / status.

(empty)

### verification

Commands and results that confirmed something works (or doesn't). Useful for
"how did we test this last phase?" without re-running.

(empty)

### handoff

**This is the section workers receive in their prompt.** Keep it compact (≤ 1 KB).

Current state of the run for the next worker:

- where we are (phase / task)
- what was just completed
- what's the next worker's job
- any constraints or recent decisions that affect this task

(empty — controller fills before each worker dispatch)

---

Last update: never (template state)
