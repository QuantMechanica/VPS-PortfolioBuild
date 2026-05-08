param(
    [string]$EaDir = "C:\QM\repo\framework\EAs\QM5_SRC04_S03_lien_fade_double_zeros"
)

$ErrorActionPreference = "Stop"

$guard = Join-Path $EaDir "run_qua743_heartbeat_guard.ps1"
$summary = Join-Path $EaDir "refresh_qua743_audit_summary.ps1"
$waitNote = Join-Path $EaDir "QUA-743_WAITING_SIGNOFF_2026-05-05.md"

pwsh -NoProfile -File $guard
pwsh -NoProfile -File $summary

if (Test-Path -LiteralPath $waitNote -PathType Leaf) {
    $ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $lines = Get-Content -LiteralPath $waitNote
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -like "Last heartbeat maintenance (UTC):*") {
            $lines[$i] = "Last heartbeat maintenance (UTC): $ts"
            $updated = $true
            break
        }
    }
    if (-not $updated) {
        $lines += ""
        $lines += "Last heartbeat maintenance (UTC): $ts"
    }
    Set-Content -LiteralPath $waitNote -Value $lines -Encoding UTF8
    Write-Output "wait_note_updated=$waitNote"
}

Write-Output "maintenance=PASS"
