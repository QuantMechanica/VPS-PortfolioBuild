# =====================================================================
#  QuantMechanica - tscon_console_keepalive.ps1
#  PERMANENT "RDP always-on" fix (OWNER 2026-06-09).
#
#  Problem: the MT5 visible-mode factory needs a LIVE desktop. When OWNER
#  disconnects RDP the session goes Disconnected -> no desktop -> terminal64
#  (GUI) can't render -> the whole factory wedges (workers alive, 0 terminals).
#
#  Fix: the instant the RDP session disconnects, snap it back to the PHYSICAL
#  CONSOLE (tscon /dest:console). The console always has a live desktop and
#  needs no RDP connection, so the factory keeps running headless. When OWNER
#  reconnects RDP, Windows reconnects them to the (console) session normally.
#
#  Driven by an event-triggered task on TerminalServices LocalSessionManager
#  EventID 24 (session disconnected). Runs as SYSTEM (tscon another session).
#  Only acts on a DISCONNECTED session of the autologon user; never disrupts an
#  Active RDP view. Complements the 15-min factory_watchdog tscon (this is instant).
# =====================================================================
$ErrorActionPreference = 'Continue'
$log = 'D:\QM\reports\state\tscon_keepalive.jsonl'

$targetUser = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).DefaultUserName
if (-not $targetUser) { $targetUser = 'qm-admin' }

# Resolve the autologon user's session id + state from qwinsta (handles both the
# Active "rdp-tcp#0 user 1 Active" line and the disconnected "user 1 Disc" line).
$sid = $null; $state = ''
foreach ($line in (qwinsta 2>$null)) {
    if (($line -match "\b$([regex]::Escape($targetUser))\b") -and
        ($line -match "\s(\d+)\s+(Active|Disc|Conn|Listen)\b")) { $sid = $matches[1]; $state = $matches[2] }
}

$action = 'noop'
if ($sid -and $state -eq 'Disc') {
    # reattach to the physical console -> restores a persistent active desktop
    & tscon.exe $sid /dest:console 2>$null
    Start-Sleep -Milliseconds 800
    $action = "tscon_console(sid=$sid,exit=$LASTEXITCODE)"
} elseif ($state -eq 'Active') {
    $action = 'noop_active'   # already connected/console-active, nothing to do
}

$now = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
try { Add-Content -Path $log -Value ('{"ts":"' + $now + '","user":"' + $targetUser + '","sid":"' + $sid + '","state":"' + $state + '","action":"' + $action + '"}') } catch {}
