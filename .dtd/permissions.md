# DTD Permission Ledger

> Source of truth for what the user has pre-approved.
> Append-only history; current state is resolved by key, scope specificity,
> and timestamp.
> Rule format:
>   `<ts> | <decision> | <key> | scope: <expr> [| worker: <id>] [| until: <orig>] [| resolved_until: <abs ts|run_end>] [| resolved_until_tz: <tz>] | by: <who>`
>
> Read by controller before any permission-class action. See
> `dtd.md` §`/dtd permission` for command spec.

## Active rules

(Empty by default. Populated by `/dtd permission allow|deny|ask|revoke ...`
or by hand-edit. Matching rules resolve by most-specific scope first, then
latest timestamp for ties.)

## Default rules

> Apply when no `## Active rules` entry matches. Read-only template; user-set
> rules go in `## Active rules`.

- ask   | edit               | scope: *
- ask   | bash               | scope: *
- ask   | external_directory | scope: *
- ask   | task               | scope: *
- ask   | snapshot           | scope: *
- ask   | revert             | scope: *
- ask   | tool_relay_read    | scope: *
- ask   | tool_relay_mutating | scope: *
- allow | todowrite          | scope: *           # always-safe; never blocks
- ask   | question           | scope: *           # questions to user; user choice

## Resolution algorithm

1. Compute `(key, scope, worker, capability)` for the proposed action.
2. Collect `## Active rules` whose key matches and whose scope/worker/
   capability filters match the proposed action.
3. Apply tombstones first: a `revoke` row that references an earlier rule
   neutralizes that earlier rule. Tombstone rows are audit records, not
   candidate decisions.
4. Drop expired rules:
   - If `resolved_until: <ISO ts>` exists, compare that timestamp to now.
   - If `resolved_until: run_end` exists, keep it active until finalize_run
     step 5c appends its tombstone.
   - Else if legacy `until: <ISO ts>` exists, compare that timestamp to now.
   - Else if `until` is a v0.3.0e duration/named form but `resolved_until`
     is missing, treat the rule as unresolved and fall through to the next
     match/default; doctor reports `permission_until_unresolved`.
5. Sort remaining matches by scope specificity DESC, then timestamp DESC.
   Specificity order: exact path/command > longer glob/prefix > shorter
   glob/prefix > `*`; worker/capability filters add specificity.
6. First sorted rule wins. If no active rule matches, fall back to
   `## Default rules` for that key.
7. Apply the matched decision:
   - `allow`: proceed; append `auto-allow` row to `.dtd/log/permissions.md`.
   - `deny`: abort; append `auto-deny` row. Silent mode does NOT defer
     deny — deny is final.
   - `ask`: fill `awaiting_user_reason: PERMISSION_REQUIRED` decision
     capsule. Interactive surfaces immediately; silent defers per silent
     algorithm.

## Audit log (v0.2.0b R1)

Every permission resolution (allow / deny / ask / user-decision)
appends one row to `.dtd/log/permissions.md` (gitignored,
append-only). Writer is the controller in `run-loop.md` step
5.5 / 6.c / 6.e.5 / 6.f.0 / 6.g, plus the `/dtd permission *`
mutating commands and `/dtd revert` permission gate.

**Row format**:

```
<ts> | <dec_id> | <key> | <scope> | rule_match: <ts of rule or "default"> | decision: <auto-allow|auto-deny|asked|user-allow|user-deny|denied-explicit-rule|revoked-after-tombstone>
```

**Field semantics**:

- `<ts>` — ISO 8601 UTC timestamp of resolution.
- `<dec_id>` — decision capsule id IF this resolution required
  user input (e.g. `dec-009`). For auto-allow / auto-deny rows
  that did not surface a capsule, use the synthetic id
  `auto-<run>-<seq>` (e.g. `auto-001-042`). Synthetic ids are NOT
  recorded in `state.md` decision capsule fields.
- `<key>` — one of the 10 v0.2.0b permission keys.
- `<scope>` — the specific scope at resolution time (path /
  command / worker / capability — whichever applied to the
  proposed action). For `bash`: the exact command string.
  For `edit`: the resolved output path. For
  `tool_relay_mutating`: `<tool_name>: <args summary>`.
- `rule_match` — `<ts of matched ## Active rule>`, OR
  `default` for default-rule fallback, OR `dec-NNN (user)`
  when user resolved an `ask` capsule. The `<ts>` form
  references the rule timestamp at resolution time (rules are
  immutable; revoke adds tombstone, never edits).
- `decision` — one of:
  - `auto-allow` — matched `allow` rule; proceeded.
  - `auto-deny` — matched `deny` rule; aborted.
  - `asked` — matched `ask` rule; capsule filled (this is the
    "before user answered" row).
  - `user-allow` — user picked `allow_once` or `allow_always`.
  - `user-deny` — user picked `deny_once` or `deny_always`.
  - `denied-explicit-rule` — matched `deny` rule, AND the
    user previously confirmed it (from `deny_always` lineage).
  - `revoked-after-tombstone` — matched a rule that was later
    revoked; resolution treats it as inactive and falls through.

**One row per resolution event** (so an `ask` rule that the
user resolves with `allow_once` produces TWO rows: one `asked`
and one `user-allow`).

**Writer is the controller**, not the worker. Per
§Observational discipline below.

**Observational discipline**: writes to
`.dtd/log/permissions.md` are NOT considered run-state
mutations. They do not flip `state.md.last_writer`, they do
not increment `state.md.last_update_at` for permission-resolution
turns, and they do not appear in `state.md.recent_outputs`. They
ARE cross-checked by doctor:

- Audit log file size > 32 KB → WARN
  `permission_audit_log_too_large`.
- Audit row count exceeds active-rules count by > 100×: INFO
  `permission_audit_high_volume` (suggests reviewing
  `permission_bash_too_broad` patterns).
- Audit row references unknown rule timestamp: WARN
  `permission_audit_rule_drift`.

## Notes

- Rules are append-only here; `revoke` adds a tombstone row but does not
  remove prior history.
- Silent-mode transient rules (from v0.2.0f `silent_allow_*` config flags)
  are written here at `/dtd silent on` time with `until: <attention_until>`
  and `by: silent_window`. They expire automatically at silent-window end
  or are revoked by `/dtd interactive`.
- Doctor (v0.2.0b) flags overly-broad allow patterns and expired rules.

## Time-limited rules (v0.3.0e)

The `until` field accepts three syntactic forms:

| Form | Meaning |
|---|---|
| `<ISO ts>` | absolute UTC timestamp (existing v0.2.0b syntax) |
| `+<int><m\|h\|d\|w>` | duration from now (NEW; v0.3.0e) |
| `<named scope>` | named time scope (NEW; v0.3.0e) |

Single-unit durations only in v0.3.0e R0: `+1h`, `+30m`, `+2d`,
`+1w`. Combined units (`+1h30m`) DEFERRED to v0.3.x — rejected at
parse time with `permission_duration_combined_unsupported_v030e`.

**Named scopes** (v0.3.0e R0):

| Scope | Meaning | Resolves to |
|---|---|---|
| `today` | until 23:59:59 local time today | absolute ISO ts |
| `eod` | alias for `today` | absolute ISO ts |
| `this-week` | until next Monday 00:00 local time | absolute ISO ts |
| `next-monday` | alias for `this-week` (until next Monday 00:00) | absolute ISO ts |
| `next-week` | until 7 days after this-week | absolute ISO ts |
| `run` | until the active `/dtd run` finalize_run, or the next run's finalize_run if issued before a run starts | sentinel `run_end` |
| `run_end` | explicit form of `run` | sentinel `run_end` |

**`for <duration>` form**: equivalent UX wrapper. The user-facing
syntax is `for 1h` (relative) or `until eod` (absolute / named).
Mutually exclusive: a single rule cannot mix `for X until Y` —
parser rejects with `permission_duration_until_mixed_unsupported`.

`for run` is the user-facing alias for `until run_end`.

**Resolution at write time**: when a rule is appended with
duration or named-scope `until` form, controller computes the
absolute expiry timestamp AND stores it as a derived field
`resolved_until`. The original `until` form preserved for
audit; `resolved_until` is the canonical expiry checked by
runtime.

**Resolved row format** (v0.3.0e):

```text
<ts> | <decision> | <key> | scope: <expr> | until: <orig form> | resolved_until: <abs ts | run_end> | resolved_until_tz: <tz | UTC> | by: <who>
```

- `resolved_until: <abs ts>` — for `<ISO ts>` / `+<duration>` /
  named-time-scope forms.
- `resolved_until: run_end` — sentinel for `for run` /
  `until run_end`. Cleared at finalize_run by the v0.3.0e step 5c
  prune (see `reference/run-loop.md`).
- `resolved_until_tz`: timezone tag (e.g. `Asia/Seoul`,
  `America/Los_Angeles`, or `UTC`). REQUIRED for named local-time
  scopes (`today`, `eod`, `this-week`, etc.) so cross-machine
  sync (v0.3.0d) interprets unambiguously. For `<ISO ts>` and
  `+<duration>` forms, set to `UTC`.

Examples:

```text
2026-05-05 18:30 | allow | edit  | scope: src/**     | until: +1h        | resolved_until: 2026-05-05T19:30:00Z   | resolved_until_tz: UTC          | by: user
2026-05-05 18:30 | allow | bash  | scope: npm test   | until: for run    | resolved_until: run_end                | resolved_until_tz: UTC          | by: user
2026-05-05 18:30 | allow | edit  | scope: docs/**    | until: eod        | resolved_until: 2026-05-05T23:59:59+09:00 | resolved_until_tz: Asia/Seoul   | by: user
2026-05-05 18:30 | allow | edit  | scope: tests/**   | until: 2026-05-06T18:00:00Z | resolved_until: 2026-05-06T18:00:00Z   | resolved_until_tz: UTC          | by: user (legacy v0.2.0b form)
```

**Backward compatibility**: existing v0.2.0b `until: <ISO ts>`
rows have empty `resolved_until` field. Doctor surfaces these as
INFO `permission_until_unresolved_legacy_v020b` and recommends
re-writing to populate the derived field.
