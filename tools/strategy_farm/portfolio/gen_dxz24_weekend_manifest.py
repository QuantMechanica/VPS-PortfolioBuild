"""DXZ weekend book 23 -> 24 (2026-07-17, OWNER-mandated).

Changes vs the live 23-sleeve book:
  OUT  10476/USDCAD  (true neighborhood FAIL: ao_slow -10% -> DD ratio 1.589, OWNER removal)
  IN   13301/GDAXI   (Balke minute-range breakout DE40 — OWNER admission 2026-07-17)
  IN   13117/EURGBP  (EURGBP/AUDJPY cointegration basket — OWNER admission 2026-07-17,
                      neighborhood PASS complete, corr-to-book 0.036)

Stream basis = sealed bundle D:/QM/reports/portfolio/dxz24_weekend_frozen_20260717
(21 sleeves from the sweep-verified dxz23 frozen reference 2026-07-15 == live-book basis;
11165/AUDCAD + the 2 new sleeves from canonical full-history 2017-2025 reruns 2026-07-17,
validated against their factory Q08 baselines). NOT the volatile Common\\Files store —
13 of its 22 book streams have diverged since the freeze (requal waves / as-live runs).

Methodology identical to gen_dxz_23sleeve_manifest.py: capped inverse-vol on daily PnL,
CAP 1.0, TOTAL_RISK 9.75, commission model net-of-cost.
"""
import sys, json, math, csv, glob, os
sys.path.insert(0, r"C:/QM/repo")
from pathlib import Path
from tools.strategy_farm.portfolio.portfolio_common import load_streams, to_daily_pnl, align

STARTING_CAPITAL = 100_000.0; TOTAL_RISK = 9.75; CAP = 1.0
BUNDLE = Path(r"D:/QM/reports/portfolio/dxz24_weekend_frozen_20260717")
DRAFT23 = json.load(open(r"D:/QM/reports/portfolio/portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json"))
REG = r"C:/QM/repo/framework/registry/magic_numbers.csv"
OUT = r"D:/QM/reports/portfolio/portfolio_manifest_weekend_24sleeve_DRAFT_20260717.json"

REMOVE = (10476, "USDCAD.DWX")
NEW2 = [(13117, "EURGBP.DWX"), (13301, "GDAXI.DWX")]
EXPECTED_TRADES = {(13117, "EURGBP.DWX"): 208, (13301, "GDAXI.DWX"): 742, (11165, "AUDCAD.DWX"): 207}


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
    eq = []; c = 0
    for v in dp: c += v; eq.append(c)
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
    if not sets and d:  # basket sets carry the logical symbol in the filename, not the host
        sets = glob.glob(os.path.join(d, "sets", "*backtest.set"))
    return lbl, (ex5.replace("/", "\\") if ex5 else None), (sets[0].replace("/", "\\") if sets else None)


book23 = [(int(s["ea_id"]), s["symbol"]) for s in DRAFT23["sleeves"]]
assert REMOVE in book23, f"{REMOVE} not in book23"
book22 = [k for k in book23 if k != REMOVE]
book24 = book22 + NEW2

st = load_streams(BUNDLE, candidates=book24)
missing = [k for k in book24 if k not in st or not st[k]]
assert not missing, f"missing streams in bundle: {missing}"
for k, n in EXPECTED_TRADES.items():
    assert len(st[k]) == n, f"{k}: bundle stream has {len(st[k])} trades, expected {n}"
dl = {k: to_daily_pnl(v) for k, v in st.items()}

w24 = cap_iv(book24, dl); kpis24 = met(book24, w24, dl)
w22 = cap_iv(book22, dl); kpis22 = met(book22, w22, dl)

sleeves = []
for ea, sym in book24:
    lbl, ex5, setf = resolve(ea, sym)
    weight = round(w24.get((ea, sym), 0.0), 6)
    sleeves.append(dict(ea_id=ea, symbol=sym, ea_label=lbl, magic_number=magics.get((ea, sym)),
        weight=weight, risk_percent=weight, ex5_path=ex5, backtest_set=setf,
        new_candidate=(ea, sym) in NEW2, trades=len(st.get((ea, sym), [])),
        # ``weight`` is already the absolute allocated account-risk percentage.
        # The framework multiplies RISK_PERCENT by PORTFOLIO_WEIGHT, so applying
        # weight/TOTAL_RISK here would double-scale every sleeve.
        set_file_expectation={"ENV": "live", "RISK_FIXED": 0.0, "RISK_PERCENT": weight, "PORTFOLIO_WEIGHT": 1.0}))

manifest = dict(
    book="DXZ", status="DRAFT", n_sleeves=len(sleeves), starting_capital=STARTING_CAPITAL,
    total_risk_pct=TOTAL_RISK, weight_method="capped_inverse_vol_cap1.0_total9.75",
    risk_application_contract={"RISK_PERCENT": "absolute_allocated_sleeve_risk",
        "PORTFOLIO_WEIGHT": 1.0, "effective_risk_formula": "RISK_PERCENT * PORTFOLIO_WEIGHT",
        "relative_weights_are_analytics_only": True},
    generated_by="claude_weekend24_on_sealed_bundle_20260717",
    stream_basis={"bundle": str(BUNDLE), "bundle_manifest": str(BUNDLE / "bundle_manifest.json"),
        "seal": str(BUNDLE / "seal.sha256")},
    kpis=kpis24,
    kpis_comparison={
        "live23_reference": {"sharpe": 2.3478, "max_drawdown_pct": 3.3232,
            "source": "portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json"},
        "book22_after_10476_removal": kpis22,
        "book24_weekend": kpis24},
    changes={"removed": [{"ea_id": 10476, "symbol": "USDCAD.DWX",
            "reason": "true neighborhood FAIL (ao_slow -10% -> DD ratio 1.589 + edge decay), OWNER 2026-07-17"}],
        "added": [{"ea_id": 13117, "symbol": "EURGBP.DWX",
            "reason": "OWNER admission 2026-07-17; neighborhood PASS complete (max ratio 1.07x), Q09 net PF 1.52 / Sharpe 2.82 / corr 0.036"},
            {"ea_id": 13301, "symbol": "GDAXI.DWX",
            "reason": "OWNER admission 2026-07-17; neighborhood confirmed manually (max ratio 1.00x); Q09_PORTFOLIO FAIL_PORTFOLIO overridden by OWNER, re-run pending"}]},
    note=("Weekend 24-sleeve = live DXZ-23 minus 10476/USDCAD plus 13117/EURGBP-basket plus 13301/GDAXI. "
        "Weights = capped inverse-vol RECOMPUTED on the sealed dxz24 stream bundle "
        "(21x frozen 07-15 reference == live-book basis; AUDCAD + 2 new = canonical 2017-2025 reruns "
        "2026-07-17, validated vs factory Q08 baselines). DRAFT ONLY — deploy staging (presets/binaries/SHA) "
        "+ OWNER written approval remain before any T_Live change."),
    manual_approval_required=True, autotrading_action="NONE", deployment_action="STAGE_ONLY",
    new_candidates=[{"ea_id": e, "symbol": s} for e, s in NEW2],
    sleeves=sleeves)
json.dump(manifest, open(OUT, "w"), indent=1)
print(f"wrote {OUT}")
print(f"KPIs 24: Sharpe {kpis24['sharpe']}  MaxDD {kpis24['max_drawdown_pct']}%  net ${kpis24['total_net_of_cost_profit']:,.0f}  sleeves {kpis24['n_sleeves']}")
print(f"KPIs 22 (post-removal): Sharpe {kpis22['sharpe']}  MaxDD {kpis22['max_drawdown_pct']}%")
print(f"KPIs 23 live ref: Sharpe 2.3478  MaxDD 3.3232%")
missing_meta = [s for s in sleeves if not s['magic_number'] or not s['ex5_path']]
if missing_meta: print("WARN missing magic/ex5:", [(s['ea_id'], s['symbol']) for s in missing_meta])
print("new-candidate weights:", {f"{s['ea_id']}/{s['symbol']}": s['weight'] for s in sleeves if s['new_candidate']})
print("sum RISK_PERCENT:", round(sum(s['weight'] for s in sleeves), 4))
