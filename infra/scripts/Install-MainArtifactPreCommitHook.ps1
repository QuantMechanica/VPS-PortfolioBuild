[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ProtectedBranch = 'main',
    [switch]$PreviewOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gitDir = Join-Path $RepoRoot '.git'
if (-not (Test-Path -LiteralPath $gitDir)) {
    throw "Not a git repository root: $RepoRoot"
}

$hooksDir = Join-Path $RepoRoot '.githooks'
if (-not (Test-Path -LiteralPath $hooksDir)) {
    New-Item -Path $hooksDir -ItemType Directory -Force | Out-Null
}

$hookPath = Join-Path $hooksDir 'pre-commit'
$hookBody = @"
#!/usr/bin/env bash
set -euo pipefail

if ! command -v pwsh >/dev/null 2>&1; then
  echo "pre-commit: pwsh not found; cannot enforce main artifact policy."
  exit 1
fi

pwsh -NoProfile -ExecutionPolicy Bypass -File "C:/QM/repo/infra/scripts/Assert-CommitAllowlist.ps1" -RepoRoot "C:/QM/repo" -FailOnMainArtifactPaths -ProtectedBranch "$ProtectedBranch"
"@

$existing = ''
if (Test-Path -LiteralPath $hookPath) {
    $existing = Get-Content -LiteralPath $hookPath -Raw
}
$coreHooksPath = (& git -C $RepoRoot config --get core.hooksPath).Trim()
$needsHookWrite = ($existing -ne $hookBody)
$needsHooksPathUpdate = ([string]::IsNullOrWhiteSpace($coreHooksPath) -or ($coreHooksPath -ne '.githooks'))

if ($PreviewOnly.IsPresent) {
    [pscustomobject]@{
        preview = $true
        repo_root = $RepoRoot
        protected_branch = $ProtectedBranch
        hook_path = $hookPath
        hooks_dir = $hooksDir
        would_write_hook = $needsHookWrite
        current_core_hooks_path = $coreHooksPath
        would_update_core_hooks_path = $needsHooksPathUpdate
        target_core_hooks_path = '.githooks'
    } | ConvertTo-Json -Depth 5
    exit 0
}

if ($needsHookWrite) {
    $normalized = $hookBody -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($hookPath, $normalized, $utf8NoBom)
}

if ($needsHooksPathUpdate) {
    & git -C $RepoRoot config core.hooksPath .githooks
}

Write-Host "status=ok hook_path=$hookPath hooks_path=.githooks protected_branch=$ProtectedBranch"
exit 0
