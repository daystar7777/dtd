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
- DTD install: all 15 `.dtd/` template files + `dtd.md` present (instructions.md, config.md, workers.md, worker-system.md, resources.md, state.md, steering.md, phase-history.md, PROJECT.md, notepad.md, .gitignore, .env.example, plus 3 skills/*.md)
- Host always-read pointer: present and references `.dtd/instructions.md`
- `dtd.md` present at host slash command dir (Claude Code: `.claude/commands/dtd.md`, etc.)

**Mode consistency**:
- `.dtd/state.md` has `mode: off|dtd` (DTD activation, separate from host capability)
- `.dtd/state.md` has valid `host_mode: plan-only|assisted|full`
- `.dtd/config.md` `host.mode` matches `state.md host_mode`
- Probed capabilities currently match the recorded `host_mode` (re-detect available)

**Worker registry**:
- `workers.md` parses; only H2 sections OUTSIDE `<!-- ... -->` example blocks count as registry
- Disabled (`enabled: false`) entries reported but skipped in routing
- Alias collisions: worker alias vs other worker, alias vs role, alias/display_name vs `controller.name`
- Reserved word usage rejected (`controller, user, worker, self, all, any, none, default`)
- Threshold consistency: `failure_threshold` is positive int per worker
- `escalate_to` chain: no cycles, terminates at `user`
- Capabilities reasonable: at least one worker for each role declared in `config.md` `roles`
- If active registry empty: WARN, recommend `/dtd workers add`

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
- `add`: interactive add — id, endpoint, model, api_key_env, max_context, capabilities, tier, failure_threshold, escalate_to
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

### `/dtd run`

Execute the plan. Allowed when:

- `plan_status: APPROVED` AND `pending_patch: false` → start RUNNING
- `plan_status: PAUSED` AND `pending_patch: false` → resume RUNNING
- Otherwise refused with reason

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
      - If estimate ≥ `emergency_context_limit` (default 95%): emergency checkpoint, mark `state.md` `awaiting_user_decision: true` AND `awaiting_user_reason: CONTEXT_EXHAUSTED`, stop for controller/user decision. `/dtd status` displays the reason.
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
   g. Apply file changes (mode `assisted` may confirm; mode `full` auto-applies).
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
5. **Append AIMemory `WORK_END`** (only if AIMemory present): one-line event with `status=<terminal_status> grade=<final_grade> <duration>`. Per §AIMemory Boundary.
6. **Update state.md**: `plan_status: <terminal_status>`, `plan_ended_at: <ts>`, clear `current_task`/`current_phase`/`pending_patch`/`pending_attempts` fields, set `last_update`.

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
5. **User escalation** — `escalate_to: user` is terminal. Set `state.md` `awaiting_user_decision: true`, `awaiting_user_reason: ESCALATION_TERMINAL`, `user_decision_options: [accept, rework, abandon]`. `/dtd status` displays the reason.

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
  "temperature": 0.0,
  "max_tokens":  <reserved_output_budget>,
  "stream":      false
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

| HTTP status / condition | Action |
|---|---|
| 200 OK | Parse response, proceed to validation step (run loop step 6.f) |
| 401 unauthorized | Abort dispatch. Prompt user: "auth failed, check env var `<api_key_env>`". Mark attempt `blocked`, reason `auth_failed`. **Never log the key value.** |
| 403 forbidden | Abort. Recommend `/dtd doctor` (likely endpoint config wrong). |
| 404 not found | Abort. Endpoint URL wrong; recommend `/dtd workers test <id>`. |
| 429 rate limit | Wait `Retry-After` header (or default 30s), retry ONCE, then mark attempt `failed` with reason `rate_limit`, escalate per ladder. |
| 5xx server error | Wait 5s, retry ONCE, then mark attempt `failed` with reason `worker_5xx`, escalate. |
| Timeout (`worker.timeout_sec`) | Mark attempt `failed`, reason `timeout`. failure_reason_hash = "timeout". |
| Network unreachable | Mark attempt `failed`, reason `network`. Recommend `/dtd doctor` + check `/dtd workers test <id>`. |
| JSON parse error | Mark attempt `failed`, reason `malformed_response`. Save raw to log for inspection. |

All failures append entry to `.dtd/attempts/run-NNN.md` per §Attempt Timeline.

### Streaming (v0.2)

v0.1 sets `stream: false`. Streaming (`stream: true`, SSE response) is deferred to v0.2 for partial file application during long generation. Until then: full response or nothing.

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
2. Set `state.md` `awaiting_user_decision: true`, `awaiting_user_reason: MAX_ITERATIONS_REACHED`, `user_decision_options: [accept, rework, abandon, increase-cap]`.
3. Stop run loop. Display reason + options to user.
4. User chooses:
   - `accept` — current grade kept, advance to next phase
   - `rework` — reset iteration counter, try again (with optional steering hint)
   - `abandon` — call `finalize_run(STOPPED)`
   - `increase-cap N` — bump `max-iterations` to N (or `unlimited`), continue

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

## v0.1.1 / v0.2 Roadmap (declared, not implemented)

These are designed-in but explicitly deferred. v0.1 has hooks in place; full
implementation is the next milestone.

### v0.1.1

- **Notepad UX enhancements** — minimal notepad already shipped in v0.1. v0.1.1 adds: search across `.dtd/runs/run-*-notepad.md` archive, structured `<learnings>` extraction across runs, and `/dtd notepad show <run-id>` query command.
- **README polish + setup walkthrough** with screenshots / animated flow.
- **`/dtd plan show --explain` mode** for first-time users (line-by-line plan walkthrough).

### v0.2

- **Category routing as a first-class layer** above worker IDs and aliases. Categories: `quick`, `deep`, `planning`, `review`, `code-write`, `visual-engineering`, `docs`, `explore`, `writing`. Users say "explore에 시켜" and routing maps to a worker registered for that category. (v0.1 already supports `capabilities` + `roles`; v0.2 adds the explicit category layer.)
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
