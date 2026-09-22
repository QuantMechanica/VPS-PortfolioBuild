"""Agent-task Q01 successor admission stays receipted and fail-closed."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.strategy_farm import farmctl
from tools.strategy_farm.setfile_build_hash import PENDING_BUILD_HASH_LINE


EA_ID = "QM5_90002"
EA_NUMERIC = "90002"
SYMBOL = "EURUSD.DWX"
BUILD_TASK_ID = "11111111-2222-4333-8444-555555555555"
COMPILE_WORK_ITEM_ID = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _generated_setfile() -> bytes:
    lines = [
        ";==========================================================",
        "; QM5 Set File",
        "; ea_id:        90002",
        "; ea_slug:      agent-task-q01-fixture",
        "; ea_version:   v5.0",
        "; set_version:  s1",
        f"; symbol:       {SYMBOL}",
        "; timeframe:    H1",
        "; environment:  backtest",
        "; magic_slot:   0",
        "; risk_mode:    FIXED",
        "; portfolio_weight: 1",
        PENDING_BUILD_HASH_LINE,
        "; author:       Development",
        "; date:         2026-09-22",
        ";==========================================================",
        "qm_ea_id=90002",
        "qm_magic_slot_offset=0",
        "RISK_FIXED=1000",
        "RISK_PERCENT=0",
        "PORTFOLIO_WEIGHT=1",
        "strategy_period=14",
    ]
    return ("\n".join(lines) + "\n").encode("utf-8")


def _ex5_restamp(generated: bytes, ex5_sha: str) -> bytes:
    lines = generated.decode("utf-8").splitlines()
    lines[lines.index(PENDING_BUILD_HASH_LINE)] = f"; build_hash:   {ex5_sha}"
    return ("\n".join(lines) + "\n").encode("utf-8")


def _seed(tmp_path: Path) -> tuple[Path, dict[str, object]]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    ea_dir = tmp_path / "repo" / "framework" / "EAs" / f"{EA_ID}_agent-task-q01-fixture"
    set_dir = ea_dir / "sets"
    set_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{EA_ID}_agent-task-q01-fixture.mq5"
    ex5 = ea_dir / f"{EA_ID}_agent-task-q01-fixture.ex5"
    setfile = set_dir / f"{EA_ID}_agent-task-q01-fixture_{SYMBOL}_H1_backtest.set"
    mq5.write_bytes(b"// source\n")
    ex5.write_bytes(b"\x00authenticated binary\x01")
    generated = _generated_setfile()
    setfile.write_bytes(_ex5_restamp(generated, _sha(ex5.read_bytes())))

    evidence_dir = (
        root
        / "reports"
        / "work_items"
        / COMPILE_WORK_ITEM_ID
        / EA_ID
        / "COMPILE_EA"
    )
    evidence_dir.mkdir(parents=True)
    evidence_path = evidence_dir / "compile_evidence.json"
    evidence = {
        "ea_id": EA_ID,
        "mq5_path": str(mq5),
        "ex5_path": str(ex5),
        "mq5_sha256": _sha(mq5.read_bytes()),
        "ex5_sha256": _sha(ex5.read_bytes()),
        "success": True,
        "compile_result": "PASS",
        "build_check_result": "PASS",
        "setfile_generation": [
            {
                "symbol": SYMBOL,
                "setfile_path": str(setfile),
                "setfile_sha256": _sha(generated),
                "setfile_exists": True,
                "exit_code": 0,
            }
        ],
    }
    evidence_path.write_text(
        json.dumps(evidence, indent=2, sort_keys=True), encoding="utf-8"
    )

    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,evidence_path,payload_json,created_at,updated_at,
                mq5_sha256,ex5_sha256
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                COMPILE_WORK_ITEM_ID,
                "compile",
                "COMPILE_EA",
                EA_ID,
                "",
                "",
                "done",
                "COMPILE_OK",
                0,
                str(evidence_path),
                "{}",
                now,
                now,
                evidence["mq5_sha256"],
                evidence["ex5_sha256"],
            ),
        )
        conn.executescript(
            """
            CREATE TABLE agent_tasks (
                id TEXT PRIMARY KEY,
                task_type TEXT NOT NULL,
                state TEXT NOT NULL,
                priority INTEGER NOT NULL DEFAULT 50,
                required_capabilities_json TEXT NOT NULL,
                required_skills_json TEXT NOT NULL DEFAULT '[]',
                assigned_agent TEXT,
                budget_class TEXT NOT NULL DEFAULT 'standard',
                parent_id TEXT,
                artifact_path TEXT,
                verdict TEXT,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        conn.execute(
            """
            INSERT INTO agent_tasks(
                id,task_type,state,priority,required_capabilities_json,
                required_skills_json,assigned_agent,budget_class,parent_id,
                artifact_path,verdict,payload_json,created_at,updated_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """,
            (
                BUILD_TASK_ID,
                "build_ea",
                "TODO",
                50,
                "[]",
                "[]",
                "codex",
                "standard",
                None,
                str(evidence_path),
                "compiled",
                json.dumps({"ea_id": EA_NUMERIC, "source": "fixture"}),
                now,
                now,
            ),
        )
        conn.commit()

    dispatch = farmctl.append_q01_smoke_work_item(
        root,
        ea_id=EA_ID,
        symbol=SYMBOL,
        build_task_id=BUILD_TASK_ID,
        compile_evidence_path=str(evidence_path),
        from_date="2019.01.01",
        to_date="2019.12.31",
    )
    assert dispatch["appended"] is True, dispatch
    smoke_evidence = root / "reports" / dispatch["work_item_id"] / "summary.json"
    smoke_evidence.parent.mkdir(parents=True)
    smoke_evidence.write_text('{"result":"PASS"}\n', encoding="utf-8")
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            UPDATE work_items
            SET status='done',verdict='PASS',evidence_path=?,updated_at=?
            WHERE id=?
            """,
            (str(smoke_evidence), farmctl.utc_now(), dispatch["work_item_id"]),
        )
        conn.commit()
    return root, {
        "mq5": mq5,
        "ex5": ex5,
        "setfile": setfile,
        "evidence_path": evidence_path,
        "smoke_work_item_id": dispatch["work_item_id"],
        "setfile_binding_receipt": Path(dispatch["setfile_binding_receipt_path"]),
    }


def test_agent_task_successor_dry_run_writes_nothing(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    with farmctl.connect(root) as conn:
        before = conn.execute(
            "SELECT payload_json FROM agent_tasks WHERE id=?", (BUILD_TASK_ID,)
        ).fetchone()[0]
    result = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"]), dry_run=True
    )
    assert result["would_record"] is True, result
    assert result["build_task_kind"] == "agent_tasks"
    assert not Path(result["admission_receipt_path"]).exists()
    with farmctl.connect(root) as conn:
        after = conn.execute(
            "SELECT payload_json FROM agent_tasks WHERE id=?", (BUILD_TASK_ID,)
        ).fetchone()[0]
        assert conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0] == 0
    assert after == before


def test_agent_task_successor_records_receipt_and_flips_admission(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    result = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"])
    )
    assert result["recorded"] is True, result
    assert result["latest_smoke_result_after"] == "passed"
    assert result["q01_smoke_admission_after"]["admitted"] is True
    receipt_path = Path(result["admission_receipt_path"])
    assert receipt_path.is_file()
    assert _sha(receipt_path.read_bytes()) == result["admission_receipt_sha256"]

    with farmctl.connect(root) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM agent_tasks WHERE id=?", (BUILD_TASK_ID,)
            ).fetchone()[0]
        )
        latest = farmctl._latest_build_smoke_result(conn, EA_ID)
        assert conn.execute("SELECT COUNT(*) FROM tasks").fetchone()[0] == 0
    successor = payload["q01_smoke_successor"]
    assert successor["schema"] == farmctl.Q01_AGENT_TASK_SUCCESSOR_VERSION
    assert successor["smoke_result"] == "passed"
    assert successor["admission_receipt_sha256"] == result["admission_receipt_sha256"]
    assert latest["build_task_kind"] == "agent_tasks"
    assert farmctl._q01_smoke_admission(latest)["admitted"] is True


def test_agent_task_successor_is_idempotent(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    first = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"])
    )
    second = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"])
    )
    assert first["recorded"] is True
    assert second["already_recorded"] is True, second
    with farmctl.connect(root) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event=?",
            ("q01_agent_task_smoke_successor_recorded",),
        ).fetchone()[0] == 1


def test_agent_task_successor_refuses_tampered_dispatch_receipt(tmp_path: Path) -> None:
    root, art = _seed(tmp_path)
    Path(art["setfile_binding_receipt"]).write_text("{}\n", encoding="utf-8")
    result = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"]), dry_run=True
    )
    assert result["recorded"] is False
    assert result["reason"] == "setfile_binding_receipt_hash_mismatch"


def test_latest_agent_successor_fails_closed_if_admission_receipt_drifts(
    tmp_path: Path,
) -> None:
    root, art = _seed(tmp_path)
    result = farmctl.record_q01_smoke_successor(
        root, BUILD_TASK_ID, str(art["smoke_work_item_id"])
    )
    Path(result["admission_receipt_path"]).write_text("{}\n", encoding="utf-8")
    with farmctl.connect(root) as conn:
        latest = farmctl._latest_build_smoke_result(conn, EA_ID)
    assert latest["smoke_result"] == ""
    assert latest["blocked_reason"] == "q01_agent_successor_receipt_hash_mismatch"
    assert farmctl._q01_smoke_admission(latest)["admitted"] is False
