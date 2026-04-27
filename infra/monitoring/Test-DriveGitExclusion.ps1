[CmdletBinding()]
param(
    [string[]]$RepoRoots = @(
        "C:\QM\repo"
    ),
    [string[]]$PossibleDriveRoots = @(
        "G:\My Drive",
        "G:\Meine Ablage",
        "C:\Users\Administrator\Google Drive",
        "C:\Users\Administrator\My Drive",
        "C:\Users\Administrator\Google Drive\My Drive"
    ),
    [switch]$FailOnMissingRepo,
    [string]$PrimaryRepoForWorktrees = "C:\QM\repo",
    [switch]$IncludeGitWorktrees,
    [string]$OutputPath = "C:\QM\logs\infra\health\drive_git_exclusion_latest.json",
    [string]$AlertWebhookUrl = $(if ($env:QM_ALERT_WEBHOOK_URL) { $env:QM_ALERT_WEBHOOK_URL } else { "" })
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-NormalizedPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    return ([IO.Path]::GetFullPath($Path)).TrimEnd([char]'\')
}

function Test-PathUnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    if ($Path.Equals($Root, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $rootPrefix = "$Root\"
    return $Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Resolve-GitMetadataPath {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$GitEntryPath
    )

    if (Test-Path -LiteralPath $GitEntryPath -PathType Container) {
        return [pscustomobject]@{
            git_entry_type = "directory"
            resolved_git_dir = (Resolve-NormalizedPath -Path $GitEntryPath)
        }
    }

    if (Test-Path -LiteralPath $GitEntryPath -PathType Leaf) {
        $firstLine = Get-Content -LiteralPath $GitEntryPath -TotalCount 1 -ErrorAction Stop
        if (-not $firstLine -or -not $firstLine.StartsWith("gitdir:", [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Unsupported .git file format: $GitEntryPath"
        }

        $rawGitDir = $firstLine.Substring(7).Trim()
        if (-not $rawGitDir) {
            throw "Missing gitdir target in .git file: $GitEntryPath"
        }

        if ([IO.Path]::IsPathRooted($rawGitDir)) {
            $resolvedGitDir = Resolve-NormalizedPath -Path $rawGitDir
        }
        else {
            $resolvedGitDir = Resolve-NormalizedPath -Path (Join-Path $RepoRoot $rawGitDir)
        }

        return [pscustomobject]@{
            git_entry_type = "file"
            resolved_git_dir = $resolvedGitDir
        }
    }

    return [pscustomobject]@{
        git_entry_type = "missing"
        resolved_git_dir = $null
    }
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

function Get-RepoRootsWithWorktrees {
    param(
        [string[]]$BaseRepoRoots,
        [string]$PrimaryRepo
    )

    $paths = @()
    foreach ($r in $BaseRepoRoots) {
        if (-not $r) { continue }
        $paths += (Resolve-NormalizedPath -Path $r)
    }

    if ($IncludeGitWorktrees.IsPresent -and (Test-Path -LiteralPath $PrimaryRepo -PathType Container)) {
        try {
            $lines = & git -C $PrimaryRepo worktree list --porcelain 2>$null
            foreach ($line in $lines) {
                if (-not $line.StartsWith("worktree ")) { continue }
                $worktreePath = $line.Substring(9).Trim()
                if (-not $worktreePath) { continue }
                $paths += (Resolve-NormalizedPath -Path $worktreePath)
            }
        }
        catch {
            # keep base roots only when git worktree introspection fails
        }
    }

    return @($paths | Select-Object -Unique)
}

$resolvedDriveRoots = @()
foreach ($root in $PossibleDriveRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    $resolvedDriveRoots += (Resolve-NormalizedPath -Path $root)
}
$resolvedDriveRoots = @($resolvedDriveRoots | Select-Object -Unique)

$resolvedRepoRoots = Get-RepoRootsWithWorktrees -BaseRepoRoots $RepoRoots -PrimaryRepo $PrimaryRepoForWorktrees

$repoResults = @()
foreach ($repoRoot in $resolvedRepoRoots) {
    if (-not $repoRoot) { continue }

    $resolvedRepo = Resolve-NormalizedPath -Path $repoRoot
    $gitEntryPath = Join-Path $resolvedRepo ".git"
    $repoStatus = "ok"
    $repoMessage = "Repo root and git metadata are outside Drive sync roots."
    $matchingRoots = @()
    $resolvedGitDir = $null
    $gitEntryType = "missing"

    $repoExists = Test-Path -LiteralPath $resolvedRepo -PathType Container
    $gitEntryExists = Test-Path -LiteralPath $gitEntryPath

    if (-not $repoExists) {
        $repoStatus = if ($FailOnMissingRepo.IsPresent) { "critical" } else { "warn" }
        $repoMessage = "Repository root is missing."
    }
    else {
        foreach ($driveRoot in $resolvedDriveRoots) {
            if (Test-PathUnderRoot -Path $resolvedRepo -Root $driveRoot) {
                $matchingRoots += $driveRoot
            }
        }

        $gitMetadata = Resolve-GitMetadataPath -RepoRoot $resolvedRepo -GitEntryPath $gitEntryPath
        $gitEntryType = $gitMetadata.git_entry_type
        $resolvedGitDir = $gitMetadata.resolved_git_dir

        if ($gitEntryType -eq "missing") {
            $repoStatus = "critical"
            $repoMessage = "Repo .git metadata entry is missing."
        }
        else {
            $gitEntryItem = Get-Item -LiteralPath $gitEntryPath -Force
            if (($gitEntryItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $repoStatus = "critical"
                $repoMessage = ".git entry is a reparse point; fence cannot guarantee isolation."
            }
        }

        if ($repoStatus -eq "ok" -and $resolvedGitDir) {
            foreach ($driveRoot in $resolvedDriveRoots) {
                if (Test-PathUnderRoot -Path $resolvedGitDir -Root $driveRoot) {
                    $matchingRoots += $driveRoot
                }
            }
        }

        $matchingRoots = @($matchingRoots | Select-Object -Unique)
        if ($repoStatus -eq "ok" -and $matchingRoots.Count -gt 0) {
            $repoStatus = "critical"
            $repoMessage = "Repo or git metadata resolves under Drive sync root."
        }
    }

    $repoResults += [pscustomobject]@{
        repo_root = $resolvedRepo
        status = $repoStatus
        message = $repoMessage
        repo_exists = $repoExists
        git_entry_path = $gitEntryPath
        git_entry_exists = $gitEntryExists
        git_entry_type = $gitEntryType
        resolved_git_dir = $resolvedGitDir
        matching_drive_roots = @($matchingRoots)
    }
}

$criticalCount = @($repoResults | Where-Object { $_.status -eq "critical" }).Count
$warnCount = @($repoResults | Where-Object { $_.status -eq "warn" }).Count
$okCount = @($repoResults | Where-Object { $_.status -eq "ok" }).Count

$overallStatus = "ok"
$message = "All repositories are outside Drive sync scope and git metadata paths are safe."
if ($criticalCount -gt 0) {
    $overallStatus = "critical"
    $message = "One or more repositories violate Drive-sync hard-fence rules."
}
elseif ($warnCount -gt 0) {
    $overallStatus = "warn"
    $message = "Drive-sync hard-fence check completed with warnings."
}
elseif ($resolvedDriveRoots.Count -eq 0) {
    $overallStatus = "warn"
    $message = "No known Drive roots were found on disk; hard-fence check has limited scope."
}

$result = [pscustomobject]@{
    check = "drive_git_exclusion_hard_fence"
    generated_at_utc = [datetime]::UtcNow.ToString("o")
    status = $overallStatus
    message = $message
    drive_roots = @($resolvedDriveRoots)
    include_git_worktrees = $IncludeGitWorktrees.IsPresent
    primary_repo_for_worktrees = $PrimaryRepoForWorktrees
    resolved_repo_roots = @($resolvedRepoRoots)
    output_path = $OutputPath
    alert_webhook_enabled = [bool]($AlertWebhookUrl)
    repo_roots = @($repoResults)
    summary = [pscustomobject]@{
        repo_count = $repoResults.Count
        critical = $criticalCount
        warn = $warnCount
        ok = $okCount
    }
}

Ensure-ParentDirectory -Path $OutputPath
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding ASCII
$result | ConvertTo-Json -Depth 8

if ($overallStatus -ne "ok" -and $AlertWebhookUrl) {
    try {
        Invoke-RestMethod -Method Post -Uri $AlertWebhookUrl -ContentType "application/json" -Body ($result | ConvertTo-Json -Depth 8) | Out-Null
    }
    catch {
        Write-Warning "Drive/git hard-fence alert webhook post failed: $($_.Exception.Message)"
    }
}

if ($overallStatus -eq "ok") { exit 0 }
if ($overallStatus -eq "warn") { exit 1 }
exit 2
