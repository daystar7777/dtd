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
     value via `HKDF-SHA256(salt = first 16 bytes of repo_identity_hash)`.
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

## R1 runtime contract

R0 (commit `6013ac2` + Codex review patches `1ab11f3`) shipped 3
backends, the mandatory encryption invariant (Codex P1.6), shared
`repo_identity_hash` (Codex P1.7), SESSION_CONFLICT capsule,
sync-enabled gating across 10 doctor checks, branch-isolation
contract for git_branch backend, and `/dtd session-sync` command.

R1 ships the runtime algorithms:

### R1.1 — Encryption / decryption flow

```
session_sync_aad(repo_identity_hash, public_row):
  return "dtd-session-sync-v1|" +
         repo_identity_hash + "|" +
         public_row.machine_id + "|" +
         public_row.provider + "|" +
         public_row.session_id_hash

encrypt_session_id(session_id, key_env_value, repo_identity_hash, public_row):
  # 1. Derive per-row encryption key via HKDF.
  salt = hex_to_bytes(repo_identity_hash)[0:16] # first 16 bytes (32 hex chars)
  ikm = utf8(key_env_value)
  derived_key = HKDF_SHA256(ikm=ikm, salt=salt, info=b"dtd-session-sync-v1", length=32)

  # 2. Generate per-row 96-bit nonce.
  nonce = secure_random(12)                     # 96 bits = 12 bytes

  # 3. AES-256-GCM encrypt.
  plaintext = utf8(session_id)
  session_id_hash = public_row.session_id_hash  # equals sha256(session_id)
  associated_data = utf8(session_sync_aad(repo_identity_hash, public_row))
  ciphertext, auth_tag = AES_256_GCM_encrypt(
    key = derived_key,
    nonce = nonce,
    plaintext = plaintext,
    associated_data = associated_data,
  )

  # 4. Encode for ledger (base64url, no padding).
  return EncryptedRow(
    nonce_b64u = base64url_no_pad(nonce),
    ciphertext_b64u = base64url_no_pad(ciphertext),
    auth_tag_b64u = base64url_no_pad(auth_tag),
    session_id_hash = session_id_hash,
  )

decrypt_session_id(encrypted_row, public_row, key_env_value, repo_identity_hash):
  # Same key derivation.
  salt = hex_to_bytes(repo_identity_hash)[0:16]
  derived_key = HKDF_SHA256(ikm=utf8(key_env_value), salt=salt, info=b"dtd-session-sync-v1", length=32)

  try:
    plaintext = AES_256_GCM_decrypt(
      key = derived_key,
      nonce = base64url_no_pad_decode(encrypted_row.nonce_b64u),
      ciphertext = base64url_no_pad_decode(encrypted_row.ciphertext_b64u),
      auth_tag = base64url_no_pad_decode(encrypted_row.auth_tag_b64u),
      associated_data = utf8(session_sync_aad(repo_identity_hash, public_row)),
    )
    return Decrypted(session_id = utf8_decode(plaintext))
  except AuthError:
    # Tampered or wrong key — fail closed (Codex P1.6).
    log_warn("session_sync_decrypt_failed", row=public_row.session_id_hash)
    return Corrupted
```

Associated data is reconstructed from the public ledger row at
encrypt/decrypt time:

```text
dtd-session-sync-v1|<repo_identity_hash>|<machine_id>|<provider>|<session_id_hash>
```

Mutable lifecycle fields such as `status`, `last_used`, and
`expires_at` are intentionally not AAD-bound so conflict resolution
can mark rows `superseded` / `expired` without re-encrypting the
session id.

Ciphertext format on disk (`.dtd/session-sync.encrypted`):

```
# DTD session-sync encrypted blob (v0.3.0d R1)
# format: <session_id_hash> | <nonce_b64u> | <ciphertext_b64u> | <auth_tag_b64u>

a3f1b9d2c4e5f6a7... | xQ-fR3pK0sLm5tBg | iEpDx9nKv... | dF3qZ7wR2nVgT5...
```

R1 doctor `session_sync_decrypt_failed` (WARN — runtime, not
static) records corruption events.

### R1.2 — Pre-dispatch sync read (step 5.5.5b)

```
pre_dispatch_sync_read(state, config):
  if not config.session_sync.enabled or config.session_sync.backend == "none":
    return SkipSync()  # v0.2.1 per-machine behavior

  # 1. Verify encryption key present (P1.6 mandatory).
  key_env = os.environ.get(config.session_sync.encryption_key_env)
  if not key_env:
    log_error("session_sync_no_encryption_key")
    return SyncDisabled()  # falls back to per-machine

  # 2. Read local + remote ledgers.
  local_ledger = read_ledger(".dtd/session-sync.md")
  remote_ledger = backend_read(config.session_sync.backend, repo_identity_hash())

  # 3. Conflict detection.
  for (worker, provider) in active_dispatches(state):
    local_active = local_ledger.find_active(worker, provider)
    remote_active = remote_ledger.find_active(worker, provider)

    if local_active and remote_active and local_active.session_id_hash != remote_active.session_id_hash:
      # CONFLICT — capsule before any same-session reuse.
      return SessionConflict(local=local_active, remote=remote_active)

    elif remote_active and not local_active and within_expiry(remote_active):
      # Hint v0.2.1 R1 to use same-worker strategy.
      encrypted_row = remote_ledger.encrypted_row(remote_active.session_id_hash)
      if not encrypted_row:
        log_error("session_sync_plaintext_violation")
        continue  # remote public row has no encrypted backing; fail closed
      decrypted = decrypt_session_id(
        encrypted_row,
        remote_active,
        key_env,
        repo_identity_hash(),
      )
      if isinstance(decrypted, Corrupted):
        continue  # treat as fresh
      hint_resume_strategy("same-worker", session_id=decrypted.session_id)

  state.session_sync_last_read_at = now_utc()
```

### R1.3 — Backend-specific transport

#### `filesystem` read

```
backend_read_filesystem(sync_path, repo_id_hash):
  ledger_path = f"{sync_path}/{repo_id_hash}/session-sync.md"
  encrypted_path = f"{sync_path}/{repo_id_hash}/session-sync.encrypted"

  if not file_exists(ledger_path):
    return EmptyLedger()
  if not file_exists(encrypted_path):
    log_error("session_sync_plaintext_violation")
    return EmptyLedger()  # synced ledger without encrypted blob — refuse

  return Ledger(
    rows = parse_md(ledger_path),
    encrypted_rows = parse_encrypted(encrypted_path),
  )
```

#### `git_branch` read

```
backend_read_git_branch(sync_branch, sync_remote, repo_id_hash):
  # Fetch the sync branch from the configured remote.
  result = git_fetch(sync_remote, sync_branch)
  if result.failed:
    log_warn("session_sync_unreachable", reason=result.reason)
    return EmptyLedger()

  # Read files at FETCH_HEAD without checking out.
  ledger_md = git_show(f"{sync_remote}/{sync_branch}:.dtd/session-sync.md")
  encrypted_blob = git_show(f"{sync_remote}/{sync_branch}:.dtd/session-sync.encrypted")

  return Ledger(
    rows = parse_md(ledger_md),
    encrypted_rows = parse_encrypted(encrypted_blob),
  )
```

The git_branch read uses `git show <ref>:<path>` to avoid
disturbing the user's working branch.

### R1.4 — Finalize_run sync write (step 9.session-sync)

NEW finalize_run sub-step (under step 5e dedicated v0.3 hooks).
Codex P1.10 dedicated step discipline.

```
finalize_run_step_9_session_sync(state, config):
  if not config.session_sync.enabled or config.session_sync.backend == "none":
    return  # no sync

  key_env = os.environ.get(config.session_sync.encryption_key_env)
  if not key_env:
    return  # already logged at pre-dispatch; skip silently here

  # 1. Update local ledger row for this machine.
  local_row = local_ledger.upsert(
    machine_id = state.machine_id,
    machine_display_name = state.machine_display_name,
    provider = current_dispatch.provider,
    session_id_hash = sha256(current_dispatch.session_id),
    last_used = now_utc(),
    expires_at = now_utc() + config.session_sync.expires_default_hours * 3600,
    status = "active",
  )

  # 2. Encrypt session_id and update encrypted blob.
  encrypted_row = encrypt_session_id(
    session_id = current_dispatch.session_id,
    key_env_value = key_env,
    repo_identity_hash = repo_identity_hash(),
    public_row = local_row,
  )
  encrypted_blob.upsert(local_row.session_id_hash, encrypted_row)

  # 3. Write local files atomically.
  atomic_write(".dtd/session-sync.md", render_ledger(local_ledger))
  atomic_write(".dtd/session-sync.encrypted", render_encrypted_blob(encrypted_blob))

  # 4. Backend-specific write.
  result = backend_write(config.session_sync.backend, ...)
  if result.failed:
    log_warn("session_sync_unreachable", reason=result.reason)
    # Connectivity != conflict: do NOT block dispatch.

  state.session_sync_last_write_at = now_utc()
```

#### `filesystem` write

```
backend_write_filesystem(sync_path, repo_id_hash):
  target_dir = f"{sync_path}/{repo_id_hash}/"
  ensure_dir(target_dir)
  copy(".dtd/session-sync.md", f"{target_dir}/session-sync.md")
  copy(".dtd/session-sync.encrypted", f"{target_dir}/session-sync.encrypted")
```

#### `git_branch` write

Branch-isolation contract (per Codex review patch in `1ab11f3`):
sync ledger files MUST be force-added only on the configured sync
branch or in an isolated worktree; never on the user's active
project branch.

```
backend_write_git_branch(sync_branch, sync_remote, commit_interval):
  # Skip if last commit < commit_interval ago.
  if (now_utc() - last_sync_commit_at) < commit_interval * 60:
    return Skipped()

  # 1. Use isolated worktree for the sync branch (does not disturb user's branch).
  worktree_path = ".dtd/tmp/session-sync-worktree/"
  if not worktree_exists(worktree_path):
    git_worktree_add(worktree_path, sync_branch)

  # 2. Copy session-sync files to worktree.
  copy(".dtd/session-sync.md", f"{worktree_path}/.dtd/session-sync.md")
  copy(".dtd/session-sync.encrypted", f"{worktree_path}/.dtd/session-sync.encrypted")

  # 3. Force-add (these files are gitignored).
  cd(worktree_path)
  git_add_force(".dtd/session-sync.md", ".dtd/session-sync.encrypted")
  git_commit(message=f"dtd session-sync update: {sha8(machine_id)} @ {iso_now()}")

  # 4. Push.
  result = git_push(sync_remote, sync_branch)
  if result.failed:
    return ConnectivityFailure(result.reason)

  state.session_sync_last_write_at = now_utc()
```

R1 doctor check `session_sync_files_staged_on_work_branch` (R0
ERROR — already added in `1ab11f3`) catches misconfigured
implementations that stage `.dtd/session-sync.*` on the user's
project branch.

### R1.5 — Conflict resolution

When `pre_dispatch_sync_read()` returns `SessionConflict`:

```
on_session_conflict(local, remote, config):
  payload = {
    provider: local.provider,
    local_machine_id: local.machine_id,
    local_session_id_hash: local.session_id_hash,
    remote_machine_id: remote.machine_id,
    remote_session_id_hash: remote.session_id_hash,
  }

  fill_capsule(
    awaiting_user_decision = true,
    awaiting_user_reason = "SESSION_CONFLICT",
    decision_id = "dec-NNN",
    decision_prompt = "Another machine has an active session for this worker/provider. Which session should DTD use?",
    pending_session_conflict = payload,
    decision_options = [
      {id: "use_local",  label: "use this machine", effect: "local session wins; remote marked superseded", risk: "remote work may diverge"},
      {id: "use_remote", label: "use remote session", effect: "decrypt remote session and resume same-worker", risk: "local session superseded"},
      {id: "fresh",      label: "fresh session", effect: "both sessions superseded; start fresh", risk: "lose session continuation"},
      {id: "stop",       label: "stop the run", effect: "finalize_run(STOPPED)", risk: "lose run progress"},
    ],
    decision_default = "fresh",  # conservative
    decision_resume_action = "controller applies selected conflict resolution; stop inherits the global destructive confirmation rule",
    user_decision_options = ["use_local", "use_remote", "fresh", "stop"],
  )
  state.pending_session_conflict = payload
  state.session_sync_pending_conflicts.append({
    provider: local.provider,
    machine_id: remote.machine_id,
    session_id_hash: remote.session_id_hash,
  })
```

`decision_resume_action` map:

| Option | On `/dtd run` resume |
|---|---|
| `use_local` | local row stays `active`; remote row marked `superseded` in local ledger; sync write at finalize_run propagates supersession. |
| `use_remote` | remote row's encrypted backing is required; remote row's `session_id` decrypted using metadata-bound AAD; local row marked `superseded`; v0.2.1 R1 strategy resolver hinted to `same-worker` with remote session_id. |
| `fresh` | both rows marked `superseded`; v0.2.1 R1 falls back to fresh strategy. |
| `stop` | finalize_run(STOPPED). |

Loser row is marked `superseded` in the synced ledger; both rows
persist for audit (no row deletion on conflict resolve).
After any non-`stop` option is applied, clear
`state.pending_session_conflict` and remove the matching conflict
entry from `state.session_sync_pending_conflicts`. On `stop`,
`finalize_run(STOPPED)` clears `pending_session_conflict` via the
terminal state cleanup while preserving the audit trail in the
session-sync ledger.

### R1.6 — Connectivity failure handling

A real `SESSION_CONFLICT` MUST create a decision capsule before
any same-session reuse (Codex additional amendment:
connectivity ≠ conflict).

A connectivity failure (network unreachable, push rejected, sync
path missing) is WARN-only:

```
on_connectivity_failure(reason):
  log_to_run_summary(f"session_sync_unreachable: {reason}")
  # Dispatch proceeds with whatever state we already have; sync is
  # retried at next finalize_run.
  # Doctor surfaces session_sync_unreachable WARN (already R0).
```

R1 doctor check `session_sync_consecutive_unreachable_count` (WARN
when count >= 5 across 5 consecutive runs) suggests user verify
backend reachability — connectivity is degraded but sync still
attempts.

### R1.7 — `/dtd session-sync` command R1 implementations

#### `/dtd session-sync show`

R0 specified the command; R1 specifies the output:

```
$ /dtd session-sync show

Session sync (backend: filesystem; enabled: true; encryption: OK):

Local ledger:
| Machine | Provider   | Hash      | Last used         | Expires at        | Status |
| laptop-A| claude-api | a3f1b9... | 2026-05-05 18:23  | 2026-05-06 14:00  | active |

Remote ledger (last sync: 2026-05-05 18:25 UTC):
| Machine  | Provider   | Hash      | Last used         | Expires at        | Status |
| desktop-B| claude-api | a3f1b9... | 2026-05-05 18:24  | 2026-05-06 14:00  | active (resumed from laptop-A) |

Pending conflicts: 0
```

#### `/dtd session-sync sync`

Triggers a manual finalize_run-style sync write. Permission-gated
under existing `tool_relay_mutating`.

#### `/dtd session-sync expire <hash>`

Marks a specific session_id_hash row as `expired`; tombstones
appended to local + synced ledger at next sync write.

#### `/dtd session-sync purge --before <date>`

Tombstones all rows whose `expires_at < <date>`. Bulk operation
preserves audit (tombstone, not physical removal).

## R1 doctor checks (additional)

```
- session_sync_decrypt_failed (WARN — runtime)
    Decryption of an encrypted_row failed (auth tag mismatch).
    Row marked corrupted; not used for resume.

- session_sync_consecutive_unreachable_count (WARN)
    5+ consecutive run finalize_run sync writes failed with
    connectivity error. Suggests backend reachability check.

- session_sync_worktree_orphan (WARN)
    .dtd/tmp/session-sync-worktree/ exists but git_branch backend
    is no longer enabled. Suggests git worktree remove.

- session_sync_encrypted_format_invalid (ERROR)
    .dtd/session-sync.encrypted has rows that don't parse to
    <hash>|<nonce>|<ciphertext>|<auth_tag> format.

- session_sync_hkdf_salt_mismatch (ERROR — runtime)
    HKDF salt = first 16 bytes of repo_identity_hash differs between
    local and remote ledgers. Repository identity changed (rehash
    needed, similar to v030a).
```

## R1 acceptance scenarios

> Scenario numbers 182-189 (next free range after v0.3.0c R1
> 174-181). See `test-scenarios.md` ## v0.3.0d R1 — Cross-machine
> session sync runtime.

```
182. AES-256-GCM encryption: encrypt_session_id() produces
     deterministic structure (nonce 12B, auth_tag 16B); decrypt
     succeeds; tampered ciphertext fails closed.
183. HKDF salt = first 16 bytes of repo_identity_hash: same project on 2
     machines with same git remote derives same key.
184. Pre-dispatch read: filesystem backend reads
     <sync_path>/<repo_id_hash>/session-sync.md; missing encrypted
     blob with rows present -> session_sync_plaintext_violation
     ERROR.
185. git_branch read uses git show <ref>:<path>: does NOT disturb
     user's working branch checkout.
186. git_branch write uses isolated worktree: force-adds session
     ledger files only on sync branch; project branch staged-files
     remain unchanged.
187. finalize_run step 9.session-sync writes encrypted blob
     atomically; partial-write failures don't corrupt ledger.
188. SESSION_CONFLICT decision_resume_action: use_remote decrypts
     remote session_id and hints v0.2.1 R1 same-worker strategy.
189. Decrypt failure (auth tag mismatch): WARN
     session_sync_decrypt_failed; row marked corrupted; resume
     falls back to fresh strategy.
```

## Migration (R1 additions)

R1 is a runtime contract; it adds these state fields:

```
state.md (additional R1):
- session_sync_consecutive_unreachable_count: 0  # R1; counter for backend reachability
- last_session_sync_decrypt_failure_at: null     # R1; ts of last decrypt failure
- pending_session_conflict: null                 # R1; durable SESSION_CONFLICT resume payload
```

No new permission keys (11-key invariant from v0.3.0c stable;
session-sync mutating sub-commands gated under
`tool_relay_mutating`).
