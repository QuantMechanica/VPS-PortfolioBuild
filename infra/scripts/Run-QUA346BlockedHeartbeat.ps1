[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$ReadinessOutJson = "C:\QM\repo\docs\ops\QUA-346_READINESS_CHECK_2026-04-28.json",
    [string]$IssueCommentOutMd = "C:\QM\repo\docs\ops\QUA-346_ISSUE_COMMENT_2026-04-28.md"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$readinessScript = Join-Path $RepoRoot "infra\scripts\Test-QUA346Readiness.ps1"
$commentScript = Join-Path $RepoRoot "infra\scripts\New-QUA346IssueComment.ps1"

if (-not (Test-Path -LiteralPath $readinessScript -PathType Leaf)) {
    throw "Missing readiness script: $readinessScript"
}
if (-not (Test-Path -LiteralPath $commentScript -PathType Leaf)) {
    throw "Missing issue comment script: $commentScript"
}

$tmpReadiness = [System.IO.Path]::GetTempFileName()
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $readinessScript -RepoRoot $RepoRoot > $tmpReadiness
    $readinessExit = $LASTEXITCODE
    $readinessText = Get-Content -LiteralPath $tmpReadiness -Raw
}
finally {
    if (Test-Path -LiteralPath $tmpReadiness) {
        Remove-Item -LiteralPath $tmpReadiness -Force -ErrorAction SilentlyContinue
    }
}

# Persist readiness JSON even when readiness script exits non-zero (not-ready state).
Set-Content -LiteralPath $ReadinessOutJson -Value $readinessText -Encoding UTF8

& powershell -NoProfile -ExecutionPolicy Bypass -File $commentScript -ReadinessJsonPath $ReadinessOutJson -OutMarkdownPath $IssueCommentOutMd | Out-Null
$commentExit = $LASTEXITCODE

$status = if ($readinessExit -eq 0 -and $commentExit -eq 0) { "ready" } elseif ($commentExit -eq 0) { "blocked" } else { "error" }

$summary = [ordered]@{
    issue = "QUA-346"
    checked_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    status = $status
    readiness_exit_code = $readinessExit
    comment_exit_code = $commentExit
    readiness_json = $ReadinessOutJson
    issue_comment_md = $IssueCommentOutMd
}

$summary | ConvertTo-Json -Depth 4 | Write-Output

if ($status -eq "error") { exit 2 }
if ($status -eq "blocked") { exit 1 }
exit 0
