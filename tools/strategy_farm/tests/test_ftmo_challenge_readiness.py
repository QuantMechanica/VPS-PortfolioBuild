"""FTMO Challenge readiness enum mapping + assembly (directive sections 62-63).

Slice f1_ftmo_validation_readiness.
"""
from __future__ import annotations

import datetime as dt

from tools.strategy_farm.ftmo import challenge_readiness as cr


def _fit(overall, admitted, best, floor=1.0):
    return {
        "overall_verdict": overall,
        "admitted_pairs": admitted,
        "best_fund_score": best,
        "fund_score_floor": floor,
        "fitness_axes": {},
    }


def test_blockers_force_not_ready():
    rec, why = cr.map_recommendation(
        blockers=["Rule snapshot is 45 days old."],
        fitness=_fit("NOT_FIT", 0, 0.41),
        representative=False,
        demo_metrics=None,
        first_passage=None,
    )
    assert rec == "NOT_READY"
    assert "blocker" in why.lower()


def test_no_candidate_is_not_ready():
    rec, _ = cr.map_recommendation(
        blockers=[],
        fitness=_fit("NOT_FIT", 0, 0.41),
        representative=False,
        demo_metrics=None,
        first_passage=None,
    )
    assert rec == "NOT_READY"


def test_realized_breach_is_not_ready():
    rec, why = cr.map_recommendation(
        blockers=[],
        fitness=_fit("NOT_FIT", 5, 1.4),  # candidates exist...
        representative=True,
        demo_metrics={"cycles": [{"realized_max_dd_pct": -10.26}], "latest_cycle": {}},
        first_passage=None,
    )
    assert rec == "NOT_READY"
    assert "breach" in why.lower()


def test_not_fit_with_candidates_recomposes():
    rec, _ = cr.map_recommendation(
        blockers=[],
        fitness=_fit("NOT_FIT", 5, 1.4),
        representative=True,
        demo_metrics={"cycles": [{"realized_max_dd_pct": -3.0}], "latest_cycle": {}},
        first_passage=None,
    )
    assert rec == "RECOMPOSE"


def test_fit_not_representative_continues_demo():
    rec, _ = cr.map_recommendation(
        blockers=[],
        fitness=_fit("FIT", 5, 1.4),
        representative=False,
        demo_metrics={"cycles": [], "latest_cycle": {}},
        first_passage=None,
    )
    assert rec == "CONTINUE_DEMO"


def test_fit_representative_high_pass_recommends_buy():
    rec, why = cr.map_recommendation(
        blockers=[],
        fitness=_fit("FIT", 5, 1.5),
        representative=True,
        demo_metrics={"cycles": [{"realized_max_dd_pct": -3.0}], "latest_cycle": {}},
        first_passage={"p_pass_60d": 0.85},
    )
    assert rec == "BUY_100K_2STEP_RECOMMENDED"


def test_fit_representative_mid_pass_owner_review():
    rec, _ = cr.map_recommendation(
        blockers=[],
        fitness=_fit("FIT", 5, 1.5),
        representative=True,
        demo_metrics={"cycles": [{"realized_max_dd_pct": -3.0}], "latest_cycle": {}},
        first_passage={"p_pass_60d": 0.74},
    )
    assert rec == "READY_FOR_OWNER_REVIEW"


def test_recommendation_is_in_enum_always():
    for rep in (True, False):
        for fit in ("FIT", "NOT_FIT", "INSUFFICIENT_EVIDENCE"):
            rec, _ = cr.map_recommendation(
                blockers=[],
                fitness=_fit(fit, 3, 1.2),
                representative=rep,
                demo_metrics={"cycles": [], "latest_cycle": {}},
                first_passage=None,
            )
            assert rec in cr.RECOMMENDATIONS


def test_build_readiness_offline_smoke(tmp_path):
    """No terminal / no cache -> deterministic degraded read-model, valid schema."""
    out = tmp_path / "ftmo_challenge_readiness.json"
    model = cr.build_readiness(
        out=out,
        fund_score_cache=tmp_path / "missing_cache.json",
        demo_cycle_path=tmp_path / "missing_ledger.json",
        terminal_dir=tmp_path / "no_terminal",
        journal_path=tmp_path / "no_journal.csv",
        now=dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc),
        write=False,
    )
    assert model["schema"] == cr.SCHEMA
    assert model["recommendation"] in cr.RECOMMENDATIONS
    assert model["would_fable_buy_today"]["answer"] is False
    # venue fitness is FTMO and separate
    assert model["fitness"]["venue"] == "ftmo"
    # demo journal missing -> evidence missing, not invented
    assert model["demo_metrics_detail"]["status"] == "EVIDENCE_MISSING"
