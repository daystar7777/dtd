# DTD realuse benchmark runner skeleton (R0)
#
# Hermetic by default. Modes:
#   dry-run            Generate fixture results.jsonl with dry_run:true; no
#                      network/LLM calls; tokens=0; evidence_paths empty.
#   validate-results   Validate a results.jsonl against the v030 realuse
#                      schema (plain + DTD rows; DTD token sum invariant);
#                      report doctor-code triggers.
#   intake-status      Report which intake state the realuse track is in:
#                      no_results / partial_results / schema_valid /
#                      scored_report_ready.
#   probe-only         STUB. Would run capability probes against real
#                      worker endpoints. Currently a user-gate stub.
#   full               BLOCKED. Real benchmark execution requires explicit
#                      user-gate command.
#
# Usage:
#   pwsh ./scripts/realuse-runner.ps1 -Mode dry-run [-RunId <id>]
#   pwsh ./scripts/realuse-runner.ps1 -Mode validate-results -Path <results.jsonl>
#   pwsh ./scripts/realuse-runner.ps1 -Mode intake-status [-RunDir <dir>]
#
# Exit codes:
#   0  success / GO
#   1  validation failure / doctor codes fired
#   2  user gate required (probe-only / full modes)
#
# Boundary (per Codex's v0.3 realuse-benchmark dev-phase reference):
# - NEVER call live workers from this runner without explicit user gate.
# - NEVER print or log raw API keys.
# - Dry-run rows MUST set dry_run:true, tokens=0, evidence_paths=[].

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("dry-run", "validate-results", "intake-status", "probe-only", "full")]
    [string]$Mode,

    [string]$RunId,
    [string]$Path,
    [string]$RunDir,
    [string]$RepoRoot = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path $RepoRoot).Path
}

$RealuseRoot = Join-Path $RepoRoot "test-projects/dtd-realuse-agent-suite"

# ─── Constants from .dtd/reference/v030-realuse-benchmark.md ────────────────

$ValidSchemaVersion = "1.0"
$ValidRowTypes = @("plain", "dtd")
$ValidRecommendationModes = @("quick", "balanced", "thorough", "silent-overnight")

# ─── Helpers ────────────────────────────────────────────────────────────────

function New-RunId {
    return (Get-Date -Format "yyyyMMddTHHmmssZ") + "-dryrun"
}

function Get-RowField {
    param([pscustomobject]$Row, [string]$FieldName, $Default = $null)
    if ($null -ne $Row -and $null -ne $Row.PSObject.Properties[$FieldName]) {
        return $Row.$FieldName
    }
    return $Default
}

function Get-DoctorCode {
    param([string]$Code, [string]$Severity, [string]$Detail)
    return [pscustomobject]@{
        code = $Code
        severity = $Severity
        detail = $Detail
    }
}

function Test-RealuseRowSchema {
    param([pscustomobject]$Row, [string]$RowSourceName)

    $codes = @()

    # schema_version
    if ($Row.schema_version -ne $ValidSchemaVersion) {
        $codes += Get-DoctorCode -Code "realuse_jsonl_schema_invalid" `
            -Severity "ERROR" `
            -Detail "${RowSourceName}: schema_version != '$ValidSchemaVersion' (got '$($Row.schema_version)')"
        return $codes  # bail early; further checks may misalign
    }

    # row_type
    if ($Row.row_type -notin $ValidRowTypes) {
        $codes += Get-DoctorCode -Code "realuse_jsonl_schema_invalid" `
            -Severity "ERROR" `
            -Detail "${RowSourceName}: row_type must be one of $($ValidRowTypes -join ', '); got '$($Row.row_type)'"
        return $codes
    }

    $isDryRun = ($Row.dry_run -eq $true)

    # Required fields (both plain + dtd)
    $requiredFields = @("case_id", "case_size", "case_type", "method", "control_arm",
                        "max_iterations", "actual_iterations", "elapsed_sec",
                        "result_score", "pass_external_acceptance", "product_lines")
    foreach ($f in $requiredFields) {
        if ($null -eq $Row.PSObject.Properties[$f]) {
            $codes += Get-DoctorCode -Code "realuse_jsonl_schema_invalid" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: required field '$f' missing"
        }
    }

    # DTD token-sum invariant (when not dry-run)
    if ($Row.row_type -eq "dtd" -and -not $isDryRun) {
        $controller = [int](Get-RowField -Row $Row -FieldName "controller_tokens" -Default 0)
        $impl       = [int](Get-RowField -Row $Row -FieldName "implementation_worker_tokens" -Default 0)
        $test       = [int](Get-RowField -Row $Row -FieldName "test_worker_tokens" -Default 0)
        $verifier   = [int](Get-RowField -Row $Row -FieldName "verifier_tokens" -Default 0)
        $scorekeep  = [int](Get-RowField -Row $Row -FieldName "scorekeeper_tokens" -Default 0)
        $sum        = $controller + $impl + $test + $verifier + $scorekeep
        $total      = [int](Get-RowField -Row $Row -FieldName "total_tokens" -Default 0)

        if ($total -ne $sum) {
            $tokenBreakdown = "controller=" + $controller + " impl=" + $impl + " test=" + $test + " verifier=" + $verifier + " scorekeep=" + $scorekeep
            $codes += Get-DoctorCode -Code "realuse_jsonl_schema_invalid" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: DTD token sum invariant violated (total=$total sum=$sum; $tokenBreakdown)"
        }
    }

    # Score inflation guard (Codex P1: external_acceptance:0 + score>=70 = ERROR)
    if (-not $isDryRun) {
        $score = [int](Get-RowField -Row $Row -FieldName "result_score" -Default 0)
        $extAcc = [bool](Get-RowField -Row $Row -FieldName "pass_external_acceptance" -Default $false)
        if ($score -ge 70 -and -not $extAcc) {
            $codes += Get-DoctorCode -Code "realuse_score_inflation_violation" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: result_score=$score >= 70 but pass_external_acceptance=false (rubric requires external_acceptance for high scores)"
        }
    }

    # Evidence paths required for non-dry-run
    if (-not $isDryRun) {
        $evidence = @(Get-RowField -Row $Row -FieldName "evidence_paths" -Default @())
        $hasEvidence = ($evidence | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
        if (-not $hasEvidence) {
            $codes += Get-DoctorCode -Code "realuse_score_no_evidence_path" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: non-dry-run row has empty evidence_paths"
        }
    }

    # Dry-run hermetic invariants
    if ($isDryRun) {
        $hasEvidence = $false
        if ($null -ne $Row.evidence_paths) {
            $hasEvidence = (@($Row.evidence_paths) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0
        }
        $totalTokens = [int](Get-RowField -Row $Row -FieldName "total_tokens" -Default 0)
        if ($hasEvidence -or $totalTokens -gt 0) {
            $codes += Get-DoctorCode -Code "realuse_dryrun_has_evidence" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: dry_run=true row must have evidence_paths=[] AND total_tokens=0; got evidence=$hasEvidence tokens=$totalTokens"
        }
    }

    # Recommendation mode validation
    $recMode = Get-RowField -Row $Row -FieldName "recommended_mode" -Default $null
    if ($null -ne $recMode) {
        if ($recMode -notin $ValidRecommendationModes) {
            $codes += Get-DoctorCode -Code "realuse_recommendation_unknown_mode" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: recommended_mode='$recMode' not in $($ValidRecommendationModes -join ', ')"
        }
    }

    # User gate for full mode
    if ($Row.method -eq "full" -or $Row.control_arm -eq "FULL") {
        $userGate = Get-RowField -Row $Row -FieldName "user_start_command_recorded" -Default $null
        if ($userGate -ne $true) {
            $codes += Get-DoctorCode -Code "realuse_full_run_no_user_gate" `
                -Severity "ERROR" `
                -Detail "${RowSourceName}: full mode row missing user_start_command_recorded:true"
        }
    }

    # Same-model judge flag
    if ($Row.row_type -eq "dtd" -and -not $isDryRun) {
        $controller = Get-RowField -Row $Row -FieldName "controller_model" -Default ""
        $scorekeeper = Get-RowField -Row $Row -FieldName "scorekeeper_model" -Default ""
        if (-not [string]::IsNullOrWhiteSpace($controller) -and $controller -eq $scorekeeper) {
            $flagged = ((Get-RowField -Row $Row -FieldName "same_model_judge" -Default $false) -eq $true)
            if (-not $flagged) {
                $codes += Get-DoctorCode -Code "realuse_same_model_judge_unflagged" `
                    -Severity "WARN" `
                    -Detail "${RowSourceName}: controller_model=='$controller' equals scorekeeper_model but same_model_judge:true flag missing"
            }
        }
    }

    return $codes
}

# ─── Mode: dry-run ──────────────────────────────────────────────────────────

function Invoke-DryRun {
    if ([string]::IsNullOrWhiteSpace($script:RunId)) {
        $script:RunId = New-RunId
    }
    $runRoot = Join-Path $RealuseRoot "runs/$($script:RunId)"
    New-Item -ItemType Directory -Force -Path $runRoot | Out-Null

    $resultsPath = Join-Path $runRoot "results.jsonl"
    $validationPath = Join-Path $runRoot "dryrun-validation.md"

    # Hermetic fixture rows: 1 plain + 1 dtd, both dry_run:true
    $plainRow = [ordered]@{
        schema_version = $ValidSchemaVersion
        row_type = "plain"
        dry_run = $true
        case_id = "fixture-short-cli-001"
        case_size = "short"
        case_type = "cli-tool"
        method = "plain"
        control_arm = "P0F"
        creator_model = "FIXTURE-NO-LLM"
        max_iterations = 1
        actual_iterations = 0
        elapsed_sec = 0
        total_tokens = 0
        result_score = $null
        pass_external_acceptance = $false
        pass_generated_tests = $null
        product_lines = 0
        evidence_paths = @()
        notes = "DRY REHEARSAL — hermetic fixture; no real LLM call; not eligible for benchmark conclusions"
    }

    $dtdRow = [ordered]@{
        schema_version = $ValidSchemaVersion
        row_type = "dtd"
        dry_run = $true
        case_id = "fixture-short-cli-001"
        case_size = "short"
        case_type = "cli-tool"
        method = "dtd-D3"
        control_arm = "D3"
        controller_model = "FIXTURE-NO-LLM"
        implementation_worker_model = "FIXTURE-NO-LLM"
        test_worker_model = "FIXTURE-NO-LLM"
        verifier_model = "FIXTURE-NO-LLM"
        scorekeeper_model = "FIXTURE-NO-LLM"
        max_iterations = 3
        actual_iterations = 0
        elapsed_sec = 0
        total_tokens = 0
        controller_tokens = 0
        implementation_worker_tokens = 0
        test_worker_tokens = 0
        verifier_tokens = 0
        scorekeeper_tokens = 0
        total_system_tokens = 0
        worker_attempts = 0
        result_score = $null
        pass_external_acceptance = $false
        product_lines = 0
        evidence_paths = @()
        recommended_mode = "balanced"
        notes = "DRY REHEARSAL — hermetic fixture; no real LLM call; not eligible for benchmark conclusions"
    }

    $jsonl = @(
        ($plainRow | ConvertTo-Json -Compress -Depth 10),
        ($dtdRow | ConvertTo-Json -Compress -Depth 10)
    ) -join "`n"

    Set-Content -LiteralPath $resultsPath -Value $jsonl -Encoding UTF8 -NoNewline

    # Re-validate the rows we just wrote (hermetic round-trip)
    $rows = @($plainRow, $dtdRow) | ForEach-Object { [pscustomobject]$_ }
    $allCodes = @()
    for ($i = 0; $i -lt $rows.Count; $i++) {
        $allCodes += Test-RealuseRowSchema -Row $rows[$i] -RowSourceName "${resultsPath}#row$($i+1)"
    }

    $report = "# DTD realuse benchmark — DRY REHEARSAL validation`n`n"
    $report += "Run id: $($script:RunId)`n"
    $report += "Run root: $runRoot`n"
    $report += "Results: $resultsPath`n"
    $report += "Generated: $(Get-Date -Format 'yyyy-MM-ddTHH:mm:ssZ')`n`n"
    $report += "## Hermetic invariants`n`n"
    $report += "- No network calls.`n"
    $report += "- No LLM calls.`n"
    $report += "- All rows have dry_run:true, total_tokens:0, evidence_paths:[].`n"
    $report += "- Schema version: $ValidSchemaVersion.`n`n"
    $report += "## Rows`n`n"
    $report += "- $($rows.Count) rows written.`n"
    $report += "- Plain row: case=fixture-short-cli-001 arm=P0F.`n"
    $report += "- DTD row:   case=fixture-short-cli-001 arm=D3.`n`n"
    $report += "## Doctor codes triggered`n`n"

    if ($allCodes.Count -eq 0) {
        $report += "(none — dry-run is clean)`n"
        $exitCode = 0
    } else {
        foreach ($c in $allCodes) {
            $report += "- [$($c.severity)] $($c.code) — $($c.detail)`n"
        }
        $exitCode = 1
    }

    $report += "`n## Boundary`n`n"
    $report += "This is a DRY REHEARSAL only. Per Codex's realuse-benchmark dev-phase`n"
    $report += "boundary, this run did NOT call any real LLM endpoint. Mock results are`n"
    $report += "labelled DRY REHEARSAL and are NOT eligible for benchmark conclusions or`n"
    $report += "final R2 PASS.`n`n"
    $report += "## Next phase`n`n"
    $report += "To advance to a real benchmark run, the user must invoke an explicit`n"
    $report += "start command (e.g. ``/dtd realuse start``). That command must be`n"
    $report += "checker-protected via realuse_full_run_no_user_gate.`n"

    Set-Content -LiteralPath $validationPath -Value $report -Encoding UTF8

    Write-Host "REALUSE_DRYRUN run_id=$($script:RunId) rows=$($rows.Count) doctor_codes=$($allCodes.Count) results=$resultsPath validation=$validationPath"
    return $exitCode
}

# ─── Mode: validate-results ─────────────────────────────────────────────────

function Invoke-ValidateResults {
    if ([string]::IsNullOrWhiteSpace($script:Path)) {
        Write-Error "validate-results requires -Path <results.jsonl>"
        return 2
    }
    if (-not (Test-Path -LiteralPath $script:Path)) {
        Write-Error "Path not found: $($script:Path)"
        return 2
    }

    $lines = Get-Content -LiteralPath $script:Path -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }
    $allCodes = @()
    $rowCount = 0

    foreach ($line in $lines) {
        $rowCount++
        try {
            $row = $line | ConvertFrom-Json
        } catch {
            $allCodes += Get-DoctorCode -Code "realuse_jsonl_schema_invalid" `
                -Severity "ERROR" `
                -Detail "$($script:Path)#row${rowCount}: malformed JSON"
            continue
        }
        $allCodes += Test-RealuseRowSchema -Row $row -RowSourceName "$($script:Path)#row$rowCount"
    }

    Write-Host ""
    Write-Host "Validated $rowCount rows from $($script:Path)"
    if ($allCodes.Count -eq 0) {
        Write-Host "REALUSE_VALIDATE_RESULTS rows=$rowCount doctor_codes=0 status=clean"
        return 0
    } else {
        Write-Host ""
        Write-Host "Doctor codes:"
        foreach ($c in $allCodes) {
            Write-Host "  - [$($c.severity)] $($c.code) -- $($c.detail)"
        }
        Write-Host ""
        Write-Host "REALUSE_VALIDATE_RESULTS rows=$rowCount doctor_codes=$($allCodes.Count) status=fail"
        return 1
    }
}

# ─── Mode: intake-status ────────────────────────────────────────────────────

function Invoke-IntakeStatus {
    $checkDir = if ([string]::IsNullOrWhiteSpace($script:RunDir)) { $RealuseRoot } else { $script:RunDir }

    if (-not (Test-Path -LiteralPath $checkDir)) {
        Write-Host "REALUSE_INTAKE_STATUS state=no_results detail=`"$checkDir does not exist`""
        return 0
    }

    $resultsFiles = @(Get-ChildItem -LiteralPath $checkDir -Filter "results.jsonl" -Recurse -ErrorAction SilentlyContinue)
    if ($resultsFiles.Count -eq 0) {
        Write-Host "REALUSE_INTAKE_STATUS state=no_results detail=`"no results.jsonl under $checkDir`""
        return 0
    }

    $totalRows = 0
    $invalidRows = 0
    $allDryRun = $true

    foreach ($f in $resultsFiles) {
        $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }
        foreach ($line in $lines) {
            $totalRows++
            try {
                $row = $line | ConvertFrom-Json
                if ($row.dry_run -ne $true) { $allDryRun = $false }
                $codes = Test-RealuseRowSchema -Row $row -RowSourceName "$($f.FullName)#row$totalRows"
                if ($codes.Count -gt 0) { $invalidRows++ }
            } catch {
                $invalidRows++
                $allDryRun = $false
            }
        }
    }

    if ($invalidRows -eq $totalRows -and $totalRows -gt 0) {
        $state = "partial_results"
        $detail = "all $totalRows rows have schema/doctor errors"
    } elseif ($invalidRows -gt 0) {
        $state = "partial_results"
        $detail = "$invalidRows of $totalRows rows have schema/doctor errors"
    } elseif ($allDryRun) {
        $state = "schema_valid"
        $detail = "$totalRows rows valid; all dry_run (DRY REHEARSAL only - not benchmark-ready)"
    } else {
        # Schema-valid + has real (non-dry-run) rows. Scored if all rows have result_score.
        $hasScores = $true
        foreach ($f in $resultsFiles) {
            $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8 | Where-Object { $_.Trim() -ne "" }
            foreach ($line in $lines) {
                $row = $line | ConvertFrom-Json
                if ($null -eq $row.result_score -or $row.result_score -eq 0) { $hasScores = $false; break }
            }
        }
        $state = if ($hasScores) { "scored_report_ready" } else { "schema_valid" }
        $detail = "$totalRows rows valid; non-dry-run real benchmark data"
    }

    Write-Host "REALUSE_INTAKE_STATUS state=$state files=$($resultsFiles.Count) rows=$totalRows invalid=$invalidRows detail=`"$detail`""
    return 0
}

# ─── Mode: probe-only ───────────────────────────────────────────────────────

function Invoke-ProbeOnly {
    Write-Host "REALUSE_PROBE_ONLY status=user_gate_required"
    Write-Host ""
    Write-Host "Probe mode would call configured worker endpoints to record their"
    Write-Host "capability profile (basic_content / file_marker_echo /"
    Write-Host "json_response_format / provider_thinking {disabled,low,max} /"
    Write-Host "streaming / usage_tokens / reasoning_content_field)."
    Write-Host ""
    Write-Host "This R0 runner skeleton does NOT actually call any worker. To run"
    Write-Host "real probes, the user must explicitly start them through the DTD"
    Write-Host "worker-test pipeline (existing v0.2.1 path) — not through this"
    Write-Host "realuse-runner."
    Write-Host ""
    Write-Host "If you need probe results for the realuse benchmark:"
    Write-Host "  1. Configure your workers in .dtd/workers.md"
    Write-Host "  2. Run /dtd workers test <id> --quick"
    Write-Host "  3. Capability inventory will be written to"
    Write-Host "     .dtd/log/worker-checks/<id>-capabilities.md"
    Write-Host ""
    Write-Host "To validate already-collected probe artifacts hermetically, use:"
    Write-Host "  pwsh ./scripts/realuse-runner.ps1 -Mode validate-results -Path <probe.jsonl>"
    return 2
}

# ─── Mode: full ─────────────────────────────────────────────────────────────

function Invoke-Full {
    Write-Host "REALUSE_FULL status=blocked_user_gate_required"
    Write-Host ""
    Write-Host "Full benchmark execution is INTENTIONALLY BLOCKED in this runner."
    Write-Host "Per Codex's v0.3 realuse-benchmark dev-phase boundary"
    Write-Host "(.dtd/reference/v030-realuse-benchmark.md ## 5. Runner dry-run plan):"
    Write-Host ""
    Write-Host "  > full mode requires user gate (e.g. /dtd realuse start)"
    Write-Host "  > realuse_full_run_no_user_gate ERROR fires if a full row"
    Write-Host "  > exists without recorded user start."
    Write-Host ""
    Write-Host "This R0 runner skeleton refuses to start a real LLM-backed"
    Write-Host "benchmark. Real execution requires:"
    Write-Host "  1. Worker capability inventory (probe-only first)."
    Write-Host "  2. User-issued start command equivalent to /dtd realuse start."
    Write-Host "  3. Each results.jsonl row tagged user_start_command_recorded:true."
    Write-Host "  4. realuse_full_run_no_user_gate doctor passes."
    Write-Host ""
    Write-Host "To rehearse the runner without spending tokens, use:"
    Write-Host "  pwsh ./scripts/realuse-runner.ps1 -Mode dry-run"
    Write-Host ""
    Write-Host "To validate existing results:"
    Write-Host "  pwsh ./scripts/realuse-runner.ps1 -Mode validate-results -Path <path>"
    return 2
}

# ─── Dispatch ───────────────────────────────────────────────────────────────

switch ($Mode) {
    "dry-run"          { exit (Invoke-DryRun) }
    "validate-results" { exit (Invoke-ValidateResults) }
    "intake-status"    { exit (Invoke-IntakeStatus) }
    "probe-only"       { exit (Invoke-ProbeOnly) }
    "full"             { exit (Invoke-Full) }
    default {
        Write-Error "Unknown mode: $Mode"
        exit 2
    }
}
