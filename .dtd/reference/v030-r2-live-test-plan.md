# DTD v0.3 R2 — Live test plan (canonical reference)

## Anchor

This file is the canonical reference for the v0.3 line R2 phase:
**live DTD run against a nontrivial test project to exercise the
v0.3 sub-release contracts end-to-end**.

Per Codex final review pass
(`handoff_dtd-v030c-v030d-r1-codex-review.gpt-5-codex.md` 2026-05-06):

> "After this patch, v0.3 is GO at R0 + R1 contract level. Tagging
> still requires explicit user authorization. Residual risk is
> real-world execution: R2 should be a live DTD run against a
> nontrivial test project to exercise consensus staging, worker
> cancellation, git-branch sync, and session conflict recovery
> end to end."

R0 = spec; R1 = runtime contracts; **R2 = live execution
verification**.

## Summary

The release-contract harnesses (`scripts/check-v030*.ps1`) verify
**static contracts**: that markdown files contain expected
sections, that scenario blocks exist, that doctor codes are
defined. They do NOT verify that contracts actually behave
correctly when DTD runs.

R2 closes that gap by spinning up a nontrivial DTD project and
exercising each v0.3 sub-release end-to-end with at least one
worker that supports the R2-relevant capabilities (parallel
dispatch, provider quota headers, cancellation, git-branch
push, etc.).

R2 is **user-driven**. The controller / autonomous overnight
sessions cannot execute R2 alone — it requires:
- A test project with real source code (not just markdown).
- At least 2 worker endpoints (1 for `vote_unanimous`, 3 for
  `reviewer_consensus`).
- A DTD_SESSION_SYNC_KEY env var if exercising v0.3.0d sync.
- A 2-machine setup (or simulated via separate clones with
  different `state.md.machine_id`) for cross-machine sync.

## Test project requirements

R2 needs a `test-projects/dtd-v03-live/` analogous to the existing
`test-projects/dtd-v01-smoke/`, but exercising v0.3 features.

Minimum requirements:

1. **Source code** — at least 5 source files across 3 directories
   (e.g. `src/auth/`, `src/api/`, `tests/`). Real-ish code, not
   just placeholder stubs.
2. **A multi-phase plan** — 3+ phases with parallel-group tasks.
3. **A consensus task** — at least one task with `consensus="3"
   reviewer_consensus`.
4. **Workers**:
   - At least 3 configured worker slots for consensus scenarios.
   - At least 1 local worker (Ollama / vLLM / LM Studio).
   - At least 1 remote worker that returns `x-ratelimit-*`
     headers (any OpenAI-compat provider).
   - The reviewer-consensus reviewer MUST be a distinct worker id
     from the candidate set. Multiple worker ids may point at the
     same provider only when they use separate model/session
     configuration and the test report says so.
   - Optionally a paid worker for stretch fallback coverage.
5. **Sync target** (optional, only if testing v0.3.0d):
   - A shared filesystem path (e.g. `~/Dropbox/dtd-r2-test-sync/`
     or a tmpfs path simulated via 2 parallel project clones).
   - `DTD_SESSION_SYNC_KEY` env var set to a 32-byte secret.

R2 safety guardrails:

- Use a disposable test repo/worktree only. Do not run R2 against a
  production project.
- Use a dedicated sync path or branch that contains no real user data.
- Use non-production worker credentials. Do not commit `.dtd/.env`,
  `.dtd/session-sync*`, worker logs, or live provider tokens.
- Cleanup commands, when used, must be scoped to
  `test-projects/dtd-v03-live/` and the dedicated sync target.

Suggested scaffold:

```text
test-projects/dtd-v03-live/
  src/auth/
  src/api/
  src/core/
  tests/
  .dtd/
```

## Per-sub-release coverage matrix

Each v0.3 sub-release needs at least 1 live scenario covering its
core contract:

### v0.3.0e — Time-limited permissions

| Live scenario | Covers |
|---|---|
| **L-E-1**: Issue `/dtd permission allow edit scope: src/** for 5m`; observe rule auto-prune at finalize_run + tombstone with `by: finalize_run_ttl_expired`. | Resolution-time evaluator, finalize_run step 5c, tombstone audit format. |
| **L-E-2**: Issue `/dtd permission allow bash scope: npm test for run`; run a plan to COMPLETED; verify tombstone has `by: finalize_run_run_end`. | `for run` sentinel, R1 audit field `resolved_until_form: named_run`. |
| **L-E-3**: Set `state.md.user_tz: Asia/Seoul`; issue `until eod` rule at 14:00 Seoul; verify `resolved_until` carries `+09:00` offset; resume at next day morning to confirm rule pruned. | Named-local TZ resolution + DST/cross-day correctness. |

### v0.3.0b — Token-rate-aware scheduling

| Live scenario | Covers |
|---|---|
| **L-B-1**: Configure local worker with `daily_token_quota: 10000`; run one or more tasks that record about 9000 used tokens, then queue a next task whose estimate would cross the quota threshold; verify predictive check fires WORKER_QUOTA_EXHAUSTED_PREDICTED before dispatch. | Step 5.5.0 predictive routing. |
| **L-B-2**: Provider returns `x-ratelimit-remaining: 50`; verify `worker-usage-run-NNN.md` row has `provider_remaining: 50` AND no raw header strings persisted. | Provider-header parser + redaction discipline. |
| **L-B-3**: Trigger 429 mid-run; verify capsule fires with `mid_run_actual_exceeded: true`; verify `plan_status: PAUSED` + `awaiting_user_decision: true` (NOT terminal). | Mid-run quota exhaust as durable blocker. |

### v0.3.0a — Cross-run loop guard

| Live scenario | Covers |
|---|---|
| **L-A-1**: Run two distinct terminal runs that produce the same failure signature; verify finalize_run captures both rows; on the following dispatch/watch, the same pattern fires LOOP_GUARD_CROSS_RUN_HIT after threshold (2 by default). | Capture-before-clear at step 5d + cross-run match algorithm. |
| **L-A-2**: User runs `/dtd loop-guard prune <signature>`; tombstone appended; immediate lookup treats the older signature inactive. A later same-signature failure may create a fresh non-tombstone row at count=1, and only a subsequent recurrence can hit the threshold again. | Tombstone precedence + revival semantics. |
| **L-A-3**: 2 controllers running same project simultaneously both finalize_run within 60s; verify `cross_run_concurrent_finalize_detected` INFO; ledger has 2 rows for same signature; match algorithm uses MAX run_count. | Concurrent run handling. |
| **L-A-4**: Run `/dtd loop-guard rehash` in the disposable project after a deliberate project-identity change; verify old signature rows are tombstoned by `rehash_admin`, replacement rows use the new project identity, and no ledger history is physically deleted. | Rehash admin path + audit-preserving migration. |

### v0.3.0c — Multi-worker consensus dispatch

| Live scenario | Covers |
|---|---|
| **L-C-1**: Plan with `consensus="3" first_passing` against 3 different workers; verify all 3 dispatch in parallel into isolated staging dirs; first to return `::done::` wins; remaining cancelled or marked `consensus_late_stale`. | Parallel dispatch + staged isolation + late-result-never-apply. |
| **L-C-2**: Plan with `consensus="3" reviewer_consensus consensus-reviewer="<id>"`; verify reviewer is DISTINCT from candidate set; reviewer returns `::winner: <id>::`; only winner applies. | Reviewer prompt + reviewer-distinct invariant. |
| **L-C-3**: Plan with `consensus="3" vote_unanimous` against 3 workers that produce slightly different outputs; verify CONSENSUS_DISAGREEMENT capsule fires; user picks `retry_all` → fresh dispatch; verify staging cleaned up. | vote_unanimous + capsule resume actions. |
| **L-C-4**: Two consensus tasks race on the same `output-paths`; the first task or fixture holds the group lock longer than `consensus_lock_acquire_timeout_sec` (30s); verify the second task blocks and then fires CONSENSUS_LOCK_TIMEOUT. | Group lock semantics + timeout capsule. |

### v0.3.0d — Cross-machine session sync

| Live scenario | Covers |
|---|---|
| **L-D-1**: Backend `none` (default); verify v0.2.1 per-machine behavior unchanged (no sync read/write). | Backend `none` no-op. |
| **L-D-2**: Backend `filesystem`, sync_path = shared folder, `DTD_SESSION_SYNC_KEY` set; finalize_run writes `<sync_path>/<repo_id_hash>/session-sync.encrypted`; verify the file contains encrypted base64url text rows, contains no raw session id by grep, and decrypts with the same key on Machine B. | Encryption round-trip + cross-machine resume. |
| **L-D-3**: Backend `filesystem` with NO encryption key set; verify ERROR `session_sync_no_encryption_key`; sync DISABLED for run; per-machine fallback. | Fail-closed without key (Codex P1.6). |
| **L-D-4**: Backend `git_branch`, sync_branch = `dtd-session-sync`; verify isolated worktree at `.dtd/tmp/session-sync-worktree/`; commit happens only there; user's working branch git status NOT modified. | Branch isolation. |
| **L-D-5**: 2 machines both have active session for `(worker_x, claude-api)` with different `session_id_hash`; verify SESSION_CONFLICT capsule fires with full decision capsule; user picks `use_remote`; verify decryption succeeds + same-worker hint. | Conflict detection + durable `pending_session_conflict` resume. |

### Cross-cutting

| Live scenario | Covers |
|---|---|
| **L-X-1**: Run all 5 sub-releases interleaved within a single plan; verify finalize_run step 5e runs both `9.quota` AND `9.session-sync` hooks before WORK_END; verify step 7 clears all v0.3 per-run runtime fields. | Codex P1.10 dedicated-step discipline + step 7 cleanup. |
| **L-X-2**: After R2 run, run `/dtd doctor`; verify zero ERRORs across all v0.3 doctor codes when contracts hold. | Doctor coverage. |

Optional stretch coverage:

| Live scenario | Covers |
|---|---|
| **L-X-S1**: With session sync enabled, exhaust a free/local worker quota and offer a paid fallback worker; verify paid fallback still requires the configured confirmation policy and sync artifacts contain no raw session ids. | Cross-cutting quota + fallback + sync safety. |

## Acceptance criteria

R2 passes if:

1. **All required live scenarios in the coverage matrix above
   complete the documented "Pass" condition** with at least 1
   verified pass per scenario. The Optional stretch coverage section
   does not block R2.
2. **No unexpected `ERROR`-level doctor codes remain** after each
   scenario is remediated. Negative scenarios such as L-D-3 MUST
   first observe the expected ERROR, then restore configuration and
   finish with a clean doctor pass for the contracts under test
   (INFO/WARN are OK and expected for some scenarios).
3. **No raw provider session ids appear** in any synced file
   (filesystem OR git_branch backend), verified by grep over the
   encrypted sync file, sync working tree, and DTD logs; decryption
   is used only to verify round-trip correctness. No token strings
   may appear in `.dtd/log/worker-usage-run-NNN.md` (P1.6 + P1.2).
4. **Group locks behave correctly under contention** — no
   deadlocks; CONSENSUS_LOCK_TIMEOUT capsule fires when expected;
   retry_failed reuses lock; retry_all releases.
5. **Cross-run loop guard catches 2 distinct runs of the same
   failure** without firing on unrelated failures.
6. **Cross-machine sync round-trips** at least one session_id
   between 2 machines; conflicts produce SESSION_CONFLICT capsules
   with the full decision capsule shape.

## Reporting format

R2 results recorded in `test-projects/dtd-v03-live/run-r2-results.md`
with one row per live scenario:

```markdown
| Scenario | Status | Evidence | Notes |
|---|---|---|---|
| L-E-1 | PASS | `.dtd/permissions.md`, `.dtd/log/...` | rule pruned at finalize_run; tombstone matches by:finalize_run_ttl_expired |
| L-E-2 | PASS | `.dtd/permissions.md` | for run sentinel cleared at COMPLETED |
| ... | ... | ... | ... |
```

A failed scenario MUST file a v0.2.0a incident; recovery options
follow the standard DTD flow. The incident id, decision capsule id,
and recovery choice should be listed in the Evidence column.

## Out of scope for R2

- Performance benchmarking (latency, throughput) — that's R3 if
  the user wants it.
- Adversarial security testing — separate engagement; not part of
  feature acceptance.
- Multi-vendor parity testing (e.g. Anthropic vs OpenAI behavior
  on consensus) — single-vendor coverage is enough for R2.
- v0.4 design — explicitly NOT started until R2 passes.

## Anchor

This file IS the canonical R2 live-test plan for the v0.3 line.
Per-sub-release scenarios live in this file (L-E-* / L-B-* /
L-A-* / L-C-* / L-D-* / L-X-*). The static-contract test scenarios
remain in `test-scenarios.md` (numbered 109-189 across v0.3
sub-releases).

R2 execution requires user-driven setup (test project, workers,
optional sync target) — autonomous overnight sessions cannot run
R2 unaided.

## Related topics

- `test-scenarios.md` — static-contract scenarios 109-189.
- `v030*.md` — per-sub-release reference topics (R0 + R1 contracts).
- `roadmap.md` — overall v0.3 line status pointer.
