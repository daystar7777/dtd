# DTD reference: perf (v0.2.0f)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §`/dtd perf`.

## Summary

Observational performance/token report. Separates controller vs worker
totals (never blended). Read-only: never mutates state, notepad,
attempts, phase history, steering, or AIMemory.

```text
/dtd perf                            full report (controller + workers + worker detail)
/dtd perf --phase <id>               filter to one phase
/dtd perf --worker <id>              one worker's calls
/dtd perf --since <run>              aggregate across runs
/dtd perf --tokens                   suppress timing/cost columns
/dtd perf --cost                     requires worker pricing metadata
```

## Data sources

- `.dtd/log/controller-usage-run-NNN.md` — authoritative for controller
  mutating turns (plan / run_loop / dispatch_prepare / steer /
  decision_resolve / finalize). Append-only ledger; observational reads
  do NOT append.
- `.dtd/log/exec-<run>-task-<id>-att-<n>-ctx.md` — per-dispatch worker
  diagnostics + provider `usage.prompt_tokens` / `usage.completion_tokens`.
  Controller estimate fields used as fallback when ledger absent.
- `.dtd/attempts/run-NNN.md` — task/worker/phase/attempt mapping.
- `.dtd/phase-history.md` — phase duration/gates/grades.
- `.dtd/workers.md` — optional pricing metadata.

No double-counting: controller totals prefer ledger over ctx-file
controller estimates.

## Anchor

See `dtd.md` §`### /dtd perf` for output format, controller usage
ledger schema, ctx file YAML schema, output flag matrix.

## Related topics

- `autonomy.md` — `/dtd perf` is observational per v0.2.0f.
- `workers.md` — worker registry + pricing metadata.
