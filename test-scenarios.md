# DTD v0.1 Test Scenarios

> 46 acceptance scenarios for v0.1 + v0.1.1 + v0.2.0a. Not auto-runnable — these are
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

### 26. Multi-blocker policy: second blocker waits in queue

**Setup**: scenario 24 state (one active blocker). Force a second blocking failure (e.g., simulate disk-full during apply on a different task).
**Steps**: `/dtd run` — would dispatch task 2.2 (different task, different incident path), simulate DISK_FULL.
**Expected**: Multi-blocker invariant — only ONE active_blocking_incident_id at a time:
1. Second incident created with status=open, severity=blocked, but `active_blocking_incident_id` is NOT updated (first incident still active)
2. `last_incident_id` updates to second incident's id
3. `incident_count: 2`
4. `recent_incident_summary` includes both
5. Decision capsule still references first incident
6. After user resolves first via `/dtd incident resolve`, controller promotes second blocker (oldest unresolved blocking incident) — `active_blocking_incident_id` set to second's id, decision capsule refilled with its options
**Pass**: invariant maintained; promotion happens on first resolution.

### 27. Info-severity incident does NOT set active_incident_id

**Setup**: any state. Force an info-severity event (e.g., a 1st-hit RATE_LIMIT that's about to retry — recoverable, just notable).
**Steps**: dispatch encounters 429, retries (recoverable, not blocking). Controller logs an info incident.
**Expected**:
1. `.dtd/log/incidents/inc-001-0003.md` created with severity=info
2. state.md: `last_incident_id: inc-001-0003`, `incident_count: 3` (cumulative)
3. state.md: `active_incident_id` REMAINS null (info doesn't set it — P1-3 fix from v0.2 design R1)
4. state.md: `active_blocking_incident_id` REMAINS null
5. Decision capsule UNCHANGED (no awaiting_user_decision)
6. `/dtd run` continues; retry succeeds
7. Compact `/dtd status` does NOT show this incident (info hidden); `--full` does show in `recent_incident_summary`
**Pass**: severity → state mapping correct; non-blocking incidents don't gate run.

### 28. Doctor verifies incident cross-link integrity

**Setup**: scenario 26 state. Manually corrupt `.dtd/attempts/run-001.md` — remove the `incident:` cross-link from a failed attempt.
**Steps**: `/dtd doctor`.
**Expected**:
1. WARN `attempt_incident_link_missing` with attempt id and incident id pointer
2. Other incident-state checks PASS (state fields valid, no multi-blocker violation, no secret leak)
3. Doctor does NOT auto-fix; recommends manual restoration or treating as superseded
**Pass**: incident state checks per dtd.md doctor §Incident state are exercised; corruption surfaced as WARN; clean state passes silently.

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
| 23 | dashboard width/fallback (P2-10) |
| 24 | v0.2.0a: blocking incident creation on network failure |
| 25 | v0.2.0a: incident resolve via decision capsule + retry |
| 26 | v0.2.0a: multi-blocker invariant — second blocker waits, oldest-promoted on resolve |
| 27 | v0.2.0a: info-severity does NOT set active_incident_id (P1-3 fix from R1) |
| 28 | v0.2.0a: doctor cross-link integrity check |

Controller no-self-grade gate (P1-2): exercised wherever step 4 of escalation ladder is reached (Scenario 17 covers this; specific REVIEW_REQUIRED gate is observed in phase-history.md gate column).

---

## Running

These scenarios are not auto-runnable in v0.1 (markdown-only, no test harness). Manual or semi-manual run by:
- a developer doing acceptance review before tagging v0.1
- Codex doing post-author review
- a user kicking the tires after install

For each scenario: walk through Steps, verify Pass criteria, mark ✓/✗.
