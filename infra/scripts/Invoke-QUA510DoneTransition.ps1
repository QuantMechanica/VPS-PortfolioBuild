[CmdletBinding()]
param(
    [string]$BaseUrl = "",
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
    comment = $commentBody
} | ConvertTo-Json -Depth 6

if ([string]::IsNullOrWhiteSpace($BaseUrl)) {
    if (-not [string]::IsNullOrWhiteSpace($env:PAPERCLIP_API_URL)) {
        $BaseUrl = $env:PAPERCLIP_API_URL
    } elseif (-not [string]::IsNullOrWhiteSpace($env:PAPERCLIP_RUNTIME_API_URL)) {
        $BaseUrl = $env:PAPERCLIP_RUNTIME_API_URL
    } else {
        $BaseUrl = "http://localhost:3000"
    }
}

$statusUri = "$BaseUrl/api/issues/$IssueId"
$commentUri = "$BaseUrl/api/issues/$IssueId/comments"

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
    $token = $env:PAPERCLIP_API_KEY
}
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Missing PAPERCLIP_API_TOKEN / PAPERCLIP_API_KEY environment variable."
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
    "X-Paperclip-Run-Id" = $runId
}

$statusResponse = Invoke-RestMethod -Method Patch -Uri $statusUri -Headers $headers -Body $statusBody
$commentPayload = @{
    body = $commentBody
    resume = $true
} | ConvertTo-Json -Depth 4
$commentResponse = Invoke-RestMethod -Method Post -Uri $commentUri -Headers $headers -Body $commentPayload

[ordered]@{
    check = "qua510_done_transition"
    issue_id = $IssueId
    status = "done"
    run_id = $runId
    status_response = $statusResponse
    comment_response = $commentResponse
} | ConvertTo-Json -Depth 8
