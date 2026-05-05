# DTD help: workers

## Summary

Worker registry commands. `add` is an interactive wizard; `test`
verifies a worker is reachable; `list` shows registered workers.
Workers route by capability + role + alias resolution.

## Quick examples

```text
/dtd workers add                       interactive wizard
/dtd workers test <id>                 basic connectivity probe
/dtd workers list                      registry + status
/dtd workers alias add <id> <alias>    add an alias for routing
/dtd workers role set <role> <id>      e.g. set reviewer role
/dtd workers rm <id>                   remove worker (audit-safe)
```

## Canonical commands

- `/dtd workers add` — wizard collects fields per `workers.example.md` schema.
- `/dtd workers test <id>` — basic probe (v0.2.0a) or 14-stage check (v0.2.1+).
- `/dtd workers list [--enabled-only]` — observational.
- `/dtd workers rm <id>` — destructive; confirm always.
- `/dtd workers alias add|rm <id> <alias>` — alias for NL routing.
- `/dtd workers role set <role> <id>` — assigns canonical role.

## Worker registry fields

In `.dtd/workers.md`:
- `worker_id` (kebab-case, required)
- `endpoint`, `model`, `api_key_env`
- `max_context`, `tier`, `capabilities`, `aliases`
- `permission_profile` (explore | review | planning | code-write | controller)
- `tool_runtime` + `native_tool_sandbox` (v0.2.0f)

## Naming resolution precedence

1. exact `worker_id`
2. exact `alias`
3. exact `role` name
4. capability fuzzy match
5. ambiguous → ask

## Next topics

- `/dtd help start` — first-run flow includes worker setup.
- `/dtd help update` — worker check evolution in v0.2.1.
