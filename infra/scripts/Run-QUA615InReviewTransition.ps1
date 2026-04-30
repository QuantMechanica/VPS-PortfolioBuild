[CmdletBinding()]
param(
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3100/api" }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { "" }),
    [string]$IssueId = "QUA-615",
    [string]$Status = "in_review",
    [string]$Comment = "QUA-615 DevOps scope is complete and ready for review. Evidence is recorded under infra/reports/*. See qua615_transition_recommendation_2026-05-01.md and qua615_done_candidate_status_2026-05-01.md.",
    [string]$PaperclipRunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { "" }),
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-ApiRoot {
    param([Parameter(Mandatory = $true)][string]$Base)
    $trimmed = $Base.TrimEnd("/")
    if ($trimmed -match "/api$") { return $trimmed }
    return "$trimmed/api"
}

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "PAPERCLIP_API_KEY missing. Refusing to continue."
}

$apiRoot = Normalize-ApiRoot -Base $ApiBaseUrl
$uri = "$apiRoot/issues/$IssueId"
$payload = [ordered]@{
    status = $Status
    comment = $Comment
}

if (-not $Apply.IsPresent) {
    [pscustomobject]@{
        preview = $true
        method = "PATCH"
        uri = $uri
        payload = $payload
        required_headers = @(
            "Authorization: Bearer ***",
            "X-Paperclip-Run-Id: <run-id>"
        )
    } | ConvertTo-Json -Depth 6
    exit 0
}

$runId = if (-not [string]::IsNullOrWhiteSpace($PaperclipRunId)) { $PaperclipRunId } else { [guid]::NewGuid().ToString() }
$headers = @{
    Authorization = "Bearer $ApiKey"
    "X-Paperclip-Run-Id" = $runId
}

$body = $payload | ConvertTo-Json -Depth 6
$result = Invoke-RestMethod -Method PATCH -Uri $uri -Headers $headers -ContentType "application/json" -Body $body

[pscustomobject]@{
    applied = $true
    uri = $uri
    issue_id = $IssueId
    status = $Status
    run_id = $runId
    response_issue_id = $result.id
} | ConvertTo-Json -Depth 6
