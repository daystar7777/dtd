# DTD (Do Till Done) — Slash Command Spec

This file IS the canonical behavior spec for `/dtd` and the natural-language
equivalents. When DTD mode is ON, the controller LLM follows these rules
verbatim. When DTD mode is OFF, the host operates normally.

NL routing and state-aware decisions live in `.dtd/instructions.md`.
This file defines **what each canonical action does**.

---

## Modes

DTD has two activation states:

- **`mode: off`** — host LLM operates as usual; `/dtd` only runs informational subcommands (`status`, `doctor`, `mode on`).
- **`mode: dtd`** — host becomes the controller; reads `.dtd/instructions.md` on every turn; orchestrates worker dispatch per the plan state machine.

Mode is stored in `.dtd/state.md` (`mode:` field). Toggle with `/dtd mode on|off`.

---

## Canonical Actions

All commands accept both slash form (`/dtd <action>`) and natural-language form (per `.dtd/instructions.md`).

### `/dtd setup`

First-time install (run once). See `prompt.md` for full bootstrap.
Subsequent runs verify and offer upgrade — never destructive.

### `/dtd doctor`

Health check. Output uses the same Unicode/ASCII style as `/dtd status`. Reports:

**Install integrity**:
- DTD install: all 15 `.dtd/` committed template files + `dtd.md` present.
  Committed templates: `instructions.md`, `config.md`, **`workers.example.md`** (schema reference; `workers.md` is a generated, gitignored local registry — see Worker Registry checks below), `worker-system.md`, `resources.md`, `state.md`, `steering.md`, `phase-history.md`, `PROJECT.md`, `notepad.md`, `.gitignore`, `.env.example`, plus 3 `skills/*.md`.
- Local registry: `.dtd/workers.md` exists (created from `workers.example.md` at install if missing; gitignored).
- Host always-read pointer: present and references `.dtd/instructions.md`
- `dtd.md` present at host slash command dir (Claude Code: `.claude/commands/dtd.md`, etc.)

**Mode consistency**:
- `.dtd/state.md` has `mode: off|dtd` (DTD activation, separate from host capability)
- `.dtd/state.md` has valid `host_mode: plan-only|assisted|full`
- `.dtd/config.md` `host.mode` matches `state.md host_mode`
- Probed capabilities currently match the recorded `host_mode` (re-detect available)

**Worker registry**:
- `.dtd/workers.example.md` exists (committed schema reference)
- `.dtd/workers.md` exists locally (gitignored user registry; if missing → ERROR with hint: `cp .dtd/workers.example.md .dtd/workers.md` or rerun install)
- `workers.md` parses; only H2 sections under "## Active registry" heading count as registry
- Disabled (`enabled: false`) entries reported but skipped in routing
- Alias collisions: worker alias vs other worker, alias vs role, alias/display_name vs `controller.name`
- Reserved word usage rejected (`controller, user, worker, self, all, any, none, default`)
- Threshold consistency: `failure_threshold` is positive int per worker
- `escalate_to` chain: no cycles, terminates at `user`
- Capabilities reasonable: at least one worker for each role declared in `config.md` `roles`
- Endpoint URL sanity: not literally `localhost` if user expects multi-machine access (INFO, suggest LAN IP / Tailscale — see workers.example.md)
- If active registry empty: WARN, recommend `/dtd workers add` or paste from `workers.example.md`

**agent-work-mem**:
- Detected (`AIMemory/PROTOCOL.md` + `INDEX.md` + `work.log` all exist) → INFO "integrated"
- Absent → INFO "not installed; recommended for multi-session continuity" (do NOT block)

**Project context**:
- `.dtd/PROJECT.md` is not pure-TODO: parse for `(TODO:`. If TODO-only AND `host_mode` is `assisted` or `full`: WARN
- `.dtd/PROJECT.md` size ≤ 8 KB: ERROR if larger (capsule too big for prompt prefix)

**Resource state**:
- Stale leases in `resources.md` (heartbeat_at older than `stale_threshold` minutes): WARN per stale lease, suggest `--takeover` after user confirm
- Orphaned lock dropfiles (e.g. leftover `.dtd/.dtd.lock`): WARN

**Plan state**:
- `state.md` `plan_status` matches plan file existence and content
- Active plan size ≤ 24 KB hard cap (12 KB preferred): WARN if over preferred, ERROR if over hard
- `pending_patch: true` consistency with `<patches>` section in plan-NNN.md
- No orphan WORK_START in AIMemory without matching state in `.dtd/state.md`

**Incident state** (v0.2.0a):
- If `active_incident_id` is non-null, corresponding `.dtd/log/incidents/inc-*.md` file MUST exist; ELSE ERROR `incident_file_missing`
- `active_blocking_incident_id` (if non-null) MUST equal an open blocking-severity incident; ELSE ERROR `blocking_incident_invalid`
- At most ONE `active_blocking_incident_id` at a time (multi-blocker invariant); ELSE ERROR `multi_blocker_invariant_violated`
- All failed/blocked attempts in `.dtd/attempts/run-NNN.md` MUST cross-link to a valid incident id; ELSE WARN `attempt_incident_link_missing`
- All open incidents MUST have valid `recoverable` (`yes|user|no`) and `side_effects` (`none|request_saved|response_saved|partial_apply|unknown`); ELSE ERROR `incident_field_invalid`
- Incident detail files in `.dtd/log/incidents/` should not contain secret patterns (regex scan); ELSE ERROR `incident_secret_leak`
- Total open-incident count > 100 → INFO suggesting `/dtd incident list --all` review or v0.3 prune command (deferred)

**Path policy**:
- Scan plan files for `..` paths: WARN, recommend absolute form
- BLOCK pattern hits in plans: ERROR with line ref
- relative/absolute classification: each path correctly classified

**`.gitignore`**:
- `.dtd/.gitignore` exists and covers `.env`, `tmp/`, `log/`, `eval/`: ERROR if missing
- Project-root `.gitignore` coverage: INFO only (does not block)
- Secret leak: regex scan of `.dtd/log/`, `.dtd/state.md`, `AIMemory/work.log` (if present) for known key patterns:
  - `sk-[A-Za-z0-9]{32,}` (OpenAI)
  - `sk-ant-[A-Za-z0-9_-]{40,}` (Anthropic)
  - `sk-or-v1-[A-Za-z0-9_-]{40,}` (OpenRouter)
  - `AIza[0-9A-Za-z_-]{35}` (Google)
  - `ghp_[A-Za-z0-9]{36}` (GitHub PAT)
  - `hf_[A-Za-z0-9]{30,}` (Hugging Face)
  - `Bearer\s+[A-Za-z0-9_-]{20,}`
  - generic long token-like values within 50 chars of `api_key`/`token`/`secret`/`authorization`
- agent-work-mem detection: report `present|absent`; if absent, recommend (do not block)
- `.gitignore` content: `.env`, `.dtd/tmp/`, `.dtd/log/` recommended

Exit code on slash hosts: 0 if all checks pass, 1 if any ERROR-level issue.

### `/dtd uninstall [--soft|--hard|--purge]`

Three-tier removal. Default is `--soft` (least destructive). Each tier is a strict superset of the prior in destructiveness.

**`--soft`** (default):
1. Set `state.md` `mode: off` (DTD activation off, host_mode preserved).
2. Keep all `.dtd/` content intact.
3. Optionally remove DTD pointer block from host always-read file (ask user).
4. Slash command file remains.
5. Plans, history, steering, eval all preserved.

→ Reversible: `/dtd mode on` reactivates without re-install.

**`--hard`**:
1. Set `state.md` `mode: off`.
2. Remove DTD pointer block from host always-read file.
3. Move `.dtd/` to `.dtd.uninstalled-YYYYMMDD-HHMM/` (timestamped backup at project root).
4. **Add `.dtd.uninstalled-*/` pattern to project-root `.gitignore`** (with user confirm). Reason: `.dtd/.gitignore` cannot reach the project-root backup path; without root coverage the backup becomes git-visible. If user declines: WARN that backup may be tracked by git.
5. Remove `dtd.md` from project root and host slash command directory.
6. If install added entries to project-root `.gitignore` (only if user opted in at install), remove only those install-added entries (preserve user's other entries).
7. **Never touch `AIMemory/`**.

**`--purge`** (destructive, requires explicit `y`):
1. Everything `--hard` does.
2. Plus: delete the `.dtd.uninstalled-*` backup folder.
3. **Never touch `AIMemory/`** unless user separately requests it.

Common gates (all variants):
- If `state.md` shows `plan_status: RUNNING` or `pending_patch: true`, abort uninstall and tell user to `/dtd stop` first.
- AIMemory is sacred: even `--purge` does not touch it. If user wants AIMemory removed, that's a separate `agent-work-mem` operation.

### `/dtd mode on|off`

Toggle. Updates `state.md` `mode` field. On `off`: in-flight tasks finish, no new tasks dispatched. On `on`: load `.dtd/instructions.md` on next turn.

### `/dtd workers [list|add|test|rm|alias|role]`

Worker registry management. Backed by `.dtd/workers.md`.

- `list` (default if no arg): table of registered workers with id, aliases, tier, capabilities, cost_tier, current health
- `add`: **thin conversational wizard** — asks one field at a time, redacts secrets, writes to `.dtd/workers.md` (gitignored) and optionally `.env`:

  1. **Alias hint**: if user said "qwen 워커 추가해줘", controller pre-fills `worker_id: qwen-local` and `aliases: qwen`. User can override.
  2. **Endpoint** — controller suggests common cases based on alias hint (e.g., qwen → `http://localhost:1234/v1/chat/completions` (LMStudio default)). Asks once.
  3. **Model** — suggests common ids per provider hint (e.g., DeepSeek → `deepseek-v4-pro`).
  4. **api_key_env** — env var **name** only. Suggests `<ID_UPPER>_API_KEY` (e.g., `QWEN_API_KEY`). This is the only secret-related field collected through chat.
  5. **API key value** — by default, NOT collected through chat (a chat host conversation is not a secure secret-input channel; the value would persist in the controller's transcript). Instead, the wizard tells the user:

     ```
     Set the key value yourself:

     POSIX (bash/zsh):  echo 'QWEN_API_KEY=<your-key-here>' >> .dtd/.env
     Windows (PowerShell): Add-Content -Path .dtd/.env -Value 'QWEN_API_KEY=<your-key-here>'

     Or if you already have QWEN_API_KEY set in your shell environment, leave .dtd/.env empty for that key — DTD will use the shell value.

     When done, run /dtd workers test <id> to verify.
     ```

     The wizard then proceeds to step 6 without ever seeing the secret. Confirmation of "key is set" is non-secret metadata only (e.g., "I've set it" / "skip"). NEVER echo length, prefix, suffix, fingerprint, or any other secret-derived info — those are still secret material in the chat.

     Only if the host explicitly provides a secure-input channel (a tool UI prompt that bypasses the LLM conversation), wizard MAY accept the key value through that channel and write it directly to `.dtd/.env`. v0.1.1 hosts (chat-only) follow the user-sets-it path above.
  6. **max_context** — suggests provider default (32000 / 64000 / 128000 / 200000 depending on model hint).
  7. **capabilities** — suggests based on phrasing (qwen/deepseek-coder → `code-write, code-refactor`).
  8. **permission_profile** — defaults to `code-write`. Asks user to confirm or pick `explore | review | planning | code-write`.
  9. **Test now?** — offers to run `/dtd workers test <id>` immediately. If test fails (network/auth), creates a `WORKER_INACTIVE` or `AUTH_FAILED` decision capsule for the worker config (not for an active task).

  **Secret handling rules**:
  - API key value (raw) NEVER enters chat conversation. v0.1.1 wizard does NOT prompt for it.
  - User sets `.dtd/.env` themselves (POSIX/PowerShell snippet provided in step 5).
  - NEVER echo any secret-derived info — no length, no prefix/suffix, no fingerprint, nothing the user provided as secret.
  - `workers.md` only ever holds `api_key_env: <NAME>`. `.dtd/.env` is the canonical secret file path (NOT plain `.env`).
  - If the host provides a secure-input channel out-of-band of the chat conversation, wizard MAY use that path to write `.dtd/.env` directly. v0.1.1 chat hosts follow the user-sets-it path.

  **Apply step**: before writing, shows summary (no secret-derived info — wizard never saw a value):
  ```
  About to add worker:
    id: qwen-local
    endpoint: http://localhost:1234/v1/chat/completions
    model: qwen2.5-coder:32b
    api_key_env: QWEN_API_KEY
    api_key_value: not collected (set .dtd/.env or shell env)
    max_context: 32768
    capabilities: code-write, code-refactor
    permission_profile: code-write
  Apply? yes | edit <field> | cancel
  ```
  Only on `yes` does controller append to `workers.md`. The wizard does NOT write `.dtd/.env` in v0.1.1 (chat-host hosts) — user sets the value out-of-band per step 5.

  **Wizard isolation**: wizard turns are setup-context, not run-context. Don't mutate notepad/steering/attempts/phase-history. Don't include wizard Q/A in future worker prompts.
- `test <id>`: send a no-op probe (echo prompt) to that worker, report latency + auth status
- `rm <id>`: remove (warn if any plan references this worker; offer to remap)
- `alias add <id> <alias>` / `alias rm <id> <alias>`: manage aliases
- `role set <role> <id>` / `role unset <role>`: manage role mapping in `config.md`

NL equivalents: see `instructions.md`.

### `/dtd plan <goal>`

Generate a new plan from a goal. Sequence:

1. If `state.md` shows existing `active_plan` with `plan_status: DRAFT`: ask user whether to discard and start fresh, or refine.
2. If `plan_status` is `RUNNING`/`PAUSED`, OR if `pending_patch: true` (any state): refuse — finish, stop, or resolve the patch first.
3. Create `.dtd/plan-NNN.md` (next number) with:
   - `<plan-status>DRAFT</plan-status>`
   - `<brief>` section (≤ 2 KB) — human-readable goal/approach summary
   - phases 1..N with tasks (XML schema below)
   - per-task `<worker>` resolved from explicit user request, role mapping, capability matching, or priority — whichever applies
   - per-task `<work-paths>` and `<output-paths>` (predicted)
4. Update `state.md`: `active_plan: NNN`, `plan_status: DRAFT`, `pending_patch: false`.
5. Display the plan via `/dtd plan show` rendering.
6. Stop. Wait for `/dtd approve` or further edits.

### `/dtd plan show [--task N|--phase N|--brief|--patches|--workers|--paths]`

Render the active plan. Uses the **same ASCII/Unicode style switch as `/dtd status`** (`config.dashboard_style`, default `ascii`). Default ASCII output:

```
+ plan-001 [<plan_status>] (+ patch pending: <impact>)
| goal: <one-line from <brief>>
+ tasks
| Task | Goal             | Worker     | Work paths       | Output paths       | Assigned via
| 1.1  | schema 작성      | qwen       | docs/,src/types/ | docs/schema.md     | role:planner
| 2.1  | API endpoints    | deepseek   | src/api/**       | src/api/**         | capability:code-write
| 4.1  | 코드 리뷰        | codex      | src/api/+src/ui/ | docs/review-001.md | role:reviewer
+ phases
| phase 1: planning  workers: qwen       touches: docs/, src/types/
| phase 2: backend   workers: deepseek   touches: src/api/**
| phase 3: review    workers: codex      reads src/api/+src/ui/  writes docs/review-001.md
```

If `dashboard_style: unicode` is set AND terminal can render box-drawing chars,
the renderer can substitute `┌`, `│`, `├`, `└` per the glyph reference in §Status Dashboard. Same fallback rule applies.

Truncate long path lists with `(+N more)`. Use first alias if `display_worker_format: alias`.

Flags select sections: `--brief` shows just the brief, `--workers` just the worker table, `--paths` just paths summary, etc.

### `/dtd plan worker <task_id|phase:N|all> <worker>`

Swap worker assignment in DRAFT only. Validation:

- Worker exists (or alias/role resolves) → else error + suggest candidates
- Capability mismatch → soft warn + confirm; if accepted, plan gets `<worker-mismatch>` annotation
- Parallel-group duplicate (same worker on `parallel-group="A"` siblings) → info + offer to break parallelism
- Tier 1 overload (single tier-1 worker on many tasks) → advisory

In APPROVED/RUNNING/PAUSED states, this command is **blocked** — use steering (medium impact patch) instead. The NL form `"task 3은 큐엔으로"` routes through `/dtd steer` automatically when not DRAFT.

After swap, `<worker-resolved-from>` is updated to `user-override (was: <previous>)`.

### `/dtd approve`

DRAFT → APPROVED. Validations:

- `plan_status` must be DRAFT
- Plan size: `plan-NNN.md` ≤ 24 KB hard cap (≤ 12 KB preferred — warn if over)
- All tasks have a resolved `<worker>` (no unresolved role/alias)
- All workers in plan exist in `workers.md`
- No path overlap warnings unaddressed

After approve, plan is locked in: further changes require steering.

### `/dtd run [--until <boundary>]`

Execute the plan. Allowed when:

- `plan_status: APPROVED` AND `pending_patch: false` → start RUNNING
- `plan_status: PAUSED` AND `pending_patch: false` → resume RUNNING
- Otherwise refused with reason

**Optional `--until <boundary>`** — bounded execution that pauses at a user-specified checkpoint instead of running to natural completion. Boundary syntax:

| Syntax | Meaning |
|---|---|
| `--until phase:<id>` | Pause AFTER the named phase completes (inclusive) |
| `--until task:<id>` | Pause AFTER the named task completes |
| `--until before:<phase\|task>` | Pause BEFORE the named phase/task starts (next dispatch refused) |
| `--until next-decision` | Pause as soon as any decision capsule needs filling (auth fail, max iter, etc.) |

NL routing examples (instructions.md):

| User phrase | Canonical |
|---|---|
| "3페이즈까지만 해줘" | `/dtd run --until phase:3` |
| "리뷰 전까지만 돌려" | `/dtd run --until before:review` |
| "UI 만들고 멈춰" | `/dtd run --until task:<UI task id>` |
| "다음 결정 나올때까지" | `/dtd run --until next-decision` |

Boundary stored in `state.md` while RUNNING:
```yaml
- run_until: phase:3                # null | phase:<id> | task:<id> | before:<id> | next-decision
- run_until_reason: user-checkpoint # user-test | user-decision | manual-check | explicit-limit
```

When boundary reached:
1. In-flight task (if any) finishes (same as `/dtd pause`).
2. Set `plan_status: PAUSED`.
3. Append `phase-history.md` row with `gate: user-checkpoint` and `note: <run_until value>`.
4. **Copy boundary to durable display fields** before clearing:
   - `last_pause_reason: run_until_boundary`
   - `last_pause_boundary: <run_until value>` (e.g., "phase:3")
   - `last_pause_at: <timestamp>`
5. Clear `run_until` and `run_until_reason` (active-run fields).
6. `/dtd status` reads `last_pause_*` to display: "Paused at requested boundary: phase:3 (set by user --until); next: /dtd run".

Resume is just `/dtd run` again (no `--until` = run to natural completion). On resume:
- Clear `last_pause_*` fields.
- Apply a new `--until` if you want another bounded segment.

Why split active vs durable: status display must stay reliable across resume sessions and after the active flag clears. `run_until` is the runtime control; `last_pause_*` is the audit/display.

**Do not confuse `--until` with `pause_requested`**: `--until` is a planned boundary set at run-time; `pause_requested` is an interrupt. Both lead to PAUSED but the audit trail is different.

**Pre-run checks** (before entering the run loop):

- If `host_mode` is `assisted` or `full` AND `.dtd/PROJECT.md` is TODO-only (no real project context filled in): WARN user "PROJECT.md is empty — workers will receive generic context. Continue anyway? (y/n)". Same check as `/dtd doctor` #11, but at run time.
- Verify `.dtd/notepad.md` exists (template state OK).
- Verify `.dtd/attempts/` directory exists (create if not).

Run loop (per task):

1. Read `state.md` — check `pause_requested`. If true, mark `plan_status: PAUSED`, exit.
2. Read `steering.md` cursor — apply any new low-impact entries to upcoming worker prompts.
3. Check `pending_patch`. If true: refuse to dispatch new task; await approve/reject.
4. Pick next ready batch by topo order (respect `depends-on` and `parallel-group`).
5. **Pre-dispatch lock partitioning** (FIX P1-3 — happens BEFORE any dispatch):
   a. For every task in the candidate parallel batch, resolve `<worker>` and compute its lock set from `<output-paths>` + `<resources>`.
   b. Build the parallel batch's combined lock graph. Apply overlap matrix (see §Resource Locks).
   c. If two siblings' lock sets conflict (e.g., both write `src/api/**`): split the batch into non-conflicting sub-batches (one task per conflict cluster). Or, if the user requested strict parallelism, ask user to break parallel-group manually.
   d. Acquire all leases for the first non-conflicting sub-batch atomically (each lease appended to `resources.md`).
   e. Only then dispatch this sub-batch in parallel.
   f. Wait for all sub-batch members to finish; release their leases; advance to the next sub-batch.
6. For each dispatched task (within a sub-batch):
   a. Build worker prompt in this canonical order (same as `instructions.md` §Token Economy #2):
      ```
      1. worker-system.md             (static, cacheable)
      2. PROJECT.md                   (rarely changes, cacheable)
      3. notepad.md <handoff> only    (dynamic, REWRITTEN before each dispatch, NOT cached)
      4. skills/<capability>.md       (per capability, cacheable)
      5. task-specific section        (varies, not cached)
      ```
      Notepad `<handoff>` is dynamic by design; do not mark it for cache.
   b. **Context budget gate** (mandatory pre-dispatch — required, not optional):
      - Estimate input tokens (full prompt) + reserved output budget against the worker's `max_context`.
      - If estimate ≥ worker's `soft_context_limit` (default 70%) AND this is NOT a final/closing response: **checkpoint, close current phase, split task into smaller sub-tasks, do NOT dispatch the oversized task as-is**. Append `phase-history.md` row noting `note: phase split on soft cap`.
      - If estimate ≥ `hard_context_limit` (default 85%): refuse dispatch, require split.
      - If estimate ≥ `emergency_context_limit` (default 95%): emergency checkpoint. Fill the **decision capsule** (per state.md schema): `awaiting_user_decision: true`, `awaiting_user_reason: CONTEXT_EXHAUSTED`, `decision_id: dec-NNN`, `decision_prompt: "Worker context near limit. How should DTD proceed?"`, `decision_options: [{id:checkpoint, label:"checkpoint and stop", effect:"finalize_run(STOPPED)", risk:"manual resume needed"}, {id:split_phase, label:"split phase and continue", effect:"split task, lower budget", risk:"may produce smaller deliverable"}, {id:wait_compact, label:"compact notepad and retry", effect:"shrink prompt prefix", risk:"loses some history"}]`, `decision_default: checkpoint`, `decision_resume_action: "after user choice, controller acts on the option's effect"`. `/dtd status` displays the prompt + options + default.
      - Record estimate, decision, and split reason to `.dtd/log/exec-NNN-task-N-ctx.md` and `phase-history.md`.
      - Worker's `::ctx::` self-report (if any) is advisory; controller's calculation is authoritative.
   c. Dispatch (mode-dependent — see Modes section).
   d. Heartbeat lease at `heartbeat_interval_sec` (default 30s) for long tasks. **Best-effort in plan-only / blocking-shell hosts** — stale takeover is the safety boundary.
   e. Receive worker response. Parse `::ctx::` (optional, before summary) and `::done::` / `::blocked::` (mandatory last line); extract `===FILE: <path>===` blocks. **Redact secrets in worker response before saving to log.**
   f. **Validate before apply** (gating step — required before any file write):
      - Each `===FILE: <path>===` path must:
        1. fall within the worker's `permission_profile` write scope (see §Worker Permission Profiles in `instructions.md`)
        2. fall within the task's declared `<output-paths>` (or be a subset thereof)
        3. fall within currently held lock set
        4. NOT match `path-policy.block_patterns`
      - If any path fails any check: do NOT apply ANYTHING from this response. Mark attempt `blocked` with reason `output_path_out_of_scope`. Append to `.dtd/attempts/run-NNN.md`. Trigger escalation per ladder.
      - All paths pass → proceed to step g.
   g. Apply file changes (mode `assisted` may confirm; mode `full` auto-applies). **Use temp-file + atomic rename** for safety, in two phases:

      **Phase 1 — write all temp files**: for each output file, write `<path>.dtd-tmp.<pid>` (contents from worker response). If ANY temp write fails (e.g., `DISK_FULL` during write of file 2 of 3): abort phase 1 immediately, **delete any temp files already written in this attempt** (no rename has happened yet so no final file is changed), fill `DISK_FULL` (or appropriate write-failure reason) capsule. **No final files modified — clean abort.**

      **Phase 2 — rename all temps to final**: after all temps written successfully, rename them to final paths. If a rename fails partway (rare — e.g., file 2 locked by AV, file 3 path disappeared): some final files were renamed (applied), others still as `.dtd-tmp.*`. This is `PARTIAL_APPLY`. Fill capsule with explicit applied/pending lists. **Automatic resume forbidden** — user picks inspect / revert_partial / accept_partial / stop.

      **Local apply failure paths** (each is blocking — fill decision capsule, do NOT silently fail):

      | Condition | Reason enum | Options |
      |---|---|---|
      | Out of disk space | `DISK_FULL` | `[free_space_retry, skip_file, stop]`, default `free_space_retry` |
      | Filesystem permission denied | `FS_PERMISSION_DENIED` | `[fix_permissions_retry, skip_file, stop]`, default `fix_permissions_retry` |
      | File locked by another process (Windows AV, IDE) | `FILE_LOCKED` | `[wait_retry, force_overwrite, skip_file, stop]`, default `wait_retry` |
      | Path disappeared between validate and write | `PATH_GONE` | `[recreate_dir_retry, skip_file, stop]`, default `recreate_dir_retry` |
      | Some files in response wrote OK but later ones failed | `PARTIAL_APPLY` | `[inspect, revert_partial, accept_partial, stop]`, default `inspect`. Lists exactly which files were applied vs not. **Automatic resume forbidden** — user must choose. |
      | Other write error | `UNKNOWN_APPLY_FAILURE` | `[retry, inspect, stop]`, default `inspect` |

      On any of the above:
      - Mark attempt `blocked` (NOT failed — failed implies retry-able by tier ladder, but apply failures need user input).
      - Fill decision capsule per template above.
      - Save sanitized error summary to `.dtd/log/exec-<run>-task-<id>.<worker>.md`.
      - Lease is held (NOT released) until user resolves — safer to keep lock during ambiguous state.
      - `/dtd status` shows `awaiting decision: <reason>`.
      - When user picks an option, controller acts per `effect`. `revert_partial` deletes any files that were written in this attempt (using temp-file rename audit trail).

      For `PARTIAL_APPLY` specifically: the controller logs which files made it (atomic rename succeeded) and which didn't (still `.dtd-tmp.*`), and presents the list to the user. The user can `inspect` (view diffs), `revert_partial` (undo the applied ones), `accept_partial` (treat applied subset as the result, mark task partial-grade), or `stop`.
   h. Update `<output-paths actual="true">` with actual files written.
   i. Release lease.
   j. Compute grade (controller-side, never worker self-grade): worker output vs target_grade. Update task status.
   k. If grade < target_grade: failure counter `++`, escalate per ladder if threshold hit.
   l. If grade ≥ target_grade: counter reset, advance.
   m. Append phase row to `phase-history.md` on phase boundary.
   n. Compact completed tasks in `plan-NNN.md` (1-line form).
   o. Update `state.md` (current_task, progress, counters). Update `notepad.md` with any new learnings/decisions/issues from this task (see §Per-Run Notepad).
   p. Apply patches in `<patches>` section ONLY between tasks (after step o completes), never during step c/d/e.

7. After all phases pass: call `finalize_run(COMPLETED)` (defined below). 

If `WORK_START` not yet emitted for this run, emit it on first dispatch (or on `/dtd run` from APPROVED).

### `finalize_run(terminal_status)` — shared terminal lifecycle

**Required by ALL terminal exits**: COMPLETED (run loop end), STOPPED (`/dtd stop`), FAILED (unrecoverable error, e.g. all workers dead). NOT called for PAUSED (pause is non-terminal).

Order (atomic from controller's POV — execute ALL steps before responding to user):

1. **Release leases**: scan `resources.md` for any leases owned by this run; remove all. Cancel any in-flight heartbeat.
2. **Archive notepad**: copy `.dtd/notepad.md` → `.dtd/runs/run-NNN-notepad.md`. Create `.dtd/runs/` if missing.
3. **Reset notepad**: replace `.dtd/notepad.md` content with the template state (5 sections, all `(empty)`).
4. **Write run summary**: `.dtd/log/run-NNN-summary.md` with phase grades / output paths / duration / final grade.
5. **Clear incident state** (v0.2.0a):
   - For every incident in `.dtd/log/incidents/index.md` belonging to this run with `status=open`:
     - On `terminal_status=COMPLETED` or `STOPPED` → set `status: superseded`, `resolved_at: <ts>`, `resolved_option: terminal_run`.
     - On `terminal_status=FAILED` → set `status: fatal`, `resolved_at: <ts>`, `resolved_option: terminal_failed`.
   - Update each affected `.dtd/log/incidents/inc-<run>-<seq>.md` detail file accordingly.
   - In state.md (held for the step-7 atomic write below): clear `active_incident_id`, `active_blocking_incident_id`, `recent_incident_summary`. Keep `last_incident_id` and `incident_count` for cross-run reference.
   - If `awaiting_user_decision` was an incident-backed reason (`INCIDENT_BLOCKED`), also clear `awaiting_user_decision`, `awaiting_user_reason`, `decision_id`, `decision_prompt`, `decision_options`, `decision_default`, `decision_resume_action`, `decision_expires_at`, `user_decision_options` as part of step 7.
6. **Append AIMemory `WORK_END`** (only if AIMemory present): one-line event with `status=<terminal_status> grade=<final_grade> <duration>`. Per §AIMemory Boundary.
7. **Update state.md**: `plan_status: <terminal_status>`, `plan_ended_at: <ts>`, clear `current_task`/`current_phase`/`pending_patch`/`pending_attempts` fields, plus the incident-state clears from step 5, plus the decision-capsule clears from step 5 if applicable. Set `last_update`. Single atomic tmp-rename write.

If any step fails partway, the controller logs an `ORPHAN_RUN_NOTE` to `AIMemory/work.log` (if present) describing what was completed vs not, and prints a recovery hint to the user. Doctor's "orphaned notepad content" check catches the most common failure (step 3 not executed).

### `/dtd pause`

RUNNING → PAUSED on next task boundary. Sets `state.md` `pause_requested: true`. The currently in-flight task (if any) finishes; controller does not dispatch the next one. **NOT terminal — does NOT call `finalize_run`.**

### `/dtd stop`

Force-end the active plan. Allowed from `RUNNING` / `PAUSED`, OR any state with `pending_patch: true`.
Calls `finalize_run(STOPPED)`. Active leases released, `pending_patch` cleared, `patch_status` set to `rejected` if was proposed.
The plan file is preserved (audit). New plans start fresh with `/dtd plan`.

### `/dtd steer <instruction>`

Append a steering directive. Sequence:

1. Append entry to `steering.md` (raw user phrase + controller's interpretation).
2. Classify impact: `low | medium | high`.
3. **low**: prefix to upcoming worker prompts; no patch, no confirm.
4. **medium / high**: create patch in plan-NNN.md `<patches>` section. Set `state.md` `pending_patch: true`, `patch_impact: <medium|high>`, `patch_status: proposed`.
5. If RUNNING: in-flight task continues, no new dispatch until patch resolved.
6. Display patch + ask: `approve | reject`.
7. On `approve`: apply patch to plan body, `pending_patch: false`, `patch_status: approved`. Resume per `plan_status`.
8. On `reject`: discard patch, `pending_patch: false`, `patch_status: rejected`. Steering entry preserved in `steering.md` for context. Resume per `plan_status`.

Patch application **only between tasks or after in-flight task completes**. Never mutate a worker call mid-flight.

### `/dtd incident list [--all|--blocking|--recent]` (v0.2.0a)

Show incidents. Default = last 10 unresolved. Output is compact ASCII table per `dashboard_style`:

```
+ DTD incidents (run 001)
| ID                  | severity | reason            | task | resolved |
| inc-001-0001        | blocked  | NETWORK_UNREACHABLE | 2.1  | no       |
| inc-001-0002        | warn     | MALFORMED_RESPONSE | 2.2  | no       |
| inc-001-0003        | info     | RATE_LIMIT (1st)   | 3.1  | no       |
+ next: /dtd incident show <id>
```

Flags:

- `--all` — include resolved incidents too
- `--blocking` — only severity=blocked|fatal
- `--recent` — last 24h regardless of resolution

Classified as `observational_read` per `instructions.md` §Status read isolation — does NOT mutate notepad/steering/attempts/phase-history.

### `/dtd incident show <id>` (v0.2.0a)

Renders the full incident detail file. Shows reason / phase / worker / task / recoverability / side effects / cross-linked attempt / recovery options / sanitized error summary / timeline.

Also `observational_read` — no state mutation.

### `/dtd incident resolve <id> <option>` (v0.2.0a)

Resolve an open incident with a chosen recovery option.

```
/dtd incident resolve inc-001-0001 retry
/dtd incident resolve inc-001-0001 switch_worker
/dtd incident resolve inc-001-0001 stop
```

Option must be one from the incident's `recovery_options` (matches the decision capsule's `decision_options` for blocking incidents).

Effect: per Incident Tracking §Resolve logic — clears state fields, promotes next blocker if queued, triggers chosen option's `effect`.

NL routing in `instructions.md`:

| User phrase | Canonical |
|---|---|
| "그 에러 다시 보여줘", "지금 막힌 거 뭐야", "incident 보여줘" | `incident list` or `incident show <active>` |
| "incident 4 처리해", "재시도로 가자", "그 에러 retry" | `incident resolve <id> <option>` |
| "어디서 막혔어?" | `incident show <active_blocking_incident_id>` |

### `/dtd status [--compact|--full|--plan|--history|--eval]`

Always allowed regardless of state. Renders dashboard (see Status Dashboard section).

---

## Plan State Machine

7 `plan_status` values + 1 orthogonal `pending_patch` flag.

```
              /dtd plan
                 │
                 ▼
            ┌─────────┐
            │  DRAFT  │ ◀── /dtd plan worker, /dtd plan, manual edit
            └────┬────┘
                 │ /dtd approve
                 ▼
           ┌──────────┐
           │ APPROVED │
           └────┬─────┘
                │ /dtd run
                ▼
            ┌─────────┐
   ┌───────▶│ RUNNING │────(all phases pass)────▶ ┌───────────┐
   │        └────┬────┘                            │ COMPLETED │
   │             │ /dtd pause                      └───────────┘
   │             ▼
   │ /dtd run  ┌────────┐
   └───────────│ PAUSED │
               └───┬────┘
                   │ /dtd stop
                   ▼              ┌────────┐
              ┌─────────┐         │ FAILED │ ◀── all workers down / unrecoverable
              │ STOPPED │         └────────┘
              └─────────┘
```

`pending_patch` flag is **orthogonal** — can be true in APPROVED, RUNNING, PAUSED. State examples:

- `RUNNING + pending_patch=true`: in-flight task completes; no new dispatch until patch resolved
- `APPROVED + pending_patch=true`: cannot run until patch resolved
- `PAUSED + pending_patch=true`: resume blocked until patch resolved

Cannot be true in DRAFT (use direct edit), STOPPED, COMPLETED, FAILED.

### State × Action Matrix

| state \ action            | plan        | approve     | run         | pause       | stop        | steer (med/high) | approve patch | reject patch | plan worker  |
|---------------------------|-------------|-------------|-------------|-------------|-------------|------------------|---------------|--------------|--------------|
| DRAFT                     | overwrite?  | ✓ → APPROVED| ✗           | ✗           | ✓           | direct edit      | n/a           | n/a          | ✓            |
| APPROVED, no patch        | ✗ (stop?)   | ✗           | ✓ → RUNNING | ✗           | ✓           | → set patch      | n/a           | n/a          | ✗ (use steer)|
| APPROVED, patch           | ✗           | ✗           | ✗           | ✗           | ✓           | accumulate       | ✓             | ✓            | ✗            |
| RUNNING, no patch         | ✗           | ✗           | n/a         | ✓           | ✓           | → set patch      | n/a           | n/a          | ✗            |
| RUNNING, patch            | ✗           | ✗           | n/a         | ✓           | ✓           | accumulate       | ✓ (apply when next task boundary) | ✓ | ✗ |
| PAUSED, no patch          | ✗           | ✗           | ✓ → RUNNING | n/a         | ✓           | → set patch      | n/a           | n/a          | ✗            |
| PAUSED, patch             | ✗           | ✗           | ✗           | n/a         | ✓           | accumulate       | ✓             | ✓            | ✗            |
| COMPLETED / STOPPED / FAILED | ✓ (new)  | ✗           | ✗           | ✗           | ✗           | ✗                | n/a           | n/a          | ✗            |

`✗` = blocked with reason. `✓` = proceed. `n/a` = not applicable.

---

## Worker Registry & Routing

`workers.md` schema (excerpt — see template for full):

```markdown
## <worker_id>
- aliases: <comma-separated nicknames>
- display_name: <preferred nickname for status output>
- endpoint: <OpenAI-compatible URL>
- model: <model identifier per provider>
- api_key_env: <ENV_VAR_NAME>          # never inline raw keys
- max_context: <token int>
- soft_context_limit: 70
- hard_context_limit: 85
- emergency_context_limit: 95
- capabilities: <comma list — code-write, code-refactor, review, planning, debug, ...>
- cost_tier: free | paid
- priority: <int — higher first>
- tier: 1|2|3
- failure_threshold: <int>
- escalate_to: <next worker_id, or `user`>
```

### Routing precedence (when task has no explicit `<worker>`)

1. Task has `<worker>X</worker>` → use X (manual override).
2. Task has `<capability>Y</capability>`:
   a. Filter workers with capability Y.
   b. Sort: priority desc, then cost_tier (free first), then tier asc.
   c. Pick top. On failure, advance escalate_to chain.
3. No explicit hint → use `config.md` `roles.primary`.
4. All resolution failed → controller asks user.

### NL alias / role resolution

Order:

1. exact `worker_id` match
2. exact `alias` match (across all workers)
3. exact `role` name match (look up `config.md` `roles.<name>`)
4. capability fuzzy (e.g. "리뷰어" → role:reviewer or capability:review)
5. ambiguous → confirm

If a phrase matches both `controller.name` and a worker alias: confirm which.

---

## Plan Schema (XML)

```xml
<plan-status>DRAFT</plan-status>

<brief>
goal: <2-4 sentences>
approach: <high-level shape>
non-goals: <if relevant>
</brief>

<phases>
  <phase id="1" name="planning" target-grade="GOOD" max-iterations="5">
    <task id="1.1" parallel-group="A">
      <goal>schema 작성</goal>
      <worker>qwen-remote</worker>
      <worker-resolved-from>role:planner</worker-resolved-from>
      <capability>planning</capability>
      <work-paths>docs/, src/types/</work-paths>
      <output-paths predicted="true">docs/schema.md</output-paths>
      <context-files>src/types/api.ts</context-files>
      <resources>
        <resource mode="write">files:project:docs/schema.md</resource>
      </resources>
      <done>false</done>
    </task>
    <!-- ...more tasks... -->
  </phase>
  <!-- ...more phases... -->
</phases>

<patches>
  <!-- empty until steering creates one -->
</patches>
```

Completed tasks are compacted to one-line form to save context:

```xml
<task id="1.1" worker="qwen-remote" status="done" grade="GREAT" dur="18s" log="exec-001-task-1.1.qwen-remote.md"/>
```

Original full task body is archived to `plan-NNN-history.md` if compaction loses important detail. Compaction trigger: any task transitioning to `done` AND plan size > 8 KB.

### Plan size budget & spill

- **Preferred**: `plan-NNN.md` ≤ 12 KB
- **Hard cap**: 24 KB (`/dtd doctor` ERRORs above this)

Patches policy:

- ≤ 5 patches AND ≤ 4 KB → keep in `<patches>` section
- exceed → spill: keep latest 1 patch summary inline, full history → `plan-NNN-patches.md`
- Applied patches → migrated to `phase-history.md` or `log/run-NNN-summary.md` with pointer

Brief: bounded (≤ 2 KB) — large rationale belongs in `PROJECT.md`.

---

## Tier Escalation

### Counters (in `state.md`)

```markdown
- failure_counts:
    - { worker: deepseek-local, task: 2.1, count: 2, reason_hashes: [a3f1b9, a3f1b9] }
    - { worker: deepseek-local, task: 2.2, count: 0 }
- failure_count_phase: 2
- last_failure_reason: "test failed: assertEquals expected 5 got 3"
```

### Trigger

Worker W escalates on task T when **W's count for T ≥ W.failure_threshold** (or `config.default_failure_threshold`, default 3).

Phase counter is dashboard-only by default. Set `config.md` `escalate_on_phase_failures: <N>` to enable phase-level trigger.

### Reset

- Task T succeeds → (W, T) count = 0, hashes = []
- Task T reassigned to W' → (W, T) preserved (history); (W', T) starts at 0
- User-accept (run failure as-is) → all counters for T reset

### `failure_reason_hash` (acceleration, not replacement)

Worker `::blocked:: <reason>` reason → normalized (lowercase, stopwords stripped) → hashed. Same hash twice = "stuck on same blocker" — **shortcut to next escalation step**. Threshold-based escalation remains the default; hash matching only accelerates.

### 5-Step Escalation Ladder

1. **Focused retry** — same worker, same task, with explicit hint about prior failure (1-2 retries within `failure_threshold`).
2. **Tier escalation** — follow `escalate_to` chain to next worker.
3. **Add reviewer worker** — inject reviewer's analysis as hint to the original/next worker.
4. **Controller intervention** — controller handles directly (must be classified as `small_direct_fix` or `artifact_authoring` per Controller Categories below; `REVIEW_REQUIRED` gate applies).
5. **User escalation** — `escalate_to: user` is terminal. Fill decision capsule: `awaiting_user_decision: true`, `awaiting_user_reason: ESCALATION_TERMINAL`, `decision_id: dec-NNN`, `decision_prompt: "Worker chain exhausted on task <id>. How to proceed?"`, `decision_options: [{id:accept, label:"accept current", effect:"keep current grade, advance"}, {id:rework, label:"rework", effect:"reset counters, retry from current step"}, {id:abandon, label:"abandon", effect:"finalize_run(STOPPED)"}]`, `decision_default: rework`. `/dtd status` displays the prompt + options.

---

## Resource Locks

7-step lifecycle, executed by controller around each task dispatch.

1. **Normalize paths**: relative → `project:<path>`, absolute → `global:<path>`. Glob preserved as-is for matching.
2. **Compute lock set**: union of `<output-paths>` (write mode) + explicit `<resources>` entries.
3. **Check overlap**: scan `resources.md` active leases. Apply overlap matrix:

   | existing \ new | read | write | exclusive |
   |---|---|---|---|
   | read | OK | block | block |
   | write | block | block | block |
   | exclusive | block | block | block |

   Path overlap: literal⊆literal exact match; literal⊆glob via pattern match; glob⊆glob via specialization (conservative — `src/api/**` ⊆ `src/**`).

4. **Acquire lease**: append entry to `resources.md`. Canonical resource string format: `<type>:<namespace>:<path>` (v0.1 type is always `files`).

   ```markdown
   ## lease-<id>
   - worker: <worker_id>
   - task: <task_id>
   - mode: write
   - paths:
       - files:project:src/api/**
       - files:global:/tmp/build/
   - acquired_at: <ts>
   - heartbeat_at: <ts>
   - run_id: <run_id>
   ```

5. **Heartbeat**: every `heartbeat_interval_sec` (default 30) during long tasks, controller updates `heartbeat_at`. **In prompt-only / blocking-shell hosts, heartbeat is best-effort** — stale takeover is the safety boundary.
6. **Release**: on success/failure/blocked, remove lease entry from `resources.md`.
7. **Stale takeover**: if `heartbeat_at` older than `stale_threshold` (default 5 min), DO NOT auto-takeover. Ask user explicitly. Log `NOTE` event in `AIMemory/work.log` (if present) on takeover.

`global:` namespace locks (absolute paths) are **best-effort only** — coordination across DTD instances or external tools not guaranteed. Confirm with user before acquiring.

---

## Path Notation

Inside project root → **relative** (`src/api/users.ts`, `src/api/**`).
Outside project root → **absolute** (`/tmp/build/`, `~/.cache/`, `C:\Users\...`).

Auto-detect: leading `/`, `<drive>:\`, or `~/` → absolute. Otherwise relative.

`..` discouraged. Doctor warns and recommends absolute form.

Security BLOCK patterns (in `config.md` `path-policy`):

- `/etc/**`, `C:\Windows\**`, `~/.ssh/**`, `~/.aws/**` → BLOCK
- `~/**` (other) → WARN
- `/`, `C:\` → BLOCK
- `/tmp/**`, `/var/log/**` → OK

---

## Host Capability Modes

Set during install, stored in `config.md` `host.mode`. Changeable via `/dtd doctor` recommendation or manual edit. The actual HTTP recipe is in §Worker Dispatch — HTTP Transport above; this section says only WHO triggers it per mode.

### `plan-only`

Capability: filesystem-read/write only.
DTD does: plan/state/eval/steering management. `/dtd run` does NOT auto-dispatch — instead, prints the worker prompt for the next task and asks user to:

```
Next task: 2.1 API endpoints
Worker: deepseek-local

→ Copy this prompt into a separate session running deepseek-coder:6.7b:

[----- prompt begins -----]
[full prompt text]
[----- prompt ends -----]

When you have the response, paste it back as:

  /dtd run --paste

Or save to .dtd/tmp/paste-2.1.md and run /dtd run --paste-file 2.1
```

The controller then parses the pasted response and continues the loop.

### `assisted`

Capability: + shell-exec or web-fetch.
DTD does: auto-dispatch. Per-call confirm if `config.md` `assisted_confirm_each_call: true` (default false in v0.1).

### `full`

Capability: + shell-exec/web-fetch + autonomy.
DTD does: autonomous dispatch + auto-apply file changes. Destructive actions (file delete, force push, dependency removal) still confirm.

---

## Controller Work Categories

When the controller does work itself (orchestration, escalation step 4, or any direct action), classify into one of three categories. Self-classification at action start, recorded in `state.md`:

- **`orchestration`** (planning, dispatching, status, NL parsing, integrating worker outputs) → `grade: N/A`, `gate: none`
- **`small_direct_fix`** (controller fixes a typo/small bug instead of re-dispatching to worker) → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`
- **`artifact_authoring`** (controller writes a non-trivial artifact: code module, doc, plan section) → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`

`REVIEW_REQUIRED` gate: phase pass blocked until reviewer (worker with `review` capability) or user explicitly OKs.

`config.md` `controller-work-policy`:

```markdown
- review_required_by: reviewer_worker | user
- review_fallback: user
```

Controller never grades its own work. Status display: `grade: N/A(controller) gate: REVIEW_REQUIRED — awaiting <reviewer>`.

---

## Worker Output Discipline

See `.dtd/worker-system.md` for the prompt prefix. Summary:

- ONE fenced code block per file, prefixed `===FILE: <path>===`
- ONE summary line `::done:: <≤80 chars>` OR `::blocked:: <reason>`
- Optional: `::ctx:: used=<%> status=ok|soft_cap|hard_cap` (advisory; controller computes authoritatively)
- NO explanations, NO markdown headers outside fences, NO apologies, NO "Here is the code"

Controller parses these markers strictly. Malformed output triggers `failure_count_iter++`.

---

## Worker Dispatch — HTTP Transport

This is the actual recipe for making a worker call. Per-mode (plan-only / assisted / full) the recipe is the same below; the difference is who triggers it.

### Request shape (OpenAI-compatible chat completions)

```
POST <worker.endpoint>
Headers:
  Authorization: Bearer ${env[worker.api_key_env]}
  Content-Type: application/json
Body (JSON):
{
  "model": "<worker.model>",
  "messages": [
    {"role": "system", "content": "<system_prompt>"},
    {"role": "user",   "content": "<user_prompt>"}
  ],
  "max_tokens":  <reserved_output_budget>,

  // Tuning fields below are MERGED from worker config (workers.md).
  // Defaults applied if worker doesn't set them:
  "temperature": <worker.temperature ?? 0.0>,
  "top_p":       <worker.top_p ?? 1.0>,
  "stream":      <worker.stream ?? false>,         // v0.1 enforces false; v0.2 will allow true
  // optional, only included if set in worker config:
  "seed":              <worker.seed>,
  "stop":              <worker.stop as array>,
  "response_format":   <worker.response_format>,   // text | {"type": "json_object"}
  "frequency_penalty": <worker.frequency_penalty>,
  "presence_penalty":  <worker.presence_penalty>,
  "reasoning_effort":  <worker.reasoning_effort>,  // OpenAI o1/o3/gpt-5 reasoning models
  // shallow-merged at top level for provider-specific:
  ...<worker.extra_body>
}
```

`<system_prompt>` = concatenation of (in this exact order, per §Token Economy #2):
1. `worker-system.md`
2. `PROJECT.md`
3. `notepad.md` `<handoff>` section only
4. `skills/<capability>.md` (if applicable)

`<user_prompt>` = the task-specific section: goal, context-files (per inline tier policy), output-paths, resources, plus the worker's `permission_profile` declaration so it knows the scope.

`<reserved_output_budget>` = `min(worker.max_context * (1 - hard_context_limit/100), 4096)` typically. Adjust per task expected output size.

**JSON escaping**: file content in `messages` MUST be properly JSON-escaped (`\n` → `\\n`, `"` → `\\"`). Build the body in a tmp file (`.dtd/tmp/dispatch-<run>-<task>.json`) using your host's JSON serializer, never string-concatenated.

### Per-mode dispatch

**`full` mode** — controller makes the HTTP call autonomously:

POSIX (curl):

```bash
mkdir -p .dtd/tmp
# Build the JSON body using your host's JSON tool (jq, python -c, node -e, etc.)
# … assume already at .dtd/tmp/dispatch-001-2.1.json
curl -fsSL --max-time ${TIMEOUT_SEC:-120} \
  -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @.dtd/tmp/dispatch-001-2.1.json \
  -o .dtd/tmp/response-001-2.1.json
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path .dtd/tmp | Out-Null
$headers = @{
  "Authorization" = "Bearer $env:OLLAMA_API_KEY"
  "Content-Type"  = "application/json"
}
Invoke-RestMethod -Method POST -Uri $endpoint -Headers $headers `
  -InFile ".dtd/tmp/dispatch-001-2.1.json" `
  -TimeoutSec 120 `
  -OutFile ".dtd/tmp/response-001-2.1.json"
```

The API key value comes from the env var (`workers.md` `api_key_env: OLLAMA_API_KEY` → `$OLLAMA_API_KEY`). **Never inline the value into the body, log file, or chat output** (per §Security).

**`assisted` mode** — same recipe, but if `config.host.assisted_confirm_each_call: true`, prompt the user first:

```
About to dispatch task 2.1 to deepseek-local (POST http://localhost:11434/v1/chat/completions, ~1300 tokens). Proceed? (y/n)
```

**`plan-only` mode** — controller does NOT make the HTTP call. Instead:

1. Write the assembled prompt as plain text to `.dtd/tmp/dispatch-<run>-<task>.txt` (NOT as JSON — human-paste-friendly).
2. Print to chat:
   ```
   Next task: 2.1 API endpoints
   Worker: deepseek-local
   Prompt at: .dtd/tmp/dispatch-001-2.1.txt
   
   Copy it into a separate session running deepseek-coder:6.7b.
   Save the worker's response to: .dtd/tmp/response-001-2.1.txt
   Then run: /dtd run --paste
   ```
3. Wait for `/dtd run --paste`. Parse `.dtd/tmp/response-001-2.1.txt` and continue from step 6.e (parse `::done::` + `===FILE:===` blocks).

### Response parsing

Standard OpenAI shape:

```json
{
  "choices": [{
    "message": { "role": "assistant", "content": "<worker output>" },
    "finish_reason": "stop"
  }],
  "usage": { "prompt_tokens": 1234, "completion_tokens": 567 }
}
```

Extract `.choices[0].message.content` → that's the worker's raw output (will contain `===FILE: ...===` blocks + `::done::` or `::blocked::` line).

`finish_reason: "length"` → response truncated. Mark attempt as `failed`, reason `output_truncated`, increase `max_tokens` budget, retry per ladder.

`usage.prompt_tokens` + `usage.completion_tokens` → log to `.dtd/log/exec-<run>-task-<id>-ctx.md` for context budget tracking (compares vs controller's pre-dispatch estimate).

### Error handling

Two-layer model:
1. **Recoverable / quality failures** → mark attempt failed, escalate per tier ladder. No user-blocking decision needed (the ladder itself is the action).
2. **Blocking failures** (need user input — env var fix, switch worker, abandon, etc.) → fill the **decision capsule** (per state.md schema) so `/dtd status` shows the actionable blocker, and resume is durable across sessions.

#### Per-status table

| HTTP status / condition | Layer | Action |
|---|---|---|
| 200 OK | n/a | Parse response, proceed to validation step (run loop step 6.f) |
| **401 unauthorized** | **Blocking** | Abort dispatch immediately. Fill decision capsule with `awaiting_user_reason: AUTH_FAILED`, options `[fix_env_retry, switch_worker, stop]`, default `fix_env_retry`. **Never log the key value or attempted value.** Mark attempt `blocked`, reason `auth_failed`. |
| 403 forbidden | Blocking | Same as 401 — fill capsule with reason `AUTH_FAILED`, options `[edit_worker, switch_worker, stop]`, default `edit_worker`. (No separate FORBIDDEN reason; both 401 and 403 collapse to `AUTH_FAILED` since both are auth/permission failures resolved by editing worker config.) |
| 404 not found | Blocking | Endpoint or model id wrong. Fill capsule reason `ENDPOINT_NOT_FOUND`, options `[edit_worker, test_worker, switch_worker, stop]`, default `edit_worker`. |
| 429 rate limit | Recoverable on 1st hit, Blocking on 2nd | 1st: wait `Retry-After` header (or 30s default), retry ONCE. 2nd consecutive: fill capsule reason `RATE_LIMIT_BLOCKED`, options `[wait_retry, retry_later, switch_worker, stop]`, default `wait_retry`. |
| 5xx server error | Recoverable on 1st, Blocking on 2nd | 1st: wait 5s, retry ONCE. 2nd: capsule reason `WORKER_5XX_BLOCKED`, options `[retry, switch_worker, stop]`, default `switch_worker`. |
| Timeout (`worker.timeout_sec`) | Recoverable on 1st, Blocking on repeat | 1st: failure_count++ on (worker, task), retry per tier ladder. After threshold OR 2nd timeout in same dispatch: fill capsule reason `TIMEOUT_BLOCKED`, options `[wait_once, retry_same, switch_worker, controller_takeover, stop]`, default `switch_worker`. |
| Network unreachable | Blocking | Fill capsule reason `NETWORK_UNREACHABLE`, options `[retry, test_worker, switch_worker, manual_paste, stop]`, default `test_worker`. Recommend `/dtd doctor` + `/dtd workers test <id>`. |
| JSON parse error | Recoverable on 1st, Blocking on 2nd | 1st: failure_count++, retry. 2nd: capsule reason `MALFORMED_RESPONSE`, options `[retry, switch_worker, stop]`, default `switch_worker`. Save raw to log for inspection. |

Decision capsule shape for blocking errors (template):

```yaml
awaiting_user_decision: true
awaiting_user_reason: <enum from above>
decision_id: dec-NNN
decision_prompt: "<one-line context: which task, which worker, what failed>"
decision_options:
  - {id: <opt-id>, label: <human label>, effect: <what controller does>, risk: <what user should know>}
  - ...
decision_default: <safest option id>
decision_resume_action: "<exact next-step description for user>"
user_decision_options: [<id list>]   # legacy back-compat
```

`/dtd status` displays the prompt, options, default, and current task/worker context. `/dtd run` is refused while `awaiting_user_decision: true` until user picks an option.

#### Worker inactive / stuck (heartbeat stale, slow but no timeout)

When `last_heartbeat_at` is older than `stale_threshold_min` (default 5) AND the attempt is still `running`, OR when `worker.timeout_sec` is reached but worker is responding intermittently:

```yaml
awaiting_user_decision: true
awaiting_user_reason: WORKER_INACTIVE
decision_id: dec-NNN
decision_prompt: "Worker <worker_id> on task <task_id> inactive for <elapsed>s (timeout=<sec>s, last heartbeat <X>s ago). How to proceed?"
decision_options:
  - {id: wait_once,           label: "wait <N>s longer",           effect: "extend timeout, keep same worker",                  risk: "may waste more time"}
  - {id: retry_same,          label: "cancel and retry",            effect: "abort current attempt, dispatch same worker fresh", risk: "may fail same way"}
  - {id: switch_worker,       label: "switch to next-tier",         effect: "supersede attempt, dispatch escalate_to worker",     risk: "different cost/quality"}
  - {id: controller_takeover, label: "controller does it",          effect: "controller intervenes (REVIEW_REQUIRED gate)",       risk: "no worker grade"}
  - {id: stop,                label: "stop the run",                effect: "finalize_run(STOPPED)",                              risk: "lose run progress beyond saved files"}
decision_default: switch_worker
decision_resume_action: "controller acts on chosen option's effect; if switch_worker, advances current_fallback_index"
user_decision_options: [wait_once, retry_same, switch_worker, controller_takeover, stop]   # legacy back-compat
```

When `switch_worker` is chosen, the late return from the now-superseded attempt is marked `superseded` per attempt timeline rules; output is NOT applied.

All failures (recoverable + blocking) append entry to `.dtd/attempts/run-NNN.md` per §Attempt Timeline. Blocking failures additionally update `state.md` decision capsule.

### Fallback chain — explicit per-task computation

Before dispatching a task, controller computes the `fallback_chain` and stores it in the attempt entry + `state.md` `current_fallback_chain`. Order:

1. Task's explicit `<worker>X</worker>`
2. Worker `X.escalate_to`
3. Same-capability worker with same or narrower `permission_profile`
4. `config.md` `roles.fallback`
5. Controller takeover (only if `gate: REVIEW_REQUIRED` is acceptable)
6. User (terminal)

**Automatic fallback is allowed only when ALL hold**:
- next worker has same or narrower `permission_profile`
- next worker has same or lower `cost_tier`, OR config has `paid_fallback_requires_confirm: false`
- no path-lock conflict (compute lock set at fallback consideration time)
- no pending steering / pending_patch
- retry count below `config.max_auto_worker_switches` (default 1)

If any fail-fast condition fails → fill decision capsule, ask user.

`config.md` knobs added:

```yaml
- auto_fallback: same-profile-only      # never | same-profile-only | ask-before-switch
- max_same_worker_retries: 1
- max_auto_worker_switches: 1
- paid_fallback_requires_confirm: true
- worker_inactive_wait_default_sec: 60   # for WORKER_INACTIVE wait_once option
```

`/dtd status --full` displays the fallback chain for the current task: `fallback: deepseek-local → qwen-remote → user`.

### Tuning fields — how worker config merges into the request body

Each worker entry in `workers.md` may set tuning fields (see `workers.example.md`
schema). Controller merges them into the request body per the rules above:

| Field | Default | Notes |
|---|---|---|
| `temperature` | `0.0` | 0.0 deterministic, 0.5 balanced, 1.0+ creative. Use 0.0-0.2 for code. |
| `top_p` | `1.0` | Nucleus sampling; usually leave default. |
| `seed` | (omitted) | Reproducibility, provider-dependent support. |
| `stop` | (omitted) | Comma-list in worker config → JSON array in body. |
| `response_format` | `"text"` | `"json_object"` requires worker support. |
| `frequency_penalty` | `0.0` | Rare; usually leave default. |
| `presence_penalty` | `0.0` | Rare; usually leave default. |
| `reasoning_effort` | (omitted) | OpenAI o1/o3/gpt-5 reasoning only; ignored by others. |
| `stream` | `false` | **v0.1 always false.** Workers with `stream: true` configured: controller forces false anyway, logs WARN. |
| `extra_body` | `{}` | JSON object shallow-merged into request body for provider-specific params (e.g. `top_k`, `min_p`). Use sparingly. |

The controller does NOT pass through unknown worker fields — only the explicit
tuning whitelist above plus `extra_body`. This prevents accidental leakage of
internal DTD config (`tier`, `failure_threshold`, `aliases`, etc.) into the
worker's request.

### Reasoning / "thinking" model response handling

For workers using reasoning models:

- **OpenAI o1 / o3 / gpt-5 (reasoning)**: provider returns standard `choices[0].message.content`; chain-of-thought hidden. Set `reasoning_effort` per worker.
- **DeepSeek-R1 / V3**: response may include `choices[0].message.reasoning_content` AND `content`. Controller extracts ONLY `content` for `===FILE:===` parsing. Optionally save `reasoning_content` to `.dtd/log/exec-<run>-task-<id>-reasoning.md` for debugging (gitignored along with `log/`).
- **Anthropic extended thinking via shim**: depends on shim mapping; usually maps back to standard `content`.

In all cases the controller's parsing logic is identical — extract `content`, parse markers. The reasoning content is informational only.

### Streaming (v0.2)

v0.1 enforces `stream: false`. Streaming (`stream: true`, SSE response) is deferred to v0.2 for partial file application during long generation. Until then: full response or nothing.

### Provider-specific notes

The above shape works with any **OpenAI-compatible chat completions endpoint**:

- ✓ Ollama, vLLM, LM Studio, llama.cpp server (local)
- ✓ OpenAI, OpenRouter, DeepSeek API, Hugging Face Inference (remote)

Native APIs that do **not** match this shape need a shim:

- **Anthropic Messages API** — uses `anthropic-version` header, system as separate field, different message types. Use `litellm` proxy, `openai-anthropic-shim`, or vLLM router. Direct adapter planned v0.2.
- **Gemini API** — uses `generationConfig` block, content parts. Same: shim. Direct adapter planned v0.2.

`/dtd workers test <id>` performs a probe POST with a minimal `"hello"` prompt and reports back: 2xx + parseable response = healthy.

### Local request body builder (helper, per host)

The controller can use whatever JSON tool the host has. Examples:

POSIX with `jq`:
```bash
jq -n --arg model "$MODEL" --arg sys "$SYSTEM_PROMPT" --arg usr "$USER_PROMPT" --argjson maxtok "$MAX_TOKENS" \
  '{model:$model, temperature:0.0, max_tokens:$maxtok, stream:false,
    messages:[{role:"system", content:$sys},{role:"user", content:$usr}]}' \
  > .dtd/tmp/dispatch-001-2.1.json
```

PowerShell:
```powershell
@{
  model = $model
  temperature = 0.0
  max_tokens = $maxTokens
  stream = $false
  messages = @(
    @{ role = "system"; content = $systemPrompt }
    @{ role = "user";   content = $userPrompt }
  )
} | ConvertTo-Json -Depth 8 | Set-Content -Path ".dtd/tmp/dispatch-001-2.1.json" -Encoding UTF8
```

Both produce a valid OpenAI-compatible request body.

---

## Phase Iteration Control

Each phase declares `max-iterations="<N>"` in plan XML. An "iteration" = one full pass through the phase where worker(s) attempt all tasks. If the resulting grade < `target-grade`, the controller retries (next iteration), unless max is reached.

**Values**:

- `max-iterations="5"` (or any integer ≥ 1) — retry up to N times, then escalate to user
- `max-iterations="unlimited"` — no cap. Controller keeps retrying until grade ≥ target OR another escalation trigger fires (tier escalation, stuck-blocker hash, user pause/stop).
- Phase has no `max-iterations` attribute → use `config.md` `default_max_iterations` (default 5).

**Behavior at limit reached** (`iteration_count == max_iterations` AND grade < target):

1. Append `phase-history.md` row with `gate: escalated:user`.
2. Fill decision capsule (per state.md schema):
   ```yaml
   awaiting_user_decision: true
   awaiting_user_reason: MAX_ITERATIONS_REACHED
   decision_id: dec-NNN
   decision_prompt: "Phase <name> hit max-iterations cap with grade <X> < target <Y>. How to proceed?"
   decision_options:
     - {id: accept,        label: "accept current",     effect: "keep current grade, advance",                    risk: "deliverable below target"}
     - {id: rework,        label: "rework",             effect: "reset iteration counter, try again",             risk: "may stall again"}
     - {id: increase_cap,  label: "raise cap by 5",     effect: "bump max-iterations by 5, continue",             risk: "more time/tokens"}
     - {id: abandon,       label: "abandon",            effect: "finalize_run(STOPPED)",                          risk: "lose run progress beyond saved files"}
   decision_default: rework
   decision_resume_action: "controller acts on chosen option's effect"
   user_decision_options: [accept, rework, increase_cap, abandon]   # legacy back-compat
   ```
3. Stop run loop. `/dtd status` displays prompt + options + default.
4. User chooses; controller acts on the option's `effect`.

**Unlimited safety**:

- Doctor WARNs on plans where any phase has `max-iterations="unlimited"` AND that phase's worker `escalate_to: user` is NOT terminal (would create true infinite loop on stuck blocker).
- Recommend: when using `unlimited`, ensure tier escalation chain has a real terminal at user.
- Steering: user can pause anytime regardless of unlimited (`/dtd pause` always works).
- Best-blocker hash detection still fires inside an unlimited phase, so genuinely stuck identical-failure loops still escalate via the failure_reason_hash acceleration.

**Iteration counter** in `state.md` Active Run Capsule (`current_iteration`) increments on each phase retry; resets on phase pass or phase reassign.

---

## Per-Run Notepad

`.dtd/notepad.md` is a compact wisdom capsule for the active run. Five sections:
`learnings`, `decisions`, `issues`, `verification`, `handoff`.

**Workers receive ONLY the `<handoff>` section** as part of their prompt prefix
(after `worker-system.md` and `PROJECT.md`, before `skills/<capability>.md`).
This replaces "send entire phase log to next worker" (token-expensive) with a
curated controller-authored summary.

Update lifecycle:

- Controller updates `notepad.md` in the canonical `/dtd run` step (o) — between tasks, never mid-flight.
- `learnings` / `decisions` / `issues` / `verification` are append-mostly. Controller may prune/compact when total file size exceeds ~4 KB.
- `handoff` section is **rewritten** before each worker dispatch — it's a snapshot of state, not history.

**Terminal lifecycle**: notepad archive/reset is one of the steps in `finalize_run(terminal_status)` (see `/dtd run` section). Called by ALL terminal exits — `COMPLETED`, `STOPPED`, `FAILED`. Steps:

1. Copy `.dtd/notepad.md` → `.dtd/runs/run-NNN-notepad.md` (creates `.dtd/runs/` if missing).
2. Reset `.dtd/notepad.md` to template state.

PAUSED is non-terminal — notepad is preserved across pause/resume.

Doctor checks:
- `notepad.md` is non-empty AND no active plan → ERROR (orphaned content from a crashed/skipped finalize_run).
- `runs/` directory exists AND has files → INFO (history available; user can grep).
- `runs/` directory file count > 100 OR total size > 10 MB → INFO (consider cleanup; v0.1.1 will add `/dtd runs prune`).

Notepad is **complementary** to `phase-history.md` (compact phase pass log) and `attempts/run-NNN.md` (immutable attempt history). Notepad is **interpretive** ("what did we learn"); the others are **factual** ("what happened").

---

## Attempt Timeline

For every worker dispatch, append an entry to `.dtd/attempts/run-NNN.md` (created on first dispatch of a run). Provides immutable history of who tried what, when, and why an attempt was superseded.

Format (one H2 per attempt, newest at bottom):

```markdown
## attempt-001-task-2.1-att-1
- task: 2.1
- phase: 2
- worker: deepseek-local
- profile: code-write
- model: deepseek-coder:6.7b
- status: done                  # pending | running | done | blocked | failed | cancelled | superseded
- started_at: 2026-05-04 19:51:12
- ended_at: 2026-05-04 19:59:24
- duration: 8m12s
- grade: GOOD
- output_paths: src/api/users.ts, src/api/users.test.ts, src/api/users.helpers.ts
- error: null
- replacement_reason: null      # set if superseded by a later attempt
```

Rules:

- **Append-only**. Once an attempt is `done`/`blocked`/`failed`/`cancelled`/`superseded`, its entry is immutable.
- Only the **current attempt** (status=`pending` or `running`) may be updated.
- If a stale attempt's worker returns late after the controller has already moved on, mark the late result as `superseded` with `replacement_reason: "late return after escalate to <new worker>"`. The late output is NOT applied.
- Attempt IDs use `att-N` suffix per (task, attempt-number-for-this-task). E.g., first attempt on task 2.1 = `att-1`, retry = `att-2`.
- `pending_attempts` in `state.md` Active Run Capsule lists IDs of currently-running attempts.

This file becomes the basis for `/dtd status` "recent attempts" widget and `phase-history.md` notes.

---

## Incident Tracking (v0.2.0a)

Every operational failure that needs **durable tracking** creates an incident. Incidents convert ad-hoc "blocked attempt" failures into queryable, resolvable records that survive across sessions.

### Files

- `.dtd/log/incidents/index.md` — append-only registry (one row per incident)
- `.dtd/log/incidents/inc-<run>-<seq>.md` — per-incident detail (created on first incident)
- `.dtd/log/incidents/` directory (gitignored under `.dtd/.gitignore` `log/`)

### Incident schema

```
inc-<run>-<seq>            # e.g. inc-001-0001
status: open | resolved | superseded | ignored | fatal
severity: info | warn | blocked | fatal
phase: pre_dispatch | dispatch | receive | parse | validate | apply | finalize
reason: <enum from awaiting_user_reason — see state.md>
recoverable: yes | user | no
side_effects: none | request_saved | response_saved | partial_apply | unknown
links:
  attempt: attempt-<run>-task-<id>-att-<n>
  worker: <worker_id>
  task: <task_id>
  phase_id: <phase_id>
created_at: <ts>
resolved_at: null
resolved_option: null
```

### Severity → state mapping (P1-3 fix from v0.2 design R1 review)

- `info` — observational. Touches `last_incident_id`, `incident_count`, `recent_incident_summary`. Does NOT touch `active_incident_id`. Does NOT fill decision capsule.
- `warn` — non-blocking notice. Same as info plus sets `active_incident_id`. Still does NOT touch `active_blocking_incident_id`. Still no decision capsule.
- `blocked` — needs user input. Sets `active_incident_id` AND `active_blocking_incident_id`. Fills decision capsule with `awaiting_user_reason: INCIDENT_BLOCKED`. `/dtd run` refused while pending.
- `fatal` — unrecoverable. Same as blocked, plus run terminates with `finalize_run(FAILED)` after user acknowledges.

### Multi-blocker policy

At most **ONE** `active_blocking_incident_id` at any time. v0.2.0a is single-dispatch
(only one task in flight per run), so a second blocker cannot arise from `/dtd run`
while one is pending — `/dtd run` is refused while `awaiting_user_decision` is set.

The second-blocker case still exists in v0.2.0a from these legal paths:

1. **Late worker return** — controller dispatched task X, marked it `pending_attempts`, then a
   transport stall caused user to manually `/dtd stop` or pause; the worker eventually replied
   with a blocker AFTER a separate first blocker was already filed. (Rare; possible if the
   first blocker came from controller-side phase like apply/finalize while a worker call was
   still in flight.)
2. **Controller-side internal failure during incident review** — e.g. `/dtd incident show`
   triggers a state read that hits a FILE_LOCKED on `.dtd/state.md`, filing a second blocker.
3. **Manual fixture injection** (test path) — a developer or test harness writes a second
   `inc-<run>-<seq>.md` directly to exercise the queue invariant without dispatching.
4. **Future v0.2.x parallel-dispatch** — once `pending_attempts` allows N>1 in flight,
   the second case becomes routine. Spec is forward-compatible.

When a second blocking incident is created via any of the paths above:

- Second incident is logged with status `open` and severity preserved.
- `last_incident_id` and `incident_count` updated.
- `active_blocking_incident_id` is NOT changed (first incident keeps the slot).
- `recent_incident_summary` includes the second.
- When user resolves the first, the second can be promoted: controller picks the **oldest** unresolved blocking incident as the next `active_blocking_incident_id`. Doctor verifies invariant.

If v0.2.0a never observes any of paths 1-3 in practice, the queue stays a forward-compat
hook: the invariant remains enforceable by doctor and the resolve/promote code path is
exercised by the test fixture (scenario 26).

### When to create an incident

Per the v0.1.1 error matrix in §Worker Dispatch / §Resource Locks / §Apply step. The blocking conditions (AUTH_FAILED, NETWORK_UNREACHABLE, RATE_LIMIT_BLOCKED, etc., DISK_FULL, FS_PERMISSION_DENIED, FILE_LOCKED, PATH_GONE, PARTIAL_APPLY, UNKNOWN_APPLY_FAILURE, WORKER_INACTIVE) all create blocking-severity incidents.

Recoverable conditions (1st-hit retries) do NOT create incidents — they resolve via the failure counter / tier ladder. If the same condition recurs and becomes blocking, that's when the incident is filed.

#### Info-severity incident triggers (non-blocking durable events)

`info` incidents are reserved for **non-blocking events worth durable tracking**. They never
populate `active_incident_id` and never block dispatch. v0.2.0a defines exactly two triggers:

1. **Tier escalation crossed** — a worker call failed and the controller escalated to the
   next tier per the fallback chain. Filed once per (task, escalation hop). Records the
   from/to worker and the failure-class enum.
2. **Repeated recoverable retry threshold** — the same recoverable condition (e.g.
   `RATE_LIMIT_BLOCKED` 1st-hit) succeeds-after-retry but has now occurred ≥ `info_threshold`
   times within the current run (default `info_threshold: 3`, configurable in
   `.dtd/config.md` under `incident.info_threshold`). The N-th occurrence files an info
   incident; subsequent occurrences in the same run do not file additional info incidents
   (rate-limited to one per (run, reason_class)).

All other recoverable 1st-hit retries do NOT create incidents. `info_threshold` only
applies to recoverable conditions; blocking conditions fire on first hit per the rule above.

`warn` incidents are for events that need user attention but don't block dispatch (e.g.
MALFORMED_RESPONSE that the controller auto-recovered from but with measurable risk).
v0.2.0a does not auto-create `warn` incidents — they are created by explicit user/test
action (`/dtd incident` future flag, or manual fixture). The `recent_incident_summary`
slot exists so future v0.2.x triggers can populate it without state-schema change.

### Cross-link integrity

Every failed/blocked attempt entry in `.dtd/attempts/run-NNN.md` MUST include:

```yaml
- status: failed | blocked
- error: <reason enum>
- incident: inc-<run>-<seq>
- side_effects: <enum>
```

Incident detail file MUST link back to attempt id. `/dtd attempt show` and `/dtd incident show` converge on the same facts. Doctor verifies bidirectional links.

### Resolve logic (P2-2 fix from v0.2 design R1 review)

`/dtd incident resolve <id> <option>`:

1. Update incident detail file: `status: resolved`, `resolved_at: <ts>`, `resolved_option: <option>`.
2. Append a row to `.dtd/log/incidents/index.md` updating the resolved row.
3. If incident's `id` equals `active_blocking_incident_id`: **clear** the field (not "decrement" — id pointer, not counter), then promote the next unresolved blocking incident (oldest first) if any exists in queue.
4. If incident's `id` equals `active_incident_id` (warn-level): clear the field, then set to next-most-recent unresolved warn incident if any (else null).
5. Decision capsule: if `active_blocking_incident_id` is now null, clear `awaiting_user_decision`, `awaiting_user_reason`, `decision_*` fields. If queue had a next blocker promoted, refill capsule with that incident's recovery options.
6. Trigger the chosen option's `effect` (e.g., `retry`, `switch_worker`, `stop`) per the original capsule's `decision_resume_action`.

### finalize_run integration

The canonical `finalize_run(terminal_status)` order in §`finalize_run` (above)
already includes step 5 "Clear incident state" inline. This appendix references
that step for completeness:

- All `open` incidents for this run are marked `superseded` (COMPLETED/STOPPED) or
  `fatal` (FAILED), with `resolved_at: <ts>`, `resolved_option: terminal_run` or
  `terminal_failed`.
- state.md `active_incident_id`, `active_blocking_incident_id`,
  `recent_incident_summary` are cleared.
- `last_incident_id` and `incident_count` are kept for cross-run reference.
- If the active decision capsule was incident-backed (`INCIDENT_BLOCKED`), the full
  capsule is cleared in the same atomic state write.

This guarantees terminal exits never leave stale active incidents that would block
future `/dtd run` invocations on a fresh plan. Doctor's incident-state checks
verify post-terminal state has no active incident pointers if `plan_status` is
COMPLETED/STOPPED/FAILED.

---

## Token Economy

Controller MUST follow:

- Worker raw output → save to `.dtd/log/exec-<run>-task-<id>.<worker>.md`. Reference path in chat, never dump raw.
- Worker prompt assembly order (canonical — same as `instructions.md` §Token Economy #2):
  1. `worker-system.md` (cached)
  2. `PROJECT.md` (cached)
  3. `notepad.md` `<handoff>` only (dynamic, NOT cached)
  4. `skills/<capability>.md` (cached)
  5. task-specific section (not cached)
  Workers receive ONLY the `<handoff>` section of notepad, not the full file.
- Context-file inline policy:
  - < 2 KB: inline as-is
  - 2-8 KB: `head -100 + tail -50 + ref:context-N.md` truncation
  - > 8 KB: NO inline. If worker has `shell-exec`/`filesystem-read`, instruct it to read directly. Else split into smaller tasks.
- Plan compaction: completed tasks → 1-line form when plan size > 8 KB.
- `work.log` events use compact grammar: `### HH:MM | <model> | <EVENT> <one-line body>`.
- Status output: table-only by default. Full details on `--full` flag or explicit `/dtd plan show --task <id>`.

Full token rules in `.dtd/instructions.md`.

---

## Status Dashboard

ASCII is the **canonical** rendering for v0.1 (deterministic across all terminals).
Unicode polish is optional and may be enabled in `config.md` if the terminal supports it.

`/dtd status` (default = `--compact`):

```
+ DTD plan-001 [RUNNING] phase 2/5 backend-api | iter 1/3 | NORMAL < GOOD | gate RETRY | ctx 61% | total 42m
| goal      e-commerce 백엔드 API + 프론트엔드 + 코드 리뷰
| current   2.1 API endpoints
| worker    deepseek-local (tier 1)   profile=code-write
| work      src/api/**
| writing   src/api/users.ts, src/api/products.ts  (live)
| locks     write files:project:src/api/**
| elapsed   total 42m | phase 8m | task 5m12s
+ recent
| * 1.1 schema 작성    [qwen-remote]   docs/schema.md         GREAT  18s
| * 1.2 ER diagram     [qwen-remote]   docs/er-diagram.md     GREAT  12s
+ queue
| -> 2.2 auth middleware    [deepseek-local]   src/auth/**
| -> 3.1 React 컴포넌트     [deepseek-local]   src/ui/**
| -> 4.1 코드 리뷰          [gpt-codex]        docs/review-001.md
+ pause anytime: /dtd pause  or  "잠깐 멈춰"
```

When an active blocking incident exists (v0.2.0a), the dashboard adds **one** compact line after `current/worker/work/writing/locks` and before `recent`:

```
| incident   inc-001-0001 blocked NETWORK_UNREACHABLE  next:retry
```

The line stays within `dashboard_width: 80` (per scenario 23 width policy). The
suffix `next:<option_id>` uses just the resolve option id (e.g. `retry`,
`switch_worker`, `stop`). The full canonical command
`/dtd incident resolve <id> <option>` is shown only in `/dtd incident show <id>`
output, and as a hint line below the dashboard:

```
+ next: /dtd incident show inc-001-0001  |  /dtd incident resolve inc-001-0001 <option>
```

This trailing hint line is wrap-friendly (rendered as a single soft-wrapped string)
and is suppressed in plan-only host mode. `--full` adds non-blocking warn incidents
(last 3) under a separate `+ recent incidents` panel. `info` incidents are NOT
shown in compact dashboard (only in `--full`'s history view).

Glyph reference (ASCII canonical):

| Concept | ASCII | Unicode (optional) |
|---|---|---|
| section header | `+` | `┌` `└` `├` |
| recent done bullet | `*` | `✓` |
| queue arrow | `->` | `→` |
| current marker | `>` | `▶` |
| pause hint | `[P]` | `⏸` |
| separator | `|` | `│` |

Flags:

- `--compact` (default): single-screen summary
- `--full`: include phase history table + recent steering + active patches + lease list
- `--plan`: same as `/dtd plan show`
- `--history`: load `phase-history.md`, render full table
- `--eval`: list eval files in `.dtd/eval/`, render most recent

Format config in `config.md`:

```markdown
- dashboard_style: ascii      # ascii (default) | unicode
- dashboard_width: 100
- progress_report: every_phase | every_task | none
- display_worker_format: alias | id | both
```

If `dashboard_style: unicode`, controller probes the terminal's encoding support; falls back to `ascii` if it can't safely render box-drawing chars.

---

## AIMemory Boundary

DTD writes to `AIMemory/work.log` only in these cases (per design §8):

1. **DTD run start** → `WORK_START` (one event)
2. **DTD run end** → `WORK_END` (one event)
3. **Durable architecture decision** → `NOTE`
4. **High-impact steering (goal materially changed)** → `NOTE`
5. **DTD run BLOCKED/FAILED** → `WORK_END` with `status=blocked|failed`
6. **Cross-agent handoff** (rare) → `HANDOFF`
7. **DTD protocol/spec changed across versions** → `NOTE`

Event format (compact):

```
### 2026-05-04 19:50 | <controller-model> | WORK_START
DTD run-001 (plan-001): "<goal first line>". <N> phases, <M> tasks, <K> workers. Plan: .dtd/plan-001.md

### 2026-05-04 22:42 | <controller-model> | WORK_END
DTD run-001 done. status=COMPLETED grade=GREAT 2h52m. <N>/<N> phases pass. Summary: .dtd/log/run-001-summary.md
```

If `AIMemory/` does not exist, DTD operates fully via `.dtd/` and emits no AIMemory events. Setup recommends but never requires AIMemory.

All phase/task/worker/iteration/eval/steering details stay in `.dtd/`. **Never write per-task or per-iteration events to `AIMemory/work.log`.**

---

## Security & Secret Redaction

This is a **first-class** policy. Violations are install-blocking errors.

1. **Never write API keys, auth headers, bearer tokens, or raw env values** to:
   - `.dtd/log/**`
   - `AIMemory/**`
   - worker prompt body (use HTTP header for auth instead)
   - `/dtd status` output
   - `/dtd plan show` output
   - any markdown displayed to user

2. **Reference env var names only**:

   ```markdown
   ✗ BAD:  api_key: sk-abc123def456...
   ✓ GOOD: api_key_env: DEEPSEEK_API_KEY
   ```

3. **Worker prompt assembly**: env var values resolved ONLY in HTTP header at dispatch time. Never substituted into prompt body. Never logged in raw form.

4. **`/dtd doctor` secret-leak detection** scans:
   - `.dtd/log/**/*.md`
   - `.dtd/state.md`
   - `AIMemory/work.log` (if present)
   - `AIMemory/handoff_*.md` (if present)

   Patterns include the ones listed under `/dtd doctor`. Plus heuristic: any string ≥ 20 chars matching `[A-Za-z0-9_/+=-]+` within 50 chars of `api_key`/`token`/`secret`/`authorization`/`bearer`.

   On detection: ERROR exit, point to file/line, suggest redaction. Do not auto-fix (user might lose context).

5. **`.gitignore` enforcement** (canonical: `.dtd/.gitignore` is the source of truth for `.dtd/` local protection):
   - **`.dtd/.gitignore`** is mandatory. Install fetches it. Covers `.env`, `tmp/`, `log/`, `eval/`, `attempts/`, `runs/`, lock dropfiles, OS noise within `.dtd/`.
   - All per-run history files (`attempts/run-NNN.md`, `runs/run-NNN-notepad.md`, `log/exec-*.md`, `eval/eval-*.md`) are local runtime history and intentionally **not** committed. Audit trail is durable on the local machine (or via separate backup).
   - **Project root `.gitignore`** is optional. Install does NOT auto-modify it for `.dtd/` itself. The `--hard` uninstall flow asks user to add `.dtd.uninstalled-*/` to root for backup-folder protection (see §`/dtd uninstall`). Otherwise doctor reports root-level coverage gaps as INFO.
   - Rationale: keeping policy in `.dtd/.gitignore` means uninstall removes it cleanly; root-level edits leave residue.

6. **Worker response**: if a worker echoes secrets in its output, controller **must redact before saving** to `.dtd/log/`. Replace matched patterns with `<REDACTED>` and append a NOTE to the log file.

---

## Adopting DTD on existing in-progress work

DTD is not greenfield-only. You can install it on a project that already has
phased development underway and bring the remaining work under DTD without
rewriting history. Three patterns, in order of effort:

### Pattern A — Forward-only (simplest, recommended)

Install DTD, then use `/dtd plan` ONLY for remaining work. Past work stays in your
code + git history; you don't try to retroactively model it.

```
1. fetch prompt.md ... apply to project   (install DTD, ~30s)
2. Fill .dtd/PROJECT.md with current project state:
     - what the project does
     - tech stack
     - what's already done (1 paragraph)
     - what's left (1 paragraph)
3. /dtd workers add  (or paste from workers.example.md)
4. /dtd mode on
5. /dtd plan "remaining: <X, Y, Z>"
6. /dtd approve  →  /dtd run
```

DTD only sees and tracks the new work. Your existing code is the starting state,
nothing else needs annotation.

### Pattern B — Hybrid retroactive (audit-friendly)

If you want the full project under DTD's audit umbrella (every phase logged,
including past), add already-done phases/tasks to the plan with `status="done"`
markings before approving:

```
1. /dtd plan "the full project goal"     (covers past + future)
2. /dtd plan show — review the DRAFT
3. Edit .dtd/plan-001.md by hand:
     - For already-completed phases/tasks:
       <task id="1.1" status="done" worker="manual" grade="GOOD"
             dur="prior-to-DTD">
         <output-paths actual="true">src/api/users.ts, src/api/users.test.ts</output-paths>
       </task>
     - Use worker="manual" or worker="controller" to signal
       "not dispatched via DTD" (safe: routing skips done tasks)
4. (Optional) Pre-populate .dtd/phase-history.md with rows for past phases:
   note="manual prior work, imported at adoption"
5. (Optional) Pre-populate .dtd/notepad.md <learnings> with prior decisions
6. /dtd approve  →  /dtd run    (only pending tasks dispatch)
```

### Pattern C — Translate an existing planning doc

If you already have your own phased planning markdown (a roadmap.md, plan.md,
etc.), translate it into DTD's XML schema in `.dtd/plan-001.md`:

1. Each top-level phase in your doc → `<phase id="N">` block
2. Each task/checkpoint → `<task id="N.M">` with `<goal>`, `<output-paths>`
3. Done items → add `status="done" worker="manual"` and fill `<output-paths actual="true">`
4. Pending items → leave `<done>false</done>`, assign `<worker>` or `<capability>`
5. Run `/dtd plan show` to verify rendering, then `/dtd approve` + `/dtd run`

Your original doc stays where it was (e.g., `docs/roadmap.md`); DTD's
`plan-001.md` becomes the executable mirror.

### Pseudo-worker validation rule

`worker="manual"` and `worker="controller"` are **pseudo-worker** annotations,
allowed ONLY on tasks already marked done. They signal "this task was completed
outside DTD's dispatch system" — controller skips them entirely (no dispatch,
no validation, no lease, no attempt entry).

Validation:

- Pending task (`<done>false</done>`) with `worker="manual"` or `worker="controller"`:
  → `/dtd doctor` ERROR `pseudo_worker_on_pending_task`. `/dtd run` refuses.
- Done task (`status="done"` AND `<done>true</done>`) with these pseudo-workers:
  → OK; routing/permission/lock checks all skipped for that task.
- Reserved word check in `/dtd doctor` is suppressed for these two values when
  used in `<worker>` of a done task. (Same words remain rejected as worker IDs
  in `workers.md` registry — only the `<worker>` field on done plan tasks
  treats them as legitimate annotations.)

This keeps `controller` reserved as a system-meaning identifier in NL routing
(per `instructions.md` Naming Resolution) while letting plan XML use it as an
adoption-history annotation. The two contexts don't conflict because plan XML
parsing happens before NL resolution.

### Best practices for adoption

- **PROJECT.md is the bridge.** Fill it with enough current state that workers
  understand the codebase without you having to repeat in every task.
- **worker="manual"** on past tasks is a clear signal in audit logs and avoids
  re-dispatch attempts.
- **phase-history.md prior rows** can use `note="adopted at <date>, prior work
  not via DTD"` for clarity.
- **Don't backfill attempt timeline** (`.dtd/attempts/run-NNN.md`) — that's
  immutable per-dispatch history; for past manual work, keep your git history
  as the audit source.
- **First run starts at the next pending task** — DTD reads `<done>true</done>`
  marks correctly and skips ahead.

### Doctor for adoption sanity

Run `/dtd doctor` after adopting:

- PROJECT.md TODO check: should pass (you filled it in)
- Plan state check: plan-001 is DRAFT or APPROVED, size ≤ 24 KB
- Path policy: any `<output-paths actual="true">` paths still exist on disk

If past tasks have `output-paths` pointing at files that no longer exist (refactored away), the doctor will WARN — fix the plan or accept the warning.

---

## v0.1.1 / v0.2 Roadmap (declared, not implemented)

These are designed-in but explicitly deferred. v0.1 has hooks in place; full
implementation is the next milestone.

### v0.1.1

- **Notepad UX enhancements** — minimal notepad already shipped in v0.1. v0.1.1 adds: search across `.dtd/runs/run-*-notepad.md` archive, structured `<learnings>` extraction across runs, and `/dtd notepad show <run-id>` query command.
- **README polish + setup walkthrough** with screenshots / animated flow.
- **`/dtd plan show --explain` mode** for first-time users (line-by-line plan walkthrough).

### v0.2 — Operations hardening + lifecycle (revised sequence including v0.2.0d Self-Update)

Revised v0.2 sub-release tree (from v0.2 design R1 + v0.2.0d addendum):

```
v0.2.0a   Incident Tracking       (R0 in progress as of 2026-05-05)
v0.2.0d   Self-Update              /dtd update — fetch latest from github with diff preview
                                    (NEW per user request; ships after 0a, before 0b/0c)
v0.2.0b   Permission Ledger       (.dtd/permissions.md ask|allow|deny)
v0.2.0c   Snapshot / Revert       (.dtd/snapshots/ + /dtd revert)
v0.2.1    Runtime Resilience      loop guard + worker session resume
v0.2.2    Compaction UX           notepad v2 7-heading
```

These are spec'd in detail in (in AIMemory archive):
- `handoff_dtd-v011-spec-design.gpt-5-codex.md` (V011-1~9)
- `handoff_dtd-v011-ops-recovery-status.gpt-5-codex.md` (V011-Ops-1~10)
- `handoff_dtd-v02-design-r1.claude-opus-4-7.md` (sequence revision)
- `handoff_dtd-v020d-design.claude-opus-4-7.md` (Self-Update addendum)

Each sub-release goes through full R-round flow (design → review → patches → GO → tag).

These are spec'd in detail in handoff_dtd-v011-spec-design.gpt-5-codex.md and
handoff_dtd-v011-ops-recovery-status.gpt-5-codex.md (in AIMemory archive).
v0.1.1 has hooks (decision capsule structure, state field placeholders); v0.2
implements the full systems.

- **Permission Decision Ledger** (V011-1): `.dtd/permissions.md` with ask|allow|deny rules per `edit/bash/external_directory/task/snapshot/revert/todowrite/question` keys. `/dtd permission list/approve/reject/rules` commands. Pending request capsule in state.md (already partially in v0.1.1 decision capsule).
- **Structured Notepad v2 handoff** (V011-2): 7-heading `<handoff>` template (Goal/Constraints/Progress/Decisions/Next Steps/Critical Context/Relevant Files), <= 1KB worker-visible.
- **Snapshot / Revert hooks** (V011-3): `.dtd/snapshots/` (gitignored), three modes per v0.2 design R1:
  - `metadata-only` — pre-apply file hash + git diff metadata. Audit-only; **never revertable** (no preimage stored). Cheapest, default for files within version control.
  - `preimage` — durable byte-for-byte snapshot of pre-apply file content. Revertable. Used for files outside git or when `revert_required: true` is set in `.dtd/permissions.md`.
  - `patch` — delta-only snapshot (forward + reverse patch). Revertable, smaller than `preimage` for large files. Mode chosen per-file based on size and policy.
  - `/dtd revert last|attempt|task` requires the affected files to be in `preimage` or `patch` mode at apply time. Files in `metadata-only` mode return `revert_unavailable_metadata_only` and the user must restore manually.
- **Worker session resume** (V011-4): `worker_session_id`, `resume_strategy: fresh|same-worker|new-worker|controller-takeover` in attempt timeline.
- **Loop guard / doom-loop detection** (V011-5): `loop_guard_status`, signature = worker+task+prompt-hash+failure-hash, threshold action ask|worker_swap|controller.
- **External directory permission** (V011-6): absolute paths trigger explicit approval.
- **Approval packet** (V011-7): `.dtd/runs/run-NNN-approval.md` written on `/dtd approve` with goal/phases/risks/path-scope frozen.
- **Status dashboard v2** (V011-8): adds `perms`, `snapshot`, `loop`, `incident` lines.
- **Incident tracking** (V011-Ops-1~3): `.dtd/log/incidents/inc-NNN.md` with reason taxonomy (NETWORK_UNREACHABLE / TIMEOUT / AUTH_FAILED / CONTEXT_HARD_CAP / PARTIAL_APPLY / LOOP_GUARD / etc.), recoverability classification, resume rules.
- **Worker-add wizard** (V011-Ops-10): conversational setup with field-by-field collection + secret redaction + ephemeral context. `/ㄷㅌㄷ qwen 워커 하나 추가해줘` pattern.

### v0.2 — Earlier roadmap items (orthogonal)

- **Category routing as a first-class layer** above worker IDs and aliases. Categories: `quick`, `deep`, `planning`, `review`, `code-write`, `visual-engineering`, `docs`, `explore`, `writing`. (v0.1 has capabilities + roles; v0.2 makes categories explicit.)
- **Hash-anchored edits** for finer-grained patch application (currently full-file replacement).
- **LSP / AST tool integration** for capable hosts (optional, not portable).
- **Streaming worker responses** with incremental file application.
- **Anthropic Messages / Gemini API direct adapters** (currently OpenAI-compat shims only).
- **A/B / consensus dispatch** (multiple workers on same task, controller picks best).
- **Distributed lock guarantees** across DTD instances for `global:` namespace.

---

## End of spec

This spec is the source of truth. NL routing and per-turn behavior live in
`.dtd/instructions.md`. Templates and examples live in `.dtd/` and `examples/`.
Test scenarios for v0.1 acceptance are in `test-scenarios.md`.
