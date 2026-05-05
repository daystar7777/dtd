# DTD v0.3.0e — Time-limited permissions runtime (R1 canonical reference)

## Anchor

This file is the canonical reference for v0.3.0e R1 runtime
contracts: pre-dispatch resolution check, named-scope evaluation,
late-binding mid-tool-call edge cases, clock-skew handling, DST
transitions, audit trail format. R0 spec lives in
`.dtd/permissions.md` ## Time-limited rules (v0.3.0e); R0
finalize_run integration is `run-loop.md` step 5c.

Per Codex v0.3 review (per-sub-release split pattern), this topic
hosts R1 wiring instead of expanding cross-cutting `run-loop.md`
past its lazy-load budget.

## Summary

R0 (commit `ebd9920` + patches `19bf3f1`) shipped the syntax: `for
1h`, `until eod`, `for run`, named scopes, `resolved_until` derived
field, `resolved_until_tz` for named local-time scopes, finalize_run
step 5c auto-prune.

R1 ships the runtime algorithms that turn that syntax into safe,
predictable enforcement at dispatch time:

1. **Resolution-time evaluator** — write-time algorithm that
   produces `resolved_until` from the user's `until: <form>`.
2. **Pre-dispatch check** — at every permission resolution, verify
   the rule has not expired since it was written.
3. **Late-binding behavior** — what happens when a rule expires
   between resolution and apply, or mid-tool-call.
4. **TZ + DST + clock-skew model** — named local-time scopes use
   the user's TZ and survive DST without ambiguity.
5. **R1 audit fields** — finalize_run tombstones carry resolution
   provenance; doctor checks for orphaned references.

## 1. Resolution-time evaluator (write-time)

Triggered when `/dtd permission allow|deny|ask` (or `/dtd permission
revoke` referencing a v0.3.0e form) appends a row whose `until:`
field is non-empty.

### Algorithm

```
resolve_until_at_write(until_str, now_local, user_tz):
  # Form 1: legacy v0.2.0b absolute UTC
  if matches(until_str, ISO_8601_UTC):
    return ResolvedUntil(
      resolved_until = until_str,
      resolved_until_tz = "UTC",
      form = "absolute"
    )

  # Form 2: duration (v0.3.0e R0 single-unit only)
  if matches(until_str, r"^\+(\d+)([mhdw])$"):
    qty, unit = parse(until_str)
    if combined_units_in_string(until_str):
      raise permission_duration_combined_unsupported_v030e
    abs_ts = now_utc() + duration_seconds(qty, unit)
    return ResolvedUntil(
      resolved_until = iso8601_utc(abs_ts),
      resolved_until_tz = "UTC",
      form = "duration"
    )

  # Form 3: named scope (run/run_end -> sentinel; others -> abs ts)
  if until_str in {"run", "run_end"}:
    return ResolvedUntil(
      resolved_until = "run_end",
      resolved_until_tz = "UTC",  # sentinel; tz irrelevant
      form = "named_run"
    )

  if until_str in {"today", "eod", "this-week", "next-monday", "next-week"}:
    abs_ts_local = compute_named_scope(until_str, now_local, user_tz)
    return ResolvedUntil(
      resolved_until = iso8601_with_offset(abs_ts_local, user_tz),
      resolved_until_tz = user_tz,           # REQUIRED; not "UTC"
      form = "named_local"
    )

  # Form 4 (rejected): mixed for/until
  if mixed_for_until_detected:
    raise permission_duration_until_mixed_unsupported

  # Form 5 (rejected): unknown form
  raise permission_until_form_unknown
```

### Named-scope formulas (Codex P1.9 / Asia/Seoul fixture example)

| Scope | Formula | Codex P1.9 status |
|---|---|---|
| `today` / `eod` | local 23:59:59 of `now_local`'s date | tz REQUIRED |
| `this-week` / `next-monday` | local 00:00:00 of next Monday | tz REQUIRED |
| `next-week` | `this-week` + 7d, local 00:00:00 | tz REQUIRED |

The tz is taken from `state.md.user_tz` (set at install or via
`/dtd config user_tz <tz>`). If null AND the user issues a named
local scope: fail with `permission_user_tz_required` and refuse to
write the rule.

### `resolved_until_tz` invariant (Codex P1.9)

For `form = "named_local"`: `resolved_until_tz` MUST equal the tz
used to compute the absolute timestamp. Doctor check
`permission_until_tz_missing` (R0) plus the new R1
`permission_until_tz_form_mismatch` enforce it.

For `form = "absolute"` and `form = "duration"`:
`resolved_until_tz: UTC` (these forms are timezone-free at
resolution; `UTC` is the canonical marker).

For `form = "named_run"`: `resolved_until_tz: UTC` (sentinel; tz
irrelevant).

## 2. Pre-dispatch check (read-time)

Triggered at every permission resolution event in `run-loop.md`
step 5.5 / 6.c / 6.e.5 / 6.f.0 / 6.g (and `/dtd permission`
mutating commands).

### Algorithm

```
check_rule_expired(rule, now_utc):
  # Apply tombstone first; if revoked, rule is inactive regardless of expiry.
  if rule.revoked_by_tombstone():
    return Inactive(reason = "tombstoned")

  # v0.3.0e: prefer resolved_until.
  if rule.resolved_until:
    if rule.resolved_until == "run_end":
      # Sentinel: active until finalize_run step 5c. No comparison needed.
      return Active

    # Compare absolute ts (UTC) to now_utc. resolved_until carries TZ
    # offset for named_local form; convert before compare.
    ru_utc = to_utc(rule.resolved_until, rule.resolved_until_tz)
    if ru_utc <= now_utc:
      return Expired(reason = "ttl_elapsed", ts = ru_utc)
    return Active

  # Legacy v0.2.0b: until: <ISO ts> alone.
  if rule.until_legacy_iso:
    if rule.until_legacy_iso <= now_utc:
      return Expired(reason = "ttl_elapsed_legacy", ts = rule.until_legacy_iso)
    return Active

  # No until field at all = permanent rule (existing v0.2.0b behavior).
  return Active
```

Expired rules at read-time are SKIPPED (not first-sorted-rule-wins
candidates) but NOT auto-tombstoned in this step. Tombstoning runs
ONLY at `finalize_run` step 5c (Codex P1.10: auto-prune is its own
dedicated step, not hidden inside another step).

If the read-time skip leaves NO matching rule: fall through to
`## Default rules` per existing v0.2.0b resolution.

## 3. Late-binding behavior (mid-tool-call expiry)

Edge case: rule resolved as Active at step 6.c.0 (pre-dispatch
permission gate); tool call dispatched at step 6.c.1; tool returns
at step 6.c.2 — and `resolved_until` falls in the (0, n) seconds
window between gate and return.

### Decision tree

| Phase | Behavior |
|---|---|
| **Pre-dispatch gate** | Standard check. If Active: proceed. If Expired: ask/deny per fallback rule. |
| **Mid-call (gate passed, tool running)** | NOT re-evaluated. The rule was Active at gate time; the dispatched call completes per its existing contract. |
| **Post-return apply** | NOT re-evaluated. Apply proceeds. |
| **Next dispatch event** | Re-evaluated; rule is now Expired; falls through to default. |

Rationale: re-checking mid-call would require interrupt semantics
that DTD doesn't provide. Locking-in the gate decision matches
v0.2.0b R1 dispatch-time-resolution discipline.

Doctor check: `permission_late_bind_overrun` (R1 INFO) records when
a tool call's wall-clock duration exceeds the residual time on its
gating rule. Informational only — does not flag a contract
violation.

## 4. Clock skew + DST + ambiguous local times

### Clock skew

`now_utc` is sourced from the controller host's clock. If the
controller drifts vs. the user's actual time, named local scopes
will resolve to skewed absolute timestamps. R1 doctor check
`permission_clock_skew_excessive` (WARN at >5 minutes drift vs.
NTP-derived reference IF accessible) — opt-in; disabled by
default.

### DST transitions

Named scope `today` resolves to local 23:59:59 on the date the
rule is written. If a 1-hour rule is written at 01:30 local on a
"spring forward" date (skipping 02:00–02:59): the duration form
`+1h` produces UTC + 3600s (definitionally unambiguous).

Named scope `this-week` (next Monday 00:00 local) on a "fall back"
date (e.g. last Sunday of October in EU): 00:00:00 local refers to
the second occurrence (after fall-back). This matches user
intuition ("midnight, the second one if there are two").

Doctor check `permission_until_dst_ambiguous` (WARN) fires if a
rule's `resolved_until` falls within a DST transition window AND
the form is `named_local`. Codex's recommendation: warn but do not
auto-resolve.

### Ambiguous local times in `<ISO ts>` legacy form

Legacy v0.2.0b syntax requires UTC `<ISO ts>`. Local-time
`<ISO ts>` (e.g. `2026-05-05T18:00:00-07:00`) is also accepted; the
runtime converts to UTC at read time and compares against
`now_utc`. Doctor check `permission_until_legacy_local_offset`
(INFO) suggests rewriting to UTC for clarity.

## 5. Resolution-time state updates

When `resolve_until_at_write` succeeds, controller writes:

```
state.md.active_time_limited_rule_count += 1   (only for non-permanent rules)
state.md.last_permission_rule_written_at: <now>
state.md.last_permission_rule_form: <absolute|duration|named_local|named_run>  # NEW R1 field
```

The `last_permission_rule_form` field is for doctor cross-check
only; not used by the resolver.

## 6. Tombstone format (finalize_run step 5c output)

Step 5c writes tombstones with R1 audit fields:

```text
<ts> | revoke | <key> | scope: <expr> | by: finalize_run_ttl_expired (revokes <orig ts> row, resolved_until: <orig resolved_until>) | resolved_until_form: <form>
```

```text
<ts> | revoke | <key> | scope: <expr> | by: finalize_run_run_end (revokes <orig ts> row, resolved_until: run_end) | resolved_until_form: named_run
```

The `resolved_until_form` audit field is NEW in R1; doctor uses it
for the new `permission_finalize_form_drift` check (tombstone form
must match the original rule's form).

## 7. Doctor checks (R1 — additional)

R0 shipped 8 codes (covered in `doctor-checks.md`). R1 adds:

```
- permission_until_form_unknown (ERROR)
    Write attempt with until_str that doesn't match any of the
    accepted forms. Rule write is rejected.

- permission_user_tz_required (ERROR)
    Write attempt with form="named_local" but state.md.user_tz is
    null. Rule write is rejected; user must set user_tz first.

- permission_until_tz_form_mismatch (ERROR)
    Existing rule has form="named_local" but resolved_until_tz="UTC"
    (or vice versa). Indicates corruption / migration drift.

- permission_late_bind_overrun (INFO)
    A tool call's wall-clock duration exceeded the residual time
    on its gating rule. Informational only; the gate-time decision
    is locked-in by design.

- permission_clock_skew_excessive (WARN — opt-in)
    Controller clock drift > 5 min vs. NTP reference IF accessible.
    Disabled by default; enabled via
    config.permission_clock_skew_check_enabled: true.

- permission_until_dst_ambiguous (WARN)
    Rule with form="named_local" resolves to within a DST transition
    window (US/EU spring-forward or fall-back).

- permission_until_legacy_local_offset (INFO)
    Legacy v0.2.0b rule uses <ISO ts> with non-UTC offset
    (e.g. -07:00). Suggests rewriting to UTC for clarity.

- permission_finalize_form_drift (WARN)
    Tombstone row's resolved_until_form does not match the original
    rule's form. Indicates a controller bug or manual edit.
```

## 8. R1 acceptance scenarios

> Scenario numbers 150-157 (the v0.3.0b R0 set already occupies
> 118-125). See `test-scenarios.md` ## v0.3.0e R1 — Time-limited
> permissions runtime.

```
150. Pre-dispatch gate locks in: tool runs to completion even if
     resolved_until passes mid-call; next dispatch re-evaluates.
151. Named local scope (today) writes resolved_until_tz=user_tz;
     resolves to UTC at read time correctly.
152. user_tz null + named-local form = ERROR
     permission_user_tz_required; rule NOT written.
153. Combined units (+1h30m) rejected at write with
     permission_duration_combined_unsupported_v030e.
154. for run + finalize_run: step 5c tombstones with
     by: finalize_run_run_end audit; resolved_until_form=named_run.
155. Manual edit corruption: form=named_local + tz=UTC mismatch
     detected by doctor permission_until_tz_form_mismatch.
156. Clock skew opt-in: with permission_clock_skew_check_enabled:true
     and 7-min drift, doctor WARN permission_clock_skew_excessive.
157. DST spring-forward: named-local rule on transition date
     resolves to first valid post-transition local minute; doctor
     WARN permission_until_dst_ambiguous.
```

## 9. Migration

R1 is a runtime contract; it does not change R0 file shapes. New
fields:
- `state.md.last_permission_rule_written_at` (R1; null pre-R1)
- `state.md.last_permission_rule_form` (R1; null pre-R1)

Tombstones written before R1 lack `resolved_until_form` audit field;
doctor INFO `permission_finalize_pre_r1_tombstone_unannotated`
suggests re-finalize-run after upgrade (cosmetic; not a contract
violation).

Permission keys: NO new key. 11-key invariant from v0.3.0c remains
stable.
