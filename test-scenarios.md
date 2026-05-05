# DTD v0.1 Test Scenarios

> 81 acceptance scenarios (72 single-feature + 9 cross-sub-release integration) for v0.1 + v0.1.1 + v0.2.0a (TAGGED) + v0.2.0d (R0 implementation) + v0.2.3 R1 reference extraction + Lazy-Load Profile + v0.2.0f/0e/0b/0c/0.2.1/0.2.2 (planned). Not auto-runnable — these are
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
**Expected**: `.dtd/` tree created with 15 committed templates + 1 generated local registry (`workers.md` from `workers.example.md`); `dtd.md` at project root + host slash command dir; host always-read file has DTD pointer block; `state.md` shows `mode: off`, host_mode set to detected mode.
**Pass criteria**:
- 15 committed `.dtd/` templates exist: `instructions.md`, `config.md`, `workers.example.md`, `worker-system.md`, `resources.md`, `state.md`, `steering.md`, `phase-history.md`, `PROJECT.md`, `notepad.md`, `.gitignore`, `.env.example`, `skills/code-write.md`, `skills/review.md`, `skills/planning.md`
- `.dtd/workers.md` exists locally as a copy of `workers.example.md` (gitignored — `git check-ignore -v .dtd/workers.md` confirms ignore rule)
- `git ls-files .dtd/workers.example.md` confirms tracked; `git ls-files .dtd/workers.md` returns empty
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

### 22d. Workers split — install workflow + privacy

**Setup**: Fresh project, no `.dtd/` yet.
**Steps**:
1. Run install bootstrap.
2. Verify `.dtd/workers.example.md` (committed reference) AND `.dtd/workers.md` (local copy) both exist after install.
3. `.dtd/.gitignore` includes `workers.md`.
4. Edit `workers.md`: add a worker with sensitive endpoint (e.g. LAN IP).
5. `git status` — `workers.md` should NOT appear as untracked or modified; `workers.example.md` should be tracked.
6. Re-run install (simulating an upgrade): `workers.md` untouched, `workers.example.md` refreshed.
**Pass**:
- Both files exist after install
- `workers.md` user edits persist across re-install (never overwritten)
- `git check-ignore -v .dtd/workers.md` confirms ignore rule
- `git ls-files .dtd/workers.example.md` confirms tracked

### 22e. LMStudio LAN IP + Tailscale — multi-machine reach

**Setup A** (LAN IP):
- Machine A: LMStudio running, "Serve on local network" enabled (binds 0.0.0.0:1234).
- Machine B: different host on same LAN.

**Steps A**:
1. On machine B: register worker with `endpoint: http://<machine-A LAN IP>:1234/v1/chat/completions`.
2. `/dtd workers test <id>` from machine B.
3. (Negative) Set endpoint to `http://127.0.0.1:1234/...` from machine B → `/dtd workers test`.

**Pass A**:
- Test from machine B with LAN IP succeeds (200 from probe POST)
- Test with `127.0.0.1` from machine B fails (connection refused / network unreachable)
- Doctor INFO suggests LAN IP / Tailscale alternative

**Setup B** (Tailscale):
- Both machines on same Tailscale tailnet (logged in same account).
- Machine A still bound to 0.0.0.0:1234.

**Steps B**:
1. On machine A: `tailscale ip -4` → e.g., `100.64.0.10`.
2. Machine B (different network — coffee-shop WiFi): register worker with `endpoint: http://100.64.0.10:1234/v1/chat/completions`.
3. `/dtd workers test <id>`.

**Pass B**:
- Test succeeds via tailnet IP across networks
- No port forwarding, no public exposure
- API key (if any) never appears in any log file

### 22f. Commercial OpenAI-compatible API (DeepSeek)

**Setup**: User has a DeepSeek API key in env: `export DEEPSEEK_API_KEY=sk-...`.
**Steps**:
1. Register worker:
   ```markdown
   ## deepseek-cloud
   - endpoint: https://api.deepseek.com/v1/chat/completions
   - model: deepseek-v4-pro                    # or deepseek-v4-flash; older `deepseek-coder` deprecated 2026-07-24
   - api_key_env: DEEPSEEK_API_KEY
   - max_context: 64000
   - capabilities: code-write
   - enabled: true
   - permission_profile: code-write
   ```
2. `/dtd workers test deepseek-cloud`.
3. Run a small plan with this worker.
**Pass**:
- 200 response, OpenAI-shaped output (`choices[0].message.content`)
- Worker output parsed correctly (`===FILE:===` blocks + `::done::` line)
- Files applied to project per `<output-paths>`
- API key (`sk-...`) NEVER appears in: `.dtd/tmp/dispatch-*.json`, `.dtd/log/*.md`, `.dtd/state.md`, AIMemory `work.log`, status output, chat history
- doctor secret-leak scan: 0 hits across all `.dtd/log/`, `.dtd/state.md`, AIMemory

### 22g. Tuning params merge into request body

**Setup**: Register a worker with full tuning fields:
```markdown
## tuned-worker
- endpoint: http://localhost:11434/v1/chat/completions
- model: deepseek-coder:6.7b
- api_key_env: OLLAMA_API_KEY
- max_context: 32000
- capabilities: code-write
- temperature: 0.7
- top_p: 0.9
- seed: 42
- stop: "###,END"
- reasoning_effort: medium
- extra_body: {"top_k": 40, "min_p": 0.05}
- enabled: true
- permission_profile: code-write
```
**Steps**:
1. `/dtd plan` + `/dtd approve` + `/dtd run` for a single-task plan.
2. Inspect `.dtd/tmp/dispatch-<run>-<task>.json` request body before dispatch.
**Pass**:
- Body has `"temperature": 0.7`, `"top_p": 0.9`, `"seed": 42`, `"reasoning_effort": "medium"`
- `"stop": ["###", "END"]` (comma-list parsed to JSON array)
- `extra_body` keys present at top level: `"top_k": 40`, `"min_p": 0.05`
- DTD-internal fields NOT in body: `tier`, `failure_threshold`, `aliases`, `display_name`, `permission_profile`, `escalate_to`, `enabled`
- `stream` field absent or `false` (v0.1 enforces)

### 22h. Adopt DTD on in-progress project

**Setup**: User has a partially-built project. `src/api/users.ts` exists (built manually before DTD adoption); `src/api/products.ts` and `src/api/orders.ts` not yet started.
**Steps**:
1. Install DTD into the project.
2. Fill `.dtd/PROJECT.md`: project description, tech stack, "what's done: User CRUD; what's pending: Product + Order CRUD".
3. `/dtd plan "complete CRUD: Users (done), Products, Orders"`.
4. Edit DRAFT `.dtd/plan-001.md`:
   - Phase 1 (User CRUD) tasks: add `status="done" worker="manual"`, fill `<output-paths actual="true">src/api/users.ts</output-paths>`.
   - Phase 2 (Product) and Phase 3 (Order) tasks: leave `<done>false</done>`, assign `<worker>` to a real worker.
5. (Optional) Add a row to `.dtd/phase-history.md` for phase 1 with `note="adopted prior work"`.
6. `/dtd approve` → `/dtd run`.
**Pass**:
- `/dtd run` skips phase 1 (no dispatch attempts; `attempts/run-001.md` has 0 entries for phase 1 tasks)
- Dispatches start at phase 2.1 (first pending task)
- `phase-history.md` has phase 1 row (manually added) + phase 2/3 rows generated by run
- Worker output for phase 2 successfully writes `src/api/products.ts`
- `/dtd status` correctly shows "phase 2/3, manual phase 1 already done"

### 22i. MAX_ITERATIONS_REACHED → full decision capsule

**Setup**: phase with `max-iterations="2"`, target_grade=GREAT, worker that consistently produces GOOD.
**Steps**: `/dtd run`. After 2 failed iterations:
**Expected**: state.md has full decision capsule (decision_id, prompt, options, default, resume_action). `/dtd status` shows the prompt + options + default. NOT just `awaiting_user_decision: true` with sparse fields.
**Pass**:
- `decision_options` lists 4 entries: accept / rework / increase_cap / abandon
- `decision_default: rework`
- `/dtd status` rendering includes "choose: accept | rework | increase_cap | abandon" line and "default: rework"
- `user_decision_options` legacy field also populated for back-compat

### 22j. AUTH_FAILED → durable blocker decision capsule

**Setup**: worker registered with wrong API key in env var.
**Steps**: `/dtd run` dispatches a task; receives 401.
**Expected**: instead of just attempt failed, state.md decision capsule filled with reason `AUTH_FAILED`, options `[fix_env_retry, switch_worker, stop]`, default `fix_env_retry`. `/dtd status` shows the blocker. Even after closing session and reopening, `/dtd status` still shows the blocker (it's durable in state.md).
**Pass**:
- API key value (`sk-...`) NEVER logged anywhere
- After fixing env var: user picks `fix_env_retry` → controller re-dispatches same task
- New session reads state.md, sees the blocker, displays it (durable across sessions)

### 22k. NETWORK_UNREACHABLE → recovery options

**Setup**: worker endpoint pointing at unreachable host (e.g., 127.0.0.1:9999 closed port).
**Steps**: `/dtd run`.
**Expected**: capsule reason `NETWORK_UNREACHABLE`, options `[retry, test_worker, switch_worker, manual_paste, stop]`, default `test_worker`. `/dtd status` shows the blocker + suggests `/dtd workers test <id>`.
**Pass**:
- decision capsule has all 5 options
- selecting `manual_paste` switches to plan-only paste flow for this task only
- selecting `switch_worker` invokes fallback chain

### 22l. WORKER_INACTIVE — wait/cancel/switch/takeover

**Setup**: long-running task, worker silent past `worker.timeout_sec` (or heartbeat stale past `stale_threshold_min`).
**Steps**: `/dtd run` dispatches; wait for timeout.
**Expected**: capsule reason `WORKER_INACTIVE`, options `[wait_once, retry_same, switch_worker, controller_takeover, stop]`, default `switch_worker`. Late return after `switch_worker` is `superseded` (per attempt timeline rules), output NOT applied.
**Pass**:
- elapsed time visible in `/dtd status` (started_at, elapsed_sec, timeout threshold)
- on `switch_worker`: original attempt marked `superseded`, replacement_reason set
- new attempt dispatched to next worker in fallback chain

### 22m. Fallback chain shown in status

**Setup**: 3 workers with capability `code-write`: `local-fast` (tier 1, free), `local-big` (tier 2, free), `cloud` (tier 3, paid). `config.paid_fallback_requires_confirm: true`.
**Steps**: `/dtd run`. local-fast fails 3× (failure_threshold).
**Expected**: controller computes fallback chain `local-fast → local-big → cloud → user`. Auto-fallback to `local-big` (same/lower cost). To go to `cloud` (paid) → fills decision capsule (require user confirm). `/dtd status --full` shows chain.
**Pass**:
- chain visible in status
- automatic transition local-fast → local-big without prompt
- prompt before local-big → cloud (paid)
- attempt timeline records each fallback step with `replacement_reason`

### 22n. /dtd run --until phase:N

**Setup**: plan with 5 phases. plan_status APPROVED.
**Steps**: `/dtd run --until phase:3`.
**Expected**: phases 1, 2, 3 execute; phase 4 NOT dispatched. plan_status: PAUSED. state.md `run_until` cleared (was phase:3 during run). phase-history.md row for phase 3 has `gate: user-checkpoint, note: run_until=phase:3`.
**Pass**:
- exactly 3 phases dispatched (no phase 4 attempts in `attempts/run-001.md`)
- `/dtd status` after pause: "Paused at requested boundary: phase:3"
- `/dtd run` (no flag) resumes phase 4 normally

### 22o.1. DISK_FULL during temp-write (clean abort, no final files changed)

**Setup**: worker output has 3 files. After validation, simulate `ENOSPC` when writing 2nd temp file (`<path>.dtd-tmp.<pid>`).
**Steps**: `/dtd run`. Phase 1 (temp-write): file-1 temp OK, file-2 temp fails.
**Expected**: abort phase 1 immediately. **Delete already-written temp files** (no rename has happened). Fill `DISK_FULL` capsule with options `[free_space_retry, skip_file, stop]`, default `free_space_retry`. NO final files changed.
**Pass**:
- no `<file>.dtd-tmp.*` files leftover after abort
- final `src/api/users.ts` (or whatever was target) NOT modified
- capsule reason `DISK_FULL`, options as specified
- lease still held (NOT released — ambiguous state needs resolution)
- on `free_space_retry`: user frees space → re-dispatch attempt fresh

### 22o.2. PARTIAL_APPLY during rename phase (some final files written)

**Setup**: worker output has 3 files. All 3 temps written OK. During phase 2 (rename), simulate file-2 rename failing (e.g., file-2 path locked by another process), file-1 rename already succeeded.
**Steps**: `/dtd run`. Phase 1 OK, phase 2: rename-1 OK, rename-2 fails.
**Expected**: file-1 final on disk (atomic-renamed). file-2 still as `.dtd-tmp.*`. file-3 rename NOT attempted (controller stops phase 2 on first failure to keep state determinable). Capsule reason `PARTIAL_APPLY` with options `[inspect, revert_partial, accept_partial, stop]`, default `inspect`. **Automatic resume forbidden**. Lease held.
**Pass**:
- exactly 1 file final-renamed (`src/api/users.ts`)
- exactly 2 files still as `.dtd-tmp.*`
- capsule shows applied=[1 file] / pending=[2 files] explicitly
- on `inspect`: shows diff of each file group
- on `revert_partial`: deletes the 1 applied final + cleans up 2 temp files; lease released; attempt blocked
- on `accept_partial`: deletes 2 temp files; task marked grade<NORMAL or partial

### 22p. Worker-add wizard end-to-end (chat-safe secret flow)

**Setup**: clean install, no workers yet.
**Steps**: NL `/ㄷㅌㄷ qwen 워커 하나 추가해줘`.
**Expected**: thin wizard starts. Asks (one field at a time, in chat):
1. alias hint (suggests `qwen-local`)
2. endpoint (suggests LMStudio `http://localhost:1234/v1/chat/completions` based on hint)
3. model (suggests `qwen2.5-coder:32b` or similar)
4. api_key_env name (suggests `QWEN_API_KEY`) — NAME ONLY
5. **NOT** api_key_value. Wizard prints POSIX/PowerShell snippet and instructs user to set `.dtd/.env` themselves out-of-band, OR rely on shell env. Wizard waits for user to confirm "set" or "skip".
6. max_context (suggests provider default)
7. capabilities (suggests based on alias hint, e.g. qwen → code-write/code-refactor)
8. permission_profile (defaults code-write)
9. summary + apply confirm.

Redacted summary line for the key field is: `api_key_value: not collected (set .dtd/.env or shell env)` — NOT `<REDACTED>` (which would imply the wizard saw a value).

On `yes`: writes `workers.md` only. Offers `/dtd workers test <id>`.
On `cancel`: no files modified.

**Pass**:
- Raw API key value NEVER enters the chat conversation (controller transcript)
- `.dtd/workers.md` contains `api_key_env: QWEN_API_KEY` (env var NAME, not value)
- `.dtd/.env` is the canonical path; if user set it via the provided snippet, it contains `QWEN_API_KEY=<value>`. If user used existing shell env, `.dtd/.env` may be empty for this key.
- Plain `.env` (project root) is NOT used — canonical path is `.dtd/.env`
- Wizard turns NOT copied into notepad / steering / attempts / phase-history / AIMemory
- Cancel before apply: no `workers.md` or `.dtd/.env` modification
- Length / prefix / suffix / fingerprint of any secret NEVER echoed in chat

### 22q. Context pattern selection + GSD-style reset

**Setup**: active DRAFT plan with at least one planning/research phase, one
code-write phase, and one task that will need a retry.
**Steps**:
1. Run `/dtd plan show --full`.
2. Say "이번 설계 페이즈는 탐색적으로 해" before approval.
3. Approve and run until the code-write phase.
4. Force one worker failure, then retry the same task.

**Expected**:
- Controller-selected plan fields use only `context-pattern="fresh"`,
  `"explore"`, or `"debug"`.
- Planning/research phase is `explore`; code-write/review/verification tasks
  are `fresh` unless explicitly overridden.
- Retry path resolves to `debug`, updates `state.md`
  `resolved_context_pattern: debug`, and starts a fresh worker context.
- Retry prompt includes compact failure reason + attempt/log ref + current
  `<handoff>`, not the previous raw worker transcript.
- Improvements accepted before retry remain as file changes, notepad distilled
  learnings, attempts/log refs, and phase history.

**Pass**: context resets at dispatch/retry/phase boundary while durable
artifacts preserve useful learning. `/dtd status --full` shows resolved pattern
and compact sampling line.

### 22r. Persona, reasoning utility, and tool-runtime controls resolve safely

**Setup**: active DRAFT plan with architecture, implementation, debug, review,
and verification phases. Worker registry has one normal worker without native
tools and one opt-in worker with trusted sandboxed native tools.
**Steps**:
1. Ask for architecture to use a planner persona and stepwise decomposition.
2. Ask one research task to use tool relay.
3. Ask a retrying debug task to use debugger persona and tool-based critique.
4. Approve and run until each task dispatch point.

**Expected**:
- Plan XML uses only configured optional attributes:
  `persona`, `reasoning-utility`, and `tool-runtime`.
- `state.md` resolves compact fields:
  `resolved_controller_persona`, `resolved_worker_persona`,
  `resolved_reasoning_utility`, and `resolved_tool_runtime`.
- Worker prompt includes a short persona/reasoning/tool capsule inside the
  task-specific section, not a long role-play block.
- No worker prompt asks for raw chain-of-thought; logs contain only compact
  rationale summaries, evidence refs, risks, and next actions.
- A non-native worker needing a tool returns `::tool_request::`; controller
  validates and runs the relay between dispatches, logs sanitized full output
  to `.dtd/log/tool-<run>-task-<id>-<seq>.md`, then retries with a compact log
  ref. File writes still go through normal output-path validation/apply.
- A worker-native tool task is allowed only when the registry/config marks the
  runtime as sandboxed (`tool_runtime: worker_native|hybrid` and
  `native_tool_sandbox: true`); otherwise it resolves back to
  `controller_relay` or blocks. Final output path validation still runs.

**Pass**: phase/task personality and reasoning depth improve usability without
turning into long context, hidden reasoning leakage, or uncontrolled tool use.

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

### 23a. Silent overnight mode defers blockers and continues safe work

**Setup**: APPROVED plan with three independent tasks A/B/C. Task A will hit an
AUTH_FAILED worker error; B and C are safe code-write tasks with no dependency
on A.
**Steps**: `/ㄷㅌㄷ 자러갈게 4시간 조용히 개발해줘`.
**Expected**:
- State sets `attention_mode: silent`, `attention_until` about 4h ahead, and
  `attention_goal` summarizing the user request.
- A creates a durable incident/decision capsule but is deferred, not repeatedly
  asked in chat.
- Controller skips A and A dependents, then continues B/C if locks and
  dependencies allow.
- Destructive, paid, secret, external-path, partial-apply, and ambiguous
  permission decisions are never auto-approved.
- When no ready non-blocked work remains or silent window ends, status/morning
  summary shows completed tasks, deferred blockers, elapsed time, and next
  choices.

**Pass**: silent mode maximizes safe progress without user prompts and without
losing blockers.

### 23b. Decision mode and attention mode can change mid-run

**Setup**: RUNNING or PAUSED plan in silent mode with at least one deferred
decision.
**Steps**:
1. `/dtd interactive`
2. `/dtd mode decision plan`
3. `/dtd status --full`
4. `/dtd silent on --for 2h`

**Expected**:
- Switching to interactive surfaces the oldest deferred blocker first.
- Switching decision mode affects future choices only; it does not auto-resolve
  queued blockers.
- Status shows `decision_mode`, `attention_mode`, `attention_until`, and
  deferred decision count.
- Returning to silent preserves current phase/worker state and applies silent
  policy at the next decision point.

**Pass**: modes are orthogonal: host apply authority, decision frequency, and
attention timing do not overwrite each other.

### 23c. Silent mode handles token/quota exhaustion safely

**Setup**: silent run with fallback chain configured. Task A worker returns
token/quota exhaustion; later simulate controller token exhaustion.
**Steps**:
1. `/dtd run --decision auto --silent=4h`
2. Worker A hits provider quota.
3. Safe same-profile/free fallback exists, then also fails.
4. Controller detects its own token/quota exhaustion.

**Expected**:
- Worker quota failure tries safe same-profile/free fallback only if silent
  policy allows it.
- If safe fallback fails, A is deferred and independent ready tasks continue.
- Controller quota exhaustion checkpoints immediately, sets `plan_status:
  PAUSED`, fills `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`, and waits.
- No paid fallback, destructive action, secret prompt, or external path action
  is auto-approved.

**Pass**: silent mode keeps making safe progress for worker quota issues, but
controller quota exhaustion becomes a durable paused state.

### 23d. Perf report separates controller and worker token usage

**Setup**: completed or running plan with
`.dtd/log/controller-usage-run-NNN.md` written for mutating controller turns,
`.dtd/log/exec-<run>-task-<id>-att-<n>-ctx.md` files written for each dispatch,
plus `.dtd/attempts/run-NNN.md` and `.dtd/phase-history.md` populated.
**Steps**: `/ㄷㅌㄷ 페이즈별 토큰 사용량 보여줘`.
**Expected**:
- Routes to `/dtd perf`.
- Output has separate `controller`, `workers`, and `worker detail` sections.
- Controller section shows total and per-phase prompt/completion/context peak.
- Controller totals prefer `controller-usage-run-NNN.md` and do not
  double-count worker ctx controller estimate fields.
- Worker section shows total calls/tokens and per-phase calls/tokens/context
  peak.
- Worker detail shows calls/tokens/retry count by worker id.
- No blended "total tokens" adds controller + worker into one number.
- Read is observational: state, notepad, attempts, phase history, steering, and
  AIMemory are unchanged.

**Pass**: user can see controller orchestration cost separately from worker
execution cost.

### 23e. Morning summary surfaces deferred blockers in age order

**Setup**: silent run completed safe work but accumulated 3 deferred decisions
(AUTH_FAILED at t+1h, RATE_LIMIT_BLOCKED at t+2h, DISK_FULL at t+3h). User
returns and runs `/dtd interactive`. If the silent window expired while the
user was away, the run is already PAUSED with a compact status summary, but
the full morning-summary path still starts only via `/dtd interactive`.

**Steps**:
1. `/dtd interactive`.
2. Inspect the morning summary block.
3. Resolve the surfaced capsule (oldest first — AUTH_FAILED).
4. After resolve, observe the next capsule (RATE_LIMIT_BLOCKED) being surfaced.

**Expected**:
- Morning summary block matches dtd.md §Morning summary format:
  `+ DTD silent window ended — <elapsed>` header, `+ progress`, `+ deferred
  decisions`, `+ ready work`, `+ next` sections.
- Deferred decisions ordered oldest-first (AUTH_FAILED → RATE_LIMIT → DISK_FULL).
- Each deferred line ≤ 80 chars; includes age (e.g. `3h05m old`).
- `attention_goal` text shown above progress when non-null.
- state.md after `/dtd interactive`: `attention_mode: interactive`,
  `attention_until: null`,
  `last_pause_reason: silent_window_ended` (or `silent_window_ended_no_ready_work`).
- After resolving first capsule, second one is filled into the decision
  capsule slot (oldest of remaining 2).
- AIMemory NOTE event: `silent_window_ended, completed=<N> deferred=3 skipped=<K>`.

**Pass**: user navigates 3 deferred blockers via the morning summary path
without losing any of them; oldest-first ordering preserved across resolutions.

### 23f. Silent deferred-decision limit pauses the run

**Setup**: silent run with `silent_deferred_decision_limit: 5` (lowered from
default 20 for testing). Force 5 deferrals via 5 different blocking conditions
on independent tasks.

**Steps**:
1. `/dtd run --silent=4h --decision auto`.
2. Inject 5 blockers; each defers per silent algorithm.
3. Observe state on the 5th deferral.

**Expected**:
- After 5th deferral: state.md `deferred_decision_count: 5`,
  `plan_status: PAUSED`, `last_pause_reason: silent_deferred_limit`.
- Compact one-line surface in chat: `⚠ silent paused:
  deferred_decision_limit=5 reached. Run /dtd interactive to review.`
- Controller does NOT auto-flip to interactive (per Don't Do These
  v0.2.0f rule).
- AIMemory NOTE: `silent_paused_deferred_limit, count=5`.
- 6th would-be blocker does NOT add to refs (run is already PAUSED).
- `/dtd interactive` then surfaces all 5 deferred via morning summary.

**Pass**: hard cap is enforced; silent does not silently accumulate
unbounded blockers.

### 23g. CONTROLLER_TOKEN_EXHAUSTED capsule fires safely

**Setup**: silent run in progress. Controller (host LLM) hits its own token/
quota wall mid-dispatch (simulated by host UI quota signal or by manual
state injection of `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`).

**Steps**:
1. Force controller exhaustion mid-task.
2. Observe state transition.
3. User next-turn: see capsule + morning summary.

**Expected**:
- state.md: `plan_status: PAUSED`, `last_pause_reason: error_blocked`,
  attention fields preserved exactly as they were before exhaustion,
  `awaiting_user_decision: true`,
  `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`.
- Decision capsule has options
  `[wait_reset, switch_host_model, compact_and_resume, stop]`
  with `decision_default: wait_reset`.
- Compact silent progress summary prints alongside the capsule (silent window
  interrupted by controller exhaustion). Full morning summary requires
  `/dtd interactive`.
- AIMemory NOTE: `controller_token_exhausted, paused_at=<ts>`.
- Doctor `/dtd doctor` PASSes the v0.2.0f autonomy invariant
  (`capsule_options_invalid` check).
- User picks `wait_reset` → state stays PAUSED, capsule is cleared,
  user later runs `/dtd run` to resume.

**Pass**: controller exhaustion is a graceful pause with a recoverable
capsule, not a crash; silent mode is not auto-flipped while the user may be
away.

### 23h. Status dashboard renders modes/ctx lines per v0.2.0f rules

**Setup**: RUNNING plan in `decision_mode: auto`, `attention_mode: silent`
(2h remaining), `resolved_context_pattern: explore`,
`resolved_handoff_mode: rich`, `resolved_sampling: "temp=0.6 top_p=0.95 samples=2"`,
`deferred_decision_count: 1`.

**Steps**: `/dtd status`.

**Expected** (per dtd.md §Status Dashboard v0.2.0f rendering rules):
- `modes` line renders: `| modes     ask auto | attention silent 2h00m left | deferred 1`.
- `ctx` line renders: `| ctx       explore | handoff rich | t=0.6 top_p=0.95 s=2`.
- Both lines ≤ 80 chars.
- Subsequent state with `decision_mode: permission`, `attention_mode: interactive`,
  `deferred_decision_count: 0`, `resolved_context_pattern: null`: BOTH lines
  omitted from compact dashboard (they would be no-ops).
- `/dtd status --full` adds `| ctx-next   <pattern> for next task <id>`.

**Pass**: dashboard renders new lines only when state is non-default;
omits cleanly otherwise; widths within 80.

### 23i. /dtd perf reads ctx data files without polluting context

**Setup**: completed run-001 with a controller usage ledger and 5 task
dispatches (no retries; one ctx file per task). Each dispatch wrote
`.dtd/log/exec-001-task-<id>-att-1-ctx.md` per the v0.2.0f schema. Notepad has
content from a separate run-002 (currently RUNNING).

**Steps**:
1. Capture state.md / notepad.md / attempts/run-002.md before.
2. `/dtd perf --since 1`.
3. Compare after.

**Expected**:
- Perf output uses controller ledger rows for controller totals and YAML front
  matter from each ctx file for worker totals (run/task/worker/
  attempt/phase/context_pattern/sampling/elapsed_ms/controller_*tokens/
  worker_*tokens/cost_usd/http_status).
- Controller and worker totals shown in separate sections.
- Provider tokens null → shown as `unknown`; controller estimates always
  filled.
- Observational reads are absent from `controller-usage-run-NNN.md`.
- state.md / notepad.md / attempts/run-002.md byte-identical before and after.
- `/dtd perf` does NOT update `state.md.last_update`.

**Pass**: ctx data file format works as spec'd; perf is observational.

---

## v0.2.0a — Incident Tracking

### 24. Network failure creates blocking incident

**Setup**: worker registered with unreachable endpoint (closed port). DTD mode on, plan APPROVED.
**Steps**: `/dtd run`. Dispatch fails with NETWORK_UNREACHABLE.
**Expected**: 
1. attempt entry status=`blocked`, error=`NETWORK_UNREACHABLE`, `incident: inc-001-0001`
2. `.dtd/log/incidents/inc-001-0001.md` created with severity=blocked, recoverable=yes, side_effects=none, recovery_options=[retry, test_worker, switch_worker, manual_paste, stop]
3. `.dtd/log/incidents/index.md` has new row
4. state.md: `active_incident_id: inc-001-0001`, `active_blocking_incident_id: inc-001-0001`, `last_incident_id: inc-001-0001`, `incident_count: 1`
5. Decision capsule filled: `awaiting_user_reason: INCIDENT_BLOCKED`
6. `/dtd run` is refused while pending
**Pass**: all 6 conditions hold; doctor reports incident state OK.

### 25. Incident resolved via /dtd incident resolve

**Setup**: scenario 24 state. User fixes the unreachable endpoint (e.g. brings up local server).
**Steps**: `/dtd incident resolve inc-001-0001 retry`.
**Expected**:
1. `.dtd/log/incidents/inc-001-0001.md` updated: `status: resolved`, `resolved_at: <ts>`, `resolved_option: retry`
2. state.md: `active_blocking_incident_id` cleared (NOT decremented — id pointer cleared)
3. state.md: `active_incident_id` also cleared (was the same id, no other unresolved warns)
4. Decision capsule cleared
5. Controller re-dispatches the same task (per `decision_resume_action` for retry option)
6. New attempt created (att-2), no incident on second dispatch (succeeds)
**Pass**: all 6 conditions hold; second attempt succeeds and run continues.

### 26. Multi-blocker policy: second blocker waits in queue (test-fixture path)

**Setup**: scenario 24 state (one active blocker, `active_blocking_incident_id: inc-001-0001`,
decision capsule filled with INCIDENT_BLOCKED). `/dtd run` is refused (per scenario 24 #6).

In v0.2.0a, the test does NOT use `/dtd run` to create the second blocker — that path is
intentionally refused (single-dispatch invariant). The second blocker is created via
**manual fixture injection** to exercise the queue logic, per dtd.md §Incident Tracking
"Multi-blocker policy" path 3 (legal second-blocker sources).

**Steps**:
1. Create `.dtd/log/incidents/inc-001-0002.md` directly (test fixture) with
   `severity=blocked`, `status=open`, `reason=DISK_FULL`, distinct `created_at` newer than `inc-001-0001`.
2. Append a row to `.dtd/log/incidents/index.md` for `inc-001-0002` (this is the queue
   — the index file is the single source of truth for blocker queue ordering).
3. Update state.md: `last_incident_id: inc-001-0002`, `incident_count: 2`. (Do NOT touch
   `active_blocking_incident_id` — invariant: second blocker waits. Do NOT touch
   `recent_incident_summary` — that field is INFO/WARN only per Severity → state mapping.)

**Expected**: Multi-blocker invariant — only ONE active_blocking_incident_id at a time:
1. `active_blocking_incident_id` REMAINS `inc-001-0001` (first incident keeps the slot)
2. `last_incident_id: inc-001-0002`
3. `incident_count: 2`
4. `recent_incident_summary` REMAINS unchanged (does NOT contain blocking incidents —
   queue lives in `index.md`; this field is reserved for info/warn per R2 P2 split)
5. Decision capsule still references first incident (`inc-001-0001`)
6. `/dtd doctor` PASSes the multi-blocker invariant check (≤ 1 active blocker; queue depth = 1
   computed from `index.md` scan, NOT from state.md fields)
7. `/dtd incident list --blocking` shows BOTH `inc-001-0001` (active) and `inc-001-0002`
   (queued) by reading `index.md`
8. After `/dtd incident resolve inc-001-0001 retry`: controller scans `index.md` for the
   oldest unresolved blocker belonging to this run — that is `inc-001-0002` —
   `active_blocking_incident_id` set to `inc-001-0002`, decision capsule refilled with
   `inc-001-0002`'s recovery options
9. `/dtd run` remains refused (now blocked on the promoted second incident)
**Pass**: all 9 conditions hold; invariant maintained; promotion happens exactly once on
first resolution via `index.md` scan; `recent_incident_summary` never contains blockers;
doctor exercises the queue check against `index.md`.

**Note**: the legal non-test paths (late worker return, controller-side internal failure,
future parallel dispatch) are designed-in but not user-reachable in v0.2.0a routine flow.
Manual fixture injection is the v0.2.0a-conformant test path.

### 27. Info-severity incident at info_threshold (recoverable retry repetition)

**Setup**: clean run, `incident_count: 0`, `info_threshold: 3` (default in config.md).
Worker endpoint returns HTTP 429 with `Retry-After` header on each call. Controller's
1st-hit-recovery rule applies — each 429 succeeds on retry per the v0.1.1 error matrix.
The first two 429s do NOT create incidents (1st-hit recoveries are silent per the spec).

The info incident is filed only on the **3rd recoverable 429** of this run (per
`info_threshold: 3` from dtd.md §Incident Tracking "Info-severity triggers" trigger #2),
because at that point the repeated recoverable retry pattern is worth durable tracking.

**Steps**:
1. Dispatch task hits 429 #1 → retry succeeds → no incident, no state mutation beyond
   normal counters.
2. Dispatch task hits 429 #2 → retry succeeds → still no incident.
3. Dispatch task hits 429 #3 → retry succeeds → controller files the info incident
   (threshold reached, rate-limited to one per (run, reason_class)).

**Expected**:
1. `.dtd/log/incidents/inc-001-0001.md` created with `severity=info`,
   `reason=RATE_LIMIT_BLOCKED`, `recoverable=yes`, status=open, `notes: info_threshold reached (3 occurrences)`.
2. state.md: `last_incident_id: inc-001-0001`, `incident_count: 1`.
3. state.md: `active_incident_id` REMAINS null (info doesn't set it — per Severity → state mapping).
4. state.md: `active_blocking_incident_id` REMAINS null.
5. Decision capsule UNCHANGED — no `awaiting_user_decision`, no pause.
6. `/dtd run` continues; current task completes normally.
7. A 4th, 5th, ... 429 in the same run does NOT create additional info incidents
   (rate-limited to one per (run, reason_class)).
8. Compact `/dtd status` does NOT show this incident (info severity hidden in compact);
   `/dtd status --full` shows it under `+ recent incidents` panel via `recent_incident_summary`.
9. `/dtd incident list` (no flag) does include it among unresolved incidents.
**Pass**: severity → state mapping correct; non-blocking incidents don't gate run; the
"1st-hit recoveries do NOT create incidents" rule is preserved (no incident on 429 #1 or #2).

### 28. Doctor verifies incident cross-link integrity

**Setup**: scenario 26 state. Manually corrupt `.dtd/attempts/run-001.md` — remove the `incident:` cross-link from a failed attempt.
**Steps**: `/dtd doctor`.
**Expected**:
1. WARN `attempt_incident_link_missing` with attempt id and incident id pointer
2. Other incident-state checks PASS (state fields valid, no multi-blocker violation, no secret leak)
3. Doctor does NOT auto-fix; recommends manual restoration or treating as superseded
**Pass**: incident state checks per dtd.md doctor §Incident state are exercised; corruption surfaced as WARN; clean state passes silently.

### 29. finalize_run clears incident state on terminal exit

**Setup**: scenario 24 state (one active blocker, decision capsule INCIDENT_BLOCKED).
User decides not to resolve and instead invokes `/dtd stop`.

**Steps**: `/dtd stop` (confirms destructive action).

**Expected** (canonical finalize_run order, dtd.md §`finalize_run` step 5 + 7):
1. `.dtd/log/incidents/inc-001-0001.md` updated: `status: superseded`,
   `resolved_at: <ts>`, `resolved_option: terminal_run`.
2. `.dtd/log/incidents/index.md` row updated to match.
3. state.md: `active_incident_id: null`, `active_blocking_incident_id: null`,
   `recent_incident_summary: []`. `last_incident_id: inc-001-0001` retained.
   `incident_count: 1` retained.
4. state.md decision capsule cleared: `awaiting_user_decision: false`,
   `awaiting_user_reason: null`, `decision_id: null`, `decision_prompt: null`,
   `decision_options: []`, `decision_default: null`, `decision_resume_action: null`.
5. state.md: `plan_status: STOPPED`, `plan_ended_at: <ts>`.
6. AIMemory `WORK_END` event appended (one line, `status=STOPPED`).
7. `/dtd doctor` runs clean — no orphan active incident pointers.
8. A subsequent `/dtd plan ...` then `/dtd run` proceeds without being gated by
   the now-superseded incident.

**FAILED variant**: same setup, but the run terminates via `finalize_run(FAILED)`
(e.g., all workers dead, unrecoverable). Then expected #1 changes to
`status: fatal`, `resolved_option: terminal_failed`. All other expectations identical.

**Pass**: terminal exit fully cleans active incident state; superseded vs fatal
distinction matches terminal_status; doctor confirms clean post-terminal state.

### 30. Destructive incident option requires explicit confirmation (R2 P1 fix)

**Setup**: scenario 24 state (active blocker `inc-001-0001`, decision capsule
INCIDENT_BLOCKED). Recovery options include `retry`, `switch_worker`, `stop`.

**Steps**: user types NL phrase `"그 에러 멈춰"` (or equivalent: `"incident
inc-001-0001 stop"`, `"그만"`, `"중지"`).

**Expected** (per `dtd.md` §`/dtd incident resolve` Destructive option
confirmation, and `.dtd/instructions.md` "Don't auto-execute destructive
incident recovery options"):

1. Controller classifies intent as `incident resolve inc-001-0001 stop` with
   confidence ≥ 0.9 (NL is unambiguous).
2. Controller does NOT execute `finalize_run(STOPPED)`. Instead it prints a
   one-line confirm in Korean (or user's language), e.g.:
   ```
   "incident inc-001-0001을 stop 으로 처리하면 plan-001은 STOPPED로 마감되고
    재개 안 됩니다. 진행? (y/n)"
   ```
3. state.md unchanged at this point: `awaiting_user_decision: true`,
   `active_blocking_incident_id: inc-001-0001` still set; no `plan_ended_at`.
4. On `n` / `취소` / `아니` → controller cancels; state unchanged; user can
   choose another option.
5. On `y` / `네` / `OK` → controller now executes the destructive option:
   `finalize_run(STOPPED)` per scenario 29 expectations.

**Non-destructive control** (verify normal options still flow without extra
confirm): user types `"재시도"` / `"그 에러 retry"` → controller executes
`incident resolve inc-001-0001 retry` immediately at confidence ≥ 0.9 (no
confirm needed; `retry` is not in the destructive option set).

**Pass**: destructive option set (`stop`/`purge`/`delete`/`force_overwrite`/
`revert_partial`/`terminal_finalize`) always confirms regardless of confidence;
non-destructive options (`retry`/`switch_worker`/`wait_once`/`manual_paste`)
follow normal confidence rules; no silent run termination via NL.

---

## v0.2.2 — Compaction UX (Notepad v2 8-heading)

### 80. New install creates schema v2 notepad with all 8 headings empty

**Setup**: fresh install at v0.2.2.

**Steps**: read `.dtd/notepad.md`.

**Expected**:
- First H2 is `## handoff (v0.2.2 8-heading)`.
- 8 H3 children under handoff: Goal, Constraints, Progress,
  Decisions, Next Steps, Critical Context, Relevant Files,
  Reasoning Notes.
- All 8 H3 sections empty (just placeholder text).
- Free-form sections (`## learnings`, `## decisions`,
  `## issues`, `## verification`) present and empty.

**Pass**: schema v2 template ships clean.

### 81. Worker sees only `<handoff>` 8 headings (≤ 1.2 KB total)

**Setup**: active run with populated handoff (all 8 headings
within budget).

**Steps**: dispatch a worker; inspect the prompt assembly.

**Expected**:
- Worker prompt includes the `## handoff` H2 and all 8 H3
  children verbatim (≤ 1.2 KB combined).
- `## learnings`, `## decisions`, `## issues`,
  `## verification` are NOT included (controller-only).
- Token budget for handoff section ≤ 1.2 KB.

**Pass**: workers see structured handoff only; total within budget.

### 82. Compaction at phase boundary truncates Progress, then Relevant Files

**Setup**: handoff at 1.5 KB (over budget); each heading at 2× its
allowed budget.

**Steps**: phase boundary triggers compaction.

**Expected**:
- Step 1: `Progress` truncated to "Phase N completed; see
  phase-history.md".
- Step 2: `Relevant Files` truncated to last 5 path refs.
- Other 6 headings (Goal, Constraints, Decisions, Next Steps,
  Critical Context, Reasoning Notes) preserved as-is.
- Total handoff ≤ 1.2 KB after compaction.

**Pass**: priority order (TRUNCATE first → Progress;
TRUNCATE second → Relevant Files) respected; KEEP headings unchanged.

### 83. Schema v1 notepad keeps working (backward-compat); doctor INFO

**Setup**: pre-v0.2.2 install with free-form `### handoff`
(no `## handoff` H2 + H3 children).

**Steps**:
1. Dispatch worker.
2. `/dtd doctor`.

**Expected**:
- Step 1: worker receives the free-form `<handoff>` block as one
  chunk (no per-heading parsing).
- Step 2: doctor INFO `notepad_schema_v1` recommending migration.
  No ERROR.

**Pass**: backward-compat; old notepads work, doctor recommends
upgrade without blocking.

### 84. Per-heading oversized triggers WARN; /dtd notepad compact clears

**Setup**: schema v2 notepad. `Reasoning Notes` heading at 600
chars (3× the 200-char budget).

**Steps**:
1. `/dtd doctor`.
2. `/dtd notepad compact`.
3. `/dtd doctor`.

**Expected**:
- Step 1: WARN
  `notepad_heading_oversized: Reasoning Notes` with size+budget.
- Step 2: compaction reduces Reasoning Notes to last 3 entries
  (≤ 200 chars); older entries roll into `## learnings` section.
- Step 3: WARN cleared.

**Pass**: oversized headings detected; manual compact clears.

### 85. /dtd notepad search finds across .dtd/runs/ archive

**Setup**: 3 archived runs in `.dtd/runs/run-001-notepad.md`,
`-002-notepad.md`, `-003-notepad.md`. Active notepad is run-004.

**Steps**: `/dtd notepad search "JWT auth"`.

**Expected**:
- Search scans all 4 files (3 archive + 1 active).
- Output groups matches by file with line numbers.
- Hits in active notepad come first; then run-003 (most recent
  archive).

**Pass**: cross-run search works; archive is queryable; output is
auditable.

### 85b. Notepad v2 has Reasoning Notes; worker prompts include compact reasoning capsule

**Setup**: schema v2 notepad with Reasoning Notes populated:

```
- decision: cache layer at edge, not origin
  evidence: [log:exec-001-task-3.1, attempt:att-2]
  risks: cold-cache penalty for cold paths
  next: add ttl monitoring
```

Plan task uses `reasoning-utility="tool_critic"` per v0.2.0f.

**Steps**: dispatch the task; inspect worker prompt.

**Expected**:
- Worker prompt includes the Reasoning Notes content + a
  `<reasoning>` block with `output_contract: decision /
  evidence_refs / risks / next_action`.
- Worker is told NOT to include raw chain-of-thought.

**Pass**: reasoning capsule plumbing works end-to-end without
leakage.

### 85c. Reflexion utility writes 1-line lesson; older entries roll into learnings

**Setup**: 4 prior reflexion entries in Reasoning Notes
(over the "keep last 3" rule). Worker dispatch uses
`reasoning-utility="reflexion"`.

**Steps**: post-process worker response; observe notepad changes.

**Expected**:
- New 1-line lesson entry appended to Reasoning Notes.
- Oldest entry rolled into `## learnings` as one-line bullet.
- Reasoning Notes always has ≤ 3 most-recent entries.

**Pass**: reflexion lessons preserved durably; size stays bounded.

### 85d. Doctor flags reasoning_notes_chain_of_thought_leak

**Setup**: Reasoning Notes contains a multi-paragraph "let me
think step-by-step..." narrative entry (10 lines).

**Steps**: `/dtd doctor`.

**Expected**: WARN `reasoning_notes_chain_of_thought_leak` with
line ref + remediation hint ("compact to ≤ 5 lines per entry").

**Pass**: heuristic catches narrative leakage; protects against
chain-of-thought storage in durable state.

---

## v0.2.1 — Runtime Resilience

### 85e. Phase-boundary compaction order: Progress first, Relevant Files second (v0.2.2 R1)

**Setup**: schema v2 notepad. Handoff at 1.4 KB (over 1.2 KB
budget). Each heading at 1.5× its allowed budget.

**Steps**: phase boundary completes; controller runs compaction
algorithm.

**Expected** (per run-loop.md §"Phase-boundary compaction
algorithm" Step 4):
- Step 4.a: `### Progress` truncated FIRST → replaced with
  `Phase N completed; see phase-history.md for detail`.
- Step 4.b: `### Relevant Files` truncated SECOND → keep last
  5 path refs only.
- Goal / Constraints / Decisions / Next Steps / Critical Context
  / Reasoning Notes preserved unchanged.
- Total handoff ≤ 1.2 KB after compaction.
- `state.md.last_compaction_at: <ts>`,
  `last_compaction_reason: phase_boundary`.

**Pass**: priority order matches Codex's v0.2.2 R0 review patch
(Section 7); state tracks compaction event.

### 85f. Reasoning utility post-processing extracts contract fields (v0.2.2 R1)

**Setup**: APPROVED plan task with
`reasoning-utility="tool_critic"`. Worker dispatches; worker
response includes the output_contract block:

```
<reasoning>
decision: cache layer at edge, not origin
evidence: [log:exec-001-task-3.1, attempt:att-2]
risks: cold-cache penalty for cold paths
next_action: add ttl monitoring
</reasoning>
```

**Steps**: post-dispatch (run-loop step 6.e), observe notepad.

**Expected**:
- Reasoning Notes section gains one entry with the 4 fields
  (decision / evidence / risks / next_action).
- Older entries (if Reasoning Notes already had 3): oldest rolls
  into `## learnings` H2 section as
  `<ts>: <decision> [evidence: <refs>]` bullet.
- No raw chain-of-thought leakage (controller filtered narrative
  patterns).

**Pass**: reasoning capsule captured durably; rollover to
learnings preserved.

### 85g. Chain-of-thought redaction filter triggers on narrative leak (v0.2.2 R1)

**Setup**: worker response (with reasoning utility configured)
includes a multi-paragraph "let me think step-by-step" narrative
in the reasoning block.

**Steps**: post-dispatch.

**Expected**:
- Controller detects narrative pattern (multi-paragraph >5 lines).
- Reasoning Notes entry replaced with placeholder:
  `[redacted: reasoning narrative removed per output discipline]`.
- WARN logged to `.dtd/log/run-NNN-summary.md`.
- `state.md.compaction_warns_run` increments.
- Original narrative is NOT stored anywhere.

**Pass**: chain-of-thought leakage caught and redacted at
post-processing time, before durable storage.

### 85h. reflexion utility writes 1-line lesson always (v0.2.2 R1)

**Setup**: worker dispatches with
`reasoning-utility="reflexion"`. Response includes a lesson:
`lesson: timeout retry should escalate to next-tier worker
faster on stuck-task pattern`.

**Steps**: post-dispatch + at next phase boundary.

**Expected**:
- Post-dispatch: 1-line lesson appended to Reasoning Notes
  (always, even if lesson is short).
- At phase boundary: lesson rolls into `## learnings` (per
  Reasoning Notes "keep last 3, older roll" invariant).
- Cross-run: lesson durable in notepad archive
  (`.dtd/runs/run-NNN-notepad.md`).

**Pass**: reflexion lessons preserved durably; cross-run via
archive; size stays bounded via rollover.

---

## v0.2.1 — Runtime Resilience

### 70. /dtd workers test --all --quick returns OK / FAIL / WARN per worker

**Setup**: registry with 3 workers — one healthy, one with bad
`api_key_env` (env var unset), one with unreachable endpoint.

**Steps**: `/dtd workers test --all --quick`.

**Expected**:
- Stages 1-5 run for each worker.
- Healthy worker: PASS.
- Unset env: FAIL stage 3 with `WORKER_ENV_MISSING`.
- Unreachable: FAIL stage 5 with `WORKER_NETWORK_UNREACHABLE`.
- One row per worker in `.dtd/log/worker-checks/<ts>.md` (redacted —
  no env values, no auth headers).
- `state.md` NOT mutated (observational read).
- No incident or decision capsule is created by standalone
  `/dtd workers test`; only `/dtd run` preflight may create
  `WORKER_HEALTH_FAILED`.

**Pass**: per-worker outcomes are independent; redaction enforced.

### 71. /dtd workers test <id> --full runs protocol probe; sentinel match required

**Setup**: a real worker that responds to OpenAI-compatible chat
completions.

**Steps**: `/dtd workers test deepseek-local --full`.

**Expected**:
- All 17 stages run.
- Stage 10 (protocol_probe) sends a small DTD-shaped mock-output
  prompt asking for one `.dtd/tmp/healthcheck-sentinel.txt` file block
  plus `::done:: healthcheck`; the mock file is parsed but never
  applied.
- Stage 11 (sentinel_match) verifies response contains the terminal
  sentinel exactly.
- Stage 12 verifies the mock file block + terminal marker discipline.
- Worker that fabricates response (e.g. wraps in markdown):
  FAIL stage 11 with `WORKER_SENTINEL_MISMATCH`.

**Pass**: full mode enforces protocol contract that workers must
satisfy for DTD dispatch.

### 72. Preflight check fires WORKER_HEALTH_FAILED capsule on /dtd run

**Setup**: APPROVED plan whose task 2.1 assigns `qwen-local`. That
worker has bad endpoint URL. `worker_test_auto_before_run:
assigned_only` (default).

**Steps**: `/dtd run`.

**Expected**:
- Before dispatching task 2.1, controller runs `--quick` on
  `qwen-local`.
- Stage 4 fails with `WORKER_ENDPOINT_INVALID`.
- Capsule `awaiting_user_reason: WORKER_HEALTH_FAILED` fires;
  options: `edit_worker | switch_worker | retry_check | stop`,
  default `edit_worker`.
- `/dtd run` does NOT dispatch the task until capsule is resolved.

**Pass**: preflight catches setup errors before they become
dispatch errors.

### 73. Worker session resume: same-worker after timeout

**Setup**: worker `claude-api` with `supports_session_resume: true`.
Task 3.1 dispatched; first attempt times out (TIMEOUT_BLOCKED).

**Steps**: `/dtd run` resumes from PAUSED.

**Expected**:
- Controller computes resume strategy: prior failure was TIMEOUT
  (interruption-class) AND worker supports sessions →
  `same-worker`.
- Second attempt: same provider, passes prior `session_id`,
  appends "continue" prompt.
- `attempts/run-NNN.md` row: `resume_of: att-1`,
  `resume_strategy: same-worker`,
  `worker_session_id: <provider-session-id>`.
- `state.md.last_resume_strategy: same-worker`.

**Pass**: provider session continuation reused; lost work avoided.

### 74. Worker session resume: protocol violation forces fresh strategy

**Setup**: worker `local-llm` failed prior attempt with
`MALFORMED_RESPONSE` or `WORKER_PROTOCOL_VIOLATION`.

**Steps**: retry.

**Expected**:
- Strategy resolution: prior failure was protocol-violation class →
  `fresh`.
- Second attempt: brand-new prompt assembly, no
  `worker_session_id`, full GSD-style reset.
- `attempts/run-NNN.md` row: `resume_strategy: fresh`.

**Pass**: tainted sessions never reused; protocol violations get
clean slate.

### 75. Loop guard: 3 consecutive same-signature failures fire LOOP_GUARD_HIT

**Setup**: task 4.1 dispatched 3 times; each fails with the same
`worker_id + task_id + prompt_hash + failure_hash`.

**Steps**: observe controller after the 3rd consecutive failure.

**Expected**:
- After failure 1: `loop_guard_signature` set, count=1.
- After failure 2: count=2.
- After failure 3: count=3 ≥ threshold → `loop_guard_status: hit`.
- Capsule `awaiting_user_reason: LOOP_GUARD_HIT` fires; options:
  `ask_user | worker_swap | controller | stop`, default `ask_user`.

**Pass**: doom loops short-circuit before the failure_threshold
ladder fires; user gets early signal.

### 76. Loop guard: signature window expiry resets counter

**Setup**: signature set 35 minutes ago (window default 30 min).
Two failed attempts have hit it. Now a new failed attempt with the
same signature.

**Steps**: observe.

**Expected**:
- `loop_guard_signature_window_min: 30` evaluation: prior signature
  is stale.
- New failure resets `loop_guard_signature` to current hash; count
  reset to 1.
- No LOOP_GUARD_HIT capsule fires.

**Pass**: stale signatures never accumulate across long gaps.

### 77. Loop guard auto-action: worker_swap (when configured)

**Setup**: `loop_guard_threshold_action: worker_swap`. Three
consecutive same-signature failures.

**Steps**: observe.

**Expected**:
- At threshold hit, controller does NOT fill user-prompted capsule;
  instead advances `current_fallback_index` and dispatches the next
  worker.
- `state.md.loop_guard_status` returns to `idle`; signature reset.
- `attempts/run-NNN.md` row notes `auto_action: worker_swap`.

**Pass**: auto-action skips user prompt only when explicitly
configured; default `ask` always asks.

### 78. /dtd attempts show <id> displays resume strategy lineage

**Setup**: task 5.1 has 3 attempts: att-1 (fresh), att-2 (resumed
same-worker from att-1), att-3 (resumed new-worker from att-2).

**Steps**: `/dtd attempts show 5.1-att-3`.

**Expected**:
- Output shows lineage:
  ```
  att-3: resumed new-worker from att-2
  att-2: resumed same-worker from att-1
  att-1: fresh start
  ```

**Pass**: resume history is auditable and human-readable.

### 79. Doctor catches loop_guard_orphan when capsule unfilled despite hit

**Setup**: `state.md.loop_guard_status: hit` but
`awaiting_user_decision: false` (controller crashed mid-capsule
fill or hand-edited state).

**Steps**: `/dtd doctor`.

**Expected**: WARN `loop_guard_orphan` with hint to clear via
`/dtd doctor --takeover` or manually reset state.

**Pass**: orphan detection prevents stuck-state mysteries.

### 79b. /dtd workers test --full probes tool-relay (controller_relay)

**Setup**: worker `gpt-4o-relay` with
`tool_runtime: controller_relay`. Healthy provider.

**Steps**: `/dtd workers test gpt-4o-relay --full`.

**Expected**:
- Stage 14 (`tool_request_relay_probe`) runs.
- Probe sends a small DTD-shaped prompt asking worker to emit
  `::tool_request::` for `read_file pattern: "package.json"`.
- Worker returns `::tool_request::` as terminal status (does NOT
  pretend to have run the tool).
- Tool name + args well-formed.
- Stage 14 PASS.

**Pass**: relay protocol verified at health-check time, before
real dispatch.

### 79c. Worker fabricates tool result; flagged WORKER_TOOL_RELAY_FABRICATED_RESULT

**Setup**: worker that ignores relay protocol and instead writes
fake tool result text.

**Steps**: `/dtd workers test <id> --full`.

**Expected**:
- Stage 14 detects fabricated result (worker did not return
  `::tool_request::`; instead returned a "result" string).
- Stage 14 FAIL with `WORKER_TOOL_RELAY_FABRICATED_RESULT`.
- This is security-relevant: fill capsule
  `awaiting_user_reason: WORKER_TOOL_RELAY_FABRICATED` if mid-run;
  options `[switch_worker, stop]`, default `switch_worker`.

**Pass**: fabrication caught before it can damage state.

### 79d. Worker registry claims native_tool_sandbox: true but probe finds no sandbox

**Setup**: worker `claude-native` with `tool_runtime: worker_native`
and `native_tool_sandbox: true` in registry. Provider does NOT
expose tools.

**Steps**: `/dtd workers test claude-native --full`.

**Expected**:
- Stage 15 (`native_tool_sandbox_check`) runs.
- Probe asks worker to run a trivial native tool (list current dir).
- Response has no sandbox markers (no tool_use blocks, no function
  calls).
- Stage 15 FAIL with `WORKER_NATIVE_TOOL_NOT_SUPPORTED`.
- Per `worker_test_sandbox_leak_action: refuse_native` (default),
  controller refuses to use this worker for native/hybrid tool
  modes; capsule
  `awaiting_user_reason: WORKER_NATIVE_TOOL_SANDBOX_INVALID`
  with options `[switch_to_relay, fix_registry, switch_worker, stop]`.

**Pass**: registry claims about sandbox are runtime-verified; bad
configs cannot silently use unsafe modes.

---

## v0.2.0c — Snapshot / Revert

### 79e. Worker test stage runner halts on stages 1-5 FAIL (v0.2.1 R1)

**Setup**: worker `test-fixture` with intentionally bad
`api_key_env` (env var unset).

**Steps**: `/dtd workers test test-fixture --full`.

**Expected**:
- Stages 1-3 PASS (registry/schema/secret-name).
- Stage 3 FAIL? No — secret-NAME is ok; stage 4 (endpoint URL)
  PASS; stage 5 (network reachability) PASS *or* the auth header
  is missing → stage 7 (auth_handshake) FAIL with
  `WORKER_AUTH_FAILED`.
- Per the runtime contract (run-loop.md §"Worker test diagnostic
  runner"), stages 1-5 FAIL halts further stages; stages 6-13
  FAIL records but continues; stages 14-17 always run if reached.
- For an env-missing scenario where stage 3 itself FAILs: log
  shows stages 1-3 with stage 3 FAIL; no stages 4+ logged.
- Doctor INFO `worker_check_stage_sequence_drift` if drift seen.

**Pass**: stage runner sequence is contract-enforced; redaction
applied to log; standalone test creates no incident/capsule.

### 79f. Resume strategy resolution per failure class (v0.2.1 R1)

**Setup**: task 4.1 retry. Three sub-scenarios:

| Prior failure | worker.supports_session_resume | Expected strategy |
|---|---|---|
| TIMEOUT_BLOCKED | true | `same-worker` |
| WORKER_PROTOCOL_VIOLATION | true | `fresh` (tainted session) |
| TIMEOUT_BLOCKED, prior 2× same-worker failed | true | `new-worker` |

**Steps**: trigger each retry; observe controller's resume
strategy resolver.

**Expected**:
- Sub-scenario 1: `state.md.last_resume_strategy: same-worker`;
  prior `worker_session_id` reused.
- Sub-scenario 2: `last_resume_strategy: fresh`; no session_id
  passed.
- Sub-scenario 3: `last_resume_strategy: new-worker`; fallback
  chain advanced.
- Same-worker resume row in `attempts/run-NNN.md` does NOT
  inline raw prior worker output (per Codex safety guardrail).

**Pass**: strategy resolver matches the documented algorithm
(failure-class-aware + provider-aware + failure-count-aware).

### 79g. Loop guard signature window resets (v0.2.1 R1)

**Setup**: `loop_guard_threshold: 3`,
`loop_guard_signature_window_min: 30`.
Two attempts at T-35min hit signature S1 (count=2). Now T+0 a
new attempt also has signature S1.

**Steps**: observe controller after the new failed attempt.

**Expected**:
- `loop_guard_signature_first_seen_at` is older than 30 min →
  reset count to 1 and set `loop_guard_signature_first_seen_at: <now>`
  (despite signature match).
- `loop_guard_status` stays `idle` (count=1 < threshold=3).
- No `LOOP_GUARD_HIT` capsule fires.

**Pass**: window-based staleness prevents old patterns from
triggering false positives.

### 79h. Loop guard auto-action ignores decision_mode auto (v0.2.1 R1)

**Setup**:
- Sub-A: `loop_guard_threshold_action: ask`,
  `decision_mode: auto`. 3× same signature.
- Sub-B: `loop_guard_threshold_action: worker_swap`,
  `decision_mode: permission`. 3× same signature.

**Expected**:
- Sub-A: `LOOP_GUARD_HIT` capsule fires (decision_mode auto does
  NOT skip permission-class capsule).
- Sub-B: capsule does NOT fire; controller advances
  `current_fallback_index` and dispatches next worker (auto-action
  triggered by explicit config, not decision_mode); loop signature,
  count, and `loop_guard_signature_first_seen_at` reset to idle values.

**Pass**: auto-action is gated by `loop_guard_threshold_action`
config explicitly, not by decision_mode auto.

---

## v0.2.0c — Snapshot / Revert

### 60. Snapshot created at apply for each output file with mode-per-policy

**Setup**: APPROVED plan, task 2.1 writes 3 files: `src/api/users.ts`
(text, 4 KB, git-tracked), `src/build/icon.png` (binary, 12 KB,
git-tracked), `tests/fixtures/big.json` (text, 200 KB, untracked).

**Steps**: `/dtd run --until task:2.1`.

**Expected**:
- After apply, `.dtd/snapshots/snap-001-task-2.1-att-1/` exists with:
  * `manifest.md` listing all 3 files.
  * `files/src__api__users.ts.preimage` (small tracked text; default
    apply writes must be revertable).
  * `files/src__build__icon.png.preimage` (binary).
  * `files/tests__fixtures__big.json.patch` (text > preimage threshold).
- `.dtd/snapshots/index.md` `## Active snapshots` row appended.
- `state.md.last_snapshot_id: snap-001-task-2.1-att-1`,
  `last_snapshot_at: <ts>`.

**Pass**: per-file mode follows policy (small changed text → preimage,
binary → preimage, large text → patch).

### 61. /dtd revert last restores files atomically (temp + rename)

**Setup**: scenario 60's snapshot exists. Permission `revert: allow`
or default ask resolved.

**Steps**: `/dtd revert last` and confirm.

**Expected**:
- All revertable files (preimage + patch) restored atomically:
  Phase 1 writes temps; Phase 2 renames over current.
- `state.md.last_revert_id: snap-001-task-2.1-att-1`,
  `last_revert_at: <ts>`.
- `attempts/run-NNN.md` row appended: `reverted: snap-001-task-2.1-att-1`.
- `phase-history.md` row appended.

**Pass**: revert is atomic + recorded; `src/api/users.ts`,
`src/build/icon.png`, and `tests/fixtures/big.json` are restored.

### 62. /dtd revert task <id> undoes all attempts in reverse order

**Setup**: task 3.1 has 3 attempts (att-1 failed, att-2 superseded by
att-3, att-3 applied successfully). Snapshots exist for att-1 and
att-3 (att-2 was superseded before apply, so no snapshot).

**Steps**: `/dtd revert task 3.1` and confirm.

**Expected**:
- Revert iterates attempts in reverse: att-3 first, then att-1.
- Superseded att-2 skipped (no `applied: true` flag).
- Files restored to pre-att-1 state.
- `attempts/run-NNN.md` rows appended for each revert.

**Pass**: superseded attempts skipped; revert order is reverse;
final state is pre-task baseline.

### 63. metadata-only files surface revert_unavailable_metadata_only

**Setup**: snapshot exists where `docs/schema.md` is explicitly marked
`metadata-only` as an audit-only/non-output context file. Normal worker output
files do not default to metadata-only.

**Steps**: `/dtd revert last`.

**Expected**:
- Capsule `awaiting_user_reason: PARTIAL_REVERT` fired.
- `decision_options` include `revert_revertable_only`, `inspect`,
  `cancel`.
- Output mentions `revert_unavailable_metadata_only: docs/schema.md`.

**Pass**: capsule surfaces clearly; user can choose to skip the
non-revertable file or cancel.

### 64. PARTIAL_REVERT capsule when some files revertable, some not

**Setup**: same snapshot from scenario 63 (mixed modes).

**Steps**:
1. `/dtd revert last` → PARTIAL_REVERT capsule.
2. Choose `revert_revertable_only`.

**Expected**:
- Only preimage/patch files restored.
- Metadata-only files left untouched; controller logs the skip.
- `attempts/run-NNN.md` row notes partial revert.

**Pass**: partial revert is explicit user choice; never silent.

### 65. Snapshot mode selection: small text → preimage, large text → patch, binary → preimage

**Setup**: synthetic apply with one file per mode trigger:
- `small.txt` (text, 2 KB, untracked) → preimage (untracked rule).
- `large.go` (text, 200 KB, untracked) → patch (>threshold + text).
- `image.png` (binary, 8 KB) → preimage (binary).

**Steps**: trigger snapshot creation; inspect `manifest.md`.

**Expected**: each file's mode column matches its trigger.

**Pass**: policy is deterministic and documented in manifest's
"Reason for mode choices" section.

### 66. DISK_FULL during snapshot creation: decision capsule with proceed_unsafe option

**Setup**: simulate disk full when writing
`.dtd/snapshots/snap-001-task-2.1-att-1/files/...`.

**Steps**: dispatch task whose apply would trigger snapshot.

**Expected**:
- Snapshot phase fails; per `config.snapshot.on_snapshot_fail`
  (default `refuse_apply`):
  * Decision capsule `awaiting_user_reason: DISK_FULL`.
  * Options include the existing v0.1.1 set PLUS new
    `proceed_unsafe` (default NO).
- If user chooses `proceed_unsafe`: apply proceeds; attempt marked
  `unrevertable: true` in attempts log.
- If user chooses default refuse: dispatch aborts; no apply.

**Pass**: snapshot failure surfaces explicitly; proceed_unsafe is an
informed override.

### 67. Permission ledger revert: ask fires PERMISSION_REQUIRED before revert

**Setup**: scenario 60's snapshot exists. `permissions.md` has no
explicit revert rule (default `ask`).

**Steps**: `/dtd revert last`.

**Expected**:
- BEFORE entering the revert algorithm: capsule
  `awaiting_user_reason: PERMISSION_REQUIRED` fires for `revert`
  key.
- User chooses `allow_once` → revert proceeds.
- User chooses `deny_always` → revert aborts AND new ledger row
  `deny | revert` added.

**Pass**: revert is gated by ledger; v0.2.0b integration works.

### 68. Doctor catches preimage SHA corruption and patch drift

**Setup**:
1. Snapshot exists with `users.ts.preimage`.
2. Manually corrupt the preimage file (flip a byte).
3. Snapshot exists with `products.ts.patch`. Manually edit current
   working `products.ts` so the reverse patch wouldn't apply
   cleanly.

**Steps**: `/dtd doctor`.

**Expected**:
- ERROR `snapshot_preimage_corrupted` for users.ts.preimage.
- WARN `snapshot_patch_drift` for products.ts.patch.

**Pass**: doctor catches both corruption modes; user can re-snapshot
or accept partial revertability.

### 69. /dtd snapshot rotate moves old snapshots to archived/; doesn't delete

**Setup**: 5 snapshots exist; 2 are older than `retention_days`
(default 30). `auto_rotate: false`.

**Steps**: `/dtd snapshot rotate`.

**Expected**:
- 2 old snapshots moved to `.dtd/snapshots/archived/`.
- `index.md` rows updated with status `rotated` (not deleted).
- 3 active snapshots remain in `.dtd/snapshots/`.
- No file content lost.

**Pass**: rotate preserves audit; only archive flag and path move.

---

## v0.2.0b — Permission Ledger

### 69a. Snapshot mode resolution at apply (v0.2.0c R1)

**Setup**: APPROVED plan, task 2.1 writes 4 files at apply:
- `src/api/users.ts` (text, 4 KB, git-tracked, NEW worker output)
- `src/build/icon.png` (binary, 12 KB, git-tracked)
- `tests/fixtures/big.json` (text, 200 KB, untracked)
- `src/new-widget.ts` (text, 2 KB, path absent before apply)
- `docs/notes.md` (text, 1 KB, git-tracked, context-only existing
  file the worker reads but does not modify)

**Steps**: `/dtd run --until task:2.1`.

**Expected** (per run-loop.md §"Snapshot mode resolution"):
- `src/api/users.ts` → **`preimage`** (small tracked text output;
  per Codex policy small tracked text outputs MUST use preimage).
- `src/build/icon.png` → **`preimage`** (binary extension).
- `tests/fixtures/big.json` → **`patch`** (untracked text >
  preimage_size_threshold; falls under rule 4 of mode resolution).
  Wait — actually rule 4 (size > 64 KB) fires before rule 7 (untracked
  text default = preimage). Re-read: rule 4 is "size > 64 KB → patch".
  This file is 200 KB > 64 KB so → patch. Confirm.
- `src/new-widget.ts` → **`preimage`** with absent-prestate marker;
  revert deletes the created file.
- `docs/notes.md` is NOT in `<output-paths>` — no snapshot row at all
  (snapshot only covers files actually being modified by the apply).

**Pass**: per-file mode follows the resolution-order policy
deterministically; reasoning recorded in `manifest.md` "Reason for
mode choices" section.

### 69b. Revert algorithm permission-gated + lock-acquired (v0.2.0c R1)

**Setup**: scenario 69a's snapshot exists. `permissions.md` has no
explicit revert rule (default `ask`).

**Steps**: `/dtd revert last`.

**Expected**:
- BEFORE entering revert algorithm:
  - Capsule `awaiting_user_reason: PERMISSION_REQUIRED` for
    `revert` key (default ask) — user grants `allow_once`.
  - Audit log row: `<ts> | dec-NNN | revert | last | rule_match: default | decision: asked` then `decision: user-allow`.
  - Destructive confirm prompt (`/dtd revert` is destructive) —
    user confirms.
  - Write locks acquired for all 3 revertable files (per §Resource
    Locks; same lock set as fresh apply).
- Validation pass: preimage SHA matches manifest; patch dry-run
  cleanly applies.
- Phase 1 + 2 atomic restore.
- `state.md.last_revert_id: snap-001-task-2.1-att-1`,
  `last_revert_at: <ts>`.
- `index.md` row updated: status `active` → `reverted`.
- `attempts/run-NNN.md` row appended:
  `reverted: snap-001-task-2.1-att-1`.

**Pass**: revert is permission-gated, lock-acquired, atomic,
audit-logged, and state-tracked end-to-end.

### 69c. Patch artifacts + format spec validated (v0.2.0c R1)

**Setup**: a snapshot with at least one `patch` mode file.

**Steps**: read `snap-*/manifest.md` and `/dtd doctor`.

**Expected**:
- Manifest "Patch artifacts" section lists `forward.patch` +
  `reverse.patch` paths.
- `patch_format_version: 1` declared.
- `whitespace_handling: preserve_lf` (or `normalize_crlf` for CRLF
  files; chosen by controller per file's line-ending detection).
- Doctor verifies both artifact files exist on disk.
- Manually delete `reverse.patch` → doctor ERROR
  `snapshot_patch_artifacts_missing`.

**Pass**: patch format is spec'd; doctor catches missing artifacts.

### 69d. /dtd revert task <id> reverse-order skip-superseded (v0.2.0c R1)

**Setup**: task 3.1 has 3 attempts:
- att-1 applied successfully → snap-001-task-3.1-att-1 exists.
- att-2 superseded BEFORE apply (no snapshot — never applied).
- att-3 applied successfully → snap-001-task-3.1-att-3 exists.

**Steps**: `/dtd revert task 3.1`.

**Expected**:
- Revert applies in REVERSE order:
  - First: revert att-3 (snap-001-task-3.1-att-3).
  - Second: revert att-1 (snap-001-task-3.1-att-1).
- att-2 is SKIPPED (no snapshot; `attempts/run-NNN.md` row
  has no `applied: true`).
- Files end up in pre-att-1 state (as expected for
  `revert task <id>` semantics).

**Pass**: superseded attempts skipped; reverse order is
deterministic.

---

## v0.2.0b — Permission Ledger

### 50. Default rules allow todowrite, ask everything else

**Setup**: fresh install at v0.2.0b. `.dtd/permissions.md` exists with empty
`## Active rules` and the canonical `## Default rules`.

**Steps**: `/dtd permission list`.

**Expected**:
- Active rules: empty.
- Default rules show `allow | todowrite | scope: *` and `ask | <key>` for
  the other 9 permission keys (edit, bash, external_directory, task,
  snapshot, revert, tool_relay_read, tool_relay_mutating, question).
- `state.md.pending_permission_request: null`.

**Pass**: install ships safe defaults; nothing auto-allowed except `todowrite`.

### 51. /dtd permission allow persists across sessions

**Setup**: per scenario 50.

**Steps**:
1. `/dtd permission allow edit scope: src/**`.
2. End session; reopen.
3. `/dtd permission list`.

**Expected**:
- Step 1 appends one row to `.dtd/permissions.md` `## Active rules` with
  `<ts> | allow | edit | scope: src/** | by: user`.
- Step 3 (after session reopen) shows the rule still active.

**Pass**: rules durable across sessions; ledger is the single source of truth.

### 52. Auto-allow during run does not surface PERMISSION_REQUIRED capsule

**Setup**: `/dtd permission allow edit scope: src/**` set; APPROVED plan
where task 2.1 writes to `src/api/users.ts`.

**Steps**: `/dtd run`.

**Expected**:
- Task 2.1 dispatches without filling `awaiting_user_decision`.
- `.dtd/log/permissions.md` accumulates a row:
  `<ts> | dec-NNN | edit | src/api/users.ts | rule_match: <ts of allow row> | decision: auto-allow`.
- `state.md.pending_permission_request` remains `null`.

**Pass**: matching `allow` rule short-circuits the capsule; controller proceeds.

### 53. /dtd permission deny blocks immediately, no defer

**Setup**: any plan state. `/dtd permission deny bash scope: rm -rf` set.

**Steps**: trigger an action whose bash scope matches `rm -rf` (e.g., a
worker dispatch that would attempt it).

**Expected**:
- Action aborted before dispatch; `.dtd/log/permissions.md` records
  `decision: auto-deny`.
- Even with `attention_mode: silent`, the deny is NOT deferred —
  `deferred_decision_count` is unchanged.
- Optional incident `info` row recorded; no blocking incident.

**Pass**: deny rules are final and silent-mode-safe.

### 54. Silent mode + ask rule defers; allow auto-handles

**Setup**: `attention_mode: silent`, `attention_until` 4h future. Active
rules: `allow edit scope: src/**`, `ask edit scope: tests/**`.

**Steps**: silent run dispatches two tasks — one editing `src/api/users.ts`,
one editing `tests/integration/foo.test.ts`.

**Expected**:
- First task: auto-allow per `src/**` rule; runs without capsule.
- Second task: ask rule fires PERMISSION_REQUIRED capsule; capsule
  added to `deferred_decision_refs`; controller skips the task and
  continues with next ready work per silent algorithm.
- Morning summary on `/dtd interactive` lists the deferred capsule
  as item 1.

**Pass**: silent mode honors per-key ledger; ask defers, allow auto-runs.

### 55. Doctor flags overly-broad bash allow

**Setup**: `/dtd permission allow bash scope: *` (or `/**`).

**Steps**: `/dtd doctor`.

**Expected**: WARN `permission_bash_too_broad` with line ref + remediation
hint. Exit code remains 0 (WARN does not block).

**Pass**: doctor catches dangerously-broad allow rules.

### 55a. Narrow deny beats broader allow by specificity

**Setup**: active rules include `allow | edit | scope: src/**` and
`deny | edit | scope: src/api/secrets/**`.

**Steps**: `/dtd permission show edit scope: src/api/secrets/key.ts`, then
trigger an edit under `src/api/secrets/`.

**Expected**:
- Resolution chooses the narrower deny rule even if the broad allow is newer.
- `.dtd/log/permissions.md` records `decision: auto-deny`.
- `/dtd doctor` may WARN `permission_rule_overlap`, but runtime semantics are
  deterministic: specificity first, timestamp second.

**Pass**: broad allow cannot accidentally override a narrower deny.

### 56. Permission audit log accumulates per-decision rows

**Setup**: a few permission resolutions across a run (auto-allow,
auto-deny, asked-then-allowed by user).

**Steps**: read `.dtd/log/permissions.md` after the run.

**Expected**:
- One row per resolution.
- Each row has `<ts> | <dec_id> | <key> | <scope> | rule_match: ... | decision: ...`.
- Audit log is gitignored (`.dtd/.gitignore` covers `log/`).

**Pass**: audit log durable + private; one row per resolution; no rule
mutations are silently dropped.

### 57. Rule expiry: `until` timestamp in past makes rule inactive

**Setup**: `allow edit scope: src/** until: 2026-05-04 00:00` (past).

**Steps**:
1. `/dtd permission show edit scope: src/api/users.ts`.
2. Trigger an edit action.
3. `/dtd doctor`.

**Expected**:
- Step 1: resolution falls through to default `ask`.
- Step 2: PERMISSION_REQUIRED capsule fires (rule treated as inactive).
- Step 3: INFO `permission_rule_expired` listing the expired row.

**Pass**: time-of-check expiry; doctor surfaces cleanup recommendation.

### 58. /dtd permission revoke removes rule; audit retained

**Setup**: `allow edit scope: src/**` exists.

**Steps**: `/dtd permission revoke edit scope: src/**`.

**Expected**:
- A tombstone row appended:
  `<ts> | revoke | edit | scope: src/** | by: user (revokes 2026-05-05 14:00 row)`.
- The original allow row remains in the file (history preserved).
- Resolution after revoke: falls through to default `ask` (most-recent
  matching rule for that scope is the `revoke`, which neutralizes
  prior allow).

**Pass**: revoke is a tombstone, not a destructive deletion.

### 59. Silent transient rules expire on /dtd interactive

**Setup**: `silent_allow_destructive: false` (config default). Run
`/dtd silent on --for 4h`.

**Steps**:
1. After silent_on, inspect `.dtd/permissions.md` `## Active rules`.
2. Run `/dtd interactive` before window expires.
3. Inspect `## Active rules` again.

**Expected**:
- Step 1: a transient row exists with
  `by: silent_window` and `until: <attention_until>`.
- Step 3: the transient row is no longer the resolved rule (revoked or
  expired by interactive). User's permanent rules apply again.

**Pass**: silent-mode safety nets are per-window only, never permanent.

### 59a. Permission key resolved at correct run-loop step (v0.2.0b R1)

**Setup**: APPROVED plan with task that writes `src/api/users.ts`.
Active rules: `allow edit scope: src/**`, `ask bash scope: *`.

**Steps**: `/dtd run`.

**Expected**:
- Step 5.5 resolves `task` against default-rule (no explicit task
  rule); fires PERMISSION_REQUIRED (default `ask`); user grants
  `allow_once`.
- Step 6.f.0 resolves `edit` against `allow edit scope: src/**`;
  no capsule fires (auto-allow).
- `.dtd/log/permissions.md` accumulates 3 rows (task asked +
  user-allow, edit auto-allow).

**Pass**: per-key resolution at the spec'd run-loop step; audit
log captures every resolution with `dec_id` lineage.

### 59b. Audit log row format enforced (v0.2.0b R1)

**Setup**: any active permissions ledger run with a few resolutions.

**Steps**: read `.dtd/log/permissions.md`. Run `/dtd doctor`.

**Expected**:
- All rows match
  `<ts> | <dec_id> | <key> | <scope> | rule_match: ... | decision: ...`.
- Doctor passes the audit format check.
- Manually corrupt one row (drop the `decision:` field). Re-run
  doctor → WARN `permission_audit_row_invalid` with line ref.

**Pass**: audit log format is doctor-enforced; row corruption is
caught.

### 59c. Silent transient rules installed at /dtd silent on (v0.2.0b R1)

**Setup**: `config.attention.silent_allow_destructive: false`,
`silent_allow_paid_fallback: false`. User has permanent
`allow bash scope: rm -rf` (terrifying but legal).

**Steps**: `/dtd silent on --for 4h --goal "overnight build"`.

**Expected**:
- 2 transient rows appended to `.dtd/permissions.md` `## Active rules`:
  - `<ts> | deny | task | scope: paid_fallback | until: <attention_until> | by: silent_window`
  - `<ts> | deny | bash | scope: destructive_command_set | until: <attention_until> | by: silent_window`
- `state.md.silent_window_transient_rule_ids` populated with the
  2 timestamps.
- During silent window: a worker's attempt to run `rm -rf X`,
  PowerShell `Remove-Item -Recurse X`, or `cmd /c rmdir /s X`
  resolves to `deny` (transient rule covers POSIX and Windows
  destructive-command forms, and beats permanent allow per
  specificity-first; transient rule is more specific because of
  `until` and `by`).

**Pass**: transient rules override permanent rules within the
silent window only.

### 59d. Transient rules revoked at /dtd interactive (v0.2.0b R1)

**Setup**: silent window active per scenario 59c.

**Steps**: `/dtd interactive`.

**Expected**:
- 2 tombstone rows appended to `## Active rules`:
  - `<ts> | revoke | task | scope: paid_fallback | by: silent_window_end (revokes <transient ts>)`
  - `<ts> | revoke | bash | scope: destructive_command_set | by: silent_window_end (revokes <transient ts>)`
- `state.md.silent_window_transient_rule_ids` cleared (empty list).
- Original transient rows remain in file (audit trail preserved).
- User's permanent `allow bash scope: rm -rf` is now active again
  (terrifying but per user's explicit rule).

**Pass**: revoke is non-destructive (tombstones, not deletes);
state list synced; permanent rules resume.

### 59e. Decision_mode auto does NOT auto-resolve ask permission (v0.2.0b R1)

**Setup**: `decision_mode: auto`. Active rules: `ask edit scope: *`.

**Steps**: `/dtd run` with task that needs to edit a file.

**Expected**:
- Step 6.f.0 resolves `edit` to `ask` (default rule).
- PERMISSION_REQUIRED capsule fires (NOT auto-resolved by
  decision_mode: auto).
- `decision_mode: auto` only auto-resolves non-permission
  decisions (e.g. plan-pending vs run-now).

**Pass**: permission-class is user-required regardless of
decision_mode. The only auto-resolve gate is an explicit user
`allow` rule.

---

## v0.2.0e — Locale Packs

### 44. Locale pack disabled by default; only bootstrap aliases route

**Setup**: fresh install at v0.2.0e. `config.md locale.enabled: false`,
`state.md locale_active: null`, `.dtd/locales/ko.md` AND `.dtd/locales/ja.md`
both present on disk.

**Steps**:
1. User: `/ㄷㅌㄷ 워커 추가` (Korean alias + non-bootstrap NL phrase).
2. User: `/ㄷㅌㄷ locale enable ko` (bootstrap form).
3. User: `/ㄷㅌㄷ locale list` (bootstrap form).
4. User: `/ㄷㅌㄷ 워커 추가` again (post-enable; should now route).

**Expected**:
- Step 1: controller returns the bootstrap hint
  `"Korean locale is not enabled. Run /dtd locale enable ko."`. Does NOT
  route to `/dtd workers add`.
- Step 2: routes to `/dtd locale enable ko`. After confirm, sets
  `config.md locale.enabled: true`, `locale.language: ko`, `state.md
  locale_active: ko`, `locale_set_by: user`.
- Step 3: routes to `/dtd locale list` and prints the catalog
  (active=ko, available=ko/ja/en).
- Step 4: now routes to `/dtd workers add` because the Korean pack is
  loaded and its NL row matches.

**Pass**: only the four bootstrap-alias forms route while
`locale_active: null`; full Korean NL routing requires a successful
`/dtd locale enable ko`.

### 45. /dtd locale enable activates Korean pack on next turn

**Setup**: install per scenario 44 step 0. Run `/dtd locale enable ko`.

**Steps**:
1. Inspect `.dtd/state.md` and `.dtd/config.md` immediately after the
   enable command.
2. Issue any Korean NL phrase (e.g. `"진행상황"`).

**Expected**:
- `state.md`: `locale_active: ko`, `locale_set_by: user`,
  `locale_set_at: <ts>` set in same atomic write.
- `config.md`: `locale.enabled: true`, `locale.language: ko`.
- Next turn loads `.dtd/locales/ko.md` after `instructions.md`
  (per-turn protocol step 1.6).
- `"진행상황"` routes to `/dtd status` via the Korean NL row.

**Pass**: pack-load is observable on the next turn; canonical action
is recorded in audit log as `/dtd status`, never the Korean phrasing.

### 46. /dtd locale disable reverts to English-only without removing files

**Setup**: ko pack enabled per scenario 45.

**Steps**:
1. `/dtd locale disable`.
2. Issue `"진행상황"` (Korean NL).
3. Issue `/ㄷㅌㄷ locale enable ko` (bootstrap form).

**Expected**:
- Step 1: `config.md locale.enabled: false`, `locale.language: null`,
  `state.md locale_active: null`, `locale_set_by: user`.
  `.dtd/locales/ko.md` file remains on disk untouched.
- Step 2: `"진행상황"` does NOT route (no pack loaded). Controller
  returns bootstrap hint.
- Step 3: re-enable works without reinstall (pack file still present).

**Pass**: disable is reversible; pack files persist; only state/config
flip.

### 47. Doctor flags missing locale pack when enabled

**Setup**: `config.md locale.enabled: true, locale.language: ko`, but
`.dtd/locales/ko.md` is intentionally absent (simulated misconfig).

**Steps**: `/dtd doctor`.

**Expected**:
- ERROR `locale_pack_missing` with hint to disable or install pack.
- Exit code 1.

**Pass**: misconfigured locale state surfaces as a blocking ERROR.

### 48. Locale pack required-section + size budget validated

**Setup**: install with valid `ko.md` and `ja.md` packs.

**Steps**:
1. `/dtd doctor` against valid packs → PASS.
2. Edit `ko.md` to remove the `## NL routing additions` section. Run
   doctor.
3. Inflate `ko.md` past 12 KB (`pack_size_budget_kb` cap). Run doctor.

**Expected**:
- Step 1: no locale-related ERROR/WARN.
- Step 2: ERROR `locale_pack_missing_required_section: ko`.
- Step 3: WARN `locale_pack_oversized: ko`.

**Pass**: doctor validates pack contract and size budget per
`config.md locale.pack_size_budget_kb`.

### 49. Bootstrap alias section enforced in instructions.md

**Setup**: install at v0.2.0e.

**Steps**:
1. Verify `.dtd/instructions.md` contains §"Locale bootstrap aliases".
2. Remove that section (simulated drift).
3. Run `/dtd doctor`.

**Expected**:
- Step 1: section present with `/ㄷㅌㄷ locale enable <lang>` row, etc.
- Step 3 after removal: ERROR `bootstrap_alias_missing` (a non-English
  user could not enable their pack from a fresh install).

**Pass**: bootstrap alias surface is doctor-enforced; cannot regress.

---

## v0.2.0d — Self-Update + /dtd help

### 86. /dtd update check no-op when on latest

**Setup**: install at v0.2.0d (or whatever current tagged version).
`state.md.installed_version: <current>`.

**Steps**: `/dtd update check`.

**Expected**:
- HTTP GET to GitHub manifest of latest tagged release.
- Compare `manifest.version` vs `state.md.installed_version`.
- If equal: print `✓ already on latest (v0.2.0d). last checked: <ts>`.
- `state.md` remains byte-identical before/after; `update_check_at` is not
  written by this observational command.
- No file writes; no backup; no AIMemory/notepad/attempt append.

**Pass**: no-op message printed; no files or state are modified.

### 87. /dtd update --dry-run shows full delta + asks confirm

**Setup**: install at v0.2.0a (pre-v0.2.0d). User invokes update flow.

**Steps**: `/dtd update --dry-run`.

**Expected**:
- Pre-update gates: state.md.update_in_progress: false ✓, no plan_status:
  RUNNING with pending_patch ✓, host.mode != plan-only ✓.
- HTTP GET MANIFEST.json from `<repo>/<latest-tag>`.
- Verify version: from v0.2.0a → to v0.2.0d.
- Print delta:
  ```
  + DTD update preview: v0.2.0a → v0.2.0d
  + new files: 12 (.dtd/help/×10, MANIFEST.json, scripts/build-manifest.ps1)
  + modified files: 6 (dtd.md, instructions.md, state.md, config.md, README*, prompt.md)
  + state schema migration: +6 fields (Self-Update state section)
  + config schema migration: +6 keys (update section)
  + estimated total token reduction: minimal (v0.2.0d is additive)
  + Apply? (y/n/edit)
  ```
- NO file writes.
- NO state.md mutation.

**Pass**: full delta visible without applying; user can review before confirm.

### 88. /dtd update applies; manifest verification passes; doctor PASS

**Setup**: install at v0.2.0a. User has reviewed --dry-run output and confirmed.

**Steps**: `/dtd update` → confirm `y`.

**Expected** (B1-B7 update flow per dtd.md §/dtd update):
- B1: `state.md.update_in_progress: true` atomically.
- B2: MANIFEST.json fetched from GitHub.
- B2.5: version delta v0.2.0a → v0.2.0d confirmed.
- B3: backup at `.dtd.backup-v020a-to-v020d-<ts>/`.
- B3.5: state schema migration adds 6 Self-Update state fields with defaults.
- B4: 12 files added + 6 modified. Each verified against manifest sha256.
  Atomic temp+rename per file.
- B5: `/dtd doctor` post-migration; all NEW v0.2.0d checks PASS.
- B6: `state.md.installed_version: v0.2.0d`, `last_update_from: v0.2.0a`,
  `last_update_at: <now>`, `update_in_progress: false`.
- B7: AIMemory NOTE: `dtd_updated, from=v020a to=v020d`.

**Pass**: all B-steps execute in order; doctor PASSes; backup directory
exists for rollback safety; AIMemory event recorded.

### 89. /dtd update rolls back on manifest mismatch

**Setup**: install at v0.2.0a. Tampered MANIFEST.json (file sha mismatch
on at least one entry).

**Steps**: `/dtd update` → confirm `y`.

**Expected**:
- B1-B3 succeed.
- B4: file sha256 mismatch detected on first failing file.
- B5.5 rollback triggered:
  - Restore from `.dtd.backup-v020a-to-v020d-<ts>/`.
  - `state.md.update_in_progress: false`.
  - Append rollback note to update log.
  - Print failure: `✗ manifest mismatch on .dtd/instructions.md
    (expected sha256: abc... actual: def...). Rolled back to v0.2.0a.`
- No partial-update state remains; `.dtd/` byte-identical to pre-update.

**Pass**: rollback restores fully; no partial state; user sees clear error.

### 90. /dtd update preserves user data (workers.md / state.md customizations)

**Setup**: v0.2.0a install with customized `workers.md` (3 workers added
manually) and `state.md` (custom `host_mode: full`).

**Steps**: `/dtd update` to v0.2.0d.

**Expected**:
- `workers.md` byte-identical post-update (gitignored user file; never
  in manifest).
- `state.md` post-update: existing fields preserved (host_mode: full,
  workers, etc.); new Self-Update state fields added with defaults.
- `config.md` post-update: existing user customizations preserved; new
  update section added with defaults.
- No prompt to re-add workers; no prompt to re-set host_mode.

**Pass**: user customizations unchanged; only spec-shaped additions land.

### 91. /dtd help shows default 25-line overview

**Setup**: post-v0.2.0d install with `.dtd/help/` directory populated.

**Steps**: `/dtd help`.

**Expected**:
- Render `.dtd/help/index.md` content.
- Output ≤ 25 lines.
- Lists all 9 canonical topics (start/observe/recover/workers/stuck/update/
  plan/run/steer) with one-line description each.
- Footer: `Try: /dtd help start  or  /dtd help stuck`.
- Observational read: no state.md mutation, no notepad write, no log append.

**Pass**: output within 25-line budget; covers all canonical topics;
truly observational.

### 92. /dtd help <topic> shows ≤50-line topic detail

**Setup**: post-v0.2.0d install.

**Steps**: `/dtd help workers`.

**Expected**:
- Render `.dtd/help/workers.md` Summary + Quick examples sections.
- Output ≤ 50 lines (default; --full prints full file).
- Includes worker registry fields and naming resolution precedence.
- Footer: `Next topics: /dtd help start, /dtd help update`.
- Observational read.

**Pass**: topic file content rendered concisely; under budget; observational.

### 93. /dtd help <unknown> searches and shows top 3 matches

**Setup**: post-v0.2.0d install.

**Steps**: `/dtd help foo`.

**Expected**:
- `.dtd/help/foo.md` does not exist.
- Search across `.dtd/help/*.md` for keyword `foo` (case-insensitive).
- If matches: show top 3 candidates:
  ```
  No topic 'foo'. Did you mean:
  | <topic>    <one-line description>
  ```
- If no matches: show full topic list (same as `/dtd help` no-arg).
- Observational read.

**Pass**: graceful "did you mean" UX; never errors out; observational.

---

## v0.2.3 — Spec modularization + Lazy-load profile

### 94. .dtd/reference/ catalog exists with index + 13 topics

**Setup**: post-v0.2.3 R1 install where all reference topics are canonical
full extractions.

**Steps**: inspect `.dtd/reference/` directory.

**Expected**:
- 14 markdown files exist: index plus 13 reference topics: autonomy, incidents,
  persona-reasoning-tools, perf, workers, plan-schema,
  status-dashboard, self-update, help-system, run-loop,
  doctor-checks, roadmap, load-profile.
- Each is <= 24 KB.
- Each topic has Summary + Anchor section.
- index.md lists all 13 reference topics with one-line description and marks
  every topic `canonical`.

**Pass**: reference catalog present; lazy-load architecture verified at file
level.

### 95. /dtd help <topic> --full drills into reference (when ready)

**Setup**: post-v0.2.3 R1+ install where reference files have full
canonical content.

**Steps**:
1. `/dtd help autonomy` — shows compact summary generated from
   `.dtd/reference/index.md` plus a `--full` hint.
2. `/dtd help autonomy --full` — drills into `.dtd/reference/autonomy.md`
   for full spec extraction.

R0 correction: `autonomy` is a reference topic, not a v0.2.0d help topic.
Default `/dtd help autonomy` should render a compact summary from
`.dtd/reference/index.md` plus a `--full` hint; only `--full` loads the
reference file.

**Expected**:
- `/dtd help` (no flag) loads only `.dtd/help/<topic>.md` when present, or
  `.dtd/reference/index.md` for reference-only topics.
- `--full` flag loads `.dtd/reference/<topic>.md` (<= 24 KB).
- Neither loads `dtd.md` itself (lazy-load policy).
- Output remains observational; no state.md mutation.

**Pass**: drill-down respects lazy-load policy; only one reference
file loaded per `/dtd help <topic> --full` invocation.

### 96. Lazy-load profile resolves correctly across state transitions

**Setup**: clean install with `mode: dtd`. Run sequence:
1. No active plan: `loaded_profile: minimal` expected.
2. `/dtd plan "x"` → `plan_status: DRAFT`: profile should transition to `planning`.
3. `/dtd approve` + `/dtd run` → `plan_status: RUNNING`: profile transitions to `running`.
4. Force a blocking incident → `active_blocking_incident_id` set: profile transitions to `recovery`.
5. `/dtd incident resolve <id> retry` → blocker cleared: profile transitions back to `running`.

**Steps**: walk through the sequence. After each transition, run
`/dtd status --profile` to display current loaded_profile.

**Expected**:
- `effective_profile` is computed at per-turn protocol step 1.5 of the
  next turn (NOT mid-task).
- Mutating turns persist `state.md.loaded_profile` atomically with the
  action's normal state write. Observational reads such as
  `/dtd status --profile` display computed profile but do not write state.
- `state.md.loaded_profile_set_at` timestamps each transition.
- `state.md.loaded_profile_reason` records the trigger (e.g.
  `draft_or_approved`, `running_or_paused`, `active_blocker`,
  `pending_patch`).
- `steering.md` is not appended for profile transitions. If diagnostics are
  enabled, entries go to `.dtd/log/profile-transitions.md`.
- Doctor's `loaded_profile_drift` check passes (resolved profile
  matches state).

**Pass**: profile resolution is deterministic; transitions happen at
turn boundaries; logging is non-intrusive.

### 97. Lazy-load profile reduces controller cognitive load

**Setup**: silent run with `decision_mode: auto` (v0.2.0f). Active for
8 hours with mostly safe ready-work and no blockers. Profile stays at
`running` throughout.

**Steps**: at end of run, inspect `/dtd perf` controller usage ledger.

**Expected**:
- During `running` profile, controller does NOT process recovery-only
  sections (incident resolve commands, /dtd update flow, etc.).
- Controller usage ledger may show unchanged prompt tokens on hosts that
  still auto-load the full prompt. That is acceptable.
- Estimated benefit is reduced controller cognitive scope. Actual prompt-token
  savings are expected only when the host honors selective loading or
  `aggressive_unload`.

**Pass**: lazy-load profile reduces effective per-turn cognitive scope
without claiming token savings unless measured by `/dtd perf`.

---

## Cross-sub-release integration scenarios (v0.2 line)

These scenarios verify interactions between features that ship in DIFFERENT
v0.2 sub-releases. They cannot be tested until ALL referenced sub-releases
have shipped, but the contracts can be validated against the design proposals
today.

### 100. Silent + permission deny — auto-deny is final, never deferred (v0.2.0f + v0.2.0b)

**Setup**: silent run with `decision_mode: auto`. Permission ledger has
`deny | tool_relay_mutating | scope: run_shell pattern: "rm -rf"` (set by user pre-run). Worker emits
`::tool_request:: tool_name=run_shell args="rm -rf node_modules"`.

**Steps**:
1. `/dtd run --silent=4h --decision auto`.
2. Worker dispatch reaches the dangerous bash request.

**Expected**:
- Permission ledger resolves `deny | tool_relay_mutating | scope: run_shell pattern: "rm -rf"`.
- Action BLOCKED immediately (NOT deferred — deny is unambiguous final).
- Attempt entry: `status: blocked`, reason: `tool_relay_denied`.
- NO entry in `deferred_decision_refs` (deny doesn't defer).
- Controller continues with next ready work.
- Morning summary shows: 0 deferred, but the blocked task is in skipped list.

**Pass**: deny rules block IMMEDIATELY without going through silent defer flow,
even in auto mode. silent+auto+deny = block.

### 101. Silent + ask permission + autonomy interaction (v0.2.0f + v0.2.0b)

**Setup**: silent run with `decision_mode: auto`. Permission ledger has
`ask | tool_relay_mutating | scope: web_post` (default). Worker emits
`::tool_request:: tool_name=web_post`.

**Steps**:
1. `/dtd run --silent=4h --decision auto`.
2. Worker requests web_post relay.

**Expected**:
- Permission ledger resolves `ask`.
- Silent mode: capsule snapshotted to incident, deferred per silent algorithm.
- `deferred_decision_refs` += incident id.
- Decision capsule body preserved in incident detail file under
  `deferred_capsule:` key.
- Controller continues with next ready work.
- On `/dtd interactive`, capsule surfaces; user picks allow_once / allow_always
  / deny_once / deny_always per v0.2.0b.

**Pass**: ask permissions defer in silent (per v0.2.0f algorithm) and surface
correctly in morning summary. allow_always option correctly adds an `allow`
rule to ledger when chosen.

### 102. Snapshot + revert + permission audit (v0.2.0c + v0.2.0b)

**Setup**: completed run with snapshots (preimage mode for src/api/users.ts).
Permission ledger has `ask | revert | scope: *` (default).

**Steps**:
1. `/dtd revert task 2.1` (after run completed).
2. Permission ledger fires `PERMISSION_REQUIRED` capsule.
3. User chooses `allow_always`.
4. Revert proceeds.

**Expected**:
- Permission resolution PRECEDES revert execution (capsule fires before any
  file write).
- After user `allow_always`: ledger gains `allow | revert | scope: *`.
- Revert proceeds atomically: temp + rename per phase 1/2.
- Snapshot manifest entry for revert appended; original file's pre-snapshot
  preserved.
- `.dtd/log/permissions.md` audit row appended for the revert decision.
- `state.md.last_revert_id: snap-001-task-2.1-att-1`,
  `state.md.last_revert_at: <ts>`.

**Pass**: permission ledger gates revert correctly; audit log records the
permission resolution; revert atomically restores file content.

### 103. Loop guard + worker session resume (v0.2.1 internal)

**Setup**: RUNNING plan; worker has `supports_session_resume: true` in registry.
Worker has hit the same task with same prompt+failure twice; this is the 3rd
hit (loop_guard_threshold).

**Steps**:
1. Worker emits failure for the 3rd consecutive time with same signature.
2. Loop guard signature_count reaches threshold.
3. `loop_guard_status: hit`.

**Expected**:
- Decision capsule `LOOP_GUARD_HIT` fires.
- Loop guard interaction with resume strategy: even though worker supports
  session resume, the next attempt should NOT reuse the failed session
  (loop guard suggests fresh context). Resume strategy resolves to
  `new-worker` (skip same-worker), advancing fallback chain.
- If user picks `worker_swap` from capsule: `current_fallback_index++`,
  fresh worker context, new dispatch.
- `last_resume_strategy: new-worker`,
  `last_worker_session_id: null`.
- Loop guard resets: `signature_count: 0`, `status: idle`.

**Pass**: loop guard short-circuits the would-be `same-worker` resume; tier
escalation happens; loop signature resets after user resolution.

### 104. Self-update + state migration + locale auto-detect (v0.2.0d + v0.2.0e)

**Setup**: install at v0.2.0a tagged. User has been using `/ㄷㅌㄷ` aliases
in `steering.md` (auto-detected by migration).

**Steps**:
1. `/dtd update --dry-run` to a target release that includes both v0.2.0d
   Self-Update and v0.2.0e Locale Packs (for example, skipping from v0.2.0a
   directly to v0.2.0e or later).
2. Migration detects Korean usage; offers `Auto-enable locale pack? (y/n/skip)`.
3. User picks `y`.
4. `/dtd update` proceeds.

**Expected**:
- Pre-update backup created at `.dtd.backup-v020a-to-v020d-<ts>/`.
- State schema migration applies every delta included in the target release.
  If the target is v0.2.0d only, locale auto-detect may be reported as a
  preview but MUST NOT set `locale_active: ko` until `.dtd/locales/ko.md`
  exists in the manifest.
- Locale auto-enabled: `state.md.locale_active: ko`,
  `config.md.locale.enabled: true`, `config.md.locale.language: ko`.
- `.dtd/locales/ko.md` copied from release manifest.
- `.dtd/help/` directory installed.
- Doctor PASS post-update.
- AIMemory NOTE: `dtd_updated, from=v020a to=v020d, locale=ko (auto)`.

**Pass**: cumulative migration applies cleanly; locale pack auto-detected;
user's Korean UX is preserved post-update; doctor verification PASSes.

### 105. Tool relay + snapshot + permission (v0.2.0f + v0.2.0c + v0.2.0b)

**Setup**: APPROVED plan. Worker has `tool_runtime: controller_relay`.
Permission ledger has:
- `ask | tool_relay_read | scope: run_shell:npm-test`
- `allow | snapshot | scope: *`

Worker first emits `::tool_request:: tool_name=run_shell args="npm test"`,
then the next fresh dispatch emits `===FILE: src/api/users.ts===` as its
declared output.

**Steps**:
1. `/dtd run`.
2. Worker emits the read/verification tool request.
3. Controller runs the relay, then re-dispatches with a compact tool-log ref.
4. Worker returns a normal file block for `src/api/users.ts`.

**Expected**:
- Controller resolves `tool_relay_read ask` → fills PERMISSION_REQUIRED
  capsule.
- User picks `allow_once`.
- Controller relay executes only after permission resolves; sanitized output is
  saved to `.dtd/log/tool-001-task-2.1-1.md`.
- Next fresh worker dispatch receives only compact tool result + log ref.
- File modification still arrives through `===FILE: src/api/users.ts===`.
- Before applying that file block, controller validates output path and takes a
  snapshot per v0.2.0c rules (preimage mode for src/api/users.ts).
- Snapshot manifest entry created, then normal temp-file + atomic rename apply
  pipeline runs.

**Pass**: three-way integration (tool runtime + permission + snapshot)
correctly orders: permission first, relay execution second, snapshot before
apply, apply last.
Audit log + snapshot + tool log all populate per spec, and tool relay never
bypasses output-path validation or the apply pipeline.

### 106. Persona resolution under context_pattern + reasoning_utility (v0.2.0f internal)

**Setup**: DRAFT plan with phase 1 having
`context-pattern="explore" persona="planner" reasoning-utility="least_to_most"`.

**Steps**:
1. `/dtd plan show --full`.
2. `/dtd approve`.
3. `/dtd run` until phase 1 dispatches.

**Expected**:
- Plan XML attributes preserved.
- state.md fields after dispatch:
  - `resolved_context_pattern: explore`
  - `resolved_handoff_mode: rich` (from explore pattern config)
  - `resolved_sampling: "temp=0.6 top_p=0.95 samples=2"`
  - `resolved_controller_persona: planner` (explicit)
  - `resolved_worker_persona: planner` (defaults to same when phase says planner)
  - `resolved_reasoning_utility: least_to_most`
  - `resolved_tool_runtime: controller_relay` (default)
- Worker prompt task-specific section has compact persona/reasoning capsule:
  `controller=planner; worker=planner; stance="make dependencies and decision points explicit"; utility=least_to_most`
- ≤ 120 words for persona; reasoning utility output_contract present.

**Pass**: all 4 v0.2.0f attributes resolve correctly; worker prompt is
compact (no role-play biography); reasoning chain-of-thought NOT requested.

### 107. Notepad v2 reasoning notes + reflexion utility (v0.2.0f + v0.2.2)

**Setup**: RUNNING plan with notepad v2 schema. Phase 2 task with
`reasoning-utility="reflexion"` and a prior failed attempt.

**Steps**:
1. Worker dispatch with reflexion utility.
2. Worker fails on first attempt; controller retries.
3. After concrete failure signal (test failure / reviewer finding /
   incident), reflexion utility writes a 1-line lesson.

**Expected**:
- Reasoning Notes heading in notepad gets a new entry:
  ```
  - lesson (reflexion): <one-line learned heuristic>
    trigger: <attempt-002-task-2.1>
  ```
- ≤ 5 lines per entry (rule).
- Older Reasoning Notes entries (after 3rd entry) roll into `## learnings`
  section as one-line bullets.
- Doctor `reasoning_notes_chain_of_thought_leak` does NOT trigger
  (no narrative, no multi-paragraph blocks).

**Pass**: reflexion lesson stored compactly; old entries rolled into
learnings; chain-of-thought leak detection passes.

### 108. dtd.md modularization + /dtd help drilling (v0.2.3 + v0.2.0d)

**Setup**: post-v0.2.3 install. `/dtd help` topic system from v0.2.0d in place.
User runs `/dtd help autonomy`.

**Steps**:
1. `/dtd help autonomy`.

**Expected**:
- Controller resolves `<topic>` to `.dtd/reference/autonomy.md`.
- Loads ONLY that file (not dtd.md or other reference files).
- Renders Summary + Quick examples sections (≤ 50 lines).
- Mentions related topics (e.g., persona-reasoning-tools.md) without loading them.
- `state.md` unchanged (observational read).

**Pass**: lazy-load policy works (only one reference file loaded);
help output stays under 50 lines; user can drill via `/dtd help <other-topic>`.

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
| 22d | workers split + privacy (.env / .env.example pattern) |
| 22e | LMStudio LAN IP + Tailscale (multi-machine reach) |
| 22f | commercial OpenAI-compat API (DeepSeek) |
| 22g | tuning params merge (temperature/seed/reasoning_effort/extra_body) |
| 22h | DTD adoption on existing in-progress project (Pattern B) |
| 22i | MAX_ITERATIONS_REACHED full decision capsule (R2) |
| 22j | AUTH_FAILED durable blocker decision capsule (R2) |
| 22k | NETWORK_UNREACHABLE recovery options (R2) |
| 22l | WORKER_INACTIVE wait/cancel/switch/takeover (R2 spec, R3 full capsule example) |
| 22m | fallback chain shown in status + paid_fallback_requires_confirm (R2 + R3 config knobs) |
| 22n | /dtd run --until phase:N bounded execution + durable last_pause_boundary (R2 + R3) |
| 22o.1 | DISK_FULL during temp-write (clean abort, no final files changed) (R3 split) |
| 22o.2 | PARTIAL_APPLY during rename phase (some final files written, no auto-resume) (R3 split) |
| 22p | Worker-add wizard end-to-end with chat-safe secret flow (R3) |
| 22q | v0.2.0f: Context pattern selection + GSD-style fresh reset with durable learning |
| 22r | v0.2.0f: persona/reasoning/tool-runtime controls resolve without CoT/tool leakage |
| 23 | dashboard width/fallback (P2-10) |
| 23a | v0.2.0f: silent overnight mode defers blockers and continues safe work |
| 23b | v0.2.0f: decision mode and attention mode can change mid-run |
| 23c | v0.2.0f: silent mode handles worker/controller token exhaustion safely |
| 23d | v0.2.0f: perf report separates controller and worker token usage |
| 23e | v0.2.0f: morning summary surfaces deferred blockers in age order |
| 23f | v0.2.0f: silent_deferred_decision_limit pauses run when hit |
| 23g | v0.2.0f: CONTROLLER_TOKEN_EXHAUSTED capsule fires safely |
| 23h | v0.2.0f: status dashboard modes/ctx render rules |
| 23i | v0.2.0f: /dtd perf reads ctx data files observationally |
| 24 | v0.2.0a: blocking incident creation on network failure |
| 25 | v0.2.0a: incident resolve via decision capsule + retry |
| 26 | v0.2.0a: multi-blocker invariant — second blocker waits, oldest-promoted on resolve |
| 27 | v0.2.0a: info-severity does NOT set active_incident_id (P1-3 fix from R1) |
| 28 | v0.2.0a: doctor cross-link integrity check |
| 29 | v0.2.0a: finalize_run clears incident state on terminal exit (P1-4 R1 fix) |
| 30 | v0.2.0a: destructive incident option requires explicit confirmation (R2 P1 fix) |
| 86 | v0.2.0d: /dtd update check no-op when on latest |
| 87 | v0.2.0d: /dtd update --dry-run shows full delta + asks confirm |
| 88 | v0.2.0d: /dtd update applies; manifest verification PASSes; doctor PASS |
| 89 | v0.2.0d: /dtd update rolls back on manifest mismatch |
| 90 | v0.2.0d: /dtd update preserves user data (workers.md customizations) |
| 91 | v0.2.0d: /dtd help shows default 25-line overview |
| 92 | v0.2.0d: /dtd help <topic> shows ≤50-line topic detail |
| 93 | v0.2.0d: /dtd help <unknown> searches and shows top 3 matches |
| 94 | v0.2.3: .dtd/reference/ catalog has index + 13 topics + budget OK |
| 95 | v0.2.3: /dtd help <topic> --full drills into reference file (lazy-load) |
| 96 | v0.2.3 lazy-load profile: resolves correctly across state transitions |
| 97 | v0.2.3 lazy-load profile: reduces controller cognitive load (perf savings) |
| 100 | cross v0.2.0f+0b: silent + permission deny — auto-deny is final, never deferred |
| 101 | cross v0.2.0f+0b: silent + ask permission defers; allow_always adds ledger rule |
| 102 | cross v0.2.0c+0b: snapshot + revert + permission audit |
| 103 | cross v0.2.1: loop guard + worker session resume (skip same-worker on loop hit) |
| 104 | cross v0.2.0d+0e: self-update + state migration + locale auto-detect |
| 105 | cross v0.2.0f+0c+0b: tool relay + snapshot + permission ordering |
| 106 | cross v0.2.0f: persona + context_pattern + reasoning_utility resolution |
| 107 | cross v0.2.0f+v0.2.2: reflexion utility writes notepad v2 reasoning notes |
| 108 | cross v0.2.3+0d: modularization + /dtd help lazy-load drilling |

Controller no-self-grade gate (P1-2): exercised wherever step 4 of escalation ladder is reached (Scenario 17 covers this; specific REVIEW_REQUIRED gate is observed in phase-history.md gate column).

---

## User Journey Scenarios (planned)

The acceptance scenarios above (1-30) verify feature contracts. The journey
scenarios below verify that **a user following only README / quickstart /
help can actually complete the product flow** — without reading `dtd.md`
internals or AIMemory handoffs.

Full Setup / Steps / Expected / Pass for each planned journey lives in the
tracked file [`examples/user-journeys.md`](examples/user-journeys.md). The
table here is the index — when a sub-release ships a journey, that journey
moves from `planned` to `landed in <ver>` in `examples/user-journeys.md`,
and a corresponding row appears in the Coverage Map above.

| # | Journey | Lands in |
|---|---------|----------|
| 31 | Fresh project from docs only | **landed in v0.2.0d** |
| 32 | Existing project adoption | **landed in v0.2.0d** |
| 33 | Worker check success path | v0.2.1 (worker health check) |
| 34 | Worker check pinpoints setup failure | v0.2.1 |
| 35 | Worker check separates endpoint/auth/protocol failures | v0.2.1 |
| 36 | Run to a boundary for human review | **landed in v0.2.0d** (uses existing `/dtd run --until`) |
| 37 | Steering mid-run from natural language | **landed in v0.2.0d** (uses existing steering) |
| 38 | Incident recovery from help only | **landed in v0.2.0d** (v0.2.0a feature; help system enables) |
| 39 | Observational reads do not pollute context (status/plan/doctor/incident/help) | **landed in v0.2.0d** |
| 39b | Worker health diagnostics do not pollute context | v0.2.1 |
| 40 | Update journey after v0.2.0d | **landed in v0.2.0d** (introduces `/dtd update`) |
| 41 | Korean/mixed-language primary path | v0.2.0e (after Locale Pack split) |
| 42 | Help-only discoverability | **landed in v0.2.0d** (introduces `/dtd help` topic system) |
| 43 | Sleep-friendly autonomous overnight run | v0.2.0f (Autonomy & Attention) |

Each journey expects a fixed input doc (README / quickstart / specific help
page) and verifies the user can complete the flow without external context.
History/audit context lives in
`AIMemory/handoff_dtd-user-journey-doc-test-audit.gpt-5-codex.md`; canonical
journey content is `examples/user-journeys.md` (tracked in repo).

---

## v0.3.0c — Multi-worker consensus dispatch

### 134. Plan with consensus="3" dispatches to 3 workers in parallel into staged dirs

**Setup**: APPROVED plan with task 3.1 attribute
`consensus="3" consensus-strategy="reviewer_consensus"
consensus-reviewer="codex-review"` and
`<consensus-workers>deepseek-local, qwen-remote, claude-api</consensus-workers>`.
`task_consensus` permission rule = `allow scope: *`.

**Steps**: `/dtd run --until task:3.1`.

**Expected** (Codex P1.4 — staged outputs only):
- Step 5.5.5: consensus check; permission gate passes.
- Step 6.consensus.b: single output-path lock acquired for the
  consensus group (NOT per-worker).
- Step 6.consensus.c: 3 dispatches in parallel; each writes to
  its own staging dir
  `.dtd/tmp/consensus-001-3.1-att-1-<worker>.staged/`.
- NO worker writes directly to project files.
- Other tasks blocked from same paths until consensus completes.

**Pass**: staged isolation enforced; group lock semantics
prevent racing.

### 135. first_passing strategy: first ::done:: wins; late results never apply

**Setup**: consensus task with `consensus-strategy="first_passing"`.
3 workers dispatch. Worker A returns `::done::` at T=15s.
Workers B + C still in flight at T=15s.

**Steps**: observe controller after Worker A's response.

**Expected**:
- A's output validated, snapshot created (v0.2.0c step 6.g.0
  ONCE on winner), applied.
- Controller attempts provider-side cancel for B + C (HTTP cancel,
  stream close per provider).
- If B / C return late: marked `consensus_late_stale: true`,
  `applied: false` (Codex P1.4: late results NEVER apply).
- `attempts/run-NNN.md` shows: A `consensus_winner: true,
  applied: true`; B/C `consensus_late_stale: true,
  applied: false`.

**Pass**: late-result-never-apply invariant holds; Codex P1.4.

### 136. reviewer_consensus: reviewer must be distinct from candidates

**Setup**: plan task with
`consensus-strategy="reviewer_consensus"
consensus-reviewer="claude-api"` AND
`<consensus-workers>` includes `claude-api`.

**Steps**: `/dtd doctor` (plan-XML validation).

**Expected**:
- ERROR `plan_consensus_reviewer_in_candidate_set` (no
  self-review per Codex P1 additional).
- Plan rejected at plan-XML doctor check, not at dispatch.

**Pass**: reviewer-candidate distinction enforced at plan
validation.

### 137. vote_unanimous: 3 agreeing outputs apply; 1 disagreement fires CONSENSUS_DISAGREEMENT

**Setup**: consensus task with `consensus-strategy="vote_unanimous"`.

**Sub-A**: 3 workers all produce identical file content
(after whitespace normalization).
**Sub-B**: 3 workers produce 2 distinct file contents.

**Steps**: observe each.

**Expected**:
- Sub-A: all match; controller applies (single snapshot +
  apply per Codex P1.4).
- Sub-B: capsule
  `awaiting_user_reason: CONSENSUS_DISAGREEMENT` fires with 4
  options `[reviewer_pick, controller_pick, retry_all, stop]`,
  default `reviewer_pick`.
- All 3 attempt outputs preserved in staging dirs until user
  resolves capsule.

**Pass**: vote_unanimous applies on full match; disagreement
surfaces capsule.

### 138. CONSENSUS_PARTIAL_FAILURE: 2 of 3 succeed; user picks accept_majority

**Setup**: consensus N=3. Worker C times out
(WORKER_TIMEOUT). Workers A + B return `::done::`.

**Steps**: observe controller.

**Expected**:
- Capsule `awaiting_user_reason: CONSENSUS_PARTIAL_FAILURE`
  fires with 3 options `[accept_majority, retry_failed, stop]`,
  default `accept_majority`.
- User picks `accept_majority`: controller applies selection
  strategy on the 2 successful candidates (A + B).
- Failed C is logged; not retried.

**Pass**: partial-failure handling explicit; user picks
recovery path.

### 139. Cost confirm in assisted host mode shows N× per-worker estimate

**Setup**: `host.mode: assisted` AND
`config.consensus.consensus_confirm_each_call: true`.
Consensus N=3 task with estimated 5000 tokens per worker.

**Steps**: `/dtd run` reaches step 5.5.5.

**Expected**:
- Confirm prompt: "About to dispatch consensus task 3.1 to
  3 workers (~15000 tokens total, 3× single-worker cost).
  Proceed? (y/n)".
- User can decline; consensus aborts; no dispatch.

**Pass**: cost transparency surfaces N× multiplier; user
gates explicitly in assisted mode.

### 140. Permission `task_consensus deny` blocks consensus dispatch

**Setup**: user previously ran
`/dtd permission deny task_consensus scope: *`.
Plan has consensus task 3.1.

**Steps**: `/dtd run`.

**Expected**:
- Step 5.5.5 resolves `task_consensus` key → `deny`.
- Audit row: `auto-deny task_consensus`.
- Consensus dispatch aborted.
- Controller does NOT silently fall back to single-worker; user
  must edit plan to remove consensus or grant permission.

**Pass**: ledger gates consensus opt-in cleanly; no silent
fallback to single-worker.

### 141. Group lock prevents racing on same output paths

**Setup**: 2 plan tasks BOTH writing to `src/api/users.ts`.
- Task 3.1: `consensus="3"`.
- Task 3.2: regular single-worker.

Both tasks become ready at the same time.

**Steps**: `/dtd run`.

**Expected**:
- Task 3.1 acquires consensus group lock for `src/api/users.ts`.
- Task 3.2 BLOCKED on the lock; waits.
- Other tasks NOT writing to that path proceed normally.
- After 3.1 completes (winner applied + lock released): 3.2
  proceeds.

**Pass**: group lock semantics consistent with v0.1 §Resource
Locks; consensus group treated as one lock-holder, not N.

---

## v0.3.0d — Cross-machine session sync

### 142. Sync disabled (default backend: none)

**Setup**: fresh DTD install; default `session_sync.enabled: false`,
`backend: none`.

**Steps**: `/dtd run`. Worker dispatch happens normally.

**Expected**:
- No sync read at run start.
- No sync write at finalize_run.
- Session resume strategy resolver behaves exactly as v0.2.1 R1
  (per-machine).
- No `.dtd/session-sync.md` and no `.dtd/session-sync.encrypted`
  files created.

**Pass**: backend `none` is a strict no-op; v0.2.1 behavior
preserved.

### 143. Backend != none without encryption key fails closed

**Setup**:
- `session_sync.enabled: true`
- `backend: filesystem`
- `sync_path: /tmp/dtd-sync`
- `encryption_key_env: DTD_SESSION_SYNC_KEY` but env var **unset**.

**Steps**: `/dtd run` triggers any worker dispatch.

**Expected** (per Codex P1.6):
- ERROR `session_sync_no_encryption_key` fires.
- Sync is **disabled** for this run (NOT WARN with plaintext
  fallback).
- Controller falls back to per-machine v0.2.1 behavior.
- Dispatch proceeds normally; session not synced.

**Pass**: missing key never permits plaintext fallback; sync
silently degrades to per-machine.

### 144. Filesystem backend writes encrypted at finalize_run

**Setup**:
- `session_sync.enabled: true`, `backend: filesystem`
- `sync_path: /tmp/dtd-sync`
- `DTD_SESSION_SYNC_KEY` env var set to non-empty value.
- `repo_identity_hash` computed (assume git remote available).

**Steps**: `/dtd run` dispatches a worker that captures a
session_id; finalize_run runs.

**Expected**:
- `<sync_path>/<repo_identity_hash>/session-sync.md` written
  containing only `machine_id`, `provider`, `session_id_hash`,
  timestamps, status.
- `<sync_path>/<repo_identity_hash>/session-sync.encrypted`
  written with AES-256-GCM-encrypted raw `session_id` payload.
- Raw `session_id` value NEVER appears in `session-sync.md`,
  any log, or any committed artifact.
- `state.md.session_sync_last_write_at` updated.

**Pass**: encrypted at rest; metadata only in cleartext synced
file.

### 145. Git branch backend commits but raw id never committed

**Setup**:
- `session_sync.enabled: true`, `backend: git_branch`
- `sync_branch: dtd-session-sync`, `sync_remote: origin`
- `commit_interval_min: 15`
- `DTD_SESSION_SYNC_KEY` env var set.

**Steps**: `/dtd run`; finalize_run + commit_interval expires.

**Expected**:
- Commit on `dtd-session-sync` branch contains
  `.dtd/session-sync.md` (metadata) + `.dtd/session-sync.encrypted`
  (binary blob).
- `git log -p dtd-session-sync` for the committed file shows NO
  raw `session_id` strings — only hashes and encrypted blob.
- Push to `origin` happens; failure logged as
  `session_sync_unreachable` WARN, not ERROR.

**Pass**: synced branch contains zero plaintext session ids.

### 146. Cross-machine resume via session_id_hash match

**Setup**: 2 machines (laptop-A, desktop-B), same DTD install,
same repo (resolves to same `repo_identity_hash`).
- Machine A starts a worker session; session_id captured;
  finalize_run syncs.
- User switches to Machine B; both machines have configured
  filesystem backend pointed at the same shared folder.

**Steps**: on Machine B, `/dtd run` resumes the same plan.

**Expected**:
- Pre-dispatch step 5.5.5b reads sync ledger; finds active
  session for `(worker, provider)` from Machine A.
- v0.2.1 R1 strategy resolver hinted to use `same-worker`
  with the synced `session_id_hash`.
- Encrypted blob decrypted using `DTD_SESSION_SYNC_KEY`; raw
  `session_id` recovered for resume call.
- Dispatch uses resumed session.

**Pass**: cross-machine continuation works without losing the
session.

### 147. SESSION_CONFLICT fires on divergent hashes

**Setup**: 2 machines BOTH have active sessions for same
`(worker, provider)` tuple but different `session_id_hash` (each
started a session before the first sync).

**Steps**: 3rd machine reads sync; OR machine A reads after B
diverged.

**Expected**:
- Capsule `awaiting_user_reason: SESSION_CONFLICT` fires.
- Options `[use_local, use_remote, fresh, stop]`.
- Default `fresh`.
- Capsule fires BEFORE any same-session reuse (Codex additional
  amendment: a real conflict requires explicit user decision).
- After resolution: loser session marked `superseded` in synced
  ledger; both rows persist for audit.

**Pass**: divergent sessions never silently tie-break; user
explicitly decides.

### 148. Connectivity failure WARNs but does NOT block

**Setup**:
- `session_sync.enabled: true`, `backend: filesystem`
- `sync_path: /Volumes/Dropbox-not-mounted` (simulate unreachable)
- Encryption key set.

**Steps**: `/dtd run` reaches finalize_run; sync write attempts.

**Expected**:
- WARN `session_sync_unreachable` logged in
  `.dtd/log/run-NNN-summary.md`.
- Dispatch and finalize_run COMPLETE — sync failure is NEVER a
  blocking error (Codex additional amendment: connectivity ≠
  conflict).
- Local `.dtd/session-sync.md` still updated.
- Sync retried at next finalize_run.

**Pass**: connectivity issues degrade gracefully; never block
the run.

### 149. Repo identity tertiary fallback warns

**Setup**:
- Project has no git remote AND `state.md.project_id` is null.
- `session_sync.enabled: true`, `backend: filesystem`.

**Steps**: `/dtd doctor`.

**Expected**:
- WARN `session_sync_repo_identity_unstable` recommending the
  user set `project_id` via `/dtd update` or configure a git
  remote.
- Sync still functions (using absolute-path tertiary as
  tie-breaker), but will FAIL to match on a different machine
  whose absolute path differs.

**Pass**: tertiary fallback is allowed but flagged; user warned
that cross-machine match will not work without stable identity.

---

## v0.3.0a — Cross-run loop guard

### 126. Stable cross-run signature differs from within-run signature

**Setup**: any project. Within-run signature uses
`worker_id="qwen-local" + task_id="2.1" + prompt_hash + failure_hash`.
User aliases qwen-local → "코드워커" in workers.md before next run.

**Steps**: trigger same conceptual failure on next run after
worker_id rename.

**Expected** (per Codex P1.1):
- v0.2.1 within-run signature CHANGES (worker_id changed).
- v0.3.0a cross-run signature is STABLE (uses
  `worker_provider_model_or_capability` instead).
- Cross-run match works across the rename; within-run
  match doesn't.

**Pass**: stable cross-run signature catches patterns that
v0.2.1 misses due to user-local alias variation.

### 127. repo_identity_hash priority

**Setup**: 3 projects:
- (A) Git repo with remote `git@github.com:user/proj.git`.
- (B) No git remote; `state.md.project_id` set to UUID.
- (C) No git remote AND no project_id.

**Steps**: trigger cross-run signature in each.

**Expected**:
- (A): `repo_identity_hash` =
  `sha256(remote_url + first_commit_sha)`.
- (B): `repo_identity_hash` = `sha256(project_id_uuid)`.
- (C): `repo_identity_hash` = `sha256(absolute_path)`.
  Doctor INFO `project_id_unset_using_fallback`.

**Pass**: priority PRIMARY → SECONDARY → TERTIARY (Codex
P1.7); absolute path NEVER primary.

### 128. finalize_run step 5d capture-before-clear

**Setup**: run with within-run loop guard
`signature_count: 2` at finalize time.

**Steps**: finalize_run terminates run.

**Expected**:
- Step 5d executes BEFORE step 7 (Codex amendment: capture
  before clearing).
- Compute stable cross-run signature using last failed
  attempt's data.
- Read `.dtd/cross-run-loop-guard.md`; upsert. If new:
  append row with `run_count: 1`. If existing: increment
  `run_count` + update `last_seen`.
- `state.md.last_cross_run_finalize_at: <ts>`.
- THEN step 7 clears within-run fields.

**Pass**: signature captured BEFORE clear; cross-run ledger
gets data; doctor sees no `cross_run_finalize_capture_missed`.

### 129. LOOP_GUARD_CROSS_RUN_HIT fires after threshold runs

**Setup**: `config.cross_run_threshold: 2`. Stable signature
S1 has `run_count: 2` in
`.dtd/cross-run-loop-guard.md` (last_seen within retention).
Run 3 dispatching same task; current attempt produces S1.

**Steps**: observe controller after current attempt fails.

**Expected**:
- S1 matches; `run_count = 2 >= cross_run_threshold`.
- Capsule `LOOP_GUARD_CROSS_RUN_HIT` fires with 5 options:
  `[ask_user, swap_to_specific, controller, prune_signature, stop]`.
- `decision_default: ask_user`.
- `state.md.pending_cross_run_signature: S1`.
- Compact `/dtd status --full` shows hit + short hint
  (Codex P1 additional).

**Pass**: cross-run threshold + capsule semantics work.

### 130. prune_signature appends tombstone (Codex P1 additional)

**Setup**: capsule `LOOP_GUARD_CROSS_RUN_HIT` active for
signature S1.

**Steps**: user picks `prune_signature` option.

**Expected**:
- Tombstone row appended to `## Tombstones` with
  `revoked: <ts>` reference to S1.
- Original S1 row in `## Active signatures` REMAINS (audit
  trail per v0.2.0b style).
- Resolution algorithm treats S1 as inactive (tombstones-first
  per amended algorithm).
- Future runs producing S1 treated as fresh patterns.

**Pass**: prune is non-destructive; resolution treats it as
inactive.

### 131. Retention auto-prune at finalize_run

**Setup**: 5 stable signatures. 2 have `last_seen` older than
`config.cross_run_retention_days: 30`. Run finalize_run.

**Steps**: observe step 5d output.

**Expected**:
- 2 retention-expired signatures get tombstone rows.
- 3 within-retention untouched.
- Doctor reports `cross_run_signature_expired_unpruned: 0`.

**Pass**: retention auto-prune keeps ledger bounded.

### 132. /dtd loop-guard show compact display

**Setup**: 4 active signatures + 2 tombstones. Recent run
hit cross-run threshold for S1.

**Steps**: `/dtd loop-guard show` (compact, default).

**Expected**:
- Output shows ONLY the active cross-run hit (S1) + short
  hint (Codex P1 additional).
- Tombstoned rows NOT shown by default.
- All 4 active + 2 tombstones shown when
  `/dtd loop-guard show --full`.

**Pass**: compact default; full ledger behind --full flag.

### 133. /dtd loop-guard prune --before <date> bulk tombstone

**Setup**: 10 active signatures with various last_seen dates.
6 are older than 2026-04-01.

**Steps**: `/dtd loop-guard prune --before 2026-04-01`.

**Expected**:
- 6 tombstone rows appended.
- 4 newer signatures untouched.
- Audit trail preserved (originals + tombstones).
- Resolution treats the 6 as inactive.

**Pass**: bulk prune is non-destructive; tombstones reference
originals.

---

## v0.3.0b — Token-rate-aware scheduling

### 118. /dtd workers test --quota shows accurate remaining

**Setup**: registry with `claude-api` (daily_token_quota: 50000,
49500 used today) and `qwen-remote` (no quota set).

**Steps**: `/dtd workers test --quota`.

**Expected**:
- Output table shows per-worker daily + monthly columns:
  - `claude-api`: `49500/50000 (99%)` daily.
  - `qwen-remote`: `--` (no quota set).
- Predictive routing summary lists each worker's status for
  next typical task estimate.
- `state.md` NOT mutated (observational read).
- `.dtd/log/worker-usage-run-NNN.md` may be empty if no
  prior dispatches.

**Pass**: per-worker quota status accurate; no state mutation;
`--quota` is purely observational.

### 119. Predictive routing skips worker at >95% quota

**Setup**: `claude-api` 99% used. APPROVED plan task 2.1
assigned to `claude-api`. Fallback chain:
`claude-api → deepseek-local`.

**Steps**: `/dtd run`.

**Expected**:
- Step 5.5.0: predictive check sees `claude-api` over
  `quota_block_threshold_pct: 95`.
- Routes to `deepseek-local` per fallback chain.
- Permission gate (step 5.5) runs on `deepseek-local`.
- Dispatch proceeds with `deepseek-local`.
- `attempts/run-NNN.md` row notes
  `routed_from: claude-api (quota_predictive)`.

**Pass**: predictive routing happens BEFORE permission gate;
fallback chain advances cleanly.

### 120. WORKER_QUOTA_EXHAUSTED_PREDICTED fires when all near-empty

**Setup**: ALL workers in fallback chain are above
`quota_block_threshold_pct: 95`.

**Steps**: `/dtd run`.

**Expected**:
- Capsule `awaiting_user_reason: WORKER_QUOTA_EXHAUSTED_PREDICTED`
  fires with 5 options:
  `[extend_quota, switch_to_paid, continue_unsafe, pause_overnight, stop]`.
- `decision_default: pause_overnight`.
- `pause_overnight` prompt shows EXACT local reset time +
  timezone (e.g.
  "until 2026-05-06 00:00 KST [Asia/Seoul]").
- `state.md.pending_quota_capsule: <fields>`.

**Pass**: capsule fires only when entire chain is exhausted;
local reset time is unambiguous.

### 121. Paid fallback in silent mode defers (Codex P1.3)

**Setup**: `attention_mode: silent`. `claude-api` (free) at
99% used. `gpt-4-paid` (paid) is fallback. User has no
explicit `allow task scope: paid_fallback` rule.
`config.quota.quota_paid_fallback_silent_defer: true` (default).

**Steps**: `/dtd run` mid-silent-window.

**Expected**:
- Predictive check identifies paid_fallback as the next chain
  step.
- Per silent + no-explicit-allow rule: defer the
  `WORKER_QUOTA_EXHAUSTED_PREDICTED` capsule.
- `deferred_decision_refs` gains entry.
- Controller continues with independent non-paid ready work
  per silent algorithm.

**Pass**: silent mode never auto-routes to paid worker without
explicit user authorization (Codex P1.3).

### 122. Provider rate-limit headers captured advisory-only

**Setup**: `claude-api` configured with
`quota_provider_header_prefix: "x-ratelimit-"`. Dispatch
returns response with header
`x-ratelimit-remaining-tokens: 87600`.

**Steps**: post-dispatch.

**Expected**:
- `.dtd/log/worker-usage-run-NNN.md` row populates
  `provider_remaining: 87600`, `source: provider_header`.
- No raw token values logged.
- No auth header content logged.

**Pass**: header capture is advisory + redacted.

### 123. Cross-run quota persistence (when enabled) carries forward

**Setup**: `config.quota.cross_run_quota_persist: true`. Run 1
uses 12000 tokens of `claude-api`. Run 1 finalizes.

**Steps**: start Run 2. `/dtd workers test --quota` early in
Run 2.

**Expected**:
- `.dtd/log/worker-quota-tracker.md` shows `claude-api` daily
  row updated by Run 1's finalize_run.
- `/dtd workers test --quota` reflects 12000 tokens used
  carrying over from Run 1.
- Predictive routing uses cross-run total.

**Pass**: cross-run quota tracking is opt-in but works
end-to-end when enabled.

### 124. Daily quota reset at quota_reset_local_time boundary

**Setup**: `claude-api` `quota_reset_local_time: "00:00"`.
Local timezone Asia/Seoul. Run 1 ends at 23:55 KST with
40000 used. Run 2 starts at 00:05 KST next day.

**Steps**: Run 2 `/dtd workers test --quota`.

**Expected**:
- Per-day reset boundary detected (00:00 KST crossed).
- Old day row archived to `.dtd/runs/`.
- Run 2's daily counter starts at 0.
- `state.md.last_quota_reset_local_at: <ts>`,
  `last_quota_reset_tz: Asia/Seoul`.

**Pass**: daily reset is timezone-aware; archive preserves
audit; new day starts clean.

### 125. workers.example.md ships nullable quota defaults (Codex P1)

**Setup**: fresh install.

**Steps**: read `.dtd/workers.example.md`.

**Expected**:
- 6 quota fields present with `null` / default values:
  - `daily_token_quota: null`
  - `monthly_token_quota: null`
  - `quota_safety_margin: 1.5`
  - `quota_reset_local_time: "00:00"`
  - `quota_reset_window_days: 30`
  - `quota_provider_header_prefix: null`
- Fresh installs ship with no quota tracking until user
  declares a quota in their local `workers.md`.

**Pass**: example file is the schema reference; user-specific
values stay local.

---

## v0.3.0e — Time-limited permissions UX

### 109. /dtd permission allow ... for 1h sets resolved_until = now + 1h

**Setup**: fresh install. `permissions.md ## Active rules` empty.

**Steps**: `/dtd permission allow edit scope: src/** for 1h`.

**Expected**:
- Append row to `## Active rules` with `until: +1h`,
  `resolved_until: <now+1h ISO ts>`, `resolved_until_tz: UTC`,
  `by: user`.
- `state.md.active_time_limited_rule_count: 1`.

**Pass**: duration syntax parses; resolved_until populated;
state count incremented.

### 110. /dtd permission allow ... for run expires at finalize_run

**Setup**: fresh install.

**Steps**:
1. `/dtd permission allow bash scope: npm test for run`.
2. Run a plan to completion (any
   COMPLETED/STOPPED/FAILED terminal).

**Expected**:
- Step 1: row written with `until: for run`,
  `resolved_until: run_end`, `resolved_until_tz: UTC`.
- Step 2 finalize_run step 5c: tombstone row appended
  `<ts> | revoke | bash | scope: npm test | by:
  finalize_run_run_end (revokes <orig ts> row)`.
- `state.md.last_permission_prune_at: <ts>`.
- Original allow row preserved (audit trail).

**Pass**: run-end sentinel cleared by step 5c; tombstone is
non-destructive.

### 111. /dtd permission allow ... until eod resolves to today 23:59:59 local

**Setup**: fresh install. Local timezone: Asia/Seoul (UTC+9).
Current time: 2026-05-05 18:30 KST.

**Steps**: `/dtd permission allow edit scope: docs/** until eod`.

**Expected**:
- `until: eod`,
  `resolved_until: 2026-05-05T23:59:59+09:00`,
  `resolved_until_tz: Asia/Seoul`.

**Pass**: eod resolves to local 23:59:59 with timezone tag.

### 112. /dtd permission allow ... until next-monday resolves to next Monday 00:00 local

**Setup**: today is Wednesday 2026-05-06. Local: Asia/Seoul.

**Steps**: `/dtd permission allow edit scope: docs/** until next-monday`.

**Expected**:
- `until: next-monday`,
  `resolved_until: 2026-05-11T00:00:00+09:00` (Mon),
  `resolved_until_tz: Asia/Seoul`.

**Pass**: next-monday resolves to next Monday 00:00 local +
timezone.

### 113. Time-limited rule expires mid-run; next resolution falls through to default

**Setup**: `permissions.md` has
`allow edit scope: src/** until: +5m | resolved_until: <now+5m>`.
Plan running. 6 minutes pass.

**Steps**: trigger an edit at 6 minutes (after expiry).

**Expected**:
- Resolution algorithm reads rule; `resolved_until` < now;
  rule treated as inactive; falls through to default
  `ask edit scope: *`.
- Capsule `awaiting_user_reason: PERMISSION_REQUIRED` fires.
- Doctor INFO `permission_rule_expired` lists the rule.

**Pass**: time-of-check expiry; default-rule fallback works.

### 114. /dtd status --full shows perms line with countdown

**Setup**: 2 active time-limited rules:
- `allow edit src/** for 1h` (45m left).
- `allow bash npm test until eod` (eod in 5h).

**Steps**: `/dtd status --full`.

**Expected**:
- New line in `--full` rendering:
  `| perms      2 time-limited rules: edit src/** (45m left), bash npm test (eod)`.
- Total line width ≤ 80; if overflow, drop count tag and
  surface only the most-restrictive rule.

**Pass**: countdown displayed; format respects width budget.

### 115. /dtd permission allow ... for "1h30m" rejected at parse time

**Setup**: any state.

**Steps**: `/dtd permission allow edit scope: src/** for 1h30m`.

**Expected**:
- Parser rejects with error
  `permission_duration_combined_unsupported_v030e`.
- Hint: "Use `for 90m` instead. Combined units deferred to
  v0.3.x."
- No row written to `## Active rules`.

**Pass**: combined-unit syntax rejected with clear hint.

### 116. /dtd permission allow ... for 1h until eod rejected at parse time

**Setup**: any state.

**Steps**: `/dtd permission allow edit scope: src/** for 1h until eod`.

**Expected**:
- Parser rejects with error
  `permission_duration_until_mixed_unsupported`.
- Hint: "Pick one: `for 1h` OR `until eod`, not both."
- No row written.

**Pass**: mixed for/until rejected; clear hint.

### 117. finalize_run step 5c tombstones all run-end-scoped rules

**Setup**: 5 active rules:
- 2 with `resolved_until: run_end` (for run).
- 1 with `resolved_until: <past ISO ts>` (TTL expired).
- 2 with `resolved_until: <future ISO ts>` (still valid).

**Steps**: run a plan to COMPLETED.

**Expected** at step 5c:
- 3 tombstones appended:
  - 2 with `by: finalize_run_run_end`.
  - 1 with `by: finalize_run_ttl_expired`.
- 2 future-ts rules untouched.
- `state.md.active_time_limited_rule_count: 2`
  (post-prune count of remaining time-limited rules).
- `state.md.last_permission_prune_at: <ts>`.

**Pass**: step 5c distinguishes run_end vs TTL-expired
tombstones; future-ts rules survive; count accurate.

---

## Running

These scenarios are not auto-runnable in v0.1 (markdown-only, no test harness). Manual or semi-manual run by:
- a developer doing acceptance review before tagging v0.1
- Codex doing post-author review
- a user kicking the tires after install

For each scenario: walk through Steps, verify Pass criteria, mark ✓/✗.
