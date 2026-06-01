# =====================================================================
#  QuantMechanica - Hourly Factory Monitor (deterministic, fail-safe)
#  Durable successor to the removed AutonomousWake task, scoped to safe,
#  reversible triage only (DL-065). Runs as an ALWAYS_ON scheduled task.
#
#  Each run:
#    1. farmctl health  -> classify FAIL/WARN
#    2. AUTO-FIX (reversible only):
#         - ensure ALWAYS_ON tasks enabled (re-enable drift; e.g. morning brief)
#         - force-disable ENFORCE_DISABLED hazards if drifted on (Repair_Hourly,
#           TerminalWorkers) - the exact drift caught 2026-06-01
#    3. ESCALATE (record only, never auto-act): codex_auth_broken, factory down,
#         T_Live, code bugs. Special-case the codex token-refresh race
#         (low auth_age + 401 = auth dying right after login).
#    4. Append one JSON line to the triage log. NO email (GmailAlarm owns that);
#       NO destructive ops; NEVER touches FACTORY/AI enable-state (OWNER's ON/OFF)
#       or T_Live.
# =====================================================================

$ErrorActionPreference = 'Continue'
$repo = 'C:\QM\repo'
$py   = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$triageLog = 'D:\QM\reports\state\hourly_monitor.jsonl'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$actions = @()
$escalations = @()

# 1. health
$health = $null
try {
    $raw = & $py (Join-Path $repo 'tools\strategy_farm\farmctl.py') health 2>$null
    $health = $raw | ConvertFrom-Json
} catch { $escalations += "health_command_failed:$_" }

$fails = @(); $warns = @()
if ($health) {
    foreach ($c in $health.checks) {
        if ($c.status -eq 'FAIL') { $fails += $c }
        elseif ($c.status -eq 'WARN') { $warns += $c }
    }
}

# 2. AUTO-FIX (reversible task-state drift only)
foreach ($t in $QM_ALWAYSON_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -eq 'Disabled') {
        Enable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        $actions += "re-enabled_alwayson:$t"
    }
}
foreach ($t in $QM_ENFORCE_DISABLED_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') {
        Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        Disable-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue | Out-Null
        $actions += "force_disabled_hazard:$t"
    }
}

# 3. ESCALATE (record only)
foreach ($c in $fails) {
    $esc = "FAIL:$($c.name):$($c.detail)"
    # codex token-refresh race: auth dying right after login
    if ($c.name -eq 'codex_auth_broken' -and $c.detail -match 'auth_age=([0-9.]+)h') {
        $age = [double]$matches[1]
        if ($age -lt 2.0 -and $c.detail -match '401') {
            $esc = "FAIL:codex_auth_broken:TOKEN_REFRESH_RACE (fresh login dying; verify codex orchestration --max-sessions=1) :: $($c.detail)"
        }
    }
    $escalations += $esc
}

# 4. record (rolling JSONL); keep only last 500 lines
$record = [ordered]@{
    ts          = $now
    n_fail      = $fails.Count
    n_warn      = $warns.Count
    auto_fixed  = $actions
    escalations = $escalations
} | ConvertTo-Json -Compress -Depth 5

try {
    $dir = Split-Path $triageLog -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $triageLog -Value $record -Encoding UTF8
    if (Test-Path $triageLog) {
        $lines = Get-Content $triageLog
        if ($lines.Count -gt 500) { Set-Content -Path $triageLog -Value ($lines | Select-Object -Last 500) -Encoding UTF8 }
    }
} catch { }

Write-Output $record
