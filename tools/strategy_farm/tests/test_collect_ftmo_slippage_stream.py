from __future__ import annotations

from datetime import datetime, timezone
from types import SimpleNamespace

import pytest

from tools.strategy_farm.portfolio import collect_ftmo_slippage_stream as stream


def test_window_requires_monday_and_five_days() -> None:
    start = datetime(2026, 9, 14, tzinfo=timezone.utc)
    stream.validate_window(start, datetime(2026, 9, 19, tzinfo=timezone.utc))
    with pytest.raises(ValueError, match="Monday"):
        stream.validate_window(
            datetime(2026, 9, 15, tzinfo=timezone.utc),
            datetime(2026, 9, 20, tzinfo=timezone.utc),
        )
    with pytest.raises(ValueError, match="five trading days"):
        stream.validate_window(start, datetime(2026, 9, 18, tzinfo=timezone.utc))


def test_quote_selects_latest_prior_tick_and_marks_fresh() -> None:
    quote = stream.quote_at_or_before(
        [
            {"time_msc": 1_000, "bid": 1.1, "ask": 1.2, "flags": 1},
            {"time_msc": 1_900, "bid": 1.2, "ask": 1.3, "flags": 2},
            {"time_msc": 2_100, "bid": 1.3, "ask": 1.4, "flags": 3},
        ],
        2_000,
    )
    assert quote == {
        "time_msc": 1_900,
        "bid": 1.2,
        "ask": 1.3,
        "flags": 2,
        "age_msc": 100,
        "fresh": True,
    }


def test_quote_refuses_future_zero_and_stale_ticks() -> None:
    assert stream.quote_at_or_before(
        [{"time_msc": 1_000, "bid": 0, "ask": 1.2}], 2_000
    ) is None
    stale = stream.quote_at_or_before(
        [{"time_msc": 1_000, "bid": 1.1, "ask": 1.2}], 4_000
    )
    assert stale is not None and stale["fresh"] is False


def test_reference_contract_distinguishes_market_and_pending() -> None:
    deal = SimpleNamespace(time_msc=2_000)
    market = stream.reference_contract(
        SimpleNamespace(type=0, time_setup_msc=1_000), deal
    )
    pending = stream.reference_contract(
        SimpleNamespace(type=4, time_setup_msc=1_000), deal
    )
    assert market["kind"] == "ORDER_REQUEST_TIME" and market["time_msc"] == 1_000
    assert pending["kind"] == "PENDING_TRIGGER_FILL_TIME" and pending["time_msc"] == 2_000


def test_signed_adverse_points_uses_executable_side() -> None:
    quote = {"bid": 1.1000, "ask": 1.1002}
    assert stream.signed_adverse_points(0, 1.1003, quote, 0.0001) == 1.0
    assert stream.signed_adverse_points(1, 1.0999, quote, 0.0001) == 1.0
