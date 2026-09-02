"""Q08.2 — Deflated Sharpe Ratio + Monte Carlo + FDR.

Two-tier pass:
  Tier 1 (Core):     Deflated Sharpe Ratio p-value < 0.05
  Tier 2 (Watchlist): Benjamini-Hochberg FDR-controlled pass

DSR adjusts Sharpe for the multiple-testing bias of having *selected* this
strategy out of a candidate cohort. The deflation reflects the maximum-Sharpe
selection variance across that cohort.

First-entry / empty-cohort semantics
------------------------------------
The deflation only has meaning when there is a peer cohort to have selected
from. For the first EA (no portfolio peers) there is no selection bias to
correct, so — exactly like 8.1 (correlation) and 8.3 (tail-dependence) — this
gate returns a trivial PASS pending cohort, and the deflation is deferred.
A computed DSR result is NEVER returned as INVALID: INVALID is reserved for
genuine infrastructure gaps (insufficient data), not statistical outcomes.
A Tier-1 statistical fail resolves to FAIL (there is no batch-FDR rescue pass
implemented in the aggregator yet; once one exists it may override FAIL->PASS).

Reference: Bailey & López de Prado, 2014 — "The Deflated Sharpe Ratio".
"""

from __future__ import annotations

import math
import statistics

from .common import make_result, trade_timestamp

GATE_NAME = "8.2_dsr_mc_fdr"
DSR_P_MIN = 0.05
N_CANDIDATE_STRATEGIES = 369   # rough V5 candidate count; updates as the farm grows
# CEO audit 2026-09-02, read-only farm census.  These do not alter the sealed
# 8.2 threshold or verdict yet; they are emitted as the mandatory report-only
# cohort deflation for OWNER review.
FUNNEL_DISTINCT_EAS = 3_001
FUNNEL_DISTINCT_PAIRS = 13_398
# Optimization-track selection multiplicity (DL-084 / plan v2 A3).
# `selection_trial_count` is the number of configurations the evaluated one was
# SELECTED FROM, not the number measured. Under the plan-v2 firewall (E0-1) a
# source-derived, pre-registered predicate is selected from 1 candidate even when
# a census measured 154 — measurement is not selection. A max-selected winner
# passes its full trial count. Absent/None/<=1 leaves the fleet default untouched,
# so ordinary Q08 runs (which carry no trial ledger) are bit-identical to before.
MIN_SELECTION_TRIALS_FOR_DEFLATION = 2
# Minimum peer cohort below which DSR deflation is not applicable (no
# selection bias to correct). Mirrors the first-entry trivial-pass used by
# 8.1 / 8.3. TODO(calibration): once the farm wires a real candidate-Sharpe
# distribution, derive `sharpe_std` from it and replace the 1.0 placeholder in
# run(); the current deflation bar (E[max] ~= sqrt(2 ln N)) is otherwise too
# harsh for any realistic Sharpe.
MIN_COHORT_PEERS = 1
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


def _report_only_funnel_dsr(sharpe: float, skew: float, kurt_ex: float,
                            n_obs: int) -> dict:
    """Bailey-Lopez de Prado DSR against the audited full search funnel.

    The annualized benchmark uses the observed daily-series duration.  This is
    deliberately evidence-only: existing 8.2 PASS/FAIL semantics and the sealed
    p<0.05 threshold remain untouched pending OWNER disposition.
    """
    years = n_obs / 252.0
    nd = statistics.NormalDist()
    sr_se_annual = math.sqrt(252.0) * math.sqrt(max(
        (1.0 - skew * sharpe / math.sqrt(252.0)
         + ((kurt_ex - 1.0) / 4.0) * (sharpe / math.sqrt(252.0)) ** 2)
        / max(1, n_obs - 1),
        1e-12,
    ))
    rows = []
    for label, count in (("distinct_eas", FUNNEL_DISTINCT_EAS),
                         ("distinct_pairs", FUNNEL_DISTINCT_PAIRS)):
        expected_max = (
            ((1.0 - EULER_MASCHERONI) * nd.inv_cdf(1.0 - 1.0 / count)
             + EULER_MASCHERONI * nd.inv_cdf(1.0 - 1.0 / (count * math.e)))
            / math.sqrt(years)
        )
        probability = nd.cdf((sharpe - expected_max) / sr_se_annual)
        rows.append({
            "cohort": label,
            "effective_trial_count": count,
            "expected_max_annualized_sharpe": round(expected_max, 6),
            "dsr_probability": round(probability, 8),
            "would_meet_existing_probability_bar": probability > 1.0 - DSR_P_MIN,
        })
    return {
        "mode": "REPORT_ONLY_OWNER_REVIEW",
        "formula": "BAILEY_LOPEZ_DE_PRADO_2014",
        "threshold_changed": False,
        "observed_annualized_sharpe": round(sharpe, 6),
        "n_obs_days": n_obs,
        "years_at_252_days": round(years, 6),
        "rows": rows,
    }


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


def _effective_candidate_count(selection_trial_count) -> tuple[int, str, int | None]:
    """Resolve the DSR selection pool from the optional optimization-track count.

    Returns (n_strats, mode, normalized_count). A missing, unparseable or <2 count
    yields the untouched fleet default so non-optimization runs never change.
    """
    try:
        count = int(selection_trial_count)
    except (TypeError, ValueError):
        return N_CANDIDATE_STRATEGIES, "fleet_default", None
    if count < MIN_SELECTION_TRIALS_FOR_DEFLATION:
        return N_CANDIDATE_STRATEGIES, "fleet_default", count if count > 0 else None
    # Additive family expansion: the sleeve competed against the farm cohort AND
    # against its own (count-1) sibling configurations. The sleeve itself is
    # already one member of the fleet cohort, hence count-1 and not count.
    return N_CANDIDATE_STRATEGIES + count - 1, "optimization_selection_expanded", count


def run(trades: list[dict], *, portfolio: list[dict] | None = None,
        selection_trial_count: int | None = None, **_) -> dict:
    returns = _trade_returns_per_day(trades)
    if len(returns) < 60:  # ~3 months of trading days
        # Genuine infrastructure / data gap — INVALID is correct here (re-runnable).
        return make_result(GATE_NAME, "INVALID",
                           value=len(returns), threshold=60,
                           detail=f"insufficient_daily_returns:got={len(returns)}:need>=60")

    sharpe, skew, kurt_ex, n_obs = _sharpe_annual(returns)
    funnel_report = _report_only_funnel_dsr(sharpe, skew, kurt_ex, n_obs)
    if sharpe <= 0:
        return make_result(GATE_NAME, "FAIL",
                           value=round(sharpe, 4), threshold=0,
                           detail=f"sharpe_non_positive:sr={sharpe:.3f}",
                           evidence={"cohort_dsr_report": funnel_report})

    # First-entry / empty-cohort: no selection bias to deflate. Trivial PASS
    # pending cohort, consistent with 8.1 / 8.3. The DSR deflation activates
    # once the farm accumulates a calibrated peer cohort (see MIN_COHORT_PEERS).
    n_peers = len(portfolio or [])
    if n_peers < MIN_COHORT_PEERS:
        return make_result(GATE_NAME, "PASS",
                           value=0, threshold=DSR_P_MIN,
                           detail=("no_candidate_cohort_first_entry_trivial_pass:"
                                   f"sr={sharpe:.3f}; DSR deflation deferred until "
                                   f">={MIN_COHORT_PEERS} peer(s)"),
                           evidence={"sharpe": round(sharpe, 4), "skew": round(skew, 4),
                                     "excess_kurtosis": round(kurt_ex, 4),
                                     "n_obs_days": n_obs, "n_peers": n_peers,
                                     "tier": "standalone_pending_cohort",
                                     "cohort_dsr_report": funnel_report})

    # Cohort mode — deflate against the candidate set's max-Sharpe selection bias.
    # Deliberately conservative, NOT an un-investigated placeholder: the 2026-08-13
    # calibration study (docs/ops/evidence/2026-08-13_dsr_sharpe_std_calibration_study.md)
    # measured 0.892 across the 26 EAs with a recorded Q08 Sharpe, but that sample is
    # survivors-only — selection truncates the low tail and shrinks the dispersion, so
    # adopting it would SHRINK E[max] and silently loosen this gate. 1.0 is kept until a
    # loser-inclusive candidate distribution exists; changing it is an OWNER-ratified
    # gate recalibration, not a side effect.
    sharpe_std_estimate = 1.0
    n_strats, selection_mode, selection_count = _effective_candidate_count(selection_trial_count)
    p_value = _deflated_sharpe_pvalue(sharpe, sharpe_std_estimate, skew, kurt_ex,
                                      n_obs, n_strats)

    if p_value < DSR_P_MIN:
        return make_result(GATE_NAME, "PASS",
                           value=round(p_value, 5), threshold=DSR_P_MIN,
                           detail=f"DSR_TIER1:p={p_value:.4f}<{DSR_P_MIN}:sr={sharpe:.3f}",
                           evidence={"sharpe": round(sharpe, 4), "skew": round(skew, 4),
                                     "excess_kurtosis": round(kurt_ex, 4),
                                     "n_obs_days": n_obs, "n_peers": n_peers,
                                     "tier": "core",
                                     "n_candidate_strategies": n_strats,
                                     "selection_mode": selection_mode,
                                     "selection_trial_count": selection_count,
                                     "sharpe_std_estimate": sharpe_std_estimate,
                                     "sharpe_std_calibrated": False,
                                     "cohort_dsr_report": funnel_report})

    # Tier-1 statistical fail. There is no batch-level BH-FDR rescue pass in the
    # aggregator yet, so resolve to a real verdict (FAIL) rather than a permanent
    # INVALID dead-end. A future cohort-level FDR pass may override FAIL->PASS.
    return make_result(GATE_NAME, "FAIL",
                       value=round(p_value, 5), threshold=DSR_P_MIN,
                       detail=f"DSR_TIER1_FAIL:p={p_value:.4f}>={DSR_P_MIN}:sr={sharpe:.3f}",
                       evidence={"sharpe": round(sharpe, 4), "skew": round(skew, 4),
                                 "excess_kurtosis": round(kurt_ex, 4),
                                 "n_obs_days": n_obs, "n_peers": n_peers,
                                 "tier": "fdr_rescue_eligible",
                                 "n_candidate_strategies": n_strats,
                                 "selection_mode": selection_mode,
                                 "selection_trial_count": selection_count,
                                 "sharpe_std_estimate": sharpe_std_estimate,
                                 "sharpe_std_calibrated": False,
                                 "cohort_dsr_report": funnel_report})
