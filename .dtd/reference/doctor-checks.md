# DTD reference: doctor-checks

> Canonical reference for `/dtd doctor` health-check command.
> Lazy-loaded via `/dtd help doctor-checks --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

`/dtd doctor` runs all checks across the v0.2 line. Output uses the same
Unicode/ASCII style as `/dtd status`. Exit code on slash hosts: `0` if
all checks pass, `1` if any ERROR-level issue.

Sections:
- Install integrity
- Mode consistency
- Worker registry
- agent-work-mem
- Project context
- Resource state
- Plan state
- Autonomy & Attention state (v0.2.0f)
- Context-pattern state (v0.2.0f)
- Incident state (v0.2.0a)
- Self-Update state (v0.2.0d)
- Help system (v0.2.0d)
- Spec modularization (v0.2.3 R0/R1)
- Path policy
- `.gitignore` + secret leak

## Install integrity

- DTD install: all 15 `.dtd/` committed template files + `dtd.md` present.
  Committed templates: `instructions.md`, `config.md`,
  **`workers.example.md`** (schema reference; `workers.md` is a generated,
  gitignored local registry — see Worker Registry checks below),
  `worker-system.md`, `resources.md`, `state.md`, `steering.md`,
  `phase-history.md`, `PROJECT.md`, `notepad.md`, `.gitignore`,
  `.env.example`, plus 3 `skills/*.md`.
- Local registry: `.dtd/workers.md` exists (created from `workers.example.md`
  at install if missing; gitignored).
- Host always-read pointer: present and references `.dtd/instructions.md`.
- `dtd.md` present at host slash command dir (Claude Code:
  `.claude/commands/dtd.md`, etc.).

## Mode consistency

- `.dtd/state.md` has `mode: off|dtd` (DTD activation, separate from host
  capability).
- `.dtd/state.md` has valid `host_mode: plan-only|assisted|full`.
- `.dtd/config.md` `host.mode` matches `state.md host_mode`.
- Probed capabilities currently match the recorded `host_mode` (re-detect
  available).

## Worker registry

- `.dtd/workers.example.md` exists (committed schema reference).
- `.dtd/workers.md` exists locally (gitignored user registry; if missing
  → ERROR with hint: `cp .dtd/workers.example.md .dtd/workers.md` or
  rerun install).
- `workers.md` parses; only H2 sections under "## Active registry"
  heading count as registry.
- Disabled (`enabled: false`) entries reported but skipped in routing.
- Alias collisions: worker alias vs other worker, alias vs role,
  alias/display_name vs `controller.name`.
- Reserved word usage rejected (`controller, user, worker, self, all,
  any, none, default`).
- Threshold consistency: `failure_threshold` is positive int per worker.
- `escalate_to` chain: no cycles, terminates at `user`.
- Capabilities reasonable: at least one worker for each role declared
  in `config.md` `roles`.
- Endpoint URL sanity: not literally `localhost` if user expects
  multi-machine access (INFO, suggest LAN IP / Tailscale — see
  workers.example.md).
- If active registry empty: WARN, recommend `/dtd workers add` or
  paste from `workers.example.md`.

## agent-work-mem

- Detected (`AIMemory/PROTOCOL.md` + `INDEX.md` + `work.log` all exist)
  → INFO "integrated".
- Absent → INFO "not installed; recommended for multi-session
  continuity" (do NOT block).

## Project context

- `.dtd/PROJECT.md` is not pure-TODO: parse for `(TODO:`. If TODO-only
  AND `host_mode` is `assisted` or `full`: WARN.
- `.dtd/PROJECT.md` size ≤ 8 KB: ERROR if larger (capsule too big for
  prompt prefix).

## Resource state

- Stale leases in `resources.md` (heartbeat_at older than
  `stale_threshold` minutes): WARN per stale lease, suggest `--takeover`
  after user confirm.
- Orphaned lock dropfiles (e.g. leftover `.dtd/.dtd.lock`): WARN.

## Plan state

- `state.md` `plan_status` matches plan file existence and content.
- Active plan size ≤ 24 KB hard cap (12 KB preferred): WARN if over
  preferred, ERROR if over hard.
- `pending_patch: true` consistency with `<patches>` section in
  plan-NNN.md.
- No orphan WORK_START in AIMemory without matching state in
  `.dtd/state.md`.

## Autonomy & Attention state (v0.2.0f)

- `decision_mode` is one of `plan|permission|auto`; ELSE ERROR
  `decision_mode_invalid`. Pre-v0.2.0f installs missing the field →
  INFO `decision_mode_default_assumed`, treat as `permission`.
- `attention_mode` is one of `interactive|silent`; ELSE ERROR
  `attention_mode_invalid`. Pre-v0.2.0f installs missing the field →
  INFO `attention_mode_default_assumed`, treat as `interactive`.
- If `attention_mode: silent`: `attention_until` MUST be a future
  timestamp; ELSE WARN `silent_window_expired_but_state_not_flipped`
  and recommend `/dtd interactive`.
- If `attention_mode: silent`: `attention_until - now` ≤
  `config.attention.silent_max_hours`; ELSE ERROR
  `silent_window_exceeds_max`.
- `deferred_decision_refs` entries: every id MUST resolve to an
  existing `.dtd/log/incidents/inc-*.md` file with `status: open` AND
  a `deferred_capsule:` key; ELSE ERROR `deferred_ref_invalid`.
- `deferred_decision_count` MUST equal `len(deferred_decision_refs)`;
  ELSE ERROR `deferred_count_mismatch`.
- `deferred_decision_count` ≤
  `config.attention.silent_deferred_decision_limit`; ELSE WARN
  `deferred_limit_breached_invariant` (rule 5 of silent algorithm
  should have already flipped `plan_status: PAUSED` — this WARN
  catches the gap).
- If `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`, decision
  capsule MUST contain options
  `[wait_reset, switch_host_model, compact_and_resume, stop]`; ELSE
  ERROR `capsule_options_invalid`.

## Context-pattern state (v0.2.0f)

- `resolved_context_pattern` (when non-null) is one of
  `fresh|explore|debug`; ELSE ERROR `context_pattern_invalid`.
- `resolved_handoff_mode` (when non-null) is one of
  `standard|rich|failure`; ELSE ERROR `handoff_mode_invalid`.
- If `plan_status: RUNNING` AND `current_task` non-null:
  `resolved_context_pattern` MUST be non-null; ELSE WARN
  `running_task_missing_context_resolution`.
- Plan XML `context-pattern` attribute (when present) MUST be one of
  `fresh|explore|debug`; ELSE ERROR `plan_context_pattern_invalid`.
- `config.md context_patterns` MUST have entries for `fresh`, `explore`,
  `debug`; ELSE ERROR `context_patterns_config_missing`.
- Plan XML `persona` attribute (when present) MUST resolve to
  `config.md persona_patterns`; ELSE ERROR `plan_persona_invalid`.
- Plan XML `reasoning-utility` attribute (when present) MUST resolve to
  `config.md reasoning_utilities`; ELSE ERROR
  `plan_reasoning_utility_invalid`.
- `config.md tool-runtime.default_worker_tool_mode` MUST be one of
  `none|controller_relay|worker_native|hybrid`; ELSE ERROR
  `tool_runtime_invalid`.
- ctx file count vs attempt count: count
  `.dtd/log/exec-<run>-task-*-ctx.md` files vs attempt count in
  `.dtd/attempts/run-<run>.md` for the active run; report ratio as
  INFO. Mismatch is not blocking (silent installs without v0.2.0f
  workers don't write ctx files).

## Incident state (v0.2.0a)

- If `active_incident_id` is non-null, corresponding
  `.dtd/log/incidents/inc-*.md` file MUST exist; ELSE ERROR
  `incident_file_missing`.
- `active_blocking_incident_id` (if non-null) MUST equal an open
  blocking-severity incident; ELSE ERROR `blocking_incident_invalid`.
- At most ONE `active_blocking_incident_id` at a time (multi-blocker
  invariant); ELSE ERROR `multi_blocker_invariant_violated`.
- All failed/blocked attempts in `.dtd/attempts/run-NNN.md` MUST
  cross-link to a valid incident id; ELSE WARN
  `attempt_incident_link_missing`.
- All open incidents MUST have valid `recoverable` (`yes|user|no`)
  and `side_effects`
  (`none|request_saved|response_saved|partial_apply|unknown`); ELSE
  ERROR `incident_field_invalid`.
- Incident detail files in `.dtd/log/incidents/` should not contain
  secret patterns (regex scan); ELSE ERROR `incident_secret_leak`.
- Total open-incident count > 100 → INFO suggesting
  `/dtd incident list --all` review or v0.3 prune command (deferred).

## Self-Update state (v0.2.0d)

- `state.md.installed_version` is non-null and matches a tagged
  release format (e.g. `v0.2.0d`); ELSE INFO
  `installed_version_unrecorded` (legitimate for pre-v0.2.0d installs
  upgrading via first `/dtd update`).
- `state.md.update_in_progress: false` between actual update
  operations; ELSE WARN `update_lock_held` (auto-clear after
  `stale_threshold_min * 6` per stale-takeover policy — default
  30 min).
- If `state.md.update_in_progress: true` for > 30 min: WARN
  `update_lock_stuck`, recommend `/dtd doctor --takeover`.
- `MANIFEST.json` exists at repo root if installed via v0.2.0d-aware
  bootstrap; ELSE INFO `manifest_absent_will_fetch` (acceptable).
- If `MANIFEST.json` exists: parses as valid JSON with required
  fields (`version`, `tagged_at`, `manifest_format_version`,
  `files[]`); ELSE ERROR `manifest_invalid`.
- If `MANIFEST.json` exists: `manifest.version` matches
  `state.md.installed_version`; ELSE WARN `manifest_version_drift`.
- `state.md.update_check_at` if non-null parses as timestamp; ELSE
  WARN `update_check_at_invalid`. Do not require freshness here:
  `/dtd update check` is observational and does not refresh durable
  state.
- `.dtd.backup-*-<ts>/` directories older than
  `config.update.backup_retention_days` (default 7); INFO
  recommending purge.

## Help system (v0.2.0d)

- `.dtd/help/` directory exists; ELSE WARN `help_dir_missing`
  (graceful — `/dtd help` falls back to dtd.md anchor lookup).
- All 9 canonical topics have `.dtd/help/<topic>.md` files
  (start, observe, recover, workers, stuck, update, plan, run,
  steer); ELSE WARN `help_topic_missing: <topic>`.
- `.dtd/help/index.md` exists and is ≤ 1 KB; ELSE WARN.
- Each topic file ≤ 2 KB; ELSE WARN `help_topic_oversized: <topic>`.
- Default help body (rendered from index.md Summary section) ≤ 25
  lines; topic help ≤ 50 lines (line-budget INFO; not blocking).

## Permission ledger (v0.2.0b)

- `.dtd/permissions.md` exists and parses; ELSE INFO
  `permission_ledger_missing` (default rules from spec apply until
  the file is created).
- All `## Active rules` entries have valid
  `<ts> | <decision> | <key> | scope: <expr> [...] | by: <who>` format;
  ELSE ERROR `permission_rule_invalid` with line ref.
- Permission keys MUST be one of
  `edit | bash | external_directory | task | snapshot | revert |
  tool_relay_read | tool_relay_mutating | todowrite | question |
  task_consensus` (11-key set as of v0.3.0c; was 10-key in
  v0.2.0b R1); ELSE ERROR `permission_key_unknown`.
- Decisions MUST be one of `allow | deny | ask`; ELSE ERROR
  `permission_decision_invalid`.
- No active rule allows `bash` with overly-broad scope (`*`, `/**`,
  empty, or single token like `bash`); ELSE WARN
  `permission_bash_too_broad`. Recommend narrowing to specific
  command(s).
- No active rule allows `external_directory` with `*` scope; ELSE
  WARN `permission_external_directory_too_broad`.
- Overlapping deny+allow rules: WARN `permission_rule_overlap`. Runtime
  resolves matching rules by scope specificity first and timestamp second, so
  the warning is for auditability/user clarity rather than ambiguity.
- Active rules referencing non-existent workers: WARN
  `permission_rule_unknown_worker`.
- `until` timestamps in past: INFO `permission_rule_expired` (rule
  is effectively absent; recommend explicit revoke for clarity).
- File size > 32 KB: WARN `permission_ledger_too_large` (recommend
  purge expired rules; also signals possibly-noisy permission flow).
- `state.md.pending_permission_request` non-null but no matching
  `awaiting_user_decision: true` capsule with reason
  `PERMISSION_REQUIRED`: WARN `permission_pending_orphan`.
- `.dtd/log/permissions.md` (audit log) exists when any active rule
  exists; ELSE INFO (audit log lazy-created on first decision).

### v0.2.0b R1 wiring checks

- Audit log row format: every line in
  `.dtd/log/permissions.md` matches
  `<ts> | <dec_id> | <key> | <scope> | rule_match: ... | decision: ...`;
  ELSE WARN `permission_audit_row_invalid` with line ref.
- Audit log size > 32 KB → WARN `permission_audit_log_too_large`
  recommending purge of resolutions older than 30 days.
- Audit row count exceeds active-rules count by > 100×: INFO
  `permission_audit_high_volume` (suggests reviewing
  `permission_bash_too_broad` patterns).
- Audit row references unknown rule timestamp: WARN
  `permission_audit_rule_drift`.
- `state.md.silent_window_transient_rule_ids` consistency:
  every id MUST correspond to a `## Active rules` row with
  `by: silent_window`; ELSE WARN
  `silent_window_transient_drift`.
- If `state.md.attention_mode: interactive` AND
  `silent_window_transient_rule_ids` is non-empty: WARN
  `silent_window_transient_orphan` (transient rules survived
  past silent window without revoke; recommend
  `/dtd doctor --takeover`).
- `## Active rules` rows with `by: silent_window` AND past
  `until` timestamp: INFO
  `silent_window_transient_expired_unrevoked` (rule effectively
  inactive but tombstone not added; cosmetic).

### v0.3.0c Consensus state checks

- Plan XML `consensus="<N>"` attributes: N >= 1; ELSE ERROR
  `plan_consensus_invalid`.
- Plan XML `consensus="<N>"` AND N > `config.max_consensus_n`
  (default 5): ERROR `plan_consensus_exceeds_max`.
- `consensus-strategy` ∈
  `first_passing | quality_rubric | reviewer_consensus |
  vote_unanimous`; ELSE ERROR `plan_consensus_strategy_invalid`.
- `consensus-strategy="reviewer_consensus"` requires
  `consensus-reviewer="<worker>"`; ELSE ERROR
  `plan_consensus_reviewer_missing`.
- `consensus-reviewer` MUST be DISTINCT from all
  `<consensus-workers>` entries (no self-review per Codex P1
  additional); ELSE ERROR
  `plan_consensus_reviewer_in_candidate_set`.
- `<consensus-workers>` entries must exist in registry; ELSE
  ERROR `plan_consensus_unknown_worker`.
- `state.md.active_consensus_task` non-null AND no
  `attempts/run-NNN.md` rows match the active consensus group:
  WARN `consensus_state_drift`.
- Consensus loser attempt rows have `applied: true`: ERROR
  `consensus_loser_applied_violation` (Codex P1.4: only
  winner may apply; losers MUST NOT).
- Late-stale attempt rows have `applied: true`: ERROR
  `consensus_late_stale_applied_violation` (Codex P1.4: late
  results MUST NEVER apply).
- 11-key permission set: `task_consensus` present in
  `.dtd/permissions.md` `## Default rules`; ELSE ERROR
  `permission_task_consensus_missing` (v0.3.0c invariant).
- Consensus group lock held during 6.consensus dispatch (single
  lock for N workers; not per-worker); ELSE WARN
  `consensus_per_worker_lock_violation` (acquired wrong lock
  shape).

### v0.3.0d Cross-machine session sync checks

- Backend != `none` AND env var named in
  `config.session_sync.encryption_key_env` is unset / empty:
  ERROR `session_sync_no_encryption_key`. Sync is **disabled** for
  the run; controller falls back to v0.2.1 per-machine behavior
  (Codex P1.6: missing key MUST be ERROR, not WARN with plaintext
  fallback).
- Backend = `filesystem` AND `config.session_sync.sync_path`
  missing or not writable: ERROR `session_sync_path_invalid`.
- Backend = `git_branch` AND `config.session_sync.sync_branch`
  does not exist locally: WARN `session_sync_branch_missing`.
- Backend != `none` AND `.dtd/session-sync.md` contains rows but
  `.dtd/session-sync.encrypted` is missing: ERROR
  `session_sync_plaintext_violation` (synced ledger would leak
  raw session metadata; Codex P1.6 invariant violation).
- `state.md.session_sync_pending_conflicts` non-empty: WARN
  `session_sync_unresolved_conflicts` recommending
  `/dtd session-sync show`.
- `.dtd/session-sync.md` rows where `expires_at < now`: INFO
  `session_sync_expired_rows_pending`.
- `repo_identity_hash` falls through to TERTIARY (absolute path)
  when sync is enabled: WARN
  `session_sync_repo_identity_unstable` recommending
  `state.md.project_id` set or git remote configured.
- Backend != `none` AND `state.md.machine_id` is null: ERROR
  `session_sync_machine_id_missing` (auto-generated at install;
  null means migration drift).
- Last sync attempt logged a connectivity failure (network
  unreachable, push rejected, sync path missing): WARN
  `session_sync_unreachable` (runtime, not static; logged in
  `.dtd/log/run-NNN-summary.md`; does NOT block dispatch — Codex
  additional amendment).

### v0.3.0a Cross-run loop guard checks

- `.dtd/cross-run-loop-guard.md` exists if
  `config.cross_run_loop_guard_enabled: true`; ELSE INFO
  `cross_run_ledger_missing` (lazy-created on first
  finalize_run capture-before-clear).
- Each row matches format
  `<first_seen> | <signature> | <run_count> | <last_seen> | <last_resolution> | <by>`;
  ELSE WARN `cross_run_ledger_row_invalid` with line ref.
- Total active (non-tombstoned) signatures ≤
  `config.cross_run_max_signatures` (default 500); ELSE WARN
  `cross_run_ledger_overflow` recommending purge.
- Signatures with `last_seen` past
  `config.cross_run_retention_days` AND no tombstone: INFO
  `cross_run_signature_expired_unpruned` recommending
  `/dtd loop-guard prune --before <retention_cutoff>`.
- `state.md.pending_cross_run_signature` non-null AND
  `awaiting_user_decision: false`: WARN
  `cross_run_pending_orphan` (capsule didn't fill;
  recover with `/dtd doctor --takeover`).
- `state.md.cross_run_loop_guard_status` ∈
  `idle | watching | hit`; ELSE ERROR
  `cross_run_status_invalid`.
- Within-run `loop_guard_signature_count` was >= 1 at last
  finalize but no matching cross-run row appended: WARN
  `cross_run_finalize_capture_missed` (capture-before-clear
  step 5d didn't run).
- Cross-run row references unknown failure_class enum: WARN
  `cross_run_failure_class_unknown`.
- `state.md.project_id` non-null when
  `cross_run_loop_guard_enabled: true`; ELSE INFO
  `project_id_unset_using_fallback` (using git remote OR path
  fallback per `repo_identity_hash` priority).

### v0.3.0b Token-rate-aware scheduling checks

- For workers with `daily_token_quota: <int>`, the per-run
  worker-usage ledger should have a row for the current day;
  ELSE INFO `quota_no_data_today` (acceptable for fresh runs).
- Per-worker daily usage > `quota_warn_threshold_pct`
  (default 80%): WARN `quota_warn_<worker>`.
- Per-worker daily usage > `quota_block_threshold_pct`
  (default 95%): WARN `quota_block_pending_<worker>` (next
  dispatch will trigger predictive capsule).
- `state.md.pending_quota_capsule` non-null AND
  `awaiting_user_decision: false`: WARN `quota_pending_orphan`.
- `.dtd/log/worker-usage-run-NNN.md` rows should have only
  redacted advisory data (no raw token values, no auth
  headers): ERROR `quota_audit_secret_leak`.
- Provider-header capture: if
  `worker.quota_provider_header_prefix` is set, response
  rows from that worker should populate `provider_remaining`;
  ELSE INFO `quota_provider_header_unused`.
- Cross-run quota tracker file size > 64 KB: WARN
  `quota_tracker_oversized` recommending purge of old daily
  rows.
- `pause_overnight` capsule prompts MUST include exact local
  reset time + timezone; ELSE WARN
  `quota_pause_overnight_tz_missing` (Codex P1.3).
- Paid-fallback in silent mode: if a `WORKER_QUOTA_EXHAUSTED_PREDICTED`
  capsule auto-resolved to `switch_to_paid` without an explicit
  user `allow task scope: paid_fallback` rule: ERROR
  `quota_paid_fallback_unauthorized` (Codex P1.3).

### v0.3.0e Time-limited permissions checks

- For every `## Active rules` row with `until` field in
  duration form (`+<int><m|h|d|w>`) or named-scope form
  (`today | eod | this-week | next-monday | next-week | run |
  run_end`): `resolved_until` MUST be derived; ELSE WARN
  `permission_until_unresolved`.
- Legacy v0.2.0b rules (`until: <ISO ts>` only, no
  `resolved_until` derived field): INFO
  `permission_until_unresolved_legacy_v020b` recommending
  re-write to populate derived field.
- `resolved_until: run_end` rules MUST be tombstoned by
  `finalize_run` step 5c after each terminal exit. If a
  `run_end` row exists AND `state.md.plan_status` is null OR
  COMPLETED/STOPPED/FAILED AND no matching tombstone:
  WARN `permission_run_end_orphaned_after_finalize`.
- `resolved_until_tz` REQUIRED for named local-time scopes
  (today/eod/this-week/next-monday/next-week); ELSE WARN
  `permission_until_tz_missing` (cross-machine sync v0.3.0d
  cannot interpret unambiguously).
- Combined-unit `for` rules (e.g. `for 1h30m`) detected at
  parse time: ERROR
  `permission_duration_combined_unsupported_v030e`.
- Mixed `for X until Y` rules: ERROR
  `permission_duration_until_mixed_unsupported`.
- `state.md.active_time_limited_rule_count` should match
  count of non-tombstoned time-limited rows in
  `## Active rules`; ELSE WARN
  `permission_time_limited_count_drift`.
- `state.md.last_permission_prune_at` is non-null after the
  first finalize_run step 5c; ELSE INFO
  `permission_finalize_prune_unrun` (acceptable for fresh
  installs).

## Worker health + runtime resilience (v0.2.1)

### Worker health check freshness

- `.dtd/log/worker-checks/` directory exists if any `--quick`/`--full`
  has been run; ELSE INFO `worker_check_history_missing` (acceptable
  for fresh installs).
- Worker check history retention ≤
  `config.worker-test.worker_test_history_retention` (default 20);
  ELSE INFO `worker_check_history_overflow` recommending purge.
- Each worker-check log has redacted artifacts only — no env values,
  no auth headers, no full request/response body for failed auth;
  ELSE ERROR `worker_check_secret_leak`.
- If `config.worker-test.worker_test_auto_before_run: assigned_only`:
  every `/dtd run` start should produce a worker-check log entry
  for assigned workers; if no entry within the last 24 h: INFO
  `worker_check_preflight_overdue`.
- Worker registry entries with `tool_runtime: worker_native|hybrid`
  AND `native_tool_sandbox: true` should have a recent
  `native_tool_sandbox_check` PASS in `.dtd/log/worker-checks/`;
  ELSE WARN `worker_native_sandbox_unverified`.

### Worker session resume

- `state.md.last_resume_strategy` (when non-null) MUST be one of
  `fresh | same-worker | new-worker | controller-takeover`; ELSE
  ERROR `resume_strategy_invalid`.
- If `state.md.last_worker_session_id` non-null:
  `last_worker_session_provider` MUST also be non-null; ELSE WARN
  `resume_session_orphan`.
- Worker registry entries with `supports_session_resume: true` MUST
  declare a known provider family; ELSE INFO
  `resume_provider_unknown` (default `fresh` strategy will apply).

### Loop guard

- `state.md.loop_guard_status` is one of `idle|watching|hit`; ELSE
  ERROR `loop_guard_status_invalid`.
- If `loop_guard_status: hit`: `awaiting_user_decision: true` AND
  `awaiting_user_reason: LOOP_GUARD_HIT` MUST be set; ELSE WARN
  `loop_guard_orphan` (controller did not fill capsule; resume
  hint: `/dtd doctor --takeover` or manual reset).
- `state.md.loop_guard_signature_count` ≤
  `config.loop-guard.loop_guard_threshold` while
  `loop_guard_status: watching`; ELSE WARN
  `loop_guard_count_overflow`.
- `state.md.loop_guard_last_check_at` not older than
  `config.loop-guard.loop_guard_signature_window_min`; staler
  signatures should have been reset; ELSE INFO
  `loop_guard_signature_stale`.
- `loop_guard_signature_count` matches actual consecutive same-signature
  attempts in `attempts/run-NNN.md`; ELSE WARN
  `loop_guard_count_drift`.

### v0.2.1 R1 wiring checks

- Worker-check log redaction: no env values, no auth headers, no
  20+ char key-pattern matches; ELSE ERROR
  `worker_check_redaction_violated`.
- Stage sequence: stages 1-5 FAIL ⇒ no stages 6+ logged; ELSE
  INFO `worker_check_stage_sequence_drift`.
- Mock probe cleanup: `.dtd/tmp/healthcheck-sentinel.txt` should
  not persist post-test; ELSE INFO
  `worker_check_mock_artifact_orphan`.
- `resume_strategy` ∈ `fresh | same-worker | new-worker |
  controller-takeover`; ELSE ERROR
  `attempt_resume_strategy_invalid`.
- `resume_of` references existing attempt row; ELSE WARN
  `attempt_resume_lineage_broken`.
- `resume_strategy: same-worker` rows must not include raw
  prior worker output inline; ELSE ERROR
  `same_worker_resume_raw_output_leak`.
- `loop_guard_signature_first_seen_at` older than window when
  `signature_count > 1`: WARN `loop_guard_window_stale_unreset`.
- Auto-action explicit-config consistency: INFO
  `loop_auto_action_config_documented` verifying
  `decision_mode: auto` does NOT auto-resolve `threshold_action:
  ask` capsule.

## Notepad schema (v0.2.2)

- `.dtd/notepad.md` parses (markdown well-formed); ELSE WARN
  `notepad_parse_error` with line ref.
- Schema detection: first H2 is `## handoff` AND H3 children
  include `### Goal` → schema v2; else schema v1.
- Schema v1: INFO `notepad_schema_v1` recommending update to v2
  via `/dtd update` Amendment 9 migration.
- Schema v2: all 8 expected H3 headings present under `## handoff`
  (Goal / Constraints / Progress / Decisions / Next Steps /
  Critical Context / Relevant Files / Reasoning Notes); ELSE WARN
  `notepad_v2_missing_heading: <heading>`.
- Per-heading content size ≤ 2× budget (e.g. Reasoning Notes ≤
  400 chars); ELSE WARN `notepad_heading_oversized: <heading>`
  recommending `/dtd notepad compact`.
- Total `## handoff` size ≤ 2 KB (2× the 1.2 KB worker-visible
  budget; allows buffer for non-worker-visible content); ELSE
  WARN `notepad_handoff_oversized`.
- Reasoning Notes content discipline: heuristic scan for
  chain-of-thought leakage. Ignore template guidance/comment lines
  (Markdown blockquotes beginning with `>`). Warn when an actual entry
  contains private-reasoning trigger phrases, or when an entry combines
  step-by-step/narrative wording with multi-paragraph blocks > 5 lines.
  A simple "step 1 / step 2" checklist alone is not enough to warn.
  ELSE WARN `reasoning_notes_chain_of_thought_leak` with line ref.
- `Reasoning Notes` heading exists in v2 schema notepad; ELSE WARN
  `notepad_v2_missing_reasoning_notes`.

### v0.2.2 R1 wiring checks

- `state.md.last_compaction_at` non-null when notepad has been
  edited recently (controller-recent-edit heuristic); ELSE INFO
  `notepad_compaction_unrun`.
- `state.md.last_compaction_reason` ∈
  `phase_boundary | manual | finalize_run`; ELSE WARN
  `notepad_compaction_reason_invalid`.
- `compaction_warns_run` > 5 → INFO
  `notepad_compaction_warn_high` (handoff repeatedly oversized;
  user may need to reduce content).
- Reasoning utility post-processing: if any
  `attempts/run-NNN.md` row has
  `resolved_reasoning_utility: <non-null>`, the corresponding
  notepad `### Reasoning Notes` should have an entry within the
  same phase; ELSE INFO `reasoning_utility_no_capsule_capture`.
- Chain-of-thought redaction trail: if `## handoff` shows
  `[redacted: reasoning narrative removed per output discipline]`
  placeholder, count occurrences. > 3 in current run: WARN
  `reasoning_redaction_high` (worker is repeatedly violating
  output discipline; recommend `/dtd workers test --full` to
  verify protocol compliance).
- Reasoning rollover to learnings: if `### Reasoning Notes` has
  > 3 entries (the keep-last-3 invariant should prevent this):
  WARN `reasoning_notes_overflow_unrolled`.

## Snapshot state (v0.2.0c)

- `.dtd/snapshots/` directory exists if
  `config.snapshot.enabled: true`; ELSE INFO `snapshot_dir_missing`
  (creates on next apply).
- `.dtd/snapshots/index.md` exists with `## Active snapshots` section;
  ELSE WARN `snapshot_index_missing`.
- All `index.md` rows have matching `snap-<run>-<task>-<att>/`
  directories under `.dtd/snapshots/` or
  `.dtd/snapshots/archived/`; ELSE WARN `snapshot_index_drift`.
- All `snap-*/` directories have a valid `manifest.md` with required
  fields (`run`, `task`, `attempt`, `worker`, `applied_at`,
  `mode_default`); ELSE WARN `snapshot_manifest_missing`.
- Total snapshot dir size ≤
  `config.snapshot.max_total_size_mb` (default 512 MB); ELSE WARN
  `snapshot_size_exceeded` and recommend `/dtd snapshot rotate` or
  `purge --before <date>`.
- Snapshots older than `retention_days * 2` and not in `archived/`:
  INFO `snapshot_rotation_overdue`.
- Each `preimage` artifact's SHA-256 matches its manifest entry, OR the
  manifest explicitly marks an absent-prestate marker for a newly-created
  output path; ELSE ERROR `snapshot_preimage_corrupted`.
- Each `patch` artifact applies cleanly to current working state via
  dry-run; ELSE WARN `snapshot_patch_drift` (means another process
  modified the file after apply; revert may not produce expected
  state).
- `state.md.last_snapshot_id` matches the most recent
  `snap-*/manifest.md` `applied_at` row; ELSE WARN
  `snapshot_state_drift`.
- `state.md.last_revert_id` (when non-null) corresponds to a
  snapshot whose status is `reverted` in `index.md`; ELSE WARN
  `revert_state_drift`.
- Permission ledger interaction: surface INFO if
  `revert: deny` rule covers most paths (revert flow effectively
  disabled).

### v0.2.0c R1 wiring checks

- Manifest required fields (`run`, `task`, `attempt`, `worker`,
  `applied_at`, `mode_default`); ELSE WARN
  `snapshot_manifest_field_missing: <field>`.
- `## Files` row format
  `<path> | mode: <m> | size_pre: <n|absent> | sha256_pre: <h|absent> | revertable: yes|no`;
  ELSE WARN `snapshot_file_row_invalid`.
- `mode` ∈ `preimage | patch | metadata-only`; ELSE ERROR
  `snapshot_mode_invalid`.
- `mode: patch` files have `forward.patch` + `reverse.patch`
  artifacts; ELSE ERROR `snapshot_patch_artifacts_missing`.
- `patch_format_version` MUST be `1`; ELSE WARN
  `snapshot_patch_format_unsupported`.
- `whitespace_handling` ∈ `preserve_lf | normalize_crlf`; ELSE
  WARN `snapshot_patch_whitespace_unknown`.
- `index.md` row format
  `<ts> | snap-* | <int> | <mode> | <int> | <int> | <status>`;
  ELSE WARN `snapshot_index_row_invalid`.
- `<status>` ∈ `active | rotated | purged | reverted`; ELSE
  ERROR `snapshot_index_status_invalid`.
- Tracked text worker output mode: MUST be `preimage`; ELSE ERROR
  `snapshot_tracked_text_unrevertable`. Legacy implementations may also
  report INFO `snapshot_mode_policy_drift`, but normal apply output is
  not allowed to depend on git restore.
- Newly-created worker output paths MUST be `preimage` with an
  absent-prestate marker, never `metadata-only`; ELSE ERROR
  `snapshot_new_output_unrevertable`.
- Revert lineage: `## Active rules` revert entries match a
  `reverted` snap-id in `index.md`; ELSE INFO
  `revert_audit_lineage_drift`.

## Locale state (v0.2.0e)

- `.dtd/locales/` directory exists; ELSE INFO `locale_dir_missing`
  (acceptable — locale packs are optional).
- If `config.md locale.enabled: true`: `config.md locale.language`
  is non-null AND `.dtd/locales/<language>.md` exists. ELSE ERROR
  `locale_pack_missing`.
- `state.md locale_active` matches `config.md locale.language` (or
  both `null`). ELSE WARN `locale_state_drift`.
- `state.md locale_set_by` is one of `default | install | user |
  auto_probe`. ELSE WARN `locale_set_by_invalid`.
- Each existing pack file `.dtd/locales/<lang>.md` is ≤
  `config.md locale.pack_size_budget_kb` (default 12 KB; was 8 KB
  in v0.2.0e R0). ELSE WARN `locale_pack_oversized: <lang>`.
- Each existing pack file contains the required sections
  `## Slash aliases` AND `## NL routing additions`. ELSE ERROR
  `locale_pack_missing_required_section: <lang>`.
- Each pack's `## Pack metadata` declares `merge_policy` matching
  `config.md locale.merge_policy`. ELSE WARN
  `locale_pack_merge_policy_drift`.
- `instructions.md` contains the §"Locale bootstrap aliases"
  section even when `locale.enabled: false`; ELSE ERROR
  `bootstrap_alias_missing` (a non-English user cannot enable
  their pack without this).
- Pack canonical-references: each NL row in a pack maps to a
  canonical action that exists in `dtd.md` Canonical Actions; ELSE
  ERROR `locale_pack_invalid_canonical: <lang>:<row>`. (R0:
  spot-check; R1+ may make this exhaustive.)
- Core-prompt locale drift: scan `.dtd/instructions.md` (outside
  the bootstrap alias table + §Locale bootstrap aliases),
  `prompt.md` (outside locale offer), and `dtd.md` (outside
  user-data examples and the `/dtd locale` documentation block) for
  Korean/Japanese characters; ELSE WARN
  `core_prompt_locale_drift: <file>:<line>`. R0 may surface this as
  INFO; R1+ tightens to WARN.

## Spec modularization (v0.2.3 R1)

- `.dtd/reference/` directory exists; ELSE INFO
  `reference_dir_missing`.
- `.dtd/reference/index.md` plus all 13 canonical reference topics
  exist (autonomy, incidents, persona-reasoning-tools, perf,
  workers, plan-schema, status-dashboard, self-update, help-system,
  run-loop, doctor-checks, roadmap, load-profile); ELSE INFO
  `reference_stub_missing: <topic>` (graceful).
- Reference files ≤ 24 KB each (R1 full-extraction files grow to
  ~6-23 KB; workers.md ~23 KB). Exception: cross-cutting
  consolidation refs (`doctor-checks.md`, `run-loop.md`) cap is
  48 KB (was 32 KB; bumped at v0.3.0b R0 to absorb quota
  predictive routing contract). Future v0.3+ work should split
  per-sub-release reference topics rather than continue
  expanding these refs. ELSE WARN `reference_oversized: <topic>`.
- `.dtd/reference/index.md` marks every topic as `canonical`; ELSE INFO
  `reference_status_missing`.
- Each reference file has an "Anchor" section saying the reference file is
  canonical for that topic; ELSE INFO `reference_anchor_missing`.
- v0.2.3 R1 full extraction complete: dtd.md sections may stay compact as
  summaries and pointers.

## Path policy

- Scan plan files for `..` paths: WARN, recommend absolute form.
- BLOCK pattern hits in plans: ERROR with line ref.
- relative/absolute classification: each path correctly classified.

## `.gitignore` + secret leak

- `.dtd/.gitignore` exists and covers `.env`, `tmp/`, `log/`,
  `eval/`: ERROR if missing.
- Project-root `.gitignore` coverage: INFO only (does not block).
- Secret leak: regex scan of `.dtd/log/`, `.dtd/state.md`,
  `AIMemory/work.log` (if present) for known key patterns:
  - `sk-[A-Za-z0-9]{32,}` (OpenAI)
  - `sk-ant-[A-Za-z0-9_-]{40,}` (Anthropic)
  - `sk-or-v1-[A-Za-z0-9_-]{40,}` (OpenRouter)
  - `AIza[0-9A-Za-z_-]{35}` (Google)
  - `ghp_[A-Za-z0-9]{36}` (GitHub PAT)
  - `hf_[A-Za-z0-9]{30,}` (Hugging Face)
  - `Bearer\s+[A-Za-z0-9_-]{20,}`
  - generic long token-like values within 50 chars of
    `api_key`/`token`/`secret`/`authorization`.
- agent-work-mem detection: report `present|absent`; if absent,
  recommend (do not block).
- `.gitignore` content: `.env`, `.dtd/tmp/`, `.dtd/log/`
  recommended.

## Anchor

This file IS the canonical source for `/dtd doctor` check
specifications across all v0.2 sub-releases.
v0.2.3 R1 extraction completed; `dtd.md` §`### /dtd doctor` now
points here.

## Related topics

- `incidents.md` — incident-state checks rationale + severity
  mapping.
- `autonomy.md` — autonomy/attention/context-pattern check
  rationale.
- `self-update.md` — Self-Update + Help system check rationale.
- `status-dashboard.md` — `/dtd doctor` output style mirrors
  `/dtd status`.
