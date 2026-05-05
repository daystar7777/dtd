# DTD v0.3.0b release-contract checks (token-rate-aware scheduling)
#
# Validates:
#   - workers.example.md has 6 quota fields with nullable defaults
#   - dtd.md /dtd workers test gains --quota flag
#   - dtd.md doctor section lists Quota state (v0.3.0b)
#   - state.md has ## Quota state (v0.3.0b)
#   - state.md awaiting_user_reason enum lists WORKER_QUOTA_EXHAUSTED_PREDICTED
#   - config.md has ## quota (v0.3.0b)
#   - reference/run-loop.md has step 5.5.0 + ## Quota predictive check section
#   - reference/doctor-checks.md has v0.3.0b checks
#   - test-scenarios.md has scenarios 118-125
#   - scripts/build-manifest.ps1 includes check-v030b.ps1

[CmdletBinding()]
param([string]$RepoRoot = "")

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$Results = @()
function Add-Result {
    param([string]$Id, [string]$Name, [bool]$Pass, [string]$Detail = "")
    $script:Results += [pscustomobject]@{ id = $Id; name = $Name; pass = $Pass; detail = $Detail }
}
function Read-Text([string]$RelativePath) {
    [System.IO.File]::ReadAllText((Join-Path $RepoRoot $RelativePath), [System.Text.Encoding]::UTF8)
}

# ─── workers.example.md ───────────────────────────────────────────────────────

$workersExample = Read-Text ".dtd/workers.example.md"

$quotaFields = @("daily_token_quota", "monthly_token_quota",
                 "quota_safety_margin", "quota_reset_local_time",
                 "quota_reset_window_days",
                 "quota_provider_header_prefix")
foreach ($field in $quotaFields) {
    Add-Result "v030b.workers_example.$field" "workers.example.md has $field" `
        ($workersExample -match "(?m)^- $([regex]::Escape($field)):")
}
Add-Result "v030b.workers_example.daily_quota_null_default" "workers.example.md daily_token_quota null default" `
    ($workersExample -match "(?m)^- daily_token_quota:\s*null")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v030b.dtdmd.quota_flag" "dtd.md /dtd workers test has --quota flag" `
    ($dtdMd -match "test \[<id\|alias>\] \[--all\|--quick\|--full\|--connectivity\|--assigned\|--json\|--quota\]")
Add-Result "v030b.dtdmd.quota_flag_doc" "dtd.md documents --quota flag (v0.3.0b)" `
    ($dtdMd -match "(?s)``--quota`` flag \(v0\.3\.0b\).*?observational")
Add-Result "v030b.dtdmd.doctor_lists_quota" "dtd.md doctor lists Quota state (v0.3.0b)" `
    ($dtdMd -match "Quota state \(v0\.3\.0b\)")

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v030b.state.section" "state.md has ## Quota state (v0.3.0b)" `
    ($stateMd -match "## Quota state \(v0\.3\.0b\)")
$stateKeys = @("pending_quota_capsule", "last_quota_check_at",
               "last_quota_reset_local_at", "last_quota_reset_tz")
foreach ($key in $stateKeys) {
    Add-Result "v030b.state.key.$key" "state.md Quota section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030b.state.awaiting_reason" "state.md awaiting_user_reason enum lists WORKER_QUOTA_EXHAUSTED_PREDICTED" `
    ($stateMd -match "WORKER_QUOTA_EXHAUSTED_PREDICTED")

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v030b.config.section" "config.md has ## quota (v0.3.0b)" `
    ($configMd -match "## quota \(v0\.3\.0b\)")
$configKeys = @("quota_predictive_routing_enabled",
                "quota_safety_margin_default",
                "cross_run_quota_persist",
                "quota_warn_threshold_pct",
                "quota_block_threshold_pct",
                "quota_provider_headers_capture",
                "quota_persist_path",
                "quota_paid_fallback_silent_defer")
foreach ($key in $configKeys) {
    Add-Result "v030b.config.key.$key" "config.md quota section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── reference/run-loop.md ───────────────────────────────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v030b.runloop.step_5_5_0" "run-loop.md has step 5.5.0 quota predictive check" `
    ($runLoopRef -match "5\.5\.0\.\s*\*\*Quota predictive check\*\*")
Add-Result "v030b.runloop.section" "run-loop.md has ## Quota predictive check + ledger discipline (v0.3.0b R0)" `
    ($runLoopRef -match "## Quota predictive check \+ ledger discipline \(v0\.3\.0b R0\)")
Add-Result "v030b.runloop.controller_only_preserved" "run-loop.md says controller ledger stays controller-only" `
    ($runLoopRef -match "(?s)controller-usage-run-NNN\.md.*?controller-only")
Add-Result "v030b.runloop.worker_usage_separate" "run-loop.md adds separate worker-usage-run-NNN.md ledger" `
    ($runLoopRef -match "worker-usage-run-NNN\.md.*?NEW")
Add-Result "v030b.runloop.paid_fallback_contract" "run-loop.md says paid fallback is permission-gated" `
    ($runLoopRef -match "(?s)Paid-fallback contract.*?permission/cost\s+transition")
Add-Result "v030b.runloop.quota_blocker_durable_state" "run-loop.md says quota blockers create durable resume state" `
    (($runLoopRef -match 'pending_quota_capsule') -and
     ($runLoopRef -match 'awaiting_user_decision') -and
     ($runLoopRef -notmatch 'does NOT mutate state\.md'))
Add-Result "v030b.runloop.tz_aware_pause_overnight" "run-loop.md says pause_overnight shows tz-aware reset time" `
    ($runLoopRef -match "(?s)pause_overnight.*?exact local reset time \+ timezone")
Add-Result "v030b.runloop.estimation_priority" "run-loop.md documents estimation source priority" `
    ($runLoopRef -match "(?s)Estimation source priority.*?exec-\*-ctx\.md")
Add-Result "v030b.runloop.advisory_redaction" "run-loop.md says provider headers are advisory + redacted" `
    ($runLoopRef -match "(?s)Provider-header capture.*?advisory.*?NEVER capture or log raw header strings")
Add-Result "v030b.runloop.capsule_schema" "run-loop.md has WORKER_QUOTA_EXHAUSTED_PREDICTED capsule schema" `
    ($runLoopRef -match "awaiting_user_reason: WORKER_QUOTA_EXHAUSTED_PREDICTED")
Add-Result "v030b.runloop.finalize_hook" "run-loop.md wires finalize_run step 9.quota terminal hook" `
    (($runLoopRef -match "9\.quota") -and `
     ($runLoopRef -match "v030b-quota-scheduling"))

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v030b.doctor.section" "doctor-checks ref has v0.3.0b Token-rate-aware scheduling checks" `
    ($doctorRef -match "v0\.3\.0b Token-rate-aware scheduling checks")
$doctorCodes = @(
    "quota_no_data_today",
    "quota_warn_<worker>",
    "quota_block_pending_<worker>",
    "quota_pending_orphan",
    "quota_audit_secret_leak",
    "quota_provider_header_unused",
    "quota_tracker_oversized",
    "quota_pause_overnight_tz_missing",
    "quota_paid_fallback_unauthorized"
)
foreach ($code in $doctorCodes) {
    Add-Result "v030b.doctor.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030b.scenarios.section_header" "test-scenarios.md has v0.3.0b section header" `
    ($scenariosMd -match "## v0\.3\.0b .* Token-rate-aware scheduling")
foreach ($n in 118..125) {
    Add-Result "v030b.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030b.scenarios.r1_section_header" "test-scenarios.md has v0.3.0b R1 section header" `
    ($scenariosMd -match "## v0\.3\.0b R1 .* Token-rate-aware scheduling runtime")
foreach ($n in 158..165) {
    Add-Result "v030b.scenarios.r1_$n" "test-scenarios.md has R1 scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030b.scenarios.r1_158_fallback_source" "scenario 158 separates plan-derived from no-plan fallback" `
    (($scenariosMd -match 'Task `2\.1` has `<context-files>`') -and `
     ($scenariosMd -match 'Task `2\.1-empty` has no plan-size signal'))
Add-Result "v030b.scenarios.r1_163_pause_not_terminal" "scenario 163 expects durable pause rather than legacy terminal status" `
    (($scenariosMd -match "plan_status: PAUSED") -and `
     ($scenariosMd -notmatch "STOPPED_BY_QUOTA_MID_RUN"))

# ─── reference/v030b-quota-scheduling.md (R1 canonical topic) ──────────────

$v030bRef = Read-Text ".dtd/reference/v030b-quota-scheduling.md"

Add-Result "v030b.r1_ref.summary" "v030b R1 ref has Summary section" `
    ($v030bRef -match "(?m)^## Summary")
Add-Result "v030b.r1_ref.anchor" "v030b R1 ref has Anchor section" `
    ($v030bRef -match "(?m)^## Anchor")
Add-Result "v030b.r1_ref.estimation" "v030b R1 ref documents estimation function" `
    ($v030bRef -match "next_task_estimate\(")
Add-Result "v030b.r1_ref.estimation_fallback_reachable" "v030b R1 estimation gates plan-derived before conservative fallback" `
    (($v030bRef -match "task_has_plan_size_signal") -and `
     ($v030bRef -match "DEFAULT_TASK_ESTIMATE_TOKENS"))
Add-Result "v030b.r1_ref.history_priority" "v030b R1 ref documents history-first priority (Codex P1)" `
    (($v030bRef -match "Per-task historical mean") -and ($v030bRef -match "Codex P1"))
Add-Result "v030b.r1_ref.vendor_table" "v030b R1 ref has provider header vendor table" `
    (($v030bRef -match "Anthropic") -and ($v030bRef -match "OpenAI") -and `
     ($v030bRef -match "anthropic-ratelimit-"))
Add-Result "v030b.r1_ref.redaction_discipline" "v030b R1 ref documents redaction (Codex P1)" `
    (($v030bRef -match "NEVER captured:") -and ($v030bRef -match "auth headers"))
Add-Result "v030b.r1_ref.finalize_step_9" "v030b R1 ref documents finalize_run step 9.quota" `
    ($v030bRef -match "step 9\.quota|finalize_run_step_9_quota")
Add-Result "v030b.r1_ref.dedicated_step_codex" "v030b R1 ref calls out Codex P1.10 dedicated step" `
    ($v030bRef -match "P1\.10")
Add-Result "v030b.r1_ref.tz_aware_reset" "v030b R1 ref documents TZ-aware reset window" `
    (($v030bRef -match "compute_daily_window") -and ($v030bRef -match "user_tz"))
Add-Result "v030b.r1_ref.mid_run_exhaust" "v030b R1 ref documents mid-run exhaust handling" `
    (($v030bRef -match "Mid-run quota exhaust") -and ($v030bRef -match "mid_run_actual_exceeded"))
Add-Result "v030b.r1_ref.mid_run_no_legacy_terminal" "v030b R1 mid-run quota exhaust uses durable pause, not legacy terminal status" `
    (($v030bRef -match 'plan_status = "PAUSED"') -and `
     ($v030bRef -notmatch "STOPPED_BY_QUOTA_MID_RUN"))
Add-Result "v030b.r1_ref.capsule_rendering" "v030b R1 ref documents capsule prompt rendering" `
    ($v030bRef -match "Capsule rendering")
Add-Result "v030b.r1_ref.r1_scenarios" "v030b R1 ref lists scenarios 158-165" `
    ($v030bRef -match "(?s)R1 acceptance scenarios.*?158.*?165")

# ─── reference/index.md (v030b R1 row + expansion note) ────────────────────

$indexRefText = Read-Text ".dtd/reference/index.md"
Add-Result "v030b.index.r1_row" "index.md has v030b-quota-scheduling row" `
    ($indexRefText -match '(?m)^\| `v030b-quota-scheduling` ')
Add-Result "v030b.index.r1_canonical" "index.md marks v030b-quota-scheduling canonical" `
    ($indexRefText -match '(?m)^\| `v030b-quota-scheduling` .*\| canonical \|')

# ─── state.md (R1 fields) ──────────────────────────────────────────────────

$stateR1Keys = @("last_quota_estimation_source", "mid_run_actual_exceeded_count")
foreach ($key in $stateR1Keys) {
    Add-Result "v030b.state.r1_key.$key" "state.md Quota section has R1 $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── config.md (R1 quota keys) ─────────────────────────────────────────────

$configR1Keys = @("estimation_default_completion_tokens",
                  "estimation_default_task_tokens",
                  "quota_archive_max_files")
foreach ($key in $configR1Keys) {
    Add-Result "v030b.config.r1_key.$key" "config.md quota section has R1 $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── doctor-checks.md (R1 doctor codes) ────────────────────────────────────

$doctorR1Codes = @(
    "quota_estimation_history_thin",
    "quota_provider_header_format_drift",
    "quota_provider_header_unknown_format",
    "quota_reset_tz_mismatch",
    "quota_pause_overnight_resume_tick_missing",
    "quota_finalize_aggregation_skipped",
    "quota_archive_overflow"
)
foreach ($code in $doctorR1Codes) {
    Add-Result "v030b.doctor.r1_code.$code" "doctor-checks ref defines R1 $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030b.doctor.r1_section" "doctor-checks ref has v0.3.0b R1 runtime checks header" `
    ($doctorRef -match "v0\.3\.0b R1 runtime checks")

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030b.manifest.checker" "build-manifest includes scripts/check-v030b.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030b.ps1"))
Add-Result "v030b.manifest.r1_reference" "build-manifest includes reference/v030b-quota-scheduling.md" `
    ($builderText -match [regex]::Escape(".dtd/reference/v030b-quota-scheduling.md"))

$pass = @($Results | Where-Object { $_.pass }).Count
$fail = @($Results | Where-Object { -not $_.pass }).Count
$total = $Results.Count

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "FAILED checks:"
    @($Results | Where-Object { -not $_.pass }) | ForEach-Object {
        Write-Host "  - [$($_.id)] $($_.name) -- $($_.detail)"
    }
}

Write-Host ""
Write-Host "V030B_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
