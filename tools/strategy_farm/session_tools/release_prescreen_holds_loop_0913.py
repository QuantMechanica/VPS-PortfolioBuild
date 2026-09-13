"""Retry wrapper: re-run release_prescreen_holds_0913.py --all until no PRESCREEN_SCHEMA_FIX_PENDING hold remains.
The single-shot tool aborts on factory_mutation_lock_busy / GOVERNED_STATE_BACKUP_TIMEOUT contention with workers;
this loop just retries (each pass is idempotent and governed). Detached via Start-Process; log below.
"""
import datetime as dt, sqlite3, subprocess, time
from pathlib import Path
LOG = Path("D:/QM/strategy_farm/logs/prescreen_release_loop_0913.log")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
def remaining():
    c = sqlite3.connect(DB, uri=True)
    n = c.execute("select count(*) from work_item_holds where active=1 and hold_code='PRESCREEN_SCHEMA_FIX_PENDING'").fetchone()[0]
    c.close(); return n
def log(s):
    with LOG.open("a", encoding="utf-8") as fh: fh.write(dt.datetime.now(dt.timezone.utc).strftime("%H:%M:%SZ ") + s + "\n")
deadline = time.time() + 3 * 3600
for attempt in range(1, 200):
    n = remaining(); log(f"attempt {attempt} remaining {n}")
    if n == 0 or time.time() > deadline: break
    r = subprocess.run(["python", "-X", "utf8", "C:/QM/repo/tools/strategy_farm/session_tools/release_prescreen_holds_0913.py", "--all"],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", cwd="C:/QM/repo")
    tail = (r.stdout.strip().splitlines() or [""])[-1]
    log(f"rc {r.returncode} {tail[:120]} {(r.stderr.strip().splitlines() or [''])[-1][:160]}")
    time.sleep(30)
log(f"end remaining {remaining()}")
