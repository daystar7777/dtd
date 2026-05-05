# DTD MANIFEST.json builder (v0.2.0d)
#
# Generates MANIFEST.json at repo root containing:
#   version + per-file sha256 + size_bytes
# for every tracked file shipped in a release.
#
# Usage:
#   pwsh ./scripts/build-manifest.ps1 -Version v0.2.0d
#
# Run at tag time. Output: ./MANIFEST.json (overwrites).

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Version,
    [string]$RepoRoot = (Resolve-Path "$PSScriptRoot/..").Path
)

$ErrorActionPreference = "Stop"

# Files to include in manifest (tracked release deliverables).
# Excludes: AIMemory/, .git/, log/, snapshots/, attempts/, runs/, tmp/, workers.md (gitignored)
$IncludedPaths = @(
    "dtd.md",
    "README.md",
    "README.ko.md",
    "README.ja.md",
    "prompt.md",
    "test-scenarios.md",
    "examples/quickstart.md",
    "examples/quickstart.ko.md",
    "examples/quickstart.ja.md",
    "examples/user-journeys.md",
    "examples/plan-001.md",
    "examples/run-001-summary.md",
    ".dtd/instructions.md",
    ".dtd/config.md",
    ".dtd/state.md",
    ".dtd/workers.example.md",
    ".dtd/worker-system.md",
    ".dtd/PROJECT.md",
    ".dtd/notepad.md",
    ".dtd/resources.md",
    ".dtd/steering.md",
    ".dtd/phase-history.md",
    ".dtd/.gitignore",
    ".dtd/.env.example",
    ".dtd/skills/code-write.md",
    ".dtd/skills/review.md",
    ".dtd/skills/planning.md",
    ".dtd/help/index.md",
    ".dtd/help/start.md",
    ".dtd/help/observe.md",
    ".dtd/help/recover.md",
    ".dtd/help/workers.md",
    ".dtd/help/stuck.md",
    ".dtd/help/update.md",
    ".dtd/help/plan.md",
    ".dtd/help/run.md",
    ".dtd/help/steer.md"
)

$files = @()
foreach ($relPath in $IncludedPaths) {
    $absPath = Join-Path $RepoRoot $relPath
    if (-not (Test-Path $absPath)) {
        Write-Warning "MISSING: $relPath"
        continue
    }
    $bytes = [IO.File]::ReadAllBytes($absPath)
    $sha = [Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    $sha256Hex = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
    $files += [ordered]@{
        path = $relPath -replace '\\', '/'
        sha256 = $sha256Hex
        size_bytes = $bytes.Length
    }
}

$manifest = [ordered]@{
    version = $Version
    tagged_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    manifest_format_version = 1
    files = $files
}

$json = $manifest | ConvertTo-Json -Depth 10
$outPath = Join-Path $RepoRoot "MANIFEST.json"
$json | Out-File -FilePath $outPath -Encoding utf8 -NoNewline

Write-Host "MANIFEST.json written: $outPath ($($files.Count) files)"
