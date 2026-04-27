[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PayloadJson = 'docs\ops\QUA-95_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$GateDecisionJson = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$payloadPath = Join-Path $RepoRoot $PayloadJson
$gatePath = Join-Path $RepoRoot $GateDecisionJson
$blockerPath = Join-Path $RepoRoot $BlockerJson

foreach ($p in @($payloadPath, $gatePath, $blockerPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host ("missing_file={0}" -f $p)
        exit 1
    }
}

$payload = Get-Content -Raw -LiteralPath $payloadPath | ConvertFrom-Json
$gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
$blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json

$expectedStatus = if ($gate.recommended_state -eq 'blocked') { 'blocked' } else { 'in_progress' }
$ok = $true

if ($payload.issue -ne $blocker.issue) {
    Write-Host ("mismatch=issue payload={0} blocker={1}" -f $payload.issue, $blocker.issue)
    $ok = $false
}
if ($payload.transition.status -ne $expectedStatus) {
    Write-Host ("mismatch=status payload={0} expected={1}" -f $payload.transition.status, $expectedStatus)
    $ok = $false
}
if ([double]$payload.transition.tail_shortfall_seconds -ne [double]$gate.tail_shortfall_seconds) {
    Write-Host ("mismatch=tail_shortfall_seconds payload={0} gate={1}" -f $payload.transition.tail_shortfall_seconds, $gate.tail_shortfall_seconds)
    $ok = $false
}
if ([int]$payload.transition.bars_got -ne [int]$gate.bars_got) {
    Write-Host ("mismatch=bars_got payload={0} gate={1}" -f $payload.transition.bars_got, $gate.bars_got)
    $ok = $false
}
if ($payload.transition.disposition -ne $gate.disposition) {
    Write-Host ("mismatch=disposition payload={0} gate={1}" -f $payload.transition.disposition, $gate.disposition)
    $ok = $false
}
if ($payload.transition.last_checked_local -ne $gate.last_checked_local) {
    Write-Host ("mismatch=last_checked_local payload={0} gate={1}" -f $payload.transition.last_checked_local, $gate.last_checked_local)
    $ok = $false
}

$ownersCountPayload = @($payload.unblock_owners).Count
$ownersCountBlocker = @($blocker.unblock_owners).Count
if ($ownersCountPayload -ne $ownersCountBlocker) {
    Write-Host ("mismatch=unblock_owners_count payload={0} blocker={1}" -f $ownersCountPayload, $ownersCountBlocker)
    $ok = $false
}

if (-not $ok) {
    Write-Host "status=critical check=qua95_issue_transition_payload"
    exit 1
}

Write-Host ("status=ok check=qua95_issue_transition_payload status_value={0}" -f $payload.transition.status)
exit 0
