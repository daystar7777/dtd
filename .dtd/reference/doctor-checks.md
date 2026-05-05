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
  tool_relay_read | tool_relay_mutating | todowrite | question`; ELSE
  ERROR `permission_key_unknown`.
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
- Each `preimage` artifact's SHA-256 matches its manifest entry;
  ELSE ERROR `snapshot_preimage_corrupted`.
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
  `config.md locale.pack_size_budget_kb` (default 8 KB). ELSE WARN
  `locale_pack_oversized: <lang>`.
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
- Reference files ≤ 24 KB each (R1 full-extraction reference files may grow
  to ~6-20 KB carrying
  canonical content; workers.md is the thickest at ~19 KB); ELSE
  WARN `reference_oversized: <topic>`.
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
