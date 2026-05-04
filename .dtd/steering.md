# DTD Steering Log

> Append-only. Newest entry at the bottom.
> Controller checks `state.md.steering_cursor` and reads new entries between phases / tasks.
> Low-impact entries → applied immediately as worker prompt prefix.
> Medium/high entries → trigger patch flow (see `dtd.md` "/dtd steer").

## Format

```
## YYYY-MM-DD HH:MM | <impact> | <category>
> <user phrase verbatim>
→ controller interpretation: <one line>
→ applied: <how it was applied or "patch pending">
```

## Impact categories

- **low** — style, tone, naming preference, priority hint, implementation flavor
- **medium** — task add/remove, worker change, target_grade change, timeout adjustment
- **high** — goal change, architecture change, completion criteria change

Medium and high create patches in `plan-NNN.md <patches>` and require user confirm.

## Entries

(none yet — entries appear as user steers via /dtd steer or NL phrases)

---

Last update: 2026-05-04 23:00 by claude-opus-4-7
