"""Tests for the read-only V3 terminal-concurrency A/B measurement harness."""
import csv
import datetime as dt
import json
import sqlite3

from tools.strategy_farm import concurrency_ab_measure


NOW = dt.datetime(2026, 8, 27, 12, 0, tzinfo=dt.timezone.utc)


def _con() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, phase TEXT, status TEXT, verdict TEXT,
          claimed_by TEXT, payload_json TEXT, updated_at TEXT,
          gate_contract_version TEXT
        );
        """
    )
    return con


def _iso(hours_ago: float) -> str:
    return (NOW - dt.timedelta(hours=hours_ago)).isoformat()


def _insert(con: sqlite3.Connection, **values) -> None:
    columns = (
        "id",
        "phase",
        "status",
        "verdict",
        "claimed_by",
        "payload_json",
        "updated_at",
        "gate_contract_version",
    )
    row = {column: values.get(column) for column in columns}
    con.execute(
        f"INSERT INTO work_items({','.join(columns)}) "
        f"VALUES({','.join('?' for _ in columns)})",
        tuple(row[column] for column in columns),
    )


def test_db_metrics_exclude_disposition_count_measured_and_use_q_only_phases():
    con = _con()
    _insert(
        con,
        id="real",
        phase="P4",
        status="done",
        verdict="PASS",
        payload_json=json.dumps(
            {"claimed_at_iso": _iso(3), "terminal": "T1"}
        ),
        updated_at=_iso(2),
        gate_contract_version="legacy",
    )
    _insert(
        con,
        id="measured",
        phase="OPT_CENSUS",
        status="done",
        verdict="MEASURED",
        payload_json=json.dumps(
            {"claimed_at_iso": _iso(1.5), "terminal": "T2"}
        ),
        updated_at=_iso(1),
        gate_contract_version="v4",
    )
    _insert(
        con,
        id="disposition",
        phase="Q02",
        status="failed",
        verdict="INVALID",
        payload_json=json.dumps({"disposition_only": True}),
        updated_at=_iso(1),
        gate_contract_version="v4",
    )
    metrics = concurrency_ab_measure.collect_db_metrics(
        con, window_end=NOW, window_hours=24, configured_slots=10
    )
    assert metrics["execution_verdicts"] == 2
    assert metrics["disposition_only_rows"] == 1
    assert metrics["measured_cells"] == 1
    assert metrics["measured_cells_per_hour"] == round(1 / 24, 3)
    assert metrics["median_wall_minutes_by_phase"]["Q04"] == {
        "median": 60.0,
        "sample_count": 1,
    }
    assert metrics["measurement_pool_wall_minutes"]["median"] == 30.0
    assert all(key.startswith("Q") for key in metrics["median_wall_minutes_by_phase"])
    assert con.total_changes == 3  # only fixture inserts; collector issued no writes


def test_utilization_clips_and_merges_overlapping_claims_per_terminal():
    con = _con()
    # Two overlapping completed claims on T1 merge to a three-hour interval.
    _insert(
        con,
        id="a",
        phase="Q09",
        status="done",
        verdict="PASS",
        payload_json=json.dumps({"claimed_at_iso": _iso(5), "terminal": "T1"}),
        updated_at=_iso(3),
        gate_contract_version="v4",
    )
    _insert(
        con,
        id="b",
        phase="Q09",
        status="done",
        verdict="PASS",
        payload_json=json.dumps({"claimed_at_iso": _iso(4), "terminal": "T1"}),
        updated_at=_iso(2),
        gate_contract_version="v4",
    )
    # Active T2 claim began before the two-hour measurement window -> clipped.
    _insert(
        con,
        id="active",
        phase="Q10_NEWS",
        status="active",
        claimed_by="T2",
        payload_json=json.dumps({"claimed_at_iso": _iso(8)}),
        updated_at=_iso(0.1),
        gate_contract_version="v4",
    )
    metrics = concurrency_ab_measure.collect_db_metrics(
        con, window_end=NOW, window_hours=6, configured_slots=2
    )
    assert metrics["occupied_hours_by_terminal"] == {"T1": 3.0, "T2": 6.0}
    assert metrics["occupied_terminal_hours"] == 9.0
    assert metrics["available_slot_hours"] == 12.0
    assert metrics["slot_utilization"] == 0.75


def test_cpu_pause_scan_is_windowed_and_reports_coverage(tmp_path):
    for terminal in ("T1", "T2"):
        path = tmp_path / f"terminal_worker_{terminal}.log"
        events = [
            {"event": "cpu_high_pause", "terminal": terminal, "at_utc": _iso(25)},
            {"event": "other", "terminal": terminal, "at_utc": _iso(12)},
            {"event": "cpu_high_pause", "terminal": terminal, "at_utc": _iso(1)},
        ]
        path.write_text("\n".join(json.dumps(event) for event in events) + "\n")
    metrics = concurrency_ab_measure.collect_cpu_pause_metrics(
        tmp_path, window_end=NOW, window_hours=24, configured_slots=2
    )
    assert metrics["cpu_high_pause_events"] == 2
    assert metrics["cpu_high_pause_events_per_hour"] == round(2 / 24, 3)
    assert metrics["coverage_complete"] is True
    assert all(item["reached_cutoff"] for item in metrics["log_coverage"].values())


def test_csv_and_report_include_metrics_and_nonexecuted_rollback(tmp_path):
    snapshot = {
        "window_start_utc": _iso(24),
        "window_end_utc": _iso(0),
        "window_hours": 24.0,
        "configured_slots": 10,
        "execution_verdicts": 20,
        "execution_verdicts_per_day": 20.0,
        "disposition_only_rows": 2,
        "measured_cells": 12,
        "measured_cells_per_hour": 0.5,
        "execution_by_phase": {"Q09": 8},
        "median_wall_minutes_by_phase": {
            "Q09": {"median": 15.0, "sample_count": 8}
        },
        "measurement_pool_wall_minutes": {"median": 7.2, "sample_count": 12},
        "slot_utilization": 0.5,
        "occupied_terminal_hours": 120.0,
        "available_slot_hours": 240.0,
        "occupied_hours_by_terminal": {f"T{i}": 12.0 for i in range(1, 11)},
        "skipped_wall_no_claim": 0,
        "skipped_utilization_no_binding": 0,
        "queue_by_phase": {"Q09": {"pending": 3, "active": 1}},
        "measurement_pool_queue": {"pending": 4, "active": 2},
        "other_non_gate_queue": {"pending": 0, "active": 0},
        "cpu_high_pause_events": 24,
        "cpu_high_pause_events_per_hour": 1.0,
        "cpu_high_pause_events_per_slot_hour": 0.1,
        "cpu_high_pause_by_terminal": {f"T{i}": 1 for i in range(1, 11)},
        "coverage_complete": True,
        "disabled_terminals_file": {
            "bytes": 0,
            "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        },
    }
    csv_path, report_path = concurrency_ab_measure.write_outputs(
        snapshot,
        output_dir=tmp_path,
        output_stem="baseline",
        label="BASELINE_10",
    )
    with csv_path.open(encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert {row["metric"] for row in rows} >= {
        "execution_verdicts_per_day",
        "measured_cells_per_hour",
        "cpu_high_pause_events_per_hour",
        "median_wall_minutes",
        "slot_utilization",
    }
    report = report_path.read_text(encoding="utf-8")
    assert "BASELINE_MEASURED_NO_SWITCH" in report
    assert "Phase-2 switch checklist — not executed" in report
    assert "exactly an empty `disabled_terminals.txt`" in report
    assert "never start `terminal64.exe` manually" in report
