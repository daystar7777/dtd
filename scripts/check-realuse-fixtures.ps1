# DTD realuse benchmark fixture harness
#
# Validates that each JSONL fixture under
# examples/realuse-benchmark-fixtures/ triggers exactly the
# expected doctor code(s) when fed through the realuse runner's
# validate-results mode.
#
# This makes the 8 realuse doctor codes operationally testable WITHOUT
# requiring a live LLM run.
#
# Usage:
#   pwsh ./scripts/check-realuse-fixtures.ps1
# Exit code: 0 if all fixtures behave as expected; 1 otherwise.

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

$fixtureDir = Join-Path $RepoRoot "examples/realuse-benchmark-fixtures"
$runner = Join-Path $RepoRoot "scripts/realuse-runner.ps1"

Add-Result "realuse_fixtures.dir_exists" "fixture directory exists" `
    (Test-Path -LiteralPath $fixtureDir)
Add-Result "realuse_fixtures.runner_exists" "scripts/realuse-runner.ps1 exists" `
    (Test-Path -LiteralPath $runner)
Add-Result "realuse_fixtures.readme_exists" "fixtures/README.md exists" `
    (Test-Path -LiteralPath (Join-Path $fixtureDir "README.md"))

# Map fixture file -> expected doctor codes set (semicolon-joined for compactness)
$expectations = [ordered]@{
    "valid-plain-row.jsonl"          = ""
    "valid-dtd-row.jsonl"            = ""
    "invalid-schema-version.jsonl"   = "realuse_jsonl_schema_invalid"
    "invalid-token-sum.jsonl"        = "realuse_jsonl_schema_invalid"
    "score-inflation.jsonl"          = "realuse_score_inflation_violation"
    "unknown-mode.jsonl"             = "realuse_recommendation_unknown_mode"
    "no-evidence.jsonl"              = "realuse_score_no_evidence_path"
    "same-model-judge.jsonl"         = "realuse_same_model_judge_unflagged"
    "dryrun-with-evidence.jsonl"     = "realuse_dryrun_has_evidence"
    "full-no-user-gate.jsonl"        = "realuse_full_run_no_user_gate"
}

foreach ($fixture in $expectations.Keys) {
    $path = Join-Path $fixtureDir $fixture
    $existsKey = "realuse_fixtures." + ($fixture -replace "[^a-zA-Z0-9]", "_") + ".exists"
    Add-Result $existsKey "fixture $fixture exists" `
        (Test-Path -LiteralPath $path)

    if (-not (Test-Path -LiteralPath $path)) { continue }

    # Run validator and capture output
    $expectedCodes = $expectations[$fixture]
    $expectedPass = [string]::IsNullOrWhiteSpace($expectedCodes)

    try {
        $output = & pwsh -NoProfile -File $runner -Mode validate-results -Path $path 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    } catch {
        # Try powershell fallback
        try {
            $output = & powershell -NoProfile -File $runner -Mode validate-results -Path $path 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        } catch {
            $output = $_.Exception.Message
            $exitCode = -1
        }
    }

    $checkKey = "realuse_fixtures." + ($fixture -replace "[^a-zA-Z0-9]", "_") + ".behavior"

    if ($expectedPass) {
        # Fixture should validate clean (no doctor codes)
        $passed = ($exitCode -eq 0) -and ($output -match "doctor_codes=0")
        Add-Result $checkKey "fixture $fixture validates clean" $passed `
            "exitCode=$exitCode output=$($output -replace '\s+', ' ' | Select-Object -First 200)"
    } else {
        # Fixture should fire the expected doctor code(s)
        $codes = $expectedCodes -split ";"
        $allFired = $true
        foreach ($code in $codes) {
            if ($output -notmatch [regex]::Escape($code)) {
                $allFired = $false
                break
            }
        }
        $exitNonzero = ($exitCode -ne 0)
        Add-Result $checkKey "fixture $fixture fires $expectedCodes" ($allFired -and $exitNonzero) `
            "exitCode=$exitCode codes_fired=$allFired"
    }
}

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
Write-Host "REALUSE_FIXTURES_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
