[CmdletBinding()]
param(
    [string]$RepoRoot = 'C:\QM\repo',
    [string]$ProtectedBranch = 'main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) {
    throw "Not a git repository root: $RepoRoot"
}

$currentBranch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
if (-not $currentBranch.Equals($ProtectedBranch, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host ("status=ok reason=not_protected_branch current_branch={0} protected_branch={1}" -f $currentBranch, $ProtectedBranch)
    exit 0
}

$trackedRaw = & git -C $RepoRoot ls-files
$untrackedRaw = & git -C $RepoRoot ls-files --others --exclude-standard
$all = @($trackedRaw + $untrackedRaw | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$violations = @()

foreach ($f in $all) {
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
        $violations += $f
    }
}

if (@($violations).Count -gt 0) {
    Write-Host ("status=critical reason=main_artifact_policy_violation branch={0} violation_count={1}" -f $currentBranch, @($violations).Count)
    foreach ($f in $violations) { Write-Host ("main_artifact_violation={0}" -f $f) }
    exit 2
}

Write-Host ("status=ok reason=main_artifact_policy_clear branch={0}" -f $currentBranch)
exit 0
