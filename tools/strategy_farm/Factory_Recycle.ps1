# =====================================================================
#  QuantMechanica - Factory preventive recycle (SYSTEM, daily)
#  Reclaims leaked SESSION-GLOBAL process-init resources (desktop heap /
#  CSRSS / USER handles) that accumulate from the high-churn pwsh+terminal64
#  spawn/kill cycle and eventually cause a 0xC0000142 launch_fault wedge
#  (root cause of the 2026-06-24 ~6h incident). Performs the same
#  OFF/ON-equivalent reset the watchdog uses for healed_full_reset, but
#  PROACTIVELY, before the leak exhausts the session.
#
#  Adaptive + safe:
#    - Runs only if the factory is meant to be ON (OWNER intent).
#    - NEVER touches T_Live (Hard Rule: live trading = OWNER+Claude only).
#    - Skips if a reset/recycle already happened < MinHoursSinceReset ago
#      (shares watchdog_realstall.json last_reset) so it never piles onto a
#      watchdog realstall reset and never recycles a freshly-reset factory.
#    - SYSTEM principal: respawns workers INTO the interactive session via
#      run_in_console_session.ps1 (WTSQueryUserToken + CreateProcessAsUser),
#      exactly like the watchdog. A daily trigger + the 18h guard => ~1
#      recycle/day unless a natural reset already covered it.
# =====================================================================
param([int]$MinHoursSinceReset = 18)
$ErrorActionPreference = 'Continue'
$repo    = 'C:\QM\repo'
$py      = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$rsState = 'D:\QM\reports\state\watchdog_realstall.json'
$log     = 'D:\QM\reports\state\factory_recycle.log'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

function Write-RecycleLog([string]$m) {
    try {
        $line = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') + ' ' + $m
        Add-Content -Path $log -Value $line -Encoding UTF8
        Write-Output $line
    } catch {}
}

# 1. OWNER intent: factory meant to be ON?
$factoryEnabled = $false
foreach ($t in $QM_FACTORY_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') { $factoryEnabled = $true }
}
if (-not $factoryEnabled) { Write-RecycleLog 'SKIP: factory OFF (OWNER intent)'; return }

# 2. T_Live guard (Hard Rule): never recycle while live trading runs.
if (@(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match 'T_Live' }).Count -gt 0) {
    Write-RecycleLog 'SKIP: a T_Live terminal is running (Hard Rule)'; return
}

# 2b. SYSTEM-only HARD GUARD. The respawn uses run_in_console_session.ps1
#     (WTSQueryUserToken + CreateProcessAsUser) which only SYSTEM (SeTcb) can do.
#     Run as anything else (e.g. a manual admin shell) and the kill-all succeeds but
#     the respawn yields 0 workers -> a self-inflicted outage. Refuse the destructive
#     path unless we are SYSTEM. (The scheduled task runs as SYSTEM, so this passes
#     there; a manual invocation safely no-ops.)
if (-not [Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) {
    Write-RecycleLog 'SKIP: not running as SYSTEM (respawn needs WTSQueryUserToken) - refusing destructive recycle'; return
}

# 3. Adaptive guard — FAIL-SAFE: only recycle when we can POSITIVELY confirm the last
#    reset/recycle was >= MinHoursSinceReset ago. ANY uncertainty (unreadable state, a
#    partial read racing the watchdog's 5-min write, a parse failure, no prior stamp)
#    -> SKIP. Recycling is the disruptive action; never do it on a guess. Parse the
#    stored 'Z' stamp as UTC (same convention as factory_watchdog ConvertFrom-UtcStamp).
$nowDt = (Get-Date).ToUniversalTime()
$confirmedOld = $false
try {
    $rst = Get-Content $rsState -Raw -ErrorAction Stop | ConvertFrom-Json
    if ($rst.last_reset) {
        $last = [datetime]::ParseExact($rst.last_reset, 'yyyy-MM-ddTHH:mm:ssZ',
            [Globalization.CultureInfo]::InvariantCulture,
            ([Globalization.DateTimeStyles]::AssumeUniversal -bor [Globalization.DateTimeStyles]::AdjustToUniversal))
        $hrs = [math]::Round(($nowDt - $last).TotalHours, 1)
        if ($hrs -ge $MinHoursSinceReset) { $confirmedOld = $true }
        else { Write-RecycleLog "SKIP: last reset $($rst.last_reset) was ${hrs}h ago (< ${MinHoursSinceReset}h)"; return }
    } else {
        # No prior stamp: establish the baseline and skip — never recycle on first sight.
        @{ pending_since = $null; last_reset = $nowDt.ToString('yyyy-MM-ddTHH:mm:ssZ') } |
            ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8
        Write-RecycleLog 'SKIP: no prior reset stamp - wrote baseline, will recycle next cycle if still up'; return
    }
} catch {
    Write-RecycleLog "SKIP: cannot read/parse reset state (fail-safe) - $($_.Exception.Message)"; return
}
if (-not $confirmedOld) { Write-RecycleLog 'SKIP: could not confirm reset age (fail-safe)'; return }

# 4. OFF/ON-equivalent reset (mirror of factory_watchdog healed_full_reset).
Write-RecycleLog 'RECYCLE: start preventive OFF/ON-equivalent reset'
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
try {
    foreach ($t in $QM_FACTORY_TASKS) { Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    foreach ($d in $daemons) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
    # Kill ONLY factory T1-T10 terminals (path-matched). NEVER T_Live / T_Export.
    @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }) |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-Sleep -Seconds 10   # settle so the OS reclaims the leaked session handles
    foreach ($t in $QM_FACTORY_TASKS) { Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null }
    & $py (Join-Path $repo 'tools\strategy_farm\farmctl.py') repair 2>$null | Out-Null
    $launcher = Join-Path $repo 'tools\strategy_farm\run_in_console_session.ps1'
    $swArgs = '"' + (Join-Path $repo 'tools\strategy_farm\start_terminal_workers.py') + '" --repo-root "' + $repo + '" --farm-root "D:\QM\strategy_farm" --dedupe'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Exe $py -Arguments $swArgs -WorkDir $repo 2>$null | Out-Null
    Start-Sleep -Seconds 12
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction SilentlyContinue
    # Share the reset timestamp with the watchdog cooldown so neither double-fires.
    @{ pending_since = $null; last_reset = $nowDt.ToString('yyyy-MM-ddTHH:mm:ssZ') } |
        ConvertTo-Json -Compress | Set-Content -Path $rsState -Encoding UTF8
    $after = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
               Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
    Write-RecycleLog "RECYCLE: done -> after=$after workers"
} catch {
    Write-RecycleLog "RECYCLE: ERROR $($_.Exception.Message)"
}
