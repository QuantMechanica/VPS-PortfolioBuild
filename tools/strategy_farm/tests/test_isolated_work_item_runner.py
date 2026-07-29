from __future__ import annotations

import hashlib
import json
import os
import sqlite3
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import isolated_work_item_runner as runner  # noqa: E402


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _seed(tmp_path: Path) -> tuple[Path, Path, Path, str]:
    root = tmp_path / "farm"
    repo = tmp_path / "repo"
    state = root / "state"
    state.mkdir(parents=True)
    flag = state / "FACTORY_OFF.flag"
    flag.write_text("intentional\n", encoding="utf-8")

    ea_name = "QM5_99999_measurement"
    ea_dir = repo / "framework" / "EAs" / ea_name
    ea_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{ea_name}.mq5"
    mq5.write_text("// source\n", encoding="utf-8")
    setfile = ea_dir / "test.set"
    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
    staged = root / "artifacts" / "test.ex5"
    staged.parent.mkdir(parents=True)
    staged.write_bytes(b"compiled")

    payload = {
        "terminal": "T6",
        "avoid_terminals": ["T3", "T5", "T_Live"],
        "ea_dir_name": ea_name,
        "expected_setfile_sha256": _sha(setfile),
        "staged_ex5_path": str(staged),
        "staged_ex5_sha256": _sha(staged),
        "expected_mq5_sha256": _sha(mq5),
    }
    payload_text = json.dumps(payload, sort_keys=True)
    db = state / "farm_state.sqlite"
    with sqlite3.connect(db) as conn:
        conn.executescript(
            """
            CREATE TABLE work_items(
              id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT,
              setfile_path TEXT, status TEXT, verdict TEXT, claimed_by TEXT,
              evidence_path TEXT, payload_json TEXT, updated_at TEXT
            );
            CREATE TABLE work_item_holds(
              work_item_id TEXT PRIMARY KEY, hold_code TEXT, reason TEXT,
              active INTEGER, release_on_restart INTEGER, created_at TEXT,
              updated_at TEXT, released_at TEXT, release_note TEXT
            );
            """
        )
        conn.execute(
            "INSERT INTO work_items VALUES "
            "('target','Q02','QM5_99999','GDAXI.DWX',?,'pending',NULL,NULL,NULL,?,'now')",
            (str(setfile), payload_text),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES "
            "('target','ISOLATED_T6_ONE_SHOT_REQUIRED','test',1,0,'now','now',NULL,NULL)"
        )
    return root, repo, db, payload_text


def _fake_worker(path: Path) -> None:
    path.write_text(
        """import argparse, sqlite3
from pathlib import Path
import framework
p=argparse.ArgumentParser()
p.add_argument('--terminal'); p.add_argument('--root'); p.add_argument('--timeout-minutes')
p.add_argument('--work-item-id'); a=p.parse_args()
db=Path(a.root)/'state'/'farm_state.sqlite'
with sqlite3.connect(db) as c:
 c.execute("update work_items set status='done',verdict='PASS',claimed_by=NULL,evidence_path='evidence.json',updated_at='later' where id=?",(a.work_item_id,))
print('fake isolated worker complete')
""",
        encoding="utf-8",
    )


def _fake_worker_requiring_repo_cwd(path: Path) -> None:
    path.write_text(
        """import argparse, sqlite3
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('--terminal'); p.add_argument('--root'); p.add_argument('--timeout-minutes')
p.add_argument('--work-item-id'); a=p.parse_args()
assert (Path.cwd()/'framework').is_dir(), Path.cwd()
db=Path(a.root)/'state'/'farm_state.sqlite'
with sqlite3.connect(db) as c:
 c.execute("update work_items set status='done',verdict='PASS',claimed_by=NULL,evidence_path='evidence.json',updated_at='later' where id=?",(a.work_item_id,))
""",
        encoding="utf-8",
    )


def test_plan_binds_hold_terminal_payload_and_artifacts(tmp_path: Path, monkeypatch) -> None:
    root, repo, _db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])

    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )

    assert plan["valid"] is True
    assert plan["hold"]["release_on_restart"] == 0
    assert all(item["valid"] for item in plan["artifacts"])


def test_execute_is_hash_bound_and_writes_receipt(tmp_path: Path, monkeypatch) -> None:
    root, repo, _db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )

    result = runner.execute(
        root,
        terminal="T6",
        work_item_id="target",
        worker_script=worker,
        repo_root=repo,
        timeout_minutes=0.1,
        expected_factory_off_sha256=plan["factory_off_sha256"],
        expected_db_state_sha256=plan["db_state_sha256"],
        expected_payload_sha256=plan["work_item"]["payload_sha256"],
        expected_worker_sha256=plan["worker_sha256"],
        snapshot_path=tmp_path / "before.sqlite",
        receipt_path=tmp_path / "receipt.json",
        worker_log_path=tmp_path / "worker.log",
    )

    assert result["post_work_item"]["status"] == "done"
    assert result["post_work_item"]["verdict"] == "PASS"
    assert result["factory_off_sha256"] == plan["factory_off_sha256"]
    assert (tmp_path / "receipt.json").is_file()
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()


def test_execute_launches_worker_from_bound_repo_root(tmp_path: Path, monkeypatch) -> None:
    root, repo, _db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker_requiring_repo_cwd(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )

    result = runner.execute(
        root,
        terminal="T6",
        work_item_id="target",
        worker_script=worker,
        repo_root=repo,
        timeout_minutes=0.1,
        expected_factory_off_sha256=plan["factory_off_sha256"],
        expected_db_state_sha256=plan["db_state_sha256"],
        expected_payload_sha256=plan["work_item"]["payload_sha256"],
        expected_worker_sha256=plan["worker_sha256"],
        snapshot_path=tmp_path / "cwd_before.sqlite",
        receipt_path=tmp_path / "cwd_receipt.json",
        worker_log_path=tmp_path / "cwd_worker.log",
    )

    assert result["worker_exit_code"] == 0
    assert result["post_work_item"]["status"] == "done"


def test_execute_rejects_payload_hash_drift_before_snapshot(tmp_path: Path, monkeypatch) -> None:
    root, repo, db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )
    with sqlite3.connect(db) as conn:
        conn.execute("UPDATE work_items SET payload_json='{}' WHERE id='target'")

    try:
        runner.execute(
            root,
            terminal="T6",
            work_item_id="target",
            worker_script=worker,
            repo_root=repo,
            timeout_minutes=0.1,
            expected_factory_off_sha256=plan["factory_off_sha256"],
            expected_db_state_sha256=runner.sqlite_state_sha256(db),
            expected_payload_sha256=plan["work_item"]["payload_sha256"],
            expected_worker_sha256=plan["worker_sha256"],
            snapshot_path=tmp_path / "before.sqlite",
            receipt_path=tmp_path / "receipt.json",
            worker_log_path=tmp_path / "worker.log",
        )
    except RuntimeError as exc:
        assert "preflight failed" in str(exc) or "payload SHA-256 mismatch" in str(exc)
    else:  # pragma: no cover
        raise AssertionError("payload drift was accepted")
    assert not (tmp_path / "before.sqlite").exists()


def test_harvest_copies_only_fresh_changed_stream_atomically(tmp_path: Path) -> None:
    source = tmp_path / "common" / "13301_GDAXI_DWX.jsonl"
    target = tmp_path / "evidence" / "q08_trades_13301_GDAXI_DWX.timer_v2.jsonl"
    source.parent.mkdir(parents=True)
    source.write_text('{"trade":1}\n', encoding="utf-8")
    pre = runner._stream_fingerprint(source)
    started_ns = source.stat().st_mtime_ns
    source.write_text('{"trade":2}\n{"trade":3}\n', encoding="utf-8")
    contract = {
        "requested": True,
        "valid": True,
        "source": str(source),
        "target": str(target),
        "pre_run_source": pre,
        "pre_v2_capture": {"sha256": pre["sha256"]},
    }

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is True
    assert result["harvested"]["lines"] == 2
    assert result["harvested"]["sha256"] == runner.sha256_file(source)
    assert target.read_bytes() == source.read_bytes()
    assert not list(target.parent.glob("*.tmp"))


def test_harvest_rejects_unchanged_pre_run_stream(tmp_path: Path) -> None:
    source = tmp_path / "13301_GDAXI_DWX.jsonl"
    target = tmp_path / "q08_trades_13301_GDAXI_DWX.timer_v2.jsonl"
    source.write_text('{"trade":1}\n', encoding="utf-8")
    pre = runner._stream_fingerprint(source)
    contract = {
        "requested": True,
        "valid": True,
        "source": str(source),
        "target": str(target),
        "pre_run_source": pre,
        "pre_v2_capture": {},
    }

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=source.stat().st_mtime_ns
    )

    assert result["valid"] is False
    assert "unchanged" in result["error"]
    assert not target.exists()


def test_harvest_accepts_identical_content_rewritten_during_worker(tmp_path: Path) -> None:
    source = tmp_path / "13301_GDAXI_DWX.jsonl"
    target = tmp_path / "q08_trades_13301_GDAXI_DWX.timer_v2.jsonl"
    source.write_text('{"trade":1}\n', encoding="utf-8")
    pre = runner._stream_fingerprint(source)
    started_ns = int(pre["mtime_ns"]) + 1_000_000_000
    os.utime(source, ns=(started_ns + 1_000_000_000, started_ns + 1_000_000_000))
    contract = {
        "requested": True,
        "valid": True,
        "source": str(source),
        "target": str(target),
        "pre_run_source": pre,
        "pre_v2_capture": {"sha256": "0" * 64},
    }

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is True
    assert result["content_identical_but_rewritten"] is True
    assert target.read_bytes() == source.read_bytes()
