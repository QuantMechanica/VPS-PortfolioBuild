param(
    [string]$PackageCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockPackage.ps1',
    [string]$SignalCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockSignal.ps1',
    [string]$HandoffCacheCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockHandoffCache.ps1',
    [string]$StatusTaskCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockStatusTask.ps1',
    [string]$StatusSnapshotScript = 'infra\scripts\Write-QUA774ExternalUnblockStatusSnapshot.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

$checks = @(
    [pscustomobject]@{ name = 'package_check'; script = $PackageCheckScript; allow_exit_codes = @(0) }
    [pscustomobject]@{ name = 'signal_check'; script = $SignalCheckScript; allow_exit_codes = @(0,3) }
    [pscustomobject]@{ name = 'handoff_cache_check'; script = $HandoffCacheCheckScript; allow_exit_codes = @(0) }
    [pscustomobject]@{ name = 'status_task_check'; script = $StatusTaskCheckScript; allow_exit_codes = @(0) }
    [pscustomobject]@{ name = 'status_snapshot_write'; script = $StatusSnapshotScript; allow_exit_codes = @(0) }
)

$results = @()
$criticalFailures = @()

foreach ($check in $checks) {
    $full = Join-Path $repoRoot $check.script
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $criticalFailures += "$($check.name):script_missing"
        $results += [pscustomobject]@{
            name = $check.name
            script = $check.script
            exit_code = $null
            status = 'critical'
            reason = 'script_missing'
        }
        continue
    }

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $full 2>&1
    $exitCode = [int]$LASTEXITCODE
    $allowed = @($check.allow_exit_codes) -contains $exitCode
    $status = if ($allowed) { 'ok' } else { 'critical' }
    if (-not $allowed) {
        $criticalFailures += "$($check.name):exit_$exitCode"
    }

    $results += [pscustomobject]@{
        name = $check.name
        script = $check.script
        exit_code = $exitCode
        status = $status
        output = $output
    }
}

$suiteStatus = if ($criticalFailures.Count -eq 0) { 'ok' } else { 'critical' }

$summary = [pscustomobject]@{
    issue_id = 'QUA-774'
    status = $suiteStatus
    checks = $results
    critical_failures = $criticalFailures
}

$summary

if ($suiteStatus -ne 'ok') {
    exit 2
}
