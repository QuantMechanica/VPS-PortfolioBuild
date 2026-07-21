[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Identity', 'InspectReady', 'Quiesce', 'InspectQuiesced', 'AwaitQuiesced', 'Unregister', 'ProbeAbsent')]
    [string]$Operation,

    [ValidatePattern('^QM_QM20002_AUDIT_[0-9a-f]{24}$')]
    [string]$TaskName,

    [string]$PythonExe,
    [string]$ToolPath,
    [string]$JobPath,
    [string]$RepoRoot,

    [ValidateRange(60, 777600)]
    [int]$ExecutionLimitSeconds = 60,

    [ValidatePattern('^S-1-[0-9-]+$')]
    [string]$ExpectedPrincipalSid,

    [ValidatePattern('^S-1-[0-9-]+$')]
    [string]$ExpectedDev1Sid,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedDisabledXmlSha256,

    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedTaskContractSha256,

    [switch]$AllowObservedStartRace,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$actualHelperSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'QM20002 G1 closure task helper byte binding drifted.'
}

if (-not ('QmG1ProcessProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;

public sealed class QmG1ProcessRecord
{
    public int ProcessId { get; set; }
    public long CreationFileTimeUtc { get; set; }
    public string OwnerSid { get; set; }
    public string ImagePath { get; set; }
}

public static class QmG1ProcessProbe
{
    private const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;
    private const uint TOKEN_QUERY = 0x0008;
    private const uint STILL_ACTIVE = 259;
    private const int ERROR_ACCESS_DENIED = 5;
    private const int ERROR_INVALID_PARAMETER = 87;
    private const int TokenUser = 1;

    [StructLayout(LayoutKind.Sequential)]
    private struct FILETIME
    {
        public uint LowDateTime;
        public uint HighDateTime;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SID_AND_ATTRIBUTES
    {
        public IntPtr Sid;
        public uint Attributes;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct TOKEN_USER
    {
        public SID_AND_ATTRIBUTES User;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr OpenProcess(uint access, bool inheritHandle, uint processId);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetProcessTimes(
        IntPtr process,
        out FILETIME creation,
        out FILETIME exit,
        out FILETIME kernel,
        out FILETIME user);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool QueryFullProcessImageName(
        IntPtr process,
        int flags,
        StringBuilder imagePath,
        ref int size);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(
        IntPtr token,
        int tokenInformationClass,
        IntPtr tokenInformation,
        int tokenInformationLength,
        out int returnLength);

    private static bool HasExited(IntPtr process)
    {
        uint exitCode;
        return GetExitCodeProcess(process, out exitCode) && exitCode != STILL_ACTIVE;
    }

    private static long ToInt64(FILETIME value)
    {
        return ((long)value.HighDateTime << 32) | value.LowDateTime;
    }

    private static string ReadOwnerSid(IntPtr process)
    {
        IntPtr token;
        if (!OpenProcessToken(process, TOKEN_QUERY, out token))
        {
            if (HasExited(process)) return null;
            throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenProcessToken failed");
        }
        try
        {
            int needed = 0;
            GetTokenInformation(token, TokenUser, IntPtr.Zero, 0, out needed);
            if (needed <= 0)
                throw new Win32Exception(Marshal.GetLastWin32Error(), "TokenUser size query failed");
            IntPtr buffer = Marshal.AllocHGlobal(needed);
            try
            {
                if (!GetTokenInformation(token, TokenUser, buffer, needed, out needed))
                    throw new Win32Exception(Marshal.GetLastWin32Error(), "TokenUser query failed");
                TOKEN_USER user = (TOKEN_USER)Marshal.PtrToStructure(buffer, typeof(TOKEN_USER));
                return new SecurityIdentifier(user.User.Sid).Value;
            }
            finally
            {
                Marshal.FreeHGlobal(buffer);
            }
        }
        finally
        {
            CloseHandle(token);
        }
    }

    private static string ReadImagePath(IntPtr process, int processId, string processName, string ownerSid)
    {
        int capacity = 32768;
        StringBuilder path = new StringBuilder(capacity);
        if (!QueryFullProcessImageName(process, 0, path, ref capacity))
        {
            if (HasExited(process)) return null;
            int error = Marshal.GetLastWin32Error();
            if (error == 0 && processName == "Registry" && ownerSid == "S-1-5-18")
                return "[KERNEL_REGISTRY_PROCESS_NO_USER_IMAGE]";
            throw new Win32Exception(error, "QueryFullProcessImageName failed for PID " + processId + " with error " + error);
        }
        return path.ToString();
    }

    private static QmG1ProcessRecord ProbeOne(int processId, string processName)
    {
        if (processId == 0 || processId == 4) return null;
        IntPtr process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, false, (uint)processId);
        if (process == IntPtr.Zero)
        {
            int error = Marshal.GetLastWin32Error();
            if (error == ERROR_INVALID_PARAMETER) return null;
            if (error == ERROR_ACCESS_DENIED)
                throw new Win32Exception(error, "Cannot prove process owner for PID " + processId);
            throw new Win32Exception(error, "OpenProcess failed for PID " + processId);
        }
        try
        {
            if (HasExited(process)) return null;
            FILETIME creation, exit, kernel, user;
            if (!GetProcessTimes(process, out creation, out exit, out kernel, out user))
            {
                if (HasExited(process)) return null;
                throw new Win32Exception(Marshal.GetLastWin32Error(), "GetProcessTimes failed");
            }
            string ownerSid = ReadOwnerSid(process);
            if (ownerSid == null) return null;
            string imagePath = ReadImagePath(process, processId, processName, ownerSid);
            if (imagePath == null) return null;
            if (HasExited(process)) return null;
            return new QmG1ProcessRecord {
                ProcessId = processId,
                CreationFileTimeUtc = ToInt64(creation),
                OwnerSid = ownerSid,
                ImagePath = imagePath
            };
        }
        finally
        {
            CloseHandle(process);
        }
    }

    public static QmG1ProcessRecord[] Snapshot()
    {
        List<QmG1ProcessRecord> records = new List<QmG1ProcessRecord>();
        foreach (Process process in Process.GetProcesses())
        {
            try
            {
                int processId;
                string processName;
                try
                {
                    processId = process.Id;
                    processName = process.ProcessName;
                }
                catch (InvalidOperationException)
                {
                    // The process exited between enumeration and handle capture.
                    continue;
                }
                QmG1ProcessRecord record = ProbeOne(processId, processName);
                if (record != null) records.Add(record);
            }
            finally
            {
                process.Dispose();
            }
        }
        records.Sort((left, right) => left.ProcessId != right.ProcessId
            ? left.ProcessId.CompareTo(right.ProcessId)
            : left.CreationFileTimeUtc.CompareTo(right.CreationFileTimeUtc));
        return records.ToArray();
    }
}
'@
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

function Get-QmNonNullItemCount {
    param($Items)
    $count = 0
    foreach ($item in @($Items)) {
        if ($null -ne $item) { $count++ }
    }
    return $count
}

function Get-QmCurrentIdentity {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    if ($null -eq $identity.User -or [string]::IsNullOrWhiteSpace($identity.Name)) {
        throw 'Could not resolve the current Windows identity.'
    }
    return [pscustomobject]@{ Name = $identity.Name; Sid = $identity.User.Value }
}

function Get-QmSha256Text {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Value)
    $algorithm = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    } finally {
        $algorithm.Dispose()
    }
}

function Get-QmTaskXmlSha256 {
    $xml = Export-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    return Get-QmSha256Text -Value ([string]$xml)
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
    if ([string]::IsNullOrWhiteSpace($ExpectedPrincipalSid) -or
        [string]::IsNullOrWhiteSpace($ExpectedDev1Sid)) {
        throw 'Expected principal and DEV1 SIDs are mandatory for G1 task recovery.'
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

function Get-QmStableProcessEvidence {
    $dev1Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1').TrimEnd('\') + '\'
    $previousSignature = $null
    for ($attempt = 1; $attempt -le 4; $attempt++) {
        $records = @([QmG1ProcessProbe]::Snapshot())
        $relevant = @($records | Where-Object {
            $_.OwnerSid -ceq $ExpectedDev1Sid -or
            (-not [string]::IsNullOrWhiteSpace($_.ImagePath) -and
             $_.ImagePath.StartsWith($dev1Root, [System.StringComparison]::OrdinalIgnoreCase))
        })
        $signatureText = (($relevant | ForEach-Object {
            "$($_.ProcessId):$($_.CreationFileTimeUtc):$($_.OwnerSid):$($_.ImagePath)"
        }) -join "`n")
        $signature = Get-QmSha256Text -Value $signatureText
        if ($null -ne $previousSignature -and $signature -ceq $previousSignature) {
            $ownerCount = @($relevant | Where-Object { $_.OwnerSid -ceq $ExpectedDev1Sid }).Count
            $rootCount = @($relevant | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.ImagePath) -and
                $_.ImagePath.StartsWith($dev1Root, [System.StringComparison]::OrdinalIgnoreCase)
            }).Count
            return [ordered]@{
                dev1_owner_process_count = $ownerCount
                dev1_root_process_count = $rootCount
                relevant_process_identity_sha256 = $signature
                stable_snapshot_count = 2
                process_probe_method = 'NATIVE_PROCESS_HANDLE_TOKEN_SID_AND_IMAGE_PATH_STABLE_DOUBLE_SNAPSHOT_NO_COMMAND_LINE'
            }
        }
        $previousSignature = $signature
        Start-Sleep -Milliseconds 50
    }
    throw 'Could not obtain two stable native DEV1 process snapshots.'
}

function Assert-QmNoProcessSideEffects {
    param([Parameter(Mandatory = $true)]$Evidence)
    if ([int]$Evidence.dev1_owner_process_count -ne 0 -or
        [int]$Evidence.dev1_root_process_count -ne 0) {
        throw 'G1 closure observed worker or DEV1 process side effects.'
    }
}

function Get-QmTaskInfoEvidence {
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $lastRunUtc = $null
    if ($info.LastRunTime.Year -gt 2000) {
        $lastRunUtc = $info.LastRunTime.ToUniversalTime().ToString('o')
    }
    $lastResult = [int64]$info.LastTaskResult
    $neverRun = $null -eq $lastRunUtc -and $lastResult -in @([int64]0, [int64]267011)
    return [ordered]@{
        last_run_utc = $lastRunUtc
        last_task_result = $lastResult
        never_run = $neverRun
    }
}

function Get-QmTaskContractSha256 {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)][string]$PrincipalSid
    )
    $action = @($Task.Actions | Where-Object { $null -ne $_ })[0]
    $actualLimit = [int64]([System.Xml.XmlConvert]::ToTimeSpan(
        [string]$Task.Settings.ExecutionTimeLimit
    ).TotalSeconds)
    $payload = [ordered]@{
        task_name = [string]$Task.TaskName
        task_path = [string]$Task.TaskPath
        description = [string]$Task.Description
        principal_sid = $PrincipalSid
        logon_type = [string]$Task.Principal.LogonType.ToString()
        run_level = [string]$Task.Principal.RunLevel.ToString()
        non_null_trigger_count = Get-QmNonNullItemCount -Items $Task.Triggers
        non_null_action_count = Get-QmNonNullItemCount -Items $Task.Actions
        action_execute = ConvertTo-QmFullPath -Path $action.Execute -Label 'task action executable'
        action_arguments = [string]$action.Arguments
        action_working_directory = ConvertTo-QmFullPath -Path $action.WorkingDirectory -Label 'task working directory'
        multiple_instances = [string]$Task.Settings.MultipleInstances.ToString()
        allow_demand_start = [bool]$Task.Settings.AllowDemandStart
        start_when_available = [bool]$Task.Settings.StartWhenAvailable
        allow_hard_terminate = [bool]$Task.Settings.AllowHardTerminate
        hidden = [bool]$Task.Settings.Hidden
        disallow_start_if_on_batteries = [bool]$Task.Settings.DisallowStartIfOnBatteries
        stop_if_going_on_batteries = [bool]$Task.Settings.StopIfGoingOnBatteries
        run_only_if_idle = [bool]$Task.Settings.RunOnlyIfIdle
        run_only_if_network_available = [bool]$Task.Settings.RunOnlyIfNetworkAvailable
        wake_to_run = [bool]$Task.Settings.WakeToRun
        restart_count = [int]$Task.Settings.RestartCount
        restart_interval = [string]$Task.Settings.RestartInterval
        execution_limit_seconds = $actualLimit
        expected_python = $Contract.PythonExe
        expected_arguments = $Contract.Arguments
        expected_repo_root = $Contract.RepoRoot
    }
    return Get-QmSha256Text -Value ($payload | ConvertTo-Json -Depth 5 -Compress)
}

function Assert-QmTaskContract {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][bool]$RequireDisabled
    )
    if ($Task.TaskName -cne $TaskName -or $Task.TaskPath -cne '\') {
        throw "Scheduled task '$TaskName' escaped the root task path."
    }
    if ([string]$Task.Description -cne $Contract.Description) {
        throw "Scheduled task '$TaskName' description drifted from the exact G1 contract."
    }
    $principalSid = (New-Object System.Security.Principal.NTAccount($Task.Principal.UserId)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
    if ($principalSid -cne $ExpectedPrincipalSid -or
        $principalSid -cne $Identity.Sid -or
        $Task.Principal.LogonType.ToString() -cne 'S4U' -or
        $Task.Principal.RunLevel.ToString() -cne 'Highest') {
        throw "Scheduled task '$TaskName' principal drifted from the exact qm-admin S4U/Highest contract."
    }
    if ((Get-QmNonNullItemCount -Items $Task.Triggers) -ne 0) {
        throw "Scheduled task '$TaskName' has an actual trigger."
    }
    if ((Get-QmNonNullItemCount -Items $Task.Actions) -ne 1) {
        throw "Scheduled task '$TaskName' must have exactly one non-null action."
    }
    $action = @($Task.Actions | Where-Object { $null -ne $_ })[0]
    if (-not (ConvertTo-QmFullPath -Path $action.Execute -Label 'task action executable').Equals(
            $Contract.PythonExe, [System.StringComparison]::OrdinalIgnoreCase
        ) -or
        [string]$action.Arguments -cne $Contract.Arguments -or
        -not (ConvertTo-QmFullPath -Path $action.WorkingDirectory -Label 'task working directory').Equals(
            $Contract.RepoRoot, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw "Scheduled task '$TaskName' action drifted from the immutable G1 worker contract."
    }
    $enabled = [bool]$Task.Settings.Enabled
    if (($RequireDisabled -and $enabled) -or ((-not $RequireDisabled) -and (-not $enabled)) -or
        $Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew' -or
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
        throw "Scheduled task '$TaskName' settings drifted from the exact G1 contract."
    }
    $actualLimit = [System.Xml.XmlConvert]::ToTimeSpan(
        [string]$Task.Settings.ExecutionTimeLimit
    ).TotalSeconds
    if ([int64]$actualLimit -ne [int64]$ExecutionLimitSeconds) {
        throw "Scheduled task '$TaskName' execution limit drifted."
    }
}

function Get-QmExactTask {
    $tasks = @(Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue)
    if ($tasks.Count -ne 1) {
        throw "Expected exactly one G1 scheduled task '$TaskName'; observed $($tasks.Count)."
    }
    return $tasks[0]
}

function Get-QmClosureEvidence {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)]$Contract,
        [Parameter(Mandatory = $true)]$Identity,
        [Parameter(Mandatory = $true)][bool]$RequireDisabled,
        [bool]$RequireNeverRun = $true
    )
    Assert-QmTaskContract -Task $Task -Contract $Contract -Identity $Identity -RequireDisabled $RequireDisabled
    $info = Get-QmTaskInfoEvidence
    if ($RequireNeverRun -and -not [bool]$info.never_run) {
        throw "Scheduled task '$TaskName' has run or has ambiguous run history."
    }
    $processes = Get-QmStableProcessEvidence
    Assert-QmNoProcessSideEffects -Evidence $processes
    $workerInferenceBasis = if ($Task.State.ToString() -ceq 'Running') {
        'INFERRED_FROM_CALLER_HELD_STATE_LOCK_AND_DIRECT_ZERO_DEV1_OWNER_OR_ROOT'
    } elseif ([bool]$info.never_run) {
        'INFERRED_FROM_EXACT_NEVER_RUN_TASK_HISTORY_AND_NON_RUNNING_TASK_STATE'
    } else {
        'INFERRED_FROM_DURABLE_TERMINAL_REJECT_AND_NON_RUNNING_TASK_STATE'
    }
    return [ordered]@{
        state = $Task.State.ToString()
        enabled = [bool]$Task.Settings.Enabled
        last_run_utc = $info.last_run_utc
        last_task_result = [int64]$info.last_task_result
        never_run = [bool]$info.never_run
        non_null_trigger_count = Get-QmNonNullItemCount -Items $Task.Triggers
        non_null_action_count = Get-QmNonNullItemCount -Items $Task.Actions
        task_xml_sha256 = Get-QmTaskXmlSha256
        task_contract_sha256 = Get-QmTaskContractSha256 -Task $Task -Contract $Contract -PrincipalSid $Identity.Sid
        matching_worker_process_count = 0
        matching_worker_process_count_basis = $workerInferenceBasis
        dev1_owner_process_count = [int]$processes.dev1_owner_process_count
        dev1_root_process_count = [int]$processes.dev1_root_process_count
        relevant_process_identity_sha256 = [string]$processes.relevant_process_identity_sha256
        stable_snapshot_count = [int]$processes.stable_snapshot_count
        process_probe_method = [string]$processes.process_probe_method
    }
}

$identity = Get-QmCurrentIdentity
if ($Operation -eq 'Identity') {
    [ordered]@{
        operation = 'Identity'
        helper_sha256 = $actualHelperSha256
        principal_name = $identity.Name
        principal_sid = $identity.Sid
    } | ConvertTo-Json -Depth 4 -Compress
    exit 0
}

$contract = Get-QmTaskContract
if ($Operation -eq 'ProbeAbsent') {
    $tasks = @(Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue)
    if ($tasks.Count -ne 0) {
        throw "G1 scheduled task '$TaskName' is not absent."
    }
    $processes = Get-QmStableProcessEvidence
    Assert-QmNoProcessSideEffects -Evidence $processes
    [ordered]@{
        operation = 'ProbeAbsent'
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        absent = $true
        matching_worker_process_count = 0
        matching_worker_process_count_basis = 'INFERRED_FROM_DURABLE_NEVER_RUN_CLOSURE_PROOF_REQUIRED_BY_CALLER'
        dev1_owner_process_count = [int]$processes.dev1_owner_process_count
        dev1_root_process_count = [int]$processes.dev1_root_process_count
        relevant_process_identity_sha256 = [string]$processes.relevant_process_identity_sha256
        stable_snapshot_count = [int]$processes.stable_snapshot_count
        process_probe_method = [string]$processes.process_probe_method
    } | ConvertTo-Json -Depth 4 -Compress
    exit 0
}

if ($Operation -eq 'InspectReady') {
    $readyTask = Get-QmExactTask
    $ready = Get-QmClosureEvidence -Task $readyTask -Contract $contract -Identity $identity -RequireDisabled $false
    if ($ready.state -cne 'Ready') {
        throw "Enabled G1 scheduled task '$TaskName' is not exactly Ready."
    }
    [ordered]@{
        operation = 'InspectReady'
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        principal_sid = $identity.Sid
        evidence = $ready
        absent = $false
    } | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

if ($Operation -eq 'Quiesce') {
    $beforeTask = Get-QmExactTask
    $beforeDisabled = -not [bool]$beforeTask.Settings.Enabled
    $before = Get-QmClosureEvidence -Task $beforeTask -Contract $contract -Identity $identity -RequireDisabled $beforeDisabled
    if ([string]::IsNullOrWhiteSpace($ExpectedTaskContractSha256) -or
        $before.task_contract_sha256 -cne $ExpectedTaskContractSha256) {
        throw 'G1 task contract drifted from the durable closure intent.'
    }
    if (-not $beforeDisabled -and $before.state -cne 'Ready') {
        throw "Enabled G1 scheduled task '$TaskName' is not exactly Ready before quiescence."
    }
    if (-not $beforeDisabled) {
        Disable-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop | Out-Null
    }
    $afterTask = Get-QmExactTask
    $after = Get-QmClosureEvidence -Task $afterTask -Contract $contract -Identity $identity -RequireDisabled $true -RequireNeverRun $false
    if ($after.task_contract_sha256 -cne $ExpectedTaskContractSha256 -or
        $after.state -notin @('Disabled', 'Running')) {
        throw 'G1 task contract/state drifted while it was being disabled.'
    }
    [ordered]@{
        operation = 'Quiesce'
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        principal_sid = $identity.Sid
        before = $before
        after = $after
        start_race_observed = (-not [bool]$after.never_run) -or $after.state -ceq 'Running'
        absent = $false
    } | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

$task = Get-QmExactTask
$requireNeverRun = -not [bool]$AllowObservedStartRace
$evidence = Get-QmClosureEvidence -Task $task -Contract $contract -Identity $identity -RequireDisabled $true -RequireNeverRun $requireNeverRun
if ($evidence.state -cne 'Disabled') {
    if ($Operation -ne 'AwaitQuiesced') {
        throw "G1 scheduled task '$TaskName' is not exactly Disabled."
    }
}
if (-not [string]::IsNullOrWhiteSpace($ExpectedTaskContractSha256) -and
    $evidence.task_contract_sha256 -cne $ExpectedTaskContractSha256) {
    throw 'G1 quiesced task contract drifted from the durable closure intent.'
}

if ($Operation -eq 'InspectQuiesced') {
    [ordered]@{
        operation = 'InspectQuiesced'
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        principal_sid = $identity.Sid
        evidence = $evidence
        absent = $false
    } | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

if ($Operation -eq 'AwaitQuiesced') {
    $deadline = [DateTime]::UtcNow.AddSeconds(30)
    while ($evidence.state -cne 'Disabled') {
        if ([DateTime]::UtcNow -ge $deadline) {
            throw "G1 scheduled task '$TaskName' did not stop after terminal REJECT publication."
        }
        Start-Sleep -Milliseconds 100
        $task = Get-QmExactTask
        $evidence = Get-QmClosureEvidence -Task $task -Contract $contract -Identity $identity -RequireDisabled $true -RequireNeverRun $requireNeverRun
    }
    [ordered]@{
        operation = 'AwaitQuiesced'
        helper_sha256 = $actualHelperSha256
        task_name = $TaskName
        task_path = '\'
        principal_sid = $identity.Sid
        evidence = $evidence
        start_race_observed = (-not [bool]$evidence.never_run)
        absent = $false
    } | ConvertTo-Json -Depth 6 -Compress
    exit 0
}

if ([string]::IsNullOrWhiteSpace($ExpectedTaskContractSha256) -or
    [string]::IsNullOrWhiteSpace($ExpectedDisabledXmlSha256) -or
    $evidence.task_xml_sha256 -cne $ExpectedDisabledXmlSha256) {
    throw 'G1 disabled task XML or contract drifted before unregister.'
}
Unregister-ScheduledTask -TaskName $TaskName -TaskPath '\' -Confirm:$false -ErrorAction Stop
$remaining = @(Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction SilentlyContinue)
if ($remaining.Count -ne 0) {
    throw "G1 scheduled task '$TaskName' remained after unregister."
}
$processes = Get-QmStableProcessEvidence
Assert-QmNoProcessSideEffects -Evidence $processes
[ordered]@{
    operation = 'Unregister'
    helper_sha256 = $actualHelperSha256
    task_name = $TaskName
    task_path = '\'
    principal_sid = $identity.Sid
    before = $evidence
    expected_disabled_task_xml_sha256 = $ExpectedDisabledXmlSha256
    absent = $true
    matching_worker_process_count = 0
    matching_worker_process_count_basis = 'INFERRED_FROM_EXACT_NEVER_RUN_TASK_HISTORY_AND_SUCCESSFUL_UNREGISTER'
    dev1_owner_process_count = [int]$processes.dev1_owner_process_count
    dev1_root_process_count = [int]$processes.dev1_root_process_count
    relevant_process_identity_sha256 = [string]$processes.relevant_process_identity_sha256
    stable_snapshot_count = [int]$processes.stable_snapshot_count
    process_probe_method = [string]$processes.process_probe_method
} | ConvertTo-Json -Depth 6 -Compress
