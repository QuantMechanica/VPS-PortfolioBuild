from __future__ import annotations

import csv
import datetime as dt
import hashlib
import importlib.util
import sys
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "execute_backup_retention_phase2.py"
SPEC = importlib.util.spec_from_file_location("execute_backup_retention_phase2", MODULE_PATH)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mod
SPEC.loader.exec_module(mod)


def _manifest(path: Path) -> str:
    fields = [
        "scope", "ea_id", "symbol", "phase", "pair_class", "disposition", "reason",
        "file_count", "bytes", "projected_free_bytes", "compression_candidate_bytes",
    ]
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerow({
            "scope": "D_FARM_LOGS", "ea_id": "UNRESOLVED", "symbol": "UNRESOLVED",
            "phase": "UNRESOLVED", "pair_class": "LOG_ROOT", "disposition": "DELETE_LOG",
            "reason": "OWNER doctrine: dedicated farm logs need not be kept",
            "file_count": 1, "bytes": 3, "projected_free_bytes": 3,
            "compression_candidate_bytes": 0,
        })
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_manifest_hash_is_enforced(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.csv"
    digest = _manifest(manifest)
    rows = mod.load_sealed_rows(manifest, digest)
    assert len(rows) == 1
    try:
        mod.load_sealed_rows(manifest, "0" * 64)
    except ValueError as exc:
        assert "mismatch" in str(exc)
    else:
        raise AssertionError("hash mismatch was not rejected")


def test_post_seal_log_is_held(tmp_path: Path) -> None:
    reports = tmp_path / "reports"
    logs = tmp_path / "logs"
    relocated = tmp_path / "relocated"
    reports.mkdir()
    logs.mkdir()
    relocated.mkdir()
    log = logs / "worker.log"
    log.write_bytes(b"abc")
    manifest = tmp_path / "manifest.csv"
    digest = _manifest(manifest)
    sealed = mod.load_sealed_rows(manifest, digest)
    snapshot = mod.phase1.Snapshot(db_quick_check="ok")
    seal_time = dt.datetime.now(dt.UTC) - dt.timedelta(minutes=5)
    result = mod.build_plan(sealed, seal_time, snapshot, reports, logs, relocated, dt.datetime.now(dt.UTC))
    assert not result.candidates
    assert result.holds["post_seal_new_or_changed"] == 1


def test_batch_limits_files_and_bytes(tmp_path: Path) -> None:
    key = ("D_FARM_LOGS", "UNRESOLVED", "UNRESOLVED", "UNRESOLVED", "LOG_ROOT", "DELETE_LOG", "x")
    records = [
        mod.FileRecord("D_FARM_LOGS", tmp_path, tmp_path / f"{index}.log", f"{index}.log", "DELETE_LOG", key, 4, 1, index)
        for index in range(5)
    ]
    batches = list(mod._batch(records, max_files=2, max_bytes=8))
    assert [len(batch) for batch in batches] == [2, 2, 1]


def test_quarantine_destination_is_flat_and_bounded(tmp_path: Path) -> None:
    key = ("D_REPORTS", "QM5_1", "EURUSD.DWX", "Q02", "OTHER", "DELETE_LOG", "x")
    source = Path("D:/QM/reports") / Path(*(["very_long_component"] * 20)) / "tester.log"
    record = mod.FileRecord(
        "D_REPORTS", Path("D:/QM/reports"), source, "unused", "DELETE_LOG", key, 4, 1, 1
    )
    destination = mod._quarantine_destination(record, "20260831T1506Z_test")
    assert len(str(destination)) < 200
    assert destination.suffix == ".log"
    assert destination.parts[-2] == destination.name[:2]
