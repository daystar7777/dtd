# DTD help: plan

## Summary

Planning commands. `/dtd plan <goal>` produces a DRAFT plan; `/dtd plan
show` inspects; `/dtd plan worker` swaps assignments while DRAFT.
After `approve`, plan changes go through steering patches.

## Quick examples

```text
/dtd plan "add user CRUD endpoints"      generate DRAFT plan
/dtd plan show                           summary
/dtd plan show --task 2.1                detail one task
/dtd plan show --workers                 worker assignment view
/dtd plan worker phase:2 deepseek        swap workers (DRAFT only)
/dtd plan worker 3.1 codex               swap one task
```

## Canonical commands

- `/dtd plan <goal>` — controller produces DRAFT plan-NNN.md.
- `/dtd plan show [--task N|--phase N|--brief|--patches|--workers|--paths]`
- `/dtd plan worker <task_id|phase:N|all> <worker>` — DRAFT only.

## Plan XML schema (excerpt)

```xml
<phase id="1" name="planning" target-grade="GOOD" max-iterations="5">
  <task id="1.1" parallel-group="A">
    <goal>schema 작성</goal>
    <worker>qwen-remote</worker>
    <capability>planning</capability>
    <work-paths>docs/, src/types/</work-paths>
    <output-paths predicted="true">docs/schema.md</output-paths>
  </task>
</phase>
```

Optional v0.2.0f attributes on `<phase>` or `<task>`:
- `context-pattern="fresh|explore|debug"`
- `persona="planner|implementer|debugger|..."`
- `reasoning-utility="direct|least_to_most|react|..."`
- `tool-runtime="none|controller_relay|worker_native|hybrid"`

## State changes

- DRAFT — free to edit / swap workers.
- APPROVED — locked; changes go through steering.

## NL phrases

- `"계획 짜줘"` / `"이 목표로 정리"` → `/dtd plan <goal>`
- `"task N은 X로"` → DRAFT swap or steering patch (state-aware)

## Next topics

- `/dtd help run` — execute the plan.
- `/dtd help steer` — change direction mid-run.
