# DTD v0.2.3 release-contract checks
#
# Validates the v0.2.3 R1 reference extraction + Lazy-Load Profile contract.
#
# Usage:
#   pwsh ./scripts/check-v023.ps1
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

function Test-HasHangulSyllable([string]$Text) {
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $code = [int][char]$Text[$i]
        if ($code -ge 0xAC00 -and $code -le 0xD7A3) {
            return $true
        }
    }
    return $false
}

$referenceTopics = @(
    "autonomy", "incidents", "persona-reasoning-tools", "perf", "workers",
    "plan-schema", "status-dashboard", "self-update", "help-system",
    "run-loop", "doctor-checks", "roadmap", "load-profile"
)
$canonicalReferenceTopics = $referenceTopics

$referenceDir = Join-Path $RepoRoot ".dtd/reference"
$referenceFiles = @()
if (Test-Path -LiteralPath $referenceDir) {
    $referenceFiles = @(Get-ChildItem -LiteralPath $referenceDir -Filter "*.md" -File)
}

Add-Result "v023.reference.dir" ".dtd/reference directory exists" (Test-Path -LiteralPath $referenceDir)
Add-Result "v023.reference.count" ".dtd/reference has 14 markdown files" ($referenceFiles.Count -eq 14) "count=$($referenceFiles.Count)"

$indexPath = Join-Path $referenceDir "index.md"
Add-Result "v023.reference.index" "reference index.md exists" (Test-Path -LiteralPath $indexPath)

if (Test-Path -LiteralPath $indexPath) {
    $indexText = Get-Content -LiteralPath $indexPath -Raw
    foreach ($topic in $referenceTopics) {
        Add-Result "v023.reference.index.topic.$topic" "index lists $topic" ($indexText -match [regex]::Escape($topic))
    }
    Add-Result "v023.reference.index.topic_count_wording" "index says 13 reference topics" ($indexText -match "13 reference topics")
    Add-Result "v023.reference.index.status_column" "index has Status column" ($indexText -match "\| Topic \| Covers \| Status \| Source \|")
    foreach ($topic in $canonicalReferenceTopics) {
        $topicLine = @($indexText -split "`r?`n" | Where-Object { $_ -match [regex]::Escape($topic) } | Select-Object -First 1)
        Add-Result "v023.reference.index.canonical.$topic" "index marks $topic canonical" `
            (($topicLine.Count -gt 0) -and ($topicLine[0] -match "canonical"))
    }
    Add-Result "v023.reference.index.all_canonical" "index says all 13 topics are canonical" `
        ($indexText -match "all 13 reference topics are canonical")
}

foreach ($topic in $referenceTopics) {
    $path = Join-Path $referenceDir "$topic.md"
    if (Test-Path -LiteralPath $path) {
        $text = Get-Content -LiteralPath $path -Raw
        $size = (Get-Item -LiteralPath $path).Length
        Add-Result "v023.reference.$topic.exists" "reference/$topic.md exists" $true "size=$size"
        # Cross-cutting consolidation refs (doctor-checks, run-loop) absorb
        # per-sub-release R1 wiring for every v0.2.x sub-release; they get a
        # higher 32 KB cap. Topic-specific refs keep the typical 24 KB.
        $crossCutting = @("doctor-checks", "run-loop")
        $cap = if ($crossCutting -contains $topic) { 32768 } else { 24576 }
        $capLabel = if ($crossCutting -contains $topic) { "32 KB" } else { "24 KB" }
        Add-Result "v023.reference.$topic.budget" "reference/$topic.md <= $capLabel" ($size -le $cap) "size=$size"
        Add-Result "v023.reference.$topic.summary" "reference/$topic.md has Summary" ($text -match "## Summary")
        Add-Result "v023.reference.$topic.anchor" "reference/$topic.md has Anchor" ($text -match "## Anchor")
    } else {
        Add-Result "v023.reference.$topic.exists" "reference/$topic.md exists" $false "MISSING"
    }
}

$dtdMd = Read-Text "dtd.md"
$instructionsMd = Read-Text ".dtd/instructions.md"
$configMd = Read-Text ".dtd/config.md"
$stateMd = Read-Text ".dtd/state.md"
$scenariosMd = Read-Text "test-scenarios.md"
$builderText = Read-Text "scripts/build-manifest.ps1"

# v0.2.3 R1: doctor-checks extracted; dtd.md stub mentions "13 topics",
# full enumeration lives in .dtd/reference/doctor-checks.md.
$doctorRefText = Read-Text ".dtd/reference/doctor-checks.md"
Add-Result "v023.dtd.reference_count" "dtd.md + doctor-checks ref document index + 13 reference topics" `
    (($dtdMd -match "13 canonical topics") -and ($doctorRefText -match "all 13 canonical reference topics"))
# v0.2.3 R1: full text moved to .dtd/reference/help-system.md
$helpSystemRefText = Read-Text ".dtd/reference/help-system.md"
Add-Result "v023.dtd.help_full_reference" "dtd.md + help-system ref say --full loads one reference file" `
    (($dtdMd -match '\.dtd/reference/<topic>\.md') -and `
     ($helpSystemRefText -match 'Do not load `dtd\.md` or other reference files'))
Add-Result "v023.dtd.profile_observational" "dtd.md says observational reads do not persist profile" `
    ($dtdMd -match 'observational reads compute and display `effective_profile`')
Add-Result "v023.dtd.profile_log_not_steering" "dtd.md routes profile diagnostics away from steering" `
    (($dtdMd -match '\.dtd/log/profile-transitions\.md') -and ($dtdMd -match 'never\s+to\s+`steering\.md`'))
Add-Result "v023.dtd.token_caveat" "dtd.md does not guarantee token savings" `
    ($dtdMd -match "not a guaranteed provider-token reduction")

Add-Result "v023.instructions.effective_profile" "instructions compute effective_profile" `
    ($instructionsMd -match 'compute `effective_profile`')
Add-Result "v023.instructions.observational_no_profile_write" "instructions prevent profile writes on observational reads" `
    ($instructionsMd -match "Do not persist profile changes during\s+observational reads")
Add-Result "v023.instructions.read_isolation_profile" "read isolation blocks loaded_profile persistence" `
    ($instructionsMd -match 'DO NOT persist `loaded_profile`')

Add-Result "v023.config.transition_default_false" "config default profile_transition_logging false" `
    ($configMd -match "profile_transition_logging:\s*false")
Add-Result "v023.config.transition_log_path" "config has profile_transition_log_path" `
    ($configMd -match "profile_transition_log_path:\s*\.dtd/log/profile-transitions\.md")
foreach ($profile in @("minimal", "planning", "running", "recovery")) {
    Add-Result "v023.config.profile_sections.$profile.shape" "config profile_sections.$profile has active_sections + reference_drilldown_topics" `
        ($configMd -match "(?s)$([regex]::Escape($profile)):\s*.*?active_sections:\s*.*?reference_drilldown_topics:")
}
Add-Result "v023.config.profile_sections.drilldown_topics" "config lists expected R1 reference drill-down topics" `
    (($configMd -match 'reference_drilldown_topics:') -and
     ($configMd -match '"run-loop"') -and
     ($configMd -match '"workers"') -and
     ($configMd -match '"incidents"') -and
     ($configMd -match '"doctor-checks"'))

Add-Result "v023.state.observational_comment" "state comments say observational reads do not persist profile" `
    ($stateMd -match "Observational reads do not persist profile")

foreach ($n in 94..97) {
    Add-Result "v023.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v023.scenarios.reference_count" "scenario 94 expects 14 markdown files" `
    ($scenariosMd -match "14 markdown files exist")
Add-Result "v023.scenarios.reference_budget" "scenario 94 expects reference budget" `
    ($scenariosMd -match "Each is <= (16|24) KB")
Add-Result "v023.scenarios.reference_status" "scenario 94 expects all topics canonical" `
    ($scenariosMd -match 'every topic `canonical`')
Add-Result "v023.scenarios.no_steering_profile" "scenario 96 does not log profile transitions to steering" `
    (($scenariosMd -match "steering\.md") -and ($scenariosMd -match "not appended") -and ($scenariosMd -match "profile-transitions\.md"))
Add-Result "v023.scenarios.token_caveat" "scenario 97 allows unchanged prompt tokens" `
    ($scenariosMd -match "may show unchanged prompt tokens")

Add-Result "v023.manifest.includes_checker" "build-manifest includes check-v023.ps1" `
    ($builderText -match '"scripts/check-v023\.ps1"')
foreach ($topic in $referenceTopics) {
    Add-Result "v023.manifest.reference.$topic" "build-manifest includes reference/$topic.md" `
        ($builderText -match [regex]::Escape(".dtd/reference/$topic.md"))
}

$installSideFiles = @(
    "prompt.md", "README.md", "examples/quickstart.md",
    ".dtd/help/recover.md", ".dtd/help/plan.md", ".dtd/help/steer.md"
)
foreach ($file in $installSideFiles) {
    $text = Read-Text $file
    Add-Result "v023.korean_clean.$file" "$file has no Korean Hangul chars" `
        (-not (Test-HasHangulSyllable $text))
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
Write-Host "V023_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
