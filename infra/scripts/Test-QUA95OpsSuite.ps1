[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$steps = @(
    @{ name = 'ops_bundle_manifest'; script = Join-Path $RepoRoot 'infra\scripts\Test-QUA95OpsBundleManifest.ps1' },
    @{ name = 'handoff_integrity'; script = Join-Path $RepoRoot 'infra\scripts\Test-QUA95HandoffIntegrity.ps1' },
    @{ name = 'transition_payload'; script = Join-Path $RepoRoot 'infra\scripts\Test-QUA95IssueTransitionPayload.ps1' },
    @{ name = 'blocked_invariant'; script = Join-Path $RepoRoot 'infra\scripts\Test-QUA95BlockedInvariant.ps1' },
    @{ name = 'blocked_heartbeat_wrapper'; script = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95BlockedHeartbeatWrapper.ps1' },
    @{ name = 'blocker_task_health'; script = Join-Path $RepoRoot 'infra\monitoring\Test-QUA95BlockerTaskHealth.ps1' }
)

$results = @()
$failed = $false

foreach ($step in $steps) {
    $path = $step.script
    if (-not (Test-Path -LiteralPath $path)) {
        $results += [pscustomobject]@{
            name = $step.name
            status = 'critical'
            exit_code = 127
            output = ("missing_script={0}" -f $path)
        }
        $failed = $true
        continue
    }

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $path 2>&1
    $code = $LASTEXITCODE
    $status = if ($code -eq 0) { 'ok' } else { 'critical' }
    if ($code -ne 0) { $failed = $true }
    $results += [pscustomobject]@{
        name = $step.name
        status = $status
        exit_code = $code
        output = (($out | ForEach-Object { $_.ToString() }) -join '; ')
    }
}

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    overall_status = if ($failed) { 'critical' } else { 'ok' }
    checks = @($results)
}

$json = $summary | ConvertTo-Json -Depth 6
Write-Output $json

if ($failed) { exit 2 }
exit 0
