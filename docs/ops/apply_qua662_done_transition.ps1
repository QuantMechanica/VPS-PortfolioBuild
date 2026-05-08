param(
  [string]$ApiBase = 'http://127.0.0.1:3100',
  [string]$IssueId = '29bb311e-7f6e-4caf-8838-e9a238b1c4a0',
  [string]$CommentPath = 'C:\QM\repo\docs\ops\QUA-662_DONE_COMMENT_DRAFT_2026-05-05T1928+0200.md'
)
$ErrorActionPreference = 'Stop'
$commentBody = Get-Content -Raw -Path $CommentPath
Write-Output "Posting DONE comment to issue $IssueId ..."
Invoke-RestMethod -Method Post -Uri "$ApiBase/api/issues/$IssueId/comments" -ContentType 'text/plain; charset=utf-8' -Body $commentBody | Out-Null
Write-Output "Transitioning issue $IssueId to done ..."
$statePayload = @{ status = 'done' } | ConvertTo-Json
Invoke-RestMethod -Method Patch -Uri "$ApiBase/api/issues/$IssueId" -ContentType 'application/json' -Body $statePayload | Out-Null
Write-Output 'DONE transition applied.'
