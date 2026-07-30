from __future__ import annotations

import datetime as dt
import copy
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
import ftmo_book3_fidelity_gate as fidelity_gate  # noqa: E402
import farmctl  # noqa: E402


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
              id TEXT PRIMARY KEY, kind TEXT DEFAULT 'backtest', phase TEXT,
              ea_id TEXT, symbol TEXT, setfile_path TEXT, status TEXT,
              verdict TEXT, attempt_count INTEGER DEFAULT 0,
              parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
              payload_json TEXT, created_at TEXT DEFAULT 'now', updated_at TEXT
            );
            CREATE TABLE work_item_holds(
              work_item_id TEXT PRIMARY KEY, hold_code TEXT, reason TEXT,
              active INTEGER, release_on_restart INTEGER, created_at TEXT,
              updated_at TEXT, released_at TEXT, release_note TEXT
            );
            """
        )
        conn.execute(
            "INSERT INTO work_items "
            "(id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,"
            "parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at) "
            "VALUES ('target','backtest','Q02','QM5_99999','GDAXI.DWX',?,'pending',"
            "NULL,0,NULL,NULL,NULL,?,'now','now')",
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
    monkeypatch.setattr(
        runner,
        "_ftmo_compile_binding_plan",
        lambda *_args, **_kwargs: {
            "requested": True,
            "valid": True,
            "errors": [],
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


def test_ftmo_compile_binding_is_parsed_rehashed_and_revalidated(
    tmp_path: Path,
) -> None:
    repo = (tmp_path / "repo").resolve()
    artifact_root = (tmp_path / "compile").resolve()
    flag = (tmp_path / "state" / "FACTORY_OFF.flag").resolve()
    flag.parent.mkdir(parents=True)
    flag.write_text("off\n", encoding="utf-8")
    controller = repo / "tools/strategy_farm/compile_ftmo_book3_v2.ps1"
    controller.parent.mkdir(parents=True)
    controller.write_text("# compile\n", encoding="utf-8")
    expected_results = (
        (9936, "QM5_9936_ff-range-breakout-gmt3-h1"),
        (10145, "QM5_10145_tsm-meanret"),
        (13108, "QM5_13108_xti-mtsm-s2"),
        (20181, "QM5_20181_ftmo-joint-multisym-timer"),
    )
    results = []
    for ea_id, name in expected_results:
        mq5 = repo / "framework/EAs" / name / f"{name}.mq5"
        ex5 = artifact_root / "canonical_staged_ex5" / f"{name}.ex5"
        log = artifact_root / "canonical_compile_logs" / f"{name}.compile.log"
        for path in (mq5, ex5, log):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"{path.name}\n", encoding="utf-8")
        results.append(
            {
                "ea_id": ea_id,
                "name": name,
                "result": "PASS",
                "errors": 0,
                "warnings": 0,
                "metaeditor_exit_code": 1,
                "source_mq5_path": str(mq5),
                "source_mq5_sha256": runner.sha256_file(mq5),
                "ex5_path": str(ex5),
                "ex5_sha256": runner.sha256_file(ex5),
                "compile_log_path": str(log),
                "compile_log_sha256": runner.sha256_file(log),
            }
        )
    artifact_root.mkdir(parents=True, exist_ok=True)
    manifest_path = artifact_root / "compile_manifest.json"
    source_commit = "1" * 40
    manifest = {
        "schema_version": 2,
        "contract": "FTMO_BOOK3_PORTABLE_COMPILE_V2",
        "result": "PASS",
        "create_only": True,
        "serial_compile": True,
        "canonical_publication_after_four_pass": True,
        "terminals_started": [],
        "terminals_modified": [],
        "artifact_root": str(artifact_root),
        "source_commit": source_commit,
        "factory_off": {"path": str(flag), "sha256": runner.sha256_file(flag)},
        "mutation_lock": {
            "path": str(runner.path_for_factory_flag(flag)),
            "required_absent": True,
        },
        "tool": {
            "path": str(controller),
            "sha256": runner.sha256_file(controller),
        },
        "results": results,
    }
    manifest_path.write_text(json.dumps(manifest) + "\n", encoding="utf-8")
    selected = results[2]
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
        "compile_manifest_path": str(manifest_path),
        "compile_manifest_sha256": runner.sha256_file(manifest_path),
        "compile_manifest_bytes": manifest_path.stat().st_size,
        "compile_source_commit": source_commit,
        "compile_controller_path": str(controller),
        "compile_controller_sha256": runner.sha256_file(controller),
        "ea_dir_name": selected["name"],
        "staged_ex5_path": selected["ex5_path"],
        "staged_ex5_sha256": selected["ex5_sha256"],
        "expected_mq5_sha256": selected["source_mq5_sha256"],
    }
    binding = runner._ftmo_compile_binding_plan(
        payload,
        repo_root=repo,
        factory_off_flag=flag,
        expected_factory_off_sha256=runner.sha256_file(flag),
    )
    assert binding["valid"] is True, binding["errors"]

    controller.write_text("# tampered\n", encoding="utf-8")
    revalidated = runner._revalidate_compile_binding(
        {
            "compile_binding": binding,
            "factory_off_flag": str(flag),
            "factory_off_sha256": runner.sha256_file(flag),
        },
        repo_root=repo,
    )
    assert revalidated["valid"] is False
    assert any("controller" in error for error in revalidated["errors"])


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
        / "2026-07-29_ftmo_book3_execution_preregistration_v2.md"
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
        "qm_evidence_run_id=FTMO_BOOK3_20260729_V2_J0\n",
        encoding="utf-8",
    )
    commit = "a" * 40
    tree_sha, _ = runner._tree_content_sha256(include)
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "evidence_vintage": runner.FTMO_BOOK3_EVIDENCE_VINTAGE,
        "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "measurement_rung": "J0",
        "measurement_sequence": 1,
        "evidence_run_id": "FTMO_BOOK3_20260729_V2_J0",
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
    assert valid["valid"] is True, valid["errors"]

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


def test_standalone_diagnostic_runtime_source_closure_binds_import_dependencies(
    tmp_path: Path,
) -> None:
    paths = runner._ftmo_runtime_source_paths(
        tmp_path,
        worker_script=tmp_path / "terminal_worker.py",
        measurement_contract=runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
    )
    assert set(runner.FTMO_DIAGNOSTIC_EXTRA_RUNTIME_SOURCE_ROLES) <= set(paths)
    assert "fidelity_comparator" not in paths
    assert "fidelity_gate" not in paths
    assert paths["base_preparation_controller"].name == "prepare_ftmo_book3_q02.py"
    assert paths["news_calendar_gate"].name == "news_calendar_gate.py"
    assert paths["q09_news_contract"].name == "q09_news_contract.py"
    assert paths["phase_runner_allowlist"].name == "phase_runner_allowlist.v1.json"
    assert paths["tester_defaults"].as_posix().endswith(
        "framework/registry/tester_defaults.json"
    )


@pytest.mark.parametrize(
    "drift_role", ["q09_news_contract", "phase_runner_allowlist", "tester_defaults"]
)
def test_standalone_diagnostic_transitive_runtime_dependency_drift_between_checks_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, drift_role: str
) -> None:
    repo = (tmp_path / "repo").resolve()
    worker = (tmp_path / "terminal_worker.py").resolve()
    paths = runner._ftmo_runtime_source_paths(
        repo,
        worker_script=worker,
        measurement_contract=runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
    )
    for role, path in paths.items():
        if path.is_file():
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"bound runtime source: {role}\n", encoding="utf-8")
    rows = sorted(
        (
            {
                "role": role,
                "path": str(path),
                "sha256": runner.sha256_file(path),
                "bytes": path.stat().st_size,
            }
            for role, path in paths.items()
        ),
        key=lambda row: (row["role"], row["path"]),
    )
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
        "runtime_source_artifacts": rows,
        "runtime_source_artifacts_sha256": runner.canonical_sha256(rows),
    }
    monkeypatch.setattr(
        runner,
        "_git_clean_plan",
        lambda *_args, **_kwargs: {
            "valid": True,
            "error": None,
            "porcelain": "",
        },
    )
    preflight_runtime = runner._ftmo_runtime_source_plan(
        payload, repo_root=repo, worker_script=worker
    )
    assert preflight_runtime["valid"] is True, preflight_runtime["errors"]

    paths[drift_role].write_text("raced after preflight\n", encoding="utf-8")
    post = runner._revalidate_runtime_sources(
        {
            "work_item": {
                "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT
            },
            "source_binding": {"runtime_sources": preflight_runtime},
        },
        repo_root=repo,
        worker_script=worker,
    )
    assert post["valid"] is False
    assert any(
        f"runtime source {drift_role} SHA-256 mismatch" in error
        for error in post["errors"]
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
    assert result["success_checks"] == {
        key: True for key in fidelity_gate.SUCCESS_CHECK_KEYS
    }
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


def _diagnostic_core_payload(execution_sha: str) -> dict:
    core = runner.FTMO_BOOK3_DIAGNOSTIC_WORK_CORE
    return {
        "schema": "qm.ftmo-book3-standalone-diagnostic-work-item-payload/v1",
        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
        "evidence_vintage": runner.FTMO_BOOK3_DIAGNOSTIC_EVIDENCE_VINTAGE,
        "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "diagnostic_code": core["diagnostic_code"],
        "diagnostic_purpose": "portfolio_component_evaluation",
        "compile_policy": runner.FTMO_BOOK3_DIAGNOSTIC_COMPILE_POLICY,
        "no_ladder_progression": True,
        "no_joint_admission": True,
        "no_release_authority": True,
        "supersedes_work_item_id": None,
        "excluded_v2_r2_row_sha256": "b" * 64,
        "excluded_v2_r2_hold_sha256": "a" * 64,
        "execution_bundle_sha256": execution_sha,
        "terminal": "T10",
        "avoid_terminals": [
            "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T_LIVE"
        ],
        "host_timeframe": core["period"],
        "ea_dir_name": core["ea_dir_name"],
        "from_date": "2018.07.02",
        "to_date": "2025.12.31",
        "model": 4,
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "risk_mode": "RISK_FIXED",
        "risk_fixed": 1000,
        "risk_percent": 0,
        "q08_expected_magic": 131080000,
        "q08_expected_symbol": "XTIUSD.DWX",
        "q08_expected_money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "isolated_only": True,
        "auto_enqueue": False,
        "auto_promote": False,
        "next_phase": None,
        "factory_on_authorized": False,
        "timeout_min": 240,
    }


def test_ftmo_standalone_diagnostic_core_is_separate_and_exact(tmp_path: Path) -> None:
    _root, _repo, db, _payload = _seed(tmp_path)
    execution_sha = "2" * 64
    work_id = runner._content_uuid(execution_sha)
    assert work_id is not None
    core = runner.FTMO_BOOK3_DIAGNOSTIC_WORK_CORE
    setfile = tmp_path / core["set_name"]
    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")
    payload = _diagnostic_core_payload(execution_sha)
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
            "UPDATE work_item_holds SET work_item_id=?,hold_code=?,reason=? "
            "WHERE work_item_id='target'",
            (
                work_id,
                runner.FTMO_BOOK3_DIAGNOSTIC_HOLD_CODE,
                runner.FTMO_BOOK3_DIAGNOSTIC_HOLD_REASON,
            ),
        )
        row = conn.execute("SELECT * FROM work_items WHERE id=?", (work_id,)).fetchone()
        hold = conn.execute(
            "SELECT * FROM work_item_holds WHERE work_item_id=?", (work_id,)
        ).fetchone()
    accepted = runner._ftmo_work_core_plan(
        row=row,
        hold=hold,
        payload=payload,
        work_item_id=work_id,
        terminal="T10",
        requested_timeout_minutes=240,
    )
    assert accepted["valid"] is True, accepted["errors"]
    assert accepted["diagnostic"] is True

    spliced = {**payload, "measurement_rung": "R2", "measurement_sequence": 4}
    rejected = runner._ftmo_work_core_plan(
        row=row,
        hold=hold,
        payload=spliced,
        work_item_id=work_id,
        terminal="T10",
        requested_timeout_minutes=240,
    )
    assert rejected["valid"] is False
    assert any("forbidden V2 ladder fields" in error for error in rejected["errors"])

    caller_rooted = {**payload, "report_root": str(tmp_path / "caller-selected")}
    rejected_root = runner._ftmo_work_core_plan(
        row=row,
        hold=hold,
        payload=caller_rooted,
        work_item_id=work_id,
        terminal="T10",
        requested_timeout_minutes=240,
    )
    assert rejected_root["valid"] is False
    assert any("report_root must be absent" in error for error in rejected_root["errors"])


def test_ftmo_standalone_diagnostic_binds_untouched_pending_v2_r2(
    tmp_path: Path,
) -> None:
    _root, _repo, db, _payload = _seed(tmp_path)
    excluded_payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "measurement_rung": "R2",
        "measurement_sequence": 4,
        "terminal": "T10",
    }
    excluded_raw = json.dumps(excluded_payload, sort_keys=True)
    excluded_sha = runner.sha256_text(excluded_raw)
    excluded_hold = {
        "work_item_id": "v2-r2",
        "hold_code": runner.FTMO_BOOK3_HOLD_CODE,
        "reason": runner.FTMO_BOOK3_HOLD_REASON,
        "active": 1,
        "release_on_restart": 0,
        "created_at": "now",
        "updated_at": "now",
        "released_at": None,
        "release_note": None,
    }
    diagnostic_payload = {
        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
        "excluded_v2_r2_work_item_id": "v2-r2",
        "excluded_v2_r2_payload_sha256": excluded_sha,
        "excluded_v2_r2_row_sha256": "",
        "excluded_v2_r2_hold_sha256": runner.canonical_sha256(excluded_hold),
    }
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute(
            "INSERT INTO work_items "
            "(id,phase,ea_id,symbol,setfile_path,status,verdict,claimed_by,evidence_path,payload_json,updated_at) "
            "VALUES ('v2-r2','Q02','QM5_13108','XTIUSD.DWX','r2.set','pending',NULL,NULL,NULL,?,'now')",
            (excluded_raw,),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES (?,?,?,?,?,?,?,?,?)",
            tuple(excluded_hold.values()),
        )
        excluded_row = conn.execute(
            "SELECT * FROM work_items WHERE id='v2-r2'"
        ).fetchone()
        diagnostic_payload["excluded_v2_r2_row_sha256"] = runner.canonical_sha256(
            {
                key: excluded_row[key]
                for key in runner.FTMO_V2_R2_WORK_ITEM_PREIMAGE_COLUMNS
            }
        )
        accepted = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="diagnostic", payload=diagnostic_payload
        )
        conn.execute(
            "UPDATE work_items SET attempt_count=1 WHERE id='v2-r2'"
        )
        row_rejected = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="diagnostic", payload=diagnostic_payload
        )
        conn.execute(
            "UPDATE work_items SET attempt_count=0 WHERE id='v2-r2'"
        )
        conn.execute(
            "UPDATE work_item_holds SET active=0,released_at='later',release_note='released' "
            "WHERE work_item_id='v2-r2'"
        )
        hold_rejected = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="diagnostic", payload=diagnostic_payload
        )
        conn.execute(
            "UPDATE work_item_holds SET active=1,released_at=NULL,release_note=NULL "
            "WHERE work_item_id='v2-r2'"
        )
        conn.execute(
            "UPDATE work_items SET status='done',verdict='PASS' WHERE id='v2-r2'"
        )
        rejected = runner._ftmo_ladder_order_plan(
            conn, current_work_item_id="diagnostic", payload=diagnostic_payload
        )
    assert accepted["valid"] is True, accepted["errors"]
    assert accepted["rungs"] == []
    assert accepted["no_ladder_progression"] is True
    assert row_rejected["valid"] is False
    assert any("row SHA-256 drift" in error for error in row_rejected["errors"])
    assert hold_rejected["valid"] is False
    assert any("hold active mismatch" in error for error in hold_rejected["errors"])
    revalidated = runner._revalidate_diagnostic_isolation(
        {
            "work_item_id": "diagnostic",
            "ladder_order": accepted,
        },
        db=db,
    )
    assert revalidated["valid"] is False
    assert any("changed during" in error for error in revalidated["errors"])
    assert rejected["valid"] is False
    assert any("status mismatch" in error for error in rejected["errors"])


def test_ftmo_standalone_diagnostic_forbids_fidelity_receipt(tmp_path: Path) -> None:
    payload = {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT}
    without = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order={"rungs": []},
        receipt_path=None,
        expected_receipt_sha256=None,
        expected_factory_off_sha256="a" * 64,
    )
    with_receipt = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order={"rungs": []},
        receipt_path=tmp_path / "receipt.json",
        expected_receipt_sha256="b" * 64,
        expected_factory_off_sha256="a" * 64,
    )
    assert without["valid"] is True
    assert without["prohibited"] is True
    assert with_receipt["valid"] is False
    assert any("must not consume" in error for error in with_receipt["errors"])


def test_diagnostic_post_run_plan_requires_wholly_absent_content_report_root(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    reports = (tmp_path / "reports" / "work_items").resolve()
    trades = (tmp_path / "common" / "q08_trades").resolve()
    trades.mkdir(parents=True)
    source = trades / "13108_XTIUSD_DWX.jsonl"
    source.write_text("{}\n", encoding="utf-8")
    monkeypatch.setattr(runner, "DEFAULT_REPORTS_WORK_ITEMS", reports)
    monkeypatch.setattr(runner, "DEFAULT_FILE_COMMON_Q08", trades)
    work_id = "diagnostic-content-id"
    report_root = reports / work_id
    report_root.mkdir(parents=True)
    (report_root / "foreign.txt").write_text("incumbent\n", encoding="utf-8")
    result = runner._post_run_stream_plan(
        {
            "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
            "post_run_file_common_source": str(source),
        },
        work_id,
    )
    assert result["valid"] is False
    assert any("report_root must be wholly absent" in error for error in result["errors"])
    assert (report_root / "foreign.txt").read_text(encoding="utf-8") == "incumbent\n"


def test_diagnostic_compile_gate_uses_only_manifest_pinned_staged_ex5(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ea_dir = runner.FTMO_BOOK3_DIAGNOSTIC_WORK_CORE["ea_dir_name"]
    source = (tmp_path / "artifacts" / "staged.ex5").resolve()
    destination = (tmp_path / "terminal" / "Experts" / "QM" / f"{ea_dir}.ex5").resolve()
    manifest = (tmp_path / "artifacts" / "compile.json").resolve()
    repo_ex5 = (tmp_path / "repo" / "framework" / "EAs" / ea_dir / f"{ea_dir}.ex5").resolve()
    for path in (source, destination, manifest, repo_ex5):
        path.parent.mkdir(parents=True, exist_ok=True)
    source.write_bytes(b"manifest-pinned-binary")
    destination.write_bytes(source.read_bytes())
    manifest.write_text('{"strict":"PASS"}\n', encoding="utf-8")
    repo_ex5.write_bytes(b"do-not-touch-repository-binary")
    repo_before = (repo_ex5.read_bytes(), repo_ex5.stat().st_mtime_ns)
    staged_sha = runner.sha256_file(source)
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
        "compile_policy": runner.FTMO_BOOK3_DIAGNOSTIC_COMPILE_POLICY,
        "ea_dir_name": ea_dir,
        "staged_ex5_path": str(source),
        "staged_ex5_sha256": staged_sha,
        "compile_manifest_path": str(manifest),
        "compile_manifest_sha256": runner.sha256_file(manifest),
        "compile_manifest_bytes": manifest.stat().st_size,
        "staged_ex5": {
            "source_path": str(source),
            "destination_path": str(destination),
            "required_sha256": staged_sha,
            "pre_run_sha256": staged_sha,
        },
    }
    monkeypatch.setattr(
        farmctl,
        "_compile_gate_check",
        lambda _name: (_ for _ in ()).throw(
            AssertionError("generic compile fallback must never run")
        ),
    )

    accepted = farmctl._work_item_compile_gate("Q02", ea_dir, payload)
    assert accepted["allowed"] is True
    assert accepted["generic_compile_fallback_allowed"] is False
    assert accepted["source"] == "manifest_pinned_staged_ex5_no_recompile"

    source.write_bytes(b"drifted")
    rejected = farmctl._work_item_compile_gate("Q02", ea_dir, payload)
    assert rejected["allowed"] is False
    assert "staged_ex5_source_sha256_mismatch" in rejected["errors"]
    assert (repo_ex5.read_bytes(), repo_ex5.stat().st_mtime_ns) == repo_before


def test_diagnostic_exact_window_is_not_replaced_by_generic_q02_defaults() -> None:
    assert farmctl._ftmo_book3_q02_exact_window(
        "Q02",
        {
            "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT,
            "from_date": "2018.07.02",
            "to_date": "2025.12.31",
        },
    ) == ("2018.07.02", "2025.12.31")


def test_ftmo_standalone_diagnostic_q08_requires_full_lifecycle_rows(
    tmp_path: Path,
) -> None:
    target = tmp_path / "q08.jsonl"
    row = {
        "event": "TRADE_CLOSED",
        "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "magic": 131080000,
        "symbol": "XTIUSD.DWX",
        "side": "BUY",
        "entry_time": 100,
        "time": 200,
        "entry_price": 70.0,
        "exit_price": 71.0,
        "profit": 100.0,
        "swap": -1.0,
        "fee": 0.0,
        "entry_commission": -0.5,
        "exit_commission": -0.5,
        "commission": -1.0,
        "net": 98.0,
        "volume": 1.0,
        "mae_acct": -25.0,
    }
    target.write_text(json.dumps(row) + "\n", encoding="utf-8")
    payload = {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT}
    valid = runner._ftmo_diagnostic_q08_plan(
        payload,
        {
            "valid": True,
            "target": str(target),
            "harvested": runner._stream_fingerprint(target),
        },
    )
    assert valid["valid"] is True, valid["errors"]
    assert valid["selected_trade_count"] == 1
    assert valid["downstream_evaluator_gate"] == {
        "field": "selected_trade_count",
        "required_exact_stream_recount": True,
        "count": 1,
    }

    row.pop("money_basis")
    target.write_text(json.dumps(row) + "\n", encoding="utf-8")
    invalid = runner._ftmo_diagnostic_q08_plan(
        payload,
        {
            "valid": True,
            "target": str(target),
            "harvested": runner._stream_fingerprint(target),
        },
    )
    assert invalid["valid"] is False
    assert any("money_basis mismatch" in error for error in invalid["errors"])


@pytest.mark.parametrize(
    ("field", "bad_value", "expected_error"),
    [
        ("magic", 131080001, "magic mismatch"),
        ("magic", 131080000.0, "magic mismatch"),
        ("money_basis", "PROFIT_ONLY", "money_basis mismatch"),
        ("net", 99.0, "full-lifecycle net does not reconcile"),
        ("mae_acct", 1.0, "mae_acct must be non-positive"),
    ],
)
def test_ftmo_standalone_diagnostic_q08_rejects_semantic_drift(
    tmp_path: Path, field: str, bad_value: object, expected_error: str
) -> None:
    target = tmp_path / "q08.jsonl"
    row = {
        "event": "TRADE_CLOSED",
        "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "magic": 131080000,
        "symbol": "XTIUSD.DWX",
        "side": "BUY",
        "entry_time": 100,
        "time": 200,
        "entry_price": 70.0,
        "exit_price": 71.0,
        "profit": 100.0,
        "swap": -1.0,
        "fee": 0.0,
        "entry_commission": -0.5,
        "exit_commission": -0.5,
        "commission": -1.0,
        "net": 98.0,
        "volume": 1.0,
        "mae_acct": -25.0,
    }
    row[field] = bad_value
    target.write_text(json.dumps(row) + "\n", encoding="utf-8")
    result = runner._ftmo_diagnostic_q08_plan(
        {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT},
        {
            "valid": True,
            "target": str(target),
            "harvested": runner._stream_fingerprint(target),
        },
    )
    assert result["valid"] is False
    assert any(expected_error in error for error in result["errors"])


def test_ftmo_standalone_diagnostic_q08_rejects_harvest_fingerprint_drift(
    tmp_path: Path,
) -> None:
    target = tmp_path / "q08.jsonl"
    target.write_text("{}\n", encoding="utf-8")
    fingerprint = runner._stream_fingerprint(target)
    fingerprint["sha256"] = "0" * 64
    result = runner._ftmo_diagnostic_q08_plan(
        {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT},
        {"valid": True, "target": str(target), "harvested": fingerprint},
    )
    assert result["valid"] is False
    assert any("fingerprint mismatch" in error for error in result["errors"])


@pytest.mark.parametrize(
    ("limit_name", "limit", "payload", "expected_error"),
    [
        ("FTMO_DIAGNOSTIC_Q08_MAX_BYTES", 2, b"{}\n", "exceeds byte limit"),
        (
            "FTMO_DIAGNOSTIC_Q08_MAX_LINE_BYTES",
            3,
            b'{"event":"IGNORED"}\n',
            "line exceeds byte limit",
        ),
    ],
)
def test_ftmo_standalone_diagnostic_q08_enforces_preparse_size_limits(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    limit_name: str,
    limit: int,
    payload: bytes,
    expected_error: str,
) -> None:
    target = tmp_path / "q08.jsonl"
    target.write_bytes(payload)
    monkeypatch.setattr(runner, limit_name, limit)
    result = runner._ftmo_diagnostic_q08_plan(
        {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT},
        {
            "valid": True,
            "target": str(target),
            "harvested": runner._stream_fingerprint(target),
        },
    )
    assert result["valid"] is False
    assert any(expected_error in error for error in result["errors"])


def test_ftmo_standalone_diagnostic_q08_caps_closed_trade_rows(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    target = tmp_path / "q08.jsonl"
    row = {
        "event": "TRADE_CLOSED",
        "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        "magic": 131080000,
        "symbol": "XTIUSD.DWX",
        "side": "BUY",
        "entry_time": 100,
        "time": 200,
        "entry_price": 70.0,
        "exit_price": 71.0,
        "profit": 100.0,
        "swap": -1.0,
        "fee": 0.0,
        "entry_commission": -0.5,
        "exit_commission": -0.5,
        "commission": -1.0,
        "net": 98.0,
        "volume": 1.0,
        "mae_acct": -25.0,
    }
    target.write_text(
        json.dumps(row) + "\n" + json.dumps(row) + "\n", encoding="utf-8"
    )
    monkeypatch.setattr(runner, "FTMO_DIAGNOSTIC_Q08_MAX_CLOSED_ROWS", 1)
    result = runner._ftmo_diagnostic_q08_plan(
        {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT},
        {
            "valid": True,
            "target": str(target),
            "harvested": runner._stream_fingerprint(target),
        },
    )
    assert result["valid"] is False
    assert any("closed-trade row count exceeds" in error for error in result["errors"])


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


@pytest.mark.parametrize(("stage", "sequence"), [(0, 2), (1, 4)])
def test_fidelity_stage_receipt_is_required_and_hash_bound(
    tmp_path: Path, stage: int, sequence: int
) -> None:
    hashes = {
        role: f"{index + 1:064x}"
        for index, role in enumerate(runner.FTMO_RUNTIME_SOURCE_ROLES)
    }
    runtime_sources = [
        {
            "role": role,
            "path": str((tmp_path / "runtime" / role).resolve()),
            "sha256": value,
            "bytes": index + 100,
        }
        for index, (role, value) in enumerate(sorted(hashes.items()))
    ]
    payload = {
        "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
        "measurement_sequence": sequence,
        "required_fidelity_stage": stage,
        "authoritative_source_commit": "a" * 40,
        "framework_include_tree_sha256": "e" * 64,
        "execution_input_artifacts_sha256": "b" * 64,
        "runtime_source_artifacts": runtime_sources,
    }
    ladder = {
        "rungs": [
            {
                "rung": "R0",
                "id": "r0-id",
                "evidence_path": str((tmp_path / "standalone_evidence.json").resolve()),
            },
            {
                "rung": "J0",
                "id": "j0-id",
                "evidence_path": str((tmp_path / "joint_evidence.json").resolve()),
            },
            {
                "rung": "R1",
                "id": "r1-id",
                "evidence_path": str((tmp_path / "standalone_evidence.json").resolve()),
            },
            {
                "rung": "J1",
                "id": "j1-id",
                "evidence_path": str((tmp_path / "joint_evidence.json").resolve()),
            },
        ]
    }
    missing = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder,
        receipt_path=None,
        expected_receipt_sha256=None,
        expected_factory_off_sha256="f" * 64,
    )
    runtime_by_role = {row["role"]: row for row in runtime_sources}
    normalized_runtime_roles = {
        role: {
            "role": role,
            "path": row["path"],
            "sha256": row["sha256"],
            "bytes": row["bytes"],
        }
        for role, row in runtime_by_role.items()
    }
    source_binding = {
        "framework_include_tree": {
            "path": str((tmp_path / "framework" / "include" / "QM").resolve()),
            "sha256": "e" * 64,
            "file_count": 91,
        },
        **{
            direct: {
                "path": runtime_by_role[runtime_role]["path"],
                "sha256": runtime_by_role[runtime_role]["sha256"],
            }
            for direct, runtime_role in {
                "preregistration": "preregistration",
                "isolated_runner": "isolated_runner",
                "terminal_worker": "terminal_worker",
                "preparation_controller": "preparation_controller",
            }.items()
        },
        "runtime_sources": {
            "canonical_sha256": runner.canonical_sha256(
                sorted(
                    normalized_runtime_roles.values(),
                    key=lambda row: (row["role"], row["path"]),
                )
            ),
            "roles": normalized_runtime_roles,
        },
    }
    expected_ids = {
        "standalone": f"r{stage}-id",
        "joint": f"j{stage}-id",
    }

    def gate_operand(role: str) -> dict:
        member = runner.FTMO_BOOK3_FIDELITY_STAGE_MEMBERS[stage][role]
        runner_receipt = (tmp_path / f"{role}_runner_receipt.json").resolve()
        runner_receipt.write_text(
            json.dumps({"role": role, "stage": stage}) + "\n", encoding="utf-8"
        )
        evidence = (tmp_path / f"{role}_evidence.json").resolve()
        evidence.write_text(json.dumps({"verdict": "PASS"}) + "\n", encoding="utf-8")
        q08 = (tmp_path / f"{role}_q08.jsonl").resolve()
        q08.write_text(
            '{"event":"TRADE_CLOSED","trade":1}\n'
            '{"event":"TRADE_CLOSED","trade":2}\n',
            encoding="utf-8",
        )
        artifact_rows = {}
        for artifact_role in ("setfile", "staged_ex5", "mq5"):
            artifact_path = (tmp_path / role / artifact_role).resolve()
            artifact_path.parent.mkdir(parents=True, exist_ok=True)
            artifact_path.write_bytes(f"{role}:{artifact_role}\n".encode("utf-8"))
            artifact_rows[artifact_role] = {
                "path": str(artifact_path),
                "sha256": _sha(artifact_path),
            }
        started_hour = 10 if role == "standalone" else 12
        return {
            "role": role,
            "rung": member["rung"],
            "sequence": member["sequence"],
            "receipt_path": str(runner_receipt),
            "receipt_sha256": _sha(runner_receipt),
            "work_item_id": expected_ids[role],
            "started_at_utc": f"2026-07-29T{started_hour:02d}:00:00+00:00",
            "completed_at_utc": f"2026-07-29T{started_hour + 1:02d}:00:00+00:00",
            "source_commit": "a" * 40,
            "factory_off_sha256": "f" * 64,
            "source_binding": copy.deepcopy(source_binding),
            "runner_artifacts": artifact_rows,
            "execution_input_artifacts_sha256": "b" * 64,
            "execution_input_observed_bundle_sha256": "d" * 64,
            "execution_input_artifact_count": runner.FTMO_BOOK3_EXPECTED_EXECUTION_INPUT_COUNT,
            "post_payload_sha256": "c" * 64,
            "post_evidence": {
                "path": str(evidence),
                "resolved_path": str(evidence),
                "sha256": _sha(evidence),
                "bytes": evidence.stat().st_size,
            },
            "q08_trades": {
                "source": str((tmp_path / "common" / f"{role}.jsonl").resolve()),
                "target": str(q08),
                "path": str(q08),
                "sha256": _sha(q08),
                "bytes": q08.stat().st_size,
                "lines": 2,
                "selected_trade_count": 2,
            },
            "magic": member["magic"],
            "symbol": member["symbol"],
        }

    receipt = {
        "schema": "qm.ftmo-book3-fidelity-adjudication-receipt/v2",
        "generated_at_utc": "2026-07-29T12:00:00+00:00",
        "stage": stage,
        "verdict": "PASS",
        "errors": [],
        "work_item_ids": expected_ids,
        "source_commit": "a" * 40,
        "execution_input_artifacts_sha256": "b" * 64,
        "controller_path": runtime_by_role["fidelity_gate"]["path"],
        "controller_sha256": hashes["fidelity_gate"],
        "controller_bytes": runtime_by_role["fidelity_gate"]["bytes"],
        "isolated_runner_sha256": hashes["isolated_runner"],
        "preparation_controller_sha256": hashes["preparation_controller"],
        "comparator_sha256": hashes["fidelity_comparator"],
        "comparator": {
            "path": runtime_by_role["fidelity_comparator"]["path"],
            "sha256": hashes["fidelity_comparator"],
            "bytes": runtime_by_role["fidelity_comparator"]["bytes"],
        },
        "contract": {
            "measurement_contract": runner.FTMO_BOOK3_MEASUREMENT_CONTRACT,
            "expected_execution_input_count": (
                runner.FTMO_BOOK3_EXPECTED_EXECUTION_INPUT_COUNT
            ),
            "match_rate_required": 1.0,
            "unmatched_required": 0,
            "both_operands_nonempty": True,
            "money_tolerance": runner.FTMO_BOOK3_MONEY_TOLERANCE,
            "volume_tolerance": runner.FTMO_BOOK3_VOLUME_TOLERANCE,
            "price_tolerance": runner.FTMO_BOOK3_PRICE_TOLERANCE,
            "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
        },
        "safety": {
            "read_only_inputs": True,
            "create_only_output": True,
            "opens_factory_db": False,
            "runs_mt5": False,
            "mutates_factory_state": False,
            "touches_live_scope": False,
            "touches_autotrading": False,
        },
        "operands": {
            "standalone": gate_operand("standalone"),
            "joint": gate_operand("joint"),
        },
        "comparison": {
            "algorithm": runner.FTMO_BOOK3_FIDELITY_ALGORITHM,
            "money_basis": runner.FTMO_BOOK3_MONEY_BASIS,
            "money_tolerance": runner.FTMO_BOOK3_MONEY_TOLERANCE,
            "volume_tolerance": runner.FTMO_BOOK3_VOLUME_TOLERANCE,
            "price_tolerance": runner.FTMO_BOOK3_PRICE_TOLERANCE,
            "match_rate": 1.0,
            "unmatched_standalone": 0,
            "unmatched_joint": 0,
            "standalone_trades": 2,
            "joint_trades": 2,
            "matched": 2,
            "unmatched_standalone_sample": [],
            "unmatched_joint_sample": [],
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
    path = (tmp_path / f"stage{stage}.json").resolve()
    path.write_text(json.dumps(receipt, sort_keys=True) + "\n", encoding="utf-8")
    valid = runner._ftmo_fidelity_receipt_plan(
        payload,
        ladder_order=ladder,
        receipt_path=path,
        expected_receipt_sha256=_sha(path),
        expected_factory_off_sha256="f" * 64,
    )
    assert missing["valid"] is False
    assert valid["valid"] is True, valid["errors"]

    def validate_mutation(mutator) -> dict:
        candidate = copy.deepcopy(receipt)
        mutator(candidate)
        identity = {
            key: value
            for key, value in candidate.items()
            if key not in {"generated_at_utc", "adjudication_id"}
        }
        candidate["adjudication_id"] = hashlib.sha256(
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
        path.write_text(json.dumps(candidate, sort_keys=True) + "\n", encoding="utf-8")
        return runner._ftmo_fidelity_receipt_plan(
            payload,
            ladder_order=ladder,
            receipt_path=path,
            expected_receipt_sha256=_sha(path),
            expected_factory_off_sha256="f" * 64,
        )

    invalid_cases = (
        lambda candidate: candidate.__setitem__("verdict", "FAIL"),
        lambda candidate: candidate.pop("operands"),
        lambda candidate: candidate.__setitem__("unexpected", True),
        lambda candidate: candidate.__setitem__("stage", bool(stage)),
        lambda candidate: candidate["contract"].__setitem__(
            "expected_execution_input_count", 307.0
        ),
        lambda candidate: candidate["contract"].__setitem__(
            "both_operands_nonempty", 1
        ),
        lambda candidate: candidate["contract"].__setitem__(
            "money_tolerance", 0.006
        ),
        lambda candidate: candidate["comparison"].__setitem__(
            "algorithm", "count_only"
        ),
        lambda candidate: candidate["comparison"].__setitem__("matched", 1),
        lambda candidate: candidate["comparison"].__setitem__(
            "price_tolerance", 0.00001
        ),
        lambda candidate: candidate["comparison"].__setitem__(
            "unmatched_joint", 0.0
        ),
        lambda candidate: candidate["operands"]["standalone"].__setitem__(
            "role", "joint"
        ),
        lambda candidate: candidate["operands"]["standalone"].__setitem__(
            "execution_input_artifact_count", 307.0
        ),
        lambda candidate: candidate["operands"]["joint"]["q08_trades"].__setitem__(
            "selected_trade_count", 2.0
        ),
        lambda candidate: candidate["operands"]["standalone"]["post_evidence"].__setitem__(
            "bytes", None
        ),
        lambda candidate: candidate["operands"]["joint"]["q08_trades"].__setitem__(
            "bytes", True
        ),
        lambda candidate: candidate["operands"]["joint"]["q08_trades"].__setitem__(
            "lines", 2.0
        ),
        lambda candidate: candidate["operands"]["standalone"]["q08_trades"].__setitem__(
            "lines", 3
        ),
        lambda candidate: candidate["comparison"].__setitem__(
            "standalone_trades", 1
        ),
        lambda candidate: candidate["operands"]["joint"].__setitem__(
            "execution_input_observed_bundle_sha256", "8" * 64
        ),
        lambda candidate: [
            candidate["operands"][role].__setitem__(
                "factory_off_sha256", "0" * 64
            )
            for role in ("standalone", "joint")
        ],
        lambda candidate: candidate["operands"]["standalone"]["runner_artifacts"][
            "mq5"
        ].__setitem__("sha256", "7" * 64),
        lambda candidate: candidate["operands"]["joint"]["source_binding"][
            "runtime_sources"
        ]["roles"]["fidelity_gate"].__setitem__("sha256", "9" * 64),
    )
    for mutate in invalid_cases:
        assert validate_mutation(mutate)["valid"] is False


def test_stage1_standalone_magic_is_authoritative_literal() -> None:
    assert (
        runner.FTMO_BOOK3_FIDELITY_STAGE_MEMBERS[1]["standalone"]["magic"]
        == 101450034
    )


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
    temp_residue = list(target.parent.glob("*.tmp"))
    assert len(temp_residue) == 1
    assert os.path.samefile(temp_residue[0], target)


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


@pytest.mark.parametrize("same_bytes", [False, True])
def test_harvest_target_race_never_overwrites_or_deletes_incumbent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, same_bytes: bool
) -> None:
    source = tmp_path / "common" / "13301_GDAXI_DWX.jsonl"
    target = tmp_path / "evidence" / "q08_trades_13301_GDAXI_DWX.timer_v2.jsonl"
    source.parent.mkdir(parents=True)
    source.write_text('{"trade":0}\n', encoding="utf-8")
    pre = runner._stream_fingerprint(source)
    started_ns = int(pre["mtime_ns"])
    _rewrite_after_preflight(source, '{"trade":1}\n', started_ns)
    incumbent = source.read_bytes() if same_bytes else b'{"incumbent":true}\n'
    contract = {
        "requested": True,
        "valid": True,
        "source": str(source),
        "target": str(target),
        "pre_run_source": pre,
        "pre_v2_capture": {"sha256": "0" * 64},
    }
    real_link = os.link
    raced = False

    def race_target(source_path: str | os.PathLike, target_path: str | os.PathLike) -> None:
        nonlocal raced
        if Path(target_path) == target and not raced:
            raced = True
            target.write_bytes(incumbent)
        real_link(source_path, target_path)

    monkeypatch.setattr(runner.os, "link", race_target)
    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert raced is True
    assert target.read_bytes() == incumbent
    assert result["publication"]["published_targets"] == []


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
    temp_residue = list(report_root.glob("*.tmp"))
    assert len(temp_residue) == 2
    assert all(
        any(os.path.samefile(tmp, Path(item["target"])) for item in result["streams"])
        for tmp in temp_residue
    )


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


def test_atomic_two_stream_harvest_retains_residue_if_second_publish_fails(
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
    real_link = os.link

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            raise OSError("injected second-publish failure")
        real_link(source, target)

    monkeypatch.setattr(runner.os, "link", fail_equity_publish)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert any("injected second-publish failure" in error for error in result["errors"])
    existing = [
        Path(item["target"]) for item in result["streams"] if Path(item["target"]).exists()
    ]
    assert len(existing) == 1
    assert result["publication"]["rollback_attempted"] is False
    assert result["publication"]["rollback_complete"] is False
    assert result["publication"]["published_targets"] == [str(existing[0])]
    assert any("publication residue retained" in error for error in result["errors"])


def test_post_run_quiescence_never_terminates_foreign_factory_processes(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    foreign = [
        {"Name": "terminal64.exe", "ProcessId": 5, "ExecutablePath": r"C:\QM\mt5\T5\terminal64.exe"},
        {"Name": "terminal64.exe", "ProcessId": 6, "ExecutablePath": r"C:\QM\mt5\T_Live\terminal64.exe"},
        {"Name": "metatester64.exe", "ProcessId": 7, "ExecutablePath": r"C:\foreign\metatester64.exe"},
    ]
    monkeypatch.setattr(runner, "_factory_processes", lambda: foreign)
    monotonic = iter((0.0, 31.0))
    monkeypatch.setattr(runner.time, "monotonic", lambda: next(monotonic))
    assert not hasattr(runner, "_terminate_pid_tree")

    result = runner._post_run_quiescence()

    assert result["valid"] is False
    assert result["before"] == foreign
    assert result["after"] == foreign
    assert result["termination_actions"] == []
    assert result["foreign_process_policy"] == "OBSERVE_AND_FAIL_NEVER_TERMINATE"


def test_factory_process_census_includes_worker_and_smoke_without_mt5(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    scan = {
        "scanned_at": "2026-07-30T12:00:00.000Z",
        "worker_daemons": [{"process_class": "worker_daemon", "pid": 11}],
        "phase_runners": [],
        "smoke_wrappers": [{"process_class": "smoke_wrapper", "pid": 12}],
        "terminal64": [],
        "metatester64": [],
        "review_required": [],
    }
    monkeypatch.setattr(
        runner.subprocess,
        "run",
        lambda *_args, **_kwargs: subprocess.CompletedProcess(
            args=[], returncode=0, stdout=json.dumps(scan), stderr=""
        ),
    )
    found = runner._factory_processes()
    assert {(row["census_bucket"], row["pid"]) for row in found} == {
        ("worker_daemons", 11),
        ("smoke_wrappers", 12),
    }


def test_diagnostic_output_paths_are_absolute_governed_and_not_source_aliases(
    tmp_path: Path,
) -> None:
    allowed = (tmp_path / "artifacts").resolve()
    allowed.mkdir()
    paths = {
        "snapshot_path": allowed / "run" / "before.sqlite",
        "receipt_path": allowed / "run" / "receipt.json",
        "worker_log_path": allowed / "run" / "worker.log",
    }
    runner._validate_diagnostic_output_paths(
        **paths,
        protected_paths=[],
        allowed_roots=(allowed,),
    )
    with pytest.raises(RuntimeError, match="must be absolute"):
        runner._validate_diagnostic_output_paths(
            snapshot_path=Path("relative.sqlite"),
            receipt_path=paths["receipt_path"],
            worker_log_path=paths["worker_log_path"],
            protected_paths=[],
            allowed_roots=(allowed,),
        )
    with pytest.raises(RuntimeError, match="outside governed"):
        runner._validate_diagnostic_output_paths(
            snapshot_path=(tmp_path / "outside.sqlite").resolve(),
            receipt_path=paths["receipt_path"],
            worker_log_path=paths["worker_log_path"],
            protected_paths=[],
            allowed_roots=(allowed,),
        )
    protected = allowed / "run" / "protected.sqlite"
    with pytest.raises(RuntimeError, match="aliases a governed source"):
        runner._validate_diagnostic_output_paths(
            snapshot_path=protected,
            receipt_path=paths["receipt_path"],
            worker_log_path=paths["worker_log_path"],
            protected_paths=[protected],
            allowed_roots=(allowed,),
        )


def test_partial_output_reservation_leaves_audit_residue_without_unlink_aba(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    snapshot = (tmp_path / "before.sqlite").resolve()
    receipt = (tmp_path / "receipt.json").resolve()
    worker_log = (tmp_path / "worker.log").resolve()
    original_fsync = runner._fsync_file
    calls = 0

    def inject_collision(handle: object) -> None:
        nonlocal calls
        original_fsync(handle)
        calls += 1
        if calls == 1:
            worker_log.write_bytes(b"incumbent")

    monkeypatch.setattr(runner, "_fsync_file", inject_collision)
    with pytest.raises(FileExistsError):
        runner._reserve_execution_outputs(
            snapshot_path=snapshot,
            receipt_path=receipt,
            worker_log_path=worker_log,
            intent={"mode": "test"},
        )
    assert snapshot.is_file() and snapshot.stat().st_size == 0
    assert worker_log.read_bytes() == b"incumbent"


def test_snapshot_and_worker_log_replacements_are_rejected_without_deletion(
    tmp_path: Path,
) -> None:
    snapshot = (tmp_path / "before.sqlite").resolve()
    receipt = (tmp_path / "receipt.json").resolve()
    worker_log = (tmp_path / "worker.log").resolve()
    reservation = runner._reserve_execution_outputs(
        snapshot_path=snapshot,
        receipt_path=receipt,
        worker_log_path=worker_log,
        intent={"mode": "test"},
    )
    snapshot.unlink()
    snapshot.write_bytes(b"attacker-snapshot")
    source = tmp_path / "source.sqlite"
    with sqlite3.connect(source) as conn:
        conn.execute("CREATE TABLE t(value INTEGER)")
    with pytest.raises(RuntimeError, match="reservation is missing or changed"):
        runner.sqlite_snapshot(
            source,
            snapshot,
            reserved=True,
            reservation_identity=reservation["snapshot_identity"],
        )
    assert snapshot.read_bytes() == b"attacker-snapshot"

    worker_log.unlink()
    worker_log.write_bytes(b"attacker-log")
    assert not runner._reserved_file_matches(
        worker_log, reservation["worker_log_identity"], require_empty=True
    )
    assert worker_log.read_bytes() == b"attacker-log"


def test_windows_worker_containment_closes_only_retained_job_handle(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    class FakeProcess:
        pid = 4242

        def __init__(self) -> None:
            self.ended = False

        def poll(self) -> int | None:
            return 0 if self.ended else None

        def wait(self, timeout: int | None = None) -> int:
            assert timeout == 30
            self.ended = True
            return 0

    process = FakeProcess()
    calls: list[tuple[int, str]] = []

    def abort(pid: int, creation_key: str) -> bool:
        calls.append((pid, creation_key))
        process.ended = True
        return True

    monkeypatch.setattr(runner.sys, "platform", "win32")
    monkeypatch.setattr(runner.GLOBAL_JOB_REGISTRY, "abort_retained", abort)
    monkeypatch.setattr(runner, "reap_finished_job_objects", lambda: 0)
    result = runner._contain_worker_process_tree(
        process,  # type: ignore[arg-type]
        {
            "process_creation_key": "windows-filetime:123",
            "job_object_registry_key": "4242|windows-filetime:123",
            "job_object_assigned": True,
        },
    )
    assert result["valid"] is True
    assert calls == [(4242, "windows-filetime:123")]
    assert result["actions"][0]["mode"] == "retained_job_handle_close"


def test_diagnostic_hold_is_revalidated_exactly_after_worker(tmp_path: Path) -> None:
    _root, _repo, db, _payload = _seed(tmp_path)
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        conn.execute(
            "UPDATE work_item_holds SET hold_code=?,reason=?,active=1,"
            "release_on_restart=0,released_at=NULL,release_note=NULL WHERE work_item_id='target'",
            (
                runner.FTMO_BOOK3_DIAGNOSTIC_HOLD_CODE,
                runner.FTMO_BOOK3_DIAGNOSTIC_HOLD_REASON,
            ),
        )
        prior = dict(
            conn.execute(
                "SELECT * FROM work_item_holds WHERE work_item_id='target'"
            ).fetchone()
        )
    preflight = {
        "work_item": {"measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT},
        "hold": prior,
    }
    accepted = runner._revalidate_diagnostic_hold(
        preflight, db=db, work_item_id="target"
    )
    assert accepted["valid"] is True
    with sqlite3.connect(db) as conn:
        conn.execute(
            "UPDATE work_item_holds SET release_on_restart=1 WHERE work_item_id='target'"
        )
    rejected = runner._revalidate_diagnostic_hold(
        preflight, db=db, work_item_id="target"
    )
    assert rejected["valid"] is False
    assert any("release_on_restart mismatch" in error for error in rejected["errors"])


def test_reserved_receipt_publish_never_overwrites_racing_incumbent(
    tmp_path: Path,
) -> None:
    receipt = (tmp_path / "receipt.json").resolve()
    reservation = runner._reserve_receipt_output(
        receipt, intent={"mode": "test"}
    )
    incumbent = b'{"incumbent":true}\n'
    receipt.write_bytes(incumbent)

    with pytest.raises(RuntimeError, match="incumbent was not overwritten"):
        runner._publish_reserved_receipt(
            receipt,
            reservation_id=reservation["reservation_id"],
            reservation_identity=reservation["reservation_identity"],
            payload={"mode": "completed"},
        )

    assert receipt.read_bytes() == incumbent
    assert runner._receipt_reservation_path(receipt).is_file()


def test_receipt_publisher_rejects_reservation_and_link_substitution(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    receipt = (tmp_path / "receipt.json").resolve()
    reservation = runner._reserve_receipt_output(receipt, intent={"mode": "test"})
    reservation_path = runner._receipt_reservation_path(receipt)
    original = json.loads(reservation_path.read_text(encoding="utf-8"))
    reservation_path.unlink()
    reservation_path.write_text(json.dumps(original) + "\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="reservation file identity changed"):
        runner._publish_reserved_receipt(
            receipt,
            reservation_id=reservation["reservation_id"],
            reservation_identity=reservation["reservation_identity"],
            payload={"mode": "completed"},
        )
    assert not receipt.exists()

    receipt2 = (tmp_path / "receipt2.json").resolve()
    reservation2 = runner._reserve_receipt_output(receipt2, intent={"mode": "test"})
    attacker = b'{"attacker":true}\n'

    def substitute_link(_source: object, target: object) -> None:
        Path(target).write_bytes(attacker)

    monkeypatch.setattr(runner.os, "link", substitute_link)
    with pytest.raises(RuntimeError, match="not the linked temp object"):
        runner._publish_reserved_receipt(
            receipt2,
            reservation_id=reservation2["reservation_id"],
            reservation_identity=reservation2["reservation_identity"],
            payload={"mode": "completed"},
        )
    assert receipt2.read_bytes() == attacker


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
    real_link = os.link

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_trades_"):
            raise OSError("injected recovery-eligible publication failure")
        real_link(source, target)

    monkeypatch.setattr(runner.os, "link", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    assert failed["valid"] is False
    monkeypatch.setattr(runner.os, "link", real_link)
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

    recovery_receipt = (tmp_path / "recovery_receipt.json").resolve()
    incumbent = b'{"incumbent":true}\n'
    recovery_receipt.write_bytes(incumbent)
    with pytest.raises(FileExistsError, match="recovery receipt target already exists"):
        runner.recover_harvest_from_receipt(
            root,
            source_receipt_path=source_receipt,
            expected_source_receipt_sha256=runner.sha256_file(source_receipt),
            recovery_receipt_path=recovery_receipt,
        )
    assert recovery_receipt.read_bytes() == incumbent
    assert not any(Path(item["target"]).exists() for item in failed["streams"])
    recovery_receipt.unlink()

    result = runner.recover_harvest_from_receipt(
        root,
        source_receipt_path=source_receipt,
        expected_source_receipt_sha256=runner.sha256_file(source_receipt),
        recovery_receipt_path=recovery_receipt,
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
    real_link = os.link

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_trades_"):
            raise OSError("injected publication failure")
        real_link(source, target)

    monkeypatch.setattr(runner.os, "link", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    assert failed["valid"] is False
    monkeypatch.setattr(runner.os, "link", real_link)
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


def test_standalone_diagnostic_harvest_recovery_is_strictly_forbidden(
    tmp_path: Path,
) -> None:
    root, _repo, _db, _payload = _seed(tmp_path)
    source_receipt = tmp_path / "diagnostic_failed_receipt.json"
    source_receipt.write_text(
        json.dumps(
            {
                "mode": "apply",
                "worker_exit_code": 0,
                "post_work_item": {
                    "id": "diagnostic",
                    "status": "done",
                    "verdict": "PASS",
                },
                "preflight": {
                    "work_item": {
                        "measurement_contract": runner.FTMO_BOOK3_DIAGNOSTIC_CONTRACT
                    },
                    "post_run_stream": {},
                },
                "post_run_stream": {"requested": True, "valid": False},
            }
        )
        + "\n",
        encoding="utf-8",
    )
    with pytest.raises(RuntimeError, match="diagnostic harvest recovery is forbidden"):
        runner.recover_harvest_from_receipt(
            root,
            source_receipt_path=source_receipt,
            expected_source_receipt_sha256=runner.sha256_file(source_receipt),
            recovery_receipt_path=(tmp_path / "recovery.json").resolve(),
        )
    assert not (tmp_path / "recovery.json").exists()


def test_atomic_two_stream_harvest_retains_residue_on_baseexception(
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
    real_link = os.link

    class InjectedPublicationAbort(BaseException):
        pass

    def abort_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_equity_"):
            # Model an interrupt delivered after the OS completed link but
            # before the Python call returned to append bookkeeping.
            real_link(source, target)
            raise InjectedPublicationAbort("injected BaseException")
        real_link(source, target)

    monkeypatch.setattr(runner.os, "link", abort_equity_publish)

    result = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )

    assert result["valid"] is False
    assert any("InjectedPublicationAbort" in error for error in result["errors"])
    assert all(Path(item["target"]).exists() for item in result["streams"])
    assert result["publication"]["physically_atomic_across_targets"] is False
    assert result["publication"]["rollback_attempted"] is False
    assert result["publication"]["rollback_complete"] is False
    assert len(result["publication"]["published_targets"]) == 2


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
    real_link = os.link

    def fail_equity_publish(source: str | os.PathLike, target: str | os.PathLike) -> None:
        if Path(target).name.startswith("q08_trades_"):
            raise OSError("make receipt recovery-eligible")
        real_link(source, target)

    monkeypatch.setattr(runner.os, "link", fail_equity_publish)
    failed = runner._harvest_post_run_stream(
        contract, worker_started_wall_ns=started_ns
    )
    monkeypatch.setattr(runner.os, "link", real_link)
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
