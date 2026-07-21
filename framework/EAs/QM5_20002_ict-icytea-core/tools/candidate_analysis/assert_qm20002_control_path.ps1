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
$ancestorCreateOnlyRightsAllowed = @(
    'CreateFiles',
    'CreateDirectories'
)
$ancestorReplaceRightsForbidden = @(
    'DeleteSubdirectoriesAndFiles',
    'Delete',
    'ChangePermissions',
    'TakeOwnership'
)
$ancestorRawGenericRightsAllowed = @(
    'GENERIC_READ',
    'GENERIC_WRITE',
    'GENERIC_EXECUTE'
)
$ancestorRawGenericRightsForbidden = @('GENERIC_ALL')
$ancestorRawUnknownBitsDisposition = 'REJECT'
$ancestorCreatorPlaceholderPolicy = 'INHERIT_ONLY_KNOWN_MASK_ALLOWED'
$ancestorCreatorIdentityProofRequired = $true
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

function Assert-ExactAclObject(
    [Security.AccessControl.FileSystemSecurity]$Acl,
    [bool]$Directory
) {
    $ownerSid = $Acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    $rules = @($Acl.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier]))
    if (-not $Acl.AreAccessRulesProtected -or $ownerSid -cne $administratorsSid.Value -or $rules.Count -ne 2) {
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
    if (-not $observed.SetEquals([string[]]@($systemSid.Value, $administratorsSid.Value))) {
        throw 'QM20002 control ACL omits SYSTEM or Administrators.'
    }
}

function Assert-ExactAcl([string]$Candidate, [bool]$Directory) {
    $acl = Get-Acl -LiteralPath $Candidate -ErrorAction Stop
    Assert-ExactAclObject -Acl $acl -Directory $Directory
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
    Initialize-QmLsaRightsReader
    $dev1PrimaryGroupSid = [QmLsaRightsReader]::LocalUserPrimaryGroupSid('QMDev1')
    if ([string]::IsNullOrWhiteSpace($dev1PrimaryGroupSid)) {
        throw 'Unable to prove the QMDev1 primary-group SID.'
    }
    [void]$sids.Add($dev1PrimaryGroupSid)
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
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct USER_INFO_4
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string Name;
        [MarshalAs(UnmanagedType.LPWStr)] public string Password;
        public UInt32 PasswordAge;
        public UInt32 Privilege;
        [MarshalAs(UnmanagedType.LPWStr)] public string HomeDirectory;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public UInt32 Flags;
        [MarshalAs(UnmanagedType.LPWStr)] public string ScriptPath;
        public UInt32 AuthFlags;
        [MarshalAs(UnmanagedType.LPWStr)] public string FullName;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserComment;
        [MarshalAs(UnmanagedType.LPWStr)] public string Parameters;
        [MarshalAs(UnmanagedType.LPWStr)] public string Workstations;
        public UInt32 LastLogon;
        public UInt32 LastLogoff;
        public UInt32 AccountExpires;
        public UInt32 MaxStorage;
        public UInt32 UnitsPerWeek;
        public IntPtr LogonHours;
        public UInt32 BadPasswordCount;
        public UInt32 NumberOfLogons;
        [MarshalAs(UnmanagedType.LPWStr)] public string LogonServer;
        public UInt32 CountryCode;
        public UInt32 CodePage;
        public IntPtr UserSid;
        public UInt32 PrimaryGroupId;
        [MarshalAs(UnmanagedType.LPWStr)] public string Profile;
        [MarshalAs(UnmanagedType.LPWStr)] public string HomeDirectoryDrive;
        public UInt32 PasswordExpired;
    }

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

    private enum TOKEN_INFORMATION_CLASS
    {
        TokenOwner = 4,
        TokenPrimaryGroup = 5
    }

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool GetTokenInformation(
        IntPtr tokenHandle,
        TOKEN_INFORMATION_CLASS tokenInformationClass,
        IntPtr tokenInformation,
        Int32 tokenInformationLength,
        out Int32 returnLength);

    [DllImport("netapi32.dll", CharSet = CharSet.Unicode)]
    private static extern UInt32 NetUserGetInfo(
        string serverName,
        string userName,
        UInt32 level,
        out IntPtr buffer);

    [DllImport("netapi32.dll")]
    private static extern UInt32 NetApiBufferFree(IntPtr buffer);

    private static string GetTokenSid(
        IntPtr tokenHandle,
        TOKEN_INFORMATION_CLASS informationClass)
    {
        Int32 length;
        GetTokenInformation(tokenHandle, informationClass, IntPtr.Zero, 0, out length);
        const Int32 ERROR_INSUFFICIENT_BUFFER = 122;
        Int32 error = Marshal.GetLastWin32Error();
        if (length <= 0 || error != ERROR_INSUFFICIENT_BUFFER)
            throw new Win32Exception(error);

        IntPtr buffer = Marshal.AllocHGlobal(length);
        try
        {
            if (!GetTokenInformation(
                    tokenHandle, informationClass, buffer, length, out length))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            IntPtr sid = Marshal.ReadIntPtr(buffer);
            return new SecurityIdentifier(sid).Value;
        }
        finally
        {
            Marshal.FreeHGlobal(buffer);
        }
    }

    public static string[] CurrentCreatorSids()
    {
        using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
        {
            return new string[] {
                GetTokenSid(identity.Token, TOKEN_INFORMATION_CLASS.TokenOwner),
                GetTokenSid(identity.Token, TOKEN_INFORMATION_CLASS.TokenPrimaryGroup)
            };
        }
    }

    public static string LocalUserPrimaryGroupSid(string userName)
    {
        IntPtr buffer = IntPtr.Zero;
        UInt32 status = NetUserGetInfo(null, userName, 4, out buffer);
        if (status != 0)
            throw new Win32Exception((int)status);
        try
        {
            USER_INFO_4 info = (USER_INFO_4)Marshal.PtrToStructure(
                buffer, typeof(USER_INFO_4));
            SecurityIdentifier userSid = new SecurityIdentifier(info.UserSid);
            SecurityIdentifier accountDomainSid = userSid.AccountDomainSid;
            if (accountDomainSid == null || info.PrimaryGroupId == 0)
                throw new InvalidOperationException("Local user primary group is unavailable.");
            return accountDomainSid.Value + "-" + info.PrimaryGroupId.ToString();
        }
        finally
        {
            if (buffer != IntPtr.Zero) NetApiBufferFree(buffer);
        }
    }

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

function Get-QmAncestorAccessMaskDisposition([uint32]$AccessMask) {
    # Directory CreateFiles/CreateDirectories are the aliases of
    # WriteData/AppendData.  They can win a bootstrap precreation race, but
    # cannot rename/delete an already protected child.  The create path treats
    # a race winner as untrusted and fails closed in Ensure-ExactProtectedDirectory.
    # GENERIC_WRITE maps to FILE_GENERIC_WRITE: create/write data, EA and
    # attributes plus READ_CONTROL/SYNCHRONIZE.  It contains no DELETE_CHILD,
    # DELETE, WRITE_DAC or WRITE_OWNER and therefore cannot replace a protected
    # child.  GENERIC_READ and GENERIC_EXECUTE are non-replacing as well.
    # Raw GENERIC_ALL, the four named replace rights, and every unknown or
    # ambiguous access-mask bit are rejected fail-closed.
    $mask = [uint64]$AccessMask
    $knownSafeMask = [Convert]::ToUInt64('e01201bf', 16)
    $replaceMask = [Convert]::ToUInt64('100d0040', 16)
    $allMask = [Convert]::ToUInt64('ffffffff', 16)
    $unknownMask = $allMask -bxor ($knownSafeMask -bor $replaceMask)
    if (($mask -band $unknownMask) -ne 0) {
        return 'AMBIGUOUS'
    }
    if (($mask -band $replaceMask) -ne 0) {
        return 'REPLACE'
    }
    return 'SAFE'
}

function Test-QmAncestorReplaceAuthority([uint32]$AccessMask) {
    return (Get-QmAncestorAccessMaskDisposition -AccessMask $AccessMask) -cne 'SAFE'
}

function ConvertTo-QmUInt32AccessMask([int32]$AccessMask) {
    return [BitConverter]::ToUInt32([BitConverter]::GetBytes($AccessMask), 0)
}

function Assert-QmAncestorRawDescriptor(
    [Security.AccessControl.RawSecurityDescriptor]$Descriptor,
    $UntrustedSids,
    [string]$EffectiveCreatorOwnerSid,
    [string]$EffectiveCreatorGroupSid,
    [string]$Candidate
) {
    if ($null -eq $Descriptor.DiscretionaryAcl) {
        throw "Null DACL grants replace authority on QM20002 control ancestor: $Candidate"
    }
    foreach ($ace in $Descriptor.DiscretionaryAcl) {
        if ($ace -isnot [Security.AccessControl.QualifiedAce]) {
            throw "Unsupported raw ACE in QM20002 control ancestor: $Candidate"
        }
        if ($ace.AceQualifier -ne [Security.AccessControl.AceQualifier]::AccessAllowed) {
            continue
        }
        $sid = [string]$ace.SecurityIdentifier.Value
        $creatorPlaceholder = $sid -in @('S-1-3-0', 'S-1-3-1')
        if (-not $creatorPlaceholder -and -not $UntrustedSids.Contains($sid)) {
            continue
        }
        $rawMask = ConvertTo-QmUInt32AccessMask -AccessMask $ace.AccessMask
        $disposition = Get-QmAncestorAccessMaskDisposition -AccessMask $rawMask
        $propagates = ($ace.AceFlags -band (
                [Security.AccessControl.AceFlags]::ContainerInherit -bor
                [Security.AccessControl.AceFlags]::ObjectInherit
            )) -ne 0
        $inheritOnly = ($ace.AceFlags -band [Security.AccessControl.AceFlags]::InheritOnly) -ne 0
        $writeOrCreateMask = [Convert]::ToUInt64('40000116', 16)
        $hasWriteOrCreate = (([uint64]$rawMask -band $writeOrCreateMask) -ne 0)
        if ($creatorPlaceholder) {
            $effectiveCreatorSid = if ($sid -ceq 'S-1-3-0') {
                $EffectiveCreatorOwnerSid
            } else {
                $EffectiveCreatorGroupSid
            }
            $effectiveCreatorUntrusted = [string]::IsNullOrWhiteSpace($effectiveCreatorSid) -or
                $UntrustedSids.Contains($effectiveCreatorSid)
            # A normal CI/OI/IO CREATOR OWNER/GROUP ACE is substituted with the
            # privileged bootstrap creator on a new child.  An attacker-created
            # race winner is never adopted: the exact owner/DACL closure rejects
            # it.  This exception requires a proven non-untrusted effective
            # owner/primary-group SID.  Unknown masks, malformed inheritance,
            # or non-inherit-only replace authority remain fail-closed.
            if ($disposition -ceq 'AMBIGUOUS' -or
                ($inheritOnly -and -not $propagates) -or
                (($disposition -cne 'SAFE' -or $hasWriteOrCreate) -and
                    $effectiveCreatorUntrusted) -or
                (-not $inheritOnly -and $disposition -cne 'SAFE')) {
                throw "Creator placeholder ACE can replace the QM20002 control root through ancestor: $Candidate"
            }
            continue
        }
        # An inheritable untrusted write/create ACE would apply to the newly
        # created anchor before Set-ExactDirectoryAcl seals it.  Reject that
        # transient race even though the same non-inheritable right on the
        # ancestor cannot delete or rename an already protected child.
        if ($propagates -and $hasWriteOrCreate) {
            throw "Untrusted inheritable write ACE races the QM20002 control-root seal through ancestor: $Candidate"
        }
        if ($disposition -cne 'SAFE') {
            throw "QMDev1 or one of its groups can replace the QM20002 control root through ancestor: $Candidate"
        }
    }
}

function Assert-AncestorProtection {
    $untrusted = Get-UntrustedSids
    $effectiveCreatorSids = @([QmLsaRightsReader]::CurrentCreatorSids())
    if ($effectiveCreatorSids.Count -ne 2 -or
        [string]::IsNullOrWhiteSpace([string]$effectiveCreatorSids[0]) -or
        [string]::IsNullOrWhiteSpace([string]$effectiveCreatorSids[1])) {
        throw 'Unable to prove QM20002 bootstrap creator owner/primary-group SIDs.'
    }
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
        $rawDescriptor = [Security.AccessControl.RawSecurityDescriptor]::new(
            $acl.GetSecurityDescriptorBinaryForm(),
            0
        )
        Assert-QmAncestorRawDescriptor `
            -Descriptor $rawDescriptor `
            -UntrustedSids $untrusted `
            -EffectiveCreatorOwnerSid ([string]$effectiveCreatorSids[0]) `
            -EffectiveCreatorGroupSid ([string]$effectiveCreatorSids[1]) `
            -Candidate $cursor
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
    ancestor_create_only_rights_allowed = @($ancestorCreateOnlyRightsAllowed)
    ancestor_replace_rights_forbidden = @($ancestorReplaceRightsForbidden)
    ancestor_raw_generic_rights_allowed = @($ancestorRawGenericRightsAllowed)
    ancestor_raw_generic_rights_forbidden = @($ancestorRawGenericRightsForbidden)
    ancestor_raw_unknown_bits_disposition = $ancestorRawUnknownBitsDisposition
    ancestor_creator_placeholder_policy = $ancestorCreatorPlaceholderPolicy
    ancestor_creator_identity_proof_required = $ancestorCreatorIdentityProofRequired
    qmdev1_privilege_surface_verified = $true
    privileged_group_sids_forbidden = @($privilegedGroupSids)
    privileges_forbidden = @($dangerousPrivileges)
    helper_sha256 = $actualHelperSha256
} | ConvertTo-Json -Depth 4 -Compress
