# Scheduler wrapper: reclaim abandoned MT5 tester-agent scratch every 10 minutes.
# lock-primary (the agent never reopens bar*.tmp; measured 0 locked at 20/5/2 min),
# 5-minute margin, all ten terminals. Appends a one-line result to the log so the
# disk curve can be audited without manual runs.
$ErrorActionPreference = 'Continue'
$log = 'D:\QM\strategy_farm\logs\agent_temp_reclaim.log'
try { New-Item -ItemType Directory -Force -Path (Split-Path $log) | Out-Null } catch {}
$before = [math]::Round((Get-PSDrive D).Free/1GB,1)
$out = & 'C:\QM\repo\tools\strategy_farm\reclaim_busy_agent_temp.ps1' -MinAgeMinutes 5 -Apply 2>&1 | Out-String
$after = [math]::Round((Get-PSDrive D).Free/1GB,1)
$sum = ($out -split "?
" | Where-Object { $_ -match '^SUMME' }) -join ' '
Add-Content -Path $log -Value ("{0} D_before={1}GB D_after={2}GB {3}" -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK'), $before, $after, $sum) -Encoding UTF8
