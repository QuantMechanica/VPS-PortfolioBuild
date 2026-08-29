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

import pytest  # noqa: E402


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


def test_gate_contract_schema_steady_state_performs_no_write_or_ddl() -> None:
    conn = _legacy_connection()
    first = farmctl.ensure_work_item_gate_contract_schema(conn)
    assert first == {"column_added": 1, "rows_backfilled": 0}
    conn.commit()
    denied = {
        sqlite3.SQLITE_INSERT,
        sqlite3.SQLITE_UPDATE,
        sqlite3.SQLITE_DELETE,
        sqlite3.SQLITE_ALTER_TABLE,
        sqlite3.SQLITE_CREATE_TRIGGER,
        sqlite3.SQLITE_DROP_TRIGGER,
    }

    def authorizer(action, _arg1, _arg2, _database, _source):
        return sqlite3.SQLITE_DENY if action in denied else sqlite3.SQLITE_OK

    conn.set_authorizer(authorizer)
    second = farmctl.ensure_work_item_gate_contract_schema(conn)
    assert second == {"column_added": 0, "rows_backfilled": 0}


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
        "unstamped-legacy": phase_ids.LEGACY_P_TO_Q["P9"],
        "v3-incumbent": phase_ids.display_phase("Q10", "v3"),
        "v4-news": phase_ids.display_phase("Q10", "v4"),
    }
    assert rendered["v3-incumbent"] != rendered["v4-news"]


def test_backfill_cutoff_is_the_true_v3_activation_instant() -> None:
    """The cutoff must be the real v3 default-activation instant (commit
    d4e4dcfcb, 2026-08-23 12:18:19 +0200 = 10:18:19Z), not local midnight.
    A row enqueued in the 09:00-10:18Z window ran while v2 was still the
    default and must never be silently reinterpreted as v3 (review fix P2 #2)."""

    assert farmctl.GATE_CONTRACT_V3_BACKFILL_CUTOFF == "2026-08-23T10:18:19Z"

    conn = _legacy_connection()
    conn.executemany(
        "INSERT INTO work_items(id,phase,payload_json,created_at) VALUES(?,?,?,?)",
        (
            # Enqueued after midnight but BEFORE v3 became the default.
            ("pre-activation", "Q10", "{}", "2026-08-23T09:30:00Z"),
            # Exactly at the activation instant -> v3.
            ("at-activation", "Q10", "{}", "2026-08-23T10:18:19Z"),
            # After activation -> v3.
            ("post-activation", "Q10", "{}", "2026-08-23T11:00:00Z"),
        ),
    )
    farmctl.ensure_work_item_gate_contract_schema(conn)
    stamped = {
        row["id"]: row["gate_contract_version"]
        for row in conn.execute("SELECT id, gate_contract_version FROM work_items")
    }
    assert stamped["pre-activation"] == "legacy"
    assert stamped["at-activation"] == "v3"
    assert stamped["post-activation"] == "v3"


def test_display_helpers_degrade_on_unknown_contract_version() -> None:
    """phase_qid/phase_label/normalize_phase_id promise graceful degradation and
    must never hard-fail on an unrecognised version token; the raw token is kept
    as provenance instead (review fix P2 #3)."""

    # No exception on an unknown version; phase passes through.
    assert phase_ids.phase_qid("Q05", "v9") == "Q05"
    assert phase_ids.normalize_phase_id("Q05", "v9") == "Q05"
    # The unrecognised token is surfaced as raw provenance, not swallowed.
    assert phase_ids.phase_label("Q05", "v9") == "Q05 (v9:Q05)"
    assert phase_ids.display_phase("Q07", "not-a-version") == "Q07 (not-a-version:Q07)"


def test_contract_version_normaliser_strict_mode_still_rejects() -> None:
    """The strict path (explicit write/validation) keeps the hard fail, so an
    unexpected token cannot be silently written (review fix P2 #3)."""

    assert phase_ids._normalise_contract_version("v9") == "v9"  # display degrade
    assert phase_ids._normalise_contract_version(None) is None
    assert phase_ids._normalise_contract_version("legacy") is None
    with pytest.raises(ValueError):
        phase_ids._normalise_contract_version("v9", strict=True)


def test_phase_and_bound_payload_provenance_are_immutable() -> None:
    conn = _legacy_connection()
    farmctl.ensure_work_item_gate_contract_schema(conn)
    conn.execute(
        "INSERT INTO work_items(id,phase,payload_json,created_at,gate_contract_version) "
        "VALUES(?,?,?,?,?)",
        ("unbound", "Q12", "{}", "2026-08-24T00:00:00Z", "v4"),
    )
    payload = json.dumps({"phase": "Q12", "gate_contract_version": "v4"})
    conn.execute(
        "INSERT INTO work_items(id,phase,payload_json,created_at,gate_contract_version) "
        "VALUES(?,?,?,?,?)",
        ("bound", "Q12", payload, "2026-08-24T00:00:00Z", "v4"),
    )

    with pytest.raises(sqlite3.IntegrityError, match="phase is append-only"):
        conn.execute("UPDATE work_items SET phase='Q14' WHERE id='unbound'")
    with pytest.raises(sqlite3.IntegrityError, match="payload provenance"):
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='bound'",
            (json.dumps({"phase": "Q12", "gate_contract_version": "v3"}),),
        )


@pytest.mark.parametrize(
    ("phase", "version", "payload"),
    (
        ("Q12", "v4", {"phase": "Q14", "gate_contract_version": "v4"}),
        ("Q12", "v4", {"phase": "Q12", "gate_contract_version": "v3"}),
    ),
)
def test_insert_rejects_column_payload_provenance_mismatch(
    phase: str, version: str, payload: dict[str, str]
) -> None:
    conn = _legacy_connection()
    farmctl.ensure_work_item_gate_contract_schema(conn)
    with pytest.raises(sqlite3.IntegrityError, match="payload provenance"):
        conn.execute(
            "INSERT INTO work_items(id,phase,payload_json,created_at,gate_contract_version) "
            "VALUES(?,?,?,?,?)",
            ("mismatch", phase, json.dumps(payload), "2026-08-24T00:00:00Z", version),
        )


def test_storage_stamp_cannot_relabel_bound_payload() -> None:
    conn = _legacy_connection()
    farmctl.ensure_work_item_gate_contract_schema(conn)
    with pytest.raises(sqlite3.IntegrityError, match="payload provenance"):
        conn.execute(
            "INSERT INTO work_items(id,phase,payload_json,created_at) VALUES(?,?,?,?)",
            (
                "implicit-mismatch",
                "Q14",
                json.dumps({"phase": "Q14", "gate_contract_version": "v3"}),
                "2026-08-24T00:00:00Z",
            ),
        )
