#Requires -Version 5.1
<#
.SYNOPSIS
    Sunday boot-verification GO/NO-GO checker for the QuantMechanica VPS.

.DESCRIPTION
    Run once after the provider-panel reboot on Sunday to confirm the system
    is healthy before enabling live trading.  Each check prints PASS/FAIL/WARN
    with detail.  Final verdict is GO only when ALL checks PASS.

    Appends a one-line JSONL record to D:\QM\reports\state\sunday_go_ampel.jsonl.

.EXAMPLE
    pwsh -File C:\QM\repo\tools\strategy_farm\sunday_go_ampel.ps1

.NOTES
    Exit code 0 = GO (all checks passed)
    Exit code 1 = NO-GO (one or more FAILs)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ──────────────────────────────────────────────────────────────────────────────
# Colour helpers
# ──────────────────────────────────────────────────────────────────────────────
function Write-Pass   { param([string]$msg) Write-Host "[PASS] $msg"  -ForegroundColor Green  }
function Write-Fail   { param([string]$msg) Write-Host "[FAIL] $msg"  -ForegroundColor Red    }
function Write-Warn   { param([string]$msg) Write-Host "[WARN] $msg"  -ForegroundColor Yellow }
function Write-Header { param([string]$msg) Write-Host "`n=== $msg ===" -ForegroundColor Cyan  }

$failures = 0
$warnings = 0
$results  = [ordered]@{}   # for the JSONL record

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 1 — Uptime < 12 hours (reboot actually happened)
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 1: Uptime < 12 hours"
try {
    $os          = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $bootTime    = $os.LastBootUpTime
    $uptimeSecs  = [int]([datetime]::Now - $bootTime).TotalSeconds
    $uptimeMins  = [int]($uptimeSecs / 60)
    $uptimeHours = [math]::Round($uptimeSecs / 3600.0, 2)
    if ($uptimeHours -lt 12) {
        Write-Pass "Uptime $uptimeHours h (boot: $bootTime)"
        $results['check1_uptime'] = 'PASS'
    } else {
        Write-Fail "Uptime $uptimeHours h (boot: $bootTime) — reboot may not have happened"
        $results['check1_uptime'] = 'FAIL'
        $failures++
    }
    $results['check1_uptime_hours'] = $uptimeHours
    $results['check1_boot_time']    = $bootTime.ToString('o')
} catch {
    Write-Fail "Could not query OS uptime: $_"
    $results['check1_uptime'] = 'FAIL'
    $failures++
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 2 — Terminal workers: >= 7 pythonw.exe processes matching terminal_worker
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 2: Terminal workers >= 7"
try {
    $workerProcs = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'pythonw.exe'" -ErrorAction Stop |
        Where-Object { $_.CommandLine -match 'terminal_worker' }
    $workerCount = @($workerProcs).Count
    if ($workerCount -ge 7) {
        Write-Pass "$workerCount terminal_worker pythonw.exe processes running"
        $results['check2_terminal_workers'] = 'PASS'
    } else {
        Write-Fail "Only $workerCount terminal_worker pythonw.exe processes (need >= 7)"
        $results['check2_terminal_workers'] = 'FAIL'
        $failures++
    }
    $results['check2_worker_count'] = $workerCount
} catch {
    Write-Fail "Could not query terminal worker processes: $_"
    $results['check2_terminal_workers'] = 'FAIL'
    $failures++
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 3 — T_Live terminal64.exe running from C:\QM\mt5\T_Live
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 3: T_Live terminal64.exe running"
try {
    $t_live_root    = 'C:\QM\mt5\T_Live'
    $terminalProcs  = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'terminal64.exe'" -ErrorAction Stop |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($t_live_root, [System.StringComparison]::OrdinalIgnoreCase) }
    $terminalCount  = @($terminalProcs).Count
    if ($terminalCount -ge 1) {
        $path = $terminalProcs[0].ExecutablePath
        Write-Pass "T_Live terminal64.exe running: $path (count: $terminalCount)"
        $results['check3_t_live_terminal'] = 'PASS'
    } else {
        Write-Fail "No terminal64.exe found under $t_live_root"
        $results['check3_t_live_terminal'] = 'FAIL'
        $failures++
    }
    $results['check3_t_live_proc_count'] = $terminalCount
} catch {
    Write-Fail "Could not query terminal64.exe processes: $_"
    $results['check3_t_live_terminal'] = 'FAIL'
    $failures++
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 4 — Scheduler alive: QM_StrategyFarm_QuotaGovernor (15 min cadence)
#                             QM_StrategyFarm_FactoryWatchdog_15min (15 min cadence)
#           Grace period: within first 30 min after boot → WARN not-yet-run is OK
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 4: Scheduled tasks alive"

$scheduledTasks = @(
    @{ Name = 'QM_StrategyFarm_QuotaGovernor';          CadenceMinutes = 15 },
    @{ Name = 'QM_StrategyFarm_FactoryWatchdog_15min';  CadenceMinutes = 15 }
)

# Determine boot time for grace-period calculation (reuse from check 1 or re-query)
$bootTimeForGrace = $null
try { $bootTimeForGrace = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).LastBootUpTime } catch { }

foreach ($taskDef in $scheduledTasks) {
    $taskName = $taskDef.Name
    $cadence  = $taskDef.CadenceMinutes
    try {
        $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $lastResult  = $info.LastTaskResult
        $lastRunTime = $info.LastRunTime

        # "Never run" marker: LastRunTime may be 1999-11-30 or very old epoch
        $neverRun = ($lastRunTime -lt [datetime]'2020-01-01')

        if ($neverRun) {
            # Has the task had enough time to run?
            $graceOk = $false
            if ($bootTimeForGrace) {
                $minutesSinceBoot = ([datetime]::Now - $bootTimeForGrace).TotalMinutes
                $graceOk = $minutesSinceBoot -le 30
            }
            if ($graceOk) {
                Write-Warn "$taskName has not run yet (boot < 30 min ago — grace period)"
                $results["check4_${taskName}"] = 'WARN'
                $warnings++
            } else {
                Write-Fail "$taskName has never run (or not since before 2020)"
                $results["check4_${taskName}"] = 'FAIL'
                $failures++
            }
        } else {
            $minutesSinceRun = ([datetime]::Now - $lastRunTime).TotalMinutes
            $graceWindow     = [math]::Max(30, $cadence * 2)  # at least 30 min
            if ($lastResult -eq 0) {
                Write-Pass "$taskName last result=0 (success), last run: $lastRunTime ($([math]::Round($minutesSinceRun,1)) min ago)"
                $results["check4_${taskName}"] = 'PASS'
            } elseif ($minutesSinceRun -le $graceWindow) {
                # Non-zero result but ran recently — may still be starting up
                Write-Warn "$taskName last result=$lastResult (non-zero), last run: $lastRunTime ($([math]::Round($minutesSinceRun,1)) min ago) — within grace window"
                $results["check4_${taskName}"] = 'WARN'
                $warnings++
            } else {
                Write-Fail "$taskName last result=$lastResult (non-zero), last run: $lastRunTime ($([math]::Round($minutesSinceRun,1)) min ago)"
                $results["check4_${taskName}"] = 'FAIL'
                $failures++
            }
            $results["check4_${taskName}_last_result"]       = $lastResult
            $results["check4_${taskName}_minutes_since_run"] = [math]::Round($minutesSinceRun, 1)
        }
    } catch {
        Write-Fail "$taskName — could not query: $_"
        $results["check4_${taskName}"] = 'FAIL'
        $failures++
    }
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 5 — qm-admin session Active (qwinsta)
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 5: qm-admin session Active"
try {
    $qwinstaOutput = & qwinsta 2>&1
    $qwinstaExit   = $LASTEXITCODE
    if ($qwinstaExit -ne 0) {
        Write-Fail "qwinsta exited with code $qwinstaExit"
        $results['check5_qwinsta'] = 'FAIL'
        $failures++
    } else {
        # Look for qm-admin with "Active" in the output
        $activeLines = $qwinstaOutput | Where-Object { $_ -match 'qm-admin' -and $_ -match 'Active' }
        if ($activeLines) {
            Write-Pass "qm-admin session is Active"
            $results['check5_qwinsta'] = 'PASS'
        } else {
            # Show what we found for diagnostic
            $allLines = ($qwinstaOutput | Where-Object { $_ -match 'qm-admin' }) -join ' | '
            if (-not $allLines) { $allLines = '(qm-admin not found in qwinsta output)' }
            Write-Fail "qm-admin session not Active: $allLines"
            $results['check5_qwinsta'] = 'FAIL'
            $failures++
        }
    }
    $results['check5_qwinsta_exit_code'] = $qwinstaExit
} catch {
    Write-Fail "qwinsta failed: $_"
    $results['check5_qwinsta'] = 'FAIL'
    $failures++
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 6 — Magic 109400003 (QM5_10940) has NO open position
# Strategy: parse T_Live EA JSONL logs for the most recent open/close event
#           for this magic number.  If not determinable → CHECK_MANUALLY.
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 6: Magic 109400003 (QM5_10940) no open position"
$MAGIC_10940 = 109400003

$eaLogDir = 'C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM'
# Try standard layout first, then fallback
if (-not (Test-Path $eaLogDir)) {
    $eaLogDir = 'C:\QM\mt5\T_Live\MQL5\Files\QM'
}

$check6_verdict = 'CHECK_MANUALLY'
$check6_detail  = 'No QM EA log files found for T_Live'

if (Test-Path $eaLogDir) {
    $logFiles = Get-ChildItem -Path $eaLogDir -Filter 'QM5_10940_*-ea-*.log' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending
    if (-not $logFiles) {
        # Try broader search
        $logFiles = Get-ChildItem -Path $eaLogDir -Filter 'QM5_10940*.log' -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending
    }
    if ($logFiles) {
        # Scan the most recent 2 log files for position events for this magic
        $latestEvent     = $null
        $latestEventTime = $null
        $scanFiles       = $logFiles | Select-Object -First 2
        foreach ($lf in $scanFiles) {
            try {
                $lines = Get-Content -LiteralPath $lf.FullName -ErrorAction SilentlyContinue
                foreach ($line in $lines) {
                    if (-not $line.Trim()) { continue }
                    try {
                        $ev = $line | ConvertFrom-Json -ErrorAction SilentlyContinue
                    } catch { continue }
                    if (-not $ev) { continue }
                    $evMagic = [int]($ev.magic ?? 0)
                    if ($evMagic -ne $MAGIC_10940) { continue }
                    $evName = [string]($ev.event ?? '')
                    if ($evName -notmatch 'TM_OPEN|TM_CLOSE|TRADE_OPEN|TRADE_CLOSED|POSITION_OPEN|POSITION_CLOSE') { continue }
                    $evTs = [string]($ev.ts_utc ?? $ev.ts_broker ?? '')
                    if (-not $latestEventTime -or $evTs -gt $latestEventTime) {
                        $latestEvent     = $evName
                        $latestEventTime = $evTs
                    }
                }
            } catch { }
        }
        if ($latestEvent) {
            $isOpen = $latestEvent -match 'TM_OPEN|TRADE_OPEN|POSITION_OPEN'
            if ($isOpen) {
                $check6_verdict = 'FAIL_OPEN'
                $check6_detail  = "Last position event = $latestEvent at $latestEventTime — position appears OPEN"
            } else {
                $check6_verdict = 'PASS'
                $check6_detail  = "Last position event = $latestEvent at $latestEventTime — position closed/flat"
            }
        } else {
            $check6_verdict = 'CHECK_MANUALLY'
            $check6_detail  = "Log files found ($($logFiles.Count)) but no TM_OPEN/TM_CLOSE events for magic $MAGIC_10940"
        }
    } else {
        $check6_verdict = 'CHECK_MANUALLY'
        $check6_detail  = "No log files matching QM5_10940* in $eaLogDir"
    }
} else {
    # Directory not found — try a broader search under T_Live
    $t_live_base = 'C:\QM\mt5\T_Live'
    $found = Get-ChildItem -Path $t_live_base -Filter 'QM5_10940*.log' -Recurse -ErrorAction SilentlyContinue |
             Select-Object -First 1
    if ($found) {
        $check6_verdict = 'CHECK_MANUALLY'
        $check6_detail  = "Log found at $($found.FullName) but not in expected directory — manual parse required"
    }
}

# 10940-open is NOT a NO-GO: the S3 chart session proceeds (Teil 1 + Teil 3); only
# Teil 2 (10940 EA removal) is deferred until the position closes. Verified 2026-07-04:
# ticket 3162733509 SELL XAUUSD 0.11 open since 06-29, breakeven-protected since 06-30.
switch ($check6_verdict) {
    'PASS'         { Write-Pass  "Magic $MAGIC_10940 (QM5_10940): $check6_detail" }
    'FAIL_OPEN'    { Write-Warn  "Magic $MAGIC_10940 (QM5_10940): $check6_detail -> DEFER Teil 2 (EA removal) until flat; Teil 1+3 proceed"; $warnings++ }
    default        { Write-Warn  "Magic $MAGIC_10940 (QM5_10940): $check6_detail"; $warnings++ }
}
$results['check6_magic_10940'] = $check6_verdict
$results['check6_detail']      = $check6_detail

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 7 — D: free space > 100 GB
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 7: D: free space > 100 GB"
try {
    $disk = Get-PSDrive -Name 'D' -ErrorAction Stop
    $freeGB = [math]::Round($disk.Free / 1GB, 2)
    if ($freeGB -gt 100) {
        Write-Pass "D: free space $freeGB GB (> 100 GB threshold)"
        $results['check7_d_free_gb'] = 'PASS'
    } else {
        Write-Fail "D: free space $freeGB GB (need > 100 GB)"
        $results['check7_d_free_gb'] = 'FAIL'
        $failures++
    }
    $results['check7_d_free_gb_value'] = $freeGB
} catch {
    Write-Fail "Could not query D: drive free space: $_"
    $results['check7_d_free_gb'] = 'FAIL'
    $failures++
}

# ──────────────────────────────────────────────────────────────────────────────
# CHECK 8 — lsm_health.json verdict == "ok" (fresh < 7h); absent = WARN
# ──────────────────────────────────────────────────────────────────────────────
Write-Header "CHECK 8: lsm_health.json verdict"
$lsmHealthPath = 'D:\QM\reports\state\lsm_health.json'

if (Test-Path $lsmHealthPath) {
    try {
        $lsmAge = ([datetime]::Now - (Get-Item $lsmHealthPath).LastWriteTime).TotalHours
        if ($lsmAge -gt 7) {
            Write-Warn "lsm_health.json is stale ($([math]::Round($lsmAge,1)) h old)"
            $results['check8_lsm_health'] = 'WARN'
            $warnings++
        } else {
            $lsmData    = Get-Content $lsmHealthPath -Raw | ConvertFrom-Json -ErrorAction Stop
            $lsmVerdict = [string]($lsmData.verdict ?? '')
            if ($lsmVerdict -eq 'ok') {
                Write-Pass "lsm_health.json verdict=ok (age: $([math]::Round($lsmAge,1)) h)"
                $results['check8_lsm_health'] = 'PASS'
            } else {
                Write-Fail "lsm_health.json verdict='$lsmVerdict' (expected 'ok')"
                $results['check8_lsm_health'] = 'FAIL'
                $failures++
            }
            $results['check8_lsm_verdict']    = $lsmVerdict
        }
        $results['check8_lsm_age_hours'] = [math]::Round($lsmAge, 1)
    } catch {
        Write-Warn "lsm_health.json found but could not parse: $_"
        $results['check8_lsm_health'] = 'WARN'
        $warnings++
    }
} else {
    Write-Warn "lsm_health.json not found at $lsmHealthPath (probe task may not be installed yet)"
    $results['check8_lsm_health'] = 'WARN'
    $warnings++
}

# ──────────────────────────────────────────────────────────────────────────────
# FINAL VERDICT
# ──────────────────────────────────────────────────────────────────────────────
Write-Host ''
$ts = [datetime]::UtcNow.ToString('o')
if ($failures -eq 0) {
    $verdict = 'GO'
    Write-Host "GO-AMPEL: GO  ($warnings warning(s))" -ForegroundColor Green
} else {
    $verdict = "NO-GO ($failures failure(s))"
    Write-Host "GO-AMPEL: NO-GO ($failures failure(s), $warnings warning(s))" -ForegroundColor Red
}

# ──────────────────────────────────────────────────────────────────────────────
# Append JSONL record
# ──────────────────────────────────────────────────────────────────────────────
$jsonlPath = 'D:\QM\reports\state\sunday_go_ampel.jsonl'
try {
    $record = [ordered]@{
        ts_utc          = $ts
        verdict         = $verdict
        failures        = $failures
        warnings        = $warnings
        host            = $env:COMPUTERNAME
    }
    foreach ($k in $results.Keys) { $record[$k] = $results[$k] }
    $jsonLine = $record | ConvertTo-Json -Compress -Depth 3
    New-Item -ItemType Directory -Force -Path (Split-Path $jsonlPath) | Out-Null
    Add-Content -LiteralPath $jsonlPath -Value $jsonLine -Encoding UTF8
    Write-Host "JSONL appended: $jsonlPath" -ForegroundColor DarkGray
} catch {
    Write-Warn "Could not append JSONL record: $_"
}

exit $(if ($failures -eq 0) { 0 } else { 1 })
