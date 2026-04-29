[CmdletBinding()]
param(
    [string]$BaseUrl = "http://localhost:3000",
    [string]$IssueId = "QUA-510",
    [string]$StatusPayloadPath = "C:\QM\repo\docs\ops\QUA-510_ISSUE_STATUS_UPDATE_2026-04-29.json",
    [string]$CommentPath = "C:\QM\repo\docs\ops\QUA-510_DONE_COMMENT_2026-04-29.md",
    [switch]$WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$runId = $env:PAPERCLIP_RUN_ID
if ([string]::IsNullOrWhiteSpace($runId)) {
    $runId = [guid]::NewGuid().ToString()
}

if (-not (Test-Path -LiteralPath $StatusPayloadPath)) {
    throw "Missing status payload: $StatusPayloadPath"
}
if (-not (Test-Path -LiteralPath $CommentPath)) {
    throw "Missing comment file: $CommentPath"
}

$statusDoc = Get-Content -LiteralPath $StatusPayloadPath -Raw | ConvertFrom-Json
$commentBody = Get-Content -LiteralPath $CommentPath -Raw

if ($statusDoc.target_status -ne "done") {
    throw "Status payload target_status must be 'done'."
}

$statusBody = @{
    status = "done"
    comment = @{
        body = $commentBody
    }
} | ConvertTo-Json -Depth 6

$statusUri = "$BaseUrl/api/issues/$IssueId"

if ($WhatIfOnly.IsPresent) {
    [ordered]@{
        check = "qua510_done_transition_preview"
        status_uri = $statusUri
        run_id = $runId
        status_payload_path = $StatusPayloadPath
        comment_path = $CommentPath
    } | ConvertTo-Json -Depth 6
    exit 0
}

$token = $env:PAPERCLIP_API_TOKEN
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Missing PAPERCLIP_API_TOKEN environment variable."
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "X-Paperclip-Run-Id" = $runId
}

$response = Invoke-RestMethod -Method Patch -Uri $statusUri -Headers $headers -Body $statusBody

[ordered]@{
    check = "qua510_done_transition"
    issue_id = $IssueId
    status = "done"
    run_id = $runId
    response = $response
} | ConvertTo-Json -Depth 8
