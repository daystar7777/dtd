# DTD v0.3 R2-0 — Readiness checklist (canonical reference)

## Anchor

This file is the canonical readiness checklist for the **R2-0
sub-phase** of the v0.3 line R2 live-test plan. It is the
deliverable when the user has not yet provided worker/sync details
(R2 cannot start without them).

R2-0 is **observational only** — no test project created, no
secrets touched, no live worker calls, and no sync-target write
probe. It produces a readiness decision for "can full R2 start?"
and a concise remediation checklist if not.

Per Codex's R2 phase design
(`handoff_dtd-next-phase-r2-execution-design.gpt-5-codex.md`
2026-05-06):

> "If worker/sync prerequisites are absent, STOP at R2-0 with a
> concise checklist. Do not create a fake PASS. Mock/deterministic
> workers may be used only for a DRY REHEARSAL label, never for
> final R2 PASS."

## Summary

R2-0 answers four questions in order:

1. **Static contracts pass?** — release-contract harnesses + smoke.
2. **Local DTD install healthy?** — `/dtd doctor` clean.
3. **Worker prerequisites available?** — at least 3 distinct slots
   for consensus, ≥1 with quota headers.
4. **Optional sync prerequisites available?** — `DTD_SESSION_SYNC_KEY`
   + sync target if testing v0.3.0d.

If any of #1–#3 fails, R2 STOPS at R2-0 and the user receives the
STOP checklist below. #4 is optional; absence skips L-D-* coverage
but doesn't block a partial rehearsal of other R2 sub-releases.
It does block claiming a full R2 PASS.

## Command surface

```text
/dtd r2 readiness [--full|--json]  # observational R2-0 decision
/dtd r2 status                     # alias
/dtd r2 check                      # alias
```

The command loads this reference topic and emits one `r2_0_decision`
row plus any STOP/WARN checklist. It does not mutate state except for
an optional sanitized log row at `.dtd/log/r2-0-readiness-{ts}.md`.
It must not append notepad/steering/phase history or create
`test-projects/dtd-v03-live/`.

## R2-0 algorithm (controller-side, observational)

```
r2_0_readiness(state, config):
  results = []
  blockers = []
  warnings = []

  # Step 1 — Static contracts.
  for harness in [check-v020b, check-v020c, ..., check-v030e, smoke]:
    res = run_harness(harness)
    results.append({"step": "static", "harness": harness, "pass": res.pass})
    if not res.pass:
      blockers.append(StopCase("A", "static contracts failing",
                               remediate="fix harness failures first"))

  # Step 2 — Local DTD install health.
  doctor = run_doctor()
  errors = [c for c in doctor.codes if c.severity == "ERROR"]
  if errors:
    blockers.append(StopCase("B", f"doctor errors: {errors}",
                             remediate=doctor.suggestions))

  # Step 3 — Worker prerequisites (CHECK ONLY; do not call workers).
  workers = parse_workers_md()  # NEVER persist endpoint/auth values to chat or AIMemory
  consensus_capable = count(workers, where=enabled and capability >= dispatch)
  if consensus_capable < 3:
    blockers.append(StopCase("C", f"need >= 3 worker slots; have {consensus_capable}",
                             remediate="add workers via /dtd workers add"))

  with_headers = count(workers, where=quota_provider_header_prefix is not null)
  if with_headers < 1:
    blockers.append(StopCase("C", "need >= 1 worker with quota_provider_header_prefix",
                             remediate="configure x-ratelimit-* / anthropic-ratelimit- / etc on a remote worker"))

  reviewer_distinct = exists(workers, where=role=="reviewer" and id != any candidate id)
  if not reviewer_distinct:
    blockers.append(StopCase("C", "no reviewer-distinct worker for L-C-2",
                             remediate="declare a reviewer-only worker id distinct from candidate set"))

  # Step 4 — Optional sync prerequisites (skip-not-fail if absent).
  # Observational only: inspect configured backend/key presence/path shape.
  # Do NOT write/delete a probe file and do NOT push/fetch a sync branch here.
  sync_ok = false
  if not config.session_sync.enabled:
    warnings.append(WarnCase("D", "v0.3.0d L-D-* coverage will be SKIPPED (session_sync disabled)"))
  else:
    key_env_set = os.environ.get(config.session_sync.encryption_key_env) is not None
    sync_target_declared = (config.session_sync.sync_path or config.session_sync.sync_branch) is not null
    if key_env_set and sync_target_declared:
      sync_ok = true
    else:
      warnings.append(WarnCase("D", "v0.3.0d L-D-* coverage will be SKIPPED (sync not ready)"))

  if blockers:
    return Stop(blockers=blockers, warnings=warnings)
  if warnings:
    return Warn(warnings=warnings, l_d_skipped=not sync_ok)

  # All required steps passed.
  return Go(static_pass=True, doctor_clean=True, workers_ready=True,
            sync_ok=sync_ok, l_d_skipped=not sync_ok)
```

## STOP checklist (when R2-0 says STOP)

If R2-0 returned `Stop`, the user gets every applicable checklist
from the cases below. R2-0 SHOULD collect all observable blockers
in one pass instead of short-circuiting at the first failure.
Each case has a concrete remediation step + verification command.

### Case A — Static contracts failing

```
R2-0 STOP — static contracts not all passing.

The release-contract harnesses or smoke must pass before R2 can
start. R2 verifies LIVE behavior; it cannot make sense if STATIC
contracts already drift.

Remediation:
  1. Identify failing harness(es) from the verification output.
  2. Fix the underlying drift OR file a v0.2.0a incident.
  3. Re-run all 13 harnesses + smoke until clean.

Verify:
  pwsh ./scripts/check-v020b.ps1
  pwsh ./scripts/check-v020c.ps1
  ... (all 13)
  pwsh ./test-projects/dtd-v01-smoke/run-dtd-v01-acceptance.ps1
```

### Case B — `/dtd doctor` errors

```
R2-0 STOP — local DTD install has ERROR-level doctor codes.

R2 cannot calibrate worker health if the controller's own state
is broken.

Remediation:
  1. Run /dtd doctor and read the ERROR codes.
  2. Apply the suggested remediation per code (some auto-fix; some
     need user action).
  3. Re-run /dtd doctor until ERROR count is 0.

Verify:
  /dtd doctor   # exit code 0
```

### Case C — Worker slots insufficient

```
R2-0 STOP — worker registry does not meet R2 minimum.

R2 needs:
  [REQUIRED] >= 3 worker slots for consensus dispatch.
  [REQUIRED] >= 1 worker with quota_provider_header_prefix set
             (recognizable x-ratelimit-* or anthropic-ratelimit-
             headers).
  [REQUIRED] >= 1 reviewer-distinct worker id (distinct from
             candidate set; for L-C-2 reviewer_consensus).
  [OPTIONAL] paid-fallback worker (for L-X-S1 stretch only).

Remediation:
  1. /dtd workers add  (interactive wizard, repeat as needed)
  2. Edit .dtd/workers.md to set quota_provider_header_prefix on
     the remote slot.
  3. Designate the reviewer-distinct slot via worker `role:
     reviewer` field OR explicit consensus-reviewer attribute in
     the R2 plan.

Verify:
  /dtd workers list   # see all slots
  # Optional after the user explicitly wants to validate connectivity:
  /dtd workers test <id> --quick

Note: `/dtd workers test` calls a worker and is NOT part of the
R2-0 decision. It belongs to remediation or R2-2 calibration.
```

### Case D — Sync prerequisites missing (warning, not stop)

```
R2-0 WARN — v0.3.0d sync L-D-* coverage will be SKIPPED.

This is NOT a STOP. R2 may still proceed for the other 4
sub-releases (e/b/a/c). But L-D-1..L-D-5 cannot be exercised
without:
  [REQUIRED if L-D-*] DTD_SESSION_SYNC_KEY env var set to a
                     non-empty 32-byte secret.
  [REQUIRED if L-D-*] Either sync_path (filesystem backend) or
                     sync_branch (git_branch backend) declared.
  [REQUIRED if L-D-*] If git_branch: the sync branch can accept
                     force-add commits via isolated worktree.

Remediation (only if user wants L-D-* coverage):
  1. export DTD_SESSION_SYNC_KEY=<32-byte-secret>   # NEVER commit
  2. Configure config.session_sync.backend +
     config.session_sync.sync_path or sync_branch.
  3. Verify writability/connectivity only after the user opts into
     L-D-* setup. That verification is remediation or R2-2 work,
     not part of observational R2-0.

R2 may proceed without L-D-* if the user explicitly accepts the
SKIP. The R2 report MUST mark L-D-* rows as SKIPPED with reason
"sync prerequisites not provided"; this is NOT a PASS.
```

## What R2-0 must NOT do

Per Codex's R2 phase design + secrets discipline:

- **NEVER call live workers**. R2-0 is observational. Worker
  health probes happen in R2-2, not R2-0.
- **NEVER write/delete sync probe files or push/fetch sync
  branches**. R2-0 may check that key/env names and target config
  are present; mutating sync validation belongs to remediation or
  R2-2.
- **NEVER copy endpoint URLs, auth headers, or env-var values to
  chat or AIMemory**. Inspecting `.dtd/workers.md` locally is OK;
  surfacing values is not.
- **NEVER create `test-projects/dtd-v03-live/`** at R2-0. That's
  R2-1's job, AFTER user approval and worker confirmation.
- **NEVER mark R2 as PASSED from static checks alone**. R2 PASS
  requires R2-4 live evidence per scenario.
- **NEVER use mock/deterministic workers for final R2 PASS**.
  Mocks may only be used for a DRY REHEARSAL label, never for
  the final report.

## Output format

R2-0 produces a single decision row + (if Stop) a checklist:

```yaml
r2_0_decision:
  status: GO | STOP | WARN
  static_contracts: pass | fail
  doctor_errors: <count>
  worker_slots:
    consensus_capable: <count>      # need >= 3
    with_headers: <count>           # need >= 1
    reviewer_distinct: yes | no
    paid_fallback: yes | no | n/a
  sync_prereqs:
    enabled: yes | no
    key_env_set: yes | no | n/a
    target_declared: yes | no | n/a
    decision: ok | skip | n/a
  stop_cases: [A, B, C]             # empty unless status STOP
  warn_cases: [D]                   # empty unless sync skipped
  next_step: |
    GO -> proceed to R2-1 disposable test project scaffold
    STOP -> apply remediation from listed stop_cases above
    WARN -> proceed without L-D-* coverage (user explicit accept)
```

The decision row is appended to the user-facing R2 evidence file
(`test-projects/dtd-v03-live/run-r2-results.md` if R2 is GO; or
to a transient location like `.dtd/log/r2-0-readiness-{ts}.md` if
R2-0 STOPs and no test project yet exists).

## Doctor checks

```
- r2_0_static_failure (ERROR — only when R2 is being initiated)
    Any of the 13 release-contract harnesses or v0.1 smoke FAILS
    when /dtd r2 status (or equivalent R2 entry point) runs.

- r2_0_worker_count_below_min (ERROR — only when R2 is being initiated)
    .dtd/workers.md has fewer than 3 enabled worker slots.

- r2_0_no_quota_header_worker (ERROR — only when R2 is being initiated)
    No enabled worker has quota_provider_header_prefix set.
    Blocks required L-B-2 coverage; full R2 cannot start.

- r2_0_no_reviewer_distinct (ERROR — only when R2 is being initiated)
    No worker satisfies the reviewer-distinct invariant for
    L-C-2 reviewer_consensus.

- r2_0_sync_skipped (INFO — R2-0 decision status WARN)
    R2 proceeded with L-D-* SKIPPED because sync prerequisites
    were absent. R2 report MUST reflect this; partial PASS is not
    full R2 PASS.
```

## Acceptance criteria

R2-0 is itself acceptance-tested by:

1. STOP cases produce every applicable concrete checklist with
   verification commands.
2. GO outputs a `r2_0_decision` row that R2-1 can consume.
3. SKIP-not-FAIL distinction for sync prerequisites is explicit
   in the decision row.
4. No live worker calls or sync-target writes happen at R2-0
   (metadata inspection + observational only).
5. No secrets are persisted to chat or AIMemory.

## Related topics

- `v030-r2-live-test-plan.md` — full R2 plan (16 L-* scenarios).
- `roadmap.md` — overall v0.3 line status.
- `doctor-checks.md` — existing doctor codes (R2-0 codes are
  scoped to the R2 entry point, not the always-on doctor list).
- `dtd.md` / `.dtd/instructions.md` — always-loaded command and
  routing surface for `/dtd r2 readiness`.

## R2-0 next step

When the user wakes up and provides worker/sync details:

1. Re-read this checklist.
2. Run R2-0 algorithm (above).
3. If GO → proceed to R2-1 (disposable test project scaffold).
4. If STOP → apply remediation; re-run R2-0; do NOT skip ahead.
5. If WARN (sync skipped) → proceed without L-D-*; mark report.

Until the user provides worker/sync details, this file is the
authoritative "what is R2-0" reference. No live execution
happens.
