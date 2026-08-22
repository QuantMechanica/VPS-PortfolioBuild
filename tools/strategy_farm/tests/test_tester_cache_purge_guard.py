from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import tester_cache_purge_guard as guard


REPO = Path(__file__).resolve().parents[3]
PURGE_SCRIPT = REPO / "tools" / "strategy_farm" / "tester_cache_purge.ps1"


def _write_sources(
    root: Path,
    *,
    db_pairs: list[tuple[str, str]],
    live_pairs: list[tuple[int, str]],
) -> tuple[Path, Path, Path]:
    db_path = root / "farm_state.sqlite"
    connection = sqlite3.connect(db_path)
    try:
        connection.execute(
            """
            CREATE TABLE portfolio_candidates (
                ea_id TEXT,
                symbol TEXT,
                q11_work_item_id TEXT,
                state TEXT,
                evidence_path TEXT,
                first_seen_at TEXT,
                updated_at TEXT
            )
            """
        )
        connection.executemany(
            "INSERT INTO portfolio_candidates(ea_id,symbol) VALUES(?,?)", db_pairs
        )
        connection.commit()
    finally:
        connection.close()

    manifest_path = root / "live_manifest.json"
    manifest_rows = [
        {"ea_id": ea_id, "symbol": symbol} for ea_id, symbol in live_pairs
    ]
    manifest = {
        "book": "TEST",
        "status": "LIVE",
        "n_sleeves": len(manifest_rows),
        "approved_by": "OWNER fixture",
        "sleeves": manifest_rows,
    }
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    manifest_hash = hashlib.sha256(manifest_path.read_bytes()).hexdigest()

    pulse_path = root / "live_book_pulse.json"
    pulse = {
        "book_manifest": {
            "enabled": True,
            "loaded": True,
            "exists": True,
            "error": None,
            "status": "LIVE",
            "path": str(manifest_path),
            "sha256": manifest_hash,
            "actual_manifest_sleeve_count": len(manifest_rows),
            "sleeves": manifest_rows,
        }
    }
    pulse_path.write_text(json.dumps(pulse), encoding="utf-8")
    return db_path, pulse_path, manifest_path


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_db_and_live_union_exempts_only_matching_gate_targets(tmp_path: Path) -> None:
    db_path, pulse_path, _ = _write_sources(
        tmp_path,
        db_pairs=[("QM5_11132", "SP500.DWX")],
        live_pairs=[(13301, "GDAXI.DWX")],
    )
    mt5_root = tmp_path / "mt5"
    tester = mt5_root / "T1" / "Tester"
    db_target = tester / "Agent-db"
    live_target = tester / "Agent-live"
    ordinary_target = tester / "Agent-ordinary"
    bases_target = tester / "bases" / "Darwinex-Demo"

    _write_json(
        db_target / "Q08" / "QM5_11132" / "SP500_DWX" / "aggregate.json",
        {"ea_id": "QM5_11132", "symbol": "SP500.DWX", "verdict": "PASS"},
    )
    _write_json(
        live_target / "Q10" / "QM5_13301" / "GDAXI_DWX" / "final_verdict.json",
        {"ea_id": 13301, "symbol": "GDAXI.DWX", "verdict": "PASS"},
    )
    _write_json(
        ordinary_target / "Q04" / "QM5_99999" / "EURUSD_DWX" / "aggregate.json",
        {"ea_id": 99999, "symbol": "EURUSD.DWX", "verdict": "FAIL"},
    )
    bases_target.mkdir(parents=True)
    (bases_target / "history.hcc").write_bytes(b"regenerable")

    plan = guard.build_plan(db_path, pulse_path, mt5_root, ["T1"])

    assert plan["status"] == "PASS"
    assert plan["counts"] == {
        "portfolio_candidate_pairs": 1,
        "live_manifest_pairs": 1,
        "protected_union_pairs": 2,
        "purge_targets_scanned": 4,
        "gate_evidence_artifacts_scanned": 3,
        "protected_targets": 2,
        "unprotected_targets": 2,
    }
    protected = {Path(row["path"]) for row in plan["protected_targets"]}
    assert protected == {db_target.resolve(), live_target.resolve()}
    assert ordinary_target.resolve() not in protected
    assert bases_target.resolve() not in protected
    by_pair = {
        (row["ea_id"], row["symbol"]): row["sources"]
        for row in plan["protected_pairs"]
    }
    assert by_pair[("QM5_11132", "SP500.DWX")] == ["portfolio_candidates"]
    assert by_pair[("QM5_13301", "GDAXI.DWX")] == ["live_manifest"]


def test_unclassified_gate_artifact_protects_its_target(tmp_path: Path) -> None:
    db_path, pulse_path, _ = _write_sources(
        tmp_path,
        db_pairs=[("QM5_11132", "SP500.DWX")],
        live_pairs=[(13301, "GDAXI.DWX")],
    )
    mt5_root = tmp_path / "mt5"
    target = mt5_root / "T2" / "Tester" / "Agent-ambiguous"
    _write_json(target / "Q09" / "aggregate.json", {"verdict": "PASS"})

    plan = guard.build_plan(db_path, pulse_path, mt5_root, ["T2"])

    assert [Path(row["path"]) for row in plan["protected_targets"]] == [
        target.resolve()
    ]
    reasons = plan["protected_targets"][0]["reasons"]
    assert reasons[0]["reason"] == "unclassified_gate_evidence_fail_closed"


def test_manifest_hash_drift_fails_closed(tmp_path: Path) -> None:
    db_path, pulse_path, manifest_path = _write_sources(
        tmp_path,
        db_pairs=[("QM5_11132", "SP500.DWX")],
        live_pairs=[(13301, "GDAXI.DWX")],
    )
    manifest_path.write_text('{"status":"LIVE","sleeves":[]}', encoding="utf-8")

    with pytest.raises(guard.GuardError, match="live_manifest_hash_mismatch"):
        guard.build_plan(db_path, pulse_path, tmp_path / "mt5", ["T1"])


def test_missing_database_fails_closed(tmp_path: Path) -> None:
    db_path, pulse_path, _ = _write_sources(
        tmp_path,
        db_pairs=[("QM5_11132", "SP500.DWX")],
        live_pairs=[(13301, "GDAXI.DWX")],
    )
    db_path.unlink()

    with pytest.raises(guard.GuardError, match="farm_db_missing"):
        guard.build_plan(db_path, pulse_path, tmp_path / "mt5", ["T1"])


def test_powershell_calls_guard_before_deletion_and_keeps_normal_purge() -> None:
    source = PURGE_SCRIPT.read_text(encoding="utf-8")
    guard_call = source.index("$evidencePlan = Get-EvidencePurgePlan")
    busy_call = source.index("Invoke-BusyScratchReclaim", guard_call)
    idle_delete = source.index(
        "Remove-Item -LiteralPath $targetPath -Recurse -Force", busy_call
    )
    protected_skip = source.index(
        "if ($protectedTargetLookup.ContainsKey($targetPath))", busy_call
    )
    post_stop_refresh = source.index("$refreshedEvidencePlan = Get-EvidencePurgePlan")
    deletion_guard = source.index("if (-not $evidenceRefreshFailed)", post_stop_refresh)
    fail_closed = source[guard_call:busy_call]

    assert guard_call < busy_call
    assert "PURGE_SKIP_EVIDENCE_EXCLUSION_ERROR" in fail_closed
    assert "exit 3" in fail_closed
    assert post_stop_refresh < deletion_guard < idle_delete
    assert "stage=post_stop_refresh" in source[post_stop_refresh:deletion_guard]
    assert protected_skip < idle_delete
    assert "SKIP_EVIDENCE_PROTECTED" in source[protected_skip:idle_delete]
