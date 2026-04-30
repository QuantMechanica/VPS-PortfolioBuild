[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$OutLinePath = "C:\QM\repo\docs\ops\QUA-346_HEARTBEAT_LINE_2026-04-28.txt"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$refreshScript = Join-Path $RepoRoot "infra\scripts\Run-QUA346StatusRefresh.ps1"
$fingerprintScript = Join-Path $RepoRoot "infra\scripts\Update-QUA346FingerprintState.ps1"
$fingerprintJsonPath = Join-Path $RepoRoot "docs\ops\QUA-346_FINGERPRINT_STATE_2026-04-28.json"

if (-not (Test-Path -LiteralPath $refreshScript -PathType Leaf)) { throw "Missing script: $refreshScript" }
if (-not (Test-Path -LiteralPath $fingerprintScript -PathType Leaf)) { throw "Missing script: $fingerprintScript" }

& powershell -NoProfile -ExecutionPolicy Bypass -File $refreshScript | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File $fingerprintScript | Out-Null

$fp = Get-Content -LiteralPath $fingerprintJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
$stamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")

$line = if ($fp.changed) {
    "[${stamp}] QUA-346 change-detected fingerprint=$($fp.current_fingerprint)"
} else {
    "[${stamp}] QUA-346 no-change heartbeat fingerprint=$($fp.current_fingerprint)"
}

Set-Content -LiteralPath $OutLinePath -Value ($line + "`r`n") -Encoding ascii
Write-Output $line

if ($fp.changed) { exit 0 } else { exit 10 }
