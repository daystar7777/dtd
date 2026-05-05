# Realuse benchmark — doctor-code fixtures

These JSONL fixtures exist to make each of the 8 realuse doctor
codes operationally testable without requiring a live LLM run.

Each fixture is a single-row `results.jsonl` designed to trigger
exactly ONE specific doctor code when fed through
`scripts/realuse-runner.ps1 -Mode validate-results -Path <file>`.

The fixture harness `scripts/check-realuse-fixtures.ps1` walks
this directory and asserts each fixture's expected doctor code
fires.

## Fixture catalog

| Fixture | Expected doctor code | Why |
|---|---|---|
| `valid-plain-row.jsonl` | (none) | Schema-valid plain row baseline; all checks clean |
| `valid-dtd-row.jsonl` | (none) | Schema-valid DTD row with token sum invariant satisfied |
| `invalid-schema-version.jsonl` | `realuse_jsonl_schema_invalid` | `schema_version` missing/wrong |
| `invalid-token-sum.jsonl` | `realuse_jsonl_schema_invalid` | DTD `total_tokens != sum(role_tokens)` |
| `score-inflation.jsonl` | `realuse_score_inflation_violation` | `result_score=85` + `pass_external_acceptance=false` |
| `unknown-mode.jsonl` | `realuse_recommendation_unknown_mode` | `recommended_mode="unknown"` |
| `no-evidence.jsonl` | `realuse_score_no_evidence_path` | non-dry-run row with empty `evidence_paths` |
| `same-model-judge.jsonl` | `realuse_same_model_judge_unflagged` | controller_model == scorekeeper_model, no flag |
| `dryrun-with-evidence.jsonl` | `realuse_dryrun_has_evidence` | `dry_run:true` with non-zero tokens / non-empty evidence |
| `full-no-user-gate.jsonl` | `realuse_full_run_no_user_gate` | `method:full` without `user_start_command_recorded:true` |

## NOT covered by fixtures

`realuse_capability_inventory_missing` (INFO) is environmental —
fires when a worker has been used but its capability inventory
file is missing. Cannot be triggered by a JSONL fixture; needs
worker-check log presence/absence test instead. Future fixture
harness pass.

## Discipline

- All fixtures are HERMETIC (no real LLM data, no real API keys).
- Model strings use sentinel `FIXTURE-NO-LLM` to make accidental
  copy-paste obvious.
- These fixtures are NOT benchmark results — they're test
  artifacts for the validator.
- Real benchmark `results.jsonl` files live in
  `test-projects/dtd-realuse-agent-suite/runs/<run-id>/`, not in
  this `fixtures/` subdirectory.
