# DTD reference: status-dashboard

> Canonical reference for `/dtd status` dashboard rendering.
> Lazy-loaded via `/dtd help status-dashboard --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

ASCII is the **canonical** rendering for v0.1 (deterministic across all
terminals). Unicode polish is optional and may be enabled in `config.md`
if the terminal supports it.

Compact `/dtd status` shows: header, goal, current task, worker, work
paths, writing files, locks, elapsed time, recent done bullets, queue,
pause hint.

- v0.2.0a adds: incident line when `active_blocking_incident_id` set.
- v0.2.0f adds: `modes`, `ctx`, and `ctrl` (--full) lines.

## Default compact dashboard

`/dtd status` (default = `--compact`):

```
+ DTD plan-001 [RUNNING] phase 2/5 backend-api | iter 1/3 | NORMAL < GOOD | gate RETRY | ctx 61% | total 42m
| goal      e-commerce 백엔드 API + 프론트엔드 + 코드 리뷰
| current   2.1 API endpoints
| worker    deepseek-local (tier 1)   profile=code-write
| modes     ask permission | attention silent 3h12m left
| ctx       fresh | handoff standard | t=0.0 s=1
| work      src/api/**
| writing   src/api/users.ts, src/api/products.ts  (live)
| locks     write files:project:src/api/**
| elapsed   total 42m | phase 8m | task 5m12s
+ recent
| * 1.1 schema 작성    [qwen-remote]   docs/schema.md         GREAT  18s
| * 1.2 ER diagram     [qwen-remote]   docs/er-diagram.md     GREAT  12s
+ queue
| -> 2.2 auth middleware    [deepseek-local]   src/auth/**
| -> 3.1 React 컴포넌트     [deepseek-local]   src/ui/**
| -> 4.1 코드 리뷰          [gpt-codex]        docs/review-001.md
+ pause anytime: /dtd pause  or  "잠깐 멈춰"
```

## v0.2.0f mode/ctx lines (compact rendering rules)

The compact dashboard renders two new lines (after `worker` and before `work`)
when the relevant state is non-default:

```
| modes     ask permission | attention silent 3h12m left
| ctx       fresh | handoff standard | t=0.0 s=1
```

Rendering rules:

| Condition | Render? |
|---|---|
| `decision_mode != permission` OR `attention_mode != interactive` OR `deferred_decision_count > 0` | render `modes` line |
| `state.md.resolved_context_pattern` is non-null | render `ctx` line |
| any resolved persona/reasoning/tool-runtime field is non-null | render `ctrl` line in `--full` |
| Both default + nothing deferred + no resolved pattern (e.g. between dispatches) | omit both lines |

Dashboard load policy: `/dtd status` reads only `state.md` and compact indexes.
It MUST NOT load the full persona/reasoning/tool catalog. `/dtd status --full`
may show resolved ids, but explanations belong in `/dtd help` or `dtd.md`.

`modes` line content:
- `ask <decision_mode>` — always shown when this line renders.
- `attention <interactive|silent>` — shown when not default. If silent, append
  countdown `<H>h<M>m left` derived from `attention_until - now`.
- `deferred <N>` — shown when `deferred_decision_count > 0`.
- Total line width ≤ 80; if overflow, drop the deferred segment and surface
  it on its own line below the modes line.

`ctx` line content:
- `<resolved_context_pattern>` — `fresh` / `explore` / `debug`.
- `handoff <resolved_handoff_mode>` — `standard` / `rich` / `failure`.
- Sampling shorthand from `resolved_sampling`. e.g. `t=0.0 s=1` for
  `temperature=0.0 samples=1`. Compact one-token-per-knob format.
- Total line width ≤ 80.

`/dtd status --full` adds one more line below `ctx` listing the next-task
resolved pattern (when known): `| ctx-next   <pattern> for next task <id>`.
If persona/reasoning/tool-runtime controls are active, `--full` also renders a
compact line:

```text
| ctrl      persona debugger | reason tool_critic | tools relay
```

Use `tools relay` for `controller_relay`, `native` for `worker_native`, and
omit default/null segments to stay within 80 columns.

When `attention_mode: silent` and the silent window has ended, the controller
pauses at the next safe boundary and preserves silent mode. The next
`/dtd status` may show a compact "silent window ended" summary INSTEAD of the
regular dashboard, but status remains observational and does not flip state.
The full morning-summary flow starts when the user runs `/dtd interactive`.

## v0.2.0a incident line

When an active blocking incident exists, the dashboard adds **one**
compact line in the status body before `recent`:

```
| incident   inc-001-0001 blocked NETWORK_UNREACHABLE  next:retry
```

The line stays within `dashboard_width: 80` (per scenario 23 width policy). The
suffix `next:<option_id>` uses just the resolve option id (e.g. `retry`,
`switch_worker`, `stop`). The full canonical command
`/dtd incident resolve <id> <option>` is shown only in `/dtd incident show <id>`
output, and as a multi-line hint block below the dashboard:

```
+ next:
| show    /dtd incident show inc-001-0001
| resolve /dtd incident resolve inc-001-0001 <option>
```

Each line of the hint block stays under 80 chars (the longest, with a 12-char id,
is 56 chars). The hint block is suppressed in plan-only host mode and in `--compact`
when terminal is narrower than `dashboard_width`. `--full` adds non-blocking warn
incidents (last 3) under a separate `+ recent incidents` panel. `info` incidents
are NOT shown in compact dashboard (only in `--full`'s history view).

## Glyph reference (ASCII canonical)

| Concept | ASCII | Unicode (optional) |
|---|---|---|
| section header | `+` | `┌` `└` `├` |
| recent done bullet | `*` | `✓` |
| queue arrow | `->` | `→` |
| current marker | `>` | `▶` |
| pause hint | `[P]` | `⏸` |
| separator | `|` | `│` |

## Flags

- `--compact` (default): single-screen summary
- `--full`: include phase history table + recent steering + active patches + lease list
- `--plan`: same as `/dtd plan show`
- `--history`: load `phase-history.md`, render full table
- `--eval`: list eval files in `.dtd/eval/`, render most recent

## Format config in `config.md`

```markdown
- dashboard_style: ascii      # ascii (default) | unicode
- dashboard_width: 100
- progress_report: every_phase | every_task | none
- display_worker_format: alias | id | both
```

If `dashboard_style: unicode`, controller probes the terminal's encoding
support; falls back to `ascii` if it can't safely render box-drawing chars.

## Anchor

This file IS the canonical source for v0.1+ Status Dashboard rendering
rules + glyphs + flags + v0.2.0a incident line + v0.2.0f mode/ctx/ctrl
lines.
v0.2.3 R1 extraction completed; `dtd.md` §`## Status Dashboard` now
points here.

## Related topics

- `autonomy.md` — modes/ctx/ctrl line render conditions.
- `incidents.md` — incident line in compact dashboard.
- `perf.md` — perf renders separately from status; not part of dashboard.
