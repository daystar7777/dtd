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
Add-Result "v022.notepad.no_trigger_phrase_in_template" "notepad template guidance avoids literal private-reasoning trigger phrases" `
    (($notepadMd -notmatch "let me think") -and ($notepadMd -notmatch "step-by-step"))
Add-Result "v022.notepad.updated_before_dispatch" "notepad template says handoff updates before every worker dispatch" `
    ($notepadMd -match "before\s*>?\s*every worker dispatch")

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
Add-Result "v022.dtdmd.compaction_priority" "dtd.md documents TRUNCATE order (Progress first, Relevant Files second)" `
    (($dtdMd -match "\| Progress \| 200 ch \| TRUNCATE first") -and
     ($dtdMd -match "\| Relevant Files \| 100 ch \| TRUNCATE second") -and
     ($dtdMd -match "truncate Progress first, then\s+Relevant Files"))
Add-Result "v022.dtdmd.schema_detection" "dtd.md documents schema v1/v2 detection" `
    (($dtdMd -match "schema v2") -and ($dtdMd -match "schema v1"))
Add-Result "v022.dtdmd.reasoning_discipline" "dtd.md documents Reasoning Notes content discipline" `
    (($dtdMd -match "chain-of-thought") -and ($dtdMd -match "5 lines per"))
Add-Result "v022.dtdmd.doctor_lists_notepad" "dtd.md doctor lists Notepad schema (v0.2.2)" `
    ($dtdMd -match "Notepad schema \(v0\.2\.2\)")
Add-Result "v022.instructions.notepad_intent" "instructions.md has notepad intent" `
    ((Read-Text ".dtd/instructions.md") -match '\| `notepad` \| `/dtd notepad')
Add-Result "v022.instructions.notepad_observational" "instructions.md marks notepad show/search observational" `
    (((Read-Text ".dtd/instructions.md") -match "/dtd notepad show") -and
     ((Read-Text ".dtd/instructions.md") -match "/dtd notepad search"))

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
Add-Result "v022.doctor_ref.heuristic_ignores_template_guidance" "doctor heuristic ignores template blockquote guidance" `
    (($doctorRef -match "Ignore template guidance") -and
     ($doctorRef -match "A simple .*checklist alone is not enough"))

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
Add-Result "v022.scenarios.compaction_order" "scenario 82 expects Progress first, Relevant Files second" `
    (($scenariosMd -match 'Step 1: `Progress`') -and
     ($scenariosMd -match 'Step 2: `Relevant Files`'))

# ─── R1 wiring: run-loop.md + state.md + doctor-checks.md ────────────────────

$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v022.r1.run_loop_section" "run-loop.md has Notepad compaction + reasoning utility section (v0.2.2 R1)" `
    ($runLoopRef -match "## Notepad compaction \+ reasoning utility post-processing \(v0\.2\.2 R1\)")
Add-Result "v022.r1.run_loop_compaction_algorithm" "run-loop.md has Phase-boundary compaction algorithm" `
    ($runLoopRef -match "### Phase-boundary compaction algorithm")
Add-Result "v022.r1.run_loop_schema_detect" "run-loop.md compaction step 1 detects schema" `
    ($runLoopRef -match "(?s)Schema detection.*?## handoff.*?### Goal")
Add-Result "v022.r1.run_loop_truncate_progress_first" "run-loop.md compaction step 4.a truncates Progress first" `
    ($runLoopRef -match "Step 4\.a\*\*\s*TRUNCATE.*Progress.*first")
Add-Result "v022.r1.run_loop_truncate_relevant_second" "run-loop.md compaction step 4.b truncates Relevant Files second" `
    ($runLoopRef -match "Step 4\.b\*\*\s*TRUNCATE.*Relevant Files.*second")
Add-Result "v022.r1.run_loop_keep_six" "run-loop.md compaction KEEPs Goal/Constraints/Decisions/Next/Critical/Reasoning" `
    ($runLoopRef -match "(?s)\*\*KEEP\*\*\s+Goal\s+/\s+Constraints\s+/\s+Decisions\s+/\s+Next Steps\s+/\s+Critical Context\s+/\s+Reasoning Notes")
Add-Result "v022.r1.run_loop_reasoning_section" "run-loop.md has Reasoning utility post-processing section" `
    ($runLoopRef -match "### Reasoning utility post-processing")
Add-Result "v022.r1.run_loop_chain_filter" "run-loop.md documents chain-of-thought leakage filter" `
    (($runLoopRef -match "Chain-of-thought leakage filter") -and `
     ($runLoopRef -match "5 lines per entry"))
Add-Result "v022.r1.run_loop_keep_last_3" "run-loop.md says keep last 3 reasoning entries; older roll" `
    (($runLoopRef -match "Keep last 3 entries") -or `
     ($runLoopRef -match "keep last 3 entries|keep-last-3"))
Add-Result "v022.r1.run_loop_tree_search" "run-loop.md says tree_search writes option id + score, not raw chains" `
    ($runLoopRef -match "(?s)tree_search.*?final option id.*?rubric score.*?NEVER write raw candidate chains")
Add-Result "v022.r1.run_loop_reflexion_lesson" "run-loop.md says reflexion ALWAYS appends 1-line lesson" `
    ($runLoopRef -match "(?s)reflexion.*?ALWAYS append a 1-line lesson")
Add-Result "v022.r1.run_loop_manual_trigger" "run-loop.md says /dtd notepad compact runs same algorithm" `
    ($runLoopRef -match "(?s)Manual trigger.*?/dtd notepad compact.*?runs the same\s+algorithm")

$stateMd = Read-Text ".dtd/state.md"
Add-Result "v022.r1.state.section" "state.md has ## Notepad compaction (v0.2.2 R1) section" `
    ($stateMd -match "## Notepad compaction \(v0\.2\.2 R1\)")
$r1StateKeys = @("last_compaction_at", "last_compaction_reason", "compaction_warns_run")
foreach ($key in $r1StateKeys) {
    Add-Result "v022.r1.state.$key" "state.md notepad compaction has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

$doctorRefText = Read-Text ".dtd/reference/doctor-checks.md"
Add-Result "v022.r1.doctor_section" "doctor-checks ref has v0.2.2 R1 wiring checks" `
    ($doctorRefText -match "v0\.2\.2 R1 wiring checks")
$r1DoctorCodes = @(
    "notepad_compaction_unrun",
    "notepad_compaction_reason_invalid",
    "notepad_compaction_warn_high",
    "reasoning_utility_no_capsule_capture",
    "reasoning_redaction_high",
    "reasoning_notes_overflow_unrolled"
)
foreach ($code in $r1DoctorCodes) {
    Add-Result "v022.r1.doctor.code.$code" "doctor-checks ref defines R1 code $code" `
        ($doctorRefText -match [regex]::Escape($code))
}

# R1 scenarios
foreach ($letter in @("e", "f", "g", "h")) {
    Add-Result "v022.r1.scenario.85$letter" "test-scenarios.md has scenario 85$letter (R1 wiring)" `
        ($scenariosMd -match "### 85$letter\.")
}

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
