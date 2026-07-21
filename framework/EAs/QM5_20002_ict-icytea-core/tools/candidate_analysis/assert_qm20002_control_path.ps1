[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PrepareDirectory', 'AssertDirectory', 'SealFile', 'AssertFile', 'AssertAbsentFile')]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9a-f]{64}$')]
    [string]$ExpectedHelperSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$anchorRoot = [IO.Path]::GetFullPath('D:\QM\reports\qm20002')
$controlRoot = Join-Path $anchorRoot 'short_ny_reverse_time'
$systemSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
$administratorsSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
$privilegedGroupSids = @(
    'S-1-5-32-544', # Administrators
    'S-1-5-32-548', # Account Operators
    'S-1-5-32-549', # Server Operators
    'S-1-5-32-550', # Print Operators
    'S-1-5-32-551', # Backup Operators
    'S-1-5-32-556', # Network Configuration Operators
    'S-1-5-32-578'  # Hyper-V Administrators
)
$dangerousPrivileges = @(
    'SeAssignPrimaryTokenPrivilege',
    'SeBackupPrivilege',
    'SeCreatePermanentPrivilege',
    'SeCreateSymbolicLinkPrivilege',
    'SeCreateTokenPrivilege',
    'SeDebugPrivilege',
    'SeDelegateSessionUserImpersonatePrivilege',
    'SeImpersonatePrivilege',
    'SeLoadDriverPrivilege',
    'SeManageVolumePrivilege',
    'SeRelabelPrivilege',
    'SeRestorePrivilege',
    'SeSecurityPrivilege',
    'SeSystemEnvironmentPrivilege',
    'SeTakeOwnershipPrivilege',
    'SeTcbPrivilege',
    'SeTrustedCredManAccessPrivilege'
)
$actualHelperSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'QM20002 control-path helper byte binding drifted.'
}

function Assert-LocalFixedNtfsVolume {
    $volumeRoot = [IO.Path]::GetPathRoot($controlRoot)
    $drive = [IO.DriveInfo]::new($volumeRoot)
    if (-not $drive.IsReady -or
        $drive.DriveType -ne [IO.DriveType]::Fixed -or
        $drive.DriveFormat -cne 'NTFS') {
        throw 'QM20002 control root requires a ready local fixed NTFS volume.'
    }
    $deviceId = $volumeRoot.TrimEnd('\')
    $escapedDeviceId = $deviceId.Replace("'", "''")
    $logical = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='$escapedDeviceId'" -ErrorAction Stop)
    if ($logical.Count -ne 1 -or
        [int]$logical[0].DriveType -ne 3 -or
        [string]$logical[0].FileSystem -cne 'NTFS' -or
        -not [string]::IsNullOrWhiteSpace([string]$logical[0].ProviderName)) {
        throw 'QM20002 control root volume is remote, redirected, or unsupported.'
    }
}

function ConvertTo-ControlPath([string]$Candidate) {
    if ([string]::IsNullOrWhiteSpace($Candidate) -or $Candidate.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'QM20002 control path is empty or contains CR/LF/NUL.'
    }
    $full = [IO.Path]::GetFullPath($Candidate)
    if (-not $full.Equals($controlRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $full.StartsWith($controlRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'QM20002 control path escaped its fixed root.'
    }
    return $full
}

function Assert-NoReparse([string]$Candidate, [switch]$AllowMissingLeaf) {
    $full = [IO.Path]::GetFullPath($Candidate)
    $root = [IO.Path]::GetPathRoot($full)
    $cursor = $root
    $parts = $full.Substring($root.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries)
    for ($index = 0; $index -lt $parts.Count; $index++) {
        $cursor = Join-Path $cursor $parts[$index]
        if (-not (Test-Path -LiteralPath $cursor)) {
            if ($AllowMissingLeaf.IsPresent -and $index -eq $parts.Count - 1) { return }
            throw "Missing physical QM20002 control component: $cursor"
        }
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point forbidden in QM20002 control path: $cursor"
        }
    }
}

function Set-ExactDirectoryAcl([string]$Directory) {
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($administratorsSid)
    $inheritance = [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    foreach ($sid in @($systemSid, $administratorsSid)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            $inheritance,
            [Security.AccessControl.PropagationFlags]::None,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Directory -AclObject $acl -ErrorAction Stop
}

function Set-ExactFileAcl([string]$File) {
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetOwner($administratorsSid)
    foreach ($sid in @($systemSid, $administratorsSid)) {
        $rule = New-Object Security.AccessControl.FileSystemAccessRule(
            $sid,
            [Security.AccessControl.FileSystemRights]::FullControl,
            [Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $File -AclObject $acl -ErrorAction Stop
}

function Assert-ExactAcl([string]$Candidate, [bool]$Directory) {
    $acl = Get-Acl -LiteralPath $Candidate -ErrorAction Stop
    $ownerSid = ([Security.Principal.NTAccount][string]$acl.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
    $rules = @($acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))
    if (-not $acl.AreAccessRulesProtected -or $ownerSid -cne $administratorsSid.Value -or $rules.Count -ne 2) {
        throw 'QM20002 control ACL owner/protection/rule closure drifted.'
    }
    $expectedInheritance = if ($Directory) {
        [Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit
    } else { [Security.AccessControl.InheritanceFlags]::None }
    $observed = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($rule in $rules) {
        $sid = [string]$rule.IdentityReference.Value
        if ($sid -notin @($systemSid.Value, $administratorsSid.Value) -or
            $rule.AccessControlType -ne [Security.AccessControl.AccessControlType]::Allow -or
            $rule.FileSystemRights -ne [Security.AccessControl.FileSystemRights]::FullControl -or
            $rule.InheritanceFlags -ne $expectedInheritance -or
            $rule.PropagationFlags -ne [Security.AccessControl.PropagationFlags]::None -or
            -not $observed.Add($sid)) {
            throw 'QM20002 control ACL contains an unexpected trustee or permission.'
        }
    }
    if (-not $observed.SetEquals(@($systemSid.Value, $administratorsSid.Value))) {
        throw 'QM20002 control ACL omits SYSTEM or Administrators.'
    }
}

function Ensure-ExactProtectedDirectory([string]$Directory) {
    if (Test-Path -LiteralPath $Directory) {
        Assert-NoReparse $Directory
        if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
            throw "QM20002 protected directory path is not a directory: $Directory"
        }
        # Never repair an attacker-writable/owned pre-existing directory in
        # place.  Reject before creating any descendant or temporary file.
        Assert-ExactAcl -Candidate $Directory -Directory $true
        return
    }
    New-Item -ItemType Directory -Path $Directory -ErrorAction Stop | Out-Null
    Assert-NoReparse $Directory
    Set-ExactDirectoryAcl $Directory
    Assert-ExactAcl -Candidate $Directory -Directory $true
}

function Get-UntrustedSids {
    $sids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($sid in @(
            'S-1-1-0',       # Everyone
            'S-1-2-0',       # Local
            'S-1-5-3',       # Batch (Scheduled Task Password logon)
            'S-1-5-4',       # Interactive
            'S-1-5-11',      # Authenticated Users
            'S-1-5-14',      # Remote Interactive Logon
            'S-1-5-113',     # Local account
            'S-1-5-32-545'   # Builtin Users
        )) { [void]$sids.Add($sid) }
    $dev1 = Get-LocalUser -Name 'QMDev1' -ErrorAction Stop
    [void]$sids.Add([string]$dev1.SID.Value)
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($group in @(Get-LocalGroup -ErrorAction Stop)) {
            $groupSid = [string]$group.SID.Value
            if ($sids.Contains($groupSid)) { continue }
            foreach ($member in @(Get-LocalGroupMember -SID $group.SID -ErrorAction Stop)) {
                if ($null -ne $member.SID -and $sids.Contains([string]$member.SID.Value)) {
                    if ($sids.Add($groupSid)) { $changed = $true }
                    break
                }
            }
        }
    }
    return $sids
}

function Initialize-QmLsaRightsReader {
    if ('QmLsaRightsReader' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

public static class QmLsaRightsReader
{
    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_OBJECT_ATTRIBUTES
    {
        public UInt32 Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public UInt32 Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct LSA_UNICODE_STRING
    {
        public UInt16 Length;
        public UInt16 MaximumLength;
        public IntPtr Buffer;
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern UInt32 LsaOpenPolicy(
        IntPtr systemName,
        ref LSA_OBJECT_ATTRIBUTES objectAttributes,
        UInt32 desiredAccess,
        out IntPtr policyHandle);

    [DllImport("advapi32.dll")]
    private static extern UInt32 LsaEnumerateAccountRights(
        IntPtr policyHandle,
        IntPtr accountSid,
        out IntPtr userRights,
        out UInt32 countOfRights);

    [DllImport("advapi32.dll")]
    private static extern UInt32 LsaFreeMemory(IntPtr buffer);

    [DllImport("advapi32.dll")]
    private static extern UInt32 LsaClose(IntPtr policyHandle);

    [DllImport("advapi32.dll")]
    private static extern UInt32 LsaNtStatusToWinError(UInt32 status);

    public static string[] Enumerate(string sidText)
    {
        const UInt32 POLICY_LOOKUP_NAMES = 0x00000800;
        const UInt32 STATUS_OBJECT_NAME_NOT_FOUND = 0xC0000034;
        LSA_OBJECT_ATTRIBUTES attributes = new LSA_OBJECT_ATTRIBUTES();
        attributes.Length = (UInt32)Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));
        IntPtr policy;
        UInt32 status = LsaOpenPolicy(IntPtr.Zero, ref attributes, POLICY_LOOKUP_NAMES, out policy);
        if (status != 0)
            throw new Win32Exception((int)LsaNtStatusToWinError(status));

        IntPtr rights = IntPtr.Zero;
        GCHandle pinned = new GCHandle();
        try
        {
            SecurityIdentifier sid = new SecurityIdentifier(sidText);
            byte[] bytes = new byte[sid.BinaryLength];
            sid.GetBinaryForm(bytes, 0);
            pinned = GCHandle.Alloc(bytes, GCHandleType.Pinned);
            UInt32 count;
            status = LsaEnumerateAccountRights(
                policy, pinned.AddrOfPinnedObject(), out rights, out count);
            if (status == STATUS_OBJECT_NAME_NOT_FOUND)
                return new string[0];
            if (status != 0)
                throw new Win32Exception((int)LsaNtStatusToWinError(status));

            List<string> values = new List<string>();
            int itemSize = Marshal.SizeOf(typeof(LSA_UNICODE_STRING));
            for (UInt32 index = 0; index < count; index++)
            {
                IntPtr item = new IntPtr(rights.ToInt64() + (long)index * itemSize);
                LSA_UNICODE_STRING value = (LSA_UNICODE_STRING)Marshal.PtrToStructure(
                    item, typeof(LSA_UNICODE_STRING));
                values.Add(Marshal.PtrToStringUni(value.Buffer, value.Length / 2));
            }
            return values.ToArray();
        }
        finally
        {
            if (pinned.IsAllocated) pinned.Free();
            if (rights != IntPtr.Zero) LsaFreeMemory(rights);
            LsaClose(policy);
        }
    }
}
'@
}

function Assert-QmDev1PrivilegeSurface {
    $untrusted = Get-UntrustedSids
    foreach ($sid in $privilegedGroupSids) {
        if ($untrusted.Contains($sid)) {
            throw "QMDev1 belongs to forbidden privileged local group SID: $sid"
        }
    }
    Initialize-QmLsaRightsReader
    $forbidden = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($privilege in $dangerousPrivileges) { [void]$forbidden.Add($privilege) }
    foreach ($sid in $untrusted) {
        foreach ($right in @([QmLsaRightsReader]::Enumerate([string]$sid))) {
            if ($forbidden.Contains([string]$right)) {
                throw "QMDev1 token/group SID $sid has forbidden privilege: $right"
            }
        }
    }
}

function Assert-AncestorProtection {
    $untrusted = Get-UntrustedSids
    $dangerous = [Security.AccessControl.FileSystemRights]::WriteData -bor
        [Security.AccessControl.FileSystemRights]::AppendData -bor
        [Security.AccessControl.FileSystemRights]::WriteExtendedAttributes -bor
        [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor
        [Security.AccessControl.FileSystemRights]::WriteAttributes -bor
        [Security.AccessControl.FileSystemRights]::Delete -bor
        [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [Security.AccessControl.FileSystemRights]::TakeOwnership
    $cursor = [IO.Path]::GetPathRoot($controlRoot)
    $parent = Split-Path -Parent $anchorRoot
    $ancestors = New-Object System.Collections.Generic.List[string]
    $ancestors.Add($cursor)
    foreach ($part in $parent.Substring($cursor.Length).Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $part
        $ancestors.Add($cursor)
    }
    foreach ($cursor in $ancestors) {
        if (-not (Test-Path -LiteralPath $cursor -PathType Container)) {
            throw "Required QM20002 control ancestor is missing: $cursor"
        }
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point forbidden in QM20002 control ancestor: $cursor"
        }
        $acl = Get-Acl -LiteralPath $cursor -ErrorAction Stop
        $ownerSid = ([Security.Principal.NTAccount][string]$acl.Owner).Translate(
            [Security.Principal.SecurityIdentifier]
        ).Value
        if ($untrusted.Contains($ownerSid)) {
            throw "QMDev1 or one of its token/groups owns QM20002 control ancestor: $cursor"
        }
        foreach ($rule in @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))) {
            if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
                $untrusted.Contains([string]$rule.IdentityReference.Value) -and
                (($rule.FileSystemRights -band $dangerous) -ne 0)) {
                throw "QMDev1 or one of its groups can replace the QM20002 control root through ancestor: $cursor"
            }
        }
    }
}

Assert-LocalFixedNtfsVolume
Assert-QmDev1PrivilegeSurface
$fullPath = ConvertTo-ControlPath $Path
Assert-AncestorProtection
if ($Operation -eq 'PrepareDirectory') {
    $relative = $fullPath.Substring($controlRoot.Length).TrimStart('\')
    Ensure-ExactProtectedDirectory $anchorRoot
    $cursor = $controlRoot
    Ensure-ExactProtectedDirectory $cursor
    foreach ($part in $relative.Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $part
        Ensure-ExactProtectedDirectory $cursor
    }
    Assert-ExactAcl -Candidate $fullPath -Directory $true
} elseif ($Operation -eq 'AssertAbsentFile') {
    Assert-NoReparse $anchorRoot
    Assert-ExactAcl -Candidate $anchorRoot -Directory $true
    Assert-NoReparse -Candidate $fullPath -AllowMissingLeaf
    if (Test-Path -LiteralPath $fullPath) { throw 'Expected absent QM20002 control file already exists.' }
    $parent = Split-Path -Parent $fullPath
    Assert-NoReparse $parent
    Assert-ExactAcl -Candidate $parent -Directory $true
} elseif ($Operation -eq 'SealFile') {
    Assert-NoReparse $anchorRoot
    Assert-ExactAcl -Candidate $anchorRoot -Directory $true
    Assert-NoReparse $fullPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw 'QM20002 control file is missing.' }
    Set-ExactFileAcl $fullPath
    Assert-ExactAcl -Candidate $fullPath -Directory $false
} elseif ($Operation -eq 'AssertFile') {
    Assert-NoReparse $anchorRoot
    Assert-ExactAcl -Candidate $anchorRoot -Directory $true
    Assert-NoReparse $fullPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw 'QM20002 control file is missing.' }
    Assert-ExactAcl -Candidate $fullPath -Directory $false
} else {
    Assert-NoReparse $anchorRoot
    Assert-ExactAcl -Candidate $anchorRoot -Directory $true
    Assert-NoReparse $fullPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Container)) { throw 'QM20002 control directory is missing.' }
    Assert-ExactAcl -Candidate $fullPath -Directory $true
}

[ordered]@{
    schema_version = 1
    status = 'PASS'
    operation = $Operation
    path = $fullPath
    control_root = $controlRoot
    owner_sid = $administratorsSid.Value
    full_control_sids = @($systemSid.Value, $administratorsSid.Value)
    reparse_points_forbidden = $true
    local_fixed_ntfs_required = $true
    untrusted_ancestor_owner_forbidden = $true
    qmdev1_privilege_surface_verified = $true
    privileged_group_sids_forbidden = @($privilegedGroupSids)
    privileges_forbidden = @($dangerousPrivileges)
    helper_sha256 = $actualHelperSha256
} | ConvertTo-Json -Depth 4 -Compress
