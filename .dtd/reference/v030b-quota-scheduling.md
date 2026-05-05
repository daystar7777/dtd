# DTD v0.3.0b — Token-rate-aware predictive routing runtime (R1 canonical reference)

## Anchor

This file is the canonical reference for v0.3.0b R1 runtime
contracts: detailed estimation algorithm, provider header parser
discipline, cross-run aggregation at finalize_run, TZ-aware reset
window computation, mid-run quota exhaust, capsule rendering. R0
spec lives in `run-loop.md` ## Quota predictive check + ledger
discipline (v0.3.0b R0); R0 step 5.5.0 has the high-level flow.

Per Codex v0.3 review (per-sub-release split pattern), this topic
hosts R1 wiring instead of expanding cross-cutting `run-loop.md`
past its lazy-load budget.

## Summary

R0 (commit `ea45960` + patches `19bf3f1`) shipped:
- Per-worker usage ledger (`worker-usage-run-NNN.md`) separate
  from controller ledger (Codex P1.2)
- Predictive routing at step 5.5.0 BEFORE permission gate
- Paid-fallback contract (Codex P1.3): permission-gated, never
  auto-routed
- WORKER_QUOTA_EXHAUSTED_PREDICTED capsule with 5 options
- `pause_overnight` shows TZ-aware reset time
- Provider-header capture as advisory, redacted

R1 ships the exact runtime algorithms:

1. **Estimation function** — `next_task_estimate(task, history, fallback)`
2. **Provider-header parser** — vendor-specific field parsing with redaction
3. **Cross-run finalize aggregation** — step 9.quota at finalize_run
4. **Reset window calculator** — TZ-aware daily / monthly resets
5. **Mid-run quota exhaust** — what happens when prediction was wrong
6. **Capsule rendering** — exact prompt format + decision_resume_action
7. **R1 doctor checks** — drift detection, tracker rotation, TZ mismatch

## 1. Estimation function (write-time + dispatch-time)

```
next_task_estimate(task, history, worker):
  # 1. Per-task historical mean (preferred — Codex P1 priority).
  matching = filter(history, by=(task.id, worker.id), where=ts > now - 7d)
  if len(matching) >= 3:
    return mean(matching.tokens_per_attempt) * worker.quota_safety_margin

  # 2. Plan-derived estimate.
  if task_has_plan_size_signal(task):
    ctx_files_size = sum(file_size_tokens(f) for f in task.context_files)
    system_prompt_size = system_prompt_tokens(worker)
    completion_size_estimate = task.expected_completion_tokens or DEFAULT_COMPLETION

    return (ctx_files_size + system_prompt_size + completion_size_estimate)
         * worker.quota_safety_margin

  # 3. Fallback (no plan estimate, no history).
  # Conservative multiplier — do NOT overload context-budget.default_failure_threshold
  # for this purpose (Codex P1 amendment).
  return DEFAULT_TASK_ESTIMATE_TOKENS * worker.quota_safety_margin
```

Variables:
- `DEFAULT_COMPLETION = 8000` tokens (config:
  `config.quota.estimation_default_completion_tokens`).
- `DEFAULT_TASK_ESTIMATE_TOKENS = 16000` tokens (config:
  `config.quota.estimation_default_task_tokens`).
- `worker.quota_safety_margin`: from worker registry (default 1.5
  via `config.quota.quota_safety_margin_default`).

### History pruning at finalize_run

The `.dtd/log/exec-*-ctx.md` source data is pruned per existing
v0.2.0f retention policy. R1 doctor check
`quota_estimation_history_thin` (INFO) fires when fewer than 3
matching rows exist for a frequently-dispatched (worker, task)
pair — informational only.

## 2. Provider-header parser

Vendor table for `x-ratelimit-*` / `ratelimit-*` headers (subset
that DTD recognises in R1):

| Provider | Header prefix | Remaining field | Reset field |
|---|---|---|---|
| Anthropic | `anthropic-ratelimit-` | `tokens-remaining` | `tokens-reset` |
| OpenAI | `x-ratelimit-` | `remaining-tokens` | `reset-tokens` |
| Together | `x-ratelimit-` | `remaining` | `reset` |
| Generic | `ratelimit-` | `remaining` | `reset` |

Parser is selected by `worker.quota_provider_header_prefix`. If
unset and headers present: try generic; if mismatch, log INFO
`quota_provider_header_unknown_format` and ignore the headers.

### Redaction discipline (Codex P1)

Captured fields:
- numeric `remaining` (tokens count)
- ISO timestamp `reset`

NEVER captured:
- raw header strings (may include account ids / request ids)
- auth headers, API keys, OAuth tokens
- session ids / cookie material
- request-id / trace-id values that could correlate to accounts

Redaction enforced at write time:
```
write_to_worker_usage_ledger(row, headers):
  remaining = parse_numeric(headers, vendor.remaining_field)
  reset_at  = parse_iso(headers, vendor.reset_field)
  row.provider_remaining = remaining          # int only
  row.source = "provider_header"
  # raw headers NEVER persisted
```

R1 doctor check `quota_provider_header_format_drift` (WARN)
fires if a header arrives with the configured prefix but the
expected field is missing — possible provider API change.

## 3. Cross-run aggregation (finalize_run step 9.quota)

NEW finalize_run step (between 5d cross-run loop guard and step 6
WORK_END). Codex P1.10 discipline (dedicated step, not nested).

### Algorithm

```
finalize_run_step_9_quota(run_id, now_local, user_tz):
  if not config.quota.cross_run_quota_persist:
    return  # no cross-run aggregation

  # 1. Read this run's per-worker usage.
  per_run = read_ledger(".dtd/log/worker-usage-run-{run_id}.md")
  per_worker_totals = group_sum(per_run, by="worker", field="prompt_actual + completion_actual")

  # 2. Read existing tracker.
  tracker = read_ledger(".dtd/log/worker-quota-tracker.md")

  # 3. Update daily rows (TZ-aware reset boundary).
  for worker, used in per_worker_totals:
    daily_window = compute_daily_window(worker, now_local, user_tz)
    daily_row = tracker.find_or_create(worker, daily_window)
    daily_row.tokens_used += used
    daily_row.last_run = run_id

  # 4. Update monthly (rolling 30-day) rows.
  for worker, used in per_worker_totals:
    monthly_window = compute_monthly_window(worker, now_local, user_tz)
    monthly_row = tracker.find_or_create(worker, monthly_window)
    monthly_row.tokens_used += used

  # 5. Archive expired daily rows.
  for daily_row in tracker.daily:
    if daily_row.window_end < now_utc:
      archive_to(".dtd/runs/quota-archive-{run_id}.md", daily_row)
      tracker.delete(daily_row)

  # 6. Update state.
  state.md.last_quota_check_at = now_utc()
  state.md.last_quota_reset_local_at = current_reset_boundary(user_tz)
  state.md.last_quota_reset_tz = user_tz
```

This step is observational w.r.t. permissions and incidents (no
v0.2.0a / v0.2.0b permission or incident mutation). It writes to
`.dtd/log/worker-quota-tracker.md`, the new
`.dtd/runs/quota-archive-*.md`, and the quota fields in
`.dtd/state.md`.

## 4. Reset window calculator (TZ-aware)

### Daily reset

```
compute_daily_window(worker, now_local, user_tz):
  reset_time_local = parse_local_time(worker.quota_reset_local_time, user_tz)
  # e.g. "00:00" + Asia/Seoul -> 00:00 KST today

  # If now_local >= today's reset_time: window starts today.
  # Else: window starts yesterday (prior reset, not yet rolled).
  if now_local.time() >= reset_time_local:
    window_start = today_at(reset_time_local, user_tz)
  else:
    window_start = yesterday_at(reset_time_local, user_tz)

  window_end = window_start + 24h

  return Window(start=window_start, end=window_end, tz=user_tz)
```

Worker registry field `quota_reset_local_time` defaults to
`"00:00"` (midnight in `user_tz`).

If worker explicitly sets a different `quota_reset_tz` (overrides
`user_tz`): the window uses `worker.quota_reset_tz` instead.
Doctor `quota_reset_tz_mismatch` (INFO) flags when worker
`quota_reset_tz` ≠ `state.md.user_tz` — informational; this is a
valid configuration (e.g. worker hosted in EU, user in JP).

### Monthly (rolling) reset

```
compute_monthly_window(worker, now_local, user_tz):
  window_days = worker.quota_reset_window_days or 30
  window_end = now_local
  window_start = window_end - timedelta(days=window_days)
  return Window(start=window_start, end=window_end, tz=user_tz)
```

Rolling, not calendar-aligned. Calendar-month support deferred
(v0.3.x).

### Capsule reset_at_local rendering

`pause_overnight` capsule option computes:

```
reset_at_local = next_daily_reset_boundary(worker, now_local, user_tz)
display = format_localized(reset_at_local, user_tz)
# e.g. "2026-05-06 00:00 KST [Asia/Seoul]"
```

R1 doctor `quota_pause_overnight_tz_missing` (R0 already, ERROR)
covers the case where worker has no reset_local_time and capsule
falls back to UTC.

## 5. Mid-run quota exhaust (prediction was wrong)

R0 only checks at step 5.5.0 (BEFORE dispatch). If the worker's
actual usage exceeds prediction during the call, the response
will likely be truncated or the provider will return 429.

R1 handling:

```
on_dispatch_response(response, worker):
  # Append actual usage to worker-usage-run-NNN.md FIRST.
  append_usage_row(...)

  if response.status == 429 OR provider_quota_exceeded(response):
    # Mid-run exhaust detected.
    record_attempt_failure(reason = "WORKER_QUOTA_ACTUAL_EXCEEDED")
    fill_capsule(
      reason = "WORKER_QUOTA_EXHAUSTED_PREDICTED",   # same reason; suffix differentiates
      pending_quota_capsule = {...},
      mid_run_actual_exceeded = true,                 # NEW R1 flag
    )
    state.md.mid_run_actual_exceeded_count += 1
    state.md.plan_status = "PAUSED"
    state.md.awaiting_user_decision = true
    return  # block before apply; resume follows the quota decision capsule
```

The `mid_run_actual_exceeded` flag in `pending_quota_capsule`
distinguishes mid-run from pre-dispatch (different decision
options may be appropriate — e.g. `extend_quota` is more useful
than `pause_overnight` if user is actively driving).

## 6. Capsule rendering (R1 contract)

R0 specified the YAML schema; R1 specifies rendering rules.

### Prompt template

```
Worker quota near limit:
  {worker_a}: {used_pct_a}% of {quota_a} ({reset_at_local_a})
  {worker_b}: {used_pct_b}% of {quota_b} ({reset_at_local_b})

How to proceed?
```

For ALL workers in fallback chain near-empty (last-resort
state): prompt becomes:

```
ALL fallback workers near quota limit:
  {worker_a}: {used_pct_a}%
  {worker_b}: {used_pct_b}%
  ... [N total]

Default: pause_overnight (until {reset_at_local} {tz}).
```

### `decision_resume_action` execution map

| Option | On `/dtd run` resume |
|---|---|
| `extend_quota` | re-read worker config; if `quota` increased, re-evaluate. Else re-fill same capsule. |
| `switch_to_paid` | append `allow task scope: paid_fallback worker: <id>` rule (audit by: user); proceed with paid worker. |
| `continue_unsafe` | dispatch with current worker; mid-run exhaust likely; not gated. |
| `pause_overnight` | wait for `reset_at_local`; on resume tick, recompute quota and proceed automatically if recovered. |
| `stop` | finalize_run(STOPPED). |

`pause_overnight` is the conservative default. R1 doctor
`quota_pause_overnight_resume_tick_missing` (INFO) fires when a
paused run has no scheduled wake-up tick (host-dependent).

## 7. R1 acceptance scenarios

> Scenario numbers 158-165 (next free range after v0.3.0e R1
> 150-157). See `test-scenarios.md` ## v0.3.0b R1 — Token-rate-aware
> scheduling runtime.

```
158. Estimation: 3+ history rows -> per-task mean used; <3 rows ->
     plan-derived; no plan info -> conservative fallback (Codex P1).
159. Provider header: vendor-specific prefix selects parser;
     unknown prefix -> INFO + ignore headers.
160. Provider header redaction: only numeric remaining + ISO reset
     captured; raw header bytes NEVER persisted.
161. Cross-run aggregation: finalize_run step 9.quota updates daily
     row; expired rows archived to .dtd/runs/quota-archive-NNN.md.
162. TZ-aware reset boundary: worker quota_reset_local_time + user_tz
     computes correct window; rolling 30-day for monthly.
163. Mid-run exhaust (prediction wrong): 429 response triggers
     WORKER_QUOTA_EXHAUSTED_PREDICTED capsule with
     mid_run_actual_exceeded=true flag; run halts at finalize_run.
164. Capsule rendering: prompt shows used_pct + reset_at_local for
     each near-quota worker; pause_overnight option shows tz-aware
     local time.
165. Resume tick: pause_overnight default + scheduler resumes at
     reset_at_local; quota recomputed; proceeds if recovered.
```

## 8. R1 doctor checks (additional)

```
- quota_estimation_history_thin (INFO)
    Fewer than 3 matching exec-*-ctx history rows for a frequently-
    dispatched (worker, task) pair. Estimation falls through to
    plan-derived; check is informational.

- quota_provider_header_format_drift (WARN)
    Header arrived with configured prefix but expected field
    missing. Possible provider API change; check vendor table.

- quota_provider_header_unknown_format (INFO)
    Header prefix configured but field names don't match any known
    vendor. Headers ignored; estimation uses dispatch_response only.

- quota_reset_tz_mismatch (INFO)
    worker.quota_reset_tz != state.md.user_tz. Valid configuration
    (worker hosted in different region than user); informational.

- quota_pause_overnight_resume_tick_missing (INFO)
    pause_overnight chosen but no scheduled wake-up tick configured
    (host-dependent). User may need to manually re-run /dtd run.

- quota_finalize_aggregation_skipped (INFO)
    config.cross_run_quota_persist: false; quota tracker not
    updated at finalize_run. Cosmetic.

- quota_archive_overflow (WARN)
    .dtd/runs/quota-archive-*.md count > 50. Recommends purge.
```

## 9. Migration

R1 is a runtime contract; it adds these state fields:

```
state.md (additional):
- last_quota_estimation_source: null  # R1; per_task_history | plan_derived | conservative
- mid_run_actual_exceeded_count: 0    # R1; counter of mid-run 429s in current run
```

Config additions (under existing `## quota`):

```
- estimation_default_completion_tokens: 8000  # R1; per-task completion estimate fallback
- estimation_default_task_tokens: 16000       # R1; full-task estimate fallback
- quota_archive_max_files: 50                 # R1; doctor WARN above
```

Permission keys: NO new key. 11-key invariant from v0.3.0c remains
stable. Mutating quota commands gated under existing
`tool_relay_mutating`.
