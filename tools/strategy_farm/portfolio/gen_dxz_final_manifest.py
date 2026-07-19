"""DXZ final Sunday book (2026-07-19): 24er approved composition
minus 10715/USDJPY (neighborhood DD 1.906x breach) minus 10692/NDX (honest PBO 82.9%)
plus 13213/USDJPY Balke (manual typed-neighborhood PASS, corr 0.145)
plus 1567/EURUSD TD-reverse (full typed pipeline pass, corr 0.257).

Stream basis = sealed bundle dxz_final_20260719 (dxz24 frozen basis minus removals;
13213 + 1567 canonical full-history reruns validated by trade count).
Also prints the OWNER decision alternates (with/without XNG).
Methodology identical to gen_dxz24 (capped inverse-vol, CAP 1.0, TOTAL 9.75).
"""
import sys, json, math, csv, glob, os
sys.path.insert(0, r"C:/QM/repo")
from pathlib import Path
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl, align

STARTING_CAPITAL = 100_000.0; TOTAL_RISK = 9.75; CAP = 1.0
BUNDLE = Path(r"D:/QM/reports/portfolio/dxz_final_20260719")
D24 = json.load(open(r"D:/QM/reports/portfolio/portfolio_manifest_weekend_24sleeve_DRAFT_20260717.json"))
REG = r"C:/QM/repo/framework/registry/magic_numbers.csv"
OUT = r"D:/QM/reports/portfolio/portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json"

REMOVE = [(10715, "USDJPY.DWX"), (10692, "NDX.DWX")]
NEW2 = [(13213, "USDJPY.DWX"), (1567, "EURUSD.DWX")]
EXPECTED = {(13213, "USDJPY.DWX"): 1587, (1567, "EURUSD.DWX"): 86}


def pstd(v):
    n = len(v); return math.sqrt(sum((x - sum(v) / n) ** 2 for x in v) / n) if n else 0.0


def cap_iv(keys, daily):
    ak, dates, mat = align({k: daily[k] for k in keys if k in daily and daily[k]}); vols = {}
    for c, k in enumerate(ak): vols[k] = pstd([float(mat[r][c]) for r in range(len(dates))])
    inv = {k: (1.0 / vols[k] if vols[k] > 0 else 0) for k in ak}; tot = sum(inv.values()) or 1
    w = {k: (inv[k] / tot) * TOTAL_RISK for k in ak}; capped = set()
    for _ in range(50):
        over = [k for k in w if k not in capped and w[k] > CAP]
        if not over: break
        ex = 0
        for k in over: ex += w[k] - CAP; w[k] = CAP; capped.add(k)
        under = [k for k in w if k not in capped]; ti = sum(inv[k] for k in under)
        if ti <= 0: break
        for k in under: w[k] += ex * (inv[k] / ti)
    return w


def met(keys, w, daily):
    ak, dates, mat = align({k: daily[k] for k in keys if k in daily and daily[k]})
    dp = [sum(float(mat[r][c]) * w.get(k, 0) for c, k in enumerate(ak)) for r in range(len(dates))]
    eq = []; cum = 0
    for v in dp: cum += v; eq.append(cum)
    rets = [v / STARTING_CAPITAL * 100 for v in dp]; sd = pstd(rets)
    sh = (sum(rets) / len(rets) / sd) * math.sqrt(252) if sd > 0 else 0
    peak = md = 0
    for e in eq: peak = max(peak, e); md = max(md, peak - e)
    return dict(sharpe=round(sh, 4), max_drawdown_pct=round(md / STARTING_CAPITAL * 100, 4),
                total_net_of_cost_profit=round(eq[-1], 2), n_days=len(dates), n_sleeves=len(ak))


magics = {}
for r in csv.reader(open(REG)):
    if r and r[0].isdigit(): magics[(int(r[0]), r[3])] = int(r[4])


def resolve(ea, sym):
    d = glob.glob(rf"C:/QM/repo/framework/EAs/QM5_{ea}_*"); d = d[0] if d else None
    lbl = os.path.basename(d) if d else None
    ex5 = (glob.glob(os.path.join(d, "*.ex5")) or [None])[0] if d else None
    sets = glob.glob(os.path.join(d, "sets", f"*{sym}*backtest.set")) if d else []
    if not sets and d:
        sets = glob.glob(os.path.join(d, "sets", "*backtest.set"))
    return lbl, (ex5.replace("/", "\\") if ex5 else None), (sets[0].replace("/", "\\") if sets else None)


book24 = [(int(s["ea_id"]), s["symbol"]) for s in D24["sleeves"]]
bookF = [k for k in book24 if k not in REMOVE] + NEW2
st = load_streams(BUNDLE, candidates=bookF)
missing = [k for k in bookF if k not in st or not st[k]]
assert not missing, f"missing streams: {missing}"
for k, n in EXPECTED.items():
    assert len(st[k]) == n, f"{k}: {len(st[k])} != {n}"
dl = {k: to_daily_pnl(v) for k, v in st.items()}

wF = cap_iv(bookF, dl); kF = met(bookF, wF, dl)
# alternates for the OWNER decision table
KXNG = (12567, "XNGUSD.DWX")
alt = {}
for label, book in [("final_ohne_XNG", [k for k in bookF if k != KXNG]),
                    ("V1_nur_minus_10715", [k for k in book24 if k != (10715, "USDJPY.DWX")])]:
    wa = cap_iv(book, dl if all(k in dl for k in book) else {**dl})
    alt[label] = met(book, wa, dl)

sleeves = []
for ea, sym in bookF:
    lbl, ex5, setf = resolve(ea, sym)
    weight = round(wF.get((ea, sym), 0.0), 6)
    sleeves.append(dict(ea_id=ea, symbol=sym, ea_label=lbl, magic_number=magics.get((ea, sym)),
        weight=weight, risk_percent=weight, ex5_path=ex5, backtest_set=setf,
        new_candidate=(ea, sym) in NEW2, trades=len(st.get((ea, sym), [])),
        set_file_expectation={"ENV": "live", "RISK_FIXED": 0.0, "RISK_PERCENT": weight, "PORTFOLIO_WEIGHT": 1.0}))

manifest = dict(
    book="DXZ", status="DRAFT", n_sleeves=len(sleeves), starting_capital=STARTING_CAPITAL,
    total_risk_pct=TOTAL_RISK, weight_method="capped_inverse_vol_cap1.0_total9.75",
    risk_application_contract={"RISK_PERCENT": "absolute_allocated_sleeve_risk",
        "PORTFOLIO_WEIGHT": 1.0, "effective_risk_formula": "RISK_PERCENT * PORTFOLIO_WEIGHT",
        "relative_weights_are_analytics_only": True},
    generated_by="claude_sunday_final_on_sealed_bundle_20260719",
    stream_basis={"bundle": str(BUNDLE)},
    kpis=kF, kpis_alternates=alt,
    changes={"removed": [
        {"ea_id": 10715, "symbol": "USDJPY.DWX", "reason": "typed neighborhood breach: asian_end_hour -1 -> DD ratio 1.906"},
        {"ea_id": 10692, "symbol": "NDX.DWX", "reason": "honest PBO 82.9% on Q03 cohort (35 splits)"}],
        "added": [
        {"ea_id": 13213, "symbol": "USDJPY.DWX", "reason": "Balke #2: manual typed neighborhood PASS (3 valid, 0 breaches), corr 0.145, baseline PF 1.18/1587tr, decay negative"},
        {"ea_id": 1567, "symbol": "EURUSD.DWX", "reason": "full typed pipeline pass incl countdown +/-1 (weakest 1.445x in plateau); Q09 corr 0.257, standalone PF 1.60"}],
        "flags": ["11421/AUDUSD marginal (twin clean)", "11165/EURUSD marginal (sibling clean)",
                  "12567/XNGUSD decay-42d-review", "13117 runs-p 0.0488 boundary"]},
    note=("Sunday final: approved-24 minus 10715/10692 plus 13213/1567-EURUSD on the sealed "
        "dxz_final_20260719 bundle. DRAFT ONLY - OWNER written approval + chart session remain."),
    manual_approval_required=True, autotrading_action="NONE", deployment_action="STAGE_ONLY",
    new_candidates=[{"ea_id": e, "symbol": s} for e, s in NEW2],
    sleeves=sleeves)
json.dump(manifest, open(OUT, "w"), indent=1)
print(f"wrote {OUT}")
print(f"FINAL 24: Sharpe {kF['sharpe']}  MaxDD {kF['max_drawdown_pct']}%  n={kF['n_sleeves']}")
for l, k in alt.items():
    print(f"{l}: Sharpe {k['sharpe']}  MaxDD {k['max_drawdown_pct']}%  n={k['n_sleeves']}")
print("new weights:", {f"{s['ea_id']}/{s['symbol'][:10]}": s['weight'] for s in sleeves if s['new_candidate']})
print("sum:", round(sum(s['weight'] for s in sleeves), 4))
missing_meta = [s for s in sleeves if not s['magic_number'] or not s['ex5_path']]
if missing_meta: print("WARN missing magic/ex5:", [(s['ea_id'], s['symbol']) for s in missing_meta])
