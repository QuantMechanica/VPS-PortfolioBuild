# run_live_burnin.ps1 — R-064-6 live-forward burn-in evidence from the T_Live per-EA logs.
#
# Read-only. Extracts the real live book equity curve (EQUITY_SNAPSHOT events) from the
# T_Live terminal-local logs and runs the burn-in verdict against the deployed manifest.
# NEVER touches T_Live trading state. Scheduled daily (EQUITY_SNAPSHOT is emitted once/day
# at the broker-day rollover). Scripts have no clock, so we pass the UTC timestamp in.
#
# SP-A1/SP-A2 (2026-08-22): manifest path + deployment epoch are read from the
# authenticated runtime deploy pointer (D:\QM\reports\state\live_deployment_pointer.json)
# instead of a hardcoded path here -- the prior hardcoded 13-sleeve June draft made every
# burn-in report compare against a book that had not been live for weeks (default epoch
# 1970, 0 observed days, verdict UNKNOWN). No silent fallback: if the pointer is
# missing/malformed/lacks manifest_path or deployment_epoch_utc, this script fails closed
# (non-zero exit) rather than guessing a manifest.

$ErrorActionPreference = 'Stop'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$Pointer = 'D:\QM\reports\state\live_deployment_pointer.json'

if (-not (Test-Path $Pointer)) {
    Write-Error "run_live_burnin: runtime deploy pointer missing ($Pointer) -- refusing to guess a manifest."
    exit 2
}
# Extract manifest_path / deployment_epoch_utc as raw strings via regex, NOT
# ConvertFrom-Json property access -- PowerShell auto-coerces ISO-8601-looking
# JSON string values into [datetime] and then re-renders them in the current
# culture's date format on interpolation (e.g. "07/24/2026 08:42:00"), which
# Python's datetime.fromisoformat() cannot parse. Regex keeps the literal bytes.
$pointerRaw = Get-Content -Raw -Path $Pointer
$Manifest = $null
$DeploymentEpoch = $null
if ($pointerRaw -match '"manifest_path"\s*:\s*"([^"]*)"') {
    $Manifest = $Matches[1] -replace '\\\\', '\'
}
if ($pointerRaw -match '"deployment_epoch_utc"\s*:\s*"([^"]*)"') {
    $DeploymentEpoch = $Matches[1]
}
if ([string]::IsNullOrWhiteSpace($Manifest) -or [string]::IsNullOrWhiteSpace($DeploymentEpoch)) {
    Write-Error "run_live_burnin: pointer at $Pointer is missing manifest_path or deployment_epoch_utc -- refusing to guess."
    exit 2
}
if (-not (Test-Path $Manifest)) {
    Write-Error "run_live_burnin: pointer-declared manifest not found on disk: $Manifest"
    exit 2
}

# SUM-basis 42d MaxDD MC reference (correct DD basis; regenerate via
# make_live_burnin_mc_reference.py when the book changes). Falls back to the manifest
# weighted-avg placeholder inside the adapter if this file is absent.
$McRef = 'D:\QM\reports\portfolio\live_burnin\mc_reference_d2c_42d.json'
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

Set-Location 'C:\QM\repo'
$mcArg = @()
if (Test-Path $McRef) { $mcArg = @('--mc-artifact', $McRef) }
& $py -m tools.strategy_farm.portfolio.portfolio_live_forward_from_logs `
    --manifest $Manifest `
    --deployment-epoch $DeploymentEpoch `
    --require-signed `
    @mcArg `
    --generated-at-utc $ts
exit $LASTEXITCODE
