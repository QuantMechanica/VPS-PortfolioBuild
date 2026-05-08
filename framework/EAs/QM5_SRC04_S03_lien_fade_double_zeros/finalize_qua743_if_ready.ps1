$ErrorActionPreference = "Stop"

$eaDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$checker = Join-Path $eaDir "check_qua743_closure_gate.ps1"

if (-not (Test-Path -LiteralPath $checker)) {
    Write-Output "finalize_status=BLOCKED"
    Write-Output "reason=missing_checker"
    exit 0
}

$result = & $checker
$kv = @{}
foreach ($line in $result) {
    if ($line -match "^(?<k>[^=]+)=(?<v>.*)$") {
        $kv[$matches.k] = $matches.v
    }
}

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
if ($kv["closure_gate"] -eq "READY") {
    $p = Join-Path $eaDir ("QUA-743_CLOSED_" + $ts + ".md")
    @(
        "# QUA-743 Closed",
        "",
        "- timestamp_utc: " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"),
        "- closure_gate: READY",
        "- recommended_status: " + $kv["recommended_status"],
        "- recommended_phase: " + $kv["recommended_phase"],
        "- pipeline_signal: " + $kv["pipeline_signal"],
        "- ceo_signal: " + $kv["ceo_signal"]
    ) | Set-Content -LiteralPath $p -Encoding UTF8

    Write-Output "finalize_status=CLOSED"
    Write-Output ("close_note=" + $p)
    exit 0
}

$blocked = Join-Path $eaDir ("QUA-743_FINALIZE_BLOCKED_" + $ts + ".md")
@(
    "# QUA-743 Finalize Attempt Blocked",
    "",
    "- timestamp_utc: " + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"),
    "- closure_gate: " + $kv["closure_gate"],
    "- recommended_status: " + $kv["recommended_status"],
    "- recommended_phase: " + $kv["recommended_phase"],
    "- pipeline_signal: " + $kv["pipeline_signal"],
    "- ceo_signal: " + $kv["ceo_signal"]
) | Set-Content -LiteralPath $blocked -Encoding UTF8

Write-Output "finalize_status=BLOCKED"
Write-Output ("blocked_note=" + $blocked)
