"""Synthetic, deterministic tests for the frozen-sequence CSV auditor."""

from __future__ import annotations

import csv
import json
import sys
from datetime import date, datetime, timedelta
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import audit_frozen_sequence_csv as audit_tool  # noqa: E402


def _fixture_csv(
    tmp_path: Path,
    *,
    outcome: str = "tp",
    include_spread: bool = True,
) -> Path:
    """Create one complete prior week plus a deterministic Monday sequence."""

    path = tmp_path / "explicit_m5_fixture.csv"
    header = ["time", "open", "high", "low", "close"]
    if include_spread:
        header.append("spread")

    start = datetime(2021, 12, 26, 17, 0)
    end = datetime(2022, 1, 3, 16, 0)
    rows: list[list[str | int]] = []
    cursor = start
    while cursor <= end:
        open_price = 1.1030
        high = 1.1050
        low = 1.1010
        close = 1.1030

        # Establish complete, explicit 1.1000/1.1200 weekly and Asian ranges.
        if cursor in {
            datetime(2021, 12, 27, 0, 0),
            datetime(2022, 1, 2, 20, 0),
        }:
            high = 1.1200
            low = 1.1000

        # Latest strict pre-penetration pivot high (wing=2).
        if cursor == datetime(2022, 1, 3, 1, 30):
            high = 1.1060

        # Penetration and immediate reclaim of the frozen 1.1000 low.
        if cursor == datetime(2022, 1, 3, 2, 0):
            open_price = 1.1005
            high = 1.1010
            low = 1.0990
            close = 1.1005

        # Later market-structure shift above the strict pivot.
        if cursor == datetime(2022, 1, 3, 2, 5):
            open_price = 1.1005
            high = 1.1080
            low = 1.1000
            close = 1.1070

        # First post-MSS bullish FVG: low > high two bars earlier.
        if cursor == datetime(2022, 1, 3, 2, 10):
            open_price = 1.1070
            high = 1.1080
            low = 1.1020
            close = 1.1070

        # The next bar is fresh at its open and touches the 1.1020 edge.
        if cursor == datetime(2022, 1, 3, 2, 15):
            open_price = 1.1070
            high = 1.1080
            low = 1.1015
            close = 1.1030
            if outcome == "same_bar_conflict":
                high = 1.1210
                low = 1.0980

        if cursor == datetime(2022, 1, 3, 2, 20) and outcome == "tp":
            open_price = 1.1030
            high = 1.1210
            low = 1.1025
            close = 1.1190

        broker = cursor + timedelta(hours=7)
        row: list[str | int] = [
            broker.strftime("%Y-%m-%d %H:%M:%S"),
            f"{open_price:.5f}",
            f"{high:.5f}",
            f"{low:.5f}",
            f"{close:.5f}",
        ]
        if include_spread:
            row.append(1)
        rows.append(row)
        cursor += timedelta(minutes=5)

    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)
    return path


def _config(
    path: Path,
    mode: str,
    *,
    default_spread_points: int | None = None,
) -> audit_tool.AuditConfig:
    if mode == "weekly-fx":
        from_date = date(2022, 1, 2)
    else:
        from_date = date(2022, 1, 3)
    return audit_tool.AuditConfig(
        csv_path=path,
        symbol="GBPUSD.DWX",
        mode=mode,
        from_ny_date=from_date,
        to_ny_date=date(2022, 1, 3),
        tick_size=0.00001,
        point=0.00001,
        default_spread_points=default_spread_points,
    )


@pytest.mark.parametrize("mode", ["weekly-fx", "daily-london"])
def test_frozen_sequence_is_ready_touched_and_tp(tmp_path: Path, mode: str) -> None:
    payload = audit_tool.audit(_config(_fixture_csv(tmp_path), mode))

    assert payload["status"] == "PASS"
    assert payload["funnel"]["budgets_total"] == 1
    assert payload["funnel"]["consumed"] == 1
    assert payload["funnel"]["pivot_confirmed"] == 1
    assert payload["funnel"]["mss"] == 1
    assert payload["funnel"]["fvg"] == 1
    assert payload["funnel"]["ready"] == 1
    assert payload["funnel"]["fresh_at_eligibility_ohlc"] == 1
    assert payload["funnel"]["touched_ohlc"] == 1
    assert payload["final_outcomes"] == {"EARLIEST_FVG_READY": 1}
    assert payload["approximate_post_touch"]["counts"] == {"TP": 1}

    signal = payload["ready"][0]
    assert signal["direction"] == "LONG"
    assert signal["entry"] == "1.10200000"
    assert signal["target"] == "1.12000000"
    assert signal["penetration_bar_open_broker"] == "2022-01-03T09:00:00"
    assert signal["mss_bar_open_broker"] == "2022-01-03T09:05:00"
    assert signal["fvg_bar_open_broker"] == "2022-01-03T09:10:00"
    assert signal["touch_bar_open_broker"] == "2022-01-03T09:15:00"
    assert signal["approximate_outcome"]["status"] == "TP"


def test_weekly_result_and_canonical_json_are_reproducible(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    path = _fixture_csv(tmp_path)
    arguments = [
        "--csv",
        str(path),
        "--symbol",
        "GBPUSD.DWX",
        "--mode",
        "weekly-fx",
        "--from-ny-date",
        "2022-01-02",
        "--to-ny-date",
        "2022-01-03",
        "--tick-size",
        "0.00001",
        "--point",
        "0.00001",
    ]

    before = sorted(tmp_path.iterdir())
    assert audit_tool.main(arguments) == 0
    first = capsys.readouterr()
    assert audit_tool.main(arguments) == 0
    second = capsys.readouterr()

    assert first.err == second.err == ""
    assert first.out == second.out
    payload = json.loads(first.out)
    assert first.out.rstrip("\n") == audit_tool._canonical_json(payload)
    assert payload["input"]["csv_path"] == str(path.resolve())
    assert payload["final_outcomes"] == {"EARLIEST_FVG_READY": 1}
    assert sorted(tmp_path.iterdir()) == before


def test_same_bar_sl_tp_conflict_is_conservatively_sl_first(tmp_path: Path) -> None:
    path = _fixture_csv(tmp_path, outcome="same_bar_conflict")
    payload = audit_tool.audit(_config(path, "daily-london"))

    outcome = payload["touched"][0]["approximate_outcome"]
    assert outcome["status"] == "SL"
    assert outcome["r_multiple"] == "-1.00000000"
    assert outcome["same_bar_sl_tp_conflict"] is True
    assert payload["approximate_post_touch"]["counts"] == {"SL": 1}


def test_unresolved_m5_trade_is_hard_flat_at_16_ny(tmp_path: Path) -> None:
    path = _fixture_csv(tmp_path, outcome="flat")
    payload = audit_tool.audit(_config(path, "daily-london"))

    outcome = payload["touched"][0]["approximate_outcome"]
    assert outcome["status"] == "HARD_FLAT_16_NY"
    assert outcome["exit_bar_open_broker"] == "2022-01-03T23:00:00"
    assert float(outcome["r_multiple"]) > 0.0


def test_missing_spread_requires_an_explicit_fallback(tmp_path: Path) -> None:
    path = _fixture_csv(tmp_path, include_spread=False)
    with pytest.raises(
        audit_tool.AuditError,
        match="--default-spread-points must be explicit",
    ):
        audit_tool.audit(_config(path, "daily-london"))

    payload = audit_tool.audit(
        _config(path, "daily-london", default_spread_points=4)
    )
    assert payload["input"]["spread_source"] == "EXPLICIT_DEFAULT_POINTS:4"


def test_literal_path_rejects_glob_and_emits_canonical_error(
    tmp_path: Path,
    capsys: pytest.CaptureFixture[str],
) -> None:
    wildcard = tmp_path / "*.csv"
    arguments = [
        "--csv",
        str(wildcard),
        "--symbol",
        "GBPUSD.DWX",
        "--mode",
        "daily-london",
        "--from-ny-date",
        "2022-01-03",
        "--to-ny-date",
        "2022-01-03",
        "--tick-size",
        "0.00001",
        "--point",
        "0.00001",
        "--default-spread-points",
        "4",
    ]

    assert audit_tool.main(arguments) == 2
    captured = capsys.readouterr()
    assert captured.out == ""
    payload = json.loads(captured.err)
    assert captured.err.rstrip("\n") == audit_tool._canonical_json(payload)
    assert payload["status"] == "ERROR"
    assert "wildcard/glob" in payload["error"]


def test_bar_closing_at_session_end_is_not_an_event() -> None:
    included = audit_tool.Bar(
        timestamp=0,
        broker_time=datetime(2022, 1, 3, 11, 50),
        ny_time=datetime(2022, 1, 3, 4, 50),
        open=1.0,
        high=1.1,
        low=0.9,
        close=1.0,
        spread_points=0,
    )
    excluded = audit_tool.Bar(
        timestamp=300,
        broker_time=datetime(2022, 1, 3, 11, 55),
        ny_time=datetime(2022, 1, 3, 4, 55),
        open=1.0,
        high=1.1,
        low=0.9,
        close=1.0,
        spread_points=0,
    )

    assert audit_tool._event_bar_in_session(included, date(2022, 1, 3), 120, 300)
    assert not audit_tool._event_bar_in_session(
        excluded,
        date(2022, 1, 3),
        120,
        300,
    )
