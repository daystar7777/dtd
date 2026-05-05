# DTD reference: autonomy (v0.2.0f)

> Canonical reference for v0.2.0f Autonomy & Attention Modes.
> Lazy-loaded via `/dtd help autonomy --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

This is a core DTD UX surface. It lets a user either collaborate live or leave
DTD running overnight without turning every blocker into an immediate stop.

**Feature gating**: this whole subsection ships in **v0.2.0f Autonomy &
Attention**. v0.1.1 / v0.2.0a state.md without these fields is migrated
forward by v0.2.0d Self-Update (`Amendment 4`). Doctor in pre-v0.2.0f
installs treats missing fields as INFO and falls back to defaults
(`decision_mode: permission`, `attention_mode: interactive`).

There are three independent axes:

| Axis | Values | Meaning |
|---|---|---|
| `host.mode` | `plan-only` / `assisted` / `full` | Apply authority: whether DTD may write/apply. |
| `decision_mode` | `plan` / `permission` / `auto` | How often DTD asks before taking non-destructive choices. |
| `attention_mode` | `interactive` / `silent` | Ask now, or defer safe-to-defer blockers and keep working. |

## Decision modes

- `plan`: ask at plan/phase boundaries and major plan changes. Good for careful
  human-led development.
- `permission`: default. Ask for permission, paid fallback, external paths,
  destructive actions, and ambiguous choices; auto-handle ordinary retries.
- `auto`: maximize forward progress. Still never auto-runs destructive actions,
  paid fallback, secret entry, external directory access, or partial apply.

## Commands

```text
/dtd run --silent=4h
/dtd run --decision auto --silent=4h
/dtd mode decision permission
/dtd silent on --for 4h
/dtd silent off
/dtd interactive
```

NL examples (localized phrases via locale packs per v0.2.0e):

| User phrase | Canonical |
|---|---|
| "go quietly for 4 hours" / "자러갈게 4시간 조용히 개발해줘" | `/dtd run --silent=4h` |
| "auto silent for 4h" / "4시간 자동진행, 조용히" | `/dtd run --decision auto --silent=4h` |
| "ask permission first" / "큰 결정은 물어보고 진행해" | `/dtd mode decision permission` |
| "ask at plan boundaries" / "계획 단위로만 물어봐" | `/dtd mode decision plan` |
| "go silent for X hours" / "/ㄷㅌㄷ 몇시간 동안 조용히 진행해줘" | `/dtd silent on --for <duration>` |
| "back to interactive" / "이제 질문하면서 진행해" | `/dtd interactive` |

## Interactive behavior

- Blocking decisions fill the decision capsule and pause/ask immediately.
- Status shows the active question and options.

## Silent behavior

- Do not ask the user for non-urgent choices during the silent window.
- Safe automatic actions are allowed: retry within policy, same-profile/free
  fallback if configured, task split under context gate, continue independent
  ready tasks.
- Unsafe or user-required choices are deferred: auth/secret setup, paid
  fallback, destructive options, external directory access, partial apply,
  ambiguous permission, and high-impact steering.
- Deferred blockers create incidents/attempt refs and are added to
  `state.md` `deferred_decision_refs`; the blocked task and its dependents are
  skipped for now, then the controller continues other ready work.
- Token/quota exhaustion is a hard resource boundary:
  - Worker token/quota exhaustion: try configured same-profile/free fallback
    while silent policy allows it; if all safe fallbacks fail, defer the task
    and continue independent ready work.
  - Controller token/quota exhaustion: checkpoint immediately, set
    `plan_status: PAUSED`, fill `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`,
    and wait. Silent mode cannot continue without the controller. See decision
    capsule body below.

## Decision capsule: CONTROLLER_TOKEN_EXHAUSTED

Filled when the controller (host LLM) hits its own token/quota wall and cannot
continue dispatching work — even safe ready work. This is distinct from
worker token exhaustion (which becomes a deferred per-task blocker in silent
mode).

```yaml
awaiting_user_decision: true
awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED
decision_id: dec-NNN
decision_prompt: "Controller token/quota exhausted (estimate: <usage>/<budget>). How to proceed?"
decision_options:
  - {id: wait_reset,        label: "wait for quota reset",            effect: "PAUSED until user resumes; no time-based auto-resume in v0.2.0f",                          risk: "no progress until manual resume"}
  - {id: switch_host_model, label: "switch host LLM model",            effect: "user-driven action: change controller model in host UI, then /dtd run; DTD itself does not switch", risk: "host capability re-detection may run on resume"}
  - {id: compact_and_resume, label: "compact run state and continue",  effect: "controller compacts notepad/logs to free tokens, runs `/dtd run` with smaller prefix",       risk: "loses some interpretive context; durable artifacts preserved"}
  - {id: stop,              label: "stop the run",                     effect: "finalize_run(STOPPED)",                                                                       risk: "lose run progress beyond saved files"}
decision_default: wait_reset
decision_resume_action: "user picks option; controller acts on chosen effect when next /dtd run or /dtd interactive turn arrives"
user_decision_options: [wait_reset, switch_host_model, compact_and_resume, stop]   # legacy back-compat
```

When this capsule fires while `attention_mode: silent`, the silent window is
interrupted but NOT auto-flipped. The controller cannot continue safely, but it
also must not assume the user is present. State updates in one atomic write:
- `plan_status: PAUSED`
- `last_pause_reason: error_blocked`
- Preserve `attention_mode`, `attention_until`, `attention_goal`, and
  `attention_mode_set_by` exactly as they were.
- The capsule above

The user sees the controller-exhaustion capsule on the next observable turn.
If the run was silent, also show a compact silent progress summary so the user
can decide whether to wait, switch host model, compact, or enter interactive.
The full morning-summary path is entered only when the user runs
`/dtd interactive` or explicitly resolves the capsule with an option that
surfaces deferred blockers.
- If no ready non-blocked tasks remain, set `plan_status: PAUSED` with
  `last_pause_reason: decision_capsule` and show a compact summary. Do not
  mutate attention mode as part of a read-only status render.
- Silent mode never auto-executes destructive actions, never expands path
  permissions, and never crosses `silent_max_hours`.

Mode can change mid-run. Switching to `interactive` surfaces the oldest
deferred blocker first. Switching to `silent` keeps the current phase/worker
state and applies the silent policy at the next decision point. Changing
`decision_mode` affects future decisions only; it does not retroactively
approve queued blockers.

## Silent-mode "ready work" algorithm

The behavior below assumes `config.attention.silent_blocker_policy:
defer_and_continue` (default). The alternative
`pause_on_first_blocker` short-circuits steps 1-3: on any blocker, set
`plan_status: PAUSED`, `last_pause_reason: silent_first_blocker`, surface
the morning summary on next user turn. `pause_on_first_blocker` is for
users who prefer single-blocker safety over multi-task progress; it
removes the "continue ready work" optimization but keeps the deferred-
incident snapshot path so the user still sees the full capsule on resume.

At each decision point in the run loop, while `attention_mode: silent` AND
`silent_blocker_policy: defer_and_continue`:

1. **Compute ready set**. A task is "ready" iff ALL hold:
   - It is in the active plan with `done=false`.
   - All its `depends-on` tasks are `done`.
   - It is NOT in the dependency closure of any `deferred_decision_refs`
     entry (the deferred-blocker task itself AND any task that transitively
     depends on it are excluded from ready set).
   - Its lock set in §Resource Locks does not conflict with currently held
     leases.
   - Its assigned worker is healthy (per worker registry; v0.2.1 `/dtd
     workers test` health is treated as advisory until then).
2. **If ready set is empty**:
   - If `deferred_decision_refs` is non-empty: set `plan_status: PAUSED`,
     `last_pause_reason: silent_window_ended_no_ready_work`, then trigger
     morning summary (see `/dtd interactive`).
   - If `deferred_decision_refs` is empty AND all tasks done: set
     `plan_status: COMPLETED`; call `finalize_run(COMPLETED)`.
   - If `deferred_decision_refs` is empty BUT some tasks remain non-ready
     for reasons unrelated to deferred blockers (e.g., stuck lock): pause
     with `last_pause_reason: silent_no_ready_work` and surface compact
     summary.
3. **If ready set is non-empty**: pick the next batch per the existing
   topo + parallel-group rules (§Run loop step 4). Dispatch under silent
   policy:
   - **Safe** auto actions: retry within `failure_threshold`, same-profile
     fallback (if `silent_allow_same_profile_fallback: true`), task split
     under context gate, lease takeover only if explicitly safe (no active
     heartbeat, lease older than `stale_threshold_min`).
   - **Unsafe** actions defer (see "Defer triggers" below).
4. **Defer triggers** — when the run loop hits one of these mid-task, the
   controller does NOT call `/dtd pause` or surface a capsule to chat;
   instead it:
   1. Creates an incident per the v0.2.0a model (severity = whatever the
      blocker's normal severity would be; the blocker still records as
      blocked-class).
   2. Snapshots the would-be decision capsule (reason, options, default,
      resume_action) into the incident detail file under a new
      `deferred_capsule:` key.
   3. Appends `inc-<run>-<seq>` to `state.md` `deferred_decision_refs`.
   4. Increments `deferred_decision_count`.
   5. Marks the task as `blocked` in `attempts/run-NNN.md` with `silent_deferred: true`.
   6. Releases the lease (so other ready work can proceed).
   7. Continues with the next ready batch.

### Defer triggers (silent mode)

| Trigger | Reason class |
|---|---|
| AUTH_FAILED, ENDPOINT_NOT_FOUND, NETWORK_UNREACHABLE | requires user attention |
| RATE_LIMIT_BLOCKED, WORKER_5XX_BLOCKED, TIMEOUT_BLOCKED | after configured retry exhausted |
| MALFORMED_RESPONSE | after retry exhausted |
| WORKER_INACTIVE | after `worker_inactive_wait_default_sec` |
| DISK_FULL, FS_PERMISSION_DENIED, FILE_LOCKED, PATH_GONE | always (never retry without user) |
| PARTIAL_APPLY, UNKNOWN_APPLY_FAILURE | always (`Automatic resume forbidden` rule still holds) |
| PERMISSION_REQUIRED, EXTERNAL_DIRECTORY_ACCESS | always |
| PAID_FALLBACK_REQUIRED | always (`silent_allow_paid_fallback: false` default) |
| Destructive recovery option needed | always (`silent_allow_destructive: false`) |
| RESOURCE_TAKEOVER (would steal active lease) | always |
| LOOP_GUARD_HIT (v0.2.1) | always |
| Steering classified medium/high impact mid-run | always |
| INCIDENT_BLOCKED chained on an already-deferred task | merge into existing incident |

### Auto-handle in silent (no defer)

| Trigger | Behavior |
|---|---|
| Recoverable 1st/2nd-hit (within failure_threshold) | retry per existing policy |
| Same-profile/free fallback in fallback chain | switch worker; record in attempt log |
| Task split on soft context cap | split + continue |
| Phase boundary | advance |
| Stale lease takeover (older than `stale_threshold_min`, no heartbeat) | takeover with audit note |

## Silent deferred-decision limit

`config.attention.silent_deferred_decision_limit` (default 20) hard-caps how
many blockers can pile up before silent mode pauses itself.

When `state.md.deferred_decision_count` reaches the limit:

1. Set `plan_status: PAUSED`.
2. Set `last_pause_reason: silent_deferred_limit`.
3. Print compact one-line surface in chat (it will be visible to the user
   when they next look at the host LLM):
   ```
   ⚠ silent paused: deferred_decision_limit=20 reached. Run /dtd interactive to review.
   ```
4. AIMemory `NOTE`: `silent_paused_deferred_limit, count=<N>`.
5. Do NOT auto-flip to interactive — the user explicitly invokes
   `/dtd interactive` to review. (Rationale: the user may have stepped away;
   auto-flipping would surface decisions to an empty terminal.)

The next `/dtd interactive` triggers the morning-summary path with the
deferred backlog.

## Silent mode and host.mode interaction

- `host.mode: plan-only`: `/dtd silent on` is rejected. Plan-only host cannot
  apply files; silent mode requires apply authority. Tell user:
  `silent on requires host.mode assisted or full. current: plan-only`.
- `host.mode: assisted`: works. Per-call confirms (when
  `assisted_confirm_each_call: true`) become defer triggers in silent.
- `host.mode: full`: works. Default expected combination for overnight runs.

## Anchor

This file IS the canonical source for v0.2.0f Autonomy & Attention.
v0.2.3 R1 extraction completed; `dtd.md` §Autonomy & Attention Modes
now points here.

## Related topics

- `persona-reasoning-tools.md` — v0.2.0f Codex addendum (compact stance + reasoning utilities + tool runtime).
- `perf.md` — `/dtd perf` controller vs worker token separation.
- `incidents.md` — silent-mode defer integrates with incident tracking via deferred_capsule:.
- `load-profile.md` — v0.2.3 lazy-load profile (recovery profile activates this content).
