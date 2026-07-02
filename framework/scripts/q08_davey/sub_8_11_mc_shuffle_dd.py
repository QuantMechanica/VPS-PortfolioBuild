"""Q08.11 — Monte Carlo trade-order-shuffle drawdown.

Soft-only robustness gate: preserve the realized trade outcomes, shuffle their
order without replacement, and compare the 95th-percentile shuffled max DD to
the realized max DD and the 10% capital floor.
"""

from __future__ import annotations

import math
import random
import statistics

from .common import make_result, trade_net_profits

GATE_NAME = "8.11_mc_shuffle_dd"
STARTING_CAPITAL = 100_000.0
N_PERMUTATIONS = 1000
SEED = 8112026


def _max_drawdown_abs(profits: list[float], starting_capital: float = STARTING_CAPITAL) -> float:
    equity = float(starting_capital)
    peak = equity
    max_dd = 0.0
    for profit in profits:
        equity += float(profit)
        if equity > peak:
            peak = equity
        drawdown = peak - equity
        if drawdown > max_dd:
            max_dd = drawdown
    return max_dd


def _nearest_rank_percentile(values: list[float], percentile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    rank = math.ceil((percentile / 100.0) * len(ordered))
    idx = min(max(rank - 1, 0), len(ordered) - 1)
    return ordered[idx]


def _round_money(value: float) -> float:
    return round(float(value), 2)


def _round_pct(value: float, starting_capital: float) -> float:
    if starting_capital <= 0:
        return 0.0
    return round((float(value) / starting_capital) * 100.0, 4)


def run(
    trades: list[dict],
    *,
    starting_capital: float = STARTING_CAPITAL,
    n_permutations: int = N_PERMUTATIONS,
    seed: int = SEED,
    **_,
) -> dict:
    profits = trade_net_profits(trades)
    if len(profits) < 2:
        return make_result(
            GATE_NAME,
            "INVALID",
            value=len(profits),
            threshold=2,
            detail="insufficient_trade_count: need >=2 trades for trade-order shuffle",
            evidence={
                "starting_capital": starting_capital,
                "n_permutations": n_permutations,
                "seed": seed,
                "n_trades": len(profits),
            },
        )

    rng = random.Random(seed)
    as_realized_maxdd = _max_drawdown_abs(profits, starting_capital)
    shuffled_drawdowns: list[float] = []
    working = list(profits)
    for _ in range(int(n_permutations)):
        rng.shuffle(working)
        shuffled_drawdowns.append(_max_drawdown_abs(working, starting_capital))

    mc_maxdd_median = statistics.median(shuffled_drawdowns)
    mc_maxdd_p95 = _nearest_rank_percentile(shuffled_drawdowns, 95.0)
    threshold = max(starting_capital * 0.10, as_realized_maxdd * 2.0)
    status = "PASS" if mc_maxdd_p95 <= threshold else "FAIL"
    if as_realized_maxdd > 0:
        ratio = round(mc_maxdd_p95 / as_realized_maxdd, 6)
    else:
        ratio = 1.0 if mc_maxdd_p95 == 0 else None

    evidence = {
        "method": "trade_order_shuffle_without_replacement",
        "starting_capital": starting_capital,
        "n_permutations": int(n_permutations),
        "seed": int(seed),
        "n_trades": len(profits),
        "terminal_pnl": _round_money(sum(profits)),
        "as_realized_maxdd": _round_money(as_realized_maxdd),
        "as_realized_maxdd_pct": _round_pct(as_realized_maxdd, starting_capital),
        "mc_maxdd_median": _round_money(mc_maxdd_median),
        "mc_maxdd_median_pct": _round_pct(mc_maxdd_median, starting_capital),
        "mc_maxdd_p95": _round_money(mc_maxdd_p95),
        "mc_maxdd_p95_pct": _round_pct(mc_maxdd_p95, starting_capital),
        "mc_maxdd_p95_over_as_realized_maxdd": ratio,
        "threshold": _round_money(threshold),
        "threshold_pct": _round_pct(threshold, starting_capital),
    }
    detail_ratio = "undefined" if ratio is None else f"{ratio:.6f}"
    detail = (
        f"mc_maxdd_p95={evidence['mc_maxdd_p95']:.2f}:"
        f"as_realized_maxdd={evidence['as_realized_maxdd']:.2f}:"
        f"threshold={evidence['threshold']:.2f}:"
        f"ratio={detail_ratio}:"
        f"seed={seed}:permutations={n_permutations}"
    )
    return make_result(
        GATE_NAME,
        status,
        value=evidence["mc_maxdd_p95"],
        threshold=evidence["threshold"],
        detail=detail,
        evidence=evidence,
    )
