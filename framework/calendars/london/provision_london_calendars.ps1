[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CommonFilesRoot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$manifestName = 'QM5_London_calendar_manifest.json'
$expectedManifestSha256 = '4b8da9e3af536c99db2f3d2571d4082f2ee81deb3b0e2cb2c6c56e13b2aecc7d'
$dataRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'data'))
$manifestPath = [IO.Path]::GetFullPath((Join-Path $dataRoot $manifestName))

if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "London calendar manifest is missing: $manifestPath"
}
$manifestHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $manifestPath).Hash.ToLowerInvariant()
if ($manifestHash -ne $expectedManifestSha256) {
    throw "London calendar manifest hash mismatch: expected $expectedManifestSha256 and found $manifestHash."
}
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json

if ($manifest.schema_version -ne 1 -or $manifest.bundle_id -ne 'QM5_LONDON_CALENDARS') {
    throw 'Unexpected London calendar manifest identity.'
}
if ($manifest.outside_coverage_policy -ne 'FAIL_CLOSED') {
    throw 'London calendar manifest is not fail-closed.'
}

$artifacts = [Collections.Generic.List[object]]::new()
function Add-BoundArtifact {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Sha256
    )

    if ([IO.Path]::GetFileName($Name) -ne $Name -or $Name -match '[\\/]') {
        throw "Manifest artifact is not a leaf filename: $Name"
    }
    if ($Sha256 -notmatch '^[0-9a-f]{64}$') {
        throw "Manifest artifact has an invalid SHA-256: $Name"
    }
    if (@($artifacts | Where-Object Name -eq $Name).Count -ne 0) {
        throw "Manifest artifact is duplicated: $Name"
    }
    $artifacts.Add([pscustomobject]@{ Name = $Name; Sha256 = $Sha256 })
}

Add-BoundArtifact -Name $manifest.england_wales_public_holidays.runtime_file -Sha256 $manifest.england_wales_public_holidays.runtime_sha256
Add-BoundArtifact -Name $manifest.england_wales_public_holidays.provenance_file -Sha256 $manifest.england_wales_public_holidays.provenance_sha256
Add-BoundArtifact -Name $manifest.lse_cash_sessions.runtime_file -Sha256 $manifest.lse_cash_sessions.runtime_sha256
Add-BoundArtifact -Name $manifest.lse_cash_sessions.provenance_file -Sha256 $manifest.lse_cash_sessions.provenance_sha256
Add-BoundArtifact -Name $manifest.wmr_1600_london_spot_service.runtime_file -Sha256 $manifest.wmr_1600_london_spot_service.runtime_sha256
Add-BoundArtifact -Name $manifest.wmr_1600_london_spot_service.provenance_file -Sha256 $manifest.wmr_1600_london_spot_service.provenance_sha256
Add-BoundArtifact -Name $manifest.sources_file -Sha256 $manifest.sources_sha256
Add-BoundArtifact -Name $manifestName -Sha256 $expectedManifestSha256

if ($artifacts.Count -ne 8) {
    throw "Expected eight London calendar artifacts and found $($artifacts.Count)."
}

$rootFull = [IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
if ($rootFull -match '(?i)(?:^|\\)T_Live(?:\\|$)') {
    throw "Refusing to provision inside T_Live: $rootFull"
}
$driveRoot = [IO.Path]::GetPathRoot($rootFull).TrimEnd('\')
if ($driveRoot -eq $rootFull.TrimEnd('\')) {
    throw "Refusing to use a drive root as CommonFilesRoot: $rootFull"
}

$prepared = [Collections.Generic.List[object]]::new()
foreach ($artifact in $artifacts) {
    $source = [IO.Path]::GetFullPath((Join-Path $dataRoot $artifact.Name))
    if ([IO.Path]::GetDirectoryName($source).TrimEnd('\') -ne $dataRoot.TrimEnd('\')) {
        throw "Resolved source escaped the calendar data directory: $source"
    }
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "London calendar artifact is missing: $source"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
    if ($sourceHash -ne $artifact.Sha256) {
        throw "London calendar artifact hash mismatch for $($artifact.Name): expected $($artifact.Sha256) and found $sourceHash."
    }

    $target = [IO.Path]::GetFullPath((Join-Path $rootFull $artifact.Name))
    if ([IO.Path]::GetDirectoryName($target).TrimEnd('\') -ne $rootFull.TrimEnd('\')) {
        throw "Resolved target escaped CommonFilesRoot: $target"
    }
    if ($target -match '(?i)(?:^|\\)T_Live(?:\\|$)') {
        throw "Refusing a T_Live target: $target"
    }

    $status = 'MISSING'
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
        if ($targetHash -ne $artifact.Sha256) {
            throw "A mismatched London calendar artifact already exists at $target (sha256=$targetHash)."
        }
        $status = 'ALREADY_PROVISIONED'
    }
    $prepared.Add([pscustomobject]@{
        Name = $artifact.Name
        Source = $source
        Target = $target
        Sha256 = $artifact.Sha256
        Status = $status
    })
}

foreach ($item in $prepared) {
    if ($item.Status -eq 'ALREADY_PROVISIONED') {
        [pscustomobject]@{
            status = $item.Status
            source = $item.Source
            target = $item.Target
            sha256 = $item.Sha256
        }
        continue
    }

    if ($PSCmdlet.ShouldProcess($item.Target, "Provision $($item.Name)")) {
        New-Item -ItemType Directory -Path $rootFull -Force | Out-Null
        Copy-Item -LiteralPath $item.Source -Destination $item.Target
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.Target).Hash.ToLowerInvariant()
        if ($targetHash -ne $item.Sha256) {
            throw "Provisioned London calendar artifact failed hash verification at $($item.Target): $targetHash."
        }
        [pscustomobject]@{
            status = 'PROVISIONED'
            source = $item.Source
            target = $item.Target
            sha256 = $targetHash
        }
    }
    else {
        [pscustomobject]@{
            status = 'WOULD_PROVISION'
            source = $item.Source
            target = $item.Target
            sha256 = $item.Sha256
        }
    }
}
