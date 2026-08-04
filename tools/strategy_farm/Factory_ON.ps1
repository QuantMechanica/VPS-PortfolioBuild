param(
    [switch]$NoPause,
    [switch]$CanonicalRuntimeHost
)

# =====================================================================
#  QuantMechanica - Factory ON (interactive / visible mode)
#
#  MNT-052 contract: require a verified OFF record, drain/validate while the
#  interlock is asserted, then release into one guarded repair/start window.
#  T_Live/FTMO task state, terminals and AutoTrading are never changed here.
# =====================================================================

$bootstrapPowerShell = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$reArgs = @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",'-CanonicalRuntimeHost'
)
if ($NoPause) { $reArgs += '-NoPause' }
$pr = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath $bootstrapPowerShell -Verb RunAs -ArgumentList $reArgs
    exit
}
if (-not $CanonicalRuntimeHost) {
    $canonicalProcess = Start-Process -FilePath $bootstrapPowerShell `
        -ArgumentList $reArgs -PassThru -Wait
    exit $canonicalProcess.ExitCode
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
    foreach ($requiredFunction in @(
        'Remove-QmFileIfContentMatches',
        'Remove-QmFactoryMutationLockIfUnchanged'
    )) {
        if (-not (Get-Command -Name $requiredFunction `
            -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Mutation-lock protocol lacks required function: $requiredFunction"
        }
    }
} catch {
    throw "FACTORY ON ABORTED before mutation: mutation-lock protocol failed: $($_.Exception.Message)"
}
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$factoryOffFlagPath = 'D:\QM\strategy_farm\state\FACTORY_OFF.flag'
$factoryOffRequestPath = 'D:\QM\strategy_farm\state\FACTORY_OFF_REQUEST.flag'
$factoryMutationLockPath = 'D:\QM\strategy_farm\state\FACTORY_MUTATION.lock'
$codexParallelPath = 'D:\QM\strategy_farm\state\codex_parallel.txt'
$watchdogResetBlockPath = 'D:\QM\strategy_farm\state\WATCHDOG_RESET_PENDING.json'
$disabledTerminalsPath = 'D:\QM\strategy_farm\state\disabled_terminals.txt'
$pythonExe = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$pacerScript = Join-Path $PSScriptRoot 'codex_fleet_pacer.py'
$maintenanceControlScript = Join-Path $PSScriptRoot 'maintenance_control.py'
$runtimeActivationValidatorScript = Join-Path $PSScriptRoot 'factory_runtime_activation.py'
$farmctlScript = Join-Path $PSScriptRoot 'farmctl.py'
$publicSnapshotTaskName = 'QM_Public_Snapshot_Hourly'
$legacyPublicSnapshotTaskName = 'QM_PublicSnapshot_Export_Hourly'
$publicSnapshotTaskExecute = 'powershell.exe'
$publicSnapshotTaskWrapper = 'C:\QM\repo\scripts\run_public_snapshot_task.ps1'
$publicSnapshotTaskWorkingDirectory = 'C:\QM\repo'
$canonicalFactoryOnPath = 'C:\QM\repo\tools\strategy_farm\Factory_ON.ps1'
$canonicalFactoryOnProcessImage = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$canonicalOwnerDecisionPath = 'C:\QM\repo\docs\ops\evidence\2026-08-04_factory_preparation_owner_decision.json'
$canonicalOwnerDecisionRelativePath = 'docs/ops/evidence/2026-08-04_factory_preparation_owner_decision.json'
$QM_OWNER_DECISION_SHA256 = '834e8ef5fada6ae49d13d31781ebb64a594d3c8aa451f4b51d301fa27b67a26d'
$QM_OWNER_DECISION_COMMIT = '80c657899ba65b3545fa671a735277b8b0a850f8'
$QM_OWNER_DECISION_BLOB = 'afb0c34229c3fd0feedd305e0d51c05a16104edc'
# The Pump task is scheduler-bounded by PT10M. TaskScheduler start/finish
# evidence sampled on 2026-07-31 found 13 substantive runs: p50=550.203s,
# p75=599.982s, and five reached the 600s ceiling. First-attempt success is
# therefore unreliable under load. Span the 5-minute retry cadence while
# retaining the guarded restart window; early success exits without waiting.
$factoryPostStartHealthTimeoutSeconds = 1800
$QM_PREPARATION_DECISION_WORKER_TERMINALS = @(
    'T1','T2','T3','T4','T5','T6','T7','T8','T9','T10'
)
$QM_OWNER_APPROVED_DISABLED_TERMINALS = @(
)
$QM_OWNER_APPROVED_WORKER_TERMINALS = @(
    'T1','T2','T3','T4','T5','T6','T7','T8','T9','T10'
)
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

function Get-QmSha256Hex([byte[]]$Bytes) {
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-CanonicalDisabledTerminalPolicySnapshot {
    if (Test-Path -LiteralPath $disabledTerminalsPath) {
        if (-not (Test-Path -LiteralPath $disabledTerminalsPath -PathType Leaf)) {
            throw "disabled-terminal policy path is not a file: $disabledTerminalsPath"
        }
        try {
            $bytes = [System.IO.File]::ReadAllBytes($disabledTerminalsPath)
            $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
            $text = $strictUtf8.GetString($bytes).TrimStart([char]0xFEFF)
        } catch {
            throw "disabled-terminal policy cannot be read as exact UTF-8 bytes: $($_.Exception.Message)"
        }
    } else {
        # OWNER-approved ten-worker policy: an absent cap file is the canonical
        # empty disabled set, matching start_terminal_workers.py semantics.
        $bytes = [byte[]]::new(0)
        $text = ''
    }
    $rows = @([regex]::Split($text, '\r\n|\n|\r') |
        ForEach-Object { $_.Trim() } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $invalid = @($rows | Where-Object { $_ -notmatch '(?i)^T(?:[1-9]|10)$' })
    if ($invalid.Count -ne 0) {
        throw "invalid disabled-terminal rows: $($invalid -join ', ')"
    }
    $terminals = @($rows | ForEach-Object { $_.ToUpperInvariant() })
    $duplicates = @($terminals | Group-Object |
        Where-Object { $_.Count -ne 1 } | ForEach-Object { $_.Name })
    if ($duplicates.Count -ne 0) {
        throw "duplicate disabled terminals: $($duplicates -join ', ')"
    }
    $missing = @($QM_OWNER_APPROVED_DISABLED_TERMINALS |
        Where-Object { $_ -notin $terminals })
    $extra = @($terminals |
        Where-Object { $_ -notin $QM_OWNER_APPROVED_DISABLED_TERMINALS })
    if ($missing.Count -ne 0 -or $extra.Count -ne 0 -or
        $terminals.Count -ne $QM_OWNER_APPROVED_DISABLED_TERMINALS.Count) {
        throw ("disabled-terminal exact-set mismatch: " +
            "missing=[$($missing -join ',')] extra=[$($extra -join ',')]")
    }
    return [pscustomobject][ordered]@{
        sha256 = Get-QmSha256Hex -Bytes $bytes
        terminals = @($terminals)
    }
}

function Assert-DisabledTerminalPolicyUnchanged {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][string]$Context
    )
    $current = Get-CanonicalDisabledTerminalPolicySnapshot
    if ([string]$current.sha256 -cne $ExpectedSha256) {
        throw ("$Context disabled-terminal policy SHA-256 changed: " +
            "expected=$ExpectedSha256 actual=$($current.sha256)")
    }
    return $current
}

function Assert-CanonicalOwnerRestartDecision {
    if ([System.IO.Path]::GetFullPath($PSCommandPath) -ine $canonicalFactoryOnPath) {
        throw "canonical Factory_ON path mismatch: actual=$PSCommandPath expected=$canonicalFactoryOnPath"
    }
    if (-not (Test-Path -LiteralPath $canonicalOwnerDecisionPath -PathType Leaf)) {
        throw "canonical OWNER decision is missing: $canonicalOwnerDecisionPath"
    }
    $decisionBytes = [System.IO.File]::ReadAllBytes($canonicalOwnerDecisionPath)
    $decisionSha256 = Get-QmSha256Hex -Bytes $decisionBytes
    if ($decisionSha256 -cne $QM_OWNER_DECISION_SHA256) {
        throw ("canonical OWNER decision SHA-256 mismatch: " +
            "expected=$QM_OWNER_DECISION_SHA256 actual=$decisionSha256")
    }
    try {
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $decisionText = $strictUtf8.GetString($decisionBytes).TrimStart([char]0xFEFF)
        $decision = $decisionText | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "canonical OWNER decision JSON is invalid: $($_.Exception.Message)"
    }
    if ([string]$decision.decision_id -cne 'FACTORY_PREPARATION_20260804_TEN_WORKER_ZERO_HOLD' -or
        [string]$decision.authority -cne 'OWNER' -or
        [string]$decision.status -cne 'APPROVED') {
        throw 'canonical OWNER decision identity mismatch'
    }
    [string[]]$decisionHoldIds = @($decision.restart_holds.authorized_work_item_ids |
        ForEach-Object { [string]$_ })
    if ($decision.restart_holds.authorized_release_count -isnot [int] -or
        [int]$decision.restart_holds.authorized_release_count -ne $decisionHoldIds.Count -or
        [string]$decision.restart_holds.release_policy -cne 'ONLY_AFTER_POST_START_HEALTH_GATE_PASS') {
        throw 'canonical OWNER restart-hold metadata mismatch'
    }
    for ($index = 0; $index -lt $decisionHoldIds.Count; $index++) {
        if ([string]::IsNullOrWhiteSpace($decisionHoldIds[$index]) -or
            $decisionHoldIds[$index] -cnotmatch '^[0-9a-fA-F-]{36}$') {
            throw "canonical OWNER restart-hold ID is malformed at index $index"
        }
        for ($priorIndex = 0; $priorIndex -lt $index; $priorIndex++) {
            if ($decisionHoldIds[$priorIndex] -ceq $decisionHoldIds[$index]) {
                throw "canonical OWNER restart-hold ID is duplicated at index $index"
            }
        }
    }
    $script:approvedRestartHoldIds = [string[]]@($decisionHoldIds)
    $decisionWorkerTerminals = @($decision.worker_policy.expected_terminals |
        ForEach-Object { [string]$_ })
    if ([int]$decision.worker_policy.expected_worker_count -ne 10 -or
        $decision.worker_policy.t5_quarantine_ratified -isnot [bool] -or
        [bool]$decision.worker_policy.t5_quarantine_ratified -or
        $decision.worker_policy.t5_quarantine_lifted -isnot [bool] -or
        -not [bool]$decision.worker_policy.t5_quarantine_lifted -or
        $decisionWorkerTerminals.Count -ne $QM_PREPARATION_DECISION_WORKER_TERMINALS.Count) {
        throw 'canonical OWNER worker-policy metadata mismatch'
    }
    for ($index = 0; $index -lt $QM_PREPARATION_DECISION_WORKER_TERMINALS.Count; $index++) {
        if ($decisionWorkerTerminals[$index] -cne $QM_PREPARATION_DECISION_WORKER_TERMINALS[$index]) {
            throw "canonical OWNER worker terminal mismatch at index $index"
        }
    }
    $commitSpec = "$($QM_OWNER_DECISION_COMMIT)^{commit}"
    $resolvedCommit = @(& git -C 'C:\QM\repo' rev-parse $commitSpec 2>&1)
    if ($LASTEXITCODE -ne 0 -or $resolvedCommit.Count -ne 1 -or
        ([string]$resolvedCommit[0]).Trim() -cne $QM_OWNER_DECISION_COMMIT) {
        throw "canonical OWNER decision commit mismatch: $($resolvedCommit -join ' ')"
    }
    $blobSpec = "$($QM_OWNER_DECISION_COMMIT):$canonicalOwnerDecisionRelativePath"
    $resolvedBlob = @(& git -C 'C:\QM\repo' rev-parse $blobSpec 2>&1)
    if ($LASTEXITCODE -ne 0 -or $resolvedBlob.Count -ne 1 -or
        ([string]$resolvedBlob[0]).Trim() -cne $QM_OWNER_DECISION_BLOB) {
        throw "canonical OWNER decision blob mismatch: $($resolvedBlob -join ' ')"
    }
}

function Assert-CanonicalFactoryOnHostProcess {
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$PID" -ErrorAction Stop
    if ($null -eq $process -or
        [System.IO.Path]::GetFullPath([string]$process.ExecutablePath) -ine $canonicalFactoryOnProcessImage) {
        throw "Factory_ON requires exact host image $canonicalFactoryOnProcessImage"
    }
    $arguments = @(Get-QmCommandLineArguments -CommandLine ([string]$process.CommandLine))
    $baseArguments = @(
        $canonicalFactoryOnProcessImage,
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        $canonicalFactoryOnPath,
        '-CanonicalRuntimeHost'
    )
    $allowed = @(
        ,$baseArguments
        ,@($baseArguments + '-NoPause')
    )
    $matches = $false
    foreach ($candidate in $allowed) {
        if ($arguments.Count -ne $candidate.Count) { continue }
        $candidateMatches = $true
        for ($index = 0; $index -lt $candidate.Count; $index++) {
            if ([string]$arguments[$index] -ine [string]$candidate[$index]) {
                $candidateMatches = $false
                break
            }
        }
        if ($candidateMatches) {
            $matches = $true
            break
        }
    }
    if (-not $matches) {
        throw ('Factory_ON requires exact canonical -File argv; ' +
            '-Command, -EncodedCommand and additional arguments are forbidden')
    }
    $hostProcess = Get-Process -Id $PID -ErrorAction Stop
    $script:factoryOnProcessStartedAtUtc = $hostProcess.StartTime.ToUniversalTime().ToString('o')
}

function Get-CanonicalRuntimeActivationAuthorization {
    if (-not (Test-Path -LiteralPath $runtimeActivationValidatorScript -PathType Leaf)) {
        throw "runtime-activation validator is missing: $runtimeActivationValidatorScript"
    }
    $arguments = @('--repo-root', 'C:\QM\repo')
    if (Test-Path -LiteralPath $factoryOffFlagPath -PathType Leaf) {
        $arguments += @('--factory-off-flag', $factoryOffFlagPath)
    }
    # EAP=Continue: under Stop, PS5.1 turns interpreter stderr noise in the
    # 2>&1 merge into a terminating NativeCommandError before the exit code
    # can be evaluated.
    $priorValidatorErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $pythonExe $runtimeActivationValidatorScript @arguments 2>&1)
        $validatorExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $priorValidatorErrorActionPreference
    }
    if ($validatorExitCode -ne 0) {
        throw ("fresh OWNER runtime activation decision validation failed: " +
            ($output -join [Environment]::NewLine))
    }
    # stdout/stderr are merged for Windows PowerShell 5.1 compatibility, so
    # select one explicitly framed stdout record rather than relying on output
    # position.  Unframed native noise may occur before or after the record;
    # zero or duplicate records fail closed.
    $recordPrefix = 'QM_FACTORY_RUNTIME_ACTIVATION_V1:'
    $records = @($output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($recordPrefix, [System.StringComparison]::Ordinal)
    })
    if ($records.Count -ne 1) {
        throw "runtime-activation validator returned $($records.Count) framed records; expected exactly one"
    }
    $jsonPayload = $records[0].Substring($recordPrefix.Length)
    try {
        $authorization = $jsonPayload | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "runtime-activation validator returned invalid JSON: $($_.Exception.Message)"
    }
    if ($authorization.authorized -isnot [bool] -or -not [bool]$authorization.authorized) {
        throw 'runtime-activation validator did not return authorized=true'
    }
    return $authorization
}

function Assert-CanonicalPublicSnapshotTaskAction {
    param([Parameter(Mandatory = $true)][string]$Context)

    $legacyTasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object {
        [string]$_.TaskName -ieq $legacyPublicSnapshotTaskName
    })
    if ($legacyTasks.Count -ne 0) {
        $legacyPaths = @($legacyTasks | ForEach-Object {
            "{0}{1}" -f ([string]$_.TaskPath),([string]$_.TaskName)
        })
        throw ("legacy direct-export public-snapshot task exists during ${Context}: " +
            "[$($legacyPaths -join ',')]")
    }
    if (-not (Test-Path -LiteralPath $publicSnapshotTaskWrapper -PathType Leaf)) {
        throw "canonical public-snapshot wrapper is missing: $publicSnapshotTaskWrapper"
    }
    $tasks = @(Get-ScheduledTask -TaskName $publicSnapshotTaskName -ErrorAction Stop)
    if ($tasks.Count -ne 1) {
        throw ("public-snapshot task registration cardinality is not exactly one " +
            "during ${Context}: observed=$($tasks.Count)")
    }
    $actions = @($tasks[0].Actions)
    if ($actions.Count -ne 1) {
        throw ("public-snapshot task action cardinality is not exactly one " +
            "during ${Context}: observed=$($actions.Count)")
    }
    $action = $actions[0]
    if ($null -eq $action.CimClass -or
        [string]$action.CimClass.CimClassName -cne 'MSFT_TaskExecAction') {
        throw "public-snapshot task action is not an exact Exec action during $Context"
    }
    if (-not [string]::Equals(
            [string]$action.Execute,
            $publicSnapshotTaskExecute,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ("public-snapshot task executable mismatch during ${Context}: " +
            "actual='$($action.Execute)' expected='$publicSnapshotTaskExecute'")
    }
    $workingDirectory = [string]$action.WorkingDirectory
    if (-not [System.IO.Path]::IsPathRooted($workingDirectory)) {
        throw "public-snapshot task working directory is not rooted during $Context"
    }
    try {
        $normalizedWorkingDirectory = [System.IO.Path]::GetFullPath($workingDirectory)
    } catch {
        throw "public-snapshot task working directory is invalid during ${Context}: $($_.Exception.Message)"
    }
    if (-not [string]::Equals(
            $normalizedWorkingDirectory,
            $publicSnapshotTaskWorkingDirectory,
            [System.StringComparison]::OrdinalIgnoreCase)) {
        throw ("public-snapshot task working-directory mismatch during ${Context}: " +
            "actual='$normalizedWorkingDirectory' expected='$publicSnapshotTaskWorkingDirectory'")
    }
    $arguments = @(Get-QmCommandLineArguments -CommandLine (
        $publicSnapshotTaskExecute + ' ' + [string]$action.Arguments
    ))
    $expectedArguments = @(
        $publicSnapshotTaskExecute,
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        $publicSnapshotTaskWrapper
    )
    if ($arguments.Count -ne $expectedArguments.Count) {
        throw ("public-snapshot task argv cardinality mismatch during ${Context}: " +
            "actual=$($arguments.Count) expected=$($expectedArguments.Count)")
    }
    for ($index = 0; $index -lt $expectedArguments.Count; $index++) {
        if (-not [string]::Equals(
                [string]$arguments[$index],
                [string]$expectedArguments[$index],
                [System.StringComparison]::OrdinalIgnoreCase)) {
            throw ("public-snapshot task argv mismatch during ${Context} at index ${index}: " +
                "actual='$($arguments[$index])' expected='$($expectedArguments[$index])'")
        }
    }
}

function Assert-CleanFactoryCheckout {
    param([Parameter(Mandatory = $true)][string]$Context)

    if (-not (Test-Path -LiteralPath $farmctlScript -PathType Leaf)) {
        throw "farmctl dirty-checkout planner is missing: $farmctlScript"
    }
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $pythonExe
    $startInfo.Arguments = ('"{0}" --root "{1}" artifact-autocommit-plan' -f `
        $farmctlScript,'D:\QM\strategy_farm')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) {
            throw 'artifact auto-commit planner process could not be started'
        }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(30000)) {
            try { $process.Kill() } catch {}
            throw 'artifact auto-commit planner timed out'
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw ("artifact auto-commit planner failed rc={0}: {1} {2}" -f `
                $process.ExitCode,$stdout.Trim(),$stderr.Trim())
        }
    } finally {
        $process.Dispose()
    }
    $jsonLine = @($stdout -split "`r?`n" | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_)
    } | Select-Object -Last 1)
    if ($jsonLine.Count -ne 1) {
        throw 'artifact auto-commit planner returned no JSON record'
    }
    try {
        $plan = [string]$jsonLine[0] | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "artifact auto-commit planner returned invalid JSON: $($_.Exception.Message)"
    }
    if ([string]$plan.schema_version -cne 'qm-artifact-auto-commit-plan/v1' -or
        $plan.valid -isnot [bool] -or -not [bool]$plan.valid -or
        $plan.clean -isnot [bool] -or $null -eq $plan.dirty_count) {
        throw 'artifact auto-commit planner returned an invalid or unsuccessful contract'
    }
    $dirtyCount = 0
    if (-not [int]::TryParse([string]$plan.dirty_count, [ref]$dirtyCount) -or
        $dirtyCount -lt 0) {
        throw 'artifact auto-commit planner returned an invalid dirty_count'
    }
    if (-not [bool]$plan.clean -or $dirtyCount -ne 0) {
        $paths = @($plan.dirty_paths | ForEach-Object { [string]$_ })
        throw ("canonical checkout is dirty during {0}; Factory_ON refuses before " +
            "release/first pump (dirty_count={1}, paths=[{2}])" -f `
            $Context,$dirtyCount,($paths -join ', '))
    }
    return $plan
}

function Test-ExactFactoryTaskContract {
    param(
        [Parameter(Mandatory = $true)]$TaskRows,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$ExpectedState
    )
    $errors = New-Object System.Collections.Generic.List[string]
    $rowsByName = @{}
    foreach ($row in @($TaskRows)) {
        $name = [string]$row.task_name
        if ([string]::IsNullOrWhiteSpace($name) -or $rowsByName.ContainsKey($name)) {
            [void]$errors.Add("Task row '$name' is empty or duplicated.")
            continue
        }
        $rowsByName[$name] = $row
        if (-not $ExpectedState.Contains($name)) {
            [void]$errors.Add("Unexpected task '$name' is present.")
        }
    }
    foreach ($name in @($ExpectedState.Keys)) {
        if (-not $rowsByName.ContainsKey([string]$name)) {
            [void]$errors.Add("Expected task '$name' is missing.")
            continue
        }
        $row = $rowsByName[[string]$name]
        if (-not [string]::IsNullOrWhiteSpace([string]$row.probe_error) -or
            $row.present -isnot [bool] -or -not [bool]$row.present -or
            $row.enabled -isnot [bool]) {
            [void]$errors.Add("Expected task '$name' cannot be verified.")
            continue
        }
        if ([bool]$row.enabled -ne [bool]$ExpectedState[$name]) {
            [void]$errors.Add("Task '$name' enabled-state mismatch.")
        }
    }
    return [pscustomobject][ordered]@{
        healthy = ($errors.Count -eq 0)
        errors = @($errors)
        observed_count = $rowsByName.Count
    }
}

function Get-ValidatedFactoryOffSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedSha256,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$ExpectedTaskMap,
        [Parameter(Mandatory = $true)][string]$Context
    )
    Assert-NoPendingFactoryOffRequest -Context $Context
    if (-not (Test-Path -LiteralPath $factoryOffFlagPath -PathType Leaf)) {
        throw "FACTORY_OFF.flag disappeared at $Context"
    }
    try {
        [byte[]]$bytes = [IO.File]::ReadAllBytes($factoryOffFlagPath)
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $actualSha256 = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
        } finally {
            $sha.Dispose()
        }
        $offset = 0
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xef -and
            $bytes[1] -eq 0xbb -and $bytes[2] -eq 0xbf) {
            $offset = 3
        }
        $utf8 = [Text.UTF8Encoding]::new($false, $true)
        $json = $utf8.GetString($bytes, $offset, $bytes.Length - $offset)
        $record = $json | ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "FACTORY_OFF.flag cannot be read strictly at $Context`: $($_.Exception.Message)"
    }
    if ($actualSha256 -cne $ExpectedSha256.ToLowerInvariant()) {
        throw ("FACTORY_OFF.flag raw-byte SHA-256 drift at $Context; " +
            "expected=$ExpectedSha256 actual=$actualSha256")
    }
    if ([int]$record.schema_version -ne 2 -or [string]$record.state -cne 'OFF') {
        throw "FACTORY_OFF.flag schema/state drift at $Context"
    }
    $taskMap = ConvertTo-ExactTaskEnabledState `
        -State $record.task_enabled_before `
        -ExpectedTasks $QM_QUIESCENCE_TASKS `
        -SourceLabel "FACTORY_OFF.flag at $Context"
    foreach ($taskName in $QM_QUIESCENCE_TASKS) {
        if ([bool]$taskMap[$taskName] -ne [bool]$ExpectedTaskMap[$taskName]) {
            throw "FACTORY_OFF.flag exact 21-task map drift at $Context for '$taskName'"
        }
    }
    return [pscustomobject][ordered]@{
        raw_bytes_base64 = [Convert]::ToBase64String($bytes)
        sha256 = $actualSha256
        record = $record
        task_enabled_before = $taskMap
    }
}

function Assert-NoPendingFactoryOffRequest([string]$Context) {
    if (Test-Path -LiteralPath $factoryOffRequestPath) {
        $script:retainFactoryMutationLock = $true
        throw "pending FACTORY_OFF request observed at $Context; OFF wins"
    }
}

function Assert-BoundFactoryOffRecordUnchanged([string]$Context) {
    try {
        $snapshot = Get-ValidatedFactoryOffSnapshot `
            -ExpectedSha256 $script:boundFactoryOffSha256 `
            -ExpectedTaskMap $script:boundFactoryOffTaskMap `
            -Context $Context
        if ([string]$snapshot.raw_bytes_base64 -cne [string]$script:boundFactoryOffRawBytesBase64) {
            throw "FACTORY_OFF.flag raw bytes changed without a SHA change at $Context"
        }
        return $snapshot
    } catch {
        $script:retainFactoryMutationLock = $true
        throw
    }
}

function Assert-NoFactoryOffIntent([string]$Context) {
    if ((Test-Path -LiteralPath $factoryOffRequestPath) -or
        (Test-Path -LiteralPath $factoryOffFlagPath)) {
        $script:retainFactoryMutationLock = $true
        throw "new FACTORY_OFF intent observed at $Context; OFF wins and the lock is retained"
    }
}

function Remove-BoundFactoryOffRecord {
    [void](Assert-BoundFactoryOffRecordUnchanged `
        -Context 'immediately before conditional OFF release')
    $removed = Remove-QmFileIfContentMatches `
        -Path $factoryOffFlagPath `
        -ExpectedRawBytesBase64 $script:boundFactoryOffRawBytesBase64
    if (-not $removed) {
        $script:retainFactoryMutationLock = $true
        throw 'FACTORY_OFF.flag conditional exact-byte delete refused; OFF wins'
    }
    Assert-NoFactoryOffIntent -Context 'immediately after conditional OFF release'
}

function Test-ExactFactoryWorkerCohort {
    param(
        [Parameter(Mandatory = $true)]$WorkerRows,
        [Parameter(Mandatory = $true)][string[]]$ExpectedTerminals,
        [Parameter(Mandatory = $true)][int]$ExpectedSessionId
    )
    $errors = New-Object System.Collections.Generic.List[string]
    $expectedSet = @{}
    foreach ($terminal in $ExpectedTerminals) {
        if ($terminal -notmatch '^T(?:[1-9]|10)$' -or $expectedSet.ContainsKey($terminal)) {
            [void]$errors.Add("Invalid or duplicate expected worker terminal '$terminal'.")
        } else {
            $expectedSet[$terminal] = $true
        }
    }
    $actualSet = @{}
    foreach ($row in @($WorkerRows)) {
        $terminal = [string]$row.terminal
        if ($terminal -notmatch '^T(?:[1-9]|10)$') {
            [void]$errors.Add("Worker PID '$($row.process_id)' has invalid terminal '$terminal'.")
            continue
        }
        if ($actualSet.ContainsKey($terminal)) {
            [void]$errors.Add("Worker terminal '$terminal' is duplicated.")
            continue
        }
        $actualSet[$terminal] = $true
        if (-not $expectedSet.ContainsKey($terminal)) {
            [void]$errors.Add("Unexpected worker terminal '$terminal' is visible.")
        }
        $sessionId = -1
        if (-not [int]::TryParse([string]$row.session_id, [ref]$sessionId) -or
            $sessionId -ne $ExpectedSessionId) {
            [void]$errors.Add("Worker terminal '$terminal' is not in interactive session $ExpectedSessionId.")
        }
    }
    foreach ($terminal in @($expectedSet.Keys)) {
        if (-not $actualSet.ContainsKey($terminal)) {
            [void]$errors.Add("Expected worker terminal '$terminal' is not visible.")
        }
    }
    return [pscustomobject][ordered]@{
        healthy = ($errors.Count -eq 0)
        errors = @($errors)
        observed_count = $actualSet.Count
    }
}

function Get-FactoryWorkerRows {
    param([Parameter(Mandatory = $true)]$Processes)
    $rows = @()
    foreach ($process in @($Processes)) {
        $arguments = @(Get-QmCommandLineArguments -CommandLine $process.CommandLine)
        $terminal = Get-QmUniqueCommandLineOptionValue -Arguments $arguments -Option '--terminal'
        $rows += [pscustomobject][ordered]@{
            process_id = [int64]$process.ProcessId
            session_id = [int]$process.SessionId
            terminal = [string]$terminal
        }
    }
    return @($rows)
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

function Assert-FactoryOffRecoveryRecord([string]$ExpectedReason) {
    if (-not (Test-Path -LiteralPath $factoryOffFlagPath -PathType Leaf)) {
        throw 'FACTORY_OFF recovery record was not reasserted'
    }
    try {
        $raw = [System.IO.File]::ReadAllBytes($factoryOffFlagPath)
        $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
        $record = $strictUtf8.GetString($raw).TrimStart([char]0xFEFF) |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        throw "FACTORY_OFF recovery record cannot be verified: $($_.Exception.Message)"
    }
    if ([int]$record.schema_version -ne 2 -or
        [string]$record.state -cne 'OFF_RECOVERY_REQUIRED' -or
        [string]$record.rollback_reason -cne $ExpectedReason) {
        throw 'FACTORY_OFF recovery record identity/content verification failed'
    }
    return Get-QmSha256Hex -Bytes $raw
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
        $lockHandleValue = $lockStream.SafeFileHandle.DangerousGetHandle().ToInt64()
        [string[]]$lockRestartHoldIds = @(
            $script:runtimeAuthorization.restart_hold_ids |
            ForEach-Object { [string]$_ }
        )
        $recordPayload = [ordered]@{
            pid = $PID
            owner = $Owner
            nonce = $script:factoryMutationLockNonce
            created_at = [datetime]::UtcNow.ToString('o')
            process_image = $canonicalFactoryOnProcessImage
            process_started_at_utc = [string]$script:factoryOnProcessStartedAtUtc
            lock_handle_value = [int64]$lockHandleValue
            factory_on_path = $canonicalFactoryOnPath
            owner_decision_sha256 = $QM_OWNER_DECISION_SHA256
            owner_decision_commit = $QM_OWNER_DECISION_COMMIT
            owner_decision_blob = $QM_OWNER_DECISION_BLOB
            restart_hold_ids = $lockRestartHoldIds
            disabled_terminals_sha256 = [string]$script:disabledTerminalPolicySha256
            session_id = [int]$mySession
            runtime_decision_id = [string]$script:runtimeAuthorization.decision_id
            runtime_activation_nonce = [string]$script:runtimeAuthorization.activation_nonce
            runtime_decision_sha256 = [string]$script:runtimeAuthorization.decision_sha256
            runtime_decision_commit = [string]$script:runtimeAuthorization.decision_git_commit
            runtime_decision_blob = [string]$script:runtimeAuthorization.decision_git_blob
            factory_on_source_sha256 = [string]$script:runtimeAuthorization.source_bindings.factory_on.sha256
            factory_on_source_commit = [string]$script:runtimeAuthorization.source_bindings.factory_on.git_commit
            factory_on_source_blob = [string]$script:runtimeAuthorization.source_bindings.factory_on.git_blob
            factory_off_flag_sha256 = [string]$script:runtimeAuthorization.factory_off_flag_sha256
            factory_off_request_path = $factoryOffRequestPath
            task_enabled_before_sha256 = [string]$script:runtimeAuthorization.task_enabled_before_sha256
        }
        $record = $recordPayload | ConvertTo-Json -Compress
        try {
            $roundTripRecord = $record | ConvertFrom-Json -ErrorAction Stop
        } catch {
            throw "factory mutation lock JSON round-trip failed: $($_.Exception.Message)"
        }
        [string[]]$roundTripRestartHoldIds = @(
            $roundTripRecord.restart_hold_ids | ForEach-Object { [string]$_ }
        )
        if ($roundTripRestartHoldIds.Count -ne $lockRestartHoldIds.Count) {
            throw 'factory mutation lock restart_hold_ids changed during JSON round-trip'
        }
        for ($index = 0; $index -lt $lockRestartHoldIds.Count; $index++) {
            if ($roundTripRestartHoldIds[$index] -cne $lockRestartHoldIds[$index]) {
                throw "factory mutation lock restart_hold_ids mismatch at index $index"
            }
        }
        if ($lockRestartHoldIds.Count -eq 0 -and
            -not $record.Contains('"restart_hold_ids":[]')) {
            throw 'factory mutation lock empty restart_hold_ids did not serialize as JSON []'
        }
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

function Complete-FactoryMutationLockAfterAttempt {
    param(
        [AllowNull()][object]$LockStream,
        [Parameter(Mandatory = $true)][bool]$RetainForRecovery
    )
    if ($RetainForRecovery) {
        # Dispose only the handle. Never invoke the exact-identity delete path
        # when OFF recovery failed or could not be verified.
        if ($null -ne $LockStream) {
            $LockStream.Dispose()
        }
        return $false
    }
    return Exit-FactoryMutationLock -LockStream $LockStream
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
    $releaseArguments = @(
        '--db', 'D:\QM\strategy_farm\state\farm_state.sqlite',
        '--factory-off-flag', $factoryOffFlagPath,
        'release-on-restart', '--apply',
        '--release-note', 'coordinated Factory_ON all-components restart gate passed',
        '--factory-on-lock-nonce', $script:factoryMutationLockNonce
    )
    $releaseOutput = @(& $pythonExe $maintenanceControlScript @releaseArguments)
    $releaseExitCode = $LASTEXITCODE
    if ($releaseExitCode -ne 0) {
        throw "maintenance restart-hold release failed with exit code $releaseExitCode"
    }
    # Exit 0 is emitted only after the DB transaction committed. From this
    # point, malformed/degraded evidence must never be described as retryable.
    $script:restartHoldMutationCommitted = $true
    try {
        $result = ($releaseOutput -join [Environment]::NewLine) |
            ConvertFrom-Json -ErrorAction Stop
    } catch {
        $script:retainFactoryMutationLock = $true
        throw ("restart holds may be committed but the success result is unreadable; " +
            "mutation lock retained: $($_.Exception.Message)")
    }
    if ($result.mutation_committed -isnot [bool] -or
        -not [bool]$result.mutation_committed) {
        $script:retainFactoryMutationLock = $true
        throw 'release helper exited successfully without mutation_committed=true; lock retained'
    }
    $releasedIds = @($result.released | ForEach-Object { [string]$_ })
    $missingIds = @($script:approvedRestartHoldIds |
        Where-Object { $_ -notin $releasedIds })
    $extraIds = @($releasedIds |
        Where-Object { $_ -notin $script:approvedRestartHoldIds })
    if ($missingIds.Count -ne 0 -or $extraIds.Count -ne 0 -or
        $releasedIds.Count -ne $script:approvedRestartHoldIds.Count) {
        $script:retainFactoryMutationLock = $true
        throw ("committed restart-hold result has an invalid exact set; lock retained: " +
            "missing=[$($missingIds -join ',')] extra=[$($extraIds -join ',')]")
    }
    if ([string]$result.runtime_decision_id -cne [string]$script:runtimeAuthorization.decision_id -or
        [string]$result.runtime_decision_sha256 -cne [string]$script:runtimeAuthorization.decision_sha256) {
        $script:retainFactoryMutationLock = $true
        throw 'committed restart-hold result has mismatched runtime authority; lock retained'
    }
    if ([string]$result.post_commit_evidence.status -cne 'PASS') {
        $script:retainFactoryMutationLock = $true
        $script:restartHoldEvidenceFailedAfterCommit = $true
        throw ("RESTART_HOLDS_COMMITTED_EVIDENCE_FAILED: the declared hold plan was committed, " +
            "post-commit evidence is degraded, OFF recovery will be asserted and the lock retained: " +
            (@($result.post_commit_evidence.errors) -join '; '))
    }
    Write-Host ($releaseOutput -join [Environment]::NewLine)
    return $result
}

function Invoke-FailClosedRollbackWithLockRetention {
    param(
        [Parameter(Mandatory = $true)][string]$OriginalFailure,
        [AllowNull()][object]$PriorOffRecord
    )
    try {
        Invoke-FailClosedRollback -Reason $OriginalFailure -PriorOffRecord $PriorOffRecord
    } catch {
        $script:retainFactoryMutationLock = $true
        $rollbackFailure = $_.Exception.Message
        throw (("FACTORY ON FAILED CLOSED: {0}; rollback could not reassert/verify OFF " +
            "and the mutation lock is retained: {1}") -f $OriginalFailure,$rollbackFailure)
    }
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
    if (Test-Path -LiteralPath $factoryOffFlagPath -PathType Leaf) {
        # OFF always wins.  A flag published after the conditional release is a
        # new operator intent and must never be overwritten by ON rollback.
        [byte[]]$preservedOffBytes = [IO.File]::ReadAllBytes($factoryOffFlagPath)
        $preservedSha = [Security.Cryptography.SHA256]::Create()
        try {
            $script:factoryRollbackOffSha256 = `
                ([BitConverter]::ToString($preservedSha.ComputeHash($preservedOffBytes))).Replace('-', '').ToLowerInvariant()
        } finally {
            $preservedSha.Dispose()
        }
        $script:externalFactoryOffIntentPreserved = $true
    } else {
        Write-FactoryOffRecord $rollback
        $script:factoryRollbackOffSha256 = Assert-FactoryOffRecoveryRecord -ExpectedReason $Reason
        $script:externalFactoryOffIntentPreserved = $false
    }
    Set-Content -LiteralPath $codexParallelPath -Value '0' -Encoding ASCII -ErrorAction SilentlyContinue
    foreach ($taskName in $managedTasks) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
        Disable-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
    }
    Stop-FactoryProcesses
    if ((Test-Path -LiteralPath $pythonExe -PathType Leaf) -and (Test-Path -LiteralPath $pacerScript -PathType Leaf)) {
        # EAP=Continue: interpreter stderr noise must never abort the
        # fail-closed rollback path via a PS5.1 NativeCommandError.
        $priorRollbackErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            & $pythonExe $pacerScript 2>&1 | Out-Null
        } finally {
            $ErrorActionPreference = $priorRollbackErrorActionPreference
        }
    }
}

try {
    if (-not (Test-Path -LiteralPath $pythonExe -PathType Leaf)) {
        throw "Python executable missing: $pythonExe"
    }
    Assert-CanonicalFactoryOnHostProcess
    Assert-CanonicalOwnerRestartDecision
    Assert-CanonicalPublicSnapshotTaskAction -Context 'initial read-only preflight'
    Assert-CleanFactoryCheckout -Context 'initial read-only preflight' | Out-Null
    Assert-NoPendingFactoryOffRequest -Context 'runtime authorization preflight'
    $script:runtimeAuthorization = Get-CanonicalRuntimeActivationAuthorization
    [string[]]$runtimeRestartHoldIds = @($script:runtimeAuthorization.restart_hold_ids |
        ForEach-Object { [string]$_ })
    if ($runtimeRestartHoldIds.Count -ne $script:approvedRestartHoldIds.Count) {
        throw 'runtime restart-hold plan count does not match the preparation decision'
    }
    for ($index = 0; $index -lt $script:approvedRestartHoldIds.Count; $index++) {
        if ($runtimeRestartHoldIds[$index] -cne $script:approvedRestartHoldIds[$index]) {
            throw "runtime restart-hold plan mismatch at index $index"
        }
    }
    $disabledTerminalPolicy = Get-CanonicalDisabledTerminalPolicySnapshot
} catch {
    throw "FACTORY ON ABORTED before mutation: $($_.Exception.Message)"
}
$script:disabledTerminalPolicySha256 = [string]$disabledTerminalPolicy.sha256
$disabledTerminals = @($disabledTerminalPolicy.terminals)
$derivedWorkerTerminals = @(1..10 | ForEach-Object { "T$_" } |
    Where-Object { $_ -notin $disabledTerminals })
$missingWorkerTerminals = @($QM_OWNER_APPROVED_WORKER_TERMINALS |
    Where-Object { $_ -notin $derivedWorkerTerminals })
$extraWorkerTerminals = @($derivedWorkerTerminals |
    Where-Object { $_ -notin $QM_OWNER_APPROVED_WORKER_TERMINALS })
if ($missingWorkerTerminals.Count -ne 0 -or $extraWorkerTerminals.Count -ne 0 -or
    $derivedWorkerTerminals.Count -ne 10) {
    throw ("FACTORY ON ABORTED before mutation: worker-terminal exact-set mismatch: " +
        "missing=[$($missingWorkerTerminals -join ',')] extra=[$($extraWorkerTerminals -join ',')]")
}
$expectedWorkerTerminals = @($QM_OWNER_APPROVED_WORKER_TERMINALS)
$expectWorkers = $expectedWorkerTerminals.Count
if ($expectWorkers -ne 10) {
    throw 'FACTORY ON ABORTED before mutation: OWNER-approved worker count is not exactly ten.'
}
$mySession = (Get-Process -Id $PID).SessionId
$approvedTaskEnabledBefore = ConvertTo-ExactTaskEnabledState `
    -State $script:runtimeAuthorization.task_enabled_before `
    -ExpectedTasks $QM_QUIESCENCE_TASKS `
    -SourceLabel 'fresh OWNER runtime activation decision'

$expectedTaskEnabledState = [ordered]@{}
foreach ($taskName in @($QM_FACTORY_TASKS + $QM_AI_TASKS + $QM_RESPAWN_TASKS |
    Sort-Object -Unique)) {
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled $true
}
foreach ($taskName in $QM_QUIESCENCE_TASKS) {
    Add-QmExpectedTaskEnabledState -TaskMap $expectedTaskEnabledState `
        -TaskName $taskName -Enabled ([bool]$approvedTaskEnabledBefore[$taskName])
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

Write-Host ''
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ("  QuantMechanica  -  FACTORY ON  (session {0}, visible)" -f $mySession) -ForegroundColor Cyan
Write-Host '=====================================================' -ForegroundColor Cyan
Write-Host ''

$offRecord = $null
if (Test-Path -LiteralPath $factoryOffFlagPath) {
    try {
        $initialOffSnapshot = Get-ValidatedFactoryOffSnapshot `
            -ExpectedSha256 ([string]$script:runtimeAuthorization.factory_off_flag_sha256) `
            -ExpectedTaskMap $approvedTaskEnabledBefore `
            -Context 'initial pre-lock binding'
        $offRecord = $initialOffSnapshot.record
        $script:boundFactoryOffRawBytesBase64 = [string]$initialOffSnapshot.raw_bytes_base64
        $script:boundFactoryOffSha256 = [string]$initialOffSnapshot.sha256
        $script:boundFactoryOffTaskMap = $initialOffSnapshot.task_enabled_before
    } catch {
        throw "FACTORY ON ABORTED: FACTORY_OFF.flag binding failed: $($_.Exception.Message)"
    }
} else {
    if (Test-Path -LiteralPath $factoryMutationLockPath) {
        throw ("FACTORY ON ABORTED: interlock absent but mutation lock exists; " +
            "ALREADY_ON is forbidden until OWNER validates the lock: $factoryMutationLockPath")
    }
    $snapshot = Get-FactoryProcessSnapshot
    $alreadyOnWorkerRows = @(Get-FactoryWorkerRows -Processes $snapshot.daemons)
    $alreadyOnWorkers = Test-ExactFactoryWorkerCohort `
        -WorkerRows $alreadyOnWorkerRows `
        -ExpectedTerminals $expectedWorkerTerminals `
        -ExpectedSessionId $mySession
    $alreadyOnTaskSnapshot = Get-QmFactoryPostStartSnapshot `
        -TaskNames @($expectedTaskEnabledState.Keys)
    $alreadyOnTasks = Test-ExactFactoryTaskContract `
        -TaskRows $alreadyOnTaskSnapshot.tasks `
        -ExpectedState $expectedTaskEnabledState
    if ($alreadyOnWorkers.healthy -and $alreadyOnWorkers.observed_count -eq $expectWorkers -and
        $alreadyOnTasks.healthy -and
        $alreadyOnTasks.observed_count -eq $expectedTaskEnabledState.Count) {
        Assert-NoFactoryOffIntent -Context 'already-ON final no-op verification'
        if (Test-Path -LiteralPath $factoryMutationLockPath) {
            throw 'FACTORY ON ALREADY_ON result cancelled because a mutation lock appeared'
        }
        Write-Host ("  FACTORY ALREADY ON - exact {0}/{1} worker cohort in session {2}; no action taken." -f `
            $alreadyOnWorkers.observed_count,$expectWorkers,$mySession) -ForegroundColor Green
        if (-not $NoPause) { Read-Host 'Press Enter to close' }
        exit 0
    }
    throw ("FACTORY ON ABORTED: interlock absent but factory is not verifiably ON " +
        "(worker_errors=[$($alreadyOnWorkers.errors -join '; ')] " +
        "task_errors=[$($alreadyOnTasks.errors -join '; ')]). " +
        "Exactly T1-T10 must be present in this session. " +
        "Run Factory_OFF first to establish a clean restart contract.")
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
foreach ($taskName in $QM_QUIESCENCE_TASKS) {
    if ([bool]$taskEnabledBefore[$taskName] -ne [bool]$approvedTaskEnabledBefore[$taskName]) {
        throw ("FACTORY ON ABORTED before mutation: schema-v2 OFF task map differs from " +
            "the exact OWNER-approved preparation map at '$taskName'")
    }
}
if (Test-Path -LiteralPath $factoryMutationLockPath) {
    throw "FACTORY ON ABORTED: autonomous mutation lock still exists: $factoryMutationLockPath"
}

$script:factoryRestartMutationLock = Enter-FactoryMutationLock -Owner 'factory_on_restart_window'
$released = $false
$script:retainFactoryMutationLock = $false
$script:factoryRollbackOffSha256 = $null
$script:restartHoldMutationCommitted = $false
$script:restartHoldEvidenceFailedAfterCommit = $false
try {
    [void](Assert-BoundFactoryOffRecordUnchanged `
        -Context 'immediately after Factory_ON lock acquisition')
    # Preflight and stale factory-process drain occur while the interlock remains
    # asserted and while the same lock used by maintenance one-shots is held.
    # The exact T1..T10 classifiers structurally exclude T_Live/FTMO.
    Assert-DisabledTerminalPolicyUnchanged `
        -ExpectedSha256 $script:disabledTerminalPolicySha256 `
        -Context 'locked preflight' | Out-Null
    Assert-CanonicalPublicSnapshotTaskAction -Context 'locked preflight'
    Assert-CleanFactoryCheckout -Context 'locked preflight' | Out-Null
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
    Assert-CanonicalPublicSnapshotTaskAction -Context 'immediately before OFF release'
    Assert-CleanFactoryCheckout -Context 'immediately before OFF release' | Out-Null
    Remove-BoundFactoryOffRecord
    $released = $true

    # Repair is a DB mutator, so it may not run behind FACTORY_OFF.  Execute it
    # immediately after release, under the same global writer lock, while every
    # autonomous task and worker is still stopped.  Any failure reasserts OFF.
    Assert-NoFactoryOffIntent -Context 'immediately before guarded repair'
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

    Assert-DisabledTerminalPolicyUnchanged `
        -ExpectedSha256 $script:disabledTerminalPolicySha256 `
        -Context 'immediately before worker launch' | Out-Null
    Assert-NoFactoryOffIntent -Context 'immediately before worker launch'
    & $pythonExe 'C:\QM\repo\tools\strategy_farm\start_terminal_workers.py' `
        --repo-root 'C:\QM\repo' --farm-root 'D:\QM\strategy_farm' --dedupe | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "start_terminal_workers.py failed with exit code $LASTEXITCODE"
    }
    Start-Sleep -Seconds 12

    $daemons = @(Get-CimInstance Win32_Process -Filter "Name='pythonw.exe' OR Name='python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { Test-QmFactoryWorkerCommandLine -CommandLine $_.CommandLine })
    $startedWorkerRows = @(Get-FactoryWorkerRows -Processes $daemons)
    $startedWorkers = Test-ExactFactoryWorkerCohort `
        -WorkerRows $startedWorkerRows `
        -ExpectedTerminals $expectedWorkerTerminals `
        -ExpectedSessionId $mySession
    if (-not $startedWorkers.healthy -or $startedWorkers.observed_count -ne $expectWorkers) {
        throw ("exact worker cohort did not start: " +
            "$($startedWorkers.errors -join '; ')")
    }
    Assert-NoFactoryOffIntent -Context 'after worker launch and before task enablement'

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
        Assert-NoFactoryOffIntent -Context "before enabling scheduled task '$taskName'"
        Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
    }

    foreach ($taskName in $QM_QUIESCENCE_TASKS) {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($null -eq $task) { continue }
        # Missing state is fail-closed: a task introduced after OFF must not be
        # silently enabled by ON without an explicit captured operator state.
        $shouldEnable = $false
        if ($taskEnabledBefore.Contains($taskName)) { $shouldEnable = [bool]$taskEnabledBefore[$taskName] }
        if ($shouldEnable) {
            Assert-NoFactoryOffIntent -Context "before enabling quiescence task '$taskName'"
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
            Assert-NoFactoryOffIntent -Context "before enabling always-on task '$taskName'"
            Enable-ScheduledTask -TaskName $taskName -ErrorAction Stop | Out-Null
        }
    }

    Assert-NoFactoryOffIntent -Context 'before starting QuotaPull'
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_QuotaPull' -ErrorAction Stop
    Assert-NoFactoryOffIntent -Context 'before starting AgentRouter'
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_AgentRouter_5min' -ErrorAction Stop
    Assert-NoFactoryOffIntent -Context 'before starting Pump'
    Start-ScheduledTask -TaskName 'QM_StrategyFarm_Pump_5min' -ErrorAction Stop

    Assert-NoFactoryOffIntent -Context 'before post-start health wait'
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
    # child authenticates this exact actively parent-held restart-window lock,
    # canonical OWNER provenance and internally pinned seven-ID set.
    Assert-DisabledTerminalPolicyUnchanged `
        -ExpectedSha256 $script:disabledTerminalPolicySha256 `
        -Context 'immediately before restart-hold release' | Out-Null
    $releaseHealthSnapshot = Get-QmFactoryPostStartSnapshot `
        -TaskNames @($expectedTaskEnabledState.Keys)
    $releaseHealth = Test-QmFactoryPostStartHealth `
        -Snapshot $releaseHealthSnapshot `
        -ExpectedTaskEnabledState $expectedTaskEnabledState `
        -CriticalTaskBaselines $criticalTaskBaselines `
        -CriticalTaskNames $QM_CRITICAL_POST_START_TASKS `
        -ExpectedWorkerTerminals $expectedWorkerTerminals `
        -ExpectedSessionId $mySession `
        -FreshNotBeforeUtc $criticalTasksStartedAtUtc
    if (-not $releaseHealth.healthy) {
        throw ("immediate pre-release task/worker health revalidation failed: " +
            ($releaseHealth.errors -join '; '))
    }
    Assert-NoFactoryOffIntent -Context 'immediately before restart-hold release'
    $restartHoldRelease = Invoke-RestartHoldReleaseWithMutationLock
    Assert-NoFactoryOffIntent -Context 'immediately after restart-hold release'

    Write-Host ("  FACTORY STARTED - {0}/{1} daemons live in session {2}." -f $startedWorkers.observed_count,$expectWorkers,$mySession) -ForegroundColor Green
        Write-Host '  Factory-owned scheduled components were released in one restart window.'
    } catch {
        $failure = $_.Exception.Message
        if ($released) {
            Invoke-FailClosedRollbackWithLockRetention `
                -OriginalFailure $failure -PriorOffRecord $offRecord
        }
        throw "FACTORY ON FAILED CLOSED: $failure"
    }
} finally {
    if ($script:retainFactoryMutationLock) {
        try {
            $script:factoryRestartMutationLockReleased = `
                Complete-FactoryMutationLockAfterAttempt `
                    -LockStream $script:factoryRestartMutationLock `
                    -RetainForRecovery $true
        } catch {
            Write-Warning "Mutation-lock handle disposal failed while retaining lock: $($_.Exception.Message)"
            $script:factoryRestartMutationLockReleased = $false
        }
    } else {
        $script:factoryRestartMutationLockReleased = `
            Complete-FactoryMutationLockAfterAttempt `
                -LockStream $script:factoryRestartMutationLock `
                -RetainForRecovery $false
    }
    $script:factoryRestartMutationLock = $null
    $script:factoryMutationLockNonce = $null
    $script:factoryMutationLockRecordBytesBase64 = $null
    $script:boundFactoryOffRawBytesBase64 = $null
    $script:boundFactoryOffSha256 = $null
    $script:boundFactoryOffTaskMap = $null
    if ($script:retainFactoryMutationLock) {
        Write-Warning 'Rollback failed; exact Factory mutation lock retained for OWNER recovery.'
    } elseif (-not $script:factoryRestartMutationLockReleased) {
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

Write-Host '  OWNER worker policy enforced: disabled=[]; exact T1-T10 cohort healthy.'
Write-Host '  T_Live/FTMO task state, live terminals and AutoTrading were not touched.'
Write-Host '  RDP disconnect is safe; explicit LOGOFF still terminates interactive factory workers.'
Write-Host ''
if (-not $NoPause) { Read-Host 'Press Enter to close' }
