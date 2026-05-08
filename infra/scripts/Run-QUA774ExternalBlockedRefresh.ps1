param(
    [string]$StatusSnapshotScript = 'infra\scripts\Write-QUA774ExternalUnblockStatusSnapshot.ps1',
    [string]$OpsSuiteScript = 'infra\scripts\Test-QUA774ExternalUnblockOpsSuite.ps1',
    [string]$StatusTaskCheckScript = 'infra\scripts\Test-QUA774ExternalUnblockStatusTask.ps1'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$scripts = @(
    [pscustomobject]@{ name = 'status_snapshot'; path = $StatusSnapshotScript }
    [pscustomobject]@{ name = 'ops_suite'; path = $OpsSuiteScript }
    [pscustomobject]@{ name = 'status_task_check'; path = $StatusTaskCheckScript }
)

foreach ($s in $scripts) {
    $full = Join-Path $repoRoot $s.path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "Required script missing: $full"
    }
}

$snapshot = & (Join-Path $repoRoot $StatusSnapshotScript)
$suite = & (Join-Path $repoRoot $OpsSuiteScript)
$task = & (Join-Path $repoRoot $StatusTaskCheckScript)

[pscustomobject]@{
    issue_id = 'QUA-774'
    refreshed_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    status_snapshot = $snapshot
    ops_suite = $suite
    status_task_check = $task
}
