# =====================================================================
#  QuantMechanica - Factory restart post-start health gate
#
#  Pure evaluation is kept separate from the bounded read-only probes so the
#  fail-closed contract can be tested without touching Task Scheduler, CIM or
#  Factory runtime state.
# =====================================================================

$script:QmFactoryRestartHealthProtocolVersion = 1

function Add-QmExpectedTaskEnabledState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$TaskMap,

        [Parameter(Mandatory = $true)]
        [string]$TaskName,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    if ([string]::IsNullOrWhiteSpace($TaskName)) {
        throw 'Expected task name must not be empty.'
    }
    if ($TaskMap.Contains($TaskName)) {
        if ([bool]$TaskMap[$TaskName] -ne $Enabled) {
            throw "Conflicting expected enabled state for task '$TaskName'."
        }
        return
    }
    $TaskMap[$TaskName] = $Enabled
}

function Get-QmFactoryPostStartSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TaskNames
    )

    $taskRows = @()
    foreach ($taskName in @($TaskNames | Sort-Object -Unique)) {
        try {
            $taskMatches = @(Get-ScheduledTask -TaskName $taskName -ErrorAction Stop)
            if ($taskMatches.Count -ne 1) {
                throw "Expected exactly one task registration, found $($taskMatches.Count)."
            }
            $task = $taskMatches[0]
            $taskInfo = Get-ScheduledTaskInfo -InputObject $task -ErrorAction Stop
            if ($task.Settings.Enabled -isnot [bool]) {
                throw 'Task registration has no explicit Settings.Enabled boolean.'
            }
            $lastRunUtc = $null
            if ($null -ne $taskInfo.LastRunTime) {
                $lastRunUtc = ([datetimeoffset]$taskInfo.LastRunTime.ToUniversalTime()).ToString('o')
            }
            $taskRows += [pscustomobject][ordered]@{
                task_name = $taskName
                present = $true
                enabled = [bool]$task.Settings.Enabled
                state = [string]$task.State
                last_run_utc = $lastRunUtc
                last_task_result = [int64]$taskInfo.LastTaskResult
                probe_error = $null
            }
        } catch {
            $taskRows += [pscustomobject][ordered]@{
                task_name = $taskName
                present = $false
                enabled = $null
                state = $null
                last_run_utc = $null
                last_task_result = $null
                probe_error = $_.Exception.Message
            }
        }
    }

    $workerRows = @()
    $pythonProcesses = @(Get-CimInstance Win32_Process `
        -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue)
    foreach ($process in $pythonProcesses) {
        if (-not (Test-QmFactoryWorkerCommandLine -CommandLine $process.CommandLine)) {
            continue
        }
        $arguments = @(Get-QmCommandLineArguments -CommandLine $process.CommandLine)
        $terminal = Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '--terminal'
        $workerRows += [pscustomobject][ordered]@{
            process_id = [int64]$process.ProcessId
            session_id = [int]$process.SessionId
            terminal = [string]$terminal
        }
    }

    return [pscustomobject][ordered]@{
        captured_at_utc = [datetimeoffset]::UtcNow.ToString('o')
        tasks = @($taskRows)
        workers = @($workerRows)
    }
}

function ConvertTo-QmFactoryHealthUtc {
    [CmdletBinding()]
    param(
        [AllowNull()]
        $Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    [datetimeoffset]$parsed = [datetimeoffset]::MinValue
    $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor `
        [System.Globalization.DateTimeStyles]::AdjustToUniversal
    if (-not [datetimeoffset]::TryParse(
        [string]$Value,
        [System.Globalization.CultureInfo]::InvariantCulture,
        $styles,
        [ref]$parsed
    )) {
        return $null
    }
    return $parsed.ToUniversalTime()
}

function Test-QmFactoryPostStartHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Snapshot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$ExpectedTaskEnabledState,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$CriticalTaskBaselines,

        [Parameter(Mandatory = $true)]
        [string[]]$CriticalTaskNames,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedWorkerTerminals,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedSessionId,

        [Parameter(Mandatory = $true)]
        [datetimeoffset]$FreshNotBeforeUtc,

        [ValidateRange(0, 30)]
        [int]$FreshnessClockSkewSeconds = 2
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $taskByName = @{}
    foreach ($row in @($Snapshot.tasks)) {
        $taskName = [string]$row.task_name
        if ([string]::IsNullOrWhiteSpace($taskName)) {
            [void]$errors.Add('Task snapshot contains an empty task name.')
            continue
        }
        if ($taskByName.ContainsKey($taskName)) {
            [void]$errors.Add("Task snapshot contains duplicate '$taskName'.")
            continue
        }
        $taskByName[$taskName] = $row
        if (-not $ExpectedTaskEnabledState.Contains($taskName)) {
            [void]$errors.Add("Task snapshot contains unexpected '$taskName'.")
        }
    }

    foreach ($taskName in @($ExpectedTaskEnabledState.Keys)) {
        if (-not $taskByName.ContainsKey([string]$taskName)) {
            [void]$errors.Add("Expected task '$taskName' is missing from the snapshot.")
            continue
        }
        $row = $taskByName[[string]$taskName]
        if (-not [string]::IsNullOrWhiteSpace([string]$row.probe_error)) {
            [void]$errors.Add("Expected task '$taskName' probe failed: $($row.probe_error)")
            continue
        }
        if ($row.present -isnot [bool] -or -not [bool]$row.present) {
            [void]$errors.Add("Expected task '$taskName' is not registered or could not be probed.")
            continue
        }
        if ($row.enabled -isnot [bool]) {
            [void]$errors.Add("Expected task '$taskName' has no explicit enabled state.")
            continue
        }
        $expectedEnabled = [bool]$ExpectedTaskEnabledState[$taskName]
        if ([bool]$row.enabled -ne $expectedEnabled) {
            [void]$errors.Add(
                "Task '$taskName' enabled-state mismatch: expected=$expectedEnabled actual=$([bool]$row.enabled)."
            )
        }
    }

    $freshFloor = $FreshNotBeforeUtc.ToUniversalTime().AddSeconds(-$FreshnessClockSkewSeconds)
    foreach ($criticalTaskName in $CriticalTaskNames) {
        if (-not $ExpectedTaskEnabledState.Contains($criticalTaskName) -or
            -not [bool]$ExpectedTaskEnabledState[$criticalTaskName]) {
            [void]$errors.Add("Critical task '$criticalTaskName' is not expected to be enabled.")
            continue
        }
        if (-not $taskByName.ContainsKey($criticalTaskName)) {
            continue
        }
        $row = $taskByName[$criticalTaskName]
        if ($row.present -isnot [bool] -or -not [bool]$row.present) {
            continue
        }
        if ([string]$row.state -ne 'Ready') {
            [void]$errors.Add("Critical task '$criticalTaskName' is not freshly completed (state='$($row.state)').")
        }
        $lastTaskResult = 0L
        if ($null -eq $row.last_task_result -or
            -not [int64]::TryParse([string]$row.last_task_result, [ref]$lastTaskResult) -or
            $lastTaskResult -ne 0) {
            [void]$errors.Add("Critical task '$criticalTaskName' does not have a successful result.")
        }

        $lastRunUtc = ConvertTo-QmFactoryHealthUtc -Value $row.last_run_utc
        if ($null -eq $lastRunUtc) {
            [void]$errors.Add("Critical task '$criticalTaskName' has no parseable last-run timestamp.")
            continue
        }
        if ($lastRunUtc -lt $freshFloor) {
            [void]$errors.Add("Critical task '$criticalTaskName' last run predates this restart window.")
        }
        if (-not $CriticalTaskBaselines.Contains($criticalTaskName)) {
            [void]$errors.Add("Critical task '$criticalTaskName' has no pre-start baseline.")
            continue
        }
        $baselineUtc = ConvertTo-QmFactoryHealthUtc -Value $CriticalTaskBaselines[$criticalTaskName]
        if ($null -eq $baselineUtc) {
            [void]$errors.Add("Critical task '$criticalTaskName' baseline is not parseable.")
        } elseif ($lastRunUtc -le $baselineUtc) {
            [void]$errors.Add("Critical task '$criticalTaskName' has not advanced beyond its pre-start baseline.")
        }
    }

    $expectedTerminalSet = @{}
    foreach ($terminal in $ExpectedWorkerTerminals) {
        if ($terminal -notmatch '(?i)\AT(?:[1-9]|10)\z') {
            [void]$errors.Add("Expected worker terminal '$terminal' is invalid.")
            continue
        }
        if ($expectedTerminalSet.ContainsKey($terminal)) {
            [void]$errors.Add("Expected worker terminal '$terminal' is duplicated.")
            continue
        }
        $expectedTerminalSet[$terminal] = $true
    }

    $workerByTerminal = @{}
    foreach ($worker in @($Snapshot.workers)) {
        $terminal = [string]$worker.terminal
        if ($terminal -notmatch '(?i)\AT(?:[1-9]|10)\z') {
            [void]$errors.Add("Worker PID '$($worker.process_id)' has an invalid terminal identity.")
            continue
        }
        if ($workerByTerminal.ContainsKey($terminal)) {
            [void]$errors.Add("Worker terminal '$terminal' is duplicated.")
            continue
        }
        $workerByTerminal[$terminal] = $worker
        if (-not $expectedTerminalSet.ContainsKey($terminal)) {
            [void]$errors.Add("Unexpected worker terminal '$terminal' is visible.")
        }
        $sessionId = -1
        if (-not [int]::TryParse([string]$worker.session_id, [ref]$sessionId) -or
            $sessionId -ne $ExpectedSessionId) {
            [void]$errors.Add(
                "Worker terminal '$terminal' is not in interactive session $ExpectedSessionId."
            )
        }
    }
    foreach ($terminal in @($expectedTerminalSet.Keys)) {
        if (-not $workerByTerminal.ContainsKey($terminal)) {
            [void]$errors.Add("Expected worker terminal '$terminal' is not visible.")
        }
    }

    return [pscustomobject][ordered]@{
        healthy = ($errors.Count -eq 0)
        errors = @($errors)
        expected_task_count = $ExpectedTaskEnabledState.Count
        observed_task_count = @($Snapshot.tasks).Count
        expected_worker_count = $expectedTerminalSet.Count
        observed_worker_count = @($Snapshot.workers).Count
        snapshot_captured_at_utc = [string]$Snapshot.captured_at_utc
    }
}

function Wait-QmFactoryPostStartHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$ExpectedTaskEnabledState,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$CriticalTaskBaselines,

        [Parameter(Mandatory = $true)]
        [string[]]$CriticalTaskNames,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedWorkerTerminals,

        [Parameter(Mandatory = $true)]
        [int]$ExpectedSessionId,

        [Parameter(Mandatory = $true)]
        [datetimeoffset]$FreshNotBeforeUtc,

        [ValidateRange(1, 1800)]
        [int]$TimeoutSeconds = 300,

        [ValidateRange(1, 60)]
        [int]$PollSeconds = 2,

        [scriptblock]$SnapshotProbe,
        [scriptblock]$UtcNowProbe,
        [scriptblock]$SleepProbe
    )

    if ($null -eq $SnapshotProbe) {
        $SnapshotProbe = {
            param([string[]]$TaskNames)
            Get-QmFactoryPostStartSnapshot -TaskNames $TaskNames
        }
    }
    if ($null -eq $UtcNowProbe) {
        $UtcNowProbe = { [datetimeoffset]::UtcNow }
    }
    if ($null -eq $SleepProbe) {
        $SleepProbe = {
            param([int]$Seconds)
            Start-Sleep -Seconds $Seconds
        }
    }

    $startedAt = [datetimeoffset](& $UtcNowProbe)
    $deadline = $startedAt.AddSeconds($TimeoutSeconds)
    $lastAssessment = $null
    $taskNames = @($ExpectedTaskEnabledState.Keys | ForEach-Object { [string]$_ })
    while ($true) {
        $snapshot = & $SnapshotProbe -TaskNames $taskNames
        $lastAssessment = Test-QmFactoryPostStartHealth `
            -Snapshot $snapshot `
            -ExpectedTaskEnabledState $ExpectedTaskEnabledState `
            -CriticalTaskBaselines $CriticalTaskBaselines `
            -CriticalTaskNames $CriticalTaskNames `
            -ExpectedWorkerTerminals $ExpectedWorkerTerminals `
            -ExpectedSessionId $ExpectedSessionId `
            -FreshNotBeforeUtc $FreshNotBeforeUtc
        if ($lastAssessment.healthy) {
            return $lastAssessment
        }

        $now = [datetimeoffset](& $UtcNowProbe)
        if ($now -ge $deadline) {
            $details = @($lastAssessment.errors) -join '; '
            throw "Factory post-start health gate timed out after $TimeoutSeconds seconds: $details"
        }
        & $SleepProbe -Seconds $PollSeconds
    }
}
