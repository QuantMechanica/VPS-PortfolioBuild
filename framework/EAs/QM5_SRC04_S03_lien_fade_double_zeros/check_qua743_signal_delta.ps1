$ErrorActionPreference = "Stop"

$eaDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statePath = Join-Path $eaDir "QUA-743_SIGNAL_STATE.json"

$pipeline = Get-ChildItem -LiteralPath $eaDir -File |
    Where-Object { $_.Name -match "PIPELINE" } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

$ceo = Get-ChildItem -LiteralPath $eaDir -File |
    Where-Object { $_.Name -match "CEO" } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1

$currentPipeline = if ($pipeline) { $pipeline.Name } else { "MISSING" }
$currentCeo = if ($ceo) { $ceo.Name } else { "MISSING" }

$previousPipeline = "MISSING"
$previousCeo = "MISSING"
if (Test-Path -LiteralPath $statePath) {
    $prev = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if ($prev.pipeline_signal) { $previousPipeline = [string]$prev.pipeline_signal }
    if ($prev.ceo_signal) { $previousCeo = [string]$prev.ceo_signal }
}

$changed = ($currentPipeline -ne $previousPipeline) -or ($currentCeo -ne $previousCeo)
$shouldFinalize = $changed -and ($currentPipeline -ne "MISSING") -and ($currentCeo -ne "MISSING")

$stateObj = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    pipeline_signal = $currentPipeline
    ceo_signal = $currentCeo
}
$stateObj | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding UTF8

Write-Output ("pipeline_signal=" + $currentPipeline)
Write-Output ("ceo_signal=" + $currentCeo)
Write-Output ("previous_pipeline_signal=" + $previousPipeline)
Write-Output ("previous_ceo_signal=" + $previousCeo)
Write-Output ("signal_delta=" + ($(if ($changed) { "TRUE" } else { "FALSE" })))
Write-Output ("should_finalize=" + ($(if ($shouldFinalize) { "TRUE" } else { "FALSE" })))
