[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LeasePath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^S-1-[0-9-]+$')]
    [string]$ExpectedSid,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^(?:QM_DEV1_SMOKE_|QM_DEV1_COMPILE_)[0-9a-f]{32}$')]
    [string]$TargetTaskName,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^QM_DEV1_CLEANUP_[0-9a-f]{32}$')]
    [string]$CleanupTaskName,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^Global\\QM_DEV1_CLEANUP_ACTION_[0-9a-f]{32}$')]
    [string]$CleanupActionMutex,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Dev1Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$script:Dev1ReportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev1')
$script:Dev1UserName = 'QMDev1'
$script:TaskPath = '\'
$script:CleanupActionMutexPrefix = 'Global\QM_DEV1_CLEANUP_ACTION_'
$script:CleanupActionMutexWaitMilliseconds = 180000
$script:ProfileTaskNamePrefix = 'QM_DEV1_PROFILE_INIT_'
$script:CompileTaskNamePrefix = 'QM_DEV1_COMPILE_'
$script:TesterGroupsDev1Path = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt')
$script:FailureMessages = New-Object System.Collections.Generic.List[string]

function Add-QmCleanupFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:FailureMessages.Add($Message)
}

function Enter-QmCleanupActionMutex {
    param(
        [Parameter(Mandatory = $true)][object]$Mutex,
        [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:CleanupActionMutexWaitMilliseconds
    )
    try {
        if (-not [bool]$Mutex.WaitOne($TimeoutMilliseconds)) {
            throw 'Timed out waiting for the per-run cleanup action mutex; cleanup did not start.'
        }
    } catch {
        $cursor = $_.Exception
        while ($null -ne $cursor) {
            if ($cursor -is [System.Threading.AbandonedMutexException]) { return $true }
            $cursor = $cursor.InnerException
        }
        throw
    }
    return $true
}

function Test-QmCleanupControllerDisarmedNoOpState {
    param(
        [Parameter(Mandatory = $true)][bool]$CleanupTaskPresent,
        [Parameter(Mandatory = $true)][bool]$ResultPresent,
        [Parameter(Mandatory = $true)][bool]$DisarmPresent,
        [Parameter(Mandatory = $true)][int]$ContainmentFailureCount
    )
    return (-not $CleanupTaskPresent -and -not $ResultPresent -and -not $DisarmPresent -and
        $ContainmentFailureCount -eq 0)
}

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'Paths may not contain CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-QmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowRoot
    )
    $fullPath = ConvertTo-QmFullPath -Path $Path
    $fullRoot = (ConvertTo-QmFullPath -Path $Root).TrimEnd('\')
    if ($AllowRoot -and $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }
    return $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-QmNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $fullPath = ConvertTo-QmFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Required path does not exist: $fullPath"
    }
    $root = [System.IO.Path]::GetPathRoot($fullPath)
    $relative = $fullPath.Substring($root.Length)
    $cursor = $root
    foreach ($part in @($relative.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse points are forbidden in DEV1 cleanup paths: $cursor"
        }
    }
}

function Get-QmProcessOwnerSid {
    param([Parameter(Mandatory = $true)][object]$ProcessRecord)
    try {
        $owner = Invoke-CimMethod -InputObject $ProcessRecord -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.ReturnValue -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$owner.Sid)) {
            return [string]$owner.Sid
        }
    } catch {
    }
    return $null
}

function Get-QmDev1Processes {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) {
            continue
        }
        if (Test-QmPathWithin -Path ([string]$process.ExecutablePath) -Root $script:Dev1Root) {
            $records.Add([pscustomobject]@{
                ProcessId = [int]$process.ProcessId
                ExecutablePath = ConvertTo-QmFullPath -Path ([string]$process.ExecutablePath)
                CreationDate = $process.CreationDate
                OwnerSid = Get-QmProcessOwnerSid -ProcessRecord $process
            })
        }
    }
    return $records.ToArray()
}

function Get-QmDev1IdentityProcesses {
    param([Parameter(Mandatory = $true)][string]$OwnerSid)
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        $processOwnerSid = Get-QmProcessOwnerSid -ProcessRecord $process
        if ($processOwnerSid -ceq $OwnerSid) {
            $records.Add([pscustomobject]@{
                ProcessId = [int]$process.ProcessId
                ExecutablePath = if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) { $null } else { ConvertTo-QmFullPath -Path ([string]$process.ExecutablePath) }
                CreationDate = $process.CreationDate
                OwnerSid = $processOwnerSid
            })
        }
    }
    return $records.ToArray()
}

function Stop-QmDev1ProcessesExact {
    param([Parameter(Mandatory = $true)][string]$OwnerSid)
    foreach ($candidate in @(Get-QmDev1IdentityProcesses -OwnerSid $OwnerSid)) {
        $fresh = @(Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($candidate.ProcessId)" -Property ProcessId,ExecutablePath,CreationDate -ErrorAction SilentlyContinue)
        if ($fresh.Count -ne 1) {
            continue
        }
        $freshOwner = Get-QmProcessOwnerSid -ProcessRecord $fresh[0]
        if ([string]$fresh[0].CreationDate -eq [string]$candidate.CreationDate -and
            $freshOwner -ceq $OwnerSid) {
            Stop-Process -Id $candidate.ProcessId -Force -ErrorAction Stop
        }
    }
    Start-Sleep -Seconds 2
    $remainingOwner = @(Get-QmDev1IdentityProcesses -OwnerSid $OwnerSid)
    $remainingRoot = @(Get-QmDev1Processes)
    if ($remainingOwner.Count -gt 0 -or $remainingRoot.Count -gt 0) {
        throw "DEV1 cleanup left owner/root processes (owner=$($remainingOwner.Count), root=$($remainingRoot.Count)); ambiguous or wrong-owner processes were not killed."
    }
}

function Stop-QmTargetTaskExact {
    $task = Get-ScheduledTask -TaskName $TargetTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        return
    }
    if ($task.TaskName -cne $TargetTaskName -or $task.TaskPath -cne $script:TaskPath) {
        throw 'Target Scheduled Task identity drifted.'
    }
    if ($task.State.ToString() -eq 'Running') {
        Stop-ScheduledTask -TaskName $TargetTaskName -TaskPath $script:TaskPath -ErrorAction Stop
        $deadline = (Get-Date).ToUniversalTime().AddSeconds(30)
        do {
            Start-Sleep -Milliseconds 500
            $task = Get-ScheduledTask -TaskName $TargetTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
        } while ($null -ne $task -and $task.State.ToString() -eq 'Running' -and (Get-Date).ToUniversalTime() -lt $deadline)
        if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
            throw 'Target DEV1 Scheduled Task did not stop within 30 seconds.'
        }
    }
}

function Unregister-QmTaskExact {
    param([Parameter(Mandatory = $true)][string]$TaskName)
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $script:TaskPath) {
            throw 'Scheduled Task identity drifted before unregister.'
        }
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -Confirm:$false -ErrorAction Stop
    }
    if ($null -ne (Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)) {
        throw "Scheduled Task remains registered after exact unregister: $TaskName"
    }
}

function Write-QmAtomicResult {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][hashtable]$Payload
    )
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    }
    $temporary = Join-Path $parent ('.cleanup.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $json = $Payload | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($temporary, $json, (New-Object System.Text.UTF8Encoding($false)))
    [System.IO.File]::Move($temporary, $Path, $true)
}

function Assert-QmExistingCleanupDisarmReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedContainmentResultPath
    )
    $expectedFields = @(
        'account_restored_disabled', 'artifact_type', 'cleanup_task_name', 'cleanup_task_registered',
        'completed_utc', 'containment_result_path', 'containment_verified', 'dev1_root_process_count',
        'expected_sid', 'failures', 'lease_disarmed', 'owner_process_count', 'schema_version', 'success',
        'target_task_name', 'target_task_registered'
    ) | Sort-Object
    $raw = [System.IO.File]::ReadAllText($Path)
    $document = [System.Text.Json.JsonDocument]::Parse($raw)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw 'Existing cleanup disarm evidence is not a JSON object.'
        }
        $jsonFields = New-Object System.Collections.Generic.List[string]
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { throw 'Existing cleanup disarm evidence has duplicate fields.' }
            $jsonFields.Add($property.Name)
        }
        $ownerCount = [long]0
        $rootCount = [long]0
        $ownerElement = $document.RootElement.GetProperty('owner_process_count')
        $rootElement = $document.RootElement.GetProperty('dev1_root_process_count')
        $failuresElement = $document.RootElement.GetProperty('failures')
        if ([string]::Join('|', @($jsonFields.ToArray() | Sort-Object)) -cne [string]::Join('|', $expectedFields) -or
            $ownerElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $ownerElement.GetRawText() -cne '0' -or -not $ownerElement.TryGetInt64([ref]$ownerCount) -or
            $rootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $rootElement.GetRawText() -cne '0' -or -not $rootElement.TryGetInt64([ref]$rootCount) -or
            $failuresElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Array -or
            $failuresElement.GetArrayLength() -ne 0) {
            throw 'Existing cleanup disarm evidence has invalid exact JSON fields or types.'
        }
    } finally {
        $document.Dispose()
    }
    $receipt = $raw | ConvertFrom-Json -DateKind String -ErrorAction Stop
    if ($receipt.schema_version -isnot [long] -or [long]$receipt.schema_version -ne 1 -or
        $receipt.success -isnot [bool] -or -not [bool]$receipt.success -or
        $receipt.containment_verified -isnot [bool] -or -not [bool]$receipt.containment_verified -or
        $receipt.lease_disarmed -isnot [bool] -or -not [bool]$receipt.lease_disarmed -or
        $receipt.account_restored_disabled -isnot [bool] -or -not [bool]$receipt.account_restored_disabled -or
        $receipt.target_task_registered -isnot [bool] -or [bool]$receipt.target_task_registered -or
        $receipt.cleanup_task_registered -isnot [bool] -or [bool]$receipt.cleanup_task_registered -or
        $receipt.owner_process_count -isnot [long] -or [long]$receipt.owner_process_count -ne 0 -or
        $receipt.dev1_root_process_count -isnot [long] -or [long]$receipt.dev1_root_process_count -ne 0 -or
        [string]$receipt.artifact_type -cne 'QM_DEV1_ACCOUNT_CLEANUP_DISARM_RESULT' -or
        [string]$receipt.expected_sid -cne $ExpectedSid -or
        [string]$receipt.target_task_name -cne $TargetTaskName -or
        [string]$receipt.cleanup_task_name -cne $CleanupTaskName -or
        -not (ConvertTo-QmFullPath -Path ([string]$receipt.containment_result_path)).Equals(
            (ConvertTo-QmFullPath -Path $ExpectedContainmentResultPath), [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Existing cleanup disarm evidence is malformed or not bound to this lease.'
    }
    $completed = [DateTimeOffset]::MinValue
    if ($receipt.completed_utc -isnot [string] -or
        -not [DateTimeOffset]::TryParseExact([string]$receipt.completed_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$completed) -or
        $completed.Offset -ne [TimeSpan]::Zero -or $completed -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        throw 'Existing cleanup disarm evidence has an invalid completion time.'
    }
    return $receipt
}

function Invoke-QmCleanupLeaseAction {
param(
    [switch]$ContainmentOnly,
    [switch]$AllowControllerDisarmedNoOp
)
$lease = $null
$resultPath = $null
$disarmResultPath = $null
$groupsSourcePath = $null
$groupsExpectedSha256 = $null
$manifestValid = $false

try {
    $LeasePath = ConvertTo-QmFullPath -Path $LeasePath
    if (-not (Test-QmPathWithin -Path $LeasePath -Root $script:Dev1ReportsRoot)) {
        throw 'Cleanup lease escaped the DEV1 report root.'
    }
    Assert-QmNoReparseComponents -Path $LeasePath
    $lease = Get-Content -LiteralPath $LeasePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $expectedLeaseFields = @(
        'artifact_type', 'cleanup_action_mutex', 'cleanup_task_name', 'created_utc', 'dev1_root',
        'disarm_result_path', 'expected_sid', 'expires_utc', 'helper_path', 'helper_sha256', 'nonce',
        'result_path', 'run_directory', 'run_id', 'schema_version', 'target_task_name',
        'tester_groups_sha256', 'tester_groups_source_path', 'tester_groups_target_path'
    ) | Sort-Object
    $actualLeaseFields = @($lease.PSObject.Properties.Name | Sort-Object)
    $runDirectory = ConvertTo-QmFullPath -Path ([string]$lease.run_directory)
    $controlDirectory = ConvertTo-QmFullPath -Path (Split-Path -Parent $LeasePath)
    if ([string]::Join('|', $actualLeaseFields) -cne [string]::Join('|', $expectedLeaseFields) -or
        -not (Test-QmPathWithin -Path $runDirectory -Root $script:Dev1ReportsRoot) -or
        -not $controlDirectory.Equals((Join-Path $runDirectory 'control'), [System.StringComparison]::OrdinalIgnoreCase) -or
        [int]$lease.schema_version -ne 1 -or
        [string]$lease.artifact_type -cne 'QM_DEV1_ACCOUNT_CLEANUP_LEASE' -or
        [string]$lease.nonce -cnotmatch '^[0-9a-f]{32}$' -or
        [string]$lease.cleanup_action_mutex -cne $CleanupActionMutex -or
        $CleanupActionMutex -cne ($script:CleanupActionMutexPrefix + [string]$lease.nonce) -or
        [string]$lease.expected_sid -cne $ExpectedSid -or
        [string]$lease.target_task_name -cne $TargetTaskName -or
        [string]$lease.cleanup_task_name -cne $CleanupTaskName -or
        -not (ConvertTo-QmFullPath -Path ([string]$lease.dev1_root)).Equals($script:Dev1Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Cleanup lease identity/path contract drifted.'
    }
    $helperPath = ConvertTo-QmFullPath -Path ([string]$lease.helper_path)
    if (-not $helperPath.Equals((ConvertTo-QmFullPath -Path $PSCommandPath), [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-QmPathWithin -Path $helperPath -Root $controlDirectory) -or
        [string]$lease.helper_sha256 -cne $ExpectedHelperSha256.ToLowerInvariant()) {
        throw 'Cleanup helper path/hash contract drifted.'
    }
    $actualHelperSha256 = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($actualHelperSha256 -cne $ExpectedHelperSha256.ToLowerInvariant()) {
        throw 'Cleanup helper bytes drifted after lease registration.'
    }
    $groupsSourcePath = ConvertTo-QmFullPath -Path ([string]$lease.tester_groups_source_path)
    $groupsExpectedSha256 = ([string]$lease.tester_groups_sha256).ToLowerInvariant()
    $resultPath = ConvertTo-QmFullPath -Path ([string]$lease.result_path)
    $disarmResultPath = ConvertTo-QmFullPath -Path ([string]$lease.disarm_result_path)
    if (-not (Test-QmPathWithin -Path $groupsSourcePath -Root $controlDirectory) -or
        -not (ConvertTo-QmFullPath -Path ([string]$lease.tester_groups_target_path)).Equals($script:TesterGroupsDev1Path, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resultPath.Equals((Join-Path $runDirectory 'control\cleanup_lease.result.json'), [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $disarmResultPath.Equals((Join-Path $runDirectory 'control\cleanup_lease.disarm.result.json'), [System.StringComparison]::OrdinalIgnoreCase) -or
        $groupsExpectedSha256 -notmatch '^[0-9a-f]{64}$') {
        throw 'Cleanup lease tester-groups/result contract drifted.'
    }
    foreach ($path in @($groupsSourcePath, $script:TesterGroupsDev1Path, $helperPath)) {
        Assert-QmNoReparseComponents -Path $path
    }
    if ((Get-FileHash -LiteralPath $groupsSourcePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne $groupsExpectedSha256) {
        throw 'Cleanup lease tester-groups source bytes drifted.'
    }
    $manifestValid = $true
} catch {
    Add-QmCleanupFailure -Message "lease_validation: $($_.Exception.Message)"
    try {
        $candidateRun = ConvertTo-QmFullPath -Path (Split-Path -Parent (Split-Path -Parent $LeasePath))
        if (Test-QmPathWithin -Path $candidateRun -Root $script:Dev1ReportsRoot) {
            $resultPath = Join-Path $candidateRun 'control\cleanup_lease.result.json'
            $disarmResultPath = Join-Path $candidateRun 'control\cleanup_lease.disarm.result.json'
        }
    } catch {
    }
}

try { Stop-QmTargetTaskExact } catch { Add-QmCleanupFailure -Message "task_stop: $($_.Exception.Message)" }
try { Stop-QmDev1ProcessesExact -OwnerSid $ExpectedSid } catch { Add-QmCleanupFailure -Message "process_cleanup: $($_.Exception.Message)" }
try { Unregister-QmTaskExact -TaskName $TargetTaskName } catch { Add-QmCleanupFailure -Message "task_unregister: $($_.Exception.Message)" }

if ($manifestValid) {
    try {
        [System.IO.File]::Copy($groupsSourcePath, $script:TesterGroupsDev1Path, $true)
        $restoredSha256 = (Get-FileHash -LiteralPath $script:TesterGroupsDev1Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($restoredSha256 -cne $groupsExpectedSha256) {
            throw 'Restored DEV1 tester-groups hash mismatch.'
        }
    } catch {
        Add-QmCleanupFailure -Message "tester_groups_restore: $($_.Exception.Message)"
    }
}

$accountDisabled = $false
try {
    $sid = New-Object System.Security.Principal.SecurityIdentifier($ExpectedSid)
    $user = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($user.Name -cne $script:Dev1UserName -or $user.SID.Value -cne $ExpectedSid) {
        throw 'Refusing to disable QMDev1 after SID drift.'
    }
    if ($user.Enabled) {
        Disable-LocalUser -SID $sid -ErrorAction Stop
    }
    $verified = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($verified.Name -cne $script:Dev1UserName -or $verified.SID.Value -cne $ExpectedSid -or $verified.Enabled -or -not $verified.PasswordRequired) {
        throw 'QMDev1 disabled-at-rest verification failed.'
    }
    $accountDisabled = $true
} catch {
    Add-QmCleanupFailure -Message "account_disable: $($_.Exception.Message)"
}

$ownerProcessCount = -1
$rootProcessCount = -1
try {
    $ownerProcessCount = @(Get-QmDev1IdentityProcesses -OwnerSid $ExpectedSid).Count
    $rootProcessCount = @(Get-QmDev1Processes).Count
    if ($ownerProcessCount -ne 0 -or $rootProcessCount -ne 0) {
        throw "DEV1 owner/root process verification failed (owner=$ownerProcessCount, root=$rootProcessCount)."
    }
} catch {
    Add-QmCleanupFailure -Message "process_postflight: $($_.Exception.Message)"
}

$targetTaskRegistered = $true
$cleanupTaskRegistered = $false
$cleanupTaskAbsentAfterControllerDrain = $false
try {
    $targetTaskRegistered = $null -ne (Get-ScheduledTask -TaskName $TargetTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)
    if ($targetTaskRegistered) {
        throw 'Target DEV1 task remains registered after containment.'
    }
} catch {
    Add-QmCleanupFailure -Message "target_task_postflight: $($_.Exception.Message)"
}
try {
    $profileTasks = @(Get-ScheduledTask -TaskPath $script:TaskPath -ErrorAction Stop | Where-Object {
            $_.TaskName.StartsWith($script:ProfileTaskNamePrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($script:CompileTaskNamePrefix, [System.StringComparison]::Ordinal)
        })
    if ($profileTasks.Count -ne 0) {
        throw "Found $($profileTasks.Count) unbound DEV1 profile-init/compile task(s); cleanup will not claim full containment."
    }
} catch {
    Add-QmCleanupFailure -Message "profile_task_postflight: $($_.Exception.Message)"
}
try {
    $cleanupTaskRegistered = $null -ne (Get-ScheduledTask -TaskName $CleanupTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)
    if (-not $cleanupTaskRegistered) {
        if ($AllowControllerDisarmedNoOp.IsPresent) {
            $cleanupTaskAbsentAfterControllerDrain = $true
        } else {
            throw 'Cleanup lease disappeared before its durable containment result.'
        }
    }
} catch {
    Add-QmCleanupFailure -Message "cleanup_task_postflight: $($_.Exception.Message)"
}

if ($ContainmentOnly.IsPresent) {
    if ($script:FailureMessages.Count -ne 0) {
        throw "Pre-fence cleanup containment failed; task remains armed: $([string]::Join(' | ', $script:FailureMessages.ToArray()))"
    }
    return
}

if ($AllowControllerDisarmedNoOp.IsPresent -and $cleanupTaskAbsentAfterControllerDrain) {
    $cleanupTaskPresentNow = $null -ne (Get-ScheduledTask -TaskName $CleanupTaskName `
            -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)
    $resultPresentNow = -not [string]::IsNullOrWhiteSpace($resultPath) -and
        (Test-Path -LiteralPath $resultPath -PathType Leaf)
    $disarmPresentNow = -not [string]::IsNullOrWhiteSpace($disarmResultPath) -and
        (Test-Path -LiteralPath $disarmResultPath -PathType Leaf)
    if (Test-QmCleanupControllerDisarmedNoOpState -CleanupTaskPresent $cleanupTaskPresentNow `
        -ResultPresent $resultPresentNow -DisarmPresent $disarmPresentNow `
        -ContainmentFailureCount $script:FailureMessages.Count) {
        return
    }
    if ($cleanupTaskPresentNow) {
        throw 'Cleanup task reappeared after controller-disarmed post-fence containment.'
    }
}

if (-not [string]::IsNullOrWhiteSpace($disarmResultPath) -and
    (Test-Path -LiteralPath $disarmResultPath -PathType Leaf)) {
    if (-not $manifestValid -or [string]::IsNullOrWhiteSpace($resultPath)) {
        throw 'Existing cleanup disarm evidence cannot be bound after lease validation failure.'
    }
    $existingDisarm = Assert-QmExistingCleanupDisarmReceipt -Path $disarmResultPath `
        -ExpectedContainmentResultPath $resultPath
    Write-Output ($existingDisarm | ConvertTo-Json -Depth 6 -Compress)
    return
}
if (-not [string]::IsNullOrWhiteSpace($resultPath) -and
    (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
    throw 'Existing cleanup containment evidence requires fenced recovery; helper retry refuses to overwrite it.'
}

$containmentPayload = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV1_ACCOUNT_CLEANUP_RESULT'
    completed_utc = (Get-Date).ToUniversalTime().ToString('o')
    success = ($script:FailureMessages.Count -eq 0)
    containment_verified = ($script:FailureMessages.Count -eq 0)
    lease_disarmed = $false
    expected_sid = $ExpectedSid
    target_task_name = $TargetTaskName
    cleanup_task_name = $CleanupTaskName
    manifest_valid = $manifestValid
    account_restored_disabled = $accountDisabled
    owner_process_count = $ownerProcessCount
    dev1_root_process_count = $rootProcessCount
    target_task_registered = $targetTaskRegistered
    cleanup_task_registered = $cleanupTaskRegistered
    failures = @($script:FailureMessages)
}

$containmentResultPersisted = $false
if ([string]::IsNullOrWhiteSpace($resultPath)) {
    Add-QmCleanupFailure -Message 'result_persist: cleanup result path is unavailable'
} else {
    try {
        Write-QmAtomicResult -Path $resultPath -Payload $containmentPayload
        $persisted = Get-Content -LiteralPath $resultPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$persisted.artifact_type -cne 'QM_DEV1_ACCOUNT_CLEANUP_RESULT' -or
            [bool]$persisted.success -ne [bool]$containmentPayload.success -or
            [string]$persisted.cleanup_task_name -cne $CleanupTaskName) {
            throw 'Persisted containment result verification drifted.'
        }
        $containmentResultPersisted = $true
    } catch {
        Add-QmCleanupFailure -Message "result_persist: $($_.Exception.Message)"
    }
}

if ($script:FailureMessages.Count -ne 0 -or -not $containmentResultPersisted) {
    $failurePayload = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV1_ACCOUNT_CLEANUP_RESULT'
        completed_utc = (Get-Date).ToUniversalTime().ToString('o')
        success = $false
        containment_verified = $false
        lease_disarmed = $false
        expected_sid = $ExpectedSid
        target_task_name = $TargetTaskName
        cleanup_task_name = $CleanupTaskName
        manifest_valid = $manifestValid
        account_restored_disabled = $accountDisabled
        owner_process_count = $ownerProcessCount
        dev1_root_process_count = $rootProcessCount
        target_task_registered = $targetTaskRegistered
        cleanup_task_registered = $cleanupTaskRegistered
        failures = @($script:FailureMessages)
    }
    if (-not [string]::IsNullOrWhiteSpace($resultPath)) {
        try { Write-QmAtomicResult -Path $resultPath -Payload $failurePayload } catch { }
    }
    Write-Output ($failurePayload | ConvertTo-Json -Depth 6 -Compress)
    throw 'DEV1 cleanup lease failed before durable disarm; retry remains fail-closed.'
}

try {
    Unregister-QmTaskExact -TaskName $CleanupTaskName
} catch {
    Add-QmCleanupFailure -Message "lease_unregister: $($_.Exception.Message)"
    $containmentPayload.success = $false
    $containmentPayload.containment_verified = $false
    $containmentPayload.failures = @($script:FailureMessages)
    try { Write-QmAtomicResult -Path $resultPath -Payload $containmentPayload } catch { }
    Write-Output ($containmentPayload | ConvertTo-Json -Depth 6 -Compress)
    throw 'DEV1 cleanup lease could not unregister its retry task; retry remains fail-closed.'
}

$disarmPayload = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV1_ACCOUNT_CLEANUP_DISARM_RESULT'
    completed_utc = (Get-Date).ToUniversalTime().ToString('o')
    success = $true
    containment_result_path = $resultPath
    containment_verified = $true
    lease_disarmed = $true
    expected_sid = $ExpectedSid
    target_task_name = $TargetTaskName
    cleanup_task_name = $CleanupTaskName
    account_restored_disabled = $true
    owner_process_count = 0
    dev1_root_process_count = 0
    target_task_registered = $false
    cleanup_task_registered = $false
    failures = @()
}
if ([string]::IsNullOrWhiteSpace($disarmResultPath)) {
    throw 'Cleanup disarm result path is unavailable after successful containment.'
}
Write-QmAtomicResult -Path $disarmResultPath -Payload $disarmPayload
$persistedDisarm = Assert-QmExistingCleanupDisarmReceipt -Path $disarmResultPath `
    -ExpectedContainmentResultPath $resultPath
Write-Output ($persistedDisarm | ConvertTo-Json -Depth 6 -Compress)
}

$null = Invoke-QmCleanupLeaseAction -ContainmentOnly
$cleanupActionMutexHandle = New-Object System.Threading.Mutex($false, $CleanupActionMutex)
$cleanupActionMutexAcquired = $false
try {
    $cleanupActionMutexAcquired = Enter-QmCleanupActionMutex -Mutex $cleanupActionMutexHandle
    Invoke-QmCleanupLeaseAction -AllowControllerDisarmedNoOp
} finally {
    if ($cleanupActionMutexAcquired) {
        try { $cleanupActionMutexHandle.ReleaseMutex() } catch { }
    }
    $cleanupActionMutexHandle.Dispose()
}
