# Board Advisor observe wrapper for QuantMechanica V5 strategy_farm.
# Triggered hourly at :47 by Windows Scheduled Task
# QM_StrategyFarm_BoardAdvisor_Hourly. Spawns a non-interactive Claude
# session that reads board_advisor_observe.md and executes one observe
# cycle (per the check tree in that prompt).
#
# Different from autonomous_wake.ps1: that wake DOES strategy_farm work.
# This wake OBSERVES + fixes drift / infrastructure issues.

$ErrorActionPreference = "Continue"

$promptFile = "C:\QM\repo\tools\strategy_farm\prompts\board_advisor_observe.md"
$logDir     = "D:\QM\strategy_farm\logs"
$disableFlag = "D:\QM\strategy_farm\CLAUDE_DISABLED.flag"
$stamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ssZ")

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$wakeLog = Join-Path $logDir "observe_wakes_invocation.log"
$sessLog = Join-Path $logDir "observe_wake_$stamp.log"

$utcNow = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
if (Test-Path -LiteralPath $disableFlag) {
    "$utcNow OBSERVE_SKIPPED claude_disabled_flag=$disableFlag" | Add-Content $wakeLog
    exit 0
}
"$utcNow OBSERVE_INVOKED  prompt=$promptFile  session_log=$sessLog" | Add-Content $wakeLog

$bootstrap = @"
You are woken by the hourly QM_StrategyFarm_BoardAdvisor_Hourly scheduled task.
Read C:\QM\repo\tools\strategy_farm\prompts\board_advisor_observe.md fully, then
execute the check tree exactly as specified there. You ARE the Board Advisor
per CLAUDE.md — Test-Environment-Ownership is in your direct-action zone.
Honor all hard boundaries (no T6 toggle, no autonomous_wake decision-tree
edits without OWNER sign-off, no force-push to main).
Commit any repo fixes, append exactly one line to
D:\QM\strategy_farm\logs\observe_wakes.log, and exit cleanly.
"@

& claude -p $bootstrap `
  --permission-mode bypassPermissions `
  --add-dir "C:\QM\repo" `
  --add-dir "D:\QM\strategy_farm" `
  --add-dir "G:\My Drive\QuantMechanica - Company Reference" `
  2>&1 | Tee-Object -FilePath $sessLog

$exitCode = $LASTEXITCODE
$utcEnd = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
"$utcEnd OBSERVE_EXITED   exit=$exitCode  session_log=$sessLog" | Add-Content $wakeLog
