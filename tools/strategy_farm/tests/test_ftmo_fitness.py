"""FTMO fitness computation, separate from DXZ fitness (directive sections 5, 57).

Slice f1_ftmo_validation_readiness.
"""
from __future__ import annotations

from tools.strategy_farm.ftmo import ftmo_fitness as ff


def _rows():
    return [
        {"sleeve": "12989:XAUUSD", "status": "SCORED", "fund_score": 0.41,
         "med60_1x": 0.82, "worst_day_1x": 1.00, "wdd_p90_1x": 1.275,
         "active_days_per_60d": 0.0},
        {"sleeve": "9936:USDJPY", "status": "SCORED", "fund_score": 0.38,
         "med60_1x": 3.10, "worst_day_1x": 1.93, "wdd_p90_1x": 8.2,
         "active_days_per_60d": 19.0},
        {"sleeve": "x:UNSCORABLE", "status": "UNSCORABLE"},
    ]


def test_venue_tag_and_no_dxz_axes():
    out = ff.compute_ftmo_fitness({"fund_scores": _rows()})
    assert out["venue"] == "ftmo"
    assert out["dxz_axes_present"] is False
    # FTMO axis set present
    for axis in (
        "challenge_survival", "p_pass", "daily_loss_survival", "max_loss_survival",
        "drift_stability", "time_to_target", "density", "cost_swap_burden",
        "payout_suitability",
    ):
        assert axis in out["fitness_axes"]
    # no DXZ-only axis leaks even if fed in the snapshot
    out2 = ff.compute_ftmo_fitness(
        {"fund_scores": _rows(), "d_score": 99, "sustainable_return": 1.2}
    )
    assert "d_score" not in out2["fitness_axes"]
    assert "sustainable_return" not in out2["fitness_axes"]
    assert out2["venue"] == "ftmo"


def test_below_floor_zero_admitted_is_not_fit():
    out = ff.compute_ftmo_fitness(
        {"fund_scores": _rows(), "q10_admission": {"total": 42, "suitable_yes": 0, "suitable_no": 42}}
    )
    assert out["overall_verdict"] == "NOT_FIT"
    assert out["admitted_pairs"] == 0
    assert out["best_fund_score"] == 0.41
    assert out["fitness_axes"]["challenge_survival"]["status"] == "FAIL"


def test_missing_evidence_degrades_not_invents():
    out = ff.compute_ftmo_fitness({})
    assert out["fitness_axes"]["p_pass"]["status"] == "EVIDENCE_MISSING"
    assert out["fitness_axes"]["daily_loss_survival"]["status"] == "EVIDENCE_MISSING"
    assert out["best_fund_score"] is None
    assert out["overall_verdict"] == "NOT_FIT"  # below floor (no evidence) is conservative


def test_demo_breach_marks_max_loss_fail():
    out = ff.compute_ftmo_fitness(
        {"fund_scores": _rows(), "demo_metrics": {"realized_max_dd_pct": -10.26, "worst_day_pct": -2.34}}
    )
    assert out["fitness_axes"]["max_loss_survival"]["status"] == "FAIL"
    assert out["fitness_axes"]["daily_loss_survival"]["status"] in ("PASS", "MARGINAL")


def test_deterministic():
    a = ff.compute_ftmo_fitness({"fund_scores": _rows()})
    b = ff.compute_ftmo_fitness({"fund_scores": _rows()})
    assert a == b
