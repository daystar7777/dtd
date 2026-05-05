# DTD v0.3.0d — Cross-machine session sync (canonical reference)

## Anchor

This file is the canonical reference for v0.3.0d cross-machine session
affinity. `dtd.md` keeps a compact summary; full rules live here.

Per Codex v0.3 roadmap review (v0.3.0d P1.6 + P1.7 amendments), v0.3+
sub-release runtime contracts ship as dedicated lazy-loaded reference
topics rather than expanding `run-loop.md` past its 32 KB lazy-load
cap.

## Summary

Today (v0.2.1 R1) worker session resume is per-machine. Each DTD install
on each machine has its own `state.md.last_worker_session_id`. For
multi-machine workflows (laptop ↔ desktop ↔ remote dev server),
session continuation fails when switching machines: Machine A starts a
worker session; user moves to Machine B; retry on Machine B uses
`fresh` strategy because Machine B has no record.

v0.3.0d adds **opt-in session sync** via a shared sync target with
3 backends:
- `filesystem` (cloud-synced folder, e.g. Dropbox / iCloud / OneDrive).
- `git_branch` (commit session refs to a dedicated branch).
- `none` (default; per-machine only — preserves v0.2.1 behavior).

Default is `enabled: false`. When enabled, all synced payloads are
**mandatorily encrypted** (Codex P1.6 — see "Encryption invariant"
below); raw provider session ids are NEVER written to a synced folder
or branch.

## Repo identity (shared with v0.3.0a)

Cross-machine sync uses the same `repo_identity_hash` defined in
`.dtd/reference/v030a-cross-run-loop-guard.md`:

1. PRIMARY: `sha256(git config remote.origin.url + first-commit-sha)`
   when both available.
2. SECONDARY: `state.md.project_id` (auto-generated UUID at install
   if not user-set).
3. TERTIARY: `sha256(absolute project root path)` — tie-breaker only,
   NEVER the primary cross-machine identity (Codex P1.7).

Sync target paths use `<sync_root>/<repo_identity_hash>/` so multiple
DTD-using projects sharing a single sync folder stay separated.

## Sync ledger format

`.dtd/session-sync.md` (gitignored under `.dtd/.gitignore`; raw
session ids never written here — they live encrypted in
`.dtd/session-sync.encrypted`):

```markdown
# DTD Session Sync (v0.3.0d)

> Cross-machine session-id ledger. Synced via the configured backend.
> Updated at: dispatch start, response receive, finalize_run.

## Active sessions

| machine_id | provider | session_id_hash | first_seen | last_used | expires_at | status |
|---|---|---|---|---|---|---|
| laptop-A   | claude-api | a3f1b9... | 2026-05-05T14:00 | 2026-05-05T18:23 | 2026-05-06T14:00 | active |
| desktop-B  | claude-api | a3f1b9... | 2026-05-05T19:01 | 2026-05-05T19:15 | 2026-05-06T14:00 | active (resumed from laptop-A) |

## Notes

- `session_id_hash` is sha256 of the actual session_id (the raw id is
  sensitive; hash for cross-machine matching).
- The actual `session_id` is stored in encrypted form in
  `.dtd/session-sync.encrypted` (filesystem backend).
- Status: `active | superseded | expired | conflicted`.
```

The synced filename pattern is
`<sync_root>/<repo_identity_hash>/session-sync.md` (visible metadata)
plus `<sync_root>/<repo_identity_hash>/session-sync.encrypted`
(encrypted payload — opaque to the sync provider).

## Encryption invariant (Codex P1.6 — MANDATORY)

When `session_sync.enabled: true` and ANY backend other than `none`
is active, the following are contract-mandatory:

1. **`session_sync_encryption_key_env` MUST resolve** to a non-empty
   value before any sync read or write.
   - If the env var is unset or empty: ERROR
     `session_sync_no_encryption_key`. Sync is **disabled** for the
     run; the controller falls back to per-machine v0.2.1 behavior.
   - This is NEVER a WARN with plaintext fallback.

2. **Raw provider session ids MUST NEVER be written to a synced
   folder, branch, or any backend transport**.
   - The synced ledger (`session-sync.md`) contains only:
     `machine_id`, `provider`, `session_id_hash` (sha256), timestamps,
     status, and human-readable notes.
   - The actual `session_id` lives in `session-sync.encrypted` —
     AES-256-GCM-encrypted with a key derived from the env-var
     value via `HKDF-SHA256(salt = repo_identity_hash[:16])`.
   - Each row in the encrypted blob carries a per-row 96-bit nonce.

3. **The encryption key value itself NEVER appears in any committed,
   logged, or synced location**.
   - Logs that reference the key reference its env-var **name** only
     (e.g. `DTD_SESSION_SYNC_KEY` set / unset).
   - `/dtd doctor` prints `name set` / `name unset`, never the value.

4. **Decryption failures fail closed**.
   - `decrypt_failed` produces a WARN, marks the row `corrupted`, and
     does NOT advance to plaintext fallback.

5. Doctor check `session_sync_plaintext_violation` runs whenever
   `session_sync.enabled: true`, the `session-sync.encrypted` file
   is missing while a non-`none` backend is configured, AND
   `session-sync.md` contains rows that should have backing
   encrypted entries.

## Backends

### `none` (default)

No sync. Per-machine v0.2.1 behavior. Spec'd here for completeness;
no doctor checks fire when backend is `none`.

### `filesystem`

```yaml
backend: filesystem
sync_path: "/Users/user/Dropbox/dtd-sync"     # absolute path; user-configured
encryption_key_env: DTD_SESSION_SYNC_KEY       # env var name; never literal
```

Sync mechanism:
- **Read**: at run start (after step 1), check
  `<sync_path>/<repo_identity_hash>/session-sync.md` for newer rows
  (compared by `last_used`). Decrypt encrypted entries that match
  rows we want to consume.
- **Write**: at dispatch start + finalize_run, append/update the
  local `.dtd/session-sync.md` AND copy both
  `session-sync.md` + `session-sync.encrypted` to
  `<sync_path>/<repo_identity_hash>/`.
- **Encryption**: per Codex P1.6 — actual `session_id` values
  encrypted with env-var-derived key before sync; raw ids never
  appear in synced files.

### `git_branch`

```yaml
backend: git_branch
sync_branch: "dtd-session-sync"
sync_remote: origin
sync_commit_interval_min: 15
encryption_key_env: DTD_SESSION_SYNC_KEY
```

Sync mechanism:
- **Read**: at run start, fetch the sync branch; merge if newer.
- **Write**: at finalize_run + every `commit_interval_min`,
  commit `.dtd/session-sync.md` + `.dtd/session-sync.encrypted` to
  sync branch + push.
- **Branch isolation**: writes happen only in the dedicated sync
  branch or an isolated worktree for that branch. These files are
  gitignored on the project working branch; implementations that
  use Git MUST force-add them only on the configured sync branch
  (for example `git add -f .dtd/session-sync.md
  .dtd/session-sync.encrypted`) and MUST NOT stage them on `main`
  or the user's active feature branch.
- **Encryption**: same MANDATORY invariant — encrypted blob in
  `.dtd/session-sync.encrypted` committed to branch; raw id never
  committed.

## Run-loop integration

Augments the v0.2.1 R1 step 5.5.5 (session resume strategy resolver
in `.dtd/reference/run-loop.md`):

### Pre-dispatch (step 5.5.5b — NEW)

1. If `session_sync.enabled: false` OR `backend: none`: SKIP sync
   read; proceed with v0.2.1 R1 strategy resolver only.
2. Else read `.dtd/session-sync.md`:
   - If `state.md.last_worker_session_id` is null AND the local
     ledger has an `active` session for the current
     `(worker, provider)` tuple AND `last_used` is within
     `expires_at`: hint to v0.2.1 R1 to use `same-worker` strategy
     with that session_id_hash.
3. If the local ledger AND a remote-machine ledger row both have
   `active` sessions for the same `(worker, provider)` tuple but
   different `session_id_hash`: fill capsule
   `awaiting_user_reason: SESSION_CONFLICT` with options
   `[use_local, use_remote, fresh, stop]`. Default: `fresh`.
4. Apply chosen strategy via the existing v0.2.1 R1 resolver.

### Post-dispatch / finalize_run (step 9.session-sync — NEW)

1. Update local `.dtd/session-sync.md` row for this `machine_id`.
2. Encrypt fresh session_id values into `.dtd/session-sync.encrypted`.
3. Sync via configured backend.
4. **Connectivity failure (network unreachable, push rejected, sync
   path missing)**: log WARN to `.dtd/log/run-NNN-summary.md`
   (`session_sync_unreachable`); do NOT block dispatch (Codex
   additional amendment: connectivity ≠ conflict).
5. **A real `SESSION_CONFLICT`** (per step 5.5.5b.3): MUST create a
   decision capsule before any same-session reuse — never silent
   tie-break.

## Decision capsule — SESSION_CONFLICT

```yaml
awaiting_user_reason: SESSION_CONFLICT
decision_options:
  - {id: use_local,  label: "use this machine's session",     effect: "local session_id wins; remote marked superseded", risk: "remote machine state diverges"}
  - {id: use_remote, label: "use remote machine's session",   effect: "remote session_id wins; local marked superseded", risk: "this machine's state diverges"}
  - {id: fresh,      label: "fresh session (ignore sync)",    effect: "use fresh strategy; both machines' sessions expire", risk: "lose session continuation"}
  - {id: stop,       label: "stop the run",                   effect: "finalize_run(STOPPED)",                          risk: "lose run progress"}
decision_default: fresh
```

The loser session is marked `superseded` in the synced ledger; both
rows persist for audit (no row deletion on conflict resolve).

## Config keys

```yaml
## session-sync (v0.3.0d)

# Cross-machine session continuation. Default: off (per-machine).
# See dtd.md §/dtd session-sync command.

- enabled: false                            # boolean
- backend: none                             # none | filesystem | git_branch
- sync_path: null                           # filesystem path (e.g. ~/Dropbox/dtd-sync)
- sync_branch: null                         # git branch name
- sync_remote: origin
- sync_commit_interval_min: 15
- encryption_key_env: DTD_SESSION_SYNC_KEY  # env var name; never literal
- conflict_strategy: ask                    # ask | last_writer_wins | local_wins | remote_wins (Codex: keep ask default)
- expires_default_hours: 24
```

## State additions

```yaml
## Session sync (v0.3.0d)

- session_sync_last_read_at: null
- session_sync_last_write_at: null
- session_sync_pending_conflicts: []        # list of {provider, machine_id, session_id_hash}
- machine_id: null                          # auto-generated UUID at install (Codex: UUID + optional display_name)
- machine_display_name: null                # optional human label, e.g. "laptop-A"
```

`awaiting_user_reason` enum gains: `SESSION_CONFLICT`.

## Permission key

v0.3.0d does NOT add a new permission key. `/dtd session-sync` mutating
sub-commands (sync, expire, purge, setup) are gated under existing
v0.2.0b `tool_relay_mutating` semantics. The 11-key invariant from
v0.3.0c remains stable.

## Doctor checks

```
- session_sync_no_encryption_key (ERROR)
    session_sync.enabled = true AND Backend != none AND env var named in
    config.session_sync.encryption_key_env is unset / empty.
    Per Codex P1.6 this disables sync for the run; controller
    proceeds with v0.2.1 per-machine behavior.

- session_sync_path_invalid (ERROR)
    session_sync.enabled = true AND Backend = filesystem AND sync_path
    missing or not writable.

- session_sync_branch_missing (WARN)
    session_sync.enabled = true AND Backend = git_branch AND sync_branch
    does not exist locally.

- session_sync_plaintext_violation (ERROR)
    session_sync.enabled = true AND Backend != none AND
    .dtd/session-sync.md contains rows but
    .dtd/session-sync.encrypted is missing — synced ledger would
    leak raw session metadata.

- session_sync_files_staged_on_work_branch (ERROR)
    .dtd/session-sync.md or .dtd/session-sync.encrypted is staged
    while the current branch is not config.session_sync.sync_branch.
    Use an isolated sync branch/worktree; never commit sync ledgers
    to the project working branch.

- session_sync_unresolved_conflicts (WARN)
    state.md.session_sync_pending_conflicts non-empty.
    Recommends /dtd session-sync show.

- session_sync_expired_rows_pending (INFO)
    .dtd/session-sync.md rows where expires_at < now.

- session_sync_repo_identity_unstable (WARN)
    repo_identity_hash falls through to TERTIARY (absolute path).
    Suggests setting state.md.project_id or git remote.

- session_sync_machine_id_missing (ERROR)
    session_sync.enabled = true AND Backend != none AND
    state.md.machine_id is null.
    Auto-generated at install; missing means migration drift.

- session_sync_unreachable (WARN — runtime, not static)
    Backend reachable check failed at last sync attempt; logged
    in run-NNN-summary.md but does not block dispatch.
```

## /dtd session-sync command

```text
/dtd session-sync show              # observational; show local + synced sessions
/dtd session-sync sync              # mutating; manual sync now (filesystem/git backend)
/dtd session-sync expire <hash>     # mutating; mark a session expired
/dtd session-sync purge --before <date>  # bulk purge old entries
/dtd session-sync setup             # interactive wizard to configure backend (R1; R0 manual config)
```

NL routing:

| Phrase | Canonical |
|---|---|
| "sync sessions now" | `/dtd session-sync sync` |
| "show synced sessions" | `/dtd session-sync show` |
| "set up sync" | `/dtd session-sync setup` |

R0 ships only `show / sync / expire / purge`. The interactive `setup`
wizard is deferred to R1 (Codex additional amendment: setup wizard is
R1; R0 manual config path must be safe). For R0 users edit
`.dtd/config.md` directly.

## Test scenarios (133–141 follow v0.3.0c; 142–149 new)

```
142. Sync disabled (default backend: none): no cross-machine behavior;
     v0.2.1 unchanged
143. Filesystem backend without encryption key: ERROR
     session_sync_no_encryption_key fires; sync disabled for run;
     dispatch proceeds with per-machine strategy
144. Filesystem backend with encryption key: sync at finalize_run
     writes session-sync.md + session-sync.encrypted to
     <sync_path>/<repo_identity_hash>/
145. Git branch backend: sync at commit_interval_min commits to
     sync_branch; raw session_id NEVER appears in committed file
146. Cross-machine resume: machine B reads sync; uses same-worker
     strategy with session_id_hash match
147. SESSION_CONFLICT capsule fires when 2 machines have different
     session_id_hash for same (worker, provider) tuple; default
     decision = fresh
148. Sync connectivity failure (filesystem unreachable):
     session_sync_unreachable WARN logged; dispatch proceeds (does
     NOT block)
149. Repo identity tertiary (absolute path) fallback: doctor WARN
     session_sync_repo_identity_unstable suggests setting project_id
```

## Migration (Amendment 13 to v0.2.0d Self-Update)

- `config.md` gains `## session-sync (v0.3.0d)` section (9 keys).
- `state.md` gains `## Session sync (v0.3.0d)` section (5 fields).
- `awaiting_user_reason` enum gains `SESSION_CONFLICT`.
- New file: `.dtd/session-sync.md` (template; empty ledger).
- Optional new file: `.dtd/session-sync.encrypted` (lazy-created on
  first encrypted write; never tracked).
- `.dtd/.gitignore` gains both new file entries.
- `workers.example.md` unchanged.

Backward compat: `enabled: false` default = v0.2.1 behavior.
