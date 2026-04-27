[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string[]]$AllowedPaths = @(),
    [switch]$AllowNothingWhenEmpty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "Not a git repository root: $RepoRoot"
}

$stagedRaw = & git -C $RepoRoot diff --cached --name-only --diff-filter=ACMRTUXB
$staged = @($stagedRaw | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

if (@($staged).Count -eq 0) {
    Write-Host 'status=ok staged_count=0'
    exit 0
}

if (@($AllowedPaths).Count -eq 0) {
    if ($AllowNothingWhenEmpty) {
        Write-Host ("status=critical reason=allowlist_empty staged_count={0}" -f @($staged).Count)
        foreach ($f in $staged) { Write-Host ("staged_file={0}" -f $f) }
        exit 2
    }
    Write-Host ("status=ok allowlist_empty=true staged_count={0}" -f @($staged).Count)
    exit 0
}

$normalizedAllowed = @($AllowedPaths | ForEach-Object { $_.Replace('\', '/').TrimStart('./') })
$violations = @()

foreach ($f in $staged) {
    $n = $f.Replace('\', '/').TrimStart('./')
    $allowed = $false
    foreach ($prefix in $normalizedAllowed) {
        if ($n.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            $allowed = $true
            break
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

Write-Host ("status=ok staged_count={0} allow_prefix_count={1}" -f @($staged).Count, @($normalizedAllowed).Count)
exit 0
