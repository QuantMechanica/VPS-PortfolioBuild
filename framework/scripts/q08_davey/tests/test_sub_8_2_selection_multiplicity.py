"""P0 (plan v2 A3) — optimization-track selection multiplicity in DSR.

Backward compatibility is the load-bearing property: every Q08 run that carries no
trial ledger must be bit-identical to the pre-change behaviour.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.q08_davey import sub_8_2_dsr_mc_fdr as m  # noqa: E402


def _trades(days: int, daily_pnl: float, seed: float = 0.0) -> list[dict]:
    """Deterministic daily trades: one closed trade per day, mildly varying P&L."""
    out = []
    for i in range(days):
        ts = 1_600_000_000 + i * 86_400
        pnl = daily_pnl + math.sin(i * 0.7 + seed) * daily_pnl * 0.6
        out.append({"close_time": ts, "profit": round(pnl, 4)})
    return out


PEERS = [{"ea_id": "QM5_1", "symbol": "EURUSD"}]


def test_effective_count_defaults_when_absent():
    assert m._effective_candidate_count(None) == (m.N_CANDIDATE_STRATEGIES, "fleet_default", None)


@pytest.mark.parametrize("bad", ["", "abc", None, [], {}])
def test_effective_count_defaults_on_unparseable(bad):
    n, mode, norm = m._effective_candidate_count(bad)
    assert (n, mode) == (m.N_CANDIDATE_STRATEGIES, "fleet_default")
    assert norm is None


@pytest.mark.parametrize("count", [0, 1])
def test_effective_count_defaults_below_threshold(count):
    n, mode, _ = m._effective_candidate_count(count)
    assert (n, mode) == (m.N_CANDIDATE_STRATEGIES, "fleet_default")


def test_effective_count_expands_additively_minus_self():
    n, mode, norm = m._effective_candidate_count(154)
    assert n == m.N_CANDIDATE_STRATEGIES + 153
    assert mode == "optimization_selection_expanded"
    assert norm == 154


def test_run_without_count_is_identical_to_legacy_call():
    trades = _trades(200, 55.0)
    legacy = m.run(trades=trades, portfolio=PEERS)
    explicit_none = m.run(trades=trades, portfolio=PEERS, selection_trial_count=None)
    assert legacy["status"] == explicit_none["status"]
    assert legacy["value"] == explicit_none["value"]
    assert legacy["detail"] == explicit_none["detail"]


def test_run_with_count_1_is_identical_to_no_count():
    """Firewall case: a pre-registered predicate is selected from one candidate."""
    trades = _trades(200, 55.0)
    base = m.run(trades=trades, portfolio=PEERS)
    firewalled = m.run(trades=trades, portfolio=PEERS, selection_trial_count=1)
    assert base["value"] == firewalled["value"]
    assert base["status"] == firewalled["status"]


def test_declared_count_makes_deflation_strictly_harsher():
    """A max-selected winner must face a strictly larger p-value than an unselected one."""
    trades = _trades(200, 55.0)
    base = m.run(trades=trades, portfolio=PEERS)
    deflated = m.run(trades=trades, portfolio=PEERS, selection_trial_count=154)
    assert deflated["value"] >= base["value"], "expansion must never loosen the bar"
    assert deflated["evidence"]["n_candidate_strategies"] > base["evidence"]["n_candidate_strategies"]
    assert deflated["evidence"]["selection_mode"] == "optimization_selection_expanded"
    assert deflated["evidence"]["selection_trial_count"] == 154


def test_evidence_carries_uncalibrated_sharpe_std_flag():
    """Every cohort-mode verdict must surface the known sharpe_std limitation."""
    trades = _trades(200, 55.0)
    res = m.run(trades=trades, portfolio=PEERS, selection_trial_count=154)
    assert res["evidence"]["sharpe_std_calibrated"] is False
    assert res["evidence"]["sharpe_std_estimate"] == 1.0


def test_no_cohort_path_ignores_selection_count():
    """Trivial-pass path (no peers) must not be perturbed by the new kwarg."""
    trades = _trades(200, 55.0)
    a = m.run(trades=trades, portfolio=[])
    b = m.run(trades=trades, portfolio=[], selection_trial_count=154)
    assert a["status"] == b["status"] == "PASS"
    assert a["detail"] == b["detail"]


def test_insufficient_returns_still_invalid_with_count():
    res = m.run(trades=_trades(10, 55.0), portfolio=PEERS, selection_trial_count=154)
    assert res["status"] == "INVALID"
