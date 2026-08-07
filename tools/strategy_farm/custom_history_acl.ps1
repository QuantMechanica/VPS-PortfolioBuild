[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Plan', 'Apply', 'Verify')]
    [string]$Mode,

    [Parameter(Mandatory = $true)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $true)]
    [string]$OwnerReceiptPath,

    [Parameter(Mandatory = $true)]
    [string]$SourceCustom,

    [Parameter(Mandatory = $true)]
    [string]$EvidencePath,

    [string]$FarmRoot = 'D:\QM\strategy_farm',

    [switch]$Execute
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Write-AtomicJson([string]$Path, [object]$Value) {
    $absolute = [System.IO.Path]::GetFullPath($Path)
    $parent = [System.IO.Path]::GetDirectoryName($absolute)
    [System.IO.Directory]::CreateDirectory($parent) | Out-Null
    $temporary = Join-Path $parent ('.' + [System.IO.Path]::GetFileName($absolute) + '.' + $PID + '.tmp')
    try {
        $json = $Value | ConvertTo-Json -Depth 20
        [System.IO.File]::WriteAllText($temporary, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $absolute -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

$manifestFile = [System.IO.Path]::GetFullPath($ManifestPath)
$ownerFile = [System.IO.Path]::GetFullPath($OwnerReceiptPath)
$sourceRoot = [System.IO.Path]::GetFullPath($SourceCustom).TrimEnd('\')
$farmRootPath = [System.IO.Path]::GetFullPath($FarmRoot).TrimEnd('\')
$python = Get-Command python.exe -ErrorAction Stop
$pythonPath = $python.Source
$validator = Join-Path $PSScriptRoot 'custom_history_migration.py'
$validationArguments = @($validator, 'validate-authorization', '--manifest', $manifestFile, '--owner-receipt', $ownerFile)
if ($Mode -eq 'Apply') {
    $validationArguments += @('--farm-root', $farmRootPath, '--require-mutation-guard')
}
$validationOutput = & $pythonPath @validationArguments 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Python manifest/OWNER authorization validation failed: $($validationOutput -join [Environment]::NewLine)"
}
$manifest = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json
$owner = Get-Content -Raw -LiteralPath $ownerFile | ConvertFrom-Json

if ($manifest.schema_version -ne 'qm.custom-history-archive-manifest/v1') { throw 'Unsupported manifest schema' }
if ([System.IO.Path]::GetFullPath([string]$manifest.source_custom).TrimEnd('\') -ne $sourceRoot) { throw 'SourceCustom differs from the signed manifest source' }
if ($manifest.hash_mode -ne 'SHA256_FULL') { throw 'ACL mutation requires a full-hash manifest' }
if ($null -eq $manifest.owner_approval) { throw 'Manifest has no OWNER approval' }
if ($owner.authority -ne 'OWNER' -or [string]::IsNullOrWhiteSpace([string]$owner.signature)) { throw 'Detached OWNER receipt is unsigned' }
if ($owner.rollback_authorized -ne $true -or $owner.variant -ne 'A') { throw 'Detached OWNER receipt does not authorize Variant A rollback' }
if ($owner.claude_review_verdict -ne 'APPROVED' -or [string]$owner.implementation_git_commit -notmatch '^[0-9a-f]{40}$') { throw 'Detached OWNER receipt does not bind an APPROVED Claude review and implementation commit' }
if ($owner.manifest_sha256 -ne $manifest.manifest_sha256) { throw 'Detached OWNER receipt manifest hash mismatch' }
if ($Mode -eq 'Apply' -and -not $Execute) { throw 'Apply mode requires -Execute' }
if ($Mode -eq 'Apply') {
    $factoryOff = Join-Path $farmRootPath 'state\FACTORY_OFF.flag'
    $containmentPath = Join-Path $farmRootPath 'state\custom_history_containment_mode.json'
    if (-not (Test-Path -LiteralPath $factoryOff -PathType Leaf)) { throw 'ACL Apply requires FACTORY_OFF.flag' }
    if (-not (Test-Path -LiteralPath $containmentPath -PathType Leaf)) { throw 'ACL Apply requires containment mode receipt' }
    $containment = Get-Content -Raw -LiteralPath $containmentPath | ConvertFrom-Json
    if ($containment.enabled -ne $true -or $containment.schema_version -ne 'qm.custom-history-containment-mode/v1') { throw 'ACL Apply requires engaged global containment' }
}

$account = [System.Security.Principal.NTAccount]::new([string]$manifest.runner_identity)
$sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
$rights = [System.Security.AccessControl.FileSystemRights]::Write -bor
          [System.Security.AccessControl.FileSystemRights]::Delete -bor
          [System.Security.AccessControl.FileSystemRights]::ChangePermissions -bor
          [System.Security.AccessControl.FileSystemRights]::TakeOwnership
$denyRule = [System.Security.AccessControl.FileSystemAccessRule]::new(
    $sid,
    $rights,
    [System.Security.AccessControl.AccessControlType]::Deny
)

$failures = [System.Collections.Generic.List[object]]::new()
$verified = 0
$applied = 0
foreach ($row in $manifest.files) {
    $relative = ([string]$row.relative_path).Replace('/', '\')
    $path = [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
    if (-not ($path.StartsWith($sourceRoot + '\', [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Manifest path escapes SourceCustom: $relative"
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add([pscustomobject]@{relative_path=$row.relative_path;reason='MISSING'})
        continue
    }
    if ((Get-Sha256 $path) -ne ([string]$row.sha256).ToLowerInvariant()) {
        $failures.Add([pscustomobject]@{relative_path=$row.relative_path;reason='SHA256_MISMATCH'})
        continue
    }
    if ($Mode -eq 'Apply') {
        $acl = Get-Acl -LiteralPath $path
        $acl.SetAccessRule($denyRule)
        Set-Acl -LiteralPath $path -AclObject $acl
        $applied++
    }
    if ($Mode -in @('Apply', 'Verify')) {
        $acl = Get-Acl -LiteralPath $path
        $rules = $acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])
        $denied = $false
        foreach ($rule in $rules) {
            if ($rule.IdentityReference.Value -eq $sid.Value -and
                $rule.AccessControlType -eq [System.Security.AccessControl.AccessControlType]::Deny -and
                (([int]$rule.FileSystemRights -band [int]$rights) -eq [int]$rights)) {
                $denied = $true
            }
        }
        if (-not $denied) {
            $failures.Add([pscustomobject]@{relative_path=$row.relative_path;reason='WRITE_DELETE_DENY_MISSING'})
        }
        else {
            $verified++
        }
    }
}

$payload = [ordered]@{
    schema_version = 'qm.custom-history-archive-acl/v1'
    mode = $Mode.ToUpperInvariant()
    runtime_action = if ($Mode -eq 'Apply') { 'ACL_DENY_APPLIED' } else { 'NONE' }
    status = if ($failures.Count -eq 0) { 'PASS' } else { 'FAIL_CLOSED' }
    manifest_sha256 = [string]$manifest.manifest_sha256
    manifest_file_sha256 = Get-Sha256 $manifestFile
    owner_receipt_sha256 = Get-Sha256 $ownerFile
    runner_identity = [string]$manifest.runner_identity
    runner_sid = $sid.Value
    archive_file_count = @($manifest.files).Count
    applied = $applied
    verified = $verified
    failures = @($failures)
    recorded_at_utc = [DateTime]::UtcNow.ToString('o')
}

if ($Mode -in @('Apply', 'Verify')) {
    Write-AtomicJson -Path $EvidencePath -Value $payload
    $payload['evidence_path'] = [System.IO.Path]::GetFullPath($EvidencePath)
    $payload['evidence_sha256'] = Get-Sha256 $EvidencePath
}

$payload | ConvertTo-Json -Compress -Depth 20
if ($payload.status -ne 'PASS') { exit 2 }
