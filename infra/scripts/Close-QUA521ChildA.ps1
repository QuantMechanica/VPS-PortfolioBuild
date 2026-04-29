[CmdletBinding()]
param(
    [string]$ApiBase = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { 'http://127.0.0.1:3100' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [string]$CompanyId = $(if ($env:PAPERCLIP_COMPANY_ID) { $env:PAPERCLIP_COMPANY_ID } else { '' }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { 'manual-qua521-closeout' }),
    [string]$IssueIdentifier = 'QUA-521',
    [string]$IssueTitleNeedle = 'Child A',
    [string]$OutPath = 'C:\QM\logs\infra\health\qua521_closeout_result.json',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw 'Missing ApiKey/PAPERCLIP_API_KEY.' }
if ([string]::IsNullOrWhiteSpace($CompanyId)) { throw 'Missing CompanyId/PAPERCLIP_COMPANY_ID.' }

$base = $ApiBase.TrimEnd('/')
$headers = @{ Authorization = "Bearer $ApiKey" }

function Ensure-Dir([string]$filePath) {
    $dir = Split-Path -Parent $filePath
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Resolve-TargetIssue {
    $inbox = Invoke-RestMethod -Method Get -Uri "$base/api/agents/me/inbox-lite" -Headers $headers
    $items = @($inbox)

    $exact = @($items | Where-Object {
        ([string]$_.identifier) -eq $IssueIdentifier -and ([string]$_.title) -like "*$IssueTitleNeedle*"
    } | Select-Object -First 1)
    if ($exact.Count -gt 0) { return $exact[0] }

    $fallback = @($items | Where-Object {
        ([string]$_.identifier) -eq $IssueIdentifier
    } | Select-Object -First 1)
    if ($fallback.Count -gt 0) { return $fallback[0] }

    $all = Invoke-RestMethod -Method Get -Uri "$base/api/companies/$CompanyId/issues?limit=1000" -Headers $headers
    $items2 = @($all)
    $match2 = @($items2 | Where-Object {
        ([string]$_.identifier) -eq $IssueIdentifier -and ([string]$_.title) -like "*$IssueTitleNeedle*"
    } | Select-Object -First 1)
    if ($match2.Count -gt 0) { return $match2[0] }

    return $null
}

$target = Resolve-TargetIssue
if ($null -eq $target) {
    $result = [ordered]@{
        ok = $false
        applied = $false
        reason = 'target_issue_not_found'
        issue_identifier = $IssueIdentifier
        issue_title_needle = $IssueTitleNeedle
        generated_at_utc = [datetime]::UtcNow.ToString('o')
    }
    Ensure-Dir $OutPath
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutPath -Encoding UTF8
    Write-Output ($result | ConvertTo-Json -Depth 10)
    exit 2
}

$issueId = [string]$target.id
$comment = @"
Runtime health scan task shipped and verified.

Commits:
- 1b272551ee9ace1b5fca6e0afb12c250a8525762
- 5327e1e99d5ac7ff0dbb42a614616a8358d159c3
- 34cc18884f2f670c117a989286a4f8e1c3fad1ab

Proof artifact:
- docs/ops/QUA-521_RUNTIME_HEALTH_TASK_PROOF_2026-04-29.md

Scheduler:
- QM_RuntimeHealthScan_15min active every 15 minutes
- action runs without -DryRun
- output writes to C:\QM\logs\infra\health\runtime_health_scan_latest.json
"@

$payload = @{ status = 'in_review'; comment = $comment; resume = $false }

if (-not $Apply.IsPresent) {
    $result = [ordered]@{
        ok = $true
        applied = $false
        mode = 'preview'
        issue_id = $issueId
        identifier = [string]$target.identifier
        title = [string]$target.title
        patch_uri = "$base/api/issues/$issueId"
        payload = $payload
        generated_at_utc = [datetime]::UtcNow.ToString('o')
    }
    Ensure-Dir $OutPath
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutPath -Encoding UTF8
    Write-Output ($result | ConvertTo-Json -Depth 10)
    exit 0
}

$mutHeaders = @{ Authorization = "Bearer $ApiKey"; 'X-Paperclip-Run-Id' = $RunId }
$response = Invoke-RestMethod -Method Patch -Uri "$base/api/issues/$issueId" -Headers $mutHeaders -ContentType 'application/json' -Body ($payload | ConvertTo-Json -Depth 10)
$result = [ordered]@{
    ok = $true
    applied = $true
    issue_id = $issueId
    identifier = [string]$target.identifier
    title = [string]$target.title
    new_status = [string]$response.status
    generated_at_utc = [datetime]::UtcNow.ToString('o')
}
Ensure-Dir $OutPath
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutPath -Encoding UTF8
Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
