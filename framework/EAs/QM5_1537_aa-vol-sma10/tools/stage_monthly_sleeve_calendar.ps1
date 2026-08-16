[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$ManifestPath,
    [string]$CommonFilesRoot = 'C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files',
    [switch]$VerifyOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$eaDir = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = Join-Path $eaDir 'calendar\QM5_1537_monthly_sleeves_v1.csv'
}
if ([string]::IsNullOrWhiteSpace($ManifestPath)) {
    $ManifestPath = Join-Path $eaDir 'calendar\QM5_1537_monthly_sleeves_v1.manifest.json'
}

$source = (Resolve-Path -LiteralPath $SourcePath).Path
$manifestFile = (Resolve-Path -LiteralPath $ManifestPath).Path
$root = [System.IO.Path]::GetFullPath($CommonFilesRoot).TrimEnd('\')
$destinationDir = $root
$destination = [System.IO.Path]::GetFullPath((Join-Path $destinationDir 'QM5_1537_monthly_sleeves_v1.csv'))
if (-not $destination.StartsWith($root + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination escapes governed FILE_COMMON root: $destination"
}

$manifest = Get-Content -Raw -LiteralPath $manifestFile | ConvertFrom-Json
$expected = ([string]$manifest.calendar_sha256).ToUpperInvariant()
$sourceHash = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToUpperInvariant()
if ($sourceHash -cne $expected) {
    throw "Source calendar hash mismatch: $sourceHash != $expected"
}

if (-not $VerifyOnly.IsPresent) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    $temporary = Join-Path $destinationDir ('.QM5_1537_monthly_sleeves_v1.csv.' + $PID + '.tmp')
    Copy-Item -LiteralPath $source -Destination $temporary -Force
    $temporaryHash = (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($temporaryHash -cne $expected) {
        Remove-Item -LiteralPath $temporary -Force
        throw "Staged temporary hash mismatch: $temporaryHash != $expected"
    }
    Move-Item -LiteralPath $temporary -Destination $destination -Force
}

if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
    throw "FILE_COMMON calendar missing: $destination"
}
$destinationHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToUpperInvariant()
if ($destinationHash -cne $expected) {
    throw "FILE_COMMON calendar hash mismatch: $destinationHash != $expected"
}

[pscustomobject]@{
    status = 'PASS'
    verify_only = $VerifyOnly.IsPresent
    source_path = $source
    destination_path = $destination
    calendar_sha256 = $destinationHash
    contract_sha256 = ([string]$manifest.ranking_contract_sha256).ToUpperInvariant()
    input_bundle_sha256 = ([string]$manifest.input_bundle_sha256).ToUpperInvariant()
    row_count = [int]$manifest.row_count
} | ConvertTo-Json -Depth 4
