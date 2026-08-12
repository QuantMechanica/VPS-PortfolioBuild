from __future__ import annotations

import importlib.util
import sys
from datetime import datetime, timezone
from fractions import Fraction
from pathlib import Path

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_tv_smc_mss_fvg_m15_full_dev.py"
)
SPEC = importlib.util.spec_from_file_location("qm10729_audit", TOOL)
assert SPEC and SPEC.loader
audit = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = audit
SPEC.loader.exec_module(audit)


def epoch(raw: str) -> int:
    return int((datetime.fromisoformat(raw) - datetime(1970, 1, 1)).total_seconds())


def bar(
    timestamp: int,
    open_: int | Fraction,
    high: int | Fraction,
    low: int | Fraction,
    close: int | Fraction,
    tickvol: int = 1,
):
    return audit.Bar(
        timestamp,
        Fraction(open_),
        Fraction(high),
        Fraction(low),
        Fraction(close),
        tickvol,
    )


def position(direction: int = 1) -> audit.Position:
    return audit.Position(
        symbol="XAUUSD.DWX",
        scenario="CENTER",
        direction=direction,
        session="LONDON_LABEL",
        structural_id="S",
        entry_timestamp=900,
        entry=Fraction(100),
        stop=Fraction(99 if direction > 0 else 101),
        target=Fraction(102 if direction > 0 else 98),
        lots=Fraction(1),
        entry_commission_cents=10,
        expected_next_open=900,
        flat_timestamp=3600,
    )


def dummy_trade(adjusted_r: Fraction, *, index: int = 0) -> audit.Trade:
    commission = 10
    gross_r = adjusted_r + Fraction(commission, 100_000)
    gross_usd = gross_r * 1000
    return audit.Trade(
        trade_id=f"T{index}",
        scenario="CENTER",
        symbol="XAUUSD.DWX",
        session="LONDON_LABEL",
        side="LONG",
        structural_id=f"S{index}",
        entry_timestamp=1_600_000_000 + index * 1800,
        exit_timestamp=1_600_000_900 + index * 1800,
        entry=Fraction(100),
        stop=Fraction(99),
        target=Fraction(102),
        exit_price=Fraction(102),
        lots=Fraction(1),
        gross_usd=gross_usd,
        gross_r=gross_r,
        entry_commission_cents=5,
        exit_commission_cents=5,
        commission_cents=commission,
        adjusted_usd=adjusted_r * 1000,
        adjusted_r=adjusted_r,
        exit_reason="TP" if adjusted_r > 0 else "SL",
        same_bar_sl_tp_conflict=False,
    )


def test_decimal_text_is_exact_and_canonical() -> None:
    assert audit.decimal_text(Fraction(1, 2)) == "0.5"
    assert audit.decimal_text(Fraction(1, 100)) == "0.01"
    assert audit.decimal_text(Fraction(401150, 100)) == "4011.5"
    assert audit.decimal_text(Fraction(-0, 10)) == "0"


def test_round_half_up_cents_only() -> None:
    assert audit.round_half_up_cents(Fraction(1004, 1000)) == 100
    assert audit.round_half_up_cents(Fraction(1005, 1000)) == 101
    assert audit.round_half_up_cents(Fraction(1006, 1000)) == 101


def test_m5_resampling_requires_all_three_slots() -> None:
    rows = [
        bar(0, 10, 12, 9, 11, 2),
        bar(300, 11, 13, 10, 12, 3),
        bar(600, 12, 14, 8, 13, 4),
        bar(900, 13, 15, 12, 14, 5),
        bar(1500, 14, 16, 13, 15, 6),
    ]
    result, partial = audit._aggregate_m15(rows)
    assert len(result) == 1
    assert partial == 1
    assert result[0] == bar(0, 10, 14, 8, 13, 9)


def test_strict_pivot_high_rejects_neighbor_tie() -> None:
    rows = []
    for index in range(11):
        high = 10 if index == 5 else 9
        rows.append(bar(index * 900, 5, high, 4, 5))
    _signals, funnel = audit.generate_signals("XAUUSD.DWX", rows)
    assert funnel["pivot_high_confirmations"] == 1
    tied = list(rows)
    tied[4] = bar(4 * 900, 5, 10, 4, 5)
    _signals, tied_funnel = audit.generate_signals("XAUUSD.DWX", tied)
    assert tied_funnel.get("pivot_high_confirmations", 0) == 0


def test_session_mapping_is_half_open() -> None:
    assert audit.session_for_timestamp(epoch("2020-01-02T14:00:00")) == "LONDON_LABEL"
    assert audit.session_for_timestamp(epoch("2020-01-02T16:45:00")) == "LONDON_LABEL"
    assert audit.session_for_timestamp(epoch("2020-01-02T17:00:00")) is None
    assert audit.session_for_timestamp(epoch("2020-01-02T19:30:00")) == "NEW_YORK_LABEL"
    assert audit.session_for_timestamp(epoch("2020-01-02T23:00:00")) is None


def test_broker_to_utc_uses_us_dst_and_standard_preference() -> None:
    january = audit.broker_to_utc_epoch(epoch("2020-01-15T14:00:00"))
    july = audit.broker_to_utc_epoch(epoch("2020-07-15T14:00:00"))
    assert audit.epoch_to_datetime(january) == datetime(2020, 1, 15, 12, 0)
    assert audit.epoch_to_datetime(july) == datetime(2020, 7, 15, 11, 0)


def test_news_window_is_entry_point_and_inclusive() -> None:
    event = int(
        (
            datetime(2020, 1, 15, 12, 0, tzinfo=timezone.utc)
            - datetime(1970, 1, 1, tzinfo=timezone.utc)
        ).total_seconds()
    )
    book = audit.NewsBook({"EURUSD.DWX": [event], "XAUUSD.DWX": [event]})
    assert book.blocks("EURUSD.DWX", epoch("2020-01-15T13:30:00"))
    assert book.blocks("EURUSD.DWX", epoch("2020-01-15T14:30:00"))
    assert not book.blocks("EURUSD.DWX", epoch("2020-01-15T13:29:59"))


def test_news_currency_matching_uses_both_fx_legs() -> None:
    assert audit.news_affects_symbol("EUR", "EURUSD.DWX")
    assert audit.news_affects_symbol("USD", "EURUSD.DWX")
    assert audit.news_affects_symbol("USD", "XAUUSD.DWX")
    assert not audit.news_affects_symbol("EUR", "XAUUSD.DWX")
    assert audit.news_affects_symbol("ALL", "XAUUSD.DWX")


def test_long_equal_range_conflict_resolves_stop_first() -> None:
    current = position(1)
    outcome = audit._process_position_bar(
        current, bar(900, 100, 102, 99, 101), Fraction(1, 10)
    )
    assert outcome is not None
    assert outcome.exit_price == 99
    assert outcome.exit_reason == "SL_CONSERVATIVE_CONFLICT"
    assert outcome.same_bar_sl_tp_conflict


def test_long_gap_stop_equality_uses_open() -> None:
    current = position(1)
    outcome = audit._process_position_bar(
        current, bar(900, 99, 100, 98, 99), Fraction(1, 10)
    )
    assert outcome is not None
    assert outcome.exit_reason == "SL_GAP"
    assert outcome.exit_price == 99


def test_short_ask_touch_equality_is_inclusive() -> None:
    current = position(-1)
    outcome = audit._process_position_bar(
        current, bar(900, Fraction(100), Fraction(1009, 10), 99, 100), Fraction(1, 10)
    )
    assert outcome is not None
    assert outcome.exit_reason == "SL"
    assert outcome.exit_price == 101


def test_missing_bar_while_open_fails_closed() -> None:
    current = position(1)
    with pytest.raises(audit.DataIntegrityError, match="missing expected M15 bar"):
        audit._process_position_bar(
            current, bar(1800, 100, 101, 99, 100), Fraction(1, 10)
        )


def test_future_tail_is_never_parsed_and_prestart_ohlc_is_ignored(tmp_path: Path) -> None:
    market = tmp_path / "XAUUSD.DWX_M15.csv"
    market.write_bytes(
        b"time,open,high,low,close,tickvol\r\n"
        b"1514763900,NOT,PARSED,PRESTART,ROW,NOPE\r\n"
        b"1514764800,10,11,9,10,1\r\n"
        b"1672531200,THIS,FUTURE,TAIL,MUST,NOT_PARSE\r\n"
    )
    parsed = audit.parse_market(
        market, "XAUUSD.DWX", 15, enforce_expected=False
    )
    assert len(parsed.bars) == 1
    assert not parsed.identity.future_ohlc_parsed
    assert parsed.identity.first_excluded_timestamp == "2023-01-01T00:00:00"


def test_canonical_m15_bytes_have_fixed_key_order() -> None:
    raw = audit.canonical_m15_bytes(bar(900, Fraction(1, 2), 2, Fraction(1, 4), 1, 7))
    assert raw == (
        b'{"time":900,"open":"0.5","high":"2","low":"0.25",'
        b'"close":"1","tickvol":7}\n'
    )


def test_metric_uses_inf_sentinel_and_exact_concentration() -> None:
    metric = audit.compute_metric([dummy_trade(Fraction(2), index=1)])
    assert metric.adjusted_pf == "INF"
    assert metric.top_two_winner_share == 1
    assert metric.leave_best_trade_r == 0


def test_empty_composite_cannot_pass_gates() -> None:
    empty_internal, _payload = audit.scenario_report([])
    gates, verdict = audit.evaluate_gates(empty_internal, empty_internal)
    assert verdict == "NO_CONJUNCTIVE_FAMILY_MERIT"
    assert not all(row["pass"] for row in gates)


def test_snapshot_path_rejects_parent_escape(tmp_path: Path) -> None:
    with pytest.raises(audit.AuditError, match="unsafe snapshot relative path"):
        audit._snapshot_path(tmp_path.resolve(), "../live-input.csv")


def test_snapshot_manifest_hash_is_release_pinned(tmp_path: Path) -> None:
    with pytest.raises(audit.AuditError, match="not the released exact manifest"):
        audit.verify_release(tmp_path / "manifest.json", "0" * 64)
