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
$actualHelperSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
if ($actualHelperSha256 -cne $ExpectedHelperSha256) {
    throw 'QM20002 control-path helper byte binding drifted.'
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

function Get-UntrustedSids {
    $sids = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($sid in @('S-1-1-0', 'S-1-5-11', 'S-1-5-32-545')) { [void]$sids.Add($sid) }
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
        foreach ($rule in @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))) {
            if ($rule.AccessControlType -eq [Security.AccessControl.AccessControlType]::Allow -and
                $untrusted.Contains([string]$rule.IdentityReference.Value) -and
                (($rule.FileSystemRights -band $dangerous) -ne 0)) {
                throw "QMDev1 or one of its groups can replace the QM20002 control root through ancestor: $cursor"
            }
        }
    }
}

$fullPath = ConvertTo-ControlPath $Path
Assert-AncestorProtection
if ($Operation -eq 'PrepareDirectory') {
    $relative = $fullPath.Substring($controlRoot.Length).TrimStart('\')
    if (-not (Test-Path -LiteralPath $anchorRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $anchorRoot -ErrorAction Stop | Out-Null
    }
    Assert-NoReparse $anchorRoot
    Set-ExactDirectoryAcl $anchorRoot
    Assert-ExactAcl -Candidate $anchorRoot -Directory $true
    $cursor = $controlRoot
    if (-not (Test-Path -LiteralPath $cursor -PathType Container)) {
        New-Item -ItemType Directory -Path $cursor -ErrorAction Stop | Out-Null
    }
    Assert-NoReparse $cursor
    Set-ExactDirectoryAcl $cursor
    foreach ($part in $relative.Split('\', [StringSplitOptions]::RemoveEmptyEntries)) {
        $cursor = Join-Path $cursor $part
        if (-not (Test-Path -LiteralPath $cursor -PathType Container)) {
            New-Item -ItemType Directory -Path $cursor -ErrorAction Stop | Out-Null
        }
        Assert-NoReparse $cursor
        Set-ExactDirectoryAcl $cursor
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
    helper_sha256 = $actualHelperSha256
} | ConvertTo-Json -Depth 4 -Compress
