# DTD Quickstart — Hello in 30 seconds

The minimal end-to-end walkthrough. One worker, one task, one file written.

Language: [Korean](quickstart.ko.md) · [Japanese](quickstart.ja.md)

---

## Prerequisites

You need:

- An agentic LLM with filesystem read/write **and** shell-exec or web-fetch
  (Claude Code, Codex CLI, Cursor, OpenCode, Aider, etc. all work).
- One worker LLM endpoint. The simplest: a local
  [Ollama](https://ollama.com) running `deepseek-coder:6.7b` or similar.
  Free, no key, no network.

---

## 1. Install (one line)

In your project directory, tell your agent:

```text
fetch prompt.md from github.com/daystar7777/dtd and apply it to this project
```

The agent fetches the bootstrap, detects your host capabilities, creates
`.dtd/`, drops `dtd.md`, and adds one pointer line to your `CLAUDE.md` /
`.cursorrules` / `AGENTS.md`. Takes ~30 seconds.

You'll see:

```
✓ DTD installed.

  host_mode:      full
  DTD mode:       off (toggle on via /dtd mode on)
  Files written:  15 templates + dtd.md
  Host pointer:   appended to CLAUDE.md
  AIMemory:       absent (optional, see recommendation)
```

---

## 2. Register your first worker

```text
/dtd workers add
```

Interactive prompt. For local Ollama:

```text
worker_id (kebab-case):     deepseek-local
endpoint:                    http://localhost:11434/v1/chat/completions
model:                       deepseek-coder:6.7b
api_key_env:                 OLLAMA_API_KEY
max_context (tokens):        32000
capabilities (csv):          code-write, code-refactor
aliases (csv, optional):     deepseek
tier (1-3):                  1
permission_profile:          code-write
escalate_to (worker | user): user

✓ Added worker 'deepseek-local' (aliases: deepseek). Registry now has 1 worker.
```

Or just say it in natural language:

```text
"add deepseek as a worker on localhost:11434 with code-write capability"
```

Set the env var:

```bash
export OLLAMA_API_KEY=ollama   # Ollama doesn't need a real key
```

---

## 3. Check the worker

```text
/dtd workers test deepseek-local
```

Basic connectivity probe — verifies env var, endpoint, auth, and model in one
short call. If this fails, fix env / endpoint / auth before continuing; the
later `/dtd run` will dispatch tasks to this worker, and you'd rather
discover setup issues here than during a run.

```text
✓ deepseek-local      OK     1.2s    parseable response
```

> Detailed stage logs and additional flags (`--all`, `--full`,
> `--connectivity`) ship in v0.2.1 Runtime Resilience. The basic probe
> covers env / endpoint / auth / model today.

---

## 4. Turn on DTD mode

```text
/dtd mode on
```

The host LLM (your "controller") starts loading `.dtd/instructions.md` on
every turn. Natural-language commands are now routed.

---

## 5. Plan → approve → run

```text
/dtd plan "add a hello-world endpoint to src/hello.js"
```

The controller produces a DRAFT plan and shows you the worker assignments:

```
+ plan-001 [DRAFT]
| goal: add a hello-world endpoint to src/hello.js
+ tasks
| Task | Goal                       | Worker     | Work paths | Output paths   | Assigned via
| 1.1  | hello-world endpoint impl  | deepseek   | src/       | src/hello.js   | capability:code-write
+ phases
| phase 1: implement  workers: deepseek  touches: src/

— Approve as-is:  /dtd approve
— Swap worker:    /dtd plan worker <task_id|phase:N|all> <worker>
— Re-plan:        /dtd plan <new goal>
```

Plan looks right?

```text
/dtd approve
/dtd run
```

Watch the dashboard:

```
+ DTD plan-001 [RUNNING] phase 1/1 implement | iter 1/2 | NORMAL < GOOD | ctx 4% | total 5s
| current   1.1 hello-world endpoint impl
| worker    deepseek-local (tier 1) profile=code-write
| work      src/
| writing   src/hello.js (live)
| locks     write files:project:src/hello.js
| elapsed   total 5s | phase 5s | task 5s
+ pause: /dtd pause  or  "pause"
```

A few seconds later:

```
+ DTD plan-001 [COMPLETED] grade=GOOD | total 12s
| 1.1 hello-world endpoint impl  [deepseek]  src/hello.js  GOOD  12s

✓ run-001 done. Summary: .dtd/log/run-001-summary.md
✓ Notepad archived: .dtd/runs/run-001-notepad.md
```

---

## 6. Done

`src/hello.js` now exists. Open it — it's the worker's output.

You can now:

- `/dtd plan "<another goal>"` — start the next thing
- `/dtd workers add` — register more workers (different models / tiers)
- `/dtd status` — see where you are anytime
- `/dtd doctor` — health check
- `/dtd help [topic]` — layered help; try `/dtd help start`, `/dtd help stuck`
- `/dtd update check` — see latest DTD version (v0.2.0d Self-Update)
- `/dtd uninstall --soft` — turn off cleanly (preserves all `.dtd/` content)

---

## What just happened?

1. The **controller** (your host LLM) wrote a phased plan with quality gates and asked for approval.
2. After approve, the controller dispatched task 1.1 to the **worker** (`deepseek-local` via HTTP), waited for the response.
3. The controller validated the worker's output paths against permission/lock policy, then applied the file.
4. On COMPLETED, `finalize_run` archived the notepad, wrote a summary, released leases, updated state.
5. AIMemory (if installed) got two events: `WORK_START` + `WORK_END`. That's it.

No orchestration server. No SDK. No SaaS. Just markdown files in `.dtd/` and one HTTP call per task.

---

## Where to next

- **Add a reviewer worker** for cross-LLM pipelines (writer → reviewer → fixer):
  `/dtd workers add` with `capabilities: review` and a different model.
- **Steer mid-run**: `"prioritize stability this round"` becomes a patch you approve.
- **Multi-phase plans**: see [plan-001.md example](plan-001.md) for a 5-phase plan with parallel groups and cross-vendor pipelines.
- **Full spec**: [dtd.md](../dtd.md) (~22 KB, all canonical actions).
- **Behavior rules for the controller**: [.dtd/instructions.md](../.dtd/instructions.md).

Back to [main README](../README.md).
