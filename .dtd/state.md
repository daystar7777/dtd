# DTD Runtime State

> Live state. Read at the start of every turn (DTD mode on).
> Write atomically: edit a tmp file then rename. Never mid-task.
> Single source of truth for plan_status, pending_patch, current_task, counters.

## Mode

- mode: off                       # off | dtd
- last_mode_change: 2026-05-04 23:00

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
- awaiting_user_decision: false   # set when escalate_to: user terminal hit OR context exhausted
- awaiting_user_reason: null      # null | CONTEXT_EXHAUSTED | ESCALATION_TERMINAL | PATCH_PENDING_CONFIRM
                                  #      | MAX_ITERATIONS_REACHED | ...
                                  # Single canonical reason string. /dtd status displays this.
- user_decision_options: []       # menu of choices when awaiting

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
