[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Identity', 'Register', 'Inspect', 'Start')]
    [string]$Operation,

    [ValidatePattern('^QM_QM13210_AUDIT_[0-9a-f]{24}$')]
    [string]$TaskName,

    [string]$PythonExe,
    [string]$ToolPath,
    [string]$JobPath,
    [string]$RepoRoot,

    [ValidateRange(60, 777600)]
    [int]$ExecutionLimitSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
    $python = ConvertTo-QmFullPath -Path $PythonExe -Label 'PythonExe'
    $tool = ConvertTo-QmFullPath -Path $ToolPath -Label 'ToolPath'
    $job = ConvertTo-QmFullPath -Path $JobPath -Label 'JobPath'
    $repo = ConvertTo-QmFullPath -Path $RepoRoot -Label 'RepoRoot'
    foreach ($leaf in @($python, $tool, $job)) {
        if (-not (Test-Path -LiteralPath $leaf -PathType Leaf)) {
            throw "Required task input is not a file: $leaf"
        }
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
    }
}

function Assert-QmTaskContract {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)]$Identity
    )
    if ($Task.TaskPath -cne '\') {
        throw "Scheduled task '$TaskName' escaped the root task path."
    }
    $principalSid = (New-Object System.Security.Principal.NTAccount($Task.Principal.UserId)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
    if ($principalSid -cne $Identity.Sid -or
        $Task.Principal.LogonType.ToString() -cne 'S4U' -or
        $Task.Principal.RunLevel.ToString() -cne 'Highest') {
        throw "Scheduled task '$TaskName' principal drifted from the qm-admin S4U/Highest contract."
    }
    if ($null -ne $Task.Triggers) {
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
    if ($Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew') {
        throw "Scheduled task '$TaskName' must use MultipleInstances=IgnoreNew."
    }
    $actualLimit = [System.Xml.XmlConvert]::ToTimeSpan(
        [string]$Task.Settings.ExecutionTimeLimit
    ).TotalSeconds
    if ([int64]$actualLimit -ne [int64]$ExecutionLimitSeconds) {
        throw "Scheduled task '$TaskName' execution limit drifted."
    }
    if (-not [bool]$Task.Settings.Enabled) {
        throw "Scheduled task '$TaskName' is disabled."
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
        task_name = $TaskName
        task_path = '\'
        state = $Task.State.ToString()
        principal_sid = $Identity.Sid
        logon_type = 'S4U'
        run_level = 'Highest'
        multiple_instances = 'IgnoreNew'
        execution_limit_seconds = $ExecutionLimitSeconds
        last_run_utc = $lastRunUtc
        last_task_result = $info.LastTaskResult
    }
}

$identity = Get-QmCurrentIdentity
if ($Operation -eq 'Identity') {
    [ordered]@{
        operation = 'Identity'
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
$contract = Get-QmTaskContract
$task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue

if ($Operation -eq 'Register') {
    if ($null -eq $task) {
        $action = New-ScheduledTaskAction `
            -Execute $contract.PythonExe `
            -Argument $contract.Arguments `
            -WorkingDirectory $contract.RepoRoot
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
            -Description "QM13210 outcome-fenced persistent audit controller for $([System.IO.Path]::GetFileName($contract.JobPath))." `
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

