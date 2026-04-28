param(
    [string]$PaperclipApiUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { "http://127.0.0.1:3101" }),
    [string]$IssueId = $(if ($env:PAPERCLIP_TASK_ID) { $env:PAPERCLIP_TASK_ID } else { "QUA-350" }),
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

function Normalize-ApiBaseUrl {
    param([Parameter(Mandatory = $true)] [string]$Url)
    $trimmed = $Url.TrimEnd('/')
    if ($trimmed -match '/api$') { return $trimmed }
    return "$trimmed/api"
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
if (-not [string]::IsNullOrWhiteSpace($env:PAPERCLIP_API_KEY)) {
    $headers["Authorization"] = "Bearer $($env:PAPERCLIP_API_KEY)"
}

$statusPayload = @{
    status = $statusObj.target_status
    resume = $true
}

$apiRoot = Normalize-ApiBaseUrl -Url $PaperclipApiUrl
$statusUri = "{0}/issues/{1}" -f $apiRoot, $IssueId

if (-not $Apply) {
    Write-Output "preview_only: true"
    Write-Output "status_uri: $statusUri"
    Write-Output "target_status: $($statusObj.target_status)"
    Write-Output "run_id: $RunId"
    exit 0
}

$statusPayload.comment = $commentBody
$statusJson = $statusPayload | ConvertTo-Json -Depth 6
$statusRes = Invoke-RestMethod -Method Patch -Uri $statusUri -Headers $headers -Body $statusJson

Write-Output ("status_updated: {0}" -f [bool]$statusRes)
Write-Output ("target_status: {0}" -f $statusObj.target_status)
