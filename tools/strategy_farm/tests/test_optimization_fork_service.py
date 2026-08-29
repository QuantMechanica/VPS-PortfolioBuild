from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import optimization_fork_driver as driver
from tools.strategy_farm import optimization_fork_service as subject
from tools.strategy_farm.gate_manifest import load_gate_manifest


REPO_ROOT = Path(__file__).resolve().parents[3]
V4 = load_gate_manifest(
    REPO_ROOT / "tools" / "strategy_farm" / "config" / "gate_manifest.v4.json"
)


def _db(path: Path) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    conn.execute(
        """
        CREATE TABLE work_items(
            id TEXT PRIMARY KEY,kind TEXT NOT NULL,phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,symbol TEXT NOT NULL,setfile_path TEXT NOT NULL,
            status TEXT NOT NULL,verdict TEXT,attempt_count INTEGER NOT NULL DEFAULT 0,
            parent_task_id TEXT,evidence_path TEXT,claimed_by TEXT,
            payload_json TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,
            gate_contract_version TEXT
        )
        """
    )
    conn.execute(
        """
        CREATE TABLE work_item_holds(
            work_item_id TEXT,hold_code TEXT,reason TEXT,active INTEGER,
            release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
            released_at TEXT,release_note TEXT
        )
        """
    )
    return conn


def _artifacts(tmp_path: Path) -> dict[str, Path]:
    ea_dir = tmp_path / "EAs" / "QM5_90001_fixture"
    sets = ea_dir / "sets"
    sets.mkdir(parents=True)
    files = {
        "setfile": sets / "QM5_90001_fixture_EURUSD.DWX_H1_backtest.set",
        "source": ea_dir / "QM5_90001_fixture.mq5",
        "binary": ea_dir / "QM5_90001_fixture.ex5",
        "incumbent": tmp_path / "incumbent.json",
        "harness": tmp_path / "harness.csv",
    }
    for name, path in files.items():
        path.write_bytes(f"{name}\n".encode())
    return files


def _insert(
    conn: sqlite3.Connection,
    *,
    wid: str,
    phase: str,
    ea_id: str,
    status: str,
    verdict: str | None,
    setfile: Path,
    evidence: Path,
    payload: dict | None = None,
    version: str = "v4",
) -> None:
    now = "2026-08-25T12:00:00+00:00"
    conn.execute(
        """
        INSERT INTO work_items VALUES(
          ?, 'analytic', ?, ?, 'EURUSD.DWX', ?, ?, ?, 0, NULL, ?, NULL, ?, ?, ?, ?
        )
        """,
        (
            wid,
            phase,
            ea_id,
            str(setfile),
            status,
            verdict,
            str(evidence),
            json.dumps(payload or {}, sort_keys=True),
            now,
            now,
            version,
        ),
    )


def _seed(conn: sqlite3.Connection, tmp_path: Path) -> dict[str, Path]:
    files = _artifacts(tmp_path)
    _insert(
        conn,
        wid=driver.HARNESS_ROOT_WORK_ITEM_ID,
        phase=driver.HARNESS_PHASE,
        ea_id=driver.HARNESS_EA_ID,
        status="failed",
        verdict="INFRA_FAIL",
        setfile=files["setfile"],
        evidence=files["harness"],
        version="legacy",
    )
    _insert(
        conn,
        wid="harness-green",
        phase=driver.HARNESS_PHASE,
        ea_id=driver.HARNESS_EA_ID,
        status="done",
        verdict="HARNESS_OK",
        setfile=files["setfile"],
        evidence=files["harness"],
        version="legacy",
    )
    _insert(
        conn,
        wid="incumbent-pass",
        phase=V4.gate_for_role("INCUMBENT"),
        ea_id="QM5_90001",
        status="done",
        verdict="PASS",
        setfile=files["setfile"],
        evidence=files["incumbent"],
        payload={"ea_dir_name": "QM5_90001_fixture"},
    )
    conn.commit()
    return files


def _route_one(conn: sqlite3.Connection, role: str) -> str:
    result = driver.advance_optimization_fork(conn, manifest=V4, apply=True)
    return next(row["work_item_id"] for row in result["actions"] if row["role"] == role)


def _rewrite_pattern_as_legacy_zero_search(conn: sqlite3.Connection, wid: str) -> str:
    """Model a pre-declaration routing row for backward-compatibility coverage."""

    payload = json.loads(conn.execute(
        "SELECT payload_json FROM work_items WHERE id=?", (wid,)
    ).fetchone()[0])
    payload.pop("pattern_filter_sweep")
    payload.pop("routing_revision")
    payload["dl089_contract"].pop("declared_pattern_search_required")
    legacy_id = driver._row_id(
        manifest=V4,
        role="PATTERN",
        parent_id=payload["parent_work_item_id"],
        prerequisite_id=payload["fixture_harness"]["selected_work_item_id"],
    )
    identity = dict(payload)
    identity.pop("routing_identity_sha256")
    payload["routing_identity_sha256"] = hashlib.sha256(
        driver._canonical_bytes(identity)
    ).hexdigest()
    conn.execute(
        "UPDATE work_items SET id=?,payload_json=? WHERE id=?",
        (legacy_id, json.dumps(payload, sort_keys=True), wid),
    )
    conn.commit()
    return legacy_id


def test_legacy_v4_no_change_chain_remains_evidence_bound(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    _seed(conn, tmp_path)
    evidence_root = tmp_path / "receipts"

    pattern_id = _route_one(conn, "PATTERN")
    pattern_id = _rewrite_pattern_as_legacy_zero_search(conn, pattern_id)
    preview = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=evidence_root,
        apply=False,
        work_item_ids=[pattern_id],
    )
    assert preview["planned"][0]["verdict"] == "NO_FILTER_CHANGE"
    assert conn.execute(
        "SELECT status FROM work_items WHERE id=?", (pattern_id,)
    ).fetchone()[0] == "pending"

    pattern = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=evidence_root,
        apply=True,
        work_item_ids=[pattern_id],
    )
    assert pattern["completed"][0]["verdict"] == "NO_FILTER_CHANGE"

    param_id = _route_one(conn, "PARAM_OPT")
    param = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=evidence_root,
        apply=True,
        work_item_ids=[param_id],
    )
    assert param["completed"][0]["verdict"] == "NO_PARAMETER_CHANGE"

    head_id = _route_one(conn, "HEAD_TO_HEAD")
    head = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=evidence_root,
        apply=True,
        work_item_ids=[head_id],
    )
    assert head["completed"][0]["verdict"] == "KEEP_INCUMBENT"
    rows = conn.execute(
        "SELECT phase,status,verdict,evidence_path FROM work_items "
        "WHERE id IN (?,?,?) ORDER BY phase",
        (pattern_id, param_id, head_id),
    ).fetchall()
    assert [(row[0], row[1], row[2]) for row in rows] == [
        ("Q12", "done", "NO_FILTER_CHANGE"),
        ("Q13", "done", "NO_PARAMETER_CHANGE"),
        ("Q14", "done", "KEEP_INCUMBENT"),
    ]
    for row in rows:
        receipt = json.loads(Path(row[3]).read_text(encoding="utf-8"))
        assert receipt["selection_contract_changed"] is False
        assert receipt["measured_candidate_adjudicated"] is False


def test_declared_pattern_work_is_delegated_to_dl089_and_left_pending(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    _seed(conn, tmp_path)
    pattern_id = _route_one(conn, "PATTERN")
    row = conn.execute(
        "SELECT payload_json FROM work_items WHERE id=?", (pattern_id,)
    ).fetchone()
    payload = json.loads(row[0])
    declaration = payload["pattern_filter_sweep"]
    assert declaration["declared_trial_count"] == 154
    assert declaration["annual_cell_count"] == 1085
    assert declaration["wf_cell_count"] == 4
    assert declaration["measured_candidate_adjudicated"] is False

    result = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=tmp_path / "receipts",
        apply=True,
        work_item_ids=[pattern_id],
    )

    assert result["completed"] == []
    assert result["deferred"] == []
    assert result["delegated"] == [
        {
            "work_item_id": pattern_id,
            "ea_id": "QM5_90001",
            "symbol": "EURUSD.DWX",
            "phase": "Q12",
            "governed_evaluator": "dl089_matrix_service",
            "machine_reason": "GOVERNED_EVALUATOR_ASSIGNED:dl089_matrix_service",
        }
    ]
    assert conn.execute(
        "SELECT status,verdict FROM work_items WHERE id=?", (pattern_id,)
    ).fetchone()[:] == ("pending", None)


def test_active_hold_blocks_service(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    _seed(conn, tmp_path)
    pattern_id = _route_one(conn, "PATTERN")
    conn.execute(
        "INSERT INTO work_item_holds VALUES(?,?,?,1,0,?,?,NULL,NULL)",
        (pattern_id, "OWNER_HOLD", "fixture", "t", "t"),
    )
    conn.commit()

    result = subject.service_pending(
        conn,
        manifest=V4,
        repo_root=REPO_ROOT,
        evidence_root=tmp_path / "receipts",
        apply=True,
        work_item_ids=[pattern_id],
    )

    assert result["completed"] == []
    assert "OWNER_HOLD" in result["deferred"][0]["machine_reason"]
