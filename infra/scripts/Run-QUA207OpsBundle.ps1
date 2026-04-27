[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$HeartbeatScript = 'infra\scripts\Run-QUA207RuntimeCompletionHeartbeat.ps1',
    [string]$IssueCommentScript = 'infra\scripts\New-QUA207IssueComment.ps1',
    [string]$BlockedSnapshotScript = 'infra\scripts\New-QUA207BlockedOnVerifierSnapshot.ps1',
    [string]$OutPath = 'docs\ops\QUA-207_OPS_BUNDLE_2026-04-27.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$heartbeatFull = Join-Path $RepoRoot $HeartbeatScript
$commentFull = Join-Path $RepoRoot $IssueCommentScript
$blockedFull = Join-Path $RepoRoot $BlockedSnapshotScript
$outFull = Join-Path $RepoRoot $OutPath

foreach ($p in @($heartbeatFull, $commentFull, $blockedFull)) {
    if (-not (Test-Path -LiteralPath $p)) {
        throw "Required script missing: $p"
    }
}

function Run-Step {
    param(
        [string]$ScriptPath,
        [string[]]$Args = @()
    )
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Args 2>&1
    $code = $LASTEXITCODE
    return [pscustomobject]@{
        script = $ScriptPath
        exit_code = $code
        output = @($output | ForEach-Object { $_.ToString() })
    }
}

$start = Get-Date
$heartbeat = Run-Step -ScriptPath $heartbeatFull -Args @('-RepoRoot', $RepoRoot)
$issueComment = Run-Step -ScriptPath $commentFull -Args @('-RepoRoot', $RepoRoot)
$blockedSnapshot = Run-Step -ScriptPath $blockedFull -Args @('-RepoRoot', $RepoRoot)
$end = Get-Date

$status = if ($heartbeat.exit_code -eq 0 -and $issueComment.exit_code -eq 0 -and $blockedSnapshot.exit_code -eq 0) { 'ok' } else { 'critical' }

$payload = [ordered]@{
    issue = 'QUA-207'
    generated_at_local = $end.ToString('yyyy-MM-ddTHH:mm:ssK')
    status = $status
    duration_seconds = [Math]::Round(($end - $start).TotalSeconds, 3)
    steps = @($heartbeat, $issueComment, $blockedSnapshot)
    artifacts = [ordered]@{
        heartbeat_json = 'docs/ops/QUA-207_RUNTIME_HEARTBEAT_2026-04-27.json'
        transition_payload_json = 'docs/ops/QUA-207_ISSUE_TRANSITION_PAYLOAD_2026-04-27.json'
        issue_comment_md = 'docs/ops/QUA-207_ISSUE_COMMENT_2026-04-27.md'
        blocked_snapshot_json = 'docs/ops/QUA-207_BLOCKED_ON_VERIFIER_2026-04-27.json'
    }
}

$outDir = Split-Path -Parent $outFull
if (-not [string]::IsNullOrWhiteSpace($outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $outFull -Encoding UTF8
Write-Host ("wrote={0}" -f $outFull)
Write-Host ("status={0}" -f $status)

if ($status -eq 'ok') { exit 0 } else { exit 2 }
