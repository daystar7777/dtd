# DTD reference: persona / reasoning utilities / tool runtime (v0.2.0f addendum)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Persona, Reasoning, and Tool-Use Patterns.

## Summary

Codex R0 addendum to v0.2.0f. Three compact controls per phase/task:

**Personas** (7): `operator`, `planner`, `researcher`, `implementer`,
`debugger`, `reviewer`, `release_guard`. Compact stance ≤120 words; not
role-play biographies. NEVER overrides security/permission/destructive
rules.

**Reasoning utilities** (7): `direct`, `least_to_most`, `react`,
`tool_critic`, `self_refine`, `tree_search`, `reflexion`. Hidden
reasoning may be used; DTD persists ONLY decision/evidence_refs/risks/
next_action + ≤5 line summary. Raw chain-of-thought NEVER requested,
revealed, or stored.

**Tool runtime** (4 modes): `none`, `controller_relay` (default),
`worker_native`, `hybrid`. controller_relay: worker emits
`::tool_request::`, controller validates + runs + logs sanitized
output, passes compact result + log ref to next fresh dispatch.
worker_native requires registry-level `tool_runtime: worker_native|
hybrid` AND `native_tool_sandbox: true`.

Plan XML attributes (optional, back-compat): `persona`,
`reasoning-utility`, `tool-runtime` on phase/task. Task overrides
phase. Capability defaults in `.dtd/config.md`.

state.md resolved fields: `resolved_controller_persona`,
`resolved_worker_persona`, `resolved_reasoning_utility`,
`resolved_tool_runtime`. Cleared by finalize_run.

## Anchor

See `dtd.md` §`## Persona, Reasoning, and Tool-Use Patterns (v0.2.0f Codex R0 addendum)`
for full pattern set, plan XML schema, prompt injection rules, output
contracts, controller-relay contract, worker-native contract.

## Related topics

- `autonomy.md` — v0.2.0f base release.
- `permissions.md` (planned) — tool_relay_read/mutating permission gating.
- `workers.md` — `tool_runtime` + `native_tool_sandbox` registry fields.
