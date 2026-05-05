# DTD v0.2.0b release-contract checks
#
# Validates that the v0.2.0b deliverables match the design contract:
#   - .dtd/permissions.md exists with ## Active rules + ## Default rules
#     + ## Resolution algorithm sections
#   - 10 default rules cover canonical permission keys
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

    # v0.2.0b 10-key set + v0.3.0c task_consensus = 11 keys total.
    # check-v020b validates the v0.2.0b base set (10 keys) is present;
    # check-v030c validates the 11th key (task_consensus) is present.
    $permKeys = @("edit", "bash", "external_directory", "task",
                  "snapshot", "revert", "tool_relay_read",
                  "tool_relay_mutating", "todowrite", "question")
    foreach ($key in $permKeys) {
        Add-Result "v020b.permissions.default.$key" "permissions.md default rule covers $key" `
            ($permText -match "(?m)^- (allow|ask|deny)\s+\|\s+$([regex]::Escape($key))\s+\|")
    }
    Add-Result "v020b.permissions.todowrite_allow" "permissions.md defaults todowrite to allow" `
        ($permText -match "(?m)^- allow\s+\|\s+todowrite")
    Add-Result "v020b.permissions.specificity_resolution" "permissions.md resolves by scope specificity before timestamp" `
        (($permText -match "scope specificity") -and ($permText -match "timestamp DESC"))
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
Add-Result "v020b.dtdmd.permission_default_deny_once" "permission capsule defaults to deny_once" `
    ($dtdMd -match "decision_default:\s*deny_once")
Add-Result "v020b.dtdmd.permission_specificity" "dtd.md documents specificity-first permission resolution" `
    (($dtdMd -match "most specific scope first") -and ($dtdMd -match "latest timestamp second"))
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
Add-Result "v020b.state.silent_transient_section" "state.md has Silent window transient rules (v0.2.0b R1)" `
    ($stateMd -match "## Silent window transient rules \(v0\.2\.0b R1\)")
Add-Result "v020b.state.silent_transient_field" "state.md has silent_window_transient_rule_ids field" `
    ($stateMd -match "(?m)^- silent_window_transient_rule_ids:")

# ─── R1 wiring: run-loop.md + autonomy.md + dtd.md ───────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"
$autonomyRef = Read-Text ".dtd/reference/autonomy.md"
$permissionsMd = Read-Text ".dtd/permissions.md"

Add-Result "v020b.r1.run_loop_step_5_5" "run-loop.md has step 5.5 permission gate" `
    ($runLoopRef -match "5\.5\.\s*\*\*Permission ledger gate\*\*")
Add-Result "v020b.r1.run_loop_step_6_e_5" "run-loop.md has step 6.e.5 tool-relay gate" `
    ($runLoopRef -match "6\.e\.5\*\*\s*\*\*Tool-request relay gate\*\*")
Add-Result "v020b.r1.run_loop_step_6_f_0" "run-loop.md has step 6.f.0 edit permission gate" `
    ($runLoopRef -match "6\.f\.0\*\*\s*\*\*Edit permission gate\*\*")
Add-Result "v020b.r1.run_loop_key_to_step" "run-loop.md has Permission resolution at dispatch time section" `
    ($runLoopRef -match "## Permission resolution at dispatch time \(v0\.2\.0b R1\)")
Add-Result "v020b.r1.run_loop_audit_format" "run-loop.md documents audit row format with all decision values" `
    (($runLoopRef -match "auto-allow") -and ($runLoopRef -match "auto-deny") -and `
     ($runLoopRef -match "asked") -and ($runLoopRef -match "user-allow"))
Add-Result "v020b.r1.run_loop_decision_mode_auto" "run-loop.md says decision_mode auto does NOT auto-resolve ask permission" `
    ($runLoopRef -match "decision_mode: auto.*does NOT auto-resolve")
Add-Result "v020b.r1.autonomy_silent_transient" "autonomy.md has Silent transient rules (v0.2.0b R1) section" `
    ($autonomyRef -match "## Silent transient rules \(v0\.2\.0b R1\)")
Add-Result "v020b.r1.autonomy_destructive_set" "autonomy.md documents destructive_command_set patterns" `
    (($autonomyRef -match "rm -rf") -and ($autonomyRef -match "git push --force") -and `
     ($autonomyRef -match "wget \| bash"))
Add-Result "v020b.r1.autonomy_windows_destructive_set" "autonomy.md covers Windows destructive delete commands" `
    (($autonomyRef -match "Remove-Item -Recurse") -and `
     ($autonomyRef -match "cmd /c rmdir /s") -and `
     ($autonomyRef -match "del /s"))
Add-Result "v020b.r1.autonomy_revocation" "autonomy.md documents revocation algorithm" `
    ($autonomyRef -match "Revocation algorithm")
Add-Result "v020b.r1.permissions_audit_section" "permissions.md has Audit log (v0.2.0b R1) section" `
    ($permissionsMd -match "## Audit log \(v0\.2\.0b R1\)")
Add-Result "v020b.r1.permissions_audit_observational" "permissions.md says audit writes are observational" `
    ($permissionsMd -match "Observational discipline")
Add-Result "v020b.r1.dtdmd_key_to_step" "dtd.md has Permission-key run-loop step matrix" `
    ($dtdMd -match "Permission-key .* run-loop step matrix \(v0\.2\.0b R1\)")
Add-Result "v020b.r1.dtdmd_silent_interaction" "dtd.md documents silent-mode interaction (deny does NOT defer)" `
    (($dtdMd -match "Silent-mode interaction") -and `
     ($dtdMd -match "deny is\s+unambiguous") -or ($dtdMd -match "deny is unambiguous"))
Add-Result "v020b.r1.doctor_audit_checks" "doctor-checks ref has v0.2.0b R1 wiring checks" `
    ((Read-Text ".dtd/reference/doctor-checks.md") -match "v0\.2\.0b R1 wiring checks")
$doctorRefText = Read-Text ".dtd/reference/doctor-checks.md"
$r1DoctorCodes = @(
    "permission_audit_row_invalid",
    "permission_audit_log_too_large",
    "permission_audit_high_volume",
    "permission_audit_rule_drift",
    "silent_window_transient_drift",
    "silent_window_transient_orphan",
    "silent_window_transient_expired_unrevoked"
)
foreach ($code in $r1DoctorCodes) {
    Add-Result "v020b.r1.doctor.code.$code" "doctor-checks ref defines R1 code $code" `
        ($doctorRefText -match [regex]::Escape($code))
}
$koPack = Read-Text ".dtd/locales/ko.md"
Add-Result "v020b.r1.ko_permission_section" "ko.md has Permission ledger (v0.2.0b) section" `
    ($koPack -match "### Permission ledger \(v0\.2\.0b\)")
Add-Result "v020b.r1.ko_permission_rows" "ko.md has Korean rows for permission allow/deny/ask/list/revoke" `
    (($koPack -match "/dtd permission allow") -and ($koPack -match "/dtd permission deny") -and `
     ($koPack -match "/dtd permission ask") -and ($koPack -match "/dtd permission list") -and `
     ($koPack -match "/dtd permission revoke"))

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 50..59) {
    Add-Result "v020b.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
foreach ($letter in @("a", "b", "c", "d", "e")) {
    Add-Result "v020b.scenarios.59$letter" "test-scenarios.md has scenario 59$letter (R1 wiring)" `
        ($scenariosMd -match "### 59$letter\.")
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
