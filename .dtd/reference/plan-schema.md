# DTD reference: plan-schema

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Plan Schema (XML), §Plan size budget & spill.

## Summary

Plans are markdown files with XML inline (`.dtd/plan-NNN.md`).

Top-level: `<plan-status>`, `<brief>`, `<phases>`, `<patches>`.

Phase XML:
```xml
<phase id="1" name="planning" target-grade="GOOD" max-iterations="5">
  <task id="1.1" parallel-group="A">
    <goal>...</goal>
    <worker>qwen-remote</worker>
    <capability>planning</capability>
    <work-paths>docs/, src/types/</work-paths>
    <output-paths predicted="true">docs/schema.md</output-paths>
    <context-files>...</context-files>
    <resources>
      <resource mode="write">files:project:docs/schema.md</resource>
    </resources>
    <done>false</done>
  </task>
</phase>
```

Optional v0.2.0f attributes on `<phase>` or `<task>`:
- `context-pattern="fresh|explore|debug"`
- `persona="<id>"`
- `reasoning-utility="<id>"`
- `tool-runtime="none|controller_relay|worker_native|hybrid"`

## Size budget

- Preferred: ≤ 12 KB
- Hard cap: 24 KB (`/dtd doctor` ERRORs above)
- Compact done tasks to one-liner: `<task id="X" worker="W" status="done" grade="GOOD" dur="Ns" log="..."/>`
- Patches policy: ≤ 5 inline ≤ 4 KB; spill to `plan-NNN-patches.md`.
- Brief: ≤ 2 KB.

## Anchor

See `dtd.md` §`## Plan Schema (XML)` and §`### Plan size budget & spill`
for full XML schema, compaction rules, brief/patches budget.

## Related topics

- `workers.md` — worker assignment in plans.
- `persona-reasoning-tools.md` — v0.2.0f optional attributes.
- `run-loop.md` — how plan XML drives run loop.
