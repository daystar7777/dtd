# DTD help: stuck

## Summary

When DTD is stuck on a blocking incident. Walks through inspect →
choose recovery → resume. Incidents fire when a recoverable failure
becomes blocking (per the v0.2.0a error matrix).

## Quick examples

```text
/dtd status                                  see "incident" line in dashboard
/dtd incident show inc-001-0001              detailed failure + options
/dtd incident resolve inc-001-0001 retry     re-dispatch same task
/dtd incident resolve inc-001-0001 switch_worker
/dtd incident resolve inc-001-0001 stop      destructive — confirms
```

## Recovery flow

1. `/dtd status` shows compact incident line if active blocker exists:
   `| incident   inc-001-0001 blocked NETWORK_UNREACHABLE  next:retry`
2. `/dtd incident show <id>` — full detail: severity, recoverable, side
   effects, recovery options.
3. Pick a recovery option per `/dtd incident resolve <id> <option>`.
4. Controller acts on chosen option's effect; resume per `decision_resume_action`.

## Common recovery options

| Option | Effect | Risk |
|---|---|---|
| `retry` | re-dispatch same task | may fail same way |
| `switch_worker` | advance fallback chain | different cost/quality |
| `manual_paste` | paste manual response (rare) | breaks audit trail |
| `wait_once` | wait then retry (timeout, rate-limit) | may waste time |
| `controller_takeover` | controller does it (REVIEW_REQUIRED) | no worker grade |
| `stop` | finalize_run(STOPPED) — destructive | lose run progress |

## Multi-blocker

At most ONE active blocking incident. Second blocker waits in
`.dtd/log/incidents/index.md`. Resolve first → controller promotes
oldest-unresolved-blocker per spec.

## NL phrases

- `"지금 막힌 거 뭐야"` → `incident show <active>`
- `"그 에러 retry"` → `incident resolve <id> retry`
- `"그 에러 멈춰"` → `incident resolve <id> stop` (destructive — confirms)

## Next topics

- `/dtd help recover` — broader recovery surface (incident + pause + stop).
- `/dtd help observe` — status reads that don't change run state.
