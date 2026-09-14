"""Bounded watchdog pause (Orchestrator 2026-09-14 03:5xZ, GRUEN infra, rollback = re-enable): the factory watchdog's
dispatch_stall predicate (active=0 AND pending>=threshold AND factory terminal64=0) fired every 10 min while the fleet was
claim-idle, wrote WATCHDOG_RESET_PENDING (Factory_ON task result 1), and cleared it 5 min later - a livelock that left the
workers only short unblocked windows (03:15-03:55Z). Wait until the marker is gone, then disable
QM_StrategyFarm_FactoryWatchdog_15min for PAUSE_MIN minutes so the workers get one continuous claim window, then re-enable.
Never touches T_Live watchdog tasks. Log: D:/QM/strategy_farm/logs/watchdog_pause_0914.log"""
import datetime as dt, os, subprocess, time
from pathlib import Path
TASK = "QM_StrategyFarm_FactoryWatchdog_15min"; MARK = Path("D:/QM/strategy_farm/state/WATCHDOG_RESET_PENDING.json")
LOG = Path("D:/QM/strategy_farm/logs/watchdog_pause_0914.log"); PAUSE_MIN = 40
def log(s):
    with LOG.open("a", encoding="utf-8") as fh: fh.write(dt.datetime.now(dt.timezone.utc).strftime("%H:%M:%SZ ") + s + "\n")
def ps(cmd): return subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True).stdout.strip()
log("start; waiting for marker clearance")
deadline = time.time() + 20 * 60
while MARK.exists() and time.time() < deadline: time.sleep(10)
if MARK.exists():
    log("marker still present after 20 min; aborting without touching the task"); raise SystemExit(1)
log("marker gone -> " + ps(f"Disable-ScheduledTask -TaskName '{TASK}' | Out-Null; (Get-ScheduledTask -TaskName '{TASK}').State"))
try:
    time.sleep(PAUSE_MIN * 60)
finally:
    log("re-enable -> " + ps(f"Enable-ScheduledTask -TaskName '{TASK}' | Out-Null; (Get-ScheduledTask -TaskName '{TASK}').State"))
log("end")
