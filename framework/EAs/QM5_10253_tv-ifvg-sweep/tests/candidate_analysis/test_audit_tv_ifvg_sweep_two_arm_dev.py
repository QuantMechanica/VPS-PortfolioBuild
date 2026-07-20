"""Synthetic guards for the preregistered QM5_10253 two-arm DEV audit."""

from __future__ import annotations

import hashlib
import json
import sys
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
CANDIDATE_TOOLS = EA_ROOT / "tools" / "candidate_analysis"
if str(CANDIDATE_TOOLS) not in sys.path:
    sys.path.insert(0, str(CANDIDATE_TOOLS))

import audit_tv_ifvg_sweep_two_arm_dev as audit  # noqa: E402


def epoch(value: datetime) -> int:
    return int((value - datetime(1970, 1, 1)).total_seconds())


def bar(
    index: int,
    *,
    open_: float = 10.0,
    high: float = 11.0,
    low: float = 9.0,
    close: float = 10.0,
    base: datetime = datetime(2020, 1, 6, 0, 0),
) -> audit.Bar:
    timestamp = epoch(base) + index * audit.BAR_SECONDS
    return audit.Bar(
        timestamp=timestamp,
        broker_time=audit.dt_from_epoch(timestamp),
        open=open_,
        high=high,
        low=low,
        close=close,
        tickvol=1,
    )


def test_contract_hash_and_two_preregistered_arms_are_bound() -> None:
    assert hashlib.sha256(audit.CONTRACT_PATH.read_bytes()).hexdigest() == audit.EXPECTED_CONTRACT_SHA256
    contract = json.loads(audit.CONTRACT_PATH.read_text(encoding="utf-8"))
    assert contract["analysis_id"] == audit.ANALYSIS_ID
    assert audit.ARMS == ("A_CARD_CENTER", "B_SOURCE_FAITHFUL")
    assert audit.CONTRACT_COMMIT == "ab3b31c0126deee5882a8c3eba38a3bd96011912"


def test_future_fence_neither_parses_nor_hashes_2023_ohlc(tmp_path: Path) -> None:
    path = tmp_path / "XAUUSD.DWX_M15.csv"
    selected = epoch(datetime(2022, 12, 30, 23, 45))
    excluded = epoch(datetime(2023, 1, 3, 0, 0))
    selected_line = f"{selected},1800.0,1801.0,1799.0,1800.5,12"
    path.write_bytes(
        (
            "time,open,high,low,close,tickvol\n"
            f"{selected_line}\n"
            f"{excluded},"
        ).encode("ascii")
        + b"FUTURE,OHLC,MUST,NOT_PARSE,\xff\xfe\n"
    )
    market = audit.parse_selected_market(path, "XAUUSD.DWX")
    assert len(market.bars) == 1
    assert market.identity.future_ohlc_parsed is False
    assert market.identity.first_excluded_timestamp == "2023-01-03T00:00:00"
    assert market.identity.selected_sha256 == hashlib.sha256(
        (selected_line + "\n").encode("ascii")
    ).hexdigest()


def test_selected_ohlc_still_fails_closed(tmp_path: Path) -> None:
    path = tmp_path / "NDX.DWX_M15.csv"
    selected = epoch(datetime(2022, 12, 30, 23, 45))
    excluded = epoch(datetime(2023, 1, 3, 0, 0))
    path.write_text(
        "time,open,high,low,close,tickvol\n"
        f"{selected},100,99,101,100,1\n"
        f"{excluded},FUTURE,OHLC,MUST,NOT_PARSE,NOPE\n",
        encoding="ascii",
    )
    with pytest.raises(audit.AuditError, match="invalid selected OHLC"):
        audit.parse_selected_market(path, "NDX.DWX")


def test_htf_bias_uses_only_fully_closed_h1_and_h4_bars() -> None:
    rising = [
        bar(
            index,
            open_=100.0 + index,
            high=101.5 + index,
            low=99.5 + index,
            close=101.0 + index,
        )
        for index in range(560)
    ]
    changed_incomplete_bucket = list(rising)
    for index in range(545, 560):
        changed_incomplete_bucket[index] = bar(
            index,
            open_=1000.0,
            high=1001.0,
            low=0.5,
            close=1.0,
        )
    baseline = audit.compute_mtf_bias(rising)
    changed = audit.compute_mtf_bias(changed_incomplete_bucket)
    assert baseline[544] == 1
    assert changed[544] == baseline[544]


def test_card_center_requires_exact_sweep_displacement_gap_triplet() -> None:
    bars = [bar(index, open_=100.2, high=101.0, low=100.0, close=100.5) for index in range(24)]
    bars[20] = bar(20, open_=100.2, high=100.5, low=99.0, close=100.2)
    bars[21] = bar(21, open_=100.1, high=102.0, low=100.0, close=101.6)
    bars[22] = bar(22, open_=101.2, high=102.0, low=101.0, close=101.5)
    signals, funnel = audit.generate_card_signals(bars, [1.0] * len(bars))
    assert len(signals) == 1
    signal = signals[0]
    assert (signal.sweep_index, signal.completion_index, signal.arm_index) == (20, 22, 23)
    assert (signal.direction, signal.zone_bottom, signal.zone_top) == (1, 100.5, 101.0)
    assert funnel["signals"] == 1


def test_card_center_does_not_drop_short_when_sweep_bar_takes_both_sides() -> None:
    bars = [bar(index, open_=100.0, high=101.0, low=99.0, close=100.0) for index in range(24)]
    bars[20] = bar(20, open_=100.0, high=102.0, low=98.0, close=100.0)
    bars[21] = bar(21, open_=99.8, high=100.0, low=97.5, close=98.0)
    bars[22] = bar(22, open_=96.8, high=97.0, low=96.0, close=96.5)
    signals, funnel = audit.generate_card_signals(bars, [1.0] * len(bars))
    assert [signal.direction for signal in signals] == [-1]
    assert funnel["dual_direction_sweep_bars"] == 1
    assert funnel["sweeps"] == 2


def source_fixture(*, invert: bool) -> list[audit.Bar]:
    bars = [bar(index) for index in range(16)]
    bars[5] = bar(5, open_=9.5, high=10.0, low=8.0, close=9.0)
    bars[11] = bar(11, open_=8.5, high=9.0, low=7.5, close=8.5)
    bars[12] = bar(12, open_=8.0, high=9.0, low=7.0, close=8.0)
    bars[13] = bar(13, open_=6.5, high=6.7, low=6.0, close=6.5)
    bars[14] = bar(
        14,
        open_=7.0,
        high=9.5 if invert else 7.4,
        low=6.8,
        close=9.0 if invert else 7.0,
    )
    bars[15] = bar(15, open_=9.0, high=9.5, low=8.5, close=9.0)
    return bars


def test_source_arm_requires_true_fvg_inversion_after_pivot_sweep() -> None:
    ordinary_only, ordinary_funnel = audit.generate_source_signals(
        source_fixture(invert=False), [1.0] * 16
    )
    inverted, inverted_funnel = audit.generate_source_signals(
        source_fixture(invert=True), [1.0] * 16
    )
    assert ordinary_funnel["ordinary_fvgs_created"] >= 1
    assert ordinary_only == []
    assert len(inverted) == 1
    signal = inverted[0]
    assert signal.arm == "B_SOURCE_FAITHFUL"
    assert signal.direction == 1
    assert (signal.sweep_index, signal.completion_index, signal.arm_index) == (11, 14, 15)
    assert inverted_funnel["contexts_bound_first_fvg"] == 1
    assert inverted_funnel["ifvg_completions"] >= 1


def test_dealwise_commission_is_symbol_specific_and_half_up() -> None:
    assert audit.commission_side("NDX.DWX", Decimal("2"), Decimal("20000")) == Decimal("5.50")
    assert audit.commission_side("XAUUSD.DWX", Decimal("1"), Decimal("2000")) == Decimal("5.00")
    assert audit.commission_side("XAUUSD.DWX", Decimal("0.01"), Decimal("2001")) == Decimal("0.05")


def test_same_bar_stop_precedes_target_and_adverse_stop_gap_uses_open() -> None:
    signal = audit.Signal(
        arm="A_CARD_CENTER",
        direction=1,
        completion_index=0,
        arm_index=0,
        zone_bottom=99.0,
        zone_top=100.0,
        sweep_index=0,
        sweep_extreme=98.0,
        stop_atr=1.0,
        structural_id="synthetic",
    )
    conflict = audit.execute_trade(
        bars=[bar(0, open_=100.0, high=103.0, low=98.0, close=100.0)],
        signal=signal,
        entry_index=0,
        entry=100.0,
        stop=99.0,
        target=102.0,
        spread=2.1,
        scenario="CENTER",
        symbol="NDX.DWX",
    )
    assert conflict.exit_reason == "SL"
    assert conflict.exit_price == 99.0
    assert conflict.same_bar_sl_tp_conflict is True
    assert conflict.exit_timestamp == conflict.entry_timestamp + audit.BAR_SECONDS
    assert conflict.commission_cents == round(conflict.commission_usd * 100)

    gap = audit.execute_trade(
        bars=[bar(0, open_=98.0, high=98.5, low=97.0, close=98.0)],
        signal=signal,
        entry_index=0,
        entry=100.0,
        stop=99.0,
        target=102.0,
        spread=2.1,
        scenario="CENTER",
        symbol="NDX.DWX",
    )
    assert gap.exit_reason == "SL_GAP"
    assert gap.exit_price == 98.0


def test_us_dst_conversion_and_news_boundaries_are_exact() -> None:
    before = datetime(2022, 3, 13, 6, 59, 59, tzinfo=timezone.utc)
    at = datetime(2022, 3, 13, 7, 0, 0, tzinfo=timezone.utc)
    assert audit.broker_offset_for_utc(before) == 2
    assert audit.broker_offset_for_utc(at) == 3
    event = datetime(2022, 3, 13, 12, 0, 0, tzinfo=timezone.utc)
    start = audit.utc_to_broker_epoch(event.replace(minute=30) - audit.timedelta(hours=1))
    end = audit.utc_to_broker_epoch(event.replace(minute=30))
    book = audit.BlackoutBook([(start, end)])
    assert book.contains(start)
    assert book.contains(end)
    assert not book.contains(start - 1)
    assert book.next_start_after(start - 1) == start


def test_canonical_json_and_familywise_floor_are_deterministic() -> None:
    first = audit.canonical_json({"z": 1, "a": [2, 3]})
    second = audit.canonical_json({"a": [2, 3], "z": 1})
    assert first == second
    assert first.endswith(b"\n")
    expected_u = 2.241402727604947 / (120**0.5)
    expected_d = expected_u / ((1.0 + expected_u * expected_u) ** 0.5)
    assert audit.dynamic_pf_floor(120) == pytest.approx(max(1.20, (1 + expected_d) / (1 - expected_d)))
    assert audit.dynamic_pf_floor(0) is None


def synthetic_trade(
    structural_id: str, exit_timestamp: int, adjusted_r: float, symbol: str
) -> audit.Trade:
    return audit.Trade(
        arm="A_CARD_CENTER",
        scenario="CENTER",
        symbol=symbol,
        side="LONG",
        structural_id=structural_id,
        entry_time_broker="2020-01-01T00:00:00",
        exit_time_broker=audit.stamp(audit.dt_from_epoch(exit_timestamp)),
        entry_timestamp=exit_timestamp - audit.BAR_SECONDS,
        exit_timestamp=exit_timestamp,
        entry=100.0,
        stop=99.0,
        target=102.0,
        exit_price=100.0 + adjusted_r,
        lots=1.0,
        gross_usd=adjusted_r * 1000.0,
        gross_r=adjusted_r,
        commission_cents=0,
        commission_usd=0.0,
        adjusted_usd=adjusted_r * 1000.0,
        adjusted_r=adjusted_r,
        exit_reason="SYNTHETIC",
        same_bar_sl_tp_conflict=False,
        entry_bar_exit=False,
    )


def test_simultaneous_pooled_exits_are_conservatively_loss_first() -> None:
    first = epoch(datetime(2020, 1, 2, 10, 0))
    simultaneous = first + audit.BAR_SECONDS
    rows = [
        synthetic_trade("prior_loss", first, -5.0, "NDX.DWX"),
        synthetic_trade("same_time_win", simultaneous, 10.0, "NDX.DWX"),
        synthetic_trade("same_time_loss", simultaneous, -3.0, "XAUUSD.DWX"),
    ]
    metric = audit.performance(rows)
    assert metric["max_adjusted_closed_balance_drawdown_r"] == pytest.approx(8.0)
    assert metric["external_commission_cents"] == 0
