# DTD Active Resource Leases

> Append on lease acquire, remove on release. Heartbeat updates `heartbeat_at`.
> Atomic operations only (single shell heredoc per write).
> See `dtd.md` "Resource Locks" for the 7-step lifecycle.

## Lifecycle reference (read-only — do not edit this section)

```
1. Normalize paths
   - relative path  → files:project:<path>  (e.g. files:project:src/api/**)
   - absolute path  → files:global:<path>   (e.g. files:global:/tmp/build/)
   Canonical resource string: <type>:<namespace>:<path>
   For v0.1, type is always "files". Future: ports, db, process.
2. Compute lock set (output-paths + explicit <resources>)
3. Check overlap (scan active leases below)
4. Acquire lease (append H2 entry below)
5. Heartbeat (update heartbeat_at periodically; best-effort in plan-only/blocking-shell)
6. Release (remove H2 entry on success/failure/blocked)
7. Stale takeover (heartbeat_at older than stale_threshold → user confirm required, NEVER auto)
```

Overlap rules:

| existing \ new | read | write | exclusive |
|---|---|---|---|
| read | OK (multi-reader) | block | block |
| write | block | block | block |
| exclusive | block | block | block |

Path overlap: literal⊆literal exact, literal⊆glob via match, glob⊆glob via specialization (conservative).

## Active leases

# Empty registry — no active workers. Entries appear here when /dtd run dispatches a task.
# Each lease is a single H2 section, format:
#
#   ## lease-<run_id>-<task_id>-<seq>
#   - worker: <worker_id>
#   - task: <task_id>
#   - run_id: <run_id>
#   - mode: read | write | exclusive
#   - paths:
#       - files:project:src/api/**   # relative path (project-scoped)
#       - files:global:/tmp/build/   # absolute path (best-effort cross-process)
#   - acquired_at: <UTC ISO8601>
#   - heartbeat_at: <UTC ISO8601>
#   - notes: <optional>

(none)

---

Last cleared: 2026-05-04 23:00 by claude-opus-4-7
