# DTD Permission Ledger

> Source of truth for what the user has pre-approved.
> Append-only history; current state is resolved by key, scope specificity,
> and timestamp.
> Rule format:
>   `<ts> | <decision> | <key> | scope: <expr> [| worker: <id>] [| until: <ts>] | by: <who>`
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
3. Drop rules whose `until` is past current time.
4. Sort remaining matches by scope specificity DESC, then timestamp DESC.
   Specificity order: exact path/command > longer glob/prefix > shorter
   glob/prefix > `*`; worker/capability filters add specificity.
5. First sorted rule wins. If no active rule matches, fall back to
   `## Default rules` for that key.
6. Apply the matched decision:
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
