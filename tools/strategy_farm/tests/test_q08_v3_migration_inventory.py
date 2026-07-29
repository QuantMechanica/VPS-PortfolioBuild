from __future__ import annotations

import copy
import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

import pytest


TOOLS = Path(__file__).resolve().parents[1]
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import q08_v3_migration_inventory as subject  # noqa: E402


WORK_ITEMS_SCHEMA = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT NOT NULL,
    phase TEXT NOT NULL,
    ea_id TEXT NOT NULL,
    symbol TEXT NOT NULL,
    setfile_path TEXT NOT NULL,
    status TEXT NOT NULL,
    verdict TEXT,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);
"""


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _insert(connection: sqlite3.Connection, item_id: str, **overrides: Any) -> None:
    row: dict[str, Any] = {
        "id": item_id,
        "kind": "backtest",
        "phase": "Q08",
        "ea_id": "QM5_100",
        "symbol": "EURUSD.DWX",
        "setfile_path": "sets/base.set",
        "status": "done",
        "verdict": "PASS",
        "attempt_count": 1,
        "parent_task_id": None,
        "evidence_path": "evidence/result.json",
        "claimed_by": None,
        "payload_json": "{}",
        "created_at": "2026-01-01T00:00:00Z",
        "updated_at": "2026-01-01T01:00:00Z",
    }
    row.update(overrides)
    connection.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(
          :id,:kind,:phase,:ea_id,:symbol,:setfile_path,:status,:verdict,:attempt_count,
          :parent_task_id,:evidence_path,:claimed_by,:payload_json,:created_at,:updated_at
        )
        """,
        row,
    )


@pytest.fixture()
def inventory_fixture(tmp_path: Path) -> dict[str, Any]:
    artifacts = tmp_path / "artifacts"
    (artifacts / "sets").mkdir(parents=True)
    (artifacts / "evidence").mkdir(parents=True)
    (artifacts / "sets" / "base.set").write_text("Risk=1\n", encoding="utf-8")
    (artifacts / "evidence" / "result.json").write_text("{}\n", encoding="utf-8")

    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as connection:
        connection.executescript(WORK_ITEMS_SCHEMA)
        _insert(
            connection,
            "q08-current",
            payload_json=json.dumps(
                {
                    "candidate_lineage_key": "lineage-current",
                    "aliases": ["shared-alias"],
                },
                sort_keys=True,
            ),
        )
        _insert(
            connection,
            "q08-soft",
            ea_id="QM5_101",
            verdict="FAIL_SOFT",
            payload_json=json.dumps(
                {
                    "candidate_lineage_key": "lineage-soft",
                    "aliases": ["shared-alias"],
                },
                sort_keys=True,
            ),
        )
        _insert(
            connection,
            "q08-hard",
            ea_id="QM5_102",
            verdict="FAIL_HARD",
        )
        _insert(
            connection,
            "q08-infra",
            ea_id="QM5_103",
            status="failed",
            verdict="INFRA_FAIL",
        )
        _insert(
            connection,
            "q08-superseded",
            ea_id="QM5_104",
            verdict="SUPERSEDED_DUPLICATE",
            payload_json=json.dumps(
                {"candidate_lineage_key": "lineage-soft"}, sort_keys=True
            ),
        )
        _insert(
            connection,
            "q08-invalid",
            ea_id="QM5_105",
            payload_json='{ "candidate_lineage_key": "x", "candidate_lineage_key": "y" }',
        )
        _insert(connection, "q07-ignored", phase="Q07")
        connection.commit()

    targets = {
        "schema_version": subject.TARGETS_SCHEMA_VERSION,
        "targets": [
            {
                "target": "DXZ",
                "selector_type": "WORK_ITEM_ID",
                "selector": "q08-current",
            },
            {
                "target": "FTMO",
                "selector_type": "LINEAGE_KEY",
                "selector": "not-present",
            },
        ],
    }
    return {"db": db, "artifacts": artifacts, "targets": targets}


def _assert_every_object_schema_is_closed_or_typed(node: Any) -> None:
    if isinstance(node, dict):
        if node.get("type") == "object":
            assert "additionalProperties" in node
        for child in node.values():
            _assert_every_object_schema_is_closed_or_typed(child)
    elif isinstance(node, list):
        for child in node:
            _assert_every_object_schema_is_closed_or_typed(child)


def test_inventory_is_complete_read_only_and_byte_deterministic(
    inventory_fixture: dict[str, Any], monkeypatch: pytest.MonkeyPatch
) -> None:
    db = inventory_fixture["db"]
    before_sha = _sha(db)
    before_sidecars = sorted(path.name for path in db.parent.glob("farm.sqlite-*"))
    real_connect = sqlite3.connect
    calls: list[tuple[str, dict[str, Any]]] = []

    def connect_spy(database: object, *args: Any, **kwargs: Any) -> sqlite3.Connection:
        calls.append((str(database), dict(kwargs)))
        return real_connect(database, *args, **kwargs)

    monkeypatch.setattr(subject.sqlite3, "connect", connect_spy)
    first = subject.build_inventory(
        db,
        current_targets=inventory_fixture["targets"],
        artifact_root=inventory_fixture["artifacts"],
        source_label="fixture/farm.sqlite",
    )
    second = subject.build_inventory(
        db,
        current_targets=inventory_fixture["targets"],
        artifact_root=inventory_fixture["artifacts"],
        source_label="fixture/farm.sqlite",
    )

    assert first == second
    assert subject.render_json_bytes(first) == subject.render_json_bytes(second)
    assert first["inventory_sha256"] == subject.canonical_sha256(
        {key: value for key, value in first.items() if key != "inventory_sha256"}
    )
    assert first["source"]["q08_policy_binding"] == (
        subject.canonical_q08_policy_binding()
    )
    assert first["summary"]["row_count"] == 6
    assert [row["work_item_id"] for row in first["records"]] == sorted(
        row["work_item_id"] for row in first["records"]
    )
    assert sum(first["summary"]["disposition_counts"].values()) == 6
    assert first["summary"]["disposition_counts"] == {
        "CURRENT": 1,
        "LEGACY_UNVERIFIED": 2,
        "ELIGIBLE_REEVALUATION": 1,
        "INVALID": 1,
        "SUPERSEDED": 1,
    }
    by_id = {row["work_item_id"]: row for row in first["records"]}
    assert by_id["q08-current"]["targets"] == ["DXZ"]
    assert by_id["q08-current"]["priority"] == "P0_CURRENT_TARGET"
    assert by_id["q08-soft"]["priority"] == "P2_V2_FAIL_SOFT"
    assert by_id["q08-invalid"]["disposition"] == "INVALID"
    assert "PAYLOAD_JSON_INVALID" in by_id["q08-invalid"]["reason_codes"]
    assert all(
        artifact["state"] == "VERIFIED"
        for artifact in by_id["q08-current"]["artifacts"]
    )
    assert first["summary"]["unmatched_target_selectors"] == [
        {
            "target": "FTMO",
            "selector_type": "LINEAGE_KEY",
            "selector": "not-present",
        }
    ]

    assert calls
    assert all(uri.endswith("?mode=ro") for uri, _ in calls)
    assert all(kwargs.get("uri") is True for _, kwargs in calls)
    assert first["database_access"] == {
        "sqlite_uri_mode": "ro",
        "pragma_query_only": True,
        "writes_supported": False,
    }
    assert _sha(db) == before_sha
    assert sorted(path.name for path in db.parent.glob("farm.sqlite-*")) == before_sidecars


def test_self_hashed_inventory_cannot_substitute_an_arbitrary_policy_binding(
    inventory_fixture: dict[str, Any],
) -> None:
    inventory = subject.build_inventory(
        inventory_fixture["db"],
        current_targets=inventory_fixture["targets"],
        artifact_root=inventory_fixture["artifacts"],
        source_label="fixture/farm.sqlite",
    )
    inventory["source"]["q08_policy_binding"]["canonical_sha256"] = "0" * 64
    inventory["inventory_sha256"] = subject.canonical_sha256(
        {key: value for key, value in inventory.items() if key != "inventory_sha256"}
    )

    with pytest.raises(subject.InventoryError, match="current canonical Q08-v3 policy"):
        subject.validate_inventory(inventory)


def test_query_only_connection_rejects_writes(inventory_fixture: dict[str, Any]) -> None:
    db = inventory_fixture["db"]
    before = _sha(db)
    with subject.open_read_only_database(db) as connection:
        assert connection.execute("PRAGMA query_only").fetchone()[0] == 1
        with pytest.raises(sqlite3.OperationalError, match="readonly"):
            connection.execute("CREATE TABLE forbidden_write(id INTEGER)")
    assert _sha(db) == before


def test_alias_and_lineage_collisions_are_explicit(inventory_fixture: dict[str, Any]) -> None:
    inventory = subject.build_inventory(
        inventory_fixture["db"],
        current_targets=inventory_fixture["targets"],
        artifact_root=inventory_fixture["artifacts"],
    )
    collisions = {
        (row["collision_type"], row["key"]): row for row in inventory["collisions"]
    }
    alias = collisions[("ALIAS_TO_MULTIPLE_LINEAGES", "shared-alias")]
    assert alias["blocking"] is True
    assert alias["work_item_ids"] == ["q08-current", "q08-soft"]
    lineage = collisions[("MULTIPLE_WORK_ITEMS_FOR_LINEAGE", "lineage-soft")]
    assert lineage["blocking"] is False
    assert lineage["work_item_ids"] == ["q08-soft", "q08-superseded"]
    assert inventory["summary"]["blocking_work_item_ids"] == [
        "q08-current",
        "q08-soft",
    ]


def test_inventory_validator_rejects_extra_keys_and_hash_drift(
    inventory_fixture: dict[str, Any]
) -> None:
    inventory = subject.build_inventory(inventory_fixture["db"])
    extra = copy.deepcopy(inventory)
    extra["unexpected"] = True
    with pytest.raises(subject.InventoryError, match="key set mismatch"):
        subject.validate_inventory(extra)

    drift = copy.deepcopy(inventory)
    drift["records"][0]["ea_id"] = "QM5_TAMPERED"
    with pytest.raises(subject.InventoryError, match="record_sha256 mismatch"):
        subject.validate_inventory(drift)


def test_missing_schema_and_bad_target_manifest_fail_closed(tmp_path: Path) -> None:
    db = tmp_path / "missing.sqlite"
    with sqlite3.connect(db) as connection:
        connection.execute("CREATE TABLE work_items(id TEXT PRIMARY KEY, phase TEXT)")
    with pytest.raises(subject.InventoryError, match="missing required columns"):
        subject.build_inventory(db)

    duplicate = {
        "schema_version": subject.TARGETS_SCHEMA_VERSION,
        "targets": [
            {"target": "DXZ", "selector_type": "WORK_ITEM_ID", "selector": "x"},
            {"target": "DXZ", "selector_type": "WORK_ITEM_ID", "selector": "x"},
        ],
    }
    with pytest.raises(subject.InventoryError, match="duplicate current-target selector"):
        subject._normalize_target_manifest(duplicate)


def test_known_legacy_fail_and_invalid_have_explicit_dispositions() -> None:
    fail = subject._classify(
        status="done", verdict="FAIL", targets=[], structural_reasons=[]
    )
    invalid = subject._classify(
        status="done", verdict="INVALID", targets=[], structural_reasons=[]
    )
    assert fail == (
        "LEGACY_UNVERIFIED",
        "P3_LEGACY",
        ["LEGACY_UNNORMALIZED_FAIL"],
    )
    assert invalid == (
        "INVALID",
        "HOLD_INVALID",
        ["LEGACY_EVIDENCE_INVALID"],
    )


def test_inventory_json_schema_is_strict_and_loadable() -> None:
    schema_path = TOOLS / "schemas" / "q08_v3_migration_inventory_v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    assert schema["$schema"] == "https://json-schema.org/draft/2020-12/schema"
    assert schema["additionalProperties"] is False
    _assert_every_object_schema_is_closed_or_typed(schema)
