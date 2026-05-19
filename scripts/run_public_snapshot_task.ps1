[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$LogPath = "C:\Windows\Temp\qm_public_snapshot.log",
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
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

Push-Location $RepoRoot
try {
    if (-not (Test-Path -LiteralPath $PythonExe)) {
        throw "Python executable not found: $PythonExe"
    }

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
    Pop-Location
}
