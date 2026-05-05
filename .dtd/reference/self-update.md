# DTD reference: self-update (v0.2.0d)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §`/dtd update`.

## Summary

`/dtd update [check|--dry-run|<version>|--rollback]` self-updates DTD
from GitHub. Atomic: backup → migrate state schema → temp-write all files
→ rename atomically → run doctor → on failure roll back.

```text
/dtd update check         observational; query latest tag
/dtd update --dry-run     observational; preview delta
/dtd update [<version>]   apply (mutating; ALWAYS confirms)
/dtd update --rollback    restore from backup (destructive)
```

## Update flow (B1-B7)

1. B1 Lock: `state.md.update_in_progress: true` atomically.
2. B2 Fetch manifest: HTTP GET `MANIFEST.json` from target tag.
3. B2.5 Verify version delta.
4. B3 Backup: `.dtd/` → `.dtd.backup-<from>-to-<to>-<ts>/`.
5. B3.5 State schema migration (additive only; preserves user data).
6. B4 Apply files: temp-write all + rename atomically.
7. B5 Doctor verification: ERROR triggers B5.5 rollback.
8. B5.5 Rollback (on failure): restore backup, clear lock.
9. B6 Update state: installed_version, last_update_*.
10. B7 Cleanup: backup retention; AIMemory NOTE event.

## Token discipline

- `config.md.update.github_token_env` names env var; NEVER literal.
- NEVER URL token form (`https://USER:TOKEN@...`).
- Backup files exclude tokens (consistent with v0.1.1 R3 secret-safe wizard).

## Anchor

See `dtd.md` §`### /dtd update` for full B1-B7 flow, B5.5 rollback,
migration log format, NL routing, scenarios 86-93.

## Related topics

- `help-system.md` — `/dtd help update` shows this in topic form.
- `doctor-checks.md` — Self-Update state checks (8) + Help system checks (5).
