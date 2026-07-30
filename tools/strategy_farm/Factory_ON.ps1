param([switch]$NoPause)

# =====================================================================
#  QuantMechanica - Factory ON (interactive / visible mode)
#
#  MNT-052 contract: require a verified OFF record, drain/validate while the
#  interlock is asserted, then release into one guarded repair/start window.
#  T_Live/FTMO task state, terminals and AutoTrading are never changed here.
# =====================================================================

$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $reArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($NoPause) { $reArgs += '-NoPause' }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $reArgs
    exit
}

$ErrorActionPreference = 'Stop'
$processScopePath = Join-Path $PSScriptRoot 'factory_process_scope.ps1'
try {
    $script:QmFactoryProcessScopeVersion = $null
    if (-not (Test-Path -LiteralPath $processScopePath -PathType Leaf)) {
        throw "Required process-scope guard is missing: $processScopePath"
    }
    . $processScopePath
    if ($script:QmFactoryProcessScopeVersion -ne 2) {
        throw 'Process-scope guard version mismatch.'
    }
    foreach ($requiredFunction in @(
        'Test-QmFactoryMt5ImagePath',
        'Test-QmFactoryWorkerCommandLine',
        'Test-QmFactoryRunSmokeCommandLine',
        'Test-QmFactoryPhaseRunnerCommandLine',
        'Get-QmFactoryPhaseRunnerClassification',
        'Get-QmCommandLineSha256',
        'Get-QmCommandLineArguments',
        'Get-QmUniqueCommandLineOptionValue'
    )) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Process-scope guard lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY ON ABORTED before mutation: process-scope guard failed: $($_.Exception.Message)"
}
$restartHealthPath = Join-Path $PSScriptRoot 'factory_restart_health.ps1'
try {
    $script:QmFactoryRestartHealthProtocolVersion = $null
    if (-not (Test-Path -LiteralPath $restartHealthPath -PathType Leaf)) {
        throw "Required post-start health gate is missing: $restartHealthPath"
    }
    . $restartHealthPath
    if ($script:QmFactoryRestartHealthProtocolVersion -ne 1) {
        throw 'Post-start health-gate protocol version mismatch.'
    }
    foreach ($requiredFunction in @(
        'Add-QmExpectedTaskEnabledState',
        'Get-QmFactoryPostStartSnapshot',
        'Test-QmFactoryPostStartHealth',
        'Wait-QmFactoryPostStartHealth'
    )) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Post-start health gate lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY ON ABORTED before mutation: post-start health gate failed: $($_.Exception.Message)"
}
$mutationLockProtocolPath = Join-Path $PSScriptRoot 'factory_mutation_lock.ps1'
try {
    $script:QmFactoryMutationLockProtocolVersion = $null
    if (-not (Test-Path -LiteralPath $mutationLockProtocolPath -PathType Leaf)) {
        throw "Required mutation-lock protocol is missing: $mutationLockProtocolPath"
    }
    . $mutationLockProtocolPath
    if ($script:QmFactoryMutationLockProtocolVersion -ne 2) {
        throw 'Mutation-lock protocol version mismatch.'
    }
    if (-not (Get-Command -Name 'Remove-QmFactoryMutationLockIfUnchanged' `
        -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Mutation-lock protocol lacks exact-identity release.'
    }
} catch {
    throw "FACTORY ON ABORTED before mutation: mutation-lock protocol failed: $($_.Exception.Message)"
}
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$factoryMutationLockPath = 'D:\QM\strategy_farm\state\FACTORY_MUTATION.lock'
$codexParallelPath = 'D:\QM\strategy_farm\state\codex_parallel.txt'
$watchdogResetBlockPath = 'D:\QM\strategy_farm\state\WATCHDOG_RESET_PENDING.json'
$disabledTerminalsPath = 'D:\QM\strategy_farm\state\disabled_terminals.txt'
$pythonExe = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$pacerScript = Join-Path $PSScriptRoot 'codex_fleet_pacer.py'
$maintenanceControlScript = Join-Path $PSScriptRoot 'maintenance_control.py'
$factoryPostStartHealthTimeoutSeconds = 300

$QM_RESPAWN_TASKS = @(
    'QM_StrategyFarm_FactoryWatchdog_15min',
    'QM_StrategyFarm_FactoryON_AtLogon',
    'QM_StrategyFarm_ReconcileOrphans_Hourly'
)
$QM_QUIESCENCE_TASKS = @(
    'QM_CodexParallel_RestoreOnReset',
    'QM_ClaudeParallel_RestoreOnReset',
    'QM_NewsCalendar_Refresh',
    'QM_Repo_Push',
    'QM_StrategyFarm_AgyGovernor',
    'QM_StrategyFarm_CodexFleetPacer',
    'QM_StrategyFarm_FactoryRecycle_Daily',
    'QM_StrategyFarm_SweepEnqueue_Hourly',
    'QM_StrategyFarm_MailboxSourceIntake_Daily',
    'QM_StrategyFarm_InboxCleanup_Daily',
    'QM_StrategyFarm_PlausibilityScan',
    'QM_StrategyFarm_QuotaGovernor',
    'QM_StrategyFarm_REvalDrain_15min',
    'QM_StrategyFarm_ReportsLogPurge_12h',
    'QM_StrategyFarm_SourcingIntakeSweep',
    'QM_Public_Snapshot_Hourly',
    'QM_StrategyFarm_TesterCachePurge',
    'QM_StrategyFarm_WorkerDedupe',
    'QM_StrategyFarm_WorktreeClean_4h',
    'QM_StrategyFarm_HourlyMonitor_60min',
    'QM_WorkItemLogPruner_Daily_0310'
)
$QM_LIVE_TASKS = @(
    'QM_T_Live_AtLogon',
    'QM_FTMO_AtLogon',
    'QM_Live_MT5_SessionSupervisor',
    'QM_T_Live_Watchdog',
    'QM_StrategyFarm_LiveBookPulse',
    'QM_FTMO_TrialPulse',
    'QM_StrategyFarm_LsmHealthProbe'
)
$QM_CRITICAL_POST_START_TASKS = @(
    'QM_StrategyFarm_QuotaPull',
    'QM_StrategyFarm_AgentRouter_5min',
    'QM_StrategyFarm_Pump_5min'
)
$managedTasks = @($QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS + $QM_QUIESCENCE_TASKS |
    Sort-Object -Unique)

function ConvertTo-ExactTaskEnabledState {
    param(
        [Parameter(Mandatory = $true)]$State,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTasks,
        [Parameter(Mandatory = $true)][string]$SourceLabel
    )
    $properties = @($State.PSObject.Properties)
    $names = @($properties | ForEach-Object { [string]$_.Name })
    $missing = @($ExpectedTasks | Where-Object { $_ -notin $names })
    $extra = @($names | Where-Object { $_ -notin $ExpectedTasks })
    if ($missing.Count -ne 0 -or $extra.Count -ne 0 -or $names.Count -ne $ExpectedTasks.Count) {
        throw ("{0} task key-set mismatch: missing=[{1}] extra=[{2}]" -f `
            $SourceLabel,($missing -join ','),($extra -join ','))
    }
    $normalized = [ordered]@{}
    foreach ($taskName in $ExpectedTasks) {
        $property = $State.PSObject.Properties[$taskName]
        if ($null -eq $property -or $property.Value -isnot [bool]) {
            throw "$SourceLabel task '$taskName' must have an explicit boolean value"
        }
        $normalized[$taskName] = [bool]$property.Value
    }
    return $normalized
}

function Write-FactoryOffRecord([System.Collections.IDictionary]$Record) {
    $parent = Split-Path -Parent $factoryOffFlagPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $tmp = "$factoryOffFlagPath.$PID.tmp"
    try {
        $Record | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $factoryOffFlagPath -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Get-FactoryProcessSnapshot {
    $pythonProcesses = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue)
    $phaseRunners = @()
    $reviewRequired = @()
    foreach ($process in $pythonProcesses) {
        $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $process.CommandLine
        if ($classification.Disposition -eq 'FACTORY_OWNED') {
            $phaseRunners += $process
        } elseif ($classification.Disposition -eq 'REVIEW_REQUIRED') {
            $reviewRequired += [pscustomobject]@{
                ProcessId = $process.ProcessId
                ParentProcessId = $process.ParentProcessId
                CommandLineSha256 = Get-QmCommandLineSha256 -CommandLine ([string]$process.CommandLine)
                MatcherReason = $classification.MatcherReason
            }
        }
    }
    return [ordered]@{
        daemons = @($pythonProcesses |
            Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
        phase_runners = @($phaseRunners)
        review_required = @($reviewRequired)
        wrappers = @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { Test-QmFactoryRunSmokeCommandLine -CommandLine $_.CommandLine })
        terminals = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
            Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'terminal64.exe' })
        testers = @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue |
            Where-Object { Test-QmFactoryMt5ImagePath -Path $_.ExecutablePath -ImageName 'metatester64.exe' })
    }
}

function Stop-FactoryProcesses {
    $snapshot = Get-FactoryProcessSnapshot
    if ($snapshot.review_required.Count -gt 0) {
        throw "FACTORY ON ABORTED: REVIEW_REQUIRED phase-runner near-matches exist; no ambiguous process was reaped."
    }
    foreach ($process in @($snapshot.phase_runners + $snapshot.daemons + $snapshot.wrappers + $snapshot.terminals + $snapshot.testers)) {
        Stop-Process -Id $process.ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Enter-FactoryMutationLock([string]$Owner) {
    $lockStream = $null
    try {
        try {
            $lockStream = [System.IO.File]::Open(
                $factoryMutationLockPath,
                [System.IO.FileMode]::CreateNew,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::Read
            )
        } catch [System.IO.IOException] {
            throw "factory mutation lock became busy: $factoryMutationLockPath"
        }
        $script:factoryMutationLockNonce = [guid]::NewGuid().ToString('N')
        $record = [ordered]@{
            pid = $PID
            owner = $Owner
            nonce = $script:factoryMutationLockNonce
            created_at = [datetime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($record)
        $script:factoryMutationLockRecordBytesBase64 = [Convert]::ToBase64String($bytes)
        $lockStream.Write($bytes, 0, $bytes.Length)
        $lockStream.Flush($true)
        return $lockStream
    } catch {
        if ($null -ne $lockStream) {
            $lockStream.Dispose()
            if (-not [string]::IsNullOrWhiteSpace(
                [string]$script:factoryMutationLockRecordBytesBase64
            )) {
                Remove-QmFactoryMutationLockIfUnchanged `
                    -Path $factoryMutationLockPath `
                    -ExpectedRawBytesBase64 $script:factoryMutationLockRecordBytesBase64 | Out-Null
            }
        }
        throw
    }
}

function Exit-FactoryMutationLock([object]$LockStream) {
    if ($null -ne $LockStream) {
        $LockStream.Dispose()
        $releasedExactLock = Remove-QmFactoryMutationLockIfUnchanged `
            -Path $factoryMutationLockPath `
            -ExpectedRawBytesBase64 $script:factoryMutationLockRecordBytesBase64
        if (-not $releasedExactLock) {
            Write-Warning `
                'Factory mutation lock release retained a changed/unreadable record fail-closed.'
        }
        return $releasedExactLock
    }
    return $true
}

function Invoke-RepairWithMutationLock {
    if ($null -eq $script:factoryRestartMutationLock) {
        throw 'factory restart mutation lock is not held'
    }
    & $pythonExe (Join-Path $PSScriptRoot 'farmctl.py') repair | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "farmctl repair failed with exit code $LASTEXITCODE"
    }
}

function Invoke-RestartHoldReleaseWithMutationLock {
    if ($null -eq $script:factoryRestartMutationLock -or
        [string]::IsNullOrWhiteSpace([string]$script:factoryMutationLockNonce)) {
        throw 'factory restart mutation lock identity is not held'
    }
    if (-not (Test-Path -LiteralPath $maintenanceControlScript -PathType Leaf)) {
        throw "maintenance-control helper missing: $maintenanceControlScript"
    }
    $releaseOutput = @(& $pythonExe $maintenanceControlScript `
        --db 'D:\QM\strategy_farm\state\farm_state.sqlite' `
        --factory-off-flag $factoryOffFlagPath `
        release-on-restart --apply `
        --release-note 'coordinated Factory_ON all-components restart gate passed' `
        --held-lock-owner-pid $PID `
        --held-lock-owner 'factory_on_restart_window' `
        --held-lock-nonce $script:factoryMutationLockNonce)
    $releaseExitCode = $LASTEXITCODE
    if ($releaseExitCode -ne 0) {
        throw "maintenance restart-hold release failed with exit code $releaseExitCode"
    }
    Write-Host ($releaseOutput -join [Environment]::NewLine)
}

function Invoke-FailClosedRollback([string]$Reason, [object]$PriorOffRecord) {
    $rollback = [ordered]@{
        schema_version = 2
        state = 'OFF_RECOVERY_REQUIRED'
        off_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        updated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
        codex_parallel_before = '0'
        rollback_reason = $Reason
    }
    if ($null -ne $PriorOffRecord) {
        if ($PriorOffRecord.off_at) { $rollback['off_at'] = [string]$PriorOffRecord.off_at }
        if ($null -ne $PriorOffRecord.codex_parallel_before) {
            $rollback['codex_parallel_before'] = [string]$PriorOffRecord.codex_parallel_before
        }
        if ($null -ne $PriorOffRecord.task_enabled_before) {
            $rollback['task_enabled_before'] = $PriorOffRecord.task_enabled_before
        }
    }
    Write-FactoryOffRecord $rollback
    Set-Content -LiteralPath $codexParallelPath -Value '0' -Encoding ASCII -ErrorAction SilentlyContinue
    foreach ($taskName in $managedTasks) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
        Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
    }
    Stop-FactoryProcesses
    if ((Test-Path -LiteralPath $pythonExe -PathType Leaf) -and (Test-Path -LiteralPath $pacerScript -PathType Leaf)) {
        & $pythonExe $pacerScript 2>&1 | Out-Null
    }
}

$disabledTerminals = @()
if (Test-Path -LiteralPath $disabledTerminalsPath) {
    $disabledTerminalRows = @(Get-Content -LiteralPath $disabledTerminalsPath -ErrorAction Stop |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $invalidDisabledTerminals = @($disabledTerminalRows |
        Where-Object { $_ -notmatch '(?i)^T(?:[1-9]|10)$' })
    if ($invalidDisabledTerminals.Count -ne 0) {
        throw "FACTORY ON ABORTED before mutation: invalid disabled-terminal rows: $($invalidDisabledTerminals -join ', ')"
    }
    $disabledTerminals = @($disabledTerminalRows |
        ForEach-Object { $_.ToUpperInvariant() })
    $duplicateDisabledTerminals = @($disabledTerminals | Group-Object |
        Where-Object { $_.Count -ne 1 } | ForEach-Object { $_.Name })
    if ($duplicateDisabledTerminals.Count -ne 0) {
        throw "FACTORY ON ABORTED before mutation: duplicate disabled terminals: $($duplicateDisabledTerminals -join ', ')"
    }
}
$expectedWorkerTerminals = @(1..10 | ForEach-Object { "T$_" } |
    Where-Object { $_ -notin $disabledTerminals })
$expectWorkers = $expectedWorkerTerminals.Count
if ($expectWorkers -lt 1) {
    throw 'FACTORY ON ABORTED before mutation: no Factory worker terminal is enabled.'
}
$mySession = (Get-Process -Id $PID).SessionId

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ("  QuantMechanica  -  FACTORY ON  (session {0}, visible)" -f $mySession) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

$offRecord = $null
if (Test-Path -LiteralPath $factoryOffFlagPath) {
    try {
        $offRecord = Get-Content -LiteralPath $factoryOffFlagPath -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        throw "FACTORY ON ABORTED: FACTORY_OFF.flag is not valid JSON: $($_.Exception.Message)"
    }
} else {
    $snapshot = Get-FactoryProcessSnapshot
    $requiredTaskDrift = @(@($QM_FACTORY_TASKS + $QM_AI_TASKS) | Where-Object {
        $task = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
        $null -eq $task -or $task.State -eq 'Disabled'
    })
    if ($snapshot.daemons.Count -ge $expectWorkers -and $requiredTaskDrift.Count -eq 0) {
        Write-Host ("  FACTORY ALREADY ON - {0}/{1} worker daemons; no action taken." -f $snapshot.daemons.Count,$expectWorkers) -ForegroundColor Green
        if (-not $NoPause) { Read-Host 'Press Enter to close' }
        exit 0
    }
    throw 'FACTORY ON ABORTED: interlock absent but factory is not verifiably ON. Run Factory_OFF first to establish a clean restart contract.'
}

$offSchema = 0
try { $offSchema = [int]$offRecord.schema_version } catch {}
$offState = [string]$offRecord.state
if ($offSchema -ne 2 -or $offState -ne 'OFF' -or $null -eq $offRecord.task_enabled_before) {
    throw ("FACTORY ON ABORTED: verified schema-v2 OFF record required " +
        "(found schema=$offSchema state='$offState'). A legacy-v1 flag may only be upgraded via " +
        "Factory_OFF.ps1 -RestoreIntentManifest <OWNER-approved.json>; start from " +
        "factory_restore_intent.v1.template.json. Current task state must not be inferred as pre-OFF intent.")
}
$taskEnabledBefore = ConvertTo-ExactTaskEnabledState `
    -State $offRecord.task_enabled_before `
    -ExpectedTasks $QM_QUIESCENCE_TASKS `
    -SourceLabel 'schema-v2 FACTORY_OFF.flag'

$expectedTaskEnabledState = [ordered]@{}
foreach ($taskName in @($QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS |
    Sort-Object -Unique)) {
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled $true
}
foreach ($taskName in $QM_QUIESCENCE_TASKS) {
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled ([bool]$taskEnabledBefore[$taskName])
}
foreach ($taskName in $QM_ENFORCE_DISABLED_TASKS) {
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled $false
}
foreach ($taskName in $QM_ALWAYSON_TASKS) {
    if ($taskName -in $QM_LIVE_TASKS -or $taskName -in $QM_QUIESCENCE_TASKS) { continue }
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled $true
}
$invalidExpectedTaskRegistrations = @(@($expectedTaskEnabledState.Keys) | Where-Object {
    @(Get-ScheduledTask -TaskName ([string]$_) -ErrorAction SilentlyContinue).Count -ne 1
})
if ($invalidExpectedTaskRegistrations.Count -gt 0) {
    throw ("FACTORY ON ABORTED before mutation: expected scheduled-task registration " +
        "cardinality is not exactly one: $($invalidExpectedTaskRegistrations -join ', ')")
}
if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
    throw "FACTORY ON ABORTED before mutation: Python executable missing: $pythonExe"
}
if (Test-Path -LiteralPath $factoryMutationLockPath) {
    throw "FACTORY ON ABORTED: autonomous mutation lock still exists: $factoryMutationLockPath"
}

$script:factoryRestartMutationLock = Enter-FactoryMutationLock -Owner 'factory_on_restart_window'
$released = $false
try {
    # Preflight and stale factory-process drain occur while the interlock remains
    # asserted and while the same lock used by maintenance one-shots is held.
    # The exact T1..T10 classifiers structurally exclude T_Live/FTMO.
    Stop-FactoryProcesses
    Start-Sleep -Seconds 2
    $afterDrain = Get-FactoryProcessSnapshot
    if ($afterDrain.daemons.Count -ne 0 -or $afterDrain.phase_runners.Count -ne 0 -or
        $afterDrain.wrappers.Count -ne 0 -or $afterDrain.terminals.Count -ne 0 -or
        $afterDrain.testers.Count -ne 0 -or $afterDrain.review_required.Count -ne 0) {
        throw ("FACTORY ON ABORTED: stale factory processes remain daemons={0} phase_runners={1} wrappers={2} terminals={3} testers={4} review_required={5}" -f `
            $afterDrain.daemons.Count,$afterDrain.phase_runners.Count,$afterDrain.wrappers.Count,$afterDrain.terminals.Count,$afterDrain.testers.Count,$afterDrain.review_required.Count)
    }

$codexParallelRestored = ''
if ($null -ne $offRecord.codex_parallel_before) {
    $codexParallelRestored = [string]$offRecord.codex_parallel_before
}
try {
    # Release point.  All schedulers/workers were absent up to this line; all
    # contractually enabled components are restored in this bounded block.
    Remove-Item -LiteralPath $factoryOffFlagPath -Force -ErrorAction Stop
    $released = $true

    # Repair is a DB mutator, so it may not run behind FACTORY_OFF.  Execute it
    # immediately after release, under the same global writer lock, while every
    # autonomous task and worker is still stopped.  Any failure reasserts OFF.
    Write-Host '  running farmctl repair in the guarded restart window ...'
    Invoke-RepairWithMutationLock

    if ($codexParallelRestored -match '^\d+$') {
        Set-Content -LiteralPath $codexParallelPath -Value $codexParallelRestored -Encoding ASCII
    }

    # Do not enable any autonomous scheduler until the replacement workers have
    # actually started.  This keeps a failed ON attempt side-effect-bounded and
    # prevents watchdog/pump catch-up triggers from racing the restart itself.
    foreach ($taskName in $QM_ENFORCE_DISABLED_TASKS) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -ne $task -and $task.State -ne 'Disabled') {
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
            Disable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        }
    }

    if (Test-Path -LiteralPath $watchdogResetBlockPath -ErrorAction Stop) {
        Remove-Item -LiteralPath $watchdogResetBlockPath -Force -ErrorAction Stop
    }

    & $pythonExe 'C:\QM\repo\tools\strategy_farm\start_terminal_workers.py' `
        --repo-root 'C:\QM\repo' --farm-root 'D:\QM\strategy_farm' --dedupe | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "start_terminal_workers.py failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Seconds 12

    $daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
    $inMySession = @($daemons | Where-Object { $_.SessionId -eq $mySession })
    if ($inMySession.Count -lt $expectWorkers) {
        throw "only $($inMySession.Count)/$expectWorkers worker daemons started in interactive session $mySession"
    }

    $criticalTaskBaselines = [ordered]@{}
    foreach ($taskName in $QM_CRITICAL_POST_START_TASKS) {
        $taskMatches = @(Get-ScheduledTask -TaskName $taskName -ErrorAction Stop)
        if ($taskMatches.Count -ne 1) {
            throw "Critical task '$taskName' registration cardinality changed during restart."
        }
        $taskInfo = Get-ScheduledTaskInfo -InputObject $taskMatches[0] -ErrorAction Stop
        $baselineLastRunUtc = [datetimeoffset]::MinValue
        if ($null -ne $taskInfo.LastRunTime) {
            $baselineLastRunUtc = [datetimeoffset]$taskInfo.LastRunTime.ToUniversalTime()
        }
        $criticalTaskBaselines[$taskName] = $baselineLastRunUtc.ToString('o')
    }
    $criticalTasksStartedAtUtc = [datetimeoffset]::UtcNow

    foreach ($taskName in @(@($QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS) | Sort-Object -Unique)) {
        Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
    }

    foreach ($taskName in $QM_QUIESCENCE_TASKS) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -eq $task) { continue }
        # Missing state is fail-closed: a task introduced after OFF must not be
        # silently enabled by ON without an explicit captured operator state.
        $shouldEnable = $false
        if ($taskEnabledBefore.ContainsKey($taskName)) { $shouldEnable = [bool]$taskEnabledBefore[$taskName] }
        if ($shouldEnable) {
            Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        } else {
            Disable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        }
    }

    # Keep read-only support online, but never mutate any live-task state.
    foreach ($taskName in $QM_ALWAYSON_TASKS) {
        if ($taskName -in $QM_LIVE_TASKS -or $taskName -in $QM_QUIESCENCE_TASKS) { continue }
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -ne $task -and $task.State -eq 'Disabled') {
            Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        }
    }

    Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaPull' -ErrorAction Stop
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_AgentRouter_5min' -ErrorAction Stop
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction Stop

    $postStartHealth = Wait-QmFactoryPostStartHealth `
        -ExpectedTaskEnabledState $expectedTaskEnabledState `
        -CriticalTaskBaselines $criticalTaskBaselines `
        -CriticalTaskNames $QM_CRITICAL_POST_START_TASKS `
        -ExpectedWorkerTerminals $expectedWorkerTerminals `
        -ExpectedSessionId $mySession `
        -FreshNotBeforeUtc $criticalTasksStartedAtUtc `
        -TimeoutSeconds $factoryPostStartHealthTimeoutSeconds
    Write-Host ("  post-start health gate passed: {0} tasks, {1} workers." -f `
        $postStartHealth.observed_task_count,$postStartHealth.observed_worker_count)

    # The held cohort is released only after every contractually enabled
    # worker/task is healthy.  Non-release quarantine holds remain active; the
    # completed QM5_13301/T6 hold has already been released independently.  The
    # child authenticates this exact
    # restart-window lock by PID, owner and nonce; there is no generic bypass.
    Invoke-RestartHoldReleaseWithMutationLock

    Write-Host ("  FACTORY STARTED - {0}/{1} daemons live in session {2}." -f $inMySession.Count,$expectWorkers,$mySession) -ForegroundColor Green
        Write-Host '  Factory-owned scheduled components were released in one restart window.'
    } catch {
        $failure = $_.Exception.Message
        if ($released) {
            Invoke-FailClosedRollback -Reason $failure -PriorOffRecord $offRecord
        }
        throw "FACTORY ON FAILED CLOSED: $failure"
    }
} finally {
    $script:factoryRestartMutationLockReleased = `
        Exit-FactoryMutationLock -LockStream $script:factoryRestartMutationLock
    $script:factoryRestartMutationLock = $null
    $script:factoryMutationLockNonce = $null
    $script:factoryMutationLockRecordBytesBase64 = $null
    if (-not $script:factoryRestartMutationLockReleased) {
        $releaseFailure = `
            'exact mutation-lock identity release failed; retained lock requires OWNER inspection'
        if ($released) {
            try {
                Invoke-FailClosedRollback -Reason $releaseFailure -PriorOffRecord $offRecord
            } catch {
                throw ("FACTORY ON FAILED CLOSED: {0}; rollback also failed: {1}" -f `
                    $releaseFailure,$_.Exception.Message)
            }
        }
        throw "FACTORY ON FAILED CLOSED: $releaseFailure"
    }
}

if (Test-Path -LiteralPath $disabledTerminalsPath) {
    $extraDisabled = @(Get-Content -LiteralPath $disabledTerminalsPath -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -match '^T(?:[1-9]|10)$' -and $_ -notin @('T8','T9','T10') })
    if ($extraDisabled.Count -gt 0) {
        Write-Host ("  WARNING: non-standard disabled terminals: {0}" -f ($extraDisabled -join ', ')) -ForegroundColor Yellow
    }
}

Write-Host '  T_Live/FTMO task state, live terminals and AutoTrading were not touched.'
Write-Host '  RDP disconnect is safe; explicit LOGOFF still terminates interactive factory workers.'
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
