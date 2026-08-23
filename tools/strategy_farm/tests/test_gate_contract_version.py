from __future__ import annotations

import json
import sqlite3
import sys
from collections import Counter
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import phase_ids  # noqa: E402


def _legacy_connection(*, with_pipeline_version: bool = False) -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    pipeline_column = ", pipeline_version TEXT" if with_pipeline_version else ""
    conn.execute(
        "CREATE TABLE work_items ("
        "id TEXT PRIMARY KEY, phase TEXT, payload_json TEXT NOT NULL, "
        f"created_at TEXT NOT NULL{pipeline_column})"
    )
    return conn


def test_gate_contract_migration_is_idempotent_and_append_only() -> None:
    conn = _legacy_connection()
    conn.executemany(
        "INSERT INTO work_items(id,phase,payload_json,created_at) VALUES(?,?,?,?)",
        (
            ("old-v2", "Q10", json.dumps({"pipeline_version": "v2"}), "2026-08-22T23:00:00Z"),
            ("old-legacy", "P9", "{}", "2026-08-22T23:30:00Z"),
            ("old-malformed", "Q08", "not-json", "2026-08-22T23:45:00Z"),
            ("cutoff-v3", "Q10", "{}", farmctl.GATE_CONTRACT_V3_BACKFILL_CUTOFF),
        ),
    )

    first = farmctl.ensure_work_item_gate_contract_schema(conn)
    assert first == {"column_added": 1, "rows_backfilled": 4}
    assert Counter(
        row[0]
        for row in conn.execute("SELECT gate_contract_version FROM work_items")
    ) == {"legacy": 2, "v2": 1, "v3": 1}

    # The boundary trigger derives its value from the active manifest loader;
    # an explicitly versioned imported row remains untouched.
    conn.execute(
        "INSERT INTO work_items(id,phase,payload_json,created_at) VALUES(?,?,?,?)",
        ("new-active", "Q10", "{}", "2026-08-23T10:00:00Z"),
    )
    conn.execute(
        "INSERT INTO work_items(id,phase,payload_json,created_at,gate_contract_version) "
        "VALUES(?,?,?,?,?)",
        ("explicit-v4", "Q10", "{}", "2026-08-23T10:01:00Z", "v4"),
    )
    second = farmctl.ensure_work_item_gate_contract_schema(conn)
    assert second == {"column_added": 0, "rows_backfilled": 0}
    assert conn.execute(
        "SELECT gate_contract_version FROM work_items WHERE id='new-active'"
    ).fetchone()[0] == phase_ids.ACTIVE_GATE_CONTRACT_VERSION
    assert conn.execute(
        "SELECT gate_contract_version FROM work_items WHERE id='explicit-v4'"
    ).fetchone()[0] == "v4"
    try:
        conn.execute(
            "UPDATE work_items SET gate_contract_version='v3' WHERE id='explicit-v4'"
        )
    except sqlite3.IntegrityError as exc:
        assert "append-only" in str(exc)
    else:  # pragma: no cover - fail-closed schema assertion
        raise AssertionError("an existing gate contract stamp was mutable")


def test_backfill_honours_a_real_pipeline_version_column() -> None:
    conn = _legacy_connection(with_pipeline_version=True)
    conn.execute(
        "INSERT INTO work_items(id,phase,payload_json,created_at,pipeline_version) "
        "VALUES(?,?,?,?,?)",
        ("column-v2", "Q10", "{}", "2026-08-01T00:00:00Z", "qm.gate-manifest/v2"),
    )
    farmctl.ensure_work_item_gate_contract_schema(conn)
    assert conn.execute(
        "SELECT gate_contract_version FROM work_items WHERE id='column-v2'"
    ).fetchone()[0] == "v2"


def test_mixed_version_rows_are_rendered_with_their_own_contract_semantics() -> None:
    conn = _legacy_connection()
    farmctl.ensure_work_item_gate_contract_schema(conn)
    conn.executemany(
        "INSERT INTO work_items(id,phase,payload_json,created_at,gate_contract_version) "
        "VALUES(?,?,?,?,?)",
        (
            ("v3-incumbent", "Q10", "{}", "2026-08-23T10:00:00Z", "v3"),
            ("v4-news", "Q10", "{}", "2026-08-23T10:00:01Z", "v4"),
            ("unstamped-legacy", "P9", "{}", "2026-08-23T10:00:02Z", "legacy"),
        ),
    )
    rendered = {
        row["id"]: phase_ids.display_phase(row["phase"], row["gate_contract_version"])
        for row in conn.execute(
            "SELECT id,phase,gate_contract_version FROM work_items ORDER BY id"
        )
    }
    assert rendered == {
        "unstamped-legacy": "Q11",
        "v3-incumbent": "Q10",
        "v4-news": "Q09 (v4:Q10)",
    }
