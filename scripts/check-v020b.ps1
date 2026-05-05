# DTD v0.2.0b release-contract checks
#
# Validates that the v0.2.0b deliverables match the design contract:
#   - .dtd/permissions.md exists with ## Active rules + ## Default rules
#     + ## Resolution algorithm sections
#   - 8 default rules cover canonical permission keys
#   - dtd.md has /dtd permission command body with all 7 forms
#   - dtd.md doctor section lists Permission ledger (v0.2.0b)
#   - reference/doctor-checks.md has ## Permission ledger (v0.2.0b)
#   - state.md has ## Permission ledger (v0.2.0b) section with
#     pending_permission_request field
#   - test-scenarios.md has scenarios 50-59
#   - scripts/build-manifest.ps1 includes permissions.md + check-v020b.ps1
#
# Usage:
#   pwsh ./scripts/check-v020b.ps1
#
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

$permissionsPath = Join-Path $RepoRoot ".dtd/permissions.md"
$permissionsExists = Test-Path -LiteralPath $permissionsPath
Add-Result "v020b.permissions.exists" ".dtd/permissions.md exists" $permissionsExists

if ($permissionsExists) {
    $permText = Get-Content -LiteralPath $permissionsPath -Raw

    Add-Result "v020b.permissions.active_section" "permissions.md has ## Active rules" `
        ($permText -match "## Active rules")
    Add-Result "v020b.permissions.default_section" "permissions.md has ## Default rules" `
        ($permText -match "## Default rules")
    Add-Result "v020b.permissions.resolution_section" "permissions.md has ## Resolution algorithm" `
        ($permText -match "## Resolution algorithm")

    $permKeys = @("edit", "bash", "external_directory", "task",
                  "snapshot", "revert", "todowrite", "question")
    foreach ($key in $permKeys) {
        Add-Result "v020b.permissions.default.$key" "permissions.md default rule covers $key" `
            ($permText -match "(?m)^- (allow|ask|deny)\s+\|\s+$([regex]::Escape($key))\s+\|")
    }
    Add-Result "v020b.permissions.todowrite_allow" "permissions.md defaults todowrite to allow" `
        ($permText -match "(?m)^- allow\s+\|\s+todowrite")
}

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v020b.dtdmd.permission_cmd" "dtd.md has /dtd permission command body" `
    ($dtdMd -match '### `/dtd permission \[list\|show\|allow\|deny\|ask\|revoke\|rules\]')
$permissionForms = @("list", "show", "allow", "deny", "ask", "revoke", "rules")
foreach ($form in $permissionForms) {
    Add-Result "v020b.dtdmd.form.$form" "dtd.md /dtd permission documents $form form" `
        ($dtdMd -match "/dtd permission $form")
}
Add-Result "v020b.dtdmd.permission_required" "dtd.md mentions PERMISSION_REQUIRED capsule reason" `
    ($dtdMd -match "PERMISSION_REQUIRED")
Add-Result "v020b.dtdmd.doctor_lists_permission" "dtd.md doctor lists Permission ledger (v0.2.0b)" `
    ($dtdMd -match "Permission ledger \(v0\.2\.0b\)")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v020b.doctor_ref.section" "doctor-checks ref has ## Permission ledger (v0.2.0b)" `
    ($doctorRef -match "## Permission ledger \(v0\.2\.0b\)")
$doctorCodes = @(
    "permission_ledger_missing",
    "permission_rule_invalid",
    "permission_key_unknown",
    "permission_decision_invalid",
    "permission_bash_too_broad",
    "permission_external_directory_too_broad",
    "permission_rule_overlap",
    "permission_rule_unknown_worker",
    "permission_rule_expired",
    "permission_ledger_too_large",
    "permission_pending_orphan"
)
foreach ($code in $doctorCodes) {
    Add-Result "v020b.doctor_ref.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v020b.state.section" "state.md has ## Permission ledger (v0.2.0b)" `
    ($stateMd -match "## Permission ledger \(v0\.2\.0b\)")
Add-Result "v020b.state.pending_field" "state.md has pending_permission_request field" `
    ($stateMd -match "(?m)^- pending_permission_request:")

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 50..59) {
    Add-Result "v020b.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v020b.scenarios.section_header" "test-scenarios.md has v0.2.0b section header" `
    ($scenariosMd -match "## v0\.2\.0b .* Permission Ledger")

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v020b.manifest.permissions" "build-manifest includes .dtd/permissions.md" `
    ($builderText -match [regex]::Escape(".dtd/permissions.md"))
Add-Result "v020b.manifest.checker" "build-manifest includes scripts/check-v020b.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v020b.ps1"))

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
Write-Host "V020B_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
