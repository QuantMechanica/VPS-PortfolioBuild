"""Synthetic guards for the preregistered frozen-v5 FX stability screen."""

from __future__ import annotations

import hashlib
import sys
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOLS = EA_ROOT / "tools"
CANDIDATE_TOOLS = TOOLS / "candidate_analysis"
for path in (TOOLS, CANDIDATE_TOOLS):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

import audit_frozen_sequence_csv as frozen  # noqa: E402
import audit_v5_fx_daily_london_stability as stability  # noqa: E402


def broker_epoch(value: datetime) -> int:
    return int((value - datetime(1970, 1, 1)).total_seconds())


def make_bar(
    ny_time: datetime,
    *,
    open_: float = 1.1000,
    high: float = 1.1005,
    low: float = 1.0995,
    close: float = 1.1000,
    spread_points: int = 4,
) -> frozen.Bar:
    broker = ny_time + timedelta(hours=7)
    return frozen.Bar(
        timestamp=broker_epoch(broker),
        broker_time=broker,
        ny_time=ny_time,
        open=open_,
        high=high,
        low=low,
        close=close,
        spread_points=spread_points,
    )


def dataset(rows: list[frozen.Bar]) -> frozen.Dataset:
    by_date: dict[date, list[int]] = {}
    for index, row in enumerate(rows):
        by_date.setdefault(row.ny_date, []).append(index)
    return frozen.Dataset(rows, by_date, {}, {})


def sequence_result(direction: int = 1) -> frozen.SequenceResult:
    return frozen.SequenceResult(
        signal_valid=True,
        consumed=True,
        direction=direction,
        ny_date=date(2022, 1, 3),
        entry=1.1000,
        stop=1.0990 if direction > 0 else 1.1010,
        target=1.1020 if direction > 0 else 1.0980,
        rr=2.0,
    )


def make_trade(
    *,
    symbol: str = "GBPUSD.DWX",
    side: str = "LONG",
    year: int = 2020,
    adjusted: float = 1.0,
    gross: float | None = None,
) -> stability.Trade:
    gross_value = adjusted if gross is None else gross
    return stability.Trade(
        scenario_points=4,
        symbol=symbol,
        side=side,
        ny_date=f"{year}-01-03",
        entry_time_ny=f"{year}-01-03 04:00:00",
        exit_time_ny=f"{year}-01-03 05:00:00",
        entry=1.1,
        stop=1.099,
        target=1.102,
        exit_price=1.102 if gross_value > 0 else 1.099,
        risk_price=0.001,
        rr=2.0,
        lots=10.0,
        gross_r=gross_value,
        commission_usd=max(0.0, (gross_value - adjusted) * 1000),
        adjusted_r=adjusted,
        exit_reason="TP" if adjusted > 0 else "SL",
        same_bar_sl_tp_conflict=False,
        touch_bar_exit=False,
    )


def test_contract_hash_and_frozen_center_constants() -> None:
    assert hashlib.sha256(stability.CONTRACT_PATH.read_bytes()).hexdigest() == stability.EXPECTED_CONTRACT_SHA256
    assert frozen.PIVOT_WING == 2
    assert frozen.RECLAIM_BARS == 3
    assert frozen.MAX_BARS_TO_MSS == 12
    assert frozen.MIN_FVG_SMA_TR14 == pytest.approx(0.05)
    assert frozen.SL_BUFFER_SMA_TR14 == pytest.approx(0.10)
    assert frozen.MIN_RR == pytest.approx(2.0)


def test_future_fence_does_not_parse_or_hash_2023_ohlc(tmp_path: Path) -> None:
    path = tmp_path / "GBPUSD.DWX_M5.csv"
    selected = broker_epoch(datetime(2022, 1, 3, 0, 0))
    excluded = broker_epoch(datetime(2023, 1, 1, 0, 0))
    path.write_text(
        "time,open,high,low,close,tickvol\n"
        f"{selected},1.1000,1.1010,1.0990,1.1005,12\n"
        f"{excluded},FUTURE,OHLC,MUST,NOT_PARSE,NOPE\n",
        encoding="ascii",
    )
    market = stability.parse_selected_market(path, "GBPUSD.DWX")
    assert len(market.bars) == 1
    assert market.identity.future_ohlc_parsed is False
    assert market.identity.first_excluded_timestamp == "2023-01-01 00:00:00"
    expected = hashlib.sha256(
        f"{selected},1.1000,1.1010,1.0990,1.1005,12\n".encode("ascii")
    ).hexdigest()
    assert market.identity.selected_sha256 == expected


def test_spread_dataset_reuses_prices_and_changes_only_spread(tmp_path: Path) -> None:
    identity = stability.SliceIdentity(
        path=str(tmp_path / "x.csv"),
        selected_sha256="a" * 64,
        selected_rows=1,
        first_selected_broker_time="2022-01-03 00:00:00",
        last_selected_broker_time="2022-01-03 00:00:00",
        first_excluded_timestamp="2023-01-01 00:00:00",
        future_ohlc_parsed=False,
    )
    original = make_bar(datetime(2022, 1, 3, 4, 0), spread_points=0)
    market = stability.MarketSlice("GBPUSD.DWX", (original,), identity)
    spread8 = stability.dataset_for_spread(market, 8)
    assert spread8.bars[0].spread_points == 8
    assert (spread8.bars[0].open, spread8.bars[0].high, spread8.bars[0].low, spread8.bars[0].close) == (
        original.open,
        original.high,
        original.low,
        original.close,
    )
    assert original.spread_points == 0


def test_blackout_boundaries_are_inclusive_and_next_start_is_deterministic() -> None:
    start = datetime(2022, 1, 3, 3, 30)
    end = datetime(2022, 1, 3, 4, 30)
    later = datetime(2022, 1, 3, 6, 0)
    book = stability.BlackoutBook({"GBPUSD.DWX": [(start, end), (later, later + timedelta(hours=1))]})
    assert book.contains("GBPUSD.DWX", start)
    assert book.contains("GBPUSD.DWX", end)
    assert not book.contains("GBPUSD.DWX", end + timedelta(seconds=1))
    assert book.next_start_after("GBPUSD.DWX", datetime(2022, 1, 3, 3, 0)) == start
    assert book.next_start_after("GBPUSD.DWX", start) == later


def test_external_commission_matches_dealwise_half_up_schedule() -> None:
    # EUR/GBP family rate=max(2.50,2.50*deal_price), then cents half-up per side.
    assert stability.commission_side(stability.Decimal("1"), stability.Decimal("1.25")) == stability.Decimal("3.13")
    assert stability.commission_side(stability.Decimal("2"), stability.Decimal("0.90")) == stability.Decimal("5.00")


def test_touch_bar_sl_precedes_target() -> None:
    rows = [make_bar(datetime(2022, 1, 3, 4, 0), high=1.1030, low=1.0980)]
    trade = stability.execute_outcome(dataset(rows), sequence_result(1), 0, 4, "GBPUSD.DWX")
    assert trade is not None
    assert trade.exit_reason == "SL"
    assert trade.gross_r == pytest.approx(-1.0)
    assert trade.same_bar_sl_tp_conflict is True
    assert trade.touch_bar_exit is True
    assert trade.adjusted_r < trade.gross_r


def test_hard_flat_precedes_target_in_16_ny_bar_for_short() -> None:
    rows = [
        make_bar(datetime(2022, 1, 3, 4, 0), high=1.1005, low=1.0995),
        make_bar(datetime(2022, 1, 3, 16, 0), open_=1.0990, high=1.1015, low=1.0970),
    ]
    trade = stability.execute_outcome(dataset(rows), sequence_result(-1), 0, 4, "GBPUSD.DWX")
    assert trade is not None
    assert trade.exit_reason == "HARD_FLAT_16_NY"
    assert trade.exit_price == pytest.approx(1.09904)
    assert trade.gross_r == pytest.approx(0.96)


def test_metrics_aggregate_pf_drawdown_concentration_and_expected_empty_cells() -> None:
    trades = [
        make_trade(symbol="GBPUSD.DWX", side="LONG", year=2019, adjusted=2.0),
        make_trade(symbol="EURUSD.DWX", side="SHORT", year=2020, adjusted=-1.0),
        make_trade(symbol="GBPUSD.DWX", side="SHORT", year=2021, adjusted=1.0),
        make_trade(symbol="EURUSD.DWX", side="LONG", year=2022, adjusted=-1.0),
    ]
    result = stability.scenario_performance(trades)
    assert result["pooled"]["fills"] == 4
    assert result["pooled"]["adjusted_net_r"] == pytest.approx(1.0)
    assert result["pooled"]["adjusted_pf"] == pytest.approx(1.5)
    assert result["pooled"]["max_adjusted_drawdown_r"] == pytest.approx(1.0)
    assert result["pooled"]["top_two_adjusted_winner_share"] == pytest.approx(1.0)
    assert result["by_symbol"]["GBPUSD.DWX"]["fills"] == 2
    assert result["by_year"]["2018"]["fills"] == 0
    assert result["by_symbol_side"]["EURUSD.DWX:LONG"]["fills"] == 1


def test_dynamic_pf_floor_is_exact_intent_and_stricter_for_small_samples() -> None:
    assert stability.dynamic_pf_floor(60) is not None
    assert stability.dynamic_pf_floor(60) > 1.2
    assert stability.dynamic_pf_floor(450) == pytest.approx(1.2, abs=0.002)
    assert stability.dynamic_pf_floor(2000) == pytest.approx(1.10)
    assert stability.dynamic_pf_floor(0) is None
