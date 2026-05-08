[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$auditScript = Join-Path $repoRoot "infra\scripts\Invoke-InfraAudit.ps1"

if (-not (Test-Path -LiteralPath $auditScript)) {
    throw "Missing script: $auditScript"
}

$text = Get-Content -Raw -LiteralPath $auditScript

if ($text -notmatch [regex]::Escape('$QmTokenMonitorScript')) {
    throw "Missing QmTokenMonitorScript parameter wiring."
}
if ($text -notmatch "qm_token_monitor") {
    throw "Missing qm_token_monitor check name."
}
if ($text -notmatch [regex]::Escape('Invoke-QmTokenMonitor.ps1')) {
    throw "Missing Invoke-QmTokenMonitor.ps1 invocation wiring."
}

Write-Host "PASS Test-InfraAuditQmTokenMonitorWiring"

