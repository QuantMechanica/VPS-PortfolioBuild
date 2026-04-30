[CmdletBinding()]
param(
    [string]$StatusJsonPath = "C:\QM\repo\docs\ops\QUA-346_STATUS_REFRESH_2026-04-28.json",
    [string]$StatePath = "C:\QM\repo\docs\ops\QUA-346_LAST_FINGERPRINT_2026-04-28.txt",
    [string]$OutJsonPath = "C:\QM\repo\docs\ops\QUA-346_FINGERPRINT_STATE_2026-04-28.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $StatusJsonPath -PathType Leaf)) {
    throw "Missing status JSON: $StatusJsonPath"
}

$status = Get-Content -LiteralPath $StatusJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
$current = [string]$status.blocker_fingerprint_sha256
if ([string]::IsNullOrWhiteSpace($current)) {
    throw "Status JSON does not contain blocker_fingerprint_sha256"
}

$previous = $null
if (Test-Path -LiteralPath $StatePath -PathType Leaf) {
    $previous = (Get-Content -LiteralPath $StatePath -Raw).Trim()
}

$changed = $true
if ($previous -and $previous -eq $current) {
    $changed = $false
}

Set-Content -LiteralPath $StatePath -Value ($current + "`r`n") -Encoding ascii

$out = [ordered]@{
    issue = "QUA-346"
    generated_at_local = (Get-Date).ToString("yyyy-MM-ddTHH:mm:sszzz")
    previous_fingerprint = $previous
    current_fingerprint = $current
    changed = $changed
    status_json = $StatusJsonPath
    fingerprint_state_file = $StatePath
}

$out | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutJsonPath -Encoding utf8
$out | ConvertTo-Json -Depth 4 | Write-Output

if ($changed) { exit 0 } else { exit 10 }
