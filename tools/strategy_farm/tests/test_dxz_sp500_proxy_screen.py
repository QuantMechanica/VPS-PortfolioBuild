from __future__ import annotations

import json
from datetime import date, timedelta, timezone, datetime
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_sp500_proxy_screen as screen


def _timestamp(day: date) -> int:
    return int(datetime(day.year, day.month, day.day, tzinfo=timezone.utc).timestamp())


def _bar(day: date, close: float, *, width: float = 1.0) -> screen.Bar:
    return screen.Bar(
        timestamp=_timestamp(day),
        day=day,
        open=close,
        high=close + width,
        low=close - width,
        close=close,
        tickvol=100,
    )


def _bars(closes: list[float], start: date = date(2024, 1, 1)) -> list[screen.Bar]:
    return [_bar(start + timedelta(days=index), close) for index, close in enumerate(closes)]


def _write_csv(path: Path, bars: list[screen.Bar]) -> None:
    lines = ["time,open,high,low,close,tickvol"]
    lines.extend(
        f"{bar.timestamp},{bar.open},{bar.high},{bar.low},{bar.close},{bar.tickvol}"
        for bar in bars
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _fast_parameters(**overrides: object) -> screen.StrategyParameters:
    values: dict[str, object] = {
        "name": "test",
        "rsi_period": 2,
        "cum_window": 2,
        "cum_rsi_entry": 201.0,
        "rsi_exit": 101.0,
        "sma_period": 2,
        "atr_period": 2,
        "atr_sl_mult": 2.0,
        "max_hold_bars": 2,
    }
    values.update(overrides)
    return screen.StrategyParameters(**values)  # type: ignore[arg-type]


def test_wilder_rsi_uses_seed_then_recursive_smoothing() -> None:
    result = screen.wilder_rsi([1.0, 2.0, 3.0, 2.0, 2.0], 2)

    assert result[:2] == [None, None]
    assert result[2] == pytest.approx(100.0)
    assert result[3] == pytest.approx(50.0)
    assert result[4] == pytest.approx(50.0)


def test_wilder_atr_uses_prior_close_and_recursive_smoothing() -> None:
    days = [date(2024, 1, 1) + timedelta(days=index) for index in range(3)]
    bars = [
        screen.Bar(_timestamp(days[0]), days[0], 10.0, 11.0, 9.0, 10.0, 1),
        screen.Bar(_timestamp(days[1]), days[1], 10.0, 13.0, 10.0, 12.0, 1),
        screen.Bar(_timestamp(days[2]), days[2], 12.0, 12.5, 11.0, 11.5, 1),
    ]

    result = screen.wilder_atr(bars, 2)

    assert result == [None, pytest.approx(2.5), pytest.approx(2.0)]


@pytest.mark.parametrize(
    "text,match",
    [
        (
            "time,open,high,low,close\n1704067200,10,11,9,10\n",
            "schema mismatch",
        ),
        (
            "time,open,high,low,close,tickvol\n"
            "1704067200,10,11,9,10,1\n"
            "1704067200,10,11,9,10,1\n",
            "duplicate timestamp",
        ),
        (
            "time,open,high,low,close,tickvol\n"
            "1704153600,10,11,9,10,1\n"
            "1704067200,10,11,9,10,1\n",
            "nonmonotonic",
        ),
        (
            "time,open,high,low,close,tickvol\n1704067200,10,9,8,10,1\n",
            "inconsistent OHLC",
        ),
        (
            "time,open,high,low,close,tickvol\n1704067200,10,,9,10,1\n",
            "high is missing",
        ),
    ],
)
def test_csv_validation_fails_closed(tmp_path: Path, text: str, match: str) -> None:
    path = tmp_path / "bad.csv"
    path.write_text(text, encoding="utf-8")

    with pytest.raises(screen.InputValidationError, match=match):
        screen.load_csv(path, "TEST")


def test_pairwise_calendars_are_independent_and_never_triple_intersected() -> None:
    sp500 = _bars([100.0 + index for index in range(7)])
    ndx = [bar for index, bar in enumerate(_bars([200.0 + i for i in range(7)])) if index != 2]
    ws30 = [bar for index, bar in enumerate(_bars([300.0 + i for i in range(7)])) if index != 3]
    from_day = date(2024, 1, 1)
    to_day = date(2024, 1, 7)

    ndx_summary = screen.pairwise_calendar_summary(sp500, ndx, from_day, to_day)
    ws30_summary = screen.pairwise_calendar_summary(sp500, ws30, from_day, to_day)

    assert ndx_summary["proxy_execution_bars_in_window"] == 6
    assert ws30_summary["proxy_execution_bars_in_window"] == 6
    assert ndx_summary["exact_shared_utc_dates_in_window"] == 6
    assert ws30_summary["exact_shared_utc_dates_in_window"] == 6
    assert ndx_summary["third_symbol_used"] is False
    assert ws30_summary["third_symbol_used"] is False
    assert ndx_summary["pair_stream_sha256"] != ws30_summary["pair_stream_sha256"]


def test_next_open_entry_uses_only_prior_proxy_atr_and_time_exit_is_at_open() -> None:
    sp500 = _bars([100.0 + index for index in range(9)])
    proxy = _bars([200.0 + index for index in range(9)])
    # The first signal is on Jan 4 and enters Jan 5.  A huge Jan 5 high must
    # not affect the stop, which uses Jan 4 ATR.  The low remains stop-safe.
    original = proxy[4]
    proxy[4] = screen.Bar(
        original.timestamp,
        original.day,
        original.open,
        original.open + 50.0,
        original.open - 1.0,
        original.close,
        original.tickvol,
    )

    result = screen.simulate_proxy(
        sp500,
        proxy,
        _fast_parameters(),
        friday_close=False,
        from_day=date(2024, 1, 1),
        to_day=date(2024, 1, 9),
    )

    first = result["trades"][0]
    assert first["entry_signal_date"] == "2024-01-04"
    assert first["entry_date"] == "2024-01-05"
    assert first["risk_distance"] == pytest.approx(4.0)
    assert first["exit_date"] == "2024-01-07"
    assert first["completed_proxy_bars_before_exit"] == 2
    assert first["exit_reason"] == "time_exit_at_open"


def test_rsi_exit_at_open_precedes_that_bars_intraday_stop() -> None:
    sp500 = _bars([100.0 + index for index in range(8)])
    proxy = _bars([200.0 + index for index in range(8)])
    # First entry on Jan 5 is safe; Jan 6 trades through the stop.  With an
    # always-true RSI exit threshold the old position must exit at Jan 6 open
    # before that bar's low is tested.
    jan6 = proxy[5]
    proxy[5] = screen.Bar(
        jan6.timestamp,
        jan6.day,
        jan6.open,
        jan6.high,
        jan6.open - 20.0,
        jan6.close,
        jan6.tickvol,
    )

    result = screen.simulate_proxy(
        sp500,
        proxy,
        _fast_parameters(rsi_exit=99.0),
        friday_close=False,
        from_day=date(2024, 1, 1),
        to_day=date(2024, 1, 8),
    )

    first = result["trades"][0]
    assert first["entry_date"] == "2024-01-05"
    assert first["exit_date"] == "2024-01-06"
    assert first["exit_reason"] == "rsi_exit_at_open"
    assert first["r_multiple"] != -1.0


def test_friday_stop_has_priority_and_friday_off_does_not_force_flat() -> None:
    sp500 = _bars([100.0 + index for index in range(9)])
    proxy = _bars([200.0 + index for index in range(9)])
    friday = proxy[4]
    proxy_with_stop = list(proxy)
    proxy_with_stop[4] = screen.Bar(
        friday.timestamp,
        friday.day,
        friday.open,
        friday.high,
        friday.open - 20.0,
        friday.close,
        friday.tickvol,
    )

    stop_result = screen.simulate_proxy(
        sp500,
        proxy_with_stop,
        _fast_parameters(),
        friday_close=True,
        from_day=date(2024, 1, 1),
        to_day=date(2024, 1, 9),
    )
    friday_on = screen.simulate_proxy(
        sp500,
        proxy,
        _fast_parameters(),
        friday_close=True,
        from_day=date(2024, 1, 1),
        to_day=date(2024, 1, 9),
    )
    friday_off = screen.simulate_proxy(
        sp500,
        proxy,
        _fast_parameters(),
        friday_close=False,
        from_day=date(2024, 1, 1),
        to_day=date(2024, 1, 9),
    )

    assert stop_result["trades"][0]["exit_reason"] == "stop"
    assert stop_result["trades"][0]["r_multiple"] == -1.0
    assert friday_on["trades"][0]["exit_reason"] == "friday_close"
    assert friday_on["trades"][0]["exit_date"] == "2024-01-05"
    assert friday_off["trades"][0]["exit_reason"] == "time_exit_at_open"
    assert friday_off["trades"][0]["exit_date"] == "2024-01-07"


def test_cli_writes_hashed_nonqualifying_report_and_refuses_overwrite(
    tmp_path: Path,
) -> None:
    start = date(2023, 1, 1)
    bars = _bars([100.0 + index * 0.1 for index in range(240)], start)
    paths = {
        role: tmp_path / f"{role}.csv" for role in ("sp500", "ndx", "ws30")
    }
    for offset, (role, path) in enumerate(paths.items()):
        shifted = [
            screen.Bar(
                bar.timestamp,
                bar.day,
                bar.open + offset * 100.0,
                bar.high + offset * 100.0,
                bar.low + offset * 100.0,
                bar.close + offset * 100.0,
                bar.tickvol,
            )
            for bar in bars
        ]
        _write_csv(path, shifted)
    output = tmp_path / "report" / "report.json"
    argv = [
        "--sp500-csv",
        str(paths["sp500"]),
        "--ndx-csv",
        str(paths["ndx"]),
        "--ws30-csv",
        str(paths["ws30"]),
        "--from-date",
        "2023-01-02",
        "--to-date",
        "2023-08-28",
        "--output-json",
        str(output),
    ]

    assert screen.main(argv) == 0
    original = output.read_bytes()
    report = json.loads(original)
    assert report["non_qualification"] is True
    assert report["cost_certified"] is False
    assert report["deployment_eligible"] is False
    assert len(report["inputs"]["SP500"]["sha256"]) == 64
    assert len(report["implementation_sha256"]) == 64
    assert set(report["proxy_results"]) == {"NDX", "WS30"}
    assert len(report["proxy_results"]["NDX"]["variants"]) == 4
    assert len(report["proxy_results"]["WS30"]["variants"]) == 4

    assert screen.main(argv) == 2
    assert output.read_bytes() == original
