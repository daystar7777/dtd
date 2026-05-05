# DTD Run Notepad

> Compact wisdom capsule for the active run. Updated by the controller before
> every worker dispatch and at phase boundaries. Workers receive ONLY the
> `## handoff` section (8 H3 headings)
> as part of their prompt prefix — not the full notepad.
>
> Replaces "send entire phase log to next worker" (token-expensive) with a
> curated, structured summary that survives session boundaries.
>
> Worker execution context resets on every dispatch/retry/phase boundary; only
> controller-distilled learnings and the current `## handoff` survive.
>
> One file per project (active run). On `plan_status: COMPLETED` (or
> `STOPPED`/`FAILED`), the controller **deterministically**:
>   1. archives this file to `.dtd/runs/run-NNN-notepad.md`
>   2. resets this file to template state for the next run
>
> See dtd.md §Per-Run Notepad and §`/dtd notepad` (v0.2.2) for full lifecycle.

## handoff (v0.2.2 8-heading)

> **This is the section workers receive in their prompt.** Total ≤ 1.2 KB
> across all 8 headings. Per-heading budget enforced by `/dtd doctor`.
> Schema-v2 detection: `## handoff` H2 + `### Goal` H3 child.

### Goal

(empty — 1-2 sentences; budget 150 chars; KEEP under compaction)

### Constraints

(empty — hard requirements / non-goals / must-not-do's; budget 200 chars; KEEP)

### Progress

(empty — compact list of done; budget 200 chars; TRUNCATE first → "Phase N completed; see phase-history.md")

### Decisions

(empty — architectural / approach choices; budget 200 chars; KEEP)

### Next Steps

(empty — what THIS worker should do next; budget 150 chars; KEEP)

### Critical Context

(empty — knowledge needed that isn't elsewhere; budget 250 chars; KEEP)

### Relevant Files

(empty — path refs only, no inline content; budget 100 chars; TRUNCATE second)

### Reasoning Notes

(empty — compact rationale/evidence/risks/next_action/lesson from v0.2.0f
reasoning utilities; budget 200 chars; KEEP last 3 entries; older entries
roll into `## learnings` as one-line bullets)

> **Reasoning Notes content discipline**: this is NOT a chain-of-thought log.
> Allowed entry shapes: `decision: ... evidence: [...] risks: ... next: ...`
> or `lesson (reflexion): ... trigger: ...`. Each entry ≤ 5 lines. NO
> private-reasoning trigger phrases, NO multi-paragraph reasoning, NO
> branching candidate exploration. Doctor flags narrative leakage as
> `reasoning_notes_chain_of_thought_leak`.

## learnings

Conventions and patterns the controller (or workers) discovered about THIS
project. Things a fresh session would otherwise have to rediscover.

(empty — populates as run progresses)

## decisions

Choices made during the run with one-line rationale. Future workers reference
these to avoid re-deciding settled questions.

(empty)

## issues

Known blockers, gotchas, weird behaviors. Each entry: what / where / status.

(empty)

## verification

Commands and results that confirmed something works (or doesn't). Useful for
"how did we test this last phase?" without re-running.

(empty)

---

Last update: never (template state)
