[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string[]]$PossibleDriveRoots = @(
        "G:\My Drive",
        "G:\Meine Ablage",
        "C:\Users\Administrator\Google Drive",
        "C:\Users\Administrator\My Drive"
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRepo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\\')
$gitDir = Join-Path $resolvedRepo ".git"

$result = [ordered]@{
    check = "drive_git_exclusion"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    repo_root = $resolvedRepo
    git_dir_exists = (Test-Path -LiteralPath $gitDir)
    in_drive_sync_root = $false
    matching_drive_roots = @()
    status = "ok"
    message = "Repo path is outside known Drive sync roots."
}

$matches = @()
foreach ($root in $PossibleDriveRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $resolvedRoot = [IO.Path]::GetFullPath($root).TrimEnd('\\')
    if ($resolvedRepo.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $matches += $resolvedRoot
    }
}

if ($matches.Count -gt 0) {
    $result.in_drive_sync_root = $true
    $result.matching_drive_roots = $matches
    $result.status = "critical"
    $result.message = "Repo is under a Drive sync root. Move repo or exclude .git immediately."
}

if (-not $result.git_dir_exists) {
    $result.status = "critical"
    $result.message = "Repo .git directory missing; cannot verify Drive exclusion safely."
}

$result | ConvertTo-Json -Depth 6
if ($result.status -eq "ok") { exit 0 }
exit 2
