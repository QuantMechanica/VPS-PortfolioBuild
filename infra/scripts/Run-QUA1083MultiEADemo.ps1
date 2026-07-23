[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$RunLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$artifacts = Join-Path $repo 'artifacts\qua1083_demo'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

$sourcePath = Join-Path $artifacts 'multi_ea_queue_source_demo.json'
$queuePath = Join-Path $artifacts 'multi_ea_queue_demo.json'
$statePath = Join-Path $artifacts 'multi_ea_state_demo.json'
$runsDir = Join-Path $artifacts 'runs'
$idleAlarmPath = Join-Path $artifacts 'idle_alarm_demo.json'
$phaseStatePath = Join-Path $artifacts 'PHASE_STATE_demo.md'

$payload = @{
    approved_waiting_p0 = @(
        @{ ea_id = 'QM5_1014'; phase = 'P0'; symbol = 'EURUSD.DWX'; config_hash = 'demo-p0-a' }
    )
    transition_ready = @(
        @{ ea_id = 'QM5_1017'; phase = 'P2'; symbol = 'XAUUSD.DWX'; config_hash = 'demo-p2-b' }
        @{ ea_id = 'QM5_1004'; phase = 'P3.5'; symbol = 'US500.DWX'; config_hash = 'demo-p35-c' }
    )
}
$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $sourcePath -Encoding utf8

$moduleScript = Join-Path $repo 'framework\scripts\multi_ea_scheduler.py'
if (-not (Test-Path -LiteralPath $moduleScript -PathType Leaf)) {
    throw "Scheduler script not found: $moduleScript"
}

$args = @(
    '-m', 'framework.scripts.multi_ea_scheduler',
    '--once',
    '--queue-source', $sourcePath,
    '--queue', $queuePath,
    '--state', $statePath,
    '--runs-dir', $runsDir,
    '--idle-alarm', $idleAlarmPath,
    '--phase-state', $phaseStatePath
)
if (-not $RunLive) {
    $args += '--dry-run'
}

Push-Location $repo
& python @args
$exitCode = $LASTEXITCODE
Pop-Location
if ($exitCode -ne 0) {
    throw "multi_ea_scheduler.py failed (exit=$exitCode)"
}

Write-Output ("demo.source=" + $sourcePath)
Write-Output ("demo.state=" + $statePath)
Write-Output ("demo.phase_state=" + $phaseStatePath)
