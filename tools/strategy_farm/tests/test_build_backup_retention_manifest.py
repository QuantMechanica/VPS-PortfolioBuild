from __future__ import annotations

import datetime as dt
import importlib.util
import sys
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "build_backup_retention_manifest.py"
SPEC = importlib.util.spec_from_file_location("build_backup_retention_manifest", MODULE_PATH)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = mod
SPEC.loader.exec_module(mod)


def _snapshot() -> object:
    snap = mod.Snapshot()
    rows = [
        mod.WorkItem("11111111-1111-1111-1111-111111111111", "QM5_1", "XAUUSD.DWX", "Q03", "done", "PASS", "v4"),
        mod.WorkItem("22222222-2222-2222-2222-222222222222", "QM5_2", "EURUSD.DWX", "Q02", "done", "FAIL", "v4"),
        mod.WorkItem("33333333-3333-3333-3333-333333333333", "QM5_2", "EURUSD.DWX", "Q05", "active", "", "v4"),
    ]
    for row in rows:
        snap.work_items[row.work_id] = row
        snap.symbols_by_ea[row.ea_id].add(row.symbol)
    snap.path_pairs[("QM5_1", "XAUUSD.DWX")].add("V4_PASS_LINEAGE")
    return snap


def test_path_pair_keeps_complete_chain_and_deletes_logs() -> None:
    snap = _snapshot()
    base = Path("D:/QM/reports/work_items/11111111-1111-1111-1111-111111111111/QM5_1/run")
    report = mod.classify_report(base / "report.htm", "D_REPORTS", snap)
    log = mod.classify_report(base / "tester.log", "D_REPORTS", snap)
    assert report.disposition == "COMPRESS_KEEP_COMPLETE_CHAIN"
    assert log.disposition == "DELETE_LOG"


def test_other_pair_keeps_only_q02_q04_artifact_set() -> None:
    snap = _snapshot()
    base = Path("D:/QM/reports/work_items/22222222-2222-2222-2222-222222222222/QM5_2/run")
    assert mod.classify_report(base / "report.htm.gz", "D_REPORTS", snap).disposition == "KEEP_ALREADY_COMPRESSED"
    assert mod.classify_report(base / "logger_sample.jsonl", "D_REPORTS", snap).disposition == "DELETE_LOG"
    assert mod.classify_report(base / "trades.csv", "D_REPORTS", snap).disposition == "DELETE_NONRETAINED"


def test_open_work_item_overrides_deletion() -> None:
    snap = _snapshot()
    path = Path("D:/QM/reports/work_items/33333333-3333-3333-3333-333333333333/QM5_2/tester.log")
    assert mod.classify_report(path, "D_REPORTS", snap).disposition == "KEEP_DL090_OPEN"


def test_ambiguity_keeps_nonlog() -> None:
    snap = _snapshot()
    result = mod.classify_report(Path("D:/QM/reports/rebaseline/unknown.csv"), "D_REPORTS", snap)
    assert result.disposition == "KEEP_AMBIGUOUS"
    log = mod.classify_report(Path("D:/QM/reports/rebaseline/unknown.log"), "D_REPORTS", snap)
    assert log.disposition == "KEEP_AMBIGUOUS"


def test_db_rotation_is_union_of_newest_and_14_day_window(tmp_path: Path) -> None:
    reports = tmp_path / "reports"
    logs = tmp_path / "logs"
    relocated = tmp_path / "relocated" / "farm_state_backups_20260828"
    reports.mkdir()
    logs.mkdir()
    relocated.mkdir(parents=True)
    now = dt.datetime(2026, 8, 31, tzinfo=dt.UTC)
    for index in range(16):
        path = relocated / f"farm_state_{index:02d}.sqlite"
        path.write_bytes(b"x")
        age_days = index
        stamp = (now - dt.timedelta(days=age_days)).timestamp()
        path.touch()
        import os
        os.utime(path, (stamp, stamp))
    rows, summary = mod.build_inventory(_snapshot(), reports, logs, relocated.parent, now)
    dispositions = {str(row["disposition"]): int(row["file_count"]) for row in rows}
    assert dispositions["KEEP_DB_ROTATION"] == 15
    assert dispositions["DELETE_DB_ROTATION"] == 1
    assert summary["file_count"] == 16
