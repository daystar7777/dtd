# DTD User Journey Scenarios

> Companion to `test-scenarios.md`. Where the acceptance scenarios verify
> feature contracts, these journeys verify a user can complete the product
> flow following only public docs (README / quickstart / `/dtd help`)
> without needing `dtd.md` internals or `AIMemory/` handoffs.
>
> **Status legend**:
> - `landed in <ver>` — runnable today against that release
> - `planned for <ver>` — design fixed; lands when target sub-release implements required commands
> - `draft` — design still evolving

Every journey lists Setup / Steps / Expected / Pass — same shape as
`test-scenarios.md` so they can be exercised the same way.

---

## 31. Fresh project from docs only — *landed in v0.2.0d*

**Setup**: empty project; tester reads only `README.md` and
`examples/quickstart.md`. No access to `dtd.md` or `AIMemory/`.

**Steps**:
1. Install via README one-liner.
2. `/dtd workers add` (interactive wizard).
3. `/dtd workers test <id>` (basic probe — landed in v0.2.0a).
4. `/dtd mode on`.
5. `/dtd plan "<small goal>"`.
6. `/dtd approve`.
7. `/dtd run`.
8. `/dtd status` to confirm completion.

**Expected**:
- Each step is discoverable from README without consulting `dtd.md`.
- Worker is verified before first plan/run.
- On COMPLETED, `/dtd status` shows summary path; tester can find it.
- No AIMemory handoff was needed at any point.

**Pass**: tester completes flow start-to-finish using only README + quickstart;
no surprise about command names, flags, or destination paths.

---

## 32. Existing project adoption — *landed in v0.2.0d*

**Setup**: project already has source files, open issues/TODOs, no `.dtd/`.

**Steps**:
1. Read README "Adopting on existing in-progress work" section.
2. Run install — does NOT touch existing project files.
3. Fill `.dtd/PROJECT.md` with project context (one-screen template).
4. `/dtd doctor` — surfaces missing context as INFO/WARN.
5. `/dtd plan "<phase that respects existing structure>"`.
6. `/dtd approve` after reviewing path-scope.

**Expected**:
- Install distinguishes fresh-vs-adoption and never overwrites existing files.
- Doctor lists what context is still missing.
- Plan path-scope respects existing source layout.

**Pass**: existing project files unchanged after install; doctor's missing-context
report is actionable; first plan touches only declared paths.

---

## 33. Worker check success path — *planned for v0.2.1*

**Setup**: `.dtd/workers.md` has one healthy OpenAI-compatible worker.

**Steps**: `/dtd workers test <id> --quick`.

**Expected**:
- Compact ASCII board shows OK, latency, last stage, and log path.
- Diagnostic log (`.dtd/log/worker-checks/<ts>.md`) includes all required
  stages with redacted evidence.
- `.dtd/notepad.md`, phase history, and state task counters are unchanged.

**Pass**: 14-stage check completes; observational read isolation verified;
log path printed and contains stage table.

---

## 34. Worker check pinpoints setup failure — *planned for v0.2.1*

**Setup**: same worker, env var missing.

**Steps**:
1. `/dtd workers test <id> --quick`.
2. `/dtd workers test show last`.

**Expected**:
- Compact output: `FAIL env` (or `WORKER_ENV_MISSING`).
- Detailed log: `registry_parse=OK`, `worker_resolve=OK`, `schema_validate=OK`,
  `env_check=FAIL`, later network stages `SKIP`.
- No secret value printed.
- Next-action line names the env var and how to set it.

**Pass**: failure pinpointed at `env_check` stage; downstream stages SKIPped;
no secret leak.

---

## 35. Worker check separates endpoint/auth/protocol failures — *planned for v0.2.1*

**Setup**: three subcases — endpoint unreachable / API key rejected / provider
responds but misses sentinel.

**Steps**: `/dtd workers test <id> --full` for each subcase.

**Expected**:
- Failures map to stable codes:
  `WORKER_NETWORK_UNREACHABLE`, `WORKER_AUTH_FAILED`,
  `WORKER_SENTINEL_MISMATCH` / `WORKER_PROTOCOL_VIOLATION`.
- Each log identifies last successful stage and failed stage.
- Raw provider response saved only in redacted diagnostic artifact.

**Pass**: failure taxonomy is stable; user can map output to `WORKER_*` codes
in docs.

---

## 36. Run to a boundary for human review — *landed in v0.2.0d*

**Setup**: approved multi-phase plan.

**Steps**:
1. `/dtd run --until phase:1`.
2. `/dtd status --history`.
3. User approves continuing → `/dtd run`.

**Expected**:
- DTD pauses at requested boundary; `last_pause_boundary: phase:1` durable.
- Status shows requested boundary, elapsed phase time, grade/comment.
- Resume continues from phase 2 without redoing phase 1.

**Pass**: bounded execution + durable pause-boundary fields work as advertised
in scenario 22n; user can verify from status alone.

---

## 37. Steering mid-run from natural language — *landed in v0.2.0d*

**Setup**: running plan.

**Steps**:
1. User says `"이번엔 안정성 우선으로 가자"`.
2. Controller classifies steering impact (low / medium / high).
3. If medium/high, DTD creates pending patch and asks approval.

**Expected**:
- Status shows steering goal and `pending_patch: true`.
- No worker is interrupted mid-call (patch applied between tasks only).
- Context remains compact; full steering details in log/patch file.

**Pass**: NL steering routes correctly; patch flow respects v0.1.1 between-tasks rule;
status communicates state without dumping raw patch into chat.

---

## 38. Incident recovery from help only — *landed in v0.2.0d*

**Setup**: active blocking incident caused by network failure (scenario 24
state, but reached without internal context).

**Steps**:
1. `/dtd status` — sees compact incident line.
2. Discovers `/dtd incident show <id>` from status hint.
3. Reviews recovery options, chooses one of: `retry`, `switch_worker`, `stop`.

**Expected**:
- Status compact line names the active incident and points to next inspect command.
- `incident show` presents recovery options and consequences.
- `retry` does NOT require destructive confirm.
- `stop` requires explicit confirmation per scenario 30; on `y`, scenario 29
  finalize_run path runs cleanly.

**Pass**: user navigates blocking incident using only the command surface
exposed in README "Recover" group + status hint.

---

## 39. Observational reads do not pollute context — *landed in v0.2.0d*

**Setup**: running or paused plan with notepad populated.

**Steps**:
1. Run `/dtd status`, `/dtd plan show`, `/dtd doctor`, `/dtd incident show <id>`,
   `/dtd help`, and `/dtd help stuck`.
2. Compare `.dtd/notepad.md`, phase history, task counters before/after.

**Expected**:
- None of the observational reads mutate run memory.
- Help and status reads do not update `state.md`.
- User-facing chat does NOT include raw worker or incident raw output.

**Pass**: status/help/read-only isolation rules per `instructions.md`
§Status/read-only call isolation hold for every v0.2.0d observational command.

---

## 39b. Worker health diagnostics do not pollute context — *planned for v0.2.1*

**Setup**: running or paused plan with notepad populated and at least one
registered worker.

**Steps**:
1. Run `/dtd workers test <id> --quick`.
2. Compare `.dtd/notepad.md`, phase history, task counters before/after.
3. Inspect `.dtd/log/worker-checks/<ts>.md`.

**Expected**:
- Worker-check diagnostic files are written under `.dtd/log/worker-checks/`
  only.
- `.dtd/notepad.md`, phase history, and task counters are unchanged.
- User-facing chat shows compact result + log path, not raw worker output.

**Pass**: worker health diagnostics are useful and durable without polluting
run memory. This sub-journey lands with v0.2.1 Worker Health Check.

---

## 40. Update journey after v0.2.0d — *landed in v0.2.0d*

**Setup**: project on older DTD version, with local `.dtd/workers.md`,
`.dtd/state.md`, run logs, incidents.

**Steps**:
1. `/dtd update check` — see latest available version + changelog snippet.
2. `/dtd update --dry-run` — preview file changes + state-schema migrations.
3. `/dtd update` — apply with explicit confirm.
4. `/dtd doctor` — verify post-update health.

**Expected**:
- User sees what will change before apply.
- Local registry, env, run history, incidents preserved.
- State schema migration reported (added/removed/renamed field counts).
- MANIFEST.json verification runs before any file write.
- Doctor confirms the migration succeeded.

**Pass**: update is observable, reversible until confirm, and preserves all
user data per v0.2.0d Amendment 2.

---

## 41. Korean / mixed-language primary path — *planned for v0.2.0e*

**Setup**: Korean user starts from `README.ko.md` / `quickstart.ko.md`.

**Steps**:
1. `/ㄷㅌㄷ 워커 추가`.
2. `/ㄷㅌㄷ 워커 동작체크` (v0.2.1 health check) or `/ㄷㅌㄷ 워커 점검` (v0.2.0a basic probe).
3. `/ㄷㅌㄷ 계획짜줘: <goal>`.
4. `/ㄷㅌㄷ 승인`.
5. `/ㄷㅌㄷ 실행`.
6. `/ㄷㅌㄷ 상태보여줘`.

**Expected**:
- Each phrase maps to the same canonical command as English/slash form.
- Ambiguous/destructive actions still confirm.
- `/dtd help` (v0.2.0d) explains canonical command equivalents in user's locale.
- Locale pack opt-in (v0.2.0e) does not regress this flow.

**Pass**: Korean primary path stays usable across v0.2.0a → v0.2.0d → v0.2.0e
transition; locale pack split is invisible to users with `locale: ko` set.

---

## 42. Help-only discoverability — *landed in v0.2.0d*

**Setup**: user knows only `/dtd help`.

**Steps**:
1. `/dtd help` — overview of main lifecycle.
2. `/dtd help workers` — workers add/test/list with one example each.
3. `/dtd help stuck` — incident list/show/resolve + decision capsule recovery.
4. `/dtd help update` — update check/dry-run/apply.

**Expected**:
- Default help under 25 lines; topic help under 50 lines.
- Each topic includes one short example per command.
- Help output is observational — no `state.md` mutation, no notepad write.
- Korean aliases route: `/ㄷㅌㄷ 도움말`, `/ㄷㅌㄷ 워커 도움말`, `/ㄷㅌㄷ 막혔을 때`.

**Pass**: help is small, layered, observational; user can navigate the v0.2.0d
command set using only `/dtd help` + topic drilling.

---

## 43. Sleep-friendly autonomous overnight run — *landed in v0.2.0f*

**Setup**: APPROVED multi-phase plan. User wants to sleep 8 hours and let DTD
make safe progress. Workers configured with tier escalation. `host.mode: full`.

**Steps**:
1. User: `"자러갈게 8시간 조용히 자동진행해줘"` (or
   `/dtd run --silent=8h --decision auto`).
2. Controller validates: duration ≤ `silent_max_hours` (default 8 OK),
   host.mode != plan-only OK.
3. State: `attention_mode: silent`, `attention_until: now+8h`,
   `attention_goal: "조용히 자동진행"`, `decision_mode: auto`.
4. Run loop iterates safely overnight per silent ready-work algorithm.
5. (Morning) User runs `/dtd interactive` (or `/dtd status` to peek).

**Expected**:
- During the silent window:
  - Recoverable retries succeed without prompting user.
  - Same-profile/free fallback transitions auto.
  - Phase boundaries advance.
  - Defer triggers (AUTH_FAILED, paid fallback, destructive, etc.) fire
    via the silent ready-work algorithm: incident created, capsule
    snapshotted, lease released, controller continues other ready work.
  - Destructive/paid/external-path/secret events NEVER auto-execute.
- On `/dtd interactive`:
  - Morning summary block prints (per dtd.md §Morning summary format):
    `+ DTD silent window ended — 8h00m elapsed`, `+ progress` (completed
    / deferred / skipped), `+ deferred decisions` (oldest-first),
    `+ ready work` (next batch), `+ next` (inspect / continue hints).
  - state.md: `attention_mode: interactive`, `attention_until: null`.
  - Decision capsule filled with the oldest deferred ref's recovery
    options.
- User resolves each deferred capsule sequentially; remaining capsules
  surface one-at-a-time.
- After all deferred resolved, `/dtd run` resumes execution.

**Failure-path subcases**:

- **Silent window exceeds limit**: user requested 9h → rejected
  (`silent_max_hours: 8` invariant). Tell user to split or lower.
- **Deferred limit hit at `silent_deferred_decision_limit: 20`**:
  PAUSED with `last_pause_reason: silent_deferred_limit`. User sees
  one-line surface in chat next time they look at host UI. Run
  `/dtd interactive` to see full backlog.
- **Controller token exhaustion**: PAUSED with
  `awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED`,
  attention state preserved, compact silent progress summary + capsule
  visible on next turn. User runs `/dtd interactive` for the full backlog.

**Pass**: a user can sleep 8 hours and wake up to a complete morning
summary showing progress + actionable backlog. Safe forward progress
maximized; nothing destructive auto-executed; all blockers durably
recorded with full recovery option context.

---

## How to add a new journey

When a sub-release adds a journey:

1. Move the journey from "planned" to "landed in <ver>" in this file.
2. Add a corresponding row in `test-scenarios.md` Coverage Map under the
   sub-release section.
3. Reference the journey number from any release-notes section that
   advertises the related feature.

Detail design history lives in
`AIMemory/handoff_dtd-user-journey-doc-test-audit.gpt-5-codex.md` — but the
canonical journey content lives in this file going forward.
