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

## Audit log

Every permission resolution (allow/deny/ask) appends one row to
`.dtd/log/permissions.md` (gitignored, append-only). Format:

```
<ts> | <dec_id> | <key> | <scope> | rule_match: <ts of rule or "default"> | decision: <auto-allow|auto-deny|asked|user-allow|user-deny>
```

## Notes

- Rules are append-only here; `revoke` adds a tombstone row but does not
  remove prior history.
- Silent-mode transient rules (from v0.2.0f `silent_allow_*` config flags)
  are written here at `/dtd silent on` time with `until: <attention_until>`
  and `by: silent_window`. They expire automatically at silent-window end
  or are revoked by `/dtd interactive`.
- Doctor (v0.2.0b) flags overly-broad allow patterns and expired rules.
