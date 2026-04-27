[CmdletBinding()]
param(
    [string]$SourceExpertPath = 'C:\QM\repo\framework\tests\smoke\QM5_1001_framework_smoke.ex5',
    [string]$TerminalRoot = 'D:\QM\mt5\T1',
    [string]$DestinationRelativePath = 'MQL5\Experts\QM\QM5_1001_framework_smoke.ex5',
    [string]$EvidenceJsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$sourceFull = [IO.Path]::GetFullPath($SourceExpertPath)
if (-not (Test-Path -LiteralPath $sourceFull -PathType Leaf)) {
    throw "Source expert not found: $sourceFull"
}

$terminalFull = [IO.Path]::GetFullPath($TerminalRoot).TrimEnd('\')
$terminalLeaf = Split-Path -Path $terminalFull -Leaf
if ($terminalLeaf -match '^T6(_|$)') {
    throw "Refusing deploy to T6 path '$terminalFull' without explicit OWNER + LiveOps approval."
}

if (-not (Test-Path -LiteralPath $terminalFull -PathType Container)) {
    throw "Terminal root not found: $terminalFull"
}

$destinationFull = Join-Path $terminalFull $DestinationRelativePath
$destinationDir = Split-Path -Path $destinationFull -Parent
if (-not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
}

$sourceHash = Get-Sha256Hex -Path $sourceFull
$destinationExists = Test-Path -LiteralPath $destinationFull -PathType Leaf
$status = 'unchanged'
$destinationHashBefore = $null

if ($destinationExists) {
    $destinationHashBefore = Get-Sha256Hex -Path $destinationFull
    if ($destinationHashBefore -ne $sourceHash) {
        $status = 'updated'
    }
}
else {
    $status = 'created'
}

if ($status -ne 'unchanged') {
    $tempPath = "$destinationFull.tmp_copy"
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
        Remove-Item -LiteralPath $tempPath -Force
    }

    Copy-Item -LiteralPath $sourceFull -Destination $tempPath -Force
    Move-Item -LiteralPath $tempPath -Destination $destinationFull -Force
}

$destinationHashAfter = Get-Sha256Hex -Path $destinationFull

$result = [ordered]@{
    status = $status
    source_path = $sourceFull
    destination_path = $destinationFull
    source_hash_sha256 = $sourceHash
    destination_hash_before_sha256 = $destinationHashBefore
    destination_hash_after_sha256 = $destinationHashAfter
    hash_match_after = ($sourceHash -eq $destinationHashAfter)
    deployed_at_local = (Get-Date).ToString('o')
}

$json = $result | ConvertTo-Json -Depth 4

if ($EvidenceJsonPath) {
    $evidenceFull = [IO.Path]::GetFullPath($EvidenceJsonPath)
    $evidenceDir = Split-Path -Path $evidenceFull -Parent
    if (-not (Test-Path -LiteralPath $evidenceDir -PathType Container)) {
        New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
    }
    Set-Content -LiteralPath $evidenceFull -Value $json -Encoding UTF8
}

$json
if (-not $result.hash_match_after) {
    exit 2
}
exit 0
