# Project Context Capsule

> Sent to every worker call as part of the prompt prefix. Keep tight.
> Read by controller at WORK_START, included in worker prompts after
> `worker-system.md` (provider prompt cache friendly position).
>
> ⚠️ **Fill this in before running in `assisted` or `full` mode.**
> If left as TODO-only, workers receive empty project context and
> produce generic output. `/dtd doctor` WARNs when TODO placeholders
> remain and `host_mode` is `assisted` or `full`.
>
> If this gets large, prefer creating `.dtd/skills/<topic>.md` rather
> than expanding here. Workers don't need every detail every call.

## What is this project?

(TODO: 2-4 sentences. What it does, who uses it, why it exists.)

## Tech stack

- (TODO: language, frameworks, key libraries — bullet form)
- (TODO: build tool, test runner, deploy target)

## Conventions

- (TODO: naming, file layout, comment style)
- (TODO: testing requirements — unit/integration coverage expectations)
- (TODO: error-handling patterns)

## Don't do these

- (TODO: e.g., no new dependencies without prior approval)
- (TODO: e.g., no `console.log` in committed code; use the logger)
- (TODO: e.g., no breaking API changes without a migration plan)

## Reference paths

- Source: `src/`
- Tests: `tests/` or `<colocated>`
- Docs: `docs/`
- Configs: `config/`, root-level dotfiles

## Recent context (controller may update)

(none yet)

---

Last update: 2026-05-04 by setup
Worker calls embed this as cache-friendly prefix (along with worker-system.md and skills).
