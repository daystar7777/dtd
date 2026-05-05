# DTD reference: roadmap

> Canonical reference for v0.1.1 / v0.2 / v0.3 roadmap.
> Lazy-loaded via `/dtd help roadmap --full`. Not auto-loaded.
> v0.2.3 R1 extraction from `dtd.md` (single-source).

## Summary

v0.1 / v0.1.1 / v0.2.0a tagged; rest of v0.2 line release-ready
or R0+R1 complete pending user tag authorization.
v0.3 line **GO at R0 + R1 across all 5 sub-releases**.
Codex final review pass accepted (handoff
`handoff_dtd-v030c-v030d-r1-codex-review.gpt-5-codex.md` 2026-05-06
01:20). All R0 + R1 patches integrated through `07fc465`. Tagging
pending user authorization. Residual risk: R2 = live DTD run
against a nontrivial test project.

Released:
- **v0.1** — first lock; 18/18 acceptance smoke (2026-05-05).
- **v0.1.1** — 5 R-rounds; ops hardening hooks (2026-05-05).
- **v0.2.0a** — Incident Tracking; TAGGED 2026-05-05 (`41f8c7d`).

Release-ready (release-contract-passing; tag pending user auth):
- **v0.2.0d** — Self-Update + `/dtd help`.
- **v0.2.0f** — Autonomy & Attention + persona/reasoning/tool-runtime.
- **v0.2.3** — Spec modularization + Lazy-Load Profile.

R0 + R1 complete (Codex GO accepted; tag pending user auth):
- **v0.2.0e** — Locale Packs (English-only core + opt-in /ㄷㅌㄷ pack).
- **v0.2.0b** — Permission Ledger (`.dtd/permissions.md` 10-key set
  with `tool_relay_*`; specificity-first resolution).
- **v0.2.0c** — Snapshot/Revert (3-mode taxonomy: metadata-only /
  preimage / patch; revert is permission-gated).
- **v0.2.1** — Runtime Resilience (worker health check 17-stage +
  session resume 4-strategy + loop guard with window staleness).
- **v0.2.2** — Compaction UX (notepad v2 8-heading + Reasoning Notes
  + chain-of-thought leak filter).

v0.3 line — Path A (e → b → a → c → d) execution status —
**ALL FIVE GO at R0 + R1**:
- **v0.3.0e** — Time-limited permissions UX. R0 GO (`19bf3f1`);
  R1 (`ea5fd09`) review-passed (Codex `1ab11f3`).
- **v0.3.0b** — Token-rate-aware scheduling. R0 GO (`19bf3f1`);
  R1 (`d431c57`) review-passed (Codex `1ab11f3`).
- **v0.3.0a** — Cross-run loop guard. R0 with P1.1 + P1.7 inline
  (`0681088`); R1 (`e67b10b`) review-passed (Codex `1ab11f3`).
- **v0.3.0c** — Multi-worker consensus dispatch. R0 with P1.4 +
  P1.5 inline (`be948b5`) review-passed (Codex `1ab11f3`);
  R1 (`257210a`) review-passed (Codex `07fc465`).
- **v0.3.0d** — Cross-machine session affinity. R0 with P1.6 + P1.7
  inline (`6013ac2`) review-passed (Codex `1ab11f3`);
  R1 (`0aacd5a`) review-passed (Codex `07fc465`).

Per-sub-release reference topic pattern (Codex's recommendation):
catalog grew from 13 to 18 across v0.3 R0/R1, with R2 adding the
19th runtime-validation topic:
- `v030a-cross-run-loop-guard.md` (R0 + R1)
- `v030c-consensus.md` (R0 + R1)
- `v030d-cross-machine-session-sync.md` (R0 + R1)
- `v030e-time-limited-permissions.md` (R1 dedicated)
- `v030b-quota-scheduling.md` (R1 dedicated)

R2 (Codex's residual risk): live DTD run against a nontrivial test
project to exercise consensus staging, worker cancellation,
git-branch sync, and session conflict recovery end-to-end. Defined
in `.dtd/reference/v030-r2-live-test-plan.md` and ready for
user-driven execution (session #11).

## v0.1.1

- **Notepad UX enhancements** — minimal notepad already shipped in v0.1.
  v0.1.1 adds: search across `.dtd/runs/run-*-notepad.md` archive,
  structured `<learnings>` extraction across runs, and
  `/dtd notepad show <run-id>` query command.
- **README polish + setup walkthrough** with screenshots / animated flow.
- **`/dtd plan show --explain` mode** for first-time users
  (line-by-line plan walkthrough).

## v0.2 — Operations hardening + lifecycle

Revised v0.2 sub-release tree (from v0.2 design R1 + v0.2.0d addendum):

```
v0.2.0a   Incident Tracking       TAGGED 2026-05-05 (commit 41f8c7d)
v0.2.0d   Self-Update              /dtd update — fetch latest from github with diff preview
                                    (NEW per user request; ships after 0a, before 0b/0c).
                                    Includes: state-schema migration step (also migrates
                                    to v0.2.0f schema additions, see Amendment 4),
                                    env-var-only token (never URL forms),
                                    MANIFEST.json verification,
                                    /dtd help topic system (per user-journey audit),
                                    user journey scenarios 31, 32, 36-40, 42 added with this release.
v0.2.0f   Autonomy & Attention    (NEW; sleep-friendly autonomy; ships after v0.2.0d so
                                    users can update tooling into the new state/config schema):
                                    decision_mode (plan|permission|auto),
                                    attention_mode (interactive|silent),
                                    /dtd run --silent=<duration> | --decision <mode>,
                                    /dtd silent on|off, /dtd interactive,
                                    /dtd mode decision <plan|permission|auto>,
                                    context-pattern (fresh|explore|debug) per phase/task,
                                    /dtd perf [--phase|--worker|--tokens|--cost] (separate
                                    controller vs worker token reporting),
                                    decision capsule reason CONTROLLER_TOKEN_EXHAUSTED,
                                    morning-summary on silent-window end,
                                    silent_deferred_decision_limit hard cap.
                                    Adds 11 acceptance scenarios (22q/r + 23a-i)
                                    plus user journey 43.
v0.2.0e   Locale Packs            (NEW; core prompts English-only, optional /dtd locale enable ko
                                    pack ships Korean NL + /ㄷㅌㄷ alias examples; ships after 0d.
                                    User journey scenario 41 added with this release.)
v0.2.0b   Permission Ledger       (.dtd/permissions.md ask|allow|deny)
v0.2.0c   Snapshot / Revert       (.dtd/snapshots/ + /dtd revert)
v0.2.1    Runtime Resilience      loop guard + worker session resume + Worker Health Check
                                    (per worker-healthcheck design note).
                                    /dtd workers test [--all|--quick|--full|--connectivity|--assigned|--json]
                                    14 stage diagnostic log + WORKER_* failure taxonomy,
                                    decision capsule WORKER_HEALTH_FAILED.
                                    User journey scenarios 33-35 added with this release.
v0.2.2    Compaction UX           notepad v2 8-heading (Goal/Constraints/
                                    Progress/Decisions/Next Steps/Critical Context/
                                    Relevant Files/Reasoning Notes — last added
                                    per v0.2.0f follow-up Codex P2 for compact
                                    rationale storage from reasoning utilities).
v0.2.3    Spec modularization     dtd.md split into router + .dtd/reference/<topic>.md
                                    files. Reduces always-load token cost for hosts
                                    that fetch dtd.md. Lazy-load policy: reference
                                    docs loaded only on /dtd help <topic> or
                                    explicit topic drilling. (NEW per Codex v0.2.0f
                                    follow-up P2; lowest priority of v0.2 line.)
```

Each sub-release goes through full R-round flow
(design → review → patches → GO → tag).

These are spec'd in detail in (in AIMemory archive):
- `handoff_dtd-v011-spec-design.gpt-5-codex.md` (V011-1~9)
- `handoff_dtd-v011-ops-recovery-status.gpt-5-codex.md` (V011-Ops-1~10)
- `handoff_dtd-v02-design-r1.claude-opus-4-7.md` (sequence revision)
- `handoff_dtd-v020d-design.claude-opus-4-7.md` (Self-Update addendum)
- `handoff_dtd-worker-healthcheck-design-note.gpt-5-codex.md`
  (v0.2.1 worker check design)
- `handoff_dtd-user-journey-doc-test-audit.gpt-5-codex.md`
  (journey scenarios 31-42, sub-release placement)

v0.1.1 has hooks (decision capsule structure, state field
placeholders); v0.2 implements the full systems.

## v0.1.1 / v0.2 detailed feature notes

- **Permission Decision Ledger** (V011-1): `.dtd/permissions.md` with
  ask|allow|deny rules per
  `edit/bash/external_directory/task/snapshot/revert/tool_relay_read/
  tool_relay_mutating/todowrite/question` keys.
  `/dtd permission list/show/allow/deny/ask/revoke/rules` commands. Pending
  request capsule in state.md (already partially in v0.1.1 decision
  capsule).
- **Structured Notepad v2 handoff** (V011-2): 8-heading `<handoff>`
  template (Goal/Constraints/Progress/Decisions/Next Steps/Critical
  Context/Relevant Files/Reasoning Notes), <= 1.2KB worker-visible.
- **Snapshot / Revert hooks** (V011-3): `.dtd/snapshots/` (gitignored),
  three modes per v0.2 design R1:
  - `metadata-only` — pre-apply file hash + git diff metadata.
    Audit-only; **never revertable** (no preimage stored). Used only
    for explicit audit-only/non-output context, not normal worker output.
  - `preimage` — durable byte-for-byte snapshot of pre-apply file
    content, or an absent-prestate marker for a newly-created output
    path. Revertable. Default for normal worker output, including
    tracked text files and new output paths; also used when
    `revert_required: true` is set in `.dtd/permissions.md`.
  - `patch` — delta-only snapshot (forward + reverse patch).
    Revertable, smaller than `preimage` for large files. Mode chosen
    per-file based on size and policy.
  - `/dtd revert last|attempt|task` requires the affected files to be
    in `preimage` or `patch` mode at apply time. Files in
    `metadata-only` mode return `revert_unavailable_metadata_only`
    and the user must restore manually.
- **Worker session resume** (V011-4): `worker_session_id`,
  `resume_strategy: fresh|same-worker|new-worker|controller-takeover`
  in attempt timeline.
- **Loop guard / doom-loop detection** (V011-5): `loop_guard_status`,
  v0.2 per-run signature = worker+task+prompt-hash+failure-hash,
  threshold action ask|worker_swap|controller.
- **External directory permission** (V011-6): absolute paths trigger
  explicit approval.
- **Approval packet** (V011-7): `.dtd/runs/run-NNN-approval.md`
  written on `/dtd approve` with goal/phases/risks/path-scope frozen.
- **Status dashboard v2** (V011-8): adds `perms`, `snapshot`, `loop`,
  `incident` lines.
- **Incident tracking** (V011-Ops-1~3): `.dtd/log/incidents/inc-NNN.md`
  with reason taxonomy (NETWORK_UNREACHABLE / TIMEOUT / AUTH_FAILED /
  CONTEXT_HARD_CAP / PARTIAL_APPLY / LOOP_GUARD / etc.), recoverability
  classification, resume rules.
- **Worker-add wizard** (V011-Ops-10): conversational setup with
  field-by-field collection + secret redaction + ephemeral context.
  `/ㄷㅌㄷ qwen 워커 하나 추가해줘` pattern.

## v0.2 — Earlier roadmap items (orthogonal)

- **Category routing as a first-class layer** above worker IDs and
  aliases. Categories: `quick`, `deep`, `planning`, `review`,
  `code-write`, `visual-engineering`, `docs`, `explore`, `writing`.
  (v0.1 has capabilities + roles; v0.2 makes categories explicit.)
- **Hash-anchored edits** for finer-grained patch application
  (currently full-file replacement).
- **LSP / AST tool integration** for capable hosts (optional, not
  portable).
- **Streaming worker responses** with incremental file application.
- **Anthropic Messages / Gemini API direct adapters** (currently
  OpenAI-compat shims only).
- **A/B / consensus dispatch** (multiple workers on same task,
  controller picks best).
- **Distributed lock guarantees** across DTD instances for `global:`
  namespace.

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

This file IS the canonical source for v0.1.1 / v0.2 sub-release tree,
detailed feature notes, dependency order, and AIMemory archive
references.
v0.2.3 R1 extraction completed; `dtd.md` §v0.1.1 / v0.2 Roadmap now
points here.

## Related topics

- `self-update.md` — v0.2.0d migration runway.
- `autonomy.md` — v0.2.0f sleep-friendly autonomy.
- `index.md` (this dir) — v0.2.3 scaffold structure.
