"""Q08.8 — Edge Decay: rolling 12-month PF decline < 40% over full history.

Walks the trade stream in monthly buckets, computes a rolling 12-month
profit factor, and measures the relative decline from the FIRST trailing
12-month window to the LAST. If the edge has decayed more than 40%, the
EA fails. Catches dying strategies (PF 2.5 in 2017 → 1.1 in 2025).
"""

from __future__ import annotations

import math
from collections import defaultdict

from .common import make_result, profit_factor, trade_timestamp

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


# DL-070 (OWNER 2026-06-05): swing/low-freq track. High-freq (>=200 trades) keeps the
# precise rolling-12mo edge-decay. Low-freq (e.g. ~10 trades/yr swing -> ~90 over the
# 9-year window) cannot fill 12-month buckets, so instead of failing on the 200-trade
# floor it uses a first-half vs second-half PF comparison. Below SWING_FLOOR trades
# nothing is assessable -> INVALID. The 40% decline threshold is unchanged.
SWING_FLOOR = 30


def run(trades: list[dict], **_) -> dict:
    if len(trades) < SWING_FLOOR:
        return make_result(GATE_NAME, "INVALID",
                           value=len(trades), threshold=SWING_FLOOR,
                           detail=f"insufficient_trade_count:got={len(trades)}:need>={SWING_FLOOR}")

    monthly: dict[int, list[float]] = defaultdict(list)
    for t in trades:
        ts = trade_timestamp(t)
        if ts is None:
            continue
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        monthly[_yyyymm(ts)].append(net)

    months = sorted(monthly.keys())

    if len(trades) >= 200:
        if len(months) < 24:  # high-freq: need 2y for rolling-12mo windows
            return make_result(GATE_NAME, "INVALID",
                               value=len(months), threshold=24,
                               detail=f"insufficient_month_coverage:got={len(months)}:need>=24")
        pf_first = _trailing_12mo_pf(monthly, months[11])
        pf_last = _trailing_12mo_pf(monthly, months[-1])
        decay_mode = "rolling_12mo"
        window_meta = {"first_window_end_yyyymm": months[11], "last_window_end_yyyymm": months[-1]}
    else:
        # DL-070 swing: first-half vs second-half of the active months.
        if len(months) < 12:  # need >=6 months per half for a decay signal
            return make_result(GATE_NAME, "INVALID",
                               value=len(months), threshold=12,
                               detail=f"insufficient_month_coverage_swing:got={len(months)}:need>=12")
        mid = len(months) // 2
        first_pl = [pl for m in months[:mid] for pl in monthly[m]]
        last_pl = [pl for m in months[mid:] for pl in monthly[m]]
        pf_first = profit_factor(first_pl)
        pf_last = profit_factor(last_pl)
        decay_mode = "swing_half_vs_half"
        window_meta = {"first_half_yyyymm": [months[0], months[mid - 1]],
                       "second_half_yyyymm": [months[mid], months[-1]]}

    if pf_first is None or pf_first <= 0 or math.isinf(pf_first):
        return make_result(GATE_NAME, "INVALID",
                           value=pf_first, threshold=None,
                           detail=f"first_window_pf_invalid:{pf_first}:mode={decay_mode}")

    if pf_last is None:
        return make_result(GATE_NAME, "FAIL",
                           value=None, threshold=MAX_DECLINE_PCT,
                           detail=f"last_window_has_no_losses_no_wins:mode={decay_mode}",
                           evidence={"pf_first": pf_first, "decay_mode": decay_mode})

    decline_pct = (pf_first - pf_last) / pf_first * 100.0
    status = "PASS" if decline_pct < MAX_DECLINE_PCT else "FAIL"
    return make_result(GATE_NAME, status,
                       value=round(decline_pct, 2), threshold=MAX_DECLINE_PCT,
                       detail=f"pf_decline_first={pf_first:.3f}_last={pf_last:.3f}_pct={decline_pct:.1f}_mode={decay_mode}",
                       evidence={"pf_first": round(pf_first, 4),
                                 "pf_last": round(pf_last, 4),
                                 "decay_mode": decay_mode,
                                 "n_trades": len(trades),
                                 "months_covered": len(months),
                                 **window_meta})
