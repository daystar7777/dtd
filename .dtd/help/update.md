# DTD help: update

## Summary

Self-update checks DTD releases, verifies `MANIFEST.json`, migrates additive
state/config fields, applies files atomically, runs doctor, and rolls back on
failure.

## Quick examples

```text
/dtd update check             see latest available version
/dtd update --dry-run         preview files and migrations
/dtd update                   apply latest after confirm
/dtd update --pin v0.2.0d     apply a specific version
/dtd update --rollback        restore latest backup after confirm
```

## Canonical commands

- `check` and `--dry-run` are observational: no local writes, no state update.
- `/dtd update [<version>]` mutates files and always asks for confirmation.
- `--rollback` restores from `.dtd.backup-*-<ts>/` after confirmation.

## Update flow (B1-B7)

1. B1: set `state.md.update_in_progress: true` atomically.
2. B2: fetch tag-anchored `MANIFEST.json`.
3. B2.5: compare `installed_version` with target.
4. B3: copy `.dtd/` to `.dtd.backup-<from>-to-<to>-<ts>/`.
5. B3.5: add missing state/config fields; preserve user edits.
6. B4: fetch, sha256-check, temp-write all files, then rename.
7. B5: run `/dtd doctor`; ERROR triggers rollback.
8. B5.5: restore backup, clear lock, print recovery hint.
9. B6: update version/check fields and clear lock.
10. B7: enforce backup retention; append AIMemory NOTE.

## Safety

- Never overwrites `.dtd/workers.md`, `.dtd/.env`, or project source files.
- GitHub tokens are referenced by env-var name only.
- Manifest sha must match before any final rename.
- Any apply/doctor failure restores the backup and clears the update lock.

## Next topics

- `/dtd help start`: first-run flow.
- `/dtd help observe`: status and doctor checks.
