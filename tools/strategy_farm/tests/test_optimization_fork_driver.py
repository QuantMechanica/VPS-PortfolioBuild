from __future__ import annotations

import datetime as dt
import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import optimization_fork_driver as subject
from tools.strategy_farm import health
from tools.strategy_farm.gate_manifest import load_gate_manifest


REPO_ROOT = Path(__file__).resolve().parents[3]
V3 = load_gate_manifest(
    REPO_ROOT / "tools" / "strategy_farm" / "config" / "gate_manifest.v3.json"
)
V4 = load_gate_manifest(
    REPO_ROOT / "tools" / "strategy_farm" / "config" / "gate_manifest.v4.draft.json"
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
    return conn


def _artifacts(tmp_path: Path, ea_id: str) -> dict[str, Path]:
    ea_dir = tmp_path / "EAs" / f"{ea_id}_fixture"
    sets = ea_dir / "sets"
    sets.mkdir(parents=True)
    files = {
        "setfile": sets / f"{ea_id}_fixture_EURUSD.DWX_H1_backtest.set",
        "source": ea_dir / f"{ea_id}_fixture.mq5",
        "binary": ea_dir / f"{ea_id}_fixture.ex5",
        "evidence": tmp_path / f"{ea_id}_incumbent.json",
        "stage": tmp_path / f"{ea_id}_stage.json",
        "harness": tmp_path / "harness.csv",
    }
    for name, path in files.items():
        path.write_bytes(f"{name}:{ea_id}\n".encode())
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
    evidence: Path | None,
    payload: dict | None = None,
    version: str = "v3",
    updated_at: str = "2026-08-23T12:00:00+00:00",
) -> None:
    conn.execute(
        """
        INSERT INTO work_items VALUES(
          ?, 'analytic', ?, ?, 'EURUSD.DWX', ?, ?, ?, 0, NULL, ?, NULL, ?, ?, ?, ?
        )
        """,
        (
            wid, phase, ea_id, str(setfile), status, verdict,
            None if evidence is None else str(evidence),
            json.dumps(payload or {}, sort_keys=True), updated_at, updated_at, version,
        ),
    )


def _green_harness(conn: sqlite3.Connection, files: dict[str, Path]) -> None:
    _insert(
        conn, wid=subject.HARNESS_ROOT_WORK_ITEM_ID, phase=subject.HARNESS_PHASE,
        ea_id=subject.HARNESS_EA_ID, status="failed", verdict="INFRA_FAIL",
        setfile=files["setfile"], evidence=files["harness"], version="legacy",
        updated_at="2026-08-21T20:42:31+00:00",
    )
    _insert(
        conn, wid="harness-rerun-green", phase=subject.HARNESS_PHASE,
        ea_id=subject.HARNESS_EA_ID, status="done", verdict="HARNESS_OK",
        setfile=files["setfile"], evidence=files["harness"], version="legacy",
        updated_at="2026-08-22T04:58:42+00:00",
    )


def _seed_incumbent(
    conn: sqlite3.Connection, tmp_path: Path, manifest, ea_id: str = "QM5_90001"
) -> dict[str, Path]:
    files = _artifacts(tmp_path, ea_id)
    _green_harness(conn, files)
    _insert(
        conn, wid="incumbent-pass", phase=manifest.gate_for_role("INCUMBENT"),
        ea_id=ea_id, status="done", verdict="PASS", setfile=files["setfile"],
        evidence=files["evidence"], payload={"ea_dir_name": f"{ea_id}_fixture"},
        version="v4" if manifest.schema_version.endswith("/v4") else "v3",
    )
    conn.commit()
    return files


def _complete(conn: sqlite3.Connection, wid: str, verdict: str, evidence: Path) -> None:
    conn.execute(
        "UPDATE work_items SET status='done',verdict=?,evidence_path=?,updated_at=? WHERE id=?",
        (verdict, str(evidence), "2026-08-23T13:00:00+00:00", wid),
    )
    conn.commit()


def test_v3_auto_chain_q10_to_q14_q15_q16(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _seed_incumbent(conn, tmp_path, V3)

    first = subject.advance_optimization_fork(conn, manifest=V3, apply=True)
    assert first["phases"] == {
        "incumbent": "Q10", "pattern": "Q14", "param_opt": "Q15", "head_to_head": "Q16"
    }
    pattern_id = first["created_work_item_ids"] == [first["actions"][0]["work_item_id"]]
    assert pattern_id
    q14_id = first["actions"][0]["work_item_id"]
    row = conn.execute("SELECT * FROM work_items WHERE id=?", (q14_id,)).fetchone()
    payload = json.loads(row["payload_json"])
    assert (row["phase"], row["status"], row["gate_contract_version"]) == ("Q14", "pending", "v3")
    assert payload["parent_work_item_id"] == "incumbent-pass"
    assert payload["fixture_harness"]["selected_work_item_id"] == "harness-rerun-green"
    assert payload["numeric_parameter_sweep"]["declared_parameter_count"] == 0
    assert payload["parent_bindings"]["evidence"]["sha256"] == hashlib.sha256(
        files["evidence"].read_bytes()
    ).hexdigest()

    _complete(conn, q14_id, "PASS", files["stage"])
    second = subject.advance_optimization_fork(conn, manifest=V3, apply=True)
    q15_id = next(a["work_item_id"] for a in second["actions"] if a["role"] == "PARAM_OPT")
    assert conn.execute("SELECT phase,status FROM work_items WHERE id=?", (q15_id,)).fetchone()[:] == (
        "Q15", "pending"
    )

    _complete(conn, q15_id, "NO_PARAMETER_CHANGE", files["stage"])
    third = subject.advance_optimization_fork(conn, manifest=V3, apply=True)
    q16_id = next(a["work_item_id"] for a in third["actions"] if a["role"] == "HEAD_TO_HEAD")
    assert conn.execute("SELECT phase,status FROM work_items WHERE id=?", (q16_id,)).fetchone()[:] == (
        "Q16", "pending"
    )


def test_v4_monkeypatched_manifest_uses_q11_q12_q13_q14(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _seed_incumbent(conn, tmp_path, V4)
    first = subject.advance_optimization_fork(conn, manifest=V4, apply=True)
    assert first["phases"] == {
        "incumbent": "Q11", "pattern": "Q12", "param_opt": "Q13", "head_to_head": "Q14"
    }
    pattern = first["actions"][0]
    assert pattern["phase"] == "Q12"
    _complete(conn, pattern["work_item_id"], "PASS", files["stage"])
    second = subject.advance_optimization_fork(conn, manifest=V4, apply=True)
    param = next(action for action in second["actions"] if action["role"] == "PARAM_OPT")
    assert param["phase"] == "Q13"
    _complete(conn, param["work_item_id"], "PASS", files["stage"])
    third = subject.advance_optimization_fork(conn, manifest=V4, apply=True)
    head = next(action for action in third["actions"] if action["role"] == "HEAD_TO_HEAD")
    assert head["phase"] == "Q14"
    assert conn.execute("SELECT gate_contract_version FROM work_items WHERE id=?", (
        head["work_item_id"],
    )).fetchone()[0] == "v4"


def test_fixture_dry_run_plans_whole_chain_without_writes(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _seed_incumbent(conn, tmp_path, V3)
    baseline_count = conn.execute("SELECT count(*) FROM work_items").fetchone()[0]

    pattern_plan = subject.advance_optimization_fork(conn, manifest=V3, apply=False)
    assert [(row["role"], row["phase"], row["would_create"]) for row in pattern_plan["actions"]] == [
        ("PATTERN", "Q14", True)
    ]
    assert conn.execute("SELECT count(*) FROM work_items").fetchone()[0] == baseline_count

    pattern_payload = {
        "schema": subject.SCHEMA,
        "gate_manifest_sha256": V3.sha256,
    }
    _insert(
        conn, wid="fixture-pattern-pass", phase="Q14", ea_id="QM5_90001",
        status="done", verdict="PASS", setfile=files["setfile"], evidence=files["stage"],
        payload=pattern_payload,
    )
    conn.commit()
    param_plan = subject.advance_optimization_fork(conn, manifest=V3, apply=False)
    assert any(
        row["role"] == "PARAM_OPT" and row["phase"] == "Q15" and row["would_create"]
        for row in param_plan["actions"]
    )

    _insert(
        conn, wid="fixture-param-pass", phase="Q15", ea_id="QM5_90001",
        status="done", verdict="NO_PARAMETER_CHANGE", setfile=files["setfile"],
        evidence=files["stage"], payload=pattern_payload,
    )
    conn.commit()
    before_head_plan = conn.execute("SELECT count(*) FROM work_items").fetchone()[0]
    head_plan = subject.advance_optimization_fork(conn, manifest=V3, apply=False)
    assert any(
        row["role"] == "HEAD_TO_HEAD" and row["phase"] == "Q16" and row["would_create"]
        for row in head_plan["actions"]
    )
    assert conn.execute("SELECT count(*) FROM work_items").fetchone()[0] == before_head_plan


def test_keep_incumbent_is_terminal_and_counted(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _seed_incumbent(conn, tmp_path, V3)
    pattern = subject.advance_optimization_fork(conn, manifest=V3, apply=True)["actions"][0]
    _complete(conn, pattern["work_item_id"], "KEEP_INCUMBENT", files["stage"])
    param = next(
        action for action in subject.advance_optimization_fork(conn, manifest=V3, apply=True)["actions"]
        if action["role"] == "PARAM_OPT"
    )
    _complete(conn, param["work_item_id"], "KEEP_INCUMBENT", files["stage"])
    head = next(
        action for action in subject.advance_optimization_fork(conn, manifest=V3, apply=True)["actions"]
        if action["role"] == "HEAD_TO_HEAD"
    )
    _complete(conn, head["work_item_id"], "KEEP_INCUMBENT", files["stage"])
    metrics = subject.service_metrics(
        conn, manifests=(V3, V4),
        now=dt.datetime(2026, 8, 23, 14, tzinfo=dt.timezone.utc),
    )
    assert metrics["terminal_requalification_verdicts_count"] == 1
    assert metrics["completed_per_day_by_gate"]["v3:Q16:HEAD_TO_HEAD"] == 1


def test_missing_fixture_harness_appends_machine_readable_infra_failure(tmp_path: Path) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _artifacts(tmp_path, "QM5_90001")
    _insert(
        conn, wid="incumbent-pass", phase="Q10", ea_id="QM5_90001",
        status="done", verdict="PASS", setfile=files["setfile"], evidence=files["evidence"],
        payload={"ea_dir_name": "QM5_90001_fixture"}, version="v3",
    )
    conn.commit()
    result = subject.advance_optimization_fork(conn, manifest=V3, apply=True)
    action = result["actions"][0]
    assert (action["status"], action["verdict"], action["machine_reason"]) == (
        "failed", "INFRA_FAIL", "FIXTURE_HARNESS_ROOT_MISSING"
    )
    payload = json.loads(conn.execute(
        "SELECT payload_json FROM work_items WHERE id=?", (action["work_item_id"],)
    ).fetchone()[0])
    assert payload["activation_state"] == "FAIL_CLOSED"
    assert payload["fixture_harness"]["green"] is False


def test_health_surfaces_service_rate_and_terminal_count(tmp_path: Path, monkeypatch) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _seed_incumbent(conn, tmp_path, V3)
    pattern = subject.advance_optimization_fork(conn, manifest=V3, apply=True)["actions"][0]
    monkeypatch.setattr(health, "_optimization_manifests", lambda: (V3, V4))
    rate = health.chk_opt_fork_service_rate(conn)
    terminal = health.chk_terminal_requalification_verdicts_count(conn)
    assert rate["status"] == "WARN"
    assert "v3:Q14:PATTERN" in rate["value"]
    assert terminal["value"] == 0

    _complete(conn, pattern["work_item_id"], "PASS", files["stage"])
    assert health.chk_opt_fork_service_rate(conn)["status"] == "OK"


def test_health_excludes_stale_payload_manifest_from_v4_backlog(
    tmp_path: Path, monkeypatch
) -> None:
    conn = _db(tmp_path / "farm.sqlite")
    files = _artifacts(tmp_path, "QM5_90002")
    _insert(
        conn,
        wid="stranded-v3-payload",
        phase=V4.gate_for_role("PATTERN"),
        ea_id="QM5_90002",
        status="pending",
        verdict=None,
        setfile=files["setfile"],
        evidence=None,
        payload={
            "schema": subject.SCHEMA,
            "gate_contract_version": "v3",
            "gate_manifest_sha256": V3.sha256,
        },
        version="v4",
    )
    conn.commit()
    monkeypatch.setattr(health, "_optimization_manifests", lambda: (V4,))

    result = health.chk_opt_fork_service_rate(conn)

    assert result["status"] == "OK"
    assert "pending_or_active=0" in result["detail"]
