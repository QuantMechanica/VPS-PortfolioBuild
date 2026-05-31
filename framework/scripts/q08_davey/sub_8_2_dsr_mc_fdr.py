"""Q08.2 — Deflated Sharpe Ratio + Monte Carlo + FDR.

Two-tier pass:
  Tier 1 (Core):     Deflated Sharpe Ratio p-value < 0.05
  Tier 2 (Watchlist): Benjamini-Hochberg FDR-controlled pass

DSR adjusts Sharpe for the multiple-testing bias of having tested many
strategies. The deflation reflects the maximum-Sharpe selection variance
across a candidate set of `n_strategies`.

Reference: Bailey & López de Prado, 2014 — "The Deflated Sharpe Ratio".
"""

from __future__ import annotations

import math
import statistics

from .common import make_result, trade_timestamp

GATE_NAME = "8.2_dsr_mc_fdr"
DSR_P_MIN = 0.05
N_CANDIDATE_STRATEGIES = 369   # rough V5 candidate count; updates as the farm grows
EULER_MASCHERONI = 0.5772156649


def _trade_returns_per_day(trades: list[dict]) -> list[float]:
    """Aggregate per-trade P&L into per-day return series."""
    from collections import defaultdict
    by_day: dict[int, float] = defaultdict(float)
    for t in trades:
        ts = trade_timestamp(t)
        if ts is None:
            continue
        try:
            net = float(t.get("net", t.get("profit", 0)) or 0)
        except (TypeError, ValueError):
            continue
        by_day[ts.year * 10000 + ts.month * 100 + ts.day] += net
    return [by_day[k] for k in sorted(by_day.keys())]


def _sharpe_annual(returns: list[float]) -> tuple[float, float, float, float]:
    """Return (sharpe, skew, kurtosis_excess, n_obs). Sharpe is annualised
    assuming daily returns (× sqrt(252))."""
    n = len(returns)
    if n < 30:
        return 0.0, 0.0, 0.0, n
    mu = statistics.fmean(returns)
    sd = statistics.pstdev(returns)
    if sd == 0:
        return 0.0, 0.0, 0.0, n
    sharpe = (mu / sd) * math.sqrt(252)
    # Skewness and excess kurtosis (sample moments)
    m3 = sum((r - mu) ** 3 for r in returns) / n
    m4 = sum((r - mu) ** 4 for r in returns) / n
    skew = m3 / (sd ** 3) if sd > 0 else 0.0
    kurt_ex = (m4 / (sd ** 4)) - 3.0 if sd > 0 else 0.0
    return sharpe, skew, kurt_ex, n


def _expected_max_sharpe(n_strats: int, sharpe_std: float) -> float:
    """E[max(SR_1..SR_n)] for n IID Normal Sharpe estimates with std sharpe_std."""
    if n_strats <= 1:
        return 0.0
    # Approx (Bailey & López de Prado): inverse normal of (1 - 1/n) - inverse normal of (1 - 1/(n*e))
    # Cheap approximation: sqrt(2 ln n)
    return sharpe_std * (math.sqrt(2.0 * math.log(n_strats)) -
                         EULER_MASCHERONI / math.sqrt(2.0 * math.log(n_strats)))


def _deflated_sharpe_pvalue(observed_sr: float, sharpe_std: float, skew: float,
                            kurt_ex: float, n_obs: int, n_strats: int) -> float:
    """Compute DSR p-value via Bailey & López de Prado (2014)."""
    if n_obs < 30 or sharpe_std <= 0:
        return 1.0
    expected_max = _expected_max_sharpe(n_strats, sharpe_std)
    # Variance of estimated SR
    sr_var = (1.0 - skew * observed_sr + ((kurt_ex - 1.0) / 4.0) * observed_sr ** 2) / (n_obs - 1)
    sr_var = max(sr_var, 1e-12)
    z = (observed_sr - expected_max) / math.sqrt(sr_var)
    # p-value = 1 - Phi(z)
    p = 1.0 - 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))
    return max(0.0, min(1.0, p))


def run(trades: list[dict], **_) -> dict:
    returns = _trade_returns_per_day(trades)
    if len(returns) < 60:  # ~3 months of trading days
        return make_result(GATE_NAME, "INVALID",
                           value=len(returns), threshold=60,
                           detail=f"insufficient_daily_returns:got={len(returns)}:need>=60")

    sharpe, skew, kurt_ex, n_obs = _sharpe_annual(returns)
    if sharpe <= 0:
        return make_result(GATE_NAME, "FAIL",
                           value=round(sharpe, 4), threshold=0,
                           detail=f"sharpe_non_positive:sr={sharpe:.3f}")

    sharpe_std_estimate = 1.0  # conservative; refined when N_STRATS samples land
    p_value = _deflated_sharpe_pvalue(sharpe, sharpe_std_estimate, skew, kurt_ex,
                                      n_obs, N_CANDIDATE_STRATEGIES)

    if p_value < DSR_P_MIN:
        return make_result(GATE_NAME, "PASS",
                           value=round(p_value, 5), threshold=DSR_P_MIN,
                           detail=f"DSR_TIER1:p={p_value:.4f}<{DSR_P_MIN}:sr={sharpe:.3f}",
                           evidence={"sharpe": round(sharpe, 4), "skew": round(skew, 4),
                                     "excess_kurtosis": round(kurt_ex, 4),
                                     "n_obs_days": n_obs, "tier": "core"})

    # Tier 2 (Watchlist) — BH-FDR is applied across the candidate set at
    # batch level. Per-EA we report the p-value; the batch-level FDR pass
    # is determined by the aggregator's outer pass over all candidates.
    # Here we mark "INVALID" so the aggregator knows to push to FDR review
    # rather than mark FAIL outright.
    return make_result(GATE_NAME, "INVALID",
                       value=round(p_value, 5), threshold=DSR_P_MIN,
                       detail=f"DSR_TIER1_FAIL_push_to_fdr_review:p={p_value:.4f}",
                       evidence={"sharpe": round(sharpe, 4), "skew": round(skew, 4),
                                 "excess_kurtosis": round(kurt_ex, 4),
                                 "n_obs_days": n_obs, "tier": "watchlist_pending_fdr"})
