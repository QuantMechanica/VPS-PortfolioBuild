param(
    [string]$SignalPath = 'docs\ops\QUA-774_EXTERNAL_UNBLOCK_SIGNAL.json',
    [string]$IssueId = 'QUA-774'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$signalFull = Join-Path $repoRoot $SignalPath

if (-not (Test-Path -LiteralPath $signalFull -PathType Leaf)) {
    [pscustomobject]@{
        issue_id = $IssueId
        status = 'waiting_external_signal'
        signal_path = $SignalPath
        signal_exists = $false
        ready_to_resume = $false
        reason = 'signal_file_missing'
    }
    exit 3
}

$raw = Get-Content -LiteralPath $signalFull -Raw
try {
    $signal = $raw | ConvertFrom-Json
}
catch {
    throw "Invalid JSON in signal file: $signalFull"
}

if ($null -eq $signal.issue_id -or [string]::IsNullOrWhiteSpace([string]$signal.issue_id)) {
    throw "Signal file missing required field: issue_id"
}
if ([string]$signal.issue_id -ne $IssueId) {
    throw "Signal issue mismatch: expected $IssueId got $($signal.issue_id)"
}

$ready = $false
if ($null -ne $signal.ready_to_resume) {
    $ready = [bool]$signal.ready_to_resume
}

$status = if ($ready) { 'ready' } else { 'waiting_external_signal' }
$reason = if ($ready) { 'external_signal_ready' } else { 'ready_to_resume_false' }

[pscustomobject]@{
    issue_id = $IssueId
    status = $status
    signal_path = $SignalPath
    signal_exists = $true
    ready_to_resume = $ready
    reason = $reason
    updated_at_utc = $signal.updated_at_utc
    unblock_owner = $signal.unblock_owner
    unblock_action = $signal.unblock_action
}

if (-not $ready) {
    exit 3
}
