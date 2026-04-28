param(
    [string]$PaperclipApiUrl = "http://127.0.0.1:3000",
    [string]$IssueId = "QUA-350",
    [string]$StatusPayloadPath = "docs/ops/QUA-350_ISSUE_STATUS_UPDATE_2026-04-28.json",
    [string]$CommentPath = "docs/ops/QUA-350_ISSUE_COMMENT_2026-04-28.md",
    [string]$RunId = $env:PAPERCLIP_RUN_ID,
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-RepoPath {
    param([string]$PathValue)
    if ([System.IO.Path]::IsPathRooted($PathValue)) { return $PathValue }
    return (Join-Path (Get-Location).Path $PathValue)
}

function Read-JsonFile {
    param([string]$PathValue)
    $raw = Get-Content -LiteralPath $PathValue -Raw
    return ($raw | ConvertFrom-Json)
}

$statusPath = Resolve-RepoPath -PathValue $StatusPayloadPath
$commentPath = Resolve-RepoPath -PathValue $CommentPath

if (-not (Test-Path -LiteralPath $statusPath)) { throw "missing status payload: $statusPath" }
if (-not (Test-Path -LiteralPath $commentPath)) { throw "missing comment file: $commentPath" }
if ([string]::IsNullOrWhiteSpace($RunId)) { throw "RunId is required (set PAPERCLIP_RUN_ID or pass -RunId)." }

$statusObj = Read-JsonFile -PathValue $statusPath
$commentBody = Get-Content -LiteralPath $commentPath -Raw

$headers = @{
    "Content-Type" = "application/json"
    "X-Paperclip-Run-Id" = $RunId
}

$statusPayload = @{
    status = $statusObj.target_status
    resume = $true
}

$commentPayload = @{
    body = $commentBody
    resume = $true
}

$statusUri = "{0}/api/issues/{1}" -f $PaperclipApiUrl.TrimEnd('/'), $IssueId
$commentUri = "{0}/api/issues/{1}/comments" -f $PaperclipApiUrl.TrimEnd('/'), $IssueId

if (-not $Apply) {
    Write-Output "preview_only: true"
    Write-Output "status_uri: $statusUri"
    Write-Output "comment_uri: $commentUri"
    Write-Output "target_status: $($statusObj.target_status)"
    Write-Output "run_id: $RunId"
    exit 0
}

$commentJson = $commentPayload | ConvertTo-Json -Depth 6
$statusJson = $statusPayload | ConvertTo-Json -Depth 6

$commentRes = Invoke-RestMethod -Method Post -Uri $commentUri -Headers $headers -Body $commentJson
$statusRes = Invoke-RestMethod -Method Patch -Uri $statusUri -Headers $headers -Body $statusJson

Write-Output ("comment_posted: {0}" -f [bool]$commentRes)
Write-Output ("status_updated: {0}" -f [bool]$statusRes)
Write-Output ("target_status: {0}" -f $statusObj.target_status)
