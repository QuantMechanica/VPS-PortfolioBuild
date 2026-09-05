from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_trial_telemetry as subject


def row(
    timestamp: str,
    *,
    session: str = "tester-1",
    sequence: int = 0,
    equity: float = 100_000.0,
    balance: float = 100_000.0,
    positions: list[dict] | None = None,
    orders: list[dict] | None = None,
) -> dict:
    parsed = dt.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    positions = positions or []
    orders = orders or []
    return {
        "schema": subject.RAW_SCHEMA,
        "event": "SAMPLE",
        "trial_id": "TESTER_FIXTURE",
        "session_id": session,
        "sequence": sequence,
        "ts_utc": timestamp,
        "ts_epoch": int(parsed.timestamp()),
        "prague_day_key": subject.prague_day_key(parsed),
        "source": "TIMER",
        "account_login": 123,
        "account_server": "Synthetic-Tester",
        "currency": "USD",
        "balance": balance,
        "equity": equity,
        "open_positions": len(positions),
        "pending_orders": len(orders),
        "reconciliation_complete": True,
        "positions": positions,
        "orders": orders,
    }


def write(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(item) + "\n" for item in rows), encoding="utf-8")


def test_restart_duplicate_midnight_and_planted_minimum(tmp_path: Path) -> None:
    source = tmp_path / "raw.jsonl"
    planted = row(
        "2026-01-01T23:03:00Z",
        session="tester-2",
        sequence=1,
        equity=94_999.0,
        positions=[{"magic": 107060001}],
        orders=[{"magic": 114210000}],
    )
    rows = [
        row("2026-01-01T22:59:59Z", sequence=0),
        row("2026-01-01T23:00:00Z", sequence=1),  # Prague midnight (CET)
        row("2026-01-01T23:01:00Z", session="tester-2", sequence=0),
        planted,
        dict(planted),  # exact restart-safe duplicate is idempotent
        row("2026-01-01T23:04:59Z", session="tester-2", sequence=2, equity=99_500.0),
    ]
    write(source, rows)
    report = subject.build_report(source, maximum_sample_gap_seconds=120)
    assert report["ingestion"]["restart_count"] == 1
    assert report["ingestion"]["deduplicated_samples"] == 5
    assert report["continuity"]["status"] == "PASS"
    bucket = next(item for item in report["m5_rows"] if item["interval_start_utc"] == "2026-01-01T23:00:00Z")
    assert bucket["interval_min_equity"] == 94_999.0
    assert bucket["positions_by_magic"] == {}
    assert bucket["pending_orders_by_magic"] == {}
    midnight_day = next(item for item in report["days"] if item["prague_day_key"] == 20260102)
    assert midnight_day["anchor_lag_seconds"] == 0


def test_duplicate_identity_race_conflict_fails_closed(tmp_path: Path) -> None:
    source = tmp_path / "race.jsonl"
    left = row("2026-01-01T12:00:00Z", sequence=7)
    right = dict(left, equity=99_000.0)
    write(source, [left, right])
    with pytest.raises(subject.TelemetryError, match="identity_race_conflict"):
        subject.load_rows(source)


def test_gap_and_flat_at_target(tmp_path: Path) -> None:
    source = tmp_path / "gap.jsonl"
    write(source, [
        row("2026-06-01T22:00:00Z", sequence=0),  # Prague midnight (CEST)
        row("2026-06-01T22:10:00Z", sequence=1, balance=110_001.0),
    ])
    report = subject.build_report(source, maximum_sample_gap_seconds=10)
    assert report["continuity"]["status"] == "FAIL_GAPS"
    assert report["continuity"]["gaps"][0]["seconds"] == 600
    assert report["flat_at_target"]["status"] == "PASS"


def test_prague_dst_boundaries() -> None:
    winter = dt.datetime(2026, 1, 1, 23, 0, tzinfo=dt.timezone.utc)
    summer = dt.datetime(2026, 6, 1, 22, 0, tzinfo=dt.timezone.utc)
    assert subject.prague_day_key(winter) == 20260102
    assert subject.prague_day_key(summer) == 20260602


def test_mql_collector_is_read_only_and_emits_required_fields() -> None:
    source = (Path(__file__).parents[3] / "framework/monitor/QM_FTMO_TrialTelemetry.mq5").read_text(encoding="utf-8")
    for forbidden in ("OrderSend(", "CTrade ", "PositionClose(", "AutoTrading"):
        assert forbidden not in source
    for required in (
        "AccountInfoDouble(ACCOUNT_EQUITY)",
        "AccountInfoDouble(ACCOUNT_BALANCE)",
        "QM_FTMO_PragueDayKey(now)",
        "PositionGetInteger(POSITION_MAGIC)",
        "OrderGetInteger(ORDER_MAGIC)",
        'Capture("TICK")',
        'Capture("TIMER")',
        "reconciliation_complete",
    ):
        assert required in source
