# DTD reference: persona / reasoning utilities / tool runtime (v0.2.0f addendum)

> Canonical reference for v0.2.0f Codex addendum (personas + reasoning
> utilities + tool runtime). Lazy-loaded via
> `/dtd help persona-reasoning-tools --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

These controls sit beside `context-pattern`. They are selected by the
controller during planning and resolved before each worker dispatch.
They are short behavioral stances and execution utilities, not long
role-play prompts.

## Load policy

- Always-loaded `.dtd/instructions.md` keeps only the router, reset
  contract, and safety rules for these controls.
- This detailed catalog lives here in `.dtd/reference/persona-reasoning-tools.md`
  and is loaded only when planning, changing, explaining, or
  doctor-checking persona/reasoning/tool behavior.
- Worker prompts receive only the resolved compact capsule, not this
  catalog.

## Design constraints

- Persona text is a compact stance line, not biography or decorative
  role-play.
- Persona can NEVER override security, permission profiles, path policy,
  destructive confirmation, secret redaction, or user decisions.
- Do not request, reveal, or store raw chain-of-thought. Use private
  reasoning internally and persist only concise rationale, decision,
  evidence, and next-action summaries.
- Tool use is explicit. Workers either use a trusted native tool
  runtime, or ask the controller for a validated relay between
  dispatches.

## Persona patterns

Default pattern set:

| id | Best phase/task | Controller stance | Worker stance |
|---|---|---|---|
| `operator` | run orchestration, silent mode | keep progress, surface blockers tersely | follow exact scope, report only deltas |
| `planner` | phase 0, decomposition | make dependencies and decision points explicit | produce options and tradeoffs |
| `researcher` | unknown codebase, external references | ask what evidence is missing | gather facts, cite refs, avoid edits |
| `implementer` | code-write/refactor | minimize blast radius | patch the declared outputs cleanly |
| `debugger` | failing task/retry/incident | isolate repro and smallest fix path | use evidence, logs, and hypotheses |
| `reviewer` | review/verification | look for correctness and UX regressions | report findings, not broad rewrites |
| `release_guard` | final phase/ship check | verify docs/tests/state consistency | check acceptance criteria and risks |

Resolution order:

1. Task `persona="<id>"`.
2. Phase `persona="<id>"`.
3. Capability default in `.dtd/config.md`.
4. Context pattern default (e.g. `debug` -> `debugger`).
5. Global default (`operator` for controller, `implementer` for workers).

Plan XML attributes are optional and back-compatible:

```xml
<phase id="1" name="architecture" context-pattern="explore"
       persona="planner" reasoning-utility="least_to_most">
  <task id="1.1" persona="researcher" reasoning-utility="react"
        tool-runtime="controller_relay">
    ...
  </task>
</phase>
```

Prompt injection rule:

- Add a compact `<persona>` capsule inside the task-specific section:
  `controller=<id>; worker=<id>; stance="<one sentence>"`.
- Keep it under 120 words total.
- Do not add demographic, fictional, or irrelevant traits. If a
  requested persona contains irrelevant traits, strip them and keep
  only domain stance.

## Reasoning utilities

Default utility set:

| id | Best use | Behavior |
|---|---|---|
| `direct` | simple code-write, safe refactor | concise plan, execute, summarize |
| `least_to_most` | complex phase planning | split into ordered subproblems first |
| `react` | research/tool-heavy tasks | alternate plan/action/observation summaries |
| `tool_critic` | verification, bug hunting | use external checks, then revise |
| `self_refine` | writing/docs/UI polish | draft, critique, refine within budget |
| `tree_search` | architecture/UX alternatives | sample small option set, choose with rubric |
| `reflexion` | repeated failure | store one compact lesson for next retry |

Reasoning output contract:

- Hidden/private reasoning may be used by the model, but DTD persists
  only: `decision`, `evidence_refs`, `risks`, `next_action`, and at
  most 5 lines of rationale summary.
- For `tree_search` and `self_consistency`-style sampling, store option
  ids and final rubric scores, not raw candidate chains.
- `reflexion` writes a compact lesson to notepad/attempt history only
  after a concrete external signal (test failure, reviewer finding,
  incident, or user correction). No free-floating self-talk.

## Provider thinking levels

Provider thinking/reasoning level is separate from DTD reasoning
utilities. Utilities describe the public work pattern; provider
thinking controls a model-specific transport option such as DeepSeek
thinking level or OpenAI reasoning effort.

Default policy:

| Role | Default provider thinking | Notes |
|---|---|---|
| DTD controller | `low` | repeated orchestration calls; apply only if provider supports it |
| file-output worker | `disabled` | protects `===FILE:===` output from empty-content failures |
| test-program worker | `disabled` | tests must be emitted in `content`, not hidden reasoning |
| verifier / scorekeeper | `max` | rare judgment calls; formula-bound scoring still required |

Rules:

- Apply `low` / `max` only for providers and host runtimes that
  explicitly support them. Unsupported providers omit the field.
- Never parse `reasoning_content`, hidden thinking blocks, or private
  reasoning as worker output.
- If a response has empty `content` but non-empty hidden reasoning,
  classify it as an output failure and retry with thinking disabled or
  a larger output budget, depending on task role.
- Persist only concise public rationale summaries and evidence refs.
  Raw chain-of-thought or provider reasoning text is never saved.

## Tool-use runtime policy

Workers have four tool modes:

| mode | Meaning | Default |
|---|---|---|
| `none` | worker cannot call tools | safe fallback |
| `controller_relay` | worker emits a structured tool request; controller validates and runs it between dispatches | default |
| `worker_native` | worker engine has its own sandboxed tools | opt-in only |
| `hybrid` | worker-native for read-only tools, controller relay for writes | advanced |

Controller relay contract:

1. Worker returns `::tool_request::` as the terminal status instead of
   claiming it ran the tool.
2. Controller validates requested command/API against permission
   profile, resource locks, path policy, network policy, and tool
   allowlist.
3. Controller executes the tool outside the worker transcript, saves
   full sanitized output to `.dtd/log/tool-<run>-task-<id>-<seq>.md`,
   and passes only a compact result summary + log ref into the next
   fresh worker dispatch.
4. Mutating file writes still go through `===FILE: <path>===` blocks
   and the controller apply pipeline. Relay tools do not bypass
   validation/apply.

Worker-native contract:

- Allowed only when the engine exposes a trusted sandbox boundary and
  DTD can record `tool_runtime: worker_native` in `state.md`.
- Worker registry must explicitly set `tool_runtime: worker_native`
  (or `hybrid`) and `native_tool_sandbox: true`; otherwise resolve
  back to `controller_relay` or block with `PERMISSION_REQUIRED`.
- Worker returns a compact tool transcript summary and durable log
  refs.
- The controller still validates final output paths before apply.

## Anchor

This file IS the canonical source for v0.2.0f persona/reasoning/tool
addendum. v0.2.3 R1 extraction completed; `dtd.md` §Persona, Reasoning,
and Tool-Use Patterns now points here.

## Related topics

- `autonomy.md` — v0.2.0f base release (3 axes; silent algorithm).
- `permissions.md` (planned v0.2.0b) — `tool_relay_read` /
  `tool_relay_mutating` permission gating for `controller_relay`.
- `workers.md` — `tool_runtime` + `native_tool_sandbox` registry fields.
