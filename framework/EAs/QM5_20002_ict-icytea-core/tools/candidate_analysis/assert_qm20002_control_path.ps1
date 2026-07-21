[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('PrepareDirectory', 'AssertDirectory', 'SealFile', 'AssertFile', 'AssertAbsentFile')]
    [string]$Operation,

    [Parameter(Mandatory = $true)]
    [string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$controlRoot = [IO.Path]::GetFullPath('D:\QM\reports\qm20002\short_ny_reverse_time')
$systemSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
$administratorsSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')

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

$fullPath = ConvertTo-ControlPath $Path
if ($Operation -eq 'PrepareDirectory') {
    $relative = $fullPath.Substring($controlRoot.Length).TrimStart('\')
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
    Assert-NoReparse -Candidate $fullPath -AllowMissingLeaf
    if (Test-Path -LiteralPath $fullPath) { throw 'Expected absent QM20002 control file already exists.' }
    $parent = Split-Path -Parent $fullPath
    Assert-NoReparse $parent
    Assert-ExactAcl -Candidate $parent -Directory $true
} elseif ($Operation -eq 'SealFile') {
    Assert-NoReparse $fullPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw 'QM20002 control file is missing.' }
    Set-ExactFileAcl $fullPath
    Assert-ExactAcl -Candidate $fullPath -Directory $false
} elseif ($Operation -eq 'AssertFile') {
    Assert-NoReparse $fullPath
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw 'QM20002 control file is missing.' }
    Assert-ExactAcl -Candidate $fullPath -Directory $false
} else {
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
} | ConvertTo-Json -Depth 4 -Compress
