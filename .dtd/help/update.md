# DTD help: update

## Summary

Self-Update flow (v0.2.0d). Fetches latest DTD release from GitHub,
verifies via `MANIFEST.json`, runs state-schema migration, applies
files atomically, runs doctor verification, rolls back on failure.

## Quick examples

```text
/dtd update check                see latest available version
/dtd update --dry-run            preview file changes + state migrations
/dtd update                      apply with explicit confirm
/dtd update --pin <version>      stay on a specific version
```

## Canonical commands

- `/dtd update check` — observational; queries GitHub for latest tag.
- `/dtd update --dry-run` — observational; previews delta + asks confirm.
- `/dtd update [<version>]` — applies (defaults to latest). Confirm required.
- `/dtd update --rollback` — restore from `.dtd.backup-*-*-<ts>/`.

## Update flow (B1-B7)

1. **B1 Lock + check** — `state.md.update_in_progress: true` atomically.
2. **B2 Fetch manifest** — HTTP GET MANIFEST.json from target tag.
3. **B2.5 Verify version** — compare `installed_version` vs target.
4. **B3 Backup** — copy `.dtd/` to `.dtd.backup-<from>-to-<to>-<ts>/`.
5. **B3.5 State schema migration** — apply additive deltas per spec.
6. **B4 Apply files** — temp-write + atomic rename per file.
7. **B5 Doctor verification** — run `/dtd doctor`; ERROR triggers B5.5 rollback.
8. **B5.5 Rollback** (on failure) — restore from backup, clear lock.
9. **B6 Update state** — `installed_version`, `update_check_at`, etc.
10. **B7 Cleanup** — backup retention; AIMemory NOTE event.

## State / config fields

state.md `Self-Update state (v0.2.0d)`:
- `installed_version` — e.g. `v0.2.0d`
- `update_check_at`, `update_available`, `update_in_progress`
- `last_update_from`, `last_update_at`

config.md `update (v0.2.0d)`:
- `check_on_install: true`
- `check_interval_days: 7`
- `github_repo: daystar7777/dtd`
- `github_token_env: GITHUB_TOKEN` (env var name; never literal)
- `manifest_required: true`

## Safety invariants

- Never auto-applies without user confirm.
- Never overwrites `workers.md` / user customizations / project files.
- MANIFEST sha256 verified before any file write.
- Atomic: phase 1 write all temps, phase 2 rename all (per apply spec).
- Rollback restores the full `.dtd/` from backup on any error.

## NL phrases

- `"업데이트 해줘"` / `"최신으로 업데이트"` → `/dtd update`
- `"업데이트 미리보기"` → `/dtd update --dry-run`
- `"버전 확인"` → `/dtd update check`

## Next topics

- `/dtd help start` — first-run flow.
- `/dtd help observe` — `/dtd doctor` runs after update.
