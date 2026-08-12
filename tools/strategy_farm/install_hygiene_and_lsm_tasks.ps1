# =====================================================================
#  Install QM_StrategyFarm_HygieneReboot + QM_StrategyFarm_LsmHealthProbe
#
#  ------------------------------------------------------------------
#  DO NOT RUN WHILE THE TASK SCHEDULER IS DEGRADED
#  (symptom: tasks fail 0x800710E0 / qwinsta error 87).
#  Run once after the next CLEAN BOOT from an elevated
#  (Administrator) PowerShell session.
#  ------------------------------------------------------------------
#
#  Registers two scheduled tasks -- idempotent (unregister-then-register):
#
#  QM_StrategyFarm_HygieneReboot
#    Preserved as a DISABLED legacy definition only. It must not be armed until
#    it has the dual-live watchdog's exact recovery and cancellable-edge guards.
#
#  QM_StrategyFarm_LsmHealthProbe
#    Every 6 hours, SYSTEM principal, HighestPrivilege.
#    Runs lsm_health_probe.ps1; writes lsm_health.json + appends to
#    lsm_health_history.jsonl under D:\QM\reports\state\.
#
#  QM_StrategyFarm_WorkerDedupe
#    On-demand only (no trigger), SYSTEM/ServiceAccount/Highest root.
#    The console-session helper launches start_terminal_workers.py --dedupe
#    with the logged-on qm-admin token in session 1, filling only missing
#    worker slots without killing in-flight terminals.
#
#  Usage:
#    # From an elevated PowerShell prompt after a clean boot:
#    Set-ExecutionPolicy -Scope Process Bypass
#    & "C:\QM\repo\tools\strategy_farm\install_hygiene_and_lsm_tasks.ps1"
# =====================================================================
[CmdletBinding()]
param(
    [string]$RepoRoot    = 'C:\QM\repo',
    [string]$HygieneTime = '07:00:00',   # local time, Saturday
    [int]$LsmEveryHours  = 6,
    [switch]$RunLsmNow                   # immediately fire the probe once (safe smoke test)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Resolve script paths
# ---------------------------------------------------------------------------
$hygieneScript = Join-Path $RepoRoot 'tools\strategy_farm\weekly_hygiene_reboot.ps1'
$lsmScript     = Join-Path $RepoRoot 'tools\strategy_farm\lsm_health_probe.ps1'

if (-not (Test-Path -LiteralPath $hygieneScript)) {
    throw "Hygiene-reboot script not found: $hygieneScript"
}
if (-not (Test-Path -LiteralPath $lsmScript)) {
    throw "LSM health probe script not found: $lsmScript"
}

function Assert-WindowsPowerShellScriptSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasUtf8Bom = (
        $bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and
        $bytes[1] -eq 0xBB -and
        $bytes[2] -eq 0xBF
    )
    if (-not $hasUtf8Bom -and ($bytes | Where-Object { $_ -gt 0x7F } | Select-Object -First 1)) {
        throw "WINDOWS_POWERSHELL_ENCODING_UNSAFE: $Path contains non-ASCII bytes without a UTF-8 BOM."
    }

    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    if ($parseErrors.Count -gt 0) {
        $detail = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "WINDOWS_POWERSHELL_PARSE_FAILED: $Path : $detail"
    }
}

# Fail before unregistering any working task. These scripts are launched by
# Windows PowerShell 5.1, which misdecodes BOM-less UTF-8 punctuation.
Assert-WindowsPowerShellScriptSafe -Path $hygieneScript
Assert-WindowsPowerShellScriptSafe -Path $lsmScript

try {
    & "$env:SystemRoot\System32\wevtutil.exe" sl `
        'Microsoft-Windows-TaskScheduler/Operational' /e:true
    if ($LASTEXITCODE -ne 0) {
        throw "wevtutil exited $LASTEXITCODE"
    }
    Write-Host 'Enabled Task Scheduler Operational event log.'
}
catch {
    Write-Warning "Could not enable Task Scheduler Operational log: $($_.Exception.Message)"
}

# Common task settings
$commonSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

$hygieneSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 2)

# SYSTEM principal (matches quota-governor, watchdog, factory-recycle pattern)
$sysPrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

# ---------------------------------------------------------------------------
# Task 1 -- QM_StrategyFarm_HygieneReboot  (weekly, Saturday 07:00 local)
# ---------------------------------------------------------------------------
$hygieneTask = 'QM_StrategyFarm_HygieneReboot'

$hygieneTrigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Saturday `
    -At $HygieneTime

$hygieneAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$hygieneScript`"" `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $hygieneTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $hygieneTask -Confirm:$false
    Write-Host "Unregistered existing task: $hygieneTask"
}

Register-ScheduledTask `
    -TaskName $hygieneTask `
    -Action   $hygieneAction `
    -Trigger  $hygieneTrigger `
    -Settings $hygieneSettings `
    -Principal $sysPrincipal `
    -Force `
    -Description "DISABLED legacy hygiene reboot definition. Do not enable until it has the dual-live watchdog's exact recovery-task, Autologon, maintenance, and cancellable process guards." `
    | Out-Null

Disable-ScheduledTask -TaskName $hygieneTask | Out-Null
Write-Host "Registered DISABLED: $hygieneTask (legacy definition; no automatic reboot)"

# ---------------------------------------------------------------------------
# Task 2 -- QM_StrategyFarm_LsmHealthProbe  (every 6 hours)
# ---------------------------------------------------------------------------
$lsmTask = 'QM_StrategyFarm_LsmHealthProbe'

# Use the repeating-once pattern (same as FactoryWatchdog) for sub-daily cadences
$lsmTrigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).Date `
    -RepetitionInterval (New-TimeSpan -Hours $LsmEveryHours) `
    -RepetitionDuration (New-TimeSpan -Days 3650)

$lsmAction = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$lsmScript`"" `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $lsmTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $lsmTask -Confirm:$false
    Write-Host "Unregistered existing task: $lsmTask"
}

Register-ScheduledTask `
    -TaskName $lsmTask `
    -Action   $lsmAction `
    -Trigger  $lsmTrigger `
    -Settings $commonSettings `
    -Principal $sysPrincipal `
    -Force `
    -Description "LSM session-infrastructure health probe (every ${LsmEveryHours}h, SYSTEM). Probes: qwinsta exit+error87, 3 QM scheduled-task result+cadence-lag, Win32_LogonSession interactive presence, CreateProcess viability, uptime. Verdict ok/degrading/critical. Output: D:\QM\reports\state\lsm_health.json + lsm_health_history.jsonl." `
    | Out-Null

Enable-ScheduledTask -TaskName $lsmTask | Out-Null
Write-Host "Registered: $lsmTask (every ${LsmEveryHours}h, SYSTEM)"

# ---------------------------------------------------------------------------
# Task 3 -- QM_StrategyFarm_WorkerDedupe  (on-demand, SYSTEM -> qm-admin bridge)
# ---------------------------------------------------------------------------
$dedupeTask   = 'QM_StrategyFarm_WorkerDedupe'
$dedupeScript = Join-Path $RepoRoot 'tools\strategy_farm\start_terminal_workers.py'
$helperScript = Join-Path $RepoRoot 'tools\strategy_farm\run_in_console_session.ps1'
$pyExe        = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe'
$powerShellExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$targetUser   = 'qm-admin'

if (-not (Test-Path -LiteralPath $dedupeScript)) {
    throw "start_terminal_workers.py not found: $dedupeScript"
}
if (-not (Test-Path -LiteralPath $helperScript)) {
    throw "console-session helper not found: $helperScript"
}
if (-not (Test-Path -LiteralPath $pyExe)) {
    throw "pythonw.exe not found: $pyExe"
}

# SYSTEM owns the scheduled root. The helper performs the only child spawn and
# binds it to the logged-on qm-admin token/session so terminal children remain
# viable; a direct SYSTEM child spawn is forbidden.
$dedupePrincipal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

$dedupeChildArguments = "$dedupeScript --repo-root $RepoRoot --farm-root D:\QM\strategy_farm --dedupe"
$dedupeActionArguments = (
    '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Exe "{1}" -Arguments "{2}" -WorkDir "{3}" -TargetUser "{4}" -WaitSeconds 540' -f `
        $helperScript, $pyExe, $dedupeChildArguments, $RepoRoot, $targetUser
)
if ($dedupeActionArguments.Contains("'")) {
    throw 'MNT-003 v2 action must not contain literal apostrophe wrappers.'
}
$dedupeAction = New-ScheduledTaskAction `
    -Execute $powerShellExe `
    -Argument $dedupeActionArguments `
    -WorkingDirectory $RepoRoot

if (Get-ScheduledTask -TaskName $dedupeTask -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $dedupeTask -Confirm:$false
    Write-Host "Unregistered existing task: $dedupeTask"
}

Register-ScheduledTask `
    -TaskName $dedupeTask `
    -Action   $dedupeAction `
    -Settings $commonSettings `
    -Principal $dedupePrincipal `
    -Force `
    -Description "On-demand surgical worker heal (no trigger). SYSTEM root uses run_in_console_session.ps1 to launch start_terminal_workers.py --dedupe with the logged-on qm-admin token in session 1. Never kills in-flight terminals; direct SYSTEM child spawns are forbidden." `
    | Out-Null

Enable-ScheduledTask -TaskName $dedupeTask | Out-Null
Write-Host "Registered: $dedupeTask (on-demand, SYSTEM -> qm-admin session bridge)"

# ---------------------------------------------------------------------------
# Optional immediate smoke run of the LSM probe
# ---------------------------------------------------------------------------
if ($RunLsmNow.IsPresent) {
    Write-Host "Firing $lsmTask immediately (smoke run)..."
    Start-ScheduledTask -TaskName $lsmTask
    Start-Sleep -Seconds 5
    $jsonPath = 'D:\QM\reports\state\lsm_health.json'
    if (Test-Path -LiteralPath $jsonPath) {
        Write-Host "lsm_health.json:"
        Get-Content -LiteralPath $jsonPath | Write-Host
    } else {
        Write-Host "WARNING: lsm_health.json not yet written (probe may still be running)"
    }
}

# ---------------------------------------------------------------------------
# Confirmation summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '--- Registered tasks ---'
foreach ($name in @($hygieneTask, $lsmTask, $dedupeTask)) {
    $task = Get-ScheduledTask -TaskName $name
    $info = Get-ScheduledTaskInfo -TaskName $name
    [pscustomobject]@{
        TaskName    = $task.TaskName
        State       = $task.State
        RunLevel    = $task.Principal.RunLevel
        LogonType   = $task.Principal.LogonType
        NextRunTime = $info.NextRunTime
    }
}
