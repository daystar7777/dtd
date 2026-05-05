# DTD reference: perf (v0.2.0f)

> Canonical reference for v0.2.0f `/dtd perf` command.
> Lazy-loaded via `/dtd help perf --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

`/dtd perf [--phase <id>|--worker <id>|--since <run>|--tokens|--cost]`

On-demand performance/token report. Observational and not shown in
default status unless the user asks.

## Data sources

- `.dtd/log/controller-usage-run-NNN.md` for mutating controller turns
  (planning, run-loop decisions, dispatch preparation, steering
  resolution, decision-capsule resolution, finalize). This is
  authoritative for controller totals when present.
- `.dtd/log/exec-<run>-task-<id>-att-<n>-ctx.md` for per-dispatch
  diagnostics and provider reported worker `usage.prompt_tokens` /
  `usage.completion_tokens`. Its controller estimate fields are used
  for controller totals only as a fallback when the controller usage
  ledger is absent.
- `.dtd/attempts/run-NNN.md` for task/worker/phase/attempt mapping.
- `.dtd/phase-history.md` for phase duration, gates, and grades.
- `.dtd/workers.md` optional token pricing metadata if present.

## Output

Output is split into two layers:

```text
+ DTD perf run-001
+ controller
| total      prompt 38k  completion 6k   ctx peak 42%
| phase 1    prompt 12k  completion 2k   ctx peak 31%
| phase 2    prompt 18k  completion 3k   ctx peak 42%
| phase 3    prompt 8k   completion 1k   ctx peak 28%
+ implementation workers
| total      calls 12  prompt 182k completion 41k ctx peak 68% cost $0.42
| phase 1    calls 3   prompt 32k  completion 9k  ctx peak 44%
| phase 2    calls 7   prompt 94k  completion 21k ctx peak 68%
| phase 3    calls 2   prompt 56k  completion 11k ctx peak 51%
+ test workers
| total      calls 4   prompt 28k  completion 7k  ctx peak 33%
+ verifiers / scorekeepers
| total      calls 3   prompt 11k  completion 2k  thinking max
+ worker detail
| deepseek-local   calls 9  prompt 118k completion 27k retry 2
| qwen-local       calls 3  prompt 44k  completion 10k retry 0
+ derived
| total_system_tokens 309k   # optional rollup; never controller cost
```

## Rules

- `/dtd perf` is an observational read: do not mutate `state.md`,
  notepad, attempts, phase history, steering, or AIMemory.
- Controller and worker totals MUST remain separate. Do not add them
  into one blended "total tokens" number.
- Benchmark reports may show `total_system_tokens` as a derived rollup
  after all role sections. It must never replace controller/worker/test/
  verifier columns or be described as controller context usage.
- Split delegated spend by role when known: implementation worker,
  test-program worker, verifier, scorekeeper, and plain/direct
  baseline. If the role is unknown, show it under `worker detail` with
  `role: unknown`.
- Do not double-count controller dispatch-prep estimates from both
  `controller-usage-run-NNN.md` and worker ctx files. Prefer the
  controller ledger; use ctx controller fields only for backward
  compatibility.
- Observational reads (`/dtd status`, `/dtd plan show`, `/dtd perf`,
  read-only incident/help/doctor calls) are not written to the
  controller usage ledger. `/dtd perf` reports DTD run orchestration/
  execution cost, not the cost of the user's status-check habit.
- If provider usage is missing, show `unknown` and keep controller
  estimates separate from provider-reported values.
- Cost is best-effort and shown only when worker pricing metadata
  exists.
- NL examples: "show token usage", "phase-by-phase tokens",
  "per-worker performance" (localized phrases via locale packs per v0.2.0e).

## Controller usage ledger (`.dtd/log/controller-usage-run-NNN.md`)

This compact run-local ledger keeps controller token accounting
separate from worker dispatch logs without polluting status/notepad/
attempt history.

Append one row after each **mutating** controller turn that is part
of a DTD run. Do not write a row for observational reads.

```markdown
# Controller usage run-001

| seq | ts | phase | task | kind | prompt_est | completion_est | ctx_peak | note |
|---:|---|---:|---|---|---:|---:|---:|---|
| 1 | 2026-05-05T14:02:11Z | 0 | - | plan | 9200 | 1800 | 38 | phase0 |
| 2 | 2026-05-05T14:11:05Z | 2 | 2.1 | dispatch_prepare | 8400 | 900 | 42 | att1 |
| 3 | 2026-05-05T14:18:44Z | 2 | 2.1 | decision_resolve | 2100 | 350 | 18 | retry |
```

Allowed `kind` values:

| kind | When |
|---|---|
| `plan` | phase 0 planning / plan amendment |
| `run_loop` | controller-only run-loop decision without worker dispatch |
| `dispatch_prepare` | prompt assembly + pre-dispatch gate |
| `steer` | accepted steering patch/action |
| `decision_resolve` | user option applied from decision capsule |
| `finalize` | terminal lifecycle |

`prompt_est` / `completion_est` are controller estimates unless the
host exposes provider usage for its own turn. Provider values may be
added later as optional columns. `phase: 0` is planning before phase
1 exists.

## Per-task ctx data file format (`.dtd/log/exec-<run>-task-<id>-att-<n>-ctx.md`)

Each worker dispatch writes one ctx data file. Existing log file
`.dtd/log/exec-<run>-task-<id>.<worker>.md` carries the worker's full
response; the new sibling ctx file carries only token/timing/cost
data — small (≤ 2 KB), structured, secret-free.

The ctx file name encodes the attempt number (`att-1`, `att-2`, etc.)
to distinguish retries — multiple ctx files exist per (run, task)
when a task retries. The existing exec log file is per (run, task,
worker) and can be appended on retries (existing behavior preserved).

Schema (markdown with one YAML front matter):

```markdown
---
run: 001
task: "2.1"
worker: deepseek-local
attempt: 1
phase: 2
phase_name: backend
context_pattern: fresh
sampling: "temp=0.0 top_p=1 samples=1"
worker_role: implementation           # implementation | test_program | verifier | scorekeeper | plain_baseline | unknown
provider_thinking: disabled           # disabled | low | medium | high | max | omitted | unknown
dispatched_at: 2026-05-05T14:32:11Z
returned_at:   2026-05-05T14:33:42Z
elapsed_ms: 91234
controller_prompt_estimate_tokens: 8120
controller_completion_estimate_tokens: 1410
controller_ctx_peak_pct: 42
worker_prompt_tokens_provider: 7902     # null if provider did not report
worker_completion_tokens_provider: 1287
worker_reasoning_tokens_provider: 0      # null if provider did not report
content_empty_reasoning_present: false   # true => WORKER_EMPTY_CONTENT_REASONING_ONLY
worker_ctx_pct_self_report: 38          # from worker's ::ctx:: line, if present; advisory
status: done                            # done | failed | blocked
retry_of: null                          # attempt id of the prior failed attempt, if retry
cost_usd: 0.0034                        # null if no pricing metadata
http_status: 200                        # null on non-HTTP transport
---

## Notes

(Optional human-readable notes — never raw worker output. Used for
"ctx gate triggered split" or "retry on 429" annotations.)
```

### Rules

- One file per worker dispatch (including retries — `attempt: 2` etc.).
  File name uses `att-<n>` segment to distinguish retries:
  `exec-001-task-2.1-att-1-ctx.md`, `exec-001-task-2.1-att-2-ctx.md`.
- Always written, even on `failed`/`blocked` status. Lets `/dtd perf`
  account for retry cost.
- Secret redaction applies (per §Security & Secret Redaction).
  Endpoint hosts, model ids OK; tokens, auth headers NEVER.
- Controller estimate fields are filled by the controller's own
  pre-dispatch budget gate (run loop step 6.b). Provider fields are
  filled from the HTTP response `usage` block when present; null
  otherwise.
- File is gitignored (under `.dtd/.gitignore` `log/`).
- v0.2.0a installs without v0.2.0f have NO ctx files. `/dtd perf`
  then reports `unknown` for token columns and shows controller-only
  estimates if `phase-history.md` has them; otherwise prints `no ctx
  data — run /dtd perf after at least one v0.2.0f dispatch completes.`.
- Doctor INFO check: ctx file count vs attempt count mismatch → INFO
  with ratio (helps detect skipped writes).

## Output flag matrix

| Flag | Effect |
|---|---|
| (no flag) | full report (controller + workers + worker detail) for active run |
| `--phase <id>` | filter all sections to one phase |
| `--worker <id>` | only "worker detail" + filtered phase rows for that worker |
| `--since <run>` | aggregate across runs from `<run>` to active (uses archived ctx files in `.dtd/runs/`) |
| `--tokens` | suppress timing/cost columns; emphasize prompt/completion |
| `--cost` | requires worker pricing metadata; otherwise shows `unknown` per row |

## Anchor

This file IS the canonical source for v0.2.0f `/dtd perf` command +
data sources + ledger schema + ctx file format.
v0.2.3 R1 extraction completed; `dtd.md` §`/dtd perf` now points here.

## Related topics

- `autonomy.md` — `/dtd perf` is the authority for measured token
  usage; lazy-load profile reduces cognitive scope.
- `workers.md` — worker registry + optional pricing metadata.
- `run-loop.md` — controller dispatch generates ctx files.
