# DTD v0.2.0e release-contract checks
#
# Validates that the v0.2.0e deliverables in this repo match the design contract:
#   - .dtd/locales/ directory exists with ko.md + ja.md
#   - Each pack ≤ 8 KB
#   - Each pack has required ## Slash aliases + ## NL routing additions
#   - Each pack has ## Pack metadata declaring locale + merge_policy
#   - dtd.md has /dtd locale command body
#   - dtd.md doctor sections list mentions Locale state (v0.2.0e)
#   - .dtd/reference/doctor-checks.md has Locale state (v0.2.0e) section
#   - .dtd/instructions.md has §"Locale bootstrap aliases" with
#     /ㄷㅌㄷ locale enable form
#   - .dtd/instructions.md has step 1.6 locale-pack loading
#   - .dtd/config.md has ## locale (v0.2.0e) section with required keys
#   - .dtd/state.md has ## Locale (v0.2.0e) section with required fields
#   - test-scenarios.md has scenarios 44-49
#   - scripts/build-manifest.ps1 includes locale pack files
#
# Usage:
#   pwsh ./scripts/check-v020e.ps1
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

# ─── locales directory ───────────────────────────────────────────────────────

$localesDir = Join-Path $RepoRoot ".dtd/locales"
Add-Result "v020e.locales.dir" ".dtd/locales/ directory exists" (Test-Path -LiteralPath $localesDir)

$shippedPacks = @("ko", "ja")
foreach ($lang in $shippedPacks) {
    $path = Join-Path $localesDir "$lang.md"
    if (Test-Path -LiteralPath $path) {
        $size = (Get-Item -LiteralPath $path).Length
        $text = Get-Content -LiteralPath $path -Raw
        Add-Result "v020e.locale.$lang.exists" "locales/$lang.md exists" $true "size=$size"
        Add-Result "v020e.locale.$lang.budget" "locales/$lang.md ≤ 12 KB" ($size -le 12288) "size=$size"
        Add-Result "v020e.locale.$lang.slash_aliases" "locales/$lang.md has ## Slash aliases" `
            ($text -match "## Slash aliases")
        Add-Result "v020e.locale.$lang.nl_routing" "locales/$lang.md has ## NL routing additions" `
            ($text -match "## NL routing additions")
        Add-Result "v020e.locale.$lang.pack_metadata" "locales/$lang.md has ## Pack metadata" `
            ($text -match "## Pack metadata")
        Add-Result "v020e.locale.$lang.locale_field" "locales/$lang.md declares locale: $lang" `
            ($text -match "(?m)^- locale:\s*$lang\b")
        Add-Result "v020e.locale.$lang.merge_policy" "locales/$lang.md declares merge_policy" `
            ($text -match "(?m)^- merge_policy:\s*pack_wins_on_conflict")
    } else {
        Add-Result "v020e.locale.$lang.exists" "locales/$lang.md exists" $false "MISSING"
    }
}

# ─── dtd.md ──────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"

Add-Result "v020e.dtdmd.locale_cmd" "dtd.md has /dtd locale command body" `
    ($dtdMd -match '### `/dtd locale \[enable\|disable\|list\|show\]')
Add-Result "v020e.dtdmd.locale_forms" "dtd.md /dtd locale documents enable/disable/list/show forms" `
    (($dtdMd -match "/dtd locale list") -and `
     ($dtdMd -match "/dtd locale enable <lang>") -and `
     ($dtdMd -match "/dtd locale disable"))
Add-Result "v020e.dtdmd.doctor_lists_locale" "dtd.md doctor section lists Locale state (v0.2.0e)" `
    ($dtdMd -match "Locale state \(v0\.2\.0e\)")

# ─── reference/doctor-checks.md ──────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v020e.doctor_ref.locale_section" "doctor-checks ref has ## Locale state (v0.2.0e) section" `
    ($doctorRef -match "## Locale state \(v0\.2\.0e\)")
Add-Result "v020e.doctor_ref.locale_pack_missing" "doctor-checks ref defines locale_pack_missing" `
    ($doctorRef -match "locale_pack_missing")
Add-Result "v020e.doctor_ref.locale_pack_oversized" "doctor-checks ref defines locale_pack_oversized" `
    ($doctorRef -match "locale_pack_oversized")
Add-Result "v020e.doctor_ref.required_section" "doctor-checks ref defines locale_pack_missing_required_section" `
    ($doctorRef -match "locale_pack_missing_required_section")
Add-Result "v020e.doctor_ref.bootstrap_alias" "doctor-checks ref defines bootstrap_alias_missing" `
    ($doctorRef -match "bootstrap_alias_missing")
Add-Result "v020e.doctor_ref.locale_state_drift" "doctor-checks ref defines locale_state_drift" `
    ($doctorRef -match "locale_state_drift")

# ─── instructions.md ──────────────────────────────────────────────────────────

$instructionsMd = Read-Text ".dtd/instructions.md"

Add-Result "v020e.instructions.bootstrap_section" "instructions.md has Locale bootstrap aliases section" `
    ($instructionsMd -match "## Locale bootstrap aliases")
# Korean alias check uses Unicode codepoint construction to avoid
# source-encoding ambiguity (PS5.1 reads UTF-8-without-BOM scripts as ANSI).
# /ㄷㅌㄷ = U+3137 U+314C U+3137; bootstrap row: /<KO> locale enable
$koreanAlias = "/" + [char]0x3137 + [char]0x314C + [char]0x3137 + " locale enable"
Add-Result "v020e.instructions.bootstrap_korean_alias" "bootstrap aliases include /<KO> locale enable" `
    ($instructionsMd -match [regex]::Escape($koreanAlias))
Add-Result "v020e.instructions.locale_step_1_6" "per-turn protocol step 1.6 loads locale pack" `
    ($instructionsMd -match "1\.6\.\s*\*\*Load locale pack\*\*")
Add-Result "v020e.instructions.pack_wins" "instructions.md says pack wins on conflict" `
    ($instructionsMd -match "pack wins")
Add-Result "v020e.instructions.locale_intent" "Intent Gate includes locale intent" `
    ($instructionsMd -match '\| `locale` \| `/dtd locale')
Add-Result "v020e.instructions.locale_observational" "locale list/show are observational reads" `
    (($instructionsMd -match "/dtd locale list") -and
     ($instructionsMd -match "/dtd locale show"))
$koreanWorkerAdd = "/" + [char]0x3137 + [char]0x314C + [char]0x3137 + " " +
    [char]0xC6CC + [char]0xCEE4 + " " + [char]0xCD94 + [char]0xAC00
Add-Result "v020e.instructions.no_core_worker_add_route" "core instructions do not route Korean worker-add before locale enable" `
    (-not ($instructionsMd -match ([regex]::Escape($koreanWorkerAdd) + ".*?/dtd workers add")))

# ─── config.md ────────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v020e.config.section" "config.md has ## locale (v0.2.0e) section" `
    ($configMd -match "## locale \(v0\.2\.0e\)")
$localeKeys = @("enabled", "language", "auto_probe", "pack_path",
                "pack_size_budget_kb", "merge_policy")
foreach ($key in $localeKeys) {
    Add-Result "v020e.config.key.$key" "config.md locale section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── state.md ─────────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v020e.state.section" "state.md has ## Locale (v0.2.0e) section" `
    ($stateMd -match "## Locale \(v0\.2\.0e\)")
$stateKeys = @("locale_active", "locale_set_by", "locale_set_at")
foreach ($key in $stateKeys) {
    Add-Result "v020e.state.key.$key" "state.md Locale section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── test-scenarios.md ────────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

foreach ($n in 44..49) {
    Add-Result "v020e.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v020e.scenarios.section_header" "test-scenarios.md has v0.2.0e section header" `
    ($scenariosMd -match "## v0\.2\.0e .* Locale Packs")

# ─── build-manifest.ps1 ───────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v020e.manifest.locales_ko" "build-manifest includes .dtd/locales/ko.md" `
    ($builderText -match [regex]::Escape(".dtd/locales/ko.md"))
Add-Result "v020e.manifest.locales_ja" "build-manifest includes .dtd/locales/ja.md" `
    ($builderText -match [regex]::Escape(".dtd/locales/ja.md"))
Add-Result "v020e.manifest.checker" "build-manifest includes scripts/check-v020e.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v020e.ps1"))

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
Write-Host "V020E_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
