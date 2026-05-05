# DTD Runtime State

> Live state. Read at the start of every turn (DTD mode on).
> Write atomically: edit a tmp file then rename. Never mid-task.
> Single source of truth for plan_status, pending_patch, current_task, counters.

## Mode

- mode: off                       # off | dtd
- last_mode_change: 2026-05-04 23:00

## Self-Update state (v0.2.0d)

# /dtd update flow tracking. See dtd.md §/dtd update.

- installed_version: null         # e.g. "v0.2.0d"; null pre-update / pre-tag
- update_check_at: null            # last time `/dtd update check` ran
- update_available: null           # null | "<version>" if newer release detected
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
