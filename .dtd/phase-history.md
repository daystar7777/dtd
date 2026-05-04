# DTD Phase History

> Compact one-row-per-phase log. Append on every phase boundary
> (pass / retry / fail / escalation / block).
> Detailed evals are written separately to `.dtd/eval/eval-<run>-phase-<P>-iter-<I>.md`
> only on retry/escalation/block/fail/BEST-claim — not for clean GOOD/GREAT passes.

## Format

| # | Run | Phase    | Workers           | Started        | Dur   | Iter | Grade | Gate    | Output paths              | Note          |
|---|-----|----------|-------------------|----------------|-------|------|-------|---------|---------------------------|---------------|
| 1 | 001 | planning | 큐엔              | 2026-05-04 19:50 | 30s   | 1    | GREAT | pass    | docs/schema.md            | clean         |

Gate values: `pass`, `retry`, `escalated:tier2`, `escalated:reviewer`, `escalated:controller`, `escalated:user`, `failed`, `blocked`.

## Entries

# Empty — entries appear after first phase completes.

| # | Run | Phase | Workers | Started | Dur | Iter | Grade | Gate | Output paths | Note |
|---|-----|-------|---------|---------|-----|------|-------|------|--------------|------|

---

Last update: 2026-05-04 23:00 by claude-opus-4-7
