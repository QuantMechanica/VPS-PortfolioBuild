[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$GatePath = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$TransitionPath = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$gateFull = Join-Path $RepoRoot $GatePath
$transitionFull = Join-Path $RepoRoot $TransitionPath

if (-not (Test-Path -LiteralPath $gateFull)) {
    Write-Host ("missing_gate={0}" -f $gateFull)
    exit 2
}
if (-not (Test-Path -LiteralPath $transitionFull)) {
    Write-Host ("missing_transition={0}" -f $transitionFull)
    exit 2
}

$gate = Get-Content -Raw -LiteralPath $gateFull | ConvertFrom-Json
$transition = Get-Content -Raw -LiteralPath $transitionFull | ConvertFrom-Json

$barsGot = 0
if ($null -ne $gate.bars_got) {
    $barsGot = [int]$gate.bars_got
}

$gateState = [string]$gate.recommended_state
$gateDisposition = [string]$gate.disposition
$transitionStatus = [string]$transition.transition.status
$transitionDisposition = [string]$transition.transition.disposition
$transitionReason = [string]$transition.transition.reason

if ($barsGot -le 0) {
    $ok = (
        $gateState -eq 'blocked' -and
        $gateDisposition -eq 'defer' -and
        $transitionStatus -eq 'blocked' -and
        $transitionDisposition -eq 'defer'
    )

    if (-not $ok) {
        Write-Host ("status=critical bars_got={0} gate_state={1} gate_disposition={2} transition_status={3} transition_disposition={4} transition_reason={5}" -f `
            $barsGot, $gateState, $gateDisposition, $transitionStatus, $transitionDisposition, $transitionReason)
        exit 1
    }

    Write-Host ("status=ok bars_got={0} gate_state={1} disposition={2} transition_status={3} transition_disposition={4} transition_reason={5}" -f `
        $barsGot, $gateState, $gateDisposition, $transitionStatus, $transitionDisposition, $transitionReason)
    exit 0
}

Write-Host ("status=ok bars_got={0} invariant=not_applicable gate_state={1} transition_status={2}" -f `
    $barsGot, $gateState, $transitionStatus)
exit 0
