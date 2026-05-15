# Autonomous wake wrapper for QuantMechanica V5 strategy_farm.
# Triggered hourly by Windows Scheduled Task QM_StrategyFarm_AutonomousWake_Hourly.
# Spawns a non-interactive Claude session that reads autonomous_loop.md and
# executes one productive wake (per the decision tree in that prompt).

$ErrorActionPreference = "Continue"

$promptFile = "C:\QM\repo\tools\strategy_farm\prompts\autonomous_loop.md"
$logDir     = "D:\QM\strategy_farm\logs"
$stamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ssZ")

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$wakeLog = Join-Path $logDir "autonomous_wakes_invocation.log"
$sessLog = Join-Path $logDir "autonomous_wake_$stamp.log"

$utcNow = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
"$utcNow WAKE_INVOKED  prompt=$promptFile  session_log=$sessLog" | Add-Content $wakeLog

$bootstrap = @"
You are woken by the hourly QM_StrategyFarm_AutonomousWake_Hourly scheduled task.
Read C:\QM\repo\tools\strategy_farm\prompts\autonomous_loop.md fully, then
execute the decision tree exactly as specified there. Honor all hard boundaries.
Commit any changes, append exactly one line to D:\QM\strategy_farm\logs\autonomous_wakes.log,
and exit cleanly.
"@

# Invoke claude CLI in non-interactive print mode with full bypass permissions
# (autonomous = no permission prompts) and explicit access to the three roots
# the loop needs: repo, runtime, and vault.
& claude -p $bootstrap `
  --permission-mode bypassPermissions `
  --add-dir "C:\QM\repo" `
  --add-dir "D:\QM\strategy_farm" `
  --add-dir "G:\My Drive\QuantMechanica - Company Reference" `
  2>&1 | Tee-Object -FilePath $sessLog

$exitCode = $LASTEXITCODE
$utcEnd = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
"$utcEnd WAKE_EXITED   exit=$exitCode  session_log=$sessLog" | Add-Content $wakeLog
