[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CommonFilesRoot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$artifacts = @(
    [pscustomobject]@{
        Name = 'QM5_LBMA_Gold_PM_schedule_20200101_20251231.csv'
        Sha256 = 'b71f6a2fc04565a3d7aed997b8876b7ba8b5d0b913383b4340814e56db527d94'
    }
    [pscustomobject]@{
        Name = 'QM5_LBMA_Gold_PM_schedule_provenance.csv'
        Sha256 = 'f2507db2327e0a8ba3407a3076c6a379f7ecf36726c505bce7501bb856d96b16'
    }
    [pscustomobject]@{
        Name = 'QM5_LBMA_Gold_PM_schedule_sources.csv'
        Sha256 = '4f3076944d906b1a67dc9890f883f375ea19e354af7db8a0b8d312118a5ad8de'
    }
    [pscustomobject]@{
        Name = 'QM5_Europe_London_transitions_20180101_20251231.csv'
        Sha256 = 'd0e5aba84b707c02f5c045efd56bed816f7d413e3f337cb255047e501570340c'
    }
    [pscustomobject]@{
        Name = 'QM5_LBMA_Gold_PM_schedule_gaps.csv'
        Sha256 = '7a59deac3306a78ac3747ac2ccec93d04c2b38e6c695145a0bbc4347451289a3'
    }
    [pscustomobject]@{
        Name = 'QM5_LBMA_Gold_PM_schedule_manifest.json'
        Sha256 = '556eb64fd1da3277568fc4ae5d84400a9780d15e60c11d18e6cc4d0530f8da21'
    }
)

$rootFull = [IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
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
        throw "LBMA schedule artifact is missing: $source"
    }
    $sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
    if ($sourceHash -ne $artifact.Sha256) {
        throw "LBMA schedule artifact hash mismatch for $($artifact.Name): expected $($artifact.Sha256), found $sourceHash."
    }

    $target = [IO.Path]::GetFullPath((Join-Path $rootFull $artifact.Name))
    if ([IO.Path]::GetDirectoryName($target).TrimEnd('\') -ne $rootFull.TrimEnd('\')) {
        throw "Resolved target escaped CommonFilesRoot: $target"
    }

    $status = 'MISSING'
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
        if ($targetHash -ne $artifact.Sha256) {
            throw "A mismatched LBMA schedule artifact already exists at $target (sha256=$targetHash)."
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
            throw "Provisioned LBMA schedule artifact failed hash verification at $($item.Target): $targetHash."
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
