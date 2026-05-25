"""Q08.8 — Edge Decay: rolling 12-month PF decline < 40% over full history.

Walks the trade stream in monthly buckets, computes a rolling 12-month
profit factor, and measures the relative decline from the FIRST trailing
12-month window to the LAST. If the edge has decayed more than 40%, the
EA fails. Catches dying strategies (PF 2.5 in 2017 → 1.1 in 2025).
"""

from __future__ import annotations

import math
from collections import defaultdict

from .common import make_result, parse_ts, profit_factor

GATE_NAME = "8.8_edge_decay"
MAX_DECLINE_PCT = 40.0


def _yyyymm(ts):
    return ts.year * 100 + ts.month


def _trailing_12mo_pf(monthly_pl: dict[int, list[float]], current_yyyymm: int) -> float | None:
    # Collect all per-trade P&L in the trailing 12 months
    cy, cm = divmod(current_yyyymm, 100)
    window: list[float] = []
    for back in range(12):
        # Walk months backwards
        y, m = cy, cm - back
        while m <= 0:
            m += 12
            y -= 1
        window.extend(monthly_pl.get(y * 100 + m, []))
    return profit_factor(window)


def run(trades: list[dict], **_) -> dict:
    if len(trades) < 200:
        return make_result(GATE_NAME, "INVALID",
                           value=len(trades), threshold=200,
                           detail=f"insufficient_trade_count:got={len(trades)}:need>=200")

    monthly: dict[int, list[float]] = defaultdict(list)
    for t in trades:
        ts = parse_ts(t.get("ts_utc", t.get("close_ts", "")))
        if ts is None:
            continue
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        monthly[_yyyymm(ts)].append(net)

    months = sorted(monthly.keys())
    if len(months) < 24:  # need at least 2 years of trade history
        return make_result(GATE_NAME, "INVALID",
                           value=len(months), threshold=24,
                           detail=f"insufficient_month_coverage:got={len(months)}:need>=24")

    # First trailing-12mo and last trailing-12mo windows
    first_window_end = months[11]  # 12th month from start
    last_window_end = months[-1]

    pf_first = _trailing_12mo_pf(monthly, first_window_end)
    pf_last = _trailing_12mo_pf(monthly, last_window_end)

    if pf_first is None or pf_first <= 0 or math.isinf(pf_first):
        return make_result(GATE_NAME, "INVALID",
                           value=pf_first, threshold=None,
                           detail=f"first_window_pf_invalid:{pf_first}")

    if pf_last is None:
        return make_result(GATE_NAME, "FAIL",
                           value=None, threshold=MAX_DECLINE_PCT,
                           detail="last_window_has_no_losses_no_wins",
                           evidence={"pf_first": pf_first})

    decline_pct = (pf_first - pf_last) / pf_first * 100.0
    status = "PASS" if decline_pct < MAX_DECLINE_PCT else "FAIL"
    return make_result(GATE_NAME, status,
                       value=round(decline_pct, 2), threshold=MAX_DECLINE_PCT,
                       detail=f"pf_decline_first={pf_first:.3f}_last={pf_last:.3f}_pct={decline_pct:.1f}",
                       evidence={"pf_first": round(pf_first, 4),
                                 "pf_last": round(pf_last, 4),
                                 "first_window_end_yyyymm": first_window_end,
                                 "last_window_end_yyyymm": last_window_end,
                                 "months_covered": len(months)})
