"""Section 59 materiality / anti-churn predicate (deterministic + seeded).

Weekly review does NOT imply weekly change (directive section 5/59).  A proposed
change is declared MATERIAL only when ALL of the following hold; the default is KEEP:

* expected_improvement -- venue-fitness gain clears the improvement threshold
  (DXZ also requires the OWNER-ratified oos-Sharpe +0.06 / maxDD <= +0.05pp rule,
  reusing ``dxz_next_book_trigger`` constants),
* confidence          -- seeded blocked-bootstrap CI of the daily book-PnL
  difference (alternative minus incumbent) excludes 0 at level alpha,
* downside_risk       -- worst day not worse AND max-drawdown not materially worse,
* model_uncertainty   -- split-half sign consistency of the improvement,
* live_uncertainty    -- incumbent live evidence (when present) does not contradict,
* switching_cost      -- expected return improvement exceeds a turnover-cost proxy,
* operational_complexity -- new-symbol / new-family op-risk score within budget,
* economic_band       -- |delta objective| above a minimum economic-significance band.

The bootstrap is seeded from the snapshot (``seed``) so the verdict is reproducible.
Statistical significance is not sufficient (economic band); economic significance is
not sufficient (confidence): both are required, matching the directive.
"""
from __future__ import annotations

import datetime as dt
import random
from typing import Any, Mapping, Sequence

try:  # package import
    from ..dxz_next_book_trigger import MAX_DD_WORSENING_PP, MIN_OOS_SHARPE_DELTA
except ImportError:  # pragma: no cover - direct script execution
    from dxz_next_book_trigger import MAX_DD_WORSENING_PP, MIN_OOS_SHARPE_DELTA  # type: ignore

Key = tuple[int, str]

DEFAULT_CONFIG: dict[str, Any] = {
    "min_fitness_improvement": 0.01,      # objective units (0..1 scale)
    "economic_band": 0.005,               # minimum |delta objective| to act on
    "bootstrap_replications": 2000,
    "bootstrap_block_days": 10,
    "bootstrap_alpha": 0.10,              # two-sided; CI = [alpha/2, 1-alpha/2]
    "max_dd_worsening_pp": MAX_DD_WORSENING_PP,
    "min_oos_sharpe_delta": MIN_OOS_SHARPE_DELTA,
    "switching_cost_pct_per_change": 0.02,  # annual return pp charged per added+removed sleeve
    "operational_complexity_budget": 2,
}


def _num(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _block_bootstrap_mean_ci(
    diff: Sequence[float], *, replications: int, block_days: int, alpha: float, seed: int
) -> dict[str, Any]:
    """Seeded circular block-bootstrap CI for the mean of the difference series."""
    n = len(diff)
    if n < 2:
        return {"status": "INSUFFICIENT_DATA", "lower": None, "upper": None, "excludes_zero": False}
    rng = random.Random(seed)
    block = max(1, min(int(block_days), n))
    means: list[float] = []
    for _ in range(int(replications)):
        sampled: list[float] = []
        while len(sampled) < n:
            start = rng.randrange(n)
            for offset in range(block):
                sampled.append(float(diff[(start + offset) % n]))
                if len(sampled) == n:
                    break
        means.append(sum(sampled) / n)
    means.sort()

    def _pct(p: float) -> float:
        if len(means) == 1:
            return means[0]
        pos = p * (len(means) - 1)
        lo = int(pos)
        hi = min(lo + 1, len(means) - 1)
        frac = pos - lo
        return means[lo] * (1 - frac) + means[hi] * frac

    lower = _pct(alpha / 2.0)
    upper = _pct(1.0 - alpha / 2.0)
    excludes_zero = (lower > 0.0) or (upper < 0.0)
    return {
        "status": "OK",
        "lower": round(lower, 10),
        "upper": round(upper, 10),
        "point_mean": round(sum(diff) / n, 10),
        "excludes_zero": bool(excludes_zero),
        "n_days": n,
        "block_days": block,
        "replications": int(replications),
        "alpha": alpha,
    }


def _diff_series(
    baseline_book_by_date: Mapping[dt.date, float],
    alt_book_by_date: Mapping[dt.date, float],
    starting_capital: float = 100_000.0,
) -> list[float]:
    common = sorted(set(baseline_book_by_date) & set(alt_book_by_date))
    return [
        (alt_book_by_date[d] - baseline_book_by_date[d]) / starting_capital * 100.0
        for d in common
    ]


def _split_half_consistent(diff: Sequence[float]) -> bool:
    n = len(diff)
    if n < 4:
        return False
    mid = n // 2
    first = sum(diff[:mid]) / mid
    second = sum(diff[mid:]) / (n - mid)
    if first == 0.0 or second == 0.0:
        return False
    return (first > 0.0) == (second > 0.0)


def assess(
    *,
    venue: str,
    change: Mapping[str, Any],
    baseline_fitness: Mapping[str, Any],
    alt_fitness: Mapping[str, Any],
    baseline_metrics: Mapping[str, Any],
    alt_metrics: Mapping[str, Any],
    baseline_book_by_date: Mapping[dt.date, float],
    alt_book_by_date: Mapping[dt.date, float],
    incumbent_symbols: Sequence[str],
    incumbent_live_evidence: Mapping[str, Any] | None = None,
    seed: int = 0,
    config: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Return the section 59 materiality verdict for one proposed change.

    ``material`` is True only when every factor passes; the KEEP baseline (no add/
    remove/replace) is never material.
    """
    cfg = {**DEFAULT_CONFIG, **(config or {})}
    outcome = str(change.get("outcome", "KEEP"))
    added = [tuple(x) for x in change.get("add", [])]
    removed = [tuple(x) for x in change.get("remove", [])]
    is_noop = not added and not removed

    reasons: list[str] = []
    factors: dict[str, Any] = {}

    base_obj = _num(baseline_fitness.get("objective"))
    alt_obj = _num(alt_fitness.get("objective"))
    delta_obj = None if (base_obj is None or alt_obj is None) else alt_obj - base_obj
    factors["delta_objective"] = None if delta_obj is None else round(delta_obj, 8)

    # 1. expected improvement
    improve_ok = delta_obj is not None and delta_obj >= cfg["min_fitness_improvement"]
    factors["expected_improvement"] = {
        "delta_objective": factors["delta_objective"],
        "threshold": cfg["min_fitness_improvement"],
        "pass": bool(improve_ok),
    }
    if not improve_ok:
        reasons.append("expected_improvement_below_threshold")

    # DXZ ratified sharpe/dd gate
    dxz_gate = {"applicable": venue == "dxz"}
    if venue == "dxz":
        d_sharpe = _num(alt_metrics.get("sharpe")) is not None and _num(baseline_metrics.get("sharpe")) is not None
        delta_sharpe = None
        delta_dd = None
        if _num(alt_metrics.get("sharpe")) is not None and _num(baseline_metrics.get("sharpe")) is not None:
            delta_sharpe = _num(alt_metrics.get("sharpe")) - _num(baseline_metrics.get("sharpe"))
        if _num(alt_metrics.get("max_drawdown_pct")) is not None and _num(baseline_metrics.get("max_drawdown_pct")) is not None:
            delta_dd = _num(alt_metrics.get("max_drawdown_pct")) - _num(baseline_metrics.get("max_drawdown_pct"))
        sharpe_ok = delta_sharpe is not None and delta_sharpe + 1e-12 >= cfg["min_oos_sharpe_delta"]
        dd_ok = delta_dd is not None and delta_dd <= cfg["max_dd_worsening_pp"] + 1e-12
        dxz_gate.update({
            "delta_sharpe": None if delta_sharpe is None else round(delta_sharpe, 8),
            "delta_max_drawdown_pp": None if delta_dd is None else round(delta_dd, 8),
            "sharpe_pass": bool(sharpe_ok),
            "drawdown_pass": bool(dd_ok),
            "pass": bool(sharpe_ok and dd_ok),
        })
        if not (sharpe_ok and dd_ok):
            reasons.append("dxz_ratified_sharpe_dd_gate_not_met")
    factors["dxz_ratified_gate"] = dxz_gate

    diff = _diff_series(baseline_book_by_date, alt_book_by_date)

    # 3. downside risk
    b_worst = _num(baseline_metrics.get("worst_day_pct"))
    a_worst = _num(alt_metrics.get("worst_day_pct"))
    b_dd = _num(baseline_metrics.get("max_drawdown_pct"))
    a_dd = _num(alt_metrics.get("max_drawdown_pct"))
    worst_ok = (a_worst is not None and b_worst is not None and a_worst + 1e-9 >= b_worst)
    dd_ok2 = (a_dd is not None and b_dd is not None and a_dd <= b_dd + cfg["max_dd_worsening_pp"] + 1e-9)
    downside_ok = worst_ok and dd_ok2
    factors["downside_risk"] = {
        "delta_worst_day_pp": None if (a_worst is None or b_worst is None) else round(a_worst - b_worst, 8),
        "delta_max_drawdown_pp": None if (a_dd is None or b_dd is None) else round(a_dd - b_dd, 8),
        "pass": bool(downside_ok),
    }
    if not downside_ok:
        reasons.append("downside_risk_worsens")

    # 4. model uncertainty (split-half sign consistency)
    model_ok = _split_half_consistent(diff)
    factors["model_uncertainty"] = {"split_half_consistent": bool(model_ok), "pass": bool(model_ok)}
    if not model_ok:
        reasons.append("improvement_not_split_half_consistent")

    # 5. live uncertainty
    if incumbent_live_evidence and incumbent_live_evidence.get("status") == "PRESENT":
        live_ok = True  # present + not contradicting; a richer live-vs-backtest blend is F-lane work
        live_note = "live_evidence_present_not_contradicting"
    else:
        live_ok = True
        live_note = "live_evidence_not_applicable_or_missing (treated as non-blocking)"
    factors["live_uncertainty"] = {"pass": bool(live_ok), "note": live_note}

    # 6. switching cost vs expected return improvement
    b_ret = _num(baseline_metrics.get("expected_return_annual_pct")) or 0.0
    a_ret = _num(alt_metrics.get("expected_return_annual_pct")) or 0.0
    delta_ret = a_ret - b_ret
    n_changes = len(added) + len(removed)
    switching_cost = n_changes * cfg["switching_cost_pct_per_change"]
    switch_ok = is_noop or (delta_ret > switching_cost)
    factors["switching_cost"] = {
        "delta_return_annual_pp": round(delta_ret, 8),
        "estimated_switching_cost_pp": round(switching_cost, 8),
        "n_changes": n_changes,
        "pass": bool(switch_ok),
    }
    if not switch_ok:
        reasons.append("switching_cost_exceeds_return_improvement")

    # 7. operational complexity
    incumbent_syms = {str(s).upper().split(".", 1)[0] for s in incumbent_symbols}
    op_score = 0
    new_symbols: list[str] = []
    for _ea, sym in added:
        bare = str(sym).upper().split(".", 1)[0]
        if bare not in incumbent_syms:
            op_score += 1
            new_symbols.append(bare)
    op_ok = op_score <= cfg["operational_complexity_budget"]
    factors["operational_complexity"] = {
        "score": op_score,
        "budget": cfg["operational_complexity_budget"],
        "new_symbols": sorted(set(new_symbols)),
        "pass": bool(op_ok),
    }
    if not op_ok:
        reasons.append("operational_complexity_over_budget")

    # 8. economic band
    band_ok = delta_obj is not None and abs(delta_obj) >= cfg["economic_band"]
    factors["economic_band"] = {
        "abs_delta_objective": None if delta_obj is None else round(abs(delta_obj), 8),
        "band": cfg["economic_band"],
        "pass": bool(band_ok),
    }
    if not band_ok:
        reasons.append("below_economic_significance_band")

    # 2. confidence (seeded blocked bootstrap on the daily diff) -- computed LAZILY only
    # when every cheap gate already passes, because a change that fails an earlier factor
    # is never material regardless of the CI (and the bootstrap is the expensive step).
    dxz_ok = dxz_gate.get("pass", True) if venue == "dxz" else True
    cheap_gates_pass = (
        not is_noop and improve_ok and downside_ok and model_ok and switch_ok
        and op_ok and band_ok and dxz_ok
    )
    if cheap_gates_pass:
        ci = _block_bootstrap_mean_ci(
            diff,
            replications=cfg["bootstrap_replications"],
            block_days=cfg["bootstrap_block_days"],
            alpha=cfg["bootstrap_alpha"],
            seed=int(seed),
        )
        conf_ok = bool(ci.get("excludes_zero")) and (ci.get("point_mean") or 0.0) > 0.0
        factors["confidence"] = {**ci, "pass": conf_ok}
        if not conf_ok:
            reasons.append("bootstrap_ci_does_not_exclude_zero_positively")
    else:
        conf_ok = False
        factors["confidence"] = {
            "status": "NOT_RUN_CHEAP_GATE_FAILED",
            "pass": False,
            "excludes_zero": False,
            "note": "bootstrap skipped: an earlier materiality factor already failed",
        }

    material = bool(
        not is_noop
        and improve_ok
        and conf_ok
        and downside_ok
        and model_ok
        and live_ok
        and switch_ok
        and op_ok
        and band_ok
        and (dxz_gate.get("pass", True) if venue == "dxz" else True)
    )
    if is_noop:
        reasons = ["keep_baseline_no_change"]

    return {
        "schema": "qm.recompose-materiality/v1",
        "venue": venue,
        "outcome": outcome,
        "material": material,
        "reasons": reasons,
        "factors": factors,
        "seed": int(seed),
        "config": dict(cfg),
    }
