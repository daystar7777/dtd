# DTD Worker Registry

> One worker per H2 (`## <worker_id>`) section. Required fields: `endpoint`, `model`,
> `api_key_env`, `max_context`, `capabilities`. Others have sensible defaults.
>
> Manage via `/dtd workers add|test|rm|alias|role` or edit by hand.
> NEVER inline raw API keys. Use env var name only.
>
> **Active registry below is empty on fresh install.** Examples are in the comment
> block at the bottom — copy and uncomment to use.

## Schema reference

```markdown
## <worker_id>                       # kebab-case, unique, no reserved words
- aliases: <comma-separated>          # nicknames for NL ("워커1", "딥시크"). Optional.
- display_name: <preferred alias>     # for status output. Default = first alias or worker_id.
- endpoint: <OpenAI-compatible URL>   # POST chat/completions
- model: <model identifier>           # provider-specific
- api_key_env: <ENV_VAR_NAME>         # name only. Resolved at HTTP header time.
- max_context: <int>                  # token budget (input + reserved output)
- soft_context_limit: 70              # % — phase-split if estimated usage above
- hard_context_limit: 85              # % — refuse to send more, split immediately
- emergency_context_limit: 95         # % — emergency checkpoint
- capabilities: <comma-list>          # code-write, code-refactor, review, planning, debug, ...
- cost_tier: free | paid
- priority: <int>                     # higher first within same capability filter
- tier: 1 | 2 | 3                     # 1 = cheap/fast, 3 = expensive/best
- failure_threshold: <int>            # consecutive failures on same task before escalate
- escalate_to: <worker_id> | user     # next in chain; "user" = terminal
- timeout_sec: 120                    # per call (optional, default from config)
- enabled: true                       # set false to keep entry but skip in routing
- permission_profile: <profile>       # explore | review | planning | code-write | controller
                                      # see worker-system.md §Permission Profiles
```

## Active registry

# Empty on fresh install. Add workers via `/dtd workers add` or paste H2 sections below.
# Doctor will flag empty registry as setup gap and recommend `/dtd workers add`.

(none)

---

## Examples — reference only (NOT loaded into routing)

The block below is for copy-paste reference. To activate, copy a section out of
the example block and paste above the `(none)` line in **Active registry**, then
adjust endpoint / api_key_env / capabilities for your setup.

<!-- BEGIN EXAMPLES (not parsed as registry — copy out and uncomment to use) -->

```markdown
## deepseek-local
- aliases: worker1, deepseek, coder
- display_name: deepseek
- endpoint: http://localhost:11434/v1/chat/completions
- model: deepseek-coder:6.7b
- api_key_env: OLLAMA_API_KEY
- max_context: 32000
- capabilities: code-write, code-refactor
- cost_tier: free
- priority: 10
- tier: 1
- failure_threshold: 3
- escalate_to: qwen-remote
- timeout_sec: 180
- enabled: false
- permission_profile: code-write

## qwen-remote
- aliases: worker2, qwen
- display_name: qwen
- endpoint: http://192.168.1.100:8000/v1/chat/completions
- model: qwen2.5-coder:32b
- api_key_env: QWEN_API_KEY
- max_context: 128000
- capabilities: code-write, code-explain, code-refactor, planning
- cost_tier: free
- priority: 20
- tier: 2
- failure_threshold: 10
- escalate_to: gpt-codex
- enabled: false
- permission_profile: code-write

## gpt-codex
- aliases: codex
- display_name: codex
- endpoint: https://api.openai.com/v1/chat/completions
- model: gpt-5-codex
- api_key_env: OPENAI_API_KEY
- max_context: 200000
- capabilities: review, planning, debug, hard-debug
- cost_tier: paid
- priority: 5
- tier: 3
- failure_threshold: 30
- escalate_to: user
- enabled: false
- permission_profile: review
```

<!-- END EXAMPLES -->

Note: examples use ASCII aliases for portability. Add Korean (or any language) aliases freely in your own active registry — `aliases: worker1, 딥시크, coder` is valid for end-users.

# Routing rule: only H2 sections OUTSIDE the `<!-- ... -->` block above are loaded.
# `enabled: false` entries are also skipped (kept for inspection; doctor reports them).
