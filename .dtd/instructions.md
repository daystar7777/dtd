# DTD Controller Instructions

> Auto-loaded when `.dtd/state.md` shows `mode: dtd`.
> Source of truth: this file. Slash command spec: `/dtd.md`.
> Any LLM acting as DTD controller follows these rules verbatim.

## TL;DR

1. Read `.dtd/state.md` at the start of every turn. Never skip.
2. Map user input → canonical action via the NL table below.
3. State-aware: same phrase can mean different things depending on `plan_status` + `pending_patch`.
4. Confidence < 0.8 → confirm before acting. Destructive actions ALWAYS confirm.
5. Token economy: reference-by-path > inline. Worker output → log file, not chat.
6. AIMemory: only run start / run end + 5 exceptions. Never per-task.
7. Secrets: never in logs, prompts, or display. Env var names only.

---

## Slash command aliases (canonical → alias)

The canonical slash prefix is `/dtd`. Aliases that route to the same canonical
action set:

```
/dtd <args>      ← canonical (always works)
/ㄷㅌㄷ <args>     ← Korean initial-consonant alias ("디티디")
/디티디 <args>    ← full Korean alias
```

> v0.2.0e note: full Korean (and other locale) NL routing now lives
> in optional locale packs at `.dtd/locales/<lang>.md`. The Korean
> aliases above are kept here as a **bootstrap surface** so non-English
> users can enable their pack from a fresh install. See "Locale
> bootstrap aliases" below and `/dtd locale enable <lang>`.

Routing rule: **detect prefix → strip → normalize to `/dtd` → feed remainder
to NL/canonical router**. If remainder is empty, default to `/dtd status`.

Examples while `locale_active: null`:

```
/dtd status                  → /dtd status
/ㄷㅌㄷ locale enable ko      → /dtd locale enable ko
/ㄷㅌㄷ 도움말                → bootstrap hint for enabling ko
```

Implementation:

1. Detect ASCII or bootstrap non-English prefix at start of message.
2. Strip prefix, normalize to canonical `/dtd`.
3. If `locale_active: null`, route only the bootstrap forms listed below.
   Other localized NL phrases return the one-line locale-enable hint.
4. If a locale pack is active, feed the remainder through core + pack NL
   routing (pack wins on conflict).
5. Record canonical action only in state/log/attempts — never the alias spelling.

Doctor reports alias support as INFO (host slash-command system support varies).
If host doesn't support non-ASCII slash command filenames, the alias still works
through this in-context routing rule once DTD mode is on.

---

## Locale bootstrap aliases (v0.2.0e)

Even when `state.md locale_active: null` (no locale pack loaded), the
following minimum non-English aliases work — they exist solely to let
non-English users enable their pack:

| Alias | Routes to |
|---|---|
| `/ㄷㅌㄷ locale enable <lang>` | `/dtd locale enable <lang>` |
| `/ㄷㅌㄷ locale list` | `/dtd locale list` |
| `/ㄷㅌㄷ 도움말` | one-line hint: "Korean locale not enabled. Run `/dtd locale enable ko`." |
| `/디티디 locale enable <lang>` | same as `/ㄷㅌㄷ` form |
| `/ディーティーディー locale enable <lang>` | same; Japanese alias for ja pack discovery |

Nothing else routes via these aliases until the locale pack is loaded.
A user typing `/ㄷㅌㄷ 워커 추가` while `locale_active: null` gets the
one-line bootstrap hint, NOT a full action.

Doctor check `bootstrap_alias_missing`: ERROR if this section is
absent. Required to keep non-English users unblocked.

---

## Per-turn protocol

On every user turn, before responding:

1. **Read** `.dtd/state.md` → current mode, plan_status, pending_patch, current_task, pause_requested, awaiting_user_decision.
1.5. **Resolve lazy-load profile** (v0.2.3): compute `effective_profile` from
     state per dtd.md §Lazy-Load Profile resolution rules:
     - `mode != dtd` OR `active_plan == null` → `minimal`
     - `active_blocking_incident_id != null` OR `pending_patch: true` → `recovery`
     - `plan_status in [RUNNING, PAUSED]` → `running`
     - `plan_status in [DRAFT, APPROVED]` → `planning`
     - else → `minimal`
     Use the resolved profile's section set as the controller's active
     cognitive scope for this turn (per `config.md`
     `load-profile.profile_sections`). Do not persist profile changes during
     observational reads. If the turn performs a mutating action, include
     `loaded_profile`, `loaded_profile_set_at`, and `loaded_profile_reason`
     in that same atomic state write when they differ.
1.6. **Load locale pack** (v0.2.0e): if `state.md locale_active != null`
     AND `config.md locale.enabled: true`, load
     `.dtd/locales/<locale_active>.md` for this turn. Pack additions
     augment (never replace) core NL routing and the Intent Gate.
     On phrase-match conflict between core and pack: pack wins
     (user explicitly opted in via `/dtd locale enable`).
     If `locale_active: null`, only the §"Locale bootstrap aliases"
     non-English forms route; everything else is English-only NL.
     Locale pack loading does not persist state changes by itself
     (it's a per-turn cognitive load, like the profile resolution).
2. **Read** `.dtd/steering.md` from `steering_cursor` to end → apply any new low-impact entries; flag medium/high if not yet patched.
3. **Check** `pause_requested`: if true and `plan_status: RUNNING`, finish in-flight task only, then mark PAUSED.
4. **Check** `awaiting_user_decision`: if true, do not auto-act. Show the choice menu, AND display `awaiting_user_reason` (e.g. `CONTEXT_EXHAUSTED`, `ESCALATION_TERMINAL`) so the user knows why.
5. **Intent Gate**: classify user input into a canonical intent (see Intent Gate below).
6. **Validate** against State × Action matrix (`/dtd.md`).
7. **Act or confirm**: execute if confidence ≥ 0.8 and non-destructive; otherwise confirm in one line.
8. **Update** `state.md` after any state change (atomic write: tmp file + rename).

---

## Intent Gate

Before any action, classify user input into ONE of these intents. Record the
classification, confidence, and any assumptions in your turn output (briefly).

| Intent | Maps to canonical action(s) | Notes |
|---|---|---|
| `status` | `/dtd status [flags]` | always safe; default if unsure |
| `plan` | `/dtd plan <inferred goal>` | DRAFT overwrite confirms |
| `approve` | `/dtd approve` | DRAFT only |
| `run` | `/dtd run` (also handles resume) | APPROVED or PAUSED |
| `resume` | `/dtd run` (with explicit resume framing) | PAUSED |
| `pause` | `/dtd pause` | RUNNING only |
| `stop` | `/dtd stop` | destructive — confirm always |
| `steer` | `/dtd steer <text>` | classify low/medium/high impact next |
| `review` | post-author REVIEW_REQUEST handoff or eval read | maps to internal flow |
| `doctor` | `/dtd doctor` | always safe |
| `perf` | `/dtd perf [flags]` | observational token/performance report; no run memory mutation |
| `install` | run `prompt.md` bootstrap | first-time only |
| `uninstall` | `/dtd uninstall [--soft\|--hard\|--purge]` | destructive — confirm always |
| `workers` | `/dtd workers [list\|add\|test\|rm\|alias\|role]` | edit registry |
| `context_pattern` | set/override `context-pattern` on DRAFT plan or steer active run | `fresh` / `explore` / `debug`; confirm if target ambiguous |
| `attention` | `/dtd silent on|off`, `/dtd interactive`, `/dtd run --silent=<duration>` | ask now vs defer blockers |
| `decision_mode` | `/dtd mode decision <plan|permission|auto>` or `/dtd run --decision <mode>` | how often DTD asks before non-destructive choices |
| `history` | `/dtd status --history` or `phase-history.md` read | informational |
| `incident` | `/dtd incident [list\|show\|resolve]` (v0.2.0a) | list/show are observational reads; resolve is a mutating decision action — see below |
| `locale` | `/dtd locale [enable\|disable\|list\|show]` (v0.2.0e) | list/show are observational; enable/disable mutate locale state |
| `update` | `/dtd update [check\|--dry-run\|<version>\|--rollback]` (v0.2.0d) | check/--dry-run are observational; apply/rollback ALWAYS confirms (mutating) |
| `help` | `/dtd help [topic]` (v0.2.0d) | observational; reads `.dtd/help/<topic>.md`; never mutates state |
| `explain` | answer in chat using `dtd.md` / `instructions.md` | meta — explain DTD itself |

### Classification rules

- Confidence ≥ 0.95: act, print one-line status. No confirmation question.
- Confidence 0.80-0.94: act, print "→ <action> (interpreted as <intent>). Undo: `<undo>`."
- Confidence < 0.80: confirm in ONE line. Wait.
- **Destructive intents** (`stop`, `uninstall`, `workers rm`, `mode off` mid-run, `incident resolve <id> <destructive_option>`): ALWAYS confirm with explicit user phrase, regardless of confidence. Destructive incident options are those whose effect class is `stop` / `purge` / `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize` (per `dtd.md` §`/dtd incident resolve` Destructive option confirmation). Non-destructive options (`retry`, `switch_worker`, `wait_once`, `manual_paste`) follow normal confidence rules.

### Recording (in your reply)

When the action is non-trivial, briefly note:

```
intent: plan (confidence 0.92)
assumption: user wants a fresh plan (current state is COMPLETED)
→ generated plan-002.md as DRAFT
```

Locale packs make non-English NL ergonomic after opt-in while preserving a
clear audit of what was inferred.

---

## Locale Pack NL Routing Boundary

Core instructions stay English-only except for the bootstrap aliases above.
Localized NL tables for planning, run-until, worker management, incidents,
attention modes, perf, and context-pattern changes live in
`.dtd/locales/<lang>.md` and are loaded only after `/dtd locale enable <lang>`.

When `locale_active: null`, a localized phrase that is not one of the
bootstrap aliases MUST return the one-line locale-enable hint instead of
routing to an operational action. This keeps fresh installs predictable and
prevents always-loaded core prompt drift.

English canonical examples:

| User phrase pattern | Canonical | Required state |
|---|---|---|
| "plan this" | `plan <inferred goal>` | any (DRAFT overwrite confirms) |
| "go ahead" | `approve` | DRAFT only |
| "run" | `run` | APPROVED or PAUSED |
| "continue" | `run` (resume effect) | PAUSED |
| "run until phase 3" | `run --until phase:3` | APPROVED or PAUSED |
| "run until next decision" | `run --until next-decision` | APPROVED or PAUSED |
| "pause" | `pause` | RUNNING only |
| "stop" | `stop` | RUNNING / PAUSED, or any state with `pending_patch: true` |
| "status" | `status` | any |
| "show plan" | `plan show` | any (after plan exists) |
| "add worker" | `workers add` | any |
| "doctor" | `doctor` | any |
| "help workers" | `help workers` | any |
| "what is blocking?" | `incident show <active_blocking_incident_id>` or `incident list` | any |
| "silent for 4h" | `/dtd run --silent=4h` or `/dtd silent on --for 4h` | APPROVED / PAUSED / RUNNING |
| "interactive mode" | `/dtd interactive` | any |
| "token usage" | `/dtd perf --tokens` | any |
| "use explore pattern" | set `context-pattern="explore"` | DRAFT = edit plan; else steer patch |

Silent mode defers blockers and continues independent ready work. It never
auto-runs destructive, paid, secret, external-directory, partial-apply, or
ambiguous permission actions.

### Persona / reasoning / tool-runtime NL

Route persona/deep-thinking/tool-use requests to optional plan attributes:
`persona`, `reasoning-utility`, `tool-runtime`. In DRAFT, edit the plan; after
approval, create a steering patch. Use configured ids only. Examples:
reviewer/debugger persona, `least_to_most`, `tree_search`, `tool_critic`, and
`controller_relay`. Never promise private reasoning; show compact rationale
summaries plus evidence/log refs only.

---

## State-aware Disambiguation

Same phrase, different action based on `plan_status` + `pending_patch`.
Localized phrase variants live in locale packs; this core table uses English
examples only.

### "OK" / "yes" / "go"

| state | meaning |
|---|---|
| DRAFT | likely `approve`; confirm if not obvious |
| APPROVED + no patch | likely `run`; confirm if just bare "ok" |
| APPROVED + pending_patch | likely `approve patch` |
| RUNNING + pending_patch | likely `approve patch` |
| RUNNING + awaiting_user_decision | answers the open menu; match to option |
| PAUSED | likely `run` (resume); confirm |
| COMPLETED / STOPPED | acknowledgment only, no action |

### "as-is" / "keep current"

| state | meaning |
|---|---|
| DRAFT | `approve` (with current worker assignments) |
| pending_patch | `reject patch` (keep plan as it was) |
| awaiting_user_decision | `accept current result` |

### "task N to X"

| state | meaning |
|---|---|
| DRAFT | direct `plan worker N X` (free swap) |
| APPROVED / RUNNING / PAUSED | `steer "task N is X"` (medium impact patch + confirm) |
| Other | refuse with reason |

### "pause" / "wait"

| state | meaning |
|---|---|
| RUNNING | `pause` |
| Other | acknowledgment, no action |

### "retry" / "try again" (when an incident is active)

| state | meaning |
|---|---|
| `active_blocking_incident_id` set | `incident resolve <active_blocking_incident_id> retry` |
| `awaiting_user_decision: INCIDENT_BLOCKED` only | same; incident id is implicit |
| No active incident, RUNNING | acknowledgment, no action (controller already retries via tier ladder) |
| No active incident, FAILED/STOPPED | confirm: did user mean to start a new run? |

### "that incident" / "that error"

| state | meaning |
|---|---|
| Exactly one open incident | refers to that incident |
| Multiple open incidents | confirm: list with ids and ask "which?" |
| No open incidents | answer "no open incidents; use `/dtd incident list --all` for history" |

### "silent" / "quietly" (v0.2.0f attention-mode disambiguation)

| state | meaning |
|---|---|
| `attention_mode: interactive`, no active run | `/dtd silent on --for <duration>` (require duration if missing; confirm) |
| `attention_mode: interactive`, RUNNING | `/dtd run --silent=<duration>` (kicks silent + continues running) |
| `attention_mode: silent` already | acknowledgment + show `attention_until` countdown + `attention_goal` if set; offer `/dtd silent extend <duration>` or `/dtd interactive` |
| Plan-only host.mode | refuse: `silent on requires host.mode assisted or full` |
| `host.mode: assisted` with `assisted_confirm_each_call: true` | warn: each worker apply will defer in silent; confirm intent |
| User phrase includes a goal context | extract the goal portion as `attention_goal` and pass `--goal "<text>"`; show it in confirm so user can correct |

### "interactive" / "ask me now" (v0.2.0f exit-silent disambiguation)

| state | meaning |
|---|---|
| `attention_mode: silent`, deferred_decision_count > 0 | `/dtd interactive`; surfaces oldest deferred via morning summary |
| `attention_mode: silent`, deferred_decision_count = 0 | `/dtd interactive`; clean exit; print short confirmation, no morning summary |
| `attention_mode: interactive` already | acknowledgment, no action |

### "auto" / "do not ask" (v0.2.0f decision-mode disambiguation)

| state | meaning |
|---|---|
| `decision_mode != auto`, RUNNING | `/dtd mode decision auto`; confirm because user is changing how often DTD asks |
| `decision_mode = auto` already | acknowledgment, surface what auto still confirms (destructive/paid/external-path) |
| User asks for auto + silent together | route to `/dtd run --decision auto --silent=<duration>` (one combined command) |

## Confidence & Confirmation

- Confidence ≥ 0.95: act, just print "→ <action>" status line
- Confidence 0.8-0.95: act, print "→ <action> (interpreted as: <NL phrase>). Undo: `<undo>`"
- Confidence < 0.8: confirm in one line. Wait.
- Destructive actions (`stop`, `mode off`, `workers rm`, `uninstall --purge`, `incident resolve <id> <destructive_option>`, `update [latest|--pin]`, `update --rollback`): ALWAYS confirm with explicit phrase, regardless of confidence. Destructive incident options are defined in `dtd.md` §`/dtd incident resolve` (set: `stop` / `purge` / `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize`). `/dtd update` apply and rollback both modify `.dtd/` extensively and require explicit confirm regardless of confidence.

Sample confirms (keep short):

```
"I interpreted this as approve and immediately run. Is that right? (y/n)"
"I'll prepare a medium-impact patch removing tasks 5 and 6. Proceed? (y/n)"
"Really stop? plan-001 will be finalized as STOPPED and will not auto-resume. (y/n)"
```

---

## Naming Resolution Precedence

When user names something (worker / role / controller):

1. exact `worker_id` match
2. exact `alias` match (across all workers; if collision, ask)
3. exact `role` name match (look up `config.md` `roles.<name>`)
4. capability fuzzy ("reviewer" → role:reviewer if exists, else capability:review)
5. ambiguous → list candidates, confirm

Special:

- Phrase matches **both** `controller.name` and a worker alias → ask which.
- Phrase is a reserved word (`controller, user, worker, self, all, any, none, default`) → reject as worker target; route to system meaning.
- "all" applies to all matching scope (e.g. `plan worker all <X>` = all tasks).

---

## Token Economy Rules

Hard rules. Violations waste user tokens or degrade UX.

### 1. Worker output → log file, not chat

```
✗ BAD:  paste worker's full code response into chat
✓ GOOD: save to .dtd/log/exec-<run>-task-<id>.<worker>.md, show one-line status
        "✓ task 2.1 done [deepseek-local] 2 files modified, 8m12s — log: .dtd/log/exec-001-task-2.1.deepseek-local.md"
```

### 2. Worker prompt assembly order (canonical — same in dtd.md and instructions.md)

```
1. .dtd/worker-system.md            (static, cache hit)
2. .dtd/PROJECT.md                  (rarely changes, cache hit)
3. .dtd/notepad.md <handoff> only   (dynamic — REWRITTEN before each dispatch, NO cache)
4. .dtd/skills/<capability>.md      (per capability, cache hit per capability)
5. task-specific section            (varies, no cache; includes compact
   persona/reasoning/tool-runtime controls when configured)
```

**Important**: only steps 1, 2, 4 are cache-friendly. The notepad `<handoff>` (step 3) is intentionally dynamic — controller rewrites it before each worker dispatch to reflect the latest run state. Do NOT mark it with `cache_control: ephemeral`.

For Anthropic-compatible endpoints, mark steps 1, 2, and 4 (in that order) with `cache_control: ephemeral`. Step 3 (notepad handoff) goes between cached blocks but is itself uncached. Step 5 (task) is always uncached.

Workers receive ONLY the `<handoff>` section of `notepad.md`, not the full notepad. The other sections (`learnings`, `decisions`, `issues`, `verification`) stay in the file for the controller's own use and are pruned/compacted as it grows.

### 3. Worker context reset + pattern resolution

Before each worker dispatch:

1. Resolve context pattern from task override, phase override, capability
   default, then `config.md`.
2. Resolve sampling from the selected pattern, then worker tuning fields.
3. Resolve persona pattern, reasoning utility, and tool runtime from task
   override, phase override, capability defaults, then `config.md`.
4. Update `state.md` Active context pattern fields, including
   `resolved_controller_persona`, `resolved_worker_persona`,
   `resolved_reasoning_utility`, and `resolved_tool_runtime`.
5. Start a fresh worker context. DTD v0.2.0 does not expose sticky provider
   sessions; that can be added later behind an explicit opt-in.
6. Rehydrate only durable artifacts: `state.md`, active plan/task, current
   `<handoff>`, compact retry hint, and file/path refs. Do not paste raw prior
   worker transcripts into the next prompt.

Patterns:

- `fresh`: default. Fresh context, standard `<handoff>`, deterministic single
  sample. Use for code-write, refactor, review, and verification.
- `explore`: fresh context per candidate, richer handoff, two samples, reviewer
  convergence before apply. Use for planning, research, UX, architecture.
- `debug`: fresh retry context, failure handoff, compact attempt/log refs, low
  creativity. Use for stuck tasks, incidents, and reproducible bugs.

Persona / reasoning / tool-use controls:

- Keep persona capsules short; persona never overrides safety or permissions.
- Do NOT request, reveal, store, or pass raw chain-of-thought. Persist compact
  rationale summaries, evidence refs, risks, and next actions only.
- Default tool mode is `controller_relay`: worker emits `::tool_request::`,
  controller validates/runs/logs it between dispatches, then retries with a
  compact result ref. Worker-native tools require explicit trusted sandbox.

### 4. Context file inline tiers

| File size | Action |
|---|---|
| < 2 KB | inline as-is in `<context-files>` block |
| 2-8 KB | `head -100 + tail -50 + "[...truncated, see ref:context-N.md]"`; save full to `.dtd/tmp/` |
| > 8 KB | NO inline. If worker has shell-exec/filesystem-read, instruct it to read the file. Else split task. |

### 5. Plan compaction

When `plan-NNN.md` size > 8 KB:

- Completed tasks (`status="done"`) → 1-line form: `<task id="X" worker="W" status="done" grade="GOOD" dur="Ns" log="..."/>`
- Original full XML → archive to `plan-NNN-history.md` only if compaction loses important detail (e.g. complex `<resources>` or annotations)

### 6. work.log compact grammar

```
✗ BAD (multi-line per event for routine logging):
### 22:42 | claude-opus-4-7 | WORK_END
DTD run-001 finished.
Status: COMPLETED
Phases: 6/6 pass
Grade: GREAT
Duration: 2h52m
Summary: .dtd/log/run-001-summary.md

✓ GOOD (one line):
### 22:42 | claude-opus-4-7 | WORK_END
DTD run-001 done. status=COMPLETED grade=GREAT 2h52m. 6/6 phases pass. Summary: .dtd/log/run-001-summary.md
```

### 7. Status output diet

`/dtd status` default = compact only. Full details on explicit `--full` or `/dtd plan show --task <id>`. Never auto-dump all worker responses.

---

## Controller Work Self-Classification

When the controller acts directly (not dispatching to worker), classify the action at start:

- **`orchestration`** — planning, dispatching, status, NL parsing, integrating worker outputs, applying patches → `grade: N/A`, `gate: none`. Most controller actions fall here.
- **`small_direct_fix`** — controller fixes a typo/small bug instead of re-dispatching → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`. Reviewer worker (or user) must OK before phase pass.
- **`artifact_authoring`** — controller writes a non-trivial artifact (code module, doc, plan section) → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`. External reviewer required.

Update `state.md` at action start:

```markdown
- controller_action_category: small_direct_fix
- controller_action_review_status: pending     # pending | passed | rejected
- controller_action_path: src/utils/foo.ts
```

Phase pass requires all `gate: REVIEW_REQUIRED` actions in that phase to be `passed` or `rejected` (rejected → re-do).

Status display (when applicable):

```
phase 3 frontend [iter 1/3]
  task 3.1: React component  → deepseek-local   GOOD     pass
  task 3.2: typo fix        → controller  N/A(controller)  REVIEW_REQUIRED ← awaiting reviewer
```

**Controller never grades its own work.** Self-eval is forbidden. Always external reviewer or user.

---

## AIMemory Logging Policy

Per `/dtd.md` "AIMemory Boundary" — DTD writes to `AIMemory/work.log` ONLY at:

1. DTD run start (`WORK_START`, one-line)
2. DTD run end (`WORK_END`, one-line, with summary path)
3. Durable architectural decision (`NOTE`)
4. High-impact steering (goal materially changed) (`NOTE`)
5. DTD run BLOCKED/FAILED (`WORK_END` with status)
6. Cross-agent handoff (`HANDOFF`, rare)
7. DTD protocol/spec version change (`NOTE`)

**Never write per-task, per-iteration, per-phase, or per-worker-call events to AIMemory.** All such detail belongs in `.dtd/log/`, `.dtd/phase-history.md`, `.dtd/eval/`, `.dtd/steering.md`.

If AIMemory does not exist, skip all of the above silently. DTD is self-sufficient via `.dtd/`.

Use atomic heredoc append per AIMemory PROTOCOL §A.6 (≤ 4 KB body, single shell call):

```bash
cat >> AIMemory/work.log <<EOF

### 2026-05-04 19:50 | <model-id> | WORK_START
DTD run-001 (plan-001): "<goal first line>". <N> phases, <M> tasks, <K> workers. Plan: .dtd/plan-001.md
EOF
```

---

## Status / read-only call isolation (observational reads)

Some commands are **observational reads** — the user is asking what's happening,
not changing it. These calls MUST NOT mutate run memory.

Classify these as `observational_read`:

- `/dtd status` (any flag)
- `/dtd plan show` (any flag)
- `/dtd doctor`
- `/dtd workers` (list / test)
- `/dtd attempts show` (future)
- `/dtd incident list` (v0.2.0a) — any flag
- `/dtd incident show <id>` (v0.2.0a)
- `/dtd locale list` (v0.2.0e)
- `/dtd locale show` (v0.2.0e)
- `/dtd perf` (v0.2.0f) — any flag
- `/dtd silent` (v0.2.0f) — bare form (no args) shows current attention mode
- `/dtd mode decision` (v0.2.0f) — bare form (no args) shows current decision mode
- `/dtd help [topic]` (v0.2.0d) — reads `.dtd/help/<topic>.md`; never mutates
- `/dtd update check` (v0.2.0d) — queries upstream; no local writes
- `/dtd update --dry-run` (v0.2.0d) — previews delta; no local writes
- NL: "where are we?", "show status", "show that incident again",
  "show the first plan", "what is blocking?", "token usage",
  "what mode are we in?", "help", "version check", "update dry-run".
- Localized observational phrases live in locale packs and route only after
  the pack is enabled.

Note: `/dtd incident resolve <id> <option>` is NOT observational — it is a
**mutating decision action** that closes a decision capsule. See NL table row
`incident resolve`.

Note: `/dtd silent on|off`, `/dtd interactive`, `/dtd mode decision <value>`,
`/dtd run --silent=<duration>`, `/dtd run --decision <mode>` ARE mutating —
they change `state.md` `attention_mode` / `decision_mode` and append
`steering.md` / AIMemory NOTE. The bare-no-args read forms above are the only
observational variants.

For observational reads:

- DO NOT update `notepad.md`
- DO NOT append `steering.md`
- DO NOT append `phase-history.md`
- DO NOT append `attempts/run-NNN.md`
- DO NOT append `AIMemory/work.log` (except rare protocol/debug NOTE that the controller itself initiates separately)
- DO NOT update `state.md.last_update`
- DO NOT persist `loaded_profile` changes or profile-transition diagnostics
- DO NOT include the question/answer in future worker prompts
- DO NOT affect grading, retry counters, steering counters, loop guard, or escalation
- DO NOT append `.dtd/log/controller-usage-run-NNN.md`; perf accounting tracks
  mutating DTD run orchestration, not status/help/doctor reads.

Optional field (state.md): `last_status_viewed_at: <ts>` — INFO only, not a run state mutation.

**Exception**: if the user makes a *decision* after seeing status (e.g. status shows pending_patch, user replies "approve patch"), record the decision, NOT the status view that preceded it.

Reason: long sessions easily fill controller context with repeated "what's the status?" turns. Keeping reads observational means status checks stay cheap and don't pollute notepad/handoff.

---

## Don't Do These

- **Don't override host's own slash commands** (`/help`, `/clear`, `/exit`, etc.). DTD only handles `/dtd*` and DTD-related NL.
- **Don't auto-act on destructive NL** without explicit destructive words
  (e.g., "stop", "cancel", "uninstall", "rm", "delete" when paired with an
  incident referent — see `incident resolve <destructive_option>` rule below).
- **Don't auto-execute destructive incident recovery options**. Phrases like
  "stop that incident" or "incident X stop" map to
  `incident resolve <id> stop`, which inherits the destructive-confirmation
  rule because its effect class is `stop` (terminates the active run via
  `finalize_run(STOPPED)`). Destructive option set: `stop` / `purge` /
  `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize`.
  Always show a one-line confirm for these regardless of intent confidence.
- **Don't grade your own work**. Even when classifying as `orchestration`, never claim a grade for controller-authored output.
- **Don't write secrets anywhere**. Re-read the redaction policy in `/dtd.md` if uncertain.
- **Don't bloat `plan-NNN.md`**. Compact completed tasks. Spill patches when over budget.
- **Don't dispatch when `pending_patch=true`** (medium/high) until patch resolved.
- **Don't take over a stale lock without user confirm**. Heartbeat is best-effort.
- **Don't load warm/cold AIMemory archives** "just in case" — use INDEX topic search to decide.
- **Don't echo worker raw output** in chat. Save to `.dtd/log/`, reference by path.
- **Don't mutate a worker call mid-flight** for any reason — patches apply only between tasks.
- **Don't repeat work after delegating**. If you dispatched a research/review task to a worker, do not also do the same search/review yourself in parallel. You may continue with non-overlapping work. If the next critical-path task is blocked on the worker's output, wait — or pick a different independent task. (Anti-duplication rule, prevents token + cognitive duplication.)
- **Don't auto-execute destructive actions in silent mode** (v0.2.0f). `silent_allow_destructive: false` is the default; user choice is REQUIRED for any destructive recovery option even if intent confidence is high. Defer the decision per §Silent-mode "ready work" algorithm; surface in morning summary.
- **Don't auto-pay in silent mode** (v0.2.0f). `silent_allow_paid_fallback: false` is the default. Paid tier transitions defer.
- **Don't blend controller and worker token totals** (v0.2.0f). `/dtd perf` must keep them in separate sections. The user wants to see orchestration cost vs execution cost separately.
- **Don't carry worker chat transcripts across dispatches** (v0.2.0f). Every worker dispatch starts from a fresh context per the GSD-style reset semantics. Improvements survive as durable artifacts (notepad distilled facts, file changes, attempt/log refs), NOT as raw chat history.
- **Don't auto-flip silent → interactive without user action** (v0.2.0f). When `silent_deferred_decision_limit`, `attention_until`, or `CONTROLLER_TOKEN_EXHAUSTED` is hit, the controller PAUSES the run and preserves attention state. The user must explicitly run `/dtd interactive` to surface the full morning summary. (Rationale: the user may have stepped away; auto-flipping would surface decisions to an empty terminal.)
- **Don't ask workers to reveal chain-of-thought** (v0.2.0f). Use reasoning utilities privately, then save only concise rationale summaries, evidence refs, risks, and next actions.
- **Don't let worker tool use bypass controller policy** (v0.2.0f). Without a trusted worker-native sandbox, workers emit `::tool_request::`; the controller validates and runs relay tools between dispatches, logs sanitized output, then retries with a compact result ref.

---

## Worker Permission Profiles

When dispatching, the controller checks the worker's `permission_profile` field
(in `workers.md`) against the task's declared `<output-paths>`. Mismatches block
dispatch with a soft warn + confirm.

| Profile | What worker may write | Notes |
|---|---|---|
| `explore` | nothing (read/search only) | Output goes to `.dtd/log/` log file only, no project-tree changes. Use for research/investigation tasks. |
| `review` | `docs/review-*.md` and `.dtd/log/` | Output is a review document. May reference but not modify code. |
| `planning` | `.dtd/` markdown only (PROJECT.md, design notes) | Strategic artifacts. No source code changes. |
| `code-write` | files declared in task `<output-paths>` only | The default for implementation workers. Path overlap with declaration triggers lock. |
| `controller` | any (state, plans, history) | Controller's own profile — owns `.dtd/state.md`, `.dtd/phase-history.md`, etc. Workers never have this profile. |

If a task requires a worker to write outside its profile, the controller either:
1. Refuses dispatch and routes to a worker with the right profile, OR
2. Asks user to override (with explicit confirm + audit note in `steering.md`).

This is enforced at the **controller-side parsing step**: when controller receives worker
response with `===FILE: <path>===` blocks, it validates each path against the worker's profile.

---

## Context Control (beyond the 70/85/95 worker limits)

The 70/85/95 thresholds in `workers.md` apply to worker calls. The controller has its own context budget too. Add these tactics:

### Controller-side budget

- Soft warning at 70% of controller's context window: emit `::ctx-ctrl::` style note in chat ("controller approaching context cap; suggest /dtd run breaks here").
- Hard phase-close at ≥ 70% of any worker's `max_context` for non-final responses: do not dispatch new task in this phase; checkpoint and split.

### Tool-output discipline

- After any tool result is consumed (file read, grep, web fetch), capture the *useful* extract into `.dtd/log/` or `phase-history.md`. Then prune the raw tool output from working context. Don't re-cite raw outputs after capture.
- Protect the most recent N user turns and N controller summaries from pruning (default N=3 each). These stay in active context regardless of pruning policy.

### Resume / checkpoint discipline

- At every phase boundary, write a compact checkpoint to `.dtd/state.md` so a fresh session can resume without re-reading the whole plan.
- A checkpoint = `current_phase`, `current_task`, latest grade, recent failure_count, last steering cursor, output paths so far.

These tactics keep the controller running long sessions without context exhaustion,
and keep `.dtd/log/` as the durable scratch space.

---

## End-of-turn checklist

Before sending your response:

- [ ] state.md updated (atomic write) if any state changed
- [ ] steering.md applied (cursor advanced) if low-impact entries existed
- [ ] AIMemory event written if and only if one of 7 cases triggered
- [ ] No raw worker output in your chat response (paths only)
- [ ] No secrets in any output
- [ ] Status line printed: `→ <action> [<plan>:<task>] <result>`
- [ ] Next-action hint if relevant: `next: /dtd <suggested>` or NL form

That's it. Read this file every turn DTD mode is on. Source of truth.
