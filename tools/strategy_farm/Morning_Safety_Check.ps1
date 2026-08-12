<#
.SYNOPSIS
  Daily 04:45 local start-only safety sweep for live MT5 and the strategy farm.

.DESCRIPTION
  OWNER ratified this sweep on 2026-08-06. It completes before the nominal
  05:00 local placement window for QM5_13213. The broker/local relationship can
  move by +/-1 hour during DST edge weeks; OWNER may retune the trigger.

  The sweep never starts terminal64.exe directly. It wakes the existing SYSTEM
  watchdog, which alone uses the hardened Task Scheduler RunEx -> resident
  interactive supervisor -> idempotent launcher chain. It is start-only: no
  process is stopped, no reboot is requested, and AutoTrading is never changed.

  Evidence:
    D:\QM\reports\state\morning_safety_check.json
    D:\QM\reports\state\morning_safety_check.jsonl
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$FarmRoot = 'D:\QM\strategy_farm',
    [string]$ReportsState = 'D:\QM\reports\state',
    [string]$StateFile = 'D:\QM\reports\state\morning_safety_check.json',
    [string]$HistoryFile = 'D:\QM\reports\state\morning_safety_check.jsonl',
    [string]$MailStateFile = 'D:\QM\reports\state\morning_safety_mail_state.json',
    [string]$MailLogFile = 'D:\QM\reports\state\live_alarm_mailer.jsonl',
    [string]$PythonExe = 'C:\Python311\python.exe',
    [string]$CommonFilesRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
    [string]$NewsCalendarRoot = 'D:\QM\data\news_calendar',
    [string]$DiskRoot = 'D:\',
    [ValidateRange(1, 336)][int]$MaxNewsAgeHours = 336,
    [ValidateRange(1, 1024)][int]$MinDiskFreeGB = 10,
    [ValidateRange(10, 180)][int]$LiveHealWaitSeconds = 90,
    [ValidateRange(5, 120)][int]$WorkerHealWaitSeconds = 45,
    [ValidateRange(10, 300)][int]$NewsHealWaitSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$liveMaintenanceFlag = Join-Path $ReportsState 'LIVE_UPTIME_MAINTENANCE.flag'
$factoryOffFlag = Join-Path $FarmRoot 'state\FACTORY_OFF.flag'
$watchdogStateFile = Join-Path $ReportsState 'live_uptime_watchdog.json'
$watchdogScript = Join-Path $RepoRoot 'tools\strategy_farm\T_Live_Watchdog.ps1'
$windowsPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$workerScopeScript = Join-Path $RepoRoot 'tools\strategy_farm\factory_process_scope.ps1'
$alarmMailerScript = Join-Path $RepoRoot 'tools\strategy_farm\live_alarm_mailer.py'
$checks = [Collections.Generic.List[object]]::new()
$runActions = [Collections.Generic.List[string]]::new()
$runStartedUtc = [DateTime]::UtcNow

function Get-UtcStamp {
    param([datetime]$Value = [DateTime]::UtcNow)
    return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function ConvertFrom-UtcStamp {
    param([AllowNull()]$Value)
    if ($null -eq $Value) { return $null }
    try { return ([DateTime]::Parse([string]$Value)).ToUniversalTime() }
    catch { return $null }
}

function Read-JsonObject {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
    catch { return $null }
}

function Write-AtomicJson {
    param([string]$Path, $Value)
    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $tmp = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $backup = $null
    try {
        $json = $Value | ConvertTo-Json -Depth 10
        [IO.File]::WriteAllText($tmp, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $backup = Join-Path $directory ('.' + [IO.Path]::GetFileName($Path) + '.' + $PID + '.' + [guid]::NewGuid().ToString('N') + '.bak')
            [IO.File]::Replace($tmp, $Path, $backup, $true)
        } else {
            [IO.File]::Move($tmp, $Path)
        }
        $tmp = $null
    } finally {
        if ($tmp -and [IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
        if ($backup -and [IO.File]::Exists($backup)) { [IO.File]::Delete($backup) }
    }
}

function Add-Outcome {
    param(
        [string]$Name,
        [ValidateSet('OK', 'HEALED', 'FAILED', 'SUPPRESSED')][string]$Status,
        [string]$Detail,
        [AllowEmptyCollection()][string[]]$Evidence = @(),
        [AllowEmptyCollection()][string[]]$Actions = @()
    )
    $item = [ordered]@{
        name = $Name
        status = $Status
        detail = $Detail
        evidence = @($Evidence)
        actions = @($Actions)
    }
    $checks.Add([pscustomobject]$item)
    Write-Output ("[{0}] {1} - {2}" -f $Status, $Name, $Detail)
}

function Get-SafeTask {
    param(
        [string]$Name,
        [string]$ArgumentFragment,
        [ValidateSet('SYSTEM', 'QM_ADMIN')][string]$PrincipalKind = 'SYSTEM'
    )
    try {
        $found = @(Get-ScheduledTask -TaskPath '\' -TaskName $Name -ErrorAction Stop)
        if ($found.Count -ne 1) { throw "task_count=$($found.Count)" }
        $task = $found[0]
        if (@($task.Actions).Count -ne 1) { throw "action_count=$(@($task.Actions).Count)" }
        $arguments = [string]$task.Actions[0].Arguments
        if ($arguments.IndexOf($ArgumentFragment, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
            throw "action_contract_drift"
        }
        $principal = [string]$task.Principal.UserId
        if ($PrincipalKind -eq 'SYSTEM' -and $principal -notmatch '(?i)(?:^|\\)SYSTEM$') {
            throw "principal_not_SYSTEM:$principal"
        }
        if ($PrincipalKind -eq 'QM_ADMIN' -and $principal -notmatch '(?i)(?:^|\\)qm-admin$') {
            throw "principal_not_qm-admin:$principal"
        }
        return [pscustomobject]@{ ok = $true; task = $task; reason = 'contract_ok' }
    } catch {
        return [pscustomobject]@{ ok = $false; task = $null; reason = $_.Exception.Message }
    }
}

function Invoke-StartOnlyTask {
    param(
        [string]$Name,
        [string]$ArgumentFragment,
        [ValidateSet('SYSTEM', 'QM_ADMIN')][string]$PrincipalKind = 'SYSTEM',
        [switch]$ForceStart
    )
    $actions = [Collections.Generic.List[string]]::new()
    $safe = Get-SafeTask -Name $Name -ArgumentFragment $ArgumentFragment -PrincipalKind $PrincipalKind
    if (-not $safe.ok) {
        return [pscustomobject]@{ ok = $false; changed = $false; actions = @($actions); reason = $safe.reason }
    }
    $task = $safe.task
    if ($task.Settings.Enabled -ne $true -or $task.State -eq 'Disabled') {
        if ($DryRun.IsPresent) {
            $actions.Add("would_enable:$Name")
        } else {
            Enable-ScheduledTask -TaskName $Name -ErrorAction Stop | Out-Null
            $actions.Add("enabled:$Name")
        }
    }
    if ($ForceStart.IsPresent -and $task.State -ne 'Running') {
        if ($DryRun.IsPresent) {
            $actions.Add("would_start:$Name")
        } else {
            Start-ScheduledTask -TaskName $Name -ErrorAction Stop
            $actions.Add("started:$Name")
        }
    }
    foreach ($one in $actions) { $runActions.Add($one) }
    return [pscustomobject]@{
        ok = $true
        changed = ($actions.Count -gt 0)
        actions = @($actions)
        reason = 'start_only_task_action_complete'
    }
}

function Invoke-NoRebootWatchdog {
    # The regular scheduled watchdog may carry OWNER-approved controlled-reboot
    # authority. This morning sweep invokes the same script with -NoReboot so it
    # can use the identical RunEx/supervisor/launcher chain without inheriting
    # any reboot authority.
    $actions = [Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        return [pscustomobject]@{ ok = $false; changed = $false; actions = @(); reason = 'Windows PowerShell missing' }
    }
    if (-not (Test-Path -LiteralPath $watchdogScript -PathType Leaf)) {
        return [pscustomobject]@{ ok = $false; changed = $false; actions = @(); reason = 'T_Live_Watchdog.ps1 missing' }
    }
    if ($DryRun.IsPresent) {
        $actions.Add('would_run_watchdog_no_reboot')
        $runActions.Add('would_run_watchdog_no_reboot')
        return [pscustomobject]@{ ok = $true; changed = $true; actions = @($actions); reason = 'dry_run' }
    }
    $savedErrorPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& $windowsPowerShell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass `
            -File $watchdogScript -NoReboot 2>&1)
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $savedErrorPreference
    }
    $detail = (($output | ForEach-Object { [string]$_ }) -join ' ').Trim()
    if ($detail.Length -gt 300) { $detail = $detail.Substring(0, 300) }
    $actions.Add("ran_watchdog_no_reboot:exit=$exitCode")
    $runActions.Add("ran_watchdog_no_reboot:exit=$exitCode")
    # Exit 0/1/2 are the watchdog's healthy/degraded/critical state verdicts.
    return [pscustomobject]@{
        ok = ($exitCode -in @(0, 1, 2))
        changed = $true
        actions = @($actions)
        reason = if ($exitCode -in @(0, 1, 2)) { 'watchdog_completed' } else { "exit=${exitCode}:$detail" }
    }
}

function Get-WatchdogObservation {
    $state = Read-JsonObject -Path $watchdogStateFile
    if ($null -eq $state) {
        return [pscustomobject]@{ readable = $false; fresh = $false; age_seconds = $null; state = $null; reason = 'state_missing_or_unreadable' }
    }
    $checked = ConvertFrom-UtcStamp $state.last_checked_utc
    if ($null -eq $checked) {
        return [pscustomobject]@{ readable = $true; fresh = $false; age_seconds = $null; state = $state; reason = 'timestamp_invalid' }
    }
    $age = ([DateTime]::UtcNow - $checked).TotalSeconds
    return [pscustomobject]@{
        readable = $true
        fresh = ($age -ge -5 -and $age -le 180)
        age_seconds = [math]::Round($age, 1)
        state = $state
        reason = if ($age -gt 180) { 'state_stale' } elseif ($age -lt -5) { 'state_from_future' } else { 'fresh' }
    }
}

function Test-LiveObservationHealthy {
    param($Observation)
    if ($null -eq $Observation -or -not $Observation.fresh -or $null -eq $Observation.state) { return $false }
    $s = $Observation.state
    return ($s.process_probe_ok -eq $true) -and
        ([string]$s.expected_dxz_state -eq 'RUNNING') -and
        ([string]$s.expected_ftmo_state -eq 'RUNNING') -and
        ($s.dxz_running -eq $true) -and ($s.ftmo_running -eq $true) -and
        ($s.dxz_contract_ok -eq $true) -and ($s.ftmo_contract_ok -eq $true) -and
        ($s.session_supervisor_heartbeat_ready -eq $true) -and
        ($s.session_supervisor_scheduler_owned -eq $true) -and
        ($s.autologon_ready -eq $true) -and
        ($s.recovery_task_contract_ready -eq $true)
}

function Get-TaskPulseState {
    param(
        [string]$Name,
        [int]$MaxAgeMinutes,
        [int64[]]$AllowedResults = @(0)
    )
    try {
        $task = Get-ScheduledTask -TaskPath '\' -TaskName $Name -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $Name -ErrorAction Stop
        $age = if ($info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { ((Get-Date) - $info.LastRunTime).TotalMinutes } else { [double]::PositiveInfinity }
        $running = ($task.State -eq 'Running')
        $sane = ($task.Settings.Enabled -eq $true) -and ($task.State -ne 'Disabled') -and
            ($running -or (($AllowedResults -contains [int64]$info.LastTaskResult) -and $age -le $MaxAgeMinutes))
        return [pscustomobject]@{
            sane = $sane
            state = [string]$task.State
            enabled = [bool]$task.Settings.Enabled
            last_result = [int64]$info.LastTaskResult
            age_minutes = if ([double]::IsPositiveInfinity($age)) { $null } else { [math]::Round($age, 1) }
        }
    } catch {
        return [pscustomobject]@{ sane = $false; state = 'UNKNOWN'; enabled = $false; last_result = $null; age_minutes = $null; error = $_.Exception.Message }
    }
}

function Get-WorkerObservation {
    try {
        if (-not (Test-Path -LiteralPath $workerScopeScript -PathType Leaf)) { throw 'factory_process_scope.ps1 missing' }
        . $workerScopeScript
        $expected = @(Get-QmFactoryWorkerPolicyTerminals)
        $processes = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction Stop)
        $counts = @{}
        foreach ($terminal in $expected) { $counts[$terminal] = 0 }
        foreach ($process in $processes) {
            if (-not (Test-QmFactoryWorkerCommandLine -CommandLine ([string]$process.CommandLine))) { continue }
            $arguments = @(Get-QmCommandLineArguments -CommandLine ([string]$process.CommandLine))
            $terminal = [string](Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '--terminal')
            if ($counts.ContainsKey($terminal)) { $counts[$terminal] = [int]$counts[$terminal] + 1 }
        }
        $missing = @($expected | Where-Object { [int]$counts[$_] -eq 0 })
        $duplicates = @($expected | Where-Object { [int]$counts[$_] -gt 1 })
        return [pscustomobject]@{
            probe_ok = $true
            expected = @($expected)
            counts = $counts
            missing = @($missing)
            duplicates = @($duplicates)
            ready = ($missing.Count -eq 0 -and $duplicates.Count -eq 0)
            reason = 'classified_with_factory_process_scope_v2'
        }
    } catch {
        return [pscustomobject]@{ probe_ok = $false; expected = @(); counts = @{}; missing = @(); duplicates = @(); ready = $false; reason = $_.Exception.Message }
    }
}

function Get-NewsCalendarObservation {
    $names = @('news_calendar_2015_2025.csv', 'forex_factory_calendar_clean.csv')
    $reasons = [Collections.Generic.List[string]]::new()
    $evidence = [Collections.Generic.List[string]]::new()
    $maxAge = 0.0
    foreach ($name in $names) {
        $source = Join-Path $NewsCalendarRoot $name
        $common = Join-Path $CommonFilesRoot $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { $reasons.Add("source_missing:$name"); continue }
        if (-not (Test-Path -LiteralPath $common -PathType Leaf)) { $reasons.Add("common_missing:$name"); continue }
        try {
            $sourceItem = Get-Item -LiteralPath $source -ErrorAction Stop
            $commonItem = Get-Item -LiteralPath $common -ErrorAction Stop
            if ($sourceItem.Length -le 0 -or $commonItem.Length -le 0) { $reasons.Add("empty:$name"); continue }
            $ageHours = ([DateTime]::UtcNow - $commonItem.LastWriteTimeUtc).TotalHours
            if ($ageHours -lt 0) { $ageHours = 0 }
            if ($ageHours -gt $maxAge) { $maxAge = $ageHours }
            if ($ageHours -gt $MaxNewsAgeHours) { $reasons.Add("stale:${name}:$([math]::Round($ageHours,1))h") }
            $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256 -ErrorAction Stop).Hash
            $commonHash = (Get-FileHash -LiteralPath $common -Algorithm SHA256 -ErrorAction Stop).Hash
            if (-not [string]::Equals($sourceHash, $commonHash, [StringComparison]::OrdinalIgnoreCase)) {
                $reasons.Add("hash_mismatch:$name")
            }
            $evidence.Add("$name age=$([math]::Round($ageHours,1))h sha256=$($commonHash.Substring(0,12))")
        } catch {
            $reasons.Add("probe_failed:${name}:$($_.Exception.Message)")
        }
    }
    $manifestPath = Join-Path $NewsCalendarRoot 'news_calendar_bundle_manifest.json'
    $manifest = Read-JsonObject -Path $manifestPath
    if ($null -eq $manifest) {
        $reasons.Add('manifest_missing_or_unreadable')
    } else {
        try {
            $manifestFiles = @($manifest.files)
            if ($manifestFiles.Count -lt 1) { throw 'manifest files array empty' }
            $lastEvent = ConvertFrom-UtcStamp $manifestFiles[0].last_event_utc
            if ($null -eq $lastEvent -or $lastEvent -lt [DateTime]::UtcNow) {
                $reasons.Add("manifest_coverage_expired:$($manifestFiles[0].last_event_utc)")
            } else {
                $evidence.Add("coverage_through=$(Get-UtcStamp $lastEvent)")
            }
        } catch {
            $reasons.Add("manifest_contract_invalid:$($_.Exception.Message)")
        }
    }
    return [pscustomobject]@{
        ready = ($reasons.Count -eq 0)
        reasons = @($reasons)
        evidence = @($evidence)
        max_age_hours = [math]::Round($maxAge, 1)
    }
}

# --- LIVE domain ------------------------------------------------------
$liveMaintenance = $false
try { $liveMaintenance = Test-Path -LiteralPath $liveMaintenanceFlag -PathType Leaf -ErrorAction Stop }
catch { $liveMaintenance = $true }

if ($liveMaintenance) {
    foreach ($name in @('live_watchdog_cadence', 'live_session_supervisor', 'live_terminals', 'autologon_recovery_contract')) {
        Add-Outcome -Name $name -Status SUPPRESSED -Detail 'LIVE_UPTIME_MAINTENANCE.flag active; no live-domain start attempted' -Evidence @($liveMaintenanceFlag)
    }
} else {
    $initialLive = Get-WatchdogObservation
    $needsLiveWake = -not (Test-LiveObservationHealthy -Observation $initialLive)
    $watchdogAction = Invoke-StartOnlyTask -Name 'QM_T_Live_Watchdog' `
        -ArgumentFragment 'T_Live_Watchdog.ps1' -PrincipalKind SYSTEM
    $watchdogRun = [pscustomobject]@{ ok = $true; changed = $false; actions = @(); reason = 'not_required' }
    if ($watchdogAction.ok -and $needsLiveWake) {
        $watchdogRun = Invoke-NoRebootWatchdog
    }
    $combinedWatchdogActions = @($watchdogAction.actions) + @($watchdogRun.actions)
    $liveChanged = [bool]$watchdogAction.changed
    if ($watchdogRun.changed) { $liveChanged = $true }
    if (-not $watchdogAction.ok -or -not $watchdogRun.ok) {
        $rejectReason = if (-not $watchdogAction.ok) { $watchdogAction.reason } else { $watchdogRun.reason }
        Add-Outcome -Name 'live_watchdog_cadence' -Status FAILED -Detail "watchdog heal contract rejected: $rejectReason"
        $liveObservation = $initialLive
    } else {
        if ($needsLiveWake -and -not $DryRun.IsPresent) {
            $deadline = [DateTime]::UtcNow.AddSeconds($LiveHealWaitSeconds)
            do {
                Start-Sleep -Seconds 2
                $liveObservation = Get-WatchdogObservation
                if (Test-LiveObservationHealthy -Observation $liveObservation) { break }
            } while ([DateTime]::UtcNow -lt $deadline)
        } else {
            $liveObservation = Get-WatchdogObservation
        }
        # Watchdog exits 1/2 for fresh degraded/critical observations; those are
        # state verdicts, not task-execution failures. The JSON drives health.
        $taskPulse = Get-TaskPulseState -Name 'QM_T_Live_Watchdog' -MaxAgeMinutes 5 -AllowedResults @(0, 1, 2)
        if ($taskPulse.sane -and $liveObservation.fresh) {
            $status = if ($liveChanged -and -not $DryRun.IsPresent) { 'HEALED' } else { 'OK' }
            Add-Outcome -Name 'live_watchdog_cadence' -Status $status `
                -Detail "task=$($taskPulse.state), state_age=$($liveObservation.age_seconds)s" `
                -Evidence @("last_result=$($taskPulse.last_result)", "state=$watchdogStateFile") -Actions $combinedWatchdogActions
        } else {
            Add-Outcome -Name 'live_watchdog_cadence' -Status FAILED `
                -Detail "watchdog not fresh/sane: task=$($taskPulse.state), result=$($taskPulse.last_result), state_reason=$($liveObservation.reason)" `
                -Actions $combinedWatchdogActions
        }
    }

    $liveState = if ($null -ne $liveObservation) { $liveObservation.state } else { $null }
    if ($null -ne $liveState -and $liveObservation.fresh -and
        $liveState.session_supervisor_heartbeat_ready -eq $true -and
        $liveState.session_supervisor_scheduler_owned -eq $true) {
        $status = if ($liveChanged -and -not $DryRun.IsPresent) { 'HEALED' } else { 'OK' }
        Add-Outcome -Name 'live_session_supervisor' -Status $status `
            -Detail "scheduler-owned heartbeat ready; engine_pid=$($liveState.session_supervisor_engine_pid)" `
            -Evidence @("age_seconds=$($liveState.session_supervisor_age_seconds)", "reason=$($liveState.session_supervisor_reason)")
    } else {
        $reason = if ($null -eq $liveState) { 'watchdog state unavailable' } else { "heartbeat=$($liveState.session_supervisor_heartbeat_ready), owned=$($liveState.session_supervisor_scheduler_owned), reason=$($liveState.session_supervisor_reason)" }
        Add-Outcome -Name 'live_session_supervisor' -Status FAILED -Detail $reason -Actions $combinedWatchdogActions
    }

    if ($null -eq $liveState -or -not $liveObservation.fresh) {
        Add-Outcome -Name 'live_terminals' -Status FAILED -Detail 'fresh watchdog process inventory unavailable; fail-closed, no direct launch attempted'
    } elseif ($liveState.process_probe_ok -ne $true) {
        Add-Outcome -Name 'live_terminals' -Status FAILED -Detail 'watchdog process inventory UNKNOWN; fail-closed, no direct launch attempted'
    } elseif ([string]$liveState.expected_dxz_state -ne 'RUNNING' -or [string]$liveState.expected_ftmo_state -ne 'RUNNING') {
        Add-Outcome -Name 'live_terminals' -Status FAILED `
            -Detail "expected-state contract is not dual RUNNING: DXZ=$($liveState.expected_dxz_state), FTMO=$($liveState.expected_ftmo_state)"
    } elseif ($liveState.dxz_running -eq $true -and $liveState.ftmo_running -eq $true -and
        $liveState.dxz_contract_ok -eq $true -and $liveState.ftmo_contract_ok -eq $true) {
        $status = if ($liveChanged -and -not $DryRun.IsPresent) { 'HEALED' } else { 'OK' }
        Add-Outcome -Name 'live_terminals' -Status $status `
            -Detail "DXZ and FTMO RUNNING via watchdog-observed inventory; pids=$(@($liveState.dxz_pids + $liveState.ftmo_pids) -join ',')" `
            -Evidence @('no terminal64.exe direct launch', "session_id=$($liveState.target_session_id)")
    } else {
        Add-Outcome -Name 'live_terminals' -Status FAILED `
            -Detail "watchdog recovery did not establish both terminals: DXZ=$($liveState.dxz_running), FTMO=$($liveState.ftmo_running)" `
            -Actions $combinedWatchdogActions
    }

    if ($null -ne $liveState -and $liveObservation.fresh -and
        $liveState.autologon_ready -eq $true -and
        [string]$liveState.autologon_secret_probe -eq 'present' -and
        $liveState.recovery_task_contract_ready -eq $true) {
        Add-Outcome -Name 'autologon_recovery_contract' -Status OK `
            -Detail 'watchdog Get-RecoveryTaskContractState semantics report ready; SYSTEM LSA secret present' `
            -Evidence @("expected_sid=$($liveState.recovery_task_expected_sid)")
    } else {
        $errors = if ($null -ne $liveState) { @($liveState.recovery_task_contract_errors) -join '|' } else { 'watchdog_state_unavailable' }
        Add-Outcome -Name 'autologon_recovery_contract' -Status FAILED `
            -Detail "autologon/recovery contract not ready: $errors"
    }
}

# --- FACTORY domain ---------------------------------------------------
$factoryOff = $false
try { $factoryOff = Test-Path -LiteralPath $factoryOffFlag -PathType Leaf -ErrorAction Stop }
catch { $factoryOff = $true }

if ($factoryOff) {
    Add-Outcome -Name 'factory_lane_pulse' -Status SUPPRESSED -Detail 'FACTORY_OFF.flag active; no factory task or worker start attempted' -Evidence @($factoryOffFlag)
} else {
    $pulseContracts = @(
        [pscustomobject]@{ name='QM_StrategyFarm_Pump_5min'; fragment='run_pump_task.py'; principal='SYSTEM'; max_age=15 },
        [pscustomobject]@{ name='QM_StrategyFarm_Tick_5min'; fragment='farmctl.py tick'; principal='QM_ADMIN'; max_age=15 },
        [pscustomobject]@{ name='QM_StrategyFarm_FactoryWatchdog_15min'; fragment='factory_watchdog.ps1'; principal='SYSTEM'; max_age=45 }
    )
    $factoryFailures = [Collections.Generic.List[string]]::new()
    $factoryActions = [Collections.Generic.List[string]]::new()
    $factoryHealed = $false
    foreach ($contract in $pulseContracts) {
        $before = Get-TaskPulseState -Name $contract.name -MaxAgeMinutes $contract.max_age
        $action = Invoke-StartOnlyTask -Name $contract.name -ArgumentFragment $contract.fragment `
            -PrincipalKind $contract.principal -ForceStart:(-not $before.sane)
        foreach ($one in @($action.actions)) { $factoryActions.Add($one) }
        if (-not $action.ok) {
            $factoryFailures.Add("$($contract.name):contract:$($action.reason)")
            continue
        }
        if (-not $DryRun.IsPresent -and $action.changed) { Start-Sleep -Seconds 2 }
        $after = Get-TaskPulseState -Name $contract.name -MaxAgeMinutes $contract.max_age
        if (-not $after.sane) {
            $factoryFailures.Add("$($contract.name):state=$($after.state):result=$($after.last_result):age=$($after.age_minutes)m")
        } elseif ($action.changed -and -not $DryRun.IsPresent) {
            $factoryHealed = $true
        }
    }

    $workers = Get-WorkerObservation
    if (-not $workers.probe_ok) {
        $factoryFailures.Add("worker_inventory_unknown:$($workers.reason)")
    } elseif ($workers.duplicates.Count -gt 0) {
        # Start-only boundary: never run a deduper while duplicates might own
        # active T1-T10 work. Report and leave every process untouched.
        $factoryFailures.Add("duplicate_workers_start_only_refusal:$($workers.duplicates -join ',')")
    } elseif ($workers.missing.Count -gt 0) {
        $workerAction = Invoke-StartOnlyTask -Name 'QM_StrategyFarm_WorkerDedupe' `
            -ArgumentFragment 'start_terminal_workers.py' -PrincipalKind SYSTEM -ForceStart
        foreach ($one in @($workerAction.actions)) { $factoryActions.Add($one) }
        if (-not $workerAction.ok) {
            $factoryFailures.Add("worker_start_contract:$($workerAction.reason)")
        } elseif ($DryRun.IsPresent) {
            $factoryFailures.Add("workers_missing_dry_run:$($workers.missing -join ',')")
        } else {
            $deadline = [DateTime]::UtcNow.AddSeconds($WorkerHealWaitSeconds)
            do {
                Start-Sleep -Seconds 2
                $workers = Get-WorkerObservation
                if ($workers.ready) { break }
                if (-not $workers.probe_ok -or $workers.duplicates.Count -gt 0) { break }
            } while ([DateTime]::UtcNow -lt $deadline)
            if ($workers.ready) { $factoryHealed = $true }
            else { $factoryFailures.Add("worker_start_unverified:missing=$($workers.missing -join ','):duplicates=$($workers.duplicates -join ',')") }
        }
    }

    if ($factoryFailures.Count -gt 0) {
        Add-Outcome -Name 'factory_lane_pulse' -Status FAILED -Detail ($factoryFailures -join '; ') `
            -Evidence @("expected_workers=$($workers.expected.Count)") -Actions @($factoryActions)
    } else {
        $status = if ($factoryHealed) { 'HEALED' } else { 'OK' }
        Add-Outcome -Name 'factory_lane_pulse' -Status $status `
            -Detail "pump/tick/watchdog sane; $($workers.expected.Count) policy workers present exactly once" `
            -Evidence @('classified by factory_process_scope_v2') -Actions @($factoryActions)
    }
}

# --- News seed + FILE_COMMON copy ------------------------------------
$news = Get-NewsCalendarObservation
if ($factoryOff) {
    Add-Outcome -Name 'news_calendar_freshness' -Status SUPPRESSED `
        -Detail "FACTORY_OFF.flag active; refresh suppressed; observed_ready=$($news.ready)" -Evidence $news.evidence
} elseif ($news.ready) {
    Add-Outcome -Name 'news_calendar_freshness' -Status OK `
        -Detail "source and FILE_COMMON pairs match; worst age=$($news.max_age_hours)h <= ${MaxNewsAgeHours}h" -Evidence $news.evidence
} else {
    $refreshAction = Invoke-StartOnlyTask -Name 'QM_NewsCalendar_Refresh' `
        -ArgumentFragment 'refresh_news_calendar.ps1' -PrincipalKind SYSTEM -ForceStart
    if ($refreshAction.ok -and -not $DryRun.IsPresent) {
        $deadline = [DateTime]::UtcNow.AddSeconds($NewsHealWaitSeconds)
        do {
            Start-Sleep -Seconds 3
            $news = Get-NewsCalendarObservation
            if ($news.ready) { break }
        } while ([DateTime]::UtcNow -lt $deadline)
    }
    if ($news.ready -and -not $DryRun.IsPresent) {
        Add-Outcome -Name 'news_calendar_freshness' -Status HEALED `
            -Detail 'refresh task restored fresh, hash-identical source + FILE_COMMON seeds' `
            -Evidence $news.evidence -Actions $refreshAction.actions
    } else {
        $reason = if (-not $refreshAction.ok) { "refresh task contract rejected: $($refreshAction.reason)" } else { @($news.reasons) -join '; ' }
        Add-Outcome -Name 'news_calendar_freshness' -Status FAILED `
            -Detail $reason -Evidence $news.evidence -Actions $refreshAction.actions
    }
}

# --- Disk headroom (observation only; deletion is outside this task) ---
try {
    $drive = [IO.DriveInfo]::new($DiskRoot)
    if (-not $drive.IsReady) { throw "drive_not_ready:$DiskRoot" }
    $freeGb = [math]::Round($drive.AvailableFreeSpace / 1GB, 2)
    if ($freeGb -lt $MinDiskFreeGB) {
        Add-Outcome -Name 'disk_headroom' -Status FAILED `
            -Detail "$DiskRoot free ${freeGb}GB < ${MinDiskFreeGB}GB; no cleanup attempted"
    } else {
        Add-Outcome -Name 'disk_headroom' -Status OK -Detail "$DiskRoot free ${freeGb}GB >= ${MinDiskFreeGB}GB"
    }
} catch {
    Add-Outcome -Name 'disk_headroom' -Status FAILED -Detail "disk probe failed: $($_.Exception.Message)"
}

$failed = @($checks | Where-Object { $_.status -eq 'FAILED' })
$healed = @($checks | Where-Object { $_.status -eq 'HEALED' })
$suppressed = @($checks | Where-Object { $_.status -eq 'SUPPRESSED' })
$overall = if ($failed.Count -gt 0) { 'FAILED' } elseif ($healed.Count -gt 0) { 'HEALED' } else { 'OK' }
$record = [ordered]@{
    schema_version = 1
    generated_utc = Get-UtcStamp
    started_utc = Get-UtcStamp $runStartedUtc
    local_schedule = '04:45 Europe/Berlin'
    dst_note = 'QM5_13213 nominal bracket is 05:00 local / 06:00 broker; DST edge weeks can shift +/-1h; OWNER may retune.'
    dry_run = $DryRun.IsPresent
    start_only = $true
    overall = $overall
    summary = [ordered]@{
        ok = @($checks | Where-Object { $_.status -eq 'OK' }).Count
        healed = $healed.Count
        failed = $failed.Count
        suppressed = $suppressed.Count
        total = $checks.Count
    }
    checks = @($checks)
    actions = @($runActions)
    mail = [ordered]@{ status = if ($failed.Count -gt 0) { 'pending' } else { 'not_required' } }
}

# Publish the atomic latest state before invoking the shared mail transport;
# the mailer reads this exact document. History is appended only after mail.
Write-AtomicJson -Path $StateFile -Value $record

$mailExit = 0
if ($failed.Count -gt 0) {
    if (-not (Test-Path -LiteralPath $PythonExe -PathType Leaf)) {
        $record.mail = [ordered]@{ status = 'FAILED'; detail = "python missing: $PythonExe" }
        $mailExit = 2
    } elseif (-not (Test-Path -LiteralPath $alarmMailerScript -PathType Leaf)) {
        $record.mail = [ordered]@{ status = 'FAILED'; detail = "mailer missing: $alarmMailerScript" }
        $mailExit = 2
    } else {
        $mailArgs = @(
            $alarmMailerScript,
            '--morning-safety-file', $StateFile,
            '--morning-safety-mail-state-file', $MailStateFile,
            '--log-file', $MailLogFile
        )
        if ($DryRun.IsPresent) { $mailArgs += '--dry-run' }
        $savedErrorPreference = $ErrorActionPreference
        try {
            # Python may write diagnostic text to stderr; capture it as evidence
            # and judge only the process exit code.
            $ErrorActionPreference = 'Continue'
            $mailOutput = @(& $PythonExe @mailArgs 2>&1)
            $mailExit = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $savedErrorPreference
        }
        $record.mail = [ordered]@{
            status = if ($mailExit -eq 0) { if ($DryRun.IsPresent) { 'DRY_RUN' } else { 'SENT_OR_DEDUPED' } } else { 'FAILED' }
            exit_code = $mailExit
            output = (($mailOutput | ForEach-Object { [string]$_ }) -join ' ').Trim()
        }
    }
    Write-AtomicJson -Path $StateFile -Value $record
}

$historyDirectory = Split-Path -Parent $HistoryFile
[IO.Directory]::CreateDirectory($historyDirectory) | Out-Null
$historyJson = $record | ConvertTo-Json -Compress -Depth 10
[IO.File]::AppendAllText($HistoryFile, $historyJson + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

Write-Output ($record | ConvertTo-Json -Depth 10)
if ($mailExit -ne 0) { exit $mailExit }
exit 0
