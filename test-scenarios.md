# DTD v0.1 Test Scenarios

> 77 acceptance scenarios (68 single-feature + 9 cross-sub-release integration) for v0.1 + v0.1.1 + v0.2.0a (TAGGED) + v0.2.0d (R0 implementation) + v0.2.0f/0e/0b/0c/0.2.1/0.2.2/0.2.3 (planned). Not auto-runnable — these are
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

## Running

These scenarios are not auto-runnable in v0.1 (markdown-only, no test harness). Manual or semi-manual run by:
- a developer doing acceptance review before tagging v0.1
- Codex doing post-author review
- a user kicking the tires after install

For each scenario: walk through Steps, verify Pass criteria, mark ✓/✗.
