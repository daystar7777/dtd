# DTD reference: v030c-consensus

> Canonical reference for v0.3.0c Multi-worker consensus dispatch.
> Lazy-loaded via `/dtd help v030c-consensus --full`. Not auto-loaded.
>
> Per-sub-release lazy-loaded topic per the Codex v0.3.0e/b review
> recommendation: v0.3+ runtime contracts use new reference topics
> rather than expanding cross-cutting `run-loop.md`.

## Summary

For high-stakes tasks (critical refactor, security review, ambiguous
spec interpretation), users may want N workers to attempt the same
task in parallel and the controller picks the best output via a
configured selection strategy.

v0.3.0c adds a **consensus mode** opt-in via plan XML
(`<task consensus="N">`). N workers dispatch in parallel into
ISOLATED staging artifacts (Codex P1.4: never apply to project
files directly until winner is selected). Controller picks the
winner via configured strategy, then validates / permission-checks /
snapshots / applies ONCE.

Selection strategies (4):
- `first_passing` — first worker to return `::done::` wins; later
  cancelled.
- `quality_rubric` — controller scores each per
  `config.consensus.rubric`; highest score wins.
- `reviewer_consensus` — designated reviewer worker picks from N
  candidate outputs.
- `vote_unanimous` — all N must agree on file content (after
  whitespace normalization); else CONSENSUS_DISAGREEMENT capsule
  fires.

Consensus is permission-gated by `task_consensus` key
(Codex P1.5: full 11-key invariant update; permission ledger
expanded from v0.2.0b 10-key set).

## Plan XML attributes

```xml
<phase id="3" name="security-review" target-grade="GREAT" max-iterations="3">
  <task id="3.1" parallel-group="A" consensus="3"
        consensus-strategy="reviewer_consensus"
        consensus-reviewer="codex-review">
    <goal>review src/auth/jwt.ts for OWASP issues</goal>
    <worker>deepseek-local</worker>
    <consensus-workers>deepseek-local, qwen-remote, claude-api</consensus-workers>
    <work-paths>src/auth/**</work-paths>
    <output-paths predicted="true">docs/security-review-3.1.md</output-paths>
    <done>false</done>
  </task>
</phase>
```

Schema additions:

| Attribute | Allowed values | Required when |
|---|---|---|
| `consensus="<N>"` | `1` (default; single-worker) or `2..max_consensus_n` | always optional |
| `consensus-strategy="<id>"` | `first_passing \| quality_rubric \| reviewer_consensus \| vote_unanimous` | when `consensus > 1` |
| `consensus-reviewer="<worker_id>"` | any worker_id with `review` capability AND distinct from all candidate workers | strategy = `reviewer_consensus` |
| `<consensus-workers>` | comma-list of worker_ids | when `consensus > 1`; if fewer than N, fallback chain fills the rest |

Default per `config.consensus.default_strategy` if
`consensus-strategy` omitted. `max_consensus_n` (default 5) caps N
hard; plan-validation doctor errors above this.

## Permission key (Codex P1.5)

The v0.2.0b 10-key permission set expands to **11 keys** in v0.3.0c:

```
edit, bash, external_directory, task, snapshot, revert,
todowrite, question, tool_relay_read, tool_relay_mutating,
task_consensus  ← NEW (v0.3.0c)
```

`task_consensus` default rule: `ask | task_consensus | scope: *`.

Resolution at run-loop step 5.5 (after `task` key resolves):
- If task has `consensus > 1`: ALSO resolve `task_consensus` key
  against ledger.
- `deny` → abort consensus dispatch (fall back to single-worker
  per `<worker>` element if the user wants forward progress).
- `ask` → fill PERMISSION_REQUIRED capsule first.
- `allow` → proceed to consensus dispatch.

User opts in via:
```
/dtd permission allow task_consensus scope: *
/dtd permission allow task_consensus scope: phase:3 plan: <id>
```

**Invariant update sites** (per Codex P1.5: "fully update every
invariant"):
- `.dtd/permissions.md` `## Default rules`: 10 → 11 keys.
- `dtd.md` `/dtd permission` body Permission keys table: 10 → 11.
- `.dtd/reference/doctor-checks.md` `## Permission ledger
  (v0.2.0b)`: enumerate 11 keys.
- `scripts/check-v020b.ps1`: preserves the v0.2.0b 10-key base
  permission coverage and documents that v0.3.0c adds the 11th key.
- `scripts/check-v030c.ps1`: NEW; validates `task_consensus` and
  the full 11-key contract.
- `test-scenarios.md`: scenarios that enumerate keys updated.

## Run-loop integration

New step 5.5.5 (between permission gate and dispatch):

**5.5.5 — Consensus check (v0.3.0c)**:
1. If active task has `consensus > 1`:
   - Resolve `task_consensus` permission key per ledger
     (`deny` aborts; `ask` fills capsule; `allow` proceeds).
   - Validate `consensus-reviewer` (when strategy =
     `reviewer_consensus`) is DISTINCT from all
     `<consensus-workers>` entries (no self-review). Per Codex
     P1 additional: enforce at plan-XML doctor check, not at
     dispatch.
   - Resolve N workers from `<consensus-workers>` element +
     fallback chain (if fewer than N supplied).
   - Compute combined cost estimate (N × per-worker estimate).
     In `host.mode: assisted` AND
     `consensus_confirm_each_call: true`: surface confirm
     prompt with N × cost.
   - Branch run-loop step 6 → step 6.consensus.
2. If `consensus = 1` (default): existing single-worker dispatch.

**Step 6.consensus** (replaces step 6 for consensus tasks):

- **6.consensus.a**: Build N copies of worker prompt (identical
  except `worker_id` field). Stage N attempt entries in
  `attempts/run-NNN.md` with `consensus-group: <task_id>-att-N`.
- **6.consensus.b**: Acquire output-path lock for the consensus
  group (Codex P1.4: "controller or consensus group owns
  output-path lock until winner is selected"). Single lock
  covers all N workers.
- **6.consensus.c**: Dispatch all N in parallel. Each worker
  writes to ISOLATED staging directory:
  `.dtd/tmp/consensus-<run>-<task>-<att>-<worker>.staged/`
  (Codex P1.4: "candidate outputs into isolated
  staging/attempt artifacts only; no candidate may apply
  directly").
- **6.consensus.d**: Heartbeat all N leases.
- **6.consensus.e**: Receive all N responses (or per-worker
  timeout). Parse `::done::` / `::blocked::`. Record per-worker
  outcomes.
- **6.consensus.f**: Apply selection strategy:
  - `first_passing`: first `::done::` wins. Cancel remaining
    in-flight workers (provider abort if supported, else
    mark stale upon late return). LATE RESULTS MUST NEVER
    APPLY (Codex P1.4).
  - `quality_rubric`: controller scores each candidate per
    `config.consensus.rubric` weights; highest score wins.
  - `reviewer_consensus`: invoke `consensus-reviewer` worker
    with all N outputs in a special review prompt; reviewer
    returns winner id. Reviewer attempt logged separately.
  - `vote_unanimous`: file-content equality after whitespace
    normalization (per
    `config.consensus.whitespace_normalization_for_vote`). If
    all N agree, apply. If any disagree: fill capsule
    `awaiting_user_reason: CONSENSUS_DISAGREEMENT`.
- **6.consensus.g**: Validate winner output (existing step 6.f
  output-paths × permission_profile × locks × block_patterns).
  Apply step 6.f.0 edit permission gate. Then step 6.g.0
  snapshot creation hook (v0.2.0c R1) — ONCE on the winner.
  Then step 6.g phase 1 + 2 atomic apply.
- **6.consensus.h**: Compute grade (controller-side; never
  worker self-grade).
- **6.consensus.i**: Append phase row to `phase-history.md`.
  All N attempts logged in `attempts/run-NNN.md`:
  - Winner: `consensus_winner: true`, `applied: true`.
  - Losers: `consensus_loser: true`, `superseded`.

**Group lock semantics**:
- Single output-path lock for the consensus group, NOT per-worker.
- Other tasks blocked from same paths until consensus completes.
- Lock released after step 6.consensus.g apply OR on
  consensus-group abort.

**Cancellation of late results**:
- For `first_passing`: as soon as winner returns, controller
  attempts provider-side abort for remaining N-1 workers
  (provider-specific; HTTP cancel, stream close, etc.).
- For workers that don't support cancellation: mark attempt
  `consensus_late_stale` upon return; output discarded; never
  applied to project files.

## Decision capsules

```yaml
awaiting_user_reason: CONSENSUS_DISAGREEMENT
decision_id: dec-NNN
decision_prompt: "Consensus task <task_id> with strategy `vote_unanimous`: <N> workers, <D> distinct outputs. How to proceed?"
decision_options:
  - {id: reviewer_pick,   label: "let reviewer worker pick",       effect: "dispatch reviewer with N outputs",        risk: "reviewer may pick wrong"}
  - {id: controller_pick, label: "controller picks",               effect: "controller-takeover; REVIEW_REQUIRED",    risk: "no worker grade"}
  - {id: retry_all,       label: "re-dispatch all N workers",      effect: "fresh dispatch for all N",                risk: "may disagree again"}
  - {id: stop,            label: "stop the run",                   effect: "finalize_run(STOPPED)",                   risk: "lose run"}
decision_default: reviewer_pick

awaiting_user_reason: CONSENSUS_PARTIAL_FAILURE
decision_id: dec-NNN
decision_prompt: "Consensus task <task_id>: <S> of <N> workers succeeded; <F> failed. How to proceed?"
decision_options:
  - {id: accept_majority, label: "accept majority result",         effect: "use winner from S successful candidates", risk: "fewer signals"}
  - {id: retry_failed,    label: "retry failed workers only",      effect: "re-dispatch only the F failures",         risk: "may fail again"}
  - {id: stop,            label: "stop the run",                   effect: "finalize_run(STOPPED)",                   risk: "lose run"}
decision_default: accept_majority
```

## /dtd consensus command

```text
/dtd consensus show <task_id>          # observational; show all N outcomes
/dtd consensus show --active           # observational; show currently-active consensus
```

Read-only; no mutations. NL routing in dtd.md /dtd consensus
section (English) + locale packs (Korean / Japanese in R1+).

## Config

```yaml
## consensus (v0.3.0c)

- default_strategy: reviewer_consensus    # first_passing | quality_rubric | reviewer_consensus | vote_unanimous
- consensus_confirm_each_call: true       # always confirm N× cost in assisted host mode
- max_consensus_n: 5                      # hard cap; plan-XML doctor errors above
- consensus_lock_acquire_timeout_sec: 30  # how long to wait for output-path lock before aborting consensus group
- whitespace_normalization_for_vote: true # for vote_unanimous strategy
- rubric:                                 # for quality_rubric strategy
    - {key: output_paths_match, weight: 0.4}
    - {key: sentinel_match,     weight: 0.3}
    - {key: line_count_match,   weight: 0.2}
    - {key: no_protocol_violation, weight: 0.1}
- late_result_action: discard             # discard | log_and_discard
```

## State.md additions

```yaml
## Consensus state (v0.3.0c)

- active_consensus_task: null            # null | <task_id>; non-null during 6.consensus
- active_consensus_n: 0                   # how many workers dispatched
- active_consensus_strategy: null         # null | first_passing | quality_rubric | reviewer_consensus | vote_unanimous
- active_consensus_group_lock: null       # null | <output-path-set hash>; held during dispatch
- consensus_outcomes: []                  # per-attempt rows: {worker, status, score, winner: bool, late_stale: bool}
```

Cleared at task completion or `finalize_run`.

## Doctor checks

- Plan XML `consensus="<N>"` attributes: N >= 1; ELSE ERROR
  `plan_consensus_invalid`.
- Plan XML `consensus="<N>"` AND N > `config.max_consensus_n`:
  ERROR `plan_consensus_exceeds_max`.
- Plan XML `consensus-strategy="reviewer_consensus"` requires
  `consensus-reviewer="<worker>"`; ELSE ERROR
  `plan_consensus_reviewer_missing`.
- `consensus-reviewer` MUST be DISTINCT from all
  `<consensus-workers>` entries (no self-review per Codex P1
  additional); ELSE ERROR
  `plan_consensus_reviewer_in_candidate_set`.
- `<consensus-workers>` workers must exist in registry; ELSE
  ERROR `plan_consensus_unknown_worker`.
- `consensus-strategy` value MUST be one of
  `first_passing | quality_rubric | reviewer_consensus |
  vote_unanimous`; ELSE ERROR `plan_consensus_strategy_invalid`.
- `state.md.active_consensus_task` non-null AND no
  `attempts/run-NNN.md` rows match the active consensus group:
  WARN `consensus_state_drift`.
- Consensus loser attempt rows have `applied: true`: ERROR
  `consensus_loser_applied_violation` (P1.4: only winner may
  apply; losers MUST NOT).
- Late-stale attempt rows have `applied: true`: ERROR
  `consensus_late_stale_applied_violation` (Codex P1.4: late
  results MUST NEVER apply).
- 11-key permission set: `task_consensus` present in
  `.dtd/permissions.md` `## Default rules`; ELSE ERROR
  `permission_task_consensus_missing` (v0.3.0c invariant).

## Test scenarios

Scenarios 134-141 land in `test-scenarios.md`:

134. Plan with consensus="3" dispatches to 3 workers in parallel
     into isolated staging dirs.
135. first_passing strategy: first ::done:: wins; cancellation
     attempted; late results marked stale, never applied.
136. reviewer_consensus: reviewer worker invoked with N
     outputs; picks one; reviewer must be distinct (doctor
     ERROR if not).
137. vote_unanimous: 3 agreeing outputs apply; 1 disagreement
     fires CONSENSUS_DISAGREEMENT capsule.
138. CONSENSUS_PARTIAL_FAILURE: 2 of 3 workers succeed; user
     picks accept_majority.
139. Cost confirm in assisted host mode shows N× per-worker
     estimate.
140. Permission `task_consensus deny` blocks consensus dispatch
     entirely (falls back to single-worker per `<worker>` only
     if user opts in via separate plan edit).
141. Group lock prevents other tasks from racing on same output
     paths during consensus dispatch.

## /dtd plan show + /dtd status --plan render consensus annotations

Per Codex P1 additional amendment: `/dtd plan show` annotates
consensus tasks with cost multiplier:
```
- 3.1 [consensus=3 reviewer_consensus] review src/auth/jwt.ts [3× cost]
```

`/dtd status --plan` shows the same in compact form.

## R1 runtime contract

R0 (commit `be948b5` + Codex review patches `1ab11f3`) shipped the
plan XML attributes, 4 selection strategies, group lock semantics,
staged-output isolation, late-result-never-apply invariant,
11-key permission invariant (`task_consensus`), 11 doctor codes,
and `/dtd consensus show` command.

R1 ships the runtime algorithms that turn the spec into a working
parallel dispatch:

### R1.1 — Parallel dispatch algorithm (step 6.consensus.c)

```
dispatch_consensus(task, workers, group_lock):
  futures = []
  for worker in workers:
    staged_dir = ".dtd/tmp/consensus-{run_id}-{task_id}-{att_id}-{worker.id}.staged/"
    ensure_dir(staged_dir)
    prompt = build_worker_prompt(task, worker)
    fut = dispatch_async(
      worker = worker,
      prompt = prompt,
      output_redirect = staged_dir,        # candidate writes here, NOT real output_path
      lease_id = "{group_lock_id}-{worker.id}",
      heartbeat_callback = on_consensus_heartbeat,
    )
    futures.append({worker, fut, started_at: now_utc(), staged_dir})

  set_state("active_consensus_task", task.id)
  set_state("active_consensus_n", len(workers))
  set_state("active_consensus_strategy", task.strategy)
  set_state("active_consensus_group_lock", group_lock.id)
  set_state("consensus_outcomes", [])

  return futures
```

Concurrency model: N futures share the SINGLE group lock; per-worker
lease ids derive from the group lock id (audit trail) but the lock
itself is owned by the group, not divided.

### R1.2 — Lock acquisition algorithm (step 6.consensus.b)

```
acquire_consensus_group_lock(task, output_paths):
  lock_id = "consensus-{run_id}-{task_id}-{att_id}"
  deadline = now_utc() + config.consensus_lock_acquire_timeout_sec  # default 30

  while now_utc() < deadline:
    for path_glob in output_paths:
      conflicting = find_active_locks(path_glob)
      if conflicting:
        sleep(0.5)
        break_inner  # retry from top of paths
    else:
      # All paths free — claim lock with a single resources.md row.
      append_lock(lock_id, output_paths, owner="consensus_group", ttl_sec=task.timeout)
      return lock_id

  # Deadline hit; cannot start consensus.
  return None  # caller fills CONSENSUS_LOCK_TIMEOUT capsule
```

NEW R1 capsule reason: `CONSENSUS_LOCK_TIMEOUT` (added to
`awaiting_user_reason` enum). Options
`[wait_more, retry_lock, demote_single, stop]`.

### R1.3 — Per-worker timeout & in-flight cancellation

```
on_consensus_heartbeat(future, now_utc):
  if future.last_response_ts < now_utc - worker.heartbeat_threshold:
    record_outcome(future.worker, status="timeout")
    cancel_inflight(future)            # provider abort if supported

cancel_inflight(future):
  if future.transport.supports_abort():
    future.transport.abort()           # HTTP cancel / stream close
    record_outcome(future.worker, status="cancelled_inflight")
  else:
    # Worker doesn't support cancellation; wait for return then mark stale.
    future.cancellation_pending = true
```

When a `future.cancellation_pending: true` future returns: the
output is marked `consensus_late_stale: true` in
`attempts/run-NNN.md` AND its staging dir is deleted in
`cleanup_staging()`. Per Codex P1.4: late results MUST NEVER apply.

### R1.4 — Selection strategy algorithms (step 6.consensus.f)

#### `first_passing`

```
strategy_first_passing(futures):
  for future in await_first_completing(futures):
    if future.outcome == "::done::":
      cancel_inflight(future for future in futures if future != winner)
      return Winner(future)
  return None  # no worker passed; fall back to CONSENSUS_PARTIAL_FAILURE
```

#### `quality_rubric`

```
strategy_quality_rubric(futures, rubric):
  await_all(futures)
  scores = {}
  for future in futures:
    score = 0
    for rule in rubric:        # 4 rules from config.consensus.rubric
      if rule.matches(future.outcome, future.staged_dir):
        score += rule.weight
    scores[future.worker.id] = score

  winner = max(scores, key=scores.get)
  if scores.values().distinct_count() == 1:
    # All tied — fall through to CONSENSUS_DISAGREEMENT
    return None
  return Winner(winner)
```

Rubric rule semantics (from config):
| Key | Weight | Match condition |
|---|---:|---|
| `output_paths_match` | 0.4 | All declared `<output-paths>` exist in staged dir |
| `sentinel_match` | 0.3 | Output ends with `::done::` sentinel + valid grade |
| `line_count_match` | 0.2 | Diff size within ±20% of plan estimate |
| `no_protocol_violation` | 0.1 | Worker prompt-XML protocol clean |

#### `reviewer_consensus`

```
strategy_reviewer_consensus(futures, reviewer_worker):
  await_all(futures)

  # Build review prompt with all N candidate outputs.
  review_prompt = render_template("reviewer_consensus.txt", {
    task: task,
    candidates: [{worker_id, staged_dir, outcome} for f in futures],
  })

  reviewer_outcome = dispatch_sync(
    worker = reviewer_worker,
    prompt = review_prompt,
    timeout_sec = config.consensus_reviewer_timeout_sec,  # default 120
  )

  # Parse reviewer response: expects ::winner: <worker_id>:: token.
  winner_id = parse_winner(reviewer_outcome.text)
  if not winner_id or winner_id not in [f.worker.id for f in futures]:
    return None  # malformed reviewer response -> CONSENSUS_DISAGREEMENT

  return Winner(find_future(winner_id))
```

Reviewer prompt template (R1 contract; lives in
`.dtd/skills/consensus-reviewer.md`, NEW skill file, R1 ship):

```markdown
# Consensus reviewer

You are reviewing N candidate outputs for the same task. Pick ONE
winner.

Task:
{task.goal}

Candidates:
{for each candidate}
  Worker: {candidate.worker_id}
  Output paths: {candidate.staged_dir}
  Outcome: {candidate.outcome}
  Sentinel: {candidate.sentinel}
{/for}

Respond ONLY with: `::winner: <worker_id>::`
```

#### `vote_unanimous`

```
strategy_vote_unanimous(futures, normalize_whitespace):
  await_all(futures)

  outputs = {}
  for future in futures:
    content = read_staged_dir(future.staged_dir)
    if normalize_whitespace:
      content = normalize_ws(content)  # collapse spaces/tabs, strip CRLF, trim
    outputs[future.worker.id] = sha256(content)

  distinct = set(outputs.values())
  if len(distinct) == 1:
    # All N agree — pick the first; output is identical.
    return Winner(futures[0])

  return None  # CONSENSUS_DISAGREEMENT capsule
```

`normalize_whitespace` defaults to true via
`config.consensus.whitespace_normalization_for_vote`.

### R1.5 — Apply phase (step 6.consensus.g)

```
apply_consensus_winner(winner_future, group_lock):
  # 1. Permission gate (existing v0.2.0b R1 step 6.f.0).
  edit_decision = resolve_permission("edit", winner_future.staged_dir, ...)
  if edit_decision != "allow": abort_consensus("permission_denied")

  # 2. Snapshot creation (existing v0.2.0c R1 step 6.g.0).
  snapshot_create_for_outputs(winner_future.staged_dir, mode="preimage")

  # 3. Atomic apply: copy staged_dir -> real output_paths.
  for path in winner_future.output_paths:
    src = winner_future.staged_dir + path
    atomic_rename(src, path)

  # 4. Mark winner.
  append_attempt(winner_future, applied=true, consensus_winner=true)

  # 5. Mark losers.
  for loser in active_losers():
    append_attempt(loser, applied=false, consensus_loser=true, superseded=true)

  # 6. Cleanup staging.
  cleanup_staging(active_consensus_task)

  # 7. Release group lock.
  release_lock(group_lock.id)
```

NEVER apply loser staging. NEVER apply late_stale staging
(Codex P1.4 invariant enforced by doctor
`consensus_loser_applied_violation` +
`consensus_late_stale_applied_violation`).

### R1.6 — Staging cleanup

```
cleanup_staging(task_id):
  pattern = ".dtd/tmp/consensus-*-{task_id}-*.staged/"
  for dir in glob(pattern):
    rm_rf(dir)
```

Run at:
- Step 6.consensus.g.6 (winner applied; losers + late discarded)
- finalize_run step 5e (catch-all if consensus aborted mid-flight)
- `/dtd doctor --takeover` (recovery from crashed run)

R1 doctor check `consensus_staging_orphan` (WARN) fires if any
`.dtd/tmp/consensus-*.staged/` dir exists AND no
`active_consensus_task` in state.md AND no `awaiting_user_decision`
for consensus.

### R1.7 — Capsule decision_resume_action map

| Option | On `/dtd run` resume |
|---|---|
| `reviewer_pick` (vote_unanimous disagreement) | dispatch reviewer with N candidate outputs; treat reviewer's pick as winner |
| `controller_pick` | controller selects one (typically lowest line-count + sentinel-passing); marks `applied: true` with `applied_by: controller-takeover`; capsule REVIEW_REQUIRED on next /dtd status |
| `retry_all` | release group lock; cancel staging; re-dispatch consensus_n workers fresh |
| `accept_majority` (CONSENSUS_PARTIAL_FAILURE) | apply winner from successful candidates per active strategy; failed workers' staging cleaned up |
| `retry_failed` | release group lock; re-dispatch ONLY failed workers; merge with previously-successful in next selection round |
| `wait_more` (CONSENSUS_LOCK_TIMEOUT) | extend deadline by `consensus_lock_acquire_timeout_sec` again; retry lock |
| `retry_lock` | release any partial lock state; retry from step 6.consensus.b |
| `demote_single` | drop to single-worker dispatch with first `<consensus-workers>` entry; consensus annotation removed for this attempt |
| `stop` | finalize_run(STOPPED) |

## R1 doctor checks (additional)

```
- consensus_staging_orphan (WARN)
    .dtd/tmp/consensus-*.staged/ dirs exist with no
    active_consensus_task in state.md and no awaiting_user_decision
    for consensus. Recommends /dtd doctor --takeover or manual rm.

- consensus_lock_timeout_recurring (WARN)
    3+ recent CONSENSUS_LOCK_TIMEOUT capsules in last 5 runs.
    Suggests increasing config.consensus_lock_acquire_timeout_sec
    or reducing concurrent task overlap.

- consensus_reviewer_unparseable (WARN — runtime, not static)
    Reviewer response did not contain a parseable
    ::winner: <worker_id>:: token. Falls through to
    CONSENSUS_DISAGREEMENT.

- consensus_rubric_all_tied (INFO)
    quality_rubric strategy yielded identical scores for all
    candidates. Falls through to CONSENSUS_DISAGREEMENT.

- consensus_skill_missing (ERROR — only when reviewer_consensus used)
    .dtd/skills/consensus-reviewer.md missing while a plan task
    declares consensus-strategy="reviewer_consensus".

- consensus_late_stale_applied_violation (R0 ERROR — extended R1)
    R0 already validated; R1 adds a runtime-trace check that
    inspects .dtd/log/consensus-NNN.md for any apply_attempt row
    with consensus_late_stale: true.
```

## R1 acceptance scenarios

> Scenario numbers 174-181 (next free range after v0.3.0a R1
> 166-173). See `test-scenarios.md` ## v0.3.0c R1 — Multi-worker
> consensus dispatch runtime.

```
174. Parallel dispatch with isolated staging: N workers each get
     own .dtd/tmp/consensus-*.staged/ dir; group lock owned by
     consensus group, not per-worker.
175. first_passing late-result cancellation: when winner returns,
     remaining workers cancelled via provider abort; non-cancellable
     workers' returns marked consensus_late_stale and discarded.
176. quality_rubric scoring: 4 rubric rules with weights 0.4/0.3/
     0.2/0.1 sum to 1.0; tied scores fall through to
     CONSENSUS_DISAGREEMENT.
177. reviewer_consensus prompt + parse: reviewer dispatched with
     N candidate outputs; ::winner: <id>:: token parsed; reviewer
     MUST be DISTINCT from candidate set (Codex P1).
178. vote_unanimous whitespace normalization: 3 workers produce
     same content with different line endings; normalization
     produces unanimous vote.
179. CONSENSUS_LOCK_TIMEOUT capsule: lock acquisition exceeds
     config.consensus_lock_acquire_timeout_sec (30s); capsule
     fires with [wait_more, retry_lock, demote_single, stop]
     options.
180. consensus_staging_orphan doctor check: stale
     .dtd/tmp/consensus-*.staged/ from crashed run detected;
     /dtd doctor --takeover cleans up.
181. retry_all option: group lock released; staging cleaned up;
     fresh dispatch for all N workers.
```

## Migration

R1 is a runtime contract; it does not change R0 file shapes. New
fields:
- `state.md.last_consensus_lock_acquire_attempt_at` (R1; ts)
- `state.md.last_consensus_strategy_outcome` (R1; outcome enum)

Config additions (under existing `## consensus`):
- `consensus_reviewer_timeout_sec: 120` (R1; reviewer dispatch
  timeout in sec)

`awaiting_user_reason` enum extension: `CONSENSUS_LOCK_TIMEOUT`
(R1 NEW).

NEW skill file: `.dtd/skills/consensus-reviewer.md` (template;
required when any plan task uses
`consensus-strategy="reviewer_consensus"`).

Permission keys: NO new key. 11-key invariant from R0 stable.

## Anchor

This file IS the canonical source for v0.3.0c Multi-worker
consensus dispatch (R0 + R1). Plan XML attributes + 4 strategies +
group lock + staged outputs + late-result cancellation + decision
capsules + state additions + doctor checks + R1 parallel dispatch
algorithm + R1 lock timeout handling + R1 strategy algorithms +
R1 reviewer prompt template + R1 staging cleanup all live here.

Run-loop wiring summary in `run-loop.md` step 5.5.5 / 6.consensus
points back to this file.

## Related topics

- `run-loop.md` — step 5.5.5 (consensus check) + step
  6.consensus (replaces step 6 for consensus tasks).
- `workers.md` — registry + dispatch transport (each consensus
  worker uses standard HTTP transport).
- `plan-schema.md` — XML schema; v0.3.0c adds 4 new attributes.
- `index.md` (this dir) — catalog now 15 topics after v0.3.0c.
