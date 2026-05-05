# DTD reference: load-profile (v0.2.3)

> Canonical reference for v0.2.3 Lazy-Load Profile.
> Lazy-loaded via `/dtd help load-profile --full`. Not auto-loaded.

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
3. Treat result as `effective_profile` for this turn.
4. Observational reads do not persist profile changes.
5. Mutating turns may update loaded_profile fields in the same atomic
   state write as the action.
6. Optional diagnostics go to `.dtd/log/profile-transitions.md`, never
   `steering.md`.

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
- `profile_transition_logging: false`
- `profile_transition_log_path: .dtd/log/profile-transitions.md`
- `aggressive_unload: false`  (advanced; off by default)

## Aggressive unload (advanced)

If host supports runtime context eviction (e.g., MCP-style dynamic tool
registration), `aggressive_unload: true` allows actually evicting
inactive sections from active context. Default false because most hosts
don't support this.

## Anchor

This file IS the canonical source for v0.2.3 Lazy-Load Profile.
`dtd.md` keeps the compact profile table, resolution summary, and
doctor-facing invariants.

Token caveat: lazy-load reduces controller cognitive scope by default.
It reduces prompt tokens only when the host honors selective loading or
aggressive unload.

## Related topics

- `run-loop.md` — running profile activates these.
- `incidents.md` + `autonomy.md` — recovery profile activates these.
- `perf.md` — measures actual token usage; do not claim savings unless
  the ledger shows them.
