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

$running = New-HealthySnapshot
$running.tasks[1].state = 'Running'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $running @common
Assert-ContainsError -Assessment $assessment -Pattern 'not freshly completed' `
    -Message 'still-running task must not reuse an older successful result'

$failed = New-HealthySnapshot
$failed.tasks[2].last_task_result = 1
$assessment = Test-QmFactoryPostStartHealth -Snapshot $failed @common
Assert-ContainsError -Assessment $assessment -Pattern 'does not have a successful result' `
    -Message 'nonzero critical result must fail'

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

# Latch semantics (2026-08-10): short 5-minute-cadence critical tasks are
# legitimately 'Running' again moments after a fresh success, and overlapping
# triggers poison LastTaskResult with 0x800710E0. One observed fresh
# post-baseline success per task must satisfy the gate for the whole restart
# window; without a latch the same snapshot must keep failing closed.
$latchedRouterOnly = [ordered]@{
    'QM_StrategyFarm_AgentRouter_5min' = [ordered]@{
        latched_at_utc = '2026-07-30T10:00:13Z'
        last_run_utc = '2026-07-30T10:00:11Z'
    }
}
$routerRunningAgain = New-HealthySnapshot
$routerRunningAgain.tasks[1].state = 'Running'
$routerRunningAgain.tasks[1].last_task_result = 2147946720
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerRunningAgain @common
Assert-True -Condition (-not $assessment.healthy) `
    -Message 'running critical task without latch must still fail closed'
$assessment = Test-QmFactoryPostStartHealth -Snapshot $routerRunningAgain @common `
    -LatchedCriticalTasks $latchedRouterOnly
Assert-True -Condition $assessment.healthy `
    -Message 'latched critical task must pass despite Running state and poisoned result'

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
