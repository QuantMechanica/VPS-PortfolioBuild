[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$LogPath = "C:\Windows\Temp\qm_public_snapshot.log",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [string]$FactoryOffFlagPath = "D:\QM\strategy_farm\state\FACTORY_OFF.flag",
    [string]$FactoryMutationLockPath = "D:\QM\strategy_farm\state\FACTORY_MUTATION.lock"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-TaskLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f ([datetime]::UtcNow.ToString("o")), $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
}

New-Item -ItemType Directory -Path (Split-Path -Parent $LogPath) -Force | Out-Null
Write-TaskLog "public_snapshot_task start"

$mutationLockStream = $null
$mutationLockBytesBase64 = $null
$locationPushed = $false
try {
    # MNT-052: the public exporter writes tracked files.  FACTORY_OFF therefore
    # gates it even though dashboards and read-only health tasks remain online.
    if (Test-Path -LiteralPath $FactoryOffFlagPath) {
        Write-TaskLog "public_snapshot_task skipped=FACTORY_OFF.flag"
        return
    }

    $mutationLockProtocolPath = Join-Path $RepoRoot `
        'tools\strategy_farm\factory_mutation_lock.ps1'
    if (-not (Test-Path -LiteralPath $mutationLockProtocolPath -PathType Leaf)) {
        throw "Mutation-lock protocol missing: $mutationLockProtocolPath"
    }
    . $mutationLockProtocolPath
    if ($script:QmFactoryMutationLockProtocolVersion -ne 2 -or
        -not (Get-Command -Name 'Remove-QmFactoryMutationLockIfUnchanged' `
            -CommandType Function -ErrorAction SilentlyContinue)) {
        throw 'Mutation-lock protocol version/function mismatch.'
    }

    $lockParent = Split-Path -Parent $FactoryMutationLockPath
    New-Item -ItemType Directory -Path $lockParent -Force | Out-Null
    try {
        $mutationLockStream = [System.IO.File]::Open(
            $FactoryMutationLockPath,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $lockRecord = [ordered]@{
            pid = $PID
            owner = 'public_snapshot'
            nonce = [guid]::NewGuid().ToString('N')
            created_at = [datetime]::UtcNow.ToString('o')
        } | ConvertTo-Json -Compress
        $lockBytes = [System.Text.Encoding]::UTF8.GetBytes($lockRecord)
        $mutationLockBytesBase64 = [Convert]::ToBase64String($lockBytes)
        $mutationLockStream.Write($lockBytes, 0, $lockBytes.Length)
        $mutationLockStream.Flush($true)
    }
    catch [System.IO.IOException] {
        Write-TaskLog "public_snapshot_task skipped=factory_mutation_lock_busy"
        return
    }

    if (Test-Path -LiteralPath $FactoryOffFlagPath) {
        Write-TaskLog "public_snapshot_task skipped=FACTORY_OFF.flag_after_lock"
        return
    }

    Push-Location $RepoRoot
    $locationPushed = $true
    if (-not (Test-Path -LiteralPath $PythonExe)) {
        throw "Python executable not found: $PythonExe"
    }

    # PS 5.1: with ErrorActionPreference=Stop, any native stderr line routed via 2>&1
    # becomes a terminating NativeCommandError (python's harmless "Could not find
    # platform independent libraries" warning killed this task hourly). Real failures
    # are caught via the explicit $LASTEXITCODE checks below.
    $ErrorActionPreference = "Continue"

    & $PythonExe (Join-Path $RepoRoot "scripts\build_pipeline_state.py") 2>&1 |
        ForEach-Object { Write-TaskLog $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "build_pipeline_state.py failed with exit code $LASTEXITCODE"
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $RepoRoot "scripts\export_public_snapshot.ps1") `
        -RepoRoot $RepoRoot `
        -PublicDataDir (Join-Path $RepoRoot "public-data") `
        -NoGit 2>&1 |
        ForEach-Object { Write-TaskLog $_ }
    if ($LASTEXITCODE -ne 0) {
        throw "export_public_snapshot.ps1 failed with exit code $LASTEXITCODE"
    }

    Write-TaskLog "public_snapshot_task exit=0"
}
catch {
    Write-TaskLog "public_snapshot_task exit=1 error=$($_.Exception.Message)"
    throw
}
finally {
    if ($locationPushed) {
        Pop-Location
    }
    if ($null -ne $mutationLockStream) {
        $mutationLockStream.Dispose()
        $releasedExactLock = Remove-QmFactoryMutationLockIfUnchanged `
            -Path $FactoryMutationLockPath `
            -ExpectedRawBytesBase64 $mutationLockBytesBase64
        if (-not $releasedExactLock) {
            Write-TaskLog `
                'public_snapshot_task mutation_lock_release=retained_fail_closed'
        }
    }
}
