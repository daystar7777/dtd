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

Routing rule: **detect prefix → strip → normalize to `/dtd` → feed remainder
to NL/canonical router**. If remainder is empty, default to `/dtd status`.

Examples (all equivalent):

```
/dtd status                     → /dtd status
/ㄷㅌㄷ 상태                     → /dtd status
/ㄷㅌㄷ 상태보여줘                → /dtd status (NL → status intent)
/디티디 지금 어디까지 됐어?       → /dtd status
/ㄷㅌㄷ 워커 추가                 → /dtd workers add
/ㄷㅌㄷ qwen 워커 하나 추가해줘    → /dtd workers add (with alias hint "qwen")
```

Implementation:

1. Detect ASCII or Korean prefix at start of message.
2. Strip prefix, normalize to canonical `/dtd`.
3. Feed remainder through NL intent router (per Intent Gate below).
4. Record canonical action only in state/log/attempts — never the alias spelling.

Doctor reports alias support as INFO (host slash-command system support varies).
If host doesn't support non-ASCII slash command filenames, the alias still works
through this in-context routing rule once DTD mode is on.

---

## Per-turn protocol

On every user turn, before responding:

1. **Read** `.dtd/state.md` → current mode, plan_status, pending_patch, current_task, pause_requested, awaiting_user_decision.
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
| `install` | run `prompt.md` bootstrap | first-time only |
| `uninstall` | `/dtd uninstall [--soft\|--hard\|--purge]` | destructive — confirm always |
| `workers` | `/dtd workers [list\|add\|test\|rm\|alias\|role]` | edit registry |
| `history` | `/dtd status --history` or `phase-history.md` read | informational |
| `incident` | `/dtd incident [list\|show\|resolve]` (v0.2.0a) | list/show are observational reads; resolve is a mutating decision action — see below |
| `explain` | answer in chat using `dtd.md` / `instructions.md` | meta — explain DTD itself |

### Classification rules

- Confidence ≥ 0.95: act, print one-line status. No confirmation question.
- Confidence 0.80-0.94: act, print "→ <action> (interpreted as <intent>). 되돌리려면 `<undo>`".
- Confidence < 0.80: confirm in ONE line. Wait.
- **Destructive intents** (`stop`, `uninstall`, `workers rm`, `mode off` mid-run, `incident resolve <id> <destructive_option>`): ALWAYS confirm with explicit user phrase, regardless of confidence. Destructive incident options are those whose effect class is `stop` / `purge` / `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize` (per `dtd.md` §`/dtd incident resolve` Destructive option confirmation). Non-destructive options (`retry`, `switch_worker`, `wait_once`, `manual_paste`) follow normal confidence rules.

### Recording (in your reply)

When the action is non-trivial, briefly note:

```
intent: plan (confidence 0.92)
assumption: user wants a fresh plan (current state is COMPLETED)
→ generated plan-002.md as DRAFT
```

This makes Korean-first NL ergonomic without the user having to memorize commands,
while still giving them a clear audit of what was inferred.

---

## NL → Canonical Action Mapping

| User phrase pattern (Korean) | English equivalent | Canonical | Required state |
|---|---|---|---|
| "계획 짜줘", "이 목표로 정리", "이거 어떻게 할까" | "plan this", "make a plan" | `plan <inferred goal>` | any (DRAFT overwrite confirms) |
| "좋아 진행", "ok 시작", "그대로 가" | "approve", "go ahead" | `approve` | DRAFT only |
| "실행해", "돌려", "시작" | "run", "execute" | `run` | APPROVED or PAUSED |
| "이어서", "계속해" | "continue", "resume" | `run` (resume effect) | PAUSED |
| "3페이즈까지만 해줘", "phase 3까지 돌려" | "run until phase 3" | `run --until phase:3` | APPROVED or PAUSED |
| "리뷰 전까지만 돌려" | "run until before review" | `run --until before:review` | APPROVED or PAUSED |
| "UI 만들고 멈춰", "task X끝나면 멈춰" | "run until task X" | `run --until task:<id>` | APPROVED or PAUSED |
| "다음 결정나오면 멈춰" | "run until next decision" | `run --until next-decision` | APPROVED or PAUSED |
| "잠깐", "멈춰", "기다려" | "pause", "wait" | `pause` | RUNNING only |
| "그만", "취소", "관둬" | "stop", "cancel", "abort" | `stop` | RUNNING / PAUSED, or any state with `pending_patch: true` |
| "지금 어디까지", "진행상황", "어떻게 돼가" | "status", "where are we" | `status` | any |
| "처음 계획 보여줘", "계획 다시 보여줘" | "show plan" | `plan show` | any (after plan exists) |
| "task N은 X로", "phase N은 X가" | "task N to X" | `plan worker` (DRAFT) or `steer` (post-DRAFT) | DRAFT → swap; else patch |
| "워커 추가", "X 등록" | "add worker", "register X" | `workers add` | any |
| "X 빼줘", "워커 제거" | "remove worker" | `workers rm` | any |
| "X에 별명 Y", "Y로 부를게" | "alias X as Y" | `workers alias add` | any |
| "리뷰어를 X로", "primary는 Y로" | "set role to X" | `workers role set` | any |
| "방향 바꾸자", "이번엔 안정성 우선" | "steer", "change direction" | `steer <text>` | RUNNING / APPROVED / PAUSED |
| "patch 적용", "그 변경 가" | "approve patch" | `steer approve patch` | pending_patch=true |
| "patch 빼", "그 변경 안 해" | "reject patch" | `steer reject patch` | pending_patch=true |
| "DTD 꺼", "일반모드", "그냥 너가 해" | "DTD off", "normal mode" | `mode off` | any |
| "DTD 켜", "협업모드" | "DTD on" | `mode on` | any |
| "건강 체크", "검사" | "doctor", "check" | `doctor` | any |
| "지워", "삭제", "uninstall" | "uninstall" | `uninstall` | any (off first if running) |
| "지금 막힌 거 뭐야", "어디서 막혔어?", "어떤 에러야" | "what's blocking?", "what's wrong" | `incident show <active_blocking_incident_id>` (or `incident list` if none active) | any |
| "incident 목록", "에러 목록", "사고 보여줘" | "list incidents" | `incident list` | any |
| "incident <id> 보여줘", "그 사고 자세히" | "show incident" | `incident show <id>` | any |
| "incident <id> 해결 retry", "그 에러 재시도", "재시도로 가자" | "resolve with retry" | `incident resolve <id> retry` | active blocking incident OR id supplied |
| "워커 바꿔서 다시", "다른 워커로" | "resolve with switch_worker" | `incident resolve <id> switch_worker` | active blocking incident |
| "incident <id> 그만", "그 에러 멈춰" | "resolve with stop" | `incident resolve <id> stop` — **DESTRUCTIVE; ALWAYS confirm** with explicit phrase before executing, regardless of intent confidence. Effect: triggers `finalize_run(STOPPED)` on the active run. | active blocking incident |

---

## State-aware Disambiguation

Same phrase, different action based on `plan_status` + `pending_patch`.

### "OK" / "좋아" / "y"

| state | meaning |
|---|---|
| DRAFT | likely `approve` — confirm if not obvious |
| APPROVED + no patch | likely `run` — confirm if just bare "ok" |
| APPROVED + pending_patch | likely `approve patch` |
| RUNNING + pending_patch | likely `approve patch` |
| RUNNING + awaiting_user_decision | answers the open menu — match to option |
| PAUSED | likely `run` (resume) — confirm |
| COMPLETED / STOPPED | acknowledgment only, no action |

### "그대로" / "as-is"

| state | meaning |
|---|---|
| DRAFT | `approve` (with current worker assignments) |
| pending_patch | `reject patch` (keep plan as it was) |
| awaiting_user_decision | `accept current result` |

### "task N은 X로"

| state | meaning |
|---|---|
| DRAFT | direct `plan worker N X` (free swap) |
| APPROVED / RUNNING / PAUSED | `steer "task N is X"` (medium impact patch + confirm) |
| Other | refuse with reason |

### "잠깐"

| state | meaning |
|---|---|
| RUNNING | `pause` |
| Other | acknowledgment, no action |

### "재시도" / "retry" / "다시" (when an incident is active)

| state | meaning |
|---|---|
| `active_blocking_incident_id` set | `incident resolve <active_blocking_incident_id> retry` |
| `awaiting_user_decision: INCIDENT_BLOCKED` only | same — incident id is implicit |
| No active incident, RUNNING | acknowledgment, no action (controller already retries via tier ladder) |
| No active incident, FAILED/STOPPED | confirm: did user mean to start a new run? |

### "그 에러" / "그 사고" / "incident" (referent disambiguation)

| state | meaning |
|---|---|
| Exactly one open incident | refers to that incident |
| Multiple open incidents | confirm: list with ids and ask "which?" |
| No open incidents | answer "open incident 없음. `/dtd incident list --all` 로 과거 이력 확인" |

---

## Confidence & Confirmation

- Confidence ≥ 0.95: act, just print "→ <action>" status line
- Confidence 0.8-0.95: act, print "→ <action> (interpreted as: <NL phrase>). 되돌리려면 `<undo>`"
- Confidence < 0.8: confirm in one line. Wait.
- Destructive actions (`stop`, `mode off`, `workers rm`, `uninstall --purge`, `incident resolve <id> <destructive_option>`): ALWAYS confirm with explicit phrase, regardless of confidence. Destructive incident options are defined in `dtd.md` §`/dtd incident resolve` (set: `stop` / `purge` / `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize`).

Sample confirms (keep short):

```
"approve 하고 곧장 run까지 가는 걸로 이해했어요. 맞나요? (y/n)"
"task 5,6 제거 patch를 만들게요. medium impact라 적용 전 확인 받을게요. 진행? (y/n)"
"진짜 stop 할까요? plan-001은 STOPPED로 마감되고 재개 안 됩니다. (y/n)"
```

---

## Naming Resolution Precedence

When user names something (worker / role / controller):

1. exact `worker_id` match
2. exact `alias` match (across all workers; if collision, ask)
3. exact `role` name match (look up `config.md` `roles.<name>`)
4. capability fuzzy ("리뷰어" → role:reviewer if exists, else capability:review)
5. ambiguous → list candidates, confirm

Special:

- Phrase matches **both** `controller.name` and a worker alias → ask which.
- Phrase is a reserved word (`controller, user, worker, self, all, any, none, default`) → reject as worker target; route to system meaning.
- "all" / "전부" / "다" → applies to all matching scope (e.g. `plan worker all <X>` = all tasks).

---

## Token Economy Rules

Hard rules. Violations waste user tokens or degrade UX.

### 1. Worker output → log file, not chat

```
✗ BAD:  paste worker's full code response into chat
✓ GOOD: save to .dtd/log/exec-<run>-task-<id>.<worker>.md, show one-line status
        "✓ task 2.1 done [딥시크] 2 files modified, 8m12s — log: .dtd/log/exec-001-task-2.1.deepseek-local.md"
```

### 2. Worker prompt assembly order (canonical — same in dtd.md and instructions.md)

```
1. .dtd/worker-system.md            (static, cache hit)
2. .dtd/PROJECT.md                  (rarely changes, cache hit)
3. .dtd/notepad.md <handoff> only   (dynamic — REWRITTEN before each dispatch, NO cache)
4. .dtd/skills/<capability>.md      (per capability, cache hit per capability)
5. task-specific section            (varies, no cache)
```

**Important**: only steps 1, 2, 4 are cache-friendly. The notepad `<handoff>` (step 3) is intentionally dynamic — controller rewrites it before each worker dispatch to reflect the latest run state. Do NOT mark it with `cache_control: ephemeral`.

For Anthropic-compatible endpoints, mark steps 1, 2, and 4 (in that order) with `cache_control: ephemeral`. Step 3 (notepad handoff) goes between cached blocks but is itself uncached. Step 5 (task) is always uncached.

Workers receive ONLY the `<handoff>` section of `notepad.md`, not the full notepad. The other sections (`learnings`, `decisions`, `issues`, `verification`) stay in the file for the controller's own use and are pruned/compacted as it grows.

### 3. Context file inline tiers

| File size | Action |
|---|---|
| < 2 KB | inline as-is in `<context-files>` block |
| 2-8 KB | `head -100 + tail -50 + "[...truncated, see ref:context-N.md]"`; save full to `.dtd/tmp/` |
| > 8 KB | NO inline. If worker has shell-exec/filesystem-read, instruct it to read the file. Else split task. |

### 4. Plan compaction

When `plan-NNN.md` size > 8 KB:

- Completed tasks (`status="done"`) → 1-line form: `<task id="X" worker="W" status="done" grade="GOOD" dur="Ns" log="..."/>`
- Original full XML → archive to `plan-NNN-history.md` only if compaction loses important detail (e.g. complex `<resources>` or annotations)

### 5. work.log compact grammar

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

### 6. Status output diet

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
  task 3.1: React 컴포넌트  → 딥시크   GOOD     pass
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
- NL: "지금 어디까지 됐어?", "상태 보여줘", "그 에러 다시 보여줘", "처음 계획 보여줘", "어디서 막혔어?", "지금 막힌 거 뭐야", "incident 보여줘"
- (Korean alias forms route to same set — `/ㄷㅌㄷ 상태`, `/ㄷㅌㄷ incident 목록` etc.)

Note: `/dtd incident resolve <id> <option>` is NOT observational — it is a
**mutating decision action** that closes a decision capsule. See NL table row
`incident resolve`.

For observational reads:

- DO NOT update `notepad.md`
- DO NOT append `steering.md`
- DO NOT append `phase-history.md`
- DO NOT append `attempts/run-NNN.md`
- DO NOT append `AIMemory/work.log` (except rare protocol/debug NOTE that the controller itself initiates separately)
- DO NOT update `state.md.last_update`
- DO NOT include the question/answer in future worker prompts
- DO NOT affect grading, retry counters, steering counters, loop guard, or escalation

Optional field (state.md): `last_status_viewed_at: <ts>` — INFO only, not a run state mutation.

**Exception**: if the user makes a *decision* after seeing status (e.g. status shows pending_patch, user replies "approve patch"), record the decision, NOT the status view that preceded it.

Reason: long sessions easily fill controller context with repeated "what's the status?" turns. Keeping reads observational means status checks stay cheap and don't pollute notepad/handoff.

---

## Don't Do These

- **Don't override host's own slash commands** (`/help`, `/clear`, `/exit`, etc.). DTD only handles `/dtd*` and DTD-related NL.
- **Don't auto-act on destructive NL** without explicit destructive words (e.g., "stop", "취소", "uninstall", "rm", "delete", "그만", "멈춰" when paired with an incident referent — see `incident resolve <destructive_option>` rule below).
- **Don't auto-execute destructive incident recovery options**. NL phrases like "그 에러 멈춰" or "incident X stop" map to `incident resolve <id> stop`, which inherits the destructive-confirmation rule because its effect class is `stop` (terminates the active run via `finalize_run(STOPPED)`). Destructive option set: `stop` / `purge` / `delete` / `force_overwrite` / `revert_partial` / `terminal_finalize`. Always show a one-line confirm for these regardless of intent confidence.
- **Don't grade your own work**. Even when classifying as `orchestration`, never claim a grade for controller-authored output.
- **Don't write secrets anywhere**. Re-read the redaction policy in `/dtd.md` if uncertain.
- **Don't bloat `plan-NNN.md`**. Compact completed tasks. Spill patches when over budget.
- **Don't dispatch when `pending_patch=true`** (medium/high) until patch resolved.
- **Don't take over a stale lock without user confirm**. Heartbeat is best-effort.
- **Don't load warm/cold AIMemory archives** "just in case" — use INDEX topic search to decide.
- **Don't echo worker raw output** in chat. Save to `.dtd/log/`, reference by path.
- **Don't mutate a worker call mid-flight** for any reason — patches apply only between tasks.
- **Don't repeat work after delegating**. If you dispatched a research/review task to a worker, do not also do the same search/review yourself in parallel. You may continue with non-overlapping work. If the next critical-path task is blocked on the worker's output, wait — or pick a different independent task. (Anti-duplication rule, prevents token + cognitive duplication.)

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
