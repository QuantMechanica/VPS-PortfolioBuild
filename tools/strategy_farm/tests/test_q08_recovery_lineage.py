from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from framework.scripts.q08_davey import aggregate
from tools.strategy_farm import farmctl
from tools.strategy_farm.q08_recovery_lineage import (
    build_q08_recovery_lineage,
    validate_q08_recovery_lineage,
)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture(tmp_path: Path) -> tuple[sqlite3.Connection, Path, list[Path]]:
    reports = tmp_path / "reports"
    ea_id = "QM5_10582"
    symbol = "XAUUSD.DWX"
    setfile = tmp_path / "ablation_00.set"
    setfiles = [setfile, tmp_path / "ablation_01.set", tmp_path / "ablation_02.set"]
    for index, path in enumerate(setfiles):
        path.write_text(f"strategy_period={20 + index}\n", encoding="utf-8")

    archive = reports / "work_items" / "old.requeued_20260727T0341290000"
    leaf = archive / ea_id / "Q08" / symbol.replace(".", "_")
    leaf.mkdir(parents=True)
    (leaf / "aggregate.json").write_text('{"verdict":"INVALID"}\n', encoding="utf-8")
    (leaf / "8_5_neighborhood.json").write_text(
        '{"status":"INVALID"}\n', encoding="utf-8"
    )

    bindings = []
    for index, path in enumerate(setfiles):
        bindings.append(
            {
                "role": f"setfile_ablation_{index:02d}",
                "path": str(path.resolve()),
                "sha256": _sha(path),
                "bytes": path.stat().st_size,
                "sha256_basis": "RAW_BYTES",
            }
        )
    payload = {
        "q08_single_target_requalification": {
            "archived_report_root": str(archive.resolve()),
            "artifact_bindings": bindings,
        }
    }
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_items(
            id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
            evidence_path TEXT, payload_json TEXT, created_at TEXT, updated_at TEXT
        )
        """
    )
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)",
        (
            "old",
            "Q08",
            ea_id,
            symbol,
            str(setfile),
            str(leaf / "aggregate.json"),
            json.dumps(payload),
            "2026-07-26T00:00:00Z",
            "2026-07-27T00:00:00Z",
        ),
    )
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)",
        (
            "new-failed",
            "Q08",
            ea_id,
            symbol,
            str(setfile),
            None,
            "{}",
            "2026-08-01T00:00:00Z",
            "2026-08-02T00:00:00Z",
        ),
    )
    return conn, reports, setfiles


def test_build_carries_owner_pinned_artifacts_into_new_identity(tmp_path: Path) -> None:
    conn, reports, _setfiles = _fixture(tmp_path)

    lineage, error = build_q08_recovery_lineage(
        conn,
        reports,
        ea_id="QM5_10582",
        symbol="XAUUSD.DWX",
        setfile_path=str(tmp_path / "ablation_00.set"),
    )

    assert error is None
    assert lineage is not None
    assert lineage["retry_source_work_item_id"] == "new-failed"
    assert lineage["lineage_source_work_item_id"] == "old"
    assert {row["role"] for row in lineage["artifact_bindings"]} == {
        "setfile_ablation_00",
        "setfile_ablation_01",
        "setfile_ablation_02",
    }
    assert all(len(row["sha256"]) == 64 for row in lineage["artifact_bindings"])
    assert lineage["historical_rows_mutated"] is False
    assert lineage["fresh_artifact_targets"][0]["preexisting_required"] is False
    assert validate_q08_recovery_lineage(lineage)[:2] == (True, "hash_pins_match")


def test_changed_pinned_artifact_is_refused_fail_closed(tmp_path: Path) -> None:
    conn, reports, setfiles = _fixture(tmp_path)
    setfiles[1].write_text("strategy_period=999\n", encoding="utf-8")

    lineage, error = build_q08_recovery_lineage(
        conn,
        reports,
        ea_id="QM5_10582",
        symbol="XAUUSD.DWX",
        setfile_path=str(tmp_path / "ablation_00.set"),
    )

    assert lineage is None
    assert error == "artifact_sha256_mismatch:setfile_ablation_01"


def test_dispatch_manifest_is_authenticated_again_by_q08(tmp_path: Path) -> None:
    conn, reports, _setfiles = _fixture(tmp_path)
    lineage, error = build_q08_recovery_lineage(
        conn,
        reports,
        ea_id="QM5_10582",
        symbol="XAUUSD.DWX",
        setfile_path=str(tmp_path / "ablation_00.set"),
    )
    assert error is None and lineage is not None

    manifest_path, manifest_sha, dispatch_error = (
        farmctl._materialize_q08_recovery_lineage_manifest(
            tmp_path / "new-work-item",
            {"q08_recovery_lineage": lineage},
        )
    )

    assert dispatch_error is None
    assert manifest_path is not None and manifest_sha is not None
    loaded = aggregate._load_recovery_lineage_manifest(manifest_path, manifest_sha)
    assert loaded is not None
    assert loaded["validation_status"] == "PASS"
    manifest_path.write_text("{}\n", encoding="utf-8")
    with pytest.raises(ValueError, match="SHA256 mismatch"):
        aggregate._load_recovery_lineage_manifest(manifest_path, manifest_sha)
