$ErrorActionPreference = 'Stop'

$strategyFarmRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $strategyFarmRoot 'factory_restart_health.ps1')

$script:assertions = 0

function Assert-True {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $script:assertions++
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

function Assert-ContainsError {
    param(
        [Parameter(Mandatory = $true)]$Assessment,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Message
    )
    $matched = @($Assessment.errors | Where-Object { $_ -match $Pattern }).Count -gt 0
    Assert-True -Condition $matched -Message $Message
}

function New-ExpectedTaskState {
    return [ordered]@{
        'QM_StrategyFarm_QuotaPull' = $true
        'QM_StrategyFarm_AgentRouter_5min' = $true
        'QM_StrategyFarm_Pump_5min' = $true
        'QM_StrategyFarm_UnreadableLinks_Friday' = $false
    }
}

function New-TaskRow {
    param(
        [string]$Name,
        [bool]$Enabled,
        [string]$State = 'Ready',
        [object]$LastResult = 0,
        [string]$LastRunUtc = '2026-07-30T10:00:11Z'
    )
    return [pscustomobject][ordered]@{
        task_name = $Name
        present = $true
        enabled = $Enabled
        state = $State
        last_run_utc = $LastRunUtc
        last_task_result = $LastResult
        probe_error = $null
    }
}

function New-HealthySnapshot {
    return [pscustomobject][ordered]@{
        captured_at_utc = '2026-07-30T10:00:12Z'
        tasks = @(
            (New-TaskRow -Name 'QM_StrategyFarm_QuotaPull' -Enabled $true),
            (New-TaskRow -Name 'QM_StrategyFarm_AgentRouter_5min' -Enabled $true),
            (New-TaskRow -Name 'QM_StrategyFarm_Pump_5min' -Enabled $true),
            (New-TaskRow -Name 'QM_StrategyFarm_UnreadableLinks_Friday' -Enabled $false `
                -State 'Disabled' -LastRunUtc '2026-07-29T10:00:00Z')
        )
        workers = @(
            [pscustomobject]@{ process_id = 101; session_id = 7; terminal = 'T1' },
            [pscustomobject]@{ process_id = 102; session_id = 7; terminal = 'T2' }
        )
    }
}

$expected = New-ExpectedTaskState
$critical = @(
    'QM_StrategyFarm_QuotaPull',
    'QM_StrategyFarm_AgentRouter_5min',
    'QM_StrategyFarm_Pump_5min'
)
$baselines = [ordered]@{
    'QM_StrategyFarm_QuotaPull' = '2026-07-30T10:00:00Z'
    'QM_StrategyFarm_AgentRouter_5min' = '2026-07-30T10:00:00Z'
    'QM_StrategyFarm_Pump_5min' = '2026-07-30T10:00:00Z'
}
$common = @{
    ExpectedTaskEnabledState = $expected
    CriticalTaskBaselines = $baselines
    CriticalTaskNames = $critical
    ExpectedWorkerTerminals = @('T1','T2')
    ExpectedSessionId = 7
    FreshNotBeforeUtc = [datetimeoffset]'2026-07-30T10:00:10Z'
}

$healthy = Test-QmFactoryPostStartHealth -Snapshot (New-HealthySnapshot) @common
Assert-True -Condition $healthy.healthy -Message 'complete fresh snapshot must pass'
Assert-True -Condition ($healthy.errors.Count -eq 0) -Message 'healthy snapshot must have no errors'

$drift = New-HealthySnapshot
$drift.tasks[0].enabled = $false
$assessment = Test-QmFactoryPostStartHealth -Snapshot $drift @common
Assert-True -Condition (-not $assessment.healthy) -Message 'enabled-state drift must fail'
Assert-ContainsError -Assessment $assessment -Pattern 'enabled-state mismatch' `
    -Message 'enabled-state drift reason must be explicit'

$probeFailure = New-HealthySnapshot
$probeFailure.tasks[0].probe_error = 'scheduler unavailable'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $probeFailure @common
Assert-ContainsError -Assessment $assessment -Pattern 'probe failed: scheduler unavailable' `
    -Message 'task probe error must fail closed'

$missing = New-HealthySnapshot
$missing.tasks = @($missing.tasks | Where-Object { $_.task_name -ne 'QM_StrategyFarm_Pump_5min' })
$assessment = Test-QmFactoryPostStartHealth -Snapshot $missing @common
Assert-ContainsError -Assessment $assessment -Pattern 'missing from the snapshot' `
    -Message 'missing task must fail exact task key-set'

$duplicate = New-HealthySnapshot
$duplicate.tasks += New-TaskRow -Name 'QM_StrategyFarm_Pump_5min' -Enabled $true
$assessment = Test-QmFactoryPostStartHealth -Snapshot $duplicate @common
Assert-ContainsError -Assessment $assessment -Pattern "duplicate 'QM_StrategyFarm_Pump_5min'" `
    -Message 'duplicate task row must fail'

$unexpected = New-HealthySnapshot
$unexpected.tasks += New-TaskRow -Name 'QM_Unexpected' -Enabled $true
$assessment = Test-QmFactoryPostStartHealth -Snapshot $unexpected @common
Assert-ContainsError -Assessment $assessment -Pattern "unexpected 'QM_Unexpected'" `
    -Message 'unexpected task row must fail'

$stale = New-HealthySnapshot
$stale.tasks[0].last_run_utc = '2026-07-30T10:00:00Z'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $stale @common
Assert-ContainsError -Assessment $assessment -Pattern 'predates this restart window' `
    -Message 'stale critical heartbeat must fail'
Assert-ContainsError -Assessment $assessment -Pattern 'not advanced beyond' `
    -Message 'unchanged critical baseline must fail'

# Regression contract 1: only the long-running Router may latch from a fresh
# post-baseline Running start, and its poisoned prior result is not consulted.
$routerRunningFresh = New-HealthySnapshot
$routerRunningFresh.tasks[1].state = 'Running'
$routerRunningFresh.tasks[1].last_task_result = 2147946720
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerRunningFresh @common
Assert-True -Condition $assessment.healthy `
    -Message 'fresh allow-listed Router Running start must pass'
$routerFreshness = Get-QmCriticalTaskFreshnessAssessment `
    -Row $routerRunningFresh.tasks[1] `
    -TaskName 'QM_StrategyFarm_AgentRouter_5min' `
    -FreshFloor ([datetimeoffset]'2026-07-30T10:00:08Z') `
    -BaselineText $baselines['QM_StrategyFarm_AgentRouter_5min']
Assert-True -Condition ($routerFreshness.accepted -and `
    $routerFreshness.acceptance_mode -eq 'fresh_running_start') `
    -Message 'Router Running acceptance must identify fresh_running_start mode'

$script:routerRunningFreshSnapshot = $routerRunningFresh
$routerRunningProbe = { param([string[]]$TaskNames) $script:routerRunningFreshSnapshot }
$script:fakeNow = [datetimeoffset]'2026-07-30T10:00:12Z'
$routerClockProbe = {
    $result = $script:fakeNow
    $script:fakeNow = $script:fakeNow.AddSeconds(1)
    return $result
}
$noSleepProbe = { param([int]$Seconds) }
$routerRunningLatch = Wait-QmFactoryPostStartHealth @common `
    -TimeoutSeconds 3 -PollSeconds 1 `
    -SnapshotProbe $routerRunningProbe -UtcNowProbe $routerClockProbe -SleepProbe $noSleepProbe
$routerLatchEvidence = $routerRunningLatch.latched_critical_tasks['QM_StrategyFarm_AgentRouter_5min']
Assert-True -Condition ($routerLatchEvidence.acceptance_mode -eq 'fresh_running_start' -and `
    $routerLatchEvidence.observed_start_utc -eq '2026-07-30T10:00:11.0000000+00:00') `
    -Message 'Router Running latch must record mode and observed start timestamp'

# Regression contract 2: a stale/unchanged Router Running start remains closed.
$routerRunningStale = New-HealthySnapshot
$routerRunningStale.tasks[1].state = 'Running'
$routerRunningStale.tasks[1].last_task_result = 2147946720
$routerRunningStale.tasks[1].last_run_utc = '2026-07-30T10:00:00Z'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerRunningStale @common
Assert-True -Condition (-not $assessment.healthy) `
    -Message 'stale unchanged Router Running start must fail'
Assert-ContainsError -Assessment $assessment -Pattern 'not advanced beyond' `
    -Message 'stale Router Running failure must identify unchanged baseline'

# Regression contract 3: no other critical task receives Running acceptance.
$pumpRunning = New-HealthySnapshot
$pumpRunning.tasks[2].state = 'Running'
$pumpRunning.tasks[2].last_task_result = 267009
$assessment = Test-QmFactoryPostStartHealth -Snapshot $pumpRunning @common
Assert-ContainsError -Assessment $assessment -Pattern 'not freshly completed or allow-listed as running' `
    -Message 'non-allow-listed Pump Running state must fail'

# Regression contract 4: the ordinary fresh Ready/result=0 path still passes.
$routerReady = New-HealthySnapshot
$routerReadyFreshness = Get-QmCriticalTaskFreshnessAssessment `
    -Row $routerReady.tasks[1] `
    -TaskName 'QM_StrategyFarm_AgentRouter_5min' `
    -FreshFloor ([datetimeoffset]'2026-07-30T10:00:08Z') `
    -BaselineText $baselines['QM_StrategyFarm_AgentRouter_5min']
Assert-True -Condition ($routerReadyFreshness.accepted -and `
    $routerReadyFreshness.acceptance_mode -eq 'fresh_ready_success') `
    -Message 'fresh Router Ready result zero must retain completed-success acceptance'

# Regression contract 5: Ready/0x800710E0 is pending, never an execution failure.
$routerReadyOverlap = New-HealthySnapshot
$routerReadyOverlap.tasks[1].last_task_result = 2147946720
$routerOverlapFreshness = Get-QmCriticalTaskFreshnessAssessment `
    -Row $routerReadyOverlap.tasks[1] `
    -TaskName 'QM_StrategyFarm_AgentRouter_5min' `
    -FreshFloor ([datetimeoffset]'2026-07-30T10:00:08Z') `
    -BaselineText $baselines['QM_StrategyFarm_AgentRouter_5min']
Assert-True -Condition (-not $routerOverlapFreshness.accepted -and `
    $routerOverlapFreshness.disposition -eq 'pending_overlap') `
    -Message 'Ready overlap refusal must remain pending'

# Regression contract 6: an ordinary nonzero completion is an execution failure.
$failed = New-HealthySnapshot
$failed.tasks[2].last_task_result = 1
$failedFreshness = Get-QmCriticalTaskFreshnessAssessment `
    -Row $failed.tasks[2] `
    -TaskName 'QM_StrategyFarm_Pump_5min' `
    -FreshFloor ([datetimeoffset]'2026-07-30T10:00:08Z') `
    -BaselineText $baselines['QM_StrategyFarm_Pump_5min']
Assert-True -Condition (-not $failedFreshness.accepted -and `
    $failedFreshness.disposition -eq 'execution_failure') `
    -Message 'ordinary nonzero completion must be classified execution_failure'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $failed @common
Assert-ContainsError -Assessment $assessment -Pattern 'completed with nonzero result' `
    -Message 'nonzero critical result must fail explicitly'

$missingWorker = New-HealthySnapshot
$missingWorker.workers = @($missingWorker.workers | Where-Object { $_.terminal -ne 'T2' })
$assessment = Test-QmFactoryPostStartHealth -Snapshot $missingWorker @common
Assert-ContainsError -Assessment $assessment -Pattern "Expected worker terminal 'T2' is not visible" `
    -Message 'missing worker lane must fail'

$duplicateWorker = New-HealthySnapshot
$duplicateWorker.workers += [pscustomobject]@{ process_id = 103; session_id = 7; terminal = 'T1' }
$assessment = Test-QmFactoryPostStartHealth -Snapshot $duplicateWorker @common
Assert-ContainsError -Assessment $assessment -Pattern "Worker terminal 'T1' is duplicated" `
    -Message 'duplicate worker lane must fail'

$wrongSession = New-HealthySnapshot
$wrongSession.workers[0].session_id = 0
$assessment = Test-QmFactoryPostStartHealth -Snapshot $wrongSession @common
Assert-ContainsError -Assessment $assessment -Pattern 'not in interactive session 7' `
    -Message 'session-0 worker must fail'

$extraWorker = New-HealthySnapshot
$extraWorker.workers += [pscustomobject]@{ process_id = 104; session_id = 7; terminal = 'T3' }
$assessment = Test-QmFactoryPostStartHealth -Snapshot $extraWorker @common
Assert-ContainsError -Assessment $assessment -Pattern "Unexpected worker terminal 'T3'" `
    -Message 'unexpected worker lane must fail'

$map = [ordered]@{}
Add-QmExpectedTaskEnabledState -TaskMap $map -TaskName 'same' -Enabled $true
Add-QmExpectedTaskEnabledState -TaskMap $map -TaskName 'same' -Enabled $true
Assert-True -Condition ($map.Count -eq 1) -Message 'identical expected task entries may coalesce'
$conflictThrown = $false
try {
    Add-QmExpectedTaskEnabledState -TaskMap $map -TaskName 'same' -Enabled $false
} catch {
    $conflictThrown = $_.Exception.Message -match 'Conflicting expected enabled state'
}
Assert-True -Condition $conflictThrown -Message 'conflicting expected task policy must fail closed'

$script:fakeNow = [datetimeoffset]'2026-07-30T10:00:12Z'
$badSnapshot = New-HealthySnapshot
$badSnapshot.workers = @()
$snapshotProbe = { param([string[]]$TaskNames) $script:badSnapshot }
$clockProbe = {
    $result = $script:fakeNow
    $script:fakeNow = $script:fakeNow.AddSeconds(1)
    return $result
}
$sleepProbe = { param([int]$Seconds) }
$timeoutThrown = $false
try {
    Wait-QmFactoryPostStartHealth @common -TimeoutSeconds 1 -PollSeconds 1 `
        -SnapshotProbe $snapshotProbe -UtcNowProbe $clockProbe -SleepProbe $sleepProbe | Out-Null
} catch {
    $timeoutThrown = $_.Exception.Message -match 'health gate timed out' -and `
        $_.Exception.Message -match "Expected worker terminal 'T1' is not visible"
}
Assert-True -Condition $timeoutThrown -Message 'bounded wait must throw detailed timeout failure'

# Regression contract 7: the deadline names exactly the critical tasks that
# never latched, sorted deterministically before the detailed assessment.
$starvedSnapshot = New-HealthySnapshot
$starvedSnapshot.tasks[1].state = 'Running'
$starvedSnapshot.tasks[1].last_task_result = 2147946720
$starvedSnapshot.tasks[1].last_run_utc = '2026-07-30T10:00:00Z'
$starvedSnapshot.tasks[2].state = 'Running'
$starvedSnapshot.tasks[2].last_task_result = 267009
$script:starvedSnapshot = $starvedSnapshot
$starvedProbe = { param([string[]]$TaskNames) $script:starvedSnapshot }
$script:fakeNow = [datetimeoffset]'2026-07-30T10:00:12Z'
$starvedDeadlineExact = $false
try {
    Wait-QmFactoryPostStartHealth @common -TimeoutSeconds 1 -PollSeconds 1 `
        -SnapshotProbe $starvedProbe -UtcNowProbe $clockProbe -SleepProbe $sleepProbe | Out-Null
} catch {
    $starvedNeedle = ('starved_tasks=[QM_StrategyFarm_AgentRouter_5min,' +
        'QM_StrategyFarm_Pump_5min]')
    $starvedDeadlineExact = $_.Exception.Message.Contains($starvedNeedle) -and `
        -not $_.Exception.Message.Contains('starved_tasks=[QM_StrategyFarm_QuotaPull') -and `
        $_.Exception.Message.Contains('last_assessment=')
}
Assert-True -Condition $starvedDeadlineExact `
    -Message 'deadline must list exactly the sorted unlatchable critical tasks'

# Latch semantics (2026-08-10): an overlapping trigger can replace the last
# result with 0x800710E0 after an earlier fresh success/start. One observed
# fresh post-baseline acceptance per task must satisfy the gate for the whole
# restart window; without a latch the same overlap snapshot stays pending.
$latchedRouterOnly = [ordered]@{
    'QM_StrategyFarm_AgentRouter_5min' = [ordered]@{
        latched_at_utc = '2026-07-30T10:00:13Z'
        last_run_utc = '2026-07-30T10:00:11Z'
    }
}
$routerOverlapAfterLatch = New-HealthySnapshot
$routerOverlapAfterLatch.tasks[1].last_task_result = 2147946720
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerOverlapAfterLatch @common
Assert-True -Condition (-not $assessment.healthy) `
    -Message 'overlap refusal without an earlier latch must remain pending'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerOverlapAfterLatch @common `
    -LatchedCriticalTasks $latchedRouterOnly
Assert-True -Condition $assessment.healthy `
    -Message 'previously latched critical task must survive a later overlap refusal'

$snapA = New-HealthySnapshot
$snapA.tasks[2].state = 'Running'
$snapA.tasks[2].last_task_result = 267009
$snapB = New-HealthySnapshot
$snapB.tasks[1].state = 'Running'
$snapB.tasks[1].last_task_result = 2147946720
$snapB.tasks[0].state = 'Running'
$snapB.tasks[0].last_task_result = 267009
$script:latchSnapshots = @($snapA, $snapB, $snapB, $snapB)
$latchProbe = {
    param([string[]]$TaskNames)
    $next = $script:latchSnapshots[0]
    if ($script:latchSnapshots.Count -gt 1) {
        $script:latchSnapshots = @($script:latchSnapshots[1..($script:latchSnapshots.Count - 1)])
    }
    return $next
}
$script:fakeNow = [datetimeoffset]'2026-07-30T10:00:12Z'
$latchResult = Wait-QmFactoryPostStartHealth @common -TimeoutSeconds 30 -PollSeconds 1 `
    -SnapshotProbe $latchProbe -UtcNowProbe $clockProbe -SleepProbe $sleepProbe
Assert-True -Condition $latchResult.healthy `
    -Message 'alternating Running windows must pass via per-task latches'
foreach ($criticalName in $critical) {
    Assert-True -Condition $latchResult.latched_critical_tasks.Contains($criticalName) `
        -Message "latch evidence must record '$criticalName'"
}

# Operational State is not the configured enabled bit: Task Scheduler can keep
# a disabled task Running until its current instance exits. The snapshot must
# preserve Settings.Enabled=false in that state instead of deriving true from
# State != Disabled.
function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName)
    return [pscustomobject]@{
        State = 'Running'
        Settings = [pscustomobject]@{ Enabled = $false }
    }
}
function Get-ScheduledTaskInfo {
    [CmdletBinding()]
    param($InputObject)
    return [pscustomobject]@{
        LastRunTime = [datetime]'2026-07-30T10:00:11Z'
        LastTaskResult = 0
    }
}
function Get-CimInstance {
    [CmdletBinding()]
    param([string]$ClassName, [string]$Filter)
    return @()
}
$configuredDisabledSnapshot = Get-QmFactoryPostStartSnapshot -TaskNames @('configured-disabled')
Assert-True -Condition ($configuredDisabledSnapshot.tasks.Count -eq 1) `
    -Message 'mocked task snapshot must contain one row'
Assert-True -Condition ($configuredDisabledSnapshot.tasks[0].state -eq 'Running') `
    -Message 'regression setup must retain operational Running state'
Assert-True -Condition ($configuredDisabledSnapshot.tasks[0].enabled -is [bool] -and `
    -not $configuredDisabledSnapshot.tasks[0].enabled) `
    -Message 'Running task with Settings.Enabled=false must remain configured disabled'

Write-Output "PASS Test-FactoryRestartPostStartHealth.ps1 ($script:assertions assertions)"
