from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

import pytest


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
evidence=Path(a.root)/'state'/'evidence.json'
evidence.write_text('{"ok":true}\\n',encoding='utf-8')
with sqlite3.connect(db) as c:
 c.execute("update work_items set status='done',verdict='PASS',claimed_by=NULL,evidence_path=?,updated_at='later' where id=?",(str(evidence.resolve()),a.work_item_id))
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
evidence=Path(a.root)/'state'/'evidence.json'
evidence.write_text('{"ok":true}\\n',encoding='utf-8')
with sqlite3.connect(db) as c:
 c.execute("update work_items set status='done',verdict='PASS',claimed_by=NULL,evidence_path=?,updated_at='later' where id=?",(str(evidence.resolve()),a.work_item_id))
""",
        encoding="utf-8",
    )


def _governed_stream_environment(
    tmp_path: Path, monkeypatch
) -> tuple[Path, Path, Path]:
    common = tmp_path / "common" / "QM"
    trades = common / "q08_trades"
    equity = common / "q08_equity"
    reports = tmp_path / "reports" / "work_items"
    trades.mkdir(parents=True)
    equity.mkdir(parents=True)
    monkeypatch.setattr(runner, "DEFAULT_FILE_COMMON_Q08", trades)
    monkeypatch.setattr(runner, "DEFAULT_FILE_COMMON_Q08_EQUITY", equity)
    monkeypatch.setattr(runner, "DEFAULT_REPORTS_WORK_ITEMS", reports)
    return trades, equity, reports


def _rewrite_after_preflight(path: Path, content: str, started_ns: int) -> None:
    path.write_text(content, encoding="utf-8")
    fresh_ns = max(time.time_ns(), started_ns + 1_000_000_000)
    os.utime(path, ns=(fresh_ns, fresh_ns))


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


def _bind_ftmo_execution_inputs(
    *,
    db: Path,
    payload_text: str,
    paths: dict[str, Path],
) -> dict:
    payload = json.loads(payload_text)
    payload["terminal"] = "T10"
    payload["measurement_contract"] = runner.FTMO_BOOK3_MEASUREMENT_CONTRACT
    rows = sorted(
        (
            {
                "role": role,
                "path": str(path),
                "sha256": _sha(path),
                "bytes": path.stat().st_size,
            }
            for role, path in paths.items()
        ),
        key=lambda item: (item["role"], item["path"]),
    )
    payload["execution_input_artifacts"] = rows
    payload["execution_input_artifacts_sha256"] = runner.canonical_sha256(rows)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='target'",
            (json.dumps(payload, sort_keys=True),),
        )
    return payload


def test_ftmo_execution_inputs_are_rehashed_immediately_before_run(
    tmp_path: Path, monkeypatch
) -> None:
    root, repo, db, payload_text = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    first = tmp_path / "inputs" / "terminal64.exe"
    second = tmp_path / "inputs" / "calendar.csv"
    first.parent.mkdir(parents=True)
    first.write_bytes(b"terminal")
    second.write_bytes(b"calendar")
    expected = {"t10_terminal_binary": first, "calendar_source:test.csv": second}
    _bind_ftmo_execution_inputs(db=db, payload_text=payload_text, paths=expected)
    monkeypatch.setattr(
        runner, "_ftmo_book3_expected_execution_input_paths", lambda _repo: expected
    )
    monkeypatch.setattr(
        runner,
        "_ftmo_source_binding_plan",
        lambda _payload, **_kwargs: {"requested": True, "valid": True, "errors": []},
    )
    monkeypatch.setattr(
        runner,
        "_ftmo_work_core_plan",
        lambda **_kwargs: {"requested": True, "valid": True, "errors": []},
    )
    monkeypatch.setattr(
        runner,
        "_ftmo_ladder_order_plan",
        lambda *_args, **_kwargs: {
            "requested": True,
            "valid": True,
            "errors": [],
            "rungs": [],
        },
    )
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])

    plan = runner.build_plan(
        root, terminal="T10", work_item_id="target", worker_script=worker, repo_root=repo
    )

    assert plan["valid"] is True
    assert plan["execution_inputs"]["valid"] is True
    assert len(plan["execution_inputs"]["artifacts"]) == 2
    assert all(item["valid"] for item in plan["execution_inputs"]["artifacts"])


def test_ftmo_execution_input_tamper_fails_closed(tmp_path: Path, monkeypatch) -> None:
    root, repo, db, payload_text = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    bound = tmp_path / "input.bin"
    bound.write_bytes(b"before")
    expected = {"t10_terminal_binary": bound}
    _bind_ftmo_execution_inputs(db=db, payload_text=payload_text, paths=expected)
    bound.write_bytes(b"after")
    monkeypatch.setattr(
        runner, "_ftmo_book3_expected_execution_input_paths", lambda _repo: expected
    )
    monkeypatch.setattr(
        runner,
        "_ftmo_source_binding_plan",
        lambda _payload, **_kwargs: {"requested": True, "valid": True, "errors": []},
    )
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])

    plan = runner.build_plan(
        root, terminal="T10", work_item_id="target", worker_script=worker, repo_root=repo
    )

    assert plan["valid"] is False
    assert any("byte mismatch" in error or "SHA-256 mismatch" in error for error in plan["errors"])


@pytest.mark.parametrize("fault", ["duplicate_role", "path_swap", "noncanonical"])
def test_ftmo_execution_input_shape_and_paths_fail_closed(
    tmp_path: Path, monkeypatch, fault: str
) -> None:
    root, repo, db, payload_text = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    first = tmp_path / "first.bin"
    second = tmp_path / "second.bin"
    first.write_bytes(b"first")
    second.write_bytes(b"second")
    expected = {"role_a": first, "role_b": second}
    payload = _bind_ftmo_execution_inputs(
        db=db, payload_text=payload_text, paths=expected
    )
    rows = payload["execution_input_artifacts"]
    if fault == "duplicate_role":
        rows[1]["role"] = rows[0]["role"]
    elif fault == "path_swap":
        rows[0]["path"] = str(second)
    else:
        rows.reverse()
    payload["execution_input_artifacts_sha256"] = runner.canonical_sha256(rows)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='target'",
            (json.dumps(payload, sort_keys=True),),
        )
    monkeypatch.setattr(
        runner, "_ftmo_book3_expected_execution_input_paths", lambda _repo: expected
    )
    monkeypatch.setattr(
        runner,
        "_ftmo_source_binding_plan",
        lambda _payload, **_kwargs: {"requested": True, "valid": True, "errors": []},
    )
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])

    plan = runner.build_plan(
        root, terminal="T10", work_item_id="target", worker_script=worker, repo_root=repo
    )

    assert plan["valid"] is False
    assert plan["execution_inputs"]["valid"] is False


def test_ftmo_source_binding_revalidates_commit_tree_prereg_and_controllers(
    tmp_path: Path, monkeypatch
) -> None:
    repo = tmp_path / "repo"
    include = repo / "framework" / "include" / "QM"
    prereg = (
        repo
        / "docs"
        / "ops"
        / "evidence"
        / "2026-07-29_ftmo_book3_execution_preregistration.md"
    )
    include.mkdir(parents=True)
    prereg.parent.mkdir(parents=True)
    (include / "one.mqh").write_text("// bound include\n", encoding="utf-8")
    prereg.write_text("# bound preregistration\n", encoding="utf-8")
    worker = tmp_path / "terminal_worker.py"
    worker.write_text("# bound worker\n", encoding="utf-8")
    preparation_controller = repo / "tools/strategy_farm/prepare_ftmo_book3_q02.py"
    preparation_controller.parent.mkdir(parents=True, exist_ok=True)
    preparation_controller.write_text("# bound preparation controller\n", encoding="utf-8")
    setfile = tmp_path / "j0.set"
    setfile.write_text(
        "qm_evidence_run_id=FTMO_BOOK3_20260729_V1_J0\n",
        encoding="utf-8",
    )
    commit = "a" * 40
    tree_sha, _ = runner._tree_content_sha256(include)
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "measurement_rung": "J0",
        "measurement_sequence": 1,
        "evidence_run_id": "FTMO_BOOK3_20260729_V1_J0",
        "authoritative_source_commit": commit,
        "controller_head_commit": commit,
        "framework_include_tree_sha256": tree_sha,
        "preregistration_sha256": _sha(prereg),
        "isolated_runner_path": str(Path(runner.__file__).resolve()),
        "isolated_runner_sha256": _sha(Path(runner.__file__).resolve()),
        "terminal_worker_path": str(worker),
        "terminal_worker_sha256": _sha(worker),
        "preparation_controller_path": str(preparation_controller),
        "preparation_controller_sha256": _sha(preparation_controller),
    }
    runtime_paths = runner._ftmo_runtime_source_paths(
        repo, worker_script=worker
    )
    for role, source_path in runtime_paths.items():
        if not source_path.exists():
            source_path.parent.mkdir(parents=True, exist_ok=True)
            source_path.write_text(f"# {role}\n", encoding="utf-8")
    runtime_sources = sorted(
        (
            {
                "role": role,
                "path": str(source_path),
                "sha256": _sha(source_path),
                "bytes": source_path.stat().st_size,
            }
            for role, source_path in runtime_paths.items()
        ),
        key=lambda item: (item["role"], item["path"]),
    )
    payload["runtime_source_artifacts"] = runtime_sources
    payload["runtime_source_artifacts_sha256"] = runner.canonical_sha256(
        runtime_sources
    )
    monkeypatch.setattr(runner, "_git_head", lambda _repo: commit)
    monkeypatch.setattr(
        runner,
        "_git_clean_plan",
        lambda _repo, **_kwargs: {"valid": True, "error": None, "porcelain": ""},
    )

    valid = runner._ftmo_source_binding_plan(
        payload, repo_root=repo, worker_script=worker, setfile_path=setfile
    )
    assert valid["valid"] is True

    (include / "one.mqh").write_text("// tampered include\n", encoding="utf-8")
    invalid = runner._ftmo_source_binding_plan(
        payload, repo_root=repo, worker_script=worker, setfile_path=setfile
    )
    assert invalid["valid"] is False
    assert any("include tree" in error for error in invalid["errors"])

    (include / "one.mqh").write_text("// bound include\n", encoding="utf-8")
    runtime_paths["farmctl"].write_text("# tampered farmctl\n", encoding="utf-8")
    runtime_invalid = runner._ftmo_source_binding_plan(
        payload, repo_root=repo, worker_script=worker, setfile_path=setfile
    )
    assert runtime_invalid["valid"] is False
    assert any(
        "runtime source farmctl SHA-256 mismatch" in error
        for error in runtime_invalid["errors"]
    )


def test_git_clean_plan_is_limited_to_bound_runtime_sources(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    bound = repo / "runtime.py"
    unrelated = repo / "public-data.json"
    bound.write_text("# bound\n", encoding="utf-8")
    unrelated.write_text("{}\n", encoding="utf-8")
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "add", "."], cwd=repo, check=True)
    subprocess.run(
        [
            "git",
            "-c",
            "user.name=FTMO test",
            "-c",
            "user.email=ftmo-test@example.invalid",
            "commit",
            "-qm",
            "initial",
        ],
        cwd=repo,
        check=True,
    )

    unrelated.write_text('{"owner":"open"}\n', encoding="utf-8")
    scoped = runner._git_clean_plan(repo, scoped_paths=[bound])
    assert scoped == {"valid": True, "error": None, "porcelain": ""}

    bound.write_text("# dirty bound source\n", encoding="utf-8")
    dirty = runner._git_clean_plan(repo, scoped_paths=[bound])
    assert dirty["valid"] is False
    assert dirty["error"] == "authoritative runtime-source scope is not clean"
    assert "runtime.py" in dirty["porcelain"]


def test_git_clean_plan_rejects_empty_or_outside_scope(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    repo.mkdir()
    outside = tmp_path / "outside.py"
    outside.write_text("# outside\n", encoding="utf-8")

    assert runner._git_clean_plan(repo)["valid"] is False
    result = runner._git_clean_plan(repo, scoped_paths=[outside])
    assert result["valid"] is False
    assert "outside the repository" in result["error"]


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
    assert result["success"] is True
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
    assert result["success"] is True


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


def test_preexisting_output_stops_before_worker_or_db_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    root, repo, db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )
    worker_log = tmp_path / "already.log"
    worker_log.write_text("belongs to another run\n", encoding="utf-8")

    with pytest.raises(FileExistsError, match="output target already exists"):
        runner.execute(
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
            worker_log_path=worker_log,
        )

    with sqlite3.connect(db) as conn:
        state = conn.execute(
            "SELECT status,verdict,claimed_by FROM work_items WHERE id='target'"
        ).fetchone()
    assert state == ("pending", None, None)
    assert worker_log.read_text(encoding="utf-8") == "belongs to another run\n"
    assert not (tmp_path / "before.sqlite").exists()
    assert not (tmp_path / "receipt.json").exists()
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()


def test_launch_exception_publishes_durable_failure_receipt(
    tmp_path: Path, monkeypatch
) -> None:
    root, repo, db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )

    def fail_launch(*_args, **_kwargs):
        raise OSError("injected launch failure")

    monkeypatch.setattr(runner.subprocess, "Popen", fail_launch)
    receipt_path = tmp_path / "failure.json"
    with pytest.raises(OSError, match="injected launch failure"):
        runner.execute(
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
            receipt_path=receipt_path,
            worker_log_path=tmp_path / "worker.log",
        )
    failure = json.loads(receipt_path.read_text(encoding="utf-8"))
    assert failure["state"] == "failed"
    assert failure["success"] is False
    assert failure["error_type"] == "OSError"
    assert (tmp_path / "before.sqlite").is_file()
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT status,verdict,claimed_by FROM work_items WHERE id='target'"
        ).fetchone() == ("pending", None, None)


def test_ftmo_work_core_rejects_wrong_hold_code_and_reason(tmp_path: Path) -> None:
    root, _repo, db, _payload = _seed(tmp_path)
    execution_sha = "1" * 64
    work_id = runner._content_uuid(execution_sha)
    assert work_id is not None
    core = runner.FTMO_BOOK3_WORK_CORE["R0"]
    setfile = tmp_path / core["set_name"]
    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
    payload = {
        "schema": "qm.ftmo-book3-q02-work-item-payload/v1",
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "measurement_rung": "R0",
        "measurement_sequence": 0,
        "required_fidelity_stage": None,
        "execution_bundle_sha256": execution_sha,
        "terminal": "T10",
        "avoid_terminals": [
            "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T_LIVE"
        ],
        "host_timeframe": "H1",
        "ea_dir_name": core["ea_dir_name"],
        "from_date": "2018.07.02",
        "to_date": "2025.12.31",
        "model": 4,
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "risk_mode": "RISK_FIXED",
        "risk_fixed": 1000,
        "risk_percent": 0,
        "isolated_only": True,
        "auto_enqueue": False,
        "auto_promote": False,
        "next_phase": None,
        "factory_on_authorized": False,
        "timeout_min": 240,
    }
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute(
            "UPDATE work_items SET id=?,phase='Q02',ea_id=?,symbol=?,setfile_path=?,payload_json=? "
            "WHERE id='target'",
            (
                work_id,
                core["ea_id"],
                core["symbol"],
                str(setfile),
                json.dumps(payload, sort_keys=True),
            ),
        )
        conn.execute(
            "UPDATE work_item_holds SET work_item_id=? WHERE work_item_id='target'",
            (work_id,),
        )
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_id,)).fetchone()
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (work_id,)
        ).fetchone()
    result = runner._ftmo_work_core_plan(
        row=row,
        hold=hold,
        payload=payload,
        work_item_id=work_id,
        terminal="T10",
        requested_timeout_minutes=240,
    )
    assert result["valid"] is False
    assert any("hold_code mismatch" in error for error in result["errors"])
    assert any("hold reason mismatch" in error for error in result["errors"])


def test_ftmo_ladder_rejects_out_of_order_rung(tmp_path: Path) -> None:
    _root, _repo, db, _payload = _seed(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute("DELETE FROM work_items")
        for rung, core in runner.FTMO_BOOK3_WORK_CORE.items():
            payload = {
                "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
                "measurement_rung": rung,
                "measurement_sequence": core["sequence"],
                "terminal": "T10",
            }
            conn.execute(
                "INSERT INTO work_items "
                "(id,phase,ea_id,symbol,setfile_path,status,verdict,claimed_by,evidence_path,payload_json,updated_at) "
                "VALUES (?,?,?,?,?,'pending',NULL,NULL,NULL,?,'now')",
                (
                    rung,
                    "Q02",
                    core["ea_id"],
                    core["symbol"],
                    core["set_name"],
                    json.dumps(payload, sort_keys=True),
                ),
            )
        current_payload = {
            "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
            "measurement_rung": "J0",
            "measurement_sequence": 1,
            "terminal": "T10",
        }
        blocked = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="J0", payload=current_payload
        )
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS',claimed_by=NULL,evidence_path='R0.json' "
            "WHERE id='R0'"
        )
        allowed = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="J0", payload=current_payload
        )
    assert blocked["valid"] is False
    assert any("predecessor" in error for error in blocked["errors"])
    assert allowed["valid"] is True


def test_payload_contract_allows_only_known_runtime_additions() -> None:
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "terminal": "T10",
        "execution_input_artifacts_sha256": "a" * 64,
    }
    text = json.dumps(payload, sort_keys=True)
    preflight = {
        "work_item": {"payload_sha256": runner.sha256_text(text)},
        "payload_contract": runner._payload_contract_plan(payload, payload_text=text),
    }
    allowed = {**payload, "pid": 1234, "verdict_reason": "ok"}
    allowed_result = runner._revalidate_payload_contract(
        preflight, post_payload_text=json.dumps(allowed, sort_keys=True)
    )
    changed = {**allowed, "terminal": "T9"}
    changed_result = runner._revalidate_payload_contract(
        preflight, post_payload_text=json.dumps(changed, sort_keys=True)
    )
    unexpected = {**allowed, "silent_override": True}
    unexpected_result = runner._revalidate_payload_contract(
        preflight, post_payload_text=json.dumps(unexpected, sort_keys=True)
    )
    assert allowed_result["valid"] is True
    assert changed_result["valid"] is False
    assert changed_result["changed_immutable_keys"] == ["terminal"]
    assert unexpected_result["valid"] is False
    assert unexpected_result["unexpected_added_runtime_keys"] == ["silent_override"]


def test_post_execution_input_revalidation_detects_drift(
    tmp_path: Path, monkeypatch
) -> None:
    bound = tmp_path / "bound.bin"
    bound.write_bytes(b"before")
    expected = {"t10_terminal_binary": bound}
    monkeypatch.setattr(
        runner, "_ftmo_book3_expected_execution_input_paths", lambda _repo: expected
    )
    rows = [{
        "role": "t10_terminal_binary",
        "path": str(bound),
        "sha256": _sha(bound),
        "bytes": bound.stat().st_size,
    }]
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "terminal": "T10",
        "execution_input_artifacts": rows,
        "execution_input_artifacts_sha256": runner.canonical_sha256(rows),
    }
    pre = runner._execution_input_plan(payload, repo_root=tmp_path)
    assert pre["valid"] is True
    bound.write_bytes(b"after")
    post = runner._revalidate_execution_inputs(
        {"execution_inputs": pre}, repo_root=tmp_path
    )
    assert post["valid"] is False
    assert any("changed during isolated run" in error for error in post["errors"])


def test_fidelity_stage_receipt_is_required_and_hash_bound(tmp_path: Path) -> None:
    hashes = {
        "fidelity_gate": "1" * 64,
        "isolated_runner": "2" * 64,
        "preparation_controller": "3" * 64,
        "fidelity_comparator": "4" * 64,
    }
    runtime_sources = [
        {"role": role, "path": str((tmp_path / role).resolve()), "sha256": value, "bytes": 1}
        for role, value in sorted(hashes.items())
    ]
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "measurement_sequence": 2,
        "required_fidelity_stage": 0,
        "authoritative_source_commit": "a" * 40,
        "execution_input_artifacts_sha256": "b" * 64,
        "runtime_source_artifacts": runtime_sources,
    }
    ladder = {
        "rungs": [
            {"rung": "R0", "id": "r0-id"},
            {"rung": "J0", "id": "j0-id"},
        ]
    }
    missing = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder,
        receipt_path=None,
        expected_receipt_sha256=None,
    )
    receipt = {
        "schema": "qm.ftmo-book3-fidelity-adjudication-receipt/v1",
        "generated_at_utc": "2026-07-29T12:00:00+00:00",
        "stage": 0,
        "verdict": "PASS",
        "errors": [],
        "work_item_ids": {"standalone": "r0-id", "joint": "j0-id"},
        "source_commit": "a" * 40,
        "execution_input_artifacts_sha256": "b" * 64,
        "controller_path": str(
            Path(runner.__file__).resolve().with_name("ftmo_book3_fidelity_gate.py")
        ),
        "controller_sha256": hashes["fidelity_gate"],
        "isolated_runner_sha256": hashes["isolated_runner"],
        "preparation_controller_sha256": hashes["preparation_controller"],
        "comparator_sha256": hashes["fidelity_comparator"],
        "contract": {"measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT},
        "safety": {
            "read_only_inputs": True,
            "create_only_output": True,
            "opens_factory_db": False,
            "runs_mt5": False,
            "mutates_factory_state": False,
            "touches_live_scope": False,
            "touches_autotrading": False,
        },
        "comparison": {
            "match_rate": 1.0,
            "unmatched_standalone": 0,
            "unmatched_joint": 0,
            "standalone_trades": 2,
            "joint_trades": 2,
        },
    }
    identity = {
        key: value
        for key, value in receipt.items()
        if key not in {"generated_at_utc", "adjudication_id"}
    }
    receipt["adjudication_id"] = hashlib.sha256(
        (
            json.dumps(
                identity,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
                allow_nan=False,
            )
            + "\n"
        ).encode("utf-8")
    ).hexdigest()
    path = (tmp_path / "stage0.json").resolve()
    path.write_text(json.dumps(receipt, sort_keys=True) + "\n", encoding="utf-8")
    valid = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder,
        receipt_path=path,
        expected_receipt_sha256=_sha(path),
    )
    receipt["verdict"] = "FAIL"
    path.write_text(json.dumps(receipt, sort_keys=True) + "\n", encoding="utf-8")
    invalid = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder,
        receipt_path=path,
        expected_receipt_sha256=_sha(path),
    )
    assert missing["valid"] is False
    assert valid["valid"] is True
    assert invalid["valid"] is False
    assert any("verdict mismatch" in error for error in invalid["errors"])


def test_invalid_dry_run_cli_returns_exit_two(
    tmp_path: Path, monkeypatch, capsys
) -> None:
    root, repo, _db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    exit_code = runner.main(
        [
            "--root", str(root),
            "--repo-root", str(repo),
            "--worker-script", str(worker),
            "--terminal", "T5",
            "--work-item-id", "target",
        ]
    )
    assert exit_code == 2
    assert '"valid": false' in capsys.readouterr().out


def test_oversized_payload_is_rejected_before_json_parse(
    tmp_path: Path, monkeypatch
) -> None:
    root, repo, db, _payload = _seed(tmp_path)
    worker = tmp_path / "worker.py"
    _fake_worker(worker)
    oversized = '{"padding":"' + ("x" * runner.MAX_PAYLOAD_BYTES) + '"}'
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET payload_json=? WHERE id='target'", (oversized,)
        )
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    plan = runner.build_plan(
        root, terminal="T6", work_item_id="target", worker_script=worker, repo_root=repo
    )
    assert plan["valid"] is False
    assert any("exceeds maximum size" in error for error in plan["errors"])


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


def test_legacy_single_stream_payload_contract_remains_compatible(
    tmp_path: Path, monkeypatch
) -> None:
    trades, _equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    source = trades / "20181_USDJPY_DWX.jsonl"
    source.write_text('{"trade":0}\n', encoding="utf-8")
    report_root = reports / "legacy"

    contract = runner._post_run_stream_plan(
        {
            "report_root": str(report_root),
            "post_run_file_common_source": str(source),
            "pre_v2_file_common_capture_sha256": "a" * 64,
        },
        "legacy",
    )

    assert contract["requested"] is True
    assert contract["valid"] is True
    assert "streams" not in contract
    assert contract["stream_type"] == "q08_trades"
    assert Path(contract["target"]) == (
        report_root / "q08_trades_20181_USDJPY_DWX.timer_v2.jsonl"
    )
    assert contract["pre_v2_capture"]["sha256"] == "a" * 64


def test_atomic_two_stream_harvest_requires_and_publishes_both(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    report_root = reports / "joint"
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(report_root),
            # Exercise the real migration shape: legacy trades plus a governed
            # additional equity stream in one atomic batch.
            "post_run_file_common_source": str(trade_source),
            "post_run_file_common_streams": [
                {"stream_type": "q08_equity", "source": str(equity_source)}
            ],
        },
        "joint",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n{"trade":2}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert contract["valid"] is True
    assert result["valid"] is True
    assert len(result["streams"]) == 2
    assert {item["stream_type"] for item in result["streams"]} == {
        "q08_trades",
        "q08_equity",
    }
    for item in result["streams"]:
        assert item["pre_run_source"]["exists"] is True
        assert item["post_run_source"]["exists"] is True
        assert item["post_stage_source"] == item["post_run_source"]
        assert item["valid"] is True
        assert item["harvested"]["sha256"] == item["post_run_source"]["sha256"]
        assert Path(item["target"]).read_bytes() == Path(item["source"]).read_bytes()
    assert not list(report_root.glob("*.tmp"))


def test_atomic_two_stream_harvest_publishes_nothing_when_one_is_unchanged(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    report_root = reports / "partial"
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(report_root),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "partial",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert any("unchanged" in str(item.get("error")) for item in result["streams"])
    assert not any(Path(item["target"]).exists() for item in result["streams"])


def test_atomic_two_stream_harvest_rolls_back_if_second_publish_fails(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    report_root = reports / "rollback"
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(report_root),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "rollback",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)
    real_replace = os.replace

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            raise OSError("injected second-publish failure")
        real_replace(source, target)

    monkeypatch.setattr(runner.os, "replace", fail_equity_publish)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert any("injected second-publish failure" in error for error in result["errors"])
    assert not any(Path(item["target"]).exists() for item in result["streams"])
    assert not list(report_root.glob("*.tmp"))


def test_multi_stream_plan_rejects_traversal_outside_allowlist_and_target_injection(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    outside = equity.parent / "outside" / "escape.jsonl"
    outside.parent.mkdir()
    outside.write_text("{}\n", encoding="utf-8")
    traversal = trades / ".." / "outside" / "escape.jsonl"

    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "escape"),
            "post_run_file_common_streams": [
                {
                    "stream_type": "q08_trades",
                    "source": str(traversal),
                    "target": str(tmp_path / "escaped.jsonl"),
                }
            ],
        },
        "escape",
    )

    assert contract["valid"] is False
    joined = " | ".join(contract["errors"])
    assert "outside the governed FILE_COMMON q08_trades" in joined
    assert "caller-selected targets are forbidden" in joined
    assert runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=time.time_ns()
    )["valid"] is False
    assert not (tmp_path / "escaped.jsonl").exists()


def test_multi_stream_plan_rejects_duplicate_governed_targets(
    tmp_path: Path, monkeypatch
) -> None:
    trades, _equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    source = trades / "20181_USDJPY_DWX.jsonl"
    source.write_text("{}\n", encoding="utf-8")

    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "duplicate"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(source)},
                {"stream_type": "q08_trades", "source": str(source)},
            ],
        },
        "duplicate",
    )

    assert contract["valid"] is False
    assert any("duplicate post-run evidence target" in error for error in contract["errors"])


def test_multi_stream_plan_rejects_duplicate_roles_and_mixed_run_stems(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    trade_a = trades / "20181_USDJPY_DWX.jsonl"
    trade_b = trades / "20181_XAUUSD_DWX.jsonl"
    equity_b = equity / "20181_XAUUSD_DWX.jsonl"
    for source in (trade_a, trade_b, equity_b):
        source.write_text("{}\n", encoding="utf-8")

    duplicate_role = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "duplicate-role"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_a)},
                {"stream_type": "q08_trades", "source": str(trade_b)},
            ],
        },
        "duplicate-role",
    )
    mixed_stems = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "mixed-stems"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_a)},
                {"stream_type": "q08_equity", "source": str(equity_b)},
            ],
        },
        "mixed-stems",
    )
    mismatched_type = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "mismatched-type"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(equity_b)},
            ],
        },
        "mismatched-type",
    )

    assert duplicate_role["valid"] is False
    assert any("appears more than once" in error for error in duplicate_role["errors"])
    assert mixed_stems["valid"] is False
    assert any("source stems must be identical" in error for error in mixed_stems["errors"])
    assert mismatched_type["valid"] is False
    assert any(
        "outside the governed FILE_COMMON q08_trades" in error
        for error in mismatched_type["errors"]
    )


def test_empty_multi_stream_list_is_an_explicit_valid_noop(
    tmp_path: Path, monkeypatch
) -> None:
    trades, _equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "empty"),
            "post_run_file_common_streams": [],
        },
        "empty",
    )

    assert contract == {
        "requested": False,
        "valid": True,
        "mode": "atomic_multi",
        "streams": [],
    }
    assert runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=time.time_ns()
    ) == {"requested": False, "valid": True}

    legacy_source = trades / "20181_USDJPY_DWX.jsonl"
    legacy_source.write_text("{}\n", encoding="utf-8")
    legacy_contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "legacy-empty"),
            "post_run_file_common_source": str(legacy_source),
            "post_run_file_common_streams": [],
        },
        "legacy-empty",
    )
    assert legacy_contract["requested"] is True
    assert legacy_contract["valid"] is True
    assert "streams" not in legacy_contract


def test_recovery_retries_and_requires_all_streams_from_failed_batch(
    tmp_path: Path, monkeypatch
) -> None:
    root, _repo, db, _payload = _seed(tmp_path)
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "target"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "target",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)
    real_replace = os.replace

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            raise OSError("injected recovery-eligible publication failure")
        real_replace(source, target)

    monkeypatch.setattr(runner.os, "replace", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    assert failed["valid"] is False
    monkeypatch.setattr(runner.os, "replace", real_replace)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS',evidence_path='evidence.json' "
            "WHERE id='target'"
        )
    started_at = dt.datetime.fromtimestamp(started_ns / 1_000_000_000, dt.UTC).isoformat()
    source_receipt = tmp_path / "failed_receipt.json"
    source_receipt.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "mode": "apply",
                "started_at_utc": started_at,
                "worker_exit_code": 0,
                "factory_off_sha256": runner.sha256_file(
                    root / "state" / "FACTORY_OFF.flag"
                ),
                "post_db_state_sha256": runner.sqlite_state_sha256(db),
                "post_work_item": {
                    "id": "target",
                    "status": "done",
                    "verdict": "PASS",
                },
                "preflight": {"post_run_stream": contract},
                "post_run_stream": failed,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    result = runner.recover_harvest_from_receipt(
        root,
        source_receipt_path=source_receipt,
        expected_source_receipt_sha256=runner.sha256_file(source_receipt),
        recovery_receipt_path=tmp_path / "recovery_receipt.json",
    )

    assert result["harvest"]["valid"] is True
    assert len(result["harvest"]["streams"]) == 2
    assert all(Path(item["target"]).is_file() for item in result["harvest"]["streams"])
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()


def test_recovery_refuses_stream_rewritten_after_original_failed_harvest(
    tmp_path: Path, monkeypatch
) -> None:
    root, _repo, db, _payload = _seed(tmp_path)
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "target"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "target",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)
    real_replace = os.replace

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            raise OSError("injected publication failure")
        real_replace(source, target)

    monkeypatch.setattr(runner.os, "replace", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    assert failed["valid"] is False
    monkeypatch.setattr(runner.os, "replace", real_replace)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS',evidence_path='evidence.json' "
            "WHERE id='target'"
        )
    source_receipt = tmp_path / "failed_receipt.json"
    source_receipt.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "mode": "apply",
                "started_at_utc": dt.datetime.fromtimestamp(
                    started_ns / 1_000_000_000, dt.UTC
                ).isoformat(),
                "worker_exit_code": 0,
                "factory_off_sha256": runner.sha256_file(
                    root / "state" / "FACTORY_OFF.flag"
                ),
                "post_db_state_sha256": runner.sqlite_state_sha256(db),
                "post_work_item": {
                    "id": "target",
                    "status": "done",
                    "verdict": "PASS",
                },
                "preflight": {"post_run_stream": contract},
                "post_run_stream": failed,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    _rewrite_after_preflight(equity_source, '{"equity":2}\n', time.time_ns())
    with pytest.raises(RuntimeError, match="changed after the original harvest"):
        runner.recover_harvest_from_receipt(
            root,
            source_receipt_path=source_receipt,
            expected_source_receipt_sha256=runner.sha256_file(source_receipt),
            recovery_receipt_path=tmp_path / "recovery_receipt.json",
        )

    assert not list((reports / "target").glob("*.jsonl"))
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()


def test_atomic_two_stream_harvest_rolls_back_on_baseexception(
    tmp_path: Path, monkeypatch
) -> None:
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    report_root = reports / "baseexception"
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(report_root),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "baseexception",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)
    real_replace = os.replace

    class InjectedPublicationAbort(BaseException):
        pass

    def abort_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            # Model an interrupt delivered after the OS completed replace but
            # before the Python call returned to append bookkeeping.
            real_replace(source, target)
            raise InjectedPublicationAbort("injected BaseException")
        real_replace(source, target)

    monkeypatch.setattr(runner.os, "replace", abort_equity_publish)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert any("InjectedPublicationAbort" in error for error in result["errors"])
    assert not any(Path(item["target"]).exists() for item in result["streams"])
    assert result["publication"]["physically_atomic_across_targets"] is False
    assert result["publication"]["rollback_attempted"] is True
    assert result["publication"]["rollback_complete"] is True
    assert result["publication"]["published_targets"] == []


@pytest.mark.parametrize("tampered_field", ["source", "target"])
def test_recovery_revalidates_serialized_receipt_paths_fail_closed(
    tmp_path: Path, monkeypatch, tampered_field: str
) -> None:
    root, _repo, db, _payload = _seed(tmp_path)
    trades, equity, reports = _governed_stream_environment(tmp_path, monkeypatch)
    monkeypatch.setattr(runner, "_factory_processes", lambda: [])
    trade_source = trades / "20181_USDJPY_DWX.jsonl"
    equity_source = equity / "20181_USDJPY_DWX.jsonl"
    trade_source.write_text('{"trade":0}\n', encoding="utf-8")
    equity_source.write_text('{"equity":0}\n', encoding="utf-8")
    contract = runner._post_run_stream_plan(
        {
            "report_root": str(reports / "target"),
            "post_run_file_common_streams": [
                {"stream_type": "q08_trades", "source": str(trade_source)},
                {"stream_type": "q08_equity", "source": str(equity_source)},
            ],
        },
        "target",
    )
    started_ns = max(
        trade_source.stat().st_mtime_ns, equity_source.stat().st_mtime_ns
    )
    _rewrite_after_preflight(trade_source, '{"trade":1}\n', started_ns)
    _rewrite_after_preflight(equity_source, '{"equity":1}\n', started_ns)
    real_replace = os.replace

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            raise OSError("make receipt recovery-eligible")
        real_replace(source, target)

    monkeypatch.setattr(runner.os, "replace", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    monkeypatch.setattr(runner.os, "replace", real_replace)
    assert failed["valid"] is False
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS',evidence_path='evidence.json' "
            "WHERE id='target'"
        )

    tampered = json.loads(json.dumps(contract))
    outside = tmp_path / "outside"
    outside.mkdir()
    if tampered_field == "source":
        outside_source = outside / "20181_USDJPY_DWX.jsonl"
        outside_source.write_text('{"outside":true}\n', encoding="utf-8")
        tampered["streams"][0]["source"] = str(outside_source)
    else:
        tampered["streams"][0]["target"] = str(outside / "stolen.jsonl")
    # Explicitly lie in the serialized bits; recovery must recompute trust.
    tampered["valid"] = True
    tampered["streams"][0]["valid"] = True
    source_receipt = tmp_path / f"tampered_{tampered_field}_receipt.json"
    source_receipt.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "mode": "apply",
                "started_at_utc": dt.datetime.fromtimestamp(
                    started_ns / 1_000_000_000, dt.UTC
                ).isoformat(),
                "worker_exit_code": 0,
                "factory_off_sha256": runner.sha256_file(
                    root / "state" / "FACTORY_OFF.flag"
                ),
                "post_db_state_sha256": runner.sqlite_state_sha256(db),
                "post_work_item": {
                    "id": "target",
                    "status": "done",
                    "verdict": "PASS",
                },
                "preflight": {"post_run_stream": tampered},
                "post_run_stream": failed,
            }
        )
        + "\n",
        encoding="utf-8",
    )

    with pytest.raises(RuntimeError, match="serialized recovery harvest contract is invalid"):
        runner.recover_harvest_from_receipt(
            root,
            source_receipt_path=source_receipt,
            expected_source_receipt_sha256=runner.sha256_file(source_receipt),
            recovery_receipt_path=tmp_path / "recovery_receipt.json",
        )

    assert not (tmp_path / "recovery_receipt.json").exists()
    assert not list((reports / "target").glob("*.jsonl"))
    assert not (root / "state" / "FACTORY_MUTATION.lock").exists()
