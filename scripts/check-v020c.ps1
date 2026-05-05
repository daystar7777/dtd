# DTD v0.2.0c release-contract checks
#
# Validates that the v0.2.0c deliverables match the design contract:
#   - .dtd/snapshots/ directory exists with index.md template
#   - dtd.md has /dtd snapshot + /dtd revert command bodies
#   - dtd.md doctor section lists Snapshot state (v0.2.0c)
#   - reference/doctor-checks.md has ## Snapshot state (v0.2.0c)
#   - state.md has ## Snapshot state (v0.2.0c) section with 6 fields
#   - config.md has ## snapshot (v0.2.0c) section with 8 keys
#   - test-scenarios.md has scenarios 60-69
#   - .dtd/.gitignore covers snapshots/snap-*/ and archived/
#   - scripts/build-manifest.ps1 includes snapshots/index.md + check-v020c.ps1
#
# Usage:
#   pwsh ./scripts/check-v020c.ps1
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

# ─── snapshots dir + index.md ────────────────────────────────────────────────

$snapshotsDir = Join-Path $RepoRoot ".dtd/snapshots"
Add-Result "v020c.snapshots.dir" ".dtd/snapshots/ directory exists" `
    (Test-Path -LiteralPath $snapshotsDir)

$snapshotIndexPath = Join-Path $snapshotsDir "index.md"
$snapshotIndexExists = Test-Path -LiteralPath $snapshotIndexPath
Add-Result "v020c.snapshots.index" ".dtd/snapshots/index.md template exists" $snapshotIndexExists
if ($snapshotIndexExists) {
    $idxText = Get-Content -LiteralPath $snapshotIndexPath -Raw
    Add-Result "v020c.snapshots.index.active_section" "snapshots/index.md has ## Active snapshots" `
        ($idxText -match "## Active snapshots")
    Add-Result "v020c.snapshots.index.archived_section" "snapshots/index.md has ## Archived snapshots" `
        ($idxText -match "## Archived snapshots")
}

# ─── .dtd/.gitignore ──────────────────────────────────────────────────────────

$gitignoreText = Read-Text ".dtd/.gitignore"
Add-Result "v020c.gitignore.snap_dirs" ".dtd/.gitignore ignores snapshots/snap-*/" `
    ($gitignoreText -match "(?m)^snapshots/snap-\*/")
Add-Result "v020c.gitignore.archived" ".dtd/.gitignore ignores snapshots/archived/" `
    ($gitignoreText -match "(?m)^snapshots/archived/")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v020c.dtdmd.snapshot_cmd" "dtd.md has /dtd snapshot command body" `
    ($dtdMd -match '### `/dtd snapshot \[list\|show\|purge\|rotate\]')
Add-Result "v020c.dtdmd.revert_cmd" "dtd.md has /dtd revert command body" `
    ($dtdMd -match '### `/dtd revert <last\|attempt')
$snapshotForms = @("list", "show", "purge", "rotate")
foreach ($form in $snapshotForms) {
    Add-Result "v020c.dtdmd.snapshot.$form" "dtd.md /dtd snapshot documents $form form" `
        ($dtdMd -match "/dtd snapshot $form")
}
$revertForms = @("last", "attempt", "task")
foreach ($form in $revertForms) {
    Add-Result "v020c.dtdmd.revert.$form" "dtd.md /dtd revert documents $form form" `
        ($dtdMd -match "/dtd revert $form")
}
Add-Result "v020c.dtdmd.three_modes" "dtd.md documents 3 snapshot modes" `
    (($dtdMd -match "metadata-only") -and ($dtdMd -match "preimage") -and ($dtdMd -match "patch"))
Add-Result "v020c.dtdmd.small_text_preimage" "dtd.md requires normal small text outputs to use preimage" `
    (($dtdMd -match "Small tracked text") -and ($dtdMd -match "use .*preimage.*not .*metadata-only"))
Add-Result "v020c.dtdmd.partial_revert" "dtd.md mentions PARTIAL_REVERT capsule" `
    ($dtdMd -match "PARTIAL_REVERT")
Add-Result "v020c.dtdmd.proceed_unsafe" "dtd.md mentions proceed_unsafe option" `
    ($dtdMd -match "proceed_unsafe")
Add-Result "v020c.dtdmd.doctor_lists_snapshot" "dtd.md doctor lists Snapshot state (v0.2.0c)" `
    ($dtdMd -match "Snapshot state \(v0\.2\.0c\)")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v020c.doctor_ref.section" "doctor-checks ref has ## Snapshot state (v0.2.0c)" `
    ($doctorRef -match "## Snapshot state \(v0\.2\.0c\)")
$doctorCodes = @(
    "snapshot_dir_missing",
    "snapshot_index_drift",
    "snapshot_manifest_missing",
    "snapshot_size_exceeded",
    "snapshot_rotation_overdue",
    "snapshot_preimage_corrupted",
    "snapshot_patch_drift",
    "snapshot_state_drift",
    "revert_state_drift"
)
foreach ($code in $doctorCodes) {
    Add-Result "v020c.doctor_ref.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v020c.state.section" "state.md has ## Snapshot state (v0.2.0c)" `
    ($stateMd -match "## Snapshot state \(v0\.2\.0c\)")
$stateKeys = @("last_snapshot_id", "last_snapshot_at", "snapshots_total",
               "snapshots_size_bytes", "last_revert_id", "last_revert_at")
foreach ($key in $stateKeys) {
    Add-Result "v020c.state.key.$key" "state.md Snapshot section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v020c.config.section" "config.md has ## snapshot (v0.2.0c)" `
    ($configMd -match "## snapshot \(v0\.2\.0c\)")
$configKeys = @("enabled", "preimage_size_threshold", "patch_max_size",
                "binary_extensions", "retention_days", "auto_rotate",
                "max_total_size_mb", "on_snapshot_fail")
foreach ($key in $configKeys) {
    Add-Result "v020c.config.key.$key" "config.md snapshot section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 60..69) {
    Add-Result "v020c.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v020c.scenarios.section_header" "test-scenarios.md has v0.2.0c section header" `
    ($scenariosMd -match "## v0\.2\.0c .* Snapshot")
Add-Result "v020c.scenarios.small_text_preimage" "scenario 60 expects src/api/users.ts preimage" `
    (($scenariosMd -match "files/src__api__users\.ts\.preimage") -and
     ($scenariosMd -notmatch "files/src__api__users\.ts\.metadata"))

# ─── R1 wiring: run-loop.md + permissions.md + ko.md ─────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v020c.r1.run_loop_step_6_g_0" "run-loop.md has step 6.g.0 Snapshot creation hook" `
    ($runLoopRef -match "6\.g\.0\*\*\s*\*\*Snapshot creation hook\*\*")
Add-Result "v020c.r1.run_loop_mode_resolution" "run-loop.md has Snapshot mode resolution (v0.2.0c R1)" `
    ($runLoopRef -match "## Snapshot mode resolution \(v0\.2\.0c R1\)")
Add-Result "v020c.r1.run_loop_revert_algorithm" "run-loop.md has Revert algorithm (v0.2.0c R1)" `
    ($runLoopRef -match "## Revert algorithm \(v0\.2\.0c R1\)")
Add-Result "v020c.r1.run_loop_8_resolution_rules" "run-loop.md mode resolution lists rules 1-8 in order" `
    (($runLoopRef -match "1\. \*\*File does not exist") -and `
     ($runLoopRef -match "2\. \*\*Permission ledger has") -and `
     ($runLoopRef -match "3\. \*\*File extension matches") -and `
     ($runLoopRef -match "4\. \*\*File size > .*preimage_size_threshold") -and `
     ($runLoopRef -match "5\. \*\*File size > .*patch_max_size") -and `
     ($runLoopRef -match "6\. \*\*File is git-tracked AND text") -and `
     ($runLoopRef -match "7\. \*\*Untracked text") -and `
     ($runLoopRef -match "8\. \*\*Default fallback"))
Add-Result "v020c.r1.run_loop_manifest_format" "run-loop.md documents manifest format with patch_format_version" `
    (($runLoopRef -match "patch_format_version") -and `
     ($runLoopRef -match "whitespace_handling: preserve_lf") -and `
     ($runLoopRef -match "## Patch artifacts"))
Add-Result "v020c.r1.run_loop_index_format" "run-loop.md documents index.md row format" `
    ($runLoopRef -match "active \| rotated \| purged \| reverted")
Add-Result "v020c.r1.run_loop_revert_permission_gate" "run-loop.md revert algorithm has permission gate first" `
    (($runLoopRef -match "Pre-revert") -and `
     ($runLoopRef -match "Permission gate.*resolve.*revert.*key"))
Add-Result "v020c.r1.run_loop_revert_lock" "run-loop.md revert acquires write locks" `
    ($runLoopRef -match "Lock acquisition.*acquire write locks")
Add-Result "v020c.r1.run_loop_partial_apply" "run-loop.md handles partial revert via PARTIAL_APPLY" `
    (($runLoopRef -match "PARTIAL_APPLY") -and ($runLoopRef -match "partial_revert"))

# Doctor R1 wiring checks
$doctorRefText = Read-Text ".dtd/reference/doctor-checks.md"
Add-Result "v020c.r1.doctor_section" "doctor-checks ref has v0.2.0c R1 wiring checks" `
    ($doctorRefText -match "v0\.2\.0c R1 wiring checks")
$r1DoctorCodes = @(
    "snapshot_manifest_field_missing",
    "snapshot_file_row_invalid",
    "snapshot_mode_invalid",
    "snapshot_patch_artifacts_missing",
    "snapshot_patch_format_unsupported",
    "snapshot_patch_whitespace_unknown",
    "snapshot_index_row_invalid",
    "snapshot_index_status_invalid",
    "snapshot_mode_policy_drift",
    "revert_audit_lineage_drift"
)
foreach ($code in $r1DoctorCodes) {
    Add-Result "v020c.r1.doctor.code.$code" "doctor-checks ref defines R1 code $code" `
        ($doctorRefText -match [regex]::Escape($code))
}

# Korean NL pack additions
$koPack = Read-Text ".dtd/locales/ko.md"
Add-Result "v020c.r1.ko_snapshot_section" "ko.md has Snapshot / revert (v0.2.0c) section" `
    ($koPack -match "### Snapshot / revert \(v0\.2\.0c\)")
Add-Result "v020c.r1.ko_revert_rows" "ko.md has Korean rows for /dtd revert + /dtd snapshot" `
    (($koPack -match "/dtd revert last") -and `
     ($koPack -match "/dtd revert task") -and `
     ($koPack -match "/dtd snapshot list") -and `
     ($koPack -match "/dtd snapshot rotate"))

# R1 scenarios
foreach ($letter in @("a", "b", "c", "d")) {
    Add-Result "v020c.r1.scenario.69$letter" "test-scenarios.md has scenario 69$letter (R1 wiring)" `
        ($scenariosMd -match "### 69$letter\.")
}

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v020c.manifest.snapshots_index" "build-manifest includes .dtd/snapshots/index.md" `
    ($builderText -match [regex]::Escape(".dtd/snapshots/index.md"))
Add-Result "v020c.manifest.checker" "build-manifest includes scripts/check-v020c.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v020c.ps1"))

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
Write-Host "V020C_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
