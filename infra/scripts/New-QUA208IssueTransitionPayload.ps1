[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$DirectEvidenceJson = 'lessons-learned\evidence\2026-04-27_qua95_xtiusd_direct_verify_rerun.json',
    [string]$BlockerJson = 'docs\ops\QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json',
    [string]$GateDecisionJson = 'docs\ops\QUA-95_GATE_DECISION_2026-04-27.json',
    [string]$CloseoutDoc = 'docs\ops\QUA-208_DEVOPS004_UNBLOCK_CLOSEOUT_2026-04-27.md',
    [string]$OutPath = 'docs\ops\QUA-208_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$directPath = Join-Path $RepoRoot $DirectEvidenceJson
$blockerPath = Join-Path $RepoRoot $BlockerJson
$gatePath = Join-Path $RepoRoot $GateDecisionJson
$closeoutPath = Join-Path $RepoRoot $CloseoutDoc
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($directPath, $blockerPath, $gatePath, $closeoutPath)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required input missing: $p"
    }
}

$direct = Get-Content -Raw -LiteralPath $directPath | ConvertFrom-Json
$blocker = Get-Content -Raw -LiteralPath $blockerPath | ConvertFrom-Json
$gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json

$barsGot = [int]$direct.bars_chunked
if ($barsGot -le 0) {
    $barsGot = [int]$direct.bars_one_shot
}

$tailDeltaMs = [int]$direct.tail_delta_ms
$tailTolMs = [int]$direct.tail_tolerance_ms
$tailAligned = ([Math]::Abs($tailDeltaMs) -le $tailTolMs)

$status = if ([bool]$blocker.acceptance.met -and $barsGot -gt 0 -and $tailAligned) { 'in_review' } else { 'blocked' }
$reason = if ($status -eq 'in_review') { 'devops_unblock_complete' } else { 'acceptance_not_met' }
$nextAction = if ($status -eq 'in_review') {
    'Apply transition payload and move issue to in_review for final owner sign-off.'
} else {
    'Keep issue blocked until bars_got > 0 and tail_delta_ms is within tolerance.'
}

$payload = [ordered]@{
    issue = 'QUA-208'
    parent_issue = 'QUA-95'
    generated_at_local = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    source = [ordered]@{
        direct_verify_evidence_json = $DirectEvidenceJson
        blocker_status_json = $BlockerJson
        gate_decision_json = $GateDecisionJson
        closeout_doc_md = $CloseoutDoc
    }
    recommended_transition = [ordered]@{
        status = $status
        reason = $reason
        resume = $true
    }
    acceptance = [ordered]@{
        met = [bool]$blocker.acceptance.met
        bars_got = $barsGot
        tail_delta_ms = $tailDeltaMs
        tail_tolerance_ms = $tailTolMs
        tail_aligned = $tailAligned
        verdict = [string]$direct.verdict
    }
    blocker_state = [ordered]@{
        disposition = [string]$blocker.current_observed.disposition
        blocker_recommended_state = [string]$blocker.recommended_state
        gate_recommended_state = [string]$gate.recommended_state
    }
    handoff = [ordered]@{
        next_owner = 'verifier_implementation_owner'
        next_action = $nextAction
    }
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("recommended_status={0}" -f $status)
Write-Host ("bars_got={0}" -f $barsGot)
Write-Host ("tail_delta_ms={0}" -f $tailDeltaMs)
exit 0
