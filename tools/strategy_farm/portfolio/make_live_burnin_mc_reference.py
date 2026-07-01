"""Build the SUM-basis 42-day MaxDD Monte-Carlo reference for the live burn-in.

Why
---
The live burn-in compares the realised live book drawdown (from ACCOUNT_EQUITY = the deployed
SUM of sleeves) against an MC-p95 DD threshold. The manifest's own ``mc_p95_max_drawdown_pct``
(~0.92%) is the WRONG reference for that comparison on two counts:
  1. Basis: it is the risk-parity WEIGHTED-AVERAGE book (weights sum to 1), not the deployed
     SUM-at-flat-risk book the live account actually runs.
  2. Window: it is over the FULL 8-year history, not the 42-CALENDAR-DAY burn-in window.

This tool builds the reference on the SAME basis as the live account: the SUM of the 13 sleeves
at the deployed flat per-trade risk (identical scaling to ``book_sizing.py``), as a
calendar-daily P&L series, then block-bootstraps a 42-calendar-day window to get the p95 MaxDD%.

Static artifact — regenerate only when the live book changes (new sleeve / re-sizing).
Deterministic (fixed seed). Scripts have no clock; pass --generated-at-utc from the caller.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import random
import sys
from collections import defaultdict
from pathlib import Path

_PORT = Path(__file__).resolve().parent
sys.path.insert(0, str(_PORT))
from commission import load_model  # type: ignore  # noqa: E402
from portfolio_common import load_streams, to_daily_pnl, DEFAULT_COMMON_DIR  # type: ignore  # noqa: E402
from prop_challenge_sim import _block_bootstrap, _percentile, DEFAULT_BLOCK_DAYS  # type: ignore  # noqa: E402

TESTER_DEFAULTS = Path(r"C:\QM\repo\framework\registry\tester_defaults.json")

# The 13 live DXZ sleeves — must match book_sizing.LIVE_SLEEVES and the D2-c manifest.
LIVE_SLEEVES = [
    (10440, "NDX.DWX"), (10513, "XAUUSD.DWX"), (10692, "NDX.DWX"), (10715, "USDJPY.DWX"),
    (10911, "GDAXI.DWX"), (10939, "GBPUSD.DWX"), (10940, "XAUUSD.DWX"), (11132, "SP500.DWX"),
    (11165, "AUDCAD.DWX"), (11421, "AUDUSD.DWX"), (11421, "EURUSD.DWX"),
    (12567, "XAUUSD.DWX"), (12567, "XNGUSD.DWX"),
]


def build_sum_calendar_daily(live_risk_pct: float, cap: float):
    """SUM-of-sleeves calendar-daily P&L at the deployed flat per-trade risk (book_sizing basis)."""
    td = json.load(open(TESTER_DEFAULTS))
    backtest_risk_pct = float(td["fixed_risk"]["amount"]) / float(td["initial_deposit"]) * 100.0
    factor = live_risk_pct / backtest_risk_pct

    model = load_model()
    streams = load_streams(DEFAULT_COMMON_DIR, candidates=LIVE_SLEEVES, commission_model=model)
    missing = [s for s in LIVE_SLEEVES if s not in streams]

    daily = defaultdict(float)
    for key in LIVE_SLEEVES:
        for day, val in to_daily_pnl(streams.get(key, [])).items():
            daily[day] += val * factor
    if not daily:
        raise ValueError("no sleeve streams found; cannot build reference")

    # Expand to a business-day calendar series (0 on non-trading days inside the span) so the
    # 42-day window matches the live calendar-daily EQUITY_SNAPSHOT granularity.
    start, end = min(daily), max(daily)
    series = []
    d = start
    one = dt.timedelta(days=1)
    while d <= end:
        if d.weekday() < 5:  # Mon-Fri
            series.append(daily.get(d, 0.0))
        d += one
    return series, factor, missing, (start, end)


def mc_p95_maxdd(series, window_days, block_days, runs, cap, seed):
    rng = random.Random(seed)
    maxdds = []
    for _ in range(runs):
        path = _block_bootstrap(series, window_days, block_days, rng)
        eq = peak = mdd = 0.0
        for v in path:
            eq += v
            peak = max(peak, eq)
            mdd = max(mdd, peak - eq)
        maxdds.append(mdd / cap * 100.0)
    maxdds.sort()
    return {
        "p50": round(_percentile(maxdds, 50.0), 6),
        "p95": round(_percentile(maxdds, 95.0), 6),
        "p99": round(_percentile(maxdds, 99.0), 6),
        "mean": round(sum(maxdds) / len(maxdds), 6),
    }


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--live-risk-pct", type=float, default=0.75,
                    help="deployed flat RISK_PERCENT per trade (book_sizing basis)")
    ap.add_argument("--cap", type=float, default=100_000.0)
    ap.add_argument("--window-days", type=int, default=42, help="burn-in window (calendar days)")
    ap.add_argument("--block-days", type=int, default=DEFAULT_BLOCK_DAYS)
    ap.add_argument("--runs", type=int, default=20000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--generated-at-utc", type=str, required=True)
    ap.add_argument("--out", type=Path,
                    default=Path(r"D:\QM\reports\portfolio\live_burnin\mc_reference_d2c_42d.json"))
    args = ap.parse_args(argv)

    series, factor, missing, span = build_sum_calendar_daily(args.live_risk_pct, args.cap)
    dist = mc_p95_maxdd(series, args.window_days, args.block_days, args.runs, args.cap, args.seed)

    artifact = {
        # pb._mc_drawdown_p95 reads block_bootstrap.max_drawdown_pct.p95 first.
        "block_bootstrap": {"max_drawdown_pct": dist},
        "max_drawdown_pct": {"p95": dist["p95"]},
        "_basis": "sum_of_sleeves_flat_risk_calendar_daily",
        "_provenance": {
            "generated_at_utc": args.generated_at_utc,
            "live_risk_pct_per_trade": args.live_risk_pct,
            "stream_scale_factor": round(factor, 6),
            "cap": args.cap,
            "window_days": args.window_days,
            "block_days": args.block_days,
            "runs": args.runs,
            "seed": args.seed,
            "n_sleeves": len(LIVE_SLEEVES),
            "missing_streams": [f"{e}:{s}" for e, s in missing],
            "stream_span": [span[0].isoformat(), span[1].isoformat()],
            "note": ("MaxDD p95 over a 42-calendar-day window on the DEPLOYED SUM-at-flat-risk "
                     "book. This is the correct DD reference for the live burn-in (the manifest "
                     "mc_p95 is weighted-avg + full-history). If the live per-trade risk differs "
                     "from live_risk_pct, p95 scales ~linearly."),
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as fh:
        json.dump(artifact, fh, indent=2, sort_keys=True)
        fh.write("\n")
    print(f"wrote {args.out}")
    print(f"stream factor x{factor:.3f}  span {span[0]}..{span[1]}  "
          f"{len(series)} business days  missing={missing}")
    print(f"42d MaxDD: p50={dist['p50']:.3f}%  p95={dist['p95']:.3f}%  "
          f"p99={dist['p99']:.3f}%  mean={dist['mean']:.3f}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
