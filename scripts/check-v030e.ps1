# DTD v0.3.0e release-contract checks (time-limited permissions UX)
#
# Validates:
#   - .dtd/permissions.md has v0.3.0e ## Time-limited rules section
#   - dtd.md /dtd permission body has time-limited syntax
#   - state.md has v0.3.0e fields
#   - reference/run-loop.md finalize_run has step 5c auto-prune
#   - reference/doctor-checks.md has v0.3.0e checks
#   - test-scenarios.md has scenarios 109-117
#   - scripts/build-manifest.ps1 includes check-v030e.ps1
#
# Usage: ./scripts/check-v030e.ps1
# Exit code: 0 if all PASS, 1 if any FAIL.

[CmdletBinding()]
param(
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$Results = @()
function Add-Result {
    param([string]$Id, [string]$Name, [bool]$Pass, [string]$Detail = "")
    $script:Results += [pscustomobject]@{
        id = $Id
        name = $Name
        pass = $Pass
        detail = $Detail
    }
}

function Read-Text([string]$RelativePath) {
    [System.IO.File]::ReadAllText((Join-Path $RepoRoot $RelativePath), [System.Text.Encoding]::UTF8)
}

# ─── permissions.md ──────────────────────────────────────────────────────────

$permText = Read-Text ".dtd/permissions.md"

Add-Result "v030e.permissions.section" "permissions.md has ## Time-limited rules (v0.3.0e)" `
    ($permText -match "## Time-limited rules \(v0\.3\.0e\)")
Add-Result "v030e.permissions.duration_form" "permissions.md documents duration form" `
    ($permText -match '\+<int><m\\\|h\\\|d\\\|w>')
$namedScopes = @("today", "eod", "this-week", "next-monday", "next-week", "run", "run_end")
foreach ($scope in $namedScopes) {
    Add-Result "v030e.permissions.scope.$scope" "permissions.md documents named scope $scope" `
        ($permText -match ('(?m)^\| `' + [regex]::Escape($scope) + '`'))
}
Add-Result "v030e.permissions.combined_units_deferred" "permissions.md says combined units deferred" `
    ($permText -match "Combined units .*\+1h30m.*DEFERRED")
Add-Result "v030e.permissions.combined_error" "permissions.md mentions permission_duration_combined_unsupported_v030e" `
    ($permText -match "permission_duration_combined_unsupported_v030e")
Add-Result "v030e.permissions.mixed_error" "permissions.md mentions permission_duration_until_mixed_unsupported" `
    ($permText -match "permission_duration_until_mixed_unsupported")
Add-Result "v030e.permissions.resolved_until_field" "permissions.md documents resolved_until derived field" `
    ($permText -match "resolved_until:")
Add-Result "v030e.permissions.resolved_until_tz" "permissions.md documents resolved_until_tz field" `
    ($permText -match "resolved_until_tz:")
Add-Result "v030e.permissions.run_end_sentinel" "permissions.md documents run_end sentinel" `
    ($permText -match "resolved_until: run_end")
Add-Result "v030e.permissions.legacy_v020b_back_compat" "permissions.md acknowledges v0.2.0b legacy rules" `
    ($permText -match "permission_until_unresolved_legacy_v020b")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v030e.dtdmd.time_limited_section" "dtd.md /dtd permission body has time-limited syntax" `
    ($dtdMd -match "Time-limited syntax \(v0\.3\.0e\)")
$dtdSyntaxForms = @('for <int>', 'until <ISO ts>', 'until <named scope>', 'for run')
foreach ($form in $dtdSyntaxForms) {
    $key = ($form -replace '[^a-zA-Z0-9]','_')
    Add-Result "v030e.dtdmd.syntax.$key" "dtd.md documents $form syntax" `
        ($dtdMd -match [regex]::Escape($form))
}
Add-Result "v030e.dtdmd.mutually_exclusive" "dtd.md says for X and until Y are mutually exclusive" `
    ($dtdMd -match "MUTUALLY EXCLUSIVE")
Add-Result "v030e.dtdmd.combined_deferred" "dtd.md says combined units deferred to v0.3.x" `
    ($dtdMd -match "Combined units.*deferred to v0\.3\.x")
Add-Result "v030e.dtdmd.step_5c_pointer" "dtd.md points to finalize_run step 5c" `
    ($dtdMd -match "(?s)Auto-prune at finalize_run.*?step 5c")

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v030e.state.section" "state.md has ## Permission time-limited rules (v0.3.0e)" `
    ($stateMd -match "## Permission time-limited rules \(v0\.3\.0e\)")
$stateKeys = @("session_active_time_limited_count", "last_session_prune_at")
foreach ($key in $stateKeys) {
    Add-Result "v030e.state.key.$key" "state.md v0.3.0e section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── reference/run-loop.md ───────────────────────────────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v030e.runloop.step_5c" "run-loop.md finalize_run has step 5c auto-prune" `
    ($runLoopRef -match "5c\.\s*\*\*Auto-prune time-limited permission rules\*\* \(v0\.3\.0e R0\)")
Add-Result "v030e.runloop.session_end_tombstone" "run-loop.md step 5c tombstones run_end rules" `
    ($runLoopRef -match "(?s)resolved_until: run_end.*?finalize_run_session_end")
Add-Result "v030e.runloop.ttl_expired_tombstone" "run-loop.md step 5c tombstones TTL-expired rules" `
    ($runLoopRef -match "(?s)ts < now.*?finalize_run_ttl_expired")
Add-Result "v030e.runloop.recount_state" "run-loop.md step 5c recounts session_active_time_limited_count" `
    ($runLoopRef -match "(?s)Recount.*?session_active_time_limited_count")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v030e.doctor.section" "doctor-checks ref has v0.3.0e Time-limited permissions checks" `
    ($doctorRef -match "v0\.3\.0e Time-limited permissions checks")
$doctorCodes = @(
    "permission_until_unresolved",
    "permission_until_unresolved_legacy_v020b",
    "permission_run_end_orphaned_after_finalize",
    "permission_until_tz_missing",
    "permission_duration_combined_unsupported_v030e",
    "permission_duration_until_mixed_unsupported",
    "permission_time_limited_count_drift",
    "permission_finalize_prune_unrun"
)
foreach ($code in $doctorCodes) {
    Add-Result "v030e.doctor.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030e.scenarios.section_header" "test-scenarios.md has v0.3.0e section header" `
    ($scenariosMd -match "## v0\.3\.0e .* Time-limited permissions UX")
foreach ($n in 109..117) {
    Add-Result "v030e.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030e.manifest.checker" "build-manifest includes scripts/check-v030e.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030e.ps1"))

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
Write-Host "V030E_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
