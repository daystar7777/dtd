# DTD Runtime State

> Live state. Read at the start of every turn (DTD mode on).
> Write atomically: edit a tmp file then rename. Never mid-task.
> Single source of truth for plan_status, pending_patch, current_task, counters.

## Mode

- mode: off                       # off | dtd
- last_mode_change: 2026-05-04 23:00

## Lazy-load profile (v0.2.3)

# Controller-side hint for which instructions.md / dtd.md sections are
# logically "active" this turn. Reduces cognitive load: host still has
# full instructions in context, but controller focuses on profile-matched
# sections.
#
# Observational reads do not persist profile changes; mutating turns may
# update these fields in the same atomic state write as the action.
#
# Profile is resolved at per-turn protocol step 1.5 (after reading state.md,
# before intent gate). See dtd.md §Lazy-Load Profile.

- loaded_profile: minimal          # minimal | planning | running | recovery
- loaded_profile_set_at: null      # timestamp; debug aid for profile transitions
- loaded_profile_reason: null      # null | mode_off | no_plan | draft_or_approved | running_or_paused | active_blocker | pending_patch

## Worker session resume (v0.2.1)

# Provider session continuation hint for in-flight retry decisions.
# See dtd.md §/dtd workers (Worker session resume).

- last_worker_session_id: null         # provider session token, if known
- last_worker_session_provider: null   # which provider issued the session id
- last_resume_strategy: null           # null | fresh | same-worker | new-worker | controller-takeover
- last_resume_at: null

## Loop guard (v0.2.1)

# Doom-loop detection signature. Reset to idle on finalize_run terminal exits.
# See dtd.md §/dtd workers (Loop guard subsection).

- loop_guard_status: idle              # idle | watching | hit
- loop_guard_signature: null           # sha256 of recent attempt
- loop_guard_signature_count: 0        # consecutive matches
- loop_guard_signature_first_seen_at: null   # v0.2.1 R1: ts when current signature first matched (window staleness check)
- loop_guard_threshold: 3              # mirrors config.loop_guard_threshold
- loop_guard_last_check_at: null

## Cross-run loop guard (v0.3.0a)

# Stable cross-run signature ledger interaction. See
# .dtd/reference/v030a-cross-run-loop-guard.md for the algorithm.

- cross_run_loop_guard_status: idle    # idle | watching | hit
- cross_run_match_count: 0             # ephemeral counter; reset at finalize_run
- pending_cross_run_signature: null    # current run's stable signature flagged for cross-run match
- last_cross_run_check_at: null        # ts of last ledger read
- last_cross_run_finalize_at: null     # ts of last finalize_run capture-before-clear
- last_cross_run_rehash_at: null       # R1; ts of last /dtd loop-guard rehash
- cross_run_rehash_in_progress: false  # R1; true while /dtd loop-guard rehash mid-execution

## Consensus state (v0.3.0c)

# Multi-worker consensus dispatch tracking. Cleared at task
# completion or finalize_run. See
# .dtd/reference/v030c-consensus.md.

- active_consensus_task: null              # null | <task_id>; non-null during 6.consensus
- active_consensus_n: 0                    # how many workers dispatched
- active_consensus_strategy: null          # null | first_passing | quality_rubric | reviewer_consensus | vote_unanimous
- active_consensus_group_lock: null        # null | <output-path-set hash>; held during dispatch
- consensus_outcomes: []                   # per-attempt rows: {worker, status, score, winner, late_stale}
- last_consensus_lock_acquire_attempt_at: null  # R1; ts of last lock acquisition attempt
- last_consensus_strategy_outcome: null    # R1; winner_selected | disagreement | partial_failure | lock_timeout

## Project identity (v0.3.0a)

# Stable project identifier for cross-run / cross-machine signature
# components. Auto-generated UUID at install if not user-set. See
# .dtd/reference/v030a-cross-run-loop-guard.md §"repo_identity_hash".

- project_id: null                     # UUID; null pre-v0.3.0a installs migrate at next /dtd update

## Session sync (v0.3.0d)

# Cross-machine session affinity tracking. Updated by
# pre-dispatch sync read + finalize_run sync write.
# See .dtd/reference/v030d-cross-machine-session-sync.md.

- session_sync_last_read_at: null
- session_sync_last_write_at: null
- session_sync_pending_conflicts: []   # list of {provider, machine_id, session_id_hash}
- machine_id: null                     # auto-generated UUID at install (Codex: UUID + optional display_name)
- machine_display_name: null           # optional human label, e.g. "laptop-A"
- session_sync_consecutive_unreachable_count: 0  # R1; counter for backend reachability
- last_session_sync_decrypt_failure_at: null     # R1; ts of last decrypt failure

## Notepad compaction (v0.2.2 R1)

# Phase-boundary + manual compaction tracking. See
# reference/run-loop.md §"Notepad compaction + reasoning utility
# post-processing (v0.2.2 R1)".

- last_compaction_at: null         # ts of last compaction
- last_compaction_reason: null     # null | phase_boundary | manual | finalize_run
- compaction_warns_run: 0          # WARN events this run after compaction

## Snapshot state (v0.2.0c)

# Pre-apply snapshot tracking. See dtd.md §/dtd snapshot.

- last_snapshot_id: null           # latest snap-<run>-<task>-<attempt>
- last_snapshot_at: null
- snapshots_total: 0               # total snapshots in .dtd/snapshots/ (incl. archived)
- snapshots_size_bytes: 0          # total size; for doctor display
- last_revert_id: null             # latest reverted snap-id; null if none
- last_revert_at: null

## Permission ledger (v0.2.0b)

# Active permission request capsule (denormalized from awaiting_user_decision
# for /dtd status display). Cleared when capsule resolves. See dtd.md
# §/dtd permission and .dtd/permissions.md.

- pending_permission_request: null   # null | {key, scope, worker, dec_id, asked_at}

## Quota state (v0.3.0b)

# Token-rate-aware scheduling. See dtd.md §/dtd workers test (--quota)
# and reference/run-loop.md §"Quota predictive check (v0.3.0b R0)".

- pending_quota_capsule: null               # null | {worker, used, quota, reset_at_local, reset_tz}
- last_quota_check_at: null
- last_quota_reset_local_at: null           # ts when daily reset boundary crossed
- last_quota_reset_tz: null                 # timezone tag at last reset
- last_quota_estimation_source: null        # R1; per_task_history | plan_derived | conservative
- mid_run_actual_exceeded_count: 0          # R1; counter of mid-run 429s in current run

## Permission time-limited rules (v0.3.0e)

# Time-limited permission rule tracking. See dtd.md §/dtd permission
# (v0.3.0e time-limited syntax) and reference/run-loop.md §"Auto-prune
# time-limited permission rules" finalize_run step 5c.

- active_time_limited_rule_count: 0       # for /dtd status --full perms line; recounted at finalize_run 5c
- last_permission_prune_at: null          # ts of last finalize_run step 5c
- last_permission_rule_written_at: null   # R1; ts of last /dtd permission write
- last_permission_rule_form: null         # R1; absolute | duration | named_local | named_run
- user_tz: null                           # R1; user-configured timezone (e.g. Asia/Seoul); REQUIRED for named-local-scope writes

## Silent window transient rules (v0.2.0b R1)

# v0.2.0b R1 wiring: list of permissions.md rule timestamps installed by
# /dtd silent on (with by: silent_window), to be revoked at
# /dtd interactive / attention_until / /dtd silent off. See
# reference/autonomy.md §"Silent transient rules (v0.2.0b R1)".

- silent_window_transient_rule_ids: []   # list of ISO 8601 timestamps

## Locale (v0.2.0e)

# Optional locale-pack activation. Core prompts stay English-only;
# locale_active selects which .dtd/locales/<lang>.md augments NL
# routing this session. See dtd.md §/dtd locale.

- locale_active: null             # null | ko | ja  (matches config.md locale.language)
- locale_set_by: default          # default | install | user | auto_probe
- locale_set_at: null             # timestamp when last changed

## Self-Update state (v0.2.0d)

# /dtd update flow tracking. See dtd.md §/dtd update.

- installed_version: null         # e.g. "v0.2.0d"; null pre-update / pre-tag
- update_check_at: null            # persisted install/apply check; read-only `/dtd update check` does not write
- update_available: null           # null | "<version>" from mutating update flow; read-only check is transient
- update_in_progress: false        # true blocks dispatch + concurrent /dtd update
- last_update_from: null           # version migrated from
- last_update_at: null             # timestamp of last successful update

## Attention mode (v0.2.0f)

# Autonomy & Attention surface — see dtd.md §Autonomy & Attention Modes.
# Migrated forward by v0.2.0d Self-Update Amendment 4 for pre-v0.2.0f installs.

- decision_mode: permission        # plan | permission | auto
- decision_mode_set_by: default    # default | user | run_flag
- attention_mode: interactive      # interactive | silent
- attention_mode_set_by: default   # default | user | run_flag
- attention_until: null            # timestamp; null means until run stops/completes
- attention_goal: null             # user-facing note, e.g. "work quietly for 4h"
- deferred_decision_count: 0       # silent mode blockers deferred this run
- deferred_decision_refs: []       # incident/attempt ids, compact

## Active plan

- active_plan: null               # NNN (zero-padded) or null
- plan_status: null               # null | DRAFT | APPROVED | RUNNING | PAUSED | STOPPED | COMPLETED | FAILED
- plan_started_at: null
- plan_ended_at: null

## Active Run Capsule (resume-friendly snapshot)

# Compact snapshot for cross-session resume. Updated at every phase boundary.
# A new session reads this first to decide: resume or start fresh?

- run_id: null                    # e.g. "001" — usually mirrors active_plan
- run_started_at: null
- current_phase: null             # phase id (1..N)
- current_phase_started_at: null
- current_iteration: null
- total_phases: null
- last_completed_task: null       # task id of most recent done
- last_checkpoint_at: null
- pending_attempts: []            # see attempt timeline section below
- recent_outputs: []              # last few output paths from completed tasks (≤ 5)

## Patch (orthogonal flag)

- pending_patch: false
- patch_impact: null              # null | medium | high
- patch_status: null              # null | proposed | approved | rejected
- patch_ref: null                 # e.g. .dtd/plan-001.md#patches

## Current task

# Note: phase id and iteration live in the Active Run Capsule above (single source of truth).
# This section tracks task-level fields only.

- current_task: null              # task id (e.g. "2.1")
- current_task_started_at: null

## Pause / stop intent

- pause_requested: false          # /dtd pause sets this; controller checks between tasks
- run_until: null                 # null | phase:<id> | task:<id> | before:<id> | next-decision (set by /dtd run --until; cleared when boundary hit)
- run_until_reason: null          # user-checkpoint | user-test | user-decision | manual-check | explicit-limit

# Durable pause-boundary display fields (kept after run_until clears so /dtd status can render them):
- last_pause_reason: null         # null | user_pause | run_until_boundary | decision_capsule | error_blocked
- last_pause_boundary: null       # e.g. "phase:3" if last_pause_reason=run_until_boundary
- last_pause_at: null             # timestamp
# Cleared by /dtd run when resuming.

## Fallback chain (per-task, computed before dispatch)

- current_fallback_chain: []      # ordered list: [<worker_id>, <worker_id>, ..., "controller", "user"]
- current_fallback_index: null    # int (0-based) — which step of chain is active
- current_fallback_policy: null   # null | "auto" | "ask-before-switch" | "user-confirmed"
# Cleared by finalize_run.

## Active context pattern (resolved before each worker dispatch) (v0.2.0f)

# GSD-style context patterns plus compact persona/reasoning/tool controls.
# See dtd.md §Context Patterns and §Persona, Reasoning, and Tool-Use Patterns.
# Cleared by finalize_run on terminal exit.

- resolved_context_pattern: null     # fresh | explore | debug
- resolved_handoff_mode: null        # standard | rich | failure
- resolved_sampling: null            # compact display, e.g. "temp=0.0 top_p=1 samples=1"
- resolved_controller_persona: null  # operator | planner | researcher | implementer | debugger | reviewer | release_guard
- resolved_worker_persona: null      # same enum; compact stance only, no role-play biography
- resolved_reasoning_utility: null   # direct | least_to_most | react | tool_critic | self_refine | tree_search | reflexion
- resolved_tool_runtime: null        # none | controller_relay | worker_native | hybrid
- last_context_reset_at: null
- last_context_reset_reason: null    # dispatch | retry | phase_boundary | worker_switch | run_resume

## Incidents (v0.2.0a)

# Every operational failure that needs durable tracking creates an incident.
# Incident detail files live at .dtd/log/incidents/inc-<run>-<seq>.md (gitignored).
# The index file is .dtd/log/incidents/index.md.

- active_incident_id: null               # warn-or-higher unresolved incident (info incidents do NOT set this)
- active_blocking_incident_id: null      # only severity=blocked|fatal — fills decision capsule with INCIDENT_BLOCKED
                                          # at most ONE active blocking incident at a time;
                                          # the queue of waiting blockers is .dtd/log/incidents/index.md (NOT recent_incident_summary).
                                          # Promotion on resolve scans index.md for the oldest unresolved blocking incident.
- last_incident_id: null                 # most recent of any severity (info / warn / blocked / fatal)
- incident_count: 0                      # cumulative across this project's lifetime
- recent_incident_summary: []            # last 3 unresolved INFO|WARN ONLY — shown in /dtd status --full.
                                          # Blocking incidents are NEVER added here (they live in active_blocking_incident_id + index.md).
                                          # Each entry: {id, severity, reason, created_at}

# Cleared by finalize_run on COMPLETED.
# active_blocking_incident_id is cleared when /dtd incident resolve <id> <option> chosen,
# OR when finalize_run(STOPPED|FAILED) terminates the run.

# User decision capsule (structured replacement for ad-hoc awaiting):
- awaiting_user_decision: false   # true blocks dispatch; status displays the capsule below
- awaiting_user_reason: null      # canonical enum:
                                  # core (v0.1): CONTEXT_EXHAUSTED | ESCALATION_TERMINAL
                                  #            | PATCH_PENDING_CONFIRM | MAX_ITERATIONS_REACHED
                                  # worker call (v0.1.1): AUTH_FAILED | ENDPOINT_NOT_FOUND
                                  #            | RATE_LIMIT_BLOCKED | WORKER_5XX_BLOCKED
                                  #            | TIMEOUT_BLOCKED | NETWORK_UNREACHABLE
                                  #            | MALFORMED_RESPONSE | WORKER_INACTIVE
                                  # local apply (v0.1.1): DISK_FULL | FS_PERMISSION_DENIED
                                  #            | FILE_LOCKED | PATH_GONE | PARTIAL_APPLY
                                  #            | UNKNOWN_APPLY_FAILURE
                                  # v0.2: LOOP_GUARD | RESOURCE_TAKEOVER | DESTRUCTIVE_ACTION
                                  #     | EXTERNAL_DIRECTORY_ACCESS | INCIDENT_BLOCKED
                                  #     | PERMISSION_REQUIRED | CONTROLLER_TOKEN_EXHAUSTED
                                  # v0.2.0c: PARTIAL_REVERT
                                  # v0.2.1: WORKER_HEALTH_FAILED | LOOP_GUARD_HIT
                                  #       | RESUME_STRATEGY_REQUIRED
                                  #       | WORKER_TOOL_RELAY_FABRICATED
                                  #       | WORKER_NATIVE_TOOL_SANDBOX_INVALID
                                  # v0.3.0b: WORKER_QUOTA_EXHAUSTED_PREDICTED
                                  # v0.3.0c: CONSENSUS_DISAGREEMENT | CONSENSUS_PARTIAL_FAILURE
                                  # v0.3.0c R1: CONSENSUS_LOCK_TIMEOUT
                                  # v0.3.0d: SESSION_CONFLICT
- decision_id: null               # e.g. "dec-001" — monotonic per run
- decision_prompt: null           # one-line user-facing question
- decision_options: []            # list of {id, label, effect, risk}
- decision_default: null          # id of the conservative default
- decision_resume_action: null    # what controller does on each option choice
- decision_expires_at: null       # optional auto-default after timeout (v0.2 may use)
- user_decision_options: []       # legacy field (still populated for back-compat); prefer decision_options

## Progress

- progress: 0/0                   # done / total tasks
- phases_done: 0
- phases_total: 0

## Failure counters (per-(worker, task))

- failure_counts: []
  # Example entry:
  # - worker: deepseek-local
  #   task: "2.1"
  #   count: 2
  #   reason_hashes: [a3f1b9, a3f1b9]
- failure_count_phase: 0
- last_failure_reason: null

## Controller self-action tracking

- controller_action_category: null     # null | orchestration | small_direct_fix | artifact_authoring
- controller_action_review_status: null # null | pending | passed | rejected
- controller_action_path: null
- controller_action_started_at: null

## Steering

- steering_cursor: 0              # last processed line in steering.md
- steering_count: 0
- latest_steering: null
- steering_active: false

## Concurrency

- session_lock: null              # <model-id>@<UTC-iso8601>
- session_started_at: null
- heartbeat_at: null
- stale_threshold_min: 5

## Roles snapshot (resolved view, derived from config.md)

- roles_active:
    - primary: null
    - reviewer: null
    - planner: null
    - fallback: null

## Host

- host_mode: assisted             # plan-only | assisted | full
- host_capabilities_detected: []
- mode_set_by: install            # install | doctor | user

## Last update

- last_update: 2026-05-04 23:00
- last_writer: claude-opus-4-7
