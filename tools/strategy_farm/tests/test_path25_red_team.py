from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import book_build_guard, gate_manifest, path25_red_team


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


def test_audit_is_physically_read_only_and_reports_pool_as_diagnostic(tmp_path: Path) -> None:
    db = _fixture_db(tmp_path / "farm.sqlite")
    before = _sha256(db)

    report = path25_red_team.build_audit(db, order_dir=tmp_path / "no_orders")

    assert _sha256(db) == before
    assert _check(report, "observer.sqlite_read_only")["status"] == "PASS"
    assert _check(report, "evidence.optimization_binding_coverage")["status"] == "PASS"
    # OWNER-DEC-CBE-20260915: pool size is a diagnostic (INFO), never WARN/FAIL,
    # and its summary must not claim the pool is unqualified or that no book
    # evaluation is licensed.
    pool = _check(report, "evidence.qualified_pool")
    assert pool["status"] == "INFO"
    assert pool["evidence"]["trigger_policy"] == book_build_guard.TRIGGER_POLICY
    assert "no book trigger is licensed" not in pool["summary"]
    assert report["database"]["path_to_25"]["qualified_pairs"] == 1

    connection = path25_red_team._open_ro(db)
    with pytest.raises(sqlite3.OperationalError):
        connection.execute(
            "INSERT INTO work_items(id,phase) VALUES ('mutation','Q00')"
        )
    connection.close()


def _write_dxz_order(order_dir: Path, date: str = "2026-01-01") -> Path:
    order_dir.mkdir(parents=True, exist_ok=True)
    path = order_dir / f"{date}_owner_book_order_dxz.md"
    path.write_text(
        f"# OWNER book order (test fixture)\n\nOWNER-ORDER: BOOK_BUILD dxz {date}\n",
        encoding="utf-8",
    )
    return path


def test_phase3_row_without_book_authority_is_a_hard_failure(tmp_path: Path) -> None:
    # A Phase-3 row with NO OWNER book order is a real fail-closed bypass,
    # regardless of the pool size (OWNER-DEC-CBE-20260915).
    db = _fixture_db(tmp_path / "farm.sqlite", add_phase3_bypass=True)

    report = path25_red_team.build_audit(db, order_dir=tmp_path / "no_orders")

    bypass = _check(report, "evidence.no_phase3_bypass")
    assert bypass["status"] == "FAIL"
    assert bypass["evidence"]["phase3_rows"] == 1
    assert bypass["evidence"]["book_guard_allowed"] is False
    assert report["status"] == "FAIL"


def test_phase3_row_with_small_valid_pool_and_authority_is_not_a_count_failure(
    tmp_path: Path, monkeypatch
) -> None:
    # A Phase-3 row backed by a non-empty valid pool (here: 1 pair) AND a valid
    # OWNER order is NOT a bypass: the superseded fixed-25 count no longer fails
    # the audit (OWNER-DEC-CBE-20260915: any non-empty valid pool is licensed).
    # The fixture EA has no registry directory, so stub the family fingerprint
    # (which needs one) to let the guard measure the pool; the pool SIZE, not the
    # family count, is the point under test.
    monkeypatch.setattr(book_build_guard, "_count_strategy_families", lambda rows: 1)
    db = _fixture_db(tmp_path / "farm.sqlite", add_phase3_bypass=True)
    order_dir = tmp_path / "decisions"
    _write_dxz_order(order_dir)

    report = path25_red_team.build_audit(db, order_dir=order_dir)

    bypass = _check(report, "evidence.no_phase3_bypass")
    assert bypass["evidence"]["qualified_pairs"] == 1
    assert bypass["evidence"]["book_guard_allowed"] is True
    assert bypass["status"] == "PASS"
    # The pool-size check is a diagnostic INFO, never a failure.
    assert _check(report, "evidence.qualified_pool")["status"] == "INFO"


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
