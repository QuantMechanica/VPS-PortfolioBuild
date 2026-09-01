import argparse
import datetime as dt
import json
import os
import sqlite3
import threading
from pathlib import Path
from types import SimpleNamespace

from tools.strategy_farm import continuous_retention_runner as runner
from tools.strategy_farm.factory_mutation_lock import FactoryMutationLock


def make_db(path: Path) -> None:
    con = sqlite3.connect(path)
    con.execute("CREATE TABLE work_items(id TEXT, status TEXT, evidence_path TEXT, payload_json TEXT)")
    con.commit()
    con.close()


def age(path: Path, hours: float) -> None:
    stamp = (dt.datetime.now().timestamp() - hours * 3600)
    os.utime(path, (stamp, stamp))


def test_backup_plan_keeps_union_of_newest_ten_and_fourteen_days(tmp_path: Path) -> None:
    now = dt.datetime.now(dt.UTC)
    for index in range(15):
        path = tmp_path / f"backup_{index:02d}.sqlite"
        path.write_bytes(b"x")
        age(path, index * 24 + 1)
    keep, delete = runner.backup_plan(tmp_path, now)
    assert len(keep) == 14
    assert [path.name for path in delete] == ["backup_14.sqlite"]


def test_open_work_item_paths_are_never_compaction_candidates(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    make_db(db)
    root = tmp_path / "work_items"
    open_dir = root / "open-id"
    closed_dir = root / "closed-id"
    open_dir.mkdir(parents=True)
    closed_dir.mkdir(parents=True)
    open_file = open_dir / "summary.json"
    closed_file = closed_dir / "summary.json"
    open_file.write_text("{}")
    closed_file.write_text("{}")
    age(open_file, 3)
    age(closed_file, 3)
    con = sqlite3.connect(db)
    con.execute("INSERT INTO work_items VALUES (?,?,?,?)",
                ("open-id", "active", str(open_file), json.dumps({"report_root": str(open_dir)})))
    con.commit()
    con.close()
    ids, paths = runner.open_bindings(db)
    assert runner.is_open_bound(open_file, ids, paths)
    assert runner.is_open_bound(open_dir / "nested" / "artifact.json", ids, paths)
    assert not runner.is_open_bound(closed_file, ids, paths)


def test_delete_batch_is_dry_run_by_default(tmp_path: Path) -> None:
    root = tmp_path / "backups"
    receipts = tmp_path / "receipts"
    root.mkdir()
    target = root / "old.sqlite"
    target.write_bytes(b"abc")
    result = runner.safe_delete_batch([target], root, receipts, "run", "BACKUP_DELETE", False)
    assert target.exists()
    assert result["deleted_files"] == 0
    assert result["requested_bytes"] == 3


def test_evidence_candidates_skip_already_compressed_and_reparse(tmp_path: Path, monkeypatch) -> None:
    plain = tmp_path / "plain.json"
    compressed = tmp_path / "compressed.json"
    reparse = tmp_path / "reparse.json"
    for path in (plain, compressed, reparse):
        path.write_text("{}")
        age(path, 3)
    monkeypatch.setattr(
        runner, "file_attributes",
        lambda path: (runner.COMPRESSED_ATTRIBUTE if path == compressed else
                      runner.REPARSE_ATTRIBUTE if path == reparse else 0),
    )
    candidates = list(runner.iter_evidence_candidates(
        tmp_path, dt.datetime.now().timestamp() - 2 * 3600, set(), set()))
    assert candidates == [plain]


def test_noop_above_watermark_does_not_open_database(tmp_path: Path, monkeypatch) -> None:
    args = argparse.Namespace(
        apply=True, db=tmp_path / "missing.sqlite", backups_root=tmp_path,
        work_items_root=tmp_path, logs_root=tmp_path, receipt_root=tmp_path,
        telemetry=tmp_path / "telemetry", lock=tmp_path / "lock",
        drive_root=tmp_path, noop_free_bytes=1, evidence_age_hours=2.0,
        log_keep_hours=48.0, rotate_bytes=64, max_evidence_files=10,
    )
    result = runner.run(args)
    assert result["status"] == "NOOP_FREE_SPACE"


def test_quick_check_failure_is_fail_closed(tmp_path: Path) -> None:
    broken = tmp_path / "broken.sqlite"
    broken.write_bytes(b"not sqlite")
    try:
        runner.quick_check(broken)
    except sqlite3.DatabaseError:
        pass
    else:
        raise AssertionError("corrupt DB must fail closed")


def test_telemetry_keeps_bounded_action_and_byte_counts() -> None:
    summary = {
        "status": "PASS", "free_before": 1000, "free_after": 1300,
        "backup_compression": [{"status": "ALREADY_COMPRESSED", "bytes": 20}],
        "evidence_compression": [{"status": "COMPRESSED", "bytes": 30}],
        "log_rotation": [{"status": "HELD_ACTIVE", "bytes": 40}],
        "log_delete": {"deleted_files": 0, "deleted_bytes": 0},
    }
    record = runner.telemetry_record(summary)
    assert record["free_delta"] == 300
    assert record["evidence_compression"]["status_counts"] == {"COMPRESSED": 1}
    assert record["log_rotation"]["logical_bytes"] == 40
    assert record["purge_log_pattern"]["retention"] == "current_plus_48h"


def test_retention_compression_does_not_block_factory_claim_lock(
    tmp_path: Path, monkeypatch
) -> None:
    candidate = tmp_path / "closed.json"
    candidate.write_text("{}", encoding="utf-8")
    compression_started = threading.Event()
    allow_compression = threading.Event()

    monkeypatch.setattr(
        runner.shutil,
        "disk_usage",
        lambda _path: SimpleNamespace(total=0, used=0, free=0),
    )
    monkeypatch.setattr(runner, "quick_check", lambda _path: "ok")
    monkeypatch.setattr(runner, "open_bindings", lambda _path: (set(), set()))
    monkeypatch.setattr(runner, "backup_plan", lambda _root, _now: ([], []))
    monkeypatch.setattr(
        runner,
        "iter_evidence_candidates",
        lambda *_args: iter((candidate,)),
    )
    monkeypatch.setattr(runner, "rotate_large_logs", lambda *_args: [])
    monkeypatch.setattr(runner, "iter_old_files", lambda *_args: [])

    def compress(_path: Path) -> tuple[str, int, int]:
        compression_started.set()
        assert allow_compression.wait(timeout=5)
        return "COMPRESSED", 2, 2

    monkeypatch.setattr(runner, "set_ntfs_compression", compress)
    args = argparse.Namespace(
        apply=True,
        db=tmp_path / "farm.sqlite",
        backups_root=tmp_path / "backups",
        work_items_root=tmp_path / "work_items",
        logs_root=tmp_path / "logs",
        receipt_root=tmp_path / "receipts",
        telemetry=tmp_path / "telemetry.jsonl",
        lock=tmp_path / "retention.lock",
        drive_root=tmp_path,
        noop_free_bytes=1,
        evidence_age_hours=2.0,
        log_keep_hours=48.0,
        rotate_bytes=64,
        max_evidence_files=10,
    )
    result: list[dict] = []
    thread = threading.Thread(target=lambda: result.append(runner.run(args)))
    thread.start()
    assert compression_started.wait(timeout=5)

    factory_lock = tmp_path / "FACTORY_MUTATION.lock"
    with FactoryMutationLock(
        factory_lock,
        owner="terminal_worker.claim_atomic:T-test",
        hold_telemetry_path=tmp_path / "holds.jsonl",
    ):
        assert factory_lock.exists()

    allow_compression.set()
    thread.join(timeout=5)
    assert not thread.is_alive()
    assert result[0]["status"] == "PASS"
