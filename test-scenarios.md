# DTD v0.1 Test Scenarios

> 22 acceptance scenarios for v0.1. Not auto-runnable — these are
> (a) QA checklist for releases, (b) Codex review criteria, (c) user
> usage examples. Each scenario has Setup / Steps / Expected / Pass.

Format:

```
### N. <category>
**Setup**: prerequisite state
**Steps**: ordered actions
**Expected**: observable behavior
**Pass criteria**: concrete checkable conditions
```

---

## Install & lifecycle

### 1. Install — fresh project, all files created

**Setup**: empty project directory, AIMemory absent, agent has filesystem-write + shell-exec.
**Steps**:
1. Feed `prompt.md` to the agent.
2. Agent runs Tasks 1-12.
3. Agent reports "DTD installed".
**Expected**: `.dtd/` tree created with 15 templates; `dtd.md` at project root + host slash command dir; host always-read file has DTD pointer block; `state.md` shows `mode: off`, host_mode set to detected mode.
**Pass criteria**:
- `.dtd/instructions.md`, `.dtd/config.md`, `.dtd/workers.md`, `.dtd/worker-system.md`, `.dtd/resources.md`, `.dtd/state.md`, `.dtd/steering.md`, `.dtd/phase-history.md`, `.dtd/PROJECT.md`, `.dtd/notepad.md`, `.dtd/.gitignore`, `.dtd/.env.example`, and 3 `.dtd/skills/*.md` exist (15 files total)
- runtime dirs `.dtd/log/`, `.dtd/eval/`, `.dtd/tmp/`, `.dtd/attempts/`, `.dtd/runs/` exist (empty)
- `dtd.md` present at project root and at host's slash command directory
- Host always-read file (`CLAUDE.md`, `.cursorrules`, `AGENTS.md`, etc.) ends with the DTD pointer block
- `.dtd/state.md` `mode: off` and `host_mode: <detected>`

### 2. Doctor — clean install passes

**Setup**: completed Scenario 1.
**Steps**: run `/dtd doctor`.
**Expected**: all checks pass; output enumerates each check with `OK` / `WARN` / `ERROR`.
**Pass**: zero ERROR lines; agent-work-mem reported as `absent` with one-line recommendation.

### 3. Doctor — detects breakage

**Setup**: Scenario 1 completed, then manually: rename `.dtd/instructions.md`, add a fake stale lease to `resources.md` (heartbeat_at = 30 min ago), introduce alias collision in `workers.md`.
**Steps**: run `/dtd doctor`.
**Expected**: ERROR for missing template + alias collision (2 ERRORs); WARN for stale lease (per spec — leases can legitimately exceed `stale_threshold` for long tasks, so it's WARN with takeover suggestion, not ERROR); doctor does NOT auto-fix; recommends actions.
**Pass**:
- ERROR `instructions.md missing`
- ERROR `alias collision: <alias> appears in workers <A> and <B>`
- WARN `stale lease lease-* (heartbeat 30m old). Use /dtd doctor --takeover after user confirm.`

### 4. Uninstall — AIMemory preserved (default --soft)

**Setup**: Scenario 1 + AIMemory present (with its own files).
**Steps**: run `/dtd uninstall` (default = `--soft`). Confirm `y` when prompted.
**Expected**: `state.md` `mode: off`; `.dtd/` content preserved; user optionally removes pointer block; `AIMemory/` UNTOUCHED.
**Pass**:
- `.dtd/state.md` `mode: off`
- `.dtd/` directory still exists with all content intact
- `AIMemory/PROTOCOL.md`, `INDEX.md`, `work.log` byte-identical to pre-uninstall
- `/dtd mode on` reactivates without re-install

### 4b. Uninstall --hard (backup created)

**Setup**: Scenario 1 + AIMemory present.
**Steps**: run `/dtd uninstall --hard`. Confirm `y`.
**Expected**: `.dtd/` moved to `.dtd.uninstalled-YYYYMMDD-HHMM/` (project-root, gitignored); `dtd.md` removed from root + host slash dir; pointer block removed; `AIMemory/` UNTOUCHED.
**Pass**:
- `.dtd/` does not exist
- `.dtd.uninstalled-*/` exists with all original content
- root `.gitignore` includes `.dtd.uninstalled-*/` pattern (added by uninstall flow with confirm)
- `AIMemory/` byte-identical
- Host pointer block absent from always-read file

### 4c. Uninstall --purge (backup deleted)

**Setup**: Scenario 4b completed.
**Steps**: run `/dtd uninstall --purge` (or after `--hard`, run `/dtd uninstall --purge` again). Confirm destructive prompt.
**Expected**: `.dtd.uninstalled-*/` removed; `AIMemory/` STILL UNTOUCHED.
**Pass**:
- No `.dtd.uninstalled-*/` directory remains
- `AIMemory/` byte-identical to pre-uninstall

---

## Plan lifecycle

### 5. Basic plan-approve-run-complete

**Setup**: install + 1 worker registered (alias `local`); mode: dtd.
**Steps**:
1. `/dtd plan "create a hello-world script"`
2. Review output, run `/dtd approve`
3. `/dtd run`
**Expected**: DRAFT plan shown with worker assignments; APPROVED on /dtd approve; RUNNING dispatches; COMPLETED at end.
**Pass**:
- `plan-001.md` exists, plan_status transitions DRAFT → APPROVED → RUNNING → COMPLETED in state.md
- `phase-history.md` has rows for each phase with grade
- AIMemory `WORK_START` and `WORK_END` events emitted (1 each, compact format)
- `log/run-001-summary.md` created

### 6. Pause / resume

**Setup**: Scenario 5 mid-RUNNING (more than 1 task remaining).
**Steps**: run `/dtd pause` while task 1 is in flight.
**Expected**: task 1 finishes; plan_status → PAUSED; no new dispatch. Then run `/dtd run`.
**Pass**:
- in-flight task completed normally (output applied)
- no task 2 dispatched after pause until /dtd run again
- on resume, task 2 dispatched, plan_status → RUNNING

### 7. Stop — no resume

**Setup**: Scenario 5 mid-RUNNING.
**Steps**: `/dtd stop`. Then attempt `/dtd run`.
**Expected**: STOPPED; in-flight task allowed to finish then leases released; `/dtd run` refused with reason.
**Pass**:
- plan_status: STOPPED in state.md
- resources.md has no leases for this plan
- `/dtd run` after stop prints refusal message and suggests `/dtd plan <new>` for new plan

---

## Multi-worker

### 8. Parallel dispatch (parallel-group)

**Setup**: 2 workers registered (`local-a`, `local-b`); plan with `parallel-group="A"` containing tasks 2.1 and 2.2 assigned to different workers; mode: assisted or full.
**Steps**: `/dtd run`.
**Expected**: tasks 2.1 and 2.2 dispatched concurrently; controller waits for both before task 3.
**Pass**:
- both leases active simultaneously in resources.md
- task 3 dispatch happens AFTER both 2.1 and 2.2 marked done

### 9. Cross-LLM pipeline (writer → reviewer → writer)

**Setup**: 2 workers — `writer-A` (capability: code-write) and `reviewer-B` (capability: review).
**Steps**: `/dtd plan "add JWT auth and have it reviewed"`. Approve. Run.
**Expected**: phase 1 = writer-A produces code. Phase 2 = reviewer-B writes review file. Phase 3 = writer-A applies P1 fixes from review.
**Pass**:
- log files show 3 phase boundaries
- reviewer-B output is `docs/review-NNN.md` (or similar), not source code
- writer-A's phase 3 input includes the review file as `<context-files>`

### 10. Worker swap in DRAFT

**Setup**: install + 2 workers; `/dtd plan "X"` produced DRAFT with all tasks on worker A.
**Steps**:
1. `/dtd plan show` — verify all tasks on A
2. `/dtd plan worker phase:2 B`
3. `/dtd plan show` again
**Expected**: phase 2 tasks reassigned to B; `<worker-resolved-from>` shows `user-override (was: <previous>)`.
**Pass**:
- plan-NNN.md tasks in phase 2 have `<worker>B</worker>`
- annotation persists across `/dtd plan show`
- plan_status remains DRAFT

---

## Steering

### 11. Steering low-impact

**Setup**: Scenario 5 RUNNING.
**Steps**: NL phrase "변수명은 camelCase로" between tasks.
**Expected**: appended to steering.md as `low | style`; applied to next worker prompt as prefix; no patch, no confirm.
**Pass**:
- steering.md gets new entry with `impact: low`
- pending_patch remains false
- next worker dispatch's prompt body contains the camelCase guidance

### 12. Steering medium-impact (worker change)

**Setup**: Scenario 5 RUNNING.
**Steps**: NL "phase 4 리뷰는 큐엔으로 바꿔" (medium-impact phrase).
**Expected**: pending_patch=true, patch_impact=medium; in-flight task continues; controller asks "approve patch? y/n".
**Pass**:
- state.md pending_patch=true, patch_status=proposed
- plan-NNN.md `<patches>` has new entry
- no new task dispatched until user approves/rejects
- on approve: phase 4 task workers updated to qwen, pending_patch=false
- on reject: plan unchanged, pending_patch=false, steering.md entry preserved

### 13. Steering high-impact (goal change)

**Setup**: Scenario 5 mid-RUNNING.
**Steps**: NL "이 프로젝트 목표를 SaaS에서 self-hosted로 바꿀게".
**Expected**: pending_patch=true, patch_impact=high; AIMemory NOTE event emitted (high-impact steering = exception case for AIMemory).
**Pass**:
- as Scenario 12 plus
- AIMemory `NOTE` event with one-line summary of goal change
- on approve: plan-NNN.md `<brief>` updated; plan body may be largely rewritten

---

## Tier escalation

### 14. Tier escalation on repeated failure

**Setup**: 2 workers configured (`tier1-fragile` with failure_threshold=2, escalate_to=tier2-stable; `tier2-stable` with capability code-write); craft a task tier1 will fail twice (e.g., parsing edge case the local model misses).
**Steps**: `/dtd plan` + run.
**Expected**: 2 failures from tier1-fragile → automatic escalate_to tier2-stable → success.
**Pass**:
- state.md failure_counts shows `(tier1-fragile, task) count: 2`
- log files show 2 attempts on tier1, then 1 on tier2
- phase-history.md row Note column: `escalated:tier2`
- (tier1-fragile, task) counter reset to 0 after escalation

---

## Context budget

### 15. Soft cap hit triggers phase split

**Setup**: 1 worker with `max_context: 10000` and `soft_context_limit: 70`. Task with `<context-files>` totaling ~5000 input tokens, plus expected ~2500 output → estimated 75% of max_context (above 70% soft cap).
**Steps**: `/dtd run`.
**Expected**: controller computes the estimate ≥ 70% before dispatch; splits the phase into smaller parts before sending; logs the calculation in the log file. If the worker emits a `::ctx::` advisory line, that's recorded too (but advisory only — controller's own calculation is authoritative).
**Pass**:
- controller log shows estimated context usage ≥ 0.70 before dispatch
- if worker emits it, `::ctx:: used=75 status=soft_cap` (or any concrete percent ≥ 70) appears BEFORE the `::done::` line
- phase split into 2+ smaller phases (visible in phase-history.md)
- no hard_cap (85%) hit
- task succeeds after split

---

## Resource locks

### 16. Parallel write conflict serializes

**Setup**: plan with tasks 3.1 and 3.2 in `parallel-group="A"`, both writing to `src/ui/**`.
**Steps**: `/dtd run`.
**Expected**: controller detects overlap during step 3 (overlap check); does NOT dispatch in parallel; queues 3.2 after 3.1 finishes.
**Pass**:
- task 3.1 dispatch precedes task 3.2 (sequential, not parallel)
- doctor pre-run optionally warns about conflict
- resources.md never has 2 active write leases on overlapping paths

---

## Stuck escalation (5-step ladder)

### 17. Full ladder traversal to user

**Setup**: 1 fragile worker, 1 reviewer, controller; craft a task that fails repeatedly with the same blocker (`failure_reason_hash` matches twice fast).
**Steps**: `/dtd run`.
**Expected**: ladder progresses focused-retry → tier-escalate → reviewer-add → controller-intervene → user-ask. Terminal user prompt with options.
**Pass**:
- state.md awaiting_user_decision: true at the end
- user_decision_options: `[accept, rework, abandon]`
- AIMemory NOTE entry NOT created for ladder progression (those are .dtd/-internal)
- phase-history.md note column shows the ladder step that ended at user

---

## Natural language

### 18. NL routing — Korean + English

**Setup**: install + plan in DRAFT.
**Steps**: try each phrase, observe canonical action mapped:
1. "좋아 진행" → approve
2. "approve" → approve
3. "잠깐 멈춰" → pause (only if RUNNING; else ack)
4. "처음 계획 보여줘" → plan show
5. "phase 2가 어디 작업해?" → status query (path-focused)
6. "코덱스로 4.1 바꿔" → plan worker (DRAFT) or steer (post-DRAFT)
**Expected**: each maps correctly; ambiguous (only "ok" without context) prompts confirm.
**Pass**:
- canonical action correctly inferred for unambiguous phrases (≥ 0.95 confidence)
- ambiguous phrases trigger one-line confirm
- destructive phrases (e.g. "uninstall") never auto-act without explicit phrase + confirm

---

## Path policy

### 19. Path policy enforcement

**Setup**: install with default config.md path-policy.
**Steps**:
1. `/dtd plan "fix /etc/hosts" → expected BLOCK`
2. `/dtd plan "edit ../neighbor-project/foo"` → expected WARN, suggest absolute
3. `/dtd plan "build to /tmp/build/"` → expected OK
4. `/dtd plan "edit src/api/users.ts"` → expected OK (relative)
**Expected**: blocks/warns per config; OK paths flow through normally.
**Pass**:
- (1) plan generation refuses to include `/etc/hosts` in any task; explanation cites `block_patterns`
- (2) WARN message + suggestion to use absolute home path
- (3) absolute path accepted, marked `global:` namespace lock
- (4) relative path accepted, marked `project:` namespace lock

---

## AIMemory integration

### 20. Orphan resume

**Setup**: Scenario 5 RUNNING, then user closes session abruptly (lock not released, WORK_END not emitted).
**Steps**:
1. New session, agent reads `AIMemory/work.log` tail per PROTOCOL §A.3
2. Agent finds orphan WORK_START
3. Agent reads `.dtd/state.md` → plan_status=RUNNING with stale lock
**Expected**: agent does not auto-takeover. Asks user: "Previous DTD run-001 has stale lock from <stale-time>. Resume / restart / inspect?".
**Pass**:
- new session correctly identifies the orphan via AIMemory + .dtd/state.md
- prompts user for choice; does not auto-act
- on user "resume": releases stale lock (with NOTE event), pause-state, then re-runs from current_task

---

## Security

### 21. Secret redaction in logs

**Setup**: deliberately add `OPENAI_API_KEY=sk-test-fakekey1234567890abc...` to `.env`. Run a worker call that has the key in its HTTP header.
**Steps**: `/dtd run` one task; inspect `.dtd/log/exec-NNN-task-N.<worker>.md`.
**Expected**: log file contains the worker's response but NO occurrence of the literal key string. Header use is not logged.
**Pass**:
- grep `sk-test-fakekey1234567890` in `.dtd/log/`, `.dtd/state.md`, AIMemory: zero matches
- doctor secret-leak scan returns clean
- env var name `OPENAI_API_KEY` may appear (that's fine — names are public)

---

## Dashboard

### 22a. Worker dispatch — happy path (full mode, OpenAI-compatible endpoint)

**Setup**: workers.md has 1 active worker pointing at a reachable OpenAI-compatible endpoint (e.g., local Ollama with `deepseek-coder:6.7b` or any working endpoint). `host.mode: full`. Plan with 1 simple task (e.g., "write a hello function to src/hello.js").
**Steps**: `/dtd plan ...` → `/dtd approve` → `/dtd run`.
**Expected**: controller assembles prompt per §Token Economy #2 order, builds JSON body to `.dtd/tmp/dispatch-001-1.1.json`, POSTs to endpoint with `Authorization: Bearer $env`, receives 200 + parses `choices[0].message.content`, extracts `===FILE: src/hello.js===` block + `::done::`, validates path against permission_profile and lock set, applies file, releases lease, runs finalize_run on COMPLETED.
**Pass**:
- `.dtd/tmp/dispatch-001-1.1.json` exists with correct OpenAI-compat body shape
- `.dtd/log/exec-001-task-1.1.<worker>.md` has the worker's response
- Source file `src/hello.js` matches what the worker output
- API key NEVER appears in any of: dispatch JSON body, log files, status output
- `.dtd/attempts/run-001.md` has 1 entry, status=done, with usage tokens
- `.dtd/runs/run-001-notepad.md` archived after COMPLETED

### 22b. Worker dispatch — error handling (401, 429, timeout)

**Setup**: 1 worker with intentionally bad config or slow endpoint.
**Steps**: try plan → run with each error condition (bad key, rate limit, timeout).
**Expected per error**:
- 401: dispatch aborts, prompt user to fix `api_key_env`, attempt marked `blocked` reason=`auth_failed`. **Key value never appears anywhere**.
- 429: respect `Retry-After` header, retry once, then mark `failed` reason=`rate_limit`, escalate per ladder.
- timeout (> `worker.timeout_sec`): mark `failed` reason=`timeout`, hash blocker, escalate per ladder.
**Pass**:
- Each error path produces correct attempt entry + escalation
- Doctor secret-leak scan: 0 hits across `.dtd/log/`, `.dtd/state.md`, `AIMemory/work.log`

### 22c. Plan-only mode dispatch (manual paste)

**Setup**: `host.mode: plan-only` (e.g., a host with filesystem only, no shell-exec or web-fetch).
**Steps**: `/dtd plan` → `/dtd approve` → `/dtd run`.
**Expected**: controller writes assembled prompt to `.dtd/tmp/dispatch-001-1.1.txt` (plain text), prints copy-paste instructions to chat. User pastes prompt elsewhere, gets response, saves to `.dtd/tmp/response-001-1.1.txt`, runs `/dtd run --paste`. Controller resumes from parse step.
**Pass**:
- No HTTP call made by controller
- `.dtd/tmp/dispatch-001-1.1.txt` exists in human-readable form
- `/dtd run --paste` correctly parses pasted response and continues lifecycle

### 23. Dashboard ASCII default + width compliance

**Setup**: install with `config.dashboard_style: ascii` (default for v0.1) and `dashboard_width: 80`. Plan RUNNING.
**Steps**: `/dtd status`.
**Expected**: ASCII rendering (canonical for v0.1) — uses `+`, `|`, `*`, `->` glyphs; width respects 80 columns; long values truncated with `+more`. If config is changed to `unicode`, controller probes terminal and falls back to ASCII if the terminal cannot render box-drawing chars.
**Pass**:
- output uses ASCII glyphs only (with `dashboard_style: ascii`)
- no `??` or other corrupted chars
- no line exceeds 80 chars
- truncations marked with `+more` or similar
- `/dtd plan show` also renders ASCII when `dashboard_style: ascii`

---

## Coverage map

| Test # | P1 / P2 spec rule covered |
|--------|---------------------------|
| 1, 2, 3, 4 | install / doctor / uninstall (P1-6 host modes adjacent) |
| 5, 6, 7 | state machine (pending_patch flow tested in 12-13) |
| 8, 9, 10 | multi-worker, DRAFT swap |
| 11, 12, 13 | steering (P1-1 pending_patch flag) |
| 14 | tier escalation (P1-3 counters/reset) |
| 15 | context budget (P1-6 mode + worker_system::ctx) |
| 16 | resource locks (P1-4 lifecycle) |
| 17 | stuck escalation 5-step (P1-3 + controller intervention P1-2) |
| 18 | NL routing (instructions.md) |
| 19 | path policy (P1-4 normalize + §7) |
| 20 | AIMemory boundary (P1 §8 + 7-case exceptions) |
| 21 | secret redaction (P2-9 promoted to P1) |
| 22a, 22b, 22c | worker dispatch HTTP transport (happy path / errors / plan-only paste) |
| 23 | dashboard width/fallback (P2-10) |

Controller no-self-grade gate (P1-2): exercised wherever step 4 of escalation ladder is reached (Scenario 17 covers this; specific REVIEW_REQUIRED gate is observed in phase-history.md gate column).

---

## Running

These scenarios are not auto-runnable in v0.1 (markdown-only, no test harness). Manual or semi-manual run by:
- a developer doing acceptance review before tagging v0.1
- Codex doing post-author review
- a user kicking the tires after install

For each scenario: walk through Steps, verify Pass criteria, mark ✓/✗.
