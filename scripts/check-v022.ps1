# DTD v0.2.2 release-contract checks
#
# Validates that the v0.2.2 deliverables match the design contract:
#   - .dtd/notepad.md ships schema v2 (## handoff H2 + 8 H3 children)
#   - dtd.md /dtd notepad command body with show/search/compact forms
#   - dtd.md doctor section lists Notepad schema (v0.2.2)
#   - reference/doctor-checks.md has ## Notepad schema (v0.2.2)
#   - test-scenarios.md has scenarios 80-85 + 85b/c/d
#   - scripts/build-manifest.ps1 includes check-v022.ps1
#
# Usage:
#   pwsh ./scripts/check-v022.ps1
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

# ─── notepad.md template (schema v2) ─────────────────────────────────────────

$notepadMd = Read-Text ".dtd/notepad.md"

Add-Result "v022.notepad.handoff_h2" "notepad.md has ## handoff H2" `
    ($notepadMd -match "(?m)^## handoff")
$h3Headings = @("Goal", "Constraints", "Progress", "Decisions",
                "Next Steps", "Critical Context", "Relevant Files",
                "Reasoning Notes")
foreach ($heading in $h3Headings) {
    Add-Result "v022.notepad.h3.$($heading -replace ' ','_')" "notepad.md has ### $heading" `
        ($notepadMd -match "(?m)^### $([regex]::Escape($heading))")
}
$freeForm = @("learnings", "decisions", "issues", "verification")
foreach ($section in $freeForm) {
    Add-Result "v022.notepad.freeform.$section" "notepad.md has ## $section free-form section" `
        ($notepadMd -match "(?m)^## $section")
}
Add-Result "v022.notepad.schema_label" "notepad.md labels schema as v0.2.2 8-heading" `
    ($notepadMd -match "v0\.2\.2 8-heading")

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v022.dtdmd.notepad_cmd" "dtd.md has /dtd notepad command body" `
    ($dtdMd -match '### `/dtd notepad \[show\|search\|compact\]')
$notepadForms = @("show", "search", "compact")
foreach ($form in $notepadForms) {
    Add-Result "v022.dtdmd.notepad.$form" "dtd.md /dtd notepad documents $form form" `
        ($dtdMd -match "/dtd notepad $form")
}
Add-Result "v022.dtdmd.handoff_budget" "dtd.md says handoff total ≤ 1.2 KB" `
    ($dtdMd -match "1\.2 KB")
Add-Result "v022.dtdmd.eight_headings" "dtd.md lists 8 handoff headings" `
    (($dtdMd -match "Goal") -and ($dtdMd -match "Constraints") -and `
     ($dtdMd -match "Progress") -and ($dtdMd -match "Decisions") -and `
     ($dtdMd -match "Next Steps") -and ($dtdMd -match "Critical Context") -and `
     ($dtdMd -match "Relevant Files") -and ($dtdMd -match "Reasoning Notes"))
Add-Result "v022.dtdmd.compaction_priority" "dtd.md documents TRUNCATE order (Relevant Files first, Progress second)" `
    (($dtdMd -match "TRUNCATE first") -and ($dtdMd -match "TRUNCATE second"))
Add-Result "v022.dtdmd.schema_detection" "dtd.md documents schema v1/v2 detection" `
    (($dtdMd -match "schema v2") -and ($dtdMd -match "schema v1"))
Add-Result "v022.dtdmd.reasoning_discipline" "dtd.md documents Reasoning Notes content discipline" `
    (($dtdMd -match "chain-of-thought") -and ($dtdMd -match "5 lines per"))
Add-Result "v022.dtdmd.doctor_lists_notepad" "dtd.md doctor lists Notepad schema (v0.2.2)" `
    ($dtdMd -match "Notepad schema \(v0\.2\.2\)")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v022.doctor_ref.section" "doctor-checks ref has ## Notepad schema (v0.2.2)" `
    ($doctorRef -match "## Notepad schema \(v0\.2\.2\)")
$doctorCodes = @(
    "notepad_parse_error",
    "notepad_schema_v1",
    "notepad_v2_missing_heading",
    "notepad_heading_oversized",
    "notepad_handoff_oversized",
    "reasoning_notes_chain_of_thought_leak",
    "notepad_v2_missing_reasoning_notes"
)
foreach ($code in $doctorCodes) {
    Add-Result "v022.doctor_ref.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 80..85) {
    Add-Result "v022.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
foreach ($letter in @("b", "c", "d")) {
    Add-Result "v022.scenarios.85$letter" "test-scenarios.md has scenario 85$letter" `
        ($scenariosMd -match "### 85$letter\.")
}
Add-Result "v022.scenarios.section_header" "test-scenarios.md has v0.2.2 section header" `
    ($scenariosMd -match "## v0\.2\.2 .* Compaction UX")

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v022.manifest.checker" "build-manifest includes scripts/check-v022.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v022.ps1"))

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
Write-Host "V022_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
