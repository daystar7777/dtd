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

## Spec modularization (v0.2.3 R0/R1)

- `.dtd/reference/` directory exists; ELSE INFO
  `reference_dir_missing` (acceptable — full content remains in
  dtd.md until R1+ extraction).
- `.dtd/reference/index.md` plus all 13 canonical reference topics
  exist (autonomy, incidents, persona-reasoning-tools, perf,
  workers, plan-schema, status-dashboard, self-update, help-system,
  run-loop, doctor-checks, roadmap, load-profile); ELSE INFO
  `reference_stub_missing: <topic>` (graceful).
- Reference files ≤ 24 KB each (R0 stubs are typically ≤ 2 KB; R1
  full-extraction reference files may grow to ~6-20 KB carrying
  canonical content; workers.md is the thickest at ~19 KB); ELSE
  WARN `reference_oversized: <topic>`.
- `.dtd/reference/index.md` marks each topic as `canonical` or
  `stub`; ELSE INFO `reference_status_missing`.
- Each reference file has an "Anchor" section. For canonical
  topics, the anchor says the reference file is the source. For
  stubs, the anchor points back to `dtd.md`; ELSE INFO
  `reference_anchor_missing`.
- v0.2.3 R1+ full extraction: when reference files contain full
  content (not stubs), INFO that dtd.md sections may be safely
  compacted.

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
