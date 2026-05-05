# DTD (Do Till Done)

> Cheap LLMs do the work. Expensive ones just steer.
> Multi-LLM execution mode in markdown — works in any agent.

[Korean README](README.ko.md) · [Japanese README](README.ja.md)

---

## Why?

You have great agents — Claude Code, Codex, Cursor, Antigravity, Aider.
But you can only use one at a time. Tokens run out fast. Different models are
good at different things.

DTD turns your host LLM into a **controller**.
It plans, asks for your approval, then dispatches each task to a **worker LLM**.

Codex plans, DeepSeek builds, GPT-Codex reviews, DeepSeek fixes —
one plan, one command.

No server. No SDK. No cloud. Just a `.dtd/` folder.

---

## Install

Tell the agent in your project — any agent — one line:

```text
fetch prompt.md from github.com/daystar7777/dtd and apply it to this project
```

The agent detects your host capabilities, builds the `.dtd/` tree, drops the
slash command at the right host-specific path, and adds one pointer line to
your `CLAUDE.md` / `.cursorrules` / `AGENTS.md`.

→ **Just want to try it?** [30-second Quickstart](examples/quickstart.md) walks you through install → first plan → first run with one local worker.

---

**Want evidence?** [Real-use Benchmark](BENCHMARK.md) explains the
plain-vs-DTD comparison plan, token accounting, score rubric, model-role split,
and current execution boundary.

---

## How do I use it?

Slash — three small command groups: **Start**, **Observe**, **Recover**.

Start:

```text
/dtd workers add                 register your first worker LLM
/dtd workers test <id>           basic connectivity probe (env / endpoint / auth)
/dtd mode on                     enable DTD mode
/dtd plan "add user CRUD"        generate a phased plan (DRAFT)
/dtd approve                     lock the plan
/dtd run                         execute
/dtd run --silent=4h             work quietly; defer blockers and continue safe tasks (v0.2.0f)
```

> Detailed worker health diagnostics (`--all`, `--full`, `--connectivity`,
> stage logs, failure taxonomy) are available in v0.2.1+ Runtime Resilience.

Run styles (v0.2.0f Autonomy & Attention):

```text
/dtd run --decision permission   default: ask on permissions/major choices
/dtd run --decision auto         maximize safe forward progress
/dtd interactive                 ask immediately when a decision is needed
/dtd silent on --for 4h          do not interrupt; show deferred blockers later
/dtd mode decision <plan|permission|auto>   set decision-frequency persistent default
/dtd perf [--phase|--worker|--tokens|--cost]  observational token report (controller vs worker separated)
```

> v0.2.0f decision/attention/context-pattern features land after v0.2.0d
> Self-Update so existing installs can update into the new state schema
> cleanly. Pre-v0.2.0f installs see only the always-supported `/dtd run`
> + `/dtd pause` + `/dtd stop` controls.

Observe:

```text
/dtd status                      polished dashboard
/dtd plan show                   inspect the active plan
/dtd doctor                      health check
/dtd workers list                show registered workers
/dtd help [topic]                layered help (≤25-line overview, ≤50-line topic)
/dtd update check                see latest available DTD version (v0.2.0d)
/dtd r2 readiness                v0.3 live-test entry gate; no worker calls
```

Recover (v0.2.0a Incident Tracking):

```text
/dtd pause                       halt at next task boundary
/dtd incident list               see what is blocking
/dtd incident show <id>          detailed failure + recovery options
/dtd incident resolve <id> retry choose a recovery option
/dtd stop                        force-end the active plan (destructive)
```

Or just talk:

```text
"register deepseek as a worker"
"plan this for me"
"go ahead"
"hold on, pause"
"swap task 3 to qwen"
"where are we?"
```

Same canonical actions. Two interfaces.

---

## What it looks like

### Install confirm

```
DTD install plan:
  host_mode:   full     (detected: shell-exec + filesystem rw)
  DTD mode:    off      (toggle later via /dtd mode on)
  AIMemory:    not detected — recommended
  Files to fetch:
    - dtd.md (slash command)
    - .dtd/ × 15 templates
    - host pointer block → CLAUDE.md
Proceed? (y/n)
```

The bootstrap probes your host's capabilities first, then asks for confirmation.
`host_mode` is fixed by host capability (plan-only / assisted / full); `DTD mode`
is the on/off toggle you control afterwards. AIMemory is optional — DTD works
without it.

### Plan with worker assignment

After `/dtd plan "add user CRUD endpoints"`:

```
+ plan-001 [DRAFT]
| goal: add user CRUD endpoints (POST/GET/PATCH/DELETE /users)
+ tasks
| Task | Goal                          | Worker     | Work paths       | Output paths           | Assigned via
| 1.1  | schema + validation           | qwen       | docs/, src/types | docs/users-schema.md   | role:planner
| 2.1  | POST /users + GET /users/:id  | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
| 2.2  | PATCH /users/:id + DELETE     | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
| 3.1  | code review                   | codex      | src/api/users    | docs/review-001.md     | role:reviewer
| 3.2  | apply review fixes            | deepseek   | src/api/users    | src/api/users.ts       | capability:code-write
+ phases
| phase 1: planning  workers: qwen      touches: docs/, src/types/
| phase 2: backend   workers: deepseek  touches: src/api/users/
| phase 3: review    workers: codex+deepseek

— Approve as-is:  /dtd approve
— Swap worker:    /dtd plan worker <task_id|phase:N|all> <worker>
```

You see exactly which worker handles each task and **why** (`Assigned via` column).
The plan is DRAFT — nothing runs until `/dtd approve`. You can swap any task to
any worker before approving (`/dtd plan worker 3.1 deepseek` or NL: "use qwen for review").

### Run dashboard (live)

After `/dtd run`:

```
+ DTD plan-001 [RUNNING] phase 2/3 backend | iter 1/3 | NORMAL < GOOD | gate pending | ctx 42% | total 8m
| goal      add user CRUD endpoints
| current   2.2 PATCH + DELETE
| worker    deepseek-local (tier 1) profile=code-write
| work      src/api/users
| writing   src/api/users.ts (live)
| locks     write files:project:src/api/users.ts
| elapsed   total 8m | phase 4m | task 3m12s
+ recent
| * 1.1 schema + validation        [qwen]      docs/users-schema.md  GREAT  30s
| * 2.1 POST + GET endpoints       [deepseek]  src/api/users.ts      GOOD   4m
+ queue
| -> 3.1 code review               [codex]
| -> 3.2 apply review fixes        [deepseek]
+ pause: /dtd pause  or  "pause"
```

The dashboard updates as the run progresses. You see grade, gate, context usage,
held locks, elapsed time, what's done, what's coming. Pause anytime — the
in-flight task finishes cleanly, then it stops.

### Doctor (health check)

```
$ /dtd doctor

[Install integrity]            ✓ 15/15 templates + dtd.md
[Mode consistency]             ✓ state.md mode=dtd host_mode=full | config.md aligned
[Worker registry]              ✓ 3 active workers (deepseek-local, qwen-remote, gpt-codex)
[agent-work-mem]               ℹ integrated
[Project context]              ✓ PROJECT.md filled
[Resource state]               ✓ 0 active leases
[Plan state]                   ✓ plan-001 RUNNING, size 7.8 KB (≤ 12 preferred)
[Path policy]                  ✓ no violations
[.gitignore]                   ✓ all required entries

verdict: 0 ERROR / 0 WARN / 1 INFO
```

`/dtd doctor` is your "is everything OK?" command. Detects worker registry
issues, stale leases, secret leaks, missing templates, mode mismatches. Doesn't
auto-fix — tells you what's wrong and how to handle it.

---

## What makes it different?

**Multi-LLM, multi-server**. Each worker has capability, cost tier, priority.
Tasks route automatically. Cross-vendor pipelines fit in one plan.

**Tier escalation ladder**. Worker A fails 3× → auto-promote to B → add a
reviewer → controller intervenes → ask user. Per-worker thresholds. Same
blocker twice (hash) accelerates the next step.

**State machine + approval gate**. Plans always start as DRAFT. You approve
before anything runs. Mid-run direction changes (steering) become patches
that need explicit approval if medium/high impact.

**Pause / Resume / Stop**. Halt anytime; the in-flight task finishes cleanly.
Resume across sessions. Work paths and output paths show up in the plan,
status, and history — consistently.

**Token-conservative**. Worker output → log file, not chat. Done tasks compact
to one line. Prompt cache friendly assembly. Status output diet.

**Security first-class**. API keys live only in `.env`. Never echoed, logged,
or displayed. `doctor` regex-scans for leaked patterns.

**Honest about modes**. Three:

- `plan-only` — manages plans/state; you copy worker prompts manually
- `assisted` — auto-dispatch with optional confirms
- `full` — autonomous (destructive ops still confirm)

`/dtd doctor` reports which mode your host supports.

---

## Where can I run it?

Zero host coupling. If your agent has filesystem read/write, DTD installs.
With shell or web-fetch, workers auto-dispatch.

Tested patterns: Claude Code, ChatGPT Codex CLI, OpenCode, Cursor, Antigravity,
Aider, Cline, Continue, Windsurf, gemini-cli, and any agentic harness.

Worker endpoints: any OpenAI-compatible chat completions API. Local (Ollama,
vLLM, LM Studio, llama.cpp) and remote (OpenAI, OpenRouter, DeepSeek API,
Hugging Face Inference, Anthropic-compat shims).

Optional: [agent-work-mem](https://github.com/daystar7777/agent-work-mem) for
multi-session history. DTD detects it and uses it minimally (one event per run
plus 5 exception cases).

---

## Adopting on existing in-progress work

DTD works on projects that are already underway. Install is additive: it creates
`.dtd/`, `dtd.md`, and a host pointer, but it does not rewrite your source files.

After install:

1. Fill `.dtd/PROJECT.md` with the current project shape, conventions, and
   anything a worker should know before touching code.
2. Run `/dtd doctor` and fix any missing-context warnings.
3. Pick an adoption pattern:
   - Continue from now: plan only the remaining work.
   - Audit the full project: mark already-done tasks as `worker="manual"` or
     `worker="controller"` so DTD skips them.
   - Translate an existing roadmap into DTD's plan format.

Details and XML examples live in [dtd.md §Adopting DTD on existing in-progress work](dtd.md#adopting-dtd-on-existing-in-progress-work).

---

## What gets created

```
your-project/
├── your-code/
├── CLAUDE.md (or equivalent)         ← one-line DTD pointer added
├── dtd.md                             ← slash command source
└── .dtd/
    ├── instructions.md                ← controller's behavior spec
    ├── config.md                      ← global settings
    ├── workers.example.md             ← schema + endpoint examples (committed)
    ├── workers.md                     ← your actual registry (gitignored, local-only)
                                          installs as a copy of workers.example.md
    ├── worker-system.md               ← worker output discipline
    ├── resources.md                   ← active locks/leases
    ├── state.md                       ← runtime state
    ├── steering.md                    ← your direction history
    ├── phase-history.md               ← compact phase log
    ├── PROJECT.md                     ← project context capsule
    ├── notepad.md                     ← per-run wisdom (handoff to workers)
    ├── plan-NNN.md                    ← created by /dtd plan
    ├── log/                           ← raw worker logs
    ├── attempts/                      ← immutable attempt timeline
    ├── runs/                          ← archived run notepads
    ├── eval/                          ← phase eval (on retry)
    └── skills/{code-write,review,planning}.md
```

---

## Good for

- Big-controller (Claude/Codex) plans + cheap-local workers (DeepSeek/Qwen) implements
- Cross-LLM pipelines: writer ≠ reviewer ≠ fixer
- Long multi-phase work that spans sessions (pause/resume)
- Teams who want auditable AI changes (every dispatch logged, every grade tracked)
- Anyone tired of pasting context between agents
- **Adopting DTD mid-project** — install on an in-progress phased project, mark already-done tasks in the plan, and let DTD pick up the remaining work.

---

## Not in v0.1

- Distributed lock guarantees across DTD instances (best-effort for global paths)
- Streaming worker responses
- Direct adapters for Anthropic Messages / Gemini API (use OpenAI-compatible shims)
- Per-run notepad search across `.dtd/runs/` archive
- `/dtd runs prune` cleanup command

These are on the v0.2 / v0.1.1 roadmap.

## v0.2 line — Operations hardening + lifecycle

**All 9 sub-releases tagged 2026-05-06** (v0.2.0a / v0.2.0d /
v0.2.0f / v0.2.3 / v0.2.0e / v0.2.0b / v0.2.0c / v0.2.1 /
v0.2.2). Adds incident
tracking, permission ledger, snapshot/revert, runtime resilience
(worker health-check + session resume + loop guard), notepad v2
+ reasoning-utility post-processing, autonomy & attention modes,
locale packs, self-update with migration, and modular spec
extraction.

## v0.3 line — Multi-LLM advanced execution

**All 5 sub-releases tagged 2026-05-06** (v0.3.0e / v0.3.0b /
v0.3.0a / v0.3.0c / v0.3.0d). R0 (design) + R1 (runtime) GO
(Codex final review pass 2026-05-06); R2 plan + R2-0 entry
gate + realuse-benchmark dev phase also defined. R2 live
execution starts with `/dtd r2 readiness`. 5 sub-releases:

- **v0.3.0a Cross-run loop guard** — stable signature ledger
  catches long-term failure patterns the within-run guard misses.
- **v0.3.0b Token-rate-aware scheduling** — predictive routing
  with TZ-aware quota windows; provider-header parsing for 4
  vendors; permission-gated paid fallback.
- **v0.3.0c Multi-worker consensus dispatch** — `consensus="N"`
  plan attribute; 4 selection strategies (`first_passing`,
  `quality_rubric`, `reviewer_consensus`, `vote_unanimous`);
  parallel staged outputs; group lock; late-result-never-apply
  invariant.
- **v0.3.0d Cross-machine session sync** — opt-in worker
  session affinity across laptop/desktop with mandatorily
  encrypted payloads (AES-256-GCM + HKDF-SHA256); 3 backends
  (filesystem / git_branch / none); SESSION_CONFLICT capsule.
- **v0.3.0e Time-limited permissions** — `for 1h` /
  `until eod` / `for run` natural duration syntax;
  TZ-aware named-local scopes; finalize_run auto-prune.

---

## In one line

> The controller plans. The workers do. You steer.
> **Do till done.**
