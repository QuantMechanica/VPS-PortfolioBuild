"""Q08.10 — Regime + Crisis.

HARD gate: profitable in all 3 ATR regimes (low / normal / high).
SOFT (informational): per-crisis-slice metrics — surfaced but never blocks.

Regime classification comes from the FW6 EquityStream's `atr_regime` field
on each EQUITY_SNAPSHOT event. Trades are bucketed by the day they closed
to the regime active on that day.

Crisis slices are reported separately from the regime hard gate per the
2026-05-23 OWNER call (soft, informational; old Q08 crisis-block dropped).
"""

from __future__ import annotations

from collections import defaultdict

from .common import make_result, trade_timestamp

GATE_NAME = "8.10_regime_crisis"
REQUIRED_REGIMES = ("low", "normal", "high")

# Crisis episodes (year-month windows). Informational only.
CRISIS_WINDOWS = {
    "COVID_2020":   ((2020, 2),  (2020, 4)),
    "SNB_2015":     ((2015, 1),  (2015, 1)),
    "UKRAINE_2022": ((2022, 2),  (2022, 3)),
    "GFC_2008":     ((2008, 9),  (2009, 3)),
    "CHINA_2015":   ((2015, 8),  (2015, 9)),
    "INFLATION_2022": ((2022, 1), (2022, 12)),
}


def _ts_in_window(ts, lo, hi) -> bool:
    if ts is None:
        return False
    ym = (ts.year, ts.month)
    return lo <= ym <= hi


def run(trades: list[dict], equity_stream: list[dict] | None = None, **_) -> dict:
    if not trades:
        return make_result(GATE_NAME, "INVALID",
                           value=0, threshold=3, detail="no_trades")

    # Build per-day regime map from EquityStream snapshots.
    day_regime: dict[str, str] = {}
    if equity_stream:
        for snap in equity_stream:
            day_key = snap.get("day_key")
            regime = snap.get("atr_regime")
            if day_key is None or not regime:
                continue
            day_regime[str(day_key)] = regime

    if not day_regime:
        return make_result(
            GATE_NAME, "INVALID",
            value={r: 0 for r in REQUIRED_REGIMES},
            threshold={r: ">0 trades" for r in REQUIRED_REGIMES},
            detail=f"regime_input_missing:no_equity_snapshots:n_trades={len(trades)}",
            evidence={"n_trades": len(trades), "n_equity_snapshots": len(equity_stream or [])})

    # Bucket per-trade P&L by regime.
    regime_pnl: dict[str, float] = defaultdict(float)
    regime_count: dict[str, int] = defaultdict(int)
    unclassified = 0
    timestamped_trades = 0

    crisis_pnl: dict[str, float] = defaultdict(float)
    crisis_count: dict[str, int] = defaultdict(int)

    for t in trades:
        ts = trade_timestamp(t)
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        # Regime
        if ts is not None:
            timestamped_trades += 1
            day_key = ts.year * 10000 + ts.month * 100 + ts.day
            r = day_regime.get(str(day_key)) or day_regime.get(day_key)
            if r in REQUIRED_REGIMES:
                regime_pnl[r] += net
                regime_count[r] += 1
            else:
                unclassified += 1
        # Crisis slices (informational)
        for name, (lo, hi) in CRISIS_WINDOWS.items():
            if _ts_in_window(ts, lo, hi):
                crisis_pnl[name] += net
                crisis_count[name] += 1

    # Regime hard gate: every required regime must be net-positive.
    missing = [r for r in REQUIRED_REGIMES if regime_count[r] == 0]
    losers = [r for r in REQUIRED_REGIMES if regime_count[r] > 0 and regime_pnl[r] <= 0]
    classified = sum(regime_count[r] for r in REQUIRED_REGIMES)

    crisis_info = {
        name: {"net": round(crisis_pnl[name], 2), "trades": crisis_count[name]}
        for name in CRISIS_WINDOWS
        if crisis_count[name] > 0
    }

    if classified == 0 and unclassified > 0:
        return make_result(
            GATE_NAME, "INVALID",
            value={r: regime_count[r] for r in REQUIRED_REGIMES},
            threshold={r: ">0 trades" for r in REQUIRED_REGIMES},
            detail=(
                "regime_join_failed:"
                f"classified=0:unclassified={unclassified}:n_trades={len(trades)}"
            ),
            evidence={"regime_pnl": {r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
                      "regime_count": dict(regime_count),
                      "unclassified_trades": unclassified,
                      "equity_snapshot_days": len(day_regime),
                      "crisis_informational": crisis_info})

    if timestamped_trades > 0 and unclassified / timestamped_trades > 0.10:
        return make_result(
            GATE_NAME, "INVALID",
            value={r: regime_count[r] for r in REQUIRED_REGIMES},
            threshold={r: ">0 trades" for r in REQUIRED_REGIMES},
            detail=(
                "regime_join_incomplete:"
                f"classified={classified}:unclassified={unclassified}:"
                f"n_timestamped={timestamped_trades}"
            ),
            evidence={"regime_pnl": {r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
                      "regime_count": dict(regime_count),
                      "unclassified_trades": unclassified,
                      "equity_snapshot_days": len(day_regime),
                      "crisis_informational": crisis_info})

    if missing:
        return make_result(
            GATE_NAME, "FAIL",
            value={r: regime_count[r] for r in REQUIRED_REGIMES},
            threshold={r: ">0 trades" for r in REQUIRED_REGIMES},
            detail=f"regimes_with_zero_trades:{missing}",
            evidence={"regime_pnl": {r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
                      "regime_count": dict(regime_count),
                      "unclassified_trades": unclassified,
                      "crisis_informational": crisis_info})

    if losers:
        return make_result(
            GATE_NAME, "FAIL",
            value={r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
            threshold={r: ">0 P&L" for r in REQUIRED_REGIMES},
            detail=f"unprofitable_regimes:{losers}",
            evidence={"regime_pnl": {r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
                      "regime_count": dict(regime_count),
                      "crisis_informational": crisis_info})

    return make_result(
        GATE_NAME, "PASS",
        value={r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
        threshold={r: ">0 P&L" for r in REQUIRED_REGIMES},
        detail="all_3_atr_regimes_profitable",
        evidence={"regime_pnl": {r: round(regime_pnl[r], 2) for r in REQUIRED_REGIMES},
                  "regime_count": dict(regime_count),
                  "unclassified_trades": unclassified,
                  "crisis_informational": crisis_info})
