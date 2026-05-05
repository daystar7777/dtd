# DTD reference: run-loop

> Canonical reference for `/dtd run` and `finalize_run`.
> Lazy-loaded via `/dtd help run-loop --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source). Detailed
> per-turn protocol steps live in `.dtd/instructions.md`; this file
> documents the user-facing command spec + terminal lifecycle.

## Summary

`/dtd run` executes an APPROVED or PAUSED plan. Optional flags
control bounded execution (`--until`), decision policy
(`--decision`), and attention mode (`--silent` / `--interactive`).
`finalize_run` is the shared terminal lifecycle for any
COMPLETED / STOPPED / FAILED exit.

## `/dtd run [--until <boundary>] [--decision plan|permission|auto] [--silent[=<duration>] | --interactive]`

Execute the plan. Allowed when:

- `plan_status: APPROVED` AND `pending_patch: false` → start RUNNING
- `plan_status: PAUSED` AND `pending_patch: false` → resume RUNNING
- Otherwise refused with reason

### Optional `--until <boundary>` — bounded execution

Pauses at a user-specified checkpoint instead of running to natural
completion. Boundary syntax:

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
3. Append `phase-history.md` row with `gate: user-checkpoint` and
   `note: <run_until value>`.
4. **Copy boundary to durable display fields** before clearing:
   - `last_pause_reason: run_until_boundary`
   - `last_pause_boundary: <run_until value>` (e.g., "phase:3")
   - `last_pause_at: <timestamp>`
5. Clear `run_until` and `run_until_reason` (active-run fields).
6. `/dtd status` reads `last_pause_*` to display: "Paused at
   requested boundary: phase:3 (set by user --until); next:
   /dtd run".

Resume is just `/dtd run` again (no `--until` = run to natural
completion). On resume:

- Clear `last_pause_*` fields.
- Apply a new `--until` if you want another bounded segment.

Why split active vs durable: status display must stay reliable
across resume sessions and after the active flag clears. `run_until`
is the runtime control; `last_pause_*` is the audit/display.

**Do not confuse `--until` with `pause_requested`**: `--until` is a
planned boundary set at run-time; `pause_requested` is an
interrupt. Both lead to PAUSED but the audit trail is different.

## Run loop (per task) — overview

Detailed per-turn protocol lives in `.dtd/instructions.md`. The
run loop, summarized:

1. Read `state.md` (mode, plan_status, pause_requested,
   awaiting_user_decision).
2. Read `steering.md` cursor; apply low-impact entries.
3. Check `pending_patch` (refuse new dispatch until resolved).
4. Pick next ready batch (topo + parallel-group).
5. Pre-dispatch lock partitioning.
5.5. **Permission ledger gate** (v0.2.0b R1): for the next task,
   resolve `task` key against `.dtd/permissions.md`. If `deny` →
   abort task (auto-deny audit row); if `ask` → fill
   `awaiting_user_reason: PERMISSION_REQUIRED` capsule; if
   `allow` → proceed and write `auto-allow` audit row. See
   "Permission resolution at dispatch time" below for the full
   per-key matrix.
6. For each task in batch:
   - **6.a** Build worker prompt (5-step canonical assembly +
     GSD-style reset).
   - **6.b** Context budget gate (soft 70% / hard 85% /
     emergency 95%).
   - **6.c** Dispatch (HTTP per worker registry; see workers.md).
     Pre-dispatch: resolve `tool_relay_read` /
     `tool_relay_mutating` keys per worker's `tool_runtime`
     setting. `controller_relay`/`hybrid` ⇒ both keys gated;
     `worker_native` ⇒ key gated based on tool risk class;
     `none` ⇒ no relay key check.
   - **6.d** Heartbeat lease.
   - **6.e** Receive + parse response (`::done::` / `::blocked::`).
   - **6.e.5** **Tool-request relay gate** (v0.2.0b R1): if worker
     emitted `::tool_request::` for a mutating action (write,
     exec, network), resolve `tool_relay_mutating` key first. If
     `deny` → abort relay; if `ask` → fill capsule. Read-only tool
     requests resolve against `tool_relay_read`.
   - **6.f** Validate before apply (output-paths × permission_profile
     × locks × block_patterns).
   - **6.f.0** **Edit permission gate** (v0.2.0b R1): resolve
     `edit` key against the most-specific output path. Resolve
     `external_directory` for any path outside project root. If
     either is `deny` → abort apply; if `ask` → fill capsule.
   - **6.g.0** **Snapshot creation hook** (v0.2.0c R1): BEFORE
     phase 1 temp-write. For each output path: compute SHA-256 +
     git-tracked status; pick mode per policy (see "Snapshot mode
     resolution" below); write artifact under
     `.dtd/snapshots/snap-<run>-<task>-<att>/files/<encoded-path>.<mode>`;
     append `manifest.md` + `index.md` rows. If snapshot phase
     fails (DISK_FULL / FS_PERMISSION_DENIED), honor
     `config.snapshot.on_snapshot_fail` policy (default
     `refuse_apply`); if `proceed_unsafe`, mark attempt
     `unrevertable: true` in attempts log.
   - **6.g** Apply phase 1 (write all temps) + phase 2 (rename all).
     Pre-apply: resolve `snapshot` key against ledger. Snapshot
     writes go to `.dtd/snapshots/`; bash invocations during apply
     (e.g. post-apply hooks) resolve `bash` key.
   - **6.h** Compute grade (controller-side; never worker self-grade).
   - **6.i** Append phase row to `phase-history.md`.
   - **6.j** Apply patches between tasks only.

## Permission resolution at dispatch time (v0.2.0b R1)

The 10 v0.2.0b permission keys map to specific run-loop steps:

| Key | Run-loop step | Rationale |
|---|---|---|
| `task` | 5.5 (master switch) | Before ANY worker dispatch; one resolution per task |
| `bash` | 6.c (worker shell call), 6.g (apply hook), 6.e.5 (relay) | Wherever shell exec is requested |
| `external_directory` | 6.c (read), 6.f.0 (write) | Path outside project root |
| `edit` | 6.f.0 (pre-apply) | Per output path; most-specific scope wins |
| `snapshot` | 6.g (pre-apply, between phase 1 and 2) | v0.2.0c snapshot writes |
| `revert` | `/dtd revert` command (NOT in run-loop) | User-invoked; gated separately |
| `todowrite` | 1, 2, 5, 6.i (controller-internal state writes) | Default `allow`; never blocks |
| `question` | Whenever controller fills decision capsule | User-facing question; default `ask` |
| `tool_relay_read` | 6.c (pre-dispatch), 6.e.5 (post-response) | Read-only worker tool calls |
| `tool_relay_mutating` | 6.e.5 (post-response, mutating relay) | Write/exec/network worker tools |

**Resolution semantics** (per `.dtd/permissions.md`
§Resolution algorithm): specificity-first, timestamp-second.
The most specific scope match wins; ties broken by latest
timestamp. Default rules apply only when no `## Active rule`
matches.

**Per-resolution audit row** appended to
`.dtd/log/permissions.md` (gitignored, append-only):

```text
2026-05-05T14:32:11Z | dec-007 | edit                | src/api/users.ts          | rule_match: 2026-05-05T14:00 (active) | decision: auto-allow
2026-05-05T14:32:14Z | dec-008 | bash                | rm -rf node_modules        | rule_match: 2026-05-05T14:00 (active) | decision: auto-deny
2026-05-05T14:32:18Z | dec-009 | tool_relay_mutating | shell: npm install         | rule_match: default                      | decision: asked
2026-05-05T14:32:25Z | dec-009 | tool_relay_mutating | shell: npm install         | rule_match: dec-009 (user)               | decision: user-allow
```

Audit row fields:
- `<ts>`: ISO 8601 UTC.
- `<dec_id>`: decision capsule id IF this resolution required user
  input (e.g. `dec-009`); for auto-allow / auto-deny rows that did
  not surface a capsule, use the synthetic id `auto-<run>-<seq>`.
- `<key>`: one of the 10 v0.2.0b permission keys.
- `<scope>`: the specific scope at resolution time (path, command,
  worker, capability — whichever applied).
- `rule_match`: timestamp of the matched `## Active rule`, OR
  `default` for default-rule fallback, OR `dec-NNN (user)` when
  user resolved an `ask` capsule.
- `decision`: `auto-allow | auto-deny | asked | user-allow |
  user-deny | denied-explicit-rule | revoked-after-tombstone`.

**Silent mode interaction** (v0.2.0f):
- `allow` rules auto-handle without surfacing capsule.
- `deny` rules abort immediately AND do NOT defer (deny is
  unambiguous; silent mode does not delay denials).
- `ask` rules fire `PERMISSION_REQUIRED` capsule which is
  deferred to `deferred_decision_refs` per silent algorithm.
- Transient rules from `silent_allow_*` config flags expire at
  `attention_until` or are revoked by `/dtd interactive`. See
  `autonomy.md` §"Silent transient rules (v0.2.0b R1)".

**Decision-mode interaction** (v0.2.0f):
- `decision_mode: auto` does NOT auto-resolve `ask` permission
  rules (permission-class is treated as user-required regardless
  of decision_mode).
- `decision_mode: plan` and `decision_mode: permission` follow
  the standard ask flow.
- The only auto-action gate that bypasses `ask` is when the user
  has explicitly written an `allow` rule for that scope.

## Notepad compaction + reasoning utility post-processing (v0.2.2 R1)

R1 wiring for v0.2.2 Compaction UX. Two integration points: phase
boundary compaction and per-dispatch reasoning capsule extraction.

### Phase-boundary compaction algorithm

Triggered at run-loop step 6.i (after phase row append to
`phase-history.md`). Steps:

1. **Schema detection**: read `.dtd/notepad.md`. First H2 is
   `## handoff` AND H3 children include `### Goal` → schema v2;
   else schema v1 (free-form). Schema v1 path: skip per-heading
   compaction; treat handoff as one block (legacy behavior).
2. **Free-form section pass**: for each of `## learnings`,
   `## decisions`, `## issues`, `## verification`:
   - Preserve last 3 entries (most recent).
   - Older entries summarize to ONE bullet per category
     (controller picks the most representative line).
   - If section is empty: leave empty.
3. **Handoff size check**: total size of `## handoff` H2 +
   children. If ≤ 1.2 KB: skip step 4 (no compaction needed).
4. **Per-heading priority truncation** (priority order per
   v0.2.0e/b/c Codex review patches):
   - **Step 4.a** TRUNCATE `### Progress` first → replace
     content with line: `Phase N completed; see
     phase-history.md for detail`.
   - **Step 4.b** TRUNCATE `### Relevant Files` second → keep
     last 5 path refs only.
   - **KEEP** Goal / Constraints / Decisions / Next Steps /
     Critical Context / Reasoning Notes (these are high-signal
     and not recoverable from elsewhere).
5. **Re-check size**: if still > 1.2 KB after Step 4: log WARN
   to `.dtd/log/run-NNN-summary.md`; doctor surfaces
   `notepad_handoff_oversized` next time.
6. **Atomic write**: tmp + rename per existing notepad write
   discipline.

**Manual trigger**: `/dtd notepad compact` runs the same
algorithm on demand (no phase boundary needed).

### Reasoning utility post-processing

Triggered after worker dispatch returns (run-loop step 6.e). When
the dispatched task had a v0.2.0f reasoning utility configured
(`reasoning-utility="<id>"` in plan XML; resolved into
`state.md.resolved_reasoning_utility`):

1. **Parse worker response** for compact output contract block.
   Worker prompt prefix included `<reasoning>` block with
   `output_contract: decision / evidence_refs / risks /
   next_action / lesson` (per Amendment 1).
2. **Extract structured fields**:
   - `decision`: one-line.
   - `evidence_refs`: list of `[log:..., attempt:...]` refs.
   - `risks`: short text.
   - `next_action`: one-line.
   - `lesson` (only for `reflexion` utility): one-line.
3. **Chain-of-thought leakage filter**: scan extracted content
   for narrative-reasoning patterns. If detected:
   - Pattern matches: phrases like "let me think",
     "step-by-step" (in non-list-context), multi-paragraph
     blocks > 5 lines per entry.
   - Action: redact the offending entry, log WARN to
     `.dtd/log/run-NNN-summary.md`, write a placeholder entry
     `[redacted: reasoning narrative removed per output discipline]`.
4. **Append to Reasoning Notes** in `## handoff` section:
   - Keep last 3 entries (per v0.2.2 R0 spec).
   - Older entries: roll into `## learnings` H2 section as
     one-line bullet (`<ts>: <decision> [evidence: <refs>]`).
5. **For `reasoning-utility="tree_search"`** specifically:
   write final option id + rubric score to Reasoning Notes;
   NEVER write raw candidate chains.
6. **For `reasoning-utility="reflexion"`** specifically:
   ALWAYS append a 1-line lesson entry (lesson is the durable
   output of reflexion; rolling into learnings is the
   cross-run path).

### State.md additions

```yaml
## Notepad compaction (v0.2.2 R1)
- last_compaction_at: null              # ts of last phase-boundary compaction
- last_compaction_reason: null          # null | phase_boundary | manual | finalize_run
- compaction_warns_run: 0               # count of WARN events this run (notepad_handoff_oversized after compaction)
```

These are observational; doctor checks consistency.

## Worker test runtime + session resume + loop guard (v0.2.1 R1)

Wiring for the three v0.2.1 sub-features into the run loop and the
`/dtd workers test` command.

### Worker test diagnostic runner

`/dtd workers test [<id|alias>] [--quick|--full|--connectivity|...]`
runs a sequence of probe stages per `reference/workers.md`
§"Worker Health Check (v0.2.1)". Runtime contract:

- **Observational discipline**: writes ONLY to
  `.dtd/log/worker-checks/<ts>.md`. Never mutates `state.md`,
  `notepad.md`, `attempts/run-NNN.md`. Standalone test (not
  preflight) creates NO incident, NO decision capsule, even on
  full failure.
- **Stage runner sequence**: stages 1-17 per workers.md table. On
  first FAIL, controller decides per-stage:
  - Stages 1-5 (registry/schema/secret/endpoint/network): FAIL
    blocks remaining stages (no point checking TLS if network
    failed).
  - Stages 6-13 (TLS/auth/protocol): FAIL records and continues
    (later stages may surface independent issues).
  - Stages 14-17 (tool relay / native sandbox / log write /
    diagnostic_summary): always run if reached.
- **Redaction filter** (between probe and log write): scrub env
  values, auth headers, full request body, full response body for
  failed auth/forbidden, any string ≥ 20 chars matching key
  patterns. Per `reference/workers.md` §"Redaction model".
- **Log retention**: rotate
  `.dtd/log/worker-checks/<ts>.md` files; keep most recent
  `config.worker-test.worker_test_history_retention` (default
  20). Older files purged on next test run.
- **Mock probe artifact**: stage 10 protocol probe writes to
  `.dtd/tmp/healthcheck-sentinel.txt` (parsed but NEVER applied).
  Cleanup after probe.
- **Preflight integration** at run-loop step 5.5 (BEFORE 5.5
  permission gate): if
  `config.worker-test.worker_test_auto_before_run: assigned_only`
  (default), run `--quick` on the assigned worker. On FAIL: fill
  `awaiting_user_reason: WORKER_HEALTH_FAILED` capsule (THIS is
  the only path that creates a capsule from worker test).
- **Standalone test** never creates capsule (per Codex
  observational-boundary patch).

### Session resume strategy resolver

Triggered when controller chooses to retry an attempt after
interruption. Algorithm:

1. **Fetch prior attempt** from `attempts/run-NNN.md` for the
   same task.
2. **Read prior status**: `failed | superseded | done | blocked |
   timeout | network-cut`.
3. **Read prior failure class** (from incident or attempts row):
   - `AUTH_FAILED | MALFORMED_RESPONSE | WORKER_PROTOCOL_VIOLATION`
     → strategy = `fresh` (no point reusing tainted session).
   - `TIMEOUT_BLOCKED | NETWORK_UNREACHABLE | RATE_LIMIT_BLOCKED |
     WORKER_5XX_BLOCKED` → continue to step 4.
4. **Check provider session support**: read
   `worker.supports_session_resume` field from registry. False
   (or unknown) → strategy = `fresh`.
5. **Check resume failure history**: count consecutive prior
   attempts on same task with
   `resume_strategy: same-worker AND status: failed`. If count
   ≥ 2 → strategy = `new-worker`.
6. **Check fallback chain exhaustion**: if `new-worker` would
   advance past last entry in `current_fallback_chain` → strategy
   = `controller-takeover`.
7. **All workers exhausted AND controller already attempted** →
   capsule `awaiting_user_reason: RESUME_STRATEGY_REQUIRED` with
   options `[user_pick_worker, controller_takeover, stop]`.

**Same-worker resume safety** (per Codex review): never appends
raw prior worker output, partial stream content, or private
reasoning. Only sanitized durable controller artifacts (state.md,
plan task spec, current handoff, retry hint) replay. If provider
requires replay instead of session id: replay only those
artifacts, not the previous worker transcript.

**State updates** on each retry:
- `state.md.last_worker_session_id` (provider-issued; may be null).
- `state.md.last_worker_session_provider` (provider name).
- `state.md.last_resume_strategy` (resolved value).
- `state.md.last_resume_at: <ts>`.
- `attempts/run-NNN.md` row: `resume_of: <prior att-id>`,
  `resume_strategy: <strategy>`, `worker_session_id: <or null>`.

### Loop guard signature computation

Triggered after EACH failed attempt (step 6.e or 6.f.0 fail
path). Algorithm:

1. **Compute loop_signature**:
   ```
   loop_signature = sha256(
     worker_id +
     task_id +
     prompt_hash +     # SHA of assembled worker prompt at step 6.a
     failure_hash      # SHA of redacted failure reason + first error line
   )
   ```
   Where `prompt_hash` includes the controller's prompt
   assembly (system prompt + handoff + task spec); failure_hash
   includes the failure type + first non-empty error line
   (redacted per Worker Health Check redaction model).
2. **Compare** to `state.md.loop_guard_signature`:
   - **Match**: increment `loop_guard_signature_count`.
   - **No match**: set `loop_guard_signature: <new>`,
     `loop_guard_signature_count: 1`,
     `loop_guard_signature_first_seen_at: <ts>`.
3. **Window staleness check**: if
   `loop_guard_signature_first_seen_at < now -
   config.loop-guard.loop_guard_signature_window_min` (default
   30 min): reset to `loop_guard_signature_count: 1` (ignore
   match across window).
4. **Threshold trigger**: if
   `loop_guard_signature_count >= config.loop-guard.loop_guard_threshold`
   (default 3):
   - Set `state.md.loop_guard_status: hit`.
   - Branch on `config.loop-guard.loop_guard_threshold_action`:
     - `ask` (default): fill capsule
       `awaiting_user_reason: LOOP_GUARD_HIT` with options
       `[ask_user, worker_swap, controller, stop]`.
     - `worker_swap`: advance `current_fallback_index`;
       dispatch next worker; reset signature to idle.
     - `controller`: invoke controller-takeover path
       (REVIEW_REQUIRED gate); reset signature to idle.
5. **Auto-action gate**: `decision_mode: auto` does NOT imply
   loop auto-action. Only explicit
   `loop_guard_threshold_action: worker_swap | controller`
   triggers it. `decision_mode: auto` + `threshold_action: ask` →
   capsule still fires.
6. **After resolve** (user picked option, OR auto-action ran):
   - `loop_guard_signature: null`,
   - `loop_guard_signature_count: 0`,
   - `loop_guard_status: idle`,
   - `loop_guard_last_check_at: <ts>`.

**Per-run scope**: loop guard signatures are scoped to the active
run; `finalize_run` resets to idle. Cross-run loop detection
deferred to v0.3.

### State.md addition

```yaml
## Loop guard (v0.2.1) — R1 addition
- loop_guard_signature_first_seen_at: null   # ts when current signature first matched; used for window staleness check
```

## Snapshot mode resolution (v0.2.0c R1)

Per-file mode chosen at run-loop step 6.g.0 BEFORE temp-write.
Resolution order (first match wins):

1. **File does not exist yet (new file creation)** → `metadata-only`
   (revert deletes the new file; no preimage needed since pre-state
   was "absent").
2. **Permission ledger has `revert: allow ... revert_required: true`**
   → `preimage` (user explicitly forced revertability).
3. **File extension matches
   `config.snapshot.binary_extensions`** → `preimage`
   (binary diff is unreliable).
4. **File size > `config.snapshot.preimage_size_threshold`
   (default 64 KB)** → `patch` (forward + reverse unified diff).
5. **File size > `config.snapshot.patch_max_size`
   (default 4 MB)** → `preimage` (patch overhead exceeds preimage
   for huge files; fallback for safety).
6. **File is git-tracked AND text** → `metadata-only` (audit-only;
   user can `git restore` if needed; controller cannot
   programmatically revert).
   - **Override**: small tracked text outputs from a worker apply
     SHOULD use `preimage` for revertability (per Codex v0.2.0e/b/c
     review). The `metadata-only` mode is only for explicit
     audit-only/non-output context files.
7. **Untracked text file** → `preimage` (untracked = git can't
   restore; preimage is the only restore path).
8. **Default fallback** → `preimage` (safer default than
   metadata-only).

**Manifest format** (per `snap-*/manifest.md`):

```markdown
# Snapshot snap-<run>-<task>-<att>

run: <run-id>
task: "<task-id>"
attempt: <int>
worker: <worker-id>
applied_at: <ISO 8601 UTC>
mode_default: <preimage|patch|metadata-only>     # most-common per-file mode
unrevertable: false                               # true if proceed_unsafe used

## Files

- <path>          | mode: <m> | size_pre: <bytes> | sha256_pre: <hash> | revertable: yes|no

## Reason for mode choices

- <path>: <one-line policy decision; e.g. "binary extension → preimage">

## Patch artifacts (mode: patch only)

- <path>: forward.patch + reverse.patch (both unified diff)
- patch_format_version: 1
- whitespace_handling: preserve_lf      # preserve_lf | normalize_crlf
```

**Index row format** (per `.dtd/snapshots/index.md`):

```
<applied_at> | snap-<run>-<task>-<att> | <files_count> | <mode_default> | <total_size_bytes> | <revertable_count> | <status>
```

Where `<status>` is one of `active | rotated | purged | reverted`.

## Revert algorithm (v0.2.0c R1)

Triggered by `/dtd revert <last|attempt <id>|task <id>>`. NOT part
of the run loop; runs as a user-invoked command.

**Pre-revert**:

1. **Permission gate**: resolve `revert` key against
   `.dtd/permissions.md`. `deny` → abort; `ask` → fill
   `awaiting_user_reason: PERMISSION_REQUIRED` capsule first.
2. **Confidence/destructive confirm**: `/dtd revert` is
   destructive; ALWAYS confirms with explicit user phrase per
   `instructions.md` §Confidence & Confirmation.
3. **Lock acquisition**: acquire write locks per §Resource Locks
   for every file in the target snapshot(s). Same lock set as a
   fresh apply.

**Algorithm**:

1. **Find target snapshots** by scope:
   - `last`: most recent `snap-*` for the active run (by
     `applied_at` in `index.md`).
   - `attempt <id>`: the single snapshot for that attempt.
   - `task <id>`: all snapshots for attempts of that task,
     where `attempts/run-NNN.md` row has `applied: true`.
     Superseded attempts (no apply, only dispatch) skipped.
2. **Validate every listed file** in target manifest(s):
   - `preimage`: artifact file exists AND its SHA-256 matches
     `manifest.md` `sha256_pre` for the path.
   - `patch`: reverse patch dry-run applies cleanly to current
     state (no conflict).
   - `metadata-only`: NOT revertable; collect into
     `revert_unavailable_metadata_only` list.
3. **Decision branching**:
   - All revertable + user confirmed → proceed to apply.
   - Some non-revertable → fill capsule
     `awaiting_user_reason: PARTIAL_REVERT` with options
     `[revert_revertable_only, inspect, cancel]`. User chooses;
     controller acts.
4. **Apply phase 1**: write reverted content to temp files.
   - `preimage`: copy artifact to `<path>.dtd-revert-tmp.<pid>`.
   - `patch`: apply reverse patch in memory; write result to
     temp.
5. **Apply phase 2**: atomic rename over current files. Same
   atomicity as a fresh apply.
6. **For `task <id>` (multi-snapshot)**: revert applies in
   REVERSE order (most recent attempt first). Files modified
   across multiple attempts restore correctly because each
   snapshot captured pre-apply state.
7. **State updates**:
   - `state.md.last_revert_id: snap-<run>-<task>-<att>` (most
     recent if multi).
   - `state.md.last_revert_at: <ts>`.
   - `attempts/run-NNN.md` row appended:
     `reverted: snap-<run>-<task>-<att>` for each touched
     snapshot.
   - `phase-history.md` row appended.
   - `index.md` row updated: status `active` → `reverted` for
     touched snapshots.
8. **Audit-log**: one `revert` row per file restored:
   ```
   <ts> | dec-NNN | revert | <path> | rule_match: <ts of revert allow rule> | decision: user-allow
   ```

**Rollback within revert** (extreme edge case): if phase 2
atomic rename fails partway (rare; e.g. disk full mid-rename):

- Mark the run state as `partial_revert: <list of paths
  successfully reverted>`.
- Fill capsule
  `awaiting_user_reason: PARTIAL_APPLY` (reuses existing v0.1.1
  capsule reason; semantically a revert is also an apply).
- User chooses: continue revert with retry, accept partial, or
  manually restore.

## `finalize_run(terminal_status)` — shared terminal lifecycle

**Required by ALL terminal exits**: COMPLETED (run loop end),
STOPPED (`/dtd stop`), FAILED (unrecoverable error, e.g. all
workers dead). NOT called for PAUSED (pause is non-terminal).

Order (atomic from controller's POV — execute ALL steps before
responding to user):

1. **Release leases**: scan `resources.md` for any leases owned by
   this run; remove all. Cancel any in-flight heartbeat.
2. **Archive notepad**: copy `.dtd/notepad.md` →
   `.dtd/runs/run-NNN-notepad.md`. Create `.dtd/runs/` if missing.
3. **Reset notepad**: replace `.dtd/notepad.md` content with the
   template state (5 sections, all `(empty)`).
4. **Write run summary**: `.dtd/log/run-NNN-summary.md` with phase
   grades / output paths / duration / final grade.
5. **Clear incident state** (v0.2.0a):
   - For every incident in `.dtd/log/incidents/index.md` belonging
     to this run with `status=open`:
     - On `terminal_status=COMPLETED` or `STOPPED` → set
       `status: superseded`, `resolved_at: <ts>`,
       `resolved_option: terminal_run`.
     - On `terminal_status=FAILED` → set `status: fatal`,
       `resolved_at: <ts>`, `resolved_option: terminal_failed`.
   - Update each affected `.dtd/log/incidents/inc-<run>-<seq>.md`
     detail file accordingly.
   - In state.md (held for the step-7 atomic write below): clear
     `active_incident_id`, `active_blocking_incident_id`,
     `recent_incident_summary`. Keep `last_incident_id` and
     `incident_count` for cross-run reference.
   - If `awaiting_user_decision` was an incident-backed reason
     (`INCIDENT_BLOCKED`), also clear `awaiting_user_decision`,
     `awaiting_user_reason`, `decision_id`, `decision_prompt`,
     `decision_options`, `decision_default`, `decision_resume_action`,
     `decision_expires_at`, `user_decision_options` as part of
     step 7.
5b. **Clear attention/context-pattern state** (v0.2.0f):
   - Clear `resolved_context_pattern`, `resolved_handoff_mode`,
     `resolved_sampling`, `last_context_reset_at`,
     `last_context_reset_reason`. These describe an in-flight
     dispatch and do not survive terminal exit.
   - Clear `deferred_decision_refs` and `deferred_decision_count`:
     - On `terminal_status=COMPLETED`: any remaining deferred refs
       MUST already be resolved (otherwise the run would have
       paused on silent_window_ended_no_ready_work). If non-empty
       here, mark the underlying incidents as `superseded` (same
       as step 5) and clear.
     - On `terminal_status=STOPPED|FAILED`: mark the underlying
       incidents per the step-5 rule (`superseded`/`fatal`), then
       clear.
   - Reset `attention_mode: interactive`,
     `attention_mode_set_by: default`, `attention_until: null`,
     `attention_goal: null`. Silent windows do not survive
     terminal exits — the next `/dtd plan` starts fresh in
     interactive mode.
   - If `decision_mode_set_by: run_flag`, reset `decision_mode` to
     `config.decision-policy.default_decision_mode` and
     `decision_mode_set_by: default`. `/dtd run --decision <mode>`
     is a run-scoped override.
   - If `decision_mode_set_by: user`, keep `decision_mode` across
     terminal exits. `/dtd mode decision <mode>` is the project
     preference path.
   - Clear `resolved_controller_persona`,
     `resolved_worker_persona`, `resolved_reasoning_utility`, and
     `resolved_tool_runtime`. These are per-dispatch/per-phase
     controls, not terminal state.
6. **Append AIMemory `WORK_END`** (only if AIMemory present):
   one-line event with
   `status=<terminal_status> grade=<final_grade> <duration>`. Per
   §AIMemory Boundary.
7. **Update state.md**: `plan_status: <terminal_status>`,
   `plan_ended_at: <ts>`, clear `current_task`/`current_phase`/
   `pending_patch`/`pending_attempts` fields, plus the
   incident-state clears from step 5, plus the decision-capsule
   clears from step 5 if applicable. Set `last_update`. Single
   atomic tmp-rename write.

If any step fails partway, the controller logs an
`ORPHAN_RUN_NOTE` to `AIMemory/work.log` (if present) describing
what was completed vs not, and prints a recovery hint to the user.
Doctor's "orphaned notepad content" check catches the most common
failure (step 3 not executed).

## Anchor

This file IS the canonical source for `/dtd run` command spec
(including `--until` boundary semantics) and `finalize_run`
terminal lifecycle. The detailed per-turn protocol (run loop
steps 6.a-j with full validation and apply rules) is sourced from
`.dtd/instructions.md`.
v0.2.3 R1 extraction completed; `dtd.md` §`/dtd run` and
§`finalize_run(terminal_status)` now point here.

## Related topics

- `incidents.md` — failures during dispatch/apply produce
  incidents.
- `autonomy.md` — silent mode ready-work algorithm controls when
  loop pauses.
- `plan-schema.md` — plan XML drives the run loop dispatch.
- `workers.md` — dispatch transport for step 6.c-e.
- `perf.md` — controller usage ledger writes during run loop.
