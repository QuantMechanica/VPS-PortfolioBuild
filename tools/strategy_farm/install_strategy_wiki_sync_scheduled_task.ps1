[CmdletBinding()]
param(
    [string]$RepoRoot = "C:\QM\repo",
    [string]$PythonwExe = "C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe",
    [int]$EveryMinutes = 60,
    [string]$TaskUser = "qm-admin",
    [switch]$RunNow,
    [switch]$Uninstall
)
# Strategy Wiki Sync (OWNER follow-up directive 2026-09-15 §2-§8): projects every
# canonical strategy record into a deterministic, generated Vault node, rebuilds the
# generated index, and lints completeness/staleness -> STRATEGY_WIKI_SYNC health key.
# Three sequential actions: build -> index --init-root-index -> lint. The generator
# writes only changed files, so steady-state cloud-sync cost is minimal. lint exits
# non-zero on RED; a scheduled task tolerates that (the health read-model carries the
# state for Mission Control). Rollback: -Uninstall (the generated Vault folder and the
# read-model persist; delete "09 Strategy Wiki\generated" by hand to fully revert).
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$taskName = "QM_StrategyFarm_StrategyWikiSync_60min"
$tool = Join-Path $RepoRoot "tools\strategy_farm\strategy_wiki_sync.py"

if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Output "UNINSTALLED $taskName"
    return
}

foreach ($p in @($PythonwExe, $tool)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "missing: $p" }
}

$startBoundary = (Get-Date).Date.AddHours((Get-Date).Hour).AddMinutes(31)
$trigger = New-ScheduledTaskTrigger -Once -At $startBoundary `
    -RepetitionInterval (New-TimeSpan -Minutes $EveryMinutes) `
    -RepetitionDuration (New-TimeSpan -Days 3650)
$actions = @(
    # Lineage map first (follow-up directive s9): the wiki build renders per-node relationships from it.
    New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"${RepoRoot}\tools\strategy_farm\lineage_map.py`" --summary" -WorkingDirectory $RepoRoot
    New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$tool`" build" -WorkingDirectory $RepoRoot
    New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$tool`" index --init-root-index" -WorkingDirectory $RepoRoot
    New-ScheduledTaskAction -Execute $PythonwExe -Argument "-X utf8 `"$tool`" lint" -WorkingDirectory $RepoRoot
)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) -StartWhenAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
# 2026-09-15 incident repair: SYSTEM has no G: drive mapping (Google Drive File Stream is
# per-user), so this task died instantly on the vault write. Run as the interactive
# vault-owning user instead (same pattern as QM_Live_MT5_SessionSupervisor).
$principal = New-ScheduledTaskPrincipal -UserId $TaskUser -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $actions -Trigger $trigger `
    -Settings $settings -Principal $principal -Force | Out-Null
Write-Output "REGISTERED $taskName every $EveryMinutes min, first at $startBoundary"
if ($RunNow) { Start-ScheduledTask -TaskName $taskName; Write-Output "STARTED $taskName" }
