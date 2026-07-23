[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [switch]$RunLive
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path -LiteralPath $RepoRoot).Path
$artifacts = Join-Path $repo 'artifacts\qua1083_smoke'
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null

$source = Join-Path $artifacts 'source.json'
$queue = Join-Path $artifacts 'queue.json'
$state = Join-Path $artifacts 'state.json'
$runs = Join-Path $artifacts 'runs'
$alarm = Join-Path $artifacts 'idle_alarm.json'
$phaseState = Join-Path $artifacts 'PHASE_STATE.md'
$satOut = Join-Path $artifacts 'saturation_eval.json'

$payload = @{
    approved_waiting_p0 = @(
        @{ ea_id='QM5_1014'; phase='P0'; symbol='EURUSD.DWX'; config_hash='smoke-a' }
    )
    transition_ready = @(
        @{ ea_id='QM5_1017'; phase='P2'; symbol='XAUUSD.DWX'; config_hash='smoke-b' },
        @{ ea_id='QM5_1004'; phase='P3.5'; symbol='US500.DWX'; config_hash='smoke-c' }
    )
}
$payload | ConvertTo-Json -Depth 10 | Set-Content -Path $source -Encoding utf8

Push-Location $repo
$dispatchArgs = @(
    '-m', 'framework.scripts.multi_ea_scheduler',
    '--once',
    '--queue-source', $source,
    '--queue', $queue,
    '--state', $state,
    '--runs-dir', $runs,
    '--idle-alarm', $alarm,
    '--phase-state', $phaseState
)
if (-not $RunLive) {
    $dispatchArgs += '--dry-run'
}
& python @dispatchArgs
if ($LASTEXITCODE -ne 0) { Pop-Location; throw "scheduler failed (exit=$LASTEXITCODE)" }

$satArgs = @(
    'framework/scripts/measure_mt5_saturation.py',
    '--state', $state,
    '--min-ratio', '0.5',
    '--min-minutes', '120',
    '--out', $satOut
)
& python @satArgs
$satExit = $LASTEXITCODE
Pop-Location
if ($satExit -ne 0) { throw "saturation eval failed (exit=$satExit)" }

Write-Output ("smoke.source=" + $source)
Write-Output ("smoke.state=" + $state)
Write-Output ("smoke.phase_state=" + $phaseState)
Write-Output ("smoke.saturation=" + $satOut)
