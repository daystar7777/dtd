# DTD Snapshot Index

> Audit row per `.dtd/snapshots/snap-<run>-<task>-<attempt>/` entry.
> Append-only; `/dtd snapshot purge` adds a tombstone row rather than
> truncating history.
>
> Format:
>   `<applied_at> | snap-<run>-<task>-<att> | files_count | mode_default | total_size_bytes | revertable_count | status`
>
> Statuses: `active | rotated | purged | reverted`.
>
> See `dtd.md` §`/dtd snapshot` and §`/dtd revert` for command spec.
> Pre-apply snapshot creation hooks into run-loop step 6.g.0.

## Active snapshots

(Populated by run-loop apply phase. Empty on fresh install.)

## Archived snapshots

(Populated by `/dtd snapshot rotate`. Files moved to
`.dtd/snapshots/archived/snap-*/`.)

## Notes

- `mode_default` is the policy-selected default; per-file mode may
  vary (recorded in each `snap-*/manifest.md`).
- `revertable_count` = count of files with mode `preimage` or
  `patch` (mode `metadata-only` is audit-only, never revertable).
- This file is gitignored via `.dtd/.gitignore` `snapshots/` rule.
