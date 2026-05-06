param(
    [string]$PythonExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe",
    [string]$ExpectedPrefix = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311",
    [switch]$SkipPip
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $PythonExe)) {
    Write-Host ("status=critical reason=python_exe_missing path={0}" -f $PythonExe)
    exit 2
}

$libDir = Join-Path (Split-Path -Parent $PythonExe) "Lib"
if (-not (Test-Path -LiteralPath $libDir)) {
    Write-Host ("status=critical reason=lib_dir_missing path={0}" -f $libDir)
    exit 2
}

try {
    $prefix = (& $PythonExe -c "import sys; print(sys.prefix)" 2>&1).Trim()
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("status=critical reason=python_prefix_probe_failed exit_code={0}" -f $LASTEXITCODE)
        exit 2
    }
} catch {
    Write-Host ("status=critical reason=python_prefix_probe_exception detail={0}" -f $_.Exception.Message)
    exit 2
}

if (-not $prefix.StartsWith($ExpectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Host ("status=critical reason=python_prefix_mismatch expected_prefix={0} actual_prefix={1}" -f $ExpectedPrefix, $prefix)
    exit 2
}

try {
    & $PythonExe -c "import encodings, ssl, sqlite3, pathlib, site; print('stdlib_ok')" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host ("status=critical reason=stdlib_import_failed exit_code={0}" -f $LASTEXITCODE)
        exit 2
    }
} catch {
    Write-Host ("status=critical reason=stdlib_import_exception detail={0}" -f $_.Exception.Message)
    exit 2
}

if (-not $SkipPip) {
    try {
        & $PythonExe -m pip --version | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("status=critical reason=pip_probe_failed exit_code={0}" -f $LASTEXITCODE)
            exit 2
        }
    } catch {
        Write-Host ("status=critical reason=pip_probe_exception detail={0}" -f $_.Exception.Message)
        exit 2
    }
}

Write-Host ("status=ok python_exe={0} prefix={1}" -f $PythonExe, $prefix)
exit 0
