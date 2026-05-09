[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$SourceRoot = 'framework/EAs',
    [string]$DestinationRoot = 'docs/ops/QUA-archived/framework/EAs',
    [switch]$Apply,
    [string]$ReportPath = 'docs/ops/QUA-archived/qua-1027_move_report_latest.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-ToRepoRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FullPath,
        [Parameter(Mandatory = $true)]
        [string]$RepoRootFull
    )

    $full = [System.IO.Path]::GetFullPath($FullPath)
    $root = [System.IO.Path]::GetFullPath($RepoRootFull)
    $uriPath = [System.Uri]::new($full)
    $uriRoot = [System.Uri]::new(($root.TrimEnd('\\') + '\\'))
    $rel = [System.Uri]::UnescapeDataString($uriRoot.MakeRelativeUri($uriPath).ToString())
    return $rel.Replace('/', '\\')
}

$repoRootFull = [System.IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath (Join-Path $repoRootFull '.git'))) {
    throw "Not a git repository root: $repoRootFull"
}

$sourceRootFull = [System.IO.Path]::GetFullPath((Join-Path $repoRootFull $SourceRoot))
if (-not (Test-Path -LiteralPath $sourceRootFull)) {
    throw "Source root not found: $sourceRootFull"
}

$destinationRootFull = [System.IO.Path]::GetFullPath((Join-Path $repoRootFull $DestinationRoot))
$reportFull = [System.IO.Path]::GetFullPath((Join-Path $repoRootFull $ReportPath))

if (-not $destinationRootFull.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Destination root escapes repo root: $destinationRootFull"
}
if (-not $reportFull.StartsWith($repoRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Report path escapes repo root: $reportFull"
}

$quaFiles = @(Get-ChildItem -LiteralPath $sourceRootFull -Recurse -File | Where-Object { $_.Name -like 'QUA-*' })

$operations = New-Object System.Collections.Generic.List[object]
foreach ($file in $quaFiles) {
    $sourceFull = $file.FullName
    $relativeFromSource = $sourceFull.Substring($sourceRootFull.Length).TrimStart('\\')
    $targetFull = Join-Path $destinationRootFull $relativeFromSource

    if (-not $targetFull.StartsWith($destinationRootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing path traversal candidate: $targetFull"
    }

    $targetDir = Split-Path -Parent $targetFull
    $sourceHash = (Get-FileHash -LiteralPath $sourceFull -Algorithm SHA256).Hash

    $exists = Test-Path -LiteralPath $targetFull
    if ($exists) {
        $targetHash = (Get-FileHash -LiteralPath $targetFull -Algorithm SHA256).Hash
        if ($targetHash -eq $sourceHash) {
            $action = 'remove_source_duplicate'
        } else {
            $action = 'conflict'
        }
    } else {
        $action = 'move'
    }

    $operations.Add([pscustomobject]@{
        source = (Convert-ToRepoRelativePath -FullPath $sourceFull -RepoRootFull $repoRootFull).Replace('\\', '/')
        destination = (Convert-ToRepoRelativePath -FullPath $targetFull -RepoRootFull $repoRootFull).Replace('\\', '/')
        action = $action
        source_sha256 = $sourceHash
    }) | Out-Null

    if ($Apply) {
        if (-not (Test-Path -LiteralPath $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }

        switch ($action) {
            'move' {
                Move-Item -LiteralPath $sourceFull -Destination $targetFull -Force
            }
            'remove_source_duplicate' {
                Remove-Item -LiteralPath $sourceFull -Force
            }
            'conflict' {
                throw "Destination conflict with different content: $targetFull"
            }
        }
    }
}

$summary = [pscustomobject]@{
    status = 'ok'
    apply = [bool]$Apply
    source_root = $SourceRoot
    destination_root = $DestinationRoot
    moved_count = @($operations | Where-Object { $_.action -eq 'move' }).Count
    removed_duplicate_count = @($operations | Where-Object { $_.action -eq 'remove_source_duplicate' }).Count
    conflict_count = @($operations | Where-Object { $_.action -eq 'conflict' }).Count
    total_candidates = $operations.Count
    generated_utc = (Get-Date).ToUniversalTime().ToString('o')
    operations = $operations
}

$reportDir = Split-Path -Parent $reportFull
if (-not (Test-Path -LiteralPath $reportDir)) {
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
}
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $reportFull -Encoding UTF8

Write-Host ("status=ok apply={0} total={1} moved={2} removed_duplicate={3} conflict={4} report={5}" -f [bool]$Apply, $summary.total_candidates, $summary.moved_count, $summary.removed_duplicate_count, $summary.conflict_count, ((Convert-ToRepoRelativePath -FullPath $reportFull -RepoRootFull $repoRootFull).Replace('\\', '/')))
if ($summary.conflict_count -gt 0) {
    exit 2
}
exit 0
