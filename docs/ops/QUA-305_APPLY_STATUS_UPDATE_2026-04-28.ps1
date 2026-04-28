param(
    [string]$ApiBase = "http://localhost:3100",
    [string]$IssueId = "QUA-305",
    [string]$PayloadPath = "C:\QM\worktrees\cto\docs\ops\QUA-305_ISSUE_STATUS_UPDATE_2026-04-28.json",
    [string]$BearerToken = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PayloadPath)) {
    throw "Payload file not found: $PayloadPath"
}

$payload = Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json
$body = @{
    status = [string]$payload.status_update.status
    statusReason = [string]$payload.status_update.reason
    note = "Development blocked on CTO review-only gate; see docs/ops/QUA-305_ISSUE_STATUS_UPDATE_2026-04-28.json"
} | ConvertTo-Json -Depth 5

$headers = @{
    "Content-Type" = "application/json"
}
if (-not [string]::IsNullOrWhiteSpace($BearerToken)) {
    $headers["Authorization"] = "Bearer $BearerToken"
}

$url = "$ApiBase/api/issues/$IssueId"
Write-Host "PATCH $url"
$resp = Invoke-RestMethod -Method Patch -Uri $url -Headers $headers -Body $body
$resp | ConvertTo-Json -Depth 10

