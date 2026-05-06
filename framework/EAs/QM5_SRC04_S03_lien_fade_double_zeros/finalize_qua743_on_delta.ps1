$ErrorActionPreference = "Stop"

$eaDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$deltaChecker = Join-Path $eaDir "check_qua743_signal_delta.ps1"
$finalizer = Join-Path $eaDir "finalize_qua743_if_ready.ps1"

if (-not (Test-Path -LiteralPath $deltaChecker)) {
    Write-Output "run_status=ERROR"
    Write-Output "reason=missing_delta_checker"
    exit 0
}
if (-not (Test-Path -LiteralPath $finalizer)) {
    Write-Output "run_status=ERROR"
    Write-Output "reason=missing_finalizer"
    exit 0
}

$kv = @{}
$deltaOut = & $deltaChecker
foreach ($line in $deltaOut) {
    if ($line -match "^(?<k>[^=]+)=(?<v>.*)$") {
        $kv[$matches.k] = $matches.v
    }
}

Write-Output ("pipeline_signal=" + $kv["pipeline_signal"])
Write-Output ("ceo_signal=" + $kv["ceo_signal"])
Write-Output ("signal_delta=" + $kv["signal_delta"])
Write-Output ("should_finalize=" + $kv["should_finalize"])

if ($kv["should_finalize"] -ne "TRUE") {
    Write-Output "run_status=SKIP"
    Write-Output "reason=no_semantic_delta_or_incomplete_signals"
    exit 0
}

& $finalizer
