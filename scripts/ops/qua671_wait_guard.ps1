param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$IssueId = $(if ($env:PAPERCLIP_TASK_ID) { $env:PAPERCLIP_TASK_ID } else { '' }),
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { '' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [int]$QuietHours = 24
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($IssueId)) { throw 'IssueId is required.' }
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) { throw 'ApiBaseUrl is required.' }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw 'ApiKey is required.' }

$handoffPath = Join-Path $RepoRoot 'framework\deploy\manifests\QUA-671_OWNER_HANDOFF_2026-05-01.json'
$handoff = Get-Content -Raw -Path $handoffPath | ConvertFrom-Json
$lastHeartbeatUtc = [datetime]::Parse($handoff.last_heartbeat_utc).ToUniversalTime()
$nowUtc = (Get-Date).ToUniversalTime()
$hoursSince = ($nowUtc - $lastHeartbeatUtc).TotalHours

$base = $ApiBaseUrl.TrimEnd('/')
$headers = @{ Authorization = "Bearer $ApiKey" }
$issue = Invoke-RestMethod -Method Get -Uri "$base/api/issues/$IssueId" -Headers $headers
$comments = Invoke-RestMethod -Method Get -Uri "$base/api/issues/$IssueId/comments" -Headers $headers

$pendingComments = if ($issue.PSObject.Properties.Name -contains 'pendingComments' -and $null -ne $issue.pendingComments) { [int]$issue.pendingComments } else { 0 }
$latestCommentId = if ($comments -and $comments.Count -gt 0) { [string]$comments[-1].id } else { '' }

$decision = if ($issue.status -eq 'in_progress' -and $pendingComments -eq 0 -and $hoursSince -lt $QuietHours) { 'DEFER_NO_POLLING' } else { 'CHECK_REQUIRED' }

$stamp = $nowUtc.ToString('yyyy-MM-ddTHHmmssZ')
$outPath = Join-Path $RepoRoot ("docs\\ops\\QUA-671_WAIT_GUARD_{0}.json" -f $stamp)
$out = [ordered]@{
    captured_utc = $nowUtc.ToString('yyyy-MM-ddTHH:mm:ssZ')
    issue_id = $IssueId
    issue_status = $issue.status
    pending_comments = $pendingComments
    latest_comment_id = $latestCommentId
    hours_since_last_heartbeat = [math]::Round($hoursSince, 3)
    quiet_hours_threshold = $QuietHours
    unblock_owner = 'OWNER'
    unblock_action = 'Approve P0-13 T6 manifest dry-run evidence and authorize transition to done.'
    decision = $decision
}
($out | ConvertTo-Json -Depth 6) + "`n" | Set-Content -Encoding utf8 $outPath

Write-Output ("decision={0}" -f $decision)
Write-Output ("snapshot={0}" -f $outPath)
