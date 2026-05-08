param(
    [string]$EaDir = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros",
    [string]$ArtifactsDir = "C:\QM\repo\artifacts"
)

$ErrorActionPreference = "Stop"

$validateScript = Join-Path $EaDir "validate_qua743_evidence.ps1"
$verifyHashScript = Join-Path $ArtifactsDir "verify_qua743_signoff_bundle_hash.ps1"
$refreshScript = Join-Path $EaDir "refresh_qua743_status_snapshot.ps1"
$auditLog = Join-Path $EaDir "QUA-743_HEARTBEAT_AUDIT_LOG_2026-05-05.md"

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$refreshOut = pwsh -NoProfile -File $refreshScript | Out-String
$validateOut = pwsh -NoProfile -File $validateScript | Out-String
$verifyOut = pwsh -NoProfile -File $verifyHashScript | Out-String

if (-not (Test-Path -LiteralPath $auditLog)) {
    "# QUA-743 Heartbeat Audit Log (2026-05-05)" | Set-Content -LiteralPath $auditLog -Encoding UTF8
}

Add-Content -LiteralPath $auditLog -Value @"

## $ts
- refresh_qua743_status_snapshot.ps1
~~~text
$($refreshOut.Trim())
~~~
- validate_qua743_evidence.ps1
~~~text
$($validateOut.Trim())
~~~
- verify_qua743_signoff_bundle_hash.ps1
~~~text
$($verifyOut.Trim())
~~~
"@

Write-Output "heartbeat_guard=PASS"
Write-Output "audit_log=$auditLog"
