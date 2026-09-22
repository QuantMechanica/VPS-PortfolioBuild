from __future__ import annotations

import datetime as dt
from pathlib import Path
from types import SimpleNamespace

from tools.strategy_farm.ftmo import venue_matched_collector as collector


UTC = dt.timezone.utc


def _spread_row(
    symbol: str, minute: dt.datetime, delta: float
) -> dict[str, object]:
    epoch = int(minute.timestamp())
    session = collector.session_name(epoch)
    return {
        "symbol": symbol,
        "minute_epoch": epoch,
        "minute_utc": collector.utc_iso(minute),
        "utc_date": minute.date().isoformat(),
        "utc_hour": minute.hour,
        "session": session,
        "ftmo_spread_bps": 2.0 + delta,
        "dxz_spread_bps": 2.0,
        "ftmo_minus_dxz_bps": delta,
    }


def test_first_quote_per_minute_uses_first_valid_complete_quote() -> None:
    raw = [
        {"time_msc": 60_100, "bid": 0.0, "ask": 1.2},
        {"time_msc": 60_200, "bid": 1.1, "ask": 1.2},
        {"time_msc": 60_900, "bid": 1.2, "ask": 1.3},
        {"time_msc": 120_100, "bid": 1.3, "ask": 1.4},
    ]
    rows = collector.first_quote_per_minute(raw)
    assert rows[60]["time_msc"] == 60_200
    assert rows[120]["bid"] == 1.3


def test_first_quote_normalizes_broker_wall_clock_to_utc() -> None:
    raw = [{"time_msc": 3_660_200, "bid": 1.1, "ask": 1.2}]
    rows = collector.first_quote_per_minute(raw, server_minus_utc_hours=1)
    assert list(rows) == [60]
    assert rows[60]["time_msc"] == 60_200
    assert rows[60]["server_time_msc"] == 3_660_200


def test_process_path_match_is_exact_and_case_insensitive(tmp_path: Path) -> None:
    executable = tmp_path / "Terminal64.exe"
    executable.touch()
    paths = {
        11: str(executable),
        12: str(tmp_path / "other" / "terminal64.exe"),
        13: "",
    }
    assert collector._matching_process_ids(executable, paths) == {11}


def test_matched_rows_require_exact_minute_and_compute_bid_ask_bps() -> None:
    ftmo = {
        "USDJPY": {
            60: {"time_msc": 60_100, "server_time_msc": 60_100, "bid": 100.0, "ask": 100.02},
            120: {"time_msc": 120_100, "server_time_msc": 120_100, "bid": 100.0, "ask": 100.03},
        }
    }
    dxz = {
        "USDJPY": {
            60: {"time_msc": 60_500, "server_time_msc": 60_500, "bid": 100.0, "ask": 100.01},
            180: {"time_msc": 180_100, "server_time_msc": 180_100, "bid": 100.0, "ask": 100.01},
        }
    }
    rows = collector.matched_spread_rows(ftmo, dxz)
    assert len(rows) == 1
    assert rows[0]["minute_epoch"] == 60
    assert rows[0]["ftmo_minus_dxz_bps"] > 0


def test_spread_rule_measures_only_with_60_minutes_three_sessions_and_21z() -> None:
    rows: list[dict[str, object]] = []
    for symbol in collector.SYMBOL_MAP:
        for hour in (0, 8, 21):
            for minute in range(20):
                rows.append(
                    _spread_row(
                        symbol,
                        dt.datetime(2026, 9, 21, hour, minute, tzinfo=UTC),
                        1.25,
                    )
                )
    result, table = collector.spread_measurement(
        rows, generated_at=dt.datetime(2026, 9, 22, tzinfo=UTC)
    )
    assert result["status"] == "MEASURED_ALL_SYMBOLS"
    assert table["USDJPY.DWX"] == 1.25
    assert all(row["matched_minute_count"] == 60 for row in result["symbols"])


def test_spread_rule_abstains_without_rollover_even_above_minimum() -> None:
    rows = [
        _spread_row(
            "USDJPY",
            dt.datetime(2026, 9, 21, hour, minute, tzinfo=UTC),
            0.5,
        )
        for hour in (0, 8, 14)
        for minute in range(30)
    ]
    result, table = collector.spread_measurement(
        rows, generated_at=dt.datetime(2026, 9, 22, tzinfo=UTC)
    )
    usd = next(row for row in result["symbols"] if row["symbol"] == "USDJPY")
    assert usd["status"] == "UNMEASURED"
    assert "rollover_21z_minutes=0" in usd["unmeasured_reasons"]
    assert "USDJPY.DWX" not in table


def test_slippage_values_are_signed_adverse_bps_and_usd_per_lot() -> None:
    info = SimpleNamespace(
        name="EURUSD",
        point=0.00001,
        trade_tick_size=0.00001,
        trade_tick_value=1.0,
        trade_tick_value_loss=1.0,
        trade_tick_value_profit=1.0,
    )
    bps, usd = collector._slippage_values(
        deal_side=0,
        request_price=1.10000,
        fill_price=1.10002,
        symbol_info=info,
    )
    assert bps > 0
    assert usd == 2.0
    improved_bps, improved_usd = collector._slippage_values(
        deal_side=1,
        request_price=1.10000,
        fill_price=1.10002,
        symbol_info=info,
    )
    assert improved_bps < 0
    assert improved_usd == -2.0


def test_slippage_table_requires_measured_entry_and_exit() -> None:
    base = {
        "status": "MEASURED",
        "symbol": "USDJPY",
        "server_time_msc": int(
            dt.datetime(2026, 9, 21, 10, tzinfo=UTC).timestamp() * 1000
        ),
        "time_utc_msc": int(
            dt.datetime(2026, 9, 21, 7, tzinfo=UTC).timestamp() * 1000
        ),
        "slippage_bps": 0.1,
        "slippage_usd_per_lot": 2.0,
    }
    summary, table = collector.slippage_summary(
        [
            {**base, "deal_ticket": 1, "entry": 0},
            {**base, "deal_ticket": 2, "entry": 1, "slippage_usd_per_lot": 3.0},
            {
                **base,
                "deal_ticket": 3,
                "symbol": "GBPUSD",
                "entry": 0,
            },
        ],
        generated_at=dt.datetime(2026, 9, 22, tzinfo=UTC),
    )
    assert table["USDJPY.DWX"] == 5.0
    assert "GBPUSD.DWX" not in table
    assert summary["symbols"]["GBPUSD"]["status"] == "UNMEASURED"
    daily = summary["symbols"]["USDJPY"]["daily_by_utc_hour"]
    assert daily["2026-09-21"]["07"]["n"] == 2
    assert daily["2026-09-21"]["08"]["slippage_bps"]["p90"] is None


def test_append_unique_jsonl_is_idempotent(tmp_path: Path) -> None:
    path = tmp_path / "ledger.jsonl"
    rows = [{"symbol": "EURUSD", "minute_epoch": 1, "value": 2}]
    assert collector.append_unique_jsonl(
        path, rows, key_fields=("symbol", "minute_epoch")
    ) == 1
    assert collector.append_unique_jsonl(
        path, rows, key_fields=("symbol", "minute_epoch")
    ) == 0
    assert collector.read_jsonl(path) == rows


def test_append_unique_jsonl_deduplicates_one_incoming_batch(tmp_path: Path) -> None:
    path = tmp_path / "ledger.jsonl"
    row = {"symbol": "EURUSD", "minute_epoch": 1, "value": 2}
    assert collector.append_unique_jsonl(
        path, [row, dict(row)], key_fields=("symbol", "minute_epoch")
    ) == 1
    assert collector.read_jsonl(path) == [row]


def test_session_sample_windows_include_named_rollover_hour() -> None:
    windows = collector.session_sample_windows(
        dt.datetime(2026, 9, 21, tzinfo=UTC),
        dt.datetime(2026, 9, 22, tzinfo=UTC),
    )
    labels = {label for label, _, _ in windows}
    assert labels == {"ASIA_00Z", "EUROPE_08Z", "US_14Z", "ROLLOVER_21Z"}


def test_module_has_no_trading_or_terminal_start_api_surface() -> None:
    source = Path(collector.__file__).read_text(encoding="utf-8")
    forbidden = (
        "order_send(",
        "order_check(",
        "subprocess.Popen",
        "subprocess.run",
        "Start-Process",
        "AutoTrading",
    )
    assert not any(token in source for token in forbidden)
