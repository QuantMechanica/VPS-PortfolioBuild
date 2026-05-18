param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$FarmRoot = "D:\QM\strategy_farm"
)

$ErrorActionPreference = "Stop"

$stateDir = Join-Path $FarmRoot "state"
$logDir = Join-Path $FarmRoot "logs"
$pidFile = Join-Path $stateDir "worker_pids.json"
$worker = Join-Path $RepoRoot "tools\strategy_farm\terminal_worker.py"

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
foreach ($terminal in @("T1", "T2", "T3", "T4", "T5")) {
    $workerPid = $existing[$terminal]
    if ($workerPid) {
        $proc = Get-Process -Id $workerPid -ErrorAction SilentlyContinue
        if ($proc) {
            $updated[$terminal] = $workerPid
            continue
        }
    }

    $logPath = Join-Path $logDir "terminal_worker_$terminal.log"
    $command = "& python.exe -u `"$worker`" --terminal $terminal --root `"$FarmRoot`" *>> `"$logPath`""
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) `
        -WorkingDirectory $RepoRoot `
        -WindowStyle Hidden `
        -PassThru
    $updated[$terminal] = $proc.Id
}

$updated | ConvertTo-Json | Set-Content -Path $pidFile -Encoding UTF8
$updated | ConvertTo-Json
