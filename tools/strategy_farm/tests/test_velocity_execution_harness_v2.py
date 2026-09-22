from __future__ import annotations

import datetime as dt
import hashlib
import sys
from pathlib import Path

import pytest

SESSION_TOOLS = Path("C:/QM/repo/tools/strategy_farm/session_tools")
sys.path.insert(0, str(SESSION_TOOLS))

from velocity_execution_harness_v2_0922 import (  # noqa: E402
    CUSTOM_SYMBOL_CATALOG,
    SymbolExecutionSpec,
    TickQuote,
    deterministic_json_bytes,
    infer_point_from_prices,
    pending_stop_fill,
    protective_stop_fill,
    quotes_at_or_after,
    target_fill,
    tester_execution_spec as load_tester_execution_spec,
    validate_oco_placement,
)
from velocity_family_f1_sweep_0921 import (  # noqa: E402
    RELEASE_NATIVE_CSV,
    high_impact_at_anchor,
    load_release_anchors,
)


def _epoch(text: str) -> int:
    return int(dt.datetime.fromisoformat(text).replace(tzinfo=dt.timezone.utc).timestamp())


def _spec() -> SymbolExecutionSpec:
    return SymbolExecutionSpec("USDJPY.DWX", 0.001, 0, 0, "fixture", "0" * 64, "0" * 64)


def test_release_tick_one_sided_pair_is_cancelled() -> None:
    spec = _spec()
    quote = TickQuote(_epoch("2024-04-10T15:30:00"), 1712763000171, 151.790, 151.858, "fixture")
    decision = validate_oco_placement(151.854, 151.774, quote, spec)
    assert decision.status == "CANCEL_NO_TRADE_ONE_SIDED"
    assert decision.buy_ok is False
    assert decision.sell_ok is True
    assert decision.pair_accepted is False


def test_gap_through_uses_first_available_m1_price() -> None:
    assert pending_stop_fill(+1, 100.0, 100.5, 101.0, 100.4) == 100.5
    assert pending_stop_fill(-1, 100.0, 99.5, 99.6, 99.0) == 99.5
    assert protective_stop_fill(+1, 99.0, 98.5, 99.2, 98.0) == 98.5
    assert protective_stop_fill(-1, 101.0, 101.5, 102.0, 101.2) == 101.5
    assert target_fill(+1, 101.0, 101.5, 102.0, 101.2) == 101.5
    assert target_fill(-1, 99.0, 98.5, 99.0, 98.0) == 98.5


def test_no_gap_fills_at_level_and_non_touch_is_none() -> None:
    assert pending_stop_fill(+1, 100.0, 99.5, 100.2, 99.4) == 100.0
    assert protective_stop_fill(+1, 99.0, 100.0, 100.2, 98.9) == 99.0
    assert pending_stop_fill(+1, 100.0, 99.5, 99.9, 99.4) is None


def test_pending_stop_must_be_strictly_beyond_bid_or_ask() -> None:
    spec = _spec()
    quote = TickQuote(0, 0, 151.790, 151.858, "fixture")
    decision = validate_oco_placement(151.858, 151.790, quote, spec)
    assert decision.status == "CANCEL_NO_TRADE_BOTH_INVALID"
    assert decision.buy_ok is False
    assert decision.sell_ok is False


def test_stop_and_freeze_distance_use_the_governing_maximum() -> None:
    spec = SymbolExecutionSpec("FIXTURE.DWX", 0.001, 5, 10, "fixture", "0" * 64, "0" * 64)
    quote = TickQuote(0, 0, 100.000, 100.002, "fixture")
    accepted = validate_oco_placement(100.012, 99.990, quote, spec)
    too_close = validate_oco_placement(100.011, 99.991, quote, spec)
    assert spec.minimum_distance == pytest.approx(0.010)
    assert accepted.status == "PAIR_ACCEPTED"
    assert too_close.status == "CANCEL_NO_TRADE_BOTH_INVALID"


def test_price_precision_is_data_derived() -> None:
    assert infer_point_from_prices([151.790, 151.858, 152.001]) == pytest.approx(0.001)
    assert infer_point_from_prices([1.07451, 1.07468, 1.07500]) == pytest.approx(0.00001)


def test_real_tkc_quotes_match_bound_tester_log_pairs() -> None:
    archive = Path("D:/QM/mt5/T1/Bases/Custom/ticks/USDJPY.DWX/202404.tkc")
    if not archive.is_file():
        pytest.skip("governed USDJPY TKC archive not mounted")
    april = _epoch("2024-04-10T15:30:00")
    july = _epoch("2024-07-11T15:30:00")
    quotes = quotes_at_or_after("USDJPY.DWX", [april, july])
    assert (quotes[april].bid, quotes[april].ask) == pytest.approx((151.790, 151.858))
    assert (quotes[july].bid, quotes[july].ask) == pytest.approx((161.532, 161.761))


def test_native_calendar_tags_known_0830_new_york_releases() -> None:
    if not RELEASE_NATIVE_CSV.is_file():
        pytest.skip("governed native USD-high calendar export not mounted")
    anchors = load_release_anchors()
    assert len(anchors) > 800  # complete 2018-2025 native export, not the smaller matched-join audit
    assert high_impact_at_anchor(anchors, _epoch("2024-04-10T12:30:00"))
    assert high_impact_at_anchor(anchors, _epoch("2024-07-11T12:30:00"))
    assert not high_impact_at_anchor(anchors, _epoch("2024-07-11T11:30:00"))


def test_governed_execution_spec_is_hash_bound() -> None:
    if not CUSTOM_SYMBOL_CATALOG.is_file():
        pytest.skip("governed custom-symbol catalogue not mounted")
    spec = load_tester_execution_spec("USDJPY.DWX", 0.001)
    assert spec.minimum_distance == 0
    assert len(spec.tester_defaults_sha256) == 64
    assert len(spec.custom_symbol_catalog_sha256) == 64


def test_fixture_json_is_byte_deterministic() -> None:
    fixture = {
        "gap": {"buy": pending_stop_fill(+1, 100.0, 100.5, 101.0, 100.4)},
        "placement": validate_oco_placement(
            151.854,
            151.774,
            TickQuote(1712763000, 1712763000171, 151.790, 151.858, "fixture"),
            _spec(),
        ).to_dict(),
        "schema": "qm.velocity-harness-v2-synthetic/v1",
    }
    first = deterministic_json_bytes(fixture)
    second = deterministic_json_bytes(fixture)
    assert first == second
    assert hashlib.sha256(first).hexdigest() == hashlib.sha256(second).hexdigest()


def test_both_prescreens_import_the_shared_execution_module() -> None:
    for name in ("velocity_family_f1_sweep_0921.py", "velocity_hv_prescreen_0921.py"):
        text = (SESSION_TOOLS / name).read_text(encoding="utf-8")
        assert "velocity_execution_harness_v2_0922" in text
