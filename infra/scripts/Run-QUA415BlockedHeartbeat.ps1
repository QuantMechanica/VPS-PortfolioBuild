param(
    [string]$RepoRoot = "C:\QM\repo"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
$target = Join-Path $RepoRoot ("docs/ops/QUA-415_COOWNER_MONITOR_{0}.json" -f $stamp)

$raw = & powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "infra/scripts/Test-QUA415CoOwnerCloseout.ps1") 2>&1
$payload = ($raw | Out-String).Trim()
Set-Content -Path $target -Value $payload -NoNewline

Write-Output $target