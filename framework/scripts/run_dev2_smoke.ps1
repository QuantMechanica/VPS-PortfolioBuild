[CmdletBinding()]
param(
    [int]$EAId = 0,
    [ValidatePattern('^(?:QM5_)?[0-9][A-Za-z0-9_.-]*$')]
    [string]$EALabel,
    [Parameter(Mandatory = $true)]
    [ValidateSet('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX')]
    [string]$Symbol,
    [Parameter(Mandatory = $true)]
    [ValidateRange(2000, 2100)]
    [int]$Year,
    [ValidatePattern('^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$')]
    [string]$FromDate,
    [ValidatePattern('^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$')]
    [string]$ToDate,
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^QM\\[A-Za-z0-9_.-]+$')]
    [string]$Expert,
    [ValidatePattern('^[A-Z][A-Z0-9]{0,4}$')]
    [string]$Period = 'H1',
    [ValidateRange(1, 10)]
    [int]$Runs = 2,
    [ValidateRange(0, 1000000)]
    [int]$MinTrades = 5,
    [ValidateSet(4)]
    [int]$Model = 4,
    [ValidateRange(60, 28800)]
    [int]$TimeoutSeconds = 1800,
    [string]$SetFile,
    [switch]$AllowMissingRealTicksLogMarker,
    [ValidateRange(0, 1000)]
    [double]$CommissionPerLot = 0,
    [ValidateRange(0, 1000)]
    [double]$CommissionPerSideNative = 0,
    [ValidatePattern('^[A-Z]{3}$')]
    [string]$TesterCurrencyOverride,
    [ValidateRange(0, 2147483647)]
    [int]$TesterDepositOverride = 0,
    [switch]$SmokeMode,
    [ValidateRange(0, 172800)]
    [int]$ControllerTimeoutSeconds = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Dev2Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$script:Dev2ReportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$script:CredentialPath = 'C:\ProgramData\QM\DEV2\credential.clixml'
$script:Dev2UserName = 'QMDev2'
$script:TaskPath = '\'
$script:PwshPath = 'C:\Program Files\PowerShell\7\pwsh.exe'
$script:LaneContractPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\registry\dev2_lane_contract.json'))
$script:ControllerMutexName = 'Global\QM_DEV2_SMOKE_CONTROLLER'
$script:TaskNamePrefix = 'QM_DEV2_SMOKE_'
$script:CleanupTaskNamePrefix = 'QM_DEV2_CLEANUP_'
$script:CleanupHelperSourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'cleanup_dev2_account_lease.ps1'))
$script:CleanupLeaseGraceSeconds = 900
$script:PerAttemptOverheadSeconds = 600
$script:ControllerFinalizationMarginSeconds = 600
$script:TesterGroupsCanonicalPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\registry\tester_groups\Darwinex-Live_real.canonical.txt'))
$script:TesterGroupsDev2Path = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt')
$script:AllowedSymbols = @('NDX.DWX', 'GDAXI.DWX', 'EURUSD.DWX', 'GBPUSD.DWX', 'USDJPY.DWX', 'XAUUSD.DWX')
$script:FirewallPrograms = [ordered]@{
    'QM_DEV2_BLOCK_TERMINAL_OUT'   = 'D:\QM\mt5\DEV2\terminal64.exe'
    'QM_DEV2_BLOCK_METATESTER_OUT' = 'D:\QM\mt5\DEV2\metatester64.exe'
    'QM_DEV2_BLOCK_METAEDITOR_OUT' = 'D:\QM\mt5\DEV2\MetaEditor64.exe'
}

function Get-QmLaneContract {
    if (-not (Test-Path -LiteralPath $script:LaneContractPath -PathType Leaf)) {
        throw "DEV2 lane contract is missing: $($script:LaneContractPath)"
    }
    Assert-QmNoReparseComponents -Path $script:LaneContractPath
    $contract = Get-Content -LiteralPath $script:LaneContractPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $expectedSymbols = @($script:AllowedSymbols | Sort-Object)
    $actualSymbols = @($contract.allowed_symbols | ForEach-Object { [string]$_ } | Sort-Object)
    if ([int]$contract.schema_version -ne 2 -or [string]$contract.contract_id -cne 'QM_DEV2_ISOLATED_MT5_LANE_V2' -or
        [string]$contract.lane -cne 'DEV2' -or [string]$contract.source_lane -cne 'DEV1' -or
        [string]$contract.identity.local_user -cne $script:Dev2UserName -or
        -not (ConvertTo-QmFullPath -Path ([string]$contract.paths.terminal_root)).Equals($script:Dev2Root, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not (ConvertTo-QmFullPath -Path ([string]$contract.paths.report_root)).Equals($script:Dev2ReportsRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$contract.coordination.controller_mutex -cne $script:ControllerMutexName -or
        [string]$contract.coordination.task_prefix -cne $script:TaskNamePrefix -or
        [string]::Join('|', $actualSymbols) -cne [string]::Join('|', $expectedSymbols)) {
        throw 'DEV2 lane contract drifted from the fixed controller isolation contract.'
    }
    $port = $contract.agent_port_contract
    if ([bool]$port.source_agents_dat_copied -or -not [bool]$port.require_runtime_listener_proof -or
        -not [bool]$port.require_exact_dev2_metatester_path -or
        -not [bool]$port.require_no_concurrent_overlapping_endpoint_owner -or
        -not [bool]$port.allow_released_baseline_endpoint_reuse -or
        [int]$port.minimum_port -lt 1 -or [int]$port.maximum_port -gt 65535 -or
        [int]$port.minimum_port -gt [int]$port.maximum_port) {
        throw 'DEV2 lane contract has an unsafe agent-port policy.'
    }
    return $contract
}

function Get-QmProgramHashes {
    param([Parameter(Mandatory = $true)][object]$Contract)
    $expectedNames = @('MetaEditor64.exe', 'metatester64.exe', 'terminal64.exe')
    $actualNames = @($Contract.program_sha256.PSObject.Properties.Name | Sort-Object)
    if ([string]::Join('|', $actualNames) -cne [string]::Join('|', @($expectedNames | Sort-Object))) {
        throw 'DEV2 lane contract must bind exactly terminal64.exe, metatester64.exe, and MetaEditor64.exe.'
    }
    $hashes = [ordered]@{}
    foreach ($name in $expectedNames) {
        $expected = ([string]$Contract.program_sha256.$name).ToLowerInvariant()
        if ($expected -notmatch '^[0-9a-f]{64}$') {
            throw "Invalid DEV2 program SHA-256 in lane contract: $name"
        }
        $path = Join-Path $script:Dev2Root $name
        Assert-QmNoReparseComponents -Path $path
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($actual -cne $expected) {
            throw "DEV2 program hash mismatch for $name; expected=$expected actual=$actual"
        }
        $hashes[$name] = $actual
    }
    return $hashes
}

function ConvertTo-QmFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($Path.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'Paths may not contain CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Get-QmMinimumDev2ControllerTimeoutSeconds {
    param(
        [Parameter(Mandatory = $true)][ValidateRange(1, 10)][int]$MaximumRunAttempts,
        [Parameter(Mandatory = $true)][ValidateRange(60, 28800)][int]$RunTimeoutSeconds
    )
    return ($MaximumRunAttempts * ($RunTimeoutSeconds + $script:PerAttemptOverheadSeconds)) +
        $script:ControllerFinalizationMarginSeconds
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
            throw "Reparse points are forbidden in DEV2 isolation paths: $cursor"
        }
    }
}

function Assert-QmPhysicalDev2Tree {
    $requiredFiles = @(
        (Join-Path $script:Dev2Root 'terminal64.exe'),
        (Join-Path $script:Dev2Root 'metatester64.exe'),
        (Join-Path $script:Dev2Root 'MetaEditor64.exe'),
        (Join-Path $script:Dev2Root 'Bases\symbols.custom.dat')
    )
    $basesRoot = Join-Path $script:Dev2Root 'Bases'
    Assert-QmNoReparseComponents -Path $script:Dev2Root
    Assert-QmNoReparseComponents -Path $basesRoot
    foreach ($path in $requiredFiles) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required DEV2 file is missing: $path"
        }
        Assert-QmNoReparseComponents -Path $path
    }

    $unexpectedLink = Get-ChildItem -LiteralPath $basesRoot -Force -Recurse -ErrorAction Stop |
        Where-Object {
            (($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) -or
            ($_.PSObject.Properties.Name -contains 'LinkType' -and $_.LinkType -eq 'HardLink')
        } | Select-Object -First 1
    if ($unexpectedLink) {
        throw "DEV2 Bases must be an independent physical copy; link found: $($unexpectedLink.FullName)"
    }

    foreach ($kind in @('history', 'ticks')) {
        $kindRoot = Join-Path $basesRoot "Custom\$kind"
        if (-not (Test-Path -LiteralPath $kindRoot -PathType Container)) {
            throw "Missing DEV2 custom-symbol $kind root: $kindRoot"
        }
        $actual = @(Get-ChildItem -LiteralPath $kindRoot -Directory -Force -ErrorAction Stop |
            ForEach-Object { $_.Name } | Sort-Object)
        $expected = @($script:AllowedSymbols | Sort-Object)
        if ([string]::Join('|', $actual) -cne [string]::Join('|', $expected)) {
            throw "DEV2 Custom/$kind symbol directories drifted. Expected=$([string]::Join(',', $expected)); actual=$([string]::Join(',', $actual))"
        }
    }
}

function Resolve-QmAccountSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    $normalized = $AccountName
    if ($normalized.StartsWith('.\', [System.StringComparison]::Ordinal)) {
        $normalized = "$env:COMPUTERNAME\$($normalized.Substring(2))"
    }
    $account = New-Object System.Security.Principal.NTAccount($normalized)
    return $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
}

function Get-QmWriteRightsMask {
    $rights = [System.Security.AccessControl.FileSystemRights]
    return [int64](
        $rights::Write -bor $rights::Modify -bor $rights::FullControl -bor
        $rights::Delete -bor $rights::DeleteSubdirectoriesAndFiles -bor
        $rights::ChangePermissions -bor $rights::TakeOwnership
    )
}

function Assert-QmHardenedAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$AllowedWriterSids,
        [switch]$RequireProtected,
        [string]$RequiredModifySid
    )
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    if ($RequireProtected -and -not $acl.AreAccessRulesProtected) {
        throw "ACL inheritance must be disabled on isolation root: $Path"
    }
    $ownerSid = Resolve-QmAccountSid -AccountName $acl.Owner
    if ($AllowedWriterSids -notcontains $ownerSid) {
        throw "Untrusted owner on isolation path '$Path': $ownerSid"
    }
    $writeMask = Get-QmWriteRightsMask
    $requiredModifySeen = [string]::IsNullOrWhiteSpace($RequiredModifySid)
    foreach ($rule in @($acl.Access)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow) {
            continue
        }
        $sid = Resolve-QmAccountSid -AccountName $rule.IdentityReference.Value
        $ruleMask = [int64]$rule.FileSystemRights
        if (($ruleMask -band $writeMask) -ne 0 -and $AllowedWriterSids -notcontains $sid) {
            throw "Untrusted write-capable ACL entry on '$Path': $sid ($($rule.FileSystemRights))"
        }
        if ($sid -eq $RequiredModifySid -and
            (($ruleMask -band [int64][System.Security.AccessControl.FileSystemRights]::Modify) -eq [int64][System.Security.AccessControl.FileSystemRights]::Modify)) {
            $requiredModifySeen = $true
        }
    }
    if (-not $requiredModifySeen) {
        throw "Required QMDev2 Modify ACL is missing on: $Path"
    }
}

function Get-QmDev2IdentityContract {
    $localUser = Get-LocalUser -Name $script:Dev2UserName -ErrorAction Stop
    if ($localUser.Name -cne $script:Dev2UserName -or -not $localUser.PasswordRequired) {
        throw 'The local QMDev2 account must have PasswordRequired=True.'
    }
    $targetSid = $localUser.SID.Value
    $targetAccount = "$env:COMPUTERNAME\$($script:Dev2UserName)"

    $administratorsGroup = Get-LocalGroup -SID (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')) -ErrorAction Stop
    $administratorMembers = @(Get-LocalGroupMember -Group $administratorsGroup -ErrorAction Stop)
    if (@($administratorMembers | Where-Object { $_.SID.Value -eq $targetSid }).Count -gt 0) {
        throw 'The isolated QMDev2 account must not be a member of BUILTIN\Administrators.'
    }

    $adminSid = 'S-1-5-32-544'
    $systemSid = 'S-1-5-18'
    $allowedRootWriters = @($adminSid, $systemSid, $targetSid)
    Assert-QmHardenedAcl -Path $script:Dev2Root -AllowedWriterSids $allowedRootWriters -RequireProtected -RequiredModifySid $targetSid
    Assert-QmHardenedAcl -Path $script:Dev2ReportsRoot -AllowedWriterSids $allowedRootWriters -RequireProtected -RequiredModifySid $targetSid
    Assert-QmHardenedAcl -Path $script:CredentialPath -AllowedWriterSids @($adminSid, $systemSid)

    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$targetSid"
    $profile = (Get-ItemProperty -LiteralPath $profileKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
    $profile = ConvertTo-QmFullPath -Path ([System.Environment]::ExpandEnvironmentVariables($profile))
    $commonPath = ConvertTo-QmFullPath -Path (Join-Path $profile 'AppData\Roaming\MetaQuotes\Terminal\Common')
    Assert-QmNoReparseComponents -Path $profile
    Assert-QmNoReparseComponents -Path $commonPath
    if (-not (Test-QmPathWithin -Path $commonPath -Root $profile)) {
        throw "QMDev2 Common path escaped its profile: $commonPath"
    }
    $currentAppData = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::ApplicationData)
    $currentCommon = ConvertTo-QmFullPath -Path (Join-Path $currentAppData 'MetaQuotes\Terminal\Common')
    $administratorCommon = ConvertTo-QmFullPath -Path 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common'
    if ($commonPath.Equals($currentCommon, [System.StringComparison]::OrdinalIgnoreCase) -or
        $commonPath.Equals($administratorCommon, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "QMDev2 Common path is not isolated: $commonPath"
    }

    return [pscustomobject]@{
        Account = $targetAccount
        Sid = $targetSid
        Profile = $profile
        CommonPath = $commonPath
    }
}

function Get-QmDev2ControllerAccountState {
    $localUser = Get-LocalUser -Name $script:Dev2UserName -ErrorAction Stop
    if ($localUser.Name -cne $script:Dev2UserName -or $localUser.Enabled) {
        throw 'QMDev2 must be disabled at controller entry so this controller owns the full enable/restore lifecycle.'
    }
    if (-not $localUser.PasswordRequired) {
        throw 'The local QMDev2 account must have PasswordRequired=True before controller enable.'
    }
    return [pscustomobject]@{
        Sid = $localUser.SID.Value
        InitiallyEnabled = $false
    }
}

function Enable-QmDev2ControllerAccountState {
    param([Parameter(Mandatory = $true)]$State)
    $sid = New-Object System.Security.Principal.SecurityIdentifier([string]$State.Sid)
    try {
        $current = Get-LocalUser -SID $sid -ErrorAction Stop
        if ($current.Name -cne $script:Dev2UserName -or $current.SID.Value -cne [string]$State.Sid -or $current.Enabled -or -not $current.PasswordRequired) {
            throw 'QMDev2 just-in-time enable precondition drifted.'
        }
        Enable-LocalUser -SID $sid -ErrorAction Stop
        $enabled = Get-LocalUser -SID $sid -ErrorAction Stop
        if ($enabled.Name -cne $script:Dev2UserName -or $enabled.SID.Value -cne [string]$State.Sid -or -not $enabled.Enabled -or -not $enabled.PasswordRequired) {
            throw 'QMDev2 temporary controller enable contract failed.'
        }
        return $true
    } catch {
        $enableError = $_
        try {
            $rollback = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($rollback.Name -cne $script:Dev2UserName -or $rollback.SID.Value -cne [string]$State.Sid) {
                throw 'SID drift prevents enable-failure rollback.'
            }
            if ($rollback.Enabled) {
                Disable-LocalUser -SID $sid -ErrorAction Stop
            }
            $verified = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($verified.Name -cne $script:Dev2UserName -or $verified.SID.Value -cne [string]$State.Sid -or $verified.Enabled -or -not $verified.PasswordRequired) {
                throw 'Enable-failure rollback did not restore disabled-at-rest state.'
            }
        } catch {
            throw "QMDev2 enable failed and rollback also failed. enable=$($enableError.Exception.Message); rollback=$($_.Exception.Message)"
        }
        throw $enableError
    }
}

function Restore-QmDev2ControllerAccountState {
    param([Parameter(Mandatory = $true)]$State)
    $sid = New-Object System.Security.Principal.SecurityIdentifier([string]$State.Sid)
    $current = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($current.Name -cne $script:Dev2UserName -or $current.SID.Value -cne [string]$State.Sid) {
        throw 'Refusing to restore QMDev2 account state after SID drift.'
    }
    if ($current.Enabled) {
        Disable-LocalUser -SID $sid -ErrorAction Stop
    }
    $restored = Get-LocalUser -SID $sid -ErrorAction Stop
    if ($restored.Name -cne $script:Dev2UserName -or $restored.SID.Value -cne [string]$State.Sid -or $restored.Enabled -or -not $restored.PasswordRequired) {
        throw 'QMDev2 disabled-at-rest restore contract failed.'
    }
    return $true
}

function Assert-QmNoDev2Tasks {
    $stale = @(Get-ScheduledTask -TaskPath $script:TaskPath -ErrorAction Stop | Where-Object {
        $_.TaskName.StartsWith($script:CleanupTaskNamePrefix, [System.StringComparison]::Ordinal) -or
        $_.TaskName.StartsWith($script:TaskNamePrefix, [System.StringComparison]::Ordinal)
    })
    if ($stale.Count -ne 0) {
        throw "DEV2 task preflight found $($stale.Count) stale smoke/cleanup task(s); refusing to enable the isolated account."
    }
}

function Assert-QmElevatedController {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'run_dev2_smoke.ps1 requires an elevated Administrator token.'
    }
}

function Assert-QmFirewallIsolation {
    $service = Get-Service -Name MpsSvc -ErrorAction Stop
    if ($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
        throw 'Windows Firewall service (MpsSvc) is not running.'
    }
    $profiles = @(Get-NetFirewallProfile -PolicyStore ActiveStore -ErrorAction Stop)
    $profileNames = @($profiles | ForEach-Object { [string]$_.Name } | Sort-Object)
    if ([string]::Join('|', $profileNames) -cne 'Domain|Private|Public') {
        throw "Expected Domain/Private/Public firewall profiles in ActiveStore; found $([string]::Join(',', $profileNames))."
    }
    foreach ($profile in $profiles) {
        if (-not $profile.Enabled) {
            throw "Windows Firewall profile '$($profile.Name)' is disabled."
        }
    }
    foreach ($entry in $script:FirewallPrograms.GetEnumerator()) {
        $rules = @(Get-NetFirewallRule -PolicyStore ActiveStore -DisplayName $entry.Key -ErrorAction Stop)
        if ($rules.Count -ne 1) {
            throw "Expected exactly one active firewall rule '$($entry.Key)'; found $($rules.Count)."
        }
        $rule = $rules[0]
        if ($rule.Enabled.ToString() -ne 'True' -or $rule.Direction.ToString() -ne 'Outbound' -or
            $rule.Action.ToString() -ne 'Block' -or $rule.Profile.ToString() -ne 'Any') {
            throw "Firewall rule '$($entry.Key)' must be Enabled/Outbound/Block/Profile Any."
        }
        $filters = @(Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $rule -ErrorAction Stop)
        if ($filters.Count -ne 1) {
            throw "Firewall rule '$($entry.Key)' must have exactly one application filter."
        }
        $actualProgram = ConvertTo-QmFullPath -Path $filters[0].Program
        $expectedProgram = ConvertTo-QmFullPath -Path $entry.Value
        if (-not $actualProgram.Equals($expectedProgram, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Firewall rule '$($entry.Key)' targets '$actualProgram', expected '$expectedProgram'."
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
    param([Parameter(Mandatory = $true)][string]$ExpectedOwnerSid)
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        $ownerSid = Get-QmProcessOwnerSid -ProcessRecord $process
        if ($ownerSid -ceq $ExpectedOwnerSid) {
            $records.Add([pscustomobject]@{
                ProcessId = [int]$process.ProcessId
                ExecutablePath = if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) { $null } else { ConvertTo-QmFullPath -Path ([string]$process.ExecutablePath) }
                CreationDate = $process.CreationDate
                OwnerSid = $ownerSid
            })
        }
    }
    return $records.ToArray()
}

function Assert-QmNoDev2Processes {
    param([Parameter(Mandatory = $true)][string]$Stage)
    $running = @(Get-QmDev2Processes)
    if ($running.Count -gt 0) {
        $summary = [string]::Join(', ', @($running | ForEach-Object { "pid=$($_.ProcessId) path=$($_.ExecutablePath)" }))
        throw "DEV2 must be idle at $Stage; found $summary"
    }
}

function Assert-QmNoDev2IdentityProcesses {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedOwnerSid,
        [Parameter(Mandatory = $true)][string]$Stage
    )
    $running = @(Get-QmDev2IdentityProcesses -ExpectedOwnerSid $ExpectedOwnerSid)
    if ($running.Count -gt 0) {
        throw "The dedicated QMDev2 identity must be idle at $Stage; found $($running.Count) process(es)."
    }
}

function Stop-QmDev2ProcessesExact {
    param([Parameter(Mandatory = $true)][string]$ExpectedOwnerSid)
    $initial = @(Get-QmDev2IdentityProcesses -ExpectedOwnerSid $ExpectedOwnerSid)
    foreach ($candidate in $initial) {
        $fresh = @(Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($candidate.ProcessId)" -Property ProcessId,ExecutablePath,CreationDate -ErrorAction SilentlyContinue)
        if ($fresh.Count -ne 1) {
            continue
        }
        $freshOwner = Get-QmProcessOwnerSid -ProcessRecord $fresh[0]
        $sameCreation = ([string]$fresh[0].CreationDate -eq [string]$candidate.CreationDate)
        if ($sameCreation -and $freshOwner -ceq $ExpectedOwnerSid) {
            Stop-Process -Id $candidate.ProcessId -Force -ErrorAction Stop
        }
    }
    Start-Sleep -Seconds 2
    $remainingOwner = @(Get-QmDev2IdentityProcesses -ExpectedOwnerSid $ExpectedOwnerSid)
    $remainingRoot = @(Get-QmDev2Processes)
    if ($remainingOwner.Count -gt 0 -or $remainingRoot.Count -gt 0) {
        throw "Containment cleanup left owner/root processes (owner=$($remainingOwner.Count), root=$($remainingRoot.Count)); ambiguous or wrong-owner processes were not killed."
    }
}

function Assert-QmRunnerCompatibility {
    param([Parameter(Mandatory = $true)][string]$RunSmokePath)
    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($RunSmokePath, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -gt 0) {
        throw "run_smoke.ps1 has parse errors: $($errors | Out-String)"
    }
    $text = Get-Content -LiteralPath $RunSmokePath -Raw -ErrorAction Stop
    $requiredMarkers = @(
        "DEV2 requires the isolated",
        "DEV2 ReportRoot must stay under",
        'Join-Path $resolvedReportRoot "_framework_evidence\22"',
        'post_run_pump_skipped (DEV2 isolation)'
    )
    foreach ($marker in $requiredMarkers) {
        if (-not $text.Contains($marker, [System.StringComparison]::Ordinal)) {
            throw "run_smoke.ps1 lacks required DEV2 compatibility marker: $marker"
        }
    }
    $identityIndex = $text.IndexOf('DEV2 requires the isolated', [System.StringComparison]::Ordinal)
    $mutationIndex = $text.IndexOf('Set-BacktestTerminalConfig -TerminalRoot', [System.StringComparison]::Ordinal)
    if ($identityIndex -lt 0 -or $mutationIndex -lt 0 -or $identityIndex -gt $mutationIndex) {
        throw 'run_smoke.ps1 DEV2 identity gate must precede terminal mutation.'
    }
}

function Set-QmRunDirectoryAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetSid,
        [Parameter(Mandatory = $true)][System.Security.AccessControl.FileSystemRights]$TargetRights
    )
    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleAll($rule)
    }
    $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagation = [System.Security.AccessControl.PropagationFlags]::None
    foreach ($grant in @(
        @('S-1-5-18', [System.Security.AccessControl.FileSystemRights]::FullControl),
        @('S-1-5-32-544', [System.Security.AccessControl.FileSystemRights]::FullControl),
        @($TargetSid, $TargetRights)
    )) {
        $sid = New-Object System.Security.Principal.SecurityIdentifier([string]$grant[0])
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $sid, [System.Security.AccessControl.FileSystemRights]$grant[1], $inheritance, $propagation,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($accessRule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Assert-QmRegisteredTaskContract {
    param(
        [Parameter(Mandatory = $true)][string]$TaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedAccount,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ExpectedArguments,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingDirectory
    )
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction Stop
    # Registered local-account tasks are returned by the CIM provider with a bare
    # UserId ("QMDev2") even when registration used "HOST\QMDev2". The immutable
    # SID is the authoritative identity; rejecting the provider's display form
    # made every real launch fail before Start-ScheduledTask.
    if ((Resolve-QmAccountSid -AccountName $task.Principal.UserId) -ne $ExpectedSid -or
        $task.Principal.LogonType.ToString() -ne 'Password' -or
        $task.Principal.RunLevel.ToString() -ne 'Limited') {
        throw "Scheduled task '$TaskName' principal drifted from the limited QMDev2 password-logon contract."
    }
    # MSFT_ScheduledTask exposes a triggerless Triggers property as $null, but
    # array-wrapping that CIM null value produces an unexpected count of 1.
    if ($null -ne $task.Triggers) {
        throw "Scheduled task '$TaskName' must be on-demand and have no trigger."
    }
    if (@($task.Actions).Count -ne 1) {
        throw "Scheduled task '$TaskName' must have exactly one action."
    }
    $action = @($task.Actions)[0]
    if (-not (ConvertTo-QmFullPath -Path $action.Execute).Equals($script:PwshPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$action.Arguments -cne $ExpectedArguments -or
        -not (ConvertTo-QmFullPath -Path $action.WorkingDirectory).Equals((ConvertTo-QmFullPath -Path $ExpectedWorkingDirectory), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Scheduled task '$TaskName' action drifted from the fixed helper contract."
    }
    if ($task.Settings.MultipleInstances.ToString() -ne 'IgnoreNew') {
        throw "Scheduled task '$TaskName' must use MultipleInstances=IgnoreNew."
    }
}

function Assert-QmRegisteredCleanupTaskContract {
    param(
        [Parameter(Mandatory = $true)][string]$TaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedArguments,
        [Parameter(Mandatory = $true)][string]$ExpectedHelperPath,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingDirectory,
        [Parameter(Mandatory = $true)][DateTimeOffset]$ExpectedExpiryUtc
    )
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction Stop
    if ((Resolve-QmAccountSid -AccountName $task.Principal.UserId) -cne 'S-1-5-18' -or
        $task.Principal.LogonType.ToString() -cne 'ServiceAccount' -or
        $task.Principal.RunLevel.ToString() -cne 'Highest') {
        throw "Cleanup task '$TaskName' principal drifted from SYSTEM/ServiceAccount/Highest."
    }
    $triggerKinds = @($task.Triggers | ForEach-Object { $_.CimClass.CimClassName } | Sort-Object)
    if ([string]::Join('|', $triggerKinds) -cne 'MSFT_TaskBootTrigger|MSFT_TaskTimeTrigger') {
        throw "Cleanup task '$TaskName' must have exactly one startup and one TTL trigger."
    }
    $timeTrigger = @($task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskTimeTrigger' })[0]
    $bootTrigger = @($task.Triggers | Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger' })[0]
    $actualExpiryUtc = [DateTimeOffset]::Parse([string]$timeTrigger.StartBoundary).ToUniversalTime()
    $expiryDeltaSeconds = [Math]::Abs(($actualExpiryUtc - $ExpectedExpiryUtc.ToUniversalTime()).TotalSeconds)
    if (-not $timeTrigger.Enabled -or -not $bootTrigger.Enabled -or
        [string]$timeTrigger.Repetition.Interval -cne 'PT5M' -or
        -not [string]::IsNullOrWhiteSpace([string]$timeTrigger.Repetition.Duration) -or
        $expiryDeltaSeconds -gt 2) {
        throw "Cleanup task '$TaskName' TTL trigger must retry every five minutes until verified disarm."
    }
    if (@($task.Actions).Count -ne 1) {
        throw "Cleanup task '$TaskName' must have exactly one action."
    }
    Assert-QmNoReparseComponents -Path $ExpectedHelperPath
    $action = @($task.Actions)[0]
    if (-not (ConvertTo-QmFullPath -Path $action.Execute).Equals($script:PwshPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$action.Arguments -cne $ExpectedArguments -or
        -not (ConvertTo-QmFullPath -Path $action.WorkingDirectory).Equals((ConvertTo-QmFullPath -Path $ExpectedWorkingDirectory), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Cleanup task '$TaskName' action drifted from the protected helper contract."
    }
    if ($task.State.ToString() -cne 'Ready' -or
        $task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew' -or
        -not $task.Settings.StartWhenAvailable -or -not $task.Settings.AllowHardTerminate -or
        [string]$task.Settings.ExecutionTimeLimit -cne 'PT10M' -or
        [int]$task.Settings.RestartCount -ne 3 -or
        [string]$task.Settings.RestartInterval -cne 'PT1M') {
        throw "Cleanup task '$TaskName' settings drifted from the bounded retry/hard-termination contract."
    }
}

function Stop-QmScheduledTaskExact {
    param([Parameter(Mandatory = $true)][string]$TaskName)
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
    if ($null -eq $task) {
        return
    }
    if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $script:TaskPath) {
        throw 'DEV2 Scheduled Task identity drifted before stop.'
    }
    if ($task.State.ToString() -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction Stop
        $deadline = (Get-Date).ToUniversalTime().AddSeconds(30)
        do {
            Start-Sleep -Milliseconds 500
            $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
        } while ($null -ne $task -and $task.State.ToString() -eq 'Running' -and (Get-Date).ToUniversalTime() -lt $deadline)
        if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
            throw "DEV2 Scheduled Task did not stop within 30 seconds: $TaskName"
        }
    }
}

function Unregister-QmScheduledTaskExact {
    param([Parameter(Mandatory = $true)][string]$TaskName)
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
    if ($null -ne $task) {
        if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $script:TaskPath) {
            throw 'DEV2 Scheduled Task identity drifted before unregister.'
        }
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -Confirm:$false -ErrorAction Stop
    }
    if ($null -ne (Get-ScheduledTask -TaskName $TaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue)) {
        throw "DEV2 Scheduled Task remains registered after exact unregister: $TaskName"
    }
}

function Write-QmRequestFile {
    param(
        [Parameter(Mandatory = $true)][hashtable]$Request,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $json = $Request | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Restore-QmDev2TesterGroupsCanonical {
    foreach ($path in @($script:TesterGroupsCanonicalPath, $script:TesterGroupsDev2Path)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Required tester groups file is missing: $path"
        }
        Assert-QmNoReparseComponents -Path $path
    }
    [System.IO.File]::Copy($script:TesterGroupsCanonicalPath, $script:TesterGroupsDev2Path, $true)
    $canonicalHash = (Get-FileHash -LiteralPath $script:TesterGroupsCanonicalPath -Algorithm SHA256).Hash
    $restoredHash = (Get-FileHash -LiteralPath $script:TesterGroupsDev2Path -Algorithm SHA256).Hash
    if ($restoredHash -cne $canonicalHash) {
        throw "DEV2 tester groups canonical restore hash mismatch: expected=$canonicalHash actual=$restoredHash"
    }
    return $restoredHash
}

function Assert-QmImmediateCleanupDisarmReceipt {
    param(
        [Parameter(Mandatory = $true)][object]$Receipt,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ExpectedTargetTaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedCleanupTaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedContainmentResultPath
    )
    foreach ($field in @(
        'success', 'containment_verified', 'lease_disarmed',
        'account_restored_disabled', 'target_task_registered',
        'cleanup_task_registered'
    )) {
        if ($null -eq $Receipt.PSObject.Properties[$field] -or
            $Receipt.PSObject.Properties[$field].Value -isnot [bool]) {
            throw "Immediate cleanup receipt field is not Boolean: $field"
        }
    }
    if ([string]$Receipt.artifact_type -cne 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT' -or
        -not $Receipt.success -or -not $Receipt.containment_verified -or
        -not $Receipt.lease_disarmed -or -not $Receipt.account_restored_disabled -or
        [int]$Receipt.owner_process_count -ne 0 -or [int]$Receipt.dev2_root_process_count -ne 0 -or
        $Receipt.target_task_registered -or $Receipt.cleanup_task_registered -or
        [string]$Receipt.expected_sid -cne $ExpectedSid -or
        [string]$Receipt.target_task_name -cne $ExpectedTargetTaskName -or
        [string]$Receipt.cleanup_task_name -cne $ExpectedCleanupTaskName -or
        -not (ConvertTo-QmFullPath -Path ([string]$Receipt.containment_result_path)).Equals(
            (ConvertTo-QmFullPath -Path $ExpectedContainmentResultPath), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Immediate SYSTEM cleanup lease result failed its containment contract.'
    }
}

$mutex = $null
$mutexAcquired = $false
$taskRegistered = $false
$taskName = $null
$cleanupTaskRegistered = $false
$cleanupTaskName = $null
$cleanupLeaseDisarmed = $false
$cleanupHelperSha256 = $null
$cleanupLeasePath = $null
$credential = $null
$identityContract = $null
$plainPassword = $null
$primaryError = $null
$finalResult = $null
$runDirectory = $null
$resultPath = $null
$logPath = $null
$testerGroupsPostChildSha256 = $null
$testerGroupsRestoredSha256 = $null
$laneContract = $null
$laneContractSha256 = $null
$programSha256 = $null
$runSmokeSha256 = $null
$childSha256 = $null
$dev2AccountState = $null
$dev2AccountEnabledByController = $false
$dev2AccountRestoredDisabled = $false
$cleanupErrors = New-Object System.Collections.Generic.List[string]

try {
    Assert-QmElevatedController
    $mutex = New-Object System.Threading.Mutex($false, $script:ControllerMutexName)
    try {
        $mutexAcquired = $mutex.WaitOne(0)
    } catch [System.Threading.AbandonedMutexException] {
        $mutexAcquired = $true
    }
    if (-not $mutexAcquired) {
        throw 'Another DEV2 smoke controller holds the exclusive launcher lock.'
    }
    Assert-QmNoDev2Tasks
    $dev2AccountState = Get-QmDev2ControllerAccountState

    if ($EAId -le 0 -and [string]::IsNullOrWhiteSpace($EALabel)) {
        throw 'Provide -EAId or -EALabel.'
    }
    if (-not [string]::IsNullOrWhiteSpace($SetFile)) {
        $SetFile = ConvertTo-QmFullPath -Path (Resolve-Path -LiteralPath $SetFile -ErrorAction Stop).Path
        Assert-QmNoReparseComponents -Path $SetFile
        $repoForSet = ConvertTo-QmFullPath -Path (Join-Path $PSScriptRoot '..\..')
        if (-not (Test-QmPathWithin -Path $SetFile -Root $repoForSet)) {
            throw "DEV2 SetFile must be a physical file under the repository: $SetFile"
        }
    }

    foreach ($requiredRoot in @($script:Dev2ReportsRoot, $script:CredentialPath, $script:PwshPath, $script:CleanupHelperSourcePath, $script:TesterGroupsCanonicalPath)) {
        Assert-QmNoReparseComponents -Path $requiredRoot
    }
    $repoRoot = ConvertTo-QmFullPath -Path (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    $runSmokePath = Join-Path $PSScriptRoot 'run_smoke.ps1'
    $childPath = Join-Path $PSScriptRoot 'invoke_dev2_smoke_task.ps1'
    foreach ($fixedScript in @($runSmokePath, $childPath)) {
        if (-not (Test-Path -LiteralPath $fixedScript -PathType Leaf)) {
            throw "Required fixed DEV2 script is missing: $fixedScript"
        }
        Assert-QmNoReparseComponents -Path $fixedScript
    }

    Assert-QmPhysicalDev2Tree
    $laneContract = Get-QmLaneContract
    $laneContractSha256 = (Get-FileHash -LiteralPath $script:LaneContractPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $programSha256 = Get-QmProgramHashes -Contract $laneContract
    $runSmokeSha256 = (Get-FileHash -LiteralPath $runSmokePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $childSha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $identityContract = Get-QmDev2IdentityContract
    if ($identityContract.Sid -cne [string]$dev2AccountState.Sid) {
        throw 'QMDev2 disabled-at-rest identity differs from the isolated lane identity.'
    }
    Assert-QmFirewallIsolation
    Assert-QmRunnerCompatibility -RunSmokePath $runSmokePath
    Assert-QmNoDev2Processes -Stage 'controller preflight'
    Assert-QmNoDev2IdentityProcesses -ExpectedOwnerSid $identityContract.Sid -Stage 'controller preflight'

    $credentialObject = Import-Clixml -LiteralPath $script:CredentialPath -ErrorAction Stop
    if ($credentialObject -isnot [System.Management.Automation.PSCredential]) {
        throw 'credential.clixml does not contain a PSCredential.'
    }
    $credentialSid = Resolve-QmAccountSid -AccountName $credentialObject.UserName
    if ($credentialSid -ne $identityContract.Sid) {
        throw 'credential.clixml is not bound to the local QMDev2 account.'
    }
    $credential = $credentialObject
    $plainPassword = $credential.GetNetworkCredential().Password
    if ([string]::IsNullOrEmpty($plainPassword)) {
        throw 'The QMDev2 Scheduled Task credential has an empty password.'
    }

    $runId = '{0}_{1}' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N')
    $runDirectory = Join-Path $script:Dev2ReportsRoot "runs\$runId"
    $controlDirectory = Join-Path $runDirectory 'control'
    $outputDirectory = Join-Path $runDirectory 'output'
    $smokeReportRoot = Join-Path $outputDirectory 'smoke'
    foreach ($directory in @($runDirectory, $controlDirectory, $outputDirectory, $smokeReportRoot)) {
        # New-Item has no -LiteralPath parameter. These controller-generated paths
        # contain only fixed segments plus a GUID, so -Path cannot expand a wildcard.
        New-Item -ItemType Directory -Path $directory -ErrorAction Stop | Out-Null
    }
    Set-QmRunDirectoryAcl -Path $runDirectory -TargetSid $identityContract.Sid -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Set-QmRunDirectoryAcl -Path $controlDirectory -TargetSid $identityContract.Sid -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Set-QmRunDirectoryAcl -Path $outputDirectory -TargetSid $identityContract.Sid -TargetRights ([System.Security.AccessControl.FileSystemRights]::Modify)

    $requestPath = Join-Path $controlDirectory 'request.json'
    $resultPath = Join-Path $outputDirectory 'result.json'
    $logPath = Join-Path $outputDirectory 'run.log'
    $nonce = [guid]::NewGuid().ToString('N')
    $taskName = "$($script:TaskNamePrefix)$([guid]::NewGuid().ToString('N'))"
    $maximumRunAttempts = [Math]::Min(10, ($Runs + 2))
    $minimumControllerTimeout = Get-QmMinimumDev2ControllerTimeoutSeconds `
        -MaximumRunAttempts $maximumRunAttempts -RunTimeoutSeconds $TimeoutSeconds
    if ($minimumControllerTimeout -gt 172800) {
        throw "The bounded $maximumRunAttempts-attempt controller requires $minimumControllerTimeout seconds, above the 172800-second hard limit."
    }
    if ($ControllerTimeoutSeconds -gt 0 -and $ControllerTimeoutSeconds -lt $minimumControllerTimeout) {
        throw "ControllerTimeoutSeconds=$ControllerTimeoutSeconds is below the bounded $maximumRunAttempts-attempt minimum $minimumControllerTimeout."
    }
    $effectiveControllerTimeout = if ($ControllerTimeoutSeconds -gt 0) { $ControllerTimeoutSeconds } else { $minimumControllerTimeout }

    $smokeParameters = [ordered]@{
        EAId = $EAId
        Symbol = $Symbol
        Year = $Year
        Expert = $Expert
        Period = $Period
        Runs = $Runs
        MinTrades = $MinTrades
        Model = $Model
        TimeoutSeconds = $TimeoutSeconds
        CommissionPerLot = $CommissionPerLot
        CommissionPerSideNative = $CommissionPerSideNative
        TesterDepositOverride = $TesterDepositOverride
    }
    if (-not [string]::IsNullOrWhiteSpace($EALabel)) { $smokeParameters.EALabel = $EALabel }
    if (-not [string]::IsNullOrWhiteSpace($FromDate)) { $smokeParameters.FromDate = $FromDate }
    if (-not [string]::IsNullOrWhiteSpace($ToDate)) { $smokeParameters.ToDate = $ToDate }
    if (-not [string]::IsNullOrWhiteSpace($SetFile)) { $smokeParameters.SetFile = $SetFile }
    if (-not [string]::IsNullOrWhiteSpace($TesterCurrencyOverride)) { $smokeParameters.TesterCurrencyOverride = $TesterCurrencyOverride }
    if ($AllowMissingRealTicksLogMarker.IsPresent) { $smokeParameters.AllowMissingRealTicksLogMarker = $true }
    if ($SmokeMode.IsPresent) { $smokeParameters.SmokeMode = $true }

    $request = [ordered]@{
        schema_version = 2
        run_id = $runId
        nonce = $nonce
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        expires_utc = (Get-Date).ToUniversalTime().AddSeconds($effectiveControllerTimeout + 600).ToString('o')
        expected_account = $identityContract.Account
        expected_sid = $identityContract.Sid
        expected_profile = $identityContract.Profile
        expected_common_path = $identityContract.CommonPath
        dev2_root = $script:Dev2Root
        reports_root = $script:Dev2ReportsRoot
        smoke_report_root = $smokeReportRoot
        expected_task_name = $taskName
        controller_mutex = $script:ControllerMutexName
        lane_contract_path = $script:LaneContractPath
        lane_contract_sha256 = $laneContractSha256
        child_path = $childPath
        child_sha256 = $childSha256
        run_smoke_path = $runSmokePath
        run_smoke_sha256 = $runSmokeSha256
        program_sha256 = $programSha256
        smoke_parameters = $smokeParameters
        maximum_run_attempts = $maximumRunAttempts
        per_attempt_overhead_seconds = $script:PerAttemptOverheadSeconds
        controller_finalization_margin_seconds = $script:ControllerFinalizationMarginSeconds
        controller_timeout_seconds = $effectiveControllerTimeout
    }
    Write-QmRequestFile -Request $request -Path $requestPath

    $cleanupTaskName = "$($script:CleanupTaskNamePrefix)$([guid]::NewGuid().ToString('N'))"
    $cleanupHelperPath = Join-Path $controlDirectory 'cleanup_dev2_account_lease.ps1'
    $cleanupGroupsSourcePath = Join-Path $controlDirectory 'Darwinex-Live_real.canonical.txt'
    $cleanupLeasePath = Join-Path $controlDirectory 'cleanup_lease.json'
    $cleanupResultPath = Join-Path $controlDirectory 'cleanup_lease.result.json'
    $cleanupDisarmResultPath = Join-Path $controlDirectory 'cleanup_lease.disarm.result.json'
    [System.IO.File]::Copy($script:CleanupHelperSourcePath, $cleanupHelperPath, $false)
    [System.IO.File]::Copy($script:TesterGroupsCanonicalPath, $cleanupGroupsSourcePath, $false)
    foreach ($protectedCopy in @($cleanupHelperPath, $cleanupGroupsSourcePath)) {
        Assert-QmNoReparseComponents -Path $protectedCopy
    }
    $cleanupHelperSha256 = (Get-FileHash -LiteralPath $cleanupHelperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $cleanupGroupsSha256 = (Get-FileHash -LiteralPath $cleanupGroupsSourcePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $canonicalGroupsSha256 = (Get-FileHash -LiteralPath $script:TesterGroupsCanonicalPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($cleanupGroupsSha256 -cne $canonicalGroupsSha256) {
        throw 'Protected cleanup tester-groups copy differs from the canonical source.'
    }
    $cleanupExpiresUtc = (Get-Date).ToUniversalTime().AddSeconds($effectiveControllerTimeout + $script:CleanupLeaseGraceSeconds)
    $cleanupLease = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_LEASE'
        run_id = $runId
        nonce = $nonce
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        expires_utc = $cleanupExpiresUtc.ToString('o')
        run_directory = $runDirectory
        expected_sid = $identityContract.Sid
        dev2_root = $script:Dev2Root
        target_task_name = $taskName
        cleanup_task_name = $cleanupTaskName
        helper_path = $cleanupHelperPath
        helper_sha256 = $cleanupHelperSha256
        tester_groups_source_path = $cleanupGroupsSourcePath
        tester_groups_target_path = $script:TesterGroupsDev2Path
        tester_groups_sha256 = $cleanupGroupsSha256
        result_path = $cleanupResultPath
        disarm_result_path = $cleanupDisarmResultPath
    }
    Write-QmRequestFile -Request $cleanupLease -Path $cleanupLeasePath
    Assert-QmNoReparseComponents -Path $cleanupLeasePath

    $cleanupActionArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -LeasePath "{1}" -ExpectedSid "{2}" -TargetTaskName "{3}" -CleanupTaskName "{4}" -ExpectedHelperSha256 "{5}"' -f `
        $cleanupHelperPath, $cleanupLeasePath, $identityContract.Sid, $taskName, $cleanupTaskName, $cleanupHelperSha256
    $cleanupAction = New-ScheduledTaskAction -Execute $script:PwshPath -Argument $cleanupActionArguments -WorkingDirectory $runDirectory
    $cleanupTriggers = @(
        (New-ScheduledTaskTrigger -AtStartup),
        (New-ScheduledTaskTrigger -Once -At $cleanupExpiresUtc.ToLocalTime() -RepetitionInterval (New-TimeSpan -Minutes 5))
    )
    $cleanupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $cleanupPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $cleanupTaskName -TaskPath $script:TaskPath -Action $cleanupAction `
        -Trigger $cleanupTriggers -Settings $cleanupSettings -Principal $cleanupPrincipal `
        -Description "Bounded DEV2 account containment lease $runId" -ErrorAction Stop | Out-Null
    $cleanupTaskRegistered = $true
    Assert-QmRegisteredCleanupTaskContract -TaskName $cleanupTaskName -ExpectedArguments $cleanupActionArguments `
        -ExpectedHelperPath $cleanupHelperPath -ExpectedWorkingDirectory $runDirectory -ExpectedExpiryUtc $cleanupExpiresUtc

    $dev2AccountEnabledByController = Enable-QmDev2ControllerAccountState -State $dev2AccountState

    $actionArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RunDirectory "{1}"' -f $childPath, $runDirectory
    $action = New-ScheduledTaskAction -Execute $script:PwshPath -Argument $actionArguments -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden `
        -ExecutionTimeLimit (New-TimeSpan -Seconds ($effectiveControllerTimeout + 600)) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -TaskPath $script:TaskPath -Action $action -Settings $settings `
        -User $identityContract.Account -Password $plainPassword -RunLevel Limited `
        -Description "Ephemeral isolated DEV2 smoke $runId" -ErrorAction Stop | Out-Null
    $taskRegistered = $true
    $plainPassword = $null
    $credential = $null

    Assert-QmRegisteredTaskContract -TaskName $taskName -ExpectedAccount $identityContract.Account `
        -ExpectedSid $identityContract.Sid -ExpectedArguments $actionArguments -ExpectedWorkingDirectory $repoRoot
    Assert-QmNoDev2Processes -Stage 'immediately before Scheduled Task start'
    Assert-QmNoDev2IdentityProcesses -ExpectedOwnerSid $identityContract.Sid -Stage 'immediately before Scheduled Task start'

    $startUtc = (Get-Date).ToUniversalTime()
    Start-ScheduledTask -TaskName $taskName -TaskPath $script:TaskPath -ErrorAction Stop
    $deadline = $startUtc.AddSeconds($effectiveControllerTimeout)
    $taskObservedRunning = $false
    while ((Get-Date).ToUniversalTime() -lt $deadline) {
        if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
            break
        }
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $script:TaskPath -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath $script:TaskPath -ErrorAction Stop
        if ($task.State.ToString() -eq 'Running') {
            $taskObservedRunning = $true
        } elseif ($taskObservedRunning -or
            ($info.LastRunTime.Year -gt 2000 -and $info.LastRunTime.ToUniversalTime() -ge $startUtc.AddSeconds(-5))) {
            Start-Sleep -Seconds 2
            if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
                throw "DEV2 task exited without an atomic result (LastTaskResult=$($info.LastTaskResult)); log=$logPath"
            }
        }
        Start-Sleep -Seconds 2
    }

    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        [System.IO.File]::WriteAllText((Join-Path $outputDirectory 'cancel.requested'), (Get-Date).ToUniversalTime().ToString('o'))
        throw "DEV2 Scheduled Task timed out after $effectiveControllerTimeout seconds; ordered containment cleanup is armed; log=$logPath"
    }

    $result = Get-Content -LiteralPath $resultPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ([int]$result.schema_version -ne 2 -or [string]$result.run_id -cne $runId -or [string]$result.nonce -cne $nonce) {
        throw "DEV2 result nonce/run_id mismatch; refusing stale or substituted result: $resultPath"
    }
    if ([string]$result.identity_sid -cne $identityContract.Sid -or
        [string]$result.expected_task_name -cne $taskName -or
        [string]$result.controller_mutex -cne $script:ControllerMutexName -or
        [string]$result.lane_contract_sha256 -cne $laneContractSha256 -or
        [string]$result.child_sha256 -cne $childSha256 -or
        [string]$result.run_smoke_sha256 -cne $runSmokeSha256) {
        throw 'DEV2 result identity/task/mutex/script hash binding mismatch.'
    }
    foreach ($name in @($programSha256.Keys)) {
        $reported = [string]$result.program_sha256.$name
        if ($reported -cne [string]$programSha256[$name]) {
            throw "DEV2 result program hash mismatch for $name."
        }
    }
    $postDeadline = (Get-Date).ToUniversalTime().AddSeconds(30)
    while ((Get-Date).ToUniversalTime() -lt $postDeadline) {
        $task = Get-ScheduledTask -TaskName $taskName -TaskPath $script:TaskPath -ErrorAction Stop
        if ($task.State.ToString() -ne 'Running') { break }
        Start-Sleep -Milliseconds 500
    }
    Assert-QmNoDev2Processes -Stage 'controller postflight'
    if (-not [bool]$result.success) {
        throw "DEV2 smoke failed (code=$($result.error_code), exit=$($result.run_smoke_exit_code)); log=$logPath"
    }
    $agentProof = $result.agent_port_proof
    $proofRows = @($agentProof.listeners)
    if ([string]$agentProof.status -cne 'PASS' -or $proofRows.Count -lt 1 -or
        [bool]$agentProof.preexisting_port_owner -or [bool]$agentProof.concurrent_port_owner -or
        [string]$agentProof.exclusivity_semantics -cne 'NO_CONCURRENT_OVERLAPPING_ENDPOINT_OWNER' -or
        -not [bool]$agentProof.released_baseline_endpoint_reuse_allowed -or
        -not (ConvertTo-QmFullPath -Path ([string]$agentProof.metatester_path)).Equals(
            (ConvertTo-QmFullPath -Path (Join-Path $script:Dev2Root 'metatester64.exe')),
            [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$agentProof.metatester_sha256 -cne [string]$programSha256['metatester64.exe']) {
        throw 'DEV2 result lacks a valid exact-path, runtime-exclusive metatester listener proof.'
    }
    foreach ($listener in $proofRows) {
        if ([int]$listener.local_port -lt [int]$laneContract.agent_port_contract.minimum_port -or
            [int]$listener.local_port -gt [int]$laneContract.agent_port_contract.maximum_port -or
            [int]$listener.process_id -le 0 -or [string]$listener.owner_sid -cne $identityContract.Sid -or
            [bool]$listener.preexisting_port_owner -or [bool]$listener.concurrent_port_owner -or
            -not [bool]$listener.exclusive_current_owner -or
            [int]$listener.current_overlapping_owner_count -ne 1 -or
            $listener.baseline_endpoint_was_occupied -isnot [bool] -or
            [int]$listener.released_baseline_owner_count -lt 0 -or
            ([bool]$listener.baseline_endpoint_was_occupied -and [int]$listener.released_baseline_owner_count -lt 1) -or
            -not (ConvertTo-QmFullPath -Path ([string]$listener.executable_path)).Equals(
                (ConvertTo-QmFullPath -Path (Join-Path $script:Dev2Root 'metatester64.exe')),
                [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'DEV2 metatester listener proof contains an out-of-contract listener.'
        }
    }
    if (-not (Test-Path -LiteralPath $script:TesterGroupsDev2Path -PathType Leaf)) {
        throw "DEV2 tester groups file disappeared during the run: $($script:TesterGroupsDev2Path)"
    }
    $testerGroupsPostChildSha256 = (Get-FileHash -LiteralPath $script:TesterGroupsDev2Path -Algorithm SHA256).Hash
    $testerGroupsCanonicalSha256 = (Get-FileHash -LiteralPath $script:TesterGroupsCanonicalPath -Algorithm SHA256).Hash
    if ($testerGroupsPostChildSha256 -cne $testerGroupsCanonicalSha256) {
        throw "Child returned without restoring canonical tester groups: expected=$testerGroupsCanonicalSha256 actual=$testerGroupsPostChildSha256"
    }
    $finalResult = $result
} catch {
    $primaryError = $_
} finally {
    $plainPassword = $null
    $credential = $null
    if (-not [string]::IsNullOrWhiteSpace($taskName)) {
        try { Stop-QmScheduledTaskExact -TaskName $taskName } catch { $cleanupErrors.Add("task_stop: $($_.Exception.Message)") }
    }
    if ($null -ne $dev2AccountState) {
        try { Stop-QmDev2ProcessesExact -ExpectedOwnerSid ([string]$dev2AccountState.Sid) } catch { $cleanupErrors.Add("process_cleanup: $($_.Exception.Message)") }
    }
    if (-not [string]::IsNullOrWhiteSpace($taskName)) {
        try { Unregister-QmScheduledTaskExact -TaskName $taskName } catch { $cleanupErrors.Add("task_unregister: $($_.Exception.Message)") }
    }
    if ($null -ne $identityContract) {
        try { $testerGroupsRestoredSha256 = Restore-QmDev2TesterGroupsCanonical } catch { $cleanupErrors.Add("tester_groups_restore: $($_.Exception.Message)") }
    }
    if ($null -ne $dev2AccountState) {
        try {
            $dev2AccountRestoredDisabled = Restore-QmDev2ControllerAccountState -State $dev2AccountState
        } catch { $cleanupErrors.Add("account_restore: $($_.Exception.Message)") }
    }
    if ($cleanupTaskRegistered -and -not [string]::IsNullOrWhiteSpace($cleanupTaskName) -and $cleanupErrors.Count -eq 0) {
        try {
            Stop-QmScheduledTaskExact -TaskName $cleanupTaskName
            Unregister-QmScheduledTaskExact -TaskName $cleanupTaskName
            $cleanupLeaseDisarmed = $true
        } catch {
            $cleanupErrors.Add("cleanup_lease_disarm: $($_.Exception.Message)")
        }
    }
    if ($cleanupErrors.Count -gt 0 -and $cleanupTaskRegistered -and -not [string]::IsNullOrWhiteSpace($cleanupTaskName)) {
        try {
            # The long TTL/reboot triggers remain armed as a crash backstop, but
            # a containment failure must invoke the SYSTEM repair immediately.
            Start-ScheduledTask -TaskName $cleanupTaskName -TaskPath $script:TaskPath -ErrorAction Stop
            $cleanupFallbackDeadline = (Get-Date).ToUniversalTime().AddMinutes(2)
            do {
                Start-Sleep -Milliseconds 500
                if (Test-Path -LiteralPath $cleanupDisarmResultPath -PathType Leaf) {
                    break
                }
                if (Test-Path -LiteralPath $cleanupResultPath -PathType Leaf) {
                    $interimCleanup = Get-Content -LiteralPath $cleanupResultPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                    if ([bool]$interimCleanup.success -eq $false) {
                        throw 'Immediate SYSTEM cleanup lease reported failed containment; retry lease remains armed.'
                    }
                }
            } while ((Get-Date).ToUniversalTime() -lt $cleanupFallbackDeadline)
            if (-not (Test-Path -LiteralPath $cleanupDisarmResultPath -PathType Leaf)) {
                throw 'Immediate SYSTEM cleanup lease did not produce a disarm result within two minutes; retry lease remains armed.'
            }
            $immediateCleanup = Get-Content -LiteralPath $cleanupDisarmResultPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            Assert-QmImmediateCleanupDisarmReceipt -Receipt $immediateCleanup `
                -ExpectedSid ([string]$dev2AccountState.Sid) `
                -ExpectedTargetTaskName $taskName -ExpectedCleanupTaskName $cleanupTaskName `
                -ExpectedContainmentResultPath $cleanupResultPath
            $postCleanupUser = Get-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier([string]$dev2AccountState.Sid)) -ErrorAction Stop
            $postCleanupOwnerProcesses = @(Get-QmDev2IdentityProcesses -ExpectedOwnerSid ([string]$dev2AccountState.Sid))
            $postCleanupRootProcesses = @(Get-QmDev2Processes)
            $postCleanupTargetTask = Get-ScheduledTask -TaskName $taskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
            $postCleanupLeaseTask = Get-ScheduledTask -TaskName $cleanupTaskName -TaskPath $script:TaskPath -ErrorAction SilentlyContinue
            if ($postCleanupUser.Name -cne $script:Dev2UserName -or $postCleanupUser.Enabled -or -not $postCleanupUser.PasswordRequired -or
                $postCleanupOwnerProcesses.Count -ne 0 -or $postCleanupRootProcesses.Count -ne 0 -or
                $null -ne $postCleanupTargetTask -or $null -ne $postCleanupLeaseTask) {
                throw 'Immediate SYSTEM cleanup lease failed independent host containment postchecks.'
            }
        } catch {
            $cleanupErrors.Add("cleanup_lease_immediate_start: $($_.Exception.Message)")
        }
    }
    if ($cleanupErrors.Count -gt 0) {
        $primaryMessage = if ($null -ne $primaryError) { $primaryError.Exception.Message } else { 'none' }
        $primaryError = [System.InvalidOperationException]::new(
            "DEV2 controller/containment failure. primary=$primaryMessage; cleanup=$([string]::Join(' | ', @($cleanupErrors)))"
        )
    }
    if ($mutexAcquired -and $null -ne $mutex) {
        try { $mutex.ReleaseMutex() } catch { }
    }
    if ($null -ne $mutex) { $mutex.Dispose() }
}

if ($null -ne $primaryError) {
    throw $primaryError
}

$finalResult | Add-Member -NotePropertyName tester_groups_post_child_sha256 -NotePropertyValue $testerGroupsPostChildSha256 -Force
$finalResult | Add-Member -NotePropertyName tester_groups_restored_sha256 -NotePropertyValue $testerGroupsRestoredSha256 -Force
$finalResult | Add-Member -NotePropertyName tester_groups_canonical_path -NotePropertyValue $script:TesterGroupsCanonicalPath -Force
$finalResult | Add-Member -NotePropertyName tester_groups_dev2_path -NotePropertyValue $script:TesterGroupsDev2Path -Force
$finalResult | Add-Member -NotePropertyName dev2_account_initially_enabled -NotePropertyValue ([bool]$dev2AccountState.InitiallyEnabled) -Force
$finalResult | Add-Member -NotePropertyName dev2_account_enabled_by_controller -NotePropertyValue ([bool]$dev2AccountEnabledByController) -Force
$finalResult | Add-Member -NotePropertyName dev2_account_restored_disabled -NotePropertyValue ([bool]$dev2AccountRestoredDisabled) -Force
$finalResult | Add-Member -NotePropertyName cleanup_helper_sha256 -NotePropertyValue $cleanupHelperSha256 -Force
$finalResult | Add-Member -NotePropertyName cleanup_lease_registered -NotePropertyValue ([bool]$cleanupTaskRegistered) -Force
$finalResult | Add-Member -NotePropertyName cleanup_lease_disarmed -NotePropertyValue ([bool]$cleanupLeaseDisarmed) -Force

Write-Output ($finalResult | ConvertTo-Json -Depth 6)
