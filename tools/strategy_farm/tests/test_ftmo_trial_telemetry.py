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


@pytest.mark.parametrize("change,reason", [
    ({"account_login": 456}, "mixed_account_or_trial"),
    ({"trial_id": "different"}, "mixed_account_or_trial"),
    ({"ts_epoch": 0}, "epoch_mismatch"),
    ({"sequence": 3}, "sequence_gap"),
    ({"sequence": True}, "identity_invalid"),
    ({"positions": {}}, "inventory_invalid"),
])
def test_stream_refusals(tmp_path, change, reason):
    source = tmp_path / "raw.jsonl"
    write(source, [row("2026-01-01T22:59:59Z"), dict(row("2026-01-01T23:00:00Z", sequence=1), **change)])
    with pytest.raises(subject.TelemetryError, match=reason):
        subject.load_rows(source)


def test_missing_day_and_bucket_abstain(tmp_path):
    source = tmp_path / "raw.jsonl"
    write(source, [row("2026-01-01T23:00:00Z"), row("2026-01-02T23:00:00Z", sequence=1)])
    report = subject.build_report(source)
    assert report["days"][0]["status"] == "ABSTAIN_GAPS"
    assert report["days"][0]["daily_loss_breached"] is None
    assert len(report["continuity"]["missing_intervals"]) == 287
    with pytest.raises(subject.TelemetryError, match="compaction_refused_gaps"):
        subject.compact_daily(source, tmp_path / "compact")


def test_compaction_restart_midnight_manifest_and_tamper(tmp_path):
    source = tmp_path / "raw.jsonl"
    start = dt.datetime(2026, 6, 1, 21, 55, tzinfo=dt.timezone.utc)
    rows = []
    for index in range(901):
        stamp = (start + dt.timedelta(seconds=index)).isoformat().replace("+00:00", "Z")
        rows.append(row(stamp, session="first" if index < 450 else "second", sequence=index if index < 450 else index - 450, equity=94000 if index == 460 else 100000))
    write(source, rows)
    dest = tmp_path / "compact"
    manifest = subject.compact_daily(source, dest)
    assert manifest["ingestion"]["restart_count"] == 1
    assert [item["prague_day_key"] for item in manifest["outputs"]] == [20260601, 20260602]
    assert sum(item["rows"] for item in manifest["outputs"]) == 4
    assert subject.verify_compaction(dest) == manifest
    with pytest.raises(subject.TelemetryError, match="destination_already_exists"):
        subject.compact_daily(source, dest)
    target = dest / manifest["outputs"][0]["path"]
    target.write_text(target.read_text() + "\n")
    with pytest.raises(subject.TelemetryError, match="manifest_output_hash_mismatch"):
        subject.verify_compaction(dest)


def test_same_second_endpoint_preserves_capture_order(tmp_path):
    source = tmp_path / "raw.jsonl"
    write(source, [row("2026-01-01T23:00:00Z", session="z", equity=90000), row("2026-01-01T23:00:00Z", session="a", equity=99000)])
    report = subject.build_report(source)
    assert report["m5_rows"][0]["equity"] == 99000
    assert report["m5_rows"][0]["interval_min_equity"] == 90000
