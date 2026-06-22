# rebuild_ea_metrics.ps1 — force a clean full rebuild of the ea_metrics layer.
#
# ea_metrics normally refreshes itself incrementally via the 5-min pump (§10c) and
# the hourly dashboard render. Use this only for recovery: after a schema change,
# suspected drift, or if the `ea_metrics_fresh` health check warns and an
# incremental build does not resolve it. Safe + idempotent (upsert by work_item_id);
# can be run live.
#
# Docs: docs/ops/EA_METRICS_ARCHIVE_LAYER_2026-06-22.md
[CmdletBinding()]
param(
    [string]$EaId = "QM5_10440"  # EA to spot-check after the rebuild
)

$ErrorActionPreference = "Stop"
$PY = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
$Repo = "C:\QM\repo"
Set-Location $Repo

Write-Host "==> Full rebuild of ea_metrics ..." -ForegroundColor Cyan
& $PY tools/strategy_farm/ea_metrics.py build --full

Write-Host "`n==> Spot-check $EaId ..." -ForegroundColor Cyan
& $PY tools/strategy_farm/ea_metrics.py show --ea $EaId |
    Select-String -Pattern "Q02|Q04|Q07|Q08" | Select-Object -First 12

Write-Host "`n==> ea_metrics_fresh health check ..." -ForegroundColor Cyan
& $PY tools/strategy_farm/farmctl.py health 2>$null |
    & $PY -c "import sys,json; d=json.load(sys.stdin); c=[x for x in d['checks'] if x['name']=='ea_metrics_fresh']; print(c[0]['status'],'-',c[0]['detail']) if c else print('check not registered')"

Write-Host "`nDone. The pump (5min) and render (hourly) keep it fresh from here." -ForegroundColor Green
