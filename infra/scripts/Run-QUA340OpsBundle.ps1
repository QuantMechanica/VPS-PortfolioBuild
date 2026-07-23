[CmdletBinding()]
param(
    [switch]$AttemptQueuedSmoke,
    [int]$EAId,
    [string]$SubGateConfig = "qua340-smoke-010",
    [string]$Version = "v5.0.0-qua340",
    [string]$Symbol = "EURUSD.DWX",
    [string]$Phase = "P2",
    [ValidateSet("T1","T2","T3","T4","T5")]
    [string]$Terminal = "T2",
    [int]$Year = 2022,
    [string]$Period = "M15",
    [int]$Runs = 2,
    [int]$MinTrades = 1,
    [int]$TimeoutSeconds = 900
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$artifactsRoot = Join-Path $repoRoot "artifacts\qua-340-real"
New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null

$ts = [DateTime]::UtcNow.ToString("yyyy-MM-dd_HHmmss")
$readinessOut = Join-Path $artifactsRoot ("qua340_readiness_check_{0}.json" -f $ts)

Write-Output "[QUA340] Running readiness check..."
$readinessOutput = & (Join-Path $PSScriptRoot "Invoke-QUA340ReadinessCheck.ps1") 2>&1
$readinessOutput | Set-Content -LiteralPath $readinessOut -Encoding UTF8
$readinessJson = $readinessOutput | Out-String
Write-Output "[QUA340] readiness_json=$readinessOut"

Write-Output "[QUA340] Refreshing unblock payload..."
& (Join-Path $PSScriptRoot "New-QUA340UnblockPayload.ps1") -ReadinessJson $readinessOut | Out-Null
Write-Output "[QUA340] unblock_payload=docs/ops/QUA-340_UNBLOCK_PAYLOAD_2026-04-28.md"

if ($AttemptQueuedSmoke.IsPresent) {
    if (-not $PSBoundParameters.ContainsKey("EAId")) {
        throw "-EAId is required when -AttemptQueuedSmoke is used."
    }

    Write-Output "[QUA340] Attempting queued smoke run..."
    $stateRoot = Join-Path $artifactsRoot "state"
    $evidenceRoot = Join-Path $artifactsRoot "factory_runs"
    $runOut = Join-Path $artifactsRoot ("run_result_{0}.json" -f $ts)

    & (Join-Path $PSScriptRoot "Invoke-PipelineQueuedSmokeRun.ps1") `
        -StateRoot $stateRoot `
        -EvidenceRoot $evidenceRoot `
        -EAId $EAId `
        -Version $Version `
        -Symbol $Symbol `
        -Phase $Phase `
        -SubGateConfig $SubGateConfig `
        -Terminal $Terminal `
        -Year $Year `
        -Period $Period `
        -Runs $Runs `
        -MinTrades $MinTrades `
        -TimeoutSeconds $TimeoutSeconds `
        -OutJson $runOut

    Write-Output "[QUA340] queued_smoke_result=$runOut"
}

Write-Output "[QUA340] bundle_complete=true"
