[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$CommonFilesRoot = (Join-Path $env:APPDATA 'MetaQuotes\Terminal\Common\Files')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$calendarName = 'QM5_20023_announcement_calendar_20150101_20250404.csv'
$expectedSha256 = '411ae4af3dbe261e373705660e28b81e7c5dfc7398f38516e07effff71cd73af'
$source = Join-Path $PSScriptRoot "data\$calendarName"
if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
    throw "Strategy calendar is missing: $source"
}

$sourceHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $source).Hash.ToLowerInvariant()
if ($sourceHash -ne $expectedSha256) {
    throw "Strategy calendar hash mismatch: expected $expectedSha256, found $sourceHash."
}

$rootFull = [IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd('\')
if ($rootFull -match '(?i)\\QM\\mt5\\T_Live(?:\\|$)') {
    throw "Refusing to provision inside T_Live: $rootFull"
}
$target = [IO.Path]::GetFullPath((Join-Path $rootFull $calendarName))
if ([IO.Path]::GetDirectoryName($target).TrimEnd('\') -ne $rootFull) {
    throw "Resolved target escaped CommonFilesRoot: $target"
}

if (Test-Path -LiteralPath $target -PathType Leaf) {
    $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
    if ($targetHash -eq $expectedSha256) {
        [pscustomobject]@{
            status = 'ALREADY_PROVISIONED'
            source = $source
            target = $target
            sha256 = $targetHash
        }
        return
    }
    throw "A mismatched strategy calendar already exists at $target (sha256=$targetHash)."
}

if ($PSCmdlet.ShouldProcess($target, "Provision $calendarName")) {
    New-Item -ItemType Directory -Path $rootFull -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $target
    $targetHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash.ToLowerInvariant()
    if ($targetHash -ne $expectedSha256) {
        throw "Provisioned strategy calendar failed hash verification: $targetHash."
    }
    [pscustomobject]@{
        status = 'PROVISIONED'
        source = $source
        target = $target
        sha256 = $targetHash
    }
}
