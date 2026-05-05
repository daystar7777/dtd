# DTD reference: incidents (v0.2.0a TAGGED)

> Canonical reference for v0.2.0a Incident Tracking.
> Lazy-loaded via `/dtd help incidents --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

Every operational failure that needs **durable tracking** creates an
incident. Incidents convert ad-hoc "blocked attempt" failures into
queryable, resolvable records that survive across sessions.

## Files

- `.dtd/log/incidents/index.md` — append-only registry (one row per incident)
- `.dtd/log/incidents/inc-<run>-<seq>.md` — per-incident detail (created on first incident)
- `.dtd/log/incidents/` directory (gitignored under `.dtd/.gitignore` `log/`)

## Incident schema

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

## Severity → state mapping (P1-3 fix from v0.2 design R1 review; R2 split clarified)

- `info` — observational. Touches `last_incident_id`, `incident_count`, **and `recent_incident_summary` (this is its only home in state.md)**. Does NOT touch `active_incident_id`. Does NOT fill decision capsule.
- `warn` — non-blocking notice. Touches `last_incident_id`, `incident_count`, `recent_incident_summary`, **AND** sets `active_incident_id`. Does NOT touch `active_blocking_incident_id`. Does NOT fill decision capsule.
- `blocked` — needs user input. Touches `last_incident_id`, `incident_count`, sets `active_incident_id` AND `active_blocking_incident_id`. **Does NOT touch `recent_incident_summary`** — the queue of pending blockers lives in `.dtd/log/incidents/index.md` only. Fills decision capsule with `awaiting_user_reason: INCIDENT_BLOCKED`. `/dtd run` refused while pending.
- `fatal` — same as blocked (no `recent_incident_summary` mutation), plus run terminates with `finalize_run(FAILED)` after user acknowledges.

The split keeps `/dtd status` semantics clean:
- compact dashboard: shows `active_blocking_incident_id` line if any.
- `--full` "+ recent incidents" panel: pulls from `recent_incident_summary` (info/warn).
- `/dtd incident list --blocking`: pulls from `index.md` (active + queued blockers).

## Multi-blocker policy

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
- `recent_incident_summary` is **NOT** touched by blocking incidents. That field
  is reserved for `info`/`warn` (non-blocking) summaries only — see Severity → state
  mapping. The blocking-incident queue lives in `.dtd/log/incidents/index.md` only.
- When user resolves the first, the second can be promoted: controller scans
  `.dtd/log/incidents/index.md` for the **oldest unresolved blocking incident**
  belonging to this run; that becomes the next `active_blocking_incident_id`.
  Doctor verifies invariant by scanning the same index file.

If v0.2.0a never observes any of paths 1-3 in practice, the queue stays a forward-compat
hook: the invariant remains enforceable by doctor (via `index.md` scan) and the
resolve/promote code path is exercised by the test fixture (scenario 26).

## When to create an incident

Per the v0.1.1 error matrix in §Worker Dispatch / §Resource Locks / §Apply step. The blocking conditions (AUTH_FAILED, NETWORK_UNREACHABLE, RATE_LIMIT_BLOCKED, etc., DISK_FULL, FS_PERMISSION_DENIED, FILE_LOCKED, PATH_GONE, PARTIAL_APPLY, UNKNOWN_APPLY_FAILURE, WORKER_INACTIVE) all create blocking-severity incidents.

Recoverable conditions (1st-hit retries) do NOT create incidents — they resolve via the failure counter / tier ladder. If the same condition recurs and becomes blocking, that's when the incident is filed.

### Info-severity incident triggers (non-blocking durable events)

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

## Cross-link integrity

Every failed/blocked attempt entry in `.dtd/attempts/run-NNN.md` MUST include:

```yaml
- status: failed | blocked
- error: <reason enum>
- incident: inc-<run>-<seq>
- side_effects: <enum>
```

Incident detail file MUST link back to attempt id. `/dtd attempt show` and `/dtd incident show` converge on the same facts. Doctor verifies bidirectional links.

## Resolve logic (P2-2 fix from v0.2 design R1 review)

`/dtd incident resolve <id> <option>`:

1. Update incident detail file: `status: resolved`, `resolved_at: <ts>`, `resolved_option: <option>`.
2. Append a row to `.dtd/log/incidents/index.md` updating the resolved row.
3. If incident's `id` equals `active_blocking_incident_id`: **clear** the field (not "decrement" — id pointer, not counter), then scan `.dtd/log/incidents/index.md` for the oldest unresolved blocking incident belonging to this run; if one exists, set `active_blocking_incident_id` to its id (the queue lives in the index file, NOT in `recent_incident_summary`).
4. If incident's `id` equals `active_incident_id` (warn-level): clear the field, then set to next-most-recent unresolved warn incident if any (else null).
5. Decision capsule: if `active_blocking_incident_id` is now null, clear `awaiting_user_decision`, `awaiting_user_reason`, `decision_*` fields. If queue had a next blocker promoted, refill capsule with that incident's recovery options.
6. Trigger the chosen option's `effect` (e.g., `retry`, `switch_worker`, `stop`) per the original capsule's `decision_resume_action`.

## finalize_run integration

The canonical `finalize_run(terminal_status)` order in `dtd.md` §`finalize_run`
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

## Anchor

This file IS the canonical source for v0.2.0a Incident Tracking.
v0.2.3 R1 extraction completed; `dtd.md` §Incident Tracking now points here.

## Related topics

- `autonomy.md` — silent mode defers blockers via incident snapshot in `deferred_capsule:`.
- `doctor-checks.md` — 7 incident-state checks across sub-releases.
- `permissions.md` (planned v0.2.0b) — `/dtd incident resolve` permission gating.
