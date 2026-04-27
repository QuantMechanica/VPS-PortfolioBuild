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
$manifest = Join-Path $RepoRoot 'docs\ops\QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.sha256'

foreach ($f in @($invoke, $sync, $summary, $integrity, $manifest)) {
    if (-not (Test-Path -LiteralPath $f)) {
        throw "Required script missing: $f"
    }
}

Write-TaskLog "start task=$TaskName"
try {
    $global:LASTEXITCODE = 0
    & $invoke -IssueId 'QUA-95' -Symbol 'XTIUSD.DWX' -PythonExe "$PythonExe" 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    Write-TaskLog ("invoke_verify_disposition_exit_code={0}" -f $LASTEXITCODE)

    $global:LASTEXITCODE = 0
    & $sync 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    if (-not $?) { throw ("Step failed: {0}" -f $sync) }

    $global:LASTEXITCODE = 0
    & $summary 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    if (-not $?) { throw ("Step failed: {0}" -f $summary) }

    $hashFiles = @(
        'docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.md',
        'docs/ops/QUA-95_XTIUSD_VERIFIER_HANDOFF_2026-04-27.json',
        'docs/ops/QUA-95_XTIUSD_BLOCKER_STATUS_2026-04-27.json'
    )
    $lines = foreach ($rel in $hashFiles) {
        $full = Join-Path $RepoRoot $rel
        $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $full).Hash.ToLowerInvariant()
        "{0}  {1}" -f $h, $rel
    }
    $lines | Set-Content -LiteralPath $manifest -Encoding ASCII
    Write-TaskLog "manifest_refreshed"

    $global:LASTEXITCODE = 0
    & $integrity 2>&1 | Out-File -FilePath $LogPath -Append -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw ("Step failed with exit code {0}: {1}" -f $LASTEXITCODE, $integrity) }
    Write-TaskLog "success task=$TaskName"
    exit 0
} catch {
    Write-TaskLog "failure task=$TaskName"
    Write-TaskLog ("error=" + $_.Exception.Message)
    exit 1
}
