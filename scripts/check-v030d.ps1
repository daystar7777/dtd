# DTD v0.3.0d release-contract checks (cross-machine session sync)
#
# Validates:
#   - .dtd/reference/v030d-cross-machine-session-sync.md exists with required sections
#   - reference/index.md catalog has v030d-cross-machine-session-sync row
#   - dtd.md has /dtd session-sync command body + Session sync doctor list
#   - permissions.md unchanged (no new key — 11-key invariant from v0.3.0c stable)
#   - state.md has ## Session sync (v0.3.0d) fields + SESSION_CONFLICT enum
#   - config.md has ## session-sync (v0.3.0d) + 9 keys
#   - reference/doctor-checks.md has v0.3.0d Cross-machine session sync checks
#   - test-scenarios.md has scenarios 142-149
#   - .dtd/.gitignore lists session-sync.md + session-sync.encrypted
#   - Codex P1.6 mandatory encryption invariant present
#   - Codex P1.7 repo_identity_hash priority preserved (shared with v0.3.0a)
#   - SESSION_CONFLICT capsule with 4 options + fresh default
#   - scripts/build-manifest.ps1 includes new reference + check-v030d.ps1

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
function Read-Text([string]$RelativePath) {
    [System.IO.File]::ReadAllText((Join-Path $RepoRoot $RelativePath), [System.Text.Encoding]::UTF8)
}

# ─── reference/v030d-cross-machine-session-sync.md ──────────────────────────

$v030dRef = Read-Text ".dtd/reference/v030d-cross-machine-session-sync.md"

Add-Result "v030d.ref.summary" "v030d ref has Summary section" `
    ($v030dRef -match "(?m)^## Summary")
Add-Result "v030d.ref.anchor" "v030d ref has Anchor section" `
    ($v030dRef -match "(?m)^## Anchor")

$backends = @("filesystem", "git_branch", "none")
foreach ($b in $backends) {
    Add-Result "v030d.ref.backend.$b" "v030d ref documents backend $b" `
        ($v030dRef -match [regex]::Escape($b))
}

Add-Result "v030d.ref.encryption_mandatory" "v030d ref says encryption MANDATORY" `
    (($v030dRef -match "MANDATORY") -and ($v030dRef -match "Codex P1\.6"))
Add-Result "v030d.ref.no_plaintext_fallback" "v030d ref says missing key NEVER plaintext fallback" `
    ($v030dRef -match "NEVER a WARN with plaintext fallback")
Add-Result "v030d.ref.raw_session_never_synced" "v030d ref says raw session ids NEVER synced" `
    (($v030dRef -match "MUST NEVER be written to a synced") -or `
     ($v030dRef -match "raw provider session ids are NEVER written"))
Add-Result "v030d.ref.repo_identity_shared" "v030d ref shares repo_identity_hash with v0.3.0a" `
    (($v030dRef -match "v030a-cross-run-loop-guard") -and ($v030dRef -match "repo_identity_hash"))
Add-Result "v030d.ref.repo_identity_priority" "v030d ref documents 3-tier priority (PRIMARY/SECONDARY/TERTIARY)" `
    (($v030dRef -match "PRIMARY") -and ($v030dRef -match "SECONDARY") -and ($v030dRef -match "TERTIARY"))
Add-Result "v030d.ref.session_conflict_capsule" "v030d ref has SESSION_CONFLICT capsule" `
    ($v030dRef -match "awaiting_user_reason: SESSION_CONFLICT")

$capsuleOptions = @("use_local", "use_remote", "fresh", "stop")
foreach ($opt in $capsuleOptions) {
    Add-Result "v030d.ref.capsule.$opt" "v030d capsule has option $opt" `
        ($v030dRef -match "id: $opt")
}
Add-Result "v030d.ref.capsule_default_fresh" "v030d capsule default is fresh" `
    ($v030dRef -match "decision_default: fresh")

Add-Result "v030d.ref.connectivity_not_conflict" "v030d ref says connectivity != conflict" `
    (($v030dRef -match "connectivity") -and ($v030dRef -match "do NOT block dispatch"))
Add-Result "v030d.ref.aes_gcm" "v030d ref specifies AES-256-GCM" `
    ($v030dRef -match "AES-256-GCM")
Add-Result "v030d.ref.hkdf" "v030d ref specifies HKDF key derivation" `
    ($v030dRef -match "HKDF")
Add-Result "v030d.ref.permission_unchanged" "v030d ref says NO new permission key" `
    (($v030dRef -match "does NOT add a new permission key") -or `
     ($v030dRef -match "11-key invariant.*remains stable"))
Add-Result "v030d.ref.r0_no_setup_wizard" "v030d ref says setup wizard deferred to R1" `
    ($v030dRef -match "deferred to R1")
Add-Result "v030d.ref.machine_id_uuid" "v030d ref says machine_id is UUID + optional display_name" `
    (($v030dRef -match "UUID") -and ($v030dRef -match "display_name"))

# ─── reference/index.md ─────────────────────────────────────────────────────

$indexRef = Read-Text ".dtd/reference/index.md"

Add-Result "v030d.index.row" "index.md has v030d-cross-machine-session-sync row" `
    ($indexRef -match '(?m)^\| `v030d-cross-machine-session-sync` ')
Add-Result "v030d.index.canonical_marker" "index.md marks v030d-cross-machine-session-sync canonical" `
    ($indexRef -match '(?m)^\| `v030d-cross-machine-session-sync` .*\| canonical \|')
Add-Result "v030d.index.expansion_note" "index.md mentions v0.3.0d expansion (15 -> 16)" `
    ($indexRef -match "v0\.3\.0d|15 .*16|14 .* 15 .* 16|14 .* 16")

# ─── dtd.md ─────────────────────────────────────────────────────────────────

$dtdMd = Read-Text "dtd.md"
$runLoopRef = Read-Text ".dtd/reference/run-loop.md"

Add-Result "v030d.dtdmd.command_body" "dtd.md has /dtd session-sync command body" `
    ($dtdMd -match '### `/dtd session-sync \[show\|sync\|expire\|purge\]` \(v0\.3\.0d\)')
Add-Result "v030d.dtdmd.show_form" "dtd.md /dtd session-sync show form" `
    ($dtdMd -match "/dtd session-sync show")
Add-Result "v030d.dtdmd.sync_form" "dtd.md /dtd session-sync sync form" `
    ($dtdMd -match "/dtd session-sync sync")
Add-Result "v030d.dtdmd.expire_form" "dtd.md /dtd session-sync expire form" `
    ($dtdMd -match "/dtd session-sync expire")
Add-Result "v030d.dtdmd.purge_form" "dtd.md /dtd session-sync purge form" `
    ($dtdMd -match "/dtd session-sync purge")
Add-Result "v030d.dtdmd.encryption_mandatory" "dtd.md /dtd session-sync says MANDATORY encryption" `
    (($dtdMd -match "MANDATORILY encrypted") -and ($dtdMd -match "Codex P1\.6"))
Add-Result "v030d.dtdmd.doctor_lists_session_sync" "dtd.md doctor lists Session sync (v0.3.0d)" `
    ($dtdMd -match "Session sync \(v0\.3\.0d\)")
Add-Result "v030d.runloop.finalize_hook" "run-loop.md wires finalize_run step 9.session-sync terminal hook" `
    (($runLoopRef -match "9\.session-sync") -and `
     ($runLoopRef -match "v030d-cross-machine-session-sync"))
Add-Result "v030d.runloop.clears_pending_session_conflict" "run-loop.md terminal cleanup clears pending_session_conflict" `
    ($runLoopRef -match "pending_session_conflict")
Add-Result "v030d.dtdmd.session_conflict_capsule" "dtd.md mentions SESSION_CONFLICT capsule" `
    ($dtdMd -match "SESSION_CONFLICT")

# ─── permissions.md (unchanged — 11-key invariant from v0.3.0c stable) ─────

$permissionsMd = Read-Text ".dtd/permissions.md"

Add-Result "v030d.permissions.task_consensus_still_present" "permissions.md still has task_consensus (v0.3.0c)" `
    ($permissionsMd -match "(?m)^- ask\s+\|\s+task_consensus\s+\|")

# ─── state.md ───────────────────────────────────────────────────────────────

$stateMd = Read-Text ".dtd/state.md"

Add-Result "v030d.state.section" "state.md has ## Session sync (v0.3.0d)" `
    ($stateMd -match "## Session sync \(v0\.3\.0d\)")
$stateKeys = @("session_sync_last_read_at", "session_sync_last_write_at",
               "session_sync_pending_conflicts", "machine_id",
               "machine_display_name")
foreach ($key in $stateKeys) {
    Add-Result "v030d.state.key.$key" "state.md session-sync section has $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030d.state.session_conflict_enum" "state.md awaiting_user_reason lists SESSION_CONFLICT" `
    ($stateMd -match "SESSION_CONFLICT")

# ─── config.md ──────────────────────────────────────────────────────────────

$configMd = Read-Text ".dtd/config.md"

Add-Result "v030d.config.section" "config.md has ## session-sync (v0.3.0d)" `
    ($configMd -match "## session-sync \(v0\.3\.0d\)")
$configKeys = @("enabled", "backend", "sync_path", "sync_branch",
                "sync_remote", "sync_commit_interval_min",
                "encryption_key_env", "conflict_strategy",
                "expires_default_hours")
foreach ($key in $configKeys) {
    Add-Result "v030d.config.key.$key" "config.md session-sync section has $key" `
        ($configMd -match "(?m)^- $([regex]::Escape($key)):")
}
Add-Result "v030d.config.encryption_key_env_value" "config.md encryption_key_env names env var (not literal)" `
    ($configMd -match "encryption_key_env: DTD_SESSION_SYNC_KEY")
Add-Result "v030d.config.conflict_default_ask" "config.md conflict_strategy default = ask" `
    ($configMd -match "conflict_strategy: ask")

# ─── reference/doctor-checks.md ─────────────────────────────────────────────

$doctorRef = Read-Text ".dtd/reference/doctor-checks.md"

Add-Result "v030d.doctor.section" "doctor-checks ref has v0.3.0d Cross-machine session sync checks" `
    ($doctorRef -match "v0\.3\.0d Cross-machine session sync checks")
$doctorCodes = @(
    "session_sync_no_encryption_key",
    "session_sync_path_invalid",
    "session_sync_branch_missing",
    "session_sync_plaintext_violation",
    "session_sync_files_staged_on_work_branch",
    "session_sync_unresolved_conflicts",
    "session_sync_expired_rows_pending",
    "session_sync_repo_identity_unstable",
    "session_sync_machine_id_missing",
    "session_sync_unreachable"
)
foreach ($code in $doctorCodes) {
    Add-Result "v030d.doctor.code.$code" "doctor-checks ref defines $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030d.doctor.no_encryption_is_error" "doctor-checks says missing key is ERROR (not WARN)" `
    ($doctorRef -match "(?s)session_sync_no_encryption_key.*?ERROR")
Add-Result "v030d.doctor.enabled_gating" "doctor-checks gates backend errors on session_sync.enabled true" `
    (($doctorRef -match "session_sync\.enabled: true") -and `
     ($v030dRef -match "session_sync\.enabled: true"))
Add-Result "v030d.doctor.git_branch_staging_guard" "session sync doctor protects ignored ledgers from work-branch staging" `
    (($doctorRef -match "session_sync_files_staged_on_work_branch") -and `
     ($v030dRef -match "force-add") -and `
     ($v030dRef -match "dedicated sync"))

# ─── test-scenarios.md ──────────────────────────────────────────────────────

$scenariosMd = Read-Text "test-scenarios.md"

Add-Result "v030d.scenarios.section_header" "test-scenarios.md has v0.3.0d section header" `
    ($scenariosMd -match "## v0\.3\.0d .* Cross-machine session sync")
foreach ($n in 142..149) {
    Add-Result "v030d.scenarios.$n" "test-scenarios.md has scenario $n" `
        ($scenariosMd -match "### $n\.")
}
Add-Result "v030d.scenarios.r1_section_header" "test-scenarios.md has v0.3.0d R1 section header" `
    ($scenariosMd -match "## v0\.3\.0d R1 .* Cross-machine session sync runtime")
foreach ($n in 182..189) {
    Add-Result "v030d.scenarios.r1_$n" "test-scenarios.md has R1 scenario $n" `
        ($scenariosMd -match "### $n\.")
}

# ─── reference/v030d (R1 sections) ──────────────────────────────────────────

Add-Result "v030d.r1_ref.section" "v030d ref has ## R1 runtime contract section" `
    ($v030dRef -match "(?m)^## R1 runtime contract")
Add-Result "v030d.r1_ref.encrypt_function" "v030d R1 ref documents encrypt_session_id() function" `
    (($v030dRef -match "encrypt_session_id\(") -and ($v030dRef -match "decrypt_session_id\("))
Add-Result "v030d.r1_ref.hkdf_salt" "v030d R1 ref defines HKDF salt as first 16 bytes of repo_identity_hash" `
    (($v030dRef -match "hex_to_bytes\(repo_identity_hash\)\[0:16\]") -and `
     ($v030dRef -match "first 16 bytes"))
Add-Result "v030d.r1_ref.hkdf_info_label" "v030d R1 ref defines HKDF info label" `
    ($v030dRef -match 'dtd-session-sync-v1')
Add-Result "v030d.r1_ref.aes_gcm_associated_data" "v030d R1 ref binds AES-GCM via metadata-bound associated_data" `
    (($v030dRef -match "session_sync_aad") -and `
     ($v030dRef -match "machine_id") -and `
     ($v030dRef -match "provider") -and `
     ($v030dRef -match "session_id_hash"))
Add-Result "v030d.r1_ref.encrypted_format" "v030d R1 ref documents encrypted blob row format" `
    ($v030dRef -match "<session_id_hash> \| <nonce_b64u> \| <ciphertext_b64u> \| <auth_tag_b64u>")
Add-Result "v030d.r1_ref.pre_dispatch_read" "v030d R1 ref documents pre_dispatch_sync_read()" `
    ($v030dRef -match "pre_dispatch_sync_read\(")
Add-Result "v030d.r1_ref.backend_filesystem_read" "v030d R1 ref documents backend_read_filesystem()" `
    ($v030dRef -match "backend_read_filesystem\(")
Add-Result "v030d.r1_ref.backend_git_branch_read" "v030d R1 ref documents backend_read_git_branch() with git show" `
    (($v030dRef -match "backend_read_git_branch\(") -and ($v030dRef -match "git show"))
Add-Result "v030d.r1_ref.finalize_step_9" "v030d R1 ref documents finalize_run step 9.session-sync" `
    (($v030dRef -match "finalize_run_step_9_session_sync\(") -and ($v030dRef -match "9\.session-sync"))
Add-Result "v030d.r1_ref.git_worktree_isolation" "v030d R1 ref documents git worktree isolation pattern" `
    (($v030dRef -match "session-sync-worktree") -and ($v030dRef -match "git_worktree_add\("))
Add-Result "v030d.r1_ref.session_conflict_resume_action" "v030d R1 ref documents SESSION_CONFLICT decision_resume_action map" `
    (($v030dRef -match "decision_resume_action") -and `
     ($v030dRef -match "use_local") -and `
     ($v030dRef -match "use_remote") -and `
     ($v030dRef -match "fresh"))
Add-Result "v030d.r1_ref.session_conflict_full_capsule" "v030d R1 SESSION_CONFLICT path uses full decision capsule + durable payload" `
    (($v030dRef -match "awaiting_user_decision = true") -and `
     ($v030dRef -match "decision_id = `"dec-NNN`"") -and `
     ($v030dRef -match "pending_session_conflict") -and `
     ($v030dRef -match "user_decision_options = \[`"use_local`", `"use_remote`", `"fresh`", `"stop`"\]"))
Add-Result "v030d.r1_ref.remote_row_requires_encrypted_backing" "v030d R1 pre-dispatch refuses remote rows without encrypted backing" `
    (($v030dRef -match "remote public row has no encrypted backing") -and `
     ($v030dRef -match "session_sync_plaintext_violation"))
Add-Result "v030d.r1_ref.session_conflict_cleanup" "v030d R1 clears pending_session_conflict after resolution" `
    (($v030dRef -match 'clear\s+`?state\.pending_session_conflict') -and `
     ($v030dRef -match "session_sync_pending_conflicts"))
Add-Result "v030d.r1_ref.connectivity_not_conflict_r1" "v030d R1 ref reaffirms connectivity != conflict" `
    ($v030dRef -match "(?s)connectivity failure.*?WARN-only")
Add-Result "v030d.r1_ref.r1_scenarios" "v030d R1 ref lists scenarios 182-189" `
    ($v030dRef -match "(?s)R1 acceptance scenarios.*?182.*?189")

# v030d R1 doctor codes (additional)
$v030dR1DoctorCodes = @(
    "session_sync_decrypt_failed",
    "session_sync_consecutive_unreachable_count",
    "session_sync_worktree_orphan",
    "session_sync_encrypted_format_invalid",
    "session_sync_hkdf_salt_mismatch"
)
foreach ($code in $v030dR1DoctorCodes) {
    Add-Result "v030d.doctor.r1_code.$code" "doctor-checks ref defines R1 $code" `
        ($doctorRef -match [regex]::Escape($code))
}
Add-Result "v030d.doctor.r1_section" "doctor-checks ref has v0.3.0d R1 runtime checks header" `
    ($doctorRef -match "v0\.3\.0d R1 runtime checks")

# v030d R1 state fields
$v030dR1StateKeys = @("session_sync_consecutive_unreachable_count",
                       "last_session_sync_decrypt_failure_at",
                       "pending_session_conflict")
foreach ($key in $v030dR1StateKeys) {
    Add-Result "v030d.state.r1_key.$key" "state.md Session sync section has R1 $key" `
        ($stateMd -match "(?m)^- $([regex]::Escape($key)):")
}

# ─── .dtd/.gitignore ────────────────────────────────────────────────────────

$gitignoreText = Read-Text ".dtd/.gitignore"

Add-Result "v030d.gitignore.session_sync_md" "gitignore lists session-sync.md" `
    ($gitignoreText -match "(?m)^session-sync\.md\s*$")
Add-Result "v030d.gitignore.session_sync_encrypted" "gitignore lists session-sync.encrypted" `
    ($gitignoreText -match "(?m)^session-sync\.encrypted\s*$")

# ─── build-manifest.ps1 ─────────────────────────────────────────────────────

$builderText = Read-Text "scripts/build-manifest.ps1"

Add-Result "v030d.manifest.reference" "build-manifest includes reference/v030d-cross-machine-session-sync.md" `
    ($builderText -match [regex]::Escape(".dtd/reference/v030d-cross-machine-session-sync.md"))
Add-Result "v030d.manifest.checker" "build-manifest includes scripts/check-v030d.ps1" `
    ($builderText -match [regex]::Escape("scripts/check-v030d.ps1"))

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
Write-Host "V030D_ACCEPTANCE_SUMMARY pass=$pass fail=$fail total=$total"

if ($fail -gt 0) { exit 1 }
exit 0
