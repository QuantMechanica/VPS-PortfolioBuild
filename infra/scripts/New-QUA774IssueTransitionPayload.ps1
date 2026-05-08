param(
    [string]$BlockerStatusPath = 'docs\ops\QUA-774_BLOCKER_STATUS_2026-05-08.json',
    [string]$OutJson = 'docs\ops\QUA-774_ISSUE_TRANSITION_PAYLOAD_2026-05-08.json',
    [string]$OutCommentMd = 'docs\ops\QUA-774_BLOCKED_COMMENT_2026-05-08.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$statusFull = Join-Path $repoRoot $BlockerStatusPath
$outJsonFull = Join-Path $repoRoot $OutJson
$outCommentFull = Join-Path $repoRoot $OutCommentMd

if (-not (Test-Path -LiteralPath $statusFull -PathType Leaf)) {
    throw "Blocker status missing: $statusFull"
}

$status = Get-Content -LiteralPath $statusFull -Raw -Encoding UTF8 | ConvertFrom-Json

$gateStatus = [string]$status.gate.status
$targetState = if ($gateStatus -eq 'ready') { 'in_review' } else { 'blocked' }
$stateReason = if ($gateStatus -eq 'ready') { 'reopened' } else { 'not_planned' }

$flags = @($status.gate.failure_flags | ForEach-Object { [string]$_ })
$missingTerminals = @($status.gate.missing_terminals | ForEach-Object { [string]$_ })
$missingTimeframes = @($status.gate.missing_timeframes | ForEach-Object { [string]$_ })

$commentLines = @(
    "QUA-774 blocker refresh:",
    "- gate.status: $gateStatus",
    "- verdict: $($status.source_evidence.verdict)",
    "- failure_flags: $($flags -join ';')",
    "- missing_terminals: $($missingTerminals -join ',')",
    "- missing_timeframes: $($missingTimeframes -join ',')",
    "- unblock_owner: $($status.unblock.owner)",
    "- unblock_action: $($status.unblock.required_action -join ' | ')",
    "- evidence: $($status.source_evidence.file_name)"
)
$comment = $commentLines -join "`n"

$payload = [ordered]@{
    issue_id = 'QUA-774'
    generated_at_utc = (Get-Date).ToUniversalTime().ToString('o')
    transition = [ordered]@{
        state = $targetState
        state_reason = $stateReason
    }
    comment = $comment
    resume = $false
    source = [ordered]@{
        blocker_status = $statusFull
        evidence_file_name = [string]$status.source_evidence.file_name
    }
}

foreach ($target in @($outJsonFull, $outCommentFull)) {
    $dir = Split-Path -Parent $target
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outJsonFull -Encoding UTF8
Set-Content -LiteralPath $outCommentFull -Value ($comment + "`n") -Encoding UTF8

$payload
