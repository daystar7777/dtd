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

## Anchor

This file IS the canonical source for v0.3.0c Multi-worker
consensus dispatch. Plan XML attributes + 4 strategies + group
lock + staged outputs + late-result cancellation + decision
capsules + state additions + doctor checks all live here.

Run-loop wiring summary in `run-loop.md` step 5.5.5 / 6.consensus
points back to this file.

## Related topics

- `run-loop.md` — step 5.5.5 (consensus check) + step
  6.consensus (replaces step 6 for consensus tasks).
- `workers.md` — registry + dispatch transport (each consensus
  worker uses standard HTTP transport).
- `plan-schema.md` — XML schema; v0.3.0c adds 4 new attributes.
- `index.md` (this dir) — catalog now 15 topics after v0.3.0c.
