[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$GatePath = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$BlockerStatusPath = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$TransitionPath = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$OutPath = 'docs\ops\QUA-95_UNBLOCK_READINESS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateFull = Join-Path $RepoRoot $GatePath
$blockerFull = Join-Path $RepoRoot $BlockerStatusPath
$transitionFull = Join-Path $RepoRoot $TransitionPath
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($gateFull, $blockerFull, $transitionFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required artifact missing: $p"
    }
}

$gate = Get-Content -Raw -LiteralPath $gateFull | ConvertFrom-Json
$blocker = Get-Content -Raw -LiteralPath $blockerFull | ConvertFrom-Json
$transition = Get-Content -Raw -LiteralPath $transitionFull | ConvertFrom-Json

$barsGot = if ($null -ne $gate.bars_got) { [int]$gate.bars_got } else { 0 }
$tailShortfall = if ($null -ne $gate.tail_shortfall_seconds) { [double]$gate.tail_shortfall_seconds } else { 0.0 }
$acceptanceMet = [bool]$blocker.acceptance.met
$readyToUnblock = ($acceptanceMet -and $barsGot -gt 0 -and $tailShortfall -le 0.0)

$unmet = @()
if (-not $acceptanceMet) { $unmet += 'acceptance_not_met' }
if ($barsGot -le 0) { $unmet += 'bars_got_zero' }
if ($tailShortfall -gt 0.0) { $unmet += 'tail_not_aligned' }
if ([string]$transition.transition.status -ne 'blocked' -and -not $readyToUnblock) { $unmet += 'transition_state_unexpected_for_blocked' }

$summary = [ordered]@{
    issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    readiness = [ordered]@{
        ready_to_unblock = $readyToUnblock
        unmet_criteria = @($unmet)
    }
    current = [ordered]@{
        recommended_state = $gate.recommended_state
        disposition = $gate.disposition
        bars_got = $barsGot
        tail_shortfall_seconds = $tailShortfall
        last_checked_local = $gate.last_checked_local
    }
    transition = [ordered]@{
        status = $transition.transition.status
        reason = $transition.transition.reason
        disposition = $transition.transition.disposition
    }
    unblock_owners = @($blocker.unblock_owners)
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Output ("wrote={0}" -f $outFull)
Write-Output ("ready_to_unblock={0}" -f $summary.readiness.ready_to_unblock)
Write-Output ("unmet_criteria={0}" -f ($summary.readiness.unmet_criteria -join ','))
exit 0
