[CmdletBinding()]
param(
    [string[]]$RepoRoots = @("C:\QM\repo", "C:\QM\paperclip"),
    [int]$StaleAfterMinutes = 20,
    [switch]$AutoCleanup,
    [switch]$FailOnFinding,
    [string]$OutputPath = "C:\QM\logs\infra\health\git_index_lock_monitor_latest.json"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitProcessMatches {
    param([string]$RepoRoot)

    $needle = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
    @(Get-CimInstance Win32_Process -Filter "Name='git.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.CommandLine -and $_.CommandLine.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    })
}

function Ensure-ParentDirectory {
    param([string]$Path)
    $parent = Split-Path -Path $Path -Parent
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
}

$now = [datetime]::UtcNow
$staleLocks = @()
$allLocks = @()

foreach ($repo in $RepoRoots) {
    if (-not (Test-Path -LiteralPath $repo)) { continue }
    $resolvedRepo = [IO.Path]::GetFullPath($repo).TrimEnd('\')
    $lockPath = Join-Path $resolvedRepo ".git\index.lock"
    if (-not (Test-Path -LiteralPath $lockPath)) { continue }

    $item = Get-Item -LiteralPath $lockPath -ErrorAction Stop
    $ageMinutes = [math]::Round(($now - $item.LastWriteTimeUtc).TotalMinutes, 2)
    $entry = [ordered]@{
        repo_root = $resolvedRepo
        lock_path = $lockPath
        lock_last_write_utc = $item.LastWriteTimeUtc.ToString("o")
        age_minutes = $ageMinutes
        stale_threshold_minutes = $StaleAfterMinutes
        is_stale = ($ageMinutes -ge $StaleAfterMinutes)
        auto_cleanup_attempted = $false
        auto_cleanup_removed = $false
        auto_cleanup_error = $null
        active_git_pids = @()
    }

    if ($entry.is_stale -and $AutoCleanup.IsPresent) {
        $entry.auto_cleanup_attempted = $true
        $gitProcs = @(Get-GitProcessMatches -RepoRoot $resolvedRepo)
        $entry.active_git_pids = @($gitProcs | ForEach-Object { $_.ProcessId })

        if ($gitProcs.Count -eq 0) {
            try {
                Remove-Item -LiteralPath $lockPath -Force -ErrorAction Stop
                $entry.auto_cleanup_removed = $true
            }
            catch {
                $entry.auto_cleanup_error = $_.Exception.Message
            }
        }
        else {
            $entry.auto_cleanup_error = "Active git process detected for repo; cleanup skipped."
        }
    }

    $allLocks += $entry
    if ($entry.is_stale) {
        $staleLocks += $entry
    }
}

$failedCleanupCount = @($staleLocks | Where-Object { $_.auto_cleanup_attempted -and -not $_.auto_cleanup_removed }).Count
$status = if ($staleLocks.Count -eq 0) { "ok" } elseif ($AutoCleanup.IsPresent -and $failedCleanupCount -eq 0) { "warn" } else { "critical" }
$message = if ($status -eq "ok") {
    "No stale git index.lock files detected."
}
elseif ($status -eq "warn") {
    "Stale git index.lock files detected and cleaned."
}
else {
    "Stale git index.lock files detected."
}

$result = [ordered]@{
    check = "git_index_lock_monitor"
    generated_at_utc = $now.ToString("o")
    status = $status
    message = $message
    details = [ordered]@{
        stale_after_minutes = $StaleAfterMinutes
        auto_cleanup = $AutoCleanup.IsPresent
        stale_count = $staleLocks.Count
        stale_locks = @($staleLocks)
        observed_locks = @($allLocks)
    }
}

Ensure-ParentDirectory -Path $OutputPath
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding ASCII
$result | ConvertTo-Json -Depth 8

if ($status -eq "ok") { exit 0 }
if ($FailOnFinding.IsPresent -or $status -eq "critical") { exit 2 }
exit 1
