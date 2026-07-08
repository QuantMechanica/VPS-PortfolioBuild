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
$manifest = 'D:\QM\reports\portfolio\portfolio_manifest_current_live_15sleeve_REF_20260708.json'
$stamp    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$date     = (Get-Date).ToString('yyyyMMdd')
$out      = "D:\QM\reports\portfolio\live_burnin\livevsbook_sunday_$date.json"
$log      = 'D:\QM\reports\state\sunday_livevsbook_compare.log'

"$stamp  START sunday live-vs-book compare -> $out" | Out-File -Append -Encoding utf8 $log
& $py $tool --manifest $manifest --generated-at-utc $stamp --out $out 2>&1 |
    Tee-Object -Variable result | Out-File -Append -Encoding utf8 $log
"$stamp  DONE exit=$LASTEXITCODE" | Out-File -Append -Encoding utf8 $log
