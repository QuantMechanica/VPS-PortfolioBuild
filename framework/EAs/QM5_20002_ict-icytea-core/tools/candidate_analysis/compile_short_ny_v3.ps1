[CmdletBinding(DefaultParameterSetName = 'Controller')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Child')]
    [switch]$Child,
    [Parameter(Mandatory = $true, ParameterSetName = 'Child')]
    [string]$RequestPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Child')]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedRequestSha256,
    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedCredentialSha256,
    [Parameter(Mandatory = $true, ParameterSetName = 'Controller')]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [IO.Path]::GetFullPath('C:\QM\repo')
$eaRoot = Join-Path $repoRoot 'framework\EAs\QM5_20002_ict-icytea-core'
$source = Join-Path $eaRoot 'QM5_20002_ict-icytea-core.mq5'
$repoEx5 = [IO.Path]::ChangeExtension($source, '.ex5')
$repoInclude = Join-Path $repoRoot 'framework\include'
$compileOne = Join-Path $repoRoot 'framework\scripts\compile_one.ps1'
$devRoot = [IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$metaEditor = Join-Path $devRoot 'MetaEditor64.exe'
$pwsh = 'C:\Program Files\PowerShell\7\pwsh.exe'
$credentialPath = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.json'
$credentialHelperPath = Join-Path $repoRoot 'framework\scripts\dev1_machine_credential.ps1'
$identityProbeChildPath = Join-Path $repoRoot 'framework\scripts\invoke_dev1_identity_probe.ps1'
$laneContractPath = Join-Path $repoRoot 'framework\registry\dev1_lane_contract.json'
$rotationReceiptPath = 'C:\ProgramData\QM\DEV1\credential.machine-dpapi.rotation-receipt.json'
$cleanupHelperSourcePath = Join-Path $repoRoot 'framework\scripts\cleanup_dev1_account_lease.ps1'
$testerGroupsCanonicalPath = Join-Path $repoRoot 'framework\registry\tester_groups\Darwinex-Live_real.canonical.txt'
$testerGroupsDev1Path = Join-Path $devRoot 'MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt'
$reportsRoot = [IO.Path]::GetFullPath('D:\QM\reports\dev1\build\compile')
$controllerScript = [IO.Path]::GetFullPath($PSCommandPath)
$expectedContractCommit = 'd902b04932c340dd1212b9420077d7cec6b0d80d'
$expectedContractSha256 = '6ee74c60a823fe87b03b40a2737ba67d113b2e52e7c09a05f42ba2084e17fefa'
$expectedSourceCommit = '3f1039f0eeb56ee882b5c3451eed3ee71567d6bc'
$frozenSourceSha256 = '3fd49f2cea7575e659f1b1cf9c24c752a4a8e11db5e0c17cae69629a6f207f83'
$researchStatus = 'CARD_INTAKE_NOT_APPROVED'
$taskPrefix = 'QM_DEV1_COMPILE_'
$smokeTaskPrefix = 'QM_DEV1_SMOKE_'
$cleanupTaskPrefix = 'QM_DEV1_CLEANUP_'
$profileTaskPrefix = 'QM_DEV1_PROFILE_INIT_'
$cleanupActionMutexPrefix = 'Global\QM_DEV1_CLEANUP_ACTION_'
$cleanupActionMutexWaitMilliseconds = 180000
$cleanupLeaseGraceSeconds = 900
$taskPath = '\'
$contractId = 'QM_DEV1_ISOLATED_MT5_LANE_V3'
$rotationRoot = [IO.Path]::GetFullPath('D:\QM\reports\dev1\credential-rotation')

function Test-UnderRoot([string]$Path, [string]$Root) {
    $fullPath = [IO.Path]::GetFullPath($Path)
    $fullRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    return $fullPath.StartsWith($fullRoot + '\', [StringComparison]::OrdinalIgnoreCase)
}

function Assert-PhysicalPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { throw "Required path missing: $Path" }
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in $full.Substring($root.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point forbidden in compile chain: $cursor"
        }
    }
}

function Get-Dev1Processes {
    return @(Get-CimInstance Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop | Where-Object {
        $_.ExecutablePath -and (Test-UnderRoot -Path ([string]$_.ExecutablePath) -Root $devRoot)
    })
}

function Get-EphemeralCompileTasks {
    return @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object {
        $_.TaskPath -eq '\' -and $_.TaskName.StartsWith($taskPrefix, [StringComparison]::Ordinal)
    })
}

function Get-Dev1Tasks {
    return @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
        $_.TaskName.StartsWith($taskPrefix, [StringComparison]::Ordinal) -or
        $_.TaskName.StartsWith($smokeTaskPrefix, [StringComparison]::Ordinal) -or
        $_.TaskName.StartsWith($cleanupTaskPrefix, [StringComparison]::Ordinal) -or
        $_.TaskName.StartsWith($profileTaskPrefix, [StringComparison]::Ordinal)
    })
}

function Get-ProcessOwnerSid([object]$ProcessRecord) {
    try {
        $owner = Invoke-CimMethod -InputObject $ProcessRecord -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.ReturnValue -eq 0 -and -not [string]::IsNullOrWhiteSpace([string]$owner.Sid)) {
            return [string]$owner.Sid
        }
    } catch { }
    return $null
}

function Get-Dev1IdentityProcesses([string]$OwnerSid) {
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        $observedSid = Get-ProcessOwnerSid -ProcessRecord $process
        if ($observedSid -ceq $OwnerSid) {
            $records.Add([pscustomobject]@{
                ProcessId = [int]$process.ProcessId
                ExecutablePath = if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) { $null } else { [IO.Path]::GetFullPath([string]$process.ExecutablePath) }
                CreationDate = $process.CreationDate
                OwnerSid = $observedSid
            })
        }
    }
    return $records.ToArray()
}

function Stop-Dev1ProcessesExact([string]$OwnerSid) {
    foreach ($candidate in @(Get-Dev1IdentityProcesses -OwnerSid $OwnerSid)) {
        $fresh = @(Get-CimInstance Win32_Process -Filter "ProcessId = $($candidate.ProcessId)" `
            -Property ProcessId,ExecutablePath,CreationDate -ErrorAction SilentlyContinue)
        if ($fresh.Count -ne 1) { continue }
        $sameCreation = [string]$fresh[0].CreationDate -ceq [string]$candidate.CreationDate
        $freshOwner = Get-ProcessOwnerSid -ProcessRecord $fresh[0]
        if ($sameCreation -and $freshOwner -ceq $OwnerSid) {
            Stop-Process -Id ([int]$candidate.ProcessId) -Force -ErrorAction Stop
        }
    }
    Start-Sleep -Seconds 2
    $ownerProcesses = @(Get-Dev1IdentityProcesses -OwnerSid $OwnerSid)
    $rootProcesses = @(Get-Dev1Processes)
    if ($ownerProcesses.Count -ne 0 -or $rootProcesses.Count -ne 0) {
        throw "DEV1 exact containment left processes (owner=$($ownerProcesses.Count), root=$($rootProcesses.Count))."
    }
}

function Get-Dev1AccountState {
    $user = Get-LocalUser -Name 'QMDev1' -ErrorAction Stop
    if ($user.Name -cne 'QMDev1' -or $user.Enabled -or -not $user.PasswordRequired) {
        throw 'QMDev1 must be exact, PasswordRequired=True, and disabled at compile-controller entry.'
    }
    $sid = [string]$user.SID.Value
    $adminMembers = @(Get-LocalGroupMember -SID (New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')) -ErrorAction Stop)
    if (@($adminMembers | Where-Object { [string]$_.SID.Value -ceq $sid }).Count -ne 0) {
        throw 'QMDev1 must remain a non-admin identity.'
    }
    return [pscustomobject]@{ Sid = $sid; InitiallyEnabled = $false }
}

function Enable-Dev1Account([object]$State) {
    $sid = New-Object Security.Principal.SecurityIdentifier([string]$State.Sid)
    $before = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($before.Name -cne 'QMDev1' -or $before.Enabled -or -not $before.PasswordRequired) {
        throw 'QMDev1 just-in-time enable precondition drifted.'
    }
    Enable-LocalUser -SID $sid -ErrorAction Stop
    $after = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($after.Name -cne 'QMDev1' -or -not $after.Enabled -or -not $after.PasswordRequired) {
        throw 'QMDev1 just-in-time enable failed.'
    }
}

function Disable-Dev1Account([object]$State) {
    $sid = New-Object Security.Principal.SecurityIdentifier([string]$State.Sid)
    $user = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($user.Name -cne 'QMDev1' -or [string]$user.SID.Value -cne [string]$State.Sid) {
        throw 'Refusing to disable QMDev1 after immutable identity drift.'
    }
    if ($user.Enabled) { Disable-LocalUser -SID $sid -ErrorAction Stop }
    $after = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($after.Name -cne 'QMDev1' -or $after.Enabled -or -not $after.PasswordRequired) {
        throw 'QMDev1 disabled-at-rest reassertion failed.'
    }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-CanonicalObjectSha256([object]$Value) {
    $json = $Value | ConvertTo-Json -Depth 12 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    try { return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant() }
    finally { [Array]::Clear($bytes, 0, $bytes.Length) }
}

function Write-AtomicJson([string]$Path, [object]$Value) {
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding utf8
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Set-RunDirectoryAcl([string]$Path, [string]$TargetSid, [Security.AccessControl.FileSystemRights]$TargetRights) {
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRuleAll($rule) }
    $inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    foreach ($grant in @(
        @('S-1-5-18', [Security.AccessControl.FileSystemRights]::FullControl),
        @('S-1-5-32-544', [Security.AccessControl.FileSystemRights]::FullControl),
        @($TargetSid, $TargetRights)
    )) {
        $identity = New-Object Security.Principal.SecurityIdentifier([string]$grant[0])
        $access = New-Object Security.AccessControl.FileSystemAccessRule(
            $identity, $grant[1], $inheritance, [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($access)
    }
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Remove-ScheduledTaskBounded([string]$TaskName, [switch]$DisableBeforeStop) {
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -eq $task) { return }
    if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $taskPath) {
        throw 'Bounded DEV1 compile-task drain observed identity drift.'
    }
    if ($DisableBeforeStop.IsPresent) {
        Disable-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    }
    if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
    }
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
    do {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($null -eq $task -or $task.State.ToString() -ne 'Running') { break }
        Start-Sleep -Milliseconds 200
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
        throw "DEV1 compile task did not stop within its bounded drain: $TaskName"
    }
    if ($null -ne $task) {
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
    }
    $deadline = [DateTimeOffset]::UtcNow.AddSeconds(30)
    do {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($null -eq $task) { break }
        Start-Sleep -Milliseconds 200
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if ($null -ne $task) { throw "DEV1 compile task remains registered: $TaskName" }
}

function Enter-CleanupActionMutex([string]$Name) {
    if ($Name -cnotmatch '^Global\\QM_DEV1_CLEANUP_ACTION_[0-9a-f]{32}$') {
        throw 'Compile cleanup action mutex name drifted.'
    }
    $handle = New-Object Threading.Mutex($false, $Name)
    try {
        $acquired = $false
        try { $acquired = [bool]$handle.WaitOne($cleanupActionMutexWaitMilliseconds) } catch {
            $cursor = $_.Exception
            while ($null -ne $cursor) {
                if ($cursor -is [Threading.AbandonedMutexException]) { $acquired = $true; break }
                $cursor = $cursor.InnerException
            }
            if (-not $acquired) { throw }
        }
        if (-not $acquired) { throw 'Timed out waiting for DEV1 compile cleanup action fence.' }
        return $handle
    } catch {
        $handle.Dispose()
        throw
    }
}

function Restore-TesterGroupsCanonical {
    foreach ($path in @($testerGroupsCanonicalPath, $testerGroupsDev1Path)) { Assert-PhysicalPath -Path $path }
    [IO.File]::Copy($testerGroupsCanonicalPath, $testerGroupsDev1Path, $true)
    $canonical = Get-Sha256 $testerGroupsCanonicalPath
    $restored = Get-Sha256 $testerGroupsDev1Path
    if ($restored -cne $canonical) { throw 'DEV1 compile tester-groups restore hash mismatch.' }
    return $restored
}

function Assert-Contained([object]$AccountState, [string]$AllowedCleanupTaskName) {
    $sid = New-Object Security.Principal.SecurityIdentifier([string]$AccountState.Sid)
    $user = Get-LocalUser -SID $sid -ErrorAction Stop
    $unexpected = @(Get-Dev1Tasks | Where-Object { [string]$_.TaskName -cne $AllowedCleanupTaskName })
    if ($user.Name -cne 'QMDev1' -or $user.Enabled -or -not $user.PasswordRequired -or
        @(Get-Dev1IdentityProcesses -OwnerSid ([string]$AccountState.Sid)).Count -ne 0 -or
        @(Get-Dev1Processes).Count -ne 0 -or $unexpected.Count -ne 0) {
        throw 'DEV1 compile containment reassertion failed before cleanup-lease disarm.'
    }
}

function Clear-InheritedEnvironment([string]$ExpectedProfile) {
    # Never enumerate values or serialize the inherited environment. Rebuild a
    # small fixed allowlist before resolving profile/include/tool locations.
    $systemRoot = $env:SystemRoot
    $profile = [IO.Path]::GetFullPath($ExpectedProfile)
    $safe = [ordered]@{
        SystemRoot = $systemRoot
        windir = $systemRoot
        SystemDrive = [IO.Path]::GetPathRoot($systemRoot).TrimEnd('\')
        ComSpec = Join-Path $systemRoot 'System32\cmd.exe'
        ProgramData = $env:ProgramData
        ProgramFiles = $env:ProgramFiles
        'ProgramFiles(x86)' = ${env:ProgramFiles(x86)}
        ProgramW6432 = $env:ProgramW6432
        CommonProgramFiles = $env:CommonProgramFiles
        'CommonProgramFiles(x86)' = ${env:CommonProgramFiles(x86)}
        CommonProgramW6432 = $env:CommonProgramW6432
        COMPUTERNAME = $env:COMPUTERNAME
        USERNAME = $env:USERNAME
        USERDOMAIN = $env:USERDOMAIN
        USERPROFILE = $profile
        APPDATA = Join-Path $profile 'AppData\Roaming'
        LOCALAPPDATA = Join-Path $profile 'AppData\Local'
        TEMP = Join-Path $profile 'AppData\Local\Temp'
        TMP = Join-Path $profile 'AppData\Local\Temp'
        HOMEDRIVE = [IO.Path]::GetPathRoot($profile).TrimEnd('\')
        HOMEPATH = $profile.Substring([IO.Path]::GetPathRoot($profile).Length - 1)
        OS = 'Windows_NT'
        PROCESSOR_ARCHITECTURE = $env:PROCESSOR_ARCHITECTURE
        NUMBER_OF_PROCESSORS = $env:NUMBER_OF_PROCESSORS
        PSModulePath = "$PSHOME\Modules;$env:ProgramFiles\PowerShell\Modules;$systemRoot\system32\WindowsPowerShell\v1.0\Modules"
        Path = "$systemRoot\System32;$systemRoot;$systemRoot\System32\Wbem;$systemRoot\System32\WindowsPowerShell\v1.0;$([IO.Path]::GetDirectoryName($pwsh))"
        PATHEXT = '.COM;.EXE;.BAT;.CMD'
    }
    foreach ($name in @([Environment]::GetEnvironmentVariables('Process').Keys)) {
        Remove-Item -LiteralPath ("Env:\{0}" -f [string]$name) -ErrorAction SilentlyContinue
    }
    foreach ($entry in $safe.GetEnumerator()) {
        if ($null -ne $entry.Value) { [Environment]::SetEnvironmentVariable([string]$entry.Key, [string]$entry.Value, 'Process') }
    }
}

function Read-ExactJson([string]$Path, [string[]]$ExpectedFields, [string]$Label) {
    Assert-PhysicalPath -Path $Path
    $raw = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path), [Text.UTF8Encoding]::new($false, $true))
    $document = [Text.Json.JsonDocument]::Parse($raw)
    try {
        if ($document.RootElement.ValueKind -ne [Text.Json.JsonValueKind]::Object) {
            throw "$Label is not a JSON object."
        }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { throw "$Label contains a duplicate JSON property." }
        }
        if ([string]::Join('|', @($seen | Sort-Object)) -cne [string]::Join('|', @($ExpectedFields | Sort-Object))) {
            throw "$Label field closure drifted."
        }
    } finally { $document.Dispose() }
    return $raw | ConvertFrom-Json -DateKind String -ErrorAction Stop
}

function Assert-V3RotationReceipt([object]$AccountState, [string]$CredentialSha256, [string]$HelperSha256) {
    $laneFields = @('schema_version', 'contract_id', 'lane', 'source_lane', 'identity', 'paths', 'coordination', 'firewall', 'program_sha256', 'allowed_symbols', 'copy_contract', 'agent_port_contract')
    $lane = Read-ExactJson -Path $laneContractPath -ExpectedFields $laneFields -Label 'DEV1 lane contract'
    $account = "$env:COMPUTERNAME\QMDev1"
    if ([int]$lane.schema_version -ne 3 -or [string]$lane.contract_id -cne $contractId -or
        [string]$lane.lane -cne 'DEV1' -or [string]$lane.source_lane -cne 'DEV1' -or
        [string]$lane.identity.local_user -cne 'QMDev1' -or
        -not ([IO.Path]::GetFullPath([string]$lane.identity.credential)).Equals([IO.Path]::GetFullPath($credentialPath), [StringComparison]::OrdinalIgnoreCase) -or
        [string]$lane.identity.credential_format -cne 'QM_DEV1_MACHINE_DPAPI_CREDENTIAL' -or
        [string]$lane.identity.dpapi_scope -cne 'LocalMachine' -or -not [bool]$lane.identity.limited_non_admin) {
        throw 'DEV1 V3 lane identity contract drifted.'
    }
    $receiptFields = @(
        'schema_version', 'artifact_type', 'status', 'completed_utc', 'contract_id', 'target_account', 'target_sid',
        'target_disabled_at_rest', 'target_password_required_at_rest', 'machine_credential_path', 'machine_credential_sha256',
        'machine_credential_generation_id', 'machine_credential_helper_path', 'machine_credential_helper_sha256',
        'identity_probe_child_path', 'identity_probe_child_sha256', 'identity_probe_result_path', 'identity_probe_result_sha256',
        'identity_probe_logon_type', 'identity_probe_run_level', 'machine_credential_matches_proved_password',
        'published_after_identity_proof', 'legacy_credential_path', 'legacy_credential_preserved', 'cleanup_lease_disarmed',
        'owner_process_count', 'dev1_root_process_count'
    )
    Assert-QmDev1CredentialExactAcl -Path $rotationReceiptPath
    $receipt = Read-ExactJson -Path $rotationReceiptPath -ExpectedFields $receiptFields -Label 'DEV1 rotation receipt'
    if ([int]$receipt.schema_version -ne 1 -or [string]$receipt.artifact_type -cne 'QM_DEV1_MACHINE_CREDENTIAL_ROTATION_RECEIPT' -or
        [string]$receipt.status -cne 'PASS' -or [string]$receipt.contract_id -cne $contractId -or
        [string]$receipt.target_account -cne $account -or [string]$receipt.target_sid -cne [string]$AccountState.Sid -or
        -not [bool]$receipt.target_disabled_at_rest -or -not [bool]$receipt.target_password_required_at_rest -or
        [string]$receipt.identity_probe_logon_type -cne 'Password' -or [string]$receipt.identity_probe_run_level -cne 'Limited' -or
        -not [bool]$receipt.machine_credential_matches_proved_password -or -not [bool]$receipt.published_after_identity_proof -or
        -not [bool]$receipt.legacy_credential_preserved -or -not [bool]$receipt.cleanup_lease_disarmed -or
        [int]$receipt.owner_process_count -ne 0 -or [int]$receipt.dev1_root_process_count -ne 0 -or
        [string]$receipt.machine_credential_sha256 -cne $CredentialSha256 -or
        [string]$receipt.machine_credential_helper_sha256 -cne $HelperSha256 -or
        [string]$receipt.machine_credential_generation_id -cnotmatch '^[0-9a-f]{32}$') {
        throw 'DEV1 canonical rotation receipt proof drifted.'
    }
    $pathChecks = @(
        @([string]$receipt.machine_credential_path, $credentialPath),
        @([string]$receipt.machine_credential_helper_path, $credentialHelperPath),
        @([string]$receipt.identity_probe_child_path, $identityProbeChildPath)
    )
    foreach ($pair in $pathChecks) {
        if (-not ([IO.Path]::GetFullPath($pair[0])).Equals([IO.Path]::GetFullPath($pair[1]), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'DEV1 canonical rotation receipt path drifted.'
        }
    }
    foreach ($binding in @(
        @($identityProbeChildPath, [string]$receipt.identity_probe_child_sha256),
        @([string]$receipt.identity_probe_result_path, [string]$receipt.identity_probe_result_sha256)
    )) {
        if ([string]$binding[1] -cnotmatch '^[0-9a-f]{64}$' -or (Get-Sha256 $binding[0]) -cne [string]$binding[1]) {
            throw 'DEV1 canonical rotation receipt dependency hash drifted.'
        }
    }
    $resultPath = [IO.Path]::GetFullPath([string]$receipt.identity_probe_result_path)
    if (-not (Test-UnderRoot -Path $resultPath -Root $rotationRoot) -or
        [IO.Path]::GetFileName($resultPath) -cne 'identity_probe_result.json') {
        throw 'DEV1 rotation identity result escaped its canonical root/layout.'
    }
    $identityResult = Read-ExactJson -Path $resultPath -ExpectedFields @(
        'schema_version', 'artifact_type', 'status', 'completed_utc', 'nonce', 'account', 'sid', 'profile', 'limited_non_admin', 'request_sha256'
    ) -Label 'DEV1 identity result'
    if ([int]$identityResult.schema_version -ne 1 -or [string]$identityResult.artifact_type -cne 'QM_DEV1_IDENTITY_PROBE_RESULT' -or
        [string]$identityResult.status -cne 'PASS' -or [string]$identityResult.account -cne $account -or
        [string]$identityResult.sid -cne [string]$AccountState.Sid -or -not [bool]$identityResult.limited_non_admin -or
        [string]$identityResult.request_sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'DEV1 rotation identity result proof drifted.'
    }
    $envelope = Read-QmDev1MachineCredentialEnvelope -CredentialPath $credentialPath `
        -ExpectedCredentialSha256 $CredentialSha256 -ExpectedAccount $account -ExpectedSid ([string]$AccountState.Sid) `
        -ContractId $contractId -Lane 'DEV1'
    if ([string]$envelope.GenerationId -cne [string]$receipt.machine_credential_generation_id) {
        throw 'DEV1 machine credential generation differs from rotation proof.'
    }
    return [pscustomobject]@{
        Lane = $lane
        LaneSha256 = Get-Sha256 $laneContractPath
        Receipt = $receipt
        ReceiptSha256 = Get-Sha256 $rotationReceiptPath
        IdentityChildSha256 = Get-Sha256 $identityProbeChildPath
        IdentityResultSha256 = Get-Sha256 $resultPath
        Account = $account
        Sid = [string]$AccountState.Sid
    }
}

function Assert-CleanupTaskContract([string]$TaskName, [string]$Arguments, [string]$WorkingDirectory) {
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
    $principal = $task.Principal
    $triggers = @($task.Triggers)
    $actions = @($task.Actions)
    if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $taskPath -or
        [string]$principal.UserId -notin @('SYSTEM', 'NT AUTHORITY\SYSTEM', 'S-1-5-18') -or
        $principal.LogonType.ToString() -cne 'ServiceAccount' -or $principal.RunLevel.ToString() -cne 'Highest' -or
        $triggers.Count -ne 2 -or @($triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger' }).Count -ne 1 -or
        $actions.Count -ne 1 -or -not ([IO.Path]::GetFullPath([string]$actions[0].Execute)).Equals([IO.Path]::GetFullPath($pwsh), [StringComparison]::OrdinalIgnoreCase) -or
        [string]$actions[0].Arguments -cne $Arguments -or
        -not ([IO.Path]::GetFullPath([string]$actions[0].WorkingDirectory)).Equals([IO.Path]::GetFullPath($WorkingDirectory), [StringComparison]::OrdinalIgnoreCase) -or
        $task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew' -or -not $task.Settings.StartWhenAvailable -or
        [string]$task.Settings.ExecutionTimeLimit -cne 'PT10M' -or [int]$task.Settings.RestartCount -ne 3 -or
        [string]$task.Settings.RestartInterval -cne 'PT1M') {
        throw 'SYSTEM cleanup lease Scheduled Task contract drifted.'
    }
}

function Assert-CleanupEvidence(
    [string]$ResultPath, [string]$DisarmPath, [string]$ExpectedSid,
    [string]$TargetTaskName, [string]$CleanupTaskName
) {
    $result = Read-ExactJson -Path $ResultPath -ExpectedFields @(
        'schema_version', 'artifact_type', 'completed_utc', 'success', 'containment_verified', 'lease_disarmed',
        'expected_sid', 'target_task_name', 'cleanup_task_name', 'manifest_valid', 'account_restored_disabled',
        'owner_process_count', 'dev1_root_process_count', 'target_task_registered', 'cleanup_task_registered', 'failures'
    ) -Label 'DEV1 compile cleanup containment result'
    $disarm = Read-ExactJson -Path $DisarmPath -ExpectedFields @(
        'schema_version', 'artifact_type', 'completed_utc', 'success', 'containment_result_path', 'containment_verified',
        'lease_disarmed', 'expected_sid', 'target_task_name', 'cleanup_task_name', 'account_restored_disabled',
        'owner_process_count', 'dev1_root_process_count', 'target_task_registered', 'cleanup_task_registered', 'failures'
    ) -Label 'DEV1 compile cleanup disarm result'
    if ([int]$result.schema_version -ne 1 -or [string]$result.artifact_type -cne 'QM_DEV1_ACCOUNT_CLEANUP_RESULT' -or
        -not [bool]$result.success -or -not [bool]$result.containment_verified -or [bool]$result.lease_disarmed -or
        -not [bool]$result.manifest_valid -or -not [bool]$result.account_restored_disabled -or
        [int]$result.owner_process_count -ne 0 -or [int]$result.dev1_root_process_count -ne 0 -or
        [bool]$result.target_task_registered -or -not [bool]$result.cleanup_task_registered -or @($result.failures).Count -ne 0 -or
        [string]$result.expected_sid -cne $ExpectedSid -or [string]$result.target_task_name -cne $TargetTaskName -or
        [string]$result.cleanup_task_name -cne $CleanupTaskName) {
        throw 'DEV1 compile cleanup containment evidence failed or drifted.'
    }
    if ([int]$disarm.schema_version -ne 1 -or [string]$disarm.artifact_type -cne 'QM_DEV1_ACCOUNT_CLEANUP_DISARM_RESULT' -or
        -not [bool]$disarm.success -or -not [bool]$disarm.containment_verified -or -not [bool]$disarm.lease_disarmed -or
        -not [bool]$disarm.account_restored_disabled -or [int]$disarm.owner_process_count -ne 0 -or
        [int]$disarm.dev1_root_process_count -ne 0 -or [bool]$disarm.target_task_registered -or
        [bool]$disarm.cleanup_task_registered -or @($disarm.failures).Count -ne 0 -or
        [string]$disarm.expected_sid -cne $ExpectedSid -or [string]$disarm.target_task_name -cne $TargetTaskName -or
        [string]$disarm.cleanup_task_name -cne $CleanupTaskName -or
        -not ([IO.Path]::GetFullPath([string]$disarm.containment_result_path)).Equals([IO.Path]::GetFullPath($ResultPath), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'DEV1 compile cleanup disarm evidence failed or drifted.'
    }
    return [pscustomobject]@{ ResultSha256 = Get-Sha256 $ResultPath; DisarmSha256 = Get-Sha256 $DisarmPath }
}

function Invoke-CleanupLeaseFence(
    [string]$CleanupTaskName, [string]$CleanupActionMutexName, [string]$ResultPath,
    [string]$DisarmPath, [object]$AccountState, [string]$TargetTaskName
) {
    $existing = Get-ScheduledTask -TaskName $CleanupTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Start-ScheduledTask -TaskName $CleanupTaskName -TaskPath $taskPath -ErrorAction Stop
    }
    $deadline = [DateTimeOffset]::UtcNow.AddMinutes(2)
    do {
        if (Test-Path -LiteralPath $DisarmPath -PathType Leaf) { break }
        if (Test-Path -LiteralPath $ResultPath -PathType Leaf) {
            $interim = Get-Content -LiteralPath $ResultPath -Raw -ErrorAction Stop | ConvertFrom-Json -DateKind String -ErrorAction Stop
            if ($interim.success -is [bool] -and -not [bool]$interim.success) {
                throw 'SYSTEM compile cleanup lease reported failed containment.'
            }
        }
        Start-Sleep -Milliseconds 500
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    if (-not (Test-Path -LiteralPath $DisarmPath -PathType Leaf)) {
        throw 'SYSTEM compile cleanup lease did not durably disarm within two minutes.'
    }
    $fence = Enter-CleanupActionMutex -Name $CleanupActionMutexName
    try {
        $evidence = Assert-CleanupEvidence -ResultPath $ResultPath -DisarmPath $DisarmPath `
            -ExpectedSid ([string]$AccountState.Sid) -TargetTaskName $TargetTaskName -CleanupTaskName $CleanupTaskName
        Assert-Contained -AccountState $AccountState -AllowedCleanupTaskName '__NO_TASK_ALLOWED__'
        return $evidence
    } finally {
        try { $fence.ReleaseMutex() } finally { $fence.Dispose() }
    }
}

function Resolve-Dev1ProfileInclude {
    $terminalProfiles = Join-Path $env:APPDATA 'MetaQuotes\Terminal'
    $matches = @(Get-ChildItem -LiteralPath $terminalProfiles -Directory -ErrorAction Stop | Where-Object {
        $origin = Join-Path $_.FullName 'origin.txt'
        (Test-Path -LiteralPath $origin -PathType Leaf) -and
        ((Get-Content -LiteralPath $origin -Raw).Trim()).Equals($devRoot, [StringComparison]::OrdinalIgnoreCase)
    })
    if ($matches.Count -ne 1) { throw "Expected exactly one QMDev1 DEV1 profile, found $($matches.Count)." }
    return Join-Path $matches[0].FullName 'MQL5\Include'
}

function Get-RepoIncludeSnapshot {
    $snapshot = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $repoInclude -File -Recurse | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($repoInclude.Length).TrimStart('\')
        $snapshot[$relative] = [ordered]@{
            bytes = [long]$file.Length
            sha256 = Get-Sha256 -Path $file.FullName
        }
    }
    if ($snapshot.Count -le 0) { throw 'Repository include snapshot is empty.' }
    return $snapshot
}

function Export-IncludeManifest([string[]]$Targets, [System.Collections.IDictionary]$Snapshot, [string]$Path) {
    $current = Get-RepoIncludeSnapshot
    if ($current.Count -ne $Snapshot.Count) { throw 'Repository include file count changed during compile.' }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($relative in $Snapshot.Keys) {
        if (-not $current.Contains($relative) -or
            $current[$relative].bytes -ne $Snapshot[$relative].bytes -or
            $current[$relative].sha256 -cne $Snapshot[$relative].sha256) {
            throw "Repository include changed during compile: $relative"
        }
        foreach ($target in $Targets) {
            $destination = Join-Path $target $relative
            if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
                throw "Synced include missing: $destination"
            }
            $destinationItem = Get-Item -LiteralPath $destination
            $destinationHash = Get-Sha256 -Path $destination
            if ($destinationItem.Length -ne $Snapshot[$relative].bytes -or
                $destinationHash -cne $Snapshot[$relative].sha256) {
                throw "Synced include mismatch: $destination"
            }
            $rows.Add([pscustomobject]@{
                target_include_root = [IO.Path]::GetFullPath($target)
                relative_path = $relative
                bytes = $Snapshot[$relative].bytes
                source_sha256 = $Snapshot[$relative].sha256
                destination_sha256 = $destinationHash
            })
        }
    }
    $rows.ToArray() | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
    return $rows.Count
}

function Export-IncludePathAudit([string]$CompileLog, [string[]]$AllowedRoots, [string]$StageRoot, [string]$Path) {
    $text = Get-Content -LiteralPath $CompileLog -Raw
    $matches = [regex]::Matches($text, '(?im):\s*information:\s*including\s+(?<path>[^\r\n]+)')
    $seen = [ordered]@{}
    foreach ($match in $matches) {
        $included = [IO.Path]::GetFullPath($match.Groups['path'].Value.Trim())
        if (-not $seen.Contains($included)) {
            $allowed = Test-UnderRoot -Path $included -Root $StageRoot
            if (-not $allowed) {
                foreach ($root in $AllowedRoots) {
                    if (Test-UnderRoot -Path $included -Root $root) { $allowed = $true; break }
                }
            }
            $seen[$included] = $allowed
        }
    }
    if ($seen.Count -le 0) { throw 'Compile log did not disclose any included path.' }
    $rows = foreach ($included in $seen.Keys) {
        [pscustomobject]@{ included_path = $included; allowed = [bool]$seen[$included] }
    }
    $rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding utf8
    $outside = @($rows | Where-Object { -not $_.allowed }).Count
    if ($outside -ne 0) { throw "Compile used $outside include path(s) outside the isolated roots." }
    return [ordered]@{ count = @($rows).Count; outside = $outside }
}

function Invoke-CompileChild {
    $RequestPath = [IO.Path]::GetFullPath($RequestPath)
    if (-not (Test-UnderRoot -Path $RequestPath -Root $reportsRoot) -or
        (Get-Sha256 $RequestPath) -cne $ExpectedRequestSha256) {
        throw 'Compile child request path/hash binding drifted.'
    }
    $requestFields = @(
        'schema_version', 'artifact_type', 'run_id', 'nonce', 'created_utc', 'expires_utc', 'run_root',
        'expected_account', 'expected_sid', 'expected_profile', 'expected_common_path', 'expected_task_name', 'result_path',
        'controller_path', 'controller_sha256', 'compile_one_path', 'compile_one_sha256',
        'metaeditor_path', 'metaeditor_sha256', 'source_path', 'source_sha256',
        'repo_include_path', 'repo_include_snapshot_sha256', 'pwsh_path', 'pwsh_sha256',
        'lane_contract_sha256', 'machine_credential_sha256', 'machine_credential_helper_sha256',
        'rotation_receipt_sha256', 'cleanup_helper_sha256'
    )
    $request = Read-ExactJson -Path $RequestPath -ExpectedFields $requestFields -Label 'DEV1 compile request'
    if ([int]$request.schema_version -ne 1 -or [string]$request.artifact_type -cne 'QM5_20002_DEV1_V3_COMPILE_REQUEST' -or
        [string]$request.run_id -cnotmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$' -or
        [string]$request.nonce -cnotmatch '^[0-9a-f]{32}$' -or
        [string]$request.expected_task_name -cnotmatch '^QM_DEV1_COMPILE_[0-9a-f]{32}$') {
        throw 'Compile child request identity drifted.'
    }
    $expires = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$request.expires_utc, 'o', [cultureinfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind, [ref]$expires) -or $expires.Offset -ne [TimeSpan]::Zero -or
        $expires -le [DateTimeOffset]::UtcNow) { throw 'Compile child request is expired or malformed.' }
    Clear-InheritedEnvironment -ExpectedProfile ([string]$request.expected_profile)
    $childRunRoot = [IO.Path]::GetFullPath([string]$request.run_root)
    if (-not (Test-UnderRoot -Path $childRunRoot -Root $reportsRoot)) { throw 'Child RunRoot escaped reports root.' }
    $controlRoot = Join-Path $childRunRoot 'control'
    $outputRoot = Join-Path $childRunRoot 'output'
    $stageRoot = Join-Path $outputRoot 'stage'
    $stageMq5 = Join-Path $stageRoot 'QM5_20002_ict-icytea-core.mq5'
    $stageEx5 = [IO.Path]::ChangeExtension($stageMq5, '.ex5')
    $resultPath = Join-Path $outputRoot 'child_result.json'
    $childLog = Join-Path $outputRoot 'compile_child.log'
    $includeManifest = Join-Path $outputRoot 'include_sync_manifest.csv'
    $includeAudit = Join-Path $outputRoot 'include_path_audit.csv'
    $started = (Get-Date).ToUniversalTime()
    $success = $false
    $failure = $null
    $errors = -1
    $warnings = -1
    $metaExit = -1
    $compileLog = $null
    $includeTargets = @()
    $includeRows = 0
    $includedPaths = 0
    $outsidePaths = -1
    try {
        foreach ($path in @($childRunRoot, $controlRoot, $outputRoot, $stageRoot, $stageMq5, $repoInclude, $compileOne, $metaEditor, $pwsh, $controllerScript)) {
            Assert-PhysicalPath -Path $path
        }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        if ($identity.User.Value -cne [string]$request.expected_sid) { throw "Wrong child SID: $($identity.User.Value)" }
        $expectedAccount = [string]$request.expected_account
        if (-not $identity.Name.Equals($expectedAccount, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Wrong child account: $($identity.Name)"
        }
        if (-not ([IO.Path]::GetFullPath($env:USERPROFILE)).Equals(
                [IO.Path]::GetFullPath([string]$request.expected_profile), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Wrong QMDev1 profile.'
        }
        $actualCommon = [IO.Path]::GetFullPath((Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common'))
        if (-not $actualCommon.Equals([IO.Path]::GetFullPath([string]$request.expected_common_path), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Wrong QMDev1 Common path after environment reconstruction.'
        }
        if ((Get-Sha256 -Path $stageMq5) -cne [string]$request.source_sha256) {
            throw 'Staged source SHA-256 drift.'
        }
        foreach ($binding in @(
            @($controllerScript, [string]$request.controller_path, [string]$request.controller_sha256),
            @($compileOne, [string]$request.compile_one_path, [string]$request.compile_one_sha256),
            @($metaEditor, [string]$request.metaeditor_path, [string]$request.metaeditor_sha256),
            @($pwsh, [string]$request.pwsh_path, [string]$request.pwsh_sha256),
            @($stageMq5, [string]$request.source_path, [string]$request.source_sha256)
        )) {
            if (-not ([IO.Path]::GetFullPath([string]$binding[0])).Equals([IO.Path]::GetFullPath([string]$binding[1]), [StringComparison]::OrdinalIgnoreCase) -or
                (Get-Sha256 ([string]$binding[0])) -cne [string]$binding[2]) { throw 'Compile child fixed-byte binding drifted.' }
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 was not idle in child preflight.' }

        $profileInclude = Resolve-Dev1ProfileInclude
        $portableInclude = Join-Path $devRoot 'MQL5\Include'
        foreach ($target in @($profileInclude, $portableInclude)) { Assert-PhysicalPath -Path $target }
        $expectedTargets = @([IO.Path]::GetFullPath($profileInclude), [IO.Path]::GetFullPath($portableInclude)) | Sort-Object -Unique
        $includeSnapshot = Get-RepoIncludeSnapshot
        if (Get-CanonicalObjectSha256 $includeSnapshot -cne [string]$request.repo_include_snapshot_sha256) {
            throw 'Compile child repository include snapshot drifted before compile.'
        }

        $buildRoot = Join-Path $outputRoot 'compile_one_build'
        $reportRoot = Join-Path $outputRoot 'compile_one_report'
        $output = @(& $pwsh -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $compileOne `
            -EAPath $stageMq5 -Strict -MetaEditorPath $metaEditor -BuildRoot $buildRoot -ReportRoot $reportRoot 2>&1)
        $compileExit = $LASTEXITCODE
        $output | ForEach-Object { [string]$_ } | Set-Content -LiteralPath $childLog -Encoding utf8
        $values = @{}
        foreach ($line in $output) {
            $textLine = [string]$line
            if ($textLine -match '^compile_one\.(?<key>[^=]+)=(?<value>.*)$') { $values[$Matches.key] = $Matches.value }
        }
        foreach ($requiredKey in @('result', 'reason_class', 'errors', 'warnings', 'metaeditor_exit_code',
                'include_sync_targets', 'log')) {
            if (-not $values.ContainsKey($requiredKey)) { throw "compile_one omitted output key: $requiredKey" }
        }
        if ($compileExit -ne 0 -or $values['result'] -ne 'PASS') {
            throw "compile_one failed: exit=$compileExit result=$($values['result']) reason=$($values['reason_class'])"
        }
        $errors = [int]$values['errors']
        $warnings = [int]$values['warnings']
        $metaExit = [int]$values['metaeditor_exit_code']
        if ($errors -ne 0 -or $warnings -ne 0) { throw "Strict compile failed: errors=$errors warnings=$warnings" }
        $compileLog = [IO.Path]::GetFullPath([string]$values['log'])
        if (-not (Test-Path -LiteralPath $compileLog -PathType Leaf)) { throw 'compile_one log missing.' }
        if (-not (Test-Path -LiteralPath $stageEx5 -PathType Leaf) -or (Get-Item $stageEx5).Length -le 0) {
            throw 'compile_one produced no non-empty staged EX5.'
        }
        if ((Get-Item $stageEx5).LastWriteTimeUtc -lt $started.AddSeconds(-2)) { throw 'Staged EX5 predates compile.' }

        $reportedTargets = @(([string]$values['include_sync_targets']).Split(';', [StringSplitOptions]::RemoveEmptyEntries) |
            ForEach-Object { [IO.Path]::GetFullPath($_) } | Sort-Object -Unique)
        if (($reportedTargets -join '|') -cne ($expectedTargets -join '|')) {
            throw "compile_one include targets escaped DEV1: $($reportedTargets -join ';')"
        }
        $includeTargets = $reportedTargets
        $includeRows = Export-IncludeManifest -Targets $includeTargets -Snapshot $includeSnapshot -Path $includeManifest
        $audit = Export-IncludePathAudit -CompileLog $compileLog -AllowedRoots $includeTargets -StageRoot $stageRoot -Path $includeAudit
        $includedPaths = [int]$audit.count
        $outsidePaths = [int]$audit.outside
        if ((Get-Sha256 $RequestPath) -cne $ExpectedRequestSha256 -or
            (Get-Sha256 $controllerScript) -cne [string]$request.controller_sha256 -or
            (Get-Sha256 $compileOne) -cne [string]$request.compile_one_sha256 -or
            (Get-Sha256 $metaEditor) -cne [string]$request.metaeditor_sha256 -or
            (Get-Sha256 $stageMq5) -cne [string]$request.source_sha256 -or
            (Get-CanonicalObjectSha256 (Get-RepoIncludeSnapshot)) -cne [string]$request.repo_include_snapshot_sha256) {
            throw 'Compile child fixed bytes changed during compile.'
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 process remained after compile.' }
        $success = $true
    } catch {
        $failure = $_.Exception.Message
        try { Add-Content -LiteralPath $childLog -Value "failure=$failure" -Encoding utf8 } catch { }
    } finally {
        foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
            $_.ExecutablePath -and ([IO.Path]::GetFullPath([string]$_.ExecutablePath)).Equals(
                ([IO.Path]::GetFullPath($metaEditor)), [StringComparison]::OrdinalIgnoreCase)
        })) {
            try { Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop } catch { }
        }
        $result = [ordered]@{
            schema_version = 2
            artifact_type = 'QM5_20002_DEV1_V3_COMPILE_CHILD_RESULT'
            success = $success
            failure = $failure
            run_root = $childRunRoot
            run_id = if ($null -ne $request) { [string]$request.run_id } else { $null }
            nonce = if ($null -ne $request) { [string]$request.nonce } else { $null }
            request_sha256 = $ExpectedRequestSha256
            identity_sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            common_path = if ($null -ne $request) { [string]$request.expected_common_path } else { $null }
            metaeditor_path = $metaEditor
            metaeditor_sha256 = if (Test-Path $metaEditor) { Get-Sha256 $metaEditor } else { $null }
            metaeditor_exit_code = $metaExit
            errors = $errors
            warnings = $warnings
            source_mq5_sha256 = if (Test-Path $stageMq5) { Get-Sha256 $stageMq5 } else { $null }
            ex5_path = $stageEx5
            ex5_size_bytes = if (Test-Path $stageEx5) { (Get-Item $stageEx5).Length } else { 0 }
            ex5_sha256 = if (Test-Path $stageEx5) { Get-Sha256 $stageEx5 } else { $null }
            compile_log_path = $compileLog
            include_manifest_path = $includeManifest
            include_manifest_rows = $includeRows
            include_path_audit_path = $includeAudit
            included_paths_count = $includedPaths
            outside_include_paths_count = $outsidePaths
            include_sync_targets = $includeTargets
            lane_contract_sha256 = if ($null -ne $request) { [string]$request.lane_contract_sha256 } else { $null }
            machine_credential_sha256 = if ($null -ne $request) { [string]$request.machine_credential_sha256 } else { $null }
            machine_credential_helper_sha256 = if ($null -ne $request) { [string]$request.machine_credential_helper_sha256 } else { $null }
            rotation_receipt_sha256 = if ($null -ne $request) { [string]$request.rotation_receipt_sha256 } else { $null }
            cleanup_helper_sha256 = if ($null -ne $request) { [string]$request.cleanup_helper_sha256 } else { $null }
            started_utc = $started.ToString('o')
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
        }
        Write-AtomicJson -Path $resultPath -Value $result
    }
    if (-not $success) { exit 1 }
    exit 0
}

function Invoke-CompileController {
    $sourceHash = Get-Sha256 -Path $source
    if ($sourceHash -cne $frozenSourceSha256) { throw "Frozen source drift: $sourceHash" }
    $contractPath = Join-Path $eaRoot 'docs\candidate-analysis\short_ny_reverse_time_contract.json'
    if ((Get-Sha256 $contractPath) -cne $expectedContractSha256) { throw 'Contract-v3 SHA-256 drift.' }
    & git -C $repoRoot cat-file -e "$expectedSourceCommit`:framework/EAs/QM5_20002_ict-icytea-core/QM5_20002_ict-icytea-core.mq5" 2>$null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot resolve frozen source blob.' }
    $head = (& git -C $repoRoot rev-parse HEAD).Trim()
    & git -C $repoRoot merge-base --is-ancestor $expectedContractCommit $head
    if ($LASTEXITCODE -ne 0) { throw 'Contract commit is not an ancestor of HEAD.' }
    & git -C $repoRoot merge-base --is-ancestor $expectedSourceCommit $head
    if ($LASTEXITCODE -ne 0) { throw 'Source commit is not an ancestor of HEAD.' }

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Compile controller must be elevated.'
    }
    foreach ($path in @($source, $contractPath, $repoInclude, $compileOne, $metaEditor, $pwsh, $credentialPath,
            $credentialHelperPath, $laneContractPath, $rotationReceiptPath, $cleanupHelperSourcePath,
            $identityProbeChildPath, $testerGroupsCanonicalPath, $testerGroupsDev1Path, $reportsRoot)) {
        Assert-PhysicalPath -Path $path
    }
    Assert-PhysicalPath -Path $controllerScript
    $controllerScriptHash = Get-Sha256 $controllerScript
    $compileOneHash = Get-Sha256 $compileOne
    $metaEditorHash = Get-Sha256 $metaEditor

    if ((Get-Service MpsSvc).Status -ne 'Running') { throw 'Firewall service is not running.' }
    if (@(Get-NetFirewallProfile -PolicyStore ActiveStore | Where-Object { -not $_.Enabled }).Count -ne 0) {
        throw 'A firewall profile is disabled.'
    }
    $firewall = [ordered]@{
        'QM_DEV1_BLOCK_TERMINAL_OUT' = Join-Path $devRoot 'terminal64.exe'
        'QM_DEV1_BLOCK_METATESTER_OUT' = Join-Path $devRoot 'metatester64.exe'
        'QM_DEV1_BLOCK_METAEDITOR_OUT' = $metaEditor
    }
    foreach ($entry in $firewall.GetEnumerator()) {
        $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $entry.Key)
        if ($rules.Count -ne 1) { throw "Firewall rule count drift: $($entry.Key)" }
        $rule = $rules[0]
        $filter = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule)
        if ($rule.Enabled.ToString() -ne 'True' -or $rule.Direction.ToString() -ne 'Outbound' -or
            $rule.Action.ToString() -ne 'Block' -or $rule.Profile.ToString() -ne 'Any' -or
            $filter.Count -ne 1 -or -not ([IO.Path]::GetFullPath($filter[0].Program)).Equals(
                ([IO.Path]::GetFullPath($entry.Value)), [StringComparison]::OrdinalIgnoreCase)) {
            throw "Firewall rule drift: $($entry.Key)"
        }
    }

    $mutex = [Threading.Mutex]::new($false, 'Global\QM_DEV1_SMOKE_CONTROLLER')
    $mutexAcquired = $false
    $taskRegistered = $false
    $taskName = $taskPrefix + [guid]::NewGuid().ToString('N')
    $cleanupTaskRegistered = $false
    $cleanupTaskName = $cleanupTaskPrefix + [guid]::NewGuid().ToString('N')
    $cleanupLeaseDisarmed = $false
    $cleanupEvidence = $null
    $accountState = $null
    $accountEnabledByController = $false
    $accountRestoredDisabled = $false
    $cleanupErrors = New-Object System.Collections.Generic.List[string]
    $primaryError = $null
    $delivered = $false
    $compileSucceeded = $false
    $plain = $null
    $credential = $null
    $rotationProof = $null
    $runId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ_') + [guid]::NewGuid().ToString('N')
    $nonce = [guid]::NewGuid().ToString('N')
    $controllerRunRoot = Join-Path $reportsRoot $runId
    $controlRoot = Join-Path $controllerRunRoot 'control'
    $outputRoot = Join-Path $controllerRunRoot 'output'
    $stageRoot = Join-Path $outputRoot 'stage'
    $stageMq5 = Join-Path $stageRoot 'QM5_20002_ict-icytea-core.mq5'
    $stageEx5 = [IO.Path]::ChangeExtension($stageMq5, '.ex5')
    $sourceManifest = Join-Path $controlRoot 'source_manifest.csv'
    $requestPath = Join-Path $controlRoot 'compile_request.json'
    $resultPath = Join-Path $outputRoot 'child_result.json'
    $evidencePath = Join-Path $outputRoot 'evidence.json'
    $cleanupHelperPath = Join-Path $controlRoot 'cleanup_dev1_account_lease.ps1'
    $cleanupGroupsSourcePath = Join-Path $controlRoot 'Darwinex-Live_real.canonical.txt'
    $cleanupLeasePath = Join-Path $controlRoot 'cleanup_lease.json'
    $cleanupResultPath = Join-Path $controlRoot 'cleanup_lease.result.json'
    $cleanupDisarmPath = Join-Path $controlRoot 'cleanup_lease.disarm.result.json'
    $cleanupActionMutexName = $cleanupActionMutexPrefix + $nonce
    try {
        $mutexDeadline = (Get-Date).ToUniversalTime().AddMinutes(30)
        $nextWaitNotice = [datetime]::MinValue
        while (-not $mutexAcquired -and (Get-Date).ToUniversalTime() -lt $mutexDeadline) {
            try { $mutexAcquired = $mutex.WaitOne(2000) } catch [Threading.AbandonedMutexException] { $mutexAcquired = $true }
            $now = (Get-Date).ToUniversalTime()
            if (-not $mutexAcquired -and $now -ge $nextWaitNotice) {
                Write-Output "compile_controller.waiting_for_dev1_mutex=$($now.ToString('o'))"
                $nextWaitNotice = $now.AddSeconds(30)
            }
        }
        if (-not $mutexAcquired) { throw 'Timed out waiting for the DEV1 smoke/compile mutex.' }

        if (@(Get-Dev1Tasks).Count -ne 0) {
            throw 'DEV1 compile preflight found stale smoke/compile/cleanup/profile-init tasks.'
        }
        $accountState = Get-Dev1AccountState
        if (@(Get-Dev1IdentityProcesses -OwnerSid ([string]$accountState.Sid)).Count -ne 0 -or
            @(Get-Dev1Processes).Count -ne 0) {
            throw 'DEV1 remained busy after acquiring its controller mutex.'
        }
        $helperHash = Get-Sha256 $credentialHelperPath
        if ($helperHash -cne $ExpectedHelperSha256) { throw 'DEV1 credential helper differs from expected bytes.' }
        . $credentialHelperPath
        Assert-QmDev1CredentialHelperBinding -HelperPath $credentialHelperPath -ExpectedSha256 $ExpectedHelperSha256 | Out-Null
        $credentialHash = Get-Sha256 $credentialPath
        if ($credentialHash -cne $ExpectedCredentialSha256) { throw 'DEV1 machine credential differs from expected bytes.' }
        $rotationProof = Assert-V3RotationReceipt -AccountState $accountState `
            -CredentialSha256 $ExpectedCredentialSha256 -HelperSha256 $ExpectedHelperSha256

        New-Item -ItemType Directory -Path $stageRoot -Force | Out-Null
        Assert-PhysicalPath -Path $controllerRunRoot
        Copy-Item -LiteralPath $source -Destination $stageMq5 -Force
        if ((Get-Sha256 $stageMq5) -cne $sourceHash) { throw 'Staged source hash mismatch.' }
        @([pscustomobject]@{
            relative_path = 'QM5_20002_ict-icytea-core.mq5'
            bytes = (Get-Item $source).Length
            sha256 = $sourceHash
        }) | Export-Csv -LiteralPath $sourceManifest -NoTypeInformation -Encoding utf8

        $preexisting = Test-Path -LiteralPath $repoEx5 -PathType Leaf
        $preexistingHash = $null
        if ($preexisting) {
            $preexistingHash = Get-Sha256 $repoEx5
            $preexistingBackup = Join-Path $controllerRunRoot 'preexisting_repo_target.ex5'
            Copy-Item -LiteralPath $repoEx5 -Destination $preexistingBackup -Force
            Remove-Item -LiteralPath $repoEx5 -Force
        }

        $user = Get-LocalUser QMDev1
        if (-not $user.Enabled -or -not $user.PasswordRequired) { throw 'QMDev1 account gate failed.' }
        $sid = $user.SID.Value
        $account = "$env:COMPUTERNAME\QMDev1"
        $credential = Import-Clixml -LiteralPath $credentialPath
        if ($credential -isnot [Management.Automation.PSCredential]) { throw 'Invalid DEV1 credential type.' }
        $credentialName = $credential.UserName
        if ($credentialName.StartsWith('.\')) { $credentialName = "$env:COMPUTERNAME\$($credentialName.Substring(2))" }
        if (([Security.Principal.NTAccount]$credentialName).Translate([Security.Principal.SecurityIdentifier]).Value -ne $sid) {
            throw 'DEV1 credential SID mismatch.'
        }
        $plain = $credential.GetNetworkCredential().Password
        if ([string]::IsNullOrEmpty($plain)) { throw 'DEV1 task password is empty.' }

        $arguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Child -RunRoot "{1}" -ExpectedSid "{2}" -ExpectedSourceSha256 "{3}"' -f
            $controllerScript, $controllerRunRoot, $sid, $sourceHash
        $action = New-ScheduledTaskAction -Execute $pwsh -Argument $arguments -WorkingDirectory $controllerRunRoot
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Hidden `
            -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Settings $settings `
            -User $account -Password $plain -RunLevel Limited -Description "Ephemeral isolated QM20002 Contract-v3 compile" | Out-Null
        $taskRegistered = $true
        $plain = $null
        $credential = $null
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\'
        if ($task.Principal.LogonType.ToString() -ne 'Password' -or
            $task.Principal.RunLevel.ToString() -ne 'Limited' -or $null -ne $task.Triggers -or
            @($task.Actions).Count -ne 1 -or
            -not ([IO.Path]::GetFullPath([string]$task.Actions[0].Execute)).Equals(
                ([IO.Path]::GetFullPath($pwsh)), [StringComparison]::OrdinalIgnoreCase) -or
            [string]$task.Actions[0].Arguments -cne $arguments -or
            -not ([IO.Path]::GetFullPath([string]$task.Actions[0].WorkingDirectory)).Equals(
                ([IO.Path]::GetFullPath($controllerRunRoot)), [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Scheduled task isolation contract drift.'
        }
        if (@(Get-Dev1Processes).Count -ne 0) { throw 'DEV1 became busy before compile start.' }
        Start-ScheduledTask -TaskName $taskName -TaskPath '\'

        $deadline = (Get-Date).ToUniversalTime().AddMinutes(4)
        while ((Get-Date).ToUniversalTime() -lt $deadline -and -not (Test-Path -LiteralPath $resultPath)) {
            Start-Sleep -Seconds 1
        }
        if (-not (Test-Path -LiteralPath $resultPath)) { throw 'Isolated compile timed out.' }
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if (-not $result.success -or [int]$result.errors -ne 0 -or [int]$result.warnings -ne 0) {
            throw "Compile child failed: $($result.failure); errors=$($result.errors); warnings=$($result.warnings)"
        }
        if ([string]$result.source_mq5_sha256 -cne $sourceHash -or
            -not (Test-Path -LiteralPath $stageEx5 -PathType Leaf) -or (Get-Item $stageEx5).Length -le 0) {
            throw 'Compile child result does not bind the staged source/EX5.'
        }
        $stageHash = Get-Sha256 $stageEx5
        if ($stageHash -cne [string]$result.ex5_sha256) { throw 'Child EX5 SHA-256 mismatch.' }
        if ((Get-Sha256 $source) -cne $sourceHash) { throw 'Repository source changed during compile.' }
        if ((Get-Sha256 $controllerScript) -cne $controllerScriptHash) { throw 'Compile controller changed during compile.' }
        if ((Get-Sha256 $compileOne) -cne $compileOneHash) { throw 'compile_one changed during compile.' }
        if ((Get-Sha256 $metaEditor) -cne $metaEditorHash) { throw 'MetaEditor changed during compile.' }

        $waitExit = (Get-Date).ToUniversalTime().AddSeconds(30)
        while ((Get-Date).ToUniversalTime() -lt $waitExit -and
            (Get-ScheduledTask -TaskName $taskName -TaskPath '\').State -eq 'Running') { Start-Sleep -Milliseconds 250 }
        if ((Get-ScheduledTask -TaskName $taskName -TaskPath '\').State -eq 'Running') { throw 'Compile task did not exit cleanly.' }
        Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false
        $taskRegistered = $false
        Start-Sleep -Milliseconds 500
        $activeAfter = @(Get-Dev1Processes).Count
        $tasksAfter = @(Get-EphemeralCompileTasks).Count
        if ($activeAfter -ne 0 -or $tasksAfter -ne 0) { throw "Compile cleanup incomplete: processes=$activeAfter tasks=$tasksAfter" }

        $tempTarget = "$repoEx5.$([guid]::NewGuid().ToString('N')).tmp"
        Copy-Item -LiteralPath $stageEx5 -Destination $tempTarget -Force
        if ((Get-Sha256 $tempTarget) -cne $stageHash) { Remove-Item $tempTarget -Force; throw 'EX5 delivery temp mismatch.' }
        Move-Item -LiteralPath $tempTarget -Destination $repoEx5 -Force
        if ((Get-Sha256 $repoEx5) -cne $stageHash) { throw 'Repository EX5 delivery mismatch.' }
        $delivered = $true

        $compileLog = [IO.Path]::GetFullPath([string]$result.compile_log_path)
        $includeManifest = [IO.Path]::GetFullPath([string]$result.include_manifest_path)
        $includeAudit = [IO.Path]::GetFullPath([string]$result.include_path_audit_path)
        $evidence = [ordered]@{
            result = 'PASS'
            research_status = $researchStatus
            run_id = $runId
            run_root = $controllerRunRoot
            task_user = $account
            task_logon_type = 'Password'
            task_run_level = 'Limited'
            contract_commit = $expectedContractCommit
            contract_sha256 = $expectedContractSha256
            source_git_commit = $expectedSourceCommit
            source_path = $source
            source_bytes = (Get-Item $source).Length
            source_sha256 = $sourceHash
            metaeditor_path = $metaEditor
            metaeditor_sha256 = $metaEditorHash
            compile_one_path = $compileOne
            compile_one_sha256 = $compileOneHash
            compile_controller_path = $controllerScript
            compile_controller_sha256 = $controllerScriptHash
            compile_log_path = $compileLog
            compile_log_sha256 = Get-Sha256 $compileLog
            errors = [int]$result.errors
            warnings = [int]$result.warnings
            include_manifest_path = $includeManifest
            include_manifest_rows = [int]$result.include_manifest_rows
            include_sync_manifest_sha256 = Get-Sha256 $includeManifest
            include_path_audit_path = $includeAudit
            include_path_audit_sha256 = Get-Sha256 $includeAudit
            included_paths_count = [int]$result.included_paths_count
            outside_include_paths_count = [int]$result.outside_include_paths_count
            source_manifest_sha256 = Get-Sha256 $sourceManifest
            stage_ex5_path = $stageEx5
            repo_ex5_path = $repoEx5
            ex5_size_bytes = (Get-Item $repoEx5).Length
            ex5_sha256 = $stageHash
            preexisting_repo_ex5 = $preexisting
            preexisting_repo_ex5_sha256 = $preexistingHash
            active_dev1_processes_after = $activeAfter
            ephemeral_tasks_after = $tasksAfter
            git_head_after = $head
            finished_utc = (Get-Date).ToUniversalTime().ToString('o')
        }
        Write-AtomicJson -Path $evidencePath -Value $evidence
        $complete = $true
        $evidence | ConvertTo-Json -Compress
    } catch {
        $_.Exception.Message | Set-Content -LiteralPath (Join-Path $controllerRunRoot 'controller_error.txt') -Encoding utf8 -ErrorAction SilentlyContinue
        throw
    } finally {
        $plain = $null
        $credential = $null
        if ($taskRegistered) {
            try { Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue } catch { }
            try { Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction Stop } catch { }
        }
        if ($mutexAcquired) {
            foreach ($process in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ExecutablePath -and ([IO.Path]::GetFullPath([string]$_.ExecutablePath)).Equals(
                    ([IO.Path]::GetFullPath($metaEditor)), [StringComparison]::OrdinalIgnoreCase)
            })) {
                try { Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction Stop } catch { }
            }
        }
        if (-not $complete) {
            if ($delivered -and (Test-Path -LiteralPath $repoEx5 -PathType Leaf)) {
                try { Remove-Item -LiteralPath $repoEx5 -Force } catch { }
            }
            if ($preexistingBackup -and (Test-Path -LiteralPath $preexistingBackup -PathType Leaf)) {
                try { Copy-Item -LiteralPath $preexistingBackup -Destination $repoEx5 -Force } catch { }
            }
        }
        if ($mutexAcquired) { try { $mutex.ReleaseMutex() } catch { } }
        $mutex.Dispose()
    }
}

if ($Child.IsPresent) {
    Invoke-CompileChild
} else {
    Invoke-CompileController
}
