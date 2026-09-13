"""Poll the released PRESCREEN proof cell 88328353 (run_smoke marker-scope fix c2e7bfe8f2) until it reaches a verdict.
Detached (Start-Process); writes D:/QM/strategy_farm/logs/prescreen_proof2_0913.log. Read-only on the DB.
"""
import datetime as dt, sqlite3, time, json
from pathlib import Path
CELL = "88328353-41ac-5080-8ea1-e7481678c33b"
OUT = Path("D:/QM/strategy_farm/logs/prescreen_proof2_0913.log")
DB = "file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro"
def log(s):
    with OUT.open("a", encoding="utf-8") as fh:
        fh.write(dt.datetime.now(dt.timezone.utc).strftime("%H:%M:%SZ ") + s + "\n")
log("poller start for " + CELL)
deadline = time.time() + 4 * 3600
last = None
while time.time() < deadline:
    try:
        c = sqlite3.connect(DB, uri=True); c.row_factory = sqlite3.Row
        r = c.execute("select status,verdict,claimed_by,evidence_path,payload_json from work_items where id=?", (CELL,)).fetchone(); c.close()
        p = json.loads(r["payload_json"] or "{}")
        cur = (r["status"], r["verdict"], r["claimed_by"], p.get("verdict_taxonomy"), p.get("verdict_reason"), p.get("terminal"))
        if cur != last:
            log("state %s" % (cur,)); last = cur
        if r["status"] in ("done", "failed"):
            log("FINAL status=%s verdict=%s taxonomy=%s reason=%s evidence=%s" % (r["status"], r["verdict"], p.get("verdict_taxonomy"), p.get("verdict_reason"), r["evidence_path"]))
            break
    except Exception as e:
        log("poll error %r" % (e,))
    time.sleep(60)
log("poller end")
