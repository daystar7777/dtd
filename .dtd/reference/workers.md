# DTD reference: workers

> Canonical reference for worker registry + routing + dispatch.
> Lazy-loaded via `/dtd help workers --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

Worker registry lives in `.dtd/workers.md` (gitignored; per-user).
Schema reference: `.dtd/workers.example.md` (committed). Workers
dispatch via OpenAI-compatible chat-completions HTTP. Three host
modes: `plan-only` (manual paste), `assisted` (HTTP with optional
per-call confirm), `full` (autonomous HTTP).

## Worker Registry & Routing

`workers.md` schema (excerpt — see template for full):

```markdown
## <worker_id>
- aliases: <comma-separated nicknames>
- display_name: <preferred nickname for status output>
- endpoint: <OpenAI-compatible URL>
- model: <model identifier per provider>
- api_key_env: <ENV_VAR_NAME>          # never inline raw keys
- max_context: <token int>
- soft_context_limit: 70
- hard_context_limit: 85
- emergency_context_limit: 95
- capabilities: <comma list — code-write, code-refactor, review, planning, debug, ...>
- cost_tier: free | paid
- priority: <int — higher first>
- tier: 1|2|3
- failure_threshold: <int>
- escalate_to: <next worker_id, or `user`>
```

### Routing precedence (when task has no explicit `<worker>`)

1. Task has `<worker>X</worker>` → use X (manual override).
2. Task has `<capability>Y</capability>`:
   a. Filter workers with capability Y.
   b. Sort: priority desc, then cost_tier (free first), then tier asc.
   c. Pick top. On failure, advance escalate_to chain.
3. No explicit hint → use `config.md` `roles.primary`.
4. All resolution failed → controller asks user.

### NL alias / role resolution

Order:

1. exact `worker_id` match
2. exact `alias` match (across all workers)
3. exact `role` name match (look up `config.md` `roles.<name>`)
4. capability fuzzy (e.g. "리뷰어" → role:reviewer or capability:review)
5. ambiguous → confirm

If a phrase matches both `controller.name` and a worker alias: confirm
which.

## Worker Output Discipline

See `.dtd/worker-system.md` for the prompt prefix. Summary:

- ONE fenced code block per file, prefixed `===FILE: <path>===`
- ONE summary line `::done:: <≤80 chars>` OR `::blocked:: <reason>`
- Optional: `::ctx:: used=<%> status=ok|soft_cap|hard_cap` (advisory;
  controller computes authoritatively)
- NO explanations, NO markdown headers outside fences, NO apologies,
  NO "Here is the code"

Controller parses these markers strictly. Malformed output triggers
`failure_count_iter++`.

## Worker Dispatch — HTTP Transport

This is the actual recipe for making a worker call. Per-mode
(plan-only / assisted / full) the recipe is the same below; the
difference is who triggers it.

### Request shape (OpenAI-compatible chat completions)

```
POST <worker.endpoint>
Headers:
  Authorization: Bearer ${env[worker.api_key_env]}
  Content-Type: application/json
Body (JSON):
{
  "model": "<worker.model>",
  "messages": [
    {"role": "system", "content": "<system_prompt>"},
    {"role": "user",   "content": "<user_prompt>"}
  ],
  "max_tokens":  <reserved_output_budget>,

  // Tuning fields below are MERGED from worker config (workers.md).
  // Defaults applied if worker doesn't set them:
  "temperature": <worker.temperature ?? 0.0>,
  "top_p":       <worker.top_p ?? 1.0>,
  "stream":      <worker.stream ?? false>,         // v0.1 enforces false; v0.2 will allow true
  // optional, only included if set in worker config:
  "seed":              <worker.seed>,
  "stop":              <worker.stop as array>,
  "response_format":   <worker.response_format>,   // text | {"type": "json_object"}
  "frequency_penalty": <worker.frequency_penalty>,
  "presence_penalty":  <worker.presence_penalty>,
  "reasoning_effort":  <worker.reasoning_effort>,  // OpenAI o1/o3/gpt-5 reasoning models
  // shallow-merged at top level for provider-specific:
  ...<worker.extra_body>
}
```

`<system_prompt>` = concatenation of (in this exact order, per
§Token Economy #2):
1. `worker-system.md`
2. `PROJECT.md`
3. `notepad.md` `<handoff>` section only
4. `skills/<capability>.md` (if applicable)

`<user_prompt>` = the task-specific section: goal, context-files
(per inline tier policy), output-paths, resources, plus the worker's
`permission_profile` declaration so it knows the scope.

`<reserved_output_budget>` =
`min(worker.max_context * (1 - hard_context_limit/100), 4096)`
typically. Adjust per task expected output size.

**JSON escaping**: file content in `messages` MUST be properly
JSON-escaped (`\n` → `\\n`, `"` → `\\"`). Build the body in a tmp
file (`.dtd/tmp/dispatch-<run>-<task>.json`) using your host's JSON
serializer, never string-concatenated.

### Per-mode dispatch

**`full` mode** — controller makes the HTTP call autonomously:

POSIX (curl):

```bash
mkdir -p .dtd/tmp
# Build the JSON body using your host's JSON tool (jq, python -c, node -e, etc.)
# … assume already at .dtd/tmp/dispatch-001-2.1.json
curl -fsSL --max-time ${TIMEOUT_SEC:-120} \
  -X POST "$ENDPOINT" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  --data-binary @.dtd/tmp/dispatch-001-2.1.json \
  -o .dtd/tmp/response-001-2.1.json
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path .dtd/tmp | Out-Null
$headers = @{
  "Authorization" = "Bearer $env:OLLAMA_API_KEY"
  "Content-Type"  = "application/json"
}
Invoke-RestMethod -Method POST -Uri $endpoint -Headers $headers `
  -InFile ".dtd/tmp/dispatch-001-2.1.json" `
  -TimeoutSec 120 `
  -OutFile ".dtd/tmp/response-001-2.1.json"
```

The API key value comes from the env var (`workers.md`
`api_key_env: OLLAMA_API_KEY` → `$OLLAMA_API_KEY`). **Never inline
the value into the body, log file, or chat output** (per §Security).

**`assisted` mode** — same recipe, but if
`config.host.assisted_confirm_each_call: true`, prompt the user first:

```
About to dispatch task 2.1 to deepseek-local (POST http://localhost:11434/v1/chat/completions, ~1300 tokens). Proceed? (y/n)
```

**`plan-only` mode** — controller does NOT make the HTTP call.
Instead:

1. Write the assembled prompt as plain text to
   `.dtd/tmp/dispatch-<run>-<task>.txt` (NOT as JSON —
   human-paste-friendly).
2. Print to chat:
   ```
   Next task: 2.1 API endpoints
   Worker: deepseek-local
   Prompt at: .dtd/tmp/dispatch-001-2.1.txt
   
   Copy it into a separate session running deepseek-coder:6.7b.
   Save the worker's response to: .dtd/tmp/response-001-2.1.txt
   Then run: /dtd run --paste
   ```
3. Wait for `/dtd run --paste`. Parse
   `.dtd/tmp/response-001-2.1.txt` and continue from step 6.e
   (parse `::done::` + `===FILE:===` blocks).

### Response parsing

Standard OpenAI shape:

```json
{
  "choices": [{
    "message": { "role": "assistant", "content": "<worker output>" },
    "finish_reason": "stop"
  }],
  "usage": { "prompt_tokens": 1234, "completion_tokens": 567 }
}
```

Extract `.choices[0].message.content` → that's the worker's raw
output (will contain `===FILE: ...===` blocks + `::done::` or
`::blocked::` line).

`finish_reason: "length"` → response truncated. Mark attempt as
`failed`, reason `output_truncated`, increase `max_tokens` budget,
retry per ladder.

`usage.prompt_tokens` + `usage.completion_tokens` → log to
`.dtd/log/exec-<run>-task-<id>-ctx.md` for context budget tracking
(compares vs controller's pre-dispatch estimate).

### Error handling

Two-layer model:
1. **Recoverable / quality failures** → mark attempt failed,
   escalate per tier ladder. No user-blocking decision needed (the
   ladder itself is the action).
2. **Blocking failures** (need user input — env var fix, switch
   worker, abandon, etc.) → fill the **decision capsule** (per
   state.md schema) so `/dtd status` shows the actionable blocker,
   and resume is durable across sessions.

#### Per-status table

| HTTP status / condition | Layer | Action |
|---|---|---|
| 200 OK | n/a | Parse response, proceed to validation step (run loop step 6.f) |
| **401 unauthorized** | **Blocking** | Abort dispatch immediately. Fill decision capsule with `awaiting_user_reason: AUTH_FAILED`, options `[fix_env_retry, switch_worker, stop]`, default `fix_env_retry`. **Never log the key value or attempted value.** Mark attempt `blocked`, reason `auth_failed`. |
| 403 forbidden | Blocking | Same as 401 — fill capsule with reason `AUTH_FAILED`, options `[edit_worker, switch_worker, stop]`, default `edit_worker`. (No separate FORBIDDEN reason; both 401 and 403 collapse to `AUTH_FAILED` since both are auth/permission failures resolved by editing worker config.) |
| 404 not found | Blocking | Endpoint or model id wrong. Fill capsule reason `ENDPOINT_NOT_FOUND`, options `[edit_worker, test_worker, switch_worker, stop]`, default `edit_worker`. |
| 429 rate limit | Recoverable on 1st hit, Blocking on 2nd | 1st: wait `Retry-After` header (or 30s default), retry ONCE. 2nd consecutive: fill capsule reason `RATE_LIMIT_BLOCKED`, options `[wait_retry, retry_later, switch_worker, stop]`, default `wait_retry`. |
| 5xx server error | Recoverable on 1st, Blocking on 2nd | 1st: wait 5s, retry ONCE. 2nd: capsule reason `WORKER_5XX_BLOCKED`, options `[retry, switch_worker, stop]`, default `switch_worker`. |
| Timeout (`worker.timeout_sec`) | Recoverable on 1st, Blocking on repeat | 1st: failure_count++ on (worker, task), retry per tier ladder. After threshold OR 2nd timeout in same dispatch: fill capsule reason `TIMEOUT_BLOCKED`, options `[wait_once, retry_same, switch_worker, controller_takeover, stop]`, default `switch_worker`. |
| Network unreachable | Blocking | Fill capsule reason `NETWORK_UNREACHABLE`, options `[retry, test_worker, switch_worker, manual_paste, stop]`, default `test_worker`. Recommend `/dtd doctor` + `/dtd workers test <id>`. |
| JSON parse error | Recoverable on 1st, Blocking on 2nd | 1st: failure_count++, retry. 2nd: capsule reason `MALFORMED_RESPONSE`, options `[retry, switch_worker, stop]`, default `switch_worker`. Save raw to log for inspection. |

Decision capsule shape for blocking errors (template):

```yaml
awaiting_user_decision: true
awaiting_user_reason: <enum from above>
decision_id: dec-NNN
decision_prompt: "<one-line context: which task, which worker, what failed>"
decision_options:
  - {id: <opt-id>, label: <human label>, effect: <what controller does>, risk: <what user should know>}
  - ...
decision_default: <safest option id>
decision_resume_action: "<exact next-step description for user>"
user_decision_options: [<id list>]   # legacy back-compat
```

`/dtd status` displays the prompt, options, default, and current
task/worker context. `/dtd run` is refused while
`awaiting_user_decision: true` until user picks an option.

#### Worker inactive / stuck (heartbeat stale, slow but no timeout)

When `last_heartbeat_at` is older than `stale_threshold_min`
(default 5) AND the attempt is still `running`, OR when
`worker.timeout_sec` is reached but worker is responding
intermittently:

```yaml
awaiting_user_decision: true
awaiting_user_reason: WORKER_INACTIVE
decision_id: dec-NNN
decision_prompt: "Worker <worker_id> on task <task_id> inactive for <elapsed>s (timeout=<sec>s, last heartbeat <X>s ago). How to proceed?"
decision_options:
  - {id: wait_once,           label: "wait <N>s longer",           effect: "extend timeout, keep same worker",                  risk: "may waste more time"}
  - {id: retry_same,          label: "cancel and retry",            effect: "abort current attempt, dispatch same worker fresh", risk: "may fail same way"}
  - {id: switch_worker,       label: "switch to next-tier",         effect: "supersede attempt, dispatch escalate_to worker",     risk: "different cost/quality"}
  - {id: controller_takeover, label: "controller does it",          effect: "controller intervenes (REVIEW_REQUIRED gate)",       risk: "no worker grade"}
  - {id: stop,                label: "stop the run",                effect: "finalize_run(STOPPED)",                              risk: "lose run progress beyond saved files"}
decision_default: switch_worker
decision_resume_action: "controller acts on chosen option's effect; if switch_worker, advances current_fallback_index"
user_decision_options: [wait_once, retry_same, switch_worker, controller_takeover, stop]   # legacy back-compat
```

When `switch_worker` is chosen, the late return from the
now-superseded attempt is marked `superseded` per attempt timeline
rules; output is NOT applied.

All failures (recoverable + blocking) append entry to
`.dtd/attempts/run-NNN.md` per §Attempt Timeline. Blocking failures
additionally update `state.md` decision capsule.

### Fallback chain — explicit per-task computation

Before dispatching a task, controller computes the `fallback_chain`
and stores it in the attempt entry + `state.md`
`current_fallback_chain`. Order:

1. Task's explicit `<worker>X</worker>`
2. Worker `X.escalate_to`
3. Same-capability worker with same or narrower `permission_profile`
4. `config.md` `roles.fallback`
5. Controller takeover (only if `gate: REVIEW_REQUIRED` is acceptable)
6. User (terminal)

**Automatic fallback is allowed only when ALL hold**:
- next worker has same or narrower `permission_profile`
- next worker has same or lower `cost_tier`, OR config has
  `paid_fallback_requires_confirm: false`
- no path-lock conflict (compute lock set at fallback consideration time)
- no pending steering / pending_patch
- retry count below `config.max_auto_worker_switches` (default 1)

If any fail-fast condition fails → fill decision capsule, ask user.

`config.md` knobs added:

```yaml
- auto_fallback: same-profile-only      # never | same-profile-only | ask-before-switch
- max_same_worker_retries: 1
- max_auto_worker_switches: 1
- paid_fallback_requires_confirm: true
- worker_inactive_wait_default_sec: 60   # for WORKER_INACTIVE wait_once option
```

`/dtd status --full` displays the fallback chain for the current
task: `fallback: deepseek-local → qwen-remote → user`.

### Tuning fields — how worker config merges into the request body

Each worker entry in `workers.md` may set tuning fields (see
`workers.example.md` schema). Controller merges them into the
request body per the rules above:

| Field | Default | Notes |
|---|---|---|
| `temperature` | `0.0` | 0.0 deterministic, 0.5 balanced, 1.0+ creative. Use 0.0-0.2 for code. |
| `top_p` | `1.0` | Nucleus sampling; usually leave default. |
| `seed` | (omitted) | Reproducibility, provider-dependent support. |
| `stop` | (omitted) | Comma-list in worker config → JSON array in body. |
| `response_format` | `"text"` | `"json_object"` requires worker support. |
| `frequency_penalty` | `0.0` | Rare; usually leave default. |
| `presence_penalty` | `0.0` | Rare; usually leave default. |
| `reasoning_effort` | (omitted) | OpenAI o1/o3/gpt-5 reasoning only; ignored by others. |
| `stream` | `false` | **v0.1 always false.** Workers with `stream: true` configured: controller forces false anyway, logs WARN. |
| `extra_body` | `{}` | JSON object shallow-merged into request body for provider-specific params (e.g. `top_k`, `min_p`). Use sparingly. |

The controller does NOT pass through unknown worker fields — only
the explicit tuning whitelist above plus `extra_body`. This prevents
accidental leakage of internal DTD config (`tier`, `failure_threshold`,
`aliases`, etc.) into the worker's request.

### Reasoning / "thinking" model response handling

For workers using reasoning models:

- **OpenAI o1 / o3 / gpt-5 (reasoning)**: provider returns standard
  `choices[0].message.content`; chain-of-thought hidden. Set
  `reasoning_effort` per worker.
- **DeepSeek-R1 / V3**: response may include
  `choices[0].message.reasoning_content` AND `content`. Controller
  extracts ONLY `content` for `===FILE:===` parsing. Optionally save
  `reasoning_content` to
  `.dtd/log/exec-<run>-task-<id>-reasoning.md` for debugging
  (gitignored along with `log/`).
- **Anthropic extended thinking via shim**: depends on shim mapping;
  usually maps back to standard `content`.

In all cases the controller's parsing logic is identical — extract
`content`, parse markers. The reasoning content is informational only.

### Streaming (v0.2)

v0.1 enforces `stream: false`. Streaming (`stream: true`, SSE
response) is deferred to v0.2 for partial file application during
long generation. Until then: full response or nothing.

### Provider-specific notes

The above shape works with any **OpenAI-compatible chat completions
endpoint**:

- ✓ Ollama, vLLM, LM Studio, llama.cpp server (local)
- ✓ OpenAI, OpenRouter, DeepSeek API, Hugging Face Inference (remote)

Native APIs that do **not** match this shape need a shim:

- **Anthropic Messages API** — uses `anthropic-version` header,
  system as separate field, different message types. Use `litellm`
  proxy, `openai-anthropic-shim`, or vLLM router. Direct adapter
  planned v0.2.
- **Gemini API** — uses `generationConfig` block, content parts.
  Same: shim. Direct adapter planned v0.2.

`/dtd workers test <id>` performs a probe POST with a minimal
`"hello"` prompt and reports back: 2xx + parseable response = healthy.

### Local request body builder (helper, per host)

The controller can use whatever JSON tool the host has. Examples:

POSIX with `jq`:
```bash
jq -n --arg model "$MODEL" --arg sys "$SYSTEM_PROMPT" --arg usr "$USER_PROMPT" --argjson maxtok "$MAX_TOKENS" \
  '{model:$model, temperature:0.0, max_tokens:$maxtok, stream:false,
    messages:[{role:"system", content:$sys},{role:"user", content:$usr}]}' \
  > .dtd/tmp/dispatch-001-2.1.json
```

PowerShell:
```powershell
@{
  model = $model
  temperature = 0.0
  max_tokens = $maxTokens
  stream = $false
  messages = @(
    @{ role = "system"; content = $systemPrompt }
    @{ role = "user";   content = $userPrompt }
  )
} | ConvertTo-Json -Depth 8 | Set-Content -Path ".dtd/tmp/dispatch-001-2.1.json" -Encoding UTF8
```

Both produce a valid OpenAI-compatible request body.

## Anchor

This file IS the canonical source for worker registry schema, routing
precedence, NL alias resolution, worker output discipline, and full
HTTP dispatch transport (request shape, per-mode dispatch, response
parsing, error handling, fallback chain, tuning fields, reasoning
model handling, provider notes, request body builder helpers).
v0.2.3 R1 extraction completed; `dtd.md` §Worker Registry & Routing,
§Worker Output Discipline, §Worker Dispatch — HTTP Transport now
point here.

## Related topics

- `persona-reasoning-tools.md` — worker tool runtime + persona
  resolution.
- `incidents.md` — dispatch failures become incidents
  (AUTH_FAILED / TIMEOUT_BLOCKED / etc.).
- `autonomy.md` — silent mode dispatch policy.
- `run-loop.md` — dispatch is invoked from run loop step 6.
