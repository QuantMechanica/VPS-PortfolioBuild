from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "strategy_risk_contract.py"
SPEC = importlib.util.spec_from_file_location("strategy_risk_contract_under_test", MODULE_PATH)
assert SPEC and SPEC.loader
rc = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = rc
SPEC.loader.exec_module(rc)


def _valid_contract(**overrides):
    contract = {
        "schema": "qm.strategy-risk-contract/v1",
        "tail_amplifying": True,
        "max_levels": 5,
        "sizing_progression": {"type": "geometric", "multiplier": "2"},
        "max_open_positions": 5,
        "max_basket_exposure": "0.5",
        "max_gross_notional": "50000",
        "max_margin_pct": 20.0,
        "max_basket_loss_pct": 1.0,
        "emergency_exit": {
            "type": "equity_stop",
            "equity_stop_pct": 8.0,
            "rule": "Flatten all legs at 1% basket loss.",
        },
        "gap_sensitivity": "NOT_EVALUATED",
        "spread_slippage_sensitivity": "NOT_EVALUATED",
        "worst_historical_sequence": {
            "max_adverse_levels": "EVIDENCE_MISSING",
            "max_drawdown_pct": "EVIDENCE_MISSING",
            "evidence": "EVIDENCE_MISSING",
        },
        "stress_sequence": {
            "scenario": "adverse trend",
            "result_pct": "EVIDENCE_MISSING",
            "evidence": "EVIDENCE_MISSING",
        },
    }
    contract.update(overrides)
    return contract


def test_tail_amplifying_set_matches_directive():
    assert rc.TAIL_AMPLIFYING_FLAGS == {
        "martingale",
        "grid",
        "bounded_grid",
        "negative_pyramiding",
        "recovery",
        "bounded_recovery",
        "unbounded_multi_position",
    }
    # Non-amplifying styles are valid flags but never require a contract.
    for benign in ("scalping", "hft", "trailing_stop", "positive_pyramiding", "anti_martingale"):
        assert benign in rc.MECHANISM_FLAGS
        assert benign not in rc.TAIL_AMPLIFYING_FLAGS


def test_positive_and_negative_pyramiding_are_distinct_tokens():
    assert "positive_pyramiding" in rc.MECHANISM_FLAGS
    assert "negative_pyramiding" in rc.MECHANISM_FLAGS
    assert "positive_pyramiding" not in rc.TAIL_AMPLIFYING_FLAGS
    assert "negative_pyramiding" in rc.TAIL_AMPLIFYING_FLAGS


def test_detect_flags_distinguishes_pyramiding_direction():
    assert rc.detect_flags_in_text("The EA adds to winners as the trend extends.") == [
        "positive_pyramiding"
    ]
    assert rc.detect_flags_in_text("The EA averages down into a losing position.") == [
        "negative_pyramiding"
    ]


def test_detect_flags_respects_negation():
    assert rc.detect_flags_in_text("No martingale, no grid, no averaging into losers.") == []
    assert rc.detect_flags_in_text("Uses a martingale scale-in.") == ["martingale"]


def test_detect_flags_anti_martingale_not_martingale():
    assert rc.detect_flags_in_text("Uses an anti-martingale scale-out.") == ["anti_martingale"]


def test_normalize_flags_rejects_unknown_tokens():
    valid, unknown = rc.normalize_flags(["Martingale", "not-a-real-flag", "grid"])
    assert valid == ["grid", "martingale"]
    assert unknown == ["not_a_real_flag"]


def test_valid_contract_has_no_errors_and_is_bounded():
    contract = _valid_contract()
    assert rc.validate_contract(contract) == []
    assert rc.is_unbounded(contract) is False


def test_zero_levels_is_unbounded():
    assert rc.is_unbounded(_valid_contract(max_levels=0)) is True


def test_levels_unbounded_flag_is_unbounded():
    assert rc.is_unbounded(_valid_contract(levels_unbounded=True)) is True


def test_no_equity_stop_is_unbounded():
    contract = _valid_contract(
        emergency_exit={"type": "none", "equity_stop_pct": None, "rule": "n/a"},
        max_basket_loss_pct="NOT_EVALUATED",
    )
    assert rc.is_unbounded(contract) is True


def test_basket_loss_bound_substitutes_for_equity_stop():
    # A positive account-loss bound is a valid portfolio-level safety boundary
    # (directive section 18) even when emergency_exit.equity_stop_pct is absent.
    contract = _valid_contract(
        emergency_exit={"type": "basket_sl", "equity_stop_pct": None, "rule": "flatten at basket loss"},
    )
    assert rc.validate_contract(contract) == []
    assert rc.is_unbounded(contract) is False


def test_missing_required_field_is_invalid():
    contract = _valid_contract()
    del contract["emergency_exit"]
    assert "emergency_exit_missing" in rc.validate_contract(contract)


def test_non_object_contract_invalid_and_unbounded():
    assert rc.validate_contract("nope") == ["contract_not_object"]
    assert rc.is_unbounded("nope") is True
