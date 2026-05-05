# DTD help: steer

## Summary

Steering changes plan direction mid-run. Low-impact steering applies
as a prompt prefix; medium/high-impact creates a pending patch that
needs explicit approval. Patches apply only between tasks.

## Quick examples

```text
/dtd steer "use camelCase for variables"          low-impact prefix
/dtd steer "drop tasks 5,6 — out of scope"        medium-impact patch
/dtd steer "add reviewer phase before deploy"     high-impact patch
```

## Canonical commands

- `/dtd steer <instruction>` — append + classify + patch if medium/high.

## Steering flow

1. Append entry to `.dtd/steering.md` (raw + interpretation).
2. Classify impact: `low | medium | high`.
3. **low**: prefix to upcoming worker prompts; no patch, no confirm.
4. **medium / high**: create patch in `plan-NNN.md <patches>` section.
   - Set `state.md.pending_patch: true`.
   - Display patch + ask: `approve | reject`.
5. RUNNING continues in-flight task; new dispatch waits until patch resolved.
6. On `approve`: apply to plan body; resume.
7. On `reject`: discard patch; entry preserved in `steering.md`.

Patch application only between tasks. Never mutate a worker call mid-flight.

## Impact classification heuristics

| Impact | Examples |
|---|---|
| low | naming conventions, minor style, comment additions |
| medium | task removal, worker swap, output-path tweak |
| high | new phase, target-grade change, scope expansion |

## NL phrases

- `"방향 바꾸자"` / `"이번엔 안정성 우선"` → `/dtd steer <text>`
- `"task N 빼"` → high or medium impact depending on phase
- `"camelCase로"` → low impact

## Pending patch state

When `state.md.pending_patch: true`:
- Run loop refuses new dispatches.
- `/dtd status` shows pending patch summary.
- User must `approve` or `reject` to clear.

## Next topics

- `/dtd help plan` — DRAFT-time plan changes.
- `/dtd help run` — bounded execution.
