"""FTMO fitness computation, separate from DXZ fitness (directive sections 5, 57).

`compute_ftmo_fitness(snapshot) -> dict` scores the FTMO-specific axes only:
Challenge survival, probability of pass, daily-loss survival, total-loss
survival, drift stability, time-to-target (secondary), trade density, cost/swap
burden, payout suitability. It is deterministic and degrades every axis it
cannot evidence to NOT_EVALUATED / EVIDENCE_MISSING rather than inventing a
number. It never emits DXZ optimization axes (sustainable_return, D-Score,
capital_attraction, ...): FTMO fitness is a distinct axis from DXZ fitness.

It reuses the established FUND_SCORE cache and, when available, first-passage
outputs; it does not re-implement rolling-window or first-passage math.
"""
from __future__ import annotations

import statistics
from typing import Any

VENUE = "ftmo"
DEFAULT_FUND_SCORE_FLOOR = 1.0

# Axes that belong to DXZ fitness and must never leak into an FTMO result.
_DXZ_ONLY_AXES = frozenset(
    {
        "sustainable_return",
        "d_score",
        "d_score_suitability",
        "capital_attraction",
        "long_term_capital_attraction",
        "allocation_suitability",
    }
)

_MISSING = "EVIDENCE_MISSING"
_NOT_EVAL = "NOT_EVALUATED"


def _axis(status: str, value: Any = None, basis: str = "") -> dict[str, Any]:
    return {"status": status, "value": value, "basis": basis}


def _scored_rows(rows: list[dict[str, Any]] | None) -> list[dict[str, Any]]:
    return [r for r in (rows or []) if r.get("status") == "SCORED" and r.get("fund_score") is not None]


def compute_ftmo_fitness(snapshot: dict[str, Any]) -> dict[str, Any]:
    """Compute FTMO fitness from an evidence snapshot dict.

    Recognised snapshot keys (all optional; absence -> degraded axis):
      fund_scores        list of FUND_SCORE rows (fund_scores.json 'rows')
      fund_score_floor   admission floor (default 1.0)
      q10_admission      {total, suitable_yes, suitable_no, reason_counts}
      demo_metrics       {net_pct, worst_day_pct, realized_max_dd_pct, ...} per cycle/account
      first_passage      {p_pass_30d, p_pass_60d, median_days, p_daily_loss_breach, p_max_loss_breach}
      go_criteria        rulepack evaluation_profile.go_criteria (for context only)
    """
    snapshot = snapshot or {}
    floor = float(snapshot.get("fund_score_floor", DEFAULT_FUND_SCORE_FLOOR))
    rows = snapshot.get("fund_scores")
    scored = _scored_rows(rows)

    fund_score_by_sleeve = {
        r["sleeve"]: round(float(r["fund_score"]), 4) for r in scored
    }
    best_fund_score = max(fund_score_by_sleeve.values()) if fund_score_by_sleeve else None
    n_at_floor = sum(1 for v in fund_score_by_sleeve.values() if v >= floor)

    # --- Q10 admitted pairs ---
    q10 = snapshot.get("q10_admission")
    if isinstance(q10, dict) and "suitable_yes" in q10:
        admitted_pairs = int(q10.get("suitable_yes") or 0)
        admitted_basis = f"Q10 FTMO gate: {admitted_pairs}/{q10.get('total', '?')} suitable"
    else:
        admitted_pairs = _MISSING
        admitted_basis = "Q10 FTMO admission evidence not supplied"

    demo = snapshot.get("demo_metrics") if isinstance(snapshot.get("demo_metrics"), dict) else None
    fp = snapshot.get("first_passage") if isinstance(snapshot.get("first_passage"), dict) else None

    axes: dict[str, dict[str, Any]] = {}

    # Challenge survival: gated by admitted pairs AND fund score vs floor.
    if admitted_pairs == _MISSING and best_fund_score is None:
        axes["challenge_survival"] = _axis(_MISSING, None, "no admission or FUND_SCORE evidence")
    else:
        adm_zero = admitted_pairs == 0 or (isinstance(admitted_pairs, str))
        below_floor = best_fund_score is None or best_fund_score < floor
        if (isinstance(admitted_pairs, int) and admitted_pairs > 0) and not below_floor:
            status = "PASS"
        elif not below_floor:
            status = "MARGINAL"
        else:
            status = "FAIL"
        axes["challenge_survival"] = _axis(
            status,
            {
                "admitted_pairs": admitted_pairs,
                "best_fund_score": best_fund_score,
                "fund_score_floor": floor,
                "sleeves_at_or_above_floor": n_at_floor,
            },
            "0 admitted / best FUND_SCORE below floor => not survivable"
            if status == "FAIL"
            else admitted_basis,
        )

    # Probability of pass (first-passage): evidence-only.
    if fp and any(k in fp for k in ("p_pass_30d", "p_pass_60d")):
        axes["p_pass"] = _axis(
            "EVALUATED",
            {k: fp.get(k) for k in ("p_pass_30d", "p_pass_60d")},
            "first-passage simulation supplied",
        )
    else:
        axes["p_pass"] = _axis(
            _MISSING,
            None,
            "no CONFIG_LOCKED FTMO first-passage evidence (engine present, no FTMO-locked inputs)",
        )

    # Daily-loss survival: demo realized worst day vs 5% limit, else FUND_SCORE worst_day proxy.
    if demo and demo.get("worst_day_pct") is not None:
        wd = abs(float(demo["worst_day_pct"]))
        status = "FAIL" if wd >= 5.0 else ("MARGINAL" if wd >= 3.5 else "PASS")
        axes["daily_loss_survival"] = _axis(
            status, {"worst_day_pct": wd, "limit_pct": 5.0}, "demo realized worst day vs FTMO 5% daily limit"
        )
    elif scored:
        worst = max(abs(float(r.get("worst_day_1x") or 0.0)) for r in scored)
        axes["daily_loss_survival"] = _axis(
            "PROXY",
            {"worst_day_1x_max": round(worst, 4)},
            "FUND_SCORE worst_day_1x proxy (not a rule-faithful daily-loss simulation)",
        )
    else:
        axes["daily_loss_survival"] = _axis(_MISSING, None, "no daily-loss evidence")

    # Total-loss survival: demo realized max-DD vs 10% static limit.
    if demo and demo.get("realized_max_dd_pct") is not None:
        dd = abs(float(demo["realized_max_dd_pct"]))
        status = "FAIL" if dd >= 10.0 else ("MARGINAL" if dd >= 7.0 else "PASS")
        axes["max_loss_survival"] = _axis(
            status, {"realized_max_dd_pct": dd, "limit_pct": 10.0}, "demo realized max-DD vs FTMO 10% total-loss limit"
        )
    else:
        axes["max_loss_survival"] = _axis(_MISSING, None, "no total-loss evidence")

    # Drift stability: sign/level of median 60d gains across the population.
    if scored:
        meds = [float(r.get("med60_1x") or 0.0) for r in scored]
        pos = sum(1 for m in meds if m > 0)
        axes["drift_stability"] = _axis(
            "EVALUATED",
            {
                "median_med60_1x": round(statistics.median(meds), 4),
                "positive_share": round(pos / len(meds), 4),
            },
            "median 60-day gain distribution across scored sleeves",
        )
    else:
        axes["drift_stability"] = _axis(_MISSING, None, "no scored sleeves")

    # Time-to-target: secondary; only if first-passage median present.
    if fp and fp.get("median_days") is not None:
        axes["time_to_target"] = _axis(
            "EVALUATED", {"median_days": fp.get("median_days")}, "secondary objective"
        )
    else:
        axes["time_to_target"] = _axis(_NOT_EVAL, None, "secondary; no first-passage median")

    # Trade density.
    dens = [
        float(r["active_days_per_60d"])
        for r in scored
        if r.get("active_days_per_60d") is not None
    ]
    if dens:
        axes["density"] = _axis(
            "EVALUATED",
            {"median_active_days_per_60d": round(statistics.median(dens), 3), "max": round(max(dens), 3)},
            "active trading days per 60d window",
        )
    else:
        axes["density"] = _axis(_MISSING, None, "no active-day evidence")

    # Cost / swap burden and payout suitability need dedicated inputs.
    axes["cost_swap_burden"] = (
        _axis("EVALUATED", snapshot["cost_swap"], "supplied cost/swap snapshot")
        if isinstance(snapshot.get("cost_swap"), dict)
        else _axis(_NOT_EVAL, None, "no per-symbol FTMO cost/swap snapshot supplied")
    )
    axes["payout_suitability"] = (
        _axis("EVALUATED", snapshot["payout"], "supplied payout model")
        if isinstance(snapshot.get("payout"), dict)
        else _axis(_NOT_EVAL, None, "funded-account payout model not supplied")
    )

    # --- overall verdict (deterministic) ---
    hard_axes = ("challenge_survival", "daily_loss_survival", "max_loss_survival")
    any_fail = any(axes[a]["status"] == "FAIL" for a in hard_axes)
    zero_admitted = isinstance(admitted_pairs, int) and admitted_pairs == 0
    below_floor = best_fund_score is None or best_fund_score < floor
    if any_fail or zero_admitted or below_floor:
        overall = "NOT_FIT"
    elif all(axes[a]["status"] in ("PASS", "EVALUATED") for a in hard_axes):
        overall = "FIT"
    else:
        overall = "INSUFFICIENT_EVIDENCE"

    result = {
        "venue": VENUE,
        "fitness_axes": axes,
        "fund_score_by_sleeve": fund_score_by_sleeve,
        "best_fund_score": best_fund_score,
        "fund_score_floor": floor,
        "admitted_pairs": admitted_pairs,
        "overall_verdict": overall,
        "dxz_axes_present": False,
    }
    # Defensive: guarantee no DXZ-only axis leaked in.
    assert _DXZ_ONLY_AXES.isdisjoint(result["fitness_axes"].keys()), "DXZ axis leaked into FTMO fitness"
    return result
