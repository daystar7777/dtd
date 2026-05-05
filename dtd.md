# DTD (Do Till Done) — Slash Command Spec

This file IS the canonical behavior spec for `/dtd` and the natural-language
equivalents. When DTD mode is ON, the controller LLM follows these rules
verbatim. When DTD mode is OFF, the host operates normally.

NL routing and state-aware decisions live in `.dtd/instructions.md`.
This file defines **what each canonical action does**.

---

## Modes

DTD has two activation states:

- **`mode: off`** — host LLM operates as usual; `/dtd` only runs informational subcommands (`status`, `doctor`, `mode on`).
- **`mode: dtd`** — host becomes the controller; reads `.dtd/instructions.md` on every turn; orchestrates worker dispatch per the plan state machine.

Mode is stored in `.dtd/state.md` (`mode:` field). Toggle with `/dtd mode on|off`.

---

## Canonical Actions

All commands accept both slash form (`/dtd <action>`) and natural-language form (per `.dtd/instructions.md`).

### `/dtd setup`

First-time install (run once). See `prompt.md` for full bootstrap.
Subsequent runs verify and offer upgrade — never destructive.

### `/dtd doctor`

Health check. Output uses the same Unicode/ASCII style as `/dtd status`.
Sections:

- Install integrity (15 templates + dtd.md, host pointer, slash-command dir)
- Mode consistency (`mode`, `host_mode`, config alignment)
- Worker registry (`workers.md` parse, alias collisions, escalate chain)
- agent-work-mem (integrated/absent INFO)
- Project context (`PROJECT.md` TODO-only, ≤ 8 KB)
- Resource state (stale leases, orphaned locks)
- Plan state (`plan_status`, plan size budget, pending patches)
- Autonomy & Attention state (v0.2.0f) — decision/attention modes,
  deferred refs, capsule schema for `CONTROLLER_TOKEN_EXHAUSTED`
- Context-pattern state (v0.2.0f) — resolved patterns, plan XML attrs,
  ctx file count
- Incident state (v0.2.0a) — multi-blocker invariant, attempt cross-link,
  secret-leak scan
- Self-Update state (v0.2.0d) — `installed_version`, `update_in_progress`
  staleness, MANIFEST.json validity
- Help system (v0.2.0d) — 9 canonical topics, size budgets
- Permission ledger (v0.2.0b) — `.dtd/permissions.md` parses, no
  overly-broad bash allow, expired `until` rules, ledger size cap
- Snapshot state (v0.2.0c) — `.dtd/snapshots/` size, manifest
  integrity, preimage SHA, patch dry-run cleanliness
- Worker health + runtime resilience (v0.2.1) — health-check log
  retention, redaction discipline, resume strategy validity, loop
  guard signature consistency
- Notepad schema (v0.2.2) — schema v1/v2 detect, 8-heading
  presence, per-heading budget, Reasoning Notes content
  discipline (no chain-of-thought leak)
- Quota state (v0.3.0b) — per-worker usage ledger, predictive
  routing thresholds, paid-fallback authorization, redaction
- Cross-run loop guard (v0.3.0a) — stable signature ledger
  format, capture-before-clear at finalize_run, retention prune
- Consensus state (v0.3.0c) — staged-output isolation, group
  lock semantics, late-result-never-apply invariant, 11-key
  permission set
- Session sync (v0.3.0d) — mandatory encryption invariant,
  `repo_identity_hash` priority, SESSION_CONFLICT capsule
  before same-session reuse, connectivity ≠ conflict
- Locale state (v0.2.0e) — locale pack existence, required sections,
  bootstrap-alias presence, ≤ 12 KB pack budget
- Spec modularization (v0.2.3 R1) — reference dir, 13 canonical topics,
  Summary + Anchor sections, ≤ 24 KB (doctor-checks + run-loop
  ≤ 48 KB cross-cutting exception; bumped at v0.3.0b R0 from 32 KB)
- Path policy (BLOCK patterns, `..` paths, relative/absolute)
- `.gitignore` + secret leak (regex scan for known key patterns)

Exit code on slash hosts: 0 if all checks pass, 1 if any ERROR-level issue.

> Full canonical reference: see `.dtd/reference/doctor-checks.md`
> (every check rule per section, ERROR/WARN/INFO codes, secret-leak
> regex catalog).
> Lazy-load via `/dtd help doctor-checks --full`.

### `/dtd update [check|--dry-run|--rollback|--pin <version>]` (v0.2.0d)

Self-Update flow. Fetches latest DTD release from GitHub, verifies
via `MANIFEST.json`, runs state-schema migration, applies files
atomically, runs doctor verification, rolls back on failure.

Forms:
- `/dtd update` — check + preview + apply (interactive; latest)
- `/dtd update check` — observational
- `/dtd update --dry-run` — preview only
- `/dtd update --pin <version>` — specific version
- `/dtd update --rollback` — restore from backup

Update flow (B1-B7):
B1 Lock → B2 Fetch manifest → B2.5 Verify version → B3 Backup →
B3.5 State schema migration → B4 Apply files (temp + atomic
rename) → B5 Doctor verification → B5.5 Rollback (on any error) →
B6 Update state → B7 Cleanup.

Token discipline: `config.md.update.github_token_env` names env
var; NEVER inline tokens; NEVER URL-form tokens.

> Full canonical reference: see `.dtd/reference/self-update.md`
> (pre-update gates, B1-B7 step bodies, rollback flow, migration
> log format, NL routing).
> Lazy-load via `/dtd help self-update --full`.

### `/dtd help [topic] [--full]` (v0.2.0d)

Layered help system. Default ≤ 25-line overview from
`.dtd/help/index.md`. `/dtd help <topic>` shows ≤ 50-line topic detail
from `.dtd/help/<topic>.md`. `--full` prints the entire topic file or
the matching `.dtd/reference/<topic>.md` reference.

Topic resolution: input → help dir → keyword search → catalog.
v0.2.3 extension: `--full` may render exactly one
`.dtd/reference/<topic>.md` file (do not load dtd.md or other
reference files).

Canonical topics (v0.2.0d): `start`, `observe`, `recover`, `workers`,
`stuck`, `update`, `plan`, `run`, `steer`. Plus `index` (catalog).

Output is `observational_read`: never writes `state.md`, `notepad.md`,
`phase-history.md`, or `attempts/run-NNN.md`. Static template render.

> Full canonical reference: see `.dtd/reference/help-system.md`
> (resolution algorithm, topic file structure, NL routing table,
> v0.2.3 reference-topic extension, output discipline).
> Lazy-load via `/dtd help help-system --full`.

### `/dtd notepad [show|search|compact]` (v0.2.2)

Notepad lifecycle + structured-handoff inspection.

Forms:

```text
/dtd notepad show [--full|--handoff-only]   # observational
/dtd notepad search <query>                 # search across .dtd/runs/
/dtd notepad show <run-id>                  # historical (from .dtd/runs/)
/dtd notepad compact                        # manual compaction (rare)
```

**Schema v2 (v0.2.2)**: `## handoff` H2 with 8 H3 children:
`Goal | Constraints | Progress | Decisions | Next Steps |
Critical Context | Relevant Files | Reasoning Notes`. Total
worker-visible ≤ 1.2 KB.

**Per-heading budget + compaction priority**:

| Heading | Budget | Compaction priority |
|---|---:|---|
| Goal | 150 ch | KEEP |
| Constraints | 200 ch | KEEP |
| Progress | 200 ch | TRUNCATE first → "Phase N done; see phase-history.md" |
| Decisions | 200 ch | KEEP |
| Next Steps | 150 ch | KEEP |
| Critical Context | 250 ch | KEEP |
| Relevant Files | 100 ch | TRUNCATE second |
| Reasoning Notes | 200 ch | KEEP last 3 entries |

**Reasoning Notes discipline**: compact `decision/evidence_refs/
risks/next_action/lesson` outputs from v0.2.0f reasoning utilities
(`tree_search`, `reflexion`, `tool_critic`, `react`,
`least_to_most`, etc.). Never chain-of-thought; ≤ 5 lines per
entry. Doctor flags narrative leakage as
`reasoning_notes_chain_of_thought_leak`.

**Schema detection** (controller-side):
- First H2 in notepad is `## handoff` AND H3 children include
  `### Goal` → schema v2 → enable per-heading compaction.
- Else → schema v1 (free-form) → treat `<handoff>` as one block.

**Compaction algorithm** at phase boundary:
1. Read current notepad; parse 8 v2 headings + 4 free-form
   sections (`learnings`, `decisions`, `issues`, `verification`).
2. Free-form sections: preserve last 3 entries; older summarize
   to one bullet per category.
3. `## handoff`: if total ≤ 1.2 KB, no change. Else apply
   per-heading priorities (truncate Progress first, then
   Relevant Files; KEEP others). Progress is historical and recoverable from
   `phase-history.md`; relevant file refs are often more immediately useful
   to the next worker.
4. If still over budget after truncation: log WARN to
   `.dtd/log/run-NNN.md`; doctor surfaces
   `notepad_heading_oversized` next time.

**Backward-compat**: pre-v0.2.2 free-form notepads keep working;
controller treats them as schema v1 with no per-heading compaction.
`/dtd update` v0.2.2 schema migration prepends v2 headings above
existing free-form content (Amendment 9; user data preserved).

NL routing (English):

| Phrase | Canonical |
|---|---|
| "show notepad" | `/dtd notepad show` |
| "search past notes for X" | `/dtd notepad search X` |
| "compact notepad" | `/dtd notepad compact` |

Korean / Japanese NL routing in respective locale packs.

`/dtd notepad show/search` are observational reads.
`/dtd notepad compact` is mutating but not destructive (it
reorganizes, never deletes audit trail — older entries roll into
the free-form `## learnings` section).

### `/dtd consensus show [<task_id>|--active]` (v0.3.0c)

Multi-worker consensus dispatch inspection. Read-only; consensus
dispatch itself is opted-in via plan XML `consensus="<N>"`
attribute on `<task>` or `<phase>`.

Forms:

```text
/dtd consensus show <task_id>          # observational; show all N outcomes for that task
/dtd consensus show --active           # observational; show currently-active consensus group
```

Selection strategies (4): `first_passing | quality_rubric |
reviewer_consensus | vote_unanimous`. Each consensus task
dispatches N workers in parallel into ISOLATED staging dirs
(`.dtd/tmp/consensus-<run>-<task>-<att>-<worker>.staged/`); only
the winner applies to project files (Codex P1.4: late results
NEVER apply).

Permission gate: `task_consensus` key (NEW v0.3.0c; expands
v0.2.0b 10-key set to 11 keys per Codex P1.5). Default `ask`;
user opts in via `/dtd permission allow task_consensus scope: *`.

Decision capsules:
- `CONSENSUS_DISAGREEMENT` (vote_unanimous strategy with
  divergent outputs): options `[reviewer_pick, controller_pick,
  retry_all, stop]`.
- `CONSENSUS_PARTIAL_FAILURE` (some N workers failed): options
  `[accept_majority, retry_failed, stop]`.

Cost multiplier: consensus tasks consume N× tokens. In
`host.mode: assisted` AND
`consensus_confirm_each_call: true` (default): controller
surfaces explicit confirm before each dispatch.
`/dtd plan show` annotates consensus tasks: `[consensus=N
<strategy>] [N× cost]`.

> Full canonical reference (algorithm + run-loop step 5.5.5 +
> 6.consensus + group lock + late-result cancellation + doctor
> checks): see `.dtd/reference/v030c-consensus.md`.
> Lazy-load via `/dtd help v030c-consensus --full`.

### `/dtd session-sync [show|sync|expire|purge]` (v0.3.0d)

Cross-machine worker session affinity. Default `enabled: false`
(per-machine v0.2.1 behavior). When enabled, ALL synced payloads
are MANDATORILY encrypted — raw provider session ids are NEVER
written to a synced folder or branch (Codex P1.6).

Forms:

```text
/dtd session-sync show                        # observational; local + synced sessions
/dtd session-sync sync                        # mutating; manual sync now
/dtd session-sync expire <session_id_hash>    # mutating; mark a session expired
/dtd session-sync purge --before <date>       # bulk purge old entries
```

(Interactive `/dtd session-sync setup` wizard deferred to R1 per
Codex additional amendment; R0 manual config via `.dtd/config.md`
must be safe.)

Backends: `none | filesystem | git_branch`. Filesystem syncs
through user-configured cloud folder (Dropbox / iCloud / OneDrive /
Drive); git_branch commits to a dedicated branch with periodic
push.
For `git_branch`, sync ledger files are force-added only on the
configured sync branch or isolated worktree; they must never be
staged on the user's active project branch.

Encryption invariant (Codex P1.6 — MANDATORY when sync is enabled and backend ≠ none):
- `session_sync_encryption_key_env` MUST resolve to a non-empty
  value. Missing / empty: ERROR `session_sync_no_encryption_key`,
  sync DISABLED for the run (NEVER plaintext fallback).
- These backend doctor errors apply only when
  `session_sync.enabled: true` and backend is not `none`; users may
  preconfigure a backend while sync remains disabled.
- Synced ledger contains only `session_id_hash` + metadata; raw
  `session_id` lives in `.dtd/session-sync.encrypted`
  (AES-256-GCM, key derived via HKDF from env-var value, per-row
  96-bit nonce).

Repo identity: uses the same 3-tier `repo_identity_hash` as
v0.3.0a (git remote+first-commit-sha → state.md.project_id UUID →
absolute path tie-breaker only). Sync target paths are
`<sync_root>/<repo_identity_hash>/`.

Decision capsule:
- `SESSION_CONFLICT` fires when 2 machines have different
  `session_id_hash` for the same `(worker, provider)` tuple.
  Options `[use_local, use_remote, fresh, stop]`. Default
  `fresh` (Codex: keep `ask` conflict_strategy default).

A sync connectivity failure (network, push rejected, sync path
missing) does NOT block dispatch — it logs WARN
`session_sync_unreachable` and falls back to per-machine
behavior. A real `SESSION_CONFLICT` MUST create a decision
capsule before any same-session reuse (Codex additional
amendment: connectivity ≠ conflict).

> Full canonical reference (3 backends + run-loop steps 5.5.5b +
> 9.session-sync + encryption invariant + 10 doctor checks +
> migration): see `.dtd/reference/v030d-cross-machine-session-sync.md`.
> Lazy-load via `/dtd help v030d-cross-machine-session-sync --full`.

### `/dtd loop-guard [show|prune|rehash]` (v0.3.0a)

Cross-run loop guard ledger management. Within-run loop guard
remains in `/dtd workers` (v0.2.1).

Forms:

```text
/dtd loop-guard show [--all|--recent|--full]   # observational
/dtd loop-guard prune <signature>               # mutating; tombstone
/dtd loop-guard prune --before <date>           # bulk tombstone
/dtd loop-guard rehash [--dry-run]              # admin; recompute signatures after project identity stabilizes
```

Cross-run signature is STABLE across runs (per Codex P1.1
amendment): repo identity (git remote URL + first-commit-sha,
NOT absolute path), normalized task goal, worker provider+model
or capability, output path scope, failure class enum, normalized
error line. See `.dtd/reference/v030a-cross-run-loop-guard.md`
§"Stable cross-run signature (P1.1 amendment)" for full formula.

Capture-before-clear: when within-run loop guard reached
`count >= 1` during a run, finalize_run step 5d (NEW) computes
the stable cross-run signature and upserts into
`.dtd/cross-run-loop-guard.md` BEFORE step 7 clears within-run
fields.

`LOOP_GUARD_CROSS_RUN_HIT` capsule fires when
`cross_run_match_count >= config.cross_run_threshold` (default
2 prior runs). Options: `[ask_user, swap_to_specific,
controller, prune_signature, stop]`, default `ask_user`.

`prune_signature` action appends a tombstone (Codex P1
additional), never physically removes.

Compact `/dtd status --full` shows only the active cross-run hit
+ short hint; full prior resolutions in
`/dtd loop-guard show --full`.

> Full canonical reference (algorithm + ledger format + doctor
> checks): see `.dtd/reference/v030a-cross-run-loop-guard.md`.
> Lazy-load via `/dtd help v030a-cross-run-loop-guard --full`.

### `/dtd snapshot [list|show|purge|rotate]` (v0.2.0c)

Pre-apply file snapshots stored under `.dtd/snapshots/`. Three modes
per file (chosen by policy at apply-time):

| Mode | Contents | Revertable | When |
|---|---|---|---|
| `metadata-only` | SHA-256 + size + git diff metadata | NO (audit-only) | explicit audit-only files or non-output context where revertability is not promised |
| `preimage` | byte-for-byte pre-apply copy, or an absent-prestate marker for newly-created output paths | YES | default for normal worker output, binaries, untracked files, new output paths, or `revert_required: true` |
| `patch` | forward + reverse unified diff | YES | text files larger than `preimage_size_threshold` and `<= patch_max_size` |

Normal worker output files must be revertable by default. Small tracked text
files and newly-created output paths therefore use `preimage`, not
`metadata-only`; new-path preimages record "absent before apply" so revert can
delete the created file. `metadata-only` is an explicit audit-only choice and
cannot be the default for apply writes.

Forms:

```text
/dtd snapshot list [--task <id>|--run <id>|--all]   # observational
/dtd snapshot show <snap-id>                        # observational; manifest
/dtd snapshot purge <snap-id>                       # destructive; tombstone in index
/dtd snapshot purge --before <date>                 # bulk purge
/dtd snapshot rotate                                # move retention-aged snaps to archived/
```

Snapshot creation hooks into run-loop step 6.g.0 (BEFORE temp-write):
mode chosen per file → snapshot artifact written to
`.dtd/snapshots/snap-<run>-<task>-<att>/files/<encoded-path>.<mode>`
→ `manifest.md` + `index.md` rows appended → THEN proceed to phase 1.

If snapshot phase fails (DISK_FULL / FS_PERMISSION_DENIED): per
`config.snapshot.on_snapshot_fail` (default `refuse_apply`). Decision
capsule offers `proceed_unsafe` option (marks attempt
`unrevertable: true`).

### `/dtd revert <last|attempt <id>|task <id>>` (v0.2.0c)

Restore files from a snapshot. **Destructive** — always confirms
explicitly per `instructions.md` §Confidence & Confirmation.

Forms:

```text
/dtd revert last                # undo most recent apply
/dtd revert attempt <id>        # undo specific attempt's apply
/dtd revert task <id>           # undo all attempts for a task in reverse order
/dtd revert --dry-run last      # preview only; no file writes
```

Revert algorithm:

1. Permission gate: per v0.2.0b ledger, `revert: allow` required.
   `ask` fires `awaiting_user_reason: PERMISSION_REQUIRED` first;
   `deny` aborts.
2. Find target snapshot(s) by scope. For `task <id>`, gather all
   attempts marked `applied: true` for that task; superseded
   attempts skipped.
3. Validate every listed file:
   - `preimage`: snapshot file exists AND its SHA matches manifest.
   - `patch`: snapshot patch applies cleanly to current state
     (dry-run check).
   - `metadata-only`: NOT revertable; surface
     `revert_unavailable_metadata_only`.
4. If ANY listed file is metadata-only: fill capsule
   `awaiting_user_reason: PARTIAL_REVERT` with options
   `revert_revertable_only / inspect / cancel`.
5. If ALL revertable AND user confirmed:
   - Acquire write locks per §Resource Locks (same as fresh apply).
   - Phase 1: write reverted content to temp files.
   - Phase 2: atomic rename over current files.
   - Append `attempts/run-NNN.md` row: `reverted: snap-<id>`.
   - Append `phase-history.md` row.
   - Update `state.md.last_revert_id`, `last_revert_at`.

Conflict resolution for `task <id>`: revert applies in REVERSE order
(most recent attempt first). Files modified across multiple attempts
restore correctly because each snapshot captured pre-apply state.

NL routing (English):

| Phrase | Canonical |
|---|---|
| "revert last", "undo last change" | `/dtd revert last` |
| "undo task 3" | `/dtd revert task 3` |
| "show snapshots" | `/dtd snapshot list` |
| "rotate snapshots" | `/dtd snapshot rotate` |

Korean / Japanese NL routing in respective locale packs.

### `/dtd permission [list|show|allow|deny|ask|revoke|rules]` (v0.2.0b)

Persistent permission rules at `.dtd/permissions.md`. Per-key
decisions: `ask | allow | deny`. Auto-handled in `decision_mode: auto`
or `attention_mode: silent` per resolution algorithm.

Forms:

```text
/dtd permission list                              # observational; show active + defaults
/dtd permission show <key> [scope: <expr>]        # observational; resolved decision
/dtd permission allow <key> [scope: <expr>] [for <duration> | until <abs|named>]
/dtd permission deny  <key> [scope: <expr>] [for <duration> | until <abs|named>]
/dtd permission ask   <key> [scope: <expr>]       # revert to ask
/dtd permission revoke <key> [scope: <expr>]      # remove (audit retained)
/dtd permission rules                             # observational; show config defaults
```

**Time-limited syntax (v0.3.0e)**:

| Form | Example | Meaning |
|---|---|---|
| `for <int><m\|h\|d\|w>` | `for 1h`, `for 30m`, `for 2d` | relative duration from now |
| `until <ISO ts>` | `until 2026-05-06T18:00:00Z` | absolute UTC timestamp |
| `until <named scope>` | `until eod`, `until this-week` | named time scope (local tz) |
| `for run` | `for run` | until current/next `/dtd run` finalize_run (sentinel `run_end`) |

Named scopes: `today | eod | this-week | next-monday | next-week
| run | run_end`. Local-time scopes are interpreted in the user's
local timezone; `resolved_until_tz` is stored on the rule for
unambiguous cross-machine interpretation (v0.3.0d sync reads it).

`for X` and `until Y` are MUTUALLY EXCLUSIVE — parse-rejected
(`permission_duration_until_mixed_unsupported`). Combined units (`for 1h30m`) deferred to v0.3.x — rejected with
`permission_duration_combined_unsupported_v030e`; workaround
`for 90m`.

Auto-prune at finalize_run runs as dedicated step 5c (v0.3.0e):
terminal exits append tombstone rows for `resolved_until:
run_end` AND `resolved_until: <ISO ts>` rows where `ts < now`.
See `reference/run-loop.md` §"Time-limited permissions
auto-prune (v0.3.0e R0)" + `.dtd/reference/v030e-time-limited-permissions.md`
for the R1 runtime contract.

Permission keys (canonical 11-key set; v0.2.0b 10-key + v0.3.0c
`task_consensus`):

| Key | Covers |
|---|---|
| `edit` | worker writes to project files (project-level switch) |
| `bash` | shell exec by worker or controller |
| `external_directory` | path outside project root (absolute or `~/`) |
| `task` | dispatching worker tasks (master switch) |
| `snapshot` | `.dtd/snapshots/` writes (v0.2.0c dependency) |
| `revert` | `/dtd revert` (v0.2.0c dependency) |
| `tool_relay_read` | controller-relayed read-only worker tool requests |
| `tool_relay_mutating` | controller-relayed mutating worker tool requests; never bypasses path/permission/apply validation |
| `task_consensus` | (v0.3.0c) multi-worker consensus dispatch (cost-multiplier; per-task opt-in via plan XML `consensus="N"` attribute) |
| `todowrite` | controller TodoWrite/state-tracking (always-safe; default `allow`) |
| `question` | controller asking user via decision capsule |

Scope expressions:
- Path glob: `scope: src/**`, `scope: ~/data/**`
- Worker id: `worker: deepseek-local`
- Capability: `capability: code-write`
- Bash command (exact match by default; `regex:` prefix for regex):
  `scope: npm test`, `scope: regex:^npm (test|run)`

Resolution: gather active matching rules, ignore expired rules, then choose
the most specific scope first and latest timestamp second for ties
(default-rules fallback when nothing matches). Scope specificity is
determined by exactness/longer glob/path before `*`; worker and capability
filters add specificity. See `.dtd/permissions.md` for the full algorithm.

Decision capsule integration (v0.1 `awaiting_user_reason:
PERMISSION_REQUIRED`):

```yaml
awaiting_user_reason: PERMISSION_REQUIRED
decision_options:
  - {id: allow_once,   label: "allow once",        effect: "proceed; no rule",            risk: "next time will ask again"}
  - {id: allow_always, label: "allow always",      effect: "add allow rule; proceed",     risk: "broadens permission scope"}
  - {id: deny_once,    label: "deny once",         effect: "abort; no rule",              risk: "may need retry later"}
  - {id: deny_always,  label: "deny always",       effect: "add deny rule; abort",        risk: "may need /dtd permission revoke later"}
decision_default: deny_once
```

NL routing (English):

| Phrase | Canonical |
|---|---|
| "edit src freely" | `/dtd permission allow edit scope: src/**` |
| "auto-run npm test" | `/dtd permission allow bash scope: npm test` |
| "always ask for ~/data" | `/dtd permission ask external_directory scope: ~/data/**` |
| "never run rm -rf" | `/dtd permission deny bash scope: rm -rf` |
| "show permissions" | `/dtd permission list` |

Korean / Japanese NL routing in the respective locale pack.

`list/show/rules` are observational reads. `allow/deny/ask/revoke`
are mutating; they append to `.dtd/permissions.md` `## Active rules`.
`revoke` adds a tombstone entry rather than truncating history.

#### Permission-key → run-loop step matrix (v0.2.0b R1)

Each permission key is resolved at a specific run-loop step (per
`.dtd/reference/run-loop.md` §"Permission resolution at dispatch
time"):

| Key | Run-loop step | Surface |
|---|---|---|
| `task` | 5.5 (master switch) | one resolution per task before dispatch |
| `bash` | 6.c (worker shell) / 6.g (apply hook) / 6.e.5 (relay) | wherever shell exec is requested |
| `external_directory` | 6.c (read) / 6.f.0 (write) | path outside project root |
| `edit` | 6.f.0 (pre-apply) | per output path; most-specific scope wins |
| `snapshot` | 6.g (between phase 1 and 2) | v0.2.0c snapshot writes |
| `revert` | `/dtd revert` command | NOT in run-loop; user-invoked |
| `todowrite` | 1, 2, 5, 6.i (controller-internal) | default `allow`; never blocks |
| `question` | whenever capsule fills | default `ask` |
| `tool_relay_read` | 6.c (pre-dispatch) / 6.e.5 (post-response) | read-only worker tool calls |
| `tool_relay_mutating` | 6.e.5 (post-response, mutating relay) | write/exec/network tool calls |

**Silent-mode interaction**: `allow` rules auto-handle without
capsule. `deny` rules abort immediately AND do NOT defer (deny is
unambiguous). `ask` rules fire `PERMISSION_REQUIRED` capsule which
silent mode defers per `silent_deferred_decision_limit`. Transient
rules from `silent_allow_*` flags expire at `attention_until` (see
`.dtd/reference/autonomy.md` §"Silent transient rules (v0.2.0b R1)").

**Decision-mode interaction**: `decision_mode: auto` does NOT
auto-resolve `ask` permission rules. Permission-class is treated
as user-required regardless of decision_mode. The only auto-resolve
gate is when the user explicitly wrote an `allow` rule.

**Audit log**: every resolution writes one row to
`.dtd/log/permissions.md` (gitignored, append-only). Format spec
in `.dtd/permissions.md` §"Audit log (v0.2.0b R1)".

### `/dtd locale [enable|disable|list|show] [<lang>]` (v0.2.0e)

Optional locale-pack management. Core operational prompts ship
English-only; locale packs augment NL routing + slash aliases for
the user's preferred language.

Forms:

```text
/dtd locale list              # observational; show available + active
/dtd locale show              # observational; current locale config
/dtd locale enable <lang>     # mutating; activate <lang> pack (e.g. ko, ja)
/dtd locale disable           # mutating; back to English-only core
```

Effects:

- **`/dtd locale enable <lang>`**:
  - Validate `<lang>` against `.dtd/locales/<lang>.md` existence;
    ELSE refuse with `locale_pack_missing` hint.
  - Set `config.md locale.enabled: true`, `locale.language: <lang>`.
  - Set `state.md locale_active: <lang>`, `locale_set_by: user`,
    `locale_set_at: <ts>`.
  - Pack loaded on the next instruction-load turn (controller picks
    up `.dtd/locales/<lang>.md` after reading `state.md`).
  - Confirm to user with localized phrasing if pack is now active.
- **`/dtd locale disable`**:
  - Set `config.md locale.enabled: false`, `locale.language: null`.
  - Set `state.md locale_active: null`, `locale_set_by: user`.
  - Pack file remains on disk; `enable` reactivates without reinstall.
- **`/dtd locale list`**: observational. Output:

  ```text
  + DTD locales
  | active     ko (enabled by user 2026-05-05)
  | available
  | * ko       Korean (NL routing + /ㄷㅌㄷ alias)
  | * ja       Japanese (seed pack — full coverage in R1+)
  | * en       English (always available — core prompts)
  ```

- **`/dtd locale show`**: observational read of current settings.

Pack-load order (per-turn protocol step 1.6 — added by v0.2.0e):
After `instructions.md` and lazy-load profile resolution (step 1.5),
if `state.md locale_active != null`, also load
`.dtd/locales/<active>.md` for this turn. Pack additions augment
core NL routing; **on conflict, pack wins** (user explicitly opted
in).

Bootstrap chicken-and-egg: even before any locale pack is loaded,
core `instructions.md` retains a tiny bootstrap alias table so a
non-English user can issue `/ㄷㅌㄷ locale enable ko` from a fresh
install. See `instructions.md` §"Locale bootstrap aliases".

NL routing (English):

| Phrase | Canonical |
|---|---|
| "enable Korean", "Korean mode on" | `/dtd locale enable ko` |
| "show locales", "what languages" | `/dtd locale list` |
| "disable locale", "English only" | `/dtd locale disable` |

Korean / Japanese NL routing for `/dtd locale` is in the
respective pack file.

### `/dtd uninstall [--soft|--hard|--purge]`

Three-tier removal. Default is `--soft` (least destructive). Each tier is a strict superset of the prior in destructiveness.

**`--soft`** (default):
1. Set `state.md` `mode: off` (DTD activation off, host_mode preserved).
2. Keep all `.dtd/` content intact.
3. Optionally remove DTD pointer block from host always-read file (ask user).
4. Slash command file remains.
5. Plans, history, steering, eval all preserved.

→ Reversible: `/dtd mode on` reactivates without re-install.

**`--hard`**:
1. Set `state.md` `mode: off`.
2. Remove DTD pointer block from host always-read file.
3. Move `.dtd/` to `.dtd.uninstalled-YYYYMMDD-HHMM/` (timestamped backup at project root).
4. **Add `.dtd.uninstalled-*/` pattern to project-root `.gitignore`** (with user confirm). Reason: `.dtd/.gitignore` cannot reach the project-root backup path; without root coverage the backup becomes git-visible. If user declines: WARN that backup may be tracked by git.
5. Remove `dtd.md` from project root and host slash command directory.
6. If install added entries to project-root `.gitignore` (only if user opted in at install), remove only those install-added entries (preserve user's other entries).
7. **Never touch `AIMemory/`**.

**`--purge`** (destructive, requires explicit `y`):
1. Everything `--hard` does.
2. Plus: delete the `.dtd.uninstalled-*` backup folder.
3. **Never touch `AIMemory/`** unless user separately requests it.

Common gates (all variants):
- If `state.md` shows `plan_status: RUNNING` or `pending_patch: true`, abort uninstall and tell user to `/dtd stop` first.
- AIMemory is sacred: even `--purge` does not touch it. If user wants AIMemory removed, that's a separate `agent-work-mem` operation.

### `/dtd mode on|off`

Toggle. Updates `state.md` `mode` field. On `off`: in-flight tasks finish, no new tasks dispatched. On `on`: load `.dtd/instructions.md` on next turn.

### `/dtd workers [list|add|test|rm|alias|role]`

Worker registry management. Backed by `.dtd/workers.md`.

- `list` (default if no arg): table of registered workers with id, aliases, tier, capabilities, cost_tier, current health
- `add`: **thin conversational wizard** — asks one field at a time, redacts secrets, writes to `.dtd/workers.md` (gitignored) and optionally `.env`:

  1. **Alias hint**: if user said "qwen 워커 추가해줘", controller pre-fills `worker_id: qwen-local` and `aliases: qwen`. User can override.
  2. **Endpoint** — controller suggests common cases based on alias hint (e.g., qwen → `http://localhost:1234/v1/chat/completions` (LMStudio default)). Asks once.
  3. **Model** — suggests common ids per provider hint (e.g., DeepSeek → `deepseek-v4-pro`).
  4. **api_key_env** — env var **name** only. Suggests `<ID_UPPER>_API_KEY` (e.g., `QWEN_API_KEY`). This is the only secret-related field collected through chat.
  5. **API key value** — by default, NOT collected through chat (a chat host conversation is not a secure secret-input channel; the value would persist in the controller's transcript). Instead, the wizard tells the user:

     ```
     Set the key value yourself:

     POSIX (bash/zsh):  echo 'QWEN_API_KEY=<your-key-here>' >> .dtd/.env
     Windows (PowerShell): Add-Content -Path .dtd/.env -Value 'QWEN_API_KEY=<your-key-here>'

     Or if you already have QWEN_API_KEY set in your shell environment, leave .dtd/.env empty for that key — DTD will use the shell value.

     When done, run /dtd workers test <id> to verify.
     ```

     The wizard then proceeds to step 6 without ever seeing the secret. Confirmation of "key is set" is non-secret metadata only (e.g., "I've set it" / "skip"). NEVER echo length, prefix, suffix, fingerprint, or any other secret-derived info — those are still secret material in the chat.

     Only if the host explicitly provides a secure-input channel (a tool UI prompt that bypasses the LLM conversation), wizard MAY accept the key value through that channel and write it directly to `.dtd/.env`. v0.1.1 hosts (chat-only) follow the user-sets-it path above.
  6. **max_context** — suggests provider default (32000 / 64000 / 128000 / 200000 depending on model hint).
  7. **capabilities** — suggests based on phrasing (qwen/deepseek-coder → `code-write, code-refactor`).
  8. **permission_profile** — defaults to `code-write`. Asks user to confirm or pick `explore | review | planning | code-write`.
  9. **Test now?** — offers to run `/dtd workers test <id>` immediately. A standalone test is observational: it prints the failure, writes only a redacted worker-check log, and does NOT mutate state/notepad/attempts or create a decision capsule. `/dtd run` preflight later creates `WORKER_HEALTH_FAILED` if an assigned worker is still unhealthy.

  **Secret handling rules**:
  - API key value (raw) NEVER enters chat conversation. v0.1.1 wizard does NOT prompt for it.
  - User sets `.dtd/.env` themselves (POSIX/PowerShell snippet provided in step 5).
  - NEVER echo any secret-derived info — no length, no prefix/suffix, no fingerprint, nothing the user provided as secret.
  - `workers.md` only ever holds `api_key_env: <NAME>`. `.dtd/.env` is the canonical secret file path (NOT plain `.env`).
  - If the host provides a secure-input channel out-of-band of the chat conversation, wizard MAY use that path to write `.dtd/.env` directly. v0.1.1 chat hosts follow the user-sets-it path.

  **Apply step**: before writing, shows summary (no secret-derived info — wizard never saw a value):
  ```
  About to add worker:
    id: qwen-local
    endpoint: http://localhost:1234/v1/chat/completions
    model: qwen2.5-coder:32b
    api_key_env: QWEN_API_KEY
    api_key_value: not collected (set .dtd/.env or shell env)
    max_context: 32768
    capabilities: code-write, code-refactor
    permission_profile: code-write
  Apply? yes | edit <field> | cancel
  ```
  Only on `yes` does controller append to `workers.md`. The wizard does NOT write `.dtd/.env` in v0.1.1 (chat-host hosts) — user sets the value out-of-band per step 5.

  **Wizard isolation**: wizard turns are setup-context, not run-context. Don't mutate notepad/steering/attempts/phase-history. Don't include wizard Q/A in future worker prompts.
- `test [<id|alias>] [--all|--quick|--full|--connectivity|--assigned|--json|--quota]` (v0.2.1 + v0.3.0b):
  multi-stage health probe per `.dtd/reference/workers.md` §"Worker
  Health Check" (full canonical spec for the 17-stage diagnostic).
  Compact summary:
  - `--quick` (default): stages 1-5 (schema → secret/env → endpoint → network).
  - `--full`: all 17 stages, including stage 4 protocol probe + stages
    14-15 tool-relay + native-sandbox checks (when worker has
    `tool_runtime: controller_relay | worker_native | hybrid`).
  - `--connectivity`: stages 4-6 (endpoint URL + network reachability + TLS).
  - `--all`: every registered worker.
  - `--assigned`: every worker assigned to the active plan.
  - `--json`: machine-readable summary.
  Failure taxonomy: `WORKER_REGISTRY_PARSE_FAILED`, `WORKER_NOT_FOUND`,
  `WORKER_SCHEMA_INVALID`, `WORKER_ENV_MISSING`,
  `WORKER_ENDPOINT_INVALID`, `WORKER_NETWORK_UNREACHABLE`,
  `WORKER_TLS_FAILED`, `WORKER_AUTH_FAILED`, `WORKER_FORBIDDEN`,
  `WORKER_RATE_LIMITED`, `WORKER_TIMEOUT`, `WORKER_MODEL_NOT_FOUND`,
  `WORKER_PROVIDER_ERROR`, `WORKER_BAD_RESPONSE_JSON`,
  `WORKER_SENTINEL_MISMATCH`, `WORKER_PROTOCOL_VIOLATION`,
  `WORKER_TOOL_RELAY_BAD_FORMAT`, `WORKER_TOOL_RELAY_FABRICATED_RESULT`,
  `WORKER_TOOL_RELAY_REFUSED`, `WORKER_NATIVE_TOOL_SANDBOX_INVALID`,
  `WORKER_NATIVE_TOOL_NOT_SUPPORTED`, `WORKER_NATIVE_TOOL_HOST_LEAK`,
  `WORKER_HEALTH_LOG_WRITE_FAILED`. Diagnostic log written to
  `.dtd/log/worker-checks/<ts>.md` (gitignored; redacted artifacts
  only — no raw env values, no auth headers).
  Standalone `/dtd workers test` is observational and creates no incident
  or decision capsule. Decision capsule reason `WORKER_HEALTH_FAILED` fires
  only when `/dtd run` preflight detects an assigned worker is unhealthy.
  **`--quota` flag (v0.3.0b)**: observational; reports per-worker daily +
  monthly token usage against quota declarations (workers.md
  `daily_token_quota` / `monthly_token_quota`). Output shows remaining
  quota + predictive routing impact for next-task estimates. Worker
  rate-limit headers (`x-ratelimit-*` / `ratelimit-*`) captured advisory-only
  per `worker.quota_provider_header_prefix`. See
  `.dtd/reference/run-loop.md` §"Quota predictive check + ledger
  discipline (v0.3.0b R0)" for full contract.
- `rm <id>`: remove (warn if any plan references this worker; offer to remap)
- `alias add <id> <alias>` / `alias rm <id> <alias>`: manage aliases
- `role set <role> <id>` / `role unset <role>`: manage role mapping in `config.md`

NL equivalents: see `instructions.md`.

#### Worker session resume (v0.2.1)

When a dispatch is interrupted (timeout / 5xx / stream cut / lease
takeover), controller picks a `resume_strategy` for the next attempt:

| Strategy | When | Effect |
|---|---|---|
| `fresh` | Default; provider has no session, OR prior failed with AUTH/MALFORMED/PROTOCOL_VIOLATION | Brand-new prompt assembly + fresh worker context |
| `same-worker` | `worker.supports_session_resume: true` AND prior was TIMEOUT / NETWORK / RATE_LIMIT / 5xx | Same provider, pass `session_id`, append compact continue instruction |
| `new-worker` | After 2 consecutive `same-worker` resume failures | Tier-escalate per fallback chain; fresh context |
| `controller-takeover` | All workers in chain exhausted OR explicit user request | Controller acts; REVIEW_REQUIRED gate |

State additions (state.md `## Active Run Capsule`):
`last_worker_session_id`, `last_worker_session_provider`,
`last_resume_strategy`, `last_resume_at`. Per-attempt
`worker_session_id`, `resume_of`, `resume_strategy` rows in
`.dtd/attempts/run-NNN.md`.

Worker registry gains optional `supports_session_resume: true|false`
(default false). `RESUME_STRATEGY_REQUIRED` capsule fires when
controller cannot pick automatically.

Same-worker resume never appends raw prior worker output, partial stream
content, or private reasoning to the next prompt. It may pass a provider
session id only for interruption-class failures; if the provider requires
message replay rather than a session id, replay only sanitized controller
prompt artifacts (`state.md`, plan, `## handoff`, attempt/log refs), not the
previous worker transcript.

#### Loop guard / doom-loop detection (v0.2.1)

After each failed attempt:

```
loop_signature = sha256(worker_id + task_id + prompt_hash + failure_hash)
```

Algorithm:
1. Compute `loop_signature` for the just-failed attempt.
2. If equal to `state.md.loop_guard_signature`: increment
   `loop_guard_signature_count`.
3. Else: set new signature; reset count to 1 and set
   `loop_guard_signature_first_seen_at: <ts>`.
4. If the first-seen timestamp is older than
   `loop_guard_signature_window_min` (default 30 min), treat the current
   failure as a new window: keep the signature, reset count to 1, and set
   `loop_guard_signature_first_seen_at: <now>`.
5. When count ≥ `loop_guard_threshold` (default 3): set
   `loop_guard_status: hit`; fill capsule
   `awaiting_user_reason: LOOP_GUARD_HIT` with options
   `[ask_user, worker_swap, controller, stop]`
   (default `ask_user`).
6. After resolve: reset signature/count/first_seen/status.

Signature stales after `loop_guard_signature_window_min` (default
30 min) — old patterns don't confuse new failures.

Loop guard scope is per-run; `finalize_run` resets to idle. Cross-run
loop detection deferred.

`decision_mode: auto` does NOT imply loop-guard auto-action. Loop guard can
skip the user prompt only when `config.md loop_guard_threshold_action` is
explicitly `worker_swap` or `controller`; the default `ask` always surfaces a
durable `LOOP_GUARD_HIT` capsule.

> Full canonical reference for worker health check (17-stage diagnostic
> with redacted evidence model): see `.dtd/reference/workers.md`
> §"Worker Health Check (v0.2.1)".
> Lazy-load via `/dtd help workers --full`.

### `/dtd plan <goal>`

Generate a new plan from a goal. Sequence:

1. If `state.md` shows existing `active_plan` with `plan_status: DRAFT`: ask user whether to discard and start fresh, or refine.
2. If `plan_status` is `RUNNING`/`PAUSED`, OR if `pending_patch: true` (any state): refuse — finish, stop, or resolve the patch first.
3. Create `.dtd/plan-NNN.md` (next number) with:
   - `<plan-status>DRAFT</plan-status>`
   - `<brief>` section (≤ 2 KB) — human-readable goal/approach summary
   - phases 1..N with tasks (XML schema below)
   - per-task `<worker>` resolved from explicit user request, role mapping, capability matching, or priority — whichever applies
   - per-task `<work-paths>` and `<output-paths>` (predicted)
4. Update `state.md`: `active_plan: NNN`, `plan_status: DRAFT`, `pending_patch: false`.
5. Display the plan via `/dtd plan show` rendering.
6. Stop. Wait for `/dtd approve` or further edits.

### `/dtd plan show [--task N|--phase N|--brief|--patches|--workers|--paths]`

Render the active plan. Uses the **same ASCII/Unicode style switch as `/dtd status`** (`config.dashboard_style`, default `ascii`). Default ASCII output:

```
+ plan-001 [<plan_status>] (+ patch pending: <impact>)
| goal: <one-line from <brief>>
+ tasks
| Task | Goal             | Worker     | Work paths       | Output paths       | Assigned via
| 1.1  | schema 작성      | qwen       | docs/,src/types/ | docs/schema.md     | role:planner
| 2.1  | API endpoints    | deepseek   | src/api/**       | src/api/**         | capability:code-write
| 4.1  | 코드 리뷰        | codex      | src/api/+src/ui/ | docs/review-001.md | role:reviewer
+ phases
| phase 1: planning  workers: qwen       touches: docs/, src/types/
| phase 2: backend   workers: deepseek   touches: src/api/**
| phase 3: review    workers: codex      reads src/api/+src/ui/  writes docs/review-001.md
```

If `dashboard_style: unicode` is set AND terminal can render box-drawing chars,
the renderer can substitute `┌`, `│`, `├`, `└` per the glyph reference in §Status Dashboard. Same fallback rule applies.

Truncate long path lists with `(+N more)`. Use first alias if `display_worker_format: alias`.

Flags select sections: `--brief` shows just the brief, `--workers` just the worker table, `--paths` just paths summary, etc.

### `/dtd plan worker <task_id|phase:N|all> <worker>`

Swap worker assignment in DRAFT only. Validation:

- Worker exists (or alias/role resolves) → else error + suggest candidates
- Capability mismatch → soft warn + confirm; if accepted, plan gets `<worker-mismatch>` annotation
- Parallel-group duplicate (same worker on `parallel-group="A"` siblings) → info + offer to break parallelism
- Tier 1 overload (single tier-1 worker on many tasks) → advisory

In APPROVED/RUNNING/PAUSED states, this command is **blocked** — use steering (medium impact patch) instead. The NL form `"task 3은 큐엔으로"` routes through `/dtd steer` automatically when not DRAFT.

After swap, `<worker-resolved-from>` is updated to `user-override (was: <previous>)`.

### `/dtd approve`

DRAFT → APPROVED. Validations:

- `plan_status` must be DRAFT
- Plan size: `plan-NNN.md` ≤ 24 KB hard cap (≤ 12 KB preferred — warn if over)
- All tasks have a resolved `<worker>` (no unresolved role/alias)
- All workers in plan exist in `workers.md`
- No path overlap warnings unaddressed

After approve, plan is locked in: further changes require steering.

### `/dtd run [--until <boundary>] [--decision plan|permission|auto] [--silent[=<duration>] | --interactive]`

Execute the plan. Allowed when `plan_status` is `APPROVED` (start)
or `PAUSED` (resume) AND `pending_patch: false`; else refused.

`--until <boundary>` enables bounded execution:
- `phase:<id>` — pause after that phase completes
- `task:<id>` — pause after that task completes
- `before:<phase|task>` — pause before that phase/task
- `next-decision` — pause when any decision capsule fires

`--decision`/`--silent`/`--interactive` set per-run autonomy and
attention modes (see autonomy reference).

> Full canonical reference: see `.dtd/reference/run-loop.md`
> (boundary semantics, run loop step overview 6.a-j, NL routing
> table, durable last_pause_* fields, finalize_run lifecycle).
> Lazy-load via `/dtd help run-loop --full`.

### Autonomy & Attention Modes (v0.2.0f)

> **v0.2.3 R1 extraction**: full canonical spec for this section moved to
> `.dtd/reference/autonomy.md`. Lazy-loaded via `/dtd help autonomy --full`.
> The summary below documents what the topic covers; see the reference file
> for the algorithms, capsule body, and trigger tables.

This is a core DTD UX surface. It lets a user either collaborate live or leave
DTD running overnight without turning every blocker into an immediate stop.

Three independent axes:

| Axis | Values | Meaning |
|---|---|---|
| `host.mode` | `plan-only` / `assisted` / `full` | Apply authority |
| `decision_mode` | `plan` / `permission` / `auto` | Ask cadence |
| `attention_mode` | `interactive` / `silent` | Now vs defer |

Commands: `/dtd run --silent=<duration>`, `/dtd run --decision <mode>`,
`/dtd silent on/off`, `/dtd interactive`, `/dtd mode decision <mode>`.

Silent-mode "ready work" algorithm: defer unsafe blockers (AUTH_FAILED,
DISK_FULL, paid fallback, destructive options, etc.) into
`deferred_decision_refs`; continue independent ready tasks.
`silent_deferred_decision_limit: 20` hard cap. **No auto-flip** to
interactive on any trigger (limit hit, window expired,
`CONTROLLER_TOKEN_EXHAUSTED`).

Decision capsule for `CONTROLLER_TOKEN_EXHAUSTED`: options
`[wait_reset, switch_host_model, compact_and_resume, stop]`,
default `wait_reset`. Preserves attention state when fired in silent.

For full algorithm, defer trigger table, capsule body, host.mode
interaction, and silent_blocker_policy alternatives, see
`.dtd/reference/autonomy.md`.

**Pre-run checks** (before entering the run loop):

- If `host_mode` is `assisted` or `full` AND `.dtd/PROJECT.md` is TODO-only (no real project context filled in): WARN user "PROJECT.md is empty — workers will receive generic context. Continue anyway? (y/n)". Same check as `/dtd doctor` #11, but at run time.
- Verify `.dtd/notepad.md` exists (template state OK).
- Verify `.dtd/attempts/` directory exists (create if not).

Run loop (per task):

1. Read `state.md` — check `pause_requested`. If true, mark `plan_status: PAUSED`, exit.
2. Read `steering.md` cursor — apply any new low-impact entries to upcoming worker prompts.
3. Check `pending_patch`. If true: refuse to dispatch new task; await approve/reject.
4. Pick next ready batch by topo order (respect `depends-on` and `parallel-group`).
5. **Pre-dispatch lock partitioning** (FIX P1-3 — happens BEFORE any dispatch):
   a. For every task in the candidate parallel batch, resolve `<worker>` and compute its lock set from `<output-paths>` + `<resources>`.
   b. Build the parallel batch's combined lock graph. Apply overlap matrix (see §Resource Locks).
   c. If two siblings' lock sets conflict (e.g., both write `src/api/**`): split the batch into non-conflicting sub-batches (one task per conflict cluster). Or, if the user requested strict parallelism, ask user to break parallel-group manually.
   d. Acquire all leases for the first non-conflicting sub-batch atomically (each lease appended to `resources.md`).
   e. Only then dispatch this sub-batch in parallel.
   f. Wait for all sub-batch members to finish; release their leases; advance to the next sub-batch.
6. For each dispatched task (within a sub-batch):
   a. Build worker prompt in this canonical order (same as `instructions.md` §Token Economy #2):
      ```
      1. worker-system.md             (static, cacheable)
      2. PROJECT.md                   (rarely changes, cacheable)
      3. notepad.md <handoff> only    (dynamic, REWRITTEN before each dispatch, NOT cached)
      4. skills/<capability>.md       (per capability, cacheable)
      5. task-specific section        (varies, not cached; includes compact
         persona/reasoning/tool-runtime controls when configured)
      ```
      Notepad `<handoff>` is dynamic by design; do not mark it for cache.
      **Worker context reset contract (GSD-style)**:
      - Resolve `context-pattern` (`fresh` | `explore` | `debug`) before prompt
        assembly and write the resolved values to `state.md`.
      - Resolve `persona`, `reasoning-utility`, and `tool-runtime` before
        prompt assembly. Inject only compact control capsules in the
        task-specific section; never store or request raw chain-of-thought.
      - Every worker dispatch starts from a fresh worker context by default:
        first attempt, retry, phase boundary, and worker switch do not reuse
        provider chat/session history. In DTD, one worker dispatch is the GSD
        execution-unit equivalent.
      - What resets: worker prompt transcript, raw previous response, tool
        output, failed-attempt chatter, and provider session state.
      - What survives: accepted file changes, controller-distilled notepad
        facts, attempt/log refs, phase history, incidents, and state
        checkpoints.
      - Resume/retry rehydrates from durable artifacts (`state.md`, plan,
        notepad `<handoff>`, attempts/log refs), not from a previous chat
        transcript.
      - Retry prompts include only a compact retry hint: failure reason,
        attempt/log id, changed constraints, and relevant distilled learnings.
        Do not paste raw failed output into the next worker prompt.
      - Before each dispatch, rewrite `<handoff>` from durable state. Workers
        see only the curated summary, not the previous worker conversation.
   b. **Context budget gate** (mandatory pre-dispatch — required, not optional):
      - Estimate input tokens (full prompt) + reserved output budget against the worker's `max_context`.
      - If estimate ≥ worker's `soft_context_limit` (default 70%) AND this is NOT a final/closing response: **checkpoint, close current phase, split task into smaller sub-tasks, do NOT dispatch the oversized task as-is**. Append `phase-history.md` row noting `note: phase split on soft cap`.
      - If estimate ≥ `hard_context_limit` (default 85%): refuse dispatch, require split.
      - If estimate ≥ `emergency_context_limit` (default 95%): emergency checkpoint. Fill the **decision capsule** (per state.md schema): `awaiting_user_decision: true`, `awaiting_user_reason: CONTEXT_EXHAUSTED`, `decision_id: dec-NNN`, `decision_prompt: "Worker context near limit. How should DTD proceed?"`, `decision_options: [{id:checkpoint, label:"checkpoint and stop", effect:"finalize_run(STOPPED)", risk:"manual resume needed"}, {id:split_phase, label:"split phase and continue", effect:"split task, lower budget", risk:"may produce smaller deliverable"}, {id:wait_compact, label:"compact notepad and retry", effect:"shrink prompt prefix", risk:"loses some history"}]`, `decision_default: checkpoint`, `decision_resume_action: "after user choice, controller acts on the option's effect"`. `/dtd status` displays the prompt + options + default.
      - Record estimate, decision, and split reason to `.dtd/log/exec-NNN-task-N-ctx.md` and `phase-history.md`.
      - Worker's `::ctx::` self-report (if any) is advisory; controller's calculation is authoritative.
   c. Dispatch (mode-dependent — see Modes section).
   d. Heartbeat lease at `heartbeat_interval_sec` (default 30s) for long tasks. **Best-effort in plan-only / blocking-shell hosts** — stale takeover is the safety boundary.
   e. Receive worker response. Parse `::ctx::` (optional, before summary) and `::done::` / `::blocked::` (mandatory last line); extract `===FILE: <path>===` blocks. **Redact secrets in worker response before saving to log.**
   f. **Validate before apply** (gating step — required before any file write):
      - Each `===FILE: <path>===` path must:
        1. fall within the worker's `permission_profile` write scope (see §Worker Permission Profiles in `instructions.md`)
        2. fall within the task's declared `<output-paths>` (or be a subset thereof)
        3. fall within currently held lock set
        4. NOT match `path-policy.block_patterns`
      - If any path fails any check: do NOT apply ANYTHING from this response. Mark attempt `blocked` with reason `output_path_out_of_scope`. Append to `.dtd/attempts/run-NNN.md`. Trigger escalation per ladder.
      - All paths pass → proceed to step g.
   g. Apply file changes (mode `assisted` may confirm; mode `full` auto-applies). **Use temp-file + atomic rename** for safety, in two phases:

      **Phase 1 — write all temp files**: for each output file, write `<path>.dtd-tmp.<pid>` (contents from worker response). If ANY temp write fails (e.g., `DISK_FULL` during write of file 2 of 3): abort phase 1 immediately, **delete any temp files already written in this attempt** (no rename has happened yet so no final file is changed), fill `DISK_FULL` (or appropriate write-failure reason) capsule. **No final files modified — clean abort.**

      **Phase 2 — rename all temps to final**: after all temps written successfully, rename them to final paths. If a rename fails partway (rare — e.g., file 2 locked by AV, file 3 path disappeared): some final files were renamed (applied), others still as `.dtd-tmp.*`. This is `PARTIAL_APPLY`. Fill capsule with explicit applied/pending lists. **Automatic resume forbidden** — user picks inspect / revert_partial / accept_partial / stop.

      **Local apply failure paths** (each is blocking — fill decision capsule, do NOT silently fail):

      | Condition | Reason enum | Options |
      |---|---|---|
      | Out of disk space | `DISK_FULL` | `[free_space_retry, skip_file, stop]`, default `free_space_retry` |
      | Filesystem permission denied | `FS_PERMISSION_DENIED` | `[fix_permissions_retry, skip_file, stop]`, default `fix_permissions_retry` |
      | File locked by another process (Windows AV, IDE) | `FILE_LOCKED` | `[wait_retry, force_overwrite, skip_file, stop]`, default `wait_retry` |
      | Path disappeared between validate and write | `PATH_GONE` | `[recreate_dir_retry, skip_file, stop]`, default `recreate_dir_retry` |
      | Some files in response wrote OK but later ones failed | `PARTIAL_APPLY` | `[inspect, revert_partial, accept_partial, stop]`, default `inspect`. Lists exactly which files were applied vs not. **Automatic resume forbidden** — user must choose. |
      | Other write error | `UNKNOWN_APPLY_FAILURE` | `[retry, inspect, stop]`, default `inspect` |

      On any of the above:
      - Mark attempt `blocked` (NOT failed — failed implies retry-able by tier ladder, but apply failures need user input).
      - Fill decision capsule per template above.
      - Save sanitized error summary to `.dtd/log/exec-<run>-task-<id>.<worker>.md`.
      - Lease is held (NOT released) until user resolves — safer to keep lock during ambiguous state.
      - `/dtd status` shows `awaiting decision: <reason>`.
      - When user picks an option, controller acts per `effect`. `revert_partial` deletes any files that were written in this attempt (using temp-file rename audit trail).

      For `PARTIAL_APPLY` specifically: the controller logs which files made it (atomic rename succeeded) and which didn't (still `.dtd-tmp.*`), and presents the list to the user. The user can `inspect` (view diffs), `revert_partial` (undo the applied ones), `accept_partial` (treat applied subset as the result, mark task partial-grade), or `stop`.
   h. Update `<output-paths actual="true">` with actual files written.
   i. Release lease.
   j. Compute grade (controller-side, never worker self-grade): worker output vs target_grade. Update task status.
   k. If grade < target_grade: failure counter `++`, escalate per ladder if threshold hit.
   l. If grade ≥ target_grade: counter reset, advance.
   m. Append phase row to `phase-history.md` on phase boundary.
   n. Compact completed tasks in `plan-NNN.md` (1-line form).
   o. Update `state.md` (current_task, progress, counters). Update `notepad.md` with any new learnings/decisions/issues from this task (see §Per-Run Notepad).
   p. Apply patches in `<patches>` section ONLY between tasks (after step o completes), never during step c/d/e.

7. After all phases pass: call `finalize_run(COMPLETED)` (defined below). 

If `WORK_START` not yet emitted for this run, emit it on first dispatch (or on `/dtd run` from APPROVED).

### `finalize_run(terminal_status)` — shared terminal lifecycle

Required by ALL terminal exits: COMPLETED, STOPPED, FAILED.
NOT called for PAUSED (pause is non-terminal).

Atomic order (7 steps): release leases → archive notepad → reset
notepad → write run summary → clear incident state (v0.2.0a) +
attention/context-pattern state (v0.2.0f) → append AIMemory
WORK_END → update state.md atomically.

> Full canonical reference: see `.dtd/reference/run-loop.md`
> (per-step body, incident-state clear rules, deferred decision
> handling, decision_mode_set_by retention semantics,
> ORPHAN_RUN_NOTE recovery).
> Lazy-load via `/dtd help run-loop --full`.

### `/dtd pause`

RUNNING → PAUSED on next task boundary. Sets `state.md` `pause_requested: true`. The currently in-flight task (if any) finishes; controller does not dispatch the next one. **NOT terminal — does NOT call `finalize_run`.**

### `/dtd stop`

Force-end the active plan. Allowed from `RUNNING` / `PAUSED`, OR any state with `pending_patch: true`.
Calls `finalize_run(STOPPED)`. Active leases released, `pending_patch` cleared, `patch_status` set to `rejected` if was proposed.
The plan file is preserved (audit). New plans start fresh with `/dtd plan`.

### `/dtd steer <instruction>`

Append a steering directive. Sequence:

1. Append entry to `steering.md` (raw user phrase + controller's interpretation).
2. Classify impact: `low | medium | high`.
3. **low**: prefix to upcoming worker prompts; no patch, no confirm.
4. **medium / high**: create patch in plan-NNN.md `<patches>` section. Set `state.md` `pending_patch: true`, `patch_impact: <medium|high>`, `patch_status: proposed`.
5. If RUNNING: in-flight task continues, no new dispatch until patch resolved.
6. Display patch + ask: `approve | reject`.
7. On `approve`: apply patch to plan body, `pending_patch: false`, `patch_status: approved`. Resume per `plan_status`.
8. On `reject`: discard patch, `pending_patch: false`, `patch_status: rejected`. Steering entry preserved in `steering.md` for context. Resume per `plan_status`.

Patch application **only between tasks or after in-flight task completes**. Never mutate a worker call mid-flight.

### `/dtd silent on [--for <duration>] [--goal "<text>"]` (v0.2.0f)

Enter silent attention mode. Defers safe-to-defer blockers and continues
independent ready work without interrupting the user. See §Autonomy &
Attention Modes for full behavior.

```
/dtd silent on                    # use config silent_default_hours (default 4)
/dtd silent on --for 2h           # explicit duration
/dtd silent on --for 6h --goal "프론트 마무리하고 자러갈게"
```

Effects:
1. Validate duration ≤ `config.attention.silent_max_hours` (default 8). Reject
   if larger; tell user to split into multiple silent windows.
2. Set `state.md`:
   - `attention_mode: silent`
   - `attention_mode_set_by: user`
   - `attention_until: <now + duration>`
   - `attention_goal: "<text or null>"`
   - `deferred_decision_count: 0`
   - `deferred_decision_refs: []` (cleared at silent-window start)
3. Append a one-line entry to `steering.md` recording the entry: `silent_on by user, until <ts>, goal=<text>`.
4. If a run is RUNNING, the silent policy applies at the next decision point
   (does NOT interrupt the in-flight task).
5. Append AIMemory `NOTE` event: `silent on, until=<ts>, goal=<text>` (per
   §AIMemory Boundary — durable steering decision counts as a NOTE-worthy event).
6. Print compact confirmation:
   ```
   → silent on (until 2026-05-05 08:00, "<goal>"). 잠자리 잘 다녀와.
     deferred_blocker_limit=20  silent_max_hours=8
     blockers will accumulate; surfaced when you switch back to interactive.
   ```

`/dtd silent on` is **not destructive**, but it changes how blockers surface.
Confirm in NL only when goal is empty AND `decision_mode` is currently `plan`
(plan-mode users prefer explicit confirmation).

### `/dtd silent off` (v0.2.0f)

Equivalent to `/dtd interactive`. Shorthand kept for symmetry with `silent on`.

### `/dtd interactive` (v0.2.0f)

Exit silent attention mode. Surfaces deferred blockers in age order (oldest first).

Effects:
1. Set `state.md`:
   - `attention_mode: interactive`
   - `attention_mode_set_by: user`
   - `attention_until: null`
   - `attention_goal: null`
2. If `deferred_decision_refs` is non-empty:
   - Pick the **oldest** (first in list) deferred ref.
   - Re-fill the decision capsule from that incident/attempt's recovery options
     (per `awaiting_user_reason` and `decision_options` snapshot stored with
     the deferred ref).
   - Show the morning summary (see §Morning summary format below).
   - Subsequent deferred refs are surfaced one-at-a-time as the user resolves
     each capsule.
3. If `deferred_decision_refs` is empty:
   - No capsule to fill.
   - Print compact confirmation:
     ```
     → interactive. no deferred blockers. resume with /dtd run.
     ```
4. Append a one-line entry to `steering.md`: `interactive by user, deferred_count=<N>`.
5. Append AIMemory `NOTE` event: `interactive, deferred=<N>`.

`/dtd interactive` does NOT auto-resolve any deferred decision; the user still
chooses recovery options for each surfaced capsule.

### `/dtd mode decision <plan|permission|auto>` (v0.2.0f)

Set the decision-frequency mode. Orthogonal to host.mode (apply authority) and
attention_mode (ask now vs defer).

```
/dtd mode decision plan
/dtd mode decision permission
/dtd mode decision auto
```

Effects:
1. Validate value against the enum.
2. Set `state.md`:
   - `decision_mode: <new>`
   - `decision_mode_set_by: user`
3. Print compact confirmation:
   ```
   → decision_mode = auto.  destructive/paid/external-path 는 여전히 confirm.
   ```

Behavior change applies to **future** decisions only. It does NOT auto-resolve
existing capsules or queued deferred blockers. Switching from `auto` to `plan`
does not retroactively roll back already-made auto decisions.

If the user is currently in silent + auto and switches to plan + interactive,
the controller surfaces deferred blockers per `/dtd interactive` semantics
above; the new decision_mode applies to any subsequent decision points.

### Morning summary format (v0.2.0f)

When `/dtd interactive` exits silent, the user sees:

```
+ DTD silent window ended — 4h12m elapsed
+ progress
| completed   3 tasks                                            ✓
| deferred    2 blockers                                         !
| skipped     1 task (dependency on deferred)                    -
+ deferred decisions
| dec-007  AUTH_FAILED       deepseek-local  task 2.1   3h05m old
| dec-009  PAID_FALLBACK     gpt-codex       task 3.1   1h22m old
+ ready work
| -> 4.1 docs review        [qwen-remote]    docs/review-001.md
+ next
| /dtd incident show inc-001-0007    inspect first deferred
| /dtd run                            continue ready work after deciding
```

Rules:
- Each line ≤ 80 chars (dashboard_width policy).
- Deferred decisions ordered oldest-first.
- Goal text from `attention_goal` is shown above progress if non-null.
- `silent_window_ended` reason set in `state.md`:
  - `last_pause_reason: silent_window_ended`
  - `last_pause_at: <ts>`
- `attention_mode: interactive` (atomic with the morning summary print).
- AIMemory `NOTE`: `silent_window_ended, completed=<N> deferred=<M> skipped=<K>`.

When `attention_until` expires while the user is away, the controller pauses at
the next safe boundary with `last_pause_reason: silent_window_expired` and
preserves `attention_mode: silent`. `/dtd status` may render a compact summary
from durable state, but it is observational and does not flip the mode. The
user runs `/dtd interactive` to enter the full morning-summary path and surface
deferred capsules.

If silent window ends with NO deferred blockers and ALL ready work is done,
the dashboard collapses to one line:

```
+ DTD silent run complete — 4h12m, 3 tasks done, no deferred. Run /dtd status.
```

### `/dtd incident list [--all|--blocking|--recent]` (v0.2.0a)

Show incidents. Default = last 10 unresolved. Output is compact ASCII table per `dashboard_style`:

```
+ DTD incidents (run 001)
| ID                  | severity | reason            | task | resolved |
| inc-001-0001        | blocked  | NETWORK_UNREACHABLE | 2.1  | no       |
| inc-001-0002        | warn     | MALFORMED_RESPONSE | 2.2  | no       |
| inc-001-0003        | info     | RATE_LIMIT (1st)   | 3.1  | no       |
+ next: /dtd incident show <id>
```

Flags:

- `--all` — include resolved incidents too
- `--blocking` — only severity=blocked|fatal
- `--recent` — last 24h regardless of resolution

Classified as `observational_read` per `instructions.md` §Status read isolation — does NOT mutate notepad/steering/attempts/phase-history.

### `/dtd incident show <id>` (v0.2.0a)

Renders the full incident detail file. Shows reason / phase / worker / task / recoverability / side effects / cross-linked attempt / recovery options / sanitized error summary / timeline.

Also `observational_read` — no state mutation.

### `/dtd incident resolve <id> <option>` (v0.2.0a)

Resolve an open incident with a chosen recovery option.

```
/dtd incident resolve inc-001-0001 retry
/dtd incident resolve inc-001-0001 switch_worker
/dtd incident resolve inc-001-0001 stop
```

Option must be one from the incident's `recovery_options` (matches the decision capsule's `decision_options` for blocking incidents).

Effect: per Incident Tracking §Resolve logic — clears state fields, promotes next blocker if queued, triggers chosen option's `effect`.

#### Destructive option confirmation (R2 fix — P1 from R1 review)

Any incident recovery `<option>` whose effect class is one of:

- `stop` — finalize_run(STOPPED) on the active run
- `purge` — delete state and incident files (rare; future v0.2.x)
- `delete` — drop a worker, plan, or queue entry
- `force_overwrite` — bypass a path policy or lock
- `revert_partial` — undo a partial apply
- `terminal_finalize` — any other path leading to `finalize_run`

inherits the global **destructive confirmation rule** (per `instructions.md`
§Don't Do These / §Confidence & Confirmation): the controller MUST require
an explicit user confirmation phrase BEFORE executing, regardless of intent
confidence. NL routing for these options is mapped via `incident resolve <id>
<option>` but flagged destructive — see `instructions.md` NL row for
"그 에러 멈춰" / "incident <id> stop". Slash-form `/dtd incident resolve
<id> stop` also confirms before acting.

Recovery options NOT in the destructive set (e.g. `retry`, `switch_worker`,
`wait_once`, `manual_paste`) follow normal confidence rules — no extra
confirmation required.

NL routing in `instructions.md`:

| User phrase | Canonical |
|---|---|
| "그 에러 다시 보여줘", "지금 막힌 거 뭐야", "incident 보여줘" | `incident list` or `incident show <active>` |
| "incident 4 처리해", "재시도로 가자", "그 에러 retry" | `incident resolve <id> <option>` |
| "어디서 막혔어?" | `incident show <active_blocking_incident_id>` |

### `/dtd status [--compact|--full|--plan|--history|--eval]`

Always allowed regardless of state. Renders dashboard (see Status Dashboard section).

### `/dtd perf [--phase <id>|--worker <id>|--since <run>|--tokens|--cost]` (v0.2.0f)

> **v0.2.3 R1 extraction**: full canonical spec for this section moved to
> `.dtd/reference/perf.md`. Lazy-loaded via `/dtd help perf --full`.
> The summary below documents what the topic covers; see the reference file
> for output format, controller usage ledger schema, ctx file YAML schema,
> and the output flag matrix.

On-demand performance/token report. **Observational** — not shown in default
status unless the user asks.

Data sources (priority order for controller totals):
1. `.dtd/log/controller-usage-run-NNN.md` — authoritative ledger of
   mutating controller turns (plan/run_loop/dispatch_prepare/steer/
   decision_resolve/finalize). Append-only; observational reads do NOT append.
2. `.dtd/log/exec-<run>-task-<id>-att-<n>-ctx.md` — per-dispatch ctx files
   (worker tokens from provider `usage` block + controller estimate fallback).
3. `.dtd/attempts/run-NNN.md` + `.dtd/phase-history.md` for mapping +
   timings.
4. `.dtd/workers.md` optional pricing metadata for `--cost`.

Output is split into separate **controller**, **implementation workers**,
**test workers**, **verifiers/scorekeepers**, and **worker detail** sections
when role metadata is available. Controller and delegated-worker totals MUST
remain separate. Benchmark reports may add a derived `total_system_tokens`
rollup, but it must never replace the role columns or be described as
controller context usage. No double-counting between ledger and ctx-file
controller estimate fields.

For full output sample, ledger schema (9-column markdown table with `kind`
enum), ctx file YAML front matter (run/task/worker/attempt/phase/
context_pattern/sampling/worker_role/provider_thinking/elapsed_ms/
controller_*tokens/worker_*tokens/reasoning-token flags/cost_usd/
http_status), and output flag matrix, see `.dtd/reference/perf.md`.

---

## Plan State Machine

7 `plan_status` values + 1 orthogonal `pending_patch` flag.

```
              /dtd plan
                 │
                 ▼
            ┌─────────┐
            │  DRAFT  │ ◀── /dtd plan worker, /dtd plan, manual edit
            └────┬────┘
                 │ /dtd approve
                 ▼
           ┌──────────┐
           │ APPROVED │
           └────┬─────┘
                │ /dtd run
                ▼
            ┌─────────┐
   ┌───────▶│ RUNNING │────(all phases pass)────▶ ┌───────────┐
   │        └────┬────┘                            │ COMPLETED │
   │             │ /dtd pause                      └───────────┘
   │             ▼
   │ /dtd run  ┌────────┐
   └───────────│ PAUSED │
               └───┬────┘
                   │ /dtd stop
                   ▼              ┌────────┐
              ┌─────────┐         │ FAILED │ ◀── all workers down / unrecoverable
              │ STOPPED │         └────────┘
              └─────────┘
```

`pending_patch` flag is **orthogonal** — can be true in APPROVED, RUNNING, PAUSED. State examples:

- `RUNNING + pending_patch=true`: in-flight task completes; no new dispatch until patch resolved
- `APPROVED + pending_patch=true`: cannot run until patch resolved
- `PAUSED + pending_patch=true`: resume blocked until patch resolved

Cannot be true in DRAFT (use direct edit), STOPPED, COMPLETED, FAILED.

### State × Action Matrix

| state \ action            | plan        | approve     | run         | pause       | stop        | steer (med/high) | approve patch | reject patch | plan worker  |
|---------------------------|-------------|-------------|-------------|-------------|-------------|------------------|---------------|--------------|--------------|
| DRAFT                     | overwrite?  | ✓ → APPROVED| ✗           | ✗           | ✓           | direct edit      | n/a           | n/a          | ✓            |
| APPROVED, no patch        | ✗ (stop?)   | ✗           | ✓ → RUNNING | ✗           | ✓           | → set patch      | n/a           | n/a          | ✗ (use steer)|
| APPROVED, patch           | ✗           | ✗           | ✗           | ✗           | ✓           | accumulate       | ✓             | ✓            | ✗            |
| RUNNING, no patch         | ✗           | ✗           | n/a         | ✓           | ✓           | → set patch      | n/a           | n/a          | ✗            |
| RUNNING, patch            | ✗           | ✗           | n/a         | ✓           | ✓           | accumulate       | ✓ (apply when next task boundary) | ✓ | ✗ |
| PAUSED, no patch          | ✗           | ✗           | ✓ → RUNNING | n/a         | ✓           | → set patch      | n/a           | n/a          | ✗            |
| PAUSED, patch             | ✗           | ✗           | ✗           | n/a         | ✓           | accumulate       | ✓             | ✓            | ✗            |
| COMPLETED / STOPPED / FAILED | ✓ (new)  | ✗           | ✗           | ✗           | ✗           | ✗                | n/a           | n/a          | ✗            |

`✗` = blocked with reason. `✓` = proceed. `n/a` = not applicable.

---

## Worker Registry & Routing

Worker registry: `.dtd/workers.md` (gitignored; per-user). Schema
reference: `.dtd/workers.example.md` (committed).

Routing precedence (no explicit `<worker>`):
1. Task `<worker>X</worker>` → manual override.
2. Task `<capability>Y</capability>` → filter+sort
   (priority desc, free first, tier asc).
3. No hint → `config.md roles.primary`.
4. All fail → controller asks user.

NL alias resolution: exact `worker_id` → exact `alias` → exact `role` →
capability fuzzy → ambiguous (confirm).

> Full canonical reference: see `.dtd/reference/workers.md`
> (registry schema, routing rules, output discipline, full HTTP
> dispatch transport with request/response/error/fallback contract).
> Lazy-load via `/dtd help workers --full`.

---

## Plan Schema (XML)

Plans live at `.dtd/plans/plan-NNN.md`. Top-level XML:
`<plan-status>` + `<brief>` + `<phases>` (with `<task>` rows
containing `<worker>`, `<capability>`, `<work-paths>`,
`<output-paths>`, `<context-files>`, `<resources>`, `<done>`) +
`<patches>`.

Completed tasks compact to one-line form. v0.2.0f adds optional
`context-pattern`/`persona`/`reasoning-utility`/`tool-runtime`
attributes on `<phase>` or `<task>`.

Size budget:
- `plan-NNN.md` preferred ≤ 12 KB; hard cap 24 KB.
- `<patches>`: ≤ 5 patches AND ≤ 4 KB inline; exceed → spill to
  `plan-NNN-patches.md`.
- `<brief>` ≤ 2 KB.

> Full canonical reference: see `.dtd/reference/plan-schema.md`
> (full XML example, compaction rule, v0.2.0f attribute spec,
> patches spill policy).
> Lazy-load via `/dtd help plan-schema --full`.

---

## Context Patterns (v0.2.0f)

DTD supports three GSD-inspired context patterns. The controller chooses one
for each phase/task during planning, and the user can override it in natural
language before approval.

**Feature gating**: ships in v0.2.0f. Plans authored before v0.2.0f have no
`context-pattern` attribute; the controller resolves them via capability
defaults from `.dtd/config.md` `context-pattern.capability_context_defaults`.
The plan XML schema `context-pattern` attribute is optional and back-compat.

| Pattern | Default use | Behavior |
|---|---|---|
| `fresh` | code-write, refactor, review, verification | Fresh worker context, standard `<handoff>`, deterministic single sample. This is the default. |
| `explore` | planning, research, UX, architecture | Fresh context per candidate, richer handoff, two samples, reviewer/convergence gate before apply. |
| `debug` | retry, stuck task, incident, reproducible bug | Fresh retry context, failure-focused handoff, compact attempt/log refs, low creativity. |

Plan XML may include:

```xml
<phase id="1" name="architecture" context-pattern="explore">
  <task id="1.1" context-pattern="fresh">
    ...
  </task>
</phase>
```

Planning rules:

- If omitted, controller resolves by capability from `.dtd/config.md`.
- `fresh` is conservative and should be chosen for anything that writes final
  code unless the phase is explicitly ideation/planning.
- `explore` produces alternatives; only the converged result can reach apply.
- `debug` is selected automatically on retry paths, incidents, and loop-guard
  recovery even if the original task was `fresh` or `explore`.
- `/dtd plan show --full` and `/dtd status --full` display the resolved pattern.

Natural-language steering examples:

| User phrase | Effect |
|---|---|
| "이번 설계 페이즈는 탐색적으로 해" | set phase `context-pattern="explore"` |
| "구현은 안정적으로 fresh로 가자" | set implementation phase/task `fresh` |
| "이 에러는 디버그 패턴으로 다시 돌려" | retry current task with `debug` |

---

## Persona, Reasoning, and Tool-Use Patterns (v0.2.0f Codex R0 addendum)

> **v0.2.3 R1 extraction**: full canonical spec for this section moved to
> `.dtd/reference/persona-reasoning-tools.md`. Lazy-loaded via
> `/dtd help persona-reasoning-tools --full`. The summary below documents
> what the topic covers; see the reference file for the full pattern set,
> resolution rules, prompt-injection contract, and tool-runtime contracts.

These controls sit beside `context-pattern`. Selected by the controller
during planning and resolved before each worker dispatch. Short
behavioral stances + execution utilities, not long role-play prompts.

Three pattern surfaces:

- **Personas** (7): `operator`, `planner`, `researcher`, `implementer`,
  `debugger`, `reviewer`, `release_guard`. Compact stance ≤120 words;
  NEVER overrides security/permission/destructive rules.
- **Reasoning utilities** (7): `direct`, `least_to_most`, `react`,
  `tool_critic`, `self_refine`, `tree_search`, `reflexion`. The model may
  reason privately, but DTD never asks for, stores, or forwards raw
  chain-of-thought; persist ONLY decision/evidence_refs/risks/next_action +
  ≤5 line summary.
- **Provider thinking levels**: transport hints such as DeepSeek thinking
  level or OpenAI reasoning effort. Apply only when the provider/host
  explicitly supports them. Defaults: controller `low`, scorekeeper `max`,
  file-output/test-program workers `disabled`. Unsupported providers omit the
  field. Empty `content` plus hidden reasoning is a worker output failure,
  never a partial success.
- **Tool runtime** (4 modes): `none`, `controller_relay` (default),
  `worker_native`, `hybrid`. controller_relay: worker emits
  `::tool_request::`, controller validates + runs + logs sanitized
  output; mutating writes still go through `===FILE: <path>===`
  pipeline. worker_native requires registry `tool_runtime: worker_native|
  hybrid` + `native_tool_sandbox: true`.

Plan XML optional attributes on `<phase>` / `<task>`: `persona`,
`reasoning-utility`, `tool-runtime`. Resolution: task → phase →
capability default → context-pattern default → global default.

For full pattern tables (controller/worker stances, capability
defaults, mode descriptions), prompt-injection rules, output
contracts, and the controller-relay / worker-native contracts, see
`.dtd/reference/persona-reasoning-tools.md`.

---

## Tier Escalation

### Counters (in `state.md`)

```markdown
- failure_counts:
    - { worker: deepseek-local, task: 2.1, count: 2, reason_hashes: [a3f1b9, a3f1b9] }
    - { worker: deepseek-local, task: 2.2, count: 0 }
- failure_count_phase: 2
- last_failure_reason: "test failed: assertEquals expected 5 got 3"
```

### Trigger

Worker W escalates on task T when **W's count for T ≥ W.failure_threshold** (or `config.default_failure_threshold`, default 3).

Phase counter is dashboard-only by default. Set `config.md` `escalate_on_phase_failures: <N>` to enable phase-level trigger.

### Reset

- Task T succeeds → (W, T) count = 0, hashes = []
- Task T reassigned to W' → (W, T) preserved (history); (W', T) starts at 0
- User-accept (run failure as-is) → all counters for T reset

### `failure_reason_hash` (acceleration, not replacement)

Worker `::blocked:: <reason>` reason → normalized (lowercase, stopwords stripped) → hashed. Same hash twice = "stuck on same blocker" — **shortcut to next escalation step**. Threshold-based escalation remains the default; hash matching only accelerates.

### 5-Step Escalation Ladder

1. **Focused retry** — same worker, same task, with explicit hint about prior failure (1-2 retries within `failure_threshold`).
2. **Tier escalation** — follow `escalate_to` chain to next worker.
3. **Add reviewer worker** — inject reviewer's analysis as hint to the original/next worker.
4. **Controller intervention** — controller handles directly (must be classified as `small_direct_fix` or `artifact_authoring` per Controller Categories below; `REVIEW_REQUIRED` gate applies).
5. **User escalation** — `escalate_to: user` is terminal. Fill decision capsule: `awaiting_user_decision: true`, `awaiting_user_reason: ESCALATION_TERMINAL`, `decision_id: dec-NNN`, `decision_prompt: "Worker chain exhausted on task <id>. How to proceed?"`, `decision_options: [{id:accept, label:"accept current", effect:"keep current grade, advance"}, {id:rework, label:"rework", effect:"reset counters, retry from current step"}, {id:abandon, label:"abandon", effect:"finalize_run(STOPPED)"}]`, `decision_default: rework`. `/dtd status` displays the prompt + options.

---

## Resource Locks

7-step lifecycle, executed by controller around each task dispatch.

1. **Normalize paths**: relative → `project:<path>`, absolute → `global:<path>`. Glob preserved as-is for matching.
2. **Compute lock set**: union of `<output-paths>` (write mode) + explicit `<resources>` entries.
3. **Check overlap**: scan `resources.md` active leases. Apply overlap matrix:

   | existing \ new | read | write | exclusive |
   |---|---|---|---|
   | read | OK | block | block |
   | write | block | block | block |
   | exclusive | block | block | block |

   Path overlap: literal⊆literal exact match; literal⊆glob via pattern match; glob⊆glob via specialization (conservative — `src/api/**` ⊆ `src/**`).

4. **Acquire lease**: append entry to `resources.md`. Canonical resource string format: `<type>:<namespace>:<path>` (v0.1 type is always `files`).

   ```markdown
   ## lease-<id>
   - worker: <worker_id>
   - task: <task_id>
   - mode: write
   - paths:
       - files:project:src/api/**
       - files:global:/tmp/build/
   - acquired_at: <ts>
   - heartbeat_at: <ts>
   - run_id: <run_id>
   ```

5. **Heartbeat**: every `heartbeat_interval_sec` (default 30) during long tasks, controller updates `heartbeat_at`. **In prompt-only / blocking-shell hosts, heartbeat is best-effort** — stale takeover is the safety boundary.
6. **Release**: on success/failure/blocked, remove lease entry from `resources.md`.
7. **Stale takeover**: if `heartbeat_at` older than `stale_threshold` (default 5 min), DO NOT auto-takeover. Ask user explicitly. Log `NOTE` event in `AIMemory/work.log` (if present) on takeover.

`global:` namespace locks (absolute paths) are **best-effort only** — coordination across DTD instances or external tools not guaranteed. Confirm with user before acquiring.

---

## Path Notation

Inside project root → **relative** (`src/api/users.ts`, `src/api/**`).
Outside project root → **absolute** (`/tmp/build/`, `~/.cache/`, `C:\Users\...`).

Auto-detect: leading `/`, `<drive>:\`, or `~/` → absolute. Otherwise relative.

`..` discouraged. Doctor warns and recommends absolute form.

Security BLOCK patterns (in `config.md` `path-policy`):

- `/etc/**`, `C:\Windows\**`, `~/.ssh/**`, `~/.aws/**` → BLOCK
- `~/**` (other) → WARN
- `/`, `C:\` → BLOCK
- `/tmp/**`, `/var/log/**` → OK

---

## Host Capability Modes

Set during install, stored in `config.md` `host.mode`. Changeable via `/dtd doctor` recommendation or manual edit. The actual HTTP recipe is in §Worker Dispatch — HTTP Transport above; this section says only WHO triggers it per mode.

### `plan-only`

Capability: filesystem-read/write only.
DTD does: plan/state/eval/steering management. `/dtd run` does NOT auto-dispatch — instead, prints the worker prompt for the next task and asks user to:

```
Next task: 2.1 API endpoints
Worker: deepseek-local

→ Copy this prompt into a separate session running deepseek-coder:6.7b:

[----- prompt begins -----]
[full prompt text]
[----- prompt ends -----]

When you have the response, paste it back as:

  /dtd run --paste

Or save to .dtd/tmp/paste-2.1.md and run /dtd run --paste-file 2.1
```

The controller then parses the pasted response and continues the loop.

### `assisted`

Capability: + shell-exec or web-fetch.
DTD does: auto-dispatch. Per-call confirm if `config.md` `assisted_confirm_each_call: true` (default false in v0.1).

### `full`

Capability: + shell-exec/web-fetch + autonomy.
DTD does: autonomous dispatch + auto-apply file changes. Destructive actions (file delete, force push, dependency removal) still confirm.

---

## Controller Work Categories

When the controller does work itself (orchestration, escalation step 4, or any direct action), classify into one of three categories. Self-classification at action start, recorded in `state.md`:

- **`orchestration`** (planning, dispatching, status, NL parsing, integrating worker outputs) → `grade: N/A`, `gate: none`
- **`small_direct_fix`** (controller fixes a typo/small bug instead of re-dispatching to worker) → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`
- **`artifact_authoring`** (controller writes a non-trivial artifact: code module, doc, plan section) → `grade: N/A(controller)`, `gate: REVIEW_REQUIRED`

`REVIEW_REQUIRED` gate: phase pass blocked until reviewer (worker with `review` capability) or user explicitly OKs.

`config.md` `controller-work-policy`:

```markdown
- review_required_by: reviewer_worker | user
- review_fallback: user
```

Controller never grades its own work. Status display: `grade: N/A(controller) gate: REVIEW_REQUIRED — awaiting <reviewer>`.

---

## Worker Output Discipline

Controller parses worker output strictly. Workers MUST emit:
- ONE fenced code block per file, prefixed `===FILE: <path>===`
- ONE summary line `::done:: <≤80 chars>` OR `::blocked:: <reason>`
- Optional `::ctx::` advisory line.

Malformed output triggers `failure_count_iter++`.

> Full canonical reference (output marker spec + HTTP dispatch
> transport): see `.dtd/reference/workers.md`.

---

## Worker Dispatch — HTTP Transport

OpenAI-compatible chat-completions transport. Per-mode (plan-only,
assisted, full) the recipe is identical; difference is who triggers
the call.

Two-layer error model:
- **Recoverable / quality** failures → ladder (retry → escalate via
  `escalate_to`).
- **Blocking** failures (auth/endpoint/rate-limit-2nd/timeout-2nd/
  network/parse-error) → fill decision capsule, refuse `/dtd run`.

Reasons enumerated: `AUTH_FAILED`, `ENDPOINT_NOT_FOUND`,
`RATE_LIMIT_BLOCKED`, `WORKER_5XX_BLOCKED`, `TIMEOUT_BLOCKED`,
`NETWORK_UNREACHABLE`, `MALFORMED_RESPONSE`, `WORKER_INACTIVE`.

Fallback chain (per task): explicit `<worker>` → `escalate_to` →
same-capability narrower-profile peer → `roles.fallback` →
controller takeover (REVIEW_REQUIRED) → user.

> Full canonical reference: see `.dtd/reference/workers.md`
> (request shape, per-mode dispatch recipes, response parsing,
> per-status error table, decision capsule schema, fallback rules,
> tuning fields, reasoning-model handling, provider notes).
> Lazy-load via `/dtd help workers --full`.

---

## Phase Iteration Control

Each phase declares `max-iterations="<N>"` in plan XML. An "iteration" = one full pass through the phase where worker(s) attempt all tasks. If the resulting grade < `target-grade`, the controller retries (next iteration), unless max is reached.

**Values**:

- `max-iterations="5"` (or any integer ≥ 1) — retry up to N times, then escalate to user
- `max-iterations="unlimited"` — no cap. Controller keeps retrying until grade ≥ target OR another escalation trigger fires (tier escalation, stuck-blocker hash, user pause/stop).
- Phase has no `max-iterations` attribute → use `config.md` `default_max_iterations` (default 5).

**Behavior at limit reached** (`iteration_count == max_iterations` AND grade < target):

1. Append `phase-history.md` row with `gate: escalated:user`.
2. Fill decision capsule (per state.md schema):
   ```yaml
   awaiting_user_decision: true
   awaiting_user_reason: MAX_ITERATIONS_REACHED
   decision_id: dec-NNN
   decision_prompt: "Phase <name> hit max-iterations cap with grade <X> < target <Y>. How to proceed?"
   decision_options:
     - {id: accept,        label: "accept current",     effect: "keep current grade, advance",                    risk: "deliverable below target"}
     - {id: rework,        label: "rework",             effect: "reset iteration counter, try again",             risk: "may stall again"}
     - {id: increase_cap,  label: "raise cap by 5",     effect: "bump max-iterations by 5, continue",             risk: "more time/tokens"}
     - {id: abandon,       label: "abandon",            effect: "finalize_run(STOPPED)",                          risk: "lose run progress beyond saved files"}
   decision_default: rework
   decision_resume_action: "controller acts on chosen option's effect"
   user_decision_options: [accept, rework, increase_cap, abandon]   # legacy back-compat
   ```
3. Stop run loop. `/dtd status` displays prompt + options + default.
4. User chooses; controller acts on the option's `effect`.

**Unlimited safety**:

- Doctor WARNs on plans where any phase has `max-iterations="unlimited"` AND that phase's worker `escalate_to: user` is NOT terminal (would create true infinite loop on stuck blocker).
- Recommend: when using `unlimited`, ensure tier escalation chain has a real terminal at user.
- Steering: user can pause anytime regardless of unlimited (`/dtd pause` always works).
- Best-blocker hash detection still fires inside an unlimited phase, so genuinely stuck identical-failure loops still escalate via the failure_reason_hash acceleration.

**Iteration counter** in `state.md` Active Run Capsule (`current_iteration`) increments on each phase retry; resets on phase pass or phase reassign.

---

## Per-Run Notepad

`.dtd/notepad.md` is a compact wisdom capsule for the active run. Schema v2
has a worker-visible `## handoff` section with 8 H3 headings plus four
controller-only sections: `learnings`, `decisions`, `issues`, and
`verification`. Schema v1 legacy notepads may have a free-form `<handoff>` or
`### handoff` block.

**Workers receive ONLY the schema-v2 `## handoff` section** (or the legacy
schema-v1 handoff block) as part of their prompt prefix after
`worker-system.md` and `PROJECT.md`, before `skills/<capability>.md`.
This replaces "send entire phase log to next worker" (token-expensive) with a
curated controller-authored summary.

Update lifecycle:

- Controller updates `notepad.md` in the canonical `/dtd run` step (o) — between tasks, never mid-flight.
- `learnings` / `decisions` / `issues` / `verification` are append-mostly. Controller may prune/compact when total file size exceeds ~4 KB.
- `## handoff` section is **rewritten** before each worker dispatch — it's a snapshot of state, not history.

**Terminal lifecycle**: notepad archive/reset is one of the steps in `finalize_run(terminal_status)` (see `/dtd run` section). Called by ALL terminal exits — `COMPLETED`, `STOPPED`, `FAILED`. Steps:

1. Copy `.dtd/notepad.md` → `.dtd/runs/run-NNN-notepad.md` (creates `.dtd/runs/` if missing).
2. Reset `.dtd/notepad.md` to the current schema-v2 template state.

PAUSED is non-terminal — notepad is preserved across pause/resume.

Doctor checks:
- `notepad.md` is non-empty AND no active plan → ERROR (orphaned content from a crashed/skipped finalize_run).
- `runs/` directory exists AND has files → INFO (history available; user can grep).
- `runs/` directory file count > 100 OR total size > 10 MB → INFO (consider cleanup; v0.1.1 will add `/dtd runs prune`).

Notepad is **complementary** to `phase-history.md` (compact phase pass log) and `attempts/run-NNN.md` (immutable attempt history). Notepad is **interpretive** ("what did we learn"); the others are **factual** ("what happened").

### GSD-style reset semantics

Worker execution context is reset on every dispatch, retry, worker switch, and
phase boundary. The reset is not amnesia: the controller preserves improved
method knowledge by distilling it into `learnings`, `decisions`, `issues`,
`verification`, and a compact `<handoff>`.

Rules:

- Treat a DTD worker dispatch as the GSD execution-unit equivalent. Keep the
  unit small enough that a fresh prompt can complete it without context rot.
- Never feed a worker its previous raw transcript as context for a retry.
- Never carry provider session state across phase boundaries unless a future
  explicit `worker_session_id` resume policy is specified.
- Retry starts fresh with task spec + compact retry hint + current `<handoff>`.
  Completed/superseded attempts are discovered from `.dtd/attempts/` and logs.
- Phase advance rewrites `<handoff>` from durable state, then dispatches the
  next phase with a fresh worker context.
- PAUSED preserves controller run memory and notepad; it does not preserve or
  depend on worker chat context.

---

## Attempt Timeline

For every worker dispatch, append an entry to `.dtd/attempts/run-NNN.md` (created on first dispatch of a run). Provides immutable history of who tried what, when, and why an attempt was superseded.

Format (one H2 per attempt, newest at bottom):

```markdown
## attempt-001-task-2.1-att-1
- task: 2.1
- phase: 2
- worker: deepseek-local
- profile: code-write
- model: deepseek-coder:6.7b
- status: done                  # pending | running | done | blocked | failed | cancelled | superseded
- started_at: 2026-05-04 19:51:12
- ended_at: 2026-05-04 19:59:24
- duration: 8m12s
- grade: GOOD
- output_paths: src/api/users.ts, src/api/users.test.ts, src/api/users.helpers.ts
- error: null
- replacement_reason: null      # set if superseded by a later attempt
```

Rules:

- **Append-only**. Once an attempt is `done`/`blocked`/`failed`/`cancelled`/`superseded`, its entry is immutable.
- Only the **current attempt** (status=`pending` or `running`) may be updated.
- If a stale attempt's worker returns late after the controller has already moved on, mark the late result as `superseded` with `replacement_reason: "late return after escalate to <new worker>"`. The late output is NOT applied.
- Attempt IDs use `att-N` suffix per (task, attempt-number-for-this-task). E.g., first attempt on task 2.1 = `att-1`, retry = `att-2`.
- `pending_attempts` in `state.md` Active Run Capsule lists IDs of currently-running attempts.

This file becomes the basis for `/dtd status` "recent attempts" widget and `phase-history.md` notes.

---

## Incident Tracking (v0.2.0a)

> **v0.2.3 R1 extraction**: full canonical spec for this section moved to
> `.dtd/reference/incidents.md`. Lazy-loaded via `/dtd help incidents --full`.
> The summary below documents what the topic covers; see the reference file
> for the schema, severity mapping, multi-blocker policy, info-trigger rules,
> resolve logic, and finalize_run integration.

Every operational failure that needs **durable tracking** creates an incident.
Incidents convert ad-hoc "blocked attempt" failures into queryable, resolvable
records that survive across sessions.

Files: `.dtd/log/incidents/index.md` (registry) + `inc-<run>-<seq>.md` (detail).

Severity → state mapping (4 levels):
- `info` — populates `recent_incident_summary` only.
- `warn` — sets `active_incident_id`; populates `recent_incident_summary`.
- `blocked` — sets `active_incident_id` + `active_blocking_incident_id`;
  fills `awaiting_user_reason: INCIDENT_BLOCKED`. NEVER touches
  `recent_incident_summary`. `/dtd run` refused.
- `fatal` — same as blocked + `finalize_run(FAILED)` on ack.

Multi-blocker invariant: ≤ 1 `active_blocking_incident_id`; queue lives in
`index.md` (NOT `recent_incident_summary`). On resolve, scan index for
oldest unresolved blocker.

`/dtd incident list/show/resolve <id> <option>`. Destructive options
(stop/purge/delete/...) ALWAYS confirm.

`finalize_run(terminal_status)` clears incident state per
`dtd.md` §`finalize_run` step 5.

For full schema, severity mapping rules, multi-blocker legal paths,
info-severity triggers, cross-link integrity, resolve logic, and
finalize_run integration detail, see `.dtd/reference/incidents.md`.

---

## Token Economy

Controller MUST follow:

- Worker raw output → save to `.dtd/log/exec-<run>-task-<id>.<worker>.md`. Reference path in chat, never dump raw.
- Worker prompt assembly order (canonical — same as `instructions.md` §Token Economy #2):
  1. `worker-system.md` (cached)
  2. `PROJECT.md` (cached)
  3. `notepad.md` `<handoff>` only (dynamic, NOT cached)
  4. `skills/<capability>.md` (cached)
  5. task-specific section (not cached)
  Workers receive ONLY the `<handoff>` section of notepad, not the full file.
- Context-file inline policy:
  - < 2 KB: inline as-is
  - 2-8 KB: `head -100 + tail -50 + ref:context-N.md` truncation
  - > 8 KB: NO inline. If worker has `shell-exec`/`filesystem-read`, instruct it to read directly. Else split into smaller tasks.
- Plan compaction: completed tasks → 1-line form when plan size > 8 KB.
- `work.log` events use compact grammar: `### HH:MM | <model> | <EVENT> <one-line body>`.
- Status output: table-only by default. Full details on `--full` flag or explicit `/dtd plan show --task <id>`.
- Lazy-load catalogs: detailed persona/reasoning/tool-use docs, locale packs,
  and extended help topics are not part of always-loaded instructions. Route to
  them only when planning/changing/explaining those features. Worker prompts
  get resolved compact ids/summaries only.

Full token rules in `.dtd/instructions.md`.

---

## Status Dashboard

ASCII is canonical for `/dtd status`. Compact dashboard shows: header,
goal, current task, worker, optional `modes`/`ctx` lines (v0.2.0f),
optional `incident` line (v0.2.0a), work paths, writing files, locks,
elapsed, recent, queue, pause hint.

Glyphs: `+` section header, `|` separator, `*` recent done bullet,
`->` queue arrow, `>` current marker, `[P]` pause hint. Unicode
polish optional via `config.md` `dashboard_style: unicode`.

Flags: `--compact` (default) / `--full` / `--plan` / `--history` /
`--eval`.

Dashboard load policy: `/dtd status` reads only `state.md` + compact
indexes. It MUST NOT load the full persona/reasoning/tool catalog.

> Full canonical reference: see `.dtd/reference/status-dashboard.md`
> (sample compact output, mode/ctx/ctrl line render rules,
> incident-line spec, glyph table, flag matrix, config knobs).
> Lazy-load via `/dtd help status-dashboard --full`.

---

## AIMemory Boundary

DTD writes to `AIMemory/work.log` only in these cases (per design §8):

1. **DTD run start** → `WORK_START` (one event)
2. **DTD run end** → `WORK_END` (one event)
3. **Durable architecture decision** → `NOTE`
4. **High-impact steering (goal materially changed)** → `NOTE`
5. **DTD run BLOCKED/FAILED** → `WORK_END` with `status=blocked|failed`
6. **Cross-agent handoff** (rare) → `HANDOFF`
7. **DTD protocol/spec changed across versions** → `NOTE`

Event format (compact):

```
### 2026-05-04 19:50 | <controller-model> | WORK_START
DTD run-001 (plan-001): "<goal first line>". <N> phases, <M> tasks, <K> workers. Plan: .dtd/plan-001.md

### 2026-05-04 22:42 | <controller-model> | WORK_END
DTD run-001 done. status=COMPLETED grade=GREAT 2h52m. <N>/<N> phases pass. Summary: .dtd/log/run-001-summary.md
```

If `AIMemory/` does not exist, DTD operates fully via `.dtd/` and emits no AIMemory events. Setup recommends but never requires AIMemory.

All phase/task/worker/iteration/eval/steering details stay in `.dtd/`. **Never write per-task or per-iteration events to `AIMemory/work.log`.**

---

## Security & Secret Redaction

This is a **first-class** policy. Violations are install-blocking errors.

1. **Never write API keys, auth headers, bearer tokens, or raw env values** to:
   - `.dtd/log/**`
   - `AIMemory/**`
   - worker prompt body (use HTTP header for auth instead)
   - `/dtd status` output
   - `/dtd plan show` output
   - any markdown displayed to user

2. **Reference env var names only**:

   ```markdown
   ✗ BAD:  api_key: sk-abc123def456...
   ✓ GOOD: api_key_env: DEEPSEEK_API_KEY
   ```

3. **Worker prompt assembly**: env var values resolved ONLY in HTTP header at dispatch time. Never substituted into prompt body. Never logged in raw form.

4. **`/dtd doctor` secret-leak detection** scans:
   - `.dtd/log/**/*.md`
   - `.dtd/state.md`
   - `AIMemory/work.log` (if present)
   - `AIMemory/handoff_*.md` (if present)

   Patterns include the ones listed under `/dtd doctor`. Plus heuristic: any string ≥ 20 chars matching `[A-Za-z0-9_/+=-]+` within 50 chars of `api_key`/`token`/`secret`/`authorization`/`bearer`.

   On detection: ERROR exit, point to file/line, suggest redaction. Do not auto-fix (user might lose context).

5. **`.gitignore` enforcement** (canonical: `.dtd/.gitignore` is the source of truth for `.dtd/` local protection):
   - **`.dtd/.gitignore`** is mandatory. Install fetches it. Covers `.env`, `tmp/`, `log/`, `eval/`, `attempts/`, `runs/`, lock dropfiles, OS noise within `.dtd/`.
   - All per-run history files (`attempts/run-NNN.md`, `runs/run-NNN-notepad.md`, `log/exec-*.md`, `eval/eval-*.md`) are local runtime history and intentionally **not** committed. Audit trail is durable on the local machine (or via separate backup).
   - **Project root `.gitignore`** is optional. Install does NOT auto-modify it for `.dtd/` itself. The `--hard` uninstall flow asks user to add `.dtd.uninstalled-*/` to root for backup-folder protection (see §`/dtd uninstall`). Otherwise doctor reports root-level coverage gaps as INFO.
   - Rationale: keeping policy in `.dtd/.gitignore` means uninstall removes it cleanly; root-level edits leave residue.

6. **Worker response**: if a worker echoes secrets in its output, controller **must redact before saving** to `.dtd/log/`. Replace matched patterns with `<REDACTED>` and append a NOTE to the log file.

---

## Adopting DTD on existing in-progress work

DTD is not greenfield-only. You can install it on a project that already has
phased development underway and bring the remaining work under DTD without
rewriting history. Three patterns, in order of effort:

### Pattern A — Forward-only (simplest, recommended)

Install DTD, then use `/dtd plan` ONLY for remaining work. Past work stays in your
code + git history; you don't try to retroactively model it.

```
1. fetch prompt.md ... apply to project   (install DTD, ~30s)
2. Fill .dtd/PROJECT.md with current project state:
     - what the project does
     - tech stack
     - what's already done (1 paragraph)
     - what's left (1 paragraph)
3. /dtd workers add  (or paste from workers.example.md)
4. /dtd mode on
5. /dtd plan "remaining: <X, Y, Z>"
6. /dtd approve  →  /dtd run
```

DTD only sees and tracks the new work. Your existing code is the starting state,
nothing else needs annotation.

### Pattern B — Hybrid retroactive (audit-friendly)

If you want the full project under DTD's audit umbrella (every phase logged,
including past), add already-done phases/tasks to the plan with `status="done"`
markings before approving:

```
1. /dtd plan "the full project goal"     (covers past + future)
2. /dtd plan show — review the DRAFT
3. Edit .dtd/plan-001.md by hand:
     - For already-completed phases/tasks:
       <task id="1.1" status="done" worker="manual" grade="GOOD"
             dur="prior-to-DTD">
         <output-paths actual="true">src/api/users.ts, src/api/users.test.ts</output-paths>
       </task>
     - Use worker="manual" or worker="controller" to signal
       "not dispatched via DTD" (safe: routing skips done tasks)
4. (Optional) Pre-populate .dtd/phase-history.md with rows for past phases:
   note="manual prior work, imported at adoption"
5. (Optional) Pre-populate .dtd/notepad.md <learnings> with prior decisions
6. /dtd approve  →  /dtd run    (only pending tasks dispatch)
```

### Pattern C — Translate an existing planning doc

If you already have your own phased planning markdown (a roadmap.md, plan.md,
etc.), translate it into DTD's XML schema in `.dtd/plan-001.md`:

1. Each top-level phase in your doc → `<phase id="N">` block
2. Each task/checkpoint → `<task id="N.M">` with `<goal>`, `<output-paths>`
3. Done items → add `status="done" worker="manual"` and fill `<output-paths actual="true">`
4. Pending items → leave `<done>false</done>`, assign `<worker>` or `<capability>`
5. Run `/dtd plan show` to verify rendering, then `/dtd approve` + `/dtd run`

Your original doc stays where it was (e.g., `docs/roadmap.md`); DTD's
`plan-001.md` becomes the executable mirror.

### Pseudo-worker validation rule

`worker="manual"` and `worker="controller"` are **pseudo-worker** annotations,
allowed ONLY on tasks already marked done. They signal "this task was completed
outside DTD's dispatch system" — controller skips them entirely (no dispatch,
no validation, no lease, no attempt entry).

Validation:

- Pending task (`<done>false</done>`) with `worker="manual"` or `worker="controller"`:
  → `/dtd doctor` ERROR `pseudo_worker_on_pending_task`. `/dtd run` refuses.
- Done task (`status="done"` AND `<done>true</done>`) with these pseudo-workers:
  → OK; routing/permission/lock checks all skipped for that task.
- Reserved word check in `/dtd doctor` is suppressed for these two values when
  used in `<worker>` of a done task. (Same words remain rejected as worker IDs
  in `workers.md` registry — only the `<worker>` field on done plan tasks
  treats them as legitimate annotations.)

This keeps `controller` reserved as a system-meaning identifier in NL routing
(per `instructions.md` Naming Resolution) while letting plan XML use it as an
adoption-history annotation. The two contexts don't conflict because plan XML
parsing happens before NL resolution.

### Best practices for adoption

- **PROJECT.md is the bridge.** Fill it with enough current state that workers
  understand the codebase without you having to repeat in every task.
- **worker="manual"** on past tasks is a clear signal in audit logs and avoids
  re-dispatch attempts.
- **phase-history.md prior rows** can use `note="adopted at <date>, prior work
  not via DTD"` for clarity.
- **Don't backfill attempt timeline** (`.dtd/attempts/run-NNN.md`) — that's
  immutable per-dispatch history; for past manual work, keep your git history
  as the audit source.
- **First run starts at the next pending task** — DTD reads `<done>true</done>`
  marks correctly and skips ahead.

### Doctor for adoption sanity

Run `/dtd doctor` after adopting:

- PROJECT.md TODO check: should pass (you filled it in)
- Plan state check: plan-001 is DRAFT or APPROVED, size ≤ 24 KB
- Path policy: any `<output-paths actual="true">` paths still exist on disk

If past tasks have `output-paths` pointing at files that no longer exist (refactored away), the doctor will WARN — fix the plan or accept the warning.

---

## Lazy-Load Profile (v0.2.3)

DTD's full spec is large (`instructions.md` always-loaded + `dtd.md`
slash-command source + `.dtd/reference/` lazy reference). When the
controller is doing simple work (status check, planning), it doesn't
need the full run-loop / dispatch / recovery surface in active focus.

The lazy-load profile is a **controller-side cognitive scoping hint**.
Host LLMs still receive the full auto-loaded text in their raw context
(load/unload at the host layer is host-specific). What changes is which
sections the controller logically treats as "active" for the current
turn.

### Profiles

| Profile | When | Focus |
|---|---|---|
| `minimal` | `mode: off` OR no active plan | TL;DR + intent gate + status/doctor only |
| `planning` | `plan_status: DRAFT \| APPROVED` | + NL routing + plan/approve commands + worker registry |
| `running` | `plan_status: RUNNING \| PAUSED` | + run loop + dispatch + autonomy + context patterns |
| `recovery` | `pending_patch: true` OR `active_blocking_incident_id` non-null | + incident commands + recovery surface |

`recovery` is a **superset** of `running`. Higher profiles include all
sections from lower profiles. The order is `minimal ⊂ planning ⊂ running
⊂ recovery`.

### Profile resolution

Per-turn protocol step 1.5 (after reading `state.md`, before Intent Gate):

```
1. Read state.md fields: mode, plan_status, pending_patch,
   active_blocking_incident_id.
2. Apply resolution rules:
   - If mode != dtd OR active_plan == null: minimal
   - Elif active_blocking_incident_id != null OR pending_patch: recovery
   - Elif plan_status in [RUNNING, PAUSED]: running
   - Elif plan_status in [DRAFT, APPROVED]: planning
   - Else: minimal
3. Compute `effective_profile`; do not persist it yet. If the turn later
   performs a mutating action and it differs from state.md.loaded_profile:
   - Update state.md.loaded_profile, loaded_profile_set_at,
     loaded_profile_reason atomically in that action's state write.
   - If config.load-profile.profile_transition_logging: true (diagnostic only),
     append a one-line entry to `.dtd/log/profile-transitions.md`:
     "loaded_profile: <old> -> <new> reason: <reason>". Never write
     profile transition diagnostics to `steering.md`.
4. Use the new profile's section set (from config.load-profile.profile_sections)
   as the controller's "active" cognitive scope for this turn.
```

Clarification: observational reads compute and display `effective_profile`
without writing `state.md` or appending logs. Profile transition diagnostics
are optional and, when enabled, go to `.dtd/log/profile-transitions.md`, never
to `steering.md`.

### Section coverage

Each profile maps to a set of `instructions.md` / `dtd.md` /
`.dtd/reference/` sections per `config.md.load-profile.profile_sections`.
See config.md for the canonical mapping.

Sections NOT in the active set are still in raw context but treated as
**inactive**: the controller doesn't apply their rules for this turn.
Example: in `minimal` profile, the dispatch error matrix is inactive
(no run is happening, no dispatches to handle).

### Aggressive unload (advanced; off by default)

If `config.load-profile.aggressive_unload: true` AND the host supports
runtime context eviction (e.g., MCP-style dynamic tool registration),
the controller may EVICT inactive sections from active context entirely.
Default `false` because most hosts don't support this; enabling it
without host support causes no harm but no benefit.

### Profile boundaries

Profile transitions happen at turn boundaries, never mid-task. If a
worker dispatch is in flight when state changes (e.g., incident fires
mid-task), the profile updates at the next turn's per-turn protocol
step 1.5. Mid-task incident handling uses the current profile's
section set.

### Doctor checks

Per `/dtd doctor`:

- `state.md.loaded_profile` is one of `minimal|planning|running|recovery`;
  ELSE ERROR `loaded_profile_invalid`.
- `loaded_profile` matches resolution rules given current state.md
  (computed by doctor from mode/plan_status/pending_patch/incident);
  ELSE INFO `loaded_profile_drift`. Doctor is observational by default and
  reports the computed effective profile without refreshing durable state.
- `config.load-profile.profile_sections` has all 4 keys
  (minimal/planning/running/recovery); ELSE ERROR
  `profile_sections_incomplete`.
- Each profile has `active_sections` and `reference_drilldown_topics`;
  ELSE ERROR `profile_sections_shape_invalid`.
- `aggressive_unload: true` when host doesn't support dynamic eviction
  (heuristic: host_mode == plan-only); ELSE INFO
  `aggressive_unload_unsupported`.

### Token economy impact

For long-running sessions, the lazy-load profile reduces
the controller's effective per-turn cognitive scope by making irrelevant
sections inactive. This is not a guaranteed provider-token reduction.

This is measured by the `/dtd perf` controller-usage ledger (v0.2.0f
follow-up) — perf measures actual token usage; lazy-load profile
does not assume it.

Correction: this is a cognitive-scope benefit by default, not a guaranteed
provider-token reduction. Actual prompt-token savings require host support for
selective loading or `aggressive_unload`; `/dtd perf` is the authority for
measured token usage.

### NL routing

| Phrase | Canonical |
|---|---|
| `"프로파일 보여줘"` / `"profile"` | `/dtd status --profile` (observational; v0.2.3) |
| `"프로파일 새로고침"` / `"refresh profile"` | `/dtd doctor --refresh-profile` (recompute from state) |

(Localized phrases via locale packs per v0.2.0e.)

English-only core aliases: `"profile"` / `"show profile"` render
`/dtd status --profile`; `"refresh profile"` recomputes effective profile on
the next mutating turn. Localized examples belong in locale packs.

---

## R2 Readiness (v0.3)

### `/dtd r2 readiness [--full|--json]`

Observational entry gate for v0.3 R2 live execution. It answers
whether R2 can start without creating `test-projects/dtd-v03-live/`,
calling live workers, touching secrets, or faking an R2 PASS from
static checks.

Aliases: `/dtd r2 status`, `/dtd r2 check`.

Outputs one `r2_0_decision` row:

- `GO`: proceed to R2-1 disposable scaffold.
- `STOP`: fix static/doctor/worker prerequisites first.
- `WARN`: only optional sync coverage is absent; user may proceed
  without L-D-* coverage, but that is not a full R2 PASS.

> Full canonical reference: see
> `.dtd/reference/v030-r2-0-readiness-checklist.md`.
> Lazy-load via `/dtd help v030-r2-0-readiness-checklist --full`.

---

## v0.1.1 / v0.2 / v0.3 Roadmap

Released: v0.1, v0.1.1, v0.2.0a (TAGGED 2026-05-05).

All 9 v0.2 line sub-releases TAGGED 2026-05-06: v0.2.0d / v0.2.0f
/ v0.2.3 / v0.2.0e / v0.2.0b / v0.2.0c / v0.2.1 / v0.2.2 (plus
v0.2.0a from 2026-05-05).

All 5 v0.3 line sub-releases TAGGED 2026-05-06 (Codex final
review pass `handoff_dtd-v030c-v030d-r1-codex-review.gpt-5-codex.md`
2026-05-06): v0.3.0e, v0.3.0b, v0.3.0a, v0.3.0c, v0.3.0d.

R2 (live execution verification) plan defined in
`.dtd/reference/v030-r2-live-test-plan.md`; user-driven setup
required (test project + 3 worker slots + optional sync target).

> Full canonical reference: see `.dtd/reference/roadmap.md`
> (per-sub-release scope, v0.1.1 features, v0.2 detailed feature notes,
> v0.3 line status, R2 live-test plan, orthogonal earlier roadmap items,
> AIMemory archive index).
> Lazy-load via `/dtd help roadmap --full`.

---

## End of spec

This spec is the source of truth. NL routing and per-turn behavior live in
`.dtd/instructions.md`. Templates and examples live in `.dtd/` and `examples/`.
Acceptance scenarios spanning v0.1 / v0.2 / v0.3 lines are in
`test-scenarios.md`.
