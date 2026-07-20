[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LeasePath,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^S-1-[0-9-]+$')]
    [string]$ExpectedSid,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^QM_DEV2_SMOKE_[0-9a-f]{32}$')]
    [string]$TargetTaskName,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^QM_DEV2_CLEANUP_[0-9a-f]{32}$')]
    [string]$CleanupTaskName,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-fA-F]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Dev2Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$script:Dev2ReportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$script:Dev2UserName = 'QMDev2'
$script:TaskPath = '\'
$script:TesterGroupsDev2Path = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt')
$script:FailureMessages = New-Object System.Collections.Generic.List[string]

function Add-QmCleanupFailure {
    param([Parameter(Mandatory = $true)][string]$Message)
    $script:FailureMessages.Add($Message)
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
            throw "Reparse points are forbidden in DEV2 cleanup paths: $cursor"
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

function Get-QmDev2Processes {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) {
            continue
        }
        if (Test-QmPathWithin -Path ([string]$process.ExecutablePath) -Root $script:Dev2Root) {
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

function Get-QmDev2IdentityProcesses {
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

function Stop-QmDev2ProcessesExact {
    param([Parameter(Mandatory = $true)][string]$OwnerSid)
    foreach ($candidate in @(Get-QmDev2IdentityProcesses -OwnerSid $OwnerSid)) {
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
    $remainingOwner = @(Get-QmDev2IdentityProcesses -OwnerSid $OwnerSid)
    $remainingRoot = @(Get-QmDev2Processes)
    if ($remainingOwner.Count -gt 0 -or $remainingRoot.Count -gt 0) {
        throw "DEV2 cleanup left owner/root processes (owner=$($remainingOwner.Count), root=$($remainingRoot.Count)); ambiguous or wrong-owner processes were not killed."
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
            throw 'Target DEV2 Scheduled Task did not stop within 30 seconds.'
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

$lease = $null
$resultPath = $null
$disarmResultPath = $null
$groupsSourcePath = $null
$groupsExpectedSha256 = $null
$manifestValid = $false

try {
    $LeasePath = ConvertTo-QmFullPath -Path $LeasePath
    if (-not (Test-QmPathWithin -Path $LeasePath -Root $script:Dev2ReportsRoot)) {
        throw 'Cleanup lease escaped the DEV2 report root.'
    }
    Assert-QmNoReparseComponents -Path $LeasePath
    $lease = Get-Content -LiteralPath $LeasePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $runDirectory = ConvertTo-QmFullPath -Path ([string]$lease.run_directory)
    $controlDirectory = ConvertTo-QmFullPath -Path (Split-Path -Parent $LeasePath)
    if (-not (Test-QmPathWithin -Path $runDirectory -Root $script:Dev2ReportsRoot) -or
        -not $controlDirectory.Equals((Join-Path $runDirectory 'control'), [System.StringComparison]::OrdinalIgnoreCase) -or
        [int]$lease.schema_version -ne 1 -or
        [string]$lease.artifact_type -cne 'QM_DEV2_ACCOUNT_CLEANUP_LEASE' -or
        [string]$lease.expected_sid -cne $ExpectedSid -or
        [string]$lease.target_task_name -cne $TargetTaskName -or
        [string]$lease.cleanup_task_name -cne $CleanupTaskName -or
        -not (ConvertTo-QmFullPath -Path ([string]$lease.dev2_root)).Equals($script:Dev2Root, [System.StringComparison]::OrdinalIgnoreCase)) {
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
        -not (ConvertTo-QmFullPath -Path ([string]$lease.tester_groups_target_path)).Equals($script:TesterGroupsDev2Path, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resultPath.Equals((Join-Path $runDirectory 'output\cleanup_lease.result.json'), [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $disarmResultPath.Equals((Join-Path $runDirectory 'output\cleanup_lease.disarm.result.json'), [System.StringComparison]::OrdinalIgnoreCase) -or
        $groupsExpectedSha256 -notmatch '^[0-9a-f]{64}$') {
        throw 'Cleanup lease tester-groups/result contract drifted.'
    }
    foreach ($path in @($groupsSourcePath, $script:TesterGroupsDev2Path, $helperPath)) {
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
        if (Test-QmPathWithin -Path $candidateRun -Root $script:Dev2ReportsRoot) {
            $resultPath = Join-Path $candidateRun 'output\cleanup_lease.result.json'
            $disarmResultPath = Join-Path $candidateRun 'output\cleanup_lease.disarm.result.json'
        }
    } catch {
    }
}

try { Stop-QmTargetTaskExact } catch { Add-QmCleanupFailure -Message "task_stop: $($_.Exception.Message)" }
try { Stop-QmDev2ProcessesExact -OwnerSid $ExpectedSid } catch { Add-QmCleanupFailure -Message "process_cleanup: $($_.Exception.Message)" }
try { Unregister-QmTaskExact -TaskName $TargetTaskName } catch { Add-QmCleanupFailure -Message "task_unregister: $($_.Exception.Message)" }

if ($manifestValid) {
    try {
        [System.IO.File]::Copy($groupsSourcePath, $script:TesterGroupsDev2Path, $true)
        $restoredSha256 = (Get-FileHash -LiteralPath $script:TesterGroupsDev2Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($restoredSha256 -cne $groupsExpectedSha256) {
            throw 'Restored DEV2 tester-groups hash mismatch.'
        }
    } catch {
        Add-QmCleanupFailure -Message "tester_groups_restore: $($_.Exception.Message)"
    }
}

$accountDisabled = $false
try {
    $sid = New-Object System.Security.Principal.SecurityIdentifier($ExpectedSid)
    $user = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($user.Name -cne $script:Dev2UserName -or $user.SID.Value -cne $ExpectedSid) {
        throw 'Refusing to disable QMDev2 after SID drift.'
    }
    if ($user.Enabled) {
        Disable-LocalUser -SID $sid -ErrorAction Stop
    }
    $verified = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($verified.Name -cne $script:Dev2UserName -or $verified.SID.Value -cne $ExpectedSid -or $verified.Enabled -or -not $verified.PasswordRequired) {
        throw 'QMDev2 disabled-at-rest verification failed.'
    }
    $accountDisabled = $true
} catch {
    Add-QmCleanupFailure -Message "account_disable: $($_.Exception.Message)"
}

$ownerProcessCount = -1
$rootProcessCount = -1
try {
    $ownerProcessCount = @(Get-QmDev2IdentityProcesses -OwnerSid $ExpectedSid).Count
    $rootProcessCount = @(Get-QmDev2Processes).Count
    if ($ownerProcessCount -ne 0 -or $rootProcessCount -ne 0) {
        throw "DEV2 owner/root process verification failed (owner=$ownerProcessCount, root=$rootProcessCount)."
    }
} catch {
    Add-QmCleanupFailure -Message "process_postflight: $($_.Exception.Message)"
}

$targetTaskRegistered = $true
$cleanupTaskRegistered = $false
try {
    $targetTaskRegistered = $null -ne (Get-ScheduledTask -TaskName $TargetTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)
    if ($targetTaskRegistered) {
        throw 'Target DEV2 task remains registered after containment.'
    }
} catch {
    Add-QmCleanupFailure -Message "target_task_postflight: $($_.Exception.Message)"
}
try {
    $cleanupTaskRegistered = $null -ne (Get-ScheduledTask -TaskName $CleanupTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)
    if (-not $cleanupTaskRegistered) {
        throw 'Cleanup lease disappeared before its durable containment result.'
    }
} catch {
    Add-QmCleanupFailure -Message "cleanup_task_postflight: $($_.Exception.Message)"
}

$containmentPayload = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_RESULT'
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
    dev2_root_process_count = $rootProcessCount
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
        if ([string]$persisted.artifact_type -cne 'QM_DEV2_ACCOUNT_CLEANUP_RESULT' -or
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
        artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_RESULT'
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
        dev2_root_process_count = $rootProcessCount
        target_task_registered = $targetTaskRegistered
        cleanup_task_registered = $cleanupTaskRegistered
        failures = @($script:FailureMessages)
    }
    if (-not [string]::IsNullOrWhiteSpace($resultPath)) {
        try { Write-QmAtomicResult -Path $resultPath -Payload $failurePayload } catch { }
    }
    Write-Output ($failurePayload | ConvertTo-Json -Depth 6 -Compress)
    exit 2
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
    exit 2
}

$disarmPayload = [ordered]@{
    schema_version = 1
    artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT'
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
    dev2_root_process_count = 0
    target_task_registered = $false
    cleanup_task_registered = $false
    failures = @()
}
if (-not [string]::IsNullOrWhiteSpace($disarmResultPath)) {
    try { Write-QmAtomicResult -Path $disarmResultPath -Payload $disarmPayload } catch { }
}
Write-Output ($disarmPayload | ConvertTo-Json -Depth 6 -Compress)
