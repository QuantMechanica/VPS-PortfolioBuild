# =====================================================================
#  QM_StrategyFarm_LsmHealthProbe -- Session-infrastructure health probe
#
#  PURPOSE:
#    Runs every 6 hours (SYSTEM scheduler) and scores session-manager
#    health early -- before full degradation (qwinsta error 87, tasks
#    fail 0x800710E0, RPC 1722) forces a hosting-panel hard reset.
#    Five independent probes; verdict written regardless of any failures.
#
#  PROBES:
#    1. qwinsta  -- exit code + output parse; error 87 = LSM degradation signature
#    2. Task self-test -- LastTaskResult + cadence lag on 3 known QM tasks
#    3. Logon session -- Win32_LogonSession CIM succeeds + interactive session present
#    4. Process spawn -- Start-Process cmd /c exit 0 (CreateProcess viability)
#    5. Uptime -- informational; fed into verdict context
#
#  OUTPUTS (written atomically even when system is half-dead):
#    D:\QM\reports\state\lsm_health.json       -- latest state (overwrite)
#    D:\QM\reports\state\lsm_health_history.jsonl -- one jsonl line per run (append)
#
#  VERDICT:
#    'ok'        -- all probes pass
#    'degrading' -- any single probe failing
#    'critical'  -- >=2 probes failing  OR  qwinsta error 87 + tasks failing
#
#  Every probe is individually try/caught.  This script MUST always reach
#  the write block, even when the system is half-dead.
# =====================================================================

$STATE_DIR   = 'D:\QM\reports\state'
$JSON_FILE   = Join-Path $STATE_DIR 'lsm_health.json'
$JSONL_FILE  = Join-Path $STATE_DIR 'lsm_health_history.jsonl'

# Tasks to probe: name + maximum allowed lag in minutes before counting as failing
# (cadence x 2 = generous allowance for missed ticks during load spikes)
$TASKS_TO_CHECK = @(
    [pscustomobject]@{ Name = 'QM_StrategyFarm_QuotaGovernor';         MaxLagMinutes = 30   }   # 15-min cadence
    [pscustomobject]@{ Name = 'QM_StrategyFarm_FactoryWatchdog_15min'; MaxLagMinutes = 15   }   # 5-min cadence
    [pscustomobject]@{ Name = 'QM_StrategyFarm_FactoryRecycle_Daily';  MaxLagMinutes = 1500 }   # daily cadence
)
$TASK_FAIL_CODE = 2147946720   # 0x800710E0 -- "The operator or administrator has refused the request"

# ---------------------------------------------------------------------------
# Initialise all probe results to safe defaults
# ---------------------------------------------------------------------------
$probed_at           = [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$uptime_days         = $null
$qwinsta_ok          = $false
$qwinsta_error       = 'not_run'
$tasks_failing_count = 0
$tasks_checked       = 0
$logon_session_ok    = $false
$spawn_ok            = $false

# Ensure output directory early -- use .NET directly so it works even when
# PowerShell provider is degraded.
try { [System.IO.Directory]::CreateDirectory($STATE_DIR) | Out-Null } catch { }

# ---------------------------------------------------------------------------
# Probe 5 -- Uptime (done first; other probes may reference it)
# ---------------------------------------------------------------------------
try {
    $os          = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
    $uptime_days = [System.Math]::Round(
        ([System.DateTime]::Now - $os.LastBootUpTime).TotalDays, 2
    )
} catch {
    $uptime_days = $null
}

# ---------------------------------------------------------------------------
# Probe 1 -- qwinsta session-list tool
# ---------------------------------------------------------------------------
try {
    # Capture stdout + stderr in one stream so we catch the "Error [87]" message
    # regardless of which file descriptor it comes from.
    $qwinstaOutput = & qwinsta /server:localhost 2>&1
    $qwinstaExit   = $LASTEXITCODE
    $combined      = if ($qwinstaOutput) { ($qwinstaOutput | Out-String) } else { '' }

    if ($qwinstaExit -eq 0) {
        $qwinsta_ok    = $true
        $qwinsta_error = $null
    } elseif ($combined -match 'Error\s*\[87\]') {
        # "Error [87]:The parameter is incorrect." is the LSM degradation signature
        $qwinsta_ok    = $false
        $qwinsta_error = 'error_87_lsm_degradation'
    } else {
        $qwinsta_ok    = $false
        $qwinsta_error = "exit_code_$qwinstaExit"
    }
} catch {
    $qwinsta_ok    = $false
    $qwinsta_error = "probe_exception:$($_.Exception.Message -replace '[\r\n]+',' ')"
}

# ---------------------------------------------------------------------------
# Probe 2 -- Scheduled-task self-test
# ---------------------------------------------------------------------------
foreach ($t in $TASKS_TO_CHECK) {
    $tasks_checked++
    $taskFailing = $false
    try {
        # A deliberately disabled maintenance/factory task has no cadence to
        # satisfy and must not masquerade as session-manager degradation.
        # Missing or unreadable tasks still fail closed below.
        $task = Get-ScheduledTask -TaskName $t.Name -ErrorAction Stop
        if ($task.State -eq 'Disabled' -or $task.Settings.Enabled -ne $true) {
            continue
        }
        $info = Get-ScheduledTaskInfo -TaskName $t.Name -ErrorAction Stop

        # Failure result code check
        if ($null -ne $info.LastTaskResult -and $info.LastTaskResult -eq $TASK_FAIL_CODE) {
            $taskFailing = $true
        }

        # Cadence lag check (only when the task has run at least once)
        if ($info.LastRunTime -and $info.LastRunTime -gt [datetime]'2000-01-01') {
            $lagMin = ([System.DateTime]::Now - $info.LastRunTime).TotalMinutes
            if ($lagMin -gt $t.MaxLagMinutes) {
                $taskFailing = $true
            }
        }
    } catch {
        # Task not found or info query failed -- treat as failing
        $taskFailing = $true
    }
    if ($taskFailing) { $tasks_failing_count++ }
}

# ---------------------------------------------------------------------------
# Probe 3 -- Logon session enumeration (Win32_LogonSession)
# ---------------------------------------------------------------------------
try {
    $sessions    = Get-CimInstance -ClassName Win32_LogonSession -ErrorAction Stop
    # LogonType 2 = Interactive (console), 10 = RemoteInteractive (RDP)
    $interactive = @($sessions | Where-Object { $_.LogonType -eq 2 -or $_.LogonType -eq 10 })
    $logon_session_ok = ($interactive.Count -gt 0)
} catch {
    $logon_session_ok = $false
}

# ---------------------------------------------------------------------------
# Probe 4 -- Process spawn (CreateProcess viability)
# ---------------------------------------------------------------------------
try {
    $p        = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c exit 0' `
                    -Wait -PassThru -NoNewWindow -ErrorAction Stop
    $spawn_ok = ($null -ne $p -and $p.ExitCode -eq 0)
} catch {
    $spawn_ok = $false
}

# ---------------------------------------------------------------------------
# Verdict calculation
# ---------------------------------------------------------------------------
$failing_probes = 0
if (-not $qwinsta_ok)            { $failing_probes++ }
if ($tasks_failing_count -gt 0)  { $failing_probes++ }
if (-not $logon_session_ok)      { $failing_probes++ }
if (-not $spawn_ok)              { $failing_probes++ }

$is_critical = ($failing_probes -ge 2) -or
               ($qwinsta_error -eq 'error_87_lsm_degradation' -and $tasks_failing_count -gt 0)

$verdict = if ($is_critical) {
    'critical'
} elseif ($failing_probes -ge 1) {
    'degrading'
} else {
    'ok'
}

# ---------------------------------------------------------------------------
# Build output object (field order matches spec)
# ---------------------------------------------------------------------------
$out = [ordered]@{
    probed_at            = $probed_at
    uptime_days          = $uptime_days
    qwinsta_ok           = $qwinsta_ok
    qwinsta_error        = $qwinsta_error
    tasks_failing_count  = $tasks_failing_count
    tasks_checked        = $tasks_checked
    logon_session_ok     = $logon_session_ok
    spawn_ok             = $spawn_ok
    verdict              = $verdict
}

$jsonLine = ConvertTo-Json -InputObject $out -Compress

# ---------------------------------------------------------------------------
# Write outputs -- each write is independently guarded so a partial failure
# in one does not prevent the other from completing.
# ---------------------------------------------------------------------------
try {
    [System.IO.Directory]::CreateDirectory($STATE_DIR) | Out-Null
    [System.IO.File]::WriteAllText($JSON_FILE, $jsonLine, [System.Text.Encoding]::UTF8)
} catch { }

try {
    [System.IO.Directory]::CreateDirectory($STATE_DIR) | Out-Null
    [System.IO.File]::AppendAllText(
        $JSONL_FILE,
        $jsonLine + [System.Environment]::NewLine,
        [System.Text.Encoding]::UTF8
    )
} catch { }

# Always echo to stdout (captured by Task Scheduler history if enabled)
Write-Host $jsonLine
