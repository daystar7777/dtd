# DTD help: stuck

## Summary

Use this when a run is paused on a blocking incident. Inspect the incident,
choose a recovery option, then resume.

## Quick examples

```text
/dtd status                               see compact incident line
/dtd incident show inc-001-0001           see details and options
/dtd incident resolve inc-001-0001 retry  re-dispatch same task
/dtd incident resolve inc-001-0001 switch_worker
/dtd incident resolve inc-001-0001 stop   destructive; confirms
```

## Recovery flow

1. `/dtd status` shows the active blocker:
   `| incident  inc-001-0001 blocked NETWORK_UNREACHABLE next:retry`
2. `/dtd incident show <id>` shows severity, side effects, and options.
3. `/dtd incident resolve <id> <option>` closes the decision capsule.
4. Controller resumes from the option's `decision_resume_action`.

## Common recovery options

- `retry`: re-dispatch same task.
- `switch_worker`: advance fallback chain.
- `test_worker`: run worker probe before retrying.
- `wait_once`: wait then retry for timeout/rate limit.
- `controller_takeover`: controller performs the task; mark REVIEW_REQUIRED.
- `manual_paste`: paste a manual worker result when needed.
- `stop`: terminal `finalize_run(STOPPED)`; destructive confirmation required.

## Multi-blocker

At most one blocking incident is active. Additional blockers queue in
`.dtd/log/incidents/index.md`; resolving the active one promotes the oldest
unresolved blocker.

## Next topics

- `/dtd help recover`: broader recovery surface.
- `/dtd help observe`: read-only status commands.
