# =====================================================================
#  QuantMechanica - Factory Watchdog (in-session, self-healing)
#  Covers the gap the boot-autostart (FactoryON_AtLogon) does NOT:
#  the interactive session is alive but the worker daemons / MT5
#  terminals have died (crash, hang, OOM kill). Respawns ONLY the
#  missing workers, in THIS session, so the visible-mode factory keeps
#  producing without a manual "Factory ON" click.
#
#  MUST run in the interactive (autologon) session, RunLevel=Highest -
#  a SYSTEM/session-0 task cannot spawn visible terminals (that is the
#  exact reason the hourly_monitor only ESCALATES "factory down" and
#  Repair_Hourly/TerminalWorkers are ENFORCE_DISABLED). This watchdog is
#  the in-session complement to that session-0 triage monitor.
#
#  Deterministic + respects OWNER's ON/OFF:
#    - OWNER intent is read from the FACTORY tasks' enable-state
#      (Factory ON enables Pump/Tick, Factory OFF disables them).
#      If the factory is intentionally OFF -> do NOTHING.
#    - If ON and live workers < MinWorkers -> run start_terminal_workers
#      --dedupe (idempotent: fills only the missing slots, never doubles,
#      never interrupts a running backtest).
#    - NEVER toggles FACTORY/AI enable-state, NEVER touches T_Live,
#      no email (NO ping-mail policy). One JSON line to the triage log.
# =====================================================================

param(
    [int]$MinWorkers = 8,            # heal when fewer than this many worker daemons are alive
    [int]$ExpectWorkers = 10,
    [int]$StallPendingThreshold = 50 # heal when workers are ALIVE but WEDGED: 0 active +
                                     # >= this many pending + 0 terminal64 = dispatcher stalled
)

$ErrorActionPreference = 'Continue'
$repo = 'C:\QM\repo'
$py   = 'C:\Users\Administrator\AppData\Local\Programs\Python\Python311\python.exe'
$log  = 'D:\QM\reports\state\factory_watchdog.jsonl'
$stallDumpRequest = 'D:\QM\reports\state\STALLDUMP_REQUEST'
$stallDumpDir = 'D:\QM\reports\state\worker_stalldump'
. (Join-Path $PSScriptRoot 'qm_tasks.manifest.ps1')

$now    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$action = 'none'
$detail = ''

function Invoke-StallDumpCapture {
    param(
        [string]$RequestPath,
        [string]$DumpDir
    )

    $requestStarted = (Get-Date).ToUniversalTime()
    try {
        if (-not (Test-Path $DumpDir)) { New-Item -ItemType Directory -Path $DumpDir -Force | Out-Null }
        Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip 50 |
            Remove-Item -Force -ErrorAction SilentlyContinue

        Set-Content -Path $RequestPath -Value $requestStarted.ToString('yyyy-MM-ddTHH:mm:ssZ') -Encoding ASCII
        Start-Sleep -Seconds 8

        $files = @(Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
                   Where-Object { $_.LastWriteTimeUtc -ge $requestStarted.AddSeconds(-1) } |
                   Sort-Object LastWriteTimeUtc -Descending)
        $sample = ($files | Select-Object -First 10 | ForEach-Object { $_.Name }) -join ','
        $summary = "stalldump_request files=$($files.Count) dir=$DumpDir"
        if ($sample) { $summary += " sample=$sample" }
        return $summary
    } catch {
        return "stalldump_request_error=$($_.Exception.Message)"
    } finally {
        Remove-Item -Path $RequestPath -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $DumpDir -Filter '*.txt' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -Skip 50 |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

# 1. OWNER intent: is the factory meant to be ON? (FACTORY tasks enabled?)
$factoryEnabled = $false
foreach ($t in $QM_FACTORY_TASKS) {
    $task = Get-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne 'Disabled') { $factoryEnabled = $true }
}

# 2. how many worker daemons are alive right now?
$daemons = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.CommandLine -match 'terminal_worker\.py' })
$nWorkers = $daemons.Count

# 2b. DISPATCH-STALL detection (added 2026-06-09 after an ~8.5h wedge stall).
# Worker COUNT alone misses the case where workers are alive but WEDGED: after an
# RDP disconnect/reconnect they hold a dead session handle, so they claim work but
# cannot launch terminal64 ("released_stale_claims") -> the queue has work but 0
# runs. Signal: factory ON, 0 active work_items, >= StallPendingThreshold pending,
# and 0 terminal64 procs. The same clean-slate respawn fixes it (fresh workers get
# a live session handle via CreateProcessAsUser, even into a disconnected session).
$dispatchStalled = $false
$stallInfo = ''
if ($factoryEnabled) {
    try {
        # Count ONLY factory T1-T10 terminals, not every terminal64 on the box. A
        # dedicated analysis terminal (D:\QM\mt5\T_Export) or the live T_Live terminal
        # must NOT count here, else they MASK a real dispatch stall (observed 2026-06-09:
        # a T_Export export run showed term64=1 and the watchdog read 'healthy' while the
        # factory was wedged 0-active).
        $nTerm = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }).Count
        # single-quoted here-string + stdin pipe avoids all PowerShell/SQL quote escaping
        $q = @'
import sqlite3
c = sqlite3.connect(r"D:/QM/strategy_farm/state/farm_state.sqlite")
a = c.execute("SELECT COUNT(*) FROM work_items WHERE status='active'").fetchone()[0]
p = c.execute("SELECT COUNT(*) FROM work_items WHERE status='pending'").fetchone()[0]
print(str(a) + " " + str(p))
'@
        $out = ($q | & $py - 2>$null) -join ' '
        $m = [regex]::Match($out, '(\d+)\s+(\d+)')
        if ($m.Success) {
            $nActive = [int]$m.Groups[1].Value
            $nPending = [int]$m.Groups[2].Value
            $stallInfo = "active=$nActive pending=$nPending term64=$nTerm"
            if ($nActive -eq 0 -and $nPending -ge $StallPendingThreshold -and $nTerm -eq 0) {
                $dispatchStalled = $true
            }
        }
    } catch { $stallInfo = "stall-probe-error: $_" }
}

# 2c. SESSION-LOSS detection + reboot-heal (added 2026-06-11).
# The one case neither respawn nor tscon can fix: the interactive session itself is
# DESTROYED (observed 3x 2026-06-10/11: LSM event 40 reason 23, per-session user
# services killed, no logoff event; one death preceded by an 0xc0000142 desktop-heap
# burst, two more correlate with dxgkrnl LiveKernelEvents). With NO qm-admin session,
# WTSQueryUserToken has no token to spawn into -> factory stays dead until OWNER logs
# in. Heal: controlled reboot -> autologon (LSA DefaultPassword secret, verified
# 2026-06-11) recreates the console session -> FactoryON_AtLogon restores the factory.
# Guards: confirm on 2 consecutive runs (~15 min), 6h cooldown, autologon secret must
# exist, never while any T_Live terminal runs (Hard Rule: live trading untouchable).
$sessionLost = $false
$targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
if (-not $targetUser) { $targetUser = 'qm-admin' }
if ($factoryEnabled) {
    $hasSession = $false
    foreach ($line in (qwinsta 2>$null)) {
        if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
            ($line -match "\s\d+\s+(Active|Disc|Conn)\b")) { $hasSession = $true }
    }
    $sessionLost = -not $hasSession
}

if ($factoryEnabled -and $sessionLost) {
    $healState = 'D:\QM\reports\state\watchdog_session_heal.json'
    $st = $null
    try { $st = Get-Content $healState -Raw -ErrorAction Stop | ConvertFrom-Json } catch {}
    $nowDt = Get-Date
    $pendingSince = $null
    if ($st -and $st.pending_since) { try { $pendingSince = [datetime]$st.pending_since } catch {} }
    $lastReboot = $null
    if ($st -and $st.last_reboot) { try { $lastReboot = [datetime]$st.last_reboot } catch {} }

    $secretOk = $false
    try { $secretOk = $null -ne [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine','Default').OpenSubKey('SECURITY\Policy\Secrets\DefaultPassword') } catch {}
    $autologonOn = ((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon -eq '1')
    $tLiveRunning = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
                      Where-Object { $_.CommandLine -match 'T_Live' }).Count -gt 0

    if (-not ($secretOk -and $autologonOn)) {
        $action = 'session_lost_no_autologon'
        $detail = "NO interactive $targetUser session, but autologon not usable (secret=$secretOk autoadmin=$autologonOn) - reboot would strand at logon screen; OWNER must log in"
    } elseif ($tLiveRunning) {
        $action = 'session_lost_tlive_guard'
        $detail = "NO interactive $targetUser session but a T_Live terminal is running - refusing auto-reboot (Hard Rule)"
    } elseif ($lastReboot -and ($nowDt - $lastReboot).TotalHours -lt 6) {
        $action = 'session_lost_cooldown'
        $detail = "NO interactive $targetUser session; auto-reboot suppressed (last heal-reboot $($st.last_reboot), 6h cooldown)"
    } elseif (-not $pendingSince) {
        $action = 'session_lost_pending_confirm'
        $detail = "NO interactive $targetUser session detected; confirming on next run before reboot-heal"
        @{ pending_since = $nowDt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'); last_reboot = $st.last_reboot } |
            ConvertTo-Json -Compress | Set-Content -Path $healState -Encoding UTF8
    } else {
        $action = 'healed_session_reboot'
        $detail = "NO interactive $targetUser session for 2 consecutive checks (since $($st.pending_since)) while factory ON -> controlled reboot to restore autologon session + FactoryON_AtLogon"
        @{ pending_since = $null; last_reboot = $nowDt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } |
            ConvertTo-Json -Compress | Set-Content -Path $healState -Encoding UTF8
        & shutdown.exe /r /t 60 /d p:4:1 /c "QM factory_watchdog: interactive session lost - auto-reboot to restore autologon session"
    }
    # clear stale pending flag once a session exists again
} elseif (Test-Path 'D:\QM\reports\state\watchdog_session_heal.json') {
    try {
        $st = Get-Content 'D:\QM\reports\state\watchdog_session_heal.json' -Raw | ConvertFrom-Json
        if ($st.pending_since) {
            @{ pending_since = $null; last_reboot = $st.last_reboot } | ConvertTo-Json -Compress |
                Set-Content -Path 'D:\QM\reports\state\watchdog_session_heal.json' -Encoding UTF8
        }
    } catch {}
}

if ($factoryEnabled -and $sessionLost) {
    # handled above; fall through to logging
}
elseif (-not $factoryEnabled) {
    $action = 'noop_factory_off'
    $detail = "FACTORY tasks disabled (OWNER OFF); workers=$nWorkers - leaving alone"
}
elseif ($nWorkers -ge $MinWorkers -and -not $dispatchStalled) {
    $action = 'noop_healthy'
    $detail = "workers=$nWorkers/$ExpectWorkers (>= $MinWorkers); $stallInfo"
}
else {
    # 3. heal: factory meant ON but workers are dead/short OR alive-but-wedged
    #    (dispatch stalled) -> clean-slate respawn either way.
    if ($dispatchStalled) {
        $detail = "DISPATCH STALL: workers=$nWorkers alive but wedged ($stallInfo) while factory ON -> clean-slate respawn"
    } else {
        $detail = "workers=$nWorkers/$ExpectWorkers (< $MinWorkers) while factory ON -> clean-slate respawn"
    }
    # ESCALATION (2026-06-09): a dispatch stall on a DISCONNECTED session is the case the
    # plain respawn CANNOT fix -- workers respawn fine, but terminal64 (a GUI app) has no
    # live desktop to render in on a disconnected session, so 0 runs persist (observed:
    # 6 failed heals 13:30-14:45Z, then OWNER's manual reconnect+ON fixed it). Reattach the
    # session to the physical console with tscon -> a persistent ACTIVE desktop that needs
    # NO RDP connection -> the respawned terminals run headless. SAFETY: only when the
    # session is DISCONNECTED (Disc); never tscon an Active RDP view (would disrupt OWNER).
    if ($dispatchStalled) {
        try {
            $targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
            if (-not $targetUser) { $targetUser = 'qm-admin' }
            $sid = $null; $sstate = ''
            foreach ($line in (qwinsta 2>$null)) {
                if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
                    ($line -match "\s(\d+)\s+(Active|Disc|Conn|Listen)\b")) { $sid = $matches[1]; $sstate = $matches[2] }
            }
            if ($sstate -eq 'Disc' -and $sid) {
                & tscon.exe $sid /dest:console 2>$null
                Start-Sleep -Seconds 3
                $detail += " | tscon->console(sid=$sid) to restore desktop"
            } else {
                $detail += " | tscon_skip(state='$sstate')"
            }
        } catch { $detail += " | tscon_err=$($_.Exception.Message)" }
    }
    try {
        # CLEAN-SLATE respawn INTO the autologon console session (visible-mode).
        # Why clean-slate (kill-all then spawn 10) instead of --dedupe gap-fill:
        # start_terminal_workers' --dedupe detects existing workers via a CIM
        # (Get-CimInstance) query that FAILS inside a CreateProcessAsUser'd
        # disconnected-session process -> it would see 0 existing and spawn a full
        # 10 ON TOP of survivors (observed 7 -> 17 over-provision). So we first
        # kill every worker + terminal64 from THIS SYSTEM/session-0 context (where
        # CIM works), then launch a fresh set of exactly 10 (nothing to dedupe).
        #
        # This watchdog runs as SYSTEM (SeTcb) so the launcher can WTSQueryUserToken
        # + CreateProcessAsUser into qm-admin's session even when RDP is DISCONNECTED.
        # A plain `& $py ...` here would land workers in SYSTEM's session-0 (hazard).
        if ($dispatchStalled) {
            $dumpDetail = Invoke-StallDumpCapture -RequestPath $stallDumpRequest -DumpDir $stallDumpDir
            $detail += " | $dumpDetail"
        }
        foreach ($d in $daemons) { Stop-Process -Id $d.ProcessId -Force -ErrorAction SilentlyContinue }
        # Kill ONLY factory T1-T10 terminals. NEVER terminate T_Live (live trading —
        # OWNER+Claude authority, Hard Rule) or T_Export (analysis); matching by the
        # T1-T10 path keeps the clean-slate respawn from ever touching them.
        @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe'" -ErrorAction SilentlyContinue |
          Where-Object { $_.CommandLine -match '\\mt5\\T(?:[1-9]|10)\\' }) |
          ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Seconds 4
        $launcher = Join-Path $repo 'tools\strategy_farm\run_in_console_session.ps1'
        $swArgs = '"' + (Join-Path $repo 'tools\strategy_farm\start_terminal_workers.py') + '" --repo-root "' + $repo + '" --farm-root "D:\QM\strategy_farm" --dedupe'
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $launcher -Exe $py -Arguments $swArgs -WorkDir $repo 2>$null | Out-Null
        Start-Sleep -Seconds 12
        $after = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction SilentlyContinue |
                   Where-Object { $_.CommandLine -match 'terminal_worker\.py' }).Count
        $action = 'healed_respawn_workers'
        $detail += " -> after=$after/$ExpectWorkers"
    } catch {
        $action = 'heal_failed'
        $detail += " -> ERROR: $_"
    }
}

# 4. record (rolling JSONL, keep last 500). No email.
$record = [ordered]@{
    ts               = $now
    factory_enabled  = $factoryEnabled
    workers          = $nWorkers
    expect           = $ExpectWorkers
    dispatch_stalled = $dispatchStalled
    session_lost     = $sessionLost
    action           = $action
    detail           = $detail
} | ConvertTo-Json -Compress -Depth 4

try {
    $dir = Split-Path $log -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Add-Content -Path $log -Value $record -Encoding UTF8
    $lines = Get-Content $log -ErrorAction SilentlyContinue
    if ($lines -and $lines.Count -gt 500) { Set-Content -Path $log -Value ($lines | Select-Object -Last 500) -Encoding UTF8 }
} catch { }

Write-Output $record
