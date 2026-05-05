# DTD v0.3 real-use benchmark — development phase reference

## Anchor

This file is the canonical reference for the **real-use benchmark
evidence track**: a separate evaluation of DTD's controller/worker
architecture against plain (one-shot) baselines, using real LLM
endpoints.

Per Codex's next-phase development handoff
(`handoff_dtd-next-phase-realuse-benchmark-dev.gpt-5-codex.md`
2026-05-06):

> "The real-use benchmark is a separate evidence track. It must
> not be conflated with v0.3 R2 live validation or release
> tagging. Actual benchmark execution requires a fresh explicit
> user command."

**Boundary**: this reference defines schemas + contracts +
recommendation surface for the development phase. It does NOT
authorize benchmark execution. R2 live validation
(`v030-r2-live-test-plan.md`) and the realuse benchmark are
distinct tracks.

## Summary

The real-use benchmark answers a different question than R2:

- **R2** verifies v0.3 contracts execute correctly end-to-end
  against worker infrastructure. It's a contract test.
- **Real-use benchmark** measures whether DTD's controller/worker
  split actually saves controller-context tokens vs total system
  tokens, and where DTD's quality/cost tradeoff lands relative to
  plain one-shot agents. It's a value test.

Both are user-driven; neither runs autonomously.

This reference covers 6 development-phase deliverables (per Codex
session-#19 handoff):

1. Worker capability inventory schema.
2. Benchmark result JSONL schema (plain + DTD rows).
3. Recommendation surface (`quick` / `balanced` / `thorough` /
   `silent-overnight`).
4. Scorekeeping contract (formula-bound from raw evidence).
5. Runner dry-run plan (no network / no LLM).
6. Checker coverage for new canonical docs.

Plus: **all 6 are spec-only**. The 8-hour DeepSeek-Pro agent
benchmark execution waits for explicit user start.

## 1. Worker capability inventory schema

### Storage

Per-worker probe results live at:

```
.dtd/log/worker-checks/<worker_id>-capabilities.md
```

(gitignored under `log/` per existing v0.2.1 worker-check log
discipline). This is a **detail log**; a compact summary may also
be stored in worker metadata for fast lookup.

### Schema

```yaml
# .dtd/log/worker-checks/deepseek-v4-pro-capabilities.md (example)

worker_id: deepseek-v4-pro
endpoint_hash: sha256(endpoint)[:16]   # NEVER raw endpoint URL
api_key_env: DEEPSEEK_API_KEY          # env var NAME only
probed_at: 2026-05-06T09:00:00Z
probe_run: <run-id>                     # cross-link to run notepad

capabilities:
  basic_content:           supported   # supported | unsupported | unprobed
  file_marker_echo:        supported   # ===FILE: <path>=== fenced output
  json_response_format:    supported   # response_format: {"type":"json_object"}
  provider_thinking:
    disabled:              supported
    low:                   supported
    max:                   supported
  streaming:               supported   # stream:true; DTD still uses false
  usage_tokens:            supported   # usage.prompt_tokens / completion_tokens
  reasoning_content_field: supported   # response has hidden reasoning_content (dual)

probe_results:
  - probe: basic_content
    status: PASS
    evidence: .dtd/tmp/probe-basic-<probe-id>.json (redacted)
    notes: "::done:: parsed; 4 token completion"
  - probe: file_marker_echo
    status: PASS
    evidence: .dtd/tmp/probe-marker-<probe-id>.json (redacted)
  - probe: provider_thinking_max
    status: PASS
    evidence: .dtd/tmp/probe-thinking-max-<probe-id>.json (redacted)
    reasoning_token_count: 1248
    notes: "thinking content present in reasoning_content; never parsed"
  - ...

unsupported_omit_policy: "omit field from request body; do not force"
```

### Status semantics

- `supported`: probe succeeded; feature is available.
- `unsupported`: probe ran AND feature explicitly failed (e.g. 400
  with "unknown field"). Feature MUST be omitted from production
  requests.
- `unprobed`: feature has not been tested. Treat as unsupported
  for safety; controller MAY skip the request.

### Redaction discipline (matches Codex P1.6 + workers.md)

- **NEVER** store raw API responses with possible token leakage
  in capability log.
- **NEVER** echo the API key value (env-var name only).
- **NEVER** store raw `reasoning_content` (only token count +
  presence flag).
- Endpoint URL stored as 16-char sha256 prefix (audit-friendly,
  not reversible).
- Evidence files (`probe-*.json`) MUST be redacted before write
  using existing v0.2.1 worker-check redaction filter.

### Compact summary (in worker metadata)

For fast lookup without reading the detail log:

```yaml
# .dtd/workers.md (per worker)
## deepseek-v4-pro
- ...
- capabilities_probed_at: 2026-05-06T09:00:00Z
- capabilities_summary:
    thinking: low|max
    streaming: yes
    json_response: yes
    reasoning_content: yes-redacted
```

## 2. Benchmark result JSONL schema

### Storage

```
test-projects/dtd-realuse-agent-suite/runs/<run-id>/results.jsonl
```

One row per case-execution (plain arm or DTD arm). One run-id
groups a full sweep of cases × arms.

### Plain row schema

```jsonl
{
  "schema_version": "1.0",
  "row_type": "plain",
  "case_id": "short-cli-001",
  "case_size": "short",
  "case_type": "cli-tool",
  "method": "plain",
  "control_arm": "P0F",
  "creator_model": "deepseek-v4-flash",
  "max_iterations": 1,
  "actual_iterations": 1,
  "elapsed_sec": 42.7,
  "total_tokens": 7470,
  "result_score": 90,
  "result_score_components": {
    "files_present": 10, "compile": 15, "external_acceptance": 30,
    "generated_tests": 0, "test_quality": 0, "docs_consistency": 10,
    "size_band": 5, "maintainability": 5
  },
  "pass_external_acceptance": true,
  "pass_generated_tests": null,
  "product_lines": 865,
  "evidence_paths": [
    "runs/<run-id>/short-cli-001/plain-P0F/output/",
    "runs/<run-id>/short-cli-001/plain-P0F/external-acceptance.log",
    "runs/<run-id>/short-cli-001/plain-P0F/generated-tests-pytest.log"
  ],
  "judge_model": "deepseek-v4-pro",
  "judge_thinking": "max",
  "judge_thinking_support": "supported",
  "notes": "P0F one-shot; no repair budget"
}
```

### DTD row schema

```jsonl
{
  "schema_version": "1.0",
  "row_type": "dtd",
  "case_id": "short-cli-001",
  "case_size": "short",
  "case_type": "cli-tool",
  "method": "dtd-D3",
  "control_arm": "D3",
  "controller_model": "deepseek-v4-pro",
  "implementation_worker_model": "qwen3-coder-local",
  "test_worker_model": "deepseek-v4-flash",
  "verifier_model": "deepseek-v4-flash",
  "max_iterations": 3,
  "actual_iterations": 3,
  "elapsed_sec": 187.3,
  "total_tokens": 30518,
  "controller_tokens": 4390,
  "controller_prompt_tokens": 3200,
  "controller_completion_tokens": 1190,
  "implementation_worker_tokens": 26128,
  "implementation_worker_prompt_tokens": 22000,
  "implementation_worker_completion_tokens": 4128,
  "test_worker_tokens": 0,
  "test_worker_prompt_tokens": 0,
  "test_worker_completion_tokens": 0,
  "verifier_tokens": 0,
  "scorekeeper_tokens": 0,
  "total_system_tokens": 30518,
  "worker_attempts": 6,
  "test_worker_attempts": 0,
  "verifier_attempts": 0,
  "controller_thinking": "low",
  "controller_thinking_support": "supported",
  "worker_thinking": "disabled",
  "test_worker_thinking": "disabled",
  "scorekeeper_thinking": "max",
  "scorekeeper_thinking_support": "supported",
  "streaming_support": {
    "controller": "supported",
    "worker": "supported",
    "test_worker": "supported"
  },
  "context_policy": "summary-only",
  "result_score": 100,
  "result_score_components": {
    "files_present": 10, "compile": 15, "external_acceptance": 30,
    "generated_tests": 15, "test_quality": 10, "docs_consistency": 10,
    "size_band": 5, "maintainability": 5
  },
  "pass_external_acceptance": true,
  "pass_generated_tests": true,
  "product_lines": 1367,
  "evidence_paths": [
    "runs/<run-id>/short-cli-001/dtd-D3/output/",
    "runs/<run-id>/short-cli-001/dtd-D3/controller-trace.md",
    "runs/<run-id>/short-cli-001/dtd-D3/external-acceptance.log",
    "runs/<run-id>/short-cli-001/dtd-D3/generated-tests-pytest.log",
    "runs/<run-id>/short-cli-001/dtd-D3/token-ledger.json"
  ],
  "controller_context_policy": "summary-only",
  "judge_model": "deepseek-v4-pro",
  "judge_thinking": "max",
  "notes": "D3 with test-worker; raw worker output kept in files"
}
```

### Required field invariants

- `schema_version: "1.0"` MUST be present (forward-compat).
- `row_type` MUST be `plain` or `dtd`.
- `total_tokens` for plain == `total_system_tokens` (no role split).
- `total_tokens` for dtd == `controller_tokens + implementation_worker_tokens + test_worker_tokens + verifier_tokens + scorekeeper_tokens`.
- All token fields MUST be non-negative integers.
- `evidence_paths` MUST point to real files in
  `test-projects/dtd-realuse-agent-suite/runs/<run-id>/`.
- `result_score_components` MUST sum to `result_score` ± 0.5
  (rounding tolerance).
- `judge_thinking` MUST be `low` | `max` | `disabled` | `omitted`
  | `unsupported`.

## 3. Recommendation surface

### User-facing modes

| Mode | Default for | Tradeoff (controller / total / quality / time) |
|---|---|---|
| `quick` | tiny tasks (≤200 lines, simple CLI/parser) | Lowest controller use; total ≈ plain; quality good; fastest |
| `balanced` | most coding tasks (200-1500 lines) | Controller -30 to -50%; total +1.5 to +3x; quality ~+10pts; medium time |
| `thorough` | important / multi-module (>1000 lines, ambiguous specs) | Controller -40 to -60%; total +3 to +5x; quality ~+15pts; slow |
| `silent-overnight` | bounded autonomous runs (R2-style, not R2 itself) | Same as thorough + paused-blocker discipline + extended budget |

### Selection inputs

```
recommend_mode(task, attention_mode, cost_sensitivity, capabilities):
  # 1. Task size & type heuristic.
  if task.estimated_product_lines <= 200 and task.type in {"cli", "parser", "formatter"}:
    base = "quick"
  elif task.estimated_product_lines <= 1500:
    base = "balanced"
  else:
    base = "thorough"

  # 2. Attention mode override.
  if attention_mode == "silent" and base in {"thorough", "balanced"}:
    base = "silent-overnight"

  # 3. Cost sensitivity override.
  if cost_sensitivity == "low" and base == "thorough":
    base = "balanced"     # save spend; accept slightly lower quality
  elif cost_sensitivity == "high" and base == "balanced":
    base = "quick"        # avoid worker spend; accept lower quality

  # 4. Capability gate.
  if base in {"thorough", "silent-overnight"} and not capabilities.has_test_worker:
    base = "balanced"     # thorough needs test-worker per D3+

  return base
```

### Mapping to control arms

| Mode | Default arm | Alt arm if specific cap missing |
|---|---|---|
| `quick` | P1F (plain + 1 repair) | P0F if no repair budget |
| `balanced` | D3 (test-worker DTD) | D2 if no test-worker |
| `thorough` | D5 (deep QA) | D4 if no docs/CLI gate |
| `silent-overnight` | D5 + bounded silent | D4 if D5 unavailable |

### Audit

Each `recommend_mode()` call produces an audit row in
`.dtd/log/recommendations-run-<run>.md` with:
- inputs (task hash, attention_mode, cost_sensitivity, cap summary)
- chosen mode
- chosen arm
- expected tradeoff
- override reason (if any)

NL-only: this is a controller-side recommendation, not an
auto-execute path. Final decision belongs to the user (per
v0.2.0b permission ledger discipline).

## 4. Scorekeeping contract

### Formula-bound score (100 points total)

Per benchmark-matrix.md ## Score Rubric:

| Component | Points | Source |
|---|---:|---|
| Required files present | 10 | filesystem check (objective) |
| Project compiles | 15 | compile/lint exit code 0 (objective) |
| External acceptance passes | 30 | external_acceptance.py exit 0 (objective) |
| Generated tests pass | 15 | pytest 100% pass rate (objective) |
| Test quality verified | 10 | DeepSeek Flash verifier pass (objective; binary) |
| Docs/CLI/API consistency | 10 | docs/CLI examples match `--help` (objective) |
| Target size band hit | 5 | product_lines in declared band (objective) |
| Maintainability/readability | 5 | Pro subjective, capped (semi-objective) |

### Pro scorekeeper invariants

1. **Score components are derived from raw evidence**:
   - Compile: read compile log file.
   - External acceptance: read external_acceptance.log exit code.
   - Generated tests: read pytest log; require 100% pass for full
     points; partial credit prorated.
   - Test quality: separate Flash verifier pass/fail.
   - Docs/CLI: regex match on `--help` output vs README/docstrings.
   - Size band: count product_lines (excl. harness/.dtd/).

2. **Pro must NOT modify objective sub-scores by preference**.
   The formula above is binding.

3. **Maintainability/readability cap**: Pro may award 0-5 points
   but MUST include a 1-paragraph rationale citing specific
   evidence (file paths, line refs). No bare numerical adjustment.

4. **Same-model self-judging**: when controller-model ==
   scorekeeper-model (e.g. both deepseek-v4-pro), scorekeeper
   MUST flag the row with `same_model_judge: true` for human
   audit.

5. **Audit fields** in result row:
   - `judge_model`
   - `judge_thinking`
   - `judge_thinking_support`
   - `score_evidence_paths` (list of files used to compute score)
   - `same_model_judge: true|false`

### Anti-grade-inflation

If `result_score_components` show `external_acceptance: 0`
(failed) AND `result_score >= 70`, the row is rejected as
malformed (real-use score must reflect external acceptance
failures). Doctor flags `realuse_score_inflation_violation`.

## 5. Runner dry-run plan

The runner has 3 modes:

| Mode | Network | LLM | Purpose |
|---|---|---|---|
| `dry-run` | NO | NO | Schema validation; sample fixture row generation |
| `probe-only` | YES | YES | Capability inventory probes only (no benchmark cases) |
| `full` | YES | YES | Real benchmark execution (requires explicit user start) |

### Dry-run scope

```
runner_dry_run():
  # 1. Validate schemas.
  validate_jsonl_schema(plain_row_template)
  validate_jsonl_schema(dtd_row_template)
  validate_capability_inventory_schema(sample_inventory)

  # 2. Generate sample fixture row.
  fixture = make_fixture_row(case_size="short", arm="P0F", dry_run=True)
  assert fixture.evidence_paths == []  # no real files
  assert fixture.dry_run == True       # MUST be flagged

  # 3. Validate recommendation surface.
  for case in test_cases:
    mode = recommend_mode(case)
    assert mode in {"quick", "balanced", "thorough", "silent-overnight"}

  # 4. Write dry-run report.
  write("test-projects/dtd-realuse-agent-suite/dryrun-results.jsonl", fixture)
  write("test-projects/dtd-realuse-agent-suite/dryrun-validation.md", report)
```

### Dry-run output discipline

- **Every row MUST have `dry_run: true`**.
- **No tokens** consumed (no LLM calls).
- **No external network** (no OpenAI / DeepSeek / etc).
- **Evidence_paths empty** (no real files generated).
- **Result_score: null** (not computed).

R2 doctor distinction: dry-run rows are explicitly NOT R2 PASS.
Mock results may only be used for harness validation, never for
real-use benchmark conclusions (per Codex's "do not fake R2 from
static checks" rule applied to realuse).

### `full` mode user gate

```
runner_full():
  if not user_explicit_start_received():
    raise UserGateMissing(
      "real-use benchmark execution requires explicit user start. "
      "run `/dtd realuse start` or equivalent."
    )

  # ... actual benchmark execution
```

The user gate is checker-protected: doctor `realuse_full_run_no_user_gate`
fires if a `full`-mode result row exists without a recorded user
start command.

## 6. Doctor checks (real-use benchmark track)

```
- realuse_capability_inventory_missing (INFO)
    Worker has been used in benchmark BUT
    .dtd/log/worker-checks/<id>-capabilities.md is missing.
    Recommends running probe-only first.

- realuse_jsonl_schema_invalid (ERROR — runtime, not static)
    A results.jsonl row fails schema_version 1.0 validation.

- realuse_score_inflation_violation (ERROR)
    result_score >= 70 with external_acceptance: 0. Score must
    reflect external acceptance failures.

- realuse_recommendation_unknown_mode (ERROR)
    recommend_mode() returned a value outside {quick, balanced,
    thorough, silent-overnight}.

- realuse_score_no_evidence_path (ERROR)
    A row's score_evidence_paths is empty AND row_type != "dry_run".

- realuse_full_run_no_user_gate (ERROR)
    A `full` mode results.jsonl exists without recorded user
    start command.

- realuse_same_model_judge_unflagged (WARN)
    controller_model == scorekeeper_model AND row lacks
    same_model_judge: true flag.

- realuse_dryrun_has_evidence (ERROR)
    A dry_run: true row has non-empty evidence_paths or non-zero
    tokens. Dry-run must be hermetic.
```

## 7. Boundaries

This reference defines DEVELOPMENT-PHASE deliverables only:

- **Schemas + contracts** (sections 1-4): canonical, in this file.
- **Dry-run plan** (section 5): hermetic, no LLM/network.
- **Doctor checks** (section 6): static + dry-run scoped.

It does NOT authorize:
- Full benchmark execution (waits for user gate).
- v0.3 release tagging (separate decision).
- Conflation with R2 live validation (separate evidence track).
- Mock R2 PASS (per Codex's existing rule applied to realuse).

## 8. Migration / file additions

This phase adds:
- `.dtd/reference/v030-realuse-benchmark.md` (this file)
- Catalog row in `reference/index.md`
- 1 entry in `scripts/build-manifest.ps1`
- Checker guards in `scripts/check-v023.ps1`

It does NOT add:
- New files in `test-projects/dtd-realuse-agent-suite/` yet (that
  scaffold is created when user explicitly starts the dry-run or
  full mode).
- New permission keys (existing 11-key invariant stable).
- New worker schema fields beyond Codex's `provider_thinking`.

## 9. Acceptance criteria

This development phase is acceptance-tested by:

1. Schema sections (1-4) exist with explicit field invariants.
2. Recommendation surface defines 4 modes with selection inputs +
   audit + arm mapping.
3. Scorekeeping contract is formula-bound with anti-inflation
   guard.
4. Dry-run plan defines hermetic + user-gate semantics.
5. 8 doctor codes scoped to realuse track.
6. No v0.3 R2 / contract conflation; track is separately
   namespaced.
7. Reference topic discoverable from `index.md` + checker-protected.

## Related topics

- `v030-r2-live-test-plan.md` — v0.3 contract live execution
  (separate track).
- `v030-r2-0-readiness-checklist.md` — R2 entry gate.
- `workers.md` — provider_thinking + capability probe fields.
- `perf.md` — role-split token reporting.
- `persona-reasoning-tools.md` — DTD reasoning utilities vs
  provider thinking distinction.

## Anchor

This file IS the canonical reference for the v0.3 real-use
benchmark **development phase**. Schemas, contracts, mode
mapping, scorekeeping rules, dry-run gate, and doctor codes all
live here. The 8-hour benchmark execution is a separate event
gated by explicit user start.
