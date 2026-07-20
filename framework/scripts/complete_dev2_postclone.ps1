[CmdletBinding()]
param(
    [switch]$Apply,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+$')]
    [string]$ExpectedSid,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedProvisioningDirectory,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^QM_DEV2_PROFILE_INIT_[0-9a-f]{32}$')]
    [string]$ExpectedFailedTaskName,
    [switch]$ResumeExactCompletedProfileTask,
    [ValidatePattern('^QM_DEV2_PROFILE_INIT_[0-9a-f]{32}$')]
    [string]$ExpectedSuccessfulTaskName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'framework\registry\dev2_lane_contract.json'))
$initializerPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'initialize_dev2_profile.ps1'))
$lsaRightsPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dev2_lsa_rights.ps1'))
$credentialHelperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dev2_machine_credential.ps1'))
$pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$sourceRoot = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$terminalRoot = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$reportRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$provisioningRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2\provisioning')
$credentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV2\credential.machine-dpapi.json')
$expectedAccount = "$env:COMPUTERNAME\QMDev2"
$controllerMutexName = 'Global\QM_DEV2_SMOKE_CONTROLLER'
$provisionMutexName = 'Global\QM_DEV2_PROVISION'
$sourceMutexName = 'Global\QM_DEV1_SMOKE_CONTROLLER'

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) { throw 'Path contains CR, LF, or NUL.' }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
}

function Test-QmPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowRoot
    )
    $full = ConvertTo-QmFullPath -Path $Path
    $rootFull = (ConvertTo-QmFullPath -Path $Root).TrimEnd('\')
    if ($AllowRoot -and $full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $full.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-QmElevated {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'DEV2 post-clone completion requires an elevated Administrator token.'
    }
}

function Resolve-QmAccountSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    $normalized = if ($AccountName.StartsWith('.\')) { "$env:COMPUTERNAME\$($AccountName.Substring(2))" } else { $AccountName }
    return (New-Object System.Security.Principal.NTAccount($normalized)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}

function Assert-QmNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-QmFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Required path does not exist: $full" }
    $root = [System.IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in @($full.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in DEV2 completion path: $cursor"
        }
    }
}

function Assert-QmPhysicalTree {
    param([Parameter(Mandatory = $true)][string]$Root)
    Assert-QmNoReparseComponents -Path $Root
    $link = Get-ChildItem -LiteralPath $Root -Force -Recurse -ErrorAction Stop | Where-Object {
        (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -or
        ($_.PSObject.Properties.Name -contains 'LinkType' -and $_.LinkType -eq 'HardLink')
    } | Select-Object -First 1
    if ($link) { throw "DEV2 clone is not a physical tree: $($link.FullName)" }
}

function Get-QmWriteRightsMask {
    $rights = [System.Security.AccessControl.FileSystemRights]
    return [int64]($rights::Write -bor $rights::Modify -bor $rights::FullControl -bor $rights::Delete -bor
        $rights::DeleteSubdirectoriesAndFiles -bor $rights::ChangePermissions -bor $rights::TakeOwnership)
}

function Assert-QmAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedWriterSids,
        [switch]$RequireProtected,
        [string]$RequiredModifySid
    )
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    if ($RequireProtected -and -not $acl.AreAccessRulesProtected) { throw "ACL inheritance is not disabled: $Path" }
    if ($AllowedWriterSids -notcontains (Resolve-QmAccountSid -AccountName $acl.Owner)) {
        throw "Unexpected ACL owner: $Path"
    }
    $mask = Get-QmWriteRightsMask
    $modifySeen = [string]::IsNullOrWhiteSpace($RequiredModifySid)
    foreach ($rule in @($acl.Access)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) { continue }
        $sid = Resolve-QmAccountSid -AccountName $rule.IdentityReference.Value
        $ruleMask = [int64]$rule.FileSystemRights
        if (($ruleMask -band $mask) -ne 0 -and $AllowedWriterSids -notcontains $sid) {
            throw "Unexpected write-capable ACL identity on '$Path': $sid"
        }
        if ($sid -eq $RequiredModifySid -and
            (($ruleMask -band [int64][System.Security.AccessControl.FileSystemRights]::Modify) -eq
                [int64][System.Security.AccessControl.FileSystemRights]::Modify)) {
            $modifySeen = $true
        }
    }
    if (-not $modifySeen) { throw "Required QMDev2 Modify ACL is missing: $Path" }
}

function Set-QmAdminSystemAcl {
    param([Parameter(Mandatory = $true)][string]$Path)
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRuleAll($rule) }
    $admin = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $system = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
    $acl.SetOwner($admin)
    foreach ($sid in @($admin, $system)) {
        $access = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $sid, [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($access)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Get-QmProcessesWithinRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    return @(
        Get-CimInstance -ClassName Win32_Process -ErrorAction Stop | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
            (Test-QmPathWithin -Path ([string]$_.ExecutablePath) -Root $Root)
        }
    )
}

function Assert-QmSourceQuiescent {
    if (@(Get-QmProcessesWithinRoot -Root $sourceRoot).Count -ne 0) { throw 'DEV1 source has a running exact-path process.' }
    if (@(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV1_SMOKE_*' }).Count -ne 0) {
        throw 'DEV1 source has a smoke task.'
    }
}

function Assert-QmExactLateState {
    $user = Get-LocalUser -Name 'QMDev2' -ErrorAction Stop
    if ($user.SID.Value -cne $ExpectedSid -or $user.Enabled -or -not $user.PasswordRequired -or
        $user.UserMayChangePassword -or $user.Description -cne 'Isolated offline MT5 research lane DEV2') {
        throw 'QMDev2 late-state identity drifted.'
    }
    $memberships = @(
        Get-LocalGroup -ErrorAction Stop | ForEach-Object { Get-LocalGroupMember -Group $_ -ErrorAction SilentlyContinue } |
            Where-Object { $null -ne $_.SID -and $_.SID.Value -eq $ExpectedSid }
    )
    if ($memberships.Count -ne 0) { throw 'QMDev2 must retain group-less DEV1 parity.' }
    $profilePathExists = Test-Path -LiteralPath 'C:\Users\QMDev2'
    $profileKeyExists = Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$ExpectedSid"
    $profileReceiptExists = Test-Path -LiteralPath (Join-Path $ExpectedProvisioningDirectory 'qmdev2_profile_gate_redacted.json')
    if ($ResumeExactCompletedProfileTask.IsPresent) {
        if (-not $profilePathExists -or -not $profileKeyExists -or -not $profileReceiptExists) {
            throw 'Exact completed-profile resume requires profile, registry mapping, and atomic profile receipt.'
        }
    } elseif ($profilePathExists -or $profileKeyExists -or $profileReceiptExists) {
        throw 'QMDev2 profile unexpectedly exists before exact completion.'
    }
    if (@(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV2_*' }).Count -ne 0) {
        throw 'A DEV2 task unexpectedly survived the failed attempt.'
    }
    if (@(Get-QmProcessesWithinRoot -Root $terminalRoot).Count -ne 0) { throw 'DEV2 has a running process.' }
    if (Test-Path -LiteralPath (Join-Path $terminalRoot 'Config\agents.dat')) {
        throw 'DEV2 agents.dat exists before first successful task/profile initialization.'
    }
    return $user
}

function Assert-QmFirewall {
    $expected = [ordered]@{
        QM_DEV2_BLOCK_TERMINAL_OUT = Join-Path $terminalRoot 'terminal64.exe'
        QM_DEV2_BLOCK_METATESTER_OUT = Join-Path $terminalRoot 'metatester64.exe'
        QM_DEV2_BLOCK_METAEDITOR_OUT = Join-Path $terminalRoot 'MetaEditor64.exe'
    }
    if ((Get-Service MpsSvc -ErrorAction Stop).Status.ToString() -ne 'Running') { throw 'Windows Firewall is not running.' }
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    if ($profiles.Count -ne 3 -or @($profiles | Where-Object { -not $_.Enabled }).Count -ne 0) {
        throw 'All Windows Firewall profiles must be enabled.'
    }
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($item in $expected.GetEnumerator()) {
        $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $item.Key -ErrorAction Stop)
        if ($rules.Count -ne 1) { throw "Firewall rule count drift: $($item.Key)" }
        $rule = $rules[0]
        $filters = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction Stop)
        if ($filters.Count -ne 1 -or $rule.Enabled.ToString() -ne 'True' -or
            $rule.Direction.ToString() -ne 'Outbound' -or $rule.Action.ToString() -ne 'Block' -or
            $rule.Profile.ToString() -ne 'Any' -or
            -not (ConvertTo-QmFullPath -Path ([string]$filters[0].Program).Equals(
                (ConvertTo-QmFullPath -Path $item.Value), [System.StringComparison]::OrdinalIgnoreCase))) {
            throw "Firewall rule contract drift: $($item.Key)"
        }
        $rows.Add([ordered]@{ display_name = $item.Key; program = ConvertTo-QmFullPath -Path $item.Value })
    }
    return $rows.ToArray()
}

function Get-QmEventData {
    param([Parameter(Mandatory = $true)][object]$Event)
    [xml]$xml = $Event.ToXml()
    $values = @{}
    foreach ($entry in @($xml.Event.EventData.Data)) { $values[[string]$entry.Name] = [string]$entry.'#text' }
    return $values
}

function Get-QmTaskCimTimeProof {
    param(
        [Parameter(Mandatory = $true)][DateTime]$CimDateTime,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ReferenceUtc,
        [ValidateRange(1, 300)][int]$ToleranceSeconds = 10
    )
    # MSFT_ScheduledTask can surface LastRunTime either as a normal local clock
    # or as an already-UTC clock tagged DateTimeKind.Local. Test both explicit
    # interpretations against the task's authoritative UTC Scheduler event.
    $reference = $ReferenceUtc.ToUniversalTime()
    $kindConverted = [DateTimeOffset]$CimDateTime.ToUniversalTime()
    $rawUtcDateTime = [DateTime]::SpecifyKind($CimDateTime, [DateTimeKind]::Utc)
    $rawClockAsUtc = [DateTimeOffset]$rawUtcDateTime
    $candidates = @(
        [pscustomobject]@{
            interpretation = 'KIND_TO_UTC'
            utc = $kindConverted
            delta_seconds = [Math]::Abs(($kindConverted - $reference).TotalSeconds)
        },
        [pscustomobject]@{
            interpretation = 'RAW_CLOCK_IS_UTC'
            utc = $rawClockAsUtc
            delta_seconds = [Math]::Abs(($rawClockAsUtc - $reference).TotalSeconds)
        }
    )
    $valid = @($candidates | Where-Object { $_.delta_seconds -le $ToleranceSeconds } | Sort-Object delta_seconds)
    if ($valid.Count -lt 1) {
        throw "Task CIM LastRunTime cannot be reconciled with Scheduler UTC event. raw=$($CimDateTime.ToString('o')) kind=$($CimDateTime.Kind) reference=$($reference.ToString('o'))"
    }
    $selected = $valid[0]
    return [pscustomobject]@{
        status = 'PASS'
        cim_raw = $CimDateTime.ToString('o')
        cim_kind = $CimDateTime.Kind.ToString()
        reference_event_utc = $reference.ToString('o')
        selected_interpretation = $selected.interpretation
        selected_utc = $selected.utc.ToString('o')
        delta_seconds = [double]$selected.delta_seconds
        candidates = @($candidates | ForEach-Object {
                [ordered]@{
                    interpretation = $_.interpretation
                    utc = $_.utc.ToString('o')
                    delta_seconds = [double]$_.delta_seconds
                }
            })
    }
}

function Get-QmPriorFailureEvidence {
    $qualified = "\$ExpectedFailedTaskName"
    $matches = New-Object System.Collections.Generic.List[object]
    foreach ($event in @(Get-WinEvent -FilterHashtable @{
                LogName = 'Microsoft-Windows-TaskScheduler/Operational'; Id = 101, 104
            } -ErrorAction Stop)) {
        $data = Get-QmEventData -Event $event
        $eventTask = if ($data.ContainsKey('TaskName')) { $data.TaskName } else { $data.UserName }
        if ($eventTask -cne $qualified -or [string]$data.ResultCode -cne '2147943785') { continue }
        $matches.Add([ordered]@{
                event_id = [int]$event.Id
                record_id = [int64]$event.RecordId
                time_utc = $event.TimeCreated.ToUniversalTime().ToString('o')
                result_code = [string]$data.ResultCode
            })
    }
    $ids = @($matches | ForEach-Object { [int]$_.event_id } | Sort-Object -Unique)
    if ($ids -notcontains 101 -or $ids -notcontains 104) {
        throw 'Expected Task Scheduler 101/104 Win32-1385 evidence is missing.'
    }
    return $matches.ToArray()
}

function Assert-QmNoDenyBatchPolicy {
    $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("qm_dev2_rights_$([guid]::NewGuid().ToString('N')).inf")
    try {
        & secedit.exe /export /cfg $temporary /areas USER_RIGHTS | Out-Null
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $temporary -PathType Leaf)) {
            throw 'Unable to export local user-right policy.'
        }
        $deny = @(Select-String -LiteralPath $temporary -Pattern '^SeDenyBatchLogonRight\s*=' -ErrorAction Stop)
        if ($deny.Count -ne 0) { throw 'A machine-level SeDenyBatchLogonRight assignment exists; refusing completion.' }
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { [System.IO.File]::Delete($temporary) }
    }
}

function Test-QmCloneHashes {
    param([Parameter(Mandatory = $true)][object]$Contract)
    $csvPath = Join-Path $ExpectedProvisioningDirectory 'source_destination_sha256.csv'
    if (-not (Test-Path -LiteralPath $csvPath -PathType Leaf)) { throw "Hash CSV is missing: $csvPath" }
    $preFiles = @(Get-ChildItem -LiteralPath $ExpectedProvisioningDirectory -File -Force -ErrorAction Stop)
    $expectedEvidenceNames = if ($ResumeExactCompletedProfileTask.IsPresent) {
        @('qmdev2_profile_gate_redacted.json', 'source_destination_sha256.csv')
    } else {
        @('source_destination_sha256.csv')
    }
    $actualEvidenceNames = @($preFiles | ForEach-Object { $_.Name } | Sort-Object)
    if ([string]::Join('|', $actualEvidenceNames) -cne [string]::Join('|', @($expectedEvidenceNames | Sort-Object))) {
        throw 'Late-state provisioning directory contains unexpected evidence files.'
    }
    $rows = @(Import-Csv -LiteralPath $csvPath -ErrorAction Stop)
    if ($rows.Count -lt 100) { throw "Hash evidence is implausibly small: $($rows.Count)" }
    $destinationFiles = @(Get-ChildItem -LiteralPath $terminalRoot -File -Force -Recurse -ErrorAction Stop)
    if ($destinationFiles.Count -ne $rows.Count) {
        throw "DEV2 file count differs from hash evidence: actual=$($destinationFiles.Count) evidence=$($rows.Count)"
    }
    $seen = @{}
    $bytes = [int64]0
    $hcc = 0
    $tkc = 0
    $includes = 0
    $groups = 0
    $programRows = New-Object System.Collections.Generic.List[object]
    $exception = $null
    foreach ($row in $rows) {
        $relative = ([string]$row.relative_path).Replace('/', '\')
        if ([string]::IsNullOrWhiteSpace($relative) -or [System.IO.Path]::IsPathRooted($relative) -or
            @($relative.Split('\') | Where-Object { $_ -eq '..' }).Count -ne 0 -or $seen.ContainsKey($relative)) {
            throw "Unsafe or duplicate hash-evidence path: $relative"
        }
        $seen[$relative] = $true
        $source = ConvertTo-QmFullPath -Path (Join-Path $sourceRoot $relative)
        $destination = ConvertTo-QmFullPath -Path (Join-Path $terminalRoot $relative)
        if (-not (Test-QmPathWithin -Path $source -Root $sourceRoot) -or
            -not (Test-QmPathWithin -Path $destination -Root $terminalRoot)) {
            throw "Hash-evidence path escaped a lane root: $relative"
        }
        $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
        $destinationItem = Get-Item -LiteralPath $destination -Force -ErrorAction Stop
        $sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ([string]$row.match -cne 'True' -or [int64]$row.source_length -ne [int64]$sourceItem.Length -or
            [int64]$row.destination_length -ne [int64]$destinationItem.Length -or
            ([string]$row.source_sha256).ToLowerInvariant() -cne $sourceHash -or
            ([string]$row.destination_sha256).ToLowerInvariant() -cne $destinationHash -or
            $sourceHash -cne $destinationHash) {
            throw "Source/DEV2/hash-CSV mismatch: $relative"
        }
        $bytes += [int64]$destinationItem.Length
        if ($relative -match '^Bases\\Custom\\history\\[^\\]+\\(?<year>201[7-9]|202[0-5])\.hcc$') { $hcc++ }
        if ($relative -match '^Bases\\Custom\\ticks\\[^\\]+\\.+\.tkc$') { $tkc++ }
        if ($relative -like 'MQL5\Include\*') { $includes++ }
        if ($relative -like 'MQL5\Profiles\Tester\Groups\*') { $groups++ }
        if ($relative -ceq 'Bases\Custom\history\GBPUSD.DWX\2026.hcc') {
            $exception = [ordered]@{ relative_path = $relative; current_sha256 = $destinationHash; old_manifest_hash_claimed = $false }
        }
    }
    foreach ($file in $destinationFiles) {
        $relative = $file.FullName.Substring($terminalRoot.TrimEnd('\').Length + 1)
        if (-not $seen.ContainsKey($relative)) { throw "Unexpected DEV2 file outside hash evidence: $relative" }
    }
    foreach ($property in @($Contract.program_sha256.PSObject.Properties)) {
        $name = [string]$property.Name
        $expected = ([string]$property.Value).ToLowerInvariant()
        $actual = (Get-FileHash -LiteralPath (Join-Path $terminalRoot $name) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actual -cne $expected) { throw "DEV2 program hash mismatch: $name" }
        $programRows.Add([ordered]@{ name = $name; sha256 = $actual })
    }
    if ($hcc -lt 1 -or $tkc -lt 1 -or $includes -lt 1 -or $groups -lt 1 -or $null -eq $exception) {
        throw "Required clone category is empty: hcc=$hcc tkc=$tkc includes=$includes groups=$groups exception=$($null -ne $exception)"
    }
    return [pscustomobject]@{
        csv_path = $csvPath
        csv_sha256 = (Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash.ToLowerInvariant()
        file_count = $rows.Count
        bytes = $bytes
        hcc_2017_2025_count = $hcc
        custom_tkc_count = $tkc
        include_count = $includes
        tester_group_count = $groups
        program_sha256 = $programRows.ToArray()
        documented_2026_exception = $exception
    }
}

function Invoke-QmProfileTask {
    param([Parameter(Mandatory = $true)][System.Management.Automation.PSCredential]$Credential)
    $nonce = [guid]::NewGuid().ToString('N')
    $receiptPath = Join-Path $ExpectedProvisioningDirectory 'qmdev2_profile_gate_redacted.json'
    if (Test-Path -LiteralPath $receiptPath) { throw "Profile receipt already exists: $receiptPath" }
    $taskName = "QM_DEV2_PROFILE_INIT_$([guid]::NewGuid().ToString('N'))"
    $argument = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Nonce {1} -ReceiptPath "{2}"' -f `
        $initializerPath, $nonce, $receiptPath
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $argument -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
        -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
    $password = $Credential.GetNetworkCredential().Password
    if ([string]::IsNullOrEmpty($password)) { throw 'DPAPI credential contains an empty password.' }
    $registered = $false
    $success = $false
    try {
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Settings $settings `
            -User $expectedAccount -Password $password -RunLevel Limited `
            -Description 'Ephemeral exact DEV2 post-clone profile initialization' -ErrorAction Stop | Out-Null
        $password = $null
        $registered = $true
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
        if ((Resolve-QmAccountSid -AccountName $task.Principal.UserId) -cne $ExpectedSid -or
            $task.Principal.LogonType.ToString() -ne 'Password' -or $task.Principal.RunLevel.ToString() -ne 'Limited' -or
            $null -ne $task.Triggers -or @($task.Actions).Count -ne 1 -or $task.Settings.MultipleInstances.ToString() -ne 'IgnoreNew') {
            throw 'Registered DEV2 profile task drifted from the limited triggerless contract.'
        }
        $startedUtc = (Get-Date).ToUniversalTime()
        Start-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
        $observedRunning = $false
        $deadline = $startedUtc.AddMinutes(3)
        do {
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
            $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath '\' -ErrorAction Stop
            if ($task.State.ToString() -eq 'Running') { $observedRunning = $true }
            if ((Test-Path -LiteralPath $receiptPath -PathType Leaf) -and
                $task.State.ToString() -ne 'Running' -and [int64]$info.LastTaskResult -ne 267011) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date).ToUniversalTime() -lt $deadline)
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath '\' -ErrorAction Stop
        if ($task.State.ToString() -eq 'Running' -or [int64]$info.LastTaskResult -ne 0) {
            throw "DEV2 profile task did not complete successfully; state=$($task.State) result=$($info.LastTaskResult)"
        }
        if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw 'DEV2 profile task completed without its atomic receipt.' }
        $eventDeadline = (Get-Date).ToUniversalTime().AddSeconds(10)
        do {
            $eventRows = New-Object System.Collections.Generic.List[object]
            foreach ($event in @(Get-WinEvent -FilterHashtable @{
                        LogName = 'Microsoft-Windows-TaskScheduler/Operational'; StartTime = $startedUtc.AddSeconds(-2)
                    } -ErrorAction Stop)) {
                $data = Get-QmEventData -Event $event
                $eventTask = if ($data.ContainsKey('TaskName')) { $data.TaskName } else { $null }
                if ([string]$eventTask -cne "\$taskName") { continue }
                $eventRows.Add([ordered]@{
                        event_id = [int]$event.Id
                        record_id = [int64]$event.RecordId
                        time_utc = $event.TimeCreated.ToUniversalTime().ToString('o')
                        instance_id = if ($data.ContainsKey('InstanceId')) { [string]$data.InstanceId } elseif ($data.ContainsKey('TaskInstanceId')) { [string]$data.TaskInstanceId } else { $null }
                        result_code = if ($data.ContainsKey('ResultCode')) { [string]$data.ResultCode } else { $null }
                        action_name = if ($data.ContainsKey('ActionName')) { [string]$data.ActionName } else { $null }
                    })
            }
            $eventIds = @($eventRows | ForEach-Object { [int]$_.event_id } | Sort-Object -Unique)
            if ($eventIds -contains 100 -and $eventIds -contains 102 -and $eventIds -contains 200 -and $eventIds -contains 201) { break }
            Start-Sleep -Milliseconds 250
        } while ((Get-Date).ToUniversalTime() -lt $eventDeadline)
        if ($eventIds -notcontains 100 -or $eventIds -notcontains 102 -or $eventIds -notcontains 200 -or $eventIds -notcontains 201) {
            throw "DEV2 profile task lacks Task Scheduler start/completion events; ids=$([string]::Join(',', $eventIds))"
        }
        $instances = @($eventRows | ForEach-Object { [string]$_.instance_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
        $actionSuccess = @($eventRows | Where-Object { $_.event_id -eq 201 }) | Select-Object -Last 1
        if ($instances.Count -ne 1 -or [string]$actionSuccess.result_code -cne '0' -or
            -not (ConvertTo-QmFullPath -Path ([string]$actionSuccess.action_name)).Equals(
                (ConvertTo-QmFullPath -Path $pwshPath), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'DEV2 profile task events lack a single instance and fixed-action ResultCode=0 proof.'
        }
        $startedEvent = @($eventRows | Where-Object { $_.event_id -eq 100 } | Sort-Object time_utc) | Select-Object -First 1
        $cimTimeProof = Get-QmTaskCimTimeProof -CimDateTime $info.LastRunTime `
            -ReferenceUtc ([DateTimeOffset]::Parse([string]$startedEvent.time_utc))
        $receipt = Get-Content -LiteralPath $receiptPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$receipt.status -cne 'PASS' -or [string]$receipt.nonce -cne $nonce -or
            [string]$receipt.sid -cne $ExpectedSid -or
            -not ([string]$receipt.account).Equals($expectedAccount, [System.StringComparison]::OrdinalIgnoreCase) -or
            @($receipt.calendars).Count -ne 2) {
            throw 'DEV2 profile receipt identity/nonce/calendar contract failed.'
        }
        foreach ($calendar in @($receipt.calendars)) {
            $sourceHash = (Get-FileHash -LiteralPath ([string]$calendar.source_path) -Algorithm SHA256).Hash.ToLowerInvariant()
            $destinationHash = (Get-FileHash -LiteralPath ([string]$calendar.destination_path) -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($sourceHash -cne $destinationHash -or $destinationHash -cne ([string]$calendar.sha256).ToLowerInvariant()) {
                throw "DEV2 calendar hash verification failed: $($calendar.name)"
            }
        }
        $success = $true
        return [pscustomobject]@{
            task_name = $taskName
            observed_running_state = $observedRunning
            running_state_proof = if ($observedRunning) { 'CIM_RUNNING_STATE_AND_SCHEDULER_EVENT_100' } else { 'TASK_SCHEDULER_EVENT_100' }
            last_task_result = [int64]$info.LastTaskResult
            last_run_utc = $cimTimeProof.selected_utc
            last_run_cim_time_proof = $cimTimeProof
            scheduler_events = $eventRows.ToArray()
            receipt_path = $receiptPath
            receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
            profile = [string]$receipt.profile
            common_path = [string]$receipt.common_path
            calendars = @($receipt.calendars)
        }
    } finally {
        $password = $null
        if ($registered) {
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
            if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
                Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
            }
            Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction Stop
            if ($null -ne (Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue)) {
                throw "DEV2 profile task survived exact unregister: $taskName"
            }
        }
        if (-not $success) {
            $user = Get-LocalUser -Name 'QMDev2' -ErrorAction SilentlyContinue
            if ($null -ne $user -and $user.SID.Value -eq $ExpectedSid) { Disable-LocalUser -Name 'QMDev2' -ErrorAction Stop }
        }
    }
}

function Get-QmCompletedProfileTaskEvidence {
    param([Parameter(Mandatory = $true)][string]$TaskName)
    $qualified = "\$TaskName"
    $eventRows = New-Object System.Collections.Generic.List[object]
    foreach ($event in @(Get-WinEvent -FilterHashtable @{
                LogName = 'Microsoft-Windows-TaskScheduler/Operational'; Id = 100, 102, 200, 201
            } -ErrorAction Stop)) {
        $data = Get-QmEventData -Event $event
        if (-not $data.ContainsKey('TaskName') -or [string]$data.TaskName -cne $qualified) { continue }
        $instanceId = if ($data.ContainsKey('InstanceId')) {
            [string]$data.InstanceId
        } elseif ($data.ContainsKey('TaskInstanceId')) {
            [string]$data.TaskInstanceId
        } else { $null }
        $eventRows.Add([ordered]@{
                event_id = [int]$event.Id
                record_id = [int64]$event.RecordId
                time_utc = $event.TimeCreated.ToUniversalTime().ToString('o')
                instance_id = $instanceId
                result_code = if ($data.ContainsKey('ResultCode')) { [string]$data.ResultCode } else { $null }
                action_name = if ($data.ContainsKey('ActionName')) { [string]$data.ActionName } else { $null }
            })
    }
    $ids = @($eventRows | ForEach-Object { [int]$_.event_id } | Sort-Object -Unique)
    foreach ($requiredId in @(100, 102, 200, 201)) {
        if ($ids -notcontains $requiredId) { throw "Successful DEV2 task evidence lacks Scheduler event $requiredId." }
    }
    $instances = @($eventRows | ForEach-Object { [string]$_.instance_id } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    if ($instances.Count -ne 1) { throw 'Successful DEV2 task Scheduler events do not bind to exactly one instance.' }
    $actionSuccess = @($eventRows | Where-Object { $_.event_id -eq 201 }) | Select-Object -Last 1
    if ([string]$actionSuccess.result_code -cne '0' -or
        -not (ConvertTo-QmFullPath -Path ([string]$actionSuccess.action_name)).Equals(
            (ConvertTo-QmFullPath -Path $pwshPath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Successful DEV2 action event lacks ResultCode=0 or the fixed PowerShell executable.'
    }
    $startedEvent = @($eventRows | Where-Object { $_.event_id -eq 100 } | Sort-Object time_utc) | Select-Object -First 1
    $completedEvent = @($eventRows | Where-Object { $_.event_id -eq 102 } | Sort-Object time_utc) | Select-Object -Last 1
    $startedUtc = [DateTimeOffset]::Parse([string]$startedEvent.time_utc).ToUniversalTime()
    $completedUtc = [DateTimeOffset]::Parse([string]$completedEvent.time_utc).ToUniversalTime()
    if ($completedUtc -lt $startedUtc -or ($completedUtc - $startedUtc).TotalMinutes -gt 5) {
        throw 'Successful DEV2 task event chronology is invalid.'
    }
    $receiptPath = Join-Path $ExpectedProvisioningDirectory 'qmdev2_profile_gate_redacted.json'
    $receipt = Get-Content -LiteralPath $receiptPath -Raw -ErrorAction Stop | ConvertFrom-Json -DateKind String -ErrorAction Stop
    $receiptUtc = [DateTimeOffset]::Parse([string]$receipt.completed_utc).ToUniversalTime()
    if ([string]$receipt.status -cne 'PASS' -or [string]$receipt.nonce -notmatch '^[0-9a-f]{32}$' -or
        [string]$receipt.sid -cne $ExpectedSid -or
        -not ([string]$receipt.account).Equals($expectedAccount, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$receipt.profile)).Equals('C:\Users\QMDev2', [System.StringComparison]::OrdinalIgnoreCase) -or
        $receiptUtc -lt $startedUtc.AddSeconds(-2) -or $receiptUtc -gt $completedUtc.AddSeconds(2) -or
        @($receipt.calendars).Count -ne 2) {
        throw 'Completed DEV2 profile receipt is not bound to the successful Scheduler event interval.'
    }
    foreach ($calendar in @($receipt.calendars)) {
        $sourceHash = (Get-FileHash -LiteralPath ([string]$calendar.source_path) -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationHash = (Get-FileHash -LiteralPath ([string]$calendar.destination_path) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceHash -cne $destinationHash -or $destinationHash -cne ([string]$calendar.sha256).ToLowerInvariant()) {
            throw "Completed DEV2 calendar hash verification failed: $($calendar.name)"
        }
    }
    return [pscustomobject]@{
        task_name = $TaskName
        observed_running_state = $false
        running_state_proof = 'TASK_SCHEDULER_EVENT_100'
        last_task_result = 0
        result_proof = 'TASK_SCHEDULER_EVENT_201_RESULT_0_AND_EVENT_102_SUCCESS'
        last_run_utc = $startedUtc.ToString('o')
        scheduler_events = $eventRows.ToArray()
        receipt_path = $receiptPath
        receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
        profile = [string]$receipt.profile
        common_path = [string]$receipt.common_path
        calendars = @($receipt.calendars)
        task_was_unregistered = $true
    }
}

$ExpectedProvisioningDirectory = ConvertTo-QmFullPath -Path $ExpectedProvisioningDirectory
if ($ResumeExactCompletedProfileTask.IsPresent -and [string]::IsNullOrWhiteSpace($ExpectedSuccessfulTaskName)) {
    throw '-ResumeExactCompletedProfileTask requires -ExpectedSuccessfulTaskName.'
}
if (-not $ResumeExactCompletedProfileTask.IsPresent -and -not [string]::IsNullOrWhiteSpace($ExpectedSuccessfulTaskName)) {
    throw '-ExpectedSuccessfulTaskName is valid only with -ResumeExactCompletedProfileTask.'
}
if (-not (Test-QmPathWithin -Path $ExpectedProvisioningDirectory -Root $provisioningRoot) -or
    [System.IO.Path]::GetFileName($ExpectedProvisioningDirectory) -notmatch '^[0-9]{8}T[0-9]{6}Z$') {
    throw 'ExpectedProvisioningDirectory escaped the fixed timestamped DEV2 provisioning root.'
}
foreach ($fixedPath in @($contractPath, $initializerPath, $lsaRightsPath, $credentialHelperPath, $sourceRoot, $terminalRoot, $reportRoot,
        $ExpectedProvisioningDirectory, $credentialPath, $pwshPath)) {
    Assert-QmNoReparseComponents -Path $fixedPath
}
$contract = Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ([int]$contract.schema_version -ne 3 -or [string]$contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V3' -or
    [string]$contract.identity.credential_format -cne 'QM_DEV2_MACHINE_DPAPI_CREDENTIAL' -or
    [string]$contract.identity.dpapi_scope -cne 'LocalMachine' -or
    -not (ConvertTo-QmFullPath -Path ([string]$contract.identity.credential)).Equals($credentialPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not [bool]$contract.identity.credential_acl.inheritance_protected -or
    [string]$contract.identity.credential_acl.owner_sid -cne 'S-1-5-32-544' -or
    [bool]$contract.identity.credential_acl.additional_readers -or
    [string]::Join('|', @($contract.identity.credential_acl.exact_full_control_sids | ForEach-Object { [string]$_ } | Sort-Object)) -cne 'S-1-5-18|S-1-5-32-544' -or
    [string]$contract.coordination.controller_mutex -cne $controllerMutexName -or
    [string]$contract.coordination.provision_mutex -cne $provisionMutexName -or
    [string]$contract.coordination.source_quiescence_mutex -cne $sourceMutexName -or
    [string]$contract.coordination.task_prefix -cne 'QM_DEV2_SMOKE_' -or
    [string]$contract.coordination.profile_task_prefix -cne 'QM_DEV2_PROFILE_INIT_' -or
    [bool]$contract.agent_port_contract.source_agents_dat_copied -or
    -not [bool]$contract.agent_port_contract.require_runtime_listener_proof -or
    -not [bool]$contract.agent_port_contract.require_exact_dev2_metatester_path -or
    -not [bool]$contract.agent_port_contract.require_no_concurrent_overlapping_endpoint_owner -or
    -not [bool]$contract.agent_port_contract.allow_released_baseline_endpoint_reuse) {
    throw 'DEV2 lane contract drifted before exact post-clone completion.'
}
. $lsaRightsPath
. $credentialHelperPath

if (-not $Apply) {
    $user = Get-LocalUser -Name 'QMDev2' -ErrorAction SilentlyContinue
    Write-Output ([ordered]@{
            schema_version = 1
            status = 'PLAN_ONLY'
            mutates_host = $false
            expected_sid = $ExpectedSid
            user_exists = $null -ne $user
            user_enabled = if ($null -ne $user) { [bool]$user.Enabled } else { $null }
            user_password_required = if ($null -ne $user) { [bool]$user.PasswordRequired } else { $null }
            terminal_exists = Test-Path -LiteralPath $terminalRoot
            credential_exists = Test-Path -LiteralPath $credentialPath
            profile_exists = Test-Path -LiteralPath 'C:\Users\QMDev2'
            resume_exact_completed_profile_task = $ResumeExactCompletedProfileTask.IsPresent
            expected_successful_task_name = $ExpectedSuccessfulTaskName
            agents_dat_exists = Test-Path -LiteralPath (Join-Path $terminalRoot 'Config\agents.dat')
            dev2_task_count = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV2_*' }).Count
            dev2_process_count = @(Get-QmProcessesWithinRoot -Root $terminalRoot).Count
            direct_account_rights = @(Get-QmDev2AccountRights -Sid $ExpectedSid)
            smoke_will_run = $false
        } | ConvertTo-Json -Depth 5 -Compress)
    exit 0
}

Assert-QmElevated
$provisionMutex = $null
$sourceMutex = $null
$provisionAcquired = $false
$sourceAcquired = $false
$completed = $false
$credential = $null
try {
    $provisionMutex = New-Object System.Threading.Mutex($false, $provisionMutexName)
    $sourceMutex = New-Object System.Threading.Mutex($false, $sourceMutexName)
    try { $provisionAcquired = $provisionMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $provisionAcquired = $true }
    if (-not $provisionAcquired) { throw 'Another DEV2 provisioner holds the exact mutex.' }
    try { $sourceAcquired = $sourceMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $sourceAcquired = $true }
    if (-not $sourceAcquired) { throw 'DEV1 controller mutex is busy.' }

    Assert-QmSourceQuiescent
    $user = Assert-QmExactLateState
    $adminSid = 'S-1-5-32-544'
    $systemSid = 'S-1-5-18'
    Assert-QmPhysicalTree -Root $terminalRoot
    Assert-QmAcl -Path $terminalRoot -AllowedWriterSids @($adminSid, $systemSid, $ExpectedSid) -RequireProtected -RequiredModifySid $ExpectedSid
    Assert-QmAcl -Path $reportRoot -AllowedWriterSids @($adminSid, $systemSid, $ExpectedSid) -RequireProtected -RequiredModifySid $ExpectedSid
    Assert-QmDev2CredentialExactAcl -Path ([System.IO.Path]::GetDirectoryName($credentialPath)) -Directory
    Assert-QmDev2CredentialExactAcl -Path $credentialPath
    $firewall = @(Assert-QmFirewall)
    $priorFailure = @(Get-QmPriorFailureEvidence)
    $credentialSha256 = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $credential = Get-QmDev2MachineCredential -CredentialPath $credentialPath `
        -ExpectedCredentialSha256 $credentialSha256 -ExpectedAccount $expectedAccount -ExpectedSid $ExpectedSid `
        -ContractId ([string]$contract.contract_id) -Lane ([string]$contract.lane)
    $clone = Test-QmCloneHashes -Contract $contract
    Assert-QmSourceQuiescent

    $rightsBefore = @(Get-QmDev2AccountRights -Sid $ExpectedSid)
    Assert-QmNoDenyBatchPolicy
    if ($ResumeExactCompletedProfileTask.IsPresent) {
        if ([string]::Join('|', $rightsBefore) -cne 'SeBatchLogonRight') {
            throw "Completed-profile resume requires exactly SeBatchLogonRight; actual=$([string]::Join(',', $rightsBefore))"
        }
        $rightGrant = [pscustomobject]@{
            before = @()
            after = @('SeBatchLogonRight')
            added = @('SeBatchLogonRight')
            evidence_source = 'EXACT_PRIOR_COMPLETION_ATTEMPT_PLUS_CURRENT_LSA_ENUMERATION'
        }
        $profileTask = Get-QmCompletedProfileTaskEvidence -TaskName $ExpectedSuccessfulTaskName
    } else {
        if ($rightsBefore.Count -ne 0) { throw "QMDev2 unexpectedly has direct account rights: $([string]::Join(',', $rightsBefore))" }
        $rightGrant = Grant-QmDev2BatchLogonRight -Sid $ExpectedSid
        if (@($rightGrant.added).Count -ne 1 -or [string]$rightGrant.added[0] -cne 'SeBatchLogonRight') {
            throw 'The exact LSA operation did not add only SeBatchLogonRight.'
        }
        Enable-LocalUser -Name 'QMDev2' -ErrorAction Stop
        $enabled = Get-LocalUser -Name 'QMDev2' -ErrorAction Stop
        if ($enabled.SID.Value -cne $ExpectedSid -or -not $enabled.Enabled -or -not $enabled.PasswordRequired) {
            throw 'QMDev2 enable contract failed after the minimal right grant.'
        }
        $profileTask = Invoke-QmProfileTask -Credential $credential
    }
    if ($null -ne $credential) { $credential.Password.Dispose() }
    $credential = $null
    Assert-QmNoDenyBatchPolicy
    Disable-LocalUser -Name 'QMDev2' -ErrorAction Stop
    $disarmedUser = Get-LocalUser -Name 'QMDev2' -ErrorAction Stop
    if ($disarmedUser.SID.Value -cne $ExpectedSid -or $disarmedUser.Enabled -or -not $disarmedUser.PasswordRequired) {
        throw 'QMDev2 final disabled readiness contract failed.'
    }

    $hashCsvAfterTask = (Get-FileHash -LiteralPath $clone.csv_path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hashCsvAfterTask -cne $clone.csv_sha256) { throw 'Clone hash evidence changed during profile initialization.' }
    if ((@(Get-QmProcessesWithinRoot -Root $terminalRoot).Count -ne 0) -or
        (Test-Path -LiteralPath (Join-Path $terminalRoot 'Config\agents.dat'))) {
        throw 'Profile-only completion unexpectedly started or initialized MT5.'
    }
    if (@(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV2_*' }).Count -ne 0) {
        throw 'A DEV2 task survived profile completion.'
    }
    $rightsAfter = @(Get-QmDev2AccountRights -Sid $ExpectedSid)
    if ([string]::Join('|', $rightsAfter) -cne 'SeBatchLogonRight') {
        throw "QMDev2 direct rights drifted after task: $([string]::Join(',', $rightsAfter))"
    }

    foreach ($evidencePath in @($clone.csv_path, $profileTask.receipt_path)) {
        Set-QmAdminSystemAcl -Path $evidencePath
        Assert-QmAcl -Path $evidencePath -AllowedWriterSids @($adminSid, $systemSid) -RequireProtected
    }
    Set-QmAdminSystemAcl -Path $ExpectedProvisioningDirectory
    Assert-QmAcl -Path $ExpectedProvisioningDirectory -AllowedWriterSids @($adminSid, $systemSid) -RequireProtected

    $receiptPath = Join-Path $ExpectedProvisioningDirectory 'dev2_provisioning_receipt.json'
    if (Test-Path -LiteralPath $receiptPath) { throw "Final DEV2 receipt already exists: $receiptPath" }
    $receipt = [ordered]@{
        schema_version = 1
        contract_id = [string]$contract.contract_id
        status = 'PASS'
        completed_utc = (Get-Date).ToUniversalTime().ToString('o')
        contract_path = $contractPath
        contract_sha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
        completion_script_path = $PSCommandPath
        completion_script_sha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
        initializer_sha256 = (Get-FileHash -LiteralPath $initializerPath -Algorithm SHA256).Hash.ToLowerInvariant()
        lsa_helper_sha256 = (Get-FileHash -LiteralPath $lsaRightsPath -Algorithm SHA256).Hash.ToLowerInvariant()
        source_root = $sourceRoot
        terminal_root = $terminalRoot
        report_root = $reportRoot
        identity = [ordered]@{
            account = $expectedAccount
            sid = $ExpectedSid
            enabled = $false
            ready_but_disarmed = $true
            password_required = $true
            limited_non_admin = $true
            group_memberships = @()
            profile = $profileTask.profile
            common_path = $profileTask.common_path
            credential_path = $credentialPath
            credential_sha256 = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256).Hash.ToLowerInvariant()
            credential_format = [string]$contract.identity.credential_format
            dpapi_scope = [string]$contract.identity.dpapi_scope
            credential_helper_path = $credentialHelperPath
            credential_helper_sha256 = (Get-FileHash -LiteralPath $credentialHelperPath -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        coordination = $contract.coordination
        source_quiescence = [ordered]@{
            mutex = $sourceMutexName
            mutex_held_for_reverification = $sourceAcquired
            final_source_process_count = @(Get-QmProcessesWithinRoot -Root $sourceRoot).Count
            final_source_task_count = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV1_SMOKE_*' }).Count
        }
        prior_failed_profile_task = [ordered]@{
            task_name = $ExpectedFailedTaskName
            root_cause = 'ERROR_LOGON_TYPE_NOT_GRANTED'
            win32_error = 1385
            scheduler_result = 2147943785
            events = $priorFailure
        }
        account_rights = [ordered]@{
            before = @($rightGrant.before)
            after = @($rightGrant.after)
            added = @($rightGrant.added)
            deny_batch_policy_present = $false
            other_rights_added = $false
        }
        profile_task = $profileTask
        firewall = $firewall
        copy = [ordered]@{
            file_count = $clone.file_count
            bytes = $clone.bytes
            all_files_reverified_source_destination_sha256 = $true
            hash_csv = $clone.csv_path
            hash_csv_sha256 = $clone.csv_sha256
            hcc_2017_2025_verified_count = $clone.hcc_2017_2025_count
            custom_tkc_verified_count = $clone.custom_tkc_count
            include_verified_count = $clone.include_count
            tester_group_verified_count = $clone.tester_group_count
            program_sha256 = $clone.program_sha256
            documented_2026_exception = $clone.documented_2026_exception
        }
        agent_port_contract = $contract.agent_port_contract
        non_trading_readiness = [ordered]@{
            status = 'PASS'
            mt5_smoke_started = $false
            dev2_process_count = 0
            dev2_listener_count = 0
            identity_enabled = $false
            identity_disarmed_until_authorized_smoke = $true
            source_agents_dat_copied = $false
            agents_dat_exists = $false
            runtime_listener_proof_status = 'PENDING_FIRST_AUTHORIZED_SMOKE'
        }
        smoke_proof = [ordered]@{
            status = 'PENDING'
            reason = 'No MT5 smoke was authorized during post-clone completion.'
        }
    }
    [System.IO.File]::WriteAllText($receiptPath, ($receipt | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))
    Set-QmAdminSystemAcl -Path $receiptPath
    Assert-QmAcl -Path $receiptPath -AllowedWriterSids @($adminSid, $systemSid) -RequireProtected
    $completed = $true
    Write-Output ([ordered]@{
            status = 'PASS'
            receipt = $receiptPath
            receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
            file_count = $clone.file_count
            copied_bytes = $clone.bytes
            task_last_result = $profileTask.last_task_result
            task_event_ids = @($profileTask.scheduler_events | ForEach-Object { $_.event_id } | Sort-Object -Unique)
            account_rights = $rightsAfter
            smoke_status = 'PENDING'
        } | ConvertTo-Json -Depth 5 -Compress)
} finally {
    if ($null -ne $credential) {
        try { $credential.Password.Dispose() } catch { }
    }
    $credential = $null
    if (-not $completed) {
        $user = Get-LocalUser -Name 'QMDev2' -ErrorAction SilentlyContinue
        if ($null -ne $user -and $user.SID.Value -eq $ExpectedSid) {
            try { Disable-LocalUser -Name 'QMDev2' -ErrorAction Stop } catch { Write-Warning $_.Exception.Message }
        }
    }
    if ($sourceAcquired -and $null -ne $sourceMutex) { try { $sourceMutex.ReleaseMutex() } catch { } }
    if ($provisionAcquired -and $null -ne $provisionMutex) { try { $provisionMutex.ReleaseMutex() } catch { } }
    if ($null -ne $sourceMutex) { $sourceMutex.Dispose() }
    if ($null -ne $provisionMutex) { $provisionMutex.Dispose() }
}
