# DTD Config

> Global settings for DTD. Edit by hand or via `/dtd workers role|alias`,
> `/dtd doctor`, etc. Stored in version control (no secrets — those go in
> `.env`, referenced by `api_key_env` in `workers.md`).

## controller

- name: controller            # display name (e.g. "클로드"). NL also recognizes this.

## host

- mode: assisted              # plan-only | assisted | full
- mode_set_by: install        # install | doctor | user
- assisted_confirm_each_call: false

## roles

# Map functional role → worker_id. NL "리뷰어한테 보내" resolves via this.
# Set by /dtd workers role set, or edit by hand. Empty roles fall back to
# capability matching at runtime.

- primary: null               # default worker when task has no <worker>/<capability>
- reviewer: null              # default for review capability tasks
- planner: null               # default for planning capability tasks
- fallback: null              # last-resort worker; receives escalation chain end before user

## controller-work-policy

# When the controller acts directly (not via worker), how to gate.
# See instructions.md "Controller Work Self-Classification" for usage.

- review_required_by: reviewer_worker  # reviewer_worker | user
- review_fallback: user                # if reviewer_worker not available

## path-policy

# Patterns for /dtd doctor + plan generation path validation.

- block_patterns:
    - /etc/**
    - C:\Windows\**
    - ~/.ssh/**
    - ~/.aws/**
    - /
    - C:\
- warn_patterns:
    - ~/**
- allow_patterns:
    - /tmp/**
    - /var/log/**

## context-budget

- default_failure_threshold: 3
- escalate_on_phase_failures: 0      # 0 = disabled; >0 = escalate phase as a unit after N failures
- heartbeat_interval_sec: 30
- stale_threshold_min: 5

## dashboard

- dashboard_style: ascii      # ascii (default, canonical for v0.1) | unicode (optional polish, falls back to ascii if terminal cannot render)
- dashboard_width: 100
- progress_report: every_phase   # every_phase | every_task | none
- display_worker_format: alias   # alias | id | both

## plan-budget

- preferred_size_kb: 12
- hard_cap_kb: 24
- patches_inline_max: 5
- patches_inline_max_kb: 4
- compact_threshold_kb: 8

## ai-memory

# DTD's interaction with agent-work-mem (if installed). See dtd.md §AIMemory Boundary.

- detected: false             # set by install/doctor
- emit_run_events: true       # WORK_START/WORK_END per DTD run
- emit_exception_events: true # NOTE for durable decisions, high steering, protocol changes

## defaults

- default_target_grade: GOOD       # NORMAL | GOOD | GREAT | BEST
- default_max_iterations: 5        # int >= 1, OR "unlimited" for no cap (use carefully — see dtd.md §Phase Iteration Control)
- log_retention_days: 30           # .dtd/log/ entries older than this are candidates for cleanup
