"""Unit tests for the Q11/Q15 portfolio fit report generator (tool gap G2).

Synthetic daily series with a KNOWN correlation reproduce the pairwise matrix and
the effective number of bets (ENB); pairs below the 60-day overlap floor are marked
NOT_EVALUABLE and never given a fabricated number; and every cap check
(|r| < 0.5 / family <= 3 / symbol <= 2 / 10-15 EAs) fires on the right side of its
threshold.  Marginal Sharpe is checked against an independent statistics recompute so
the leave-one-out wiring (fixed union grid, equal weight) is verified rather than a
magic constant.
"""
from __future__ import annotations

import datetime as dt
import statistics

import pytest

from tools.strategy_farm import q15_fit_report as fit


def _days(n: int) -> list[dt.date]:
    base = dt.date(2024, 1, 1)
    return [base + dt.timedelta(days=i) for i in range(n)]


# --------------------------------------------------------------- correlation + ENB
def test_correlation_matrix_and_enb_perfect_collinear():
    days = _days(80)
    a = {d: float(i + 1) for i, d in enumerate(days)}
    b = {d: 2.0 * (i + 1) for i, d in enumerate(days)}
    c = {d: -1.0 * (i + 1) for i, d in enumerate(days)}
    sbk = {(1, "AAA"): a, (2, "BBB"): b, (3, "CCC"): c}

    corr = fit.correlation_block(sbk, min_overlap_days=60)
    m = corr["matrix"]
    # keys sort to (1,AAA),(2,BBB),(3,CCC) -> indices 0,1,2
    assert m[0][1] == pytest.approx(1.0)     # A vs B (B = 2A)
    assert m[0][2] == pytest.approx(-1.0)    # A vs C (C = -A)
    assert m[1][2] == pytest.approx(-1.0)    # B vs C
    assert corr["not_evaluable_pairs"] == []
    # every pair is co-active on all 80 days
    assert all(p["overlap_days"] == 80 for p in corr["evaluable_pairs"])

    enb = fit.compute_enb(m)
    assert enb["status"] == "OK"
    # perfectly collinear members -> a single effective bet
    assert enb["value"] == pytest.approx(1.0)


def test_correlation_matrix_and_enb_orthogonal():
    days = _days(80)
    # A: period-2 contrast [+1,-1]; B: period-4 contrast [+1,+1,-1,-1] -> exact r=0
    a = {d: (1.0 if i % 2 == 0 else -1.0) for i, d in enumerate(days)}
    b = {d: (1.0 if (i % 4) < 2 else -1.0) for i, d in enumerate(days)}
    sbk = {(1, "AAA"): a, (2, "BBB"): b}

    corr = fit.correlation_block(sbk, min_overlap_days=60)
    assert corr["matrix"][0][1] == pytest.approx(0.0, abs=1e-9)
    assert corr["not_evaluable_pairs"] == []

    enb = fit.compute_enb(corr["matrix"])
    assert enb["status"] == "OK"
    # two uncorrelated members -> two effective bets
    assert enb["value"] == pytest.approx(2.0)
    assert enb["sum_lambda_squared_frobenius"] == pytest.approx(2.0)


# ------------------------------------------------------------------- below floor
def test_below_floor_pairs_marked_not_evaluable():
    days = _days(10)  # only 10 co-active days, below the 60-day floor
    a = {d: float(i + 1) for i, d in enumerate(days)}
    b = {d: 2.0 * (i + 1) for i, d in enumerate(days)}
    sbk = {(1, "AAA"): a, (2, "BBB"): b}

    corr = fit.correlation_block(sbk, min_overlap_days=60)
    assert corr["matrix"][0][1] is None
    assert len(corr["not_evaluable_pairs"]) == 1
    assert corr["not_evaluable_pairs"][0]["overlap_days"] == 10
    assert corr["evaluable_pairs"] == []

    enb = fit.compute_enb(corr["matrix"])
    assert enb["status"] == "NOT_EVALUABLE"
    assert enb["value"] is None
    assert "overlap floor" in enb["reason"]


def test_enb_not_evaluable_when_any_single_pair_missing():
    # Three members: two pairs dense/evaluable, one pair below floor -> ENB NOT_EVALUABLE.
    dense = _days(80)
    sparse = _days(5)
    a = {d: float(i + 1) for i, d in enumerate(dense)}
    b = {d: 2.0 * (i + 1) for i, d in enumerate(dense)}
    c = {d: float(i + 1) for i, d in enumerate(sparse)}  # overlaps A/B on only 5 days
    sbk = {(1, "AAA"): a, (2, "BBB"): b, (3, "CCC"): c}

    corr = fit.correlation_block(sbk, min_overlap_days=60)
    # A-B evaluable, A-C and B-C below floor
    assert corr["matrix"][0][1] is not None
    assert corr["matrix"][0][2] is None
    assert corr["matrix"][1][2] is None
    enb = fit.compute_enb(corr["matrix"])
    assert enb["status"] == "NOT_EVALUABLE"


# --------------------------------------------------------------- correlation cap
def test_correlation_cap_breach_pass_and_not_assertable():
    breach = {
        "evaluable_pairs": [{"pair": ["1:A", "2:B"], "overlap_days": 70, "r": 0.8}],
        "not_evaluable_pairs": [],
    }
    b = fit.correlation_cap_block(breach)
    assert b["status"] == "BREACH"
    assert b["breaches"][0]["abs_r"] == pytest.approx(0.8)

    neg_breach = {
        "evaluable_pairs": [{"pair": ["1:A", "2:B"], "overlap_days": 70, "r": -0.6}],
        "not_evaluable_pairs": [],
    }
    assert fit.correlation_cap_block(neg_breach)["status"] == "BREACH"

    passing = {
        "evaluable_pairs": [{"pair": ["1:A", "2:B"], "overlap_days": 70, "r": 0.3}],
        "not_evaluable_pairs": [],
    }
    assert fit.correlation_cap_block(passing)["status"] == "PASS"

    none_eval = {
        "evaluable_pairs": [],
        "not_evaluable_pairs": [{"pair": ["1:A", "2:B"], "overlap_days": 5}],
    }
    assert fit.correlation_cap_block(none_eval)["status"] == "NOT_ASSERTABLE"

    partial = {
        "evaluable_pairs": [{"pair": ["1:A", "2:B"], "overlap_days": 70, "r": 0.1}],
        "not_evaluable_pairs": [{"pair": ["1:A", "3:C"], "overlap_days": 5}],
    }
    assert fit.correlation_cap_block(partial)["status"] == "PARTIAL"


# ------------------------------------------------------------- family / symbol cap
def test_family_and_symbol_caps_fire():
    keys = [(1, "EURUSD.DWX"), (2, "EURUSD.DWX"), (3, "EURUSD.DWX"), (4, "GBPUSD.DWX")]
    asset_of = {k: "fx" for k in keys}
    family_of = {
        (1, "EURUSD.DWX"): "tv",
        (2, "EURUSD.DWX"): "tv",
        (3, "EURUSD.DWX"): "tv",
        (4, "GBPUSD.DWX"): "ohlc",
    }
    cov = fit.coverage_block(keys, family_of, asset_of)
    # EURUSD.DWX carries 3 members > symbol cap 2 -> BREACH
    assert cov["symbol_cap"]["status"] == "BREACH"
    # family 'tv' has exactly 3 members == cap 3 -> PASS (cap is <= 3)
    assert cov["family_cap"]["status"] == "PASS"

    family_over = dict(family_of)
    family_over[(4, "GBPUSD.DWX")] = "tv"  # tv now 4 members > cap 3
    cov2 = fit.coverage_block(keys, family_over, asset_of)
    assert cov2["family_cap"]["status"] == "BREACH"

    # a within-cap book passes both
    small = [(1, "EURUSD.DWX"), (2, "GBPUSD.DWX")]
    fam_small = {(1, "EURUSD.DWX"): "tv", (2, "GBPUSD.DWX"): "ohlc"}
    asset_small = {(1, "EURUSD.DWX"): "fx", (2, "GBPUSD.DWX"): "fx"}
    cov3 = fit.coverage_block(small, fam_small, asset_small)
    assert cov3["symbol_cap"]["status"] == "PASS"
    assert cov3["family_cap"]["status"] == "PASS"
    assert cov3["asset_class_coverage"]["distinct_asset_classes"] == 1


def test_book_size_band():
    assert fit.book_size_block(5)["status"] == "BELOW_BAND"
    assert fit.book_size_block(10)["status"] == "PASS"
    assert fit.book_size_block(12)["status"] == "PASS"
    assert fit.book_size_block(15)["status"] == "PASS"
    assert fit.book_size_block(20)["status"] == "BREACH"


# -------------------------------------------------------------- marginal Sharpe
def _sharpe(series):
    if len(series) < 2:
        return None
    sd = statistics.stdev(series)
    return None if sd == 0.0 else statistics.mean(series) / sd


def test_marginal_sharpe_leave_one_out_on_fixed_union_grid():
    days = _days(4)
    a = {days[0]: 1.0, days[1]: 2.0, days[2]: 3.0}       # active days 0,1,2
    b = {days[1]: 2.0, days[2]: 1.0, days[3]: 4.0}       # active days 1,2,3
    sbk = {(1, "A"): a, (2, "B"): b}

    block = fit.marginal_sharpe_block(sbk)
    grid = sorted(set(a) | set(b))
    pooled = [a.get(d, 0.0) + b.get(d, 0.0) for d in grid]   # [1,4,4,4]
    exp_pool = _sharpe(pooled)
    assert block["n_union_days"] == 4
    assert block["pool_sharpe_daily"] == pytest.approx(round(exp_pool, 8))

    loo_a = [pooled[i] - a.get(d, 0.0) for i, d in enumerate(grid)]  # B on the fixed grid
    exp_loo_a = _sharpe(loo_a)
    exp_marg_a = round(exp_pool - exp_loo_a, 8)
    member_a = next(m for m in block["members"] if m["key"] == "1:A")
    assert member_a["leave_one_out_sharpe_daily"] == pytest.approx(round(exp_loo_a, 8))
    assert member_a["marginal_sharpe_daily"] == pytest.approx(exp_marg_a)

    loo_b = [pooled[i] - b.get(d, 0.0) for i, d in enumerate(grid)]
    exp_marg_b = round(exp_pool - _sharpe(loo_b), 8)
    member_b = next(m for m in block["members"] if m["key"] == "2:B")
    assert member_b["marginal_sharpe_daily"] == pytest.approx(exp_marg_b)


def test_marginal_sharpe_none_when_leave_one_out_is_constant():
    days = _days(4)
    a = {d: float(i + 1) for i, d in enumerate(days)}   # [1,2,3,4]
    b = {d: 1.0 for d in days}                          # constant -> stdev 0
    sbk = {(1, "A"): a, (2, "B"): b}
    block = fit.marginal_sharpe_block(sbk)
    # dropping A leaves the constant series B -> LOO Sharpe undefined -> marginal None
    member_a = next(m for m in block["members"] if m["key"] == "1:A")
    assert member_a["leave_one_out_sharpe_daily"] is None
    assert member_a["marginal_sharpe_daily"] is None


# ----------------------------------------------------------------- provenance
def test_threshold_provenance_cites_source_files():
    prov = fit.THRESHOLD_PROVENANCE
    assert prov["min_overlap_days"]["value"] == 60
    assert prov["correlation_cap_abs_r"]["value"] == 0.5
    assert prov["family_cap_members"]["value"] == 3
    assert prov["symbol_cap_members"]["value"] == 2
    assert prov["book_size_band_eas"]["value"] == [10, 15]
    for entry in prov.values():
        assert entry["source"].strip()
