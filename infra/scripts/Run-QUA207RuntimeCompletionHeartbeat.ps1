[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$TransitionPayloadScript = 'infra\scripts\New-QUA207IssueTransitionPayload.ps1',
    [string]$CompletionCheckScript = 'infra\scripts\Test-QUA207RuntimeRestoreCompletion.ps1',
    [string]$OutPath = 'docs\ops\QUA-207_RUNTIME_HEARTBEAT_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$transitionScriptFull = Join-Path $RepoRoot $TransitionPayloadScript
$checkScriptFull = Join-Path $RepoRoot $CompletionCheckScript
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($transitionScriptFull, $checkScriptFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required script missing: $p"
    }
}

function Run-Step {
    param(
        [string]$ScriptPath,
        [string[]]$Args = @()
    )
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args 2>&1
    $code = $LASTEXITCODE
    return [pscustomobject]@{
        script = $ScriptPath
        exit_code = $code
        output = @($output | ForEach-Object { $_.ToString() })
    }
}

$start = Get-Date
$transitionStep = Run-Step -ScriptPath $transitionScriptFull -Args @('-RepoRoot', $RepoRoot)
$checkStep = Run-Step -ScriptPath $checkScriptFull -Args @('-RepoRoot', $RepoRoot)
$end = Get-Date

$status = if ($transitionStep.exit_code -eq 0 -and $checkStep.exit_code -eq 0) { 'ok' } else { 'critical' }
$payload = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = $end.ToString('yyyy-MM-ddTHH:mm:ssK')
    status = $status
    duration_seconds = [Math]::Round(($end - $start).TotalSeconds, 3)
    steps = @($transitionStep, $checkStep)
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("status={0}" -f $status)

if ($status -eq 'ok') { exit 0 } else { exit 2 }
