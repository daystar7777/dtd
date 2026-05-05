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
Add-Result "v030e.permissions.resolution_uses_resolved_until" "permissions resolution uses resolved_until as canonical expiry" `
    (($permText -match "(?s)Drop expired rules:.*?resolved_until: <ISO ts>") -and
     ($permText -match "resolved_until: run_end") -and
     ($permText -match 'legacy `until: <ISO ts>`'))
Add-Result "v030e.permissions.resolution_handles_tombstones" "permissions resolution applies revoke tombstones before matching" `
    (($permText -match "Apply tombstones first") -and
     ($permText -match "Tombstone rows are audit records, not\s+candidate decisions"))

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
$stateKeys = @("active_time_limited_rule_count", "last_permission_prune_at")
foreach ($key in $stateKeys) {
    Add-Result "v030e.state.key.$key" "state.md v0.3.0e section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── reference/run-loop.md ───────────────────────────────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v030e.runloop.step_5c" "run-loop.md finalize_run has step 5c auto-prune" `
    ($runLoopRef -match "5c\.\s*\*\*Auto-prune time-limited permission rules\*\* \(v0\.3\.0e R0\)")
Add-Result "v030e.runloop.run_end_tombstone" "run-loop.md step 5c tombstones run_end rules" `
    ($runLoopRef -match "(?s)resolved_until: run_end.*?finalize_run_run_end")
Add-Result "v030e.runloop.ttl_expired_tombstone" "run-loop.md step 5c tombstones TTL-expired rules" `
    ($runLoopRef -match "(?s)ts < now.*?finalize_run_ttl_expired")
Add-Result "v030e.runloop.recount_state" "run-loop.md step 5c recounts active_time_limited_rule_count" `
    ($runLoopRef -match "(?s)Recount.*?active_time_limited_rule_count")

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

# v0.3.0e R1 doctor codes (additional)
$doctorR1Codes = @(
    "permission_until_form_unknown",
    "permission_user_tz_required",
    "permission_until_tz_form_mismatch",
    "permission_late_bind_overrun",
    "permission_clock_skew_excessive",
    "permission_until_dst_ambiguous",
    "permission_until_legacy_local_offset",
    "permission_finalize_form_drift",
    "permission_finalize_pre_r1_tombstone_unannotated"
)
foreach ($code in $doctorR1Codes) {
    Add-Result "v030e.doctor.r1_code.$code" "doctor-checks ref defines R1 $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030e.doctor.r1_section" "doctor-checks ref has v0.3.0e R1 runtime checks header" `
    ($doctorRef -match "v0\.3\.0e R1 runtime checks")

# ─── reference/v030e-time-limited-permissions.md (R1 canonical topic) ──────

$v030eRef = Read-Text ".dtd/reference/v030e-time-limited-permissions.md"

Add-Result "v030e.r1_ref.summary" "v030e R1 ref has Summary section" `
    ($v030eRef -match "(?m)^## Summary")
Add-Result "v030e.r1_ref.anchor" "v030e R1 ref has Anchor section" `
    ($v030eRef -match "(?m)^## Anchor")
Add-Result "v030e.r1_ref.write_time_evaluator" "v030e R1 ref documents write-time evaluator algorithm" `
    ($v030eRef -match "Resolution-time evaluator")
Add-Result "v030e.r1_ref.pre_dispatch_check" "v030e R1 ref documents pre-dispatch check algorithm" `
    ($v030eRef -match "Pre-dispatch check")
Add-Result "v030e.r1_ref.late_binding" "v030e R1 ref documents late-binding behavior" `
    (($v030eRef -match "Late-binding") -and ($v030eRef -match "mid-tool-call"))
Add-Result "v030e.r1_ref.clock_skew" "v030e R1 ref documents clock skew model" `
    ($v030eRef -match "Clock skew")
Add-Result "v030e.r1_ref.dst_handling" "v030e R1 ref documents DST handling" `
    (($v030eRef -match "DST transitions") -or ($v030eRef -match "spring forward"))
Add-Result "v030e.r1_ref.tombstone_audit_form" "v030e R1 ref documents tombstone resolved_until_form audit field" `
    ($v030eRef -match "resolved_until_form:")
Add-Result "v030e.r1_ref.r1_scenarios" "v030e R1 ref lists scenarios 150-157 (R1)" `
    ($v030eRef -match "(?s)R1 acceptance scenarios.*?150.*?157")

# ─── reference/index.md (v030e R1 row + expansion note) ─────────────────────

$indexRef = Read-Text ".dtd/reference/index.md"
Add-Result "v030e.index.r1_row" "index.md has v030e-time-limited-permissions row" `
    ($indexRef -match '(?m)^\| `v030e-time-limited-permissions` ')
Add-Result "v030e.index.r1_canonical" "index.md marks v030e-time-limited-permissions canonical" `
    ($indexRef -match '(?m)^\| `v030e-time-limited-permissions` .*\| canonical \|')
Add-Result "v030e.index.r1_expansion_note" "index.md mentions v030e R1 catalog growth (16 -> 17)" `
    ($indexRef -match "16 .*17|v030e R1")

# ─── state.md (R1 fields) ───────────────────────────────────────────────────

$stateR1Keys = @("last_permission_rule_written_at", "last_permission_rule_form", "user_tz")
foreach ($key in $stateR1Keys) {
    Add-Result "v030e.state.r1_key.$key" "state.md v0.3.0e section has R1 $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030e.scenarios.section_header" "test-scenarios.md has v0.3.0e section header" `
    ($scenariosMd -match "## v0\.3\.0e .* Time-limited permissions UX")
foreach ($n in 109..117) {
    Add-Result "v030e.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030e.scenarios.r1_section_header" "test-scenarios.md has v0.3.0e R1 section header" `
    ($scenariosMd -match "## v0\.3\.0e R1 .* Time-limited permissions runtime")
foreach ($n in 150..157) {
    Add-Result "v030e.scenarios.r1_$n" "test-scenarios.md has R1 scenario $n" `
        ($scenariosMd -match "### $n\.")
}

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030e.manifest.checker" "build-manifest includes scripts/check-v030e.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030e.ps1"))
Add-Result "v030e.manifest.r1_reference" "build-manifest includes reference/v030e-time-limited-permissions.md" `
    ($builderText -match [regex]::Escape(".dtd/reference/v030e-time-limited-permissions.md"))

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
