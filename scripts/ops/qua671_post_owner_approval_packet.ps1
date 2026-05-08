param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$IssueId = $(if ($env:PAPERCLIP_TASK_ID) { $env:PAPERCLIP_TASK_ID } else { '' }),
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { '' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { [guid]::NewGuid().ToString() }),
    [string]$CommitHash = '5d15db1d',
    [string]$EvidencePath = 'C:\QM\repo\docs\ops\P0-13_T6_MANIFEST_DRYRUN_2026-05-01.md',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyy-MM-ddTHHmmssK'
$safeStamp = $stamp -replace ':', ''
$docPath = Join-Path $RepoRoot ("docs\\ops\\QUA-671_OWNER_APPROVAL_PACKET_{0}.md" -f $safeStamp)
$payloadPath = Join-Path $RepoRoot ("artifacts\\qua-671\\QUA-671_owner_approval_packet_{0}.json" -f $safeStamp)

$comment = @"
QUA-671 OWNER approval packet (P0-13 T6 deploy manifest dry-run)

- Scope guard: DRY-RUN ONLY, no MT5 write, no AutoTrading toggle, no live credentials.
- Commit lineage head: `$CommitHash`
- Evidence:
  - `framework/deploy/manifests/T6_DRYRUN_v0.yaml`
  - `framework/deploy/scripts/manifest_dryrun.ps1`
  - `$EvidencePath`
  - `framework/deploy/manifests/QUA-671_NO_POLLING_UNTIL_OWNER_UNBLOCK.signal`
- Blocked state: `blocked_pending_owner_approval`

Unblock owner/action:
- OWNER: approve P0-13 T6 manifest dry-run evidence and authorize transition to `done`.
"@

$docDir = Split-Path -Path $docPath -Parent
$payloadDir = Split-Path -Path $payloadPath -Parent
New-Item -ItemType Directory -Path $docDir -Force | Out-Null
New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
$comment | Set-Content -Path $docPath -Encoding utf8

$payload = [ordered]@{
    issue = 'QUA-671'
    issue_id = $IssueId
    commit = $CommitHash
    evidence_path = $EvidencePath
    run_id = $RunId
    comment_path = $docPath
    apply = $Apply.IsPresent
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -Path $payloadPath -Encoding utf8

if (-not $Apply.IsPresent) {
    Write-Output ("mode=preview comment_path={0}" -f $docPath)
    Write-Output ("mode=preview payload_path={0}" -f $payloadPath)
    exit 0
}

if ([string]::IsNullOrWhiteSpace($IssueId)) { throw 'IssueId is required when -Apply is set.' }
if ([string]::IsNullOrWhiteSpace($ApiBaseUrl)) { throw 'ApiBaseUrl is required when -Apply is set.' }
if ([string]::IsNullOrWhiteSpace($ApiKey)) { throw 'ApiKey is required when -Apply is set.' }

$base = $ApiBaseUrl.TrimEnd('/')
$uri = "$base/api/issues/$IssueId/comments"
$headers = @{
    Authorization = "Bearer $ApiKey"
    'X-Paperclip-Run-Id' = $RunId
}
$body = @{ body = $comment } | ConvertTo-Json -Depth 4
$response = Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/json' -Body $body

Write-Output ("mode=apply issue_id={0}" -f $IssueId)
Write-Output ("response_id={0}" -f $response.id)
Write-Output ("comment_path={0}" -f $docPath)
Write-Output ("payload_path={0}" -f $payloadPath)
