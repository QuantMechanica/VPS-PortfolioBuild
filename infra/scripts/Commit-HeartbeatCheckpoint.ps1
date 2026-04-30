[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [Parameter(Mandatory = $true)]
    [string]$CheckpointPath,
    [Parameter(Mandatory = $true)]
    [string]$IssueId,
    [string]$Message = "",
    [string]$ExpectedTopLevel = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Normalize-Path([string]$Value) {
    return $Value.Replace('\', '/').Trim()
}

$resolvedRepo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
if (-not (Test-Path -LiteralPath (Join-Path $resolvedRepo ".git"))) {
    throw "Not a git repository root: $resolvedRepo"
}

$repoTopLevel = (& git -C $resolvedRepo rev-parse --show-toplevel).Trim()
if ([string]::IsNullOrWhiteSpace($repoTopLevel)) {
    throw "Failed to resolve git top-level for repo root: $resolvedRepo"
}

$normalizedTopLevel = Normalize-Path $repoTopLevel
if ($normalizedTopLevel -eq "C:/QM/repo") {
    throw "Refusing heartbeat checkpoint commit from shared main worktree C:/QM/repo. Use per-agent worktree."
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedTopLevel)) {
    $normalizedExpected = Normalize-Path ([IO.Path]::GetFullPath($ExpectedTopLevel))
    if ($normalizedTopLevel -ne $normalizedExpected) {
        throw ("Top-level mismatch. expected={0} actual={1}" -f $normalizedExpected, $normalizedTopLevel)
    }
}

$normalizedCheckpoint = Normalize-Path $CheckpointPath
if ([string]::IsNullOrWhiteSpace($normalizedCheckpoint)) {
    throw "CheckpointPath cannot be empty."
}
if ([IO.Path]::IsPathRooted($normalizedCheckpoint)) {
    throw "CheckpointPath must be repo-relative."
}

$fullCheckpoint = Join-Path $resolvedRepo ($normalizedCheckpoint.Replace('/', '\'))
if (-not (Test-Path -LiteralPath $fullCheckpoint)) {
    throw "Checkpoint file not found: $fullCheckpoint"
}

if ([string]::IsNullOrWhiteSpace($Message)) {
    $timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Message = "docs($($IssueId.ToLowerInvariant())): append heartbeat checkpoint $timestamp"
}

# Stage only the explicit checkpoint path.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Invoke-GitWithMutex.ps1") `
    -RepoRoot $resolvedRepo `
    -GitCommand add `
    -GitArguments @("--", $normalizedCheckpoint)
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

# Commit only the same explicit path and enforce staged allowlist for checkpoint scope.
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "Invoke-GitWithMutex.ps1") `
    -RepoRoot $resolvedRepo `
    -GitCommand commit `
    -GitArguments @("-m", $Message, "--", $normalizedCheckpoint) `
    -CommitAllowedExactPaths @($normalizedCheckpoint) `
    -FailWhenCommitAllowlistEmpty
exit $LASTEXITCODE
