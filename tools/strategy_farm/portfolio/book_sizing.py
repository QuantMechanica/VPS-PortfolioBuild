"""Book sizing analysis at the REAL deployed per-trade risk basis.

The portfolio manifest KPIs (e.g. manifest_d2c MaxDD 0.51%) are computed on a
risk-parity *weighted-average* book (weights sum to 1). The LIVE deployment is
different: each sleeve runs INDEPENDENTLY at a flat RISK_PERCENT of the full
account, so the deployed book is the SUM of the sleeves, not a weighted average.

This tool recomputes the book on the real summed-at-flat-risk basis and reports:
  - realized return / 8yr MaxDD / monthly VaR at the live per-trade risk
  - DXZ DarwinIA scaling: whether the raw monthly VaR is high enough that DXZ's
    own normalization (capped by D-Leverage) fills the ~6.5% monthly VaR target
  - FTMO 2-step MC pass% across per-trade risk levels (reuses prop_challenge_sim)

Backtest streams are at RISK_FIXED (framework/registry/tester_defaults.json,
fixed_risk.amount on initial_deposit) -> scaled to the live RISK_PERCENT.

Usage:
  python book_sizing.py                       # 13 live sleeves @ 0.75%/trade
  python book_sizing.py --live-risk-pct 1.0   # what-if at a different sizing
"""
from __future__ import annotations
import argparse, json, sys
from collections import defaultdict
from pathlib import Path

_PORT = Path(__file__).resolve().parent
sys.path.insert(0, str(_PORT))
from commission import load_model  # type: ignore  # noqa: E402
from portfolio_common import load_streams, to_daily_pnl, DEFAULT_COMMON_DIR  # type: ignore  # noqa: E402
from prop_challenge_sim import (  # type: ignore  # noqa: E402
    get_preset, simulate, DEFAULT_PHASE_HORIZON_DAYS, DEFAULT_BLOCK_DAYS,
)

TESTER_DEFAULTS = Path(r"C:\QM\repo\framework\registry\tester_defaults.json")
DXZ_VAR_TARGET = 6.5            # % monthly VaR (DarwinIA normalization target)
DLEV_CAP_SLOW = 9.75           # D-Leverage cap for >60min holds

# The 13 live DXZ sleeves (T_Live\MT5_Base\MQL5\Presets\slot0..12, all 0.75%/trade).
LIVE_SLEEVES = [
    (10440, "NDX.DWX"), (10513, "XAUUSD.DWX"), (10692, "NDX.DWX"), (10715, "USDJPY.DWX"),
    (10911, "GDAXI.DWX"), (10939, "GBPUSD.DWX"), (10940, "XAUUSD.DWX"), (11132, "SP500.DWX"),
    (11165, "AUDCAD.DWX"), (11421, "AUDUSD.DWX"), (11421, "EURUSD.DWX"),
    (12567, "XAUUSD.DWX"), (12567, "XNGUSD.DWX"),
]


def _pctile(xs, p):
    if not xs:
        return 0.0
    i = (p / 100.0) * (len(xs) - 1)
    lo = int(i); hi = min(lo + 1, len(xs) - 1)
    return xs[lo] + (xs[hi] - xs[lo]) * (i - lo)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--live-risk-pct", type=float, default=0.75, help="deployed RISK_PERCENT per trade")
    ap.add_argument("--cap", type=float, default=100_000.0, help="account capital")
    ap.add_argument("--runs", type=int, default=400)
    args = ap.parse_args(argv)
    cap = args.cap

    td = json.load(open(TESTER_DEFAULTS))
    backtest_risk_usd = float(td["fixed_risk"]["amount"])
    backtest_risk_pct = backtest_risk_usd / float(td["initial_deposit"]) * 100.0
    factor = args.live_risk_pct / backtest_risk_pct
    print(f"backtest RISK_FIXED = ${backtest_risk_usd:.0f} = {backtest_risk_pct:.2f}%/trade; "
          f"live = {args.live_risk_pct:.2f}%/trade => stream factor x{factor:.3f}")

    model = load_model()
    streams = load_streams(DEFAULT_COMMON_DIR, candidates=LIVE_SLEEVES, commission_model=model)
    missing = [s for s in LIVE_SLEEVES if s not in streams]
    if missing:
        print("MISSING streams:", missing)

    daily = defaultdict(float)
    for key in LIVE_SLEEVES:
        for day, val in to_daily_pnl(streams.get(key, [])).items():
            daily[day] += val * factor
    dates = sorted(daily)
    series = [daily[d] for d in dates]
    total = sum(series)
    years = (dates[-1] - dates[0]).days / 365.25

    eq = peak = mdd = 0.0
    for v in series:
        eq += v; peak = max(peak, eq); mdd = max(mdd, peak - eq)
    mdd_pct = mdd / cap * 100.0
    monthly = defaultdict(float)
    for d, v in daily.items():
        monthly[(d.year, d.month)] += v
    mvals = sorted(monthly.values())
    mvar = abs(min(_pctile(mvals, 5.0), 0.0)) / cap * 100.0
    ann = total / cap * 100.0 / years

    print(f"\n=== LIVE BOOK @ {args.live_risk_pct}%/trade flat, {len(LIVE_SLEEVES)} sleeves SUMMED ===")
    print(f"  span {dates[0]}..{dates[-1]} ({years:.2f}yr), {len(series)} trade days, {len(mvals)} months")
    print(f"  return            : {ann:.2f}%/yr  (${total:,.0f} on {cap:,.0f})")
    print(f"  MaxDD (8yr)       : {mdd_pct:.2f}%")
    print(f"  monthly VaR(95%)  : {mvar:.3f}%   MaxDD/VaR {mdd_pct/mvar:.1f}x")

    s_dxz = DXZ_VAR_TARGET / mvar
    dlev_fill = min(mvar * DLEV_CAP_SLOW, DXZ_VAR_TARGET)
    print(f"\n=== DXZ DarwinIA (target {DXZ_VAR_TARGET}% monthly VaR) ===")
    print(f"  raw monthly VaR now    : {mvar:.2f}%  ({mvar/DXZ_VAR_TARGET*100:.0f}% of target)")
    print(f"  DXZ scale to target    : {s_dxz:.1f}x  (D-Leverage cap {DLEV_CAP_SLOW}x, >60min holds)")
    print(f"  Darwin fills (within cap): {dlev_fill:.2f}% VaR = {dlev_fill/DXZ_VAR_TARGET*100:.0f}% of target"
          f"  => {'FILLED (no need to raise raw risk)' if s_dxz <= DLEV_CAP_SLOW else 'CAP-LIMITED (raise raw risk)'}")
    print(f"  implied Darwin return  : ~{ann*min(s_dxz,DLEV_CAP_SLOW):.0f}%/yr  (raw {ann:.0f}%/yr x DXZ scale)")
    print(f"  if WE raised to fill    : {args.live_risk_pct*s_dxz:.2f}%/trade -> raw MaxDD {mdd_pct*s_dxz:.0f}%"
          f" (same Darwin, more raw DD => not worth it when already filled)")

    preset = get_preset("FTMO_2STEP")
    print(f"\n=== FTMO 2-step MC (block-bootstrap {args.runs} runs) ===")
    print(f"  {'risk%/tr':>9} {'~MaxDD%':>8} {'~ret/yr':>8} {'pass%':>7} {'dailyBr%':>9} {'maxLossBr%':>11} {'days50':>7}")
    rows = []
    for s in [1, 1.5, 2, 2.5, 3, 4]:
        scaled = [v * s for v in series]
        sim = simulate(scaled, preset, runs=args.runs, block_days=DEFAULT_BLOCK_DAYS, seed=1,
                       starting_capital=cap, phase_horizon_days=DEFAULT_PHASE_HORIZON_DAYS)
        b = sim["block_bootstrap"]
        r = dict(risk=args.live_risk_pct * s, mdd=mdd_pct * s, ret=ann * s,
                 p=b["pass_probability_pct"], db=b["daily_loss_breach_probability_pct"],
                 ml=b["max_loss_breach_probability_pct"], d=b["days_to_pass"]["p50"])
        rows.append(r)
        print(f"  {r['risk']:>9.2f} {r['mdd']:>8.1f} {r['ret']:>8.1f} {r['p']:>7.1f} {r['db']:>9.1f} {r['ml']:>11.1f} {r['d']:>7.0f}")
    ok = [r for r in rows if r["db"] <= 5 and r["ml"] <= 5]
    best = max(ok, key=lambda r: r["p"]) if ok else max(rows, key=lambda r: r["p"])
    print(f"\n  FTMO best (breach<=5%): {best['risk']:.2f}%/trade  pass={best['p']:.1f}%  "
          f"MaxDD~{best['mdd']:.1f}%  ret~{best['ret']:.1f}%/yr  days~{best['d']:.0f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
