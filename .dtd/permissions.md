# DTD Permission Ledger

> Source of truth for what the user has pre-approved.
> Append-only history; current state is the latest entry per (key, scope).
> Rule format:
>   `<ts> | <decision> | <key> | scope: <expr> [| worker: <id>] [| until: <ts>] | by: <who>`
>
> Read by controller before any permission-class action. See
> `dtd.md` §`/dtd permission` for command spec.

## Active rules

(Empty by default. Populated by `/dtd permission allow|deny|ask|revoke ...`
or by hand-edit. Latest-by-timestamp wins for the same (key, scope).)

## Default rules

> Apply when no `## Active rules` entry matches. Read-only template; user-set
> rules go in `## Active rules`.

- ask   | edit               | scope: *
- ask   | bash               | scope: *
- ask   | external_directory | scope: *
- ask   | task               | scope: *
- ask   | snapshot           | scope: *
- ask   | revert             | scope: *
- allow | todowrite          | scope: *           # always-safe; never blocks
- ask   | question           | scope: *           # questions to user; user choice

## Resolution algorithm

1. Compute `(key, scope, worker, capability)` for the proposed action.
2. Scan `## Active rules` from latest to oldest.
3. First rule whose key matches AND all specified scope/worker/capability
   filters match wins.
4. If `until` is past current time, treat rule as inactive and continue.
5. If no active rule matches, fall back to `## Default rules` for that key.
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
