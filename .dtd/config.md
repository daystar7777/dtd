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

## load-profile (v0.2.3)

# Lazy-load profile mapping. Maps each profile to the set of
# instructions.md / dtd.md / reference sections that are "active" for
# turns in that profile. Controller uses these sets to focus cognitive
# load. See dtd.md §Lazy-Load Profile.

- profile_resolution_mode: state_driven   # state_driven | manual | auto_probe
- default_profile: minimal                 # initial profile when state is fresh
# v0.2.3 R1: each "active" entry is a dtd.md stub OR an instructions
# section. Canonical detail for many topics now lives in
# .dtd/reference/<topic>.md and is drilled-into via
# `/dtd help <topic> --full` only when the controller actually needs it.
# The reference_drilldown_topics list below names the deeper canonical
# files the controller may load on demand for that profile.
- profile_sections:
    minimal:
      active_sections:
        - "instructions.md §TL;DR"
        - "instructions.md §Slash command aliases"
        - "instructions.md §Per-turn protocol"
        - "instructions.md §Intent Gate"
        - "instructions.md §Status / read-only call isolation"
        - "dtd.md §Modes"
        - "dtd.md §Canonical Actions (status / doctor / mode)"
      reference_drilldown_topics: []
    planning:
      active_sections:
        - "<all minimal sections>"
        - "instructions.md §NL → Canonical Action Mapping"
        - "instructions.md §State-aware Disambiguation"
        - "instructions.md §Naming Resolution Precedence"
        - "instructions.md §Worker Permission Profiles"
        - "dtd.md §/dtd plan"
        - "dtd.md §/dtd plan worker"
        - "dtd.md §/dtd approve"
        - "dtd.md §Worker Registry & Routing"
        - "dtd.md §Plan Schema (XML)"
      reference_drilldown_topics:
        - "workers"
        - "plan-schema"
    running:
      active_sections:
        - "<all planning sections>"
        - "instructions.md §Token Economy Rules"
        - "instructions.md §Controller Work Self-Classification"
        - "instructions.md §Context Control"
        - "dtd.md §/dtd run"
        - "dtd.md §finalize_run(terminal_status)"
        - "dtd.md §Autonomy & Attention Modes"
        - "dtd.md §Context Patterns"
        - "dtd.md §Persona, Reasoning, and Tool-Use Patterns"
        - "dtd.md §Worker Dispatch — HTTP Transport"
        - "dtd.md §Tier Escalation"
        - "dtd.md §Resource Locks"
        - "dtd.md §Phase Iteration Control"
        - "dtd.md §Per-Run Notepad"
        - "dtd.md §Attempt Timeline"
      reference_drilldown_topics:
        - "run-loop"
        - "autonomy"
        - "persona-reasoning-tools"
        - "workers"
        - "perf"
    recovery:
      active_sections:
        - "<all running sections>"
        - "dtd.md §Incident Tracking (v0.2.0a)"
        - "dtd.md §/dtd incident list/show/resolve"
        - "dtd.md §Status Dashboard (v0.2.0a/v0.2.0f rendering)"
        - "instructions.md §Don't Do These (full)"
      reference_drilldown_topics:
        - "incidents"
        - "autonomy"
        - "doctor-checks"
        - "status-dashboard"
        - "self-update"
- profile_transition_logging: false       # optional diagnostic; never log profile changes to steering.md
- profile_transition_log_path: .dtd/log/profile-transitions.md
- aggressive_unload: false                # if true, hosts that support unload may evict non-profile sections (advanced)

## consensus (v0.3.0c)

# Multi-worker consensus dispatch. Per-task opt-in via plan XML
# `consensus="N"` attribute. See .dtd/reference/v030c-consensus.md.

- default_strategy: reviewer_consensus    # first_passing | quality_rubric | reviewer_consensus | vote_unanimous
- consensus_confirm_each_call: true       # always confirm N× cost in assisted host mode
- max_consensus_n: 5                      # hard cap per task; doctor ERRORs above
- consensus_lock_acquire_timeout_sec: 30  # how long to wait for output-path lock
- whitespace_normalization_for_vote: true # for vote_unanimous strategy
- late_result_action: discard             # discard | log_and_discard
- rubric:                                 # for quality_rubric strategy
    - {key: output_paths_match, weight: 0.4}
    - {key: sentinel_match,     weight: 0.3}
    - {key: line_count_match,   weight: 0.2}
    - {key: no_protocol_violation, weight: 0.1}

## cross-run loop guard (v0.3.0a)

# Persist loop guard signatures across runs to detect long-term
# patterns within-run guard (v0.2.1) doesn't catch. Signatures use
# the v0.3.0a stable formula (NOT v0.2.1 within-run formula). See
# .dtd/reference/v030a-cross-run-loop-guard.md.

- cross_run_loop_guard_enabled: true
- cross_run_threshold: 2                  # prior runs needed before LOOP_GUARD_CROSS_RUN_HIT fires
- cross_run_retention_days: 30            # prune signatures whose last_seen is older
- cross_run_max_signatures: 500           # hard cap; doctor WARN above; auto-prune at finalize_run

## session-sync (v0.3.0d)

# Cross-machine session continuation. Default: off (per-machine).
# When enabled, ALL synced payloads are mandatorily encrypted (Codex
# P1.6); raw provider session ids are NEVER written to the sync
# folder/branch. See .dtd/reference/v030d-cross-machine-session-sync.md.

- enabled: false                            # boolean
- backend: none                             # none | filesystem | git_branch
- sync_path: null                           # filesystem path (e.g. ~/Dropbox/dtd-sync); used when backend=filesystem
- sync_branch: null                         # git branch name; used when backend=git_branch
- sync_remote: origin                       # git remote for git_branch backend
- sync_commit_interval_min: 15              # commit cadence for git_branch backend
- encryption_key_env: DTD_SESSION_SYNC_KEY  # env var NAME (never literal value); MUST resolve when enabled
- conflict_strategy: ask                    # ask | last_writer_wins | local_wins | remote_wins (Codex: keep ask default)
- expires_default_hours: 24                 # default expiry on freshly-recorded sessions

## quota (v0.3.0b)

# Token-rate-aware predictive routing. See dtd.md §/dtd workers test
# (--quota flag) and reference/run-loop.md §"Quota predictive check
# (v0.3.0b R0)". Per Codex P1.2/P1.3: paid fallback preserved through
# permission ledger, never bypassed.

- quota_predictive_routing_enabled: true     # global on/off
- quota_safety_margin_default: 1.5           # default if worker doesn't specify
- cross_run_quota_persist: false             # save quota usage across runs (default off; opt-in)
- quota_warn_threshold_pct: 80               # WARN when usage > N%
- quota_block_threshold_pct: 95              # capsule when > N%
- quota_provider_headers_capture: true       # capture x-ratelimit-* response headers (advisory)
- quota_persist_path: .dtd/log/worker-quota-tracker.md   # cross-run persistence file (gitignored under log/)
- quota_paid_fallback_silent_defer: true     # in silent mode, defer paid-fallback unless explicit allow rule

## locale (v0.2.0e)

# Optional locale-pack support. Core operational prompts stay English-only;
# locale packs augment NL routing and slash aliases for the user's preferred
# language. See dtd.md §/dtd locale and .dtd/locales/<lang>.md.

- enabled: false                  # true | false (auto in future)
- language: null                  # null | ko | ja  (matches .dtd/locales/<lang>.md)
- auto_probe: false               # if true, installer probes user's first message language
- pack_path: .dtd/locales         # directory containing <lang>.md packs
- pack_size_budget_kb: 12         # WARN locale_pack_oversized above this (was 8 in v0.2.0e R0; bumped at v0.2.0b/c R1 to accommodate per-sub-release NL row growth)
- merge_policy: pack_wins_on_conflict   # pack_wins_on_conflict | core_wins_on_conflict

## worker-test (v0.2.1)

# /dtd workers test settings. See dtd.md §/dtd workers + reference/workers.md
# §Worker Health Check (v0.2.1).

- worker_test_timeout_sec: 30                    # per-stage probe timeout
- worker_test_history_retention: 20              # rolling .dtd/log/worker-checks/ count
- worker_test_auto_before_run: assigned_only     # off | assigned_only | all
- worker_test_full_requires_confirm: false       # --full sends real prompts; require explicit y?
- worker_test_tool_relay_probe: full_only        # off | full_only | always (Amendment 1)
- worker_test_native_sandbox_check: true         # always run for native/hybrid (Amendment 1)
- worker_test_sandbox_leak_action: refuse_native # refuse_native | warn | allow

## loop-guard (v0.2.1)

# Doom-loop detection via attempt-signature hashing. See dtd.md §/dtd workers
# (Loop guard subsection) + reference/run-loop.md.

- loop_guard_enabled: true                  # global on/off
- loop_guard_threshold: 3                   # consecutive same-signature attempts trigger capsule
- loop_guard_threshold_action: ask          # ask | worker_swap | controller (auto-action when threshold hit)
- loop_guard_signature_window_min: 30       # signature stales after N min (avoids old replays)

## snapshot (v0.2.0c)

# Pre-apply file snapshots for safe revert. Mode chosen per file based on
# size + tracked status + permissions. See dtd.md §/dtd snapshot.

- enabled: true                    # global enable; false = no snapshots, no revert
- preimage_size_threshold: 65536   # bytes; files <= this prefer preimage; larger prefer patch
- patch_max_size: 4194304          # bytes; files > this fall back to preimage even in patch mode
- binary_extensions: [.png, .jpg, .gif, .pdf, .zip, .tar, .gz, .bin, .so, .exe, .dll]
- retention_days: 30               # snapshots older than this can be auto-rotated
- auto_rotate: false               # auto-move to archived/ after retention_days; off by default
- max_total_size_mb: 512           # snapshots dir size limit; doctor warns
- on_snapshot_fail: refuse_apply   # refuse_apply | proceed_unsafe (default refuse)

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
