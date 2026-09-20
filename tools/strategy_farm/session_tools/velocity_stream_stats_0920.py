import json, glob, os, statistics as st, math, datetime as dt
base = "D:/QM/reports/book_evolution/2026-W38/ftmo/snapshot_r2/streams/QM/q08_trades"
RISK = 1000.0  # RISK_FIXED per trade in the factory
rows = []
for f in sorted(glob.glob(base + "/*.jsonl")):
    name = os.path.basename(f)[:-6]
    tr = [json.loads(l) for l in open(f, encoding="utf-8") if l.strip()]
    tr = [t for t in tr if t.get("event") == "TRADE_CLOSED"]
    if not tr: continue
    t0 = min(t["entry_time"] for t in tr); t1 = max(t["time"] for t in tr)
    d0 = dt.datetime.utcfromtimestamp(t0).date(); d1 = dt.datetime.utcfromtimestamp(t1).date()
    # business days in span
    bd = sum(1 for i in range((d1 - d0).days + 1) if (d0 + dt.timedelta(i)).weekday() < 5)
    nets = [t["net"] for t in tr]
    R = [n / RISK for n in nets]
    holds = [(t["time"] - t["entry_time"]) / 3600 for t in tr]
    overnight = sum(1 for t in tr if dt.datetime.utcfromtimestamp(t["entry_time"]).date() != dt.datetime.utcfromtimestamp(t["time"]).date()) / len(tr)
    # daily net series
    daily = {}
    for t in tr:
        d = dt.datetime.utcfromtimestamp(t["time"]).date()
        daily[d] = daily.get(d, 0.0) + t["net"]
    dvals = list(daily.values())
    days_active = len(daily)
    density = len(tr) / bd
    eR = st.mean(R); sdR = st.pstdev(R)
    drift_bd_1pct = density * eR * 1000.0  # USD/bd at 1% of 100k
    sd_daily = st.pstdev(dvals) if len(dvals) > 1 else float("nan")
    worst_day = min(dvals)
    rows.append(dict(stream=name, n=len(tr), bd=bd, density=density, eR=eR, sdR=sdR, t=eR / (sdR / math.sqrt(len(tr))) if sdR else float("nan"),
                     hold_med=st.median(holds), overnight=overnight, drift_bd_1pct=drift_bd_1pct, active_days_pct=days_active / bd,
                     worst_day_R=worst_day / RISK, start=str(d0), end=str(d1)))
rows.sort(key=lambda r: -r["drift_bd_1pct"])
print(f'{"stream":<18}{"n":>6}{"dens/bd":>9}{"E[R]":>8}{"t":>7}{"hold_h":>8}{"ovn%":>6}{"USD/bd@1%":>11}{"act%":>6}{"worstD_R":>9}  span')
for r in rows:
    print(f'{r["stream"]:<18}{r["n"]:>6}{r["density"]:>9.3f}{r["eR"]:>8.3f}{r["t"]:>7.2f}{r["hold_med"]:>8.1f}{r["overnight"]*100:>6.0f}{r["drift_bd_1pct"]:>11.1f}{r["active_days_pct"]*100:>6.0f}{r["worst_day_R"]:>9.2f}  {r["start"]}..{r["end"]}')
json.dump(rows, open("C:/Users/ADMINI~1/AppData/Local/Temp/1/claude/C--QM-repo/5a620033-f26a-41ac-a71b-5f2f4809a4dc/scratchpad/velocity_stats.json", "w"), indent=1)
