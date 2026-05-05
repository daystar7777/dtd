# DTD reference: self-update (v0.2.0d)

> Canonical reference for `/dtd update` self-update flow.
> Lazy-loaded via `/dtd help self-update --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

Self-Update flow. Fetches latest DTD release from GitHub, verifies
via `MANIFEST.json`, runs state-schema migration, applies files
atomically, runs doctor verification, rolls back on failure.

Forms:

```text
/dtd update                         # check + preview + apply (interactive; latest)
/dtd update latest                  # explicit alias for default
/dtd update check                   # observational; show latest available
/dtd update --dry-run               # preview delta + ask confirm; no writes
/dtd update --pin <version>         # apply specific version
/dtd update --rollback              # restore from .dtd.backup-*-<ts>/
```

`/dtd update check` and `/dtd update --dry-run` are observational
reads (no writes). `/dtd update [latest|--pin]` is mutating; ALWAYS
confirms.

## Pre-update gates (before B1)

- `state.md.update_in_progress: false`. Else INFO `update_in_progress`
  and abort.
- `state.md.plan_status` is NOT `RUNNING` with `pending_patch: true`.
  Else WARN and require explicit `/dtd stop` first.
- `host.mode` is `assisted` or `full`. `plan-only` host cannot apply
  files; reject with hint to switch host capability.
- Working tree of `.dtd/` is consistent (no orphan tmp files).

## Update flow (B1-B7)

1. **B1 Lock + check** — set `state.md.update_in_progress: true`
   atomically (tmp + rename). Stale lock takeover after 30 min per
   heartbeat.
2. **B2 Fetch manifest** — HTTP GET
   `https://raw.githubusercontent.com/<repo>/<tag>/MANIFEST.json`.
   On 404: ERROR `manifest_missing` (per `manifest_required: true`).
3. **B2.5 Verify version** — compare `manifest.version` vs
   `state.md.installed_version`. If equal: print "already up to
   date" + exit. If newer: proceed.
4. **B3 Backup** — copy `.dtd/` to
   `.dtd.backup-<from>-to-<to>-<ts>/`. Record SHAs in
   `.dtd/log/update-<from>-to-<to>.md`.
5. **B3.5 State schema migration** — apply additive deltas per
   `handoff_dtd-v020d-design.claude-opus-4-7.md` Amendments 4-10.
   Use defaults from spec when adding new fields. Preserve user
   customizations. Atomic state.md write.
6. **B4 Apply files** — for each file in manifest:
   - Fetch content via tag-anchored URL.
   - Verify sha256 matches manifest entry. Mismatch → trigger B5.5.
   - Write to temp file (`<path>.dtd-tmp.<pid>`).
   - After ALL temp writes succeed: rename atomically to final paths.
7. **B5 Doctor verification** — run `/dtd doctor` post-migration.
   Any new ERROR triggers B5.5 rollback. WARN/INFO continue to B6.
8. **B5.5 Rollback** (on B4 sha mismatch / B5 doctor ERROR / any
   error):
   - Restore from `.dtd.backup-<from>-to-<to>-<ts>/`.
   - Set `update_in_progress: false`.
   - Append rollback note to update log.
   - Print failure reason + recovery hint.
9. **B6 Update state** — `state.md.installed_version: <to>`,
   `update_check_at: <now>`, `update_available: null`,
   `last_update_from: <from>`, `last_update_at: <now>`,
   `update_in_progress: false`.
10. **B7 Cleanup** — backup retention per
    `config.update.backup_retention_days` (default 7). AIMemory
    NOTE event: `dtd_updated, from=<from> to=<to>`.

## Rollback (`/dtd update --rollback`)

Restores from the most recent `.dtd.backup-*-<ts>/` directory:

1. Verify `.dtd.backup-*-<ts>/` exists and has manifest.
2. Confirm with user (this is destructive — current `.dtd/` will be
   replaced).
3. Atomic swap: rename current `.dtd/` to
   `.dtd/.dtd.rollback-victim-<ts>/`, then rename backup to `.dtd/`.
4. Set `state.md.installed_version: <prior>`.
5. AIMemory NOTE: `dtd_rollback, from=<post> to=<prior>`.

## Token / secret discipline

- `config.md.update.github_token_env` names an env var (e.g.
  `GITHUB_TOKEN`). NEVER literal token. NEVER URL token form
  (no `https://USER:TOKEN@...`).
- Update flow uses env var for private repo auth.
- Backup files exclude tokens (consistent with v0.1.1 R3
  secret-safe wizard).

## Migration log file format

`.dtd/log/update-<from>-to-<to>.md`:

```markdown
# DTD Update Log: <from> → <to>

date: <iso8601>
from_version: v0.2.0a
to_version: v0.2.0d
migration_log_format_version: 1

## Pre-update state
- workers.md SHA: <hash>
- state.md SHA: <hash>
- config.md SHA: <hash>

## Files added
- <path1>
- <path2>

## Files modified
- <path1> (lines: N → M)

## State schema migration
Added (with defaults):
- <field>: <default>

## Doctor post-update
[result]
```

## NL routing

| Phrase | Canonical |
|---|---|
| `"업데이트 해줘"` / `"최신으로 업데이트"` | `/dtd update` |
| `"업데이트 미리보기"` | `/dtd update --dry-run` |
| `"버전 확인"` | `/dtd update check` |
| `"롤백"` / `"이전 버전으로"` | `/dtd update --rollback` |

## Anchor

This file IS the canonical source for v0.2.0d `/dtd update`
self-update flow including B1-B7 atomic update steps + B5.5
rollback + pre-update gates + token discipline + migration log
format + NL routing.
v0.2.3 R1 extraction completed; `dtd.md` §`### /dtd update` now
points here.

## Related topics

- `help-system.md` — `/dtd help update` shows this in topic form.
- `doctor-checks.md` — Self-Update state checks (8) + Help system
  checks (5).
- `incidents.md` — failed updates produce incidents.
