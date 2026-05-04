# DTD Worker Registry — Schema, Examples, Endpoint Recipes

> Schema reference + concrete endpoint examples. On install, this file is
> copied to `.dtd/workers.md` if it does not exist. **Edit `workers.md` to
> register your actual workers**; this file (`workers.example.md`) stays in
> the repo as reference.
>
> `workers.md` is **gitignored** by default (`.dtd/.gitignore`) — your endpoints,
> model names, and aliases stay local. The schema and examples here are committed
> (no secrets — only field names and patterns).
>
> Manage via `/dtd workers add|test|rm|alias|role`, or edit `.dtd/workers.md` by hand.
> NEVER inline raw API keys. Use the env var **name** only; keys live in `.env`.

---

## Schema reference

```markdown
## <worker_id>                       # kebab-case, unique, no reserved words
- aliases: <comma-separated>          # nicknames for NL ("worker1", "deepseek")
- display_name: <preferred alias>     # for status output
- endpoint: <OpenAI-compatible URL>   # e.g. http://localhost:1234/v1/chat/completions
- model: <model identifier>           # provider-specific
- api_key_env: <ENV_VAR_NAME>         # NAME only. Value resolved at HTTP header time.
- max_context: <int>                  # token budget (input + reserved output)
- soft_context_limit: 70              # % — phase-split if estimated usage above
- hard_context_limit: 85              # %
- emergency_context_limit: 95         # %
- capabilities: <comma-list>          # code-write, code-refactor, review, planning, debug, ...
- cost_tier: free | paid
- priority: <int>                     # higher first within same capability filter
- tier: 1 | 2 | 3                     # 1 = cheap/fast, 3 = expensive/best
- failure_threshold: <int>            # consecutive failures on same task before escalate
- escalate_to: <worker_id> | user     # next in chain
- timeout_sec: 120                    # per call
- enabled: true                       # set false to skip in routing (kept for inspection)
- permission_profile: <profile>       # explore | review | planning | code-write | controller
- tool_runtime: null                  # null inherits config default; none | controller_relay | worker_native | hybrid
- native_tool_sandbox: false          # must be true before worker_native/hybrid native tools are allowed

# Tuning parameters (optional — all have sensible defaults; override only when needed):
- temperature: 0.0                    # 0.0 = deterministic, 0.5 = balanced, 1.0+ = creative. 0.0-0.2 for code.
- top_p: 1.0                          # nucleus sampling
- seed: <int>                         # reproducibility seed (provider-dependent support)
- stop: <comma-list>                  # stop sequences, e.g. "###,END_OF_FILE"
- response_format: text               # text | json_object  (json requires worker support)
- stream: false                       # v0.1 always false. v0.2 will support SSE streaming.
- reasoning_effort: low|medium|high   # OpenAI o1/o3/gpt-5 reasoning models only. Ignored by others.
                                      # See "Reasoning / Thinking models" section below.
- frequency_penalty: 0.0              # rare; usually leave default
- presence_penalty: 0.0               # rare; usually leave default
- extra_body: <inline JSON>           # any provider-specific param controller passes through verbatim
```

The controller merges your tuning fields into the request body. Required fields go
directly; tuning fields override defaults. Anything in `extra_body` is shallow-merged
at top level for provider-specific options (e.g., `{"top_k": 40}` for some servers).

---

## "OpenAI-compatible" — what does that actually mean?

Many providers expose the same HTTP API as OpenAI's `/v1/chat/completions`:

- POST endpoint
- `Authorization: Bearer <key>` header
- Body with `model` + `messages` + standard fields

If a provider says **"OpenAI API compatible"** or **"drop-in OpenAI replacement"**,
it works directly with DTD. Examples below.

If they have their own native API (Anthropic Messages, Gemini, etc.), use a shim
like [`litellm`](https://github.com/BerriAI/litellm) or vLLM's OpenAI router.
Direct adapters are planned for v0.2.

---

## Common endpoint examples — copy + paste + edit

The block below is a reference. **Active registry below is empty on fresh install** —
copy a section from here into your `workers.md` Active registry and adjust.

### Ollama (local, no real key)

```markdown
## ollama-local
- aliases: ollama, deepseek
- endpoint: http://localhost:11434/v1/chat/completions
- model: deepseek-coder:6.7b
- api_key_env: OLLAMA_API_KEY
- max_context: 32000
- capabilities: code-write, code-refactor
- cost_tier: free
- priority: 10
- tier: 1
- failure_threshold: 3
- escalate_to: user
- enabled: true
- permission_profile: code-write
- temperature: 0.2
```

`.env`: `OLLAMA_API_KEY=ollama` (any non-empty value works).

### LMStudio (local server with UI)

LMStudio default: `http://localhost:1234/v1`. Append `/chat/completions`.

```markdown
## lmstudio-local
- endpoint: http://localhost:1234/v1/chat/completions
- model: <whichever model is loaded in LMStudio>
- api_key_env: LMSTUDIO_API_KEY
- max_context: 32768
- capabilities: code-write
- temperature: 0.2
- enabled: true
```

> ⚠️ **`localhost` / `127.0.0.1` only works from the same machine that runs LMStudio.**
> Other machines on your LAN **cannot** reach `127.0.0.1` on your machine — that's
> always loopback to the requesting machine itself. If you want to use LMStudio (or
> any local server) from another machine, use the **LAN IP**:
>
> ```markdown
> - endpoint: http://192.168.1.50:1234/v1/chat/completions
> ```
>
> Find the LAN IP of the host machine:
> - macOS / Linux: `ifconfig` (look for `inet 192.168.x.x` under `en0` / `eth0`)
> - Windows: `ipconfig` (look for "IPv4 Address")
>
> Also: in LMStudio's server settings, enable **"Serve on local network"** /
> 0.0.0.0 binding so it listens on all interfaces, not just loopback.

### Tailscale — your local LLM from anywhere

If you run a local LLM at home and want to use it from your laptop on a coffee-shop
WiFi or another network, [Tailscale](https://tailscale.com) creates a private mesh
network with stable `100.x.x.x` IPs that work over the internet **without exposing
the endpoint publicly**.

```markdown
## home-lmstudio-via-tailnet
- aliases: home-llm
- endpoint: http://100.64.0.10:1234/v1/chat/completions   # tailnet IP of home machine
- model: qwen2.5-coder:32b
- api_key_env: HOME_LLM_KEY
- max_context: 128000
- capabilities: code-write, code-refactor, planning
- tier: 2
- temperature: 0.2
```

Setup:
1. Install Tailscale on both machines, log in to the same account.
2. Find the tailnet IP of the host machine: `tailscale ip -4`.
3. Use that IP in the `endpoint` field above.
4. Make sure LMStudio (or your server) is bound to `0.0.0.0` (all interfaces).

Now your laptop can reach your home LLM from any network. Encrypted, no port
forwarding, no public exposure. Tailscale free tier is enough for personal use.

### llama.cpp server

```markdown
## llama-cpp
- endpoint: http://localhost:8080/v1/chat/completions
- model: <path or identifier>
- api_key_env: LLAMACPP_API_KEY
- max_context: 8192
- temperature: 0.0
```

### vLLM (local high-throughput)

```markdown
## vllm-local
- endpoint: http://localhost:8000/v1/chat/completions
- model: meta-llama/Meta-Llama-3.1-8B-Instruct
- api_key_env: VLLM_API_KEY
- max_context: 128000
- temperature: 0.0
```

### DeepSeek API (commercial, OpenAI-compatible)

Per current DeepSeek docs (api-docs.deepseek.com): the canonical model ids are
`deepseek-v4-pro` (high-quality) and `deepseek-v4-flash` (cheaper/faster). The
older compatibility names `deepseek-chat` / `deepseek-reasoner` /
`deepseek-coder` are scheduled for deprecation 2026-07-24 — use them only if
you need transitional support.

```markdown
## deepseek-cloud
- endpoint: https://api.deepseek.com/v1/chat/completions
- model: deepseek-v4-pro             # or deepseek-v4-flash for cheaper
- api_key_env: DEEPSEEK_API_KEY      # get from platform.deepseek.com
- max_context: 64000
- capabilities: code-write, code-refactor, review
- cost_tier: paid
- tier: 2
- temperature: 0.0
- enabled: true
- permission_profile: code-write
```

### OpenRouter (multi-provider gateway, OpenAI-compat)

One key, many models from many vendors:

```markdown
## openrouter
- endpoint: https://openrouter.ai/api/v1/chat/completions
- model: anthropic/claude-3.5-sonnet    # or any of openrouter's catalog
- api_key_env: OPENROUTER_API_KEY
- max_context: 200000
- cost_tier: paid
- tier: 3
```

### OpenAI / GPT-5 / o-series

```markdown
## openai-codex
- endpoint: https://api.openai.com/v1/chat/completions
- model: gpt-5-codex
- api_key_env: OPENAI_API_KEY
- max_context: 200000
- capabilities: review, planning, debug
- cost_tier: paid
- tier: 3
- reasoning_effort: medium    # gpt-5 / o1 / o3 reasoning models only
- temperature: 0.0
```

### Together AI / Groq / Fireworks / Anyscale (all OpenAI-compat)

All expose `/v1/chat/completions`. Same pattern; check the provider's docs for
the exact endpoint hostname. Set `model` to whatever the provider lists.

---

## Reasoning / "Thinking" models

Some workers emit internal reasoning distinct from the final answer:

- **OpenAI o1 / o3 / gpt-5 (reasoning)**: pass `reasoning_effort: low|medium|high` per worker. Provider returns standard `content`; you don't see the chain of thought.
- **DeepSeek-R1 / V3**: response may include both `reasoning_content` and `content` fields. Controller extracts ONLY `content` for `===FILE:===` parsing; `reasoning_content` may be saved to `.dtd/log/exec-*-task-*-reasoning.md` for debugging.
- **Anthropic extended thinking** (via shim): depends on the shim's response shape; most map back to `content` only.

For DTD purposes all are treated as standard chat completions — extract
`choices[0].message.content`, ignore extra reasoning fields, parse `===FILE:===`
blocks + `::done::` line.

Recommended `temperature: 0.0` for code-write workers (reasoning or not).

---

## Active registry (this section is what `workers.md` will hold)

# Empty on fresh install. Add workers via `/dtd workers add` or paste from above.
# Doctor flags empty registry as setup gap; recommends `/dtd workers add`.
# Your actual registry lives in `.dtd/workers.md` (gitignored). This file
# (workers.example.md) stays in repo for reference.

(none)

---

# End of workers.example.md
