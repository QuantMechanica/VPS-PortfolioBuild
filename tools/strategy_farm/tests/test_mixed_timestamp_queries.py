from __future__ import annotations

import re
import sqlite3
from pathlib import Path

from tools.strategy_farm.sqlite_timestamp import normalized_timestamp_sql, parse_timestamp


SURFACES = (
    "throughput_telemetry.py",
    "heartbeat_snapshot.py",
    "mission_control_v2_data.py",
    "morning_brief.py",
    "health.py",
    "render_cockpit.py",
    "concurrency_ab_measure.py",
    "near_miss_register.py",
    "news_gate_service.py",
    "optimization_fork_driver.py",
    "portfolio/book_reoptimizer.py",
    "evidence_cohort_watch.py",
    "ws0_notifier.py",
    "prune_workitem_logs.py",
)


def _fixture() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.execute("CREATE TABLE rows(id TEXT PRIMARY KEY, updated_at TEXT NOT NULL)")
    con.executemany(
        "INSERT INTO rows VALUES(?,?)",
        (
            ("old_t", "2026-08-29T22:59:59+00:00"),
            ("old_space", "2026-08-29 22:59:59"),
            ("new_t", "2026-08-29T23:00:01+00:00"),
            ("new_space", "2026-08-29 23:00:01"),
        ),
    )
    return con


def test_mixed_separator_window_and_age_classification_are_equivalent() -> None:
    con = _fixture()
    stamp = normalized_timestamp_sql("updated_at")
    recent = {
        row[0]
        for row in con.execute(
            f"SELECT id FROM rows WHERE {stamp} >= datetime(?) ORDER BY {stamp},id",
            ("2026-08-29T23:00:00+00:00",),
        )
    }
    old = {
        row[0]
        for row in con.execute(
            f"SELECT id FROM rows WHERE {stamp} < datetime(?) ORDER BY {stamp},id",
            ("2026-08-29 23:00:00",),
        )
    }
    assert recent == {"new_t", "new_space"}
    assert old == {"old_t", "old_space"}


def test_python_operational_comparison_accepts_both_shapes() -> None:
    assert parse_timestamp("2026-08-29T23:00:01+00:00") == parse_timestamp(
        "2026-08-29 23:00:01"
    )


def test_all_audited_surfaces_use_shared_helper_without_raw_parameter_comparison() -> None:
    root = Path(__file__).resolve().parents[1]
    raw = re.compile(r"\bupdated_at\s*(?:>=|<=|>|<)\s*\?")
    for relative in SURFACES:
        source = (root / relative).read_text(encoding="utf-8")
        assert "normalized_timestamp_sql" in source, relative
        assert not raw.search(source), relative


def test_identifier_validation_rejects_sql_injection() -> None:
    try:
        normalized_timestamp_sql("updated_at); DROP TABLE rows;--")
    except ValueError:
        pass
    else:
        raise AssertionError("unsafe identifier accepted")
