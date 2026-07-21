[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Identity', 'Register', 'Inspect', 'Start')]
    [string]$Operation,

    [ValidatePattern('^QM_QM13209_NDX_AUDIT_[0-9a-f]{24}$')]
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
    param([string]$Path, [string]$Label)
    $forbidden = [char[]]@([char]13, [char]10, [char]0, [char]34)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny($forbidden) -ge 0) {
        throw "$Label is empty or contains a forbidden character."
    }
    [System.IO.Path]::GetFullPath($Path)
}

function Quote-QmArgument {
    param([string]$Value)
    $forbidden = [char[]]@([char]13, [char]10, [char]0, [char]34)
    if ($Value.IndexOfAny($forbidden) -ge 0) {
        throw 'Task arguments may not contain CR, LF, NUL, or a quote.'
    }
    '"' + $Value + '"'
}

function Get-QmIdentity {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User -or [string]::IsNullOrWhiteSpace($identity.Name)) {
        throw 'Could not resolve the current Windows identity.'
    }
    [pscustomobject]@{Name=$identity.Name;Sid=$identity.User.Value}
}

function Get-QmContract {
    $python = ConvertTo-QmFullPath $PythonExe 'PythonExe'
    $tool = ConvertTo-QmFullPath $ToolPath 'ToolPath'
    $job = ConvertTo-QmFullPath $JobPath 'JobPath'
    $repo = ConvertTo-QmFullPath $RepoRoot 'RepoRoot'
    foreach ($leaf in @($python, $tool, $job)) {
        if (-not (Test-Path -LiteralPath $leaf -PathType Leaf)) {
            throw "Required task input is not a file: $leaf"
        }
    }
    if (-not (Test-Path -LiteralPath $repo -PathType Container)) {
        throw "RepoRoot is not a directory: $repo"
    }
    [pscustomobject]@{
        Python=$python
        Tool=$tool
        Job=$job
        Repo=$repo
        Arguments=(Quote-QmArgument $tool) + ' _run-plan --job ' + (Quote-QmArgument $job)
    }
}

function Assert-QmTask {
    param($Task, $Contract, $Identity)
    if ($Task.TaskPath -cne '\' -or @($Task.Actions).Count -ne 1 -or $null -ne $Task.Triggers) {
        throw "Scheduled task '$TaskName' topology drifted."
    }
    $principalSid = (New-Object System.Security.Principal.NTAccount($Task.Principal.UserId)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
    if ($principalSid -cne $Identity.Sid -or
        $Task.Principal.LogonType.ToString() -cne 'S4U' -or
        $Task.Principal.RunLevel.ToString() -cne 'Highest') {
        throw "Scheduled task '$TaskName' principal drifted."
    }
    $action = @($Task.Actions)[0]
    if (-not (ConvertTo-QmFullPath $action.Execute 'action executable').Equals(
            $Contract.Python, [StringComparison]::OrdinalIgnoreCase) -or
        [string]$action.Arguments -cne $Contract.Arguments -or
        -not (ConvertTo-QmFullPath $action.WorkingDirectory 'working directory').Equals(
            $Contract.Repo, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Scheduled task '$TaskName' action drifted."
    }
    $actualLimit = [Xml.XmlConvert]::ToTimeSpan([string]$Task.Settings.ExecutionTimeLimit).TotalSeconds
    if ($Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew' -or
        [int64]$actualLimit -ne [int64]$ExecutionLimitSeconds -or
        -not [bool]$Task.Settings.Enabled) {
        throw "Scheduled task '$TaskName' settings drifted."
    }
}

function Get-QmMetadata {
    param($Task, $Identity)
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $lastRunUtc = if ($info.LastRunTime.Year -gt 2000) {$info.LastRunTime.ToUniversalTime().ToString('o')} else {$null}
    [ordered]@{
        operation=$Operation
        task_name=$TaskName
        task_path='\'
        state=$Task.State.ToString()
        principal_sid=$Identity.Sid
        logon_type='S4U'
        run_level='Highest'
        multiple_instances='IgnoreNew'
        execution_limit_seconds=$ExecutionLimitSeconds
        last_run_utc=$lastRunUtc
        last_task_result=$info.LastTaskResult
    }
}

$identity = Get-QmIdentity
if ($Operation -eq 'Identity') {
    [ordered]@{
        operation='Identity';principal_name=$identity.Name;principal_sid=$identity.Sid;
        logon_type='S4U';run_level='Highest'
    } | ConvertTo-Json -Depth 3 -Compress
    exit 0
}
if ([string]::IsNullOrWhiteSpace($TaskName)) {throw 'TaskName is required.'}
$contract = Get-QmContract
$task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue

if ($Operation -eq 'Register') {
    if ($null -eq $task) {
        $action = New-ScheduledTaskAction -Execute $contract.Python -Argument $contract.Arguments -WorkingDirectory $contract.Repo
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
            -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Seconds $ExecutionLimitSeconds) `
            -MultipleInstances IgnoreNew
        $principal = New-ScheduledTaskPrincipal -UserId $identity.Name -LogonType S4U -RunLevel Highest
        Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -Action $action -Settings $settings `
            -Principal $principal -Description 'QM13209 one-shot outcome-fenced NDX prescreen.' -ErrorAction Stop | Out-Null
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    }
    Assert-QmTask $task $contract $identity
    Get-QmMetadata $task $identity | ConvertTo-Json -Depth 3 -Compress
    exit 0
}

if ($null -eq $task) {throw "Scheduled task '$TaskName' does not exist."}
Assert-QmTask $task $contract $identity
$freshStartAck = $false
$startRequestedUtc = $null
if ($Operation -eq 'Start') {
    if ($task.State.ToString() -eq 'Running') {throw "Scheduled task '$TaskName' is already running."}
    $priorInfo = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $priorLastRunUtc = if ($priorInfo.LastRunTime.Year -gt 2000) {
        $priorInfo.LastRunTime.ToUniversalTime()
    } else {[DateTime]::SpecifyKind([DateTime]::MinValue,[DateTimeKind]::Utc)}
    $startRequestedUtc = (Get-Date).ToUniversalTime()
    Start-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $deadline = $startRequestedUtc.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 100
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
        $freshLastRun = $info.LastRunTime.Year -gt 2000 -and
            $info.LastRunTime.ToUniversalTime() -gt $priorLastRunUtc -and
            $info.LastRunTime.ToUniversalTime() -ge $startRequestedUtc.AddSeconds(-2)
        $freshStartAck = $task.State.ToString() -eq 'Running' -or $freshLastRun
    } while (-not $freshStartAck -and (Get-Date).ToUniversalTime() -lt $deadline)
    if (-not $freshStartAck) {throw "Scheduled task '$TaskName' did not acknowledge this fresh start."}
}
$metadata = Get-QmMetadata $task $identity
if ($Operation -eq 'Start') {
    $metadata['fresh_start_ack'] = [bool]$freshStartAck
    $metadata['start_requested_utc'] = $startRequestedUtc.ToString('o')
}
$metadata | ConvertTo-Json -Depth 3 -Compress
