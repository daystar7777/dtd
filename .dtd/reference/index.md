# DTD Reference Index (v0.2.3 R0 scaffold)

> Lazy-load topic catalog. Each file in this directory expands a section
> of `dtd.md` into a deeper reference doc. `/dtd help <topic>` reads
> `.dtd/help/<topic>.md` for the layered overview; `/dtd help <topic>
> --full` (or NL drill-down requests) read this directory's `<topic>.md`
> for the full reference.
>
> v0.2.3 R0 status: **scaffold + summaries**. Full content extraction
> from `dtd.md` lands in v0.2.3 R1+. Until then, each reference file
> here is a Summary + an `dtd.md` anchor link.

## Topics

| Topic | Covers | Source-of-truth (today) |
|---|---|---|
| `run-loop` | Run loop pre-dispatch + dispatch + apply phases | `dtd.md` §`/dtd run` |
| `incidents` | v0.2.0a Incident Tracking | `dtd.md` §Incident Tracking |
| `autonomy` | v0.2.0f decision_mode + attention_mode + silent algorithm | `dtd.md` §Autonomy & Attention Modes |
| `persona-reasoning-tools` | v0.2.0f personas + reasoning utilities + tool runtime | `dtd.md` §Persona, Reasoning, and Tool-Use Patterns |
| `perf` | v0.2.0f /dtd perf + ctx file format + controller usage ledger | `dtd.md` §`/dtd perf` |
| `workers` | Worker registry + dispatch + health check | `dtd.md` §Worker Registry & Routing |
| `plan-schema` | Plan XML schema + size budget | `dtd.md` §Plan Schema (XML) |
| `status-dashboard` | Status rendering rules + glyph reference | `dtd.md` §Status Dashboard |
| `self-update` | v0.2.0d /dtd update + B1-B7 flow | `dtd.md` §`/dtd update` |
| `help-system` | v0.2.0d /dtd help + topic resolution | `dtd.md` §`/dtd help` |
| `doctor-checks` | All doctor checks across sub-releases | `dtd.md` §`/dtd doctor` |
| `roadmap` | v0.2 sub-release tree | `dtd.md` §v0.1.1 / v0.2 Roadmap |

## Scaffold rationale

v0.2.3 R0 is intentionally a SCAFFOLD-ONLY commit:

- Risk: pulling 1800+ lines out of `dtd.md` in one commit could lose
  content or break section anchors. SHA-equivalence verification
  (per the v0.2.3 design Amendment 10 in v0.2.0d) needs careful
  per-topic extraction.
- Approach: R0 lands the directory + 12 topic stubs that point at
  `dtd.md` sections via the "Source-of-truth (today)" column. R1+
  moves content from `dtd.md` into each reference file, replacing
  the dtd.md sections with topic links.
- Lazy-load already works: hosts that fetch only `.dtd/instructions.md`
  (always-loaded) plus `dtd.md` (router + canonical actions) skip this
  reference directory entirely. Drilling into `/dtd help <topic> --full`
  loads ONE reference file at a time.

## Lazy-load policy

Reference docs are loaded ONLY when:
- User runs `/dtd help <topic> --full`.
- A `/dtd plan` action specifically requires deeper context for the topic.
- Doctor needs the topic-specific checks (rare).

NEVER load reference docs:
- During `/dtd status`, `/dtd plan show`, `/dtd perf`, default `/dtd help` (≤25 lines).
- During worker dispatch (workers see only the resolved compact capsule).
- During `/dtd run` loop (controller uses `instructions.md` for rules).
