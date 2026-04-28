[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$EaPath,
    [string[]]$TerminalRoots = @(
        'D:\QM\mt5\T1',
        'D:\QM\mt5\T2',
        'D:\QM\mt5\T3',
        'D:\QM\mt5\T4',
        'D:\QM\mt5\T5'
    ),
    [string]$ExpertsRelativeDir = 'MQL5\Experts\QM',
    [string]$EvidenceJsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Resolve-FactoryTerminalRoot {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $resolved = [IO.Path]::GetFullPath($RootPath).TrimEnd('\')
    $leaf = Split-Path -Path $resolved -Leaf
    if ($leaf -match '^T6(_|$)') {
        throw "Refusing T6 scope path '$resolved' without explicit OWNER + LiveOps approval."
    }
    if ($leaf -notmatch '^T[1-5]$') {
        throw "Unsupported terminal leaf '$leaf' under '$resolved'. Allowed: T1..T5 only."
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Terminal root not found: $resolved"
    }
    return $resolved
}

$sourceFull = [IO.Path]::GetFullPath($EaPath)
if (-not (Test-Path -LiteralPath $sourceFull -PathType Leaf)) {
    throw "EA file not found: $sourceFull"
}
if ([IO.Path]::GetExtension($sourceFull).ToLowerInvariant() -ne '.ex5') {
    throw "EaPath must point to a .ex5 file: $sourceFull"
}

$sourceHash = Get-Sha256Hex -Path $sourceFull
$fileName = Split-Path -Path $sourceFull -Leaf

$normalizedRoots = @()
foreach ($root in $TerminalRoots) {
    $resolvedRoot = Resolve-FactoryTerminalRoot -RootPath $root
    if ($normalizedRoots -notcontains $resolvedRoot) {
        $normalizedRoots += $resolvedRoot
    }
}

$results = @()
foreach ($root in $normalizedRoots) {
    $targetDir = Join-Path $root $ExpertsRelativeDir
    if (-not (Test-Path -LiteralPath $targetDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    $destinationPath = Join-Path $targetDir $fileName
    $destinationHashBefore = $null
    $status = 'unchanged'

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        $destinationHashBefore = Get-Sha256Hex -Path $destinationPath
        if ($destinationHashBefore -ne $sourceHash) {
            $status = 'updated'
        }
    }
    else {
        $status = 'created'
    }

    if ($status -ne 'unchanged') {
        $tempPath = "$destinationPath.tmp_copy"
        if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
            Remove-Item -LiteralPath $tempPath -Force
        }
        Copy-Item -LiteralPath $sourceFull -Destination $tempPath -Force
        Move-Item -LiteralPath $tempPath -Destination $destinationPath -Force
    }

    $destinationHashAfter = Get-Sha256Hex -Path $destinationPath
    $results += [pscustomobject]@{
        terminal = (Split-Path -Path $root -Leaf)
        status = $status
        source_path = $sourceFull
        destination_path = $destinationPath
        source_hash_sha256 = $sourceHash
        destination_hash_before_sha256 = $destinationHashBefore
        destination_hash_after_sha256 = $destinationHashAfter
        hash_match = ($destinationHashAfter -eq $sourceHash)
    }
}

$mismatches = @($results | Where-Object { -not $_.hash_match })
$result = [ordered]@{
    source_path = $sourceFull
    file_name = $fileName
    deployed_at_local = (Get-Date).ToString('o')
    terminal_roots = $normalizedRoots
    status_counts = @($results | Group-Object -Property status | ForEach-Object {
            [pscustomobject]@{ status = $_.Name; count = $_.Count }
        })
    files = $results
    all_hashes_match = ($mismatches.Count -eq 0)
}

$json = $result | ConvertTo-Json -Depth 8
if ($EvidenceJsonPath) {
    $full = [IO.Path]::GetFullPath($EvidenceJsonPath)
    $dir = Split-Path -Path $full -Parent
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -LiteralPath $full -Value $json -Encoding UTF8
}

if ($mismatches.Count -gt 0) {
    foreach ($row in $mismatches) {
        [Console]::Error.WriteLine(("{0} HASH_MISMATCH {1} {2}" -f $row.terminal, $row.destination_hash_after_sha256, $row.destination_path))
    }
    exit 2
}

foreach ($row in ($results | Sort-Object terminal)) {
    Write-Output ("{0} OK {1} {2}" -f $row.terminal, $row.destination_hash_after_sha256, $row.destination_path)
}
exit 0
