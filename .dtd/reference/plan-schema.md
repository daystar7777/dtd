# DTD reference: plan-schema

> Canonical reference for Plan Schema (XML) + size budget.
> Lazy-loaded via `/dtd help plan-schema --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

Plans are XML files at `.dtd/plans/plan-NNN.md`. Top-level structure:
`<plan-status>` + `<brief>` + `<phases>` (containing `<task>` rows
with worker/capability/paths/resources) + `<patches>`. Completed
tasks compact to one-line form; full bodies archive to
`plan-NNN-history.md`.

## Plan Schema (XML)

```xml
<plan-status>DRAFT</plan-status>

<brief>
goal: <2-4 sentences>
approach: <high-level shape>
non-goals: <if relevant>
</brief>

<phases>
  <phase id="1" name="planning" target-grade="GOOD" max-iterations="5">
    <task id="1.1" parallel-group="A">
      <goal>schema 작성</goal>
      <worker>qwen-remote</worker>
      <worker-resolved-from>role:planner</worker-resolved-from>
      <capability>planning</capability>
      <work-paths>docs/, src/types/</work-paths>
      <output-paths predicted="true">docs/schema.md</output-paths>
      <context-files>src/types/api.ts</context-files>
      <resources>
        <resource mode="write">files:project:docs/schema.md</resource>
      </resources>
      <done>false</done>
    </task>
    <!-- ...more tasks... -->
  </phase>
  <!-- ...more phases... -->
</phases>

<patches>
  <!-- empty until steering creates one -->
</patches>
```

Completed tasks are compacted to one-line form to save context:

```xml
<task id="1.1" worker="qwen-remote" status="done" grade="GREAT" dur="18s" log="exec-001-task-1.1.qwen-remote.md"/>
```

Original full task body is archived to `plan-NNN-history.md` if
compaction loses important detail. Compaction trigger: any task
transitioning to `done` AND plan size > 8 KB.

## v0.2.0f optional attributes

On `<phase>` or `<task>`:
- `context-pattern="fresh|explore|debug"`
- `persona="<id>"` (resolves to `config.md persona_patterns`)
- `reasoning-utility="<id>"` (resolves to
  `config.md reasoning_utilities`)
- `tool-runtime="none|controller_relay|worker_native|hybrid"`

## Plan size budget & spill

- **Preferred**: `plan-NNN.md` ≤ 12 KB
- **Hard cap**: 24 KB (`/dtd doctor` ERRORs above this)

Patches policy:

- ≤ 5 patches AND ≤ 4 KB → keep in `<patches>` section
- exceed → spill: keep latest 1 patch summary inline, full history
  → `plan-NNN-patches.md`
- Applied patches → migrated to `phase-history.md` or
  `log/run-NNN-summary.md` with pointer

Brief: bounded (≤ 2 KB) — large rationale belongs in `PROJECT.md`.

## Anchor

This file IS the canonical source for Plan Schema XML structure +
v0.2.0f optional attributes + compaction rule + size budget +
patches spill policy.
v0.2.3 R1 extraction completed; `dtd.md` §Plan Schema (XML) now
points here.

## Related topics

- `run-loop.md` — plan is consumed by run loop dispatch.
- `workers.md` — `<worker>` / `<capability>` resolution.
- `persona-reasoning-tools.md` — `<persona>` /
  `<reasoning-utility>` / `<context-pattern>` plan attributes.
