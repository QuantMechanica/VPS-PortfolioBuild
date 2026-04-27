[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$LogPath = 'C:\QM\repo\infra\smoke\qua95_blocker_refresh_task.log',
    [string]$TaskName = 'QM_QUA95_BlockerRefresh',
    [string]$PythonExe = 'python'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$logDir = Split-Path -Parent $LogPath
if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-TaskLog {
    param([string]$Message)
    $ts = Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'
    "[${ts}] $Message" | Out-File -FilePath $LogPath -Append -Encoding utf8
}

$invoke = Join-Path $RepoRoot 'infra\scripts\Invoke-VerifyDisposition.ps1'
$sync = Join-Path $RepoRoot 'infra\scripts\Update-QUA95BlockerStatus.ps1'
$summary = Join-Path $RepoRoot 'infra\scripts\Write-QUA95BlockedSummary.ps1'
$integrity = Join-Path $RepoRoot 'infra\scripts\Test-QUA95HandoffIntegrity.ps1'

foreach ($f in @($invoke, $sync, $summary, $integrity)) {
    if (-not (Test-Path -LiteralPath $f)) {
        throw "Required script missing: $f"
    }
}

Write-TaskLog "start task=$TaskName"
try {
    & $invoke -IssueId 'QUA-95' -Symbol 'XTIUSD.DWX' -PythonExe $PythonExe 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    & $sync 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    & $summary 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    & $integrity 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-TaskLog "success task=$TaskName"
    exit 0
} catch {
    Write-TaskLog "failure task=$TaskName"
    Write-TaskLog ("error=" + $_.Exception.Message)
    exit 1
}
