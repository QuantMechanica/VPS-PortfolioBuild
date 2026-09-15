"""Map the assessed alternatives to the section 6 weekly outcome + section 58 object.

Valid section 6 outcomes:
``KEEP`` / ``ADD_SLEEVE`` / ``REMOVE_SLEEVE`` / ``REPLACE_SLEEVE`` /
``CHANGE_RISK_WEIGHT`` / ``PLACE_ON_PROBATION`` / ``PROMOTE`` / ``RETIRE`` /
``CONTINUE_OBSERVATION`` / ``NO_VALID_CHANGE``.

The weekly default is KEEP (directive section 4/6): a change is proposed only when a
material alternative exists (``materiality.material == True``).  When the venue fitness
could not be evaluated at all (e.g. FTMO before slice F1 lands, or an empty pool), the
outcome degrades to ``NO_VALID_CHANGE`` / ``CONTINUE_OBSERVATION`` rather than a false KEEP.
"""
from __future__ import annotations

from typing import Any, Mapping, Sequence

VALID_OUTCOMES = {
    "KEEP",
    "ADD_SLEEVE",
    "REMOVE_SLEEVE",
    "REPLACE_SLEEVE",
    "CHANGE_RISK_WEIGHT",
    "PLACE_ON_PROBATION",
    "PROMOTE",
    "RETIRE",
    "CONTINUE_OBSERVATION",
    "NO_VALID_CHANGE",
}


def _num(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def decide(
    *,
    venue: str,
    baseline_metrics: Mapping[str, Any],
    baseline_fitness: Mapping[str, Any],
    assessed_alternatives: Sequence[Mapping[str, Any]],
    fitness_evaluated: bool,
    challengers_available: bool,
) -> dict[str, Any]:
    """Return the section 58 proposal object for a venue."""
    material = [
        a for a in assessed_alternatives if a.get("materiality", {}).get("material") is True
    ]
    material.sort(
        key=lambda a: (
            -( _num(a["materiality"]["factors"].get("delta_objective")) or float("-inf") ),
            a.get("label", ""),
        )
    )

    if not fitness_evaluated:
        outcome = "CONTINUE_OBSERVATION" if challengers_available else "NO_VALID_CHANGE"
        return {
            "outcome": outcome,
            "changes": [],
            "expected_metrics": _expected(baseline_metrics),
            "materiality": {
                "material": False,
                "reasons": ["venue_fitness_not_evaluated"],
            },
            "confidence": "NOT_EVALUATED",
            "operational_risk": "NOT_EVALUATED",
            "selected_alternative": None,
        }

    if not material:
        return {
            "outcome": "KEEP",
            "changes": [],
            "expected_metrics": _expected(baseline_metrics),
            "materiality": {
                "material": False,
                "reasons": ["no_material_alternative_default_keep"],
                "n_alternatives_evaluated": len(assessed_alternatives),
            },
            "confidence": "N/A_KEEP",
            "operational_risk": "N/A_KEEP",
            "selected_alternative": None,
        }

    best = material[0]
    change = best.get("change", {})
    outcome = str(change.get("outcome", "KEEP"))
    if outcome not in VALID_OUTCOMES:
        outcome = "KEEP"
    factors = best["materiality"]["factors"]
    return {
        "outcome": outcome,
        "changes": [change],
        "expected_metrics": _expected(best.get("metrics", {})),
        "expected_metrics_incumbent": _expected(baseline_metrics),
        "materiality": {
            "material": True,
            "delta_objective": factors.get("delta_objective"),
            "reasons": ["material_alternative_selected"],
            "detail": best["materiality"],
        },
        "confidence": factors.get("confidence"),
        "operational_risk": factors.get("operational_complexity"),
        "selected_alternative": best.get("label"),
    }


def _expected(metrics: Mapping[str, Any]) -> dict[str, Any]:
    keep = (
        "expected_return_annual_pct",
        "volatility_annual_pct",
        "max_drawdown_pct",
        "worst_day_pct",
        "tail_loss_es5_pct",
        "sharpe",
        "return_to_maxdd",
        "effective_number_of_bets",
        "mean_abs_pairwise_correlation",
        "mean_abs_downside_correlation",
        "n_sleeves",
        "total_risk_pct",
    )
    return {k: metrics.get(k) for k in keep if k in metrics}
