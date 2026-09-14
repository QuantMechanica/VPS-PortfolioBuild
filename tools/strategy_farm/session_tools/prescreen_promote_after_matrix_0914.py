"""Detached: wait until the 41405 PRESCREEN matrix has no pending/active cells, then run the config_sweep promote DRY-RUN
(keep 0.70 / control 0.10 per OWNER-DEC-PRESCREEN-OHLC-20260911) and write the result to the log. Never applies."""
import datetime as dt, json, sqlite3, subprocess, time
from pathlib import Path
LOG = Path("D:/QM/strategy_farm/logs/prescreen_promote_dryrun_0914.log"); DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
def log(s):
    with LOG.open("a", encoding="utf-8") as fh: fh.write(dt.datetime.now(dt.timezone.utc).strftime("%H:%M:%SZ ") + s + "\n")
def open_cells():
    c = sqlite3.connect(DB, uri=True)
    n = c.execute("select count(*) from work_items where ea_id='QM5_41405' and phase='OPT_CENSUS' and json_extract(payload_json,'$.evidence_class')='PRESCREEN' and status in ('pending','active')").fetchone()[0]
    c.close(); return n
log("start"); deadline = time.time() + 3 * 3600
while time.time() < deadline:
    n = open_cells()
    if n == 0: break
    log(f"open cells {n}"); time.sleep(60)
cmd = ["python", "-X", "utf8", "C:/QM/repo/tools/strategy_farm/config_sweep.py", "promote", "--declaration",
       "C:/QM/repo/docs/ops/evidence/2026-09-12_config_sweep_qm5_41405_prescreen_dryrun_declaration.json",
       "--artifact", "D:/QM/strategy_farm/artifacts/opt_census/WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025", "--keep", "0.70", "--control", "0.10"]
r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd="C:/QM/repo")
log(f"promote dry-run rc={r.returncode}"); log((r.stdout or "").strip()[-1500:]); log((r.stderr or "").strip()[-600:]); log("end")
