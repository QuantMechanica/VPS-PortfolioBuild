param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm",
    [string]$Mt5Root = "D:\QM\mt5"
)

$ErrorActionPreference = "Stop"

$stateDir = Join-Path $FarmRoot "state"
$logDir = Join-Path $FarmRoot "logs"
$pidFile = Join-Path $stateDir "worker_pids.json"
$worker = Join-Path $RepoRoot "tools\strategy_farm\terminal_worker.py"
$factoryTerminals = 1..10 | ForEach-Object { "T$_" }

New-Item -ItemType Directory -Force -Path $stateDir | Out-Null
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$existing = @{}
if (Test-Path $pidFile) {
    try {
        $json = Get-Content -Raw -Path $pidFile | ConvertFrom-Json
        foreach ($prop in $json.PSObject.Properties) {
            $existing[$prop.Name] = [int]$prop.Value
        }
    } catch {
        $existing = @{}
    }
}

$updated = @{}
$terminals = $factoryTerminals | Where-Object {
    Test-Path -LiteralPath (Join-Path $Mt5Root (Join-Path $_ "terminal64.exe")) -PathType Leaf
}
foreach ($terminal in $terminals) {
    $workerPid = $existing[$terminal]
    if ($workerPid) {
        $proc = Get-Process -Id $workerPid -ErrorAction SilentlyContinue
        if ($proc) {
            $updated[$terminal] = $workerPid
            continue
        }
    }

    $logPath = Join-Path $logDir "terminal_worker_$terminal.log"
    $pythonw = (Get-Command pythonw.exe -ErrorAction SilentlyContinue).Source
    if (-not $pythonw) { $pythonw = (Get-Command python.exe).Source }
    $proc = Start-Process -FilePath $pythonw `
        -ArgumentList @("-u", $worker, "--terminal", $terminal, "--root", $FarmRoot) `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden `
        -RedirectStandardOutput $logPath `
        -RedirectStandardError "$logPath.err" `
        -PassThru
    $updated[$terminal] = $proc.Id
}

$updated | ConvertTo-Json | Set-Content -Path $pidFile -Encoding UTF8
$updated | ConvertTo-Json
