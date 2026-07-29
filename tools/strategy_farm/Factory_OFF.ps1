param(
    [switch]$NoPause,
    [string]$RestoreIntentManifest
)

# =====================================================================
#  QuantMechanica - Factory OFF
#
#  MNT-052 contract: assert the software interlock first, then drain every
#  autonomous factory/repo/DB mutator.  Read-only dashboards, health and live
#  telemetry stay online.  T_Live/FTMO tasks, terminals and AutoTrading are
#  outside this script's mutation scope.
# =====================================================================

function ConvertTo-QmSingleQuotedLiteral([string]$Value) {
    return "'" + $Value.Replace("'", "''") + "'"
}

function Get-QmFileSha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
    } finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Encode the whole invocation so a manifest path containing whitespace or
    # PowerShell metacharacters cannot be split/reinterpreted during elevation.
    $elevatedInvocation = '& ' + (ConvertTo-QmSingleQuotedLiteral $PSCommandPath)
    if ($NoPause) { $elevatedInvocation += ' -NoPause' }
    if ($PSBoundParameters.ContainsKey('RestoreIntentManifest')) {
        $elevatedInvocation += ' -RestoreIntentManifest ' + `
            (ConvertTo-QmSingleQuotedLiteral ([string]$RestoreIntentManifest))
    }
    $encodedInvocation = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($elevatedInvocation)
    )
    Start-Process -FilePath 'powershell.exe' -Verb RunAs `
        -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encodedInvocation)
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
        'Test-QmStableFactoryNullScans'
    )) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Process-scope guard lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY OFF ABORTED before mutation: process-scope guard failed: $($_.Exception.Message)"
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
    foreach ($requiredFunction in @(
        'Read-QmFactoryMutationLockSnapshot',
        'Get-QmFactoryMutationLockOwnerState',
        'Remove-QmFactoryMutationLockIfUnchanged',
        'Wait-QmFactoryMutationLockDrain'
    )) {
        if (-not (Get-Command -Name $requiredFunction -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Mutation-lock protocol lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY OFF ABORTED before mutation: mutation-lock protocol failed: $($_.Exception.Message)"
}
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$factoryMutationLockPath = 'D:\QM\strategy_farm\state\FACTORY_MUTATION.lock'
$codexParallelPath = 'D:\QM\strategy_farm\state\codex_parallel.txt'
$pythonExe = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$pacerScript = Join-Path $PSScriptRoot 'codex_fleet_pacer.py'
$restoreIntentValidatorPath = Join-Path $PSScriptRoot 'factory_restore_intent.py'
$restoreIntentTemplatePath = Join-Path $PSScriptRoot 'factory_restore_intent.v1.template.json'
$mnt046EvidenceDirectory = 'D:\QM\reports\maintenance\factory_off'
$mnt046EvidencePath = Join-Path $mnt046EvidenceDirectory `
    ("mnt046_factory_off_quiescence_{0}_{1}.json" -f ([datetime]::UtcNow.ToString('yyyyMMddTHHmmssZ')),$PID)

$QM_RESPAWN_TASKS = @(
    'QM_StrategyFarm_FactoryWatchdog_15min',
    'QM_StrategyFarm_FactoryON_AtLogon',
    'QM_StrategyFarm_ReconcileOrphans_Hourly'
)

# These paths can enqueue DB work, spawn autonomous agents, change controller
# concurrency, commit/restore the canonical worktree or refresh tracked public
# data.  They are intentionally not left in the ALWAYS_ON set during OFF.
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

$managedTasks = @($QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS + $QM_QUIESCENCE_TASKS |
    Sort-Object -Unique)
# The hourly monitor deliberately exits while FACTORY_OFF is asserted, so it
# cannot enforce the permanently-disabled hazard set during the OFF window.
# Include those tasks in every OFF disable/drift pass, but never persist them in
# task_enabled_before: Factory_ON must not restore an unsafe task.
$offDisableTasks = @($managedTasks + $QM_ENFORCE_DISABLED_TASKS | Sort-Object -Unique)

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

function Get-TaskEnabled([string]$TaskName) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    return ($null -ne $task -and $task.State -ne 'Disabled')
}

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

function Wait-FactoryMutationDrain([int]$TimeoutSeconds = 60) {
    return Wait-QmFactoryMutationLockDrain `
        -Path $factoryMutationLockPath `
        -TimeoutSeconds $TimeoutSeconds
}

function Wait-QuiescenceTaskDrain([int]$TimeoutSeconds = 600) {
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $notDrained = @()
        foreach ($taskName in $QM_QUIESCENCE_TASKS) {
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            if ($null -eq $task) { continue }
            # The hourly monitor may have observed the first disable pass before
            # it exited and restored an ALWAYS_ON task.  Re-disable idle drift;
            # never force-stop a writer that is still Running/Queued.
            if ($task.State -notin @('Running','Queued') -and $task.State -ne 'Disabled') {
                Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            }
            if ($null -ne $task -and $task.State -ne 'Disabled') {
                $notDrained += $taskName
            }
        }
        if ($notDrained.Count -eq 0) {
            return [ordered]@{ drained=$true; tasks=@() }
        }
        if ([datetime]::UtcNow -ge $deadline) {
            return [ordered]@{ drained=$false; tasks=@($notDrained) }
        }
        Start-Sleep -Milliseconds 500
    } while ($true)
}

function ConvertTo-FactoryProcessEvidence {
    param(
        [Parameter(Mandatory = $true)]$Process,
        [Parameter(Mandatory = $true)][string]$ProcessClass,
        [Parameter(Mandatory = $true)][string]$MatcherReason,
        [AllowNull()]$Classification
    )

    $commandLine = [string]$Process.CommandLine
    return [ordered]@{
        process_class = $ProcessClass
        pid = [int]$Process.ProcessId
        parent_pid = [int]$Process.ParentProcessId
        image_name = [string]$Process.Name
        executable_path = [string]$Process.ExecutablePath
        command_line_sha256 = Get-QmCommandLineSha256 -CommandLine $commandLine
        matcher_reason = $MatcherReason
        phase = $(if ($null -ne $Classification) { [string]$Classification.Phase } else { $null })
        work_item_id = $(if ($null -ne $Classification) { [string]$Classification.WorkItemId } else { $null })
        terminal = $(if ($null -ne $Classification) { [string]$Classification.Terminal } else { $null })
    }
}

function Get-FactoryProcessEvidenceScan {
    $workers = @()
    $phaseRunners = @()
    $reviewRequired = @()
    $pythonProcesses = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue)
    foreach ($process in $pythonProcesses) {
        if (Test-QmFactoryWorkerCommandLine -CommandLine $process.CommandLine) {
            $workers += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'worker_daemon' `
                -MatcherReason 'exact_terminal_worker_path_terminal_and_farm_root' -Classification $null
        }
        $classification = Get-QmFactoryPhaseRunnerClassification -CommandLine $process.CommandLine
        if ($classification.Disposition -eq 'FACTORY_OWNED') {
            $phaseRunners += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'phase_runner' `
                -MatcherReason $classification.MatcherReason -Classification $classification
        } elseif ($classification.Disposition -eq 'REVIEW_REQUIRED') {
            $reviewRequired += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'review_required' `
                -MatcherReason $classification.MatcherReason -Classification $classification
        }
    }

    $wrappers = @()
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='pwsh.exe' OR Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
        if (Test-QmFactoryRunSmokeCommandLine -CommandLine $process.CommandLine) {
            $wrappers += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'smoke_wrapper' `
                -MatcherReason 'exact_run_smoke_path_and_factory_selector' -Classification $null
        }
    }

    $terminals = @()
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue)) {
        if (Test-QmFactoryMt5ImagePath -Path $process.ExecutablePath -ImageName 'terminal64.exe') {
            $terminals += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'terminal64' `
                -MatcherReason 'exact_factory_mt5_image_path' -Classification $null
        }
    }
    $testers = @()
    foreach ($process in @(Get-CimInstance Win32_Process -Filter "Name='metatester64.exe'" -ErrorAction SilentlyContinue)) {
        if (Test-QmFactoryMt5ImagePath -Path $process.ExecutablePath -ImageName 'metatester64.exe') {
            $testers += ConvertTo-FactoryProcessEvidence -Process $process -ProcessClass 'metatester64' `
                -MatcherReason 'exact_factory_mt5_image_path' -Classification $null
        }
    }
    return [pscustomobject][ordered]@{
        scanned_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        worker_daemons = @($workers)
        phase_runners = @($phaseRunners)
        smoke_wrappers = @($wrappers)
        terminal64 = @($terminals)
        metatester64 = @($testers)
        review_required = @($reviewRequired)
    }
}

function Stop-EvidencedFactoryProcesses {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$EvidenceRecords,
        [Parameter(Mandatory = $true)]
        [ValidateSet('phase_runner','worker_daemon','smoke_wrapper','terminal64','metatester64')]
        [string]$ProcessClass
    )

    $actions = @()
    foreach ($record in @($EvidenceRecords)) {
        $pidValue = [int]$record.pid
        $current = Get-CimInstance Win32_Process -Filter ("ProcessId={0}" -f $pidValue) -ErrorAction SilentlyContinue
        if ($null -eq $current) {
            $actions += [ordered]@{ pid=$pidValue; process_class=$ProcessClass; action='already_exited' }
            continue
        }
        $currentHash = Get-QmCommandLineSha256 -CommandLine ([string]$current.CommandLine)
        if (-not [string]::Equals($currentHash, [string]$record.command_line_sha256, [System.StringComparison]::OrdinalIgnoreCase)) {
            $actions += [ordered]@{ pid=$pidValue; process_class=$ProcessClass; action='identity_changed_not_reaped' }
            continue
        }
        $stillOwned = switch ($ProcessClass) {
            'phase_runner' { Test-QmFactoryPhaseRunnerCommandLine -CommandLine $current.CommandLine; break }
            'worker_daemon' { Test-QmFactoryWorkerCommandLine -CommandLine $current.CommandLine; break }
            'smoke_wrapper' { Test-QmFactoryRunSmokeCommandLine -CommandLine $current.CommandLine; break }
            'terminal64' { Test-QmFactoryMt5ImagePath -Path $current.ExecutablePath -ImageName 'terminal64.exe'; break }
            'metatester64' { Test-QmFactoryMt5ImagePath -Path $current.ExecutablePath -ImageName 'metatester64.exe'; break }
        }
        if (-not $stillOwned) {
            $actions += [ordered]@{ pid=$pidValue; process_class=$ProcessClass; action='scope_changed_not_reaped' }
            continue
        }
        Stop-Process -Id $pidValue -Force -ErrorAction SilentlyContinue
        $actions += [ordered]@{ pid=$pidValue; process_class=$ProcessClass; action='reap_requested' }
    }
    return @($actions)
}

function Wait-FactoryStableNullScans([int]$TimeoutSeconds = 20, [int]$IntervalSeconds = 2) {
    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    $allScans = @()
    $consecutiveNull = @()
    do {
        $scan = Get-FactoryProcessEvidenceScan
        $allScans += $scan
        if (Test-QmFactoryNullProcessScan -Scan $scan) {
            $consecutiveNull += $scan
            if ($consecutiveNull.Count -gt 2) {
                $consecutiveNull = @($consecutiveNull | Select-Object -Last 2)
            }
            if (Test-QmStableFactoryNullScans -Scans $consecutiveNull) {
                return [pscustomobject][ordered]@{
                    stable = $true
                    scans = @($allScans)
                    stable_null_scans = @($consecutiveNull)
                }
            }
        } else {
            $consecutiveNull = @()
        }
        if ([datetime]::UtcNow -ge $deadline) { break }
        Start-Sleep -Seconds $IntervalSeconds
    } while ($true)
    return [pscustomobject][ordered]@{
        stable = $false
        scans = @($allScans)
        stable_null_scans = @($consecutiveNull)
    }
}

function Write-Mnt046Evidence([System.Collections.IDictionary]$Evidence) {
    New-Item -ItemType Directory -Path $mnt046EvidenceDirectory -Force | Out-Null
    $tmp = "$mnt046EvidencePath.$PID.tmp"
    try {
        $Evidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $tmp -Encoding UTF8
        Move-Item -LiteralPath $tmp -Destination $mnt046EvidencePath -Force
    } finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

$existingOff = $null
if (Test-Path -LiteralPath $factoryOffFlagPath) {
    try {
        $existingOff = Get-Content -LiteralPath $factoryOffFlagPath -Raw -ErrorAction Stop | ConvertFrom-Json
    } catch {
        throw "FACTORY OFF ABORTED before mutation: existing FACTORY_OFF.flag is invalid JSON: $($_.Exception.Message)"
    }
}

$codexParallelBefore = '1'
if ($null -ne $existingOff -and $null -ne $existingOff.codex_parallel_before) {
    $codexParallelBefore = [string]$existingOff.codex_parallel_before
} else {
    try { $codexParallelBefore = (Get-Content -LiteralPath $codexParallelPath -ErrorAction Stop).Trim() } catch {}
}

$taskEnabledBefore = [ordered]@{}
$hasSavedTaskState = ($null -ne $existingOff -and $null -ne $existingOff.task_enabled_before)
$restoreIntentAudit = $null
if ($hasSavedTaskState) {
    if ($PSBoundParameters.ContainsKey('RestoreIntentManifest')) {
        throw 'FACTORY OFF ABORTED before mutation: -RestoreIntentManifest is valid only for a legacy-v1 OFF flag without saved task intent.'
    }
    $taskEnabledBefore = ConvertTo-ExactTaskEnabledState `
        -State $existingOff.task_enabled_before `
        -ExpectedTasks $QM_QUIESCENCE_TASKS `
        -SourceLabel 'existing schema-v2 FACTORY_OFF.flag'
} elseif ($null -ne $existingOff) {
    # Current Scheduled Task state is already post-OFF and cannot reconstruct
    # OWNER's pre-OFF enablement intent.  Legacy upgrade is therefore authorized
    # only by an exact, hash-bound OWNER manifest; otherwise stop before the
    # interlock, codex_parallel or any task/process mutation.
    if (-not $PSBoundParameters.ContainsKey('RestoreIntentManifest') -or
        [string]::IsNullOrWhiteSpace([string]$RestoreIntentManifest)) {
        throw ("FACTORY OFF ABORTED before mutation: legacy-v1 FACTORY_OFF.flag requires " +
            "-RestoreIntentManifest <OWNER-approved.json>. Start from '$restoreIntentTemplatePath'; " +
            'never infer restore intent from current disabled task state.')
    }
    if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        throw "FACTORY OFF ABORTED before mutation: Python validator runtime missing: $pythonExe"
    }
    if (-not (Test-Path -LiteralPath $restoreIntentValidatorPath -PathType Leaf)) {
        throw "FACTORY OFF ABORTED before mutation: restore-intent validator missing: $restoreIntentValidatorPath"
    }
    $validatorArgs = @(
        $restoreIntentValidatorPath,
        'validate',
        '--manifest', [string]$RestoreIntentManifest,
        '--legacy-flag', $factoryOffFlagPath
    )
    foreach ($taskName in $QM_QUIESCENCE_TASKS) {
        $validatorArgs += @('--expected-task', $taskName)
    }
    $priorErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $validatorOutput = @(& $pythonExe @validatorArgs 2>&1)
        $validatorExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorErrorActionPreference
    }
    if ($validatorExitCode -ne 0) {
        throw ("FACTORY OFF ABORTED before mutation: restore-intent validation failed: " +
            ($validatorOutput -join [Environment]::NewLine))
    }
    try {
        $validatedRestoreIntent = ($validatorOutput -join [Environment]::NewLine) | ConvertFrom-Json
    } catch {
        throw "FACTORY OFF ABORTED before mutation: validator returned invalid JSON: $($_.Exception.Message)"
    }
    if ($validatedRestoreIntent.validated -ne $true) {
        throw 'FACTORY OFF ABORTED before mutation: restore-intent validator did not attest validated=true.'
    }
    $taskEnabledBefore = ConvertTo-ExactTaskEnabledState `
        -State $validatedRestoreIntent.task_enabled_before `
        -ExpectedTasks $QM_QUIESCENCE_TASKS `
        -SourceLabel 'OWNER restore-intent manifest'
    $restoreIntentAudit = [ordered]@{
        schema_version = [string]$validatedRestoreIntent.schema_version
        manifest_id = [string]$validatedRestoreIntent.manifest_id
        manifest_path = [string]$validatedRestoreIntent.manifest_path
        manifest_sha256 = [string]$validatedRestoreIntent.manifest_sha256
        legacy_flag_sha256 = [string]$validatedRestoreIntent.legacy_flag_sha256
        owner_authorization = $validatedRestoreIntent.owner_authorization
    }
} else {
    if ($PSBoundParameters.ContainsKey('RestoreIntentManifest')) {
        throw 'FACTORY OFF ABORTED before mutation: -RestoreIntentManifest cannot be used for a fresh OFF transition.'
    }
    foreach ($taskName in $QM_QUIESCENCE_TASKS) {
        $taskEnabledBefore[$taskName] = [bool](Get-TaskEnabled $taskName)
    }
}

$offAt = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
if ($null -ne $existingOff -and $existingOff.off_at) { $offAt = [string]$existingOff.off_at }
$offRecord = [ordered]@{
    schema_version = 2
    state = 'OFF_IN_PROGRESS'
    off_at = $offAt
    updated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    codex_parallel_before = $codexParallelBefore
    task_enabled_before = $taskEnabledBefore
    mnt046_quiescence_evidence_path = $mnt046EvidencePath
}
if ($null -ne $restoreIntentAudit) {
    $offRecord['legacy_restore_intent'] = $restoreIntentAudit
}

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host '  QuantMechanica  -  FACTORY OFF' -ForegroundColor Yellow
Write-Host '=====================================================' -ForegroundColor Yellow
Write-Host ''

# Interlock FIRST: every participating mutator checks this before acquiring the
# global mutation lock.  OFF becomes final only after tasks/processes/lock drain.
if ($null -ne $restoreIntentAudit) {
    $currentLegacyFlagSha = Get-QmFileSha256 -Path $factoryOffFlagPath
    if (-not [string]::Equals(
        $currentLegacyFlagSha,
        [string]$restoreIntentAudit.legacy_flag_sha256,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw ("FACTORY OFF ABORTED before mutation: legacy FACTORY_OFF.flag changed after " +
            "manifest validation; expected=$($restoreIntentAudit.legacy_flag_sha256) actual=$currentLegacyFlagSha")
    }
    $currentRestoreManifestSha = Get-QmFileSha256 -Path ([string]$restoreIntentAudit.manifest_path)
    if (-not [string]::Equals(
        $currentRestoreManifestSha,
        [string]$restoreIntentAudit.manifest_sha256,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
        throw ("FACTORY OFF ABORTED before mutation: restore-intent manifest changed after " +
            "validation; expected=$($restoreIntentAudit.manifest_sha256) actual=$currentRestoreManifestSha")
    }
}
Write-FactoryOffRecord $offRecord
Set-Content -LiteralPath $codexParallelPath -Value '0' -Encoding ASCII
Write-Host ("  interlock asserted : {0}" -f $factoryOffFlagPath)
Write-Host ("  codex_parallel     : {0} -> 0" -f $codexParallelBefore)

$taskResults = @()
foreach ($taskName in $offDisableTasks) {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        $taskResults += [ordered]@{ name=$taskName; present=$false; state='Missing' }
        continue
    }
    # Disable every trigger immediately.  Core factory/respawn components may
    # be stopped now; autonomous maintenance writers are allowed to finish their
    # already-admitted bounded unit so Git/files/SQLite are never torn mid-write.
    Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
    if ($taskName -notin $QM_QUIESCENCE_TASKS -or $taskName -eq 'QM_StrategyFarm_HourlyMonitor_60min') {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
    }
    $state = (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue).State
    $taskResults += [ordered]@{ name=$taskName; present=$true; state=[string]$state }
    Write-Host ("  task disabled : {0,-48} [{1}]" -f $taskName,$state)
}

Write-Host '  waiting for admitted autonomous writers/tasks to drain ...'
$mutationDrainedBeforeCleanup = Wait-FactoryMutationDrain -TimeoutSeconds 600
$taskDrain = Wait-QuiescenceTaskDrain -TimeoutSeconds 600
if (-not $mutationDrainedBeforeCleanup -or -not $taskDrain.drained) {
    Write-Host ("  quiescence drain incomplete: writer_lock={0} running_or_enabled=[{1}]" -f `
        $mutationDrainedBeforeCleanup,(@($taskDrain.tasks) -join ',')) -ForegroundColor Red
}

# A scheduled wrapper can exit while its registered Codex child continues.
# Running the guarded pacer once behind the flag drains only farm-managed Codex
# leases; manually-started shells are not registered and remain untouched.
$pacerCleanupOk = $true
$pacerCleanupOutput = ''
if (-not $mutationDrainedBeforeCleanup -or -not $taskDrain.drained) {
    $pacerCleanupOk = $false
    $pacerCleanupOutput = 'autonomous writer/task drain incomplete; managed Codex cleanup deferred'
} elseif ((Test-Path -LiteralPath $pythonExe -PathType Leaf) -and (Test-Path -LiteralPath $pacerScript -PathType Leaf)) {
    try {
        $pacerCleanupOutput = (& $pythonExe $pacerScript 2>&1 | Out-String).Trim()
        $pacerCleanupOk = ($LASTEXITCODE -eq 0)
    } catch {
        $pacerCleanupOk = $false
        $pacerCleanupOutput = $_.Exception.Message
    }
} else {
    $pacerCleanupOk = $false
    $pacerCleanupOutput = 'pacer cleanup executable/script missing'
}
Write-Host ("  managed Codex drain : {0}" -f $(if ($pacerCleanupOk) {'OK'} else {'FAILED'}))

$beforeProcessScan = Get-FactoryProcessEvidenceScan
# MNT-046 fixed parent/child order after every respawn vector is disabled:
# phase-runner parents -> workers -> run_smoke wrappers -> MT5/tester children.
# REVIEW_REQUIRED near-matches are evidence only and are never passed here.
$phaseRunnerReap = @(Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.phase_runners -ProcessClass phase_runner)
$workerReap = @(Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.worker_daemons -ProcessClass worker_daemon)
$wrapperReap = @(Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.smoke_wrappers -ProcessClass smoke_wrapper)
Start-Sleep -Seconds 2
$terminalReap = @(Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.terminal64 -ProcessClass terminal64)
$testerReap = @(Stop-EvidencedFactoryProcesses -EvidenceRecords $beforeProcessScan.metatester64 -ProcessClass metatester64)

$mutationDrained = Wait-FactoryMutationDrain -TimeoutSeconds 60
# Bounded settling precedes the two distinct, consecutive null scans.
Start-Sleep -Seconds 2
$stableScanResult = Wait-FactoryStableNullScans -TimeoutSeconds 20 -IntervalSeconds 2
$finalProcessScan = @($stableScanResult.scans | Select-Object -Last 1)[0]
$leftDaemons = @($finalProcessScan.worker_daemons).Count
$leftPhaseRunners = @($finalProcessScan.phase_runners).Count
$leftWrappers = @($finalProcessScan.smoke_wrappers).Count
$leftTerms = @($finalProcessScan.terminal64).Count
$leftMeta = @($finalProcessScan.metatester64).Count
$reviewRequiredCount = @($finalProcessScan.review_required).Count
$taskDrift = @($offDisableTasks | Where-Object {
    $task = Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    $null -ne $task -and $task.State -ne 'Disabled'
})

$offSucceeded = (
    [bool]$stableScanResult.stable -and
    $leftDaemons -eq 0 -and $leftPhaseRunners -eq 0 -and $leftWrappers -eq 0 -and
    $leftTerms -eq 0 -and $leftMeta -eq 0 -and
    $reviewRequiredCount -eq 0 -and
    $taskDrift.Count -eq 0 -and $mutationDrained -and $pacerCleanupOk
)
$mnt046Evidence = [ordered]@{
    schema_version = 'mnt046-factory-off-quiescence/v1'
    generated_at = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    process_scope_version = $script:QmFactoryProcessScopeVersion
    phase_runner_allowlist_schema = $script:QmFactoryPhaseRunnerAllowlistSchema
    phase_runner_allowlist_path = $script:QmFactoryPhaseRunnerAllowlistPath
    phase_runner_allowlist_sha256 = (Get-FileHash -LiteralPath $script:QmFactoryPhaseRunnerAllowlistPath -Algorithm SHA256).Hash.ToLowerInvariant()
    reap_order = @('phase_runner','worker_daemon','smoke_wrapper','terminal64','metatester64')
    before = $beforeProcessScan
    reap_actions = [ordered]@{
        phase_runner = @($phaseRunnerReap)
        worker_daemon = @($workerReap)
        smoke_wrapper = @($wrapperReap)
        terminal64 = @($terminalReap)
        metatester64 = @($testerReap)
    }
    verification_scans = @($stableScanResult.scans)
    stable_null_scans = @($stableScanResult.stable_null_scans)
    stable_null_scan_count = @($stableScanResult.stable_null_scans).Count
    review_required = @($finalProcessScan.review_required)
    succeeded = [bool]$offSucceeded
}
$evidenceWritten = $false
$evidenceError = $null
try {
    Write-Mnt046Evidence $mnt046Evidence
    $evidenceWritten = Test-Path -LiteralPath $mnt046EvidencePath -PathType Leaf
} catch {
    $evidenceError = $_.Exception.Message
}
if (-not $evidenceWritten) { $offSucceeded = $false }
$offRecord['state'] = $(if ($offSucceeded) { 'OFF' } else { 'OFF_INCOMPLETE' })
$offRecord['updated_at'] = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$offRecord['verification'] = [ordered]@{
    worker_daemons = $leftDaemons
    phase_runners = $leftPhaseRunners
    smoke_wrappers = $leftWrappers
    terminal64 = $leftTerms
    metatester64 = $leftMeta
    stable_null_scans = @($stableScanResult.stable_null_scans).Count
    stable_quiescence = [bool]$stableScanResult.stable
    review_required = $reviewRequiredCount
    review_required_processes = @($finalProcessScan.review_required)
    mnt046_evidence_written = [bool]$evidenceWritten
    mnt046_evidence_error = $evidenceError
    mutation_lock_drained = [bool]$mutationDrained
    quiescence_tasks_drained = [bool]$taskDrain.drained
    quiescence_tasks_remaining = @($taskDrain.tasks)
    task_drift = @($taskDrift)
    pacer_cleanup_ok = [bool]$pacerCleanupOk
    pacer_cleanup_output = $pacerCleanupOutput
}
Write-FactoryOffRecord $offRecord

Write-Host ''
if ($offSucceeded) {
    Write-Host '  FACTORY QUIESCENT - autonomous repo/DB writers and T1-T10 are OFF.' -ForegroundColor Green
} else {
    Write-Host '  FACTORY OFF INCOMPLETE - interlock remains asserted; do not start maintenance one-shots.' -ForegroundColor Red
    Write-Host ("  daemons={0} phase_runners={1} wrappers={2} terminals={3} tester_agents={4} review_required={5} stable_null_scans={6} task_drift={7} mutation_drained={8} pacer_cleanup={9}" -f `
        $leftDaemons,$leftPhaseRunners,$leftWrappers,$leftTerms,$leftMeta,$reviewRequiredCount,@($stableScanResult.stable_null_scans).Count,$taskDrift.Count,$mutationDrained,$pacerCleanupOk) -ForegroundColor Red
}
Write-Host ("  MNT-046 evidence : {0}" -f $mnt046EvidencePath)
Write-Host '  Read-only dashboards/health/live telemetry were left alone.'
Write-Host '  T_Live, FTMO terminals, live task state and AutoTrading were not touched.'
Write-Host '  Existing manually-started AI shells were not touched.'
Write-Host ''

if (-not $NoPause) { Read-Host 'Press Enter to close' }
if (-not $offSucceeded) { exit 1 }
