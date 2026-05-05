# DTD reference: run-loop

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §`/dtd run`.

## Summary

`/dtd run [--until <boundary>] [--decision <mode>] [--silent[=<duration>] | --interactive]`.

Run loop per task:
1. Read state.md (mode, plan_status, pause_requested, awaiting_user_decision).
2. Read steering.md cursor; apply low-impact entries.
3. Check pending_patch (refuse new dispatch until resolved).
4. Pick next ready batch (topo + parallel-group).
5. Pre-dispatch lock partitioning.
6. For each task in batch:
   a. Build worker prompt (5-step canonical assembly + GSD-style reset).
   b. Context budget gate (soft 70% / hard 85% / emergency 95%).
   c. Dispatch (HTTP per worker registry).
   d. Heartbeat lease.
   e. Receive + parse response (`::done::` / `::blocked::`).
   f. Validate before apply (output-paths × permission_profile × locks × block_patterns).
   g. Apply phase 1 (write all temps) + phase 2 (rename all).
   h. Compute grade (controller-side; never worker self-grade).
   i. Append phase row to phase-history.md.
   j. Apply patches between tasks only.

## --until boundaries

- `phase:<id>` — pause after phase passes
- `task:<id>` — pause after task completes
- `before:<phase-name>` — pause before named phase
- `next-decision` — pause when any decision capsule fires

## v0.2.0f flags

- `--silent[=<duration>]` — defer non-urgent blockers; ≤ silent_max_hours.
- `--decision plan|permission|auto` — how often to ask.
- `--interactive` — explicit interactive mode (default).

## finalize_run(terminal_status)

Required for COMPLETED / STOPPED / FAILED (NOT PAUSED). 7 atomic steps:
1. Release leases.
2. Archive notepad.
3. Reset notepad.
4. Write run summary.
5. Clear incident state (v0.2.0a).
5b. Clear attention/context-pattern state (v0.2.0f).
6. Append AIMemory WORK_END.
7. Update state.md atomically.

## Anchor

See `dtd.md` §`### /dtd run` for full run loop, lock partitioning,
context budget gate, validate-before-apply, two-phase apply,
finalize_run order.

## Related topics

- `incidents.md` — failures become incidents during dispatch/apply.
- `autonomy.md` — silent mode ready-work algorithm.
- `plan-schema.md` — plan XML drives the run loop.
