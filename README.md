# DTD (Do Till Done)

> Cheap LLMs do the work. Expensive ones just steer.
> Multi-LLM execution mode in markdown — works in any agent.

[한국어 README](README.ko.md) · [日本語 README](README.ja.md)

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
```

> Detailed worker health diagnostics (`--all`, `--full`, `--connectivity`,
> stage logs, failure taxonomy) ship in v0.2.1 Runtime Resilience.

Observe:

```text
/dtd status                      polished dashboard
/dtd plan show                   inspect the active plan
/dtd doctor                      health check
/dtd workers list                show registered workers
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
any worker before approving (`/dtd plan worker 3.1 deepseek` or NL: "리뷰는 큐엔으로").

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
+ pause: /dtd pause  or  "잠깐 멈춰"
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
- **Adopting DTD mid-project** — install on an in-progress phased project, mark already-done tasks in the plan, and let DTD pick up the remaining work. Three patterns documented in [dtd.md §Adopting DTD on existing in-progress work](dtd.md#adopting-dtd-on-existing-in-progress-work).

---

## Not in v0.1

- Distributed lock guarantees across DTD instances (best-effort for global paths)
- Streaming worker responses
- Direct adapters for Anthropic Messages / Gemini API (use OpenAI-compatible shims)
- Voting / consensus dispatch (one worker per task)
- Per-run notepad search across `.dtd/runs/` archive
- `/dtd runs prune` cleanup command

These are on the v0.2 / v0.1.1 roadmap.

---

## In one line

> The controller plans. The workers do. You steer.
> **Do till done.**
