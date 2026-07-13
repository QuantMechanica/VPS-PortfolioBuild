<#
  Sunday live-vs-book reconciliation (OWNER request 2026-07-08).
  Compares T_Live live trading against the book (backtest) expectation via the
  read-only live burn-in module, and writes a dated report for the Sunday
  dual-book admission session. Does NOT touch trading state.

  Wired as scheduled task QM_NewBook_LiveVsBook_Sunday (one-time 2026-07-12).
  Re-point --manifest to the deployed book after any new-book deploy.
#>
$ErrorActionPreference = 'Stop'
$py       = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$tool     = 'C:\QM\repo\tools\strategy_farm\portfolio\portfolio_live_forward_from_logs.py'
# Repointed 2026-07-13: DXZ-23 book deployed 2026-07-13 (decisions/2026-07-12_t_live_dxz_23sleeve.md);
# the 23-sleeve manifest is the deployed basis (risk sum 9.75, Sharpe 2.348 / MaxDD 3.32% ref).
$manifest = 'D:\QM\reports\portfolio\portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json'
$stamp    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$date     = (Get-Date).ToString('yyyyMMdd')
$out      = "D:\QM\reports\portfolio\live_burnin\livevsbook_sunday_$date.json"
$log      = 'D:\QM\reports\state\sunday_livevsbook_compare.log'

"$stamp  START sunday live-vs-book compare -> $out" | Out-File -Append -Encoding utf8 $log
# PS 5.1: with ErrorActionPreference=Stop, python's harmless stderr warning
# ("Could not find platform independent libraries") became a terminating
# NativeCommandError via 2>&1 and killed the run right after START.
$ErrorActionPreference = 'Continue'
& $py $tool --manifest $manifest --generated-at-utc $stamp --out $out 2>&1 |
    Tee-Object -Variable result | Out-File -Append -Encoding utf8 $log
"$stamp  DONE exit=$LASTEXITCODE" | Out-File -Append -Encoding utf8 $log
