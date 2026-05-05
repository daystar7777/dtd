# DTD reference: workers

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §Worker Registry & Routing,
> §Worker Dispatch — HTTP Transport.

## Summary

Worker registry lives in `.dtd/workers.md` (gitignored; per-user).
Schema reference: `.dtd/workers.example.md` (committed).

Required fields: `worker_id`, `endpoint`, `model`, `api_key_env`,
`max_context`, `tier`, `capabilities`, `permission_profile`.

Optional v0.2.0f fields:
- `tool_runtime: null | none | controller_relay | worker_native | hybrid`
- `native_tool_sandbox: true|false` (worker_native/hybrid require true)

Optional v0.2.1 fields (planned): `supports_session_resume`.

Routing precedence: explicit `<worker>` → exact `worker_id` → exact
alias → exact role → capability fuzzy → ambiguous (ask).

`/dtd workers add|test|list|rm|alias|role` for management.
v0.2.1 expands `/dtd workers test` into 14-stage health check.

## Dispatch

OpenAI-compatible HTTP transport. Three host modes:
- `plan-only`: manual paste between sessions.
- `assisted`: HTTP with optional per-call confirm.
- `full`: autonomous HTTP dispatch.

Error matrix: 200 OK | 401/403 AUTH_FAILED | 404 ENDPOINT_NOT_FOUND |
429 RATE_LIMIT_BLOCKED | 5xx WORKER_5XX_BLOCKED | timeout TIMEOUT_BLOCKED |
network NETWORK_UNREACHABLE | bad JSON MALFORMED_RESPONSE.

## Anchor

See `dtd.md` §`## Worker Registry & Routing` and §`## Worker Dispatch — HTTP Transport`
for full registry schema, alias resolution, permission profiles,
HTTP request/response shape, error handling, fallback chain.

## Related topics

- `persona-reasoning-tools.md` — worker tool runtime.
- `incidents.md` — dispatch failures become incidents.
- `autonomy.md` — silent mode dispatch policy.
