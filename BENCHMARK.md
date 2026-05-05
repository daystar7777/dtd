# DTD Real-Use Benchmark

This document is the public entry point for DTD benchmark work.

DTD's benchmark track is separate from release-contract testing. Release
checks answer "does the spec hold?" The real-use benchmark answers "when is
DTD better than a plain one-agent run, and what does it cost?"

## Current Status

As of 2026-05-06:

- The real-use benchmark is in the **design and runner-prep phase**.
- **No full benchmark results have been received yet.**
- Full 8-hour live execution has **not** been run.
- Live execution requires a fresh explicit user command.
- The canonical benchmark reference is
  `.dtd/reference/v030-realuse-benchmark.md`.
- The control-arm matrix is
  `test-projects/dtd-realuse-token-test/benchmark-matrix.md`.

## Received Artifacts

| Artifact | Status | Notes |
|---|---|---|
| Single real-use token experiment | Received | One controlled plain-vs-DTD run exists under `test-projects/dtd-realuse-token-test/runs/20260505T203342Z/`. |
| DeepSeek/OpenCode large benchmark suite | Not received | `test-projects/dtd-realuse-agent-suite/` is not present. |
| Benchmark `results.jsonl` | Not received | No `results.jsonl` benchmark result file is present yet. |
| Public benchmark plan | Present | This file summarizes the intended benchmark evidence track. |

The single experiment is useful design evidence, but it is **not** the full
benchmark result set. Do not present it as the final benchmark.

The latest local verification closes the previous realuse doctor-code gap:

- `.dtd/reference/doctor-checks.md` registers all 8 realuse doctor codes.
- `scripts/check-v023.ps1` verifies each code exists in both the benchmark
  reference and the doctor registry.
- `check-v023` passes with public benchmark discovery and doctor-registry
  guards enabled.

## What The Benchmark Measures

The benchmark compares two execution styles:

| Track | Meaning |
|---|---|
| Plain | A single model plans, implements, repairs, and reports. |
| DTD | A controller plans and coordinates specialized workers. |

DTD must report controller tokens separately from worker tokens. Worker spend
is real system cost, but it is not the same as controller-context growth.

Key DTD token fields:

| Field | Meaning |
|---|---|
| `controller_tokens` | Controller planning, dispatch, resume, and summary tokens. |
| `implementation_worker_tokens` | Tokens spent by implementation workers. |
| `test_worker_tokens` | Tokens spent by test-writing or test-program workers. |
| `verifier_tokens` | Tokens spent by verifier workers. |
| `scorekeeper_tokens` | Tokens spent by the final judge. |
| `total_system_tokens` | Sum of controller + worker + verifier + scorekeeper tokens. |

## Default Model Split

The recommended benchmark split avoids same-model self-judging where possible.

| Role | Default |
|---|---|
| Plain baseline creator | `deepseek-v4-flash` |
| DTD controller | `deepseek-v4-pro`, thinking low if supported |
| Implementation worker | local Qwen3 Coder / configured local worker |
| Test-program worker | `deepseek-v4-flash` |
| Scorekeeper | `deepseek-v4-pro`, thinking MAX if supported |

Provider thinking, streaming, JSON response mode, marker echo, and token usage
reporting must be probed first. Unsupported optional features are omitted, not
forced.

## Control Arms

Plain controls:

| Arm | Description |
|---|---|
| `P0F` | Flash one-shot implementation, no repair. |
| `P1F` | Flash implementation plus one repair. |
| `P2F` | Flash implementation plus two repairs. |
| `P4F` | Flash implementation plus four repairs. |

DTD controls:

| Arm | Description |
|---|---|
| `D1` | Controller plan + local implementation worker, no test worker. |
| `D2` | Phased controller + local worker by phase, no test worker. |
| `D3` | Local implementation worker + Flash test-program worker. |
| `D4` | D3 plus one bounded repair loop. |
| `D5` | D3 plus two repair loops and docs/CLI consistency gate. |
| `D6` | Local worker first, Flash fallback, Pro only for controller. |

## Score Rubric

Scores are formula-bound and evidence-based.

| Component | Points |
|---|---:|
| Required files present | 10 |
| Project compiles | 15 |
| External acceptance passes | 30 |
| Generated tests pass, if present | 15 |
| Test quality verified separately | 10 |
| Docs/CLI/API examples match behavior | 10 |
| Target size band hit | 5 |
| Maintainability/readability review | 5 |

Guardrail: a result with `external_acceptance: 0` cannot receive a high score.
The doctor code `realuse_score_inflation_violation` catches this.

## Recommendation Modes

Benchmark results should eventually power user-facing recommendations:

| Mode | Intended use |
|---|---|
| `quick` | Tiny or low-risk work where DTD overhead may not pay off. |
| `balanced` | Normal implementation work with useful phase separation. |
| `thorough` | Larger or important work needing repair loops and stronger QA. |
| `silent-overnight` | Long unattended runs that defer blockers and keep moving safely. |

## Intake States

Where the realuse track is at any moment is one of 4 states. Run
`pwsh ./scripts/realuse-runner.ps1 -Mode intake-status` for the
current state.

| State | Meaning | What's needed to advance |
|---|---|---|
| `no_results` | No `results.jsonl` files exist anywhere under `test-projects/dtd-realuse-agent-suite/`. | Run dry-run to generate hermetic fixtures, OR the user starts the real benchmark. |
| `partial_results` | Some rows fail schema/doctor validation. | Fix or remove the invalid rows; re-run validate-results. |
| `schema_valid` | Rows valid, but either all dry-run OR no scores assigned. | If all dry-run: run real benchmark (user-gated). If non-dry-run no-score: assign scores via formula-bound scorekeeper. |
| `scored_report_ready` | Real (non-dry-run) rows exist, all schema-valid, all scored. | Aggregate into a public summary in this file. |

As of 2026-05-06, the realuse track is at **`no_results`**. The
single token experiment under `test-projects/dtd-realuse-token-test/`
predates the JSONL schema and is design-evidence only.

## Runner Modes

`scripts/realuse-runner.ps1` is the hermetic dev-phase runner.

| Mode | Network | LLM | What it does |
|---|---|---|---|
| `dry-run` | NO | NO | Generates a hermetic `results.jsonl` with `dry_run:true`, tokens=0, evidence_paths=[]. Exits 0 on clean validation. |
| `validate-results -Path <file>` | NO | NO | Validates a `results.jsonl` against schema + invariants + doctor codes. Exits 0 if clean. |
| `intake-status [-RunDir <dir>]` | NO | NO | Reports which of the 4 intake states the realuse track is in. |
| `probe-only` | (gated) | (gated) | Stub. Prints user-gate instructions; does not call any worker. |
| `full` | BLOCKED | BLOCKED | Refuses to run a live benchmark from this runner. Real execution requires explicit user start through a separate path. |

## Doctor-Code Fixtures

Each of the 8 realuse doctor codes has a deterministic JSONL
fixture under `examples/realuse-benchmark-fixtures/`.
Fixture harness: `pwsh ./scripts/check-realuse-fixtures.ps1`.

This makes the doctor codes operationally testable WITHOUT
requiring a live LLM run.

## Execution Boundary

The public docs and dry-run tooling are safe to run. Full live benchmark
execution is intentionally gated because it can spend real API tokens.

Before a live run, DTD should have:

- worker capability inventories,
- dry-run artifact validation,
- JSONL schema validation,
- doctor checks for realuse artifacts,
- explicit user approval for `/dtd realuse start` or equivalent.

## Related Files

- `.dtd/reference/v030-realuse-benchmark.md` - canonical schema and contract.
- `test-projects/dtd-realuse-token-test/benchmark-matrix.md` - control matrix.
- `examples/realuse-benchmark-fixtures/` - doctor-code fixtures.
- `.dtd/reference/doctor-checks.md` - doctor-code registry.
- `scripts/realuse-runner.ps1` - hermetic dev-phase runner.
- `scripts/check-realuse-fixtures.ps1` - fixture harness.
- `scripts/check-v023.ps1` - current realuse contract guard.
