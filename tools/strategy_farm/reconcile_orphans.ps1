# reconcile_orphans.ps1 — reap orphaned factory terminal64 processes.
# Scheduled hourly as SYSTEM (QM_StrategyFarm_ReconcileOrphans_Hourly). Stops
# factory terminal64.exe whose work_item is no longer active (done/failed/missing)
# via the DESIGNED farmctl reconcile path (never manual tscon/kill). Preserves
# live backtests (work_item active/claimed) and NEVER touches T_Live. Appends an
# evidence line to D:\QM\reports\state\reconcile_orphans.jsonl.
[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo"
)
# Continue (not Stop): the local python.exe emits a benign "Could not find
# platform independent libraries" warning to stderr on every invocation; under
# Stop + PS7 native-error handling that would falsely terminate this wrapper.
$ErrorActionPreference = "Continue"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -Scope Global -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}
$py  = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe"
$farmctl = Join-Path $RepoRoot "tools\strategy_farm\farmctl.py"
$logDir  = "D:\QM\reports\state"
$logPath = Join-Path $logDir "reconcile_orphans.jsonl"
if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

# FACTORY_OFF.flag master switch: no-op immediately to prevent factory resurrection.
if (Test-Path 'D:\QM\strategy_farm\state\FACTORY_OFF.flag') {
    $offLine = [ordered]@{ ts_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"); task = "reconcile_orphans"; ok = $true; orphans_stopped = 0; skipped = "FACTORY_OFF.flag" } | ConvertTo-Json -Compress
    Add-Content -LiteralPath $logPath -Value $offLine -ErrorAction SilentlyContinue
    Write-Output $offLine
    exit 0
}

$ts = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$stopped = 0; $ok = $false; $err = ""
try {
    $raw = & $py $farmctl reconcile-mt5 --fix-orphan-terminals 2>$null
    $json = ($raw | Where-Object { $_ -notmatch 'platform independent libraries' }) -join "`n"
    $obj = $json | ConvertFrom-Json    # throws if farmctl produced no valid JSON
    $ok = $true
    if ($obj.actions) {
        $stopped = (@($obj.actions | Where-Object { $_.action -eq 'stop_orphaned_terminal64' -and $_.stopped }) | Measure-Object).Count
    }
} catch {
    $err = $_.Exception.Message
}
$line = [ordered]@{ ts_utc = $ts; task = "reconcile_orphans"; ok = $ok; orphans_stopped = $stopped; error = $err } | ConvertTo-Json -Compress
Add-Content -LiteralPath $logPath -Value $line
Write-Output $line
