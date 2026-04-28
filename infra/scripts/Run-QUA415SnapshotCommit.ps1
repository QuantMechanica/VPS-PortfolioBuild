param([string]$RepoRoot = "C:\QM\repo")

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$snap = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "infra/scripts/Run-QUA415BlockedHeartbeat.ps1")
$file = ($snap | Select-Object -Last 1).Trim()
if (-not (Test-Path $file)) { throw "Snapshot file missing: $file" }

Push-Location $RepoRoot
try {
    git add -- "$file"
    git commit -m "docs(ops): add QUA-415 co-owner monitor snapshot (safe helper)"
} finally {
    Pop-Location
}

Write-Output $file