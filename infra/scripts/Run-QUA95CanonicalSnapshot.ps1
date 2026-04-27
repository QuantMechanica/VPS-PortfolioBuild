[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$heartbeatScript = Join-Path $RepoRoot 'infra\scripts\Invoke-QUA95BlockedHeartbeat.ps1'
$bundleUpdateScript = Join-Path $RepoRoot 'infra\scripts\Update-QUA95OpsBundleManifest.ps1'
$bundleTestScript = Join-Path $RepoRoot 'infra\scripts\Test-QUA95OpsBundleManifest.ps1'

foreach ($path in @($heartbeatScript, $bundleUpdateScript, $bundleTestScript)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Required script missing: $path"
    }
}

$heartbeatOut = & $heartbeatScript 2>&1
$heartbeatCode = $LASTEXITCODE
($heartbeatOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($heartbeatCode -ne 0) {
    throw ("Heartbeat failed: exit_code={0}" -f $heartbeatCode)
}

$bundleUpdateOut = & $bundleUpdateScript 2>&1
$bundleUpdateCode = $LASTEXITCODE
($bundleUpdateOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($bundleUpdateCode -ne 0) {
    throw ("Ops bundle update failed: exit_code={0}" -f $bundleUpdateCode)
}

$bundleTestOut = & $bundleTestScript 2>&1
$bundleTestCode = $LASTEXITCODE
($bundleTestOut | ForEach-Object { $_.ToString() }) | Write-Output
if ($bundleTestCode -ne 0) {
    throw ("Ops bundle verification failed: exit_code={0}" -f $bundleTestCode)
}

Write-Output "status=ok flow=qua95_canonical_snapshot"
exit 0
