# DTD v0.2.1 release-contract checks
#
# Validates that the v0.2.1 deliverables match the design contract:
#   - dtd.md /dtd workers gains test --quick|--full|--connectivity|--all|
#     --assigned|--json flags + WORKER_* failure taxonomy + session-resume
#     subsection + loop guard subsection
#   - reference/workers.md has ## Worker Health Check (v0.2.1) with 17
#     stages + decision capsule + redaction model
#   - state.md has ## Worker session resume (v0.2.1) and ## Loop guard (v0.2.1)
#   - state.md awaiting_user_reason enum extends with v0.2.1 reasons
#   - config.md has ## worker-test (v0.2.1) and ## loop-guard (v0.2.1)
#   - workers.example.md has supports_session_resume field
#   - reference/doctor-checks.md has ## Worker health + runtime resilience (v0.2.1)
#   - test-scenarios.md has scenarios 70-79 + 79b/c/d
#   - scripts/build-manifest.ps1 includes check-v021.ps1
#
# Usage:
#   pwsh ./scripts/check-v021.ps1
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

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

$workerTestFlags = @("--all", "--quick", "--full", "--connectivity", "--assigned", "--json")
foreach ($flag in $workerTestFlags) {
    Add-Result "v021.dtdmd.workers_test.$flag" "dtd.md /dtd workers documents $flag" `
        ($dtdMd -match [regex]::Escape($flag))
}
Add-Result "v021.dtdmd.session_resume_section" "dtd.md has Worker session resume (v0.2.1) subsection" `
    ($dtdMd -match "Worker session resume \(v0\.2\.1\)")
Add-Result "v021.dtdmd.loop_guard_section" "dtd.md has Loop guard / doom-loop detection (v0.2.1) subsection" `
    ($dtdMd -match "Loop guard / doom-loop detection \(v0\.2\.1\)")
$resumeStrategies = @("fresh", "same-worker", "new-worker", "controller-takeover")
foreach ($strategy in $resumeStrategies) {
    Add-Result "v021.dtdmd.resume_strategy.$strategy" "dtd.md documents resume strategy $strategy" `
        ($dtdMd -match [regex]::Escape($strategy))
}
Add-Result "v021.dtdmd.loop_signature" "dtd.md documents loop_signature formula" `
    ($dtdMd -match "loop_signature\s*=\s*sha256")
Add-Result "v021.dtdmd.quick_stages_1_5" "dtd.md says quick worker test runs stages 1-5" `
    ($dtdMd -match "--quick.*stages 1-5")
Add-Result "v021.dtdmd.connectivity_stages_4_6" "dtd.md says connectivity worker test runs stages 4-6" `
    ($dtdMd -match "--connectivity.*stages 4-6")
Add-Result "v021.dtdmd.standalone_test_no_capsule" "dtd.md says standalone workers test creates no capsule" `
    (($dtdMd -match "Standalone .*/dtd workers test.*observational") -and
     ($dtdMd -match "creates no incident"))
Add-Result "v021.dtdmd.same_worker_no_raw_replay" "dtd.md forbids raw prior output replay for same-worker resume" `
    (($dtdMd -match "Same-worker resume never appends raw prior worker output") -and
     ($dtdMd -match "previous worker transcript"))
Add-Result "v021.dtdmd.loop_auto_explicit_config" "dtd.md says decision_mode auto does not imply loop auto-action" `
    (($dtdMd -match "decision_mode: auto.*does NOT imply loop-guard auto-action") -and
     ($dtdMd -match "loop_guard_threshold_action"))

# ─── reference/workers.md ────────────────────────────────────────────────────

$workersRef = Read-Text ".dtd/reference/workers.md"

Add-Result "v021.workers_ref.section" "reference/workers.md has ## Worker Health Check (v0.2.1)" `
    ($workersRef -match "## Worker Health Check \(v0\.2\.1\)")
$probeLevels = @("--quick", "--full", "--connectivity")
foreach ($level in $probeLevels) {
    Add-Result "v021.workers_ref.level.$level" "workers ref documents probe level $level" `
        ($workersRef -match [regex]::Escape($level))
}
$workerCodes = @(
    "WORKER_REGISTRY_PARSE_FAILED",
    "WORKER_NOT_FOUND",
    "WORKER_SCHEMA_INVALID",
    "WORKER_ENV_MISSING",
    "WORKER_ENDPOINT_INVALID",
    "WORKER_NETWORK_UNREACHABLE",
    "WORKER_TLS_FAILED",
    "WORKER_AUTH_FAILED",
    "WORKER_FORBIDDEN",
    "WORKER_RATE_LIMITED",
    "WORKER_TIMEOUT",
    "WORKER_MODEL_NOT_FOUND",
    "WORKER_PROVIDER_ERROR",
    "WORKER_BAD_RESPONSE_JSON",
    "WORKER_SENTINEL_MISMATCH",
    "WORKER_PROTOCOL_VIOLATION",
    "WORKER_TOOL_RELAY_BAD_FORMAT",
    "WORKER_TOOL_RELAY_FABRICATED_RESULT",
    "WORKER_TOOL_RELAY_REFUSED",
    "WORKER_NATIVE_TOOL_SANDBOX_INVALID",
    "WORKER_NATIVE_TOOL_NOT_SUPPORTED",
    "WORKER_NATIVE_TOOL_HOST_LEAK",
    "WORKER_HEALTH_LOG_WRITE_FAILED"
)
foreach ($code in $workerCodes) {
    Add-Result "v021.workers_ref.code.$code" "workers ref defines $code" `
        ($workersRef -match [regex]::Escape($code))
}
Add-Result "v021.workers_ref.health_failed_capsule" "workers ref documents WORKER_HEALTH_FAILED capsule" `
    ($workersRef -match "WORKER_HEALTH_FAILED")
Add-Result "v021.workers_ref.observational" "workers ref says health check is observational" `
    (($workersRef -match "Observational discipline") -and `
     ($workersRef -match "does NOT mutate"))
Add-Result "v021.workers_ref.redaction" "workers ref documents redaction model" `
    (($workersRef -match "Redaction model") -and ($workersRef -match "NEVER logged"))
Add-Result "v021.workers_ref.quick_stages_1_5" "workers ref maps --quick to stages 1-5" `
    ($workersRef -match '\| `--quick` .* \| 1-5 \|')
Add-Result "v021.workers_ref.connectivity_stages_4_6" "workers ref maps --connectivity to stages 4-6" `
    ($workersRef -match '\| `--connectivity` \| 4-6 \|')
Add-Result "v021.workers_ref.mock_probe_never_apply" "workers ref protocol probe uses mock file and never applies it" `
    (($workersRef -match "healthcheck-sentinel\.txt") -and ($workersRef -match "NEVER applies"))
Add-Result "v021.workers_ref.no_incident_decision_stage" "workers ref does not make standalone test stage create incidents" `
    (($workersRef -match "diagnostic_summary") -and ($workersRef -notmatch "incident_decision"))

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v021.state.session_resume_section" "state.md has ## Worker session resume (v0.2.1)" `
    ($stateMd -match "## Worker session resume \(v0\.2\.1\)")
$resumeKeys = @("last_worker_session_id", "last_worker_session_provider",
                "last_resume_strategy", "last_resume_at")
foreach ($key in $resumeKeys) {
    Add-Result "v021.state.resume.$key" "state.md session-resume section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v021.state.loop_guard_section" "state.md has ## Loop guard (v0.2.1)" `
    ($stateMd -match "## Loop guard \(v0\.2\.1\)")
$loopKeys = @("loop_guard_status", "loop_guard_signature",
              "loop_guard_signature_count", "loop_guard_threshold",
              "loop_guard_last_check_at")
foreach ($key in $loopKeys) {
    Add-Result "v021.state.loop.$key" "state.md loop-guard section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
$awaitingReasons = @("WORKER_HEALTH_FAILED", "LOOP_GUARD_HIT",
                     "RESUME_STRATEGY_REQUIRED",
                     "WORKER_TOOL_RELAY_FABRICATED",
                     "WORKER_NATIVE_TOOL_SANDBOX_INVALID")
foreach ($reason in $awaitingReasons) {
    Add-Result "v021.state.reason.$reason" "state.md awaiting_user_reason enum lists $reason" `
        ($stateMd -match [regex]::Escape($reason))
}

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v021.config.worker_test_section" "config.md has ## worker-test (v0.2.1)" `
    ($configMd -match "## worker-test \(v0\.2\.1\)")
$workerTestKeys = @("worker_test_timeout_sec", "worker_test_history_retention",
                    "worker_test_auto_before_run",
                    "worker_test_full_requires_confirm",
                    "worker_test_tool_relay_probe",
                    "worker_test_native_sandbox_check",
                    "worker_test_sandbox_leak_action")
foreach ($key in $workerTestKeys) {
    Add-Result "v021.config.worker_test.$key" "config.md worker-test has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v021.config.loop_guard_section" "config.md has ## loop-guard (v0.2.1)" `
    ($configMd -match "## loop-guard \(v0\.2\.1\)")
$loopGuardKeys = @("loop_guard_enabled", "loop_guard_threshold",
                   "loop_guard_threshold_action",
                   "loop_guard_signature_window_min")
foreach ($key in $loopGuardKeys) {
    Add-Result "v021.config.loop_guard.$key" "config.md loop-guard has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── workers.example.md ──────────────────────────────────────────────────────

$workersExample = Read-Text ".dtd/workers.example.md"

Add-Result "v021.workers_example.session_resume_field" "workers.example.md has supports_session_resume field" `
    ($workersExample -match "(?m)^- supports_session_resume:")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v021.doctor_ref.section" "doctor-checks ref has Worker health + runtime resilience (v0.2.1)" `
    ($doctorRef -match "Worker health \+ runtime resilience \(v0\.2\.1\)")
$doctorCodes = @(
    "worker_check_history_missing",
    "worker_check_history_overflow",
    "worker_check_secret_leak",
    "worker_check_preflight_overdue",
    "worker_native_sandbox_unverified",
    "resume_strategy_invalid",
    "resume_session_orphan",
    "resume_provider_unknown",
    "loop_guard_status_invalid",
    "loop_guard_orphan",
    "loop_guard_count_overflow",
    "loop_guard_signature_stale",
    "loop_guard_count_drift"
)
foreach ($code in $doctorCodes) {
    Add-Result "v021.doctor_ref.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 70..79) {
    Add-Result "v021.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
foreach ($letter in @("b", "c", "d")) {
    Add-Result "v021.scenarios.79$letter" "test-scenarios.md has scenario 79$letter" `
        ($scenariosMd -match "### 79$letter\.")
}
Add-Result "v021.scenarios.section_header" "test-scenarios.md has v0.2.1 section header" `
    ($scenariosMd -match "## v0\.2\.1 .* Runtime Resilience")
Add-Result "v021.scenarios.quick_1_5" "scenario 70 expects quick stages 1-5" `
    ($scenariosMd -match "Stages 1-5 run for each worker")
Add-Result "v021.scenarios.worker_test_observational_no_capsule" "scenario 70 says standalone workers test creates no capsule" `
    ($scenariosMd -match "No incident or decision capsule is created by standalone")
Add-Result "v021.scenarios.mock_probe" "scenario 71 expects mock-output protocol probe" `
    ($scenariosMd -match "healthcheck-sentinel\.txt")

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v021.manifest.checker" "build-manifest includes scripts/check-v021.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v021.ps1"))

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
Write-Host "V021_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
