# DTD Reference Index (v0.2.3 R1 progress)

> Lazy-load topic catalog. Each file in this directory expands a `dtd.md`
> section into a deeper reference doc. `/dtd help <topic> --full` (or
> natural-language drill-down requests) loads exactly one matching
> `.dtd/reference/<topic>.md` file.
>
> v0.2.3 R1 status: mixed canonical references and stubs. Extracted
> topics are canonical here; remaining stubs still point back to `dtd.md`
> until their R1 extraction lands.

## Topics

| Topic | Covers | Status | Source |
|---|---|---|---|
| `run-loop` | Run loop pre-dispatch + dispatch + apply phases | stub | `dtd.md` `/dtd run` |
| `incidents` | v0.2.0a Incident Tracking | canonical | `.dtd/reference/incidents.md` |
| `autonomy` | v0.2.0f decision_mode + attention_mode + silent algorithm | canonical | `.dtd/reference/autonomy.md` |
| `persona-reasoning-tools` | v0.2.0f personas + reasoning utilities + tool runtime | canonical | `.dtd/reference/persona-reasoning-tools.md` |
| `perf` | v0.2.0f /dtd perf + ctx file format + controller usage ledger | canonical | `.dtd/reference/perf.md` |
| `workers` | Worker registry + dispatch + health check | stub | `dtd.md` Worker Registry & Routing |
| `plan-schema` | Plan XML schema + size budget | stub | `dtd.md` Plan Schema (XML) |
| `status-dashboard` | Status rendering rules + glyph reference | canonical | `.dtd/reference/status-dashboard.md` |
| `self-update` | v0.2.0d /dtd update + B1-B7 flow | stub | `dtd.md` `/dtd update` |
| `help-system` | v0.2.0d /dtd help + topic resolution | canonical | `.dtd/reference/help-system.md` |
| `doctor-checks` | All doctor checks across sub-releases | canonical | `.dtd/reference/doctor-checks.md` |
| `roadmap` | v0.2 sub-release tree | canonical | `.dtd/reference/roadmap.md` |
| `load-profile` | v0.2.3 controller cognitive scoping | canonical | `.dtd/reference/load-profile.md` |

## Extraction Rationale

v0.2.3 avoids moving all long-form spec text out of `dtd.md` in one
high-risk commit.

- R0 landed the reference directory, index, and 13 reference topics.
- R1 extracts one topic at a time, leaving a compact `dtd.md` summary and
  moving full canonical detail to the matching reference file.
- Each extracted topic keeps an `Anchor` section so doctor/help/reviewers can
  tell whether the reference file is canonical or still a stub.

## Lazy-load Policy

Reference docs are loaded ONLY when:

- User runs `/dtd help <topic> --full`.
- A plan, run, recovery, or doctor action explicitly needs deeper rules for
  one topic. Load only that topic, then return to the compact profile.
- A maintainer/reviewer is checking extraction equivalence.

Reference docs are NOT loaded for ordinary observational reads:

- `/dtd status`, `/dtd plan show`, `/dtd perf`, and default `/dtd help`.
- Worker dispatch prompts; workers receive resolved compact capsules only.
- Routine `/dtd run` turns when `.dtd/instructions.md` plus the compact
  `dtd.md` summary already contain enough policy.
