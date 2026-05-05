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

## update (v0.2.0d)

# Self-Update settings. See dtd.md §/dtd update.

- check_on_install: true              # installer may check upstream once; read-only `/dtd update check` never writes
- check_interval_days: 7              # informational upstream-check cadence; not a state mutation timer
- github_repo: daystar7777/dtd        # upstream repo for /dtd update
- github_token_env: GITHUB_TOKEN      # env var name for private repo auth; NEVER literal
- manifest_required: true             # ERROR if MANIFEST.json missing in fetched release
- backup_retention_days: 7            # auto-cleanup .dtd.backup-* after this many days

## decision-policy (v0.2.0f)

# How often DTD asks the user. Separate from host.mode (apply authority) and
# attention mode (ask now vs defer). See dtd.md §Autonomy & Attention Modes.

- default_decision_mode: permission       # plan | permission | auto
- decision_mode_destructive_confirm: true # true even in auto/silent
- decision_mode_paid_confirm: true        # paid fallback needs explicit allow
- decision_mode_external_path_confirm: true

## attention (v0.2.0f)

# Separate from host.mode. host.mode controls apply authority; attention_mode
# controls whether DTD interrupts the user or defers blockers and keeps working.
# See dtd.md §Autonomy & Attention Modes for full algorithm.

- default_attention_mode: interactive       # interactive | silent
- silent_default_hours: 4
- silent_max_hours: 8
- silent_blocker_policy: defer_and_continue # defer_and_continue | pause_on_first_blocker
- silent_allow_same_profile_fallback: true
- silent_allow_paid_fallback: false
- silent_allow_destructive: false
- silent_deferred_decision_limit: 20

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

## context-pattern (v0.2.0f)

# GSD-inspired context control. Keep only the three common user-facing patterns
# for now; finer temperature/read-depth/session knobs can be added later under
# these pattern names without changing plan syntax.
# See dtd.md §Context Patterns for plan XML attribute usage and resolution.

- default_context_pattern: fresh           # fresh | explore | debug
- context_patterns:
    fresh:   {handoff: standard, retry: compact_failure_hint, temperature: 0.0, top_p: 1.0, samples: 1, reviewer_gate: false}
    explore: {handoff: rich,     retry: summary_only,         temperature: 0.6, top_p: 0.95, samples: 2, reviewer_gate: true}
    debug:   {handoff: failure,  retry: compact_failure_hint, temperature: 0.1, top_p: 1.0, samples: 1, reviewer_gate: false}
- capability_context_defaults:
    planning: explore
    research: explore
    code-write: fresh
    code-refactor: fresh
    debug: debug
    review: fresh
    verification: fresh
- max_handoff_kb: 1
- context_warn_pct: 50
- context_checkpoint_pct: 70

## persona-pattern (v0.2.0f Codex R0 addendum)

# Compact stance controls chosen per phase/task. Personas are domain stances,
# not role-play biographies, and never override permissions or safety rules.

- default_controller_persona: operator
- default_worker_persona: implementer
- persona_patterns:
    operator:      {stance: "optimize safe progress; surface blockers tersely"}
    planner:       {stance: "make dependencies, options, and decision points explicit"}
    researcher:    {stance: "gather evidence and references before changing files"}
    implementer:   {stance: "make the smallest correct patch inside declared scope"}
    debugger:      {stance: "isolate repro, hypothesis, and smallest fix path"}
    reviewer:      {stance: "prioritize correctness, regressions, and missing tests"}
    release_guard: {stance: "verify docs, tests, state, and acceptance consistency"}
- capability_persona_defaults:
    planning: planner
    research: researcher
    code-write: implementer
    code-refactor: implementer
    debug: debugger
    review: reviewer
    verification: release_guard
- max_persona_prompt_words: 120

## reasoning-utility (v0.2.0f Codex R0 addendum)

# Utilities guide how deeply to reason for a phase/task. Raw chain-of-thought is
# never requested, stored, or shown; only compact rationale summaries survive.

- default_reasoning_utility: direct
- reasoning_utilities:
    direct:        {summary: "concise plan, execute, summarize", samples: 1}
    least_to_most: {summary: "decompose into ordered subproblems", samples: 1}
    react:         {summary: "plan/action/observation summaries for tool-heavy work", samples: 1}
    tool_critic:   {summary: "verify with external checks, then revise", samples: 1}
    self_refine:   {summary: "draft, critique, refine within budget", samples: 1}
    tree_search:   {summary: "sample small option set, select with rubric", samples: 3}
    reflexion:     {summary: "record one compact lesson after concrete failure", samples: 1}
- capability_reasoning_defaults:
    planning: least_to_most
    research: react
    code-write: direct
    code-refactor: direct
    debug: tool_critic
    review: tool_critic
    verification: tool_critic
- expose_chain_of_thought: false
- max_reasoning_summary_lines: 5

## tool-runtime (v0.2.0f Codex R0 addendum)

# Worker tool access must be explicit. Default relay keeps tool transcripts out
# of controller chat and stores full sanitized output in .dtd/log/.

- default_worker_tool_mode: controller_relay # none | controller_relay | worker_native | hybrid
- worker_native_requires_sandbox: true
- controller_relay_allows_mutating_tools: false
- max_tool_result_kb: 4

## incident (v0.2.0a)

# See dtd.md §Incident Tracking. Knobs for info-severity creation cadence.

- info_threshold: 3                  # N-th recoverable retry of same reason_class within run files an info incident; further occurrences are rate-limited (one per (run, reason_class)). 0 disables info incidents entirely.

## fallback-policy

# Per-task fallback chain rules (see dtd.md §Fallback chain).
# Auto-fallback is allowed only when ALL conditions hold; otherwise capsule.

- auto_fallback: same-profile-only       # never | same-profile-only | ask-before-switch
- max_same_worker_retries: 1             # in-place retries before tier-escalating
- max_auto_worker_switches: 1            # auto-fallbacks allowed before user prompt
- paid_fallback_requires_confirm: true   # capsule when transitioning free → paid tier
- worker_inactive_wait_default_sec: 60   # default for WORKER_INACTIVE wait_once option

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
