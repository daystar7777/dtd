# DTD v0.3.0a release-contract checks (cross-run loop guard)
#
# Validates:
#   - .dtd/reference/v030a-cross-run-loop-guard.md exists with required sections
#   - reference/index.md catalog has v030a-cross-run-loop-guard row
#   - dtd.md has /dtd loop-guard command body
#   - dtd.md doctor list includes Cross-run loop guard (v0.3.0a)
#   - state.md has v0.3.0a sections (Cross-run loop guard + Project identity)
#   - config.md has ## cross-run loop guard (v0.3.0a)
#   - reference/run-loop.md finalize_run has step 5d capture-before-clear
#   - reference/doctor-checks.md has v0.3.0a Cross-run loop guard checks
#   - test-scenarios.md has scenarios 126-133
#   - .dtd/.gitignore covers cross-run-loop-guard.md
#   - scripts/build-manifest.ps1 includes new reference + check-v030a.ps1

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

# ─── reference/v030a-cross-run-loop-guard.md ──────────────────────────────────

$v030aRef = Read-Text ".dtd/reference/v030a-cross-run-loop-guard.md"

Add-Result "v030a.ref.summary" "v030a ref has Summary section" `
    ($v030aRef -match "(?m)^## Summary")
Add-Result "v030a.ref.anchor" "v030a ref has Anchor section" `
    ($v030aRef -match "(?m)^## Anchor")
Add-Result "v030a.ref.stable_signature" "v030a ref documents stable cross-run signature formula" `
    ($v030aRef -match "## Stable cross-run signature \(P1\.1 amendment\)")
$signatureComponents = @(
    "repo_identity_hash",
    "normalized_task_goal_hash",
    "worker_provider_model_or_capability",
    "output_path_scope_hash",
    "failure_class",
    "normalized_error_hash"
)
foreach ($comp in $signatureComponents) {
    Add-Result "v030a.ref.signature.$comp" "v030a ref defines $comp" `
        ($v030aRef -match [regex]::Escape($comp))
}
Add-Result "v030a.ref.repo_identity_priority" "v030a ref documents repo_identity_hash priority (PRIMARY → SECONDARY → TERTIARY)" `
    (($v030aRef -match "PRIMARY:") -and ($v030aRef -match "SECONDARY:") -and ($v030aRef -match "TERTIARY:"))
Add-Result "v030a.ref.no_absolute_path_primary" "v030a ref says absolute path is NEVER primary" `
    ($v030aRef -match "(?s)Absolute path is NEVER the primary identity")
Add-Result "v030a.ref.capture_before_clear" "v030a ref documents capture-before-clear semantics" `
    (($v030aRef -match "capture-before-clear") -or ($v030aRef -match "Capture .*BEFORE clearing"))
Add-Result "v030a.ref.tombstone_prune" "v030a ref says prune appends tombstone (P1 additional)" `
    (($v030aRef -match "tombstone") -and ($v030aRef -match "not a physical row removal|not physical|append.*tombstone.*not"))
Add-Result "v030a.ref.compact_status" "v030a ref says compact status default + --full for prior resolutions" `
    (($v030aRef -match "compact default") -or ($v030aRef -match "compact status display"))
Add-Result "v030a.ref.capsule_schema" "v030a ref has LOOP_GUARD_CROSS_RUN_HIT capsule schema" `
    ($v030aRef -match "awaiting_user_reason: LOOP_GUARD_CROSS_RUN_HIT")

# ─── reference/index.md ──────────────────────────────────────────────────────

$indexRef = Read-Text ".dtd/reference/index.md"

Add-Result "v030a.index.row" "index.md has v030a-cross-run-loop-guard row" `
    ($indexRef -match '(?m)^\| `v030a-cross-run-loop-guard` ')
Add-Result "v030a.index.canonical_marker" "index.md marks v030a topic canonical" `
    ($indexRef -match '(?m)^\| `v030a-cross-run-loop-guard` .*\| canonical \|')
Add-Result "v030a.index.expansion_note" "index.md mentions v0.3.0a expansion (13 → 14 topics)" `
    ($indexRef -match "v0\.3\.0a expansion.*13 to 14|13 .*14")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v030a.dtdmd.command_body" "dtd.md has /dtd loop-guard command body" `
    ($dtdMd -match '### `/dtd loop-guard \[show\|prune\]`')
Add-Result "v030a.dtdmd.show_form" "dtd.md documents loop-guard show form" `
    ($dtdMd -match "/dtd loop-guard show")
Add-Result "v030a.dtdmd.prune_form" "dtd.md documents loop-guard prune form" `
    ($dtdMd -match "/dtd loop-guard prune")
Add-Result "v030a.dtdmd.stable_p11_pointer" "dtd.md mentions Codex P1.1 stable signature amendment" `
    ($dtdMd -match "P1\.1")
Add-Result "v030a.dtdmd.capture_before_clear" "dtd.md mentions capture-before-clear" `
    ($dtdMd -match "[Cc]apture-before-clear|capture.*BEFORE")
Add-Result "v030a.dtdmd.doctor_lists_v030a" "dtd.md doctor lists Cross-run loop guard (v0.3.0a)" `
    ($dtdMd -match "Cross-run loop guard \(v0\.3\.0a\)")

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v030a.state.section" "state.md has ## Cross-run loop guard (v0.3.0a)" `
    ($stateMd -match "## Cross-run loop guard \(v0\.3\.0a\)")
$stateKeys = @("cross_run_loop_guard_status", "cross_run_match_count",
               "pending_cross_run_signature", "last_cross_run_check_at",
               "last_cross_run_finalize_at")
foreach ($key in $stateKeys) {
    Add-Result "v030a.state.key.$key" "state.md cross-run section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030a.state.project_id_section" "state.md has ## Project identity (v0.3.0a)" `
    ($stateMd -match "## Project identity \(v0\.3\.0a\)")
Add-Result "v030a.state.project_id_field" "state.md has project_id field" `
    ($stateMd -match "(?m)^- project_id:")

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v030a.config.section" "config.md has ## cross-run loop guard (v0.3.0a)" `
    ($configMd -match "## cross-run loop guard \(v0\.3\.0a\)")
$configKeys = @("cross_run_loop_guard_enabled", "cross_run_threshold",
                "cross_run_retention_days", "cross_run_max_signatures")
foreach ($key in $configKeys) {
    Add-Result "v030a.config.key.$key" "config.md cross-run section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── reference/run-loop.md ───────────────────────────────────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v030a.runloop.step_5d" "run-loop.md finalize_run has step 5d capture-before-clear" `
    ($runLoopRef -match "5d\.\s*\*\*Cross-run loop-guard capture-before-clear\*\* \(v0\.3\.0a R0\)")
Add-Result "v030a.runloop.step_5d_before_step_7" "run-loop.md says step 5d runs BEFORE step 7" `
    ($runLoopRef -match "(?s)MUST run BEFORE\s+step 7")
Add-Result "v030a.runloop.signature_count_check" "run-loop.md step 5d checks loop_guard_signature_count >= 1" `
    ($runLoopRef -match "loop_guard_signature_count >= 1")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v030a.doctor.section" "doctor-checks ref has v0.3.0a Cross-run loop guard checks" `
    ($doctorRef -match "v0\.3\.0a Cross-run loop guard checks")
$doctorCodes = @(
    "cross_run_ledger_missing",
    "cross_run_ledger_row_invalid",
    "cross_run_ledger_overflow",
    "cross_run_signature_expired_unpruned",
    "cross_run_pending_orphan",
    "cross_run_status_invalid",
    "cross_run_finalize_capture_missed",
    "cross_run_failure_class_unknown",
    "project_id_unset_using_fallback"
)
foreach ($code in $doctorCodes) {
    Add-Result "v030a.doctor.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── .dtd/.gitignore ─────────────────────────────────────────────────────────

$gitignoreText = Read-Text ".dtd/.gitignore"

Add-Result "v030a.gitignore.cross_run" ".dtd/.gitignore covers cross-run-loop-guard.md" `
    ($gitignoreText -match "(?m)^cross-run-loop-guard\.md")

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030a.scenarios.section_header" "test-scenarios.md has v0.3.0a section header" `
    ($scenariosMd -match "## v0\.3\.0a .* Cross-run loop guard")
foreach ($n in 126..133) {
    Add-Result "v030a.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030a.scenarios.r1_section_header" "test-scenarios.md has v0.3.0a R1 section header" `
    ($scenariosMd -match "## v0\.3\.0a R1 .* Cross-run loop guard runtime")
foreach ($n in 166..173) {
    Add-Result "v030a.scenarios.r1_$n" "test-scenarios.md has R1 scenario $n" `
        ($scenariosMd -match "### $n\.")
}

# ─── reference/v030a-cross-run-loop-guard.md (R1 sections) ──────────────────

$v030aRef = Read-Text ".dtd/reference/v030a-cross-run-loop-guard.md"

Add-Result "v030a.r1_ref.section" "v030a ref has ## R1 runtime contract section" `
    ($v030aRef -match "(?m)^## R1 runtime contract")
Add-Result "v030a.r1_ref.match_algo" "v030a R1 ref documents match algorithm" `
    (($v030aRef -match "Match algorithm") -and ($v030aRef -match "match_cross_run\("))
Add-Result "v030a.r1_ref.tombstone_precedence" "v030a R1 ref documents tombstone precedence" `
    ($v030aRef -match "Tombstone precedence")
Add-Result "v030a.r1_ref.retention_pruning" "v030a R1 ref documents retention pruning" `
    (($v030aRef -match "Pruning at finalize_run") -and `
     ($v030aRef -match "finalize_run_step_5d_prune"))
Add-Result "v030a.r1_ref.migration" "v030a R1 ref documents migration via rehash" `
    (($v030aRef -match "Migration from v0\.2\.1") -and `
     ($v030aRef -match "/dtd loop-guard rehash"))
Add-Result "v030a.r1_ref.concurrent" "v030a R1 ref documents concurrent run handling" `
    ($v030aRef -match "Concurrent run handling")
Add-Result "v030a.r1_ref.show_format" "v030a R1 ref documents /dtd loop-guard show format" `
    ($v030aRef -match "/dtd loop-guard show.*R1 output format")
Add-Result "v030a.r1_ref.rehash_command" "v030a R1 ref documents /dtd loop-guard rehash command" `
    ($v030aRef -match "/dtd loop-guard rehash.*admin command")
Add-Result "v030a.r1_ref.r1_scenarios" "v030a R1 ref lists scenarios 166-173" `
    ($v030aRef -match "(?s)R1 acceptance scenarios.*?166.*?173")

# v030a R1 doctor codes
$v030aR1DoctorCodes = @(
    "cross_run_retention_prune_unrun",
    "cross_run_migration_required",
    "cross_run_concurrent_finalize_detected",
    "cross_run_show_no_active_signatures_after_hit",
    "cross_run_rehash_in_progress",
    "cross_run_signature_collision"
)
foreach ($code in $v030aR1DoctorCodes) {
    Add-Result "v030a.doctor.r1_code.$code" "doctor-checks ref defines R1 $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030a.doctor.r1_section" "doctor-checks ref has v0.3.0a R1 runtime checks header" `
    ($doctorRef -match "v0\.3\.0a R1 runtime checks")

# v030a R1 state fields
$v030aR1StateKeys = @("last_cross_run_rehash_at", "cross_run_rehash_in_progress")
foreach ($key in $v030aR1StateKeys) {
    Add-Result "v030a.state.r1_key.$key" "state.md cross-run section has R1 $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030a.manifest.reference" "build-manifest includes reference/v030a-cross-run-loop-guard.md" `
    ($builderText -match [regex]::Escape(".dtd/reference/v030a-cross-run-loop-guard.md"))
Add-Result "v030a.manifest.checker" "build-manifest includes scripts/check-v030a.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030a.ps1"))

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
Write-Host "V030A_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
