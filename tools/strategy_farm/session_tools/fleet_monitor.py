"""Session-bound fleet monitor (read-only). One stdout line per 10 min + immediate line on containment trip.

Usage: python -X utf8 fleet_monitor.py [interval_seconds=600]
Events: 'CONTAINMENT_TRIP enabled=true ...' the moment the mode file flips; every interval a summary
'FLEET <utc> active=<n> census_done_10m=<n> census_done_60m=<n> q02_done_10m=<n> lock_busy_15m=<n> ram_free_gb=<x> d_free_gb=<x> workers=<n> counter=<a>/<b>'.
Also emits 'ALERT ...' when ram_free < 8 GB, D: free < 40 GB, workers < 10, or census_done_60m == 0.
"""
import datetime
import json
import shutil
import sqlite3
import subprocess
import sys
import time

DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
MODE = 'D:/QM/strategy_farm/state/custom_history_containment_mode.json'
PS = 'D:/QM/reports/state/pipeline_state.json'
LOCK_LOG = 'D:/QM/strategy_farm/logs'
NORM = "replace(substr(updated_at,1,19),'T',' ')"
interval = int(sys.argv[1]) if len(sys.argv) > 1 else 600


def q(sql, *a):
    for _ in range(10):
        try:
            con = sqlite3.connect(DB, uri=True, timeout=30)
            con.row_factory = sqlite3.Row
            try:
                return con.execute(sql, a).fetchall()
            finally:
                con.close()
        except sqlite3.OperationalError as e:
            if 'locked' in str(e) or 'busy' in str(e):
                time.sleep(2)
                continue
            raise
    return []


def ago(minutes):
    return (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(minutes=minutes)).strftime('%Y-%m-%d %H:%M:%S')


def containment_enabled():
    try:
        return bool(json.load(open(MODE, encoding='utf-8-sig')).get('enabled'))
    except Exception:
        return None


def workers():
    try:
        out = subprocess.run(['powershell', '-NoProfile', '-Command',
                              "(Get-CimInstance Win32_Process -Filter \"Name like 'python%'\" | Where-Object { $_.CommandLine -match 'terminal_worker.py' } | Measure-Object).Count"],
                             capture_output=True, text=True, timeout=60, creationflags=0x08000000).stdout.strip()
        return int(out or 0)
    except Exception:
        return -1


def ram_free_gb():
    try:
        import psutil
        return round(psutil.virtual_memory().available / 2 ** 30, 1)
    except Exception:
        return -1


def lock_busy_15m():
    try:
        rows = q("select count(*) c from work_items where verdict like '%sqlite_busy%' and " + NORM + ">=?", ago(15))
        return rows[0]['c'] if rows else -1
    except Exception:
        return -1


last_enabled = containment_enabled()
next_summary = 0.0
while True:
    now = time.time()
    en = containment_enabled()
    if en is not None and en != last_enabled:
        print(f"CONTAINMENT_TRIP enabled={en} at {datetime.datetime.now(datetime.timezone.utc).strftime('%H:%M:%SZ')} (was {last_enabled})", flush=True)
        last_enabled = en
    if now >= next_summary:
        try:
            active = q("select count(*) c from work_items where status='active'")[0]['c']
            c10 = q("select count(*) c from work_items where phase like 'OPT_CENSUS%' and status='done' and " + NORM + ">=?", ago(10))[0]['c']
            c60 = q("select count(*) c from work_items where phase like 'OPT_CENSUS%' and status='done' and " + NORM + ">=?", ago(60))[0]['c']
            q02 = q("select count(*) c from work_items where phase='Q02' and status in ('done','failed') and " + NORM + ">=?", ago(10))[0]['c']
            try:
                ps = json.load(open(PS, encoding='utf-8-sig'))
                bg = (ps.get('operator_surface') or {}).get('book_guard', {})
                counter = f"{bg.get('qualified_pairs')}/{bg.get('minimum_qualified_pairs')}"
            except Exception:
                counter = '?/?'
            ram = ram_free_gb()
            dfree = round(shutil.disk_usage('D:/').free / 2 ** 30, 1)
            w = workers()
            stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%H:%MZ')
            print(f"FLEET {stamp} active={active} census_done_10m={c10} census_done_60m={c60} q02_done_10m={q02} ram_free_gb={ram} d_free_gb={dfree} workers={w} counter={counter} containment={en}", flush=True)
            alerts = []
            if ram != -1 and ram < 8: alerts.append(f'RAM_LOW {ram}GB')
            if dfree < 40: alerts.append(f'DISK_LOW {dfree}GB')
            if w != -1 and w < 10: alerts.append(f'WORKERS {w}<10')
            if c60 == 0: alerts.append('CENSUS_STALLED_60m')
            if alerts:
                print('ALERT ' + ' | '.join(alerts), flush=True)
        except Exception as e:
            print(f"MONITOR_ERROR {type(e).__name__}: {str(e)[:200]}", flush=True)
        next_summary = now + interval
    time.sleep(20)
