# DTD reference: help-system (v0.2.0d)

> Canonical reference for `/dtd help` topic system.
> Lazy-loaded via `/dtd help help-system --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

Layered help system. `/dtd help` (no arg) shows ≤ 25-line lifecycle
overview. `/dtd help <topic>` shows ≤ 50-line topic detail. `--full`
prints the entire reference for that topic.

Forms:

```text
/dtd help                  default: ≤ 25-line overview from .dtd/help/index.md
/dtd help <topic>          ≤ 50-line topic detail from .dtd/help/<topic>.md
/dtd help <topic> --full   full topic file (no Summary/Quick examples extract)
```

## Topic resolution algorithm

1. Parse user input: `/dtd help [topic] [--full]`.
2. If no topic: render `.dtd/help/index.md` (≤ 25 lines).
3. If topic exists in `.dtd/help/<topic>.md`: render that file's
   "Summary" + "Quick examples" sections (≤ 50 lines unless `--full`).
4. Else: search `.dtd/help/*.md` for keyword match (case-insensitive
   on filename + summary line). Show top 3 candidate topics:
   ```
   No topic 'foo'. Did you mean:
   | start    first-run flow
   | workers  worker registry + basic test
   | help     show available topics
   ```
5. Else: show full topic list from `.dtd/help/index.md`.

### v0.2.3 reference-topic extension

- If `--full` and `.dtd/reference/<topic>.md` exists, render that ONE
  reference file. Do not load `dtd.md` or other reference files.
- If a topic exists only in `.dtd/reference/<topic>.md`, default
  `/dtd help <topic>` renders the one-line summary from
  `.dtd/reference/index.md` and hints:
  `Run /dtd help <topic> --full for the reference file.`
- Unknown-topic search includes both `.dtd/help/*.md` and
  `.dtd/reference/index.md`.

## Canonical topics (v0.2.0d set)

| Topic | Covers |
|---|---|
| `start` | first-run flow |
| `observe` | read-only commands |
| `recover` | when stuck |
| `workers` | worker registry + basic test |
| `stuck` | incident-specific recovery |
| `update` | self-update flow |
| `plan` | planning commands |
| `run` | running + bounded execution |
| `steer` | steering / patches |

Plus `index` (catalog).

## Topic file structure

Each `.dtd/help/<topic>.md`:

```markdown
# DTD help: <topic>

## Summary
(1-2 paragraphs)

## Quick examples
(3-5 code blocks)

## Canonical commands
(slash command spec)

## State / config fields
(field list with defaults)

## NL phrases
(Korean/mixed examples)

## Next topics
(related topic links)
```

Each file ≤ 2 KB. `.dtd/help/index.md` ≤ 1 KB.

## Output discipline (observational read)

- Classified as `observational_read` per `instructions.md` §Status
  read isolation.
- Help output never appends to `notepad.md`, `phase-history.md`, or
  `attempts/run-NNN.md`.
- Help output never writes to `state.md`.
- Help output is rendered from a static template — no LLM generation,
  no dynamic prompt — so it is also free.

## NL routing (per locale pack)

| Phrase | Canonical |
|---|---|
| `"도움말"` / `"help"` | `/dtd help` |
| `"워커 도움말"` / `"help workers"` | `/dtd help workers` |
| `"막혔을 때"` / `"help stuck"` | `/dtd help stuck` |
| `"업데이트 도움말"` / `"help update"` | `/dtd help update` |

## Anchor

This file IS the canonical source for v0.2.0d `/dtd help` command +
topic resolution + canonical topics + file structure + output
discipline + NL routing.
v0.2.3 R1 extraction completed; `dtd.md` §`### /dtd help` now points
here.

## Related topics

- `self-update.md` — `/dtd help update` shows update topic.
- `doctor-checks.md` — Help system checks (5).
- `index.md` (this dir) — v0.2.3 reference-topic catalog.
