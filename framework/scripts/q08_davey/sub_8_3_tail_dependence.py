"""Q08.3 — Tail Dependence.

Correlation under top/bottom 5% market moves must be ≤ baseline pairwise
correlation. Tests whether the EA's edge survives extreme conditions —
diversification fails if assets correlate strongly when crises hit.

Implementation: compares the candidate's daily P&L correlation with each
portfolio peer's P&L during tail-vs-non-tail days, classified by the
broader market's ATR or a benchmark series.

If no portfolio peers exist (first EA), the gate trivially PASSes —
tail dependence is by definition pairwise.
"""

from __future__ import annotations

import math

from .common import make_result

GATE_NAME = "8.3_tail_dependence"
TAIL_PCT = 5.0   # top/bottom 5%


def _pearson(xs: list[float], ys: list[float]) -> float | None:
    n = len(xs)
    if n < 10 or len(ys) != n:
        return None
    mx = sum(xs) / n
    my = sum(ys) / n
    sx = math.sqrt(sum((x - mx) ** 2 for x in xs))
    sy = math.sqrt(sum((y - my) ** 2 for y in ys))
    if sx == 0 or sy == 0:
        return 0.0
    cov = sum((xs[i] - mx) * (ys[i] - my) for i in range(n))
    return cov / (sx * sy)


def _candidate_daily_returns(equity_stream: list[dict]) -> dict[int, float]:
    out: dict[int, float] = {}
    for snap in equity_stream or []:
        try:
            dk = int(snap.get("day_key"))
            pnl = float(snap.get("day_pnl", 0) or 0)
        except (TypeError, ValueError):
            continue
        out[dk] = pnl
    return out


def run(equity_stream: list[dict] | None = None,
        portfolio: list[dict] | None = None, **_) -> dict:
    if not portfolio:
        return make_result(GATE_NAME, "PASS",
                           value=0, threshold=0,
                           detail="no_portfolio_peers_trivial_pass",
                           evidence={"portfolio_size": 0})

    cand = _candidate_daily_returns(equity_stream or [])
    if len(cand) < 60:
        return make_result(GATE_NAME, "INVALID",
                           value=len(cand), threshold=60,
                           detail=f"insufficient_history:days={len(cand)}:need>=60")

    breaches: list[dict] = []
    deltas: dict[str, float] = {}

    for peer in portfolio:
        peer_id = f"QM5_{peer.get('ea_id','?')}_{peer.get('symbol','?')}"
        peer_returns = peer.get("equity_curve") or {}
        common = sorted(set(cand.keys()) & {int(k) for k in peer_returns.keys()})
        if len(common) < 60:
            continue
        xs = [cand[d] for d in common]
        ys = [float(peer_returns[str(d) if str(d) in peer_returns else d] or 0) for d in common]

        # Tail = top/bottom 5% by peer-return magnitude (proxy for "market stress")
        cutoff = max(1, int(len(common) * TAIL_PCT / 100.0))
        idx_sorted = sorted(range(len(ys)), key=lambda i: abs(ys[i]), reverse=True)
        tail_idx = set(idx_sorted[:cutoff])

        xs_tail = [xs[i] for i in range(len(xs)) if i in tail_idx]
        ys_tail = [ys[i] for i in range(len(ys)) if i in tail_idx]
        xs_body = [xs[i] for i in range(len(xs)) if i not in tail_idx]
        ys_body = [ys[i] for i in range(len(ys)) if i not in tail_idx]

        r_tail = _pearson(xs_tail, ys_tail)
        r_body = _pearson(xs_body, ys_body)
        if r_tail is None or r_body is None:
            continue

        delta = abs(r_tail) - abs(r_body)
        deltas[peer_id] = round(delta, 4)
        if delta > 0.10:  # 10pp slack — tail correlation materially higher
            breaches.append({"peer": peer_id, "r_tail": round(r_tail, 3),
                             "r_body": round(r_body, 3), "delta": round(delta, 3)})

    if breaches:
        return make_result(
            GATE_NAME, "FAIL",
            value=max(b["delta"] for b in breaches),
            threshold=0.10,
            detail=f"tail_correlation_inflation_{len(breaches)}_peers",
            evidence={"breaches": breaches[:5], "all_deltas": deltas})

    max_delta = max(deltas.values(), default=0.0)
    return make_result(
        GATE_NAME, "PASS",
        value=round(max_delta, 4), threshold=0.10,
        detail=f"max_tail_delta={max_delta:.3f}<=0.10",
        evidence={"all_deltas": deltas, "portfolio_size": len(portfolio)})
