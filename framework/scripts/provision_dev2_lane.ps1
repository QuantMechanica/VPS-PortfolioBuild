[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ResumeExactPartialUser,
    [ValidatePattern('^S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+$')]
    [string]$ExpectedPartialUserSid
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = Join-Path $repoRoot 'framework\registry\dev2_lane_contract.json'
$profileInitializerPath = Join-Path $PSScriptRoot 'initialize_dev2_profile.ps1'
$lsaRightsPath = Join-Path $PSScriptRoot 'dev2_lsa_rights.ps1'
$credentialHelperPath = Join-Path $PSScriptRoot 'dev2_machine_credential.ps1'
$pwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$fixedSourceRoot = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV1')
$fixedTerminalRoot = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$fixedReportRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$fixedProvisioningRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2\provisioning')
$fixedCredentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV2\credential.machine-dpapi.json')

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'Path contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
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

function Assert-QmElevated {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'DEV2 provisioning requires an elevated Administrator token.'
    }
}

function Assert-QmNoReparseTree {
    param([Parameter(Mandatory = $true)][string]$Root)
    $rootItem = Get-Item -LiteralPath $Root -Force -ErrorAction Stop
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse-point root is forbidden: $Root"
    }
    $link = Get-ChildItem -LiteralPath $Root -Force -Recurse -ErrorAction Stop |
        Where-Object {
            (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -or
            ($_.PSObject.Properties.Name -contains 'LinkType' -and $_.LinkType -eq 'HardLink')
        } | Select-Object -First 1
    if ($link) {
        throw "DEV2 source must be a physical tree; link found: $($link.FullName)"
    }
}

function Resolve-QmAccountSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    $account = New-Object System.Security.Principal.NTAccount($AccountName)
    return $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
}

function Set-QmPasswordRequired {
    param([Parameter(Mandatory = $true)][string]$UserName)
    $userEntry = [ADSI]("WinNT://{0}/{1},user" -f $env:COMPUTERNAME, $UserName)
    $passwordNotRequiredFlag = 0x20
    $flags = [int]$userEntry.Properties['UserFlags'].Value
    $userEntry.Properties['UserFlags'].Value = ($flags -band (-bnot $passwordNotRequiredFlag))
    $userEntry.CommitChanges()
    $user = Get-LocalUser -Name $UserName -ErrorAction Stop
    if (-not $user.PasswordRequired) {
        throw "Failed to enforce PasswordRequired=True for $UserName."
    }
}

function Assert-QmExactPartialUserState {
    param(
        [Parameter(Mandatory = $true)][string]$UserName,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$TerminalRoot,
        [Parameter(Mandatory = $true)][string]$ReportRoot,
        [Parameter(Mandatory = $true)][string]$CredentialPath,
        [Parameter(Mandatory = $true)][object[]]$FirewallContract
    )
    $user = Get-LocalUser -Name $UserName -ErrorAction Stop
    if ($user.SID.Value -cne $ExpectedSid -or $user.Name -cne 'QMDev2' -or $user.Enabled -or
        $user.PasswordRequired -or $user.UserMayChangePassword -or $null -ne $user.LastLogon -or
        $user.Description -cne 'Isolated offline MT5 research lane DEV2') {
        throw 'QMDev2 exact partial-user identity state drifted; refusing resume.'
    }
    $memberships = @(
        Get-LocalGroup -ErrorAction Stop | ForEach-Object {
            Get-LocalGroupMember -Group $_ -ErrorAction SilentlyContinue
        } | Where-Object { $null -ne $_.SID -and $_.SID.Value -eq $ExpectedSid }
    )
    if ($memberships.Count -ne 0) {
        throw 'QMDev2 partial user unexpectedly has group membership; refusing resume.'
    }
    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$ExpectedSid"
    foreach ($unexpectedPath in @(
            $TerminalRoot, $ReportRoot, $CredentialPath, ([System.IO.Path]::GetDirectoryName($CredentialPath)),
            'C:\Users\QMDev2', $profileKey
        )) {
        if (Test-Path -LiteralPath $unexpectedPath) {
            throw "QMDev2 partial-state artifact unexpectedly exists: $unexpectedPath"
        }
    }
    if (@(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV2_*' }).Count -ne 0) {
        throw 'QMDev2 partial state contains a DEV2 task; refusing resume.'
    }
    foreach ($entry in $FirewallContract) {
        if (@(Get-NetFirewallRule -DisplayName ([string]$entry.display_name) -ErrorAction SilentlyContinue).Count -ne 0) {
            throw "QMDev2 partial state contains firewall rule '$($entry.display_name)'; refusing resume."
        }
    }
    $stagePaths = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetDirectoryName($TerminalRoot)) `
            -Directory -Filter '.DEV2.stage.*' -ErrorAction Stop)
    if ($stagePaths.Count -ne 0) {
        throw 'QMDev2 partial state contains a DEV2 staging directory; refusing resume.'
    }
    return $user
}

function Set-QmRestrictedAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetSid,
        [switch]$FileOnly
    )
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleAll($rule)
    }
    $adminSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $systemSid = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
    $targetIdentity = New-Object System.Security.Principal.SecurityIdentifier($TargetSid)
    $acl.SetOwner($adminSid)
    if ($FileOnly) {
        foreach ($sid in @($adminSid, $systemSid)) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $sid,
                [System.Security.AccessControl.FileSystemRights]::FullControl,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            [void]$acl.AddAccessRule($rule)
        }
    } else {
        $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
            [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
        $propagation = [System.Security.AccessControl.PropagationFlags]::None
        foreach ($grant in @(
                @($adminSid, [System.Security.AccessControl.FileSystemRights]::FullControl),
                @($systemSid, [System.Security.AccessControl.FileSystemRights]::FullControl),
                @($targetIdentity, [System.Security.AccessControl.FileSystemRights]::Modify)
            )) {
            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                $grant[0], $grant[1], $inheritance, $propagation,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            [void]$acl.AddAccessRule($rule)
        }
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Assert-QmAclContract {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedWriterSids,
        [switch]$RequireTargetModify,
        [string]$TargetSid
    )
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    if (-not $acl.AreAccessRulesProtected) {
        throw "ACL inheritance is not disabled: $Path"
    }
    $writeRights = [int64](
        [System.Security.AccessControl.FileSystemRights]::Write -bor
        [System.Security.AccessControl.FileSystemRights]::Modify -bor
        [System.Security.AccessControl.FileSystemRights]::FullControl -bor
        [System.Security.AccessControl.FileSystemRights]::Delete -bor
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership
    )
    $targetModifySeen = -not $RequireTargetModify
    foreach ($rule in @($acl.Access)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }
        $sid = Resolve-QmAccountSid -AccountName $rule.IdentityReference.Value
        $mask = [int64]$rule.FileSystemRights
        if (($mask -band $writeRights) -ne 0 -and $sid -notin $AllowedWriterSids) {
            throw "Unexpected write-capable ACL identity on '$Path': $sid"
        }
        if ($RequireTargetModify -and $sid -eq $TargetSid -and
            (($mask -band [int64][System.Security.AccessControl.FileSystemRights]::Modify) -eq
                [int64][System.Security.AccessControl.FileSystemRights]::Modify)) {
            $targetModifySeen = $true
        }
    }
    if (-not $targetModifySeen) {
        throw "Required DEV2 Modify ACL is missing: $Path"
    }
}

function Get-QmProcessesWithinRoot {
    param([Parameter(Mandatory = $true)][string]$Root)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop)) {
        if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) {
            continue
        }
        if (Test-QmPathWithin -Path ([string]$process.ExecutablePath) -Root $Root) {
            $rows.Add($process)
        }
    }
    return $rows.ToArray()
}

function Assert-QmSourceQuiescent {
    param([Parameter(Mandatory = $true)][string]$SourceRoot)
    $running = @(Get-QmProcessesWithinRoot -Root $SourceRoot)
    if ($running.Count -gt 0) {
        throw "DEV1 source is not quiescent; exact-path process count=$($running.Count)."
    }
    $tasks = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV1_SMOKE_*' })
    if ($tasks.Count -gt 0) {
        throw "DEV1 source is not quiescent; DEV1 smoke task count=$($tasks.Count)."
    }
}

function Test-QmIncludedRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][object]$CopyContract
    )
    $relative = $RelativePath.Replace('/', '\').TrimStart('\')
    foreach ($directory in @($CopyContract.excluded_directories)) {
        $candidate = ([string]$directory).Replace('/', '\').Trim('\')
        if ($relative.Equals($candidate, [System.StringComparison]::OrdinalIgnoreCase) -or
            $relative.StartsWith($candidate + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }
    foreach ($file in @($CopyContract.excluded_files)) {
        $candidate = ([string]$file).Replace('/', '\').TrimStart('\')
        if ($relative.Equals($candidate, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }
    if (-not $relative.Contains('\')) {
        foreach ($patternText in @($CopyContract.excluded_root_patterns)) {
            $pattern = New-Object System.Management.Automation.WildcardPattern(
                [string]$patternText,
                [System.Management.Automation.WildcardOptions]::IgnoreCase
            )
            if ($pattern.IsMatch($relative)) {
                return $false
            }
        }
    }
    return $true
}

function Get-QmCopyInventory {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRoot,
        [Parameter(Mandatory = $true)][object]$CopyContract
    )
    $prefixLength = $SourceRoot.TrimEnd('\').Length + 1
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($file in @(Get-ChildItem -LiteralPath $SourceRoot -File -Force -Recurse -ErrorAction Stop)) {
        $relative = $file.FullName.Substring($prefixLength)
        if (-not (Test-QmIncludedRelativePath -RelativePath $relative -CopyContract $CopyContract)) {
            continue
        }
        $rows.Add([pscustomobject]@{
                relative_path = $relative
                source_path = $file.FullName
                source_length = [int64]$file.Length
                source_last_write_utc = $file.LastWriteTimeUtc.ToString('o')
            })
    }
    return @($rows.ToArray() | Sort-Object relative_path)
}

function Copy-QmInventoryToStage {
    param(
        [Parameter(Mandatory = $true)][object[]]$Inventory,
        [Parameter(Mandatory = $true)][string]$StageRoot,
        [Parameter(Mandatory = $true)][string]$SourceRoot
    )
    [void][System.IO.Directory]::CreateDirectory($StageRoot)
    $counter = 0
    foreach ($row in $Inventory) {
        if (($counter % 250) -eq 0) {
            Assert-QmSourceQuiescent -SourceRoot $SourceRoot
        }
        $destination = Join-Path $StageRoot ([string]$row.relative_path)
        $parent = [System.IO.Path]::GetDirectoryName($destination)
        [void][System.IO.Directory]::CreateDirectory($parent)
        if ([System.IO.File]::Exists($destination)) {
            throw "Refusing to overwrite staging file: $destination"
        }
        [System.IO.File]::Copy([string]$row.source_path, $destination, $false)
        $counter++
    }
}

function Test-QmCopiedHashes {
    param(
        [Parameter(Mandatory = $true)][object[]]$Inventory,
        [Parameter(Mandatory = $true)][string]$StageRoot,
        [Parameter(Mandatory = $true)][string]$EvidenceCsv,
        [Parameter(Mandatory = $true)][string]$SourceRoot
    )
    $rows = New-Object System.Collections.Generic.List[object]
    $counter = 0
    foreach ($row in $Inventory) {
        if (($counter % 100) -eq 0) {
            Assert-QmSourceQuiescent -SourceRoot $SourceRoot
        }
        $destination = Join-Path $StageRoot ([string]$row.relative_path)
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw "Copied DEV2 file is missing: $destination"
        }
        $sourceItem = Get-Item -LiteralPath ([string]$row.source_path) -Force -ErrorAction Stop
        $destinationItem = Get-Item -LiteralPath $destination -Force -ErrorAction Stop
        if ([int64]$sourceItem.Length -ne [int64]$row.source_length -or
            $sourceItem.LastWriteTimeUtc.ToString('o') -cne [string]$row.source_last_write_utc) {
            throw "DEV1 source mutated during copy: $($row.relative_path)"
        }
        $sourceHash = (Get-FileHash -LiteralPath $sourceItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        $destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
        $match = (
            [int64]$sourceItem.Length -eq [int64]$destinationItem.Length -and
            $sourceHash -ceq $destinationHash
        )
        $rows.Add([pscustomobject]@{
                relative_path = [string]$row.relative_path
                source_length = [int64]$sourceItem.Length
                destination_length = [int64]$destinationItem.Length
                source_sha256 = $sourceHash
                destination_sha256 = $destinationHash
                match = $match
            })
        if (-not $match) {
            throw "DEV1/DEV2 byte mismatch: $($row.relative_path)"
        }
        $counter++
    }
    $rows.ToArray() | Export-Csv -LiteralPath $EvidenceCsv -NoTypeInformation -Encoding utf8
    return $rows.ToArray()
}

function New-QmRandomPassword {
    $bytes = New-Object byte[] 48
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
    return 'Qm2!aA9-' + [Convert]::ToBase64String($bytes)
}

function Initialize-QmDev2Profile {
    param(
        [Parameter(Mandatory = $true)][string]$Account,
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][string]$ProvisioningDirectory,
        [Parameter(Mandatory = $true)][string]$TaskPrefix
    )
    $nonce = [guid]::NewGuid().ToString('N')
    $receiptPath = Join-Path $ProvisioningDirectory 'qmdev2_profile_gate_redacted.json'
    if (Test-Path -LiteralPath $receiptPath) {
        throw "Refusing to overwrite DEV2 profile receipt: $receiptPath"
    }
    $taskName = "$TaskPrefix$([guid]::NewGuid().ToString('N'))"
    $argument = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -Nonce {1} -ReceiptPath "{2}"' -f `
        $profileInitializerPath, $nonce, $receiptPath
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $argument -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
    $registered = $false
    try {
        Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Settings $settings `
            -User $Account -Password $Password -RunLevel Limited `
            -Description 'Ephemeral isolated DEV2 profile initialization' -ErrorAction Stop | Out-Null
        $registered = $true
        Start-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
        $deadline = (Get-Date).ToUniversalTime().AddMinutes(3)
        do {
            if (Test-Path -LiteralPath $receiptPath -PathType Leaf) {
                break
            }
            Start-Sleep -Milliseconds 500
        } while ((Get-Date).ToUniversalTime() -lt $deadline)
        if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
            $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath '\' -ErrorAction Stop
            throw "DEV2 profile initializer produced no receipt; LastTaskResult=$($info.LastTaskResult)"
        }
        $receipt = Get-Content -LiteralPath $receiptPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ([string]$receipt.status -cne 'PASS' -or [string]$receipt.nonce -cne $nonce) {
            throw 'DEV2 profile initializer returned a stale or invalid receipt.'
        }
        return [pscustomobject]@{
            path = $receiptPath
            sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
            common_path = [string]$receipt.common_path
            calendar_count = @($receipt.calendars).Count
        }
    } finally {
        if ($registered) {
            $cleanupDeadline = (Get-Date).ToUniversalTime().AddSeconds(30)
            while ((Get-Date).ToUniversalTime() -lt $cleanupDeadline) {
                $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
                if ($null -eq $task -or $task.State.ToString() -ne 'Running') { break }
                Start-Sleep -Milliseconds 250
            }
            $task = Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
            if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
                Stop-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction Stop
            }
            Unregister-ScheduledTask -TaskName $taskName -TaskPath '\' -Confirm:$false -ErrorAction Stop
            if ($null -ne (Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue)) {
                throw "Ephemeral DEV2 profile task survived unregister: $taskName"
            }
        }
    }
}

function Assert-QmFirewallProfiles {
    $service = Get-Service -Name MpsSvc -ErrorAction Stop
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        throw 'Windows Firewall service is not running.'
    }
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    if ($profiles.Count -ne 3 -or @($profiles | Where-Object { -not $_.Enabled }).Count -gt 0) {
        throw 'All Domain/Private/Public firewall profiles must be enabled.'
    }
}

function Install-QmFirewallRules {
    param(
        [Parameter(Mandatory = $true)][object[]]$Rules,
        [Parameter(Mandatory = $true)][string]$TerminalRoot
    )
    $result = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Rules) {
        $displayName = [string]$entry.display_name
        $program = Join-Path $TerminalRoot ([string]$entry.relative_program)
        if (@(Get-NetFirewallRule -DisplayName $displayName -ErrorAction SilentlyContinue).Count -gt 0) {
            throw "Refusing to overwrite firewall rule: $displayName"
        }
        New-NetFirewallRule -DisplayName $displayName -Direction Outbound -Action Block -Program $program `
            -Profile Any -Enabled True -ErrorAction Stop | Out-Null
        $rule = Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $displayName -ErrorAction Stop
        $application = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction Stop
        $actualProgram = ConvertTo-QmFullPath -Path ([string]$application.Program)
        if ($rule.Enabled.ToString() -ne 'True' -or $rule.Direction.ToString() -ne 'Outbound' -or
            $rule.Action.ToString() -ne 'Block' -or $rule.Profile.ToString() -ne 'Any' -or
            -not $actualProgram.Equals((ConvertTo-QmFullPath -Path $program), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "DEV2 firewall rule verification failed: $displayName"
        }
        $result.Add([ordered]@{ display_name = $displayName; program = $actualProgram })
    }
    return $result.ToArray()
}

if (-not (Test-Path -LiteralPath $contractPath -PathType Leaf)) {
    throw "DEV2 lane contract is missing: $contractPath"
}
if (-not (Test-Path -LiteralPath $profileInitializerPath -PathType Leaf)) {
    throw "DEV2 profile initializer is missing: $profileInitializerPath"
}
if (-not (Test-Path -LiteralPath $lsaRightsPath -PathType Leaf)) {
    throw "DEV2 LSA-rights helper is missing: $lsaRightsPath"
}
if (-not (Test-Path -LiteralPath $credentialHelperPath -PathType Leaf)) {
    throw "DEV2 machine-credential helper is missing: $credentialHelperPath"
}
. $lsaRightsPath
. $credentialHelperPath
$contract = Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$sourceRoot = ConvertTo-QmFullPath -Path ([string]$contract.paths.source_terminal_root)
$terminalRoot = ConvertTo-QmFullPath -Path ([string]$contract.paths.terminal_root)
$reportRoot = ConvertTo-QmFullPath -Path ([string]$contract.paths.report_root)
$provisioningRoot = ConvertTo-QmFullPath -Path ([string]$contract.paths.provisioning_root)
$credentialPath = ConvertTo-QmFullPath -Path ([string]$contract.identity.credential)
$dev2User = [string]$contract.identity.local_user
$dev2Account = "$env:COMPUTERNAME\$dev2User"
$actualFirewallNames = @($contract.firewall | ForEach-Object { [string]$_.display_name } | Sort-Object)
$expectedFirewallNames = @('QM_DEV2_BLOCK_METAEDITOR_OUT', 'QM_DEV2_BLOCK_METATESTER_OUT', 'QM_DEV2_BLOCK_TERMINAL_OUT') | Sort-Object
$excludedDirectories = @($contract.copy_contract.excluded_directories | ForEach-Object { ([string]$_).Replace('/', '\') } | Sort-Object)
$excludedFiles = @($contract.copy_contract.excluded_files | ForEach-Object { ([string]$_).Replace('/', '\') } | Sort-Object)
$expectedExcludedDirectories = @('logs', 'MQL5\Logs', 'Tester') | Sort-Object
$expectedExcludedFiles = @('Config\agents.dat', 'Config\dnsperf.dat') | Sort-Object
$expectedProgramNames = @('MetaEditor64.exe', 'metatester64.exe', 'terminal64.exe') | Sort-Object
$actualProgramNames = @($contract.program_sha256.PSObject.Properties.Name | Sort-Object)
$expectedSymbols = @('GDAXI.DWX', 'GBPUSD.DWX', 'NDX.DWX', 'EURUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX') | Sort-Object
$actualSymbols = @($contract.allowed_symbols | ForEach-Object { [string]$_ } | Sort-Object)
$expectedHccYears = @(2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025)
$actualHccYears = @($contract.copy_contract.verify_hcc_years | ForEach-Object { [int]$_ } | Sort-Object)
$firewallMapValid = $true
$expectedFirewallPrograms = @{
    QM_DEV2_BLOCK_TERMINAL_OUT = 'terminal64.exe'
    QM_DEV2_BLOCK_METATESTER_OUT = 'metatester64.exe'
    QM_DEV2_BLOCK_METAEDITOR_OUT = 'MetaEditor64.exe'
}
foreach ($entry in @($contract.firewall)) {
    $name = [string]$entry.display_name
    if (-not $expectedFirewallPrograms.ContainsKey($name) -or
        [string]$entry.relative_program -cne [string]$expectedFirewallPrograms[$name]) {
        $firewallMapValid = $false
    }
}
if ([int]$contract.schema_version -ne 3 -or [string]$contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V3' -or
    [string]$contract.lane -cne 'DEV2' -or [string]$contract.source_lane -cne 'DEV1' -or
    $dev2User -cne 'QMDev2' -or [string]$contract.identity.profile -cne 'C:/Users/QMDev2' -or
    [string]$contract.identity.credential_format -cne 'QM_DEV2_MACHINE_DPAPI_CREDENTIAL' -or
    [string]$contract.identity.dpapi_scope -cne 'LocalMachine' -or
    -not [bool]$contract.identity.credential_acl.inheritance_protected -or
    [string]$contract.identity.credential_acl.owner_sid -cne 'S-1-5-32-544' -or
    [bool]$contract.identity.credential_acl.additional_readers -or
    [string]::Join('|', @($contract.identity.credential_acl.exact_full_control_sids | ForEach-Object { [string]$_ } | Sort-Object)) -cne 'S-1-5-18|S-1-5-32-544' -or
    -not $sourceRoot.Equals($fixedSourceRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $terminalRoot.Equals($fixedTerminalRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $reportRoot.Equals($fixedReportRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $provisioningRoot.Equals($fixedProvisioningRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    -not $credentialPath.Equals($fixedCredentialPath, [System.StringComparison]::OrdinalIgnoreCase) -or
    [string]$contract.coordination.provision_mutex -cne 'Global\QM_DEV2_PROVISION' -or
    [string]$contract.coordination.source_quiescence_mutex -cne 'Global\QM_DEV1_SMOKE_CONTROLLER' -or
    [string]$contract.coordination.controller_mutex -cne 'Global\QM_DEV2_SMOKE_CONTROLLER' -or
    [string]$contract.coordination.task_prefix -cne 'QM_DEV2_SMOKE_' -or
    [string]$contract.coordination.profile_task_prefix -cne 'QM_DEV2_PROFILE_INIT_' -or
    -not $firewallMapValid -or
    [string]::Join('|', $actualFirewallNames) -cne [string]::Join('|', $expectedFirewallNames) -or
    [string]::Join('|', $excludedDirectories) -cne [string]::Join('|', $expectedExcludedDirectories) -or
    [string]::Join('|', $excludedFiles) -cne [string]::Join('|', $expectedExcludedFiles) -or
    [string]::Join('|', $actualProgramNames) -cne [string]::Join('|', $expectedProgramNames) -or
    [string]::Join('|', $actualSymbols) -cne [string]::Join('|', $expectedSymbols) -or
    [string]::Join('|', $actualHccYears) -cne [string]::Join('|', $expectedHccYears) -or
    -not [bool]$contract.copy_contract.physical_copy_required -or
    -not [bool]$contract.copy_contract.verify_all_copied_files_sha256 -or
    [string]$contract.copy_contract.documented_exception.relative_path -cne 'Bases/Custom/history/GBPUSD.DWX/2026.hcc' -or
    -not [bool]$contract.copy_contract.documented_exception.copy_current_bytes -or
    [bool]$contract.copy_contract.documented_exception.claim_old_dev1_manifest_hash -or
    [bool]$contract.agent_port_contract.source_agents_dat_copied -or
    -not [bool]$contract.agent_port_contract.require_runtime_listener_proof -or
    -not [bool]$contract.agent_port_contract.require_exact_dev2_metatester_path -or
    -not [bool]$contract.agent_port_contract.require_no_concurrent_overlapping_endpoint_owner -or
    -not [bool]$contract.agent_port_contract.allow_released_baseline_endpoint_reuse) {
    throw 'DEV2 lane contract drifted from the fixed, additive provisioning boundary.'
}
if ($ResumeExactPartialUser.IsPresent -and [string]::IsNullOrWhiteSpace($ExpectedPartialUserSid)) {
    throw '-ResumeExactPartialUser requires -ExpectedPartialUserSid.'
}
if (-not $ResumeExactPartialUser.IsPresent -and -not [string]::IsNullOrWhiteSpace($ExpectedPartialUserSid)) {
    throw '-ExpectedPartialUserSid is valid only with -ResumeExactPartialUser.'
}

if (-not $Apply) {
    $plan = [ordered]@{
        schema_version = 1
        status = 'PLAN_ONLY'
        source_root = $sourceRoot
        source_exists = (Test-Path -LiteralPath $sourceRoot -PathType Container)
        source_process_count = @(Get-QmProcessesWithinRoot -Root $sourceRoot).Count
        source_task_count = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV1_SMOKE_*' }).Count
        target_root = $terminalRoot
        target_exists = (Test-Path -LiteralPath $terminalRoot)
        target_user_exists = ($null -ne (Get-LocalUser -Name $dev2User -ErrorAction SilentlyContinue))
        resume_exact_partial_user = $ResumeExactPartialUser.IsPresent
        expected_partial_user_sid = $ExpectedPartialUserSid
        credential_exists = (Test-Path -LiteralPath $credentialPath)
        report_root = $reportRoot
        controller_mutex = [string]$contract.coordination.controller_mutex
        source_quiescence_mutex = [string]$contract.coordination.source_quiescence_mutex
        task_prefix = [string]$contract.coordination.task_prefix
        port_contract = $contract.agent_port_contract
        mutates_host = $false
    }
    Write-Output ($plan | ConvertTo-Json -Depth 6 -Compress)
    exit 0
}

Assert-QmElevated
$provisionMutex = $null
$sourceMutex = $null
$provisionAcquired = $false
$sourceAcquired = $false
$passwordText = $null
$securePassword = $null
$profileTaskReceipt = $null
$finalReceiptPath = $null
$stageRoot = $null
$dev2Sid = $null
$provisionCompleted = $false
$batchLogonRight = $null
$machineCredential = $null
try {
    $provisionMutex = New-Object System.Threading.Mutex($false, [string]$contract.coordination.provision_mutex)
    $sourceMutex = New-Object System.Threading.Mutex($false, [string]$contract.coordination.source_quiescence_mutex)
    try { $provisionAcquired = $provisionMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $provisionAcquired = $true }
    if (-not $provisionAcquired) { throw 'Another DEV2 provisioner holds the exclusive lock.' }
    try { $sourceAcquired = $sourceMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $sourceAcquired = $true }
    if (-not $sourceAcquired) { throw 'DEV1 controller mutex is busy; source is not explicitly quiescent.' }

    Assert-QmSourceQuiescent -SourceRoot $sourceRoot
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) { throw "DEV1 source is missing: $sourceRoot" }
    Assert-QmNoReparseTree -Root $sourceRoot
    if (Test-Path -LiteralPath $terminalRoot) { throw "DEV2 target unexpectedly exists: $terminalRoot" }
    $existingUser = Get-LocalUser -Name $dev2User -ErrorAction SilentlyContinue
    if ($null -ne $existingUser) {
        if (-not $ResumeExactPartialUser.IsPresent) { throw "DEV2 user unexpectedly exists: $dev2User" }
        $user = Assert-QmExactPartialUserState -UserName $dev2User -ExpectedSid $ExpectedPartialUserSid `
            -TerminalRoot $terminalRoot -ReportRoot $reportRoot -CredentialPath $credentialPath `
            -FirewallContract @($contract.firewall)
    } elseif ($ResumeExactPartialUser.IsPresent) {
        throw 'Exact partial-user resume was requested, but QMDev2 does not exist.'
    }
    if (Test-Path -LiteralPath $credentialPath) { throw "DEV2 credential unexpectedly exists: $credentialPath" }
    if (@(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV2_*' }).Count -gt 0) {
        throw 'A DEV2 scheduled task unexpectedly exists.'
    }
    foreach ($entry in @($contract.firewall)) {
        if (@(Get-NetFirewallRule -DisplayName ([string]$entry.display_name) -ErrorAction SilentlyContinue).Count -gt 0) {
            throw "DEV2 firewall rule unexpectedly exists: $($entry.display_name)"
        }
    }
    Assert-QmFirewallProfiles

    $passwordText = New-QmRandomPassword
    $securePassword = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
    if ($null -ne $existingUser) {
        Set-LocalUser -Name $dev2User -Password $securePassword -AccountNeverExpires `
            -PasswordNeverExpires $true -UserMayChangePassword $false -ErrorAction Stop
    } else {
        $user = New-LocalUser -Name $dev2User -Password $securePassword -Description 'Isolated offline MT5 research lane DEV2' `
            -AccountNeverExpires -PasswordNeverExpires -UserMayNotChangePassword -ErrorAction Stop
        Disable-LocalUser -Name $dev2User -ErrorAction Stop
    }
    Set-QmPasswordRequired -UserName $dev2User
    $user = Get-LocalUser -Name $dev2User -ErrorAction Stop
    if ($user.Enabled -or -not $user.PasswordRequired) { throw 'QMDev2 must remain disabled and password-required during provisioning.' }
    $dev2Sid = $user.SID.Value
    if ($ResumeExactPartialUser.IsPresent -and $dev2Sid -cne $ExpectedPartialUserSid) {
        throw 'QMDev2 SID changed during exact partial-user resume.'
    }
    $administrators = Get-LocalGroup -SID (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544'))
    if (@(Get-LocalGroupMember -Group $administrators -ErrorAction Stop | Where-Object { $_.SID.Value -eq $dev2Sid }).Count -gt 0) {
        throw 'QMDev2 unexpectedly belongs to BUILTIN\Administrators.'
    }

    $machineCredential = New-QmDev2MachineCredentialArtifact -CredentialPath $credentialPath `
        -Password $passwordText -ExpectedAccount $dev2Account -ExpectedSid $dev2Sid `
        -ContractId ([string]$contract.contract_id) -Lane ([string]$contract.lane)
    $adminSid = 'S-1-5-32-544'
    $systemSid = 'S-1-5-18'
    Assert-QmDev2CredentialExactAcl -Path ([System.IO.Path]::GetDirectoryName($credentialPath)) -Directory
    Assert-QmDev2CredentialExactAcl -Path $credentialPath

    [void][System.IO.Directory]::CreateDirectory($reportRoot)
    Set-QmRestrictedAcl -Path $reportRoot -TargetSid $dev2Sid
    Assert-QmAclContract -Path $reportRoot -AllowedWriterSids @($adminSid, $systemSid, $dev2Sid) `
        -RequireTargetModify -TargetSid $dev2Sid
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $provisioningDirectory = Join-Path $provisioningRoot $stamp
    [void][System.IO.Directory]::CreateDirectory($provisioningDirectory)

    $stageRoot = Join-Path ([System.IO.Path]::GetDirectoryName($terminalRoot)) ('.DEV2.stage.' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $stageRoot) { throw "DEV2 staging root unexpectedly exists: $stageRoot" }
    $inventory = @(Get-QmCopyInventory -SourceRoot $sourceRoot -CopyContract $contract.copy_contract)
    if ($inventory.Count -lt 100) { throw "DEV2 copy inventory is implausibly small: $($inventory.Count) files" }
    $copyBytes = [int64](($inventory | Measure-Object source_length -Sum).Sum)
    if ([int64](Get-PSDrive -Name ([System.IO.Path]::GetPathRoot($terminalRoot).Substring(0, 1))).Free -lt ($copyBytes + 2GB)) {
        throw "Insufficient free space for DEV2 physical copy: bytes=$copyBytes"
    }
    Copy-QmInventoryToStage -Inventory $inventory -StageRoot $stageRoot -SourceRoot $sourceRoot
    $hashCsv = Join-Path $provisioningDirectory 'source_destination_sha256.csv'
    $hashRows = @(Test-QmCopiedHashes -Inventory $inventory -StageRoot $stageRoot -EvidenceCsv $hashCsv -SourceRoot $sourceRoot)
    if (@($hashRows | Where-Object { -not $_.match }).Count -gt 0) { throw 'DEV2 copy hash verification failed.' }

    $programRows = New-Object System.Collections.Generic.List[object]
    foreach ($property in @($contract.program_sha256.PSObject.Properties)) {
        $name = [string]$property.Name
        $expected = ([string]$property.Value).ToLowerInvariant()
        $row = $hashRows | Where-Object { $_.relative_path -ceq $name } | Select-Object -First 1
        if ($null -eq $row -or [string]$row.destination_sha256 -cne $expected) {
            throw "DEV2 program hash differs from contract: $name"
        }
        $programRows.Add([ordered]@{ name = $name; sha256 = $expected })
    }

    $hccYears = @($contract.copy_contract.verify_hcc_years | ForEach-Object { [int]$_ })
    $hccRows = @($hashRows | Where-Object {
            $_.relative_path -match '^Bases\\Custom\\history\\[^\\]+\\(?<year>[0-9]{4})\.hcc$' -and
            [int]$Matches.year -in $hccYears
        })
    $tkcRows = @($hashRows | Where-Object { $_.relative_path -match '^Bases\\Custom\\ticks\\[^\\]+\\.+\.tkc$' })
    $includeRows = @($hashRows | Where-Object { $_.relative_path -like 'MQL5\Include\*' })
    $groupRows = @($hashRows | Where-Object { $_.relative_path -like 'MQL5\Profiles\Tester\Groups\*' })
    if ($hccRows.Count -eq 0 -or $tkcRows.Count -eq 0 -or $includeRows.Count -eq 0 -or $groupRows.Count -eq 0) {
        throw "Required DEV2 verification category is empty: hcc=$($hccRows.Count) tkc=$($tkcRows.Count) include=$($includeRows.Count) groups=$($groupRows.Count)"
    }
    $exceptionRelative = ([string]$contract.copy_contract.documented_exception.relative_path).Replace('/', '\')
    $exceptionRow = $hashRows | Where-Object { $_.relative_path -ceq $exceptionRelative } | Select-Object -First 1
    if ($null -eq $exceptionRow -or -not [bool]$exceptionRow.match) {
        throw "Documented 2026 exception was not copied byte-equal: $exceptionRelative"
    }

    Assert-QmSourceQuiescent -SourceRoot $sourceRoot
    if (Test-Path -LiteralPath $terminalRoot) { throw "DEV2 target appeared before atomic publish: $terminalRoot" }
    $mt5Parent = ConvertTo-QmFullPath -Path ([System.IO.Path]::GetDirectoryName($terminalRoot))
    if (-not (Test-QmPathWithin -Path $stageRoot -Root $mt5Parent) -or
        -not (Test-QmPathWithin -Path $terminalRoot -Root $mt5Parent)) {
        throw 'DEV2 staging/publish path escaped D:\QM\mt5.'
    }
    Move-Item -LiteralPath $stageRoot -Destination $terminalRoot -ErrorAction Stop
    $stageRoot = $null
    foreach ($directory in @('Tester', 'logs', 'MQL5\Logs')) {
        [void][System.IO.Directory]::CreateDirectory((Join-Path $terminalRoot $directory))
    }
    if (Test-Path -LiteralPath (Join-Path $terminalRoot 'Config\agents.dat')) {
        throw 'DEV2 copied DEV1 agents.dat; independent dynamic port allocation is not established.'
    }
    Set-QmRestrictedAcl -Path $terminalRoot -TargetSid $dev2Sid
    Assert-QmAclContract -Path $terminalRoot -AllowedWriterSids @($adminSid, $systemSid, $dev2Sid) `
        -RequireTargetModify -TargetSid $dev2Sid
    Assert-QmNoReparseTree -Root $terminalRoot

    $firewallRows = @(Install-QmFirewallRules -Rules @($contract.firewall) -TerminalRoot $terminalRoot)
    $batchLogonRight = Grant-QmDev2BatchLogonRight -Sid $dev2Sid
    Enable-LocalUser -Name $dev2User -ErrorAction Stop
    $enabledUser = Get-LocalUser -Name $dev2User -ErrorAction Stop
    if ($enabledUser.SID.Value -cne $dev2Sid -or -not $enabledUser.Enabled -or -not $enabledUser.PasswordRequired) {
        throw 'QMDev2 final enable/password contract verification failed.'
    }
    $profileTaskReceipt = Initialize-QmDev2Profile -Account $dev2Account -Password $passwordText `
        -ProvisioningDirectory $provisioningDirectory -TaskPrefix ([string]$contract.coordination.profile_task_prefix)
    foreach ($evidencePath in @($hashCsv, [string]$profileTaskReceipt.path)) {
        Set-QmRestrictedAcl -Path $evidencePath -TargetSid $dev2Sid -FileOnly
        Assert-QmAclContract -Path $evidencePath -AllowedWriterSids @($adminSid, $systemSid)
    }
    Set-QmRestrictedAcl -Path $provisioningDirectory -TargetSid $dev2Sid -FileOnly
    Assert-QmAclContract -Path $provisioningDirectory -AllowedWriterSids @($adminSid, $systemSid)
    $passwordText = $null
    $securePassword.Dispose()
    $securePassword = $null

    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$dev2Sid"
    $profilePath = ConvertTo-QmFullPath -Path ([System.Environment]::ExpandEnvironmentVariables(
            (Get-ItemProperty -LiteralPath $profileKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
        ))
    if (-not $profilePath.Equals((ConvertTo-QmFullPath -Path ([string]$contract.identity.profile)), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "QMDev2 profile path differs from contract: $profilePath"
    }
    $credentialHash = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $receipt = [ordered]@{
        schema_version = 1
        contract_id = [string]$contract.contract_id
        status = 'PASS'
        completed_utc = (Get-Date).ToUniversalTime().ToString('o')
        contract_path = $contractPath
        contract_sha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256).Hash.ToLowerInvariant()
        source_root = $sourceRoot
        terminal_root = $terminalRoot
        report_root = $reportRoot
        source_quiescence = [ordered]@{
            mutex = [string]$contract.coordination.source_quiescence_mutex
            mutex_held_for_copy = $sourceAcquired
            final_source_process_count = @(Get-QmProcessesWithinRoot -Root $sourceRoot).Count
            final_source_task_count = @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -like 'QM_DEV1_SMOKE_*' }).Count
        }
        identity = [ordered]@{
            account = $dev2Account
            sid = $dev2Sid
            profile = $profilePath
            limited_non_admin = $true
            credential_path = $credentialPath
            credential_sha256 = $credentialHash
            credential_format = [string]$contract.identity.credential_format
            dpapi_scope = [string]$contract.identity.dpapi_scope
            credential_generation_id = $machineCredential.GenerationId
            credential_helper_path = $credentialHelperPath
            credential_helper_sha256 = (Get-FileHash -LiteralPath $credentialHelperPath -Algorithm SHA256).Hash.ToLowerInvariant()
            profile_receipt_path = $profileTaskReceipt.path
            profile_receipt_sha256 = $profileTaskReceipt.sha256
            common_path = $profileTaskReceipt.common_path
            calendar_count = $profileTaskReceipt.calendar_count
        }
        coordination = $contract.coordination
        batch_logon_right = $batchLogonRight
        agent_port_contract = $contract.agent_port_contract
        source_agents_dat_copied = $false
        firewall = $firewallRows
        program_sha256 = $programRows.ToArray()
        copy = [ordered]@{
            file_count = $hashRows.Count
            bytes = $copyBytes
            all_files_byte_equal = $true
            hash_csv = $hashCsv
            hash_csv_sha256 = (Get-FileHash -LiteralPath $hashCsv -Algorithm SHA256).Hash.ToLowerInvariant()
            hcc_2017_2025_verified_count = $hccRows.Count
            custom_tkc_verified_count = $tkcRows.Count
            include_verified_count = $includeRows.Count
            tester_group_verified_count = $groupRows.Count
            exclusions = $contract.copy_contract
            documented_2026_exception = [ordered]@{
                relative_path = $exceptionRelative
                copied_byte_equal = $true
                current_source_and_destination_sha256 = [string]$exceptionRow.destination_sha256
                old_dev1_manifest_hash_claimed = $false
                reason = [string]$contract.copy_contract.documented_exception.reason
            }
        }
        smoke_proof = [ordered]@{
            status = 'PENDING'
            requirement = 'Run isolated DEV2 smoke and record exact DEV2 metatester listener port with no pre-existing owner.'
        }
    }
    $finalReceiptPath = Join-Path $provisioningDirectory 'dev2_provisioning_receipt.json'
    if (Test-Path -LiteralPath $finalReceiptPath) { throw "Refusing to overwrite DEV2 receipt: $finalReceiptPath" }
    [System.IO.File]::WriteAllText(
        $finalReceiptPath,
        ($receipt | ConvertTo-Json -Depth 10),
        (New-Object System.Text.UTF8Encoding($false))
    )
    Set-QmRestrictedAcl -Path $finalReceiptPath -TargetSid $dev2Sid -FileOnly
    Assert-QmAclContract -Path $finalReceiptPath -AllowedWriterSids @($adminSid, $systemSid)
    $provisionCompleted = $true
    Write-Output ([ordered]@{
            status = 'PASS'
            receipt = $finalReceiptPath
            receipt_sha256 = (Get-FileHash -LiteralPath $finalReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
            terminal_root = $terminalRoot
            report_root = $reportRoot
            file_count = $hashRows.Count
            copied_bytes = $copyBytes
            smoke_status = 'PENDING'
        } | ConvertTo-Json -Compress)
} finally {
    $passwordText = $null
    if ($null -ne $securePassword) {
        try { $securePassword.Dispose() } catch { }
    }
    if (-not $provisionCompleted -and -not [string]::IsNullOrWhiteSpace([string]$dev2Sid)) {
        try {
            $failedUser = Get-LocalUser -Name $dev2User -ErrorAction Stop
            if ($failedUser.SID.Value -eq $dev2Sid) { Disable-LocalUser -Name $dev2User -ErrorAction Stop }
        } catch {
            Write-Warning "Failed to disable exact QMDev2 identity after provisioning failure: $($_.Exception.Message)"
        }
    }
    if ($sourceAcquired -and $null -ne $sourceMutex) { try { $sourceMutex.ReleaseMutex() } catch { } }
    if ($provisionAcquired -and $null -ne $provisionMutex) { try { $provisionMutex.ReleaseMutex() } catch { } }
    if ($null -ne $sourceMutex) { $sourceMutex.Dispose() }
    if ($null -ne $provisionMutex) { $provisionMutex.Dispose() }
    if ($null -ne $stageRoot) {
        Write-Warning "DEV2 provisioning left a non-published staging path for forensic recovery: $stageRoot"
    }
}
