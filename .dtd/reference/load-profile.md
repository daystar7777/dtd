# DTD reference: load-profile (v0.2.3)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Lazy-Load Profile.

## Summary

Controller-side cognitive scoping hint to reduce per-turn focus area.
4 profiles ordered as supersets:

```
minimal ⊂ planning ⊂ running ⊂ recovery
```

| Profile | When | Active sections |
|---|---|---|
| `minimal` | mode off OR no plan | TL;DR, intent gate, status/doctor |
| `planning` | DRAFT/APPROVED | + NL routing, plan/approve, worker registry |
| `running` | RUNNING/PAUSED | + run loop, dispatch, autonomy, context patterns |
| `recovery` | pending_patch OR active blocker | + incident commands, recovery surface |

## Resolution

Per-turn protocol step 1.5 (after read state.md, before Intent Gate):

1. Read state.md mode/plan_status/pending_patch/active_blocking_incident_id.
2. Apply rules (see dtd.md §Lazy-Load Profile resolution).
3. If profile changed: update state.md atomically; log to steering.md.
4. Use resolved profile's section set as turn's active cognitive scope.

## state.md fields

```yaml
- loaded_profile: minimal           # minimal | planning | running | recovery
- loaded_profile_set_at: null
- loaded_profile_reason: null       # mode_off | no_plan | draft_or_approved | running_or_paused | active_blocker | pending_patch
```

## config.md

`config.md.load-profile`:
- `profile_resolution_mode: state_driven | manual | auto_probe`
- `default_profile: minimal`
- `profile_sections: {minimal: [...], planning: [...], running: [...], recovery: [...]}`
- `profile_transition_logging: true`
- `aggressive_unload: false`  (advanced; off by default)

## Aggressive unload (advanced)

If host supports runtime context eviction (e.g., MCP-style dynamic tool
registration), `aggressive_unload: true` allows actually evicting
inactive sections from active context. Default false because most hosts
don't support this.

## Anchor

See `dtd.md` §`## Lazy-Load Profile (v0.2.3)` for full resolution rules,
section coverage, profile boundaries, doctor checks, token economy
impact, NL routing.

## Related topics

- `run-loop.md` — running profile activates these.
- `incidents.md` + `autonomy.md` — recovery profile activates these.
- `perf.md` — measures actual token usage; lazy-load reduces it.
