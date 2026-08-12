[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Identity', 'Probe', 'Register', 'Inspect', 'Start')]
    [string]$Operation,

    [ValidatePattern('^QM_QM20002_AUDIT_[0-9a-f]{24}$')]
    [string]$TaskName,

    [string]$PythonExe,
    [string]$ToolPath,
    [string]$JobPath,
    [string]$RepoRoot,

    [ValidateRange(60, 777600)]
    [int]$ExecutionLimitSeconds = 60,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$actualHelperSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'QM20002 scheduled-task helper byte binding drifted.'
}

function ConvertTo-QmFullPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $forbidden = [char[]]@([char]13, [char]10, [char]0, [char]34)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny($forbidden) -ge 0) {
        throw "$Label is empty or contains a forbidden character."
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Quote-QmTaskArgument {
    param([Parameter(Mandatory = $true)][string]$Value)
    $forbidden = [char[]]@([char]13, [char]10, [char]0, [char]34)
    if ($Value.IndexOfAny($forbidden) -ge 0) {
        throw 'Task arguments may not contain CR, LF, NUL, or a quote.'
    }
    return '"' + $Value + '"'
}

function Get-QmCurrentIdentity {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User -or [string]::IsNullOrWhiteSpace($identity.Name)) {
        throw 'Could not resolve the current Windows identity.'
    }
    return [pscustomobject]@{
        Name = $identity.Name
        Sid = $identity.User.Value
    }
}

function Get-QmTaskContract {
    param([switch]$AllowMissingJob)
    $python = ConvertTo-QmFullPath -Path $PythonExe -Label 'PythonExe'
    $tool = ConvertTo-QmFullPath -Path $ToolPath -Label 'ToolPath'
    $job = ConvertTo-QmFullPath -Path $JobPath -Label 'JobPath'
    $repo = ConvertTo-QmFullPath -Path $RepoRoot -Label 'RepoRoot'
    foreach ($leaf in @($python, $tool)) {
        if (-not (Test-Path -LiteralPath $leaf -PathType Leaf)) {
            throw "Required task input is not a file: $leaf"
        }
    }
    if (Test-Path -LiteralPath $job) {
        if (-not (Test-Path -LiteralPath $job -PathType Leaf)) {
            throw "JobPath exists but is not a file: $job"
        }
    } elseif (-not $AllowMissingJob.IsPresent) {
        throw "Required task input is not a file: $job"
    }
    if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
        throw "RepoRoot is not a directory: $repo"
    }
    $arguments = (Quote-QmTaskArgument -Value $tool) +
        ' _run-plan --job ' + (Quote-QmTaskArgument -Value $job)
    return [pscustomobject]@{
        PythonExe = $python
        ToolPath = $tool
        JobPath = $job
        RepoRoot = $repo
        Arguments = $arguments
        Description = "QM20002 outcome-fenced persistent audit controller for $([System.IO.Path]::GetFileName($job))."
    }
}

function Assert-QmTaskContract {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)]$Identity
    )
    if ($Task.TaskName -cne $TaskName -or $Task.TaskPath -cne '\') {
        throw "Scheduled task '$TaskName' escaped the root task path."
    }
    if ([string]$Task.Description -cne $Contract.Description) {
        throw "Scheduled task '$TaskName' description drifted from the exact contract."
    }
    $principalSid = (New-Object System.Security.Principal.NTAccount($Task.Principal.UserId)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
    if ($principalSid -cne $Identity.Sid -or
        $Task.Principal.LogonType.ToString() -cne 'S4U' -or
        $Task.Principal.RunLevel.ToString() -cne 'Highest') {
        throw "Scheduled task '$TaskName' principal drifted from the qm-admin S4U/Highest contract."
    }
    if (@($Task.Triggers).Count -ne 0) {
        throw "Scheduled task '$TaskName' must be triggerless and on-demand only."
    }
    if (@($Task.Actions).Count -ne 1) {
        throw "Scheduled task '$TaskName' must have exactly one action."
    }
    $action = @($Task.Actions)[0]
    if (-not (ConvertTo-QmFullPath -Path $action.Execute -Label 'task action executable').Equals(
            $Contract.PythonExe, [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        [string]$action.Arguments -cne $Contract.Arguments -or
        -not (ConvertTo-QmFullPath -Path $action.WorkingDirectory -Label 'task working directory').Equals(
            $Contract.RepoRoot, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Scheduled task '$TaskName' action drifted from the immutable worker contract."
    }
    if ($Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew' -or
        -not [bool]$Task.Settings.Enabled -or
        -not [bool]$Task.Settings.AllowDemandStart -or
        -not [bool]$Task.Settings.StartWhenAvailable -or
        -not [bool]$Task.Settings.AllowHardTerminate -or
        -not [bool]$Task.Settings.Hidden -or
        [bool]$Task.Settings.DisallowStartIfOnBatteries -or
        [bool]$Task.Settings.StopIfGoingOnBatteries -or
        [bool]$Task.Settings.RunOnlyIfIdle -or
        [bool]$Task.Settings.RunOnlyIfNetworkAvailable -or
        [bool]$Task.Settings.WakeToRun -or
        [int]$Task.Settings.RestartCount -ne 0 -or
        -not [string]::IsNullOrEmpty([string]$Task.Settings.RestartInterval)) {
        throw "Scheduled task '$TaskName' settings drifted from the exact on-demand contract."
    }
    $actualLimit = [System.Xml.XmlConvert]::ToTimeSpan(
        [string]$Task.Settings.ExecutionTimeLimit
    ).TotalSeconds
    if ([int64]$actualLimit -ne [int64]$ExecutionLimitSeconds) {
        throw "Scheduled task '$TaskName' execution limit drifted."
    }
}

function Get-QmSafeTaskMetadata {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Identity
    )
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $lastRunUtc = $null
    if ($info.LastRunTime.Year -gt 2000) {
        $lastRunUtc = $info.LastRunTime.ToUniversalTime().ToString('o')
    }
    return [ordered]@{
        operation = $Operation
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        state = $Task.State.ToString()
        principal_sid = $Identity.Sid
        logon_type = 'S4U'
        run_level = 'Highest'
        triggers_count = @($Task.Triggers).Count
        actions_count = @($Task.Actions).Count
        enabled = [bool]$Task.Settings.Enabled
        allow_demand_start = [bool]$Task.Settings.AllowDemandStart
        multiple_instances = 'IgnoreNew'
        start_when_available = [bool]$Task.Settings.StartWhenAvailable
        allow_hard_terminate = [bool]$Task.Settings.AllowHardTerminate
        hidden = [bool]$Task.Settings.Hidden
        run_only_if_idle = [bool]$Task.Settings.RunOnlyIfIdle
        run_only_if_network_available = [bool]$Task.Settings.RunOnlyIfNetworkAvailable
        wake_to_run = [bool]$Task.Settings.WakeToRun
        restart_count = [int]$Task.Settings.RestartCount
        execution_limit_seconds = $ExecutionLimitSeconds
        last_run_utc = $lastRunUtc
        last_task_result = $info.LastTaskResult
    }
}

$identity = Get-QmCurrentIdentity
if ($Operation -eq 'Identity') {
    [ordered]@{
        operation = 'Identity'
        helper_sha256 = $actualHelperSha256
        principal_name = $identity.Name
        principal_sid = $identity.Sid
        logon_type = 'S4U'
        run_level = 'Highest'
    } | ConvertTo-Json -Depth 3 -Compress
    exit 0
}

if ([string]::IsNullOrWhiteSpace($TaskName)) {
    throw 'TaskName is required for this operation.'
}
$contract = Get-QmTaskContract -AllowMissingJob:($Operation -eq 'Probe')
$task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue

if ($Operation -eq 'Probe') {
    if ($null -eq $task) {
        [ordered]@{
            operation = 'Probe'
            helper_sha256 = $actualHelperSha256
            task_name = $TaskName
            exists = $false
        } | ConvertTo-Json -Depth 3 -Compress
    } else {
        Assert-QmTaskContract -Task $task -Contract $contract -Identity $identity
        $metadata = Get-QmSafeTaskMetadata -Task $task -Identity $identity
        $metadata['exists'] = $true
        $metadata | ConvertTo-Json -Depth 3 -Compress
    }
    exit 0
}

if ($Operation -eq 'Register') {
    if ($null -eq $task) {
        $action = New-ScheduledTaskAction `
            -Execute $contract.PythonExe `
            -Argument $contract.Arguments `
            -WorkingDirectory $contract.RepoRoot
        # This host's cmdlet exposes no creation switch for AllowHardTerminate;
        # Task Scheduler defaults it true and the post-registration assertion
        # above rejects the task before Start if that exact value ever differs.
        $settings = New-ScheduledTaskSettingsSet `
            -AllowStartIfOnBatteries `
            -DontStopIfGoingOnBatteries `
            -StartWhenAvailable `
            -Hidden `
            -ExecutionTimeLimit (New-TimeSpan -Seconds $ExecutionLimitSeconds) `
            -MultipleInstances IgnoreNew
        $principal = New-ScheduledTaskPrincipal `
            -UserId $identity.Name `
            -LogonType S4U `
            -RunLevel Highest
        Register-ScheduledTask `
            -TaskName $TaskName `
            -TaskPath '\' `
            -Action $action `
            -Settings $settings `
            -Principal $principal `
            -Description $contract.Description `
            -ErrorAction Stop | Out-Null
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    }
    Assert-QmTaskContract -Task $task -Contract $contract -Identity $identity
    Get-QmSafeTaskMetadata -Task $task -Identity $identity | ConvertTo-Json -Depth 3 -Compress
    exit 0
}

if ($null -eq $task) {
    throw "Scheduled task '$TaskName' does not exist."
}
Assert-QmTaskContract -Task $task -Contract $contract -Identity $identity

if ($Operation -eq 'Start') {
    if ($task.State.ToString() -eq 'Running') {
        throw "Scheduled task '$TaskName' is already running."
    }
    Start-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $deadline = (Get-Date).ToUniversalTime().AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    } while ($task.State.ToString() -ne 'Running' -and
        $info.LastRunTime.Year -le 2000 -and
        (Get-Date).ToUniversalTime() -lt $deadline)
}

Get-QmSafeTaskMetadata -Task $task -Identity $identity | ConvertTo-Json -Depth 3 -Compress
