# DTD reference: doctor-checks

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §`/dtd doctor`.

## Summary

`/dtd doctor` runs ~91 checks across the v0.2 line:

- **v0.1 baseline** (~25 checks): install integrity, mode consistency,
  worker registry, agent-work-mem, project context, resource state,
  plan state, path policy, .gitignore + secret leak.
- **v0.2.0a Incident state** (7 checks): incident file existence,
  multi-blocker invariant, cross-link integrity, secret-leak scan.
- **v0.2.0f Autonomy & Attention** (8 checks): decision_mode validity,
  attention_until future-stamp, deferred_decision_refs validity,
  CONTROLLER_TOKEN_EXHAUSTED capsule schema.
- **v0.2.0f Context-pattern** (~6+ checks): resolved_*_pattern validity,
  plan XML attribute validity, ctx file count vs attempt count.
- **v0.2.0d Self-Update** (8 checks): installed_version, update_in_progress
  staleness, MANIFEST.json validity, update_check_at freshness.
- **v0.2.0d Help system** (5 checks): help dir existence, all 9 canonical
  topics present, file size budgets.

## Output

```text
[Install integrity]            ✓ 15/15 templates + dtd.md
[Mode consistency]             ✓ state.md mode=dtd host_mode=full
[Worker registry]              ✓ 3 active workers
...
verdict: 0 ERROR / 0 WARN / 1 INFO
```

Exit code: 0 if all checks pass, 1 if any ERROR.

Flags (planned):
- `--verbose` — show all checks
- `--section <name>` — run one section
- `--takeover` — explicit lease takeover for stale leases
- `--json` — machine-readable summary

## Anchor

See `dtd.md` §`### /dtd doctor` for full check list per section.

Also see `AIMemory/REFERENCE_doctor-checks-consolidated.claude-opus-4-7.md`
for the cross-sub-release consolidated list (~91 checks).

## Related topics

- `incidents.md` — incident-state checks.
- `autonomy.md` — autonomy/attention/context-pattern checks.
- `self-update.md` — Self-Update + Help system checks.
