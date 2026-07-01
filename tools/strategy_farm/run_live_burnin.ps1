# run_live_burnin.ps1 — R-064-6 live-forward burn-in evidence from the T_Live per-EA logs.
#
# Read-only. Extracts the real live book equity curve (EQUITY_SNAPSHOT events) from the
# T_Live terminal-local logs and runs the burn-in verdict against the deployed manifest.
# NEVER touches T_Live trading state. Scheduled daily (EQUITY_SNAPSHOT is emitted once/day
# at the broker-day rollover). Scripts have no clock, so we pass the UTC timestamp in.
#
# When the live book grows (a new D-generation manifest), update $Manifest below.

$ErrorActionPreference = 'Stop'
$py = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$Manifest = 'C:\QM\deploy\GoLive_D2c_13sleeve_2026-06-28\manifest_d2c_13sleeve_2026-06-28.json'
$ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

Set-Location 'C:\QM\repo'
& $py -m tools.strategy_farm.portfolio.portfolio_live_forward_from_logs `
    --manifest $Manifest `
    --generated-at-utc $ts
exit $LASTEXITCODE
