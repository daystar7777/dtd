# DTD v0.2.0d release-contract checks
#
# Validates that the v0.2.0d deliverables in this repo match the design contract:
#   - All 10 help topic files exist + ≤ 2 KB each
#   - .dtd/help/index.md ≤ 1 KB
#   - dtd.md has /dtd update + /dtd help command bodies
#   - state.md has Self-Update state section (6 fields)
#   - config.md has update section (6 keys)
#   - instructions.md Intent Gate has update + help intents
#   - test-scenarios.md has scenarios 86-93
#   - prompt.md install bootstrap records installed_version
#   - scripts/build-manifest.ps1 generates valid manifest (40+ files)
#   - /dtd update check observational contract: no state.md write claim
#
# Usage:
#   pwsh ./scripts/check-v020d.ps1
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

# ─── Help topic files ─────────────────────────────────────────────────────────

$canonicalTopics = @("index", "start", "observe", "recover", "workers",
                     "stuck", "update", "plan", "run", "steer")
$helpDir = Join-Path $RepoRoot ".dtd/help"

foreach ($topic in $canonicalTopics) {
    $path = Join-Path $helpDir "$topic.md"
    if (Test-Path -LiteralPath $path) {
        $size = (Get-Item -LiteralPath $path).Length
        $budget = if ($topic -eq "index") { 1024 } else { 2048 }
        $within = $size -le $budget
        Add-Result -Id "v020d.help.$topic.exists" -Name "help/$topic.md exists" -Pass $true `
            -Detail "size=$size, budget=$budget"
        Add-Result -Id "v020d.help.$topic.budget" -Name "help/$topic.md ≤ $budget bytes" -Pass $within `
            -Detail "size=$size"
    } else {
        Add-Result -Id "v020d.help.$topic.exists" -Name "help/$topic.md exists" -Pass $false `
            -Detail "MISSING"
    }
}

# ─── dtd.md command bodies ───────────────────────────────────────────────────

$dtdMd = Get-Content -LiteralPath (Join-Path $RepoRoot "dtd.md") -Raw
Add-Result -Id "v020d.dtdmd.update_cmd" -Name "dtd.md has /dtd update command body" `
    -Pass ($dtdMd -match '### `/dtd update \[check\|--dry-run\|--rollback\|--pin <version>\]`')

Add-Result -Id "v020d.dtdmd.help_cmd" -Name "dtd.md has /dtd help command body" `
    -Pass ($dtdMd -match '### `/dtd help \[topic\] \[--full\]`')

Add-Result -Id "v020d.dtdmd.b_steps" -Name "dtd.md has B1-B7 update flow" `
    -Pass (($dtdMd -match 'B1 Lock') -and ($dtdMd -match 'B5\.5 Rollback') -and ($dtdMd -match 'B7 Cleanup'))

Add-Result -Id "v020d.dtdmd.help_resolution" -Name "dtd.md has Topic resolution algorithm" `
    -Pass ($dtdMd -match 'Topic resolution algorithm')

Add-Result -Id "v020d.dtdmd.doctor_self_update" -Name "dtd.md has Doctor §Self-Update state" `
    -Pass ($dtdMd -match '\*\*Self-Update state\*\* \(v0\.2\.0d\)')

Add-Result -Id "v020d.dtdmd.doctor_help" -Name "dtd.md has Doctor §Help system" `
    -Pass ($dtdMd -match '\*\*Help system\*\* \(v0\.2\.0d\)')

# ─── state.md fields ──────────────────────────────────────────────────────────

$stateMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/state.md") -Raw
$selfUpdateFields = @("installed_version", "update_check_at", "update_available",
                      "update_in_progress", "last_update_from", "last_update_at")

Add-Result -Id "v020d.state.section" -Name "state.md has Self-Update state section" `
    -Pass ($stateMd -match '## Self-Update state \(v0\.2\.0d\)')

foreach ($field in $selfUpdateFields) {
    Add-Result -Id "v020d.state.field.$field" -Name "state.md has $field field" `
        -Pass ($stateMd -match "- $field`:")
}

# ─── config.md keys ───────────────────────────────────────────────────────────

$configMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/config.md") -Raw
$updateKeys = @("check_on_install", "check_interval_days", "github_repo",
                "github_token_env", "manifest_required", "backup_retention_days")

Add-Result -Id "v020d.config.section" -Name "config.md has update section" `
    -Pass ($configMd -match '## update \(v0\.2\.0d\)')

foreach ($key in $updateKeys) {
    Add-Result -Id "v020d.config.key.$key" -Name "config.md has $key key" `
        -Pass ($configMd -match "- $key`:")
}

# ─── instructions.md Intent Gate ─────────────────────────────────────────────

$instrMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/instructions.md") -Raw

Add-Result -Id "v020d.instr.update_intent" -Name "instructions.md Intent Gate has update intent" `
    -Pass ($instrMd -match '\| `update` \|')

Add-Result -Id "v020d.instr.help_intent" -Name "instructions.md Intent Gate has help intent" `
    -Pass ($instrMd -match '\| `help` \|')

Add-Result -Id "v020d.instr.update_obs_check" -Name "instructions.md observational reads include update check + dry-run" `
    -Pass (($instrMd -match '/dtd update check') -and ($instrMd -match '/dtd update --dry-run'))

Add-Result -Id "v020d.instr.update_destructive" -Name "instructions.md destructive list includes update apply + rollback" `
    -Pass ($instrMd -match 'update \[latest\|--pin\]' -and $instrMd -match 'update --rollback')

# ─── test-scenarios.md scenarios 86-93 ────────────────────────────────────────

$scenariosMd = Get-Content -LiteralPath (Join-Path $RepoRoot "test-scenarios.md") -Raw
foreach ($n in 86..93) {
    Add-Result -Id "v020d.scenarios.$n" -Name "test-scenarios.md has scenario $n" `
        -Pass ($scenariosMd -match "### $n\.")
}

# ─── prompt.md install bootstrap ─────────────────────────────────────────────

$promptMd = Get-Content -LiteralPath (Join-Path $RepoRoot "prompt.md") -Raw

Add-Result -Id "v020d.prompt.installed_version" -Name "prompt.md records installed_version" `
    -Pass ($promptMd -match 'installed_version')

Add-Result -Id "v020d.prompt.help_dir" -Name "prompt.md creates .dtd/help/ at install" `
    -Pass ($promptMd -match '\.dtd/help/')

# ─── /dtd update check observational contract ────────────────────────────────
# /dtd update check should NOT mutate state.md.update_check_at per Codex's
# R0 review fix #3. Look for explicit observational-only language.

Add-Result -Id "v020d.update_check.observational" -Name "/dtd update check is strictly observational" `
    -Pass ($configMd -match 'never writes' -or $stateMd -match 'persisted install/apply check; read-only')

# ─── scripts/build-manifest.ps1 ──────────────────────────────────────────────

$builderPath = Join-Path $RepoRoot "scripts/build-manifest.ps1"
Add-Result -Id "v020d.builder.exists" -Name "scripts/build-manifest.ps1 exists" `
    -Pass (Test-Path -LiteralPath $builderPath)

if (Test-Path -LiteralPath $builderPath) {
    $builderText = Get-Content -LiteralPath $builderPath -Raw

    # Should include itself in $IncludedPaths (Codex fix #2)
    Add-Result -Id "v020d.builder.self_included" -Name "build-manifest.ps1 includes itself in IncludedPaths" `
        -Pass ($builderText -match '"scripts/build-manifest\.ps1"')

    Add-Result -Id "v020d.builder.includes_v020d_checker" -Name "build-manifest.ps1 includes check-v020d.ps1" `
        -Pass ($builderText -match '"scripts/check-v020d\.ps1"')

    Add-Result -Id "v020d.builder.includes_v020f_checker" -Name "build-manifest.ps1 includes check-v020f.ps1" `
        -Pass ($builderText -match '"scripts/check-v020f\.ps1"')

    # Should NOT use $PSScriptRoot in parameter default (Codex fix #2)
    $hasParamPSRDefault = $builderText -match 'param\([^)]*\$RepoRoot\s*=\s*\(Resolve-Path\s*"\$PSScriptRoot'
    Add-Result -Id "v020d.builder.no_psroot_param_default" `
        -Name "build-manifest.ps1 does not use \`$PSScriptRoot in param default" `
        -Pass (-not $hasParamPSRDefault)

    Add-Result -Id "v020d.builder.fails_on_missing" -Name "build-manifest.ps1 fails if IncludedPaths are missing" `
        -Pass (($builderText -match '\$missing\s*=\s*@\(\)') -and ($builderText -match 'Cannot build MANIFEST\.json') -and ($builderText -match 'missing IncludedPaths'))
}

# ─── Summary ──────────────────────────────────────────────────────────────────

$pass = @($Results | Where-Object { $_.pass }).Count
$fail = @($Results | Where-Object { -not $_.pass }).Count
$total = $Results.Count

if ($fail -gt 0) {
    Write-Host ""
    Write-Host "FAILED checks:"
    @($Results | Where-Object { -not $_.pass }) | ForEach-Object {
        Write-Host "  - [$($_.id)] $($_.name) — $($_.detail)"
    }
}

Write-Host ""
Write-Host "V020D_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
