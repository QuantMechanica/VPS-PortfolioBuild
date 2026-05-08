$ErrorActionPreference = "Stop"

$eaDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$statusJson = Join-Path $eaDir "QUA-743_STATUS_RECOMMENDATION_2026-05-06.json"

if (-not (Test-Path -LiteralPath $statusJson)) {
    Write-Output "closure_gate=BLOCKED"
    Write-Output "reason=missing_status_recommendation"
    exit 0
}

$status = Get-Content -LiteralPath $statusJson -Raw | ConvertFrom-Json
$closeSignals = Get-ChildItem -LiteralPath $eaDir -File |
    Where-Object { $_.Name -match "PIPELINE|CEO|CLOSE|CLOSURE|CANCEL" } |
    Sort-Object LastWriteTime -Descending

$pipelineSignal = $closeSignals | Where-Object { $_.Name -match "PIPELINE" } | Select-Object -First 1
$ceoSignal = $closeSignals | Where-Object { $_.Name -match "CEO" } | Select-Object -First 1

if ($null -ne $pipelineSignal -and $null -ne $ceoSignal) {
    Write-Output "closure_gate=READY"
} else {
    Write-Output "closure_gate=BLOCKED"
}

Write-Output ("recommended_status=" + $status.recommended_status)
Write-Output ("recommended_phase=" + $status.recommended_phase)
Write-Output ("pipeline_signal=" + ($(if ($pipelineSignal) { $pipelineSignal.Name } else { "MISSING" })))
Write-Output ("ceo_signal=" + ($(if ($ceoSignal) { $ceoSignal.Name } else { "MISSING" })))
