# DTD reference: roadmap

> v0.2.3 R0 scaffold. Full content extraction lands in R1+.
> Source-of-truth today: `dtd.md` §v0.1.1 / v0.2 Roadmap.

## Summary

Released:
- **v0.1** — first lock; 18/18 acceptance smoke (2026-05-05).
- **v0.1.1** — 5 R-rounds; ops hardening hooks (2026-05-05).
- **v0.2.0a** — Incident Tracking; **TAGGED 2026-05-05** (`41f8c7d`).

In progress / R0-ready:
- **v0.2.0d** — Self-Update + `/dtd help`. R0 implemented (`29011f6`),
  Codex GO accepted (`c451768`). Ready for tag once user authorizes.
- **v0.2.0f** — Autonomy & Attention + persona/reasoning/tool-runtime.
  Implementation in spec/state/config/scenarios; release contracts
  82/82 PASS. Ready for tag once user authorizes.

R0 designed (not implemented):
- **v0.2.0e** — Locale Packs (English-only core + opt-in /ㄷㅌㄷ pack).
- **v0.2.0b** — Permission Ledger (.dtd/permissions.md ask/allow/deny + tool_relay_*).
- **v0.2.0c** — Snapshot/Revert (3-mode taxonomy: metadata-only / preimage / patch).
- **v0.2.1** — Runtime Resilience (worker health check + session resume + loop guard).
- **v0.2.2** — Compaction UX (notepad v2 8-heading + Reasoning Notes).
- **v0.2.3** — Spec modularization (THIS doc; static markdown split + lazy-load).

## Implementation order (per dependency graph)

1. v0.2.0a — TAGGED ✓
2. v0.2.0d — Self-Update (migration runway for v0.2.0e+)
3. v0.2.0f — Autonomy & Attention (uses v0.2.0d migration)
4. v0.2.0e — Locale Packs (after v0.2.0d)
5. v0.2.0b — Permission Ledger (foundation for v0.2.0c)
6. v0.2.0c — Snapshot/Revert (uses v0.2.0b permission gating)
7. v0.2.1 — Runtime Resilience
8. v0.2.2 — Compaction UX
9. v0.2.3 — Spec modularization (parallelizable with v0.2.2)

## Anchor

See `dtd.md` §`## v0.1.1 / v0.2 Roadmap (declared, not implemented)`
for full sub-release tree, dependencies, AIMemory archive references.

## Related topics

- `self-update.md` — v0.2.0d migration runway.
- `autonomy.md` — v0.2.0f sleep-friendly autonomy.
- `index.md` (this dir) — v0.2.3 scaffold structure.
