# DTD reference: autonomy (v0.2.0f)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Autonomy & Attention Modes.

## Summary

v0.2.0f introduced three independent autonomy axes:

| Axis | Values | Meaning |
|---|---|---|
| `host.mode` | plan-only / assisted / full | apply authority |
| `decision_mode` | plan / permission / auto | how often to ask |
| `attention_mode` | interactive / silent | ask now vs defer |

Silent-mode "ready work" algorithm defers safe-to-defer blockers and
continues independent ready tasks. Defer triggers (AUTH_FAILED,
DISK_FULL, PERMISSION_REQUIRED, paid fallback, destructive option, etc.)
create incidents + snapshot capsules into `deferred_decision_refs`.
`silent_deferred_decision_limit: 20` (default) hard caps backlog.

`/dtd silent on/off`, `/dtd interactive`, `/dtd mode decision <mode>`,
`/dtd run --silent=<duration>`, `/dtd run --decision <mode>`.

NO auto-flip silent → interactive on any trigger
(`silent_deferred_decision_limit`, `attention_until` expiry, or
`CONTROLLER_TOKEN_EXHAUSTED`). User explicitly runs `/dtd interactive`
to surface morning summary.

## Anchor

See `dtd.md` §`### Autonomy & Attention Modes (v0.2.0f)` for full spec
including silent ready-work algorithm, defer trigger table,
CONTROLLER_TOKEN_EXHAUSTED capsule body, morning summary format.

## Related topics

- `persona-reasoning-tools.md` — v0.2.0f Codex addendum.
- `perf.md` — `/dtd perf` controller vs worker token separation.
- `incidents.md` — silent-mode defer integrates with incident tracking.
