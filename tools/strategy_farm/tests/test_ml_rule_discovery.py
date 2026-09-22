from __future__ import annotations

import datetime as dt
import json

import pytest

from tools.strategy_farm.research import ml_rule_discovery as ml
from tools.strategy_farm.research import session_features as sf


def _rows(planted: bool):
    rows = []
    for year, n in ((2020, 120), (2022, 80)):
        day = dt.date(year, 1, 2)
        made = 0
        while made < n:
            if day.weekday() < 5:
                signal = 1.0 if made % 2 == 0 else -1.0
                if planted:
                    long_r = 0.55 if signal > 0 else -0.20
                else:
                    long_r = -0.05
                rows.append({
                    "target_day": day.isoformat(),
                    "features": {
                        "own_return_atr": signal,
                        "own_range_atr": 1.0 + 0.1 * (made % 3),
                        "own_compression": 0,
                        "own_ma_regime": 1 if made % 3 else -1,
                        "target_day_of_week": day.weekday(),
                    },
                    "target_long_net_r": long_r,
                    "target_short_net_r": (-long_r - 0.02) if planted else -0.05,
                })
                made += 1
            day += dt.timedelta(days=1)
    return rows


def test_planted_effect_becomes_mechanical_candidate_after_fdr():
    tests, summary = ml.discover_group(_rows(True), "SYN|ASIA->LONDON")
    fdr = ml.apply_fdr(tests)
    survivors = [t for t in tests if t["state"] == "WORTH_MT5_TEST"]
    assert summary["threshold_feature_atoms_eligible"] > 0
    assert fdr["cutoff_rank"] > 0
    assert any(t["direction"] == "LONG" and any(a["feature"] == "own_return_atr" for a in t["atoms"]) for t in survivors)
    planted = next(
        t for t in survivors
        if t["direction"] == "LONG"
        and len(t["atoms"]) == 1
        and t["atoms"][0]["feature"] == "own_return_atr"
        and t["atoms"][0]["op"] == ">="
        and t["atoms"][0]["value"] == 0.5
    )
    robustness = ml.assess_neighboring_thresholds(planted, _rows(True))
    assert robustness["variants_evaluated"] > 0
    assert robustness["status"] == "ROBUST"


def test_null_fixture_yields_zero_survivors_after_fdr():
    tests, _ = ml.discover_group(_rows(False), "NULL|ASIA->LONDON")
    ml.apply_fdr(tests)
    assert not any(t["state"] == "WORTH_MT5_TEST" for t in tests)


def test_lookahead_assertion_fails_closed():
    with pytest.raises(AssertionError, match="LOOKAHEAD"):
        sf.assert_closed(100, 100, "equal_is_not_strictly_closed")
    with pytest.raises(AssertionError, match="LOOKAHEAD"):
        sf.assert_closed(101, 100, "bad")
    sf.assert_closed(99, 100, "strictly_before")


def test_negated_atom_fails_closed_on_missing_value():
    values = ml.np.array([1.0, 0.0, ml.np.nan])
    atom = {"feature": "x", "op": ">=", "value": 1.0, "negated": True}
    assert ml.atom_mask(values, atom).tolist() == [False, True, False]
    rule = {"schema": "qm.f2-mechanical-session-rule/v1", "all": [atom]}
    assert ml.mechanical_rule_matches(rule, {"x": 0.0})
    assert not ml.mechanical_rule_matches(rule, {"x": None})


def test_seeded_rule_generation_is_deterministic():
    first, s1 = ml.discover_group(_rows(True), "DET|ASIA->LONDON")
    second, s2 = ml.discover_group(_rows(True), "DET|ASIA->LONDON")
    assert json.dumps([first, s1], sort_keys=True) == json.dumps([second, s2], sort_keys=True)
