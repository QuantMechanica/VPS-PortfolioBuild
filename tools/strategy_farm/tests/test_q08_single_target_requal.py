from __future__ import annotations

import json
import sqlite3
from pathlib import Path
from typing import Any

import pytest

from tools.strategy_farm import q08_single_target_requal as requal


def _binding(path: Path, role: str) -> dict[str, Any]:
    return {
        "role": role,
        "path": str(path.resolve()),
        "sha256": requal.sha256_file(path),
        "bytes": path.stat().st_size,
    }


def _write(path: Path, content: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def _create_database(
    path: Path,
    *,
    payload: str,
    setfile: Path,
    evidence: Path,
    active_rows: int = 0,
) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, kind TEXT NOT NULL, phase TEXT NOT NULL,
          ea_id TEXT NOT NULL, symbol TEXT NOT NULL, setfile_path TEXT NOT NULL,
          status TEXT NOT NULL, verdict TEXT, attempt_count INTEGER NOT NULL,
          parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
          payload_json TEXT NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL
        );
        CREATE TABLE events(
          id INTEGER PRIMARY KEY, ts TEXT NOT NULL, entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL, event TEXT NOT NULL, detail_json TEXT NOT NULL
        );
        """
    )
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            requal.AUTHORIZED_TARGET["work_item_id"],
            "backtest",
            "Q08",
            "QM5_10582",
            "XAUUSD.DWX",
            str(setfile.resolve()),
            "done",
            "INFRA_FAIL",
            0,
            None,
            str(evidence.resolve()),
            None,
            payload,
            "2026-07-26T04:13:22Z",
            "2026-07-27T04:36:23Z",
        ),
    )
    for index in range(active_rows):
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                f"active-{index}",
                "backtest",
                "Q02",
                "QM5_1",
                "EURUSD.DWX",
                str(setfile.resolve()),
                "active",
                None,
                0,
                None,
                None,
                "T1",
                "{}",
                "2026-07-31T00:00:00Z",
                "2026-07-31T00:00:00Z",
            ),
        )
    conn.commit()
    conn.close()


def _git_ok(*_args: object, **_kwargs: object) -> dict[str, Any]:
    return {
        "head_commit": "a" * 40,
        "parser_fix_commit": requal.PARSER_FIX_COMMIT,
        "parser_file_sha256_at_fix_commit": "b" * 64,
        "source_scope_clean": True,
        "reviewed_controller_commit": "a" * 40,
    }


def _fixture(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    create_report: bool = True,
    parser_failure: bool = False,
    factory_off: bool = True,
    active_rows: int = 0,
    review_status: str = "APPROVED",
) -> dict[str, Any]:
    repo = tmp_path / "repo"
    reports = tmp_path / "reports" / "work_items"
    archive = reports / "_requal_archive"
    state = tmp_path / "state"
    repo.mkdir(parents=True)
    state.mkdir(parents=True)
    decision_source = _write(
        repo / requal.OWNER_DECISION_RELATIVE_PATH,
        "OWNER approves exact fixture target\n",
    )
    monkeypatch.setattr(
        requal, "OWNER_DECISION_SHA256", requal.sha256_file(decision_source)
    )

    parser_source = _write(
        repo / "framework" / "scripts" / "q08_5_neighborhood_runner.py",
        """
def parse_setfile_assignments(path):
    text = path.read_text(encoding='utf-8')
    if 'DUPLICATE' in text:
        raise ValueError('duplicate strategy parameter strategy_x')
    return {'strategy_x': {'value': 1}}
""".lstrip(),
    )
    mq5 = _write(repo / "ea" / "target.mq5", "// source\n")
    ex5 = _write(repo / "ea" / "target.ex5", "compiled\n")
    setfiles: dict[str, Path] = {}
    for role in requal.SETFILE_ROLES:
        content = "DUPLICATE\n" if parser_failure and role == "setfile_ablation_01" else f"{role}\n"
        setfiles[role] = _write(repo / "ea" / f"{role}.set", content)
    monkeypatch.setattr(
        requal,
        "TARGET_SETFILE_SHA256",
        {role: requal.sha256_file(path) for role, path in setfiles.items()},
    )

    report_root = reports / requal.AUTHORIZED_TARGET["work_item_id"]
    evidence = report_root / "QM5_10582" / "Q08" / "XAUUSD_DWX" / "aggregate.json"
    if create_report:
        _write(evidence, '{"status":"INVALID"}\n')
    payload = json.dumps(
        {
            "verdict_reason": "q08_8.5_neighborhood:baseline_setfile_defect:empty_strategy_params",
            "pid": 123,
            "terminal": "T7",
        },
        sort_keys=True,
    )
    db = state / "farm_state.sqlite"
    _create_database(
        db,
        payload=payload,
        setfile=setfiles["setfile_ablation_00"],
        evidence=evidence,
        active_rows=active_rows,
    )
    flag = state / "FACTORY_OFF.flag"
    if factory_off:
        _write(flag, "OWNER maintenance\n")
    receipt = _write(repo / "review.json", '{"verdict":"APPROVED"}\n')
    artifacts = [
        _binding(Path(requal.__file__), "controller_source"),
        _binding(parser_source, "parser_source"),
        _binding(mq5, "mq5"),
        _binding(ex5, "ex5"),
        *[_binding(setfiles[role], role) for role in requal.SETFILE_ROLES],
    ]
    review: dict[str, Any]
    if review_status == "APPROVED":
        review = {
            "status": "APPROVED",
            "reviewer": "Claude",
            "verdict": "APPROVED",
            "reviewed_controller_commit": "a" * 40,
            "receipt": {
                "path": str(receipt.resolve()),
                "sha256": requal.sha256_file(receipt),
            },
        }
    else:
        review = {"status": "PENDING", "reviewer": "Claude", "verdict": None}
    contract = {
        "schema_version": requal.CONTRACT_SCHEMA,
        "authorization": {
            "authority": "OWNER",
            "owner_reference": requal.OWNER_REFERENCE,
            "decision_date": "2026-07-31",
            "scope": "EXACT_ONE_ROW_Q08_REQUALIFICATION_CONTROLLER",
            "global_invariant": requal.GLOBAL_INVARIANT,
            "global_invariant_weakened": False,
            "decision_source": {
                "path": str(decision_source.resolve()),
                "sha256": requal.sha256_file(decision_source),
                "commit_sha": requal.OWNER_DECISION_COMMIT,
            },
        },
        "target": {
            **requal.AUTHORIZED_TARGET,
            "setfile_path": str(setfiles["setfile_ablation_00"].resolve()),
            "reason_class": requal.REASON_CLASS,
            "expected_state": {
                "status": "done",
                "phase": "Q08",
                "verdict": "INFRA_FAIL",
                "payload_sha256": requal.payload_sha256(payload),
            },
        },
        "parser_fix": {
            "defect_class": "STRATEGY_LINES_WITHOUT_SECTION_MARKER",
            "commit_sha": requal.PARSER_FIX_COMMIT,
            "file_sha256_at_fix_commit": requal.sha256_file(parser_source),
        },
        "artifact_bindings": artifacts,
        "evidence_archive": {
            "policy": "MOVE_WHOLE_WORK_ITEM_ROOT_NO_DELETE_NO_OVERWRITE",
            "root": str(archive.resolve()),
        },
        "implementation_review": review,
    }
    contract_path = tmp_path / "exception.json"
    contract_path.write_text(json.dumps(contract, indent=2) + "\n", encoding="utf-8")
    loaded, contract_sha = requal.load_json_strict(contract_path, "fixture")
    paths = requal.RuntimePaths(
        db=db,
        repo=repo,
        reports_root=reports,
        archive_root=archive,
        factory_off_flag=flag,
        mutation_lock=state / "FACTORY_MUTATION.lock",
    )
    return {
        "contract": loaded,
        "contract_path": contract_path,
        "contract_sha": contract_sha,
        "paths": paths,
        "payload": payload,
        "report_root": report_root,
        "evidence": evidence,
        "flag_sha": requal.sha256_file(flag) if flag.exists() else None,
        "db": db,
    }


def _plan(fixture: dict[str, Any]) -> dict[str, Any]:
    return requal.build_plan(
        fixture["contract"],
        fixture["contract_path"],
        fixture["contract_sha"],
        fixture["paths"],
        git_verifier=_git_ok,
    )


def test_dry_run_ready_is_one_row_and_non_mutating(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    before = fixture["db"].read_bytes()
    plan = _plan(fixture)
    after = fixture["db"].read_bytes()
    assert plan["status"] == "READY_FOR_APPLY"
    assert plan["target"] == requal.AUTHORIZED_TARGET
    assert plan["mutation_performed"] is False
    assert before == after


def test_cas_payload_sha_mismatch_blocks(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    conn = sqlite3.connect(fixture["db"])
    conn.execute(
        "UPDATE work_items SET payload_json=? WHERE id=?",
        ('{"drifted":true}', requal.AUTHORIZED_TARGET["work_item_id"]),
    )
    conn.commit()
    conn.close()
    plan = _plan(fixture)
    assert plan["status"] == "BLOCKED"
    assert any("payload_sha256" in item for item in plan["gates"]["row_cas"]["mismatches"])


def test_missing_invalid_archive_source_blocks(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch, create_report=False)
    plan = _plan(fixture)
    assert plan["gates"]["archive_required"]["status"] == "BLOCKED"
    assert any("source report root missing" in item for item in plan["blockers"])


def test_parser_gate_requires_nonzero_all_four_setfiles(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch, parser_failure=True)
    plan = _plan(fixture)
    gate = plan["gates"]["parser_all_four_setfiles"]
    assert gate["status"] == "BLOCKED"
    assert sum(row["assignment_count"] > 0 for row in gate["setfiles"]) == 3
    assert "duplicate strategy parameter" in gate["blockers"][0]


@pytest.mark.parametrize(
    ("factory_off", "active_rows", "expected"),
    ((False, 0, "FACTORY_OFF flag missing"), (True, 1, "active work-item count is 1")),
)
def test_apply_window_gate_refuses_factory_on_or_active_rows(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    factory_off: bool,
    active_rows: int,
    expected: str,
) -> None:
    fixture = _fixture(
        tmp_path,
        monkeypatch,
        factory_off=factory_off,
        active_rows=active_rows,
    )
    plan = _plan(fixture)
    assert plan["gates"]["apply_window"]["status"] == "BLOCKED"
    assert any(expected in blocker for blocker in plan["blockers"])


def test_apply_refuses_pending_implementation_review(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch, review_status="PENDING")
    with pytest.raises(requal.RequalError, match="implementation_review"):
        requal.apply_contract(
            fixture["contract"],
            fixture["contract_path"],
            fixture["contract_sha"],
            fixture["contract_sha"],
            fixture["flag_sha"],
            tmp_path / "journal.json",
            fixture["paths"],
            git_verifier=_git_ok,
        )


def test_apply_archives_then_guarded_revert_restores_exact_state(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    journal_path = tmp_path / "state" / "journal.json"
    applied = requal.apply_contract(
        fixture["contract"],
        fixture["contract_path"],
        fixture["contract_sha"],
        fixture["contract_sha"],
        fixture["flag_sha"],
        journal_path,
        fixture["paths"],
        git_verifier=_git_ok,
    )
    archive = Path(applied["archive_destination"])
    assert applied["status"] == "APPLIED"
    assert not fixture["report_root"].exists()
    assert archive.is_dir()
    conn = sqlite3.connect(fixture["db"])
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (requal.AUTHORIZED_TARGET["work_item_id"],)
    ).fetchone()
    assert row["status"] == "pending"
    assert row["verdict"] is None
    post_payload = json.loads(row["payload_json"])
    assert post_payload["q08_single_target_requalification"]["setfile_bytes_unchanged"] is True
    assert "pid" not in post_payload and "terminal" not in post_payload
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1
    conn.close()

    reverted = requal.revert_journal(
        journal_path,
        applied["journal_sha256"],
        fixture["flag_sha"],
        fixture["paths"],
    )
    assert reverted["status"] == "REVERTED"
    assert fixture["report_root"].is_dir()
    assert not archive.exists()
    conn = sqlite3.connect(fixture["db"])
    conn.row_factory = sqlite3.Row
    row = conn.execute(
        "SELECT * FROM work_items WHERE id=?", (requal.AUTHORIZED_TARGET["work_item_id"],)
    ).fetchone()
    assert row["status"] == "done"
    assert row["verdict"] == "INFRA_FAIL"
    assert row["payload_json"] == fixture["payload"]
    assert conn.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 2
    conn.close()


def test_guarded_revert_refuses_drifted_post_state(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    journal_path = tmp_path / "state" / "journal.json"
    applied = requal.apply_contract(
        fixture["contract"],
        fixture["contract_path"],
        fixture["contract_sha"],
        fixture["contract_sha"],
        fixture["flag_sha"],
        journal_path,
        fixture["paths"],
        git_verifier=_git_ok,
    )
    conn = sqlite3.connect(fixture["db"])
    conn.execute(
        "UPDATE work_items SET claimed_by='T1' WHERE id=?",
        (requal.AUTHORIZED_TARGET["work_item_id"],),
    )
    conn.commit()
    conn.close()
    with pytest.raises(requal.RequalError, match="row drifted"):
        requal.revert_journal(
            journal_path,
            applied["journal_sha256"],
            fixture["flag_sha"],
            fixture["paths"],
        )
    assert Path(applied["archive_destination"]).is_dir()
    assert not fixture["report_root"].exists()


def test_contract_cannot_expand_to_another_target(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    fixture = _fixture(tmp_path, monkeypatch)
    fixture["contract"]["target"]["work_item_id"] = "other"
    with pytest.raises(requal.RequalError, match="outside OWNER authorization"):
        requal.validate_contract(fixture["contract"], fixture["paths"])
