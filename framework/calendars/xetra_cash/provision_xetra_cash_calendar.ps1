[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CommonFilesRoot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifacts = @(
    [pscustomobject]@{ Name='QM5_XETRA_cash_session_exceptions_20180101_20251231.csv'; Sha256='c6ea69e62bdd309c7253b2db9b09cacb0116ff1001e0ce9cb7ace03bda024ff2' }
    [pscustomobject]@{ Name='QM5_XETRA_cash_session_exceptions_provenance.csv'; Sha256='0c13afc835591149c96cff1def7c40519fe094cd8f7cf4d45683204774cf38ae' }
    [pscustomobject]@{ Name='QM5_XETRA_cash_session_exceptions_sources.csv'; Sha256='11987919c48bdcc68f1a77fecbaaa0058b87c56ec4cf90e5bedd3712717f48db' }
    [pscustomobject]@{ Name='QM5_XETRA_cash_session_exceptions_manifest.json'; Sha256='5c914c3ce1a9c3a7c2e69c97be0236ec3e2c401e2d8d8a2ee9ec5c29280902f1' }
)

$rootFull = [IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
if ($rootFull -match '(?i)(?:^|\\)T_Live(?:\\|$)') {
    throw "Refusing to provision inside T_Live: $rootFull"
}
if ([IO.Path]::GetPathRoot($rootFull).TrimEnd('\') -eq $rootFull.TrimEnd('\')) {
    throw "Refusing to use a drive root as CommonFilesRoot: $rootFull"
}
if ($rootFull -notmatch '(?i)\\Common\\Files$') {
    throw "CommonFilesRoot must end in Common\Files: $rootFull"
}

# Preflight every source and every existing target before copying anything.
# A conflicting target aborts the entire operation, preventing a partial set.
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
        [pscustomobject]@{ status=$item.Status; source=$item.Source; target=$item.Target; sha256=$item.Sha256 }
        continue
    }

    if ($PSCmdlet.ShouldProcess($item.Target, "Provision $($item.Name)")) {
        New-Item -ItemType Directory -Path $rootFull -Force | Out-Null
        Copy-Item -LiteralPath $item.Source -Destination $item.Target
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $item.Target).Hash.ToLowerInvariant()
        if ($targetHash -ne $item.Sha256) {
            throw "Provisioned calendar artifact failed hash verification at $($item.Target): $targetHash."
        }
        [pscustomobject]@{ status='PROVISIONED'; source=$item.Source; target=$item.Target; sha256=$targetHash }
    }
    else {
        [pscustomobject]@{ status='WOULD_PROVISION'; source=$item.Source; target=$item.Target; sha256=$item.Sha256 }
    }
}
