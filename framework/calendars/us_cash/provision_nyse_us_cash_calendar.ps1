[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CommonFilesRoot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifacts = @(
    [pscustomobject]@{
        Name = 'QM5_NYSE_US_cash_session_exceptions_20180101_20251231.csv'
        Sha256 = 'c2e87e2f72b5a5fc09ae6632a2ddc47cfa3cfdd98af7deb67a42292bcaf5fd11'
    }
    [pscustomobject]@{
        Name = 'QM5_NYSE_US_cash_session_exceptions_provenance.csv'
        Sha256 = '792a50afd9ea9a3ca2be5daf50d75d7c65130cf9bff424795937e7028a518136'
    }
    [pscustomobject]@{
        Name = 'QM5_NYSE_US_cash_session_exceptions_sources.csv'
        Sha256 = 'cf2cd19b3767f41dd1a9fd9af8cb50fa1b1daa6ce532221b884f21cffee06429'
    }
    [pscustomobject]@{
        Name = 'QM5_NYSE_US_cash_session_exceptions_manifest.json'
        Sha256 = '38cb75a7af6e5648ccf9a2016200cd37db634007d3a51d70d741c88f0fa32b92'
    }
)

$rootFull = [IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
if ($rootFull -match '(?i)(?:^|\\)T_Live(?:\\|$)') {
    throw "Refusing to provision inside T_Live: $rootFull"
}
if ([IO.Path]::GetPathRoot($rootFull).TrimEnd('\') -eq $rootFull.TrimEnd('\')) {
    throw "Refusing to use a drive root as CommonFilesRoot: $rootFull"
}

$prepared = [Collections.Generic.List[object]]::new()
foreach ($artifact in $artifacts) {
    $source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "data\$($artifact.Name)"))
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Calendar artifact is missing: $source"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
    if ($sourceHash -ne $artifact.Sha256) {
        throw "Calendar artifact hash mismatch for $($artifact.Name): expected $($artifact.Sha256), found $sourceHash."
    }

    $target = [IO.Path]::GetFullPath((Join-Path $rootFull $artifact.Name))
    if ([IO.Path]::GetDirectoryName($target).TrimEnd('\') -ne $rootFull.TrimEnd('\')) {
        throw "Resolved target escaped CommonFilesRoot: $target"
    }

    $status = 'MISSING'
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
        if ($targetHash -ne $artifact.Sha256) {
            throw "A mismatched calendar artifact already exists at $target (sha256=$targetHash)."
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
            throw "Provisioned calendar artifact failed hash verification at $($item.Target): $targetHash."
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
