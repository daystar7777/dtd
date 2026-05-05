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
    "run-loop", "doctor-checks", "roadmap", "load-profile",
    "v030a-cross-run-loop-guard",
    "v030c-consensus",
    "v030d-cross-machine-session-sync",
    "v030e-time-limited-permissions",
    "v030b-quota-scheduling",
    "v030-r2-live-test-plan",
    "v030-r2-0-readiness-checklist"
)
$canonicalReferenceTopics = $referenceTopics

$referenceDir = Join-Path $RepoRoot ".dtd/reference"
$referenceFiles = @()
if (Test-Path -LiteralPath $referenceDir) {
    $referenceFiles = @(Get-ChildItem -LiteralPath $referenceDir -Filter "*.md" -File)
}

Add-Result "v023.reference.dir" ".dtd/reference directory exists" (Test-Path -LiteralPath $referenceDir)
Add-Result "v023.reference.count" ".dtd/reference has 21 markdown files (20 topics + index after R2-0 readiness checklist)" ($referenceFiles.Count -eq 21) "count=$($referenceFiles.Count)"

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
        # Match ONLY the table-row line that starts with `| ` and has the
        # topic in backticks (avoids matching prose mentions of the topic).
        $rowPattern = '^\| `' + [regex]::Escape($topic) + '` '
        $topicLine = @($indexText -split "`r?`n" | Where-Object { $_ -match $rowPattern } | Select-Object -First 1)
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
        # Budget tiers:
        # - Cross-cutting consolidation refs (doctor-checks, run-loop) absorb
        #   per-sub-release R1 wiring across v0.2 + R0 wiring for v0.3+.
        #   Bumped 24->32 (v0.2 R1), 32->48 (v0.3 R0 absorbing quota contract).
        # - Per-sub-release v0.3 topics (v030*) host BOTH R0 spec + R1
        #   runtime contract in one file (per Codex per-sub-release split
        #   pattern). They get a 32 KB budget — between strict topic 24 KB
        #   and cross-cutting 48 KB.
        # - Topic-specific refs keep 24 KB.
        $crossCutting = @("doctor-checks", "run-loop")
        $perSubRelease = $topic -like "v030*"
        if ($crossCutting -contains $topic) {
            $cap = 49152; $capLabel = "48 KB"
        } elseif ($perSubRelease) {
            $cap = 32768; $capLabel = "32 KB"
        } else {
            $cap = 24576; $capLabel = "24 KB"
        }
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
$readmeText = Read-Text "README.md"
$readmeKoText = Read-Text "README.ko.md"
$readmeJaText = Read-Text "README.ja.md"
$helpIndexText = Read-Text ".dtd/help/index.md"

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

$roadmapRefText = Read-Text ".dtd/reference/roadmap.md"
Add-Result "v023.roadmap.permission_keys_current" "roadmap includes current 10 permission keys" `
    (($roadmapRefText -match 'tool_relay_read') -and ($roadmapRefText -match 'tool_relay_mutating'))
Add-Result "v023.roadmap.notepad_v2_current" "roadmap says notepad v2 is 8-heading with Reasoning Notes" `
    (($roadmapRefText -match '8-heading `<handoff>`') -and
     ($roadmapRefText -match 'Reasoning Notes') -and
     ($roadmapRefText -match '1\.2\s*KB'))
Add-Result "v023.roadmap.snapshot_revertable_default" "roadmap says normal worker output is revertable by default" `
    (($roadmapRefText -match 'Default for normal worker output') -and
     ($roadmapRefText -match 'absent-prestate marker'))
Add-Result "v023.roadmap.no_stale_notepad_v1" "roadmap no longer says notepad v2 is 7-heading" `
    (-not ($roadmapRefText -match '7-heading `<handoff>`'))
Add-Result "v023.roadmap.no_stale_snapshot_vcs_default" "roadmap no longer says metadata-only defaults for version control" `
    (-not ($roadmapRefText -match 'default\s+for\s+files\s+within\s+version\s+control'))
Add-Result "v023.roadmap.anchor_current_v03" "roadmap anchor includes v0.3 and R2 status" `
    (($roadmapRefText -match 'v0\.1\.1 / v0\.2 / v0\.3') -and
     ($roadmapRefText -match 'R2 live-test status') -and
     ($roadmapRefText -match 'v030-r2-live-test-plan'))

$r2LivePlanText = Read-Text ".dtd/reference/v030-r2-live-test-plan.md"
Add-Result "v023.r2_live_plan.rehash_scenario" "R2 live plan covers loop-guard rehash admin path" `
    (($r2LivePlanText -match 'L-A-4') -and ($r2LivePlanText -match '/dtd loop-guard rehash') -and
     ($r2LivePlanText -match 'rehash_admin'))
Add-Result "v023.r2_live_plan.concurrent_finalize_code" "R2 live plan uses cross-run concurrent finalize doctor code" `
    (($r2LivePlanText -match 'cross_run_concurrent_finalize_detected') -and
     (-not ($r2LivePlanText -match 'consensus_concurrent_finalize_detected')))
Add-Result "v023.r2_live_plan.session_sync_no_binary_blob" "R2 live plan describes encrypted base64url sync rows" `
    (($r2LivePlanText -match 'encrypted base64url text rows') -and
     (-not ($r2LivePlanText -match 'binary blob')))
Add-Result "v023.r2_live_plan.negative_error_remediation" "R2 live plan permits expected negative ERROR then remediation" `
    (($r2LivePlanText -match 'No unexpected `ERROR`-level doctor codes remain') -and
     ($r2LivePlanText -match 'Negative scenarios such as L-D-3 MUST'))
Add-Result "v023.r2_live_plan.lock_timeout_fixture" "R2 live plan forces lock hold beyond timeout for L-C-4" `
    ($r2LivePlanText -match 'holds the group lock longer than')
Add-Result "v023.r2_live_plan.reporting_evidence" "R2 live plan reporting table includes Evidence column" `
    (($r2LivePlanText -match '\| Scenario \| Status \| Evidence \| Notes \|') -and
     ($r2LivePlanText -match 'decision capsule id'))

$r2ReadinessText = Read-Text ".dtd/reference/v030-r2-0-readiness-checklist.md"
Add-Result "v023.r2_0.command_surface" "dtd.md + instructions expose /dtd r2 readiness" `
    (($dtdMd -match '/dtd r2 readiness') -and
     ($instructionsMd -match '\| `r2_readiness` \|') -and
     ($instructionsMd -match '/dtd r2 readiness') -and
     ($instructionsMd -match 'no worker calls, no test project creation'))
Add-Result "v023.r2_0.readme_help_discovery" "README and help index expose /dtd r2 readiness" `
    (($readmeText -match '/dtd r2 readiness') -and
     ($readmeText -match 'v0\.3 live-test entry gate') -and
     ($helpIndexText -match '/dtd r2 readiness') -and
     ($helpIndexText -match 'v030-r2-0-readiness-checklist'))
Add-Result "v023.r2_0.localized_readme_discovery" "localized READMEs expose /dtd r2 readiness and current worker health wording" `
    (($readmeKoText -match '/dtd r2 readiness') -and
     ($readmeJaText -match '/dtd r2 readiness') -and
     ($readmeKoText -match 'v0\.2\.1\+') -and
     ($readmeJaText -match 'v0\.2\.1\+'))
Add-Result "v023.r2_0.reference_command_surface" "R2-0 readiness ref documents command and aliases" `
    (($r2ReadinessText -match '/dtd r2 readiness \[--full\|--json\]') -and
     ($r2ReadinessText -match '/dtd r2 status') -and
     ($r2ReadinessText -match '/dtd r2 check'))
Add-Result "v023.r2_0.no_mutating_sync_probe" "R2-0 readiness is observational for sync targets" `
    (($r2ReadinessText -match 'no sync-target write') -and
     ($r2ReadinessText -match 'sync_target_declared') -and
     (-not ($r2ReadinessText -match 'check_writable')) -and
     (-not ($r2ReadinessText -match 'write \+ delete a test file')))
Add-Result "v023.r2_0.sync_disabled_warns" "R2-0 returns WARN when session sync is disabled/skipped" `
    (($r2ReadinessText -match 'if not config\.session_sync\.enabled') -and
     ($r2ReadinessText -match 'session_sync disabled') -and
     ($r2ReadinessText -match 'R2-0 decision status WARN'))
Add-Result "v023.r2_0.quota_header_blocks_full_r2" "R2-0 treats missing quota-header worker as full-R2 blocker" `
    (($r2ReadinessText -match 'r2_0_no_quota_header_worker \(ERROR') -and
     ($r2ReadinessText -match 'Blocks required L-B-2 coverage') -and
     ($r2ReadinessText -match 'full R2 cannot start'))
Add-Result "v023.r2_0.collects_all_blockers" "R2-0 collects all observable blockers before STOP" `
    (($r2ReadinessText -match 'blockers = \[\]') -and
     ($r2ReadinessText -match 'warnings = \[\]') -and
     ($r2ReadinessText -match 'collect all observable blockers'))
Add-Result "v023.r2_0.plan_related_topic" "R2 live plan links R2-0 readiness topic" `
    ($r2LivePlanText -match 'v030-r2-0-readiness-checklist\.md')

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
