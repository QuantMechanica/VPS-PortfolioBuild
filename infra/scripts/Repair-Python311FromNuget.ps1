param(
    [string]$PythonVersion = "3.11.9",
    [string]$InstallDir = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311",
    [string]$TempRoot = "C:\Temp\python-repair",
    [switch]$ForceReinstall
)

$ErrorActionPreference = "Stop"

function Test-PythonHealthy {
    param([string]$PythonExe)
    if (-not (Test-Path -LiteralPath $PythonExe)) {
        return $false
    }
    try {
        & $PythonExe -c "import encodings, ssl, sqlite3, pathlib, site; print('ok')" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return $true
    } catch {
        return $false
    }
}

function Set-PythonLauncherRegistry {
    param(
        [string]$PythonHome
    )
    $regPath = "HKCU:\Software\Python\PythonCore\3.11\InstallPath"
    New-Item -Path $regPath -Force | Out-Null
    Set-ItemProperty -Path $regPath -Name "(default)" -Value ("{0}\" -f $PythonHome)
    Set-ItemProperty -Path $regPath -Name "ExecutablePath" -Value (Join-Path $PythonHome "python.exe")
    Set-ItemProperty -Path $regPath -Name "WindowedExecutablePath" -Value (Join-Path $PythonHome "pythonw.exe")
}

$pythonExe = Join-Path $InstallDir "python.exe"
$wasHealthy = Test-PythonHealthy -PythonExe $pythonExe

if ($wasHealthy -and -not $ForceReinstall) {
    Set-PythonLauncherRegistry -PythonHome $InstallDir
    Write-Host "python_repair_status=already_healthy"
    & $pythonExe -V
    exit 0
}

New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
$pkgPath = Join-Path $TempRoot ("python.{0}.nupkg" -f $PythonVersion)
$extractDir = Join-Path $TempRoot ("python.{0}" -f $PythonVersion)
$uri = "https://www.nuget.org/api/v2/package/python/$PythonVersion"

Invoke-WebRequest -Uri $uri -OutFile $pkgPath
if (Test-Path -LiteralPath $extractDir) {
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
Expand-Archive -Path $pkgPath -DestinationPath $extractDir -Force

$toolsDir = Join-Path $extractDir "tools"
if (-not (Test-Path -LiteralPath $toolsDir)) {
    throw "NuGet package did not contain tools directory: $toolsDir"
}

if (Test-Path -LiteralPath $InstallDir) {
    Remove-Item -LiteralPath $InstallDir -Recurse -Force
}
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
Copy-Item -Path (Join-Path $toolsDir "*") -Destination $InstallDir -Recurse -Force

Set-PythonLauncherRegistry -PythonHome $InstallDir

$healthyNow = Test-PythonHealthy -PythonExe $pythonExe
if (-not $healthyNow) {
    throw "Python repair failed health check at $pythonExe"
}

& $pythonExe -V
& $pythonExe -m pip --version
Write-Host "python_repair_status=repaired"
