from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import interval_equity_export as exporter


def _write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.write_text("".join(json.dumps(row) + "\n" for row in rows), encoding="utf-8")


def _spec(tmp_path: Path) -> dict[str, object]:
    trades = tmp_path / "trades.jsonl"
    logger = tmp_path / "logger.jsonl"
    start = dt.datetime(2024, 1, 1, tzinfo=dt.UTC)
    _write_jsonl(
        trades,
        [{
            "event": "TRADE_CLOSED", "entry_time": int((start + dt.timedelta(minutes=2)).timestamp()),
            "time": int((start + dt.timedelta(minutes=8)).timestamp()), "net": 125.25,
        }],
    )
    _write_jsonl(
        logger,
        [
            {"event": "INIT", "ts_utc": "2024-01-01T00:00:00.000Z", "payload": {}},
            {"event": "EQUITY_SNAPSHOT", "ts_utc": "2024-01-01T00:04:00.000Z", "payload": {"equity": 99900, "day_key": 20231231}},
            {"event": "EQUITY_SNAPSHOT", "ts_utc": "2024-01-01T00:10:00.000Z", "payload": {"equity": 100125.25, "day_key": 20240101}},
        ],
    )
    return {
        "schema": exporter.SPEC_SCHEMA,
        "from_utc": "2024-01-01T00:00:00Z",
        "to_utc": "2024-01-01T00:10:00Z",
        "grid_minutes": 5,
        "book_initial_balance": 100000,
        "currency": "USD",
        "sleeves": [{
            "sleeve_id": "1:EURUSD", "initial_balance": 100000, "weight": 1,
            "trade_stream_path": str(trades), "logger_path": str(logger),
        }],
    }


def test_reconstructs_balance_and_occupancy_without_inventing_equity(tmp_path: Path) -> None:
    result = exporter.export_spec(_spec(tmp_path))
    first, middle, last = result["rows"]
    assert result["status"] == "ABSTAIN"
    assert middle["joint"]["balance"] == "100000.00"
    assert middle["joint"]["open_positions"] == 1
    assert middle["sleeves"][0]["equity"] is None
    assert middle["sleeves"][0]["equity_observation"]["equity"] == "99900.00"
    assert middle["sleeves"][0]["equity_observation"]["basis"] == "EXACT_EVENT_WITHIN_INTERVAL_NOT_ENDPOINT"
    assert last["joint"]["balance"] == "100125.25"
    assert last["joint"]["equity"] == "100125.25"
    assert last["joint"]["open_positions"] == 0
    assert first["joint"]["pending_orders"] is None
    assert last["joint"]["interval_min_equity"] is None


def test_hash_binds_both_sources_and_reports_coverage(tmp_path: Path) -> None:
    result = exporter.export_spec(_spec(tmp_path))
    coverage = result["coverage"][0]
    assert len(coverage["trade_stream"]["sha256"]) == 64
    assert len(coverage["logger"]["sha256"]) == 64
    assert coverage["closed_lifecycles"] == 1
    assert coverage["equity_snapshots"] == 2
    assert coverage["pending_order_coverage"] == "MISSING"


def test_refuses_duplicate_json_keys(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    logger = Path(spec["sleeves"][0]["logger_path"])
    logger.write_text(
        '{"event":"EQUITY_SNAPSHOT","event":"EQUITY_SNAPSHOT","ts_utc":"2024-01-01T00:00:00Z","payload":{"equity":100000,"day_key":20240101}}\n',
        encoding="utf-8",
    )
    with pytest.raises(exporter.IntervalExportError, match="duplicate JSON key"):
        exporter.export_spec(spec)


def test_refuses_non_finite_money(tmp_path: Path) -> None:
    spec = _spec(tmp_path)
    trades = Path(spec["sleeves"][0]["trade_stream_path"])
    trades.write_text('{"event":"TRADE_CLOSED","entry_time":1,"time":2,"net":NaN}\n', encoding="utf-8")
    with pytest.raises(exporter.IntervalExportError, match="non-finite"):
        exporter.export_spec(spec)

