[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ProtectedBranch = 'main'
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
if ($existing -ne $hookBody) {
    $normalized = $hookBody -replace "`r`n", "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($hookPath, $normalized, $utf8NoBom)
}

$coreHooksPath = (& git -C $RepoRoot config --get core.hooksPath)
if ([string]::IsNullOrWhiteSpace($coreHooksPath) -or ($coreHooksPath.Trim() -ne '.githooks')) {
    & git -C $RepoRoot config core.hooksPath .githooks
}

Write-Host "status=ok hook_path=$hookPath hooks_path=.githooks protected_branch=$ProtectedBranch"
exit 0
