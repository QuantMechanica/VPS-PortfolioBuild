import sqlite3, json, subprocess, sys, time, datetime as dt
from pathlib import Path

REPO = Path("C:/QM/repo")
EVID = REPO / "docs/ops/evidence/2026-09-16_q08_amend_v3/repair_fresh_enqueue"
MAP = json.loads((EVID / "old_to_new_map.json").read_text())
BY_NEW = {m["new_id"]: m for m in MAP}

def row_state(nid):
    conn = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True, timeout=60)
    conn.row_factory = sqlite3.Row
    r = conn.execute("SELECT id,status,verdict,claimed_by,updated_at,evidence_path FROM work_items WHERE id=?", (nid,)).fetchone()
    conn.close()
    return dict(r) if r else None

def pid_map():
    try:
        p = subprocess.run([sys.executable, str(REPO/"tools/strategy_farm/farmctl.py"), "--root", r"D:\QM\strategy_farm", "mt5-slots"],
                           capture_output=True, text=True, timeout=120)
        d = json.loads(p.stdout)
        m = {}
        for proc in d.get("processes", []):
            wi = proc.get("work_item_id")
            if wi:
                m[wi] = {"terminal": proc.get("terminal"), "pid": proc.get("pid")}
        return m
    except Exception as e:
        return {"_error": str(e)}

def run_summary_terminal(nid, ea):
    # Recover terminal from the newest pipeline run summary for this work item's EA/Q08
    base = Path(r"D:\QM\reports\pipeline") / ea / "Q08"
    best = None
    if base.exists():
        for summ in base.rglob("summary.json"):
            try:
                d = json.loads(summ.read_text(encoding="utf-8", errors="ignore"))
            except Exception:
                continue
            if (d.get("ea_id") == ea or d.get("ea_label") == ea) and d.get("terminal"):
                ts = d.get("timestamp_utc") or ""
                if best is None or ts > best[0]:
                    best = (ts, d.get("terminal"), summ)
    return best[1] if best else None

claims = {}
deadline = time.time() + 13*60
interval = 10
snapshots = []
while time.time() < deadline:
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    pm = pid_map()
    states = {}
    for nid in BY_NEW:
        r = row_state(nid)
        states[nid] = r
        if nid in claims:
            continue
        if r and r["status"] == "active" and r["claimed_by"]:
            claims[nid] = {"claimed_at_utc": now, "terminal": r["claimed_by"], "pid": (pm.get(nid) or {}).get("pid"),
                           "captured": "live-active"}
        elif r and r["status"] in ("done", "failed"):
            # completed before we saw it active: recover terminal from run summary
            term = run_summary_terminal(nid, BY_NEW[nid]["ea_id"])
            claims[nid] = {"claimed_at_utc": now, "terminal": term, "pid": (pm.get(nid) or {}).get("pid"),
                           "captured": f"post-completion(run_summary) status={r['status']} verdict={r['verdict']}"}
    snapshots.append({"at_utc": now, "states": states})
    done = sum(1 for nid in BY_NEW if states.get(nid) and states[nid]["status"] in ("active",))
    fin = sum(1 for nid in BY_NEW if states.get(nid) and states[nid]["status"] in ("done", "failed"))
    print(f"[{now[:19]}] active={done} finished={fin} claims={len(claims)}/8 -> { {k[:8]:(v['terminal']) for k,v in claims.items()} }", flush=True)
    if len(claims) >= 8:
        print("ALL 8 CLAIMS CAPTURED", flush=True)
        break
    time.sleep(interval)

# final states
final = {nid: row_state(nid) for nid in BY_NEW}
result = {"poll_ended_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "claims_count": len(claims),
          "claims": claims, "final_states": final}
(EVID / "claims_result.json").write_text(json.dumps(result, indent=2))
(EVID / "claims_snapshots.json").write_text(json.dumps(snapshots, indent=2))
print("WROTE claims_result.json n=", len(claims))
for nid, c in claims.items():
    print(" ", nid[:8], BY_NEW[nid]["ea_id"], "terminal", c["terminal"], "pid", c["pid"], c["captured"])
