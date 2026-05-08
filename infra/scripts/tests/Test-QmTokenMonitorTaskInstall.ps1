[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$scriptPath = Join-Path $repoRoot "infra\scripts\Install-QmTokenMonitorTask.ps1"

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "Missing script: $scriptPath"
}

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -RepoRoot $repoRoot `
    -EveryMinutes 60 `
    -PreviewOnly 2>&1

if ($LASTEXITCODE -ne 0) {
    throw "Expected preview success, got exit=$LASTEXITCODE output=$($raw | Out-String)"
}

$obj = ($raw | Out-String) | ConvertFrom-Json -ErrorAction Stop
if ($obj.task_name -ne "QM_TokenBurnWatch_60min") { throw "Unexpected task_name: $($obj.task_name)" }
if ($obj.preview_only -ne $true) { throw "Expected preview_only=true" }
if (-not $obj.action.execute) { throw "Missing action.execute" }
if ($obj.action.argument -notmatch "Invoke-QmTokenMonitor.ps1") { throw "Action argument missing monitor script." }

Write-Host "PASS Test-QmTokenMonitorTaskInstall"

