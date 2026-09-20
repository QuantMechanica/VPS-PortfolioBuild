import sqlite3, json, re, os, datetime as dt
from collections import defaultdict
con = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True)
con.row_factory = sqlite3.Row
tfs = {"M1","M2","M3","M5","M10","M15","M30","H1"}
def bdays(a, b):
    d0 = dt.datetime.strptime(a, "%Y.%m.%d").date(); d1 = dt.datetime.strptime(b, "%Y.%m.%d").date()
    n = (d1 - d0).days + 1
    return sum(1 for i in range(n) if (d0 + dt.timedelta(i)).weekday() < 5)
# max phase per (ea,symbol,tf)
def prank(p):
    m = re.match(r"Q(\d+)", p or ""); return int(m.group(1)) if m else -1
maxphase = defaultdict(int); pending = defaultdict(list)
for r in con.execute("SELECT ea_id, symbol, setfile_path, phase, verdict, status FROM work_items WHERE kind='backtest'"):
    m = re.search(r"_(M1|M2|M3|M5|M10|M15|M30|H1|H4|D1|W1)_", r["setfile_path"] or ""); tf = m.group(1) if m else "?"
    k = (r["ea_id"], r["symbol"], tf)
    v = r["verdict"] or ""
    if v.startswith("PASS") or v in ("MEASURED","KEEP_INCUMBENT","ADMIT"):
        maxphase[k] = max(maxphase[k], prank(r["phase"]))
    if r["status"] in ("pending","active"): pending[k].append(f'{r["phase"]}:{r["status"]}')
rows = con.execute("SELECT id, ea_id, symbol, setfile_path, verdict, evidence_path, updated_at FROM work_items WHERE kind='backtest' AND phase='Q02' AND verdict LIKE 'PASS%' ORDER BY updated_at DESC").fetchall()
seen = set(); out = []
for r in rows:
    m = re.search(r"_(M1|M2|M3|M5|M10|M15|M30|H1|H4|D1|W1)_", r["setfile_path"] or ""); tf = m.group(1) if m else "?"
    if tf not in tfs: continue
    k = (r["ea_id"], r["symbol"], tf)
    if k in seen: continue
    ep = r["evidence_path"] or ""
    sp = ep if ep.endswith("summary.json") else os.path.join(os.path.dirname(ep), "summary.json")
    if not os.path.exists(sp): continue
    try:
        s = json.load(open(sp, encoding="utf-8"))
    except Exception: continue
    runs = s.get("runs") or []
    if not runs: continue
    run = runs[0]
    n = run.get("total_trades") or 0; net = run.get("net_profit") or 0.0; dd = run.get("drawdown") or 0.0
    fd = run.get("from_date") or s.get("from_date"); td = run.get("to_date") or s.get("to_date")
    if not (fd and td and n): continue
    try: bd = bdays(fd, td)
    except Exception: continue
    seen.add(k)
    out.append(dict(ea=r["ea_id"], sym=r["symbol"], tf=tf, n=n, dens=n/bd, eR=net/(n*1000.0), R_bd=net/(bd*1000.0), pf=run.get("profit_factor"), dd_R=dd/1000.0, bd=bd, maxQ=maxphase.get(k, -1), pend=",".join(sorted(set(pending.get(k, []))))[:40], wid=r["id"][:8], upd=r["updated_at"][:10]))
out.sort(key=lambda x: -x["R_bd"])
print(f"screened {len(out)} intraday Q02-PASS pairs")
print(f'{"ea":<10}{"sym":<12}{"tf":<4}{"n":>6}{"dens":>7}{"E[R]":>7}{"R/bd":>7}{"PF":>6}{"DD_R":>6}{"maxQ":>5}  pending / wid / upd')
for o in out[:60]:
    print(f'{o["ea"]:<10}{o["sym"]:<12}{o["tf"]:<4}{o["n"]:>6}{o["dens"]:>7.2f}{o["eR"]:>7.3f}{o["R_bd"]:>7.3f}{o["pf"] if o["pf"] is not None else 0:>6.2f}{o["dd_R"]:>6.1f}{o["maxQ"]:>5}  {o["pend"]} / {o["wid"]} / {o["upd"]}')
json.dump(out, open("C:/Users/ADMINI~1/AppData/Local/Temp/1/claude/C--QM-repo/5a620033-f26a-41ac-a71b-5f2f4809a4dc/scratchpad/q02_velocity_screen.json","w"), indent=1)
