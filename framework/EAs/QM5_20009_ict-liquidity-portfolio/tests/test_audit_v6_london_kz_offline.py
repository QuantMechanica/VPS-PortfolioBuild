"""Synthetic-only tests for the preregistered v6 London-KZ offline screen."""

from __future__ import annotations

import hashlib
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import audit_v6_london_kz_offline as audit  # noqa: E402


def epoch(value: datetime) -> int:
    return int(value.replace(tzinfo=timezone.utc).timestamp())


def bar(
    value: datetime,
    *,
    open_: float = 100.0,
    high: float = 100.5,
    low: float = 99.5,
    close: float = 100.0,
) -> audit.Bar:
    return audit.Bar(epoch(value), open_, high, low, close, 1)


def sequence(start: datetime, count: int) -> list[audit.Bar]:
    return [bar(start + timedelta(minutes=15 * index)) for index in range(count)]


def replace_bar(rows: list[audit.Bar], index: int, **values: float) -> None:
    old = rows[index]
    rows[index] = audit.Bar(
        old.epoch,
        values.get("open", old.open),
        values.get("high", old.high),
        values.get("low", old.low),
        values.get("close", old.close),
        old.tickvol,
    )


def index_map(rows: list[audit.Bar]) -> dict[int, int]:
    return {row.epoch: index for index, row in enumerate(rows)}


def test_preregistered_contract_hash_is_locked() -> None:
    payload = audit.DEFAULT_CONTRACT.read_bytes()
    assert hashlib.sha256(payload).hexdigest() == audit.EXPECTED_CONTRACT_SHA256


def test_market_reader_stops_before_parsing_future_ohlc(tmp_path: Path) -> None:
    path = tmp_path / "test.csv"
    path.write_text(
        "time,open,high,low,close,tickvol\n"
        "1640995200,1.1,1.2,1.0,1.1,10\n"
        "1672531200,THIS,FUTURE,OHLC,MUST_NOT_PARSE,NOPE\n",
        encoding="ascii",
    )
    rows, identity = audit.load_selected_m5(path)
    assert len(rows) == 1
    assert identity.first_excluded_timestamp == "2023-01-01 00:00:00"
    assert identity.future_ohlc_parsed is False


def test_m15_requires_exact_three_causal_m5_rows() -> None:
    start = datetime(2022, 1, 3, 9, 0)
    complete = [
        audit.Bar(epoch(start), 100, 101, 99, 100.5, 2),
        audit.Bar(epoch(start + timedelta(minutes=5)), 100.5, 102, 100, 101, 3),
        audit.Bar(epoch(start + timedelta(minutes=10)), 101, 101.5, 98, 99, 5),
    ]
    aggregates, invalid = audit.aggregate_m15(complete)
    assert invalid == 0
    assert len(aggregates) == 1
    assert (aggregates[0].open, aggregates[0].high, aggregates[0].low, aggregates[0].close) == (
        100,
        102,
        98,
        99,
    )
    assert aggregates[0].tickvol == 10
    aggregates, invalid = audit.aggregate_m15(complete[:2])
    assert aggregates == []
    assert invalid == 1


def test_pool_choice_is_strict_nearest_and_deterministic() -> None:
    assert audit.choose_pool([("ASIA", 99), ("PD", 98), ("PIVOT", 97)], 100, "below") == 99
    assert audit.choose_pool([("ASIA", 101), ("PD", 102), ("PIVOT", 103)], 100, "above") == 101
    assert audit.choose_pool([("ASIA", 100), ("PD", 100)], 100, "below") is None
    assert audit.choose_pool([("PD", 99), ("ASIA", 99)], 100, "below") == 99


def test_pivot_requires_strict_contiguous_three_bar_pattern() -> None:
    rows = sequence(datetime(2022, 1, 3, 8, 0), 3)
    replace_bar(rows, 0, high=100)
    replace_bar(rows, 1, high=101)
    replace_bar(rows, 2, high=100)
    assert audit.is_pivot(rows, 1, "high")
    replace_bar(rows, 2, high=101)
    assert not audit.is_pivot(rows, 1, "high")
    rows[2] = bar(datetime(2022, 1, 3, 8, 45), high=100)
    assert not audit.is_pivot(rows, 1, "high")


@pytest.mark.parametrize("break_step", [1, 8])
def test_mss_accepts_only_post_sweep_bars_one_through_eight(break_step: int) -> None:
    rows = sequence(datetime(2022, 1, 3, 9, 0), 10)
    for index in range(1, 10):
        replace_bar(rows, index, close=99.0)
    replace_bar(rows, break_step, high=101.5, close=101.0)
    found = audit.find_mss_index(
        rows,
        index_map(rows),
        0,
        100.0,
        "long",
        datetime(2022, 1, 3, 12, 0),
    )
    assert found == break_step


def test_mss_rejects_bar_nine_and_equality() -> None:
    rows = sequence(datetime(2022, 1, 3, 9, 0), 10)
    for index in range(1, 9):
        replace_bar(rows, index, close=100.0)
    replace_bar(rows, 9, high=101.5, close=101.0)
    assert audit.find_mss_index(
        rows,
        index_map(rows),
        0,
        100.0,
        "long",
        datetime(2022, 1, 3, 12, 0),
    ) is None


def test_fvg_requires_all_three_bars_strictly_post_mss_and_selects_earliest() -> None:
    rows = sequence(datetime(2022, 1, 3, 9, 0), 10)
    # A/B/C at indices 3/4/5; MSS is index 2.  A.high < C.low.
    replace_bar(rows, 3, high=100.0, low=99.0)
    replace_bar(rows, 5, high=102.0, low=101.0, close=101.5)
    # A second later FVG must never replace the first.
    replace_bar(rows, 6, high=100.0, low=99.0)
    replace_bar(rows, 8, high=103.0, low=102.0, close=102.5)
    found = audit.find_post_mss_fvg_index(
        rows,
        index_map(rows),
        2,
        "long",
        datetime(2022, 1, 3, 12, 0),
    )
    assert found == 5
    midpoint = (rows[3].high + rows[5].low) / 2
    assert midpoint < rows[5].low <= rows[5].close


def test_pre_mss_gap_and_gap_equality_do_not_form_fvg() -> None:
    rows = sequence(datetime(2022, 1, 3, 9, 0), 7)
    # Gap at 0/2 straddles MSS at 1 and must be invisible.
    replace_bar(rows, 0, high=99.0)
    replace_bar(rows, 2, low=100.0, high=101.0)
    # Wholly post-MSS A/C equality is not strict.
    replace_bar(rows, 2, high=100.0)
    replace_bar(rows, 4, low=100.0, high=101.0)
    assert audit.find_post_mss_fvg_index(
        rows,
        index_map(rows),
        1,
        "long",
        datetime(2022, 1, 3, 10, 45),
    ) is None


def test_fvg_confirming_at_noon_is_excluded() -> None:
    rows = sequence(datetime(2022, 1, 3, 11, 0), 4)
    replace_bar(rows, 1, high=100.0)
    replace_bar(rows, 3, low=101.0, high=102.0, close=101.5)
    assert rows[3].close_dt == datetime(2022, 1, 3, 12, 0)
    assert audit.find_post_mss_fvg_index(
        rows,
        index_map(rows),
        0,
        "long",
        datetime(2022, 1, 3, 12, 0),
    ) is None


def test_virtual_limit_bar_eight_fills_but_cutoff_timestamp_does_not() -> None:
    start = datetime(2022, 1, 3, 10, 0)
    rows = sequence(start, 9)
    for index in range(7):
        replace_bar(rows, index, low=100.5)
    replace_bar(rows, 7, low=99.5)
    result, found = audit.find_virtual_limit_result(
        rows,
        index_map(rows),
        "GBPUSD.DWX",
        "long",
        100.0,
        start,
        start + timedelta(minutes=120),
        audit.Blackouts({}),
    )
    assert (result, found) == ("FILLED", 7)
    replace_bar(rows, 7, low=100.5)
    replace_bar(rows, 8, low=99.5)
    result, found = audit.find_virtual_limit_result(
        rows,
        index_map(rows),
        "GBPUSD.DWX",
        "long",
        100.0,
        start,
        start + timedelta(minutes=120),
        audit.Blackouts({}),
    )
    assert (result, found) == ("EXPIRED", None)


def test_news_overlap_at_touch_is_inclusive_and_consuming() -> None:
    start = datetime(2022, 1, 3, 10, 0)
    rows = sequence(start, 1)
    replace_bar(rows, 0, low=99.5)
    blackouts = audit.Blackouts({"GBPUSD.DWX": [(start + timedelta(minutes=15), start + timedelta(minutes=30))]})
    result, found = audit.find_virtual_limit_result(
        rows,
        index_map(rows),
        "GBPUSD.DWX",
        "long",
        100.0,
        start,
        start + timedelta(minutes=15),
        blackouts,
    )
    assert (result, found) == ("NEWS_TOUCH_VOID", 0)


def position_bars() -> tuple[list[audit.Bar], dict[int, int]]:
    rows = sequence(datetime(2022, 1, 3, 10, 0), 29)
    return rows, index_map(rows)


def complete(rows: list[audit.Bar], by_epoch: dict[int, int]) -> tuple[audit.Trade, Counter[str]]:
    ambiguity: Counter[str] = Counter()
    issues: list[str] = []
    trade = audit.complete_trade(
        "GBPUSD.DWX",
        "long",
        datetime(2022, 1, 3).date(),
        rows,
        by_epoch,
        0,
        100.0,
        99.0,
        102.0,
        103.0,
        ambiguity,
        issues,
    )
    assert issues == []
    assert trade is not None
    return trade, ambiguity


def test_fill_bar_stop_precedes_all_favorable_prices() -> None:
    rows, mapping = position_bars()
    replace_bar(rows, 0, high=103.5, low=98.5)
    trade, ambiguity = complete(rows, mapping)
    assert trade.gross_r == pytest.approx(-1.0)
    assert trade.exit_reason == "STOP_FILL_BAR"
    assert ambiguity["FILL_BAR_STOP_AND_TARGET_STOP_FIRST"] == 1


def test_favorable_fill_bar_target_is_not_credited() -> None:
    rows, mapping = position_bars()
    replace_bar(rows, 0, high=103.5, low=99.5)
    trade, ambiguity = complete(rows, mapping)
    assert trade.gross_r == pytest.approx(0.0)
    assert trade.exit_reason == "HARD_FLAT"
    assert ambiguity["FILL_BAR_FAVORABLE_IGNORED"] == 1


def test_later_bar_stop_precedes_tp1() -> None:
    rows, mapping = position_bars()
    replace_bar(rows, 1, high=102.5, low=98.5)
    trade, ambiguity = complete(rows, mapping)
    assert trade.gross_r == pytest.approx(-1.0)
    assert trade.exit_reason == "STOP"
    assert ambiguity["LATER_BAR_STOP_AND_TARGET_STOP_FIRST"] == 1


def test_partial_then_ambiguous_runner_bar_uses_original_stop() -> None:
    rows, mapping = position_bars()
    replace_bar(rows, 1, high=102.5, low=99.5)
    replace_bar(rows, 2, high=103.5, low=98.5)
    trade, ambiguity = complete(rows, mapping)
    assert trade.partial_done is True
    assert trade.gross_r == pytest.approx(0.5)
    assert trade.exit_reason == "STOP_AFTER_TP1"
    assert ambiguity["LATER_BAR_STOP_AND_TARGET_STOP_FIRST"] == 1


def test_dealwise_commission_is_positive_and_reduces_r() -> None:
    rows, mapping = position_bars()
    replace_bar(rows, 1, high=103.5, low=99.5)
    trade, _ = complete(rows, mapping)
    assert trade.gross_r == pytest.approx(2.5)
    assert trade.commission_usd > 0
    assert trade.adjusted_r < trade.gross_r
