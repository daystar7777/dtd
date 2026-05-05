# DTD reference: status-dashboard

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Status Dashboard.

## Summary

ASCII canonical rendering for v0.1+. Width: `dashboard_width: 100`
default; scenario 23 enforces ≤ 80 columns when `dashboard_width: 80`.

Compact `/dtd status` shows: header, goal, current task, worker, work
paths, writing files, locks, elapsed time, recent done bullets, queue,
pause hint.

v0.2.0a adds: incident line when `active_blocking_incident_id` set.

v0.2.0f adds:
- `modes` line when `decision_mode != permission` OR
  `attention_mode != interactive` OR `deferred_decision_count > 0`
- `ctx` line when `resolved_context_pattern` non-null
- `ctrl` line in `--full` when persona/reasoning/tool resolved fields set

## Glyphs (ASCII canonical)

```
+ section header
| separator
* recent done bullet
-> queue arrow
> current marker
[P] pause hint
```

`dashboard_style: unicode` falls back to ASCII if terminal can't render
box-drawing.

## Anchor

See `dtd.md` §`## Status Dashboard` for full sample output, glyph
reference, flag matrix (--compact/--full/--plan/--history/--eval),
v0.2.0f rendering rules, morning summary integration.

## Related topics

- `autonomy.md` — modes/ctx/ctrl line render conditions.
- `incidents.md` — incident line in compact dashboard.
- `perf.md` — perf renders separately from status.
