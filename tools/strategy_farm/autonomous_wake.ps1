# Autonomous wake wrapper for QuantMechanica V5 strategy_farm.
# Triggered hourly by Windows Scheduled Task QM_StrategyFarm_AutonomousWake_Hourly.
# Spawns a non-interactive Claude session that reads autonomous_loop.md and
# executes one productive wake (per the decision tree in that prompt).

$ErrorActionPreference = "Continue"

$promptFile = "C:\QM\repo\tools\strategy_farm\prompts\autonomous_loop.md"
$logDir     = "D:\QM\strategy_farm\logs"
$disableFlag = "D:\QM\strategy_farm\CLAUDE_DISABLED.flag"
$stamp      = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH-mm-ssZ")

New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$wakeLog    = Join-Path $logDir "autonomous_wakes_invocation.log"
$sessLog    = Join-Path $logDir "autonomous_wake_$stamp.log"
# JSONL session log streamed via Claude --output-format stream-json. Tee-Object
# above flushed only on exit, so OWNER had zero visibility into a running wake.
# JSONL events arrive line-by-line and are parseable by a tailer.
$sessJsonl  = Join-Path $logDir "autonomous_wake_$stamp.jsonl"
# Heartbeat file: rewritten on every Claude stdout line so external watchers
# can detect liveness without parsing JSON. Contains the latest tool/text
# event one-liner.
$heartbeat  = Join-Path $logDir "autonomous_wake_current.heartbeat"

$utcNow = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
if (Test-Path -LiteralPath $disableFlag) {
    "$utcNow WAKE_SKIPPED claude_disabled_flag=$disableFlag" | Add-Content $wakeLog
    exit 0
}
"$utcNow WAKE_INVOKED  prompt=$promptFile  session_log=$sessLog  jsonl=$sessJsonl" | Add-Content $wakeLog
"$utcNow STARTED" | Set-Content $heartbeat

$bootstrap = @"
You are woken by the hourly QM_StrategyFarm_AutonomousWake_Hourly scheduled task.
Read C:\QM\repo\tools\strategy_farm\prompts\autonomous_loop.md fully, then
execute the decision tree exactly as specified there. Honor all hard boundaries.
Commit any changes, append exactly one line to D:\QM\strategy_farm\logs\autonomous_wakes.log,
and exit cleanly.
"@

# Invoke claude CLI in non-interactive print mode with stream-json output so
# each tool-call / text event lands in $sessJsonl immediately (vs Tee-Object's
# on-exit flush of the plain-text format which made running wakes opaque).
# Plain-text log retained in parallel for grep/human read.
& claude -p $bootstrap `
  --permission-mode bypassPermissions `
  --output-format stream-json `
  --verbose `
  --add-dir "C:\QM\repo" `
  --add-dir "D:\QM\strategy_farm" `
  --add-dir "G:\My Drive\QuantMechanica - Company Reference" `
  2>&1 | ForEach-Object {
      # Append raw JSONL
      $_ | Add-Content -LiteralPath $sessJsonl
      # Mirror to plain-text session log
      $_ | Add-Content -LiteralPath $sessLog
      # Heartbeat: timestamp + first 200 chars of the event
      $hbLine = "{0} {1}" -f (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ"), ($_.Substring(0, [Math]::Min(200, $_.Length)))
      Set-Content -LiteralPath $heartbeat -Value $hbLine
  }

$exitCode = $LASTEXITCODE
$utcEnd = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
"$utcEnd WAKE_EXITED   exit=$exitCode  session_log=$sessLog" | Add-Content $wakeLog
"$utcEnd EXITED exit=$exitCode" | Set-Content $heartbeat
