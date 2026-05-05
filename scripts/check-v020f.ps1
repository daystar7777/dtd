# DTD v0.2.0f release-contract checks
#
# Validates that the v0.2.0f Autonomy & Attention deliverables in this repo
# match the design contract:
#   - state.md: 13 fields across Attention mode + Active context pattern (incl. Codex addendum)
#   - config.md: 6 sections (decision-policy, attention, context-pattern, persona-pattern,
#                            reasoning-utility, tool-runtime) with required keys
#   - dtd.md: Autonomy & Attention Modes + Context Patterns + /dtd silent + /dtd interactive +
#             /dtd mode decision + /dtd perf + Persona/Reasoning/Tool-Use Patterns sections
#   - dtd.md: Doctor §Autonomy & Attention state + §Context-pattern state checks
#   - instructions.md: Intent Gate has perf/attention/context_pattern/decision_mode intents
#   - instructions.md: NL routing for silent/interactive/mode-decision/perf phrases
#   - test-scenarios.md: scenarios 22q, 22r, 23a-i (11 scenarios)
#   - workers.example.md: tool_runtime + native_tool_sandbox fields (Codex follow-up)
#
# Usage:
#   pwsh ./scripts/check-v020f.ps1
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

# ─── state.md fields ─────────────────────────────────────────────────────────

$stateMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/state.md") -Raw

# Attention mode section (8 fields)
Add-Result -Id "v020f.state.attention_section" -Name "state.md has Attention mode section" `
    -Pass ($stateMd -match '## Attention mode \(v0\.2\.0f\)')

$attentionFields = @("decision_mode", "decision_mode_set_by", "attention_mode",
                     "attention_mode_set_by", "attention_until", "attention_goal",
                     "deferred_decision_count", "deferred_decision_refs")
foreach ($field in $attentionFields) {
    Add-Result -Id "v020f.state.attention.$field" -Name "state.md has $field field" `
        -Pass ($stateMd -match "- $field`:")
}

# Active context pattern section (9 fields with Codex addendum)
Add-Result -Id "v020f.state.context_section" -Name "state.md has Active context pattern section" `
    -Pass ($stateMd -match '## Active context pattern.*\(v0\.2\.0f\)')

$contextFields = @("resolved_context_pattern", "resolved_handoff_mode", "resolved_sampling",
                   "resolved_controller_persona", "resolved_worker_persona",
                   "resolved_reasoning_utility", "resolved_tool_runtime",
                   "last_context_reset_at", "last_context_reset_reason")
foreach ($field in $contextFields) {
    Add-Result -Id "v020f.state.context.$field" -Name "state.md has $field field" `
        -Pass ($stateMd -match "- $field`:")
}

# CONTROLLER_TOKEN_EXHAUSTED enum extension
Add-Result -Id "v020f.state.enum.controller_exhausted" `
    -Name "state.md awaiting_user_reason enum includes CONTROLLER_TOKEN_EXHAUSTED" `
    -Pass ($stateMd -match 'CONTROLLER_TOKEN_EXHAUSTED')

# ─── config.md sections ──────────────────────────────────────────────────────

$configMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/config.md") -Raw

$configSections = @{
    "decision-policy" = @("default_decision_mode", "decision_mode_destructive_confirm")
    "attention" = @("default_attention_mode", "silent_default_hours", "silent_max_hours",
                    "silent_blocker_policy", "silent_deferred_decision_limit")
    "context-pattern" = @("default_context_pattern", "context_patterns",
                           "capability_context_defaults", "max_handoff_kb")
    "persona-pattern" = @("default_controller_persona", "default_worker_persona",
                          "persona_patterns", "max_persona_prompt_words")
    "reasoning-utility" = @("default_reasoning_utility", "reasoning_utilities",
                            "expose_chain_of_thought", "max_reasoning_summary_lines")
    "tool-runtime" = @("default_worker_tool_mode", "worker_native_requires_sandbox",
                       "controller_relay_allows_mutating_tools", "max_tool_result_kb")
}

foreach ($section in $configSections.Keys) {
    $sectionRegex = "## $([regex]::Escape($section)) \(v0\.2\.0f"
    Add-Result -Id "v020f.config.section.$section" -Name "config.md has $section section" `
        -Pass ($configMd -match $sectionRegex)

    foreach ($key in $configSections[$section]) {
        Add-Result -Id "v020f.config.key.$section.$key" -Name "config.md has $key key" `
            -Pass ($configMd -match "- $key`:")
    }
}

# Codex follow-up: silent_allow_destructive default false
Add-Result -Id "v020f.config.silent_allow_destructive" `
    -Name "config.md has silent_allow_destructive: false default" `
    -Pass ($configMd -match 'silent_allow_destructive:\s*false')

# ─── dtd.md spec sections ────────────────────────────────────────────────────

$dtdMd = Get-Content -LiteralPath (Join-Path $RepoRoot "dtd.md") -Raw

$dtdSections = @{
    "autonomy_modes" = '### Autonomy & Attention Modes \(v0\.2\.0f\)'
    "context_patterns" = '## Context Patterns \(v0\.2\.0f\)'
    "persona_section" = '## Persona, Reasoning, and Tool-Use Patterns'
    "silent_on_cmd" = '### `/dtd silent on'
    "interactive_cmd" = '### `/dtd interactive`'
    "mode_decision_cmd" = '### `/dtd mode decision'
    "perf_cmd" = '### `/dtd perf'
    "morning_summary" = '### Morning summary format'
}

foreach ($section in $dtdSections.Keys) {
    Add-Result -Id "v020f.dtdmd.$section" -Name "dtd.md has $section section" `
        -Pass ($dtdMd -match $dtdSections[$section])
}

# Doctor checks — v0.2.3 R1: lives in .dtd/reference/doctor-checks.md (extracted)
$doctorRef = Join-Path $RepoRoot ".dtd/reference/doctor-checks.md"
$doctorText = if (Test-Path -LiteralPath $doctorRef) { Get-Content -LiteralPath $doctorRef -Raw } else { "" }

Add-Result -Id "v020f.doctor_ref.autonomy" `
    -Name "doctor-checks ref has Autonomy & Attention state (v0.2.3 R1 extracted)" `
    -Pass ($doctorText -match '## Autonomy & Attention state \(v0\.2\.0f\)')

Add-Result -Id "v020f.doctor_ref.context_pattern" `
    -Name "doctor-checks ref has Context-pattern state (v0.2.3 R1 extracted)" `
    -Pass ($doctorText -match '## Context-pattern state \(v0\.2\.0f\)')

Add-Result -Id "v020f.dtdmd.doctor_stub" `
    -Name "dtd.md keeps /dtd doctor stub with Autonomy bullet" `
    -Pass (($dtdMd -match '### `/dtd doctor`') -and ($dtdMd -match 'Autonomy & Attention state \(v0\.2\.0f\)'))

# Silent ready-work algorithm — v0.2.3 R1: lives in .dtd/reference/autonomy.md (extracted)
$autonomyRef = Join-Path $RepoRoot ".dtd/reference/autonomy.md"
$autonomyText = if (Test-Path -LiteralPath $autonomyRef) { Get-Content -LiteralPath $autonomyRef -Raw } else { "" }

Add-Result -Id "v020f.autonomy_ref.silent_algorithm" `
    -Name 'autonomy ref has Silent-mode "ready work" algorithm (v0.2.3 R1 extracted)' `
    -Pass ($autonomyText -match 'Silent-mode "ready work" algorithm')

# Defer triggers table — also in autonomy ref after R1 extraction
Add-Result -Id "v020f.autonomy_ref.defer_triggers" -Name "autonomy ref has defer triggers table" `
    -Pass ($autonomyText -match 'Defer triggers \(silent mode\)')

# CONTROLLER_TOKEN_EXHAUSTED capsule body — also in autonomy ref
Add-Result -Id "v020f.autonomy_ref.controller_exhausted_capsule" `
    -Name "autonomy ref has CONTROLLER_TOKEN_EXHAUSTED decision capsule body" `
    -Pass ($autonomyText -match 'awaiting_user_reason: CONTROLLER_TOKEN_EXHAUSTED')

# dtd.md still has the section header (R1 extraction stub)
Add-Result -Id "v020f.dtdmd.autonomy_stub" `
    -Name "dtd.md retains autonomy section header + v0.2.3 R1 extraction note" `
    -Pass (($dtdMd -match '### Autonomy & Attention Modes \(v0\.2\.0f\)') -and ($dtdMd -match 'v0\.2\.3 R1 extraction'))

# Controller usage ledger
Add-Result -Id "v020f.dtdmd.controller_usage_ledger" `
    -Name "dtd.md spec'd controller-usage-run-NNN.md ledger" `
    -Pass ($dtdMd -match 'controller-usage-run-NNN\.md')

# ─── instructions.md ─────────────────────────────────────────────────────────

$instrMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/instructions.md") -Raw

$instrIntents = @("perf", "attention", "context_pattern", "decision_mode")
foreach ($intent in $instrIntents) {
    Add-Result -Id "v020f.instr.intent.$intent" -Name "instructions.md Intent Gate has $intent intent" `
        -Pass ($instrMd -match "\| ``$intent`` \|")
}

# Worker context reset contract
Add-Result -Id "v020f.instr.context_reset" `
    -Name "instructions.md has Worker context reset + pattern resolution" `
    -Pass ($instrMd -match 'Worker context reset \+ pattern resolution')

# Don't auto-flip rule
Add-Result -Id "v020f.instr.no_auto_flip" `
    -Name "instructions.md has 'Don't auto-flip silent ... interactive' rule" `
    -Pass ($instrMd -match "[Dd]on't auto-flip silent")

# ─── test-scenarios.md ───────────────────────────────────────────────────────

$scenariosMd = Get-Content -LiteralPath (Join-Path $RepoRoot "test-scenarios.md") -Raw

# Scenarios 22q and 22r (context pattern + persona/reasoning/tool runtime)
Add-Result -Id "v020f.scenarios.22q" -Name "test-scenarios.md has scenario 22q" `
    -Pass ($scenariosMd -match '### 22q\.')

Add-Result -Id "v020f.scenarios.22r" -Name "test-scenarios.md has scenario 22r" `
    -Pass ($scenariosMd -match '### 22r\.')

# Scenarios 23a-i (9 scenarios)
foreach ($letter in @("a", "b", "c", "d", "e", "f", "g", "h", "i")) {
    Add-Result -Id "v020f.scenarios.23$letter" -Name "test-scenarios.md has scenario 23$letter" `
        -Pass ($scenariosMd -match "### 23$letter\.")
}

# ─── workers.example.md (Codex follow-up tool_runtime fields) ────────────────

$workersExampleMd = Get-Content -LiteralPath (Join-Path $RepoRoot ".dtd/workers.example.md") -Raw

Add-Result -Id "v020f.workers.tool_runtime" -Name "workers.example.md has tool_runtime field" `
    -Pass ($workersExampleMd -match '- tool_runtime:')

Add-Result -Id "v020f.workers.native_tool_sandbox" `
    -Name "workers.example.md has native_tool_sandbox field" `
    -Pass ($workersExampleMd -match '- native_tool_sandbox:')

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
Write-Host "V020F_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
