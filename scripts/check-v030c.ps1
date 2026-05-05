# DTD v0.3.0c release-contract checks (multi-worker consensus)
#
# Validates:
#   - .dtd/reference/v030c-consensus.md exists with required sections
#   - reference/index.md catalog has v030c-consensus row
#   - dtd.md has /dtd consensus command body + 11-key permission table
#   - dtd.md doctor list includes Consensus state (v0.3.0c)
#   - permissions.md ## Default rules has task_consensus
#   - state.md has ## Consensus state (v0.3.0c)
#   - state.md awaiting_user_reason enum lists CONSENSUS_DISAGREEMENT + CONSENSUS_PARTIAL_FAILURE
#   - config.md has ## consensus (v0.3.0c)
#   - reference/plan-schema.md has v0.3.0c optional attributes section
#   - reference/doctor-checks.md has v0.3.0c Consensus state checks
#   - reference/doctor-checks.md ## Permission ledger lists 11-key set
#   - test-scenarios.md has scenarios 134-141
#   - scripts/check-v020b.ps1 still valid (10-key base)
#   - scripts/build-manifest.ps1 includes new reference + check-v030c.ps1

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

# ─── reference/v030c-consensus.md ─────────────────────────────────────────────

$v030cRef = Read-Text ".dtd/reference/v030c-consensus.md"

Add-Result "v030c.ref.summary" "v030c ref has Summary section" `
    ($v030cRef -match "(?m)^## Summary")
Add-Result "v030c.ref.anchor" "v030c ref has Anchor section" `
    ($v030cRef -match "(?m)^## Anchor")
$strategies = @("first_passing", "quality_rubric", "reviewer_consensus", "vote_unanimous")
foreach ($s in $strategies) {
    Add-Result "v030c.ref.strategy.$s" "v030c ref documents strategy $s" `
        ($v030cRef -match [regex]::Escape($s))
}
Add-Result "v030c.ref.staged_outputs_p14" "v030c ref documents Codex P1.4 staged outputs" `
    (($v030cRef -match "isolated staging") -and `
     ($v030cRef -match "no candidate may apply"))
Add-Result "v030c.ref.late_never_apply" "v030c ref says late results NEVER apply" `
    ($v030cRef -match "(?s)late results.*?MUST NEVER APPLY|LATE RESULTS MUST NEVER APPLY")
Add-Result "v030c.ref.group_lock" "v030c ref documents single group lock (not per-worker)" `
    (($v030cRef -match "Single output-path lock") -or ($v030cRef -match "Single lock covers all N"))
Add-Result "v030c.ref.permission_p15" "v030c ref documents Codex P1.5 11-key invariant" `
    (($v030cRef -match "task_consensus") -and ($v030cRef -match "11.key|11-key"))
Add-Result "v030c.ref.disagreement_capsule" "v030c ref has CONSENSUS_DISAGREEMENT capsule" `
    ($v030cRef -match "awaiting_user_reason: CONSENSUS_DISAGREEMENT")
Add-Result "v030c.ref.partial_failure_capsule" "v030c ref has CONSENSUS_PARTIAL_FAILURE capsule" `
    ($v030cRef -match "awaiting_user_reason: CONSENSUS_PARTIAL_FAILURE")
Add-Result "v030c.ref.reviewer_distinct" "v030c ref enforces reviewer distinct from candidates" `
    (($v030cRef -match "DISTINCT from") -and ($v030cRef -match "no self-review"))
$timesChar = [char]0x00D7
Add-Result "v030c.ref.cost_multiplier" "v030c ref mentions N$timesChar cost multiplier" `
    ($v030cRef -match "N\s*$timesChar\s*cost|N$timesChar|3$timesChar cost")

# ─── reference/index.md ──────────────────────────────────────────────────────

$indexRef = Read-Text ".dtd/reference/index.md"

Add-Result "v030c.index.row" "index.md has v030c-consensus row" `
    ($indexRef -match '(?m)^\| `v030c-consensus` ')
Add-Result "v030c.index.canonical_marker" "index.md marks v030c-consensus canonical" `
    ($indexRef -match '(?m)^\| `v030c-consensus` .*\| canonical \|')
Add-Result "v030c.index.expansion_note" "index.md mentions v0.3.0c expansion (14 → 15)" `
    ($indexRef -match "v0\.3\.0c|14 .*15|13 .* 14 .* 15")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v030c.dtdmd.command_body" "dtd.md has /dtd consensus command body" `
    ($dtdMd -match '### `/dtd consensus show \[<task_id>\|--active\]` \(v0\.3\.0c\)')
Add-Result "v030c.dtdmd.show_form" "dtd.md /dtd consensus show form" `
    ($dtdMd -match "/dtd consensus show <task_id>")
Add-Result "v030c.dtdmd.active_form" "dtd.md /dtd consensus show --active form" `
    ($dtdMd -match "/dtd consensus show --active")
Add-Result "v030c.dtdmd.eleven_key_table" "dtd.md says 11-key permission set" `
    ($dtdMd -match "canonical 11-key set")
Add-Result "v030c.dtdmd.task_consensus_row" "dtd.md permission table has task_consensus row" `
    ($dtdMd -match '(?m)^\| `task_consensus`')
Add-Result "v030c.dtdmd.doctor_lists_consensus" "dtd.md doctor lists Consensus state (v0.3.0c)" `
    ($dtdMd -match "Consensus state \(v0\.3\.0c\)")
Add-Result "v030c.dtdmd.4_strategies" "dtd.md /dtd consensus mentions 4 strategies" `
    (($dtdMd -match "first_passing") -and ($dtdMd -match "quality_rubric") -and `
     ($dtdMd -match "reviewer_consensus") -and ($dtdMd -match "vote_unanimous"))
Add-Result "v030c.dtdmd.staged_outputs" "dtd.md /dtd consensus says staged isolation" `
    (($dtdMd -match "ISOLATED staging") -and ($dtdMd -match "Codex P1\.4"))

# ─── permissions.md ──────────────────────────────────────────────────────────

$permissionsMd = Read-Text ".dtd/permissions.md"

Add-Result "v030c.permissions.task_consensus_default" "permissions.md ## Default rules has task_consensus" `
    ($permissionsMd -match "(?m)^- ask\s+\|\s+task_consensus\s+\|")

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v030c.state.section" "state.md has ## Consensus state (v0.3.0c)" `
    ($stateMd -match "## Consensus state \(v0\.3\.0c\)")
$stateKeys = @("active_consensus_task", "active_consensus_n",
               "active_consensus_strategy", "active_consensus_group_lock",
               "consensus_outcomes")
foreach ($key in $stateKeys) {
    Add-Result "v030c.state.key.$key" "state.md consensus section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030c.state.disagreement_reason" "state.md awaiting_user_reason lists CONSENSUS_DISAGREEMENT" `
    ($stateMd -match "CONSENSUS_DISAGREEMENT")
Add-Result "v030c.state.partial_failure_reason" "state.md awaiting_user_reason lists CONSENSUS_PARTIAL_FAILURE" `
    ($stateMd -match "CONSENSUS_PARTIAL_FAILURE")

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v030c.config.section" "config.md has ## consensus (v0.3.0c)" `
    ($configMd -match "## consensus \(v0\.3\.0c\)")
$configKeys = @("default_strategy", "consensus_confirm_each_call",
                "max_consensus_n", "consensus_lock_acquire_timeout_sec",
                "whitespace_normalization_for_vote", "late_result_action")
foreach ($key in $configKeys) {
    Add-Result "v030c.config.key.$key" "config.md consensus section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030c.config.rubric" "config.md consensus has rubric (4 weights)" `
    (($configMd -match "(?s)rubric:.*?output_paths_match.*?weight: 0\.4") -and `
     ($configMd -match "no_protocol_violation"))

# ─── reference/plan-schema.md ────────────────────────────────────────────────

$planSchemaRef = Read-Text ".dtd/reference/plan-schema.md"

Add-Result "v030c.planschema.section" "plan-schema.md has v0.3.0c optional attributes section" `
    ($planSchemaRef -match "## v0\.3\.0c optional attributes")
$planAttrs = @('consensus="<N>"', 'consensus-strategy=', 'consensus-reviewer=', "<consensus-workers>")
foreach ($attr in $planAttrs) {
    $key = ($attr -replace '[^a-zA-Z0-9]','_')
    Add-Result "v030c.planschema.$key" "plan-schema.md documents $attr" `
        ($planSchemaRef -match [regex]::Escape($attr))
}

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v030c.doctor.section" "doctor-checks ref has v0.3.0c Consensus state checks" `
    ($doctorRef -match "v0\.3\.0c Consensus state checks")
$doctorCodes = @(
    "plan_consensus_invalid",
    "plan_consensus_exceeds_max",
    "plan_consensus_strategy_invalid",
    "plan_consensus_reviewer_missing",
    "plan_consensus_reviewer_in_candidate_set",
    "plan_consensus_unknown_worker",
    "consensus_state_drift",
    "consensus_loser_applied_violation",
    "consensus_late_stale_applied_violation",
    "permission_task_consensus_missing",
    "consensus_per_worker_lock_violation"
)
foreach ($code in $doctorCodes) {
    Add-Result "v030c.doctor.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030c.doctor.eleven_key_set" "doctor-checks Permission ledger lists 11-key set" `
    ($doctorRef -match "task_consensus.*11-key|11-key.*task_consensus")

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030c.scenarios.section_header" "test-scenarios.md has v0.3.0c section header" `
    ($scenariosMd -match "## v0\.3\.0c .* Multi-worker consensus")
foreach ($n in 134..141) {
    Add-Result "v030c.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030c.scenarios.r1_section_header" "test-scenarios.md has v0.3.0c R1 section header" `
    ($scenariosMd -match "## v0\.3\.0c R1 .* Multi-worker consensus dispatch runtime")
foreach ($n in 174..181) {
    Add-Result "v030c.scenarios.r1_$n" "test-scenarios.md has R1 scenario $n" `
        ($scenariosMd -match "### $n\.")
}

# ─── reference/v030c-consensus.md (R1 sections) ──────────────────────────────

Add-Result "v030c.r1_ref.section" "v030c ref has ## R1 runtime contract section" `
    ($v030cRef -match "(?m)^## R1 runtime contract")
Add-Result "v030c.r1_ref.parallel_dispatch" "v030c R1 ref documents parallel dispatch algorithm" `
    (($v030cRef -match "Parallel dispatch algorithm") -and ($v030cRef -match "dispatch_consensus\("))
Add-Result "v030c.r1_ref.lock_acquire" "v030c R1 ref documents lock acquisition algorithm" `
    (($v030cRef -match "Lock acquisition") -and ($v030cRef -match "acquire_consensus_group_lock\("))
Add-Result "v030c.r1_ref.lock_timeout_capsule" "v030c R1 ref defines CONSENSUS_LOCK_TIMEOUT capsule" `
    ($v030cRef -match "CONSENSUS_LOCK_TIMEOUT")
Add-Result "v030c.r1_ref.lock_timeout_full_capsule" "v030c R1 lock-timeout path uses the full decision capsule" `
    (($v030cRef -match "decision_id: dec-NNN") -and `
     ($v030cRef -match "decision_default: wait_more") -and `
     ($v030cRef -match "user_decision_options: \[wait_more, retry_lock, demote_single, stop\]"))
Add-Result "v030c.r1_ref.cancellation" "v030c R1 ref documents cancellation algorithm" `
    (($v030cRef -match "cancel_inflight\(") -and ($v030cRef -match "cancellation_pending"))
Add-Result "v030c.r1_ref.strategy_first_passing" "v030c R1 ref documents first_passing algorithm" `
    ($v030cRef -match "strategy_first_passing\(")
Add-Result "v030c.r1_ref.strategy_quality_rubric" "v030c R1 ref documents quality_rubric algorithm" `
    ($v030cRef -match "strategy_quality_rubric\(")
Add-Result "v030c.r1_ref.strategy_reviewer_consensus" "v030c R1 ref documents reviewer_consensus algorithm" `
    ($v030cRef -match "strategy_reviewer_consensus\(")
Add-Result "v030c.r1_ref.strategy_vote_unanimous" "v030c R1 ref documents vote_unanimous algorithm" `
    ($v030cRef -match "strategy_vote_unanimous\(")
Add-Result "v030c.r1_ref.reviewer_prompt_template" "v030c R1 ref provides reviewer prompt template" `
    (($v030cRef -match "Consensus reviewer") -and ($v030cRef -match "::winner: <worker_id>::"))
Add-Result "v030c.r1_ref.staging_cleanup" "v030c R1 ref documents staging cleanup" `
    ($v030cRef -match "cleanup_staging\(")
Add-Result "v030c.r1_ref.apply_validates_real_targets" "v030c R1 apply validates real target paths before applying staged winner" `
    (($v030cRef -match "validate_declared_output_paths\(target_paths") -and `
     ($v030cRef -match "validate_path_policy\(target_paths") -and `
     ($v030cRef -match "resolve_permission\(`"edit`", target_paths") -and `
     ($v030cRef -match "snapshot_create_for_outputs\(target_paths") -and `
     ($v030cRef -notmatch "resolve_permission\(`"edit`", winner_future\.staged_dir") -and `
     ($v030cRef -notmatch "snapshot_create_for_outputs\(winner_future\.staged_dir"))
Add-Result "v030c.r1_ref.retry_failed_keeps_lock" "v030c R1 retry_failed keeps group lock while reusing successful staged candidates" `
    (($v030cRef -match "retry_failed.*keep the existing group lock") -and `
     ($v030cRef -match "Lock invariant") -and `
     ($v030cRef -match "retry_all.*releases"))
Add-Result "v030c.r1_ref.r1_scenarios" "v030c R1 ref lists scenarios 174-181" `
    ($v030cRef -match "(?s)R1 acceptance scenarios.*?174.*?181")

# v030c R1 doctor codes (additional)
$v030cR1DoctorCodes = @(
    "consensus_staging_orphan",
    "consensus_lock_timeout_recurring",
    "consensus_reviewer_unparseable",
    "consensus_rubric_all_tied",
    "consensus_skill_missing"
)
foreach ($code in $v030cR1DoctorCodes) {
    Add-Result "v030c.doctor.r1_code.$code" "doctor-checks ref defines R1 $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030c.doctor.r1_section" "doctor-checks ref has v0.3.0c R1 runtime checks header" `
    ($doctorRef -match "v0\.3\.0c R1 runtime checks")

# v030c R1 state fields
$v030cR1StateKeys = @("last_consensus_lock_acquire_attempt_at",
                       "last_consensus_strategy_outcome")
foreach ($key in $v030cR1StateKeys) {
    Add-Result "v030c.state.r1_key.$key" "state.md Consensus section has R1 $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030c.state.r1_capsule_enum" "state.md awaiting_user_reason enum lists CONSENSUS_LOCK_TIMEOUT" `
    ($stateMd -match "CONSENSUS_LOCK_TIMEOUT")

# v030c R1 config additions
Add-Result "v030c.config.r1_reviewer_timeout" "config.md consensus section has consensus_reviewer_timeout_sec" `
    ($configMd -match "(?m)^- consensus_reviewer_timeout_sec:")

# v030c R1 NEW skill file
$skillPath = Join-Path $RepoRoot ".dtd/skills/consensus-reviewer.md"
Add-Result "v030c.r1_skill.exists" ".dtd/skills/consensus-reviewer.md (R1 NEW) exists" `
    (Test-Path -LiteralPath $skillPath)
if (Test-Path -LiteralPath $skillPath) {
    $skillText = Read-Text ".dtd/skills/consensus-reviewer.md"
    Add-Result "v030c.r1_skill.winner_token" "consensus-reviewer skill specifies ::winner: token" `
        ($skillText -match "::winner: <worker_id>::")
    Add-Result "v030c.r1_skill.distinct_invariant" "consensus-reviewer skill mentions reviewer-distinct (Codex P1)" `
        (($skillText -match "DISTINCT") -or ($skillText -match "no self-review"))
    Add-Result "v030c.r1_skill.none_correct_token" "consensus-reviewer skill defines NONE_CORRECT escape" `
        ($skillText -match "NONE_CORRECT")
}

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030c.manifest.reference" "build-manifest includes reference/v030c-consensus.md" `
    ($builderText -match [regex]::Escape(".dtd/reference/v030c-consensus.md"))
Add-Result "v030c.manifest.checker" "build-manifest includes scripts/check-v030c.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030c.ps1"))
Add-Result "v030c.manifest.r1_skill" "build-manifest includes skills/consensus-reviewer.md" `
    ($builderText -match [regex]::Escape(".dtd/skills/consensus-reviewer.md"))

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
Write-Host "V030C_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
