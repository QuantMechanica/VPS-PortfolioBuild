param(
    [switch]$SkipDashboardPatch,
    [switch]$DryRun,
    [switch]$Guardrail
)

$ErrorActionPreference = "Stop"

$root = "G:\Meine Ablage\QuantMechanica"
$builder = Join-Path $root "Company\scripts\build_processes_html.py"

if (-not (Test-Path $builder)) {
    throw "Builder not found: $builder"
}

function Resolve-PythonExe {
    $pythonCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($pythonCmd) {
        return $pythonCmd.Source
    }

    $condaPython = Join-Path $env:USERPROFILE "anaconda3\python.exe"
    if (Test-Path $condaPython) {
        return $condaPython
    }

    $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
    if ($pyLauncher) {
        try {
            $resolved = (& $pyLauncher.Source -c "import sys; print(sys.executable)" 2>$null).Trim()
            if ($resolved -and (Test-Path $resolved)) {
                return $resolved
            }
        } catch {
        }
    }

    throw "No working Python interpreter found. Install Python or ensure either 'python', '%USERPROFILE%\\anaconda3\\python.exe', or a valid 'py' launcher target exists."
}

$args = @($builder)
if ($SkipDashboardPatch) {
    $args += "--skip-dashboard-patch"
}
if ($DryRun) {
    $args += "--dry-run"
}
if ($Guardrail) {
    $args += "--guardrail"
}

$pythonExe = Resolve-PythonExe
Write-Host "Running process builder: $pythonExe $($args -join ' ')" -ForegroundColor Cyan
& $pythonExe @args
if ($LASTEXITCODE -ne 0) {
    throw "build_processes_html.py failed with exit code $LASTEXITCODE"
}

Write-Host "Done: processes.html refreshed." -ForegroundColor Green
