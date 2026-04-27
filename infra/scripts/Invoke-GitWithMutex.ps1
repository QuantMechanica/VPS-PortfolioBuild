[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,
    [int]$TimeoutSeconds = 120,
    [Parameter(Mandatory = $true)]
    [string]$GitCommand,
    [string[]]$GitArguments = @()
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
