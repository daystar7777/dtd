# DTD reference: v030a-cross-run-loop-guard

> Canonical reference for v0.3.0a Cross-run Loop Guard.
> Lazy-loaded via `/dtd help v030a-cross-run-loop-guard --full`.
> Not auto-loaded.
>
> **Per-sub-release split rationale**: per Codex v0.3 batch review,
> v0.3+ runtime contracts go in their own reference topics rather
> than expanding cross-cutting `run-loop.md` past the 32 KB
> typical cap. v0.3.0a is the first such split. Index.md catalog
> grows from 13 → 14 reference topics.

## Summary

v0.2.1 R1 added within-run loop guard:
`sha256(worker_id + task_id + prompt_hash + failure_hash)`. That
detects 3 consecutive same-signature failures within ONE run.

v0.3.0a extends this: when a within-run loop signature reached
`count >= 1` (Codex P1 amendment: capture BEFORE clearing in
finalize_run), the controller appends a STABLE cross-run
signature to `.dtd/cross-run-loop-guard.md` ledger. On a future
run, if a new failed attempt produces a cross-run signature that
matches a stored one, count increments. After
`config.cross_run_threshold` matches across distinct runs, fire
`LOOP_GUARD_CROSS_RUN_HIT` capsule.

This catches long-term failure patterns that within-run loop
guard misses (user resolves with worker_swap → next session
hits same pattern → resolves again → ... for weeks).

## Stable cross-run signature (P1.1 amendment)

Per Codex P1.1: v0.2.1 per-run signature is too unstable across
runs because `prompt_hash` changes with notepad / phase history /
steering / loaded profile content, and `task_id` is plan-local.

Cross-run signature uses STABLE identity instead:

```
cross_run_signature = sha256(
  repo_identity_hash +                        # git remote URL + project root fingerprint, NOT absolute path
  normalized_task_goal_hash +                 # sha256(lowercased + whitespace-collapsed + punctuation-stripped task.goal)
  worker_provider_model_or_capability +       # provider+model id OR capability id (more stable than worker_id which is user-local)
  output_path_scope_hash +                    # sha256(<work-paths> + <output-paths> glob normalized)
  failure_class +                             # categorical enum (TIMEOUT_BLOCKED / WORKER_PROTOCOL_VIOLATION / etc.)
  normalized_error_hash                       # sha256(redacted first error line after path/timestamp normalization)
)
```

### Component definitions

**`repo_identity_hash`** (PRIMARY → SECONDARY → TERTIARY):
1. PRIMARY: `sha256(git config remote.origin.url + first-commit-sha)`
   when both available.
2. SECONDARY: `state.md.project_id` (auto-generated UUID at
   install if not user-set).
3. TERTIARY: `sha256(absolute project root path)` as
   tie-breaker if no git remote AND no project_id.

Absolute path is NEVER the primary identity (Codex P1.7).

**`normalized_task_goal_hash`**:
- Read `<task><goal>` text from plan XML.
- Normalize: lowercase, collapse whitespace, strip punctuation
  (`. , ; : ' " ! ? ( ) [ ] { } -`), collapse multiple spaces.
- Sha256 of the normalized string.

Rationale: a task goal "Write API endpoints" and "Write API
endpoints!" should hash the same. Different plans with
semantically-identical goals should match.

**`worker_provider_model_or_capability`**:
- Prefer: `<provider>:<model_id>` from worker registry (more
  stable than `worker_id` which is user-local alias).
- Fallback: `capability:<id>` from plan task's
  `<capability>` element.
- Encoding: lowercase + colon-separated.

Rationale: same provider+model should match even if user
renames their local worker_id alias.

**`output_path_scope_hash`**:
- Concatenate `<work-paths>` and `<output-paths>` from plan
  task.
- Normalize globs (lowercase, collapse `**`, strip leading
  `./`).
- Sha256 of normalized concatenation.

**`failure_class`**:
- Categorical enum from existing v0.2.0a reason taxonomy:
  `TIMEOUT_BLOCKED | NETWORK_UNREACHABLE | RATE_LIMIT_BLOCKED |
  WORKER_5XX_BLOCKED | AUTH_FAILED | MALFORMED_RESPONSE |
  WORKER_PROTOCOL_VIOLATION | WORKER_INACTIVE | DISK_FULL |
  PARTIAL_APPLY | UNKNOWN_APPLY_FAILURE | etc.`
- Free-form failure descriptions are NEVER part of the hash
  (those vary per attempt).

**`normalized_error_hash`**:
- Take the FIRST non-empty line of redacted failure reason +
  first error line (per worker output discipline).
- Normalize: replace absolute paths with `<PATH>`, replace
  ISO timestamps with `<TS>`, replace 8+ digit hex with
  `<HEX>`, strip ANSI escape codes.
- Sha256 of normalized string.

Rationale: same conceptual error ("connection refused at <PATH>")
matches across runs even when timestamps and paths differ.

## Cross-run ledger format

`.dtd/cross-run-loop-guard.md` (gitignored under
`.dtd/.gitignore`; signatures may be sensitive in aggregate).

```markdown
# DTD Cross-run Loop Guard

> Persistent stable signature ledger across runs. Updated at
> finalize_run when within-run loop signature reached count >= 1
> (signature captured BEFORE within-run loop guard fields cleared).
> Append-only with tombstones for prune. Signatures expire after
> retention_days; doctor INFO recommends purge.
>
> Format:
>   `<first_seen> | <cross_run_signature> | <run_count> | <last_seen> | <last_resolution> | <by> [| revoked: <ts>]`

## Active signatures

(Empty by default. Populated by finalize_run when applicable.)

## Tombstones

(Append `revoke` rows when user explicitly prunes a signature.
Original active rows preserved for audit.)
```

### Row field semantics

- `first_seen`: ISO 8601 UTC of first cross-run signature
  observation.
- `cross_run_signature`: 64-char hex sha256 from formula above.
- `run_count`: integer count of distinct runs that produced
  this signature.
- `last_seen`: ISO 8601 UTC of most recent observation.
- `last_resolution`: enum from prior `LOOP_GUARD_CROSS_RUN_HIT`
  resolutions: `ask_user | swap_to_specific | controller |
  prune | stop | (none)` (none = within-run threshold not yet
  hit cross-run).
- `by`: who appended (`finalize_run | user_prune | doctor`).

## Algorithm

### At finalize_run (capture-before-clear; Codex amendment)

```
function on_finalize_run() {
  // Codex amendment: capture BEFORE clearing within-run fields
  if (state.loop_guard_signature_count >= 1) {
    cross_sig = compute_cross_run_signature(
      run.repo_identity_hash,
      run.last_failed_attempt.task_goal,
      run.last_failed_attempt.worker_provider_model_or_capability,
      run.last_failed_attempt.output_path_scope,
      run.last_failed_attempt.failure_class,
      run.last_failed_attempt.normalized_error_line
    );
    upsert_cross_run_ledger(cross_sig, now, run.last_resolution);
  }

  // Now clear within-run fields per v0.2.1 R1 + Codex amendment
  state.loop_guard_signature = null;
  state.loop_guard_signature_count = 0;
  state.loop_guard_signature_first_seen_at = null;
  state.loop_guard_status = "idle";
}
```

### At signature match step (run-loop step 6.e/6.f.0 fail path)

After v0.2.1 within-run signature computation, ALSO:

1. Compute `cross_run_signature` for current attempt.
2. Read `.dtd/cross-run-loop-guard.md` (apply tombstones first;
   skip rows with `revoked:` set).
3. If cross_run_signature matches an active row AND
   `last_seen >= now - config.cross_run_retention_days`:
   - Increment ephemeral counter `cross_run_match_count` in
     state.md.
   - If `cross_run_match_count >= config.cross_run_threshold`
     (default 2): fill capsule
     `awaiting_user_reason: LOOP_GUARD_CROSS_RUN_HIT`.
4. If signature is past retention: ignore (treat as new pattern).

### Pruning

```
/dtd loop-guard prune <signature>           # adds tombstone row; doesn't physically remove
/dtd loop-guard prune --before <date>        # bulk tombstone old rows
/dtd loop-guard show [--all|--recent|--full] # observational (Codex P1 additional: compact default)
```

Per Codex P1 additional amendment: `prune_signature` action in
the LOOP_GUARD_CROSS_RUN_HIT capsule appends a tombstone, not a
physical row removal (consistent with v0.2.0b permissions.md
style).

## Decision capsule

```yaml
awaiting_user_reason: LOOP_GUARD_CROSS_RUN_HIT
decision_id: dec-NNN
decision_prompt: "Cross-run loop pattern detected: signature observed in <N> prior runs (last seen <ts>; last_resolution: <hint>). Continue?"
decision_options:
  - {id: ask_user,        label: "stop and inspect history",     effect: "PAUSED with capsule + cross-run history",                   risk: "blocks until user inspects"}
  - {id: swap_to_specific, label: "force specific worker <id>",   effect: "use named worker for this task",                            risk: "user must know which worker"}
  - {id: controller,      label: "controller takeover",          effect: "controller acts; REVIEW_REQUIRED gate",                     risk: "no worker grade"}
  - {id: prune_signature, label: "prune this signature (tombstone)", effect: "append tombstone row; treat as fresh next time",        risk: "may re-loop if pattern returns"}
  - {id: stop,            label: "stop the run",                 effect: "finalize_run(STOPPED)",                                     risk: "lose run progress"}
decision_default: ask_user
decision_resume_action: "controller acts on chosen option's effect"
```

**Compact status display** (per Codex P1 additional): only show
the active cross-run hit + a short hint in `/dtd status --full`;
full prior resolutions live in `/dtd loop-guard show --full`.

## Config

```yaml
## cross-run loop guard (v0.3.0a)

# Persist loop guard signatures across runs to detect long-term
# patterns within-run guard (v0.2.1) doesn't catch.
# Signatures are stable hashes per cross-run formula above.

- cross_run_loop_guard_enabled: true
- cross_run_threshold: 2                  # prior runs needed before LOOP_GUARD_CROSS_RUN_HIT fires (within current run, count >= threshold)
- cross_run_retention_days: 30            # prune signatures whose last_seen is older than this
- cross_run_max_signatures: 500           # hard cap; doctor WARN above; auto-prune oldest at next finalize_run
```

## State.md additions

```yaml
## Cross-run loop guard (v0.3.0a)

- cross_run_loop_guard_status: idle       # idle | watching | hit
- cross_run_match_count: 0                # ephemeral counter for current run; reset at finalize_run
- pending_cross_run_signature: null       # current run's signature flagged for cross-run match
- last_cross_run_check_at: null           # ts of last ledger read
- last_cross_run_finalize_at: null        # ts of last finalize_run capture-before-clear
```

The within-run loop guard fields (v0.2.1 R1) remain unchanged.

## /dtd loop-guard command

```text
/dtd loop-guard show [--all|--recent|--full]   # observational; show cross-run ledger (compact default; --full for prior resolutions)
/dtd loop-guard prune <signature>               # mutating; tombstone a signature
/dtd loop-guard prune --before <date>           # mutating; bulk tombstone old entries
```

`show` is observational read; `prune` is mutating but
non-destructive (tombstones, not deletions).

NL routing (English):

| Phrase | Canonical |
|---|---|
| "show loop history", "loop guard ledger" | `/dtd loop-guard show` |
| "prune that loop signature" | `/dtd loop-guard prune <signature>` |
| "purge old loop signatures" | `/dtd loop-guard prune --before <date>` |

Korean / Japanese NL routing in respective locale packs (R1+).

## Doctor checks

- `.dtd/cross-run-loop-guard.md` exists if
  `config.cross_run_loop_guard_enabled: true`; ELSE INFO
  `cross_run_ledger_missing` (lazy-created on first
  finalize_run capture).
- Each row has valid format
  `<first_seen> | <signature> | <run_count> | <last_seen> | <last_resolution> | <by>`;
  ELSE WARN `cross_run_ledger_row_invalid` with line ref.
- Total active (non-tombstoned) signatures ≤
  `config.cross_run_max_signatures` (default 500); ELSE WARN
  `cross_run_ledger_overflow` recommending purge.
- Signatures with `last_seen` past retention_days AND no
  tombstone: INFO `cross_run_signature_expired_unpruned`
  recommending `/dtd loop-guard prune --before <retention_cutoff>`.
- `state.md.pending_cross_run_signature` non-null AND
  `awaiting_user_decision: false`: WARN
  `cross_run_pending_orphan` (capsule didn't fill; recover
  with `/dtd doctor --takeover`).
- `state.md.cross_run_loop_guard_status` ∈
  `idle | watching | hit`; ELSE ERROR
  `cross_run_status_invalid`.
- Within-run loop_guard_signature_count was >=1 at last
  finalize but no matching cross-run row: WARN
  `cross_run_finalize_capture_missed` (capture-before-clear
  didn't run).
- Cross-run row references unknown failure_class enum: WARN
  `cross_run_failure_class_unknown`.

## R1 runtime contract

R0 (commit `0681088`) shipped the stable signature formula, ledger
format, finalize_run step 5d capture-before-clear, decision
capsule, and 8 doctor checks.

R1 ships the runtime algorithms that turn the ledger into a
working detector at dispatch time:

### R1.1 — Match algorithm (read-time, step 6 fail-path)

Triggered when a within-run failed attempt is recorded AND the
within-run loop guard has not yet fired (i.e. signature_count < 3).

```
match_cross_run(failed_attempt, ledger):
  # 1. Compute the new attempt's stable signature.
  sig_new = compute_stable_signature(failed_attempt)

  # 2. Apply tombstones first (Codex: tombstone, never physical removal).
  active_rows = ledger.rows.filter(r => not r.is_tombstoned())

  # 3. Look up by signature (sha256 prefix-match safe; full match required).
  match = active_rows.find(r => r.signature == sig_new)
  if not match:
    return MatchResult(status="no_match")

  # 4. Inspect run_count and last_resolution.
  if match.run_count + 1 < config.cross_run_threshold:
    # Will be incremented at finalize_run step 5d if attempt is the last failure of the run.
    return MatchResult(status="watching", row=match, projected_count=match.run_count+1)

  # 5. Threshold met -> fill capsule.
  return MatchResult(status="hit", row=match, capsule_payload={
    signature: match.signature,
    run_count: match.run_count + 1,
    first_seen: match.first_seen,
    last_resolution: match.last_resolution,
    failure_class: failed_attempt.failure_class,
  })
```

When `status="hit"`: fill capsule
`awaiting_user_reason: LOOP_GUARD_CROSS_RUN_HIT` per R0 spec.

When `status="watching"`: append `cross_run_loop_guard_status:
watching` annotation to `state.md`; do NOT fire capsule. Capture
happens at finalize_run step 5d.

When `status="no_match"`: signature is novel; capture at
finalize_run step 5d will create a new row with `run_count: 1`.

### R1.2 — Tombstone precedence

Tombstones are append-only audit records. A tombstone row format:

```text
<ts> | tombstone | <signature> | revokes: <orig first_seen ts> | by: <user|finalize_run|prune-cmd> | reason: <free-form>
```

Active row resolution:
1. Read all rows in chronological order.
2. For each `signature`, find the latest `tombstone` row that
   references that signature (by `revokes:` field).
3. If a tombstone exists AND it is newer than the latest non-tombstone
   row for that signature: the signature is INACTIVE.
4. Else: the signature is ACTIVE; use the latest non-tombstone row.

A user can "untombstone" by appending a NEW non-tombstone row with
the same signature (which becomes the new active row, since it's
newer than the tombstone). This is the audit-friendly way to revive
a signature.

### R1.3 — Pruning at finalize_run (step 5d sub-step)

After capture-before-clear (per R0), before step 6 WORK_END:

```
finalize_run_step_5d_prune():
  retention_cutoff = now_utc - config.cross_run_retention_days
  for row in ledger.active_rows():
    if row.last_seen < retention_cutoff:
      append_tombstone(
        signature = row.signature,
        revokes = row.first_seen,
        by = "finalize_run_retention_prune",
        reason = "last_seen older than retention",
      )
```

R1 doctor check `cross_run_retention_prune_unrun` (INFO) fires if
a row's `last_seen < retention_cutoff` AND no matching tombstone
exists — indicates step 5d.prune did not run since the cutoff
moved.

### R1.4 — Migration from v0.2.1 within-run only

R1 doctor check `cross_run_migration_required` (INFO) fires when:
- `state.md.project_id` is null AND no git remote AND
- The ledger has rows referring to an absolute-path-based
  `repo_identity_hash` (TERTIARY fallback).

Recommended action: user sets `project_id` via `/dtd update` OR
configures git remote — then runs `/dtd loop-guard rehash` (R1 NEW
admin command) to recompute signatures with the now-stable
identity. Old rows tombstoned with `by: rehash_admin`.

### R1.5 — Concurrent run handling

If 2 controllers run against the same project simultaneously
(rare; possible in CI / multi-machine workflows):
- Both finalize_run step 5d's append to the same ledger.
- Append-only discipline avoids data loss.
- Duplicate `first_seen` rows for the same signature are valid
  (each represents a finalize event); `match_cross_run` treats
  them as one active signature (uses MAX of `run_count`).
- R1 doctor check `cross_run_concurrent_finalize_detected` (INFO)
  fires when 2+ rows for the same signature have `first_seen`
  within 60 seconds — informational; not a contract violation.

### R1.6 — `/dtd loop-guard show` R1 output format

R0 specified the command exists; R1 specifies output format:

```
$ /dtd loop-guard show

Active cross-run signatures (3 of 47 total; 44 tombstoned):

| Signature  | Count | First seen     | Last seen      | Last resolution      |
|---|---:|---|---|---|
| a3f1b9...  | 3 (HIT) | 2026-04-15 | 2026-05-05 | LOOP_GUARD_CROSS_RUN_HIT (open) |
| 7c2e8d...  | 2     | 2026-04-22 | 2026-05-04 | user_chose: retry_with_diff_worker |
| 5d91f4...  | 1     | 2026-05-04 | 2026-05-04 | (single hit; not yet matched) |

Tombstoned (last 5):
- 2026-05-03 | b1c2d3... | by: user prune | reason: false-positive
- 2026-04-30 | e4f5a6... | by: finalize_run_retention_prune | reason: last_seen older than retention
- ...

Use `/dtd loop-guard show --full` for all rows + signatures.
```

R1 doctor check `cross_run_show_no_active_signatures_after_hit` (INFO)
fires if `state.md.cross_run_loop_guard_status: hit` but
`/dtd loop-guard show` would render zero active rows — capsule
state and ledger state diverged.

### R1.7 — `/dtd loop-guard rehash` (R1 admin command, NEW)

Recomputes all active signatures using current `repo_identity_hash`.
Used after migrating from absolute-path tertiary to git-remote or
project_id identity.

```text
/dtd loop-guard rehash               # rehash all active signatures
/dtd loop-guard rehash --dry-run     # show what would change without writing
```

Effect:
- Each active signature is recomputed with current
  `repo_identity_hash`.
- Old signature row tombstoned with `by: rehash_admin`.
- New signature row appended with `first_seen: <orig first_seen>`
  preserved in audit (`copied_from: <orig signature>`).

This command is permission-gated under existing
`tool_relay_mutating` (no new key).

## R1 doctor checks (additional)

```
- cross_run_retention_prune_unrun (INFO)
    Row's last_seen < retention_cutoff AND no matching tombstone.
    finalize_run step 5d.prune didn't run since cutoff moved.

- cross_run_migration_required (INFO)
    project_id null AND no git remote AND ledger has TERTIARY
    repo_identity_hash rows. Recommends /dtd loop-guard rehash.

- cross_run_concurrent_finalize_detected (INFO)
    2+ rows for the same signature with first_seen within 60s.
    Informational; append-only discipline preserves audit trail.

- cross_run_show_no_active_signatures_after_hit (INFO)
    state.md.cross_run_loop_guard_status: hit but /dtd loop-guard
    show renders zero active rows. Capsule state and ledger state
    diverged.

- cross_run_rehash_in_progress (WARN)
    /dtd loop-guard rehash detected ongoing finalize_run capture.
    Recommends waiting for run completion before rehashing.

- cross_run_signature_collision (ERROR — extreme rare)
    2+ rows have identical signature but different (task_goal,
    worker, output_path_scope) at row creation time. Indicates
    sha256 collision (cosmically unlikely) or signature
    computation bug. Demands investigation.
```

## R1 acceptance scenarios

> Scenario numbers 166-173 (next free range after v0.3.0b R1
> 158-165). See `test-scenarios.md` ## v0.3.0a R1 — Cross-run loop
> guard runtime.

```
166. Match algorithm: signature match in active_rows -> watching
     state if count<threshold; HIT capsule if count>=threshold.
167. Tombstone precedence: appended tombstone (newer) deactivates
     a signature; user can revive via NEW non-tombstone row.
168. Retention pruning at finalize_run step 5d: rows older than
     cross_run_retention_days get tombstones; original rows
     preserved (audit).
169. Migration: TERTIARY repo_identity_hash -> /dtd loop-guard
     rehash recomputes signatures using project_id; old tombstoned
     with by: rehash_admin.
170. Concurrent finalize_run: 2 controllers append same-signature
     rows within 60s; doctor INFO; match algorithm uses MAX run_count.
171. /dtd loop-guard show R1 output: active table + tombstoned
     summary + total counts; --full lists all rows.
172. /dtd loop-guard rehash --dry-run: shows would-be changes
     without writing; --dry-run flag respected.
173. Signature collision (forced via test fixture): ERROR
     cross_run_signature_collision; ledger NOT corrupted.
```

## Anchor

This file IS the canonical source for v0.3.0a Cross-run Loop
Guard (R0 + R1). Stable signature formula (P1.1) + ledger format +
finalize_run capture-before-clear + decision capsule + R0 pruning
+ R1 match algorithm + R1 tombstone precedence + R1 retention
pruning + R1 migration + R1 concurrent handling + R1 show/rehash
output + doctor checks all live here. Run-loop wiring stays in
`run-loop.md` step 6 fail-path; finalize_run capture is
documented in run-loop.md step 5d (NEW; below v0.3.0e step 5c).

## Related topics

- `run-loop.md` — within-run loop guard (v0.2.1 R1) +
  finalize_run.
- `incidents.md` — failure_class taxonomy enumeration.
- `workers.md` — worker provider+model fields used in stable
  signature.
- `index.md` (this dir) — v0.2.3 reference catalog (now 19 topics
  after v0.3.0a R0 + v0.3.0c R0 + v0.3.0d R0 + v0.3.0e R1 +
  v0.3.0b R1).
