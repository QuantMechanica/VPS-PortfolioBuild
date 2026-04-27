[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$PayloadJson = 'docs\ops\QUA-208_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json',
    [string]$DirectEvidenceJson = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$GateDecisionJson = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$payloadPath = Join-Path $RepoRoot $PayloadJson
$directPath = Join-Path $RepoRoot $DirectEvidenceJson
$blockerPath = Join-Path $RepoRoot $BlockerJson
$gatePath = Join-Path $RepoRoot $GateDecisionJson

foreach ($p in @($payloadPath, $directPath, $blockerPath, $gatePath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host ("missing_file={0}" -f $p)
        exit 1
    }
}

$payload = Get-Content -Raw -LiteralPath $payloadPath | ConvertFrom-Json
$direct = Get-Content -Raw -LiteralPath $directPath | ConvertFrom-Json
$blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json
$gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json

$expectedBars = [int]$direct.bars_chunked
if ($expectedBars -le 0) {
    $expectedBars = [int]$direct.bars_one_shot
}
$expectedTailDelta = [int]$direct.tail_delta_ms
$expectedTailTol = [int]$direct.tail_tolerance_ms
$expectedTailAligned = ([Math]::Abs($expectedTailDelta) -le $expectedTailTol)
$expectedStatus = if ([bool]$blocker.acceptance.met -and $expectedBars -gt 0 -and $expectedTailAligned) { 'in_review' } else { 'blocked' }

$ok = $true

if ($payload.issue -ne 'QUA-208') {
    Write-Host ("mismatch=issue payload={0} expected=QUA-208" -f $payload.issue)
    $ok = $false
}
if ($payload.parent_issue -ne 'QUA-95') {
    Write-Host ("mismatch=parent_issue payload={0} expected=QUA-95" -f $payload.parent_issue)
    $ok = $false
}
if ($payload.recommended_transition.status -ne $expectedStatus) {
    Write-Host ("mismatch=status payload={0} expected={1}" -f $payload.recommended_transition.status, $expectedStatus)
    $ok = $false
}
if ([int]$payload.acceptance.bars_got -ne $expectedBars) {
    Write-Host ("mismatch=bars_got payload={0} expected={1}" -f $payload.acceptance.bars_got, $expectedBars)
    $ok = $false
}
if ([int]$payload.acceptance.tail_delta_ms -ne $expectedTailDelta) {
    Write-Host ("mismatch=tail_delta_ms payload={0} expected={1}" -f $payload.acceptance.tail_delta_ms, $expectedTailDelta)
    $ok = $false
}
if ([int]$payload.acceptance.tail_tolerance_ms -ne $expectedTailTol) {
    Write-Host ("mismatch=tail_tolerance_ms payload={0} expected={1}" -f $payload.acceptance.tail_tolerance_ms, $expectedTailTol)
    $ok = $false
}
if ([bool]$payload.acceptance.tail_aligned -ne $expectedTailAligned) {
    Write-Host ("mismatch=tail_aligned payload={0} expected={1}" -f $payload.acceptance.tail_aligned, $expectedTailAligned)
    $ok = $false
}
if ([bool]$payload.acceptance.met -ne [bool]$blocker.acceptance.met) {
    Write-Host ("mismatch=acceptance_met payload={0} blocker={1}" -f $payload.acceptance.met, $blocker.acceptance.met)
    $ok = $false
}
if ($payload.blocker_state.disposition -ne $blocker.current_observed.disposition) {
    Write-Host ("mismatch=disposition payload={0} blocker={1}" -f $payload.blocker_state.disposition, $blocker.current_observed.disposition)
    $ok = $false
}
if ($payload.blocker_state.blocker_recommended_state -ne $blocker.recommended_state) {
    Write-Host ("mismatch=blocker_recommended_state payload={0} blocker={1}" -f $payload.blocker_state.blocker_recommended_state, $blocker.recommended_state)
    $ok = $false
}
if ($payload.blocker_state.gate_recommended_state -ne $gate.recommended_state) {
    Write-Host ("mismatch=gate_recommended_state payload={0} gate={1}" -f $payload.blocker_state.gate_recommended_state, $gate.recommended_state)
    $ok = $false
}

if (-not $ok) {
    Write-Host "status=critical check=qua208_issue_transition_payload"
    exit 1
}

Write-Host ("status=ok check=qua208_issue_transition_payload status_value={0}" -f $payload.recommended_transition.status)
exit 0
