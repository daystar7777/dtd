# DTD reference: incidents (v0.2.0a TAGGED)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Incident Tracking.

## Summary

v0.2.0a introduced durable incident tracking. Operational failures that
need cross-session visibility become incidents in
`.dtd/log/incidents/inc-<run>-<seq>.md` plus `.dtd/log/incidents/index.md`.

5 state.md fields: `active_incident_id`, `active_blocking_incident_id`,
`last_incident_id`, `incident_count`, `recent_incident_summary`.

Severity → state mapping:
- `info` — observational; populates recent_incident_summary only.
- `warn` — non-blocking; sets active_incident_id.
- `blocked` — fills decision capsule with INCIDENT_BLOCKED.
- `fatal` — same as blocked + finalize_run(FAILED) on ack.

Multi-blocker invariant: ≤ 1 active blocker; queue lives in
`.dtd/log/incidents/index.md` (NOT recent_incident_summary).

Recovery: `/dtd incident list/show/resolve <id> <option>`. Destructive
options (stop/purge/delete/...) ALWAYS confirm.

## Anchor

See `dtd.md` §`## Incident Tracking (v0.2.0a)` for incident schema,
severity mapping, multi-blocker policy, info-severity triggers,
cross-link integrity, resolve logic, finalize_run integration.

## Related topics

- `autonomy.md` — silent mode defers via incident snapshot.
- `doctor-checks.md` — 7 incident-state checks.
- `permissions.md` (planned) — `/dtd incident resolve` permission gating.
