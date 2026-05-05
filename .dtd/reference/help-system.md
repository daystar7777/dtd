# DTD reference: help-system (v0.2.0d)

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §`/dtd help`.

## Summary

`/dtd help [topic] [--full]` is a layered help system. Default ≤ 25
lines (overview from `.dtd/help/index.md`). Topic detail ≤ 50 lines
(Summary + Quick examples from `.dtd/help/<topic>.md`). `--full` reads
the full topic file.

v0.2.3 R0+ adds drilling: `/dtd help <topic> --full` may also load the
deeper `.dtd/reference/<topic>.md` reference for the full canonical
spec extraction.

## Topic resolution algorithm

1. Parse user input: `/dtd help [topic] [--full]`.
2. If no topic: render `.dtd/help/index.md` (≤ 25 lines).
3. If `.dtd/help/<topic>.md` exists: render Summary + Quick examples
   (≤ 50 lines unless `--full`).
4. Else: search `.dtd/help/*.md` filename + summary; show top 3 matches.
5. Else: print full topic catalog.

## Canonical topics (v0.2.0d)

`start`, `observe`, `recover`, `workers`, `stuck`, `update`, `plan`,
`run`, `steer`. Plus `index` (catalog).

## Output discipline

`observational_read` per `instructions.md` §Status read isolation.
NEVER mutates `state.md`, `notepad.md`, `phase-history.md`,
`attempts/run-NNN.md`. Static template render — no LLM generation.

## Anchor

See `dtd.md` §`### /dtd help` for full topic resolution algorithm,
canonical topics, topic file structure, NL routing, scenarios 91-93.

## Related topics

- `self-update.md` — `/dtd help update` shows update topic.
- `doctor-checks.md` — Help system checks (5).
