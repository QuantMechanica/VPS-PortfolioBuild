from __future__ import annotations

import sqlite3
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

import public_snapshot_incident_guard as guard  # noqa: E402


def _database(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.execute(
        """
        CREATE TABLE work_item_holds (
            work_item_id TEXT PRIMARY KEY,
            hold_code TEXT NOT NULL,
            active INTEGER NOT NULL
        )
        """
    )
    return conn


def test_publication_allowed_without_active_incident_holds(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    with _database(database) as conn:
        conn.executemany(
            "INSERT INTO work_item_holds VALUES (?,?,?)",
            [
                ("ordinary", "OWNER_REVIEW", 1),
                ("inactive-incident", guard.BLOCKING_HOLD_CODES[0], 0),
            ],
        )

    result = guard.inspect_public_snapshot_incident_holds(database)

    assert result["valid"] is True
    assert result["publication_allowed"] is True
    assert result["active_incident_hold_count"] == 0
    assert result["error"] is None
    assert result["error_code"] is None


def test_each_active_q02_bypass_incident_blocks_publication(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    with _database(database) as conn:
        conn.executemany(
            "INSERT INTO work_item_holds VALUES (?,?,?)",
            [
                ("factory-off", guard.BLOCKING_HOLD_CODES[0], 1),
                ("stale-build", guard.BLOCKING_HOLD_CODES[1], 1),
            ],
        )

    result = guard.inspect_public_snapshot_incident_holds(database)

    assert result["valid"] is True
    assert result["publication_allowed"] is False
    assert result["active_incident_hold_count"] == 2
    assert {row["hold_code"] for row in result["active_incident_holds"]} == set(
        guard.BLOCKING_HOLD_CODES
    )
    assert result["error"] is None


def test_missing_database_fails_closed_without_creating_it(tmp_path: Path) -> None:
    database = tmp_path / "missing.sqlite"

    result = guard.inspect_public_snapshot_incident_holds(database)

    assert result["valid"] is False
    assert result["publication_allowed"] is False
    assert result["error_code"] == "incident_hold_read_failed"
    assert not database.exists()


def test_invalid_hold_schema_fails_closed(tmp_path: Path) -> None:
    database = tmp_path / "farm.sqlite"
    with sqlite3.connect(database) as conn:
        conn.execute("CREATE TABLE work_item_holds (work_item_id TEXT PRIMARY KEY)")

    result = guard.inspect_public_snapshot_incident_holds(database)

    assert result["valid"] is False
    assert result["publication_allowed"] is False
    assert result["error_code"] == "incident_hold_read_failed"


@pytest.mark.parametrize("invalid_active", [2, "yes"])
def test_invalid_incident_hold_active_value_fails_closed(
    tmp_path: Path, invalid_active: object
) -> None:
    database = tmp_path / "farm.sqlite"
    with _database(database) as conn:
        conn.execute(
            "INSERT INTO work_item_holds VALUES (?,?,?)",
            ("invalid-active", guard.BLOCKING_HOLD_CODES[0], invalid_active),
        )

    result = guard.inspect_public_snapshot_incident_holds(database)

    assert result["valid"] is False
    assert result["publication_allowed"] is False
    assert result["error_code"] == "incident_hold_read_failed"


def test_wrapper_invokes_incident_guard_before_first_snapshot_writer() -> None:
    source = (REPO / "scripts" / "run_public_snapshot_task.ps1").read_text(
        encoding="utf-8-sig"
    )

    guard_call = source.index("$guardOutput = @(& $PythonExe $incidentGuardScript")
    pipeline_writer = source.index("scripts\\build_pipeline_state.py")
    public_writer = source.index("scripts\\export_public_snapshot.ps1")
    assert guard_call < pipeline_writer < public_writer
    assert "qm-public-snapshot-incident-guard/v1" in source
    assert "-not [bool]$incidentGuard.publication_allowed" in source
