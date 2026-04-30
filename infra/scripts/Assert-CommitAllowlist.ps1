[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string[]]$AllowedPaths = @(),
    [string[]]$AllowedExactPaths = @(),
    [switch]$AllowNothingWhenEmpty,
    [switch]$FailOnRepoRootZeroByte,
    [switch]$FailOnUntracked,
    [string[]]$AllowedUntrackedPaths = @(),
    [string[]]$AllowedUntrackedExactPaths = @(),
    [switch]$FailOnMainArtifactPaths,
    [string]$ProtectedBranch = 'main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "Not a git repository root: $RepoRoot"
}

if ($FailOnRepoRootZeroByte) {
    $rootZeroByteFiles = @(Get-ChildItem -LiteralPath $RepoRoot -File -ErrorAction Stop | Where-Object { $_.Length -eq 0 })
    if (@($rootZeroByteFiles).Count -gt 0) {
        Write-Host ("status=critical reason=repo_root_zero_byte_file_present count={0}" -f @($rootZeroByteFiles).Count)
        Write-Host "action=remove_root_garbage_and_retry ref=DL-028(worktree_discipline)"
        foreach ($f in $rootZeroByteFiles) { Write-Host ("root_zero_byte_violation={0}" -f $f.Name) }
        exit 4
    }
}

$normalizedAllowedUntrackedPrefixes = @($AllowedUntrackedPaths | ForEach-Object { $_.Replace('\', '/').TrimStart('./') })
$normalizedAllowedUntrackedExact = @($AllowedUntrackedExactPaths | ForEach-Object { $_.Replace('\', '/').TrimStart('./') })

if ($FailOnUntracked) {
    $untrackedRaw = & git -C $RepoRoot ls-files --others --exclude-standard
    $untracked = @($untrackedRaw | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $untrackedViolations = @()

    foreach ($f in $untracked) {
        $n = $f.Replace('\', '/').TrimStart('./')
        $allowed = $false
        foreach ($exact in $normalizedAllowedUntrackedExact) {
            if ($n.Equals($exact, [System.StringComparison]::OrdinalIgnoreCase)) {
                $allowed = $true
                break
            }
        }
        if (-not $allowed) {
            foreach ($prefix in $normalizedAllowedUntrackedPrefixes) {
                if ($n.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $allowed = $true
                    break
                }
            }
        }
        if (-not $allowed) {
            $untrackedViolations += $f
        }
    }

    if (@($untrackedViolations).Count -gt 0) {
        Write-Host ("status=critical reason=untracked_files_present untracked_count={0} violation_count={1}" -f @($untracked).Count, @($untrackedViolations).Count)
        foreach ($f in $untrackedViolations) { Write-Host ("untracked_violation={0}" -f $f) }
        exit 3
    }
}

$stagedRaw = & git -C $RepoRoot diff --cached --name-only --diff-filter=ACMRTUXB
$staged = @($stagedRaw | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if ($FailOnMainArtifactPaths) {
    $currentBranch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
    if ($currentBranch.Equals($ProtectedBranch, [System.StringComparison]::OrdinalIgnoreCase)) {
        $mainArtifactViolations = @()
        foreach ($f in $staged) {
            $n = $f.Replace('\', '/').TrimStart('./')
            if ($n -match '^docs/ops/QUA-[^/]+_[^/]+\.(md|json|sha256|txt)$' -or
                $n -match '^QUA-[^/]+_[^/]+\.(md|json|sha256|txt)$' -or
                $n -match '^decisions/2026-[^/]*_self_author_[^/]*\.md$' -or
                $n -match '^artifacts/qua-[^/]+/.+' -or
                $n -match '^framework/EAs/.+\.ex5$' -or
                $n -match '(^|/)__pycache__(/|$)' -or
                $n -match '\.pyc$' -or
                $n.StartsWith('.claude/', [System.StringComparison]::OrdinalIgnoreCase) -or
                $n.Equals('.claude/scheduled_tasks.lock', [System.StringComparison]::OrdinalIgnoreCase)) {
                $mainArtifactViolations += $f
            }
        }

        if (@($mainArtifactViolations).Count -gt 0) {
            Write-Host ("status=critical reason=main_artifact_policy_violation branch={0} staged_count={1} violation_count={2}" -f $currentBranch, @($staged).Count, @($mainArtifactViolations).Count)
            foreach ($f in $mainArtifactViolations) { Write-Host ("main_artifact_violation={0}" -f $f) }
            exit 5
        }
    }
}

if (@($staged).Count -eq 0) {
    Write-Host 'status=ok staged_count=0'
    exit 0
}

if ((@($AllowedPaths).Count -eq 0) -and (@($AllowedExactPaths).Count -eq 0)) {
    if ($AllowNothingWhenEmpty) {
        Write-Host ("status=critical reason=allowlist_empty staged_count={0}" -f @($staged).Count)
        foreach ($f in $staged) { Write-Host ("staged_file={0}" -f $f) }
        exit 2
    }
    Write-Host ("status=ok allowlist_empty=true staged_count={0}" -f @($staged).Count)
    exit 0
}

$normalizedAllowedPrefixes = @($AllowedPaths | ForEach-Object { $_.Replace('\', '/').TrimStart('./') })
$normalizedAllowedExact = @($AllowedExactPaths | ForEach-Object { $_.Replace('\', '/').TrimStart('./') })
$violations = @()

foreach ($f in $staged) {
    $n = $f.Replace('\', '/').TrimStart('./')
    $allowed = $false
    foreach ($exact in $normalizedAllowedExact) {
        if ($n.Equals($exact, [System.StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
        }
    }
    if (-not $allowed) {
        foreach ($prefix in $normalizedAllowedPrefixes) {
            if ($n.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $allowed = $true
                break
            }
        }
    }
    if (-not $allowed) {
        $violations += $f
    }
}

if (@($violations).Count -gt 0) {
    Write-Host ("status=critical reason=staged_outside_allowlist staged_count={0} violation_count={1}" -f @($staged).Count, @($violations).Count)
    foreach ($f in $violations) { Write-Host ("violation={0}" -f $f) }
    exit 2
}

Write-Host ("status=ok staged_count={0} allow_prefix_count={1} allow_exact_count={2} fail_on_untracked={3} fail_on_root_zero_byte={4}" -f @($staged).Count, @($normalizedAllowedPrefixes).Count, @($normalizedAllowedExact).Count, $FailOnUntracked.IsPresent.ToString().ToLowerInvariant(), $FailOnRepoRootZeroByte.IsPresent.ToString().ToLowerInvariant())
exit 0
