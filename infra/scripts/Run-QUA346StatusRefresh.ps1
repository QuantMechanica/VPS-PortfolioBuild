[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ReadinessJsonPath = "C:\QM\repo\docs\ops\QUA-346_READINESS_CHECK_2026-04-28.json",
    [string]$IssueCommentPath = "C:\QM\repo\docs\ops\QUA-346_ISSUE_COMMENT_2026-04-28.md",
    [string]$OutStatusJsonPath = "C:\QM\repo\docs\ops\QUA-346_STATUS_REFRESH_2026-04-28.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$readinessScript = Join-Path $RepoRoot "infra\scripts\Test-QUA346Readiness.ps1"
$commentScript = Join-Path $RepoRoot "infra\scripts\New-QUA346IssueComment.ps1"

if (-not (Test-Path -LiteralPath $readinessScript -PathType Leaf)) { throw "Missing script: $readinessScript" }
if (-not (Test-Path -LiteralPath $commentScript -PathType Leaf)) { throw "Missing script: $commentScript" }

# 1) Refresh readiness JSON deterministically.
& powershell -NoProfile -ExecutionPolicy Bypass -File $readinessScript -RepoRoot $RepoRoot | Out-File -FilePath $ReadinessJsonPath -Encoding utf8
$readinessExit = $LASTEXITCODE

# 2) Regenerate issue-comment from the refreshed readiness JSON.
& powershell -NoProfile -ExecutionPolicy Bypass -File $commentScript -ReadinessJsonPath $ReadinessJsonPath -OutMarkdownPath $IssueCommentPath | Out-Null
$commentExit = $LASTEXITCODE

$ready = $false
$checkedAt = $null
$blockerFingerprint = "unknown"
try {
    $readyObj = Get-Content -LiteralPath $ReadinessJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
    $ready = [bool]$readyObj.ready
    $checkedAt = $readyObj.checked_at_local
    $cardExists = ($readyObj.checks | Where-Object { $_.name -eq "card_exists" } | Select-Object -First 1).ok
    $sourceExists = ($readyObj.checks | Where-Object { $_.name -eq "source_exists" } | Select-Object -First 1).ok
    $manifestExists = ($readyObj.checks | Where-Object { $_.name -eq "manifest_exists" } | Select-Object -First 1).ok
    $missingFields = @()
    if ($readyObj.PSObject.Properties.Name -contains "manifest_missing_fields" -and $readyObj.manifest_missing_fields) {
        $missingFields = @($readyObj.manifest_missing_fields)
    }
    $fingerprintRaw = "ready=$ready|card=$cardExists|source=$sourceExists|manifest=$manifestExists|missing=" + ($missingFields -join ",")
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($fingerprintRaw))
        $blockerFingerprint = ([BitConverter]::ToString($hashBytes)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}
catch {
    $checkedAt = "parse_failed"
}

$status = [ordered]@{
    issue = "QUA-346"
    generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    readiness_checked_at_local = $checkedAt
    ready = $ready
    blocker_fingerprint_sha256 = $blockerFingerprint
    readiness_exit_code = $readinessExit
    comment_exit_code = $commentExit
    readiness_json = $ReadinessJsonPath
    issue_comment_md = $IssueCommentPath
}

$status | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutStatusJsonPath -Encoding utf8
$status | ConvertTo-Json -Depth 5 | Write-Output

if ($readinessExit -eq 0 -and $commentExit -eq 0) { exit 0 }
if ($commentExit -eq 0) { exit 1 }
exit 2
