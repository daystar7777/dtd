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
    ($runLoopRef -match "(?s)Paid-fallback contract.*?permission/cost transition")
Add-Result "v030b.runloop.tz_aware_pause_overnight" "run-loop.md says pause_overnight shows tz-aware reset time" `
    ($runLoopRef -match "(?s)pause_overnight.*?exact local reset time \+ timezone")
Add-Result "v030b.runloop.estimation_priority" "run-loop.md documents estimation source priority" `
    ($runLoopRef -match "(?s)Estimation source priority.*?exec-\*-ctx\.md")
Add-Result "v030b.runloop.advisory_redaction" "run-loop.md says provider headers are advisory + redacted" `
    ($runLoopRef -match "(?s)Provider-header capture.*?advisory.*?NEVER capture or log raw token values")
Add-Result "v030b.runloop.capsule_schema" "run-loop.md has WORKER_QUOTA_EXHAUSTED_PREDICTED capsule schema" `
    ($runLoopRef -match "awaiting_user_reason: WORKER_QUOTA_EXHAUSTED_PREDICTED")

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

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030b.manifest.checker" "build-manifest includes scripts/check-v030b.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030b.ps1"))

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
