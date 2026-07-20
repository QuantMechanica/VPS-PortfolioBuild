[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$ResumeFinalize,
    [string]$ResumeRotationDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'framework\registry\dev2_lane_contract.json'))
$helperPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dev2_machine_credential.ps1'))
$childPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'invoke_dev2_identity_probe.ps1'))
$cleanupSourcePath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'cleanup_dev2_account_lease.ps1'))
$groupsCanonicalPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'framework\registry\tester_groups\Darwinex-Live_real.canonical.txt'))
$credentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV2\credential.machine-dpapi.json')
$canonicalRotationReceiptPath = [System.IO.Path]::GetFullPath(
    'C:\ProgramData\QM\DEV2\credential.machine-dpapi.rotation-receipt.json'
)
$legacyCredentialPath = [System.IO.Path]::GetFullPath('C:\ProgramData\QM\DEV2\credential.clixml')
$dev2Root = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$reportsRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2')
$rotationRoot = [System.IO.Path]::GetFullPath('D:\QM\reports\dev2\credential-rotation')
$groupsTargetPath = [System.IO.Path]::GetFullPath('D:\QM\mt5\DEV2\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt')
$pwshPath = [System.IO.Path]::GetFullPath('C:\Program Files\PowerShell\7\pwsh.exe')
$mutexName = 'Global\QM_DEV2_SMOKE_CONTROLLER'
$taskPrefix = 'QM_DEV2_SMOKE_'
$cleanupPrefix = 'QM_DEV2_CLEANUP_'
$profileTaskPrefix = 'QM_DEV2_PROFILE_INIT_'
$cleanupActionMutexPrefix = 'Global\QM_DEV2_CLEANUP_ACTION_'
$cleanupActionMutexWaitMilliseconds = 180000
$taskPath = '\'
$targetUserName = 'QMDev2'
$contractId = 'QM_DEV2_ISOLATED_MT5_LANE_V3'
$lane = 'DEV2'
$journalSchemaVersion = 2
$journalArtifactType = 'QM_DEV2_MACHINE_CREDENTIAL_ROTATION_JOURNAL'

function ConvertTo-QmRotationFullPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny([char[]]@([char]13, [char]10, [char]0)) -ge 0) {
        throw 'Rotation path is empty or contains CR, LF, or NUL.'
    }
    return [System.IO.Path]::GetFullPath($Path.Replace('/', '\'))
}

function Test-QmRotationPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root,
        [switch]$AllowRoot
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    $rootFull = (ConvertTo-QmRotationFullPath -Path $Root).TrimEnd('\')
    if ($AllowRoot.IsPresent -and $full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $full.StartsWith($rootFull + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-QmRotationNoReparseComponents {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = ConvertTo-QmRotationFullPath -Path $Path
    if (-not (Test-Path -LiteralPath $full)) { throw "Required rotation path does not exist: $full" }
    $root = [System.IO.Path]::GetPathRoot($full)
    $cursor = $root
    foreach ($part in @($full.Substring($root.Length).Split('\', [System.StringSplitOptions]::RemoveEmptyEntries))) {
        $cursor = Join-Path $cursor $part
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Reparse point is forbidden in a rotation path: $cursor"
        }
    }
}

function Resolve-QmRotationSid {
    param([Parameter(Mandatory = $true)][string]$AccountName)
    return (New-Object System.Security.Principal.NTAccount($AccountName)).Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value
}

function Assert-QmRotationElevated {
    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'DEV2 machine-credential rotation requires an elevated Administrator token.'
    }
}

function Assert-QmRotationTargetNonAdministrator {
    param([Parameter(Mandatory = $true)][string]$TargetSid)
    $administrators = Get-LocalGroup -SID `
        (New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')) -ErrorAction Stop
    if (@(Get-LocalGroupMember -Group $administrators -ErrorAction Stop | Where-Object {
                $null -ne $_.SID -and $_.SID.Value -ceq $TargetSid
            }).Count -ne 0) {
        throw 'QMDev2 must not be a member of BUILTIN\Administrators.'
    }
}

function Get-QmRotationProcessOwnerSid {
    param([Parameter(Mandatory = $true)][object]$ProcessRecord)
    try {
        $owner = Invoke-CimMethod -InputObject $ProcessRecord -MethodName GetOwnerSid -ErrorAction Stop
        if ($owner.ReturnValue -eq 0) { return [string]$owner.Sid }
    } catch {
    }
    return $null
}

function Get-QmRotationDev2Processes {
    param([Parameter(Mandatory = $true)][string]$TargetSid)
    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -Property ProcessId,ExecutablePath,CreationDate -ErrorAction Stop)) {
        $pathMatch = -not [string]::IsNullOrWhiteSpace([string]$process.ExecutablePath) -and
            (Test-QmRotationPathWithin -Path ([string]$process.ExecutablePath) -Root $dev2Root)
        $ownerSid = Get-QmRotationProcessOwnerSid -ProcessRecord $process
        if ($pathMatch -or $ownerSid -ceq $TargetSid) {
            $rows.Add([pscustomobject]@{
                ProcessId = [int]$process.ProcessId
                ExecutablePath = if ([string]::IsNullOrWhiteSpace([string]$process.ExecutablePath)) { $null } else { [string]$process.ExecutablePath }
                CreationDate = $process.CreationDate
                OwnerSid = $ownerSid
            })
        }
    }
    return $rows.ToArray()
}

function Stop-QmRotationTargetProcesses {
    param([Parameter(Mandatory = $true)][string]$TargetSid)
    foreach ($candidate in @(Get-QmRotationDev2Processes -TargetSid $TargetSid)) {
        $fresh = @(Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($candidate.ProcessId)" `
                -Property ProcessId,ExecutablePath,CreationDate -ErrorAction SilentlyContinue)
        if ($fresh.Count -ne 1) { continue }
        $ownerSid = Get-QmRotationProcessOwnerSid -ProcessRecord $fresh[0]
        if ([string]$fresh[0].CreationDate -eq [string]$candidate.CreationDate -and $ownerSid -ceq $TargetSid) {
            Stop-Process -Id $candidate.ProcessId -Force -ErrorAction Stop
        }
    }
}

function Assert-QmRotationNoTasks {
    $tasks = @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
            $_.TaskName.StartsWith($taskPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($cleanupPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($profileTaskPrefix, [System.StringComparison]::Ordinal)
        })
    if ($tasks.Count -ne 0) { throw "DEV2 rotation found $($tasks.Count) pre-existing smoke/cleanup/profile-init task(s)." }
}

function Set-QmRotationDirectoryAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetSid,
        [Parameter(Mandatory = $true)][System.Security.AccessControl.FileSystemRights]$TargetRights
    )
    $acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) { [void]$acl.RemoveAccessRuleAll($rule) }
    $admin = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $system = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-18')
    $target = New-Object System.Security.Principal.SecurityIdentifier($TargetSid)
    $acl.SetOwner($admin)
    $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    foreach ($grant in @(
            @($admin, [System.Security.AccessControl.FileSystemRights]::FullControl),
            @($system, [System.Security.AccessControl.FileSystemRights]::FullControl),
            @($target, $TargetRights)
        )) {
        $access = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $grant[0], $grant[1], $inheritance, [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        [void]$acl.AddAccessRule($access)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop
}

function Assert-QmRotationDirectoryAcl {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$TargetSid,
        [Parameter(Mandatory = $true)][System.Security.AccessControl.FileSystemRights]$TargetRights
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    Assert-QmRotationNoReparseComponents -Path $full
    $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if (-not $item.PSIsContainer) { throw "Expected an exact rotation directory: $full" }
    $acl = Get-Acl -LiteralPath $full -ErrorAction Stop
    if (-not $acl.AreAccessRulesProtected -or
        (Resolve-QmRotationSid -AccountName $acl.Owner) -cne 'S-1-5-32-544') {
        throw "Rotation directory protection/owner drifted: $full"
    }
    $rules = @($acl.Access)
    if ($rules.Count -ne 3) { throw "Rotation directory must contain exactly three access rules: $full" }
    $expected = @{
        'S-1-5-32-544' = [System.Security.AccessControl.FileSystemRights]::FullControl
        'S-1-5-18' = [System.Security.AccessControl.FileSystemRights]::FullControl
        $TargetSid = $TargetRights
    }
    $inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor
        [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
    foreach ($rule in $rules) {
        $sid = Resolve-QmRotationSid -AccountName $rule.IdentityReference.Value
        if (-not $expected.ContainsKey($sid) -or -not $seen.Add($sid) -or
            $rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
            $rule.IsInherited -or [int64]$rule.FileSystemRights -ne [int64]$expected[$sid] -or
            $rule.InheritanceFlags -ne $inheritance -or
            $rule.PropagationFlags -ne [System.Security.AccessControl.PropagationFlags]::None) {
            throw "Rotation directory ACL rule drifted: $full"
        }
    }
}

function Write-QmRotationJsonAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Payload,
        [switch]$Replace
    )
    $parent = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Atomic JSON parent is missing: $parent" }
    $temporary = Join-Path $parent ('.rotation.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText(
            $temporary, ($Payload | ConvertTo-Json -Depth 8 -Compress), [System.Text.UTF8Encoding]::new($false)
        )
        [System.IO.File]::Move($temporary, $Path, $Replace.IsPresent)
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { [System.IO.File]::Delete($temporary) }
    }
}

function Write-QmCanonicalRotationReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Payload
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    if (-not $full.Equals($canonicalRotationReceiptPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Canonical rotation receipt path differs from the fixed DEV2 evidence path.'
    }
    $parent = [System.IO.Path]::GetDirectoryName($full)
    Assert-QmDev2CredentialExactAcl -Path $parent -Directory
    if (Test-Path -LiteralPath $full) {
        throw 'Canonical DEV2 machine-credential rotation receipt already exists.'
    }
    $temporary = Join-Path $parent ('.credential.machine-dpapi.rotation-receipt.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText(
            $temporary, ($Payload | ConvertTo-Json -Depth 8 -Compress), [System.Text.UTF8Encoding]::new($false)
        )
        Set-QmDev2CredentialExactAcl -Path $temporary
        Assert-QmDev2CredentialExactAcl -Path $temporary
        [System.IO.File]::Move($temporary, $full, $false)
        Assert-QmDev2CredentialExactAcl -Path $parent -Directory
        Assert-QmDev2CredentialExactAcl -Path $full
        return (Get-FileHash -LiteralPath $full -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { [System.IO.File]::Delete($temporary) }
    }
}

function Get-QmRotationJournalFieldNames {
    return @(
        'schema_version', 'artifact_type', 'rotation_id', 'nonce', 'phase', 'created_utc', 'updated_utc',
        'contract_id', 'lane', 'lane_contract_path', 'lane_contract_sha256',
        'target_account', 'target_sid', 'target_profile',
        'identity_probe_logon_type', 'identity_probe_run_level',
        'credential_staged_path', 'credential_final_path', 'credential_sha256', 'credential_generation_id',
        'credential_helper_path', 'credential_helper_sha256',
        'identity_probe_child_path', 'identity_probe_child_sha256',
        'identity_probe_request_path', 'identity_probe_request_sha256',
        'identity_probe_result_path', 'identity_probe_result_sha256',
        'identity_proof_completed_utc', 'identity_proof_verified',
        'target_task_name', 'cleanup_task_name', 'cleanup_action_mutex',
        'cleanup_lease_path', 'cleanup_lease_sha256', 'cleanup_helper_path', 'cleanup_helper_sha256',
        'tester_groups_source_path', 'tester_groups_target_path', 'tester_groups_sha256',
        'cleanup_result_path', 'cleanup_disarm_path', 'cleanup_result_sha256', 'cleanup_disarm_sha256',
        'cleanup_result_failure_archive_sha256', 'cleanup_disarm_failure_archive_sha256',
        'legacy_credential_path', 'legacy_credential_sha256', 'legacy_credential_preserved',
        'dynamic_receipt_path', 'canonical_receipt_path', 'receipt_completed_utc'
    )
}

function Read-QmRotationBoundFileBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$ExpectedSha256,
        [ValidateRange(1, 1048576)][int]$MinimumBytes = 1,
        [ValidateRange(1, 1048576)][int]$MaximumBytes = 1048576
    )
    if ($MinimumBytes -gt $MaximumBytes) { throw 'Bound-file minimum size exceeds its maximum size.' }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256) -and $ExpectedSha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw 'Expected bound-file SHA-256 is invalid.'
    }
    $full = ConvertTo-QmRotationFullPath -Path $Path
    Assert-QmRotationNoReparseComponents -Path $full
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Bound input is not a file: $full" }
    $stream = [System.IO.File]::Open(
        $full,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::None
    )
    try {
        if ($stream.Length -lt $MinimumBytes -or $stream.Length -gt $MaximumBytes) {
            throw "Bound input size is outside its strict bound: $full"
        }
        $bytes = [byte[]]::new([int]$stream.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) { throw "Bound input ended before its declared length: $full" }
            $offset += $read
        }
    } finally {
        $stream.Dispose()
    }
    $digest = [System.Security.Cryptography.SHA256]::HashData($bytes)
    try {
        $actualSha256 = ([System.BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
    } finally {
        [System.Array]::Clear($digest, 0, $digest.Length)
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedSha256) -and $actualSha256 -cne $ExpectedSha256) {
        [System.Array]::Clear($bytes, 0, $bytes.Length)
        throw "Exact input bytes differ from their sealed SHA-256 binding: $full"
    }
    Assert-QmRotationNoReparseComponents -Path $full
    return [pscustomobject]@{
        Path = $full
        Sha256 = $actualSha256
        Bytes = $bytes
    }
}

function Read-QmRotationExactJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$ExpectedFields,
        [string]$ExpectedSha256,
        [System.Collections.IDictionary]$ExpectedValueKinds,
        [ValidateRange(2, 1048576)][int]$MaximumBytes = 262144
    )
    if ($null -ne $ExpectedValueKinds -and
        [string]::Join('|', @($ExpectedValueKinds.Keys | ForEach-Object { [string]$_ } | Sort-Object)) -cne
        [string]::Join('|', @($ExpectedFields | Sort-Object))) {
        throw 'Exact JSON ValueKind schema must cover exactly the expected fields.'
    }
    $byteRecord = Read-QmRotationBoundFileBytes -Path $Path -ExpectedSha256 $ExpectedSha256 `
        -MinimumBytes 2 -MaximumBytes $MaximumBytes
    $full = $byteRecord.Path
    try {
        $json = [System.Text.UTF8Encoding]::new($false, $true).GetString($byteRecord.Bytes)
    } finally {
        [System.Array]::Clear($byteRecord.Bytes, 0, $byteRecord.Bytes.Length)
    }
    $document = [System.Text.Json.JsonDocument]::Parse($json)
    try {
        if ($document.RootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) {
            throw "Exact JSON payload is not an object: $full"
        }
        $names = New-Object System.Collections.Generic.List[string]
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        foreach ($property in $document.RootElement.EnumerateObject()) {
            if (-not $seen.Add($property.Name)) { throw "Exact JSON contains a duplicate property: $full" }
            $names.Add($property.Name)
            if ($null -ne $ExpectedValueKinds) {
                $expectedKind = [string]$ExpectedValueKinds[$property.Name]
                $kindMatches = switch -CaseSensitive ($expectedKind) {
                    'String' { $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::String; break }
                    'Int32' {
                        $integerValue = 0
                        $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Number -and
                            $property.Value.TryGetInt32([ref]$integerValue)
                        break
                    }
                    'Boolean' {
                        $property.Value.ValueKind -in @(
                            [System.Text.Json.JsonValueKind]::True,
                            [System.Text.Json.JsonValueKind]::False
                        )
                        break
                    }
                    'Array' { $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Array; break }
                    'Object' { $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Object; break }
                    'Null' { $property.Value.ValueKind -eq [System.Text.Json.JsonValueKind]::Null; break }
                    default { throw "Unsupported exact JSON ValueKind contract '$expectedKind'." }
                }
                if (-not $kindMatches) {
                    throw "Exact JSON property '$($property.Name)' has the wrong primitive ValueKind: $full"
                }
            }
        }
        if ([string]::Join('|', @($names.ToArray() | Sort-Object)) -cne
            [string]::Join('|', @($ExpectedFields | Sort-Object))) {
            throw "Exact JSON fields differ from their sealed schema: $full"
        }
    } finally {
        $document.Dispose()
    }
    $payload = $json | ConvertFrom-Json -DateKind String -ErrorAction Stop
    return [pscustomobject]@{
        Path = $full
        Sha256 = $byteRecord.Sha256
        Json = $json
        Payload = $payload
    }
}

function Write-QmRotationJournalExact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Payload,
        [switch]$Replace
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    $parent = [System.IO.Path]::GetDirectoryName($full)
    Assert-QmRotationNoReparseComponents -Path $parent
    if (-not $Replace.IsPresent -and (Test-Path -LiteralPath $full)) {
        throw 'Fresh rotation journal path already exists.'
    }
    $temporary = Join-Path $parent ('.rotation-journal.' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [System.IO.File]::WriteAllText(
            $temporary, ($Payload | ConvertTo-Json -Depth 8 -Compress), [System.Text.UTF8Encoding]::new($false)
        )
        Set-QmDev2CredentialExactAcl -Path $temporary
        [System.IO.File]::Move($temporary, $full, $Replace.IsPresent)
        Assert-QmDev2CredentialExactAcl -Path $full
    } finally {
        if (Test-Path -LiteralPath $temporary -PathType Leaf) { [System.IO.File]::Delete($temporary) }
    }
}

function Assert-QmRotationAdminControlledSourceFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$ForbiddenWriterSid
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    Assert-QmRotationNoReparseComponents -Path $full
    $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    if ($item.PSIsContainer) { throw "Expected an administrator-controlled source file: $full" }
    $acl = Get-Acl -LiteralPath $full -ErrorAction Stop
    if ((Resolve-QmRotationSid -AccountName $acl.Owner) -cne 'S-1-5-32-544') {
        throw "Administrator-controlled source owner drifted: $full"
    }
    $writeMask = [System.Security.AccessControl.FileSystemRights]::Write -bor
        [System.Security.AccessControl.FileSystemRights]::Modify -bor
        [System.Security.AccessControl.FileSystemRights]::Delete -bor
        [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
        [System.Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach ($rule in @($acl.Access)) {
        if ($rule.AccessControlType -ne [System.Security.AccessControl.AccessControlType]::Allow -or
            ([int64]$rule.FileSystemRights -band [int64]$writeMask) -eq 0) { continue }
        $writerSid = Resolve-QmRotationSid -AccountName $rule.IdentityReference.Value
        if (-not [string]::IsNullOrWhiteSpace($ForbiddenWriterSid) -and $writerSid -ceq $ForbiddenWriterSid) {
            throw "DEV2 target identity can write a sealed rotation source: $full"
        }
    }
}

function Get-QmRotationRecoveryDisposition {
    param(
        [Parameter(Mandatory = $true)][string]$Phase,
        [Parameter(Mandatory = $true)][bool]$IdentityProofVerified,
        [Parameter(Mandatory = $true)][bool]$StagedCredentialExists,
        [Parameter(Mandatory = $true)][bool]$FinalCredentialExists,
        [Parameter(Mandatory = $true)][bool]$CanonicalReceiptExists
    )
    $preProofPhases = @('PREPARED', 'CLEANUP_LEASE_ARMED', 'PASSWORD_SET')
    $postProofPhases = @(
        'IDENTITY_PROVED', 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF',
        'FINAL_CONTAINMENT_VERIFIED', 'READY_FOR_CANONICAL_RECEIPT', 'COMMITTED'
    )
    $rollbackPhases = @(
        'PASSWORD_ROLLBACK_INTENT_FORENSICALLY_BOUND',
        'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND',
        'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR'
    )
    if ($Phase -eq 'PRE_PROOF_CONTAINED_RETRY_CLEAR') {
        if ($IdentityProofVerified -or $CanonicalReceiptExists -or $FinalCredentialExists) {
            throw 'Retry-clear pre-proof recovery contains proof or canonical publication state.'
        }
        return 'CONTAIN_PRE_PROOF_RETRY_CLEAR'
    }
    if ($Phase -eq 'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR') {
        if (-not $IdentityProofVerified -or $CanonicalReceiptExists -or $FinalCredentialExists) {
            throw 'Retry-clear invalidated-proof recovery has inconsistent proof/publication state.'
        }
        return 'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR'
    }
    if ($Phase -in $rollbackPhases) {
        if ($CanonicalReceiptExists) {
            throw 'Password-rollback recovery forbids canonical success-receipt publication.'
        }
        return 'CONTAIN_ROLLBACK_RETRY_CLEAR'
    }
    if ($Phase -in $preProofPhases) {
        if ($IdentityProofVerified -or $CanonicalReceiptExists) {
            throw 'Pre-proof recovery state contains post-proof evidence.'
        }
        return 'CONTAIN_PRE_PROOF_FORENSIC_ONLY'
    }
    if ($Phase -notin $postProofPhases -or -not $IdentityProofVerified) {
        throw 'Rotation journal phase is not eligible for proof-bound recovery.'
    }
    if ($StagedCredentialExists -and $FinalCredentialExists) {
        throw 'Both staged and canonical machine credentials exist during recovery.'
    }
    if ($Phase -eq 'IDENTITY_PROVED') {
        if (-not $StagedCredentialExists -and -not $FinalCredentialExists) {
            throw 'Identity-proved recovery has no bound machine credential artifact.'
        }
        if ($CanonicalReceiptExists) {
            throw 'Canonical receipt exists before the journal reached receipt-ready state.'
        }
        return $(if ($StagedCredentialExists) { 'FINALIZE_PROVED_STAGED' } else { 'FINALIZE_PROVED_PUBLISHED' })
    }
    if ($StagedCredentialExists -or -not $FinalCredentialExists) {
        throw 'Published recovery phase does not have exactly the canonical credential.'
    }
    if ($Phase -in @('CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF', 'FINAL_CONTAINMENT_VERIFIED') -and
        $CanonicalReceiptExists) {
        throw 'Canonical receipt exists before the journal reached receipt-ready state.'
    }
    if ($Phase -eq 'COMMITTED' -and -not $CanonicalReceiptExists) {
        throw 'Committed rotation journal is missing its canonical receipt.'
    }
    return $(if ($CanonicalReceiptExists) { 'VALIDATE_COMMITTED_RECEIPT' } else { 'FINALIZE_PROVED_PUBLISHED' })
}

function Assert-QmRotationJournalSchema {
    param([Parameter(Mandatory = $true)][object]$Journal)
    $actualFields = @($Journal.PSObject.Properties.Name | Sort-Object)
    $expectedFields = @(Get-QmRotationJournalFieldNames | Sort-Object)
    if ([string]::Join('|', $actualFields) -cne [string]::Join('|', $expectedFields)) {
        throw 'Rotation recovery journal fields differ from the exact schema.'
    }
    $allHashes = @(
        'lane_contract_sha256', 'credential_sha256', 'credential_helper_sha256',
        'identity_probe_child_sha256', 'identity_probe_request_sha256', 'cleanup_lease_sha256',
        'cleanup_helper_sha256', 'tester_groups_sha256', 'legacy_credential_sha256'
    )
    foreach ($name in $allHashes) {
        if ([string]$Journal.$name -cnotmatch '^[0-9a-f]{64}$') { throw "Rotation journal has an invalid sealed hash: $name" }
    }
    foreach ($name in @(
            'cleanup_result_sha256', 'cleanup_disarm_sha256',
            'cleanup_result_failure_archive_sha256', 'cleanup_disarm_failure_archive_sha256'
        )) {
        if ($null -ne $Journal.$name -and [string]$Journal.$name -cnotmatch '^[0-9a-f]{64}$') {
            throw "Rotation journal has an invalid nullable cleanup-evidence hash: $name"
        }
    }
    if ([int]$Journal.schema_version -ne $journalSchemaVersion -or
        [string]$Journal.artifact_type -cne $journalArtifactType -or
        [string]$Journal.rotation_id -cnotmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$' -or
        [string]$Journal.nonce -cnotmatch '^[0-9a-f]{32}$' -or
        [string]$Journal.contract_id -cne $contractId -or [string]$Journal.lane -cne $lane -or
        [string]$Journal.target_account -cne "$env:COMPUTERNAME\$targetUserName" -or
        [string]$Journal.target_sid -cnotmatch '^S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+$' -or
        [string]$Journal.identity_probe_logon_type -cne 'Password' -or
        [string]$Journal.identity_probe_run_level -cne 'Limited' -or
        [string]$Journal.credential_generation_id -cnotmatch '^[0-9a-f]{32}$' -or
        [string]$Journal.target_task_name -cnotmatch '^QM_DEV2_SMOKE_[0-9a-f]{32}$' -or
        [string]$Journal.cleanup_task_name -cnotmatch '^QM_DEV2_CLEANUP_[0-9a-f]{32}$' -or
        [string]$Journal.cleanup_action_mutex -cne ($cleanupActionMutexPrefix + [string]$Journal.nonce) -or
        $Journal.legacy_credential_preserved -isnot [bool] -or -not [bool]$Journal.legacy_credential_preserved -or
        $Journal.identity_proof_verified -isnot [bool]) {
        throw 'Rotation recovery journal identity/schema binding drifted.'
    }
    $created = [DateTimeOffset]::MinValue
    $updated = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$Journal.created_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$created) -or
        -not [DateTimeOffset]::TryParseExact([string]$Journal.updated_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$updated) -or
        $created.Offset -ne [TimeSpan]::Zero -or $updated.Offset -ne [TimeSpan]::Zero -or $updated -lt $created -or
        $created -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        throw 'Rotation recovery journal chronology is invalid.'
    }
    $postProof = [string]$Journal.phase -in @(
        'IDENTITY_PROVED', 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF',
        'FINAL_CONTAINMENT_VERIFIED', 'READY_FOR_CANONICAL_RECEIPT', 'COMMITTED',
        'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR'
    )
    $rollback = [string]$Journal.phase -in @(
        'PASSWORD_ROLLBACK_INTENT_FORENSICALLY_BOUND',
        'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND',
        'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR'
    )
    if ($postProof) {
        if (-not [bool]$Journal.identity_proof_verified -or
            [string]$Journal.identity_probe_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            [string]::IsNullOrWhiteSpace([string]$Journal.identity_proof_completed_utc)) {
            throw 'Post-proof rotation journal lacks exact identity proof bindings.'
        }
    } elseif ($rollback) {
        if ([bool]$Journal.identity_proof_verified) {
            if ([string]$Journal.identity_probe_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
                [string]::IsNullOrWhiteSpace([string]$Journal.identity_proof_completed_utc)) {
                throw 'Password-rollback journal has an incomplete prior identity-proof binding.'
            }
        } elseif ($null -ne $Journal.identity_probe_result_sha256 -or
            $null -ne $Journal.identity_proof_completed_utc) {
            throw 'Password-rollback journal has partial identity-proof fields.'
        }
    } elseif ([string]$Journal.phase -in @(
            'PREPARED', 'CLEANUP_LEASE_ARMED', 'PASSWORD_SET', 'PRE_PROOF_CONTAINED_RETRY_CLEAR'
        )) {
        if ([bool]$Journal.identity_proof_verified -or $null -ne $Journal.identity_probe_result_sha256 -or
            $null -ne $Journal.identity_proof_completed_utc -or $null -ne $Journal.receipt_completed_utc) {
            throw 'Pre-proof rotation journal contains proof or receipt bindings.'
        }
    } else {
        throw 'Rotation recovery journal phase is outside the exact recovery state machine.'
    }
    if ([string]$Journal.phase -in @('FINAL_CONTAINMENT_VERIFIED', 'READY_FOR_CANONICAL_RECEIPT', 'COMMITTED')) {
        $receiptTime = [DateTimeOffset]::MinValue
        if (-not [DateTimeOffset]::TryParseExact([string]$Journal.receipt_completed_utc, 'o', [cultureinfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$receiptTime) -or
            $receiptTime.Offset -ne [TimeSpan]::Zero -or $receiptTime -lt $created) {
            throw 'Receipt-ready rotation journal has an invalid deterministic receipt time.'
        }
        if ([string]$Journal.cleanup_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            [string]$Journal.cleanup_disarm_sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Receipt-ready rotation journal lacks sealed cleanup success evidence hashes.'
        }
    } elseif ([string]$Journal.phase -in @(
            'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR',
            'PRE_PROOF_CONTAINED_RETRY_CLEAR',
            'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR'
        )) {
        if ($null -ne $Journal.receipt_completed_utc -or
            [string]$Journal.cleanup_result_sha256 -cnotmatch '^[0-9a-f]{64}$' -or
            [string]$Journal.cleanup_disarm_sha256 -cnotmatch '^[0-9a-f]{64}$') {
            throw 'Retry-clear password-rollback journal lacks sealed containment evidence or claims a success receipt.'
        }
    } elseif ($null -ne $Journal.receipt_completed_utc) {
        throw 'Pre-finalization rotation journal already contains a receipt time.'
    } elseif ($null -ne $Journal.cleanup_result_sha256 -or $null -ne $Journal.cleanup_disarm_sha256 -or
        $null -ne $Journal.cleanup_result_failure_archive_sha256 -or
        $null -ne $Journal.cleanup_disarm_failure_archive_sha256) {
        throw 'Pre-finalization rotation journal already contains cleanup evidence hashes.'
    }
}

function Test-QmRotationRetryClearPhase {
    param([Parameter(Mandatory = $true)][string]$Phase)
    return $Phase -in @(
        'PRE_PROOF_CONTAINED_RETRY_CLEAR',
        'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR',
        'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR'
    )
}

function Get-QmRotationJournalHistory {
    param([switch]$RequireExactAcl)
    if (-not (Test-Path -LiteralPath $rotationRoot -PathType Container)) { return }
    Assert-QmRotationNoReparseComponents -Path $rotationRoot
    $history = New-Object System.Collections.Generic.List[object]
    foreach ($directory in @(Get-ChildItem -LiteralPath $rotationRoot -Directory -Force -ErrorAction Stop | Where-Object {
                $_.Name -cmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$'
            })) {
        $journalPathLocal = Join-Path $directory.FullName 'control\rotation_journal.json'
        if (-not (Test-Path -LiteralPath $journalPathLocal -PathType Leaf)) { continue }
        Assert-QmRotationNoReparseComponents -Path $journalPathLocal
        if ($RequireExactAcl.IsPresent) { Assert-QmDev2CredentialExactAcl -Path $journalPathLocal }
        $record = Read-QmRotationExactJsonFile -Path $journalPathLocal `
            -ExpectedFields (Get-QmRotationJournalFieldNames) -MaximumBytes 131072
        Assert-QmRotationJournalSchema -Journal $record.Payload
        if ($directory.Name -cne [string]$record.Payload.rotation_id) {
            throw 'Rotation history directory differs from its exact journal rotation ID.'
        }
        $history.Add([pscustomobject]@{
                RunDirectory = [System.IO.Path]::GetFullPath($directory.FullName)
                JournalPath = [System.IO.Path]::GetFullPath($journalPathLocal)
                Journal = $record.Payload
                JournalSha256 = [string]$record.Sha256
            })
    }
    return $history.ToArray()
}

function Assert-QmRotationFreshApplyHistory {
    $history = @(Get-QmRotationJournalHistory -RequireExactAcl)
    foreach ($entry in $history) {
        $journal = $entry.Journal
        if (-not (Test-QmRotationRetryClearPhase -Phase ([string]$journal.phase))) {
            throw "Fresh rotation is blocked by unresolved history: $([string]$journal.rotation_id) [$([string]$journal.phase)]."
        }
        if (-not (ConvertTo-QmRotationFullPath -Path ([string]$journal.credential_final_path)).Equals(
                $credentialPath, [System.StringComparison]::OrdinalIgnoreCase
            ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$journal.canonical_receipt_path)).Equals(
                $canonicalRotationReceiptPath, [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw 'Retry-clear rotation history escaped its fixed canonical paths.'
        }
        if (Test-Path -LiteralPath $credentialPath -PathType Leaf) {
            throw 'Retry-clear rotation history conflicts with a canonical machine credential.'
        }
        if (Test-Path -LiteralPath $canonicalRotationReceiptPath -PathType Leaf) {
            throw 'Retry-clear rotation history conflicts with a canonical success receipt.'
        }
        Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
    }
    return $history.Count
}

function Assert-QmRotationResumeHasNoLaterAttempt {
    param(
        [Parameter(Mandatory = $true)][object]$CurrentJournal,
        [Parameter(Mandatory = $true)][string]$CurrentRunDirectory
    )
    $currentCreated = [DateTimeOffset]::ParseExact(
        [string]$CurrentJournal.created_utc,
        'o',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::RoundtripKind
    )
    foreach ($entry in @(Get-QmRotationJournalHistory -RequireExactAcl)) {
        if ([string]$entry.Journal.rotation_id -ceq [string]$CurrentJournal.rotation_id) {
            if (-not ([string]$entry.RunDirectory).Equals(
                    (ConvertTo-QmRotationFullPath -Path $CurrentRunDirectory),
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                throw 'Duplicate rotation ID exists in a different recovery directory.'
            }
            continue
        }
        $otherCreated = [DateTimeOffset]::ParseExact(
            [string]$entry.Journal.created_utc,
            'o',
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        )
        if ($otherCreated -ge $currentCreated) {
            throw "Recovery refuses a proof history superseded by another rotation attempt: $([string]$entry.Journal.rotation_id)."
        }
    }
}

function New-QmRotationPassword {
    $bytes = New-Object byte[] 48
    try {
        [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
        return 'Qm2!aA9-' + [System.Convert]::ToBase64String($bytes)
    } finally {
        [System.Array]::Clear($bytes, 0, $bytes.Length)
    }
}

function Assert-QmRotationTaskContract {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)][string]$ExpectedTaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedAccount,
        [Parameter(Mandatory = $true)][string]$ExpectedSid,
        [Parameter(Mandatory = $true)][string]$ExpectedArguments,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingDirectory
    )
    if ($Task.TaskName -cne $ExpectedTaskName -or $Task.TaskPath -cne $taskPath -or
        (Resolve-QmRotationSid -AccountName $Task.Principal.UserId) -cne $ExpectedSid -or
        $Task.Principal.LogonType.ToString() -cne 'Password' -or
        $Task.Principal.RunLevel.ToString() -cne 'Limited' -or $null -ne $Task.Triggers -or
        @($Task.Actions).Count -ne 1 -or $Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew') {
        throw 'DEV2 rotation identity-probe task drifted from Password/Limited/triggerless.'
    }
    $action = @($Task.Actions)[0]
    if (-not (ConvertTo-QmRotationFullPath -Path $action.Execute).Equals($pwshPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$action.Arguments -cne $ExpectedArguments -or
        -not (ConvertTo-QmRotationFullPath -Path $action.WorkingDirectory).Equals(
            $ExpectedWorkingDirectory, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'DEV2 rotation identity-probe task action drifted.'
    }
}

function Assert-QmRotationCleanupTaskContract {
    param(
        [Parameter(Mandatory = $true)]$Task,
        [Parameter(Mandatory = $true)][string]$ExpectedTaskName,
        [Parameter(Mandatory = $true)][string]$ExpectedArguments,
        [Parameter(Mandatory = $true)][string]$ExpectedWorkingDirectory
    )
    $principalSid = Resolve-QmRotationSid -AccountName $Task.Principal.UserId
    if ($Task.TaskName -cne $ExpectedTaskName -or $Task.TaskPath -cne $taskPath -or
        $principalSid -cne 'S-1-5-18' -or $Task.Principal.LogonType.ToString() -cne 'ServiceAccount' -or
        $Task.Principal.RunLevel.ToString() -cne 'Highest' -or @($Task.Actions).Count -ne 1 -or
        @($Task.Triggers).Count -ne 2 -or $Task.Settings.MultipleInstances.ToString() -cne 'IgnoreNew') {
        throw 'DEV2 rotation cleanup task drifted from the SYSTEM/Highest/two-trigger lease contract.'
    }
    $action = @($Task.Actions)[0]
    if (-not (ConvertTo-QmRotationFullPath -Path $action.Execute).Equals($pwshPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]$action.Arguments -cne $ExpectedArguments -or
        -not (ConvertTo-QmRotationFullPath -Path $action.WorkingDirectory).Equals(
            $ExpectedWorkingDirectory, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'DEV2 rotation cleanup task action drifted before account mutation.'
    }
}

function Remove-QmRotationScheduledTaskBounded {
    param(
        [Parameter(Mandatory = $true)][string]$TaskName,
        [switch]$DisableBeforeStop,
        [ValidateRange(10, 300000)][int]$TimeoutMilliseconds = 30000,
        [ValidateRange(1, 5000)][int]$PollMilliseconds = 200
    )
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -eq $task) { return }
    if ($task.TaskName -cne $TaskName -or $task.TaskPath -cne $taskPath) {
        throw "Bounded task drain observed task identity drift: $TaskName"
    }
    if ($DisableBeforeStop.IsPresent) {
        Disable-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop | Out-Null
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    }
    if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction Stop
    }
    $nonRunningDeadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($null -eq $task -or $task.State.ToString() -ne 'Running') { break }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $nonRunningDeadline)
    if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
        throw "Bounded task drain timed out waiting for a non-running task: $TaskName"
    }
    if ($null -ne $task) {
        Unregister-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
    }
    $absenceDeadline = [DateTimeOffset]::UtcNow.AddMilliseconds($TimeoutMilliseconds)
    do {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
        if ($null -eq $task) { break }
        Start-Sleep -Milliseconds $PollMilliseconds
    } while ([DateTimeOffset]::UtcNow -lt $absenceDeadline)
    if ($null -ne $task) {
        throw "Bounded task drain timed out waiting for task absence: $TaskName"
    }
}

function Enter-QmRotationCleanupActionMutex {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $cleanupActionMutexWaitMilliseconds
    )
    if ($Name -cnotmatch '^Global\\QM_DEV2_CLEANUP_ACTION_[0-9a-f]{32}$') {
        throw 'Cleanup action mutex name is outside the exact per-run namespace.'
    }
    $handle = New-Object System.Threading.Mutex($false, $Name)
    $acquired = $false
    $abandoned = $false
    try {
        try {
            $acquired = [bool]$handle.WaitOne($TimeoutMilliseconds)
        } catch {
            $cursor = $_.Exception
            while ($null -ne $cursor -and $cursor -isnot [System.Threading.AbandonedMutexException]) {
                $cursor = $cursor.InnerException
            }
            if ($null -eq $cursor) { throw }
            $acquired = $true
            $abandoned = $true
        }
        if (-not $acquired) {
            throw 'Timed out waiting for per-run cleanup action completion; recovery remains fail-closed.'
        }
        return [pscustomobject]@{
            Handle = $handle
            Acquired = $true
            Abandoned = $abandoned
            Name = $Name
        }
    } catch {
        $handle.Dispose()
        throw
    }
}

function Exit-QmRotationCleanupActionMutex {
    param([AllowNull()][object]$Fence)
    if ($null -eq $Fence) { return }
    try {
        if ([bool]$Fence.Acquired) { $Fence.Handle.ReleaseMutex() }
    } finally {
        $Fence.Handle.Dispose()
    }
}

function New-QmRotationCanonicalReceiptPayload {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [Parameter(Mandatory = $true)][string]$CredentialSha256
    )
    return [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_MACHINE_CREDENTIAL_ROTATION_RECEIPT'
        status = 'PASS'
        completed_utc = [string]$Journal.receipt_completed_utc
        contract_id = [string]$Journal.contract_id
        target_account = [string]$Journal.target_account
        target_sid = [string]$Journal.target_sid
        target_disabled_at_rest = $true
        target_password_required_at_rest = $true
        machine_credential_path = [string]$Journal.credential_final_path
        machine_credential_sha256 = $CredentialSha256
        machine_credential_generation_id = [string]$Journal.credential_generation_id
        machine_credential_helper_path = [string]$Journal.credential_helper_path
        machine_credential_helper_sha256 = [string]$Journal.credential_helper_sha256
        identity_probe_child_path = [string]$Journal.identity_probe_child_path
        identity_probe_child_sha256 = [string]$Journal.identity_probe_child_sha256
        identity_probe_result_path = [string]$Journal.identity_probe_result_path
        identity_probe_result_sha256 = [string]$Journal.identity_probe_result_sha256
        identity_probe_logon_type = 'Password'
        identity_probe_run_level = 'Limited'
        machine_credential_matches_proved_password = $true
        published_after_identity_proof = $true
        legacy_credential_path = [string]$Journal.legacy_credential_path
        legacy_credential_preserved = $true
        cleanup_lease_disarmed = $true
        owner_process_count = 0
        dev2_root_process_count = 0
    }
}

function Assert-QmRotationReceiptExact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$ExpectedPayload,
        [switch]$RequireExactAcl
    )
    $full = ConvertTo-QmRotationFullPath -Path $Path
    Assert-QmRotationNoReparseComponents -Path $full
    if ($RequireExactAcl.IsPresent) { Assert-QmDev2CredentialExactAcl -Path $full }
    $expectedJson = $ExpectedPayload | ConvertTo-Json -Depth 8 -Compress
    $expectedFields = @($ExpectedPayload.Keys | ForEach-Object { [string]$_ })
    $record = Read-QmRotationExactJsonFile -Path $full -ExpectedFields $expectedFields -MaximumBytes 65536
    if ([string]$record.Json -cne $expectedJson) {
        throw "Rotation receipt bytes differ from the proof-bound exact payload: $full"
    }
    return [string]$record.Sha256
}

function Assert-QmRotationIdentityProofBindings {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [Parameter(Mandatory = $true)][string]$RunDirectory
    )
    $requestPath = ConvertTo-QmRotationFullPath -Path ([string]$Journal.identity_probe_request_path)
    $resultPath = ConvertTo-QmRotationFullPath -Path ([string]$Journal.identity_probe_result_path)
    $expectedRequestPath = Join-Path $RunDirectory 'control\identity_probe_request.json'
    $expectedResultPath = Join-Path $RunDirectory 'output\identity_probe_result.json'
    if (-not $requestPath.Equals($expectedRequestPath, [System.StringComparison]::OrdinalIgnoreCase) -or
        -not $resultPath.Equals($expectedResultPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Rotation journal request/result paths escaped their exact run directories.'
    }
    Assert-QmDev2CredentialExactAcl -Path $requestPath
    Assert-QmDev2CredentialExactAcl -Path $resultPath
    $requestFields = @(
        'artifact_type', 'created_utc', 'expected_account', 'expected_profile', 'expected_sid',
        'expected_task_name', 'expires_utc', 'nonce', 'result_path', 'schema_version'
    )
    $requestValueKinds = [ordered]@{
        artifact_type = 'String'
        created_utc = 'String'
        expected_account = 'String'
        expected_profile = 'String'
        expected_sid = 'String'
        expected_task_name = 'String'
        expires_utc = 'String'
        nonce = 'String'
        result_path = 'String'
        schema_version = 'Int32'
    }
    $requestRecord = Read-QmRotationExactJsonFile -Path $requestPath -ExpectedFields $requestFields `
        -ExpectedSha256 ([string]$Journal.identity_probe_request_sha256) `
        -ExpectedValueKinds $requestValueKinds -MaximumBytes 32768
    $request = $requestRecord.Payload
    if ([int]$request.schema_version -ne 1 -or [string]$request.artifact_type -cne 'QM_DEV2_IDENTITY_PROBE_REQUEST' -or
        [string]$request.nonce -cne [string]$Journal.nonce -or
        [string]$request.expected_account -cne [string]$Journal.target_account -or
        [string]$request.expected_sid -cne [string]$Journal.target_sid -or
        [string]$request.expected_task_name -cne [string]$Journal.target_task_name -or
        -not (ConvertTo-QmRotationFullPath -Path ([string]$request.expected_profile)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.target_profile)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$request.result_path)).Equals(
            $resultPath, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Rotation identity request differs from its sealed journal bindings.'
    }
    $requestCreated = [DateTimeOffset]::MinValue
    $requestExpires = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$request.created_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$requestCreated) -or
        -not [DateTimeOffset]::TryParseExact([string]$request.expires_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$requestExpires) -or
        $requestCreated.Offset -ne [TimeSpan]::Zero -or $requestExpires.Offset -ne [TimeSpan]::Zero -or
        $requestExpires -le $requestCreated -or $requestExpires -gt $requestCreated.AddMinutes(15)) {
        throw 'Rotation identity request chronology differs from the exact proof window.'
    }
    $resultFields = @(
        'account', 'artifact_type', 'completed_utc', 'limited_non_admin', 'nonce',
        'profile', 'request_sha256', 'schema_version', 'sid', 'status'
    )
    $resultValueKinds = [ordered]@{
        account = 'String'
        artifact_type = 'String'
        completed_utc = 'String'
        limited_non_admin = 'Boolean'
        nonce = 'String'
        profile = 'String'
        request_sha256 = 'String'
        schema_version = 'Int32'
        sid = 'String'
        status = 'String'
    }
    $resultRecord = Read-QmRotationExactJsonFile -Path $resultPath -ExpectedFields $resultFields `
        -ExpectedSha256 ([string]$Journal.identity_probe_result_sha256) `
        -ExpectedValueKinds $resultValueKinds -MaximumBytes 32768
    $result = $resultRecord.Payload
    if ([int]$result.schema_version -ne 1 -or [string]$result.artifact_type -cne 'QM_DEV2_IDENTITY_PROBE_RESULT' -or
        [string]$result.status -cne 'PASS' -or [string]$result.nonce -cne [string]$Journal.nonce -or
        [string]$result.account -cne [string]$Journal.target_account -or [string]$result.sid -cne [string]$Journal.target_sid -or
        $result.limited_non_admin -isnot [bool] -or -not [bool]$result.limited_non_admin -or
        [string]$result.request_sha256 -cne [string]$Journal.identity_probe_request_sha256 -or
        -not (ConvertTo-QmRotationFullPath -Path ([string]$result.profile)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.target_profile)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or [string]$result.completed_utc -cne [string]$Journal.identity_proof_completed_utc) {
        throw 'Rotation identity result differs from its exact proof/journal bindings.'
    }
    $completed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$result.completed_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$completed) -or
        $completed.Offset -ne [TimeSpan]::Zero -or $completed -lt $requestCreated -or $completed -gt $requestExpires) {
        throw 'Rotation identity result completion escaped the sealed request window.'
    }
    if ((Get-FileHash -LiteralPath $requestPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
        [string]$Journal.identity_probe_request_sha256 -or
        (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
        [string]$Journal.identity_probe_result_sha256) {
        throw 'Rotation identity request/result changed after semantic validation.'
    }
    return [pscustomobject]@{
        Request = $request
        Result = $result
        CompletedUtc = $completed
    }
}

function Assert-QmRotationCleanupLeaseBindings {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [Parameter(Mandatory = $true)][string]$RunDirectory
    )
    $leasePath = ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_lease_path)
    if (-not $leasePath.Equals((Join-Path $RunDirectory 'control\cleanup_lease.json'), [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Rotation cleanup lease path escaped its exact run directory.'
    }
    Assert-QmDev2CredentialExactAcl -Path $leasePath
    foreach ($exactFile in @([string]$Journal.cleanup_helper_path, [string]$Journal.tester_groups_source_path)) {
        Assert-QmDev2CredentialExactAcl -Path (ConvertTo-QmRotationFullPath -Path $exactFile)
    }
    $leaseFields = @(
        'artifact_type', 'cleanup_action_mutex', 'cleanup_task_name', 'created_utc', 'dev2_root', 'disarm_result_path',
        'expected_sid', 'expires_utc', 'helper_path', 'helper_sha256', 'nonce', 'result_path',
        'run_directory', 'run_id', 'schema_version', 'target_task_name', 'tester_groups_sha256',
        'tester_groups_source_path', 'tester_groups_target_path'
    )
    $leaseRecord = Read-QmRotationExactJsonFile -Path $leasePath -ExpectedFields $leaseFields `
        -ExpectedSha256 ([string]$Journal.cleanup_lease_sha256) -MaximumBytes 65536
    $lease = $leaseRecord.Payload
    if ([int]$lease.schema_version -ne 1 -or [string]$lease.artifact_type -cne 'QM_DEV2_ACCOUNT_CLEANUP_LEASE' -or
        [string]$lease.run_id -cne [string]$Journal.rotation_id -or [string]$lease.nonce -cne [string]$Journal.nonce -or
        [string]$lease.expected_sid -cne [string]$Journal.target_sid -or
        [string]$lease.target_task_name -cne [string]$Journal.target_task_name -or
        [string]$lease.cleanup_task_name -cne [string]$Journal.cleanup_task_name -or
        [string]$lease.cleanup_action_mutex -cne [string]$Journal.cleanup_action_mutex -or
        [string]$lease.cleanup_action_mutex -cne ($cleanupActionMutexPrefix + [string]$lease.nonce) -or
        [string]$lease.helper_sha256 -cne [string]$Journal.cleanup_helper_sha256 -or
        [string]$lease.tester_groups_sha256 -cne [string]$Journal.tester_groups_sha256 -or
        -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.run_directory)).Equals(
            $RunDirectory, [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.dev2_root)).Equals(
            $dev2Root, [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.helper_path)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_helper_path)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.tester_groups_source_path)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.tester_groups_source_path)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.tester_groups_target_path)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.tester_groups_target_path)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.result_path)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_result_path)), [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$lease.disarm_result_path)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_disarm_path)), [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Rotation cleanup lease differs from its exact journal bindings.'
    }
    $leaseCreated = [DateTimeOffset]::MinValue
    $leaseExpires = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$lease.created_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$leaseCreated) -or
        -not [DateTimeOffset]::TryParseExact([string]$lease.expires_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$leaseExpires) -or
        $leaseCreated.Offset -ne [TimeSpan]::Zero -or $leaseExpires.Offset -ne [TimeSpan]::Zero -or
        $leaseExpires -le $leaseCreated -or $leaseExpires -gt $leaseCreated.AddMinutes(20)) {
        throw 'Rotation cleanup lease chronology is invalid.'
    }
    $cleanupHelperSha256 = (Get-FileHash -LiteralPath ([string]$Journal.cleanup_helper_path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $groupsSha256 = (Get-FileHash -LiteralPath ([string]$Journal.tester_groups_source_path) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($cleanupHelperSha256 -cne [string]$Journal.cleanup_helper_sha256 -or
        $groupsSha256 -cne [string]$Journal.tester_groups_sha256) {
        throw 'Rotation cleanup helper/groups bytes differ from their pre-mutation bindings.'
    }
    $cleanupArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -LeasePath "{1}" -ExpectedSid "{2}" -TargetTaskName "{3}" -CleanupTaskName "{4}" -CleanupActionMutex "{5}" -ExpectedHelperSha256 "{6}"' -f `
        [string]$Journal.cleanup_helper_path, $leasePath, [string]$Journal.target_sid,
        [string]$Journal.target_task_name, [string]$Journal.cleanup_task_name,
        [string]$Journal.cleanup_action_mutex, [string]$Journal.cleanup_helper_sha256
    return [pscustomobject]@{
        Lease = $lease
        Arguments = $cleanupArguments
        CreatedUtc = $leaseCreated
        ExpiresUtc = $leaseExpires
    }
}

function Assert-QmRotationCleanupEvidenceReceipt {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ArtifactType,
        [Parameter(Mandatory = $true)][object]$Journal,
        [switch]$AllowFailure
    )
    $fields = if ($ArtifactType -ceq 'QM_DEV2_ACCOUNT_CLEANUP_RESULT') {
        @(
            'account_restored_disabled', 'artifact_type', 'cleanup_task_name', 'cleanup_task_registered',
            'completed_utc', 'containment_verified', 'dev2_root_process_count', 'expected_sid', 'failures',
            'lease_disarmed', 'manifest_valid', 'owner_process_count', 'schema_version', 'success',
            'target_task_name', 'target_task_registered'
        )
    } else {
        @(
            'account_restored_disabled', 'artifact_type', 'cleanup_task_name', 'cleanup_task_registered',
            'completed_utc', 'containment_result_path', 'containment_verified', 'dev2_root_process_count',
            'expected_sid', 'failures', 'lease_disarmed', 'owner_process_count', 'schema_version', 'success',
            'target_task_name', 'target_task_registered'
        )
    }
    $record = Read-QmRotationExactJsonFile -Path $Path -ExpectedFields $fields -MaximumBytes 65536
    $payload = $record.Payload
    $ownerProcessCount = [long]0
    $dev2RootProcessCount = [long]0
    $failureValues = New-Object System.Collections.Generic.List[string]
    $typeDocument = [System.Text.Json.JsonDocument]::Parse([string]$record.Json)
    try {
        $ownerElement = $typeDocument.RootElement.GetProperty('owner_process_count')
        $rootElement = $typeDocument.RootElement.GetProperty('dev2_root_process_count')
        $failuresElement = $typeDocument.RootElement.GetProperty('failures')
        if ($ownerElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $ownerElement.GetRawText() -cnotmatch '^(?:-1|0|[1-9][0-9]*)$' -or
            -not $ownerElement.TryGetInt64([ref]$ownerProcessCount) -or $ownerProcessCount -lt -1 -or
            $ownerProcessCount -gt [int]::MaxValue -or
            $rootElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Number -or
            $rootElement.GetRawText() -cnotmatch '^(?:-1|0|[1-9][0-9]*)$' -or
            -not $rootElement.TryGetInt64([ref]$dev2RootProcessCount) -or $dev2RootProcessCount -lt -1 -or
            $dev2RootProcessCount -gt [int]::MaxValue -or
            $failuresElement.ValueKind -ne [System.Text.Json.JsonValueKind]::Array) {
            throw "Rotation cleanup evidence count/failure JSON types are invalid: $Path"
        }
        foreach ($failureElement in $failuresElement.EnumerateArray()) {
            if ($failureElement.ValueKind -ne [System.Text.Json.JsonValueKind]::String) {
                throw "Rotation cleanup failure evidence contains a non-string entry: $Path"
            }
            $failure = $failureElement.GetString()
            if ([string]::IsNullOrWhiteSpace($failure) -or $failure.Length -gt 4096) {
                throw "Rotation cleanup failure evidence contains an invalid failure entry: $Path"
            }
            $failureValues.Add($failure)
        }
    } finally {
        $typeDocument.Dispose()
    }
    if ([int]$payload.schema_version -ne 1 -or [string]$payload.artifact_type -cne $ArtifactType -or
        $payload.success -isnot [bool] -or $payload.containment_verified -isnot [bool] -or
        $payload.lease_disarmed -isnot [bool] -or $payload.account_restored_disabled -isnot [bool] -or
        $payload.target_task_registered -isnot [bool] -or $payload.cleanup_task_registered -isnot [bool] -or
        [long]$payload.owner_process_count -ne $ownerProcessCount -or
        [long]$payload.dev2_root_process_count -ne $dev2RootProcessCount -or
        [string]$payload.expected_sid -cne [string]$Journal.target_sid -or
        [string]$payload.target_task_name -cne [string]$Journal.target_task_name -or
        [string]$payload.cleanup_task_name -cne [string]$Journal.cleanup_task_name) {
        throw "Rotation cleanup evidence schema/identity binding drifted: $Path"
    }
    $completed = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$payload.completed_utc, 'o', [cultureinfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$completed) -or
        $completed.Offset -ne [TimeSpan]::Zero -or $completed -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        throw "Rotation cleanup evidence completion time is invalid: $Path"
    }
    if ($ArtifactType -ceq 'QM_DEV2_ACCOUNT_CLEANUP_RESULT') {
        if ($payload.manifest_valid -isnot [bool] -or [bool]$payload.lease_disarmed) {
            throw 'Rotation cleanup containment result semantics drifted.'
        }
    } else {
        if (-not (ConvertTo-QmRotationFullPath -Path ([string]$payload.containment_result_path)).Equals(
                (ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_result_path)),
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw 'Rotation cleanup disarm result semantics drifted.'
        }
    }
    if ([bool]$payload.success) {
        if (-not [bool]$payload.containment_verified -or -not [bool]$payload.account_restored_disabled -or
            $ownerProcessCount -ne 0 -or $dev2RootProcessCount -ne 0 -or
            [bool]$payload.target_task_registered -or $failureValues.Count -ne 0 -or
            ($ArtifactType -ceq 'QM_DEV2_ACCOUNT_CLEANUP_RESULT' -and -not [bool]$payload.manifest_valid) -or
            ($ArtifactType -ceq 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT' -and
                (-not [bool]$payload.lease_disarmed -or [bool]$payload.cleanup_task_registered))) {
            throw "Rotation cleanup success evidence has non-success semantics: $Path"
        }
    } else {
        if (-not $AllowFailure.IsPresent -or [bool]$payload.containment_verified -or
            [bool]$payload.lease_disarmed -or $failureValues.Count -eq 0) {
            throw "Rotation cleanup failure evidence is malformed or not allowed here: $Path"
        }
    }
    Set-QmDev2CredentialExactAcl -Path $Path
    return [pscustomobject]@{
        Payload = $payload
        Sha256 = $record.Sha256
        Success = [bool]$payload.success
    }
}

function Resolve-QmRotationCleanupEvidence {
    param(
        [Parameter(Mandatory = $true)][string]$CanonicalPath,
        [Parameter(Mandatory = $true)][string]$ArtifactType,
        [Parameter(Mandatory = $true)][object]$Journal,
        [string]$ExpectedFailureArchiveSha256
    )
    $canonical = ConvertTo-QmRotationFullPath -Path $CanonicalPath
    $parent = [System.IO.Path]::GetDirectoryName($canonical)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($canonical)
    $archivePattern = '^' + [regex]::Escape($stem) + '\.failed\.(?<sha>[0-9a-f]{64})\.json$'
    $archives = @(
        Get-ChildItem -LiteralPath $parent -File -Force -ErrorAction Stop |
            Where-Object { $_.Name -cmatch $archivePattern }
    )
    if ($archives.Count -gt 1) { throw "Multiple cleanup failure archives exist for: $canonical" }
    $archiveSha256 = $null
    if ($archives.Count -eq 1) {
        $archive = $archives[0]
        $nameMatch = [regex]::Match($archive.Name, $archivePattern)
        $archiveRecord = Assert-QmRotationCleanupEvidenceReceipt -Path $archive.FullName `
            -ArtifactType $ArtifactType -Journal $Journal -AllowFailure
        if ($archiveRecord.Success -or $archiveRecord.Sha256 -cne $nameMatch.Groups['sha'].Value) {
            throw "Cleanup failure archive content differs from its deterministic hash path: $($archive.FullName)"
        }
        $archiveSha256 = $archiveRecord.Sha256
    }
    if (-not [string]::IsNullOrWhiteSpace($ExpectedFailureArchiveSha256) -and
        $archiveSha256 -cne $ExpectedFailureArchiveSha256) {
        throw "Cleanup failure archive differs from its journal binding: $canonical"
    }
    $successSha256 = $null
    if (Test-Path -LiteralPath $canonical -PathType Leaf) {
        $canonicalRecord = Assert-QmRotationCleanupEvidenceReceipt -Path $canonical `
            -ArtifactType $ArtifactType -Journal $Journal -AllowFailure
        if ($canonicalRecord.Success) {
            $successSha256 = $canonicalRecord.Sha256
        } else {
            if (-not [string]::IsNullOrWhiteSpace($archiveSha256)) {
                throw "Canonical failure evidence reappeared after deterministic archival: $canonical"
            }
            $archivePath = Join-Path $parent ("$stem.failed.$($canonicalRecord.Sha256).json")
            [System.IO.File]::Move($canonical, $archivePath, $false)
            Assert-QmDev2CredentialExactAcl -Path $archivePath
            $archiveRecord = Assert-QmRotationCleanupEvidenceReceipt -Path $archivePath `
                -ArtifactType $ArtifactType -Journal $Journal -AllowFailure
            if ($archiveRecord.Success -or $archiveRecord.Sha256 -cne $canonicalRecord.Sha256 -or
                (Test-Path -LiteralPath $canonical)) {
                throw "Cleanup failure evidence archival did not preserve exact bytes: $canonical"
            }
            $archiveSha256 = $archiveRecord.Sha256
        }
    }
    return [pscustomobject]@{
        SuccessSha256 = $successSha256
        FailureArchiveSha256 = $archiveSha256
    }
}

function Assert-QmRotationCleanupEvidenceSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$ExpectedSuccessSha256,
        [Parameter(Mandatory = $true)][string]$ActualSuccessSha256,
        [AllowNull()][string]$ExpectedArchiveSha256,
        [AllowNull()][string]$ActualArchiveSha256
    )
    if ($ExpectedSuccessSha256 -cnotmatch '^[0-9a-f]{64}$' -or
        $ActualSuccessSha256 -cnotmatch '^[0-9a-f]{64}$' -or
        $ExpectedSuccessSha256 -cne $ActualSuccessSha256 -or
        [string]$ExpectedArchiveSha256 -cne [string]$ActualArchiveSha256) {
        throw 'Cleanup evidence snapshot changed after journal sealing.'
    }
}

function Assert-QmRotationCleanupEvidenceHashBindings {
    param([Parameter(Mandatory = $true)][object]$Journal)
    foreach ($entry in @(
            @{
                Path = [string]$Journal.cleanup_result_path
                ArtifactType = 'QM_DEV2_ACCOUNT_CLEANUP_RESULT'
                SuccessSha256 = [string]$Journal.cleanup_result_sha256
                ArchiveSha256 = [string]$Journal.cleanup_result_failure_archive_sha256
            },
            @{
                Path = [string]$Journal.cleanup_disarm_path
                ArtifactType = 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT'
                SuccessSha256 = [string]$Journal.cleanup_disarm_sha256
                ArchiveSha256 = [string]$Journal.cleanup_disarm_failure_archive_sha256
            }
        )) {
        $success = Assert-QmRotationCleanupEvidenceReceipt -Path $entry.Path `
            -ArtifactType $entry.ArtifactType -Journal $Journal
        $parent = [System.IO.Path]::GetDirectoryName($entry.Path)
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($entry.Path)
        $archivePattern = '^' + [regex]::Escape($stem) + '\.failed\.(?<sha>[0-9a-f]{64})\.json$'
        $archives = @(
            Get-ChildItem -LiteralPath $parent -File -Force -ErrorAction Stop |
                Where-Object { $_.Name -cmatch $archivePattern }
        )
        $expectedArchiveCount = if ([string]::IsNullOrWhiteSpace($entry.ArchiveSha256)) { 0 } else { 1 }
        if ($archives.Count -ne $expectedArchiveCount) {
            throw "Cleanup failure archive set changed after journal sealing: $($entry.Path)"
        }
        if ($archives.Count -eq 1) {
            $archive = Assert-QmRotationCleanupEvidenceReceipt -Path $archives[0].FullName `
                -ArtifactType $entry.ArtifactType -Journal $Journal -AllowFailure
            if ($archive.Success -or $archive.Sha256 -cne $entry.ArchiveSha256 -or
                $archives[0].Name -cne "$stem.failed.$($entry.ArchiveSha256).json") {
                throw "Cleanup failure archive changed after journal sealing: $($entry.Path)"
            }
        }
        $actualArchiveSha256 = if ($archives.Count -eq 1) { $archive.Sha256 } else { $null }
        Assert-QmRotationCleanupEvidenceSnapshot -ExpectedSuccessSha256 $entry.SuccessSha256 `
            -ActualSuccessSha256 $success.Sha256 -ExpectedArchiveSha256 $entry.ArchiveSha256 `
            -ActualArchiveSha256 $actualArchiveSha256
    }
}

function Write-QmRotationCleanupEvidenceFresh {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Payload
    )
    if (Test-Path -LiteralPath $Path) { throw "Fresh cleanup evidence path already exists: $Path" }
    Write-QmRotationJsonAtomic -Path $Path -Payload $Payload
    Set-QmDev2CredentialExactAcl -Path $Path
}

function Invoke-QmRotationHostContainmentPass {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [switch]$AllowBoundCleanupTask
    )
    Stop-QmRotationTargetProcesses -TargetSid ([string]$Journal.target_sid)
    $groupsSource = ConvertTo-QmRotationFullPath -Path ([string]$Journal.tester_groups_source_path)
    $groupsTarget = ConvertTo-QmRotationFullPath -Path ([string]$Journal.tester_groups_target_path)
    Assert-QmRotationNoReparseComponents -Path $groupsSource
    Assert-QmRotationNoReparseComponents -Path $groupsTarget
    [System.IO.File]::Copy($groupsSource, $groupsTarget, $true)
    if ((Get-FileHash -LiteralPath $groupsTarget -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
        [string]$Journal.tester_groups_sha256) {
        throw 'Recovery tester-groups restoration differs from its sealed bytes.'
    }
    $sidObject = New-Object System.Security.Principal.SecurityIdentifier([string]$Journal.target_sid)
    $user = Get-LocalUser -SID $sidObject -ErrorAction Stop
    if ($user.Name -cne $targetUserName -or $user.SID.Value -cne [string]$Journal.target_sid) {
        throw 'Recovery target local-user SID/name binding drifted.'
    }
    if ($user.Enabled) { Disable-LocalUser -SID $sidObject -ErrorAction Stop }
    $remainingTasks = @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
            $_.TaskName.StartsWith($taskPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($cleanupPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($profileTaskPrefix, [System.StringComparison]::Ordinal)
        })
    $unexpectedTasks = if ($AllowBoundCleanupTask.IsPresent) {
        @($remainingTasks | Where-Object {
                [string]$_.TaskName -cne [string]$Journal.cleanup_task_name
            })
    } else {
        $remainingTasks
    }
    $verifiedUser = Get-LocalUser -SID $sidObject -ErrorAction Stop
    if ($verifiedUser.Name -cne $targetUserName -or $verifiedUser.SID.Value -cne [string]$Journal.target_sid -or
        $verifiedUser.Enabled -or -not $verifiedUser.PasswordRequired -or
        @(Get-QmRotationDev2Processes -TargetSid ([string]$Journal.target_sid)).Count -ne 0 -or
        @($unexpectedTasks).Count -ne 0) {
        throw 'Recovery could not prove disabled-at-rest, process-free, task-contained host state.'
    }
}

function Invoke-QmRotationRecoveryContainment {
    param(
        [Parameter(Mandatory = $true)][object]$Journal,
        [Parameter(Mandatory = $true)][object]$LeaseBinding,
        [Parameter(Mandatory = $true)][string]$RunDirectory
    )
    $actionFence = $null
    try {
    $boundTaskNames = @([string]$Journal.target_task_name, [string]$Journal.cleanup_task_name)
    $allDev2Tasks = @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
            $_.TaskName.StartsWith($taskPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($cleanupPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($profileTaskPrefix, [System.StringComparison]::Ordinal)
        })
    foreach ($task in $allDev2Tasks) {
        if ([string]$task.TaskName -notin $boundTaskNames) {
            throw "Recovery found an unbound DEV2 task and refuses cross-run cleanup: $($task.TaskName)"
        }
    }
    $cleanupTask = Get-ScheduledTask -TaskName ([string]$Journal.cleanup_task_name) -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -ne $cleanupTask) {
        Assert-QmRotationCleanupTaskContract -Task $cleanupTask -ExpectedTaskName ([string]$Journal.cleanup_task_name) `
            -ExpectedArguments ([string]$LeaseBinding.Arguments) -ExpectedWorkingDirectory $RunDirectory
    }
    $targetTask = Get-ScheduledTask -TaskName ([string]$Journal.target_task_name) -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -ne $targetTask) {
        $targetArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RequestPath "{1}" -ExpectedRequestSha256 "{2}"' -f `
            [string]$Journal.identity_probe_child_path, [string]$Journal.identity_probe_request_path,
            [string]$Journal.identity_probe_request_sha256
        Assert-QmRotationTaskContract -Task $targetTask -ExpectedTaskName ([string]$Journal.target_task_name) `
            -ExpectedAccount ([string]$Journal.target_account) -ExpectedSid ([string]$Journal.target_sid) `
            -ExpectedArguments $targetArguments -ExpectedWorkingDirectory $repoRoot
        Remove-QmRotationScheduledTaskBounded -TaskName ([string]$Journal.target_task_name)
    }
    # Keep the independent SYSTEM lease armed until the host is already safe. A crash immediately
    # after later lease removal must leave QMDev2 disabled, process-free, and groups-restored.
    Invoke-QmRotationHostContainmentPass -Journal $Journal -AllowBoundCleanupTask
    $cleanupTask = Get-ScheduledTask -TaskName ([string]$Journal.cleanup_task_name) -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -ne $cleanupTask) {
        Assert-QmRotationCleanupTaskContract -Task $cleanupTask -ExpectedTaskName ([string]$Journal.cleanup_task_name) `
            -ExpectedArguments ([string]$LeaseBinding.Arguments) -ExpectedWorkingDirectory $RunDirectory
        Remove-QmRotationScheduledTaskBounded -TaskName ([string]$Journal.cleanup_task_name) -DisableBeforeStop
    }
    $tasksAfterDrain = @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
            $_.TaskName.StartsWith($taskPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($cleanupPrefix, [System.StringComparison]::Ordinal) -or
            $_.TaskName.StartsWith($profileTaskPrefix, [System.StringComparison]::Ordinal)
        })
    if ($tasksAfterDrain.Count -ne 0) {
        throw 'Recovery observed DEV2 task reappearance after bounded scheduler drain.'
    }
    $actionFence = Enter-QmRotationCleanupActionMutex -Name ([string]$Journal.cleanup_action_mutex)
    Invoke-QmRotationHostContainmentPass -Journal $Journal
    $resultPath = ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_result_path)
    $disarmPath = ConvertTo-QmRotationFullPath -Path ([string]$Journal.cleanup_disarm_path)
    $resultEvidence = Resolve-QmRotationCleanupEvidence -CanonicalPath $resultPath `
        -ArtifactType 'QM_DEV2_ACCOUNT_CLEANUP_RESULT' -Journal $Journal `
        -ExpectedFailureArchiveSha256 ([string]$Journal.cleanup_result_failure_archive_sha256)
    if ([string]::IsNullOrWhiteSpace([string]$resultEvidence.SuccessSha256)) {
        $resultPayload = [ordered]@{
            schema_version = 1
            artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_RESULT'
            completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            success = $true
            containment_verified = $true
            lease_disarmed = $false
            expected_sid = [string]$Journal.target_sid
            target_task_name = [string]$Journal.target_task_name
            cleanup_task_name = [string]$Journal.cleanup_task_name
            manifest_valid = $true
            account_restored_disabled = $true
            owner_process_count = 0
            dev2_root_process_count = 0
            target_task_registered = $false
            cleanup_task_registered = $false
            failures = @()
        }
        Write-QmRotationCleanupEvidenceFresh -Path $resultPath -Payload $resultPayload
    }
    $resultSuccess = Assert-QmRotationCleanupEvidenceReceipt -Path $resultPath `
        -ArtifactType 'QM_DEV2_ACCOUNT_CLEANUP_RESULT' -Journal $Journal
    $disarmEvidence = Resolve-QmRotationCleanupEvidence -CanonicalPath $disarmPath `
        -ArtifactType 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT' -Journal $Journal `
        -ExpectedFailureArchiveSha256 ([string]$Journal.cleanup_disarm_failure_archive_sha256)
    if ([string]::IsNullOrWhiteSpace([string]$disarmEvidence.SuccessSha256)) {
        $disarmPayload = [ordered]@{
            schema_version = 1
            artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT'
            completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
            success = $true
            containment_result_path = $resultPath
            containment_verified = $true
            lease_disarmed = $true
            expected_sid = [string]$Journal.target_sid
            target_task_name = [string]$Journal.target_task_name
            cleanup_task_name = [string]$Journal.cleanup_task_name
            account_restored_disabled = $true
            owner_process_count = 0
            dev2_root_process_count = 0
            target_task_registered = $false
            cleanup_task_registered = $false
            failures = @()
        }
        Write-QmRotationCleanupEvidenceFresh -Path $disarmPath -Payload $disarmPayload
    }
    $disarmSuccess = Assert-QmRotationCleanupEvidenceReceipt -Path $disarmPath `
        -ArtifactType 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT' -Journal $Journal
    if (($null -ne $Journal.cleanup_result_sha256 -and
            [string]$Journal.cleanup_result_sha256 -cne $resultSuccess.Sha256) -or
        ($null -ne $Journal.cleanup_disarm_sha256 -and
            [string]$Journal.cleanup_disarm_sha256 -cne $disarmSuccess.Sha256)) {
        throw 'Recovery cleanup success evidence differs from its sealed journal hashes.'
    }
    Assert-QmDev2CredentialExactAcl -Path $resultPath
    Assert-QmDev2CredentialExactAcl -Path $disarmPath
    return [pscustomobject]@{
        AccountDisabled = $true
        PasswordRequired = $true
        OwnerProcessCount = 0
        Dev2RootProcessCount = 0
        CleanupLeaseDisarmed = $true
        CleanupResultSha256 = $resultSuccess.Sha256
        CleanupDisarmSha256 = $disarmSuccess.Sha256
        CleanupResultFailureArchiveSha256 = $resultEvidence.FailureArchiveSha256
        CleanupDisarmFailureArchiveSha256 = $disarmEvidence.FailureArchiveSha256
        CleanupActionFence = $actionFence
    }
    } catch {
        Exit-QmRotationCleanupActionMutex -Fence $actionFence
        throw
    }
}

function Resolve-QmRotationRecoveryRunDirectory {
    param([string]$RequestedDirectory)
    if (-not [string]::IsNullOrWhiteSpace($RequestedDirectory)) {
        $candidate = ConvertTo-QmRotationFullPath -Path $RequestedDirectory
        if (-not (Test-QmRotationPathWithin -Path $candidate -Root $rotationRoot) -or
            -not (Test-Path -LiteralPath $candidate -PathType Container) -or
            -not ([System.IO.Path]::GetDirectoryName($candidate)).Equals($rotationRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
            [System.IO.Path]::GetFileName($candidate) -cnotmatch '^[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}$') {
            throw 'Explicit recovery directory is not an exact direct child of the fixed rotation root.'
        }
        Assert-QmRotationNoReparseComponents -Path $candidate
        return $candidate
    }
    if (-not (Test-Path -LiteralPath $rotationRoot -PathType Container)) {
        throw 'Rotation recovery root does not exist.'
    }
    Assert-QmRotationNoReparseComponents -Path $rotationRoot
    $history = @(Get-QmRotationJournalHistory)
    $active = @($history | Where-Object {
            -not (Test-QmRotationRetryClearPhase -Phase ([string]$_.Journal.phase)) -and
            [string]$_.Journal.phase -cne 'COMMITTED'
        })
    $selected = if ($active.Count -eq 1) {
        $active[0]
    } elseif ($active.Count -eq 0 -and $history.Count -eq 1) {
        $history[0]
    } else {
        throw "Recovery requires exactly one unresolved journal or an explicit -ResumeRotationDirectory; active=$($active.Count), total=$($history.Count)."
    }
    Assert-QmRotationNoReparseComponents -Path ([string]$selected.RunDirectory)
    return [System.IO.Path]::GetFullPath([string]$selected.RunDirectory)
}

function Invoke-QmRotationResumeFinalize {
    param([string]$RequestedDirectory)
    Assert-QmRotationElevated
    foreach ($source in @($contractPath, $helperPath, $childPath, $legacyCredentialPath)) {
        Assert-QmRotationAdminControlledSourceFile -Path $source
    }
    $run = Resolve-QmRotationRecoveryRunDirectory -RequestedDirectory $RequestedDirectory
    $journalPathLocal = Join-Path $run 'control\rotation_journal.json'
    Assert-QmDev2CredentialExactAcl -Path $journalPathLocal
    $journalRecord = Read-QmRotationExactJsonFile -Path $journalPathLocal `
        -ExpectedFields (Get-QmRotationJournalFieldNames) -MaximumBytes 131072
    $journal = $journalRecord.Payload
    Assert-QmRotationJournalSchema -Journal $journal
    foreach ($source in @($contractPath, $helperPath, $childPath, $legacyCredentialPath)) {
        Assert-QmRotationAdminControlledSourceFile -Path $source -ForbiddenWriterSid ([string]$journal.target_sid)
    }
    if ([System.IO.Path]::GetFileName($run) -cne [string]$journal.rotation_id) {
        throw 'Recovery directory name differs from the sealed rotation ID.'
    }
    Assert-QmRotationDirectoryAcl -Path $run -TargetSid ([string]$journal.target_sid) `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Assert-QmRotationDirectoryAcl -Path (Join-Path $run 'control') -TargetSid ([string]$journal.target_sid) `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Assert-QmRotationDirectoryAcl -Path (Join-Path $run 'output') -TargetSid ([string]$journal.target_sid) `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::Modify)
    Assert-QmRotationResumeHasNoLaterAttempt -CurrentJournal $journal -CurrentRunDirectory $run
    $expectedPaths = [ordered]@{
        lane_contract_path = $contractPath
        credential_final_path = $credentialPath
        credential_helper_path = $helperPath
        identity_probe_child_path = $childPath
        identity_probe_request_path = (Join-Path $run 'control\identity_probe_request.json')
        identity_probe_result_path = (Join-Path $run 'output\identity_probe_result.json')
        cleanup_lease_path = (Join-Path $run 'control\cleanup_lease.json')
        cleanup_helper_path = (Join-Path $run 'control\cleanup_dev2_account_lease.ps1')
        tester_groups_source_path = (Join-Path $run 'control\Darwinex-Live_real.canonical.txt')
        tester_groups_target_path = $groupsTargetPath
        cleanup_result_path = (Join-Path $run 'control\cleanup_lease.result.json')
        cleanup_disarm_path = (Join-Path $run 'control\cleanup_lease.disarm.result.json')
        legacy_credential_path = $legacyCredentialPath
        dynamic_receipt_path = (Join-Path $run 'control\rotation_receipt.json')
        canonical_receipt_path = $canonicalRotationReceiptPath
    }
    foreach ($binding in $expectedPaths.GetEnumerator()) {
        if (-not (ConvertTo-QmRotationFullPath -Path ([string]$journal.($binding.Key))).Equals(
                (ConvertTo-QmRotationFullPath -Path ([string]$binding.Value)), [System.StringComparison]::OrdinalIgnoreCase
            )) {
            throw "Recovery journal path binding drifted: $($binding.Key)"
        }
    }
    $expectedStagedPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
        ("credential.machine-dpapi.pending.$([string]$journal.nonce).json")
    if (-not (ConvertTo-QmRotationFullPath -Path ([string]$journal.credential_staged_path)).Equals(
            $expectedStagedPath, [System.StringComparison]::OrdinalIgnoreCase
        ) -or -not (ConvertTo-QmRotationFullPath -Path ([string]$journal.target_profile)).Equals(
            (ConvertTo-QmRotationFullPath -Path ([System.Environment]::ExpandEnvironmentVariables(
                    (Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$([string]$journal.target_sid)" `
                        -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
                ))), [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Recovery staged credential or profile binding drifted.'
    }
    $sourceHashes = [ordered]@{
        lane_contract_sha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        credential_helper_sha256 = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        identity_probe_child_sha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        legacy_credential_sha256 = (Get-FileHash -LiteralPath $legacyCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    }
    foreach ($binding in $sourceHashes.GetEnumerator()) {
        if ([string]$journal.($binding.Key) -cne [string]$binding.Value) {
            throw "Recovery source bytes differ from the pre-mutation journal binding: $($binding.Key)"
        }
    }
    Assert-QmDev2CredentialExactAcl -Path $legacyCredentialPath
    $contractRecord = Read-QmRotationExactJsonFile -Path $contractPath -ExpectedFields @(
        'agent_port_contract', 'allowed_symbols', 'contract_id', 'coordination', 'copy_contract',
        'firewall', 'identity', 'lane', 'paths', 'program_sha256', 'schema_version', 'source_lane'
    ) -ExpectedSha256 ([string]$journal.lane_contract_sha256) -MaximumBytes 262144
    $boundContract = $contractRecord.Payload
    if ([int]$boundContract.schema_version -ne 3 -or [string]$boundContract.contract_id -cne $contractId -or
        [string]$boundContract.lane -cne $lane -or [string]$boundContract.identity.local_user -cne $targetUserName -or
        [string]$boundContract.coordination.controller_mutex -cne $mutexName -or
        [string]$boundContract.coordination.task_prefix -cne $taskPrefix -or
        [string]$boundContract.coordination.profile_task_prefix -cne $profileTaskPrefix -or
        -not (ConvertTo-QmRotationFullPath -Path ([string]$boundContract.identity.credential)).Equals(
            $credentialPath, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Recovery lane contract semantics drifted from V3.'
    }
    if ((Resolve-QmRotationSid -AccountName ([string]$journal.target_account)) -cne [string]$journal.target_sid) {
        throw 'Recovery target account no longer resolves to the sealed SID.'
    }
    # Residual trust boundary: another already-trusted administrator can change PasswordLastSet/current
    # password out of band. Resume therefore never enables the account, registers tasks, or rotates a password.
    Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)
    $leaseBinding = Assert-QmRotationCleanupLeaseBindings -Journal $journal -RunDirectory $run
    $cleanupTaskAtEntry = Get-ScheduledTask -TaskName ([string]$journal.cleanup_task_name) `
        -TaskPath $taskPath -ErrorAction SilentlyContinue
    $cleanupEvidenceAtEntry =
        (Test-Path -LiteralPath ([string]$journal.cleanup_result_path) -PathType Leaf) -or
        (Test-Path -LiteralPath ([string]$journal.cleanup_disarm_path) -PathType Leaf)
    $proofInvalidatedAtEntry = [string]$journal.phase -in @(
        'IDENTITY_PROVED', 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF'
    ) -and ($null -eq $cleanupTaskAtEntry -or $cleanupEvidenceAtEntry)
    $stagedExists = Test-Path -LiteralPath ([string]$journal.credential_staged_path) -PathType Leaf
    $finalExists = Test-Path -LiteralPath ([string]$journal.credential_final_path) -PathType Leaf
    $canonicalReceiptExists = Test-Path -LiteralPath ([string]$journal.canonical_receipt_path) -PathType Leaf
    $disposition = if ($proofInvalidatedAtEntry) {
        if ($canonicalReceiptExists) {
            throw 'Cleanup-invalidated proof state cannot coexist with a canonical success receipt.'
        }
        'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR'
    } else {
        Get-QmRotationRecoveryDisposition -Phase ([string]$journal.phase) `
            -IdentityProofVerified ([bool]$journal.identity_proof_verified) `
            -StagedCredentialExists $stagedExists -FinalCredentialExists $finalExists `
            -CanonicalReceiptExists $canonicalReceiptExists
    }
    $rollbackRecovery = $disposition -eq 'CONTAIN_ROLLBACK_RETRY_CLEAR'
    $proofInvalidationRecovery = $disposition -eq 'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR'
    if ($disposition -notin @(
            'CONTAIN_PRE_PROOF_FORENSIC_ONLY', 'CONTAIN_PRE_PROOF_RETRY_CLEAR',
            'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR'
        ) -and
        (-not $rollbackRecovery -or [bool]$journal.identity_proof_verified)) {
        $null = Assert-QmRotationIdentityProofBindings -Journal $journal -RunDirectory $run
    } else {
        $requestFields = @(
            'artifact_type', 'created_utc', 'expected_account', 'expected_profile', 'expected_sid',
            'expected_task_name', 'expires_utc', 'nonce', 'result_path', 'schema_version'
        )
        $null = Read-QmRotationExactJsonFile -Path ([string]$journal.identity_probe_request_path) `
            -ExpectedFields $requestFields -ExpectedSha256 ([string]$journal.identity_probe_request_sha256) -MaximumBytes 32768
    }
    $recoveryContainment = Invoke-QmRotationRecoveryContainment -Journal $journal `
        -LeaseBinding $leaseBinding -RunDirectory $run
    try {
    if ($disposition -in @(
            'CONTAIN_PRE_PROOF_FORENSIC_ONLY', 'CONTAIN_PRE_PROOF_RETRY_CLEAR',
            'CONTAIN_PROOF_INVALIDATED_RETRY_CLEAR'
        )) {
        $forensicFailedPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
            ("credential.machine-dpapi.failed.$([string]$journal.nonce).json")
        $forensicCandidates = @(
            @([string]$journal.credential_staged_path, $credentialPath, $forensicFailedPath) | Where-Object {
                Test-Path -LiteralPath $_ -PathType Leaf
            }
        )
        if ($forensicCandidates.Count -ne 1) {
            throw 'Containment-only recovery requires exactly one bound staged/final/failed forensic credential artifact.'
        }
        $forensicCredentialPath = ConvertTo-QmRotationFullPath -Path $forensicCandidates[0]
        if (-not $forensicCredentialPath.Equals($forensicFailedPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            if (Test-Path -LiteralPath $forensicFailedPath) {
                throw 'Containment-only forensic quarantine path unexpectedly exists.'
            }
            [System.IO.File]::Move($forensicCredentialPath, $forensicFailedPath, $false)
            $forensicCredentialPath = $forensicFailedPath
            Set-QmDev2CredentialExactAcl -Path $forensicCredentialPath
        }
        Assert-QmDev2CredentialExactAcl -Path $forensicCredentialPath
        if ((Get-FileHash -LiteralPath $forensicCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
            [string]$journal.credential_sha256) {
            throw 'Containment-only forensic credential differs from its sealed journal bytes.'
        }
        $terminalPhase = if ($proofInvalidationRecovery -or [bool]$journal.identity_proof_verified) {
            'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR'
        } else {
            'PRE_PROOF_CONTAINED_RETRY_CLEAR'
        }
        if ([string]$journal.phase -eq $terminalPhase -and
            ([string]$journal.cleanup_result_failure_archive_sha256 -cne
                [string]$recoveryContainment.CleanupResultFailureArchiveSha256 -or
             [string]$journal.cleanup_disarm_failure_archive_sha256 -cne
                [string]$recoveryContainment.CleanupDisarmFailureArchiveSha256)) {
            throw 'Retry-clear containment archive set differs from its sealed journal bindings.'
        }
        $journal.cleanup_result_sha256 = $recoveryContainment.CleanupResultSha256
        $journal.cleanup_disarm_sha256 = $recoveryContainment.CleanupDisarmSha256
        $journal.cleanup_result_failure_archive_sha256 = $recoveryContainment.CleanupResultFailureArchiveSha256
        $journal.cleanup_disarm_failure_archive_sha256 = $recoveryContainment.CleanupDisarmFailureArchiveSha256
        if ([string]$journal.phase -ne $terminalPhase) {
            $journal.phase = $terminalPhase
            $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
            Assert-QmRotationJournalSchema -Journal $journal
            Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
        }
        Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
        Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)
        Assert-QmRotationNoTasks
        $containedUser = Get-LocalUser -SID `
            (New-Object System.Security.Principal.SecurityIdentifier([string]$journal.target_sid)) -ErrorAction Stop
        if ($containedUser.Name -cne $targetUserName -or $containedUser.Enabled -or
            -not $containedUser.PasswordRequired -or
            @(Get-QmRotationDev2Processes -TargetSid ([string]$journal.target_sid)).Count -ne 0 -or
            (Test-Path -LiteralPath $credentialPath) -or
            (Test-Path -LiteralPath ([string]$journal.canonical_receipt_path)) -or
            $null -ne $journal.receipt_completed_utc) {
            throw 'Retry-clear containment-only recovery reassertion failed.'
        }
        Write-Output ([ordered]@{
                status = 'PASS'
                mode = $(if ($terminalPhase -ceq 'PROOF_INVALIDATED_CONTAINED_RETRY_CLEAR') {
                        'PROOF_INVALIDATION_CONTAINMENT'
                    } else {
                        'PRE_PROOF_CONTAINMENT_REPAIR'
                    })
                rotation_id = [string]$journal.rotation_id
                phase = [string]$journal.phase
                forensic_credential_path = $forensicCredentialPath
                target_disabled_at_rest = $true
                retry_clear_for_fresh_apply = $true
                canonical_credential_published = $false
                canonical_receipt_published = $false
                password_rotated_by_resume = $false
            } | ConvertTo-Json -Depth 3 -Compress)
        return
    }
    if ($rollbackRecovery) {
        $forensicFailedPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
            ("credential.machine-dpapi.failed.$([string]$journal.nonce).json")
        $forensicCandidates = @(
            @([string]$journal.credential_staged_path, $credentialPath, $forensicFailedPath) | Where-Object {
                Test-Path -LiteralPath $_ -PathType Leaf
            }
        )
        if ($forensicCandidates.Count -ne 1) {
            throw 'Password-rollback recovery requires exactly one bound staged/final/failed forensic credential artifact.'
        }
        $forensicCredentialPath = ConvertTo-QmRotationFullPath -Path $forensicCandidates[0]
        if ($forensicCredentialPath.Equals($credentialPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            [System.IO.File]::Move($credentialPath, $forensicFailedPath, $false)
            Set-QmDev2CredentialExactAcl -Path $forensicFailedPath
            $forensicCredentialPath = $forensicFailedPath
        }
        Assert-QmDev2CredentialExactAcl -Path $forensicCredentialPath
        if ((Get-FileHash -LiteralPath $forensicCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
            [string]$journal.credential_sha256) {
            throw 'Password-rollback forensic credential differs from its sealed pre-rollback bytes.'
        }
        if ([string]$journal.phase -eq 'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR' -and
            ([string]$journal.cleanup_result_failure_archive_sha256 -cne
                [string]$recoveryContainment.CleanupResultFailureArchiveSha256 -or
             [string]$journal.cleanup_disarm_failure_archive_sha256 -cne
                [string]$recoveryContainment.CleanupDisarmFailureArchiveSha256)) {
            throw 'Retry-clear rollback cleanup archive set differs from its sealed journal bindings.'
        }
        $journal.cleanup_result_sha256 = $recoveryContainment.CleanupResultSha256
        $journal.cleanup_disarm_sha256 = $recoveryContainment.CleanupDisarmSha256
        $journal.cleanup_result_failure_archive_sha256 = $recoveryContainment.CleanupResultFailureArchiveSha256
        $journal.cleanup_disarm_failure_archive_sha256 = $recoveryContainment.CleanupDisarmFailureArchiveSha256
        if ([string]$journal.phase -ne 'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR') {
            $journal.phase = 'PASSWORD_ROLLBACK_CONTAINED_RETRY_CLEAR'
            $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
            Assert-QmRotationJournalSchema -Journal $journal
            Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
        }
        Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
        Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)
        Assert-QmRotationNoTasks
        $rollbackUser = Get-LocalUser -SID `
            (New-Object System.Security.Principal.SecurityIdentifier([string]$journal.target_sid)) -ErrorAction Stop
        if ($rollbackUser.Name -cne $targetUserName -or $rollbackUser.Enabled -or -not $rollbackUser.PasswordRequired -or
            @(Get-QmRotationDev2Processes -TargetSid ([string]$journal.target_sid)).Count -ne 0 -or
            (Test-Path -LiteralPath $credentialPath) -or
            (Test-Path -LiteralPath ([string]$journal.canonical_receipt_path)) -or
            $null -ne $journal.receipt_completed_utc) {
            throw 'Retry-clear password-rollback containment reassertion failed.'
        }
        Write-Output ([ordered]@{
                status = 'PASS'
                mode = 'ROLLBACK_CONTAINMENT_REPAIR'
                rotation_id = [string]$journal.rotation_id
                phase = [string]$journal.phase
                forensic_credential_path = $forensicCredentialPath
                target_disabled_at_rest = $true
                retry_clear_for_fresh_apply = $true
                canonical_credential_published = $false
                canonical_receipt_published = $false
                password_rotated_by_resume = $false
            } | ConvertTo-Json -Depth 3 -Compress)
        return
    }
    $artifactPath = if ($stagedExists) { [string]$journal.credential_staged_path } else { [string]$journal.credential_final_path }
    Assert-QmDev2CredentialExactAcl -Path ([System.IO.Path]::GetDirectoryName($artifactPath)) -Directory
    Assert-QmDev2CredentialExactAcl -Path $artifactPath
    $envelope = Read-QmDev2MachineCredentialEnvelope -CredentialPath $artifactPath `
        -ExpectedCredentialSha256 ([string]$journal.credential_sha256) -ExpectedAccount ([string]$journal.target_account) `
        -ExpectedSid ([string]$journal.target_sid) -ContractId ([string]$journal.contract_id) -Lane ([string]$journal.lane)
    if ($envelope.GenerationId -cne [string]$journal.credential_generation_id) {
        throw 'Recovery machine-credential generation differs from the staged journal binding.'
    }
    $decryptedCredential = Get-QmDev2MachineCredential -CredentialPath $artifactPath `
        -ExpectedCredentialSha256 ([string]$journal.credential_sha256) -ExpectedAccount ([string]$journal.target_account) `
        -ExpectedSid ([string]$journal.target_sid) -ContractId ([string]$journal.contract_id) -Lane ([string]$journal.lane)
    try {
        if ($decryptedCredential.UserName -cne [string]$journal.target_account -or $decryptedCredential.Password.Length -le 0) {
            throw 'Recovery machine credential did not decrypt to its sealed nonempty identity.'
        }
    } finally {
        if ($null -ne $decryptedCredential) { $decryptedCredential.Password.Dispose() }
    }
    if ($stagedExists) {
        if (Test-Path -LiteralPath $credentialPath) { throw 'Recovery refuses to replace an existing canonical machine credential.' }
        [System.IO.File]::Move([string]$journal.credential_staged_path, $credentialPath, $false)
        Set-QmDev2CredentialExactAcl -Path $credentialPath
    }
    Assert-QmDev2CredentialExactAcl -Path $credentialPath
    $credentialSha256 = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($credentialSha256 -cne [string]$journal.credential_sha256) {
        throw 'Recovery canonical machine credential differs after publication.'
    }
    if ([string]$journal.phase -in @('IDENTITY_PROVED', 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF')) {
        $journal.phase = 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF'
        $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
    }
    $finalUser = Get-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier([string]$journal.target_sid)) -ErrorAction Stop
    if ($finalUser.Name -cne $targetUserName -or $finalUser.Enabled -or -not $finalUser.PasswordRequired -or
        @(Get-QmRotationDev2Processes -TargetSid ([string]$journal.target_sid)).Count -ne 0 -or
        @(Get-ScheduledTask -TaskPath $taskPath -ErrorAction Stop | Where-Object {
                $_.TaskName.StartsWith($taskPrefix, [System.StringComparison]::Ordinal) -or
                $_.TaskName.StartsWith($cleanupPrefix, [System.StringComparison]::Ordinal) -or
                $_.TaskName.StartsWith($profileTaskPrefix, [System.StringComparison]::Ordinal)
            }).Count -ne 0) {
        throw 'Recovery final host containment reassertion failed.'
    }
    $null = Assert-QmRotationIdentityProofBindings -Journal $journal -RunDirectory $run
    foreach ($binding in $sourceHashes.GetEnumerator()) {
        if ((Get-FileHash -LiteralPath ([string]$expectedPaths[$binding.Key.Replace('_sha256', '_path')]) -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
            [string]$journal.($binding.Key)) {
            throw "Recovery end-reassertion source hash drifted: $($binding.Key)"
        }
    }
    if ([string]$journal.phase -in @('FINAL_CONTAINMENT_VERIFIED', 'READY_FOR_CANONICAL_RECEIPT', 'COMMITTED') -and
        ([string]$journal.cleanup_result_failure_archive_sha256 -cne
            [string]$recoveryContainment.CleanupResultFailureArchiveSha256 -or
         [string]$journal.cleanup_disarm_failure_archive_sha256 -cne
            [string]$recoveryContainment.CleanupDisarmFailureArchiveSha256)) {
        throw 'Recovery cleanup failure archive set differs from its sealed final journal bindings.'
    }
    $journal.cleanup_result_sha256 = $recoveryContainment.CleanupResultSha256
    $journal.cleanup_disarm_sha256 = $recoveryContainment.CleanupDisarmSha256
    $journal.cleanup_result_failure_archive_sha256 = $recoveryContainment.CleanupResultFailureArchiveSha256
    $journal.cleanup_disarm_failure_archive_sha256 = $recoveryContainment.CleanupDisarmFailureArchiveSha256
    if ($null -eq $journal.receipt_completed_utc) {
        $journal.receipt_completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
    }
    if ([string]$journal.phase -notin @('FINAL_CONTAINMENT_VERIFIED', 'READY_FOR_CANONICAL_RECEIPT', 'COMMITTED')) {
        $journal.phase = 'FINAL_CONTAINMENT_VERIFIED'
        $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
    }
    $receipt = New-QmRotationCanonicalReceiptPayload -Journal $journal -CredentialSha256 $credentialSha256
    Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
    $dynamicReceiptPath = [string]$journal.dynamic_receipt_path
    if (Test-Path -LiteralPath $dynamicReceiptPath -PathType Leaf) {
        $null = Assert-QmRotationReceiptExact -Path $dynamicReceiptPath -ExpectedPayload $receipt
        Set-QmDev2CredentialExactAcl -Path $dynamicReceiptPath
    } else {
        if ([string]$journal.phase -in @('READY_FOR_CANONICAL_RECEIPT', 'COMMITTED')) {
            throw 'Receipt-ready rotation journal is missing its dynamic receipt.'
        }
        Write-QmRotationJsonAtomic -Path $dynamicReceiptPath -Payload $receipt
        Set-QmDev2CredentialExactAcl -Path $dynamicReceiptPath
    }
    Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
    if ([string]$journal.phase -notin @('READY_FOR_CANONICAL_RECEIPT', 'COMMITTED')) {
        $journal.phase = 'READY_FOR_CANONICAL_RECEIPT'
        $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
    }
    Assert-QmRotationTargetNonAdministrator -TargetSid ([string]$journal.target_sid)
    Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
    $canonicalReceiptPath = [string]$journal.canonical_receipt_path
    if (Test-Path -LiteralPath $canonicalReceiptPath -PathType Leaf) {
        $canonicalSha256 = Assert-QmRotationReceiptExact -Path $canonicalReceiptPath `
            -ExpectedPayload $receipt -RequireExactAcl
    } else {
        if ([string]$journal.phase -eq 'COMMITTED') { throw 'Committed journal lost its canonical receipt.' }
        $canonicalSha256 = Write-QmCanonicalRotationReceipt -Path $canonicalReceiptPath -Payload $receipt
    }
    $null = Assert-QmRotationReceiptExact -Path $dynamicReceiptPath -ExpectedPayload $receipt -RequireExactAcl
    $null = Assert-QmRotationReceiptExact -Path $canonicalReceiptPath -ExpectedPayload $receipt -RequireExactAcl
    Assert-QmRotationCleanupEvidenceHashBindings -Journal $journal
    if ([string]$journal.phase -ne 'COMMITTED') {
        $journal.phase = 'COMMITTED'
        $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
        Write-QmRotationJournalExact -Path $journalPathLocal -Payload $journal -Replace
    }
    Write-Output ([ordered]@{
            status = 'PASS'
            mode = 'RESUME_FINALIZE'
            rotation_id = [string]$journal.rotation_id
            receipt_path = $canonicalReceiptPath
            receipt_sha256 = $canonicalSha256
            target_disabled_at_rest = $true
            cleanup_lease_disarmed = $true
            password_rotated_by_resume = $false
        } | ConvertTo-Json -Depth 3 -Compress)
    } finally {
        Exit-QmRotationCleanupActionMutex -Fence $recoveryContainment.CleanupActionFence
    }
}

if ($Apply.IsPresent -and $ResumeFinalize.IsPresent) {
    throw '-Apply and -ResumeFinalize are mutually exclusive.'
}
if (-not $ResumeFinalize.IsPresent -and -not [string]::IsNullOrWhiteSpace($ResumeRotationDirectory)) {
    throw '-ResumeRotationDirectory requires -ResumeFinalize.'
}
if (-not $Apply.IsPresent -and -not $ResumeFinalize.IsPresent) {
    $user = Get-LocalUser -Name $targetUserName -ErrorAction SilentlyContinue
    Write-Output ([ordered]@{
            schema_version = 1
            status = 'PLAN_ONLY'
            mutates_host = $false
            target_user_exists = $null -ne $user
            target_user_enabled = if ($null -ne $user) { [bool]$user.Enabled } else { $null }
            legacy_credential_preserved = Test-Path -LiteralPath $legacyCredentialPath -PathType Leaf
            machine_credential_exists = Test-Path -LiteralPath $credentialPath -PathType Leaf
        } | ConvertTo-Json -Depth 3 -Compress)
    exit 0
}

Assert-QmRotationElevated
foreach ($required in @($contractPath, $helperPath, $childPath, $cleanupSourcePath, $groupsCanonicalPath, $pwshPath, $legacyCredentialPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required DEV2 rotation input is missing: $required" }
    Assert-QmRotationNoReparseComponents -Path $required
}
$contract = Get-Content -LiteralPath $contractPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
if ([int]$contract.schema_version -ne 3 -or [string]$contract.contract_id -cne $contractId -or
    [string]$contract.lane -cne $lane -or [string]$contract.identity.local_user -cne $targetUserName -or
    [string]$contract.coordination.controller_mutex -cne $mutexName -or
    [string]$contract.coordination.task_prefix -cne $taskPrefix -or
    [string]$contract.coordination.profile_task_prefix -cne $profileTaskPrefix -or
    -not (ConvertTo-QmRotationFullPath -Path ([string]$contract.identity.credential)).Equals(
        $credentialPath, [System.StringComparison]::OrdinalIgnoreCase
    ) -or [string]$contract.identity.credential_format -cne 'QM_DEV2_MACHINE_DPAPI_CREDENTIAL' -or
    [string]$contract.identity.dpapi_scope -cne 'LocalMachine') {
    throw 'DEV2 rotation requires the exact V3 machine-credential lane contract.'
}

if ($ResumeFinalize.IsPresent) {
    $sealedResumeRun = Resolve-QmRotationRecoveryRunDirectory -RequestedDirectory $ResumeRotationDirectory
    $sealedResumeJournalPath = Join-Path $sealedResumeRun 'control\rotation_journal.json'
    $sealedResumeJournalRecord = Read-QmRotationExactJsonFile -Path $sealedResumeJournalPath `
        -ExpectedFields (Get-QmRotationJournalFieldNames) -MaximumBytes 131072
    $sealedResumeJournal = $sealedResumeJournalRecord.Payload
    Assert-QmRotationJournalSchema -Journal $sealedResumeJournal
    if (-not (ConvertTo-QmRotationFullPath -Path ([string]$sealedResumeJournal.credential_helper_path)).Equals(
            $helperPath, [System.StringComparison]::OrdinalIgnoreCase
        )) {
        throw 'Resume journal credential-helper path differs from the fixed helper.'
    }
    $sealedHelperRecord = Read-QmRotationBoundFileBytes -Path $helperPath `
        -ExpectedSha256 ([string]$sealedResumeJournal.credential_helper_sha256) `
        -MinimumBytes 32 -MaximumBytes 1048576
    try {
        $sealedHelperText = [System.Text.UTF8Encoding]::new($false, $true).GetString($sealedHelperRecord.Bytes)
        . ([scriptblock]::Create($sealedHelperText))
    } finally {
        [System.Array]::Clear($sealedHelperRecord.Bytes, 0, $sealedHelperRecord.Bytes.Length)
        $sealedHelperText = $null
    }
    $resumeMutex = New-Object System.Threading.Mutex($false, $mutexName)
    $resumeMutexAcquired = $false
    try {
        try { $resumeMutexAcquired = $resumeMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $resumeMutexAcquired = $true }
        if (-not $resumeMutexAcquired) { throw 'Another DEV2 controller holds the exclusive rotation/recovery lock.' }
        Invoke-QmRotationResumeFinalize -RequestedDirectory $sealedResumeRun
    } finally {
        if ($resumeMutexAcquired) { try { $resumeMutex.ReleaseMutex() } catch { } }
        $resumeMutex.Dispose()
    }
    exit 0
}

. $helperPath

if (Test-Path -LiteralPath $canonicalRotationReceiptPath) {
    throw 'Canonical DEV2 machine-credential rotation receipt already exists; one-time rotation refuses replacement.'
}

$mutex = New-Object System.Threading.Mutex($false, $mutexName)
$mutexAcquired = $false
$primaryError = $null
$cleanupErrors = New-Object System.Collections.Generic.List[string]
$targetTaskRegistered = $false
$cleanupTaskRegistered = $false
$targetTaskName = $null
$cleanupTaskName = $null
$targetSid = $null
$accountEnabled = $false
$passwordText = $null
$securePassword = $null
$legacyCredential = $null
$passwordChanged = $false
$identityProved = $false
$credentialPublished = $false
$pendingCredentialPath = $null
$failedCredentialPath = $null
$rotationSucceeded = $false
$runDirectory = $null
$controlDirectory = $null
$outputDirectory = $null
$journalPath = $null
$journal = $null
$receiptPath = $null
$cleanupResultPath = $null
$cleanupDisarmPath = $null
$machineCredential = $null
$finalContainment = $null
$identityResultSha256 = $null
$legacyCredentialSha256 = $null
$canonicalRotationReceiptSha256 = $null
$contractSha256 = (Get-FileHash -LiteralPath $contractPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$helperSha256 = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$childSha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$cleanupSourceSha256 = (Get-FileHash -LiteralPath $cleanupSourcePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()

try {
    try { $mutexAcquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $mutexAcquired = $true }
    if (-not $mutexAcquired) { throw 'Another DEV2 controller holds the exclusive rotation lock.' }
    $null = Assert-QmRotationFreshApplyHistory
    Assert-QmRotationNoTasks
    $user = Get-LocalUser -Name $targetUserName -ErrorAction Stop
    if ($user.Name -cne $targetUserName -or $user.Enabled -or -not $user.PasswordRequired) {
        throw 'DEV2 rotation requires QMDev2 disabled-at-rest and password-required.'
    }
    $targetSid = $user.SID.Value
    $expectedAccount = "$env:COMPUTERNAME\$targetUserName"
    if ((Resolve-QmRotationSid -AccountName $expectedAccount) -cne $targetSid) {
        throw 'DEV2 rotation target account/SID binding drifted.'
    }
    foreach ($source in @($contractPath, $helperPath, $childPath, $legacyCredentialPath)) {
        Assert-QmRotationAdminControlledSourceFile -Path $source -ForbiddenWriterSid $targetSid
    }
    $legacyCredentialSha256 = (Get-FileHash -LiteralPath $legacyCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $legacyCredential = Import-Clixml -LiteralPath $legacyCredentialPath -ErrorAction Stop
    if ($legacyCredential -isnot [System.Management.Automation.PSCredential] -or
        (Resolve-QmRotationSid -AccountName $legacyCredential.UserName) -cne $targetSid -or
        $legacyCredential.Password.Length -le 0) {
        throw 'Legacy CurrentUser-DPAPI credential is not a nonempty PSCredential bound to QMDev2.'
    }
    $profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$targetSid"
    $profilePath = ConvertTo-QmRotationFullPath -Path ([System.Environment]::ExpandEnvironmentVariables(
            (Get-ItemProperty -LiteralPath $profileKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath
        ))
    Assert-QmRotationNoReparseComponents -Path $profilePath
    Assert-QmRotationTargetNonAdministrator -TargetSid $targetSid
    if (@(Get-QmRotationDev2Processes -TargetSid $targetSid).Count -ne 0) {
        throw 'DEV2 rotation requires zero target-SID and DEV2-root processes.'
    }
    if (Test-Path -LiteralPath $credentialPath) {
        throw 'DEV2 machine credential already exists; this one-time legacy rotation refuses replacement.'
    }

    $rotationId = '{0}_{1}' -f [DateTimeOffset]::UtcNow.ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N')
    $runDirectory = Join-Path $rotationRoot $rotationId
    $controlDirectory = Join-Path $runDirectory 'control'
    $outputDirectory = Join-Path $runDirectory 'output'
    foreach ($directory in @($rotationRoot, $runDirectory, $controlDirectory, $outputDirectory)) {
        if (-not (Test-Path -LiteralPath $directory)) { [void][System.IO.Directory]::CreateDirectory($directory) }
        Assert-QmRotationNoReparseComponents -Path $directory
    }
    Set-QmRotationDirectoryAcl -Path $runDirectory -TargetSid $targetSid `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Set-QmRotationDirectoryAcl -Path $controlDirectory -TargetSid $targetSid `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::ReadAndExecute)
    Set-QmRotationDirectoryAcl -Path $outputDirectory -TargetSid $targetSid `
        -TargetRights ([System.Security.AccessControl.FileSystemRights]::Modify)

    $journalPath = Join-Path $controlDirectory 'rotation_journal.json'
    $receiptPath = Join-Path $controlDirectory 'rotation_receipt.json'
    $requestPath = Join-Path $controlDirectory 'identity_probe_request.json'
    $identityResultPath = Join-Path $outputDirectory 'identity_probe_result.json'
    $cleanupResultPath = Join-Path $controlDirectory 'cleanup_lease.result.json'
    $cleanupDisarmPath = Join-Path $controlDirectory 'cleanup_lease.disarm.result.json'
    $nonce = [guid]::NewGuid().ToString('N')
    $targetTaskName = "$taskPrefix$([guid]::NewGuid().ToString('N'))"
    $cleanupTaskName = "$cleanupPrefix$([guid]::NewGuid().ToString('N'))"
    $cleanupActionMutex = $cleanupActionMutexPrefix + $nonce

    $passwordText = New-QmRotationPassword
    $pendingCredentialPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
        ("credential.machine-dpapi.pending.$nonce.json")
    $machineCredential = New-QmDev2MachineCredentialArtifact -CredentialPath $pendingCredentialPath `
        -Password $passwordText -ExpectedAccount $expectedAccount -ExpectedSid $targetSid `
        -ContractId $contractId -Lane $lane

    $request = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_IDENTITY_PROBE_REQUEST'
        nonce = $nonce
        created_utc = [DateTimeOffset]::UtcNow.ToString('o')
        expires_utc = [DateTimeOffset]::UtcNow.AddMinutes(10).ToString('o')
        expected_account = $expectedAccount
        expected_sid = $targetSid
        expected_profile = $profilePath
        expected_task_name = $targetTaskName
        result_path = $identityResultPath
    }
    Write-QmRotationJsonAtomic -Path $requestPath -Payload $request
    $requestSha256 = (Get-FileHash -LiteralPath $requestPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()

    $cleanupHelperPath = Join-Path $controlDirectory 'cleanup_dev2_account_lease.ps1'
    $cleanupGroupsPath = Join-Path $controlDirectory 'Darwinex-Live_real.canonical.txt'
    [System.IO.File]::Copy($cleanupSourcePath, $cleanupHelperPath, $false)
    [System.IO.File]::Copy($groupsCanonicalPath, $cleanupGroupsPath, $false)
    Set-QmDev2CredentialExactAcl -Path $cleanupHelperPath
    Set-QmDev2CredentialExactAcl -Path $cleanupGroupsPath
    $cleanupHelperSha256 = (Get-FileHash -LiteralPath $cleanupHelperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($cleanupHelperSha256 -cne $cleanupSourceSha256) { throw 'Rotation cleanup helper copy hash drifted.' }
    $groupsSha256 = (Get-FileHash -LiteralPath $cleanupGroupsPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    if ($groupsSha256 -cne (Get-FileHash -LiteralPath $groupsCanonicalPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()) {
        throw 'Rotation cleanup tester-groups copy hash drifted.'
    }
    $cleanupLeasePath = Join-Path $controlDirectory 'cleanup_lease.json'
    $cleanupExpires = [DateTimeOffset]::UtcNow.AddMinutes(15)
    $cleanupLease = [ordered]@{
        schema_version = 1
        artifact_type = 'QM_DEV2_ACCOUNT_CLEANUP_LEASE'
        run_id = $rotationId
        nonce = $nonce
        created_utc = [DateTimeOffset]::UtcNow.ToString('o')
        expires_utc = $cleanupExpires.ToString('o')
        run_directory = $runDirectory
        expected_sid = $targetSid
        dev2_root = $dev2Root
        target_task_name = $targetTaskName
        cleanup_task_name = $cleanupTaskName
        cleanup_action_mutex = $cleanupActionMutex
        helper_path = $cleanupHelperPath
        helper_sha256 = $cleanupHelperSha256
        tester_groups_source_path = $cleanupGroupsPath
        tester_groups_target_path = $groupsTargetPath
        tester_groups_sha256 = $groupsSha256
        result_path = $cleanupResultPath
        disarm_result_path = $cleanupDisarmPath
    }
    Write-QmRotationJsonAtomic -Path $cleanupLeasePath -Payload $cleanupLease
    Set-QmDev2CredentialExactAcl -Path $cleanupLeasePath
    $cleanupLeaseSha256 = (Get-FileHash -LiteralPath $cleanupLeasePath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
    $cleanupArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -LeasePath "{1}" -ExpectedSid "{2}" -TargetTaskName "{3}" -CleanupTaskName "{4}" -CleanupActionMutex "{5}" -ExpectedHelperSha256 "{6}"' -f `
        $cleanupHelperPath, $cleanupLeasePath, $targetSid, $targetTaskName, $cleanupTaskName,
        $cleanupActionMutex, $cleanupHelperSha256
    $cleanupAction = New-ScheduledTaskAction -Execute $pwshPath -Argument $cleanupArguments -WorkingDirectory $runDirectory
    $cleanupTriggers = @(
        (New-ScheduledTaskTrigger -AtStartup),
        (New-ScheduledTaskTrigger -Once -At $cleanupExpires.LocalDateTime -RepetitionInterval (New-TimeSpan -Minutes 5))
    )
    $cleanupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -MultipleInstances IgnoreNew `
        -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
    $cleanupPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest

    $journalCreatedUtc = [DateTimeOffset]::UtcNow.ToString('o')
    $journal = [ordered]@{
        schema_version = $journalSchemaVersion
        artifact_type = $journalArtifactType
        rotation_id = $rotationId
        nonce = $nonce
        phase = 'PREPARED'
        created_utc = $journalCreatedUtc
        updated_utc = $journalCreatedUtc
        contract_id = $contractId
        lane = $lane
        lane_contract_path = $contractPath
        lane_contract_sha256 = $contractSha256
        target_account = $expectedAccount
        target_sid = $targetSid
        target_profile = $profilePath
        identity_probe_logon_type = 'Password'
        identity_probe_run_level = 'Limited'
        credential_staged_path = $pendingCredentialPath
        credential_final_path = $credentialPath
        credential_sha256 = $machineCredential.Sha256
        credential_generation_id = $machineCredential.GenerationId
        credential_helper_path = $helperPath
        credential_helper_sha256 = $helperSha256
        identity_probe_child_path = $childPath
        identity_probe_child_sha256 = $childSha256
        identity_probe_request_path = $requestPath
        identity_probe_request_sha256 = $requestSha256
        identity_probe_result_path = $identityResultPath
        identity_probe_result_sha256 = $null
        identity_proof_completed_utc = $null
        identity_proof_verified = $false
        target_task_name = $targetTaskName
        cleanup_task_name = $cleanupTaskName
        cleanup_action_mutex = $cleanupActionMutex
        cleanup_lease_path = $cleanupLeasePath
        cleanup_lease_sha256 = $cleanupLeaseSha256
        cleanup_helper_path = $cleanupHelperPath
        cleanup_helper_sha256 = $cleanupHelperSha256
        tester_groups_source_path = $cleanupGroupsPath
        tester_groups_target_path = $groupsTargetPath
        tester_groups_sha256 = $groupsSha256
        cleanup_result_path = $cleanupResultPath
        cleanup_disarm_path = $cleanupDisarmPath
        cleanup_result_sha256 = $null
        cleanup_disarm_sha256 = $null
        cleanup_result_failure_archive_sha256 = $null
        cleanup_disarm_failure_archive_sha256 = $null
        legacy_credential_path = $legacyCredentialPath
        legacy_credential_sha256 = $legacyCredentialSha256
        legacy_credential_preserved = $true
        dynamic_receipt_path = $receiptPath
        canonical_receipt_path = $canonicalRotationReceiptPath
        receipt_completed_utc = $null
    }
    Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
    Write-QmRotationJournalExact -Path $journalPath -Payload $journal

    Register-ScheduledTask -TaskName $cleanupTaskName -TaskPath $taskPath -Action $cleanupAction `
        -Trigger $cleanupTriggers -Settings $cleanupSettings -Principal $cleanupPrincipal `
        -Description "Fail-closed DEV2 credential rotation cleanup lease $rotationId" -ErrorAction Stop | Out-Null
    $cleanupTaskRegistered = $true
    $registeredCleanupTask = Get-ScheduledTask -TaskName $cleanupTaskName -TaskPath $taskPath -ErrorAction Stop
    Assert-QmRotationCleanupTaskContract -Task $registeredCleanupTask -ExpectedTaskName $cleanupTaskName `
        -ExpectedArguments $cleanupArguments -ExpectedWorkingDirectory $runDirectory
    $journal.phase = 'CLEANUP_LEASE_ARMED'
    $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
    Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace

    $securePassword = ConvertTo-SecureString -String $passwordText -AsPlainText -Force
    Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -Password $securePassword -ErrorAction Stop
    $passwordChanged = $true
    $journal.phase = 'PASSWORD_SET'
    $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
    Enable-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -ErrorAction Stop
    $accountEnabled = $true
    $actionArguments = '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "{0}" -RequestPath "{1}" -ExpectedRequestSha256 "{2}"' -f `
        $childPath, $requestPath, $requestSha256
    $action = New-ScheduledTaskAction -Execute $pwshPath -Argument $actionArguments -WorkingDirectory $repoRoot
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -StartWhenAvailable -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -Action $action -Settings $settings `
        -User $expectedAccount -Password $passwordText -RunLevel Limited `
        -Description "Ephemeral DEV2 machine-credential identity proof $rotationId" -ErrorAction Stop | Out-Null
    $targetTaskRegistered = $true
    $passwordText = $null
    if ($null -ne $securePassword) { $securePassword.Dispose(); $securePassword = $null }
    $task = Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
    Assert-QmRotationTaskContract -Task $task -ExpectedTaskName $targetTaskName -ExpectedAccount $expectedAccount `
        -ExpectedSid $targetSid -ExpectedArguments $actionArguments -ExpectedWorkingDirectory $repoRoot
    $started = [DateTimeOffset]::UtcNow
    Start-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
    $deadline = $started.AddMinutes(3)
    do {
        if (Test-Path -LiteralPath $identityResultPath -PathType Leaf) { break }
        $task = Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
        if ($task.State.ToString() -ne 'Running') {
            $info = Get-ScheduledTaskInfo -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
            if ($info.LastRunTime.Year -gt 2000 -and $info.LastRunTime.ToUniversalTime() -ge $started.UtcDateTime.AddSeconds(-2)) { break }
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTimeOffset]::UtcNow -lt $deadline)
    $task = Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
    $info = Get-ScheduledTaskInfo -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
    if ($task.State.ToString() -eq 'Running' -or [int64]$info.LastTaskResult -ne 0 -or
        -not (Test-Path -LiteralPath $identityResultPath -PathType Leaf)) {
        throw 'DEV2 rotation Limited/Password identity-only child did not complete successfully.'
    }
    $expectedIdentityResultNames = @(
        'account', 'artifact_type', 'completed_utc', 'limited_non_admin', 'nonce',
        'profile', 'request_sha256', 'schema_version', 'sid', 'status'
    )
    $identityResultValueKinds = [ordered]@{
        account = 'String'
        artifact_type = 'String'
        completed_utc = 'String'
        limited_non_admin = 'Boolean'
        nonce = 'String'
        profile = 'String'
        request_sha256 = 'String'
        schema_version = 'Int32'
        sid = 'String'
        status = 'String'
    }
    $identityResultRecord = Read-QmRotationExactJsonFile -Path $identityResultPath `
        -ExpectedFields $expectedIdentityResultNames -ExpectedValueKinds $identityResultValueKinds -MaximumBytes 32768
    $identityResultSha256 = [string]$identityResultRecord.Sha256
    $identityResult = $identityResultRecord.Payload
    if ([int]$identityResult.schema_version -ne 1 -or [string]$identityResult.artifact_type -cne 'QM_DEV2_IDENTITY_PROBE_RESULT' -or
        [string]$identityResult.status -cne 'PASS' -or [string]$identityResult.nonce -cne $nonce -or
        [string]$identityResult.account -cne $expectedAccount -or [string]$identityResult.sid -cne $targetSid -or
        -not (ConvertTo-QmRotationFullPath -Path ([string]$identityResult.profile)).Equals(
            $profilePath, [System.StringComparison]::OrdinalIgnoreCase
        ) -or $identityResult.limited_non_admin -isnot [bool] -or -not [bool]$identityResult.limited_non_admin -or
        [string]$identityResult.request_sha256 -cne $requestSha256) {
        throw 'DEV2 rotation identity-only child returned stale or drifted proof.'
    }
    $identityCompleted = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact(
            [string]$identityResult.completed_utc, 'o', [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind, [ref]$identityCompleted
        ) -or $identityCompleted.Offset -ne [TimeSpan]::Zero -or
        $identityCompleted -lt $started.AddSeconds(-2) -or $identityCompleted -gt [DateTimeOffset]::UtcNow.AddMinutes(1)) {
        throw 'DEV2 rotation identity-only child completion time is stale or invalid.'
    }
    $task = Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
    if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
        Stop-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
    }
    if ($null -ne (Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue)) {
        Unregister-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
    }
    $targetTaskRegistered = $false
    Stop-QmRotationTargetProcesses -TargetSid $targetSid
    Disable-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -ErrorAction Stop
    $accountEnabled = $false
    $postProofUser = Get-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -ErrorAction Stop
    if ($postProofUser.Enabled -or -not $postProofUser.PasswordRequired -or
        @(Get-QmRotationDev2Processes -TargetSid $targetSid).Count -ne 0) {
        throw 'DEV2 identity proof did not return to disabled/process-free containment before publication.'
    }
    Set-QmDev2CredentialExactAcl -Path $requestPath
    Set-QmDev2CredentialExactAcl -Path $identityResultPath
    $sealedIdentityResult = Read-QmRotationExactJsonFile -Path $identityResultPath `
        -ExpectedFields $expectedIdentityResultNames -ExpectedSha256 $identityResultSha256 `
        -ExpectedValueKinds $identityResultValueKinds -MaximumBytes 32768
    if ([string]$sealedIdentityResult.Json -cne [string]$identityResultRecord.Json) {
        throw 'DEV2 rotation identity-only result changed before target write access was removed.'
    }
    $journal.identity_probe_result_sha256 = $identityResultSha256
    $journal.identity_proof_completed_utc = [string]$identityResult.completed_utc
    $journal.identity_proof_verified = $true
    $journal.phase = 'IDENTITY_PROVED'
    $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
    Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
    $null = Assert-QmRotationIdentityProofBindings -Journal ([pscustomobject]$journal) -RunDirectory $runDirectory
    $identityProved = $true
    Assert-QmRotationTargetNonAdministrator -TargetSid $targetSid
    [System.IO.File]::Move($pendingCredentialPath, $credentialPath, $false)
    try {
        Set-QmDev2CredentialExactAcl -Path $credentialPath
        $machineCredentialSha256 = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        if ($machineCredentialSha256 -cne $machineCredential.Sha256) {
            throw 'Published machine credential hash differs from its identity-proved staged binding.'
        }
        $credentialPublished = $true
        $pendingCredentialPath = $null
    } catch {
        $publishVerificationError = $_
        $failedCredentialPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
            ("credential.machine-dpapi.failed.$nonce.json")
        try {
            if (Test-Path -LiteralPath $failedCredentialPath) {
                throw 'Credential forensic quarantine path unexpectedly exists.'
            }
            if (Test-Path -LiteralPath $credentialPath -PathType Leaf) {
                [System.IO.File]::Move($credentialPath, $failedCredentialPath, $false)
                $pendingCredentialPath = $failedCredentialPath
            }
            Set-QmDev2CredentialExactAcl -Path $failedCredentialPath
            $failedHash = (Get-FileHash -LiteralPath $failedCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            if ($failedHash -cne $machineCredential.Sha256) {
                throw 'Forensically quarantined machine credential hash drifted.'
            }
        } catch {
            throw "Machine credential publish verification and forensic quarantine both failed: publish=$($publishVerificationError.Exception.Message); quarantine=$($_.Exception.Message)"
        }
        throw $publishVerificationError
    }
    $journal.phase = 'CREDENTIAL_PUBLISHED_AFTER_IDENTITY_PROOF'
    $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
    Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
    $rotationSucceeded = $true
} catch {
    $primaryError = $_
} finally {
    $passwordText = $null
    if ($null -ne $securePassword) { try { $securePassword.Dispose() } catch { }; $securePassword = $null }
    if ($targetTaskRegistered -and -not [string]::IsNullOrWhiteSpace($targetTaskName)) {
        try {
            $task = Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue
            if ($null -ne $task -and $task.State.ToString() -eq 'Running') {
                Stop-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction Stop
            }
            if ($null -ne (Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue)) {
                Unregister-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -Confirm:$false -ErrorAction Stop
            }
            $targetTaskRegistered = $false
        } catch { $cleanupErrors.Add("identity_task_cleanup: $($_.Exception.Message)") }
    }
    if ($null -ne $primaryError -and $passwordChanged -and -not $credentialPublished) {
        try {
            if ($null -eq $journal -or [string]::IsNullOrWhiteSpace($journalPath)) {
                throw 'Rollback intent cannot be sealed before credential/password mutation.'
            }
            $journal.phase = 'PASSWORD_ROLLBACK_INTENT_FORENSICALLY_BOUND'
            $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
            Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
            Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
            if (Test-Path -LiteralPath $credentialPath -PathType Leaf) {
                if ([string]::IsNullOrWhiteSpace($failedCredentialPath)) {
                    $failedCredentialPath = Join-Path ([System.IO.Path]::GetDirectoryName($credentialPath)) `
                        ("credential.machine-dpapi.failed.$nonce.json")
                }
                if (Test-Path -LiteralPath $failedCredentialPath) {
                    throw 'Credential forensic quarantine path unexpectedly exists during rollback.'
                }
                [System.IO.File]::Move($credentialPath, $failedCredentialPath, $false)
                $pendingCredentialPath = $failedCredentialPath
            } elseif (-not [string]::IsNullOrWhiteSpace($failedCredentialPath) -and
                (Test-Path -LiteralPath $failedCredentialPath -PathType Leaf)) {
                $pendingCredentialPath = $failedCredentialPath
            }
            if (Test-Path -LiteralPath $credentialPath) {
                throw 'Canonical machine credential remains present before legacy-password rollback.'
            }
            if ([string]::IsNullOrWhiteSpace($pendingCredentialPath) -or
                -not (Test-Path -LiteralPath $pendingCredentialPath -PathType Leaf)) {
                throw 'Forensically bound pending machine credential is missing before legacy-password rollback.'
            }
            Set-QmDev2CredentialExactAcl -Path $pendingCredentialPath
            Assert-QmDev2CredentialExactAcl -Path $pendingCredentialPath
            $pendingHash = (Get-FileHash -LiteralPath $pendingCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            if ($null -eq $machineCredential -or $pendingHash -cne $machineCredential.Sha256) {
                throw 'Pending machine credential differs from its forensic binding before legacy-password rollback.'
            }
            if ($null -eq $legacyCredential -or $legacyCredential.Password.Length -le 0 -or
                (Resolve-QmRotationSid -AccountName $legacyCredential.UserName) -cne $targetSid) {
                throw 'Legacy rollback credential is unavailable or no longer bound to QMDev2.'
            }
            Set-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) `
                -Password $legacyCredential.Password -ErrorAction Stop
            $passwordChanged = $false
            if ($null -ne $journal -and -not [string]::IsNullOrWhiteSpace($journalPath)) {
                $journal.phase = 'PASSWORD_ROLLED_BACK_TO_LEGACY_PENDING_FORENSICALLY_BOUND'
                $journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
                Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
            }
        } catch {
            $cleanupErrors.Add("password_rollback: $($_.Exception.Message)")
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($targetSid)) {
        try { Stop-QmRotationTargetProcesses -TargetSid $targetSid } catch { $cleanupErrors.Add("process_cleanup: $($_.Exception.Message)") }
        try {
            $sid = New-Object System.Security.Principal.SecurityIdentifier($targetSid)
            $current = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($current.Enabled) { Disable-LocalUser -SID $sid -ErrorAction Stop }
            $verified = Get-LocalUser -SID $sid -ErrorAction Stop
            if ($verified.Enabled -or -not $verified.PasswordRequired) { throw 'QMDev2 did not return to disabled-at-rest.' }
            $accountEnabled = $false
        } catch { $cleanupErrors.Add("account_disable: $($_.Exception.Message)") }
        try {
            if (@(Get-QmRotationDev2Processes -TargetSid $targetSid).Count -ne 0) {
                throw 'DEV2 owner/root processes remain after rotation containment.'
            }
        } catch { $cleanupErrors.Add("process_postcheck: $($_.Exception.Message)") }
    }
    if ($cleanupTaskRegistered -and -not [string]::IsNullOrWhiteSpace($cleanupTaskName)) {
        if ($null -ne $primaryError -or $cleanupErrors.Count -gt 0) {
            try {
                Start-ScheduledTask -TaskName $cleanupTaskName -TaskPath $taskPath -ErrorAction Stop
                $cleanupDeadline = [DateTimeOffset]::UtcNow.AddMinutes(3)
                do {
                    if (Test-Path -LiteralPath $cleanupDisarmPath -PathType Leaf) { break }
                    Start-Sleep -Milliseconds 500
                } while ([DateTimeOffset]::UtcNow -lt $cleanupDeadline)
                if (-not (Test-Path -LiteralPath $cleanupDisarmPath -PathType Leaf)) {
                    throw 'SYSTEM cleanup lease produced no disarm receipt.'
                }
                $cleanupReceipt = Get-Content -LiteralPath $cleanupDisarmPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                if ([string]$cleanupReceipt.artifact_type -cne 'QM_DEV2_ACCOUNT_CLEANUP_DISARM_RESULT' -or
                    $cleanupReceipt.success -isnot [bool] -or -not [bool]$cleanupReceipt.success -or
                    $cleanupReceipt.containment_verified -isnot [bool] -or -not [bool]$cleanupReceipt.containment_verified -or
                    $cleanupReceipt.lease_disarmed -isnot [bool] -or -not [bool]$cleanupReceipt.lease_disarmed -or
                    $cleanupReceipt.account_restored_disabled -isnot [bool] -or -not [bool]$cleanupReceipt.account_restored_disabled -or
                    [string]$cleanupReceipt.expected_sid -cne $targetSid -or
                    [string]$cleanupReceipt.target_task_name -cne $targetTaskName -or
                    [string]$cleanupReceipt.cleanup_task_name -cne $cleanupTaskName -or
                    [int]$cleanupReceipt.owner_process_count -ne 0 -or [int]$cleanupReceipt.dev2_root_process_count -ne 0 -or
                    [bool]$cleanupReceipt.target_task_registered -or [bool]$cleanupReceipt.cleanup_task_registered -or
                    -not (ConvertTo-QmRotationFullPath -Path ([string]$cleanupReceipt.containment_result_path)).Equals(
                        $cleanupResultPath, [System.StringComparison]::OrdinalIgnoreCase
                    )) {
                    throw 'SYSTEM cleanup lease disarm receipt failed its exact containment binding.'
                }
                $postCleanupUser = Get-LocalUser -SID (New-Object System.Security.Principal.SecurityIdentifier($targetSid)) -ErrorAction Stop
                if ($postCleanupUser.Enabled -or -not $postCleanupUser.PasswordRequired -or
                    @(Get-QmRotationDev2Processes -TargetSid $targetSid).Count -ne 0 -or
                    $null -ne (Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue) -or
                    $null -ne (Get-ScheduledTask -TaskName $cleanupTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue)) {
                    throw 'SYSTEM cleanup lease failed independent rotation containment postchecks.'
                }
                $cleanupTaskRegistered = $false
            } catch { $cleanupErrors.Add("system_cleanup_lease: $($_.Exception.Message)") }
        } else {
            try {
                Remove-QmRotationScheduledTaskBounded -TaskName $cleanupTaskName -DisableBeforeStop
                $cleanupTaskRegistered = $false
            } catch { $cleanupErrors.Add("cleanup_lease_disarm: $($_.Exception.Message)") }
        }
    }
    if ($null -ne $legacyCredential) {
        try { $legacyCredential.Password.Dispose() } catch { }
        $legacyCredential = $null
    }
}

if ($null -ne $primaryError -or $cleanupErrors.Count -gt 0 -or -not $rotationSucceeded) {
    $primaryMessage = if ($null -ne $primaryError) { $primaryError.Exception.Message } else { 'rotation did not reach identity proof' }
    if ($mutexAcquired) { try { $mutex.ReleaseMutex() } catch { } }
    $mutex.Dispose()
    throw "DEV2 machine-credential rotation failed closed: $primaryMessage; containment=$([string]::Join(' | ', $cleanupErrors.ToArray()))"
}

try {
$credentialSha256 = (Get-FileHash -LiteralPath $credentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
Assert-QmDev2CredentialExactAcl -Path ([System.IO.Path]::GetDirectoryName($credentialPath)) -Directory
Assert-QmDev2CredentialExactAcl -Path $credentialPath
$finalUser = Get-LocalUser -Name $targetUserName -ErrorAction Stop
$finalHelperSha256 = (Get-FileHash -LiteralPath $helperPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$finalChildSha256 = (Get-FileHash -LiteralPath $childPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$finalIdentityResultSha256 = (Get-FileHash -LiteralPath $identityResultPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
$finalLegacyCredentialSha256 = if (Test-Path -LiteralPath $legacyCredentialPath -PathType Leaf) {
    (Get-FileHash -LiteralPath $legacyCredentialPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
} else {
    $null
}
Assert-QmRotationNoTasks
if ($finalUser.Enabled -or $finalUser.SID.Value -cne $targetSid -or -not $finalUser.PasswordRequired -or
    @(Get-QmRotationDev2Processes -TargetSid $targetSid).Count -ne 0 -or $targetTaskRegistered -or $cleanupTaskRegistered -or
    $null -ne (Get-ScheduledTask -TaskName $targetTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue) -or
    $null -ne (Get-ScheduledTask -TaskName $cleanupTaskName -TaskPath $taskPath -ErrorAction SilentlyContinue) -or
    $credentialSha256 -cne $machineCredential.Sha256 -or $finalHelperSha256 -cne $helperSha256 -or
    $finalChildSha256 -cne $childSha256 -or $finalIdentityResultSha256 -cne $identityResultSha256 -or
    [string]::IsNullOrWhiteSpace($finalLegacyCredentialSha256) -or
    $finalLegacyCredentialSha256 -cne $legacyCredentialSha256) {
    throw 'DEV2 machine-credential rotation final containment proof failed.'
}
$finalLeaseBinding = Assert-QmRotationCleanupLeaseBindings -Journal ([pscustomobject]$journal) -RunDirectory $runDirectory
$finalContainment = Invoke-QmRotationRecoveryContainment -Journal ([pscustomobject]$journal) `
    -LeaseBinding $finalLeaseBinding -RunDirectory $runDirectory
$null = Assert-QmRotationIdentityProofBindings -Journal ([pscustomobject]$journal) -RunDirectory $runDirectory
if ((Get-FileHash -LiteralPath $contractPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant() -cne
    [string]$journal.lane_contract_sha256) {
    throw 'DEV2 lane contract changed before final receipt publication.'
}
if (Test-Path -LiteralPath $canonicalRotationReceiptPath) {
    throw 'Canonical DEV2 machine-credential rotation receipt appeared before one-time publication.'
}
$journal.cleanup_result_sha256 = $finalContainment.CleanupResultSha256
$journal.cleanup_disarm_sha256 = $finalContainment.CleanupDisarmSha256
$journal.cleanup_result_failure_archive_sha256 = $finalContainment.CleanupResultFailureArchiveSha256
$journal.cleanup_disarm_failure_archive_sha256 = $finalContainment.CleanupDisarmFailureArchiveSha256
$journal.receipt_completed_utc = [DateTimeOffset]::UtcNow.ToString('o')
$journal.phase = 'FINAL_CONTAINMENT_VERIFIED'
$journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
Assert-QmRotationJournalSchema -Journal ([pscustomobject]$journal)
Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
$receipt = New-QmRotationCanonicalReceiptPayload -Journal ([pscustomobject]$journal) `
    -CredentialSha256 $credentialSha256
Assert-QmRotationCleanupEvidenceHashBindings -Journal ([pscustomobject]$journal)
Write-QmRotationJsonAtomic -Path $receiptPath -Payload $receipt
Set-QmDev2CredentialExactAcl -Path $receiptPath
Assert-QmRotationCleanupEvidenceHashBindings -Journal ([pscustomobject]$journal)
$journal.phase = 'READY_FOR_CANONICAL_RECEIPT'
$journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
Assert-QmRotationTargetNonAdministrator -TargetSid $targetSid
Assert-QmRotationCleanupEvidenceHashBindings -Journal ([pscustomobject]$journal)
$canonicalRotationReceiptSha256 = Write-QmCanonicalRotationReceipt `
    -Path $canonicalRotationReceiptPath -Payload $receipt
$null = Assert-QmRotationReceiptExact -Path $receiptPath -ExpectedPayload $receipt -RequireExactAcl
$null = Assert-QmRotationReceiptExact -Path $canonicalRotationReceiptPath -ExpectedPayload $receipt -RequireExactAcl
Assert-QmRotationCleanupEvidenceHashBindings -Journal ([pscustomobject]$journal)
$journal.phase = 'COMMITTED'
$journal.updated_utc = [DateTimeOffset]::UtcNow.ToString('o')
Write-QmRotationJournalExact -Path $journalPath -Payload $journal -Replace
Write-Output ([ordered]@{
        status = 'PASS'
        receipt_path = $canonicalRotationReceiptPath
        receipt_sha256 = $canonicalRotationReceiptSha256
        run_receipt_path = $receiptPath
        run_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
        target_disabled_at_rest = $true
        legacy_credential_preserved = $true
    } | ConvertTo-Json -Depth 3 -Compress)
} finally {
    if ($null -ne $finalContainment) {
        Exit-QmRotationCleanupActionMutex -Fence $finalContainment.CleanupActionFence
    }
    if ($mutexAcquired) { try { $mutex.ReleaseMutex() } catch { } }
    $mutex.Dispose()
}
