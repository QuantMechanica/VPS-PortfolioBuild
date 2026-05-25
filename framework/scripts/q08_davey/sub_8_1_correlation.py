"""Q08.1 — Correlation vs existing portfolio.

Pairwise |Pearson r| must be < 0.50 against every EA currently in Q11+
status. Empty portfolio pool = trivial PASS (first EA in).

Equity curves are daily-resampled from EQUITY_SNAPSHOT events. Overlap
period is the intersection of the candidate's history and each existing
portfolio EA's history.
"""

from __future__ import annotations

import math

from .common import make_result

GATE_NAME = "8.1_correlation"
ABS_R_MAX = 0.50


def _pearson(xs: list[float], ys: list[float]) -> float | None:
    n = len(xs)
    if n < 30 or len(ys) != n:
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
    """day_key (YYYYMMDD int) → day_pnl from EQUITY_SNAPSHOT events."""
    out: dict[int, float] = {}
    for snap in equity_stream or []:
        dk = snap.get("day_key")
        try:
            dk_i = int(dk)
            pnl = float(snap.get("day_pnl", 0) or 0)
        except (TypeError, ValueError):
            continue
        out[dk_i] = pnl
    return out


def run(equity_stream: list[dict] | None = None,
        portfolio: list[dict] | None = None, **_) -> dict:
    if not portfolio:
        return make_result(GATE_NAME, "PASS",
                           value=0, threshold=ABS_R_MAX,
                           detail="portfolio_empty_first_entry_trivial_pass",
                           evidence={"portfolio_size": 0})

    cand = _candidate_daily_returns(equity_stream or [])
    if len(cand) < 30:
        return make_result(GATE_NAME, "INVALID",
                           value=len(cand), threshold=30,
                           detail=f"insufficient_candidate_history:days={len(cand)}:need>=30")

    correlations: dict[str, float] = {}
    breaches: list[str] = []
    for peer in portfolio:
        peer_id = f"QM5_{peer.get('ea_id', '?')}_{peer.get('symbol', '?')}"
        peer_returns = peer.get("equity_curve") or {}
        # Intersection day keys
        common = sorted(set(cand.keys()) & set(int(k) for k in peer_returns.keys()))
        if len(common) < 30:
            continue
        xs = [cand[d] for d in common]
        ys = [float(peer_returns[str(d) if str(d) in peer_returns else d] or 0) for d in common]
        r = _pearson(xs, ys)
        if r is None:
            continue
        correlations[peer_id] = round(r, 4)
        if abs(r) >= ABS_R_MAX:
            breaches.append(f"{peer_id}:r={r:+.3f}")

    if breaches:
        return make_result(
            GATE_NAME, "FAIL",
            value=max(abs(v) for v in correlations.values()),
            threshold=ABS_R_MAX,
            detail=f"correlation_breach:{';'.join(breaches[:5])}",
            evidence={"correlations": correlations, "portfolio_size": len(portfolio)})

    max_abs = max((abs(v) for v in correlations.values()), default=0.0)
    return make_result(
        GATE_NAME, "PASS",
        value=round(max_abs, 4), threshold=ABS_R_MAX,
        detail=f"max_abs_r={max_abs:.3f}<{ABS_R_MAX}",
        evidence={"correlations": correlations, "portfolio_size": len(portfolio)})
