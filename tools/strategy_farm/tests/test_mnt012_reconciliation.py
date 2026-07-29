from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

import pytest


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import reconcile_blocked_build_tasks as reconciliation  # noqa: E402


def _fixture(tmp_path: Path) -> tuple[Path, Path, Path, Path, dict]:
    db = tmp_path / "farm_state.sqlite"
    factory_off = tmp_path / "FACTORY_OFF.flag"
    card = tmp_path / "QM5_99001_guard.md"
    source = tmp_path / "QM5_99001_guard.mq5"
    manifest_path = tmp_path / "manifest.json"
    factory_off.write_text("intentional maintenance\n", encoding="utf-8")
    card.write_text("---\nea_id: QM5_99001\n---\n", encoding="utf-8")
    source.write_text("bool Strategy_EntrySignal() { return false; }\n", encoding="utf-8")
    payload = {
        "ea_id": "QM5_99001",
        "card_path": str(card),
        "blocked_at_utc": "2026-07-25T11:49:18+00:00",
        "last_blocked_reason": "r3_missing",
    }
    payload_json = json.dumps(payload)
    with sqlite3.connect(db) as conn:
        conn.executescript(
            """
            CREATE TABLE tasks(
                id TEXT PRIMARY KEY, kind TEXT NOT NULL, status TEXT NOT NULL,
                source_id TEXT, card_id TEXT, payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL, updated_at TEXT NOT NULL
            );
            CREATE TABLE events(
                id INTEGER PRIMARY KEY, ts TEXT NOT NULL, entity_type TEXT NOT NULL,
                entity_id TEXT NOT NULL, event TEXT NOT NULL, detail_json TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            INSERT INTO tasks VALUES(
                'task-1', 'build_ea', 'pending', NULL, 'QM5_99001', ?,
                '2026-07-25T11:00:00+00:00', '2026-07-25T11:49:18+00:00'
            )
            """,
            (payload_json,),
        )
        conn.commit()
    patch = {
        "blocked_reason": "r3_missing",
        "mnt012_reconciliation": {
            "run_id": "MNT012-TEST-01",
            "transition": "pending_to_blocked",
        },
    }
    target_payload = dict(payload)
    target_payload.update(patch)
    manifest = {
        "schema_version": reconciliation.SCHEMA_VERSION,
        "run_id": "MNT012-TEST-01",
        "bindings": {
            "database": {
                "file_sha256": reconciliation.sha256_file(db),
                "logical_state_sha256": reconciliation.sqlite_state_sha256(db),
            },
            "factory_off": {"sha256": reconciliation.sha256_file(factory_off)},
        },
        "operations": [
            {
                "task_id": "task-1",
                "expected": {
                    "kind": "build_ea",
                    "status": "pending",
                    "card_id": "QM5_99001",
                    "updated_at": "2026-07-25T11:49:18+00:00",
                    "payload_sha256": reconciliation.sha256_text(payload_json),
                },
                "card": {
                    "path": str(card),
                    "sha256": reconciliation.sha256_file(card),
                },
                "source_diagnostic": {
                    "path": str(source),
                    "sha256": reconciliation.sha256_file(source),
                },
                "target": {
                    "status": "blocked",
                    "updated_at": "2026-07-29T11:30:00+00:00",
                    "payload_patch": patch,
                    "payload_sha256": reconciliation.sha256_text(
                        reconciliation.canonical_json(target_payload)
                    ),
                },
            }
        ],
    }
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return db, factory_off, card, manifest_path, manifest


def test_forecast_is_read_only_and_exact(tmp_path: Path) -> None:
    db, factory_off, card, manifest_path, _ = _fixture(tmp_path)
    loaded = reconciliation.load_manifest(manifest_path)
    before = {
        "db": reconciliation.sha256_file(db),
        "flag": reconciliation.sha256_file(factory_off),
        "card": reconciliation.sha256_file(card),
    }

    result = reconciliation.forecast(
        db,
        factory_off,
        loaded,
        manifest_path=manifest_path,
    )

    assert result["mode"] == "forecast_read_only"
    assert result["ready_to_apply"] is True
    assert result["mutated"] is False
    assert result["operations"][0]["current_status"] == "pending"
    assert result["operations"][0]["target_status"] == "blocked"
    assert before == {
        "db": reconciliation.sha256_file(db),
        "flag": reconciliation.sha256_file(factory_off),
        "card": reconciliation.sha256_file(card),
    }


def test_forecast_binds_diagnostic_source_hash(tmp_path: Path) -> None:
    db, factory_off, _, manifest_path, _ = _fixture(tmp_path)
    loaded = reconciliation.load_manifest(manifest_path)
    source = Path(loaded["operations"][0]["source_diagnostic"]["path"])
    source.write_text("changed source\n", encoding="utf-8")

    result = reconciliation.forecast(
        db,
        factory_off,
        loaded,
        manifest_path=manifest_path,
    )

    assert result["ready_to_apply"] is False
    assert any(
        mismatch.startswith("source_sha256:")
        for mismatch in result["operations"][0]["mismatches"]
    )


def test_apply_is_hashbound_snapshotted_and_cas_guarded(tmp_path: Path) -> None:
    db, factory_off, card, manifest_path, _ = _fixture(tmp_path)
    loaded = reconciliation.load_manifest(manifest_path)
    snapshot = tmp_path / "snapshots" / "pre.sqlite"
    card_sha = reconciliation.sha256_file(card)

    with pytest.raises(reconciliation.ReconciliationError, match="manifest SHA-256 mismatch"):
        reconciliation.apply_reconciliation(
            db,
            factory_off,
            manifest_path,
            loaded,
            expected_manifest_sha256="0" * 64,
            confirm_run_id="MNT012-TEST-01",
            snapshot_path=snapshot,
            mutation_lock_path=tmp_path / "mutation.lock",
        )
    assert not snapshot.exists()

    applied = reconciliation.apply_reconciliation(
        db,
        factory_off,
        manifest_path,
        loaded,
        expected_manifest_sha256=reconciliation.sha256_file(manifest_path),
        confirm_run_id="MNT012-TEST-01",
        snapshot_path=snapshot,
        mutation_lock_path=tmp_path / "mutation.lock",
    )

    assert applied["mutated"] is True
    assert snapshot.is_file()
    assert reconciliation.sha256_file(card) == card_sha
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute("SELECT status, payload_json FROM tasks WHERE id='task-1'").fetchone()
        event = conn.execute(
            "SELECT event, entity_id FROM events WHERE entity_id='task-1'"
        ).fetchone()
    stored = json.loads(row["payload_json"])
    assert row["status"] == "blocked"
    assert stored["blocked_reason"] == "r3_missing"
    assert stored["mnt012_reconciliation"]["run_id"] == "MNT012-TEST-01"
    assert dict(event) == {
        "event": "mnt012_build_task_reconciled",
        "entity_id": "task-1",
    }
    db_before_second = reconciliation.sha256_file(db)
    second = reconciliation.apply_reconciliation(
        db,
        factory_off,
        manifest_path,
        loaded,
        expected_manifest_sha256=reconciliation.sha256_file(manifest_path),
        confirm_run_id="MNT012-TEST-01",
        snapshot_path=snapshot,
        mutation_lock_path=tmp_path / "mutation.lock",
    )
    assert second["mode"] == "apply_idempotent_noop"
    assert second["already_applied"] is True
    assert second["mutated"] is False
    assert reconciliation.sha256_file(db) == db_before_second
    with sqlite3.connect(db) as conn:
        assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1
        assert conn.execute(
            "SELECT COUNT(*) FROM build_task_reconciliation_ledger"
        ).fetchone()[0] == 1
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute(
                "UPDATE build_task_reconciliation_ledger SET to_status='pending'"
            )
        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("DELETE FROM build_task_reconciliation_ledger")
