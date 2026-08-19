#!/usr/bin/env python3
"""Round 7 section 1: what a funded account is worth before it breaks, per sizing.

The question this closes
------------------------
Round 6 replaced "80 % per attempt" with "funded account within X days at no more than Y breaches".
That is better but stops one step early. After funding, the same -5 % daily and -10 % static limits
apply, but there is no deadline and no profit target - so the only quantity left is how long the
account survives and how much it pays out in the meantime.

    EV = payout_share x profit accumulated until the first breach - fee x expected attempts

Two things are computed rather than assumed
--------------------------------------------
1. **Survival is measured, not modelled geometrically.** A geometric lifetime from a per-window
   breach rate assumes windows are independent. They are not: the same book meets adjacent market
   regimes, and losses cluster. So each of the 50 window starts is run FORWARD through the real
   series until the account actually breaches, and the realised survival is recorded. The geometric
   figure is reported beside it, purely to show the size of the error.

2. **The payout convention is conservative.** Profit is withdrawn at every 60-day mark, so equity
   returns to the initial balance and the -10 % static cap always references that balance. Retained
   profit would build a cushion and lengthen survival; withdrawing removes it. If the account
   survives longer in reality, it survives longer than this number.

What is a parameter and why
----------------------------
The profit split is verified at **80 %** (docs/ops/evidence/2026-07-27_ftmo_phase2_and_funded_rules.md,
sourced from FTMO's own FAQ; 90 % under the Scaling Plan). The challenge **fee is not recorded
anywhere in this repository**, so it is not invented: EV is reported as a function of the fee, and
the break-even fee is stated. That is the number OWNER can check against the price list in a second.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import io
import json
import statistics
import sys
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import audit_intraday_sizing_sweep as sw  # noqa: E402
from audit_upper_bound import overlap_floor  # noqa: E402

ACCOUNT = sw.ACCOUNT
DAILY_CAP = sw.DAILY_CAP
TOTAL_CAP = sw.TOTAL_CAP
P1_TARGET = 0.10
P2_TARGET = 0.05
P1_DAYS = 60
P2_DAYS = 30
MIN_TRADING_DAYS = sw.MIN_TRADING_DAYS
PAYOUT_SHARE = 0.80          # verified 2026-07-27; 0.90 under the Scaling Plan
PAYOUT_EVERY_DAYS = 60
GRID = (0.44, 0.50, 0.60, 0.85, 1.00)
SCHEMA = "qm.audit-ev-funded-account/v1"


def phase(book: sw.Book, start: dt.date, mult: float, target: float, days: int,
          low_map: dict | None = None) -> tuple[str, dt.date]:
    equity = 0.0
    traded = 0
    end = start + dt.timedelta(days=days)
    last = start
    for day in book.days:
        if day < start:
            continue
        if day >= end:
            break
        last = day
        realised = book.close[day] * mult
        low = (low_map[day] * mult) if low_map is not None else min(0.0, realised)
        traded += 1
        if low <= -DAILY_CAP * ACCOUNT or equity + low <= -TOTAL_CAP * ACCOUNT:
            return "breach", day
        equity += realised
        if equity >= target * ACCOUNT and traded >= MIN_TRADING_DAYS:
            return "pass", day
    return "expired", last


def funded_run(book: sw.Book, start: dt.date, mult: float,
               low_map: dict | None = None) -> dict[str, Any]:
    """Run a funded account forward until it breaches. Profit withdrawn every 60 days."""
    equity = 0.0
    withdrawn = 0.0
    window_start = start
    for day in book.days:
        if day < start:
            continue
        realised = book.close[day] * mult
        low = (low_map[day] * mult) if low_map is not None else min(0.0, realised)
        if low <= -DAILY_CAP * ACCOUNT or equity + low <= -TOTAL_CAP * ACCOUNT:
            return {"breached": True, "days": (day - start).days,
                    "withdrawn": withdrawn, "profit_at_end": equity}
        equity += realised
        if (day - window_start).days >= PAYOUT_EVERY_DAYS:
            if equity > 0:
                withdrawn += equity
                equity = 0.0
            window_start = day
    return {"breached": False, "days": (book.days[-1] - start).days,
            "withdrawn": withdrawn + max(0.0, equity), "profit_at_end": equity}


def funding_probability(book: sw.Book, mult: float, low_map: dict | None = None) -> dict[str, Any]:
    """P(Phase 1 then Phase 2) over the window starts, chained as FTMO chains them."""
    funded = 0
    p1_only = 0
    for s in book.starts:
        o1, d1 = phase(book, s, mult, P1_TARGET, P1_DAYS, low_map)
        if o1 != "pass":
            continue
        p1_only += 1
        o2, _ = phase(book, d1 + dt.timedelta(days=1), mult, P2_TARGET, P2_DAYS, low_map)
        if o2 == "pass":
            funded += 1
    n = len(book.starts)
    return {"n_starts": n, "p1_pass": p1_only, "p1_rate": p1_only / n,
            "funded": funded, "funded_rate": funded / n,
            "expected_attempts": (n / funded) if funded else None}


def main() -> int:
    ap = argparse.ArgumentParser(description="Round 7 section 1")
    ap.add_argument("--json-out", type=Path)
    args = ap.parse_args()

    with contextlib.redirect_stdout(io.StringIO()):
        cb = sw.engine()
    book = sw.Book(cb)

    lows = overlap_floor(cb)
    rows = []
    for basis, low_map in (("close", None), ("overlap_floor", lows)):
     for m in GRID:
        fund = funding_probability(book, m, low_map)
        runs = [funded_run(book, s, m, low_map) for s in book.starts]
        surv = [r["days"] for r in runs]
        breached = [r for r in runs if r["breached"]]
        payouts = [PAYOUT_SHARE * r["withdrawn"] for r in runs]
        # Geometric comparison done RIGHT: the per-60-day-WINDOW breach rate, measured on the
        # window grid, is what a memoryless model would use. The share of forward runs that ever
        # breach is a different quantity entirely and would flatter the model.
        wins = [max(1, r["days"] // PAYOUT_EVERY_DAYS) for r in runs]
        b_rate = len(breached) / len(runs)
        win_breach = sum(1 for s in book.starts
                         if phase(book, s, m, 9.99, PAYOUT_EVERY_DAYS, low_map)[0] == "breach") / len(book.starts)
        geo_days = (PAYOUT_EVERY_DAYS / win_breach) if win_breach else float("inf")
        rows.append({
            "basis": basis,
            "multiplier": m,
            **fund,
            "breach_share": b_rate,
            "window_breach_rate": win_breach,
            "survival_days_median": statistics.median(surv),
            "survival_days_mean": statistics.mean(surv),
            "survival_days_p10": sorted(surv)[len(surv) // 10],
            "geometric_days_if_independent": geo_days,
            "payout_mean": statistics.mean(payouts),
            "payout_median": statistics.median(payouts),
            "windows_survived_mean": statistics.mean(wins),
        })

    out = {"schema_version": SCHEMA, "baseline_snapshot": "3472a5d2e1b5",
           "payout_share": PAYOUT_SHARE, "account": ACCOUNT,
           "fee_note": "challenge fee not recorded in-repo; EV reported as a function of the fee",
           "rows": rows}
    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(out, indent=1, sort_keys=True, default=str) + "\n",
                                 encoding="utf-8")

    print(f"{'basis':>14}{'mult':>6}{'P1':>7}{'funded':>8}{'E[att]':>8}{'breach':>8}"
          f"{'surv med d':>12}{'surv mean d':>12}{'geo d':>9}{'payout mean $':>15}")
    for r in rows:
        geo = r["geometric_days_if_independent"]
        print(f"{r['basis']:>14}{r['multiplier']:>6.2f}{r['p1_rate']:>7.0%}{r['funded_rate']:>8.0%}"
              f"{(r['expected_attempts'] or 0):>8.2f}{r['breach_share']:>8.0%}"
              f"{r['survival_days_median']:>12.0f}{r['survival_days_mean']:>12.0f}"
              f"{(geo if geo != float('inf') else 0):>9.0f}{r['payout_mean']:>15,.0f}")
    print()
    print("break-even fee per attempt (payout_mean / expected_attempts):")
    for r in rows:
        ea = r["expected_attempts"]
        be = (r["payout_mean"] / ea) if ea else None
        print(f"  {r['basis']:>14} {r['multiplier']:.2f}x  " + (f"{be:>12,.0f}" if be else "         n/a"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
