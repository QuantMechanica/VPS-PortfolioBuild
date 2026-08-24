from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import gate_manifest, path25_red_team


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture_db(path: Path, *, add_phase3_bypass: bool = False) -> Path:
    connection = sqlite3.connect(path)
    connection.execute(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
          setfile_path TEXT,status TEXT,verdict TEXT,payload_json TEXT,
          created_at TEXT,updated_at TEXT,gate_contract_version TEXT
        )
        """
    )
    manifest = gate_manifest.load_gate_manifest()
    for ordinal in range(2, 15):
        phase = f"Q{ordinal:02d}"
        verdict = "KEEP_INCUMBENT" if phase == "Q14" else "PASS"
        payload = {}
        if phase in {"Q12", "Q13", "Q14"}:
            payload = {
                "schema": "qm.opt-fork-routing/v1",
                "phase": phase,
                "gate_contract_version": "v4",
                "expected_ex5_sha256": "a" * 64,
                "expected_mq5_sha256": "b" * 64,
                "expected_setfile_sha256": "c" * 64,
                "gate_manifest_sha256": manifest.sha256,
                "parent_work_item_id": "parent",
                "parent_bindings": {
                    "binary": {"sha256": "a" * 64},
                    "source": {"sha256": "b" * 64},
                    "setfile": {"sha256": "c" * 64},
                    "evidence": {"sha256": "e" * 64},
                },
            }
            canonical = json.dumps(
                payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True
            ) + "\n"
            payload["routing_identity_sha256"] = hashlib.sha256(
                canonical.encode("utf-8")
            ).hexdigest()
        storage_phase = "Q10_NEWS" if phase == "Q10" else phase
        connection.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                f"row-{phase}", "analytic", storage_phase, "QM5_999999",
                "EURUSD.DWX", "fixture.set", "done", verdict,
                json.dumps(payload), "2026-08-24T00:00:00+00:00",
                "2026-08-24T01:00:00+00:00", "v4",
            ),
        )
    if add_phase3_bypass:
        connection.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                "illegal-q15", "analytic", "Q15", "QM5_999999",
                "EURUSD.DWX", "fixture.set", "pending", None, "{}",
                "2026-08-24T02:00:00+00:00", "2026-08-24T02:00:00+00:00", "v4",
            ),
        )
    connection.commit()
    connection.close()
    return path


def _check(report: dict, check_id: str) -> dict:
    return next(row for row in report["checks"] if row["id"] == check_id)


def test_active_manifest_has_closed_linear_runtime_path() -> None:
    _manifest, _raw, checks = path25_red_team.audit_manifest()
    by_id = {row.id: row for row in checks}

    assert by_id["contract.active_v4"].status == "PASS"
    assert by_id["contract.q14_is_per_ea_terminal"].status == "PASS"
    assert by_id["contract.book_trigger_authority"].status == "PASS"
    assert by_id["runtime.linear_phase2_path"].evidence["canonical_path"] == [
        "Q08", "Q09", "Q10", "Q11", "Q12", "Q13", "Q14"
    ]


def test_audit_is_physically_read_only_and_reports_unfinished_pool(tmp_path: Path) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    before = _sha256(db)

    report = path25_red_team.build_audit(db)

    assert _sha256(db) == before
    assert _check(report, "observer.sqlite_read_only")["status"] == "PASS"
    assert _check(report, "evidence.optimization_binding_coverage")["status"] == "PASS"
    assert _check(report, "evidence.qualified_pool")["status"] == "WARN"
    assert report["database"]["path_to_25"]["qualified_pairs"] == 1

    connection = path25_red_team._open_ro(db)
    with pytest.raises(sqlite3.OperationalError):
        connection.execute(
            "INSERT INTO work_items(id,phase) VALUES ('mutation','Q00')"
        )
    connection.close()


def test_phase3_row_below_25_is_a_hard_failure(tmp_path: Path) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite", add_phase3_bypass=True)

    report = path25_red_team.build_audit(db)

    bypass = _check(report, "evidence.no_phase3_bypass")
    assert bypass["status"] == "FAIL"
    assert bypass["evidence"]["phase3_rows"] == 1
    assert report["status"] == "FAIL"


def test_column_only_v4_migration_does_not_masquerade_as_native_binding(
    tmp_path: Path,
) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    connection = sqlite3.connect(db)
    payload = json.loads(connection.execute(
        "SELECT payload_json FROM work_items WHERE id='row-Q12'"
    ).fetchone()[0])
    payload["phase"] = "Q14"
    payload["gate_contract_version"] = "v3"
    payload["gate_manifest_sha256"] = "f" * 64
    unsigned = dict(payload)
    unsigned.pop("routing_identity_sha256", None)
    canonical = json.dumps(
        unsigned, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ) + "\n"
    payload["routing_identity_sha256"] = hashlib.sha256(
        canonical.encode("utf-8")
    ).hexdigest()
    connection.execute(
        "UPDATE work_items SET payload_json=? WHERE id='row-Q12'",
        (json.dumps(payload),),
    )
    connection.commit()
    connection.close()

    report = path25_red_team.build_audit(db)

    binding = _check(report, "evidence.optimization_binding_coverage")
    invalid = binding["evidence"]["by_phase"]["Q12"]["invalid_rows"][0]
    assert binding["status"] == "FAIL"
    assert invalid["reasons"] == [
        "payload_contract_version_mismatch",
        "payload_phase_mismatch",
        "active_manifest_hash_mismatch",
    ]
