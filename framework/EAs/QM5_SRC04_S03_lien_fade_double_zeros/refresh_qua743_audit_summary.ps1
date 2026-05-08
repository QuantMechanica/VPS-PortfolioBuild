param(
    [string]$EaDir = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros"
)

$ErrorActionPreference = "Stop"

$log = Join-Path $EaDir "QUA-743_HEARTBEAT_AUDIT_LOG_2026-05-05.md"
$out = Join-Path $EaDir "QUA-743_HEARTBEAT_AUDIT_SUMMARY_2026-05-05.md"

if (-not (Test-Path -LiteralPath $log -PathType Leaf)) {
    throw "Missing audit log: $log"
}

$lines = Get-Content -LiteralPath $log
$entries = @($lines | Where-Object { $_ -match '^##\s+\d{4}-\d{2}-\d{2}T' })
$passCount = @($lines | Where-Object { $_ -match 'status=PASS' }).Count
$latest = if ($entries.Count -gt 0) { ($entries[-1] -replace '^##\s+','') } else { "n/a" }

$content = @(
    "## QUA-743 Heartbeat Audit Summary (2026-05-05)",
    "",
    "- Audit entries: $($entries.Count)",
    "- PASS checks logged: $passCount",
    "- Latest audit timestamp (UTC): $latest",
    "- Source log: QUA-743_HEARTBEAT_AUDIT_LOG_2026-05-05.md"
)

Set-Content -LiteralPath $out -Value $content -Encoding UTF8
Write-Output "audit_summary_refreshed=$out"
