# DTD (Do Till Done) — Install Bootstrap

You are about to install **DTD**, a markdown-first multi-LLM execution mode that
turns the host LLM into a **controller** orchestrating **worker LLM** API calls.

- **Public name**: DTD / Do Till Done
- **Repo**: <https://github.com/daystar7777/dtd>
- **Primary command**: `/dtd`
- **State directory**: `.dtd/`
- **Distribution**: markdown-only, host-neutral. No binaries. No SDK.

DTD has two operating modes:

- **normal mode** — host LLM operates as usual
- **DTD mode** — host LLM becomes the controller, dispatching specific tasks to
  worker LLMs via API. Cross-LLM pipelines (e.g. DeepSeek writes → GPT-Codex
  reviews → Qwen normalizes) are first-class.

Features (v0.1): GSD-style phases, quality grades (NORMAL/GOOD/GREAT/BEST),
steering, stuck-detection escalation, status dashboard, context budgets,
resource locks, natural-language UI, multi-worker registry, optional
`agent-work-mem` integration.

---

## Prerequisite — agentic LLM

You need at minimum `filesystem-read` and `filesystem-write`.
Worker dispatch additionally needs `shell-exec` OR `web-fetch`.

DTD picks one of three host capability modes (Task 3):

| mode | requires | DTD behavior |
|---|---|---|
| `plan-only` | filesystem only | manages plan/state; worker calls = manual paste between sessions |
| `assisted` | + shell-exec or web-fetch | dispatches workers; per-call confirm optional |
| `full` | + shell-exec/web-fetch + autonomy | autonomous dispatch; destructive ops still confirm |

If you have only chat (no filesystem), DTD cannot install. Stop here.

Compatible host platforms: Claude Code, ChatGPT Codex CLI, OpenCode, Cursor,
Antigravity, Aider, Cline, Continue, Windsurf, gemini-cli, plus any agentic
harness with file + shell access.

---

## Tasks (execute in order)

### Task 1 — Self-identify

State at the top of your reply:

- **model-id** (lowercase kebab-case): `claude-opus-4-7`, `gpt-5-codex`,
  `gemini-2-5-pro`, `qwen-2-5-coder`, `deepseek-coder-v3`, etc.
- **vendor**: Anthropic / OpenAI / Google / xAI / DeepSeek / Meta / Alibaba / other
- **harness**: Claude Code / ChatGPT Codex CLI / Cursor / OpenCode / Aider /
  Cline / Continue / Windsurf / gemini-cli / other
- **capabilities** (from this vendor-neutral set):
  `filesystem-read`, `filesystem-write`, `shell-exec`, `web-fetch`,
  `web-search`, `subagent-spawn`

### Task 2 — Probe OS

Use whichever your shell supports:

```bash
# POSIX (macOS / Linux / git-bash on Windows)
uname -a
```

```powershell
# Windows PowerShell
(Get-CimInstance Win32_OperatingSystem).Caption
```

```cmd
:: Windows cmd.exe
ver
```

Record the result. Task 8 (host pointer file) and Task 6/7 (filesystem ops) depend on it.

### Task 3 — Probe capabilities → choose mode

Probe each of:

- `shell-exec`: try `echo ok`
- `web-fetch`: try fetching a known small URL (any one):
  - `https://raw.githubusercontent.com/daystar7777/dtd/main/dtd.md`
  - or whatever your fetch tool can reach

Based on what works, propose a **host_mode** (the host's capability tier — distinct from
`/dtd mode on|off` which toggles DTD activation) and **ask user to confirm**:

> "Detected host_mode: `<plan-only|assisted|full>`. OK or change?"

Note: `host_mode` is fixed per host install (until you run `/dtd doctor` to redetect).
DTD activation (`mode: off|dtd`) is toggled separately via `/dtd mode on|off`.

### Task 4 — Detect agent-work-mem (optional)

Check for these files:

- `AIMemory/PROTOCOL.md`
- `AIMemory/INDEX.md`
- `AIMemory/work.log`

**If present**: note "AIMemory detected — DTD will emit minimal events
(WORK_START + WORK_END per DTD run + 5 exception cases per spec §8)".

**If absent**: print a one-line *recommendation* (do NOT block install):

> Recommended (optional): install `agent-work-mem` from
> <https://raw.githubusercontent.com/daystar7777/agent-work-mem/main/prompt.md>
> for multi-session/multi-agent work history.

DTD is fully self-contained via `.dtd/` whether or not AIMemory exists.

### Task 5 — Confirm install with user

Show the user a summary:

```
DTD install plan:
  host_mode:   <chosen host_mode>     (fixed by host capability)
  DTD mode:    off                     (toggle later via /dtd mode on)
  AIMemory:    <detected | not detected — recommended>
  Files to fetch:
    - <project root>/dtd.md            (slash command source)
    - <slash command host dir>/dtd.md  (host-specific, see Task 8)
    - .dtd/instructions.md
    - .dtd/config.md
    - .dtd/workers.example.md (committed reference)
       → also copies to .dtd/workers.md (your local-only registry) if not exists
    - .dtd/worker-system.md
    - .dtd/resources.md
    - .dtd/state.md
    - .dtd/steering.md
    - .dtd/phase-history.md
    - .dtd/PROJECT.md
    - .dtd/notepad.md
    - .dtd/.gitignore
    - .dtd/.env.example
    - .dtd/skills/code-write.md
    - .dtd/skills/review.md
    - .dtd/skills/planning.md
  Host pointer: append DTD block to <CLAUDE.md|.cursorrules|AGENTS.md|host-specific>

Total: 15 .dtd/ files + dtd.md (slash) + 1 host pointer block.
Proceed? (y/n)
```

Wait for user `y` or equivalent. Do not proceed without confirmation.

### Task 6 — Create directory tree

POSIX (macOS / Linux / git-bash):

```bash
mkdir -p .dtd/skills .dtd/log .dtd/eval .dtd/tmp .dtd/attempts .dtd/runs
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path ".dtd/skills",".dtd/log",".dtd/eval",".dtd/tmp",".dtd/attempts",".dtd/runs" | Out-Null
```

Windows cmd.exe:

```cmd
mkdir .dtd\skills .dtd\log .dtd\eval .dtd\tmp .dtd\attempts .dtd\runs
```

These are *runtime* directories (separate from the 15 template files in Task 7). They start empty. The 15 templates are fetched in Task 7. `.dtd/attempts/run-NNN.md` files are created by `/dtd run` at first dispatch. `.dtd/runs/run-NNN-notepad.md` files are written by `/dtd run` at COMPLETED/STOPPED/FAILED. To preserve these directories under git, the `.dtd/.gitignore` (Task 7) covers their internals; if you want git to track the empty directories, add a `.gitkeep` per dir.

### Task 7 — Fetch and write template + spec files

Fetch each of the following from the repo. Method depends on capability:

- **shell-exec, POSIX**: `curl -fsSL <URL> -o <local-path>`
- **shell-exec, Windows PowerShell**: `Invoke-WebRequest -Uri <URL> -OutFile <local-path>`
- **shell-exec, Windows cmd.exe**: `curl -fsSL <URL> -o <local-path>` (curl ships with Windows 10+)
- **web-fetch**: use your fetch tool; save the result to local path
- **neither (plan-only)**: ask user to clone the repo manually
  (`git clone https://github.com/daystar7777/dtd`) and then copy
  the files into the project. Or paste contents from a separate channel.

GitHub raw URL prefix:
`https://raw.githubusercontent.com/daystar7777/dtd/main`

| Source | Local destination |
|---|---|
| `dtd.md` | `<project root>/dtd.md` (canonical) AND `<host slash dir>/dtd.md` |
| `.dtd/instructions.md` | `.dtd/instructions.md` |
| `.dtd/config.md` | `.dtd/config.md` |
| `.dtd/workers.example.md` | `.dtd/workers.example.md` (committed reference) AND `.dtd/workers.md` (gitignored local registry — only created if not exists) |
| `.dtd/worker-system.md` | `.dtd/worker-system.md` |
| `.dtd/resources.md` | `.dtd/resources.md` |
| `.dtd/state.md` | `.dtd/state.md` |
| `.dtd/steering.md` | `.dtd/steering.md` |
| `.dtd/phase-history.md` | `.dtd/phase-history.md` |
| `.dtd/PROJECT.md` | `.dtd/PROJECT.md` |
| `.dtd/notepad.md` | `.dtd/notepad.md` |
| `.dtd/.gitignore` | `.dtd/.gitignore` |
| `.dtd/.env.example` | `.dtd/.env.example` |
| `.dtd/skills/code-write.md` | `.dtd/skills/code-write.md` |
| `.dtd/skills/review.md` | `.dtd/skills/review.md` |
| `.dtd/skills/planning.md` | `.dtd/skills/planning.md` |

**Examples and QA references** (do NOT install — repo-only):

- `examples/plan-001.md` — illustrative plan (see for XML schema)
- `examples/run-001-summary.md` — illustrative run summary
- `test-scenarios.md` — QA scenarios for v0.1 verification

**Post-fetch step — initialize workers.md from workers.example.md**:

After Task 7 fetches all files, check if `.dtd/workers.md` exists locally. If
NOT (typical fresh install), copy `.dtd/workers.example.md` → `.dtd/workers.md`.
This local copy is your actual worker registry; it's gitignored so endpoints,
model names, and aliases stay local. The committed `workers.example.md` stays
in repo as schema + examples reference.

POSIX:
```bash
[ -f .dtd/workers.md ] || cp .dtd/workers.example.md .dtd/workers.md
```

Windows PowerShell:
```powershell
if (-not (Test-Path .dtd/workers.md)) { Copy-Item .dtd/workers.example.md .dtd/workers.md }
```

Same pattern as `.env` / `.env.example` (key names committed, key values local).

### Task 8 — Add host pointer to always-read file

DTD needs ONE line in the host's "always loaded" file so when the user enables
DTD mode, the controller reads `.dtd/instructions.md` automatically.

Detect the host's always-read file (priority order):

| Host | Always-read file | Slash command dir |
|---|---|---|
| Claude Code | `CLAUDE.md` (project root or `~/.claude/CLAUDE.md`) | `.claude/commands/` |
| Cursor (agent) | `.cursorrules` (project root) | `.cursor/commands/` (or rules) |
| ChatGPT Codex CLI | `AGENTS.md` (project root) or `~/.codex/AGENTS.md` | `.codex/commands/` |
| OpenCode | `AGENTS.md` (project root) | `.opencode/commands/` (varies) |
| Aider | `.aider.conf.yml` references / `CONVENTIONS.md` | n/a (no slash commands) |
| Cline / Continue | `.clinerules` / `.continuerc` | n/a |
| gemini-cli | `GEMINI.md` (or chosen) | host-specific |
| Generic / unknown | create `AGENTS.md` | put dtd.md at `.dtd/_command/dtd.md` |

**Append** (do not overwrite existing content) this block to the always-read file:

```markdown
## DTD plugin (Do Till Done)

If `.dtd/state.md` exists and shows `mode: dtd`, read `.dtd/instructions.md`
and follow it for natural-language command routing and controller behavior.

When mode is off (or no state.md), ignore — operate normally.

Slash command source: <slash-command-path>/dtd.md
```

Replace `<slash-command-path>` with the actual path you used.

If the always-read file is shared across multiple plugins (e.g. CLAUDE.md
already has agent-work-mem text), insert the DTD block at the end with one
blank line separator.

### Task 9 — Run /dtd doctor

Simulate `/dtd doctor` to verify the install:

1. All 15 `.dtd/` committed template files exist (instructions.md, config.md, workers.example.md, worker-system.md, resources.md, state.md, steering.md, phase-history.md, PROJECT.md, notepad.md, .gitignore, .env.example, plus 3 skills/*.md). PLUS `.dtd/workers.md` exists locally (gitignored, copy of workers.example.md created on first install).
2. Runtime directories exist: `.dtd/log/`, `.dtd/eval/`, `.dtd/tmp/`, `.dtd/attempts/`, `.dtd/runs/`
3. `dtd.md` exists at project root and at host slash command dir
4. Host always-read file has the DTD pointer block
5. `.dtd/state.md` `mode: off` (DTD activation, NOT host capability)
6. `.dtd/state.md` `host_mode: <plan-only|assisted|full>` matches detected capability
7. `.dtd/config.md` `host.mode` matches the same value
8. `.dtd/workers.example.md` exists (committed schema reference)
8b. `.dtd/workers.md` exists locally (created from workers.example.md if it didn't exist; gitignored). Active registry under "## Active registry" heading is empty on fresh install — recommend `/dtd workers add`.
9. `.dtd/.gitignore` excludes `.env`, `tmp/`, `log/`, `eval/`, `attempts/`, `runs/` (canonical local-protection file)
10. agent-work-mem detected (recommend if absent, do not block)
11. PROJECT.md is not pure-TODO if `host_mode` is `assisted` or `full` (WARN)
12. No stale leases in resources.md (WARN per stale lease, suggest takeover after user confirm)
13. Secret-pattern scan clean (regex per dtd.md §Security)

If any check fails, print the failing item and let the user decide
(re-fetch, manual fix, abort).

### Task 10 — AIMemory minimal init (only if AIMemory present)

If Task 4 detected agent-work-mem, append **one** event to `AIMemory/work.log`.

POSIX (atomic heredoc):

```bash
cat >> AIMemory/work.log <<EOF

### YYYY-MM-DD HH:MM | <your-model-id> | NOTE
DTD installed. host_mode=<plan-only|assisted|full>. DTD mode=off (user toggles via /dtd mode on).
EOF
```

Windows PowerShell (single append — `Add-Content` is not atomic in the POSIX `O_APPEND` sense, but for a single one-shot install event the race window is negligible):

```powershell
$entry = @"

### YYYY-MM-DD HH:MM | <your-model-id> | NOTE
DTD installed. host_mode=<plan-only|assisted|full>. DTD mode=off (user toggles via /dtd mode on).
"@
Add-Content -Path AIMemory\work.log -Value $entry
```

This is the only AIMemory write during install. Per DTD spec §8, runs
themselves emit only WORK_START/WORK_END to AIMemory.

### Task 10.5 — Record installed version (v0.2.0d)

Set `state.md.installed_version` to the current DTD version (e.g.
`v0.2.0d`). This enables `/dtd update check` and rollback flow.

If `MANIFEST.json` exists at the repo root of the install source, copy
it to the project root for offline doctor verification. If absent,
`state.md.installed_version` is recorded; `/dtd update check` can query
upstream read-only, and `/dtd update` fetches the manifest before apply.

Create `.dtd/help/` directory with the 10 topic files
(`index.md`, `start.md`, `observe.md`, `recover.md`, `workers.md`,
`stuck.md`, `update.md`, `plan.md`, `run.md`, `steer.md`) from the
release manifest. These enable `/dtd help [topic]`.

### Task 11 — Welcome + next steps

Print to user:

```
✓ DTD installed.

  host_mode:        <chosen — plan-only|assisted|full>
  DTD mode:         off (toggle on via /dtd mode on)
  installed_version: <e.g. v0.2.0d>
  Files written:    15 templates + 10 help topics + dtd.md
  Host pointer:     appended to <host-file>
  MANIFEST.json:    <copied | queried by /dtd update check; fetched by /dtd update>
  AIMemory:         <integrated | absent>

Next:

  /dtd workers add        → register your first worker LLM
  /dtd mode on            → enable DTD mode
  /dtd plan <goal>        → start planning
  /dtd status             → see current state
  /dtd doctor             → re-verify install anytime
  /dtd help [topic]       → layered help (try /dtd help start)
  /dtd update check       → see latest available version
  /dtd uninstall          → safe removal (preserves AIMemory)

Or talk naturally:

  "딥시크 워커 추가해줘"
  "API 만드는 계획 짜줘"
  "지금 어디까지 됐어?"
  "잠깐 멈춰"

Repo:           https://github.com/daystar7777/dtd
README:         <repo>/README.md  (한국어: <repo>/README.ko.md)
Test scenarios: <repo>/test-scenarios.md (acceptance + user journeys)
```

### Task 12 — Confirm

Reply with:

- model-id, vendor, harness, mode (Tier A/B/C), capabilities (vendor-neutral)
- list of files created (absolute paths)
- host pointer file modified
- agent-work-mem status (detected/absent/installed-now)
- one sentence: "I will follow `.dtd/instructions.md` whenever DTD mode is on."

---

## If files already exist (re-install / upgrade)

Do **not** silently overwrite. Detect existing files and prompt:

| File | Default action on existing |
|---|---|
| `dtd.md` (project root + host slash dir) | Refresh (overwrite OK after confirm) — spec file |
| `.dtd/instructions.md` | Refresh (after confirm) |
| `.dtd/config.md` | **Never overwrite** without explicit user "yes" — user data |
| `.dtd/workers.example.md` | Refresh OK (committed schema/examples; no user data) |
| `.dtd/workers.md` | **Never overwrite** — user data (gitignored, your actual registry) |
| `.dtd/worker-system.md` | Refresh (after confirm) |
| `.dtd/resources.md` | If non-empty, **never overwrite** (active leases) |
| `.dtd/state.md` | If `plan_status` is RUNNING/PAUSED, **abort upgrade** until cleared |
| `.dtd/steering.md` | **Never overwrite** — append-only history |
| `.dtd/phase-history.md` | **Never overwrite** — append-only history |
| `.dtd/PROJECT.md` | **Never overwrite** — user content |
| `.dtd/notepad.md` | If non-empty (active run wisdom), **never overwrite**; else refresh OK |
| `.dtd/.gitignore` | Merge (add missing entries, keep existing) |
| `.dtd/.env.example` | Refresh OK |
| skills | Refresh OK (these are templates, user can override per project) |

Run `/dtd doctor` after upgrade.

If the spec/protocol changed between versions, also append ONE event to
`AIMemory/work.log` (if present):

```
### YYYY-MM-DD HH:MM | <model-id> | NOTE
DTD upgraded from v<old> to v<new>. Spec changes: <summary>.
```

---

## End of bootstrap

After Task 12, hand control back to user. The agent's job for install is done.
The user takes over with `/dtd <subcommand>` or natural language.
