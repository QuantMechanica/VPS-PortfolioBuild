"""Focused tests for the Track D first-reward economics model.

Run: python -m pytest docs/ops/evidence/2026-09-09_ftmo_acceleration/test_track_d_economics_model.py -q
"""
from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest

MODULE_PATH = Path(__file__).with_name("track_d_economics_model.py")
spec = importlib.util.spec_from_file_location("track_d_economics_model", MODULE_PATH)
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)  # type: ignore[union-attr]


def test_breakeven_matches_illustrative_540_1600_formula_shape():
    # At reward_profit=1600*0.80=... not directly comparable to the 540/2140 illustrative
    # figure in the M13 Vorlage (that one used a *paid-challenge* R without the split
    # applied and without a marginal cost). Verify our own formula is internally
    # consistent instead: EV(p*) == 0 at the computed breakeven probability.
    for reward in (100.0, 1000.0, 10000.0):
        p_star = m.breakeven_joint_probability(reward)
        ev = m.expected_value(1.0, 1.0, p_star, reward)["ev_usd"]
        assert abs(ev) < 1e-9


def test_breakeven_probability_decreases_as_reward_increases():
    p_small = m.breakeven_joint_probability(50.0)
    p_large = m.breakeven_joint_probability(10000.0)
    assert 0.0 < p_large < p_small <= 1.0


def test_breakeven_probability_increases_with_marginal_cost():
    p_no_cost = m.breakeven_joint_probability(1000.0, marginal_cost_usd=0.0)
    p_with_cost = m.breakeven_joint_probability(1000.0, marginal_cost_usd=200.0)
    assert p_with_cost > p_no_cost


def test_expected_value_requires_explicit_probabilities_no_hidden_default():
    with pytest.raises(TypeError):
        m.expected_value(1.0, 1.0)  # type: ignore[call-arg]  # p_reward_given_pass omitted -> must fail, not default


def test_expected_value_rejects_out_of_range_probability():
    with pytest.raises(ValueError):
        m.expected_value(1.1, 1.0, 1.0, 1000.0)


def test_expected_value_below_breakeven_is_negative_above_is_positive():
    p_star = m.breakeven_joint_probability(1000.0)
    below = m.expected_value(1.0, 1.0, max(p_star - 0.05, 0.0), 1000.0)["ev_usd"]
    above = m.expected_value(1.0, 1.0, min(p_star + 0.05, 1.0), 1000.0)["ev_usd"]
    assert below < 0 < above


def test_fee_and_reward_split_match_sourced_rulepack_values():
    assert m.FEE_USD == 540.0
    assert m.REWARD_SPLIT_BASE == 0.80
    assert m.REWARD_SPLIT_SCALING == 0.90
    assert m.FEE_REFUND_PERCENT == 1.00


def test_sensitivity_table_covers_full_grid_and_is_monotonic_per_cost_level():
    rows = m.breakeven_sensitivity_table()
    assert len(rows) == len(m.REWARD_PROFIT_GRID_USD) * len(m.MARGINAL_COST_GRID_USD)
    by_cost: dict[float, list[dict]] = {}
    for row in rows:
        by_cost.setdefault(row["marginal_cost_usd"], []).append(row)
    for cost_rows in by_cost.values():
        probs = [r["breakeven_joint_probability"] for r in sorted(cost_rows, key=lambda r: r["reward_profit_usd"])]
        assert all(a >= b for a, b in zip(probs, probs[1:]))


def test_time_to_cash_floor_is_positive_and_labelled_as_lower_bound():
    floor = m.time_to_cash_floor_days()
    assert floor["floor_total_calendar_days_illustrative_lower_bound"] > 0
    assert "lower bound" in floor["note"].lower()


def test_build_report_asserts_no_hidden_probability():
    report = m.build_report()
    assert report["no_assumed_probability_asserted"] is True
    assert report["account_variant"] == "FTMO Challenge 2-Step / USD 100000 / Standard"
