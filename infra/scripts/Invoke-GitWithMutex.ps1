[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [int]$TimeoutSeconds = 120,
    [Parameter(Mandatory = $true)]
    [string]$GitCommand,
    [string[]]$GitArguments = @(),
    [string[]]$CommitAllowedPaths = @(),
    [string[]]$CommitAllowedExactPaths = @(),
    [switch]$FailWhenCommitAllowlistEmpty,
    [switch]$FailOnUntrackedFiles,
    [string[]]$CommitAllowedUntrackedPaths = @(),
    [string[]]$CommitAllowedUntrackedExactPaths = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedRepo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\')
$gitDir = Join-Path $resolvedRepo ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
    throw "Repo does not contain .git directory: $resolvedRepo"
}

$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($resolvedRepo.ToLowerInvariant())
    $hashBytes = $sha.ComputeHash($bytes)
}
finally {
    $sha.Dispose()
}

$hashHex = [System.BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 24)
$mutexName = "Global\QM_GIT_REPO_MUTEX_$hashHex"
$mutex = [System.Threading.Mutex]::new($false, $mutexName)
$acquired = $false

try {
    $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds))
    if (-not $acquired) {
        throw "Timed out waiting for git mutex '$mutexName' after $TimeoutSeconds seconds."
    }

    if ($GitCommand -eq "commit") {
        $allowlistScript = Join-Path $PSScriptRoot "Assert-CommitAllowlist.ps1"
        if (-not (Test-Path -LiteralPath $allowlistScript)) {
            throw "Commit allowlist script missing: $allowlistScript"
        }

        $allowArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $allowlistScript,
            "-RepoRoot", $resolvedRepo,
            "-FailOnRepoRootZeroByte"
        )
        foreach ($allowedPath in $CommitAllowedPaths) {
            $allowArgs += @("-AllowedPaths", $allowedPath)
        }
        foreach ($allowedExactPath in $CommitAllowedExactPaths) {
            $allowArgs += @("-AllowedExactPaths", $allowedExactPath)
        }
        if ($FailWhenCommitAllowlistEmpty) {
            $allowArgs += "-AllowNothingWhenEmpty"
        }
        if ($FailOnUntrackedFiles) {
            $allowArgs += "-FailOnUntracked"
        }
        foreach ($allowedUntrackedPath in $CommitAllowedUntrackedPaths) {
            $allowArgs += @("-AllowedUntrackedPaths", $allowedUntrackedPath)
        }
        foreach ($allowedUntrackedExactPath in $CommitAllowedUntrackedExactPaths) {
            $allowArgs += @("-AllowedUntrackedExactPaths", $allowedUntrackedExactPath)
        }

        & powershell @allowArgs
        $allowExit = $LASTEXITCODE
        if ($allowExit -ne 0) {
            exit $allowExit
        }
    }

    & git -C $resolvedRepo $GitCommand @GitArguments
    $exitCode = $LASTEXITCODE
}
finally {
    if ($acquired) {
        $mutex.ReleaseMutex() | Out-Null
    }
    $mutex.Dispose()
}

if ($exitCode -ne 0) {
    exit $exitCode
}

exit 0
