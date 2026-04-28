[CmdletBinding()]
param(
    [string]$SourceTerminalRoot = 'D:\QM\mt5\T1',
    [string[]]$TargetTerminalRoots = @('D:\QM\mt5\T3', 'D:\QM\mt5\T4', 'D:\QM\mt5\T5'),
    [string]$ExpertsRelativeDir = 'MQL5\Experts\QM',
    [string[]]$AllowedExpertFiles = @(
        'EA_Skeleton.ex5',
        'QM5_1001_framework_smoke.ex5',
        'QM5_1002_davey-eu-night.ex5',
        'QM5_SRC04_S03_lien_fade_double_zeros.ex5'
    ),
    [string]$EvidenceJsonPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256Hex {
    param([Parameter(Mandatory = $true)][string]$Path)
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Resolve-TerminalRoot {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $resolved = [IO.Path]::GetFullPath($RootPath).TrimEnd('\\')
    $leaf = Split-Path -Path $resolved -Leaf
    if ($leaf -match '^T6(_|$)') {
        throw "Refusing T6 scope path '$resolved' without explicit OWNER + LiveOps approval."
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        throw "Terminal root not found: $resolved"
    }
    return $resolved
}

$sourceRoot = Resolve-TerminalRoot -RootPath $SourceTerminalRoot
$normalizedTargets = @()
foreach ($target in $TargetTerminalRoots) {
    $targetRoot = Resolve-TerminalRoot -RootPath $target
    if ($targetRoot -ieq $sourceRoot) {
        throw "Target terminal root must differ from source root: $targetRoot"
    }
    if ($normalizedTargets -notcontains $targetRoot) {
        $normalizedTargets += $targetRoot
    }
}

$allowedUnique = @($AllowedExpertFiles | Where-Object { $_ -and $_.Trim().Length -gt 0 } | ForEach-Object { $_.Trim() } | Select-Object -Unique)
if ($allowedUnique.Count -eq 0) {
    throw 'AllowedExpertFiles cannot be empty.'
}

$sourceExpertDir = Join-Path $sourceRoot $ExpertsRelativeDir
if (-not (Test-Path -LiteralPath $sourceExpertDir -PathType Container)) {
    throw "Source experts directory not found: $sourceExpertDir"
}

$sourceExperts = @()
foreach ($name in $allowedUnique) {
    $sourcePath = Join-Path $sourceExpertDir $name
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Required source expert missing: $sourcePath"
    }

    $sourceExperts += [pscustomobject]@{
        file_name = $name
        source_path = $sourcePath
        source_hash_sha256 = (Get-Sha256Hex -Path $sourcePath)
    }
}

$deployResults = @()
foreach ($targetRoot in $normalizedTargets) {
    $targetExpertDir = Join-Path $targetRoot $ExpertsRelativeDir
    if (-not (Test-Path -LiteralPath $targetExpertDir -PathType Container)) {
        New-Item -ItemType Directory -Path $targetExpertDir -Force | Out-Null
    }

    foreach ($expert in $sourceExperts) {
        $destinationPath = Join-Path $targetExpertDir $expert.file_name
        $status = 'unchanged'
        $beforeHash = $null
        $exists = Test-Path -LiteralPath $destinationPath -PathType Leaf

        if ($exists) {
            $beforeHash = Get-Sha256Hex -Path $destinationPath
            if ($beforeHash -ne $expert.source_hash_sha256) {
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

            Copy-Item -LiteralPath $expert.source_path -Destination $tempPath -Force
            Move-Item -LiteralPath $tempPath -Destination $destinationPath -Force
        }

        $afterHash = Get-Sha256Hex -Path $destinationPath
        $ok = ($afterHash -eq $expert.source_hash_sha256)

        $deployResults += [pscustomobject]@{
            target_terminal_root = $targetRoot
            file_name = $expert.file_name
            status = $status
            source_path = $expert.source_path
            destination_path = $destinationPath
            source_hash_sha256 = $expert.source_hash_sha256
            destination_hash_before_sha256 = $beforeHash
            destination_hash_after_sha256 = $afterHash
            hash_match_after = $ok
        }
    }
}

$failed = @($deployResults | Where-Object { -not $_.hash_match_after })
$statusCounts = $deployResults | Group-Object -Property status | ForEach-Object {
    [pscustomobject]@{ status = $_.Name; count = $_.Count }
}

$result = [ordered]@{
    source_terminal_root = $sourceRoot
    target_terminal_roots = $normalizedTargets
    experts_relative_dir = $ExpertsRelativeDir
    allowed_expert_files = $allowedUnique
    deployed_at_local = (Get-Date).ToString('o')
    status_counts = $statusCounts
    files = $deployResults
    all_hashes_match = ($failed.Count -eq 0)
}

$json = $result | ConvertTo-Json -Depth 8

if ($EvidenceJsonPath) {
    $evidenceFull = [IO.Path]::GetFullPath($EvidenceJsonPath)
    $evidenceDir = Split-Path -Path $evidenceFull -Parent
    if (-not (Test-Path -LiteralPath $evidenceDir -PathType Container)) {
        New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
    }
    Set-Content -LiteralPath $evidenceFull -Value $json -Encoding UTF8
}

$json
if ($failed.Count -gt 0) {
    exit 2
}
exit 0
