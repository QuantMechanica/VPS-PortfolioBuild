param(
    [switch]$ArchiveUntrackedEAs,
    [switch]$ArchiveDocs,
    [switch]$RestorePublicData,
    [switch]$RestoreTrackedEx5,
    [string]$ArchiveRoot = "C:\QM\archive"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Get-FullPath([string]$Path) {
    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-UnderPath([string]$Path, [string]$Parent, [string]$Label) {
    $full = Get-FullPath $Path
    $base = (Get-FullPath $Parent).TrimEnd('\') + '\'
    if (-not $full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label path escapes expected parent: $full not under $base"
    }
    return $full
}

function Normalize-RepoPath([string]$Path) {
    $p = $Path.Trim()
    if ($p.StartsWith('"') -and $p.EndsWith('"')) {
        $p = $p.Substring(1, $p.Length - 2)
    }
    return ($p -replace '\\', '/').TrimEnd('/')
}

function Add-ArchiveUnit([hashtable]$Units, [string]$RepoPath, [string]$Reason) {
    $rel = Normalize-RepoPath $RepoPath
    if ([string]::IsNullOrWhiteSpace($rel)) {
        return
    }
    if (-not $Units.ContainsKey($rel)) {
        $Units[$rel] = $Reason
    }
}

function Copy-TrackedBeforeRestore([string]$Repo, [string]$ArchiveDir, [string[]]$Paths) {
    foreach ($rel in $Paths) {
        $source = Join-Path $Repo ($rel -replace '/', '\')
        if (-not (Test-Path -LiteralPath $source)) {
            continue
        }
        Assert-UnderPath $source $Repo "tracked source" | Out-Null
        $dest = Join-Path $ArchiveDir ("tracked-before-restore\" + ($rel -replace '/', '\'))
        $destParent = Split-Path -Parent $dest
        New-Item -ItemType Directory -Force -Path $destParent | Out-Null
        Copy-Item -LiteralPath $source -Destination $dest -Force
    }
}

$repo = Get-FullPath (Join-Path $PSScriptRoot "..\..")
$archiveRootFull = Get-FullPath $ArchiveRoot
New-Item -ItemType Directory -Force -Path $archiveRootFull | Out-Null

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$archiveDir = Join-Path $archiveRootFull "repo-dirty-$timestamp"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
Assert-UnderPath $archiveDir $archiveRootFull "archive target" | Out-Null

$status = & git -C $repo status --porcelain=v1 --untracked-files=normal
$status | Set-Content -LiteralPath (Join-Path $archiveDir "git-status-before.txt") -Encoding UTF8
(& git -C $repo diff --stat) | Set-Content -LiteralPath (Join-Path $archiveDir "git-diff-stat-before.txt") -Encoding UTF8

$archiveUnits = @{}
foreach ($line in $status) {
    if (-not $line.StartsWith("?? ")) {
        continue
    }
    $rel = Normalize-RepoPath $line.Substring(3)
    if ($rel -match '^(?:\.codex_tmp.*|\.scratch/.*|tmp_[^/]+(?:/.*)?|tmp[^/]*(?:/.*)?|check_[^/]+\.py|count_[^/]+\.py|debug_[^/]+\.py|get_[^/]+\.py|inspect_[^/]+\.py|print_[^/]+\.py|probe_[^/]+\.py|repro_[^/]+\.py)$') {
        Add-ArchiveUnit $archiveUnits $rel "root-scratch"
        continue
    }
    if ($ArchiveDocs -and $rel -match '^docs/(?:ops|research)/') {
        Add-ArchiveUnit $archiveUnits $rel "docs-artifact"
        continue
    }
    if ($ArchiveUntrackedEAs -and $rel -match '^framework/EAs/(QM5_[^/]+)(?:/.*)?$') {
        $eaDir = "framework/EAs/$($Matches[1])"
        $trackedUnder = & git -C $repo ls-files -- $eaDir
        if ($trackedUnder) {
            Add-ArchiveUnit $archiveUnits $rel "untracked-ea-file-under-tracked-dir"
        } else {
            Add-ArchiveUnit $archiveUnits $eaDir "untracked-ea-dir"
        }
    }
}

$manifest = @()
foreach ($rel in ($archiveUnits.Keys | Sort-Object)) {
    $source = Join-Path $repo ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $source)) {
        continue
    }
    Assert-UnderPath $source $repo "archive source" | Out-Null
    $dest = Join-Path $archiveDir ("untracked\" + ($rel -replace '/', '\'))
    $destParent = Split-Path -Parent $dest
    New-Item -ItemType Directory -Force -Path $destParent | Out-Null
    if (Test-Path -LiteralPath $dest) {
        $dest = "$dest.duplicate-$([guid]::NewGuid().ToString('N'))"
    }
    Move-Item -LiteralPath $source -Destination $dest
    $manifest += [pscustomobject]@{
        repo_path = $rel
        reason = $archiveUnits[$rel]
        archive_path = $dest
    }
}

$restorePaths = @()
if ($RestorePublicData) {
    $restorePaths += @(
        "public-data/process-roadmap.json",
        "public-data/public-snapshot.json",
        "public-data/strategy-archive.json"
    )
}
if ($RestoreTrackedEx5) {
    foreach ($line in $status) {
        if ($line.Length -lt 4) {
            continue
        }
        $code = $line.Substring(0, 2)
        if ($code -eq "??") {
            continue
        }
        $rel = Normalize-RepoPath $line.Substring(3)
        if ($rel -match '^framework/EAs/.+\.ex5$') {
            $restorePaths += $rel
        }
    }
}
$restorePaths = @($restorePaths | Sort-Object -Unique)
if ($restorePaths.Count -gt 0) {
    Copy-TrackedBeforeRestore $repo $archiveDir $restorePaths
    & git -C $repo restore --worktree -- @restorePaths
}

$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $archiveDir "archive-manifest.json") -Encoding UTF8
(& git -C $repo status --porcelain=v1 --untracked-files=normal) | Set-Content -LiteralPath (Join-Path $archiveDir "git-status-after.txt") -Encoding UTF8

[pscustomobject]@{
    archive_dir = $archiveDir
    archived_count = $manifest.Count
    restored_count = $restorePaths.Count
    archive_untracked_eas = [bool]$ArchiveUntrackedEAs
    archive_docs = [bool]$ArchiveDocs
    restore_public_data = [bool]$RestorePublicData
    restore_tracked_ex5 = [bool]$RestoreTrackedEx5
} | ConvertTo-Json -Depth 4
