param(
    [string]$SignalPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json',
    [string]$ChildPayloadPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json',
    [string]$EscalationPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_ESCALATION_2026-05-08.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$signalFull = Join-Path $repoRoot $SignalPath
$childFull = Join-Path $repoRoot $ChildPayloadPath
$escalationFull = Join-Path $repoRoot $EscalationPath

foreach ($p in @($signalFull, $childFull, $escalationFull)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        Write-Host "critical: missing artifact: $p"
        exit 2
    }
}

$signal = Get-Content -LiteralPath $signalFull -Raw | ConvertFrom-Json
$child = Get-Content -LiteralPath $childFull -Raw | ConvertFrom-Json
$esc = Get-Content -LiteralPath $escalationFull -Raw

if ([string]$signal.issue_id -ne 'QUA-774') {
    Write-Host 'critical: signal issue_id mismatch'
    exit 2
}
if ([string]$child.parent_issue_id -ne 'QUA-774') {
    Write-Host 'critical: child payload parent_issue_id mismatch'
    exit 2
}
if ($null -eq $child.child_issue_recommendation.external_signal_update) {
    Write-Host 'critical: missing external_signal_update section'
    exit 2
}
if (-not $esc.Contains('QUA-774_EXTERNAL_UNBLOCK_CHILD_PAYLOAD_2026-05-08.json')) {
    Write-Host 'critical: escalation note missing child payload reference'
    exit 2
}
if (-not $esc.Contains('ready_to_resume=true')) {
    Write-Host 'critical: escalation note missing resume contract'
    exit 2
}

[pscustomobject]@{
    status = 'ok'
    issue_id = 'QUA-774'
    signal_ready_to_resume = [bool]$signal.ready_to_resume
    child_payload = $ChildPayloadPath
    escalation_note = $EscalationPath
}
