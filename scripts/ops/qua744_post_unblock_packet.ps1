param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$IssueId = $(if ($env:PAPERCLIP_TASK_ID) { $env:PAPERCLIP_TASK_ID } else { '' }),
    [string]$ApiBaseUrl = $(if ($env:PAPERCLIP_API_URL) { $env:PAPERCLIP_API_URL } else { '' }),
    [string]$ApiKey = $(if ($env:PAPERCLIP_API_KEY) { $env:PAPERCLIP_API_KEY } else { '' }),
    [string]$RunId = $(if ($env:PAPERCLIP_RUN_ID) { $env:PAPERCLIP_RUN_ID } else { [guid]::NewGuid().ToString() }),
    [string]$CommitHash = '6e917fb0',
    [string]$EvidencePath = 'C:\QM\repo\artifacts\qua-744\p2_matrix_d1_full_missing.json',
    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$stamp = Get-Date -Format 'yyyy-MM-ddTHHmmssK'
$safeStamp = $stamp -replace ':', ''
$docPath = Join-Path $RepoRoot ("docs\ops\QUA-744_UNBLOCK_PACKET_{0}.md" -f $safeStamp)
$payloadPath = Join-Path $RepoRoot ("artifacts\qua-744\QUA-744_unblock_packet_{0}.json" -f $safeStamp)

$comment = @"
QUA-744 DevOps unblock packet (setfile coverage preflight)

- Commit: `$CommitHash`
- Infra change:
  - `infra/scripts/build_p2_dispatch_matrix.py`
  - `infra/README.md`
- Added:
  - `--verify-setfiles` fail-fast preflight for missing setfiles
  - `--missing-setfiles-json` machine-readable coverage artifact
- Verification:
  - 36-symbol D1 probe fails fast with `missing 29 setfile(s)` as expected
- Evidence:
  - `$EvidencePath`

Unblock owner/action:
- OWNER/CTO: decide whether to generate the 29 missing D1 setfiles for QM5_1017 or keep D1 scope intentionally limited and rerun with explicit 7-symbol D1 cohort.
"@

$docDir = Split-Path -Path $docPath -Parent
$payloadDir = Split-Path -Path $payloadPath -Parent
New-Item -ItemType Directory -Path $docDir -Force | Out-Null
New-Item -ItemType Directory -Path $payloadDir -Force | Out-Null
$comment | Set-Content -Path $docPath -Encoding utf8

$payload = [ordered]@{
    issue = 'QUA-744'
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

