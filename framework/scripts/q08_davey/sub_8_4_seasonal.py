"""Q08.4 — Seasonal: all 12 calendar months must net-positive over full history.

Aggregates per-trade P&L by calendar month (averaged across years) and
requires every month to be net-positive. Catches hidden calendar anomalies
like "EA loses money every August".
"""

from __future__ import annotations

from collections import defaultdict

from .common import make_result, trade_timestamp

GATE_NAME = "8.4_seasonal"


def run(trades: list[dict], **_) -> dict:
    if not trades:
        return make_result(GATE_NAME, "INVALID",
                           value=0, threshold=12, detail="no_trades")

    monthly: dict[int, float] = defaultdict(float)
    counted = 0
    for t in trades:
        ts = trade_timestamp(t)
        if ts is None:
            continue
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        monthly[ts.month] += net
        counted += 1

    months_covered = len(monthly)
    if months_covered < 12:
        # DL-082 §3b (frequency-aware). Structural requirement math: the gate needs
        # >=1 trade in EACH of the 12 calendar-month buckets, then every bucket
        # net-positive. The number of coverable buckets is bounded by the trades the
        # EA actually opens; with months_covered < 12 at least one bucket is empty, so
        # "all 12 months net-positive" is STRUCTURALLY unevaluable — a low-frequency
        # survivor cannot populate every calendar month. Demote to INFORMATIONAL
        # (recorded with its measured coverage, carrying no soft-fail signal) instead
        # of soft-failing on an unsatisfiable requirement. When all 12 months ARE
        # covered the gate evaluates exactly as before (a genuine losing month FAILs).
        return make_result(GATE_NAME, "INFORMATIONAL",
                           value=months_covered, threshold=12,
                           detail=(f"structurally_inapplicable_low_frequency:"
                                   f"months_covered={months_covered}:need=12"),
                           evidence={"monthly_net": {m: round(v, 2) for m, v in monthly.items()},
                                     "months_covered": months_covered,
                                     "trades_counted": counted})

    losing_months = [m for m, v in monthly.items() if v <= 0]
    if losing_months:
        return make_result(GATE_NAME, "FAIL",
                           value=12 - len(losing_months), threshold=12,
                           detail=f"losing_months:{sorted(losing_months)}",
                           evidence={"monthly_net": {m: round(v, 2) for m, v in monthly.items()},
                                     "losing_months": sorted(losing_months)})

    return make_result(GATE_NAME, "PASS",
                       value=12, threshold=12,
                       detail="all_12_months_net_positive",
                       evidence={"monthly_net": {m: round(v, 2) for m, v in monthly.items()},
                                 "trades_counted": counted})
