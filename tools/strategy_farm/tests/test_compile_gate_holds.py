from __future__ import annotations

import json
import os
from pathlib import Path

from tools.strategy_farm import farmctl


EA_ID = "QM5_99901"
FAILED_AT = "2026-09-12T10:00:00+00:00"


def _insert_item(
    conn,
    item_id: str,
    *,
    phase: str,
    ea_id: str = EA_ID,
    status: str = "pending",
    claimed_by: str | None = None,
    payload: dict | None = None,
    verdict: str | None = None,
    evidence_path: str | None = None,
    updated_at: str = "2026-09-12T09:00:00+00:00",
) -> None:
    conn.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          evidence_path,claimed_by,payload_json,created_at,updated_at,
          gate_contract_version
        ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """,
        (
            item_id,
            "compile" if phase == "COMPILE_EA" else "backtest",
            phase,
            ea_id,
            "" if phase == "COMPILE_EA" else "EURUSD.DWX",
            "" if phase == "COMPILE_EA" else "fixture.set",
            status,
            verdict,
            0,
            evidence_path,
            claimed_by,
            json.dumps(payload or {}, sort_keys=True),
            "2026-09-12T09:00:00+00:00",
            updated_at,
            farmctl.ACTIVE_GATE_CONTRACT_VERSION,
        ),
    )


def _active_trigger(root: Path):
    with farmctl.connect(root) as conn:
        return conn.execute("SELECT * FROM work_items WHERE id='trigger'").fetchone()


def _seed_compile_failure_cluster(root: Path) -> None:
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        _insert_item(
            conn,
            "trigger",
            phase="Q02",
            status="active",
            claimed_by="T2",
            payload={"sealed": "original"},
        )
        _insert_item(conn, "q03-peer", phase="Q03")
        _insert_item(conn, "q04-peer", phase="Q04")
        _insert_item(conn, "other-ea", phase="Q02", ea_id="QM5_99902")
        farmctl.record_claim_ledger(conn, "T2", "trigger", "priority", FAILED_AT)
        conn.commit()


def test_compile_gate_hold_is_default_off(monkeypatch, tmp_path: Path) -> None:
    root = tmp_path / "farm"
    _seed_compile_failure_cluster(root)
    monkeypatch.delenv(farmctl.COMPILE_GATE_HOLD_ENV, raising=False)

    result = farmctl.record_work_item_spawn_refusal(
        root,
        _active_trigger(root),
        "T2",
        {"reason": "compile_gate:COMPILE_FAILED"},
        failed_at=FAILED_AT,
    )

    assert result["event"] == "runner_spawn_refused"
    with farmctl.connect(root) as conn:
        row = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id='trigger'"
        ).fetchone()
        assert tuple(row) == ("failed", "INFRA_FAIL")
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE hold_code=?",
            (farmctl.COMPILE_GATE_HOLD_CODE,),
        ).fetchone()[0] == 0


def test_enabled_compile_gate_requires_queue_instead_of_inline_compile(
    monkeypatch, tmp_path: Path
) -> None:
    repo = tmp_path / "repo"
    ea_label = "QM5_99901_fixture"
    ea_dir = repo / "framework" / "EAs" / ea_label
    ea_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{ea_label}.mq5"
    ex5 = ea_dir / f"{ea_label}.ex5"
    mq5.write_text("source\n", encoding="utf-8")
    ex5.write_bytes(b"old")
    os.utime(ex5, (1_700_000_000, 1_700_000_000))
    os.utime(mq5, (1_700_000_100, 1_700_000_100))
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo)
    monkeypatch.setenv(farmctl.COMPILE_GATE_HOLD_ENV, "1")

    result = farmctl._compile_gate_check(ea_label)

    assert result["allowed"] is False
    assert result["verdict"] == "COMPILE_EA_REQUIRED"
    assert result["source"] == "compile_queue"


def test_compile_gate_refusal_restores_claim_and_holds_same_ea(
    monkeypatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    _seed_compile_failure_cluster(root)
    monkeypatch.setenv(farmctl.COMPILE_GATE_HOLD_ENV, "1")

    result = farmctl.record_work_item_spawn_refusal(
        root,
        _active_trigger(root),
        "T2",
        {"reason": "compile_gate:COMPILE_FAILED"},
        failed_at=FAILED_AT,
    )

    assert result["event"] == "compile_gate_spawn_deferred"
    assert result["held_count"] == 3
    with farmctl.connect(root) as conn:
        trigger = conn.execute(
            "SELECT status,verdict,claimed_by,evidence_path,payload_json "
            "FROM work_items WHERE id='trigger'"
        ).fetchone()
        assert tuple(trigger[:4]) == ("pending", None, None, None)
        assert json.loads(trigger[4]) == {"sealed": "original"}
        held = conn.execute(
            """
            SELECT w.id,h.hold_code,h.active,h.release_on_restart
            FROM work_items w JOIN work_item_holds h ON h.work_item_id=w.id
            ORDER BY w.id
            """
        ).fetchall()
        assert [row[0] for row in held] == ["q03-peer", "q04-peer", "trigger"]
        assert all(
            row[1:] == (farmctl.COMPILE_GATE_HOLD_CODE, 1, 0) for row in held
        )
        assert conn.execute(
            "SELECT COUNT(*) FROM claim_class_ledger WHERE work_item_id='trigger'"
        ).fetchone()[0] == 0
        events = [
            row[0]
            for row in conn.execute(
                "SELECT event FROM events WHERE entity_id='trigger' ORDER BY id"
            )
        ]
        assert "compile_gate_hold_installed" in events
        assert "compile_gate_spawn_deferred" in events


def test_authenticated_newer_compile_ok_releases_without_touching_verdicts(
    monkeypatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    _seed_compile_failure_cluster(root)
    monkeypatch.setenv(farmctl.COMPILE_GATE_HOLD_ENV, "1")
    farmctl.record_work_item_spawn_refusal(
        root,
        _active_trigger(root),
        "T2",
        {"reason": "compile_gate:COMPILE_FAILED"},
        failed_at=FAILED_AT,
    )
    evidence = tmp_path / "compile_evidence.json"
    receipt = {
        "schema_version": "qm.compile-ea-evidence/v1",
        "work_item_id": "compile-ok",
        "ea_id": EA_ID,
        "success": True,
        "compile_result": "PASS",
        "build_check_result": "PASS",
    }
    evidence.write_text(json.dumps(receipt), encoding="utf-8")
    with farmctl.connect(root) as conn:
        _insert_item(
            conn,
            "compile-ok",
            phase="COMPILE_EA",
            status="done",
            verdict="COMPILE_OK",
            evidence_path=str(evidence),
            updated_at="2026-09-12T10:05:00+00:00",
        )
        conn.commit()

    dry_run = farmctl.reconcile_compile_gate_holds(root, apply=False)
    assert dry_run["release_ready_count"] == 3
    assert dry_run["released_count"] == 0
    with farmctl.connect(root) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1"
        ).fetchone()[0] == 3

    applied = farmctl.reconcile_compile_gate_holds(
        root, apply=True, released_at="2026-09-12T10:06:00+00:00"
    )
    assert applied["released_count"] == 3
    with farmctl.connect(root) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE verdict IS NOT NULL "
            "AND phase IN ('Q02','Q03','Q04')"
        ).fetchone()[0] == 0
        assert conn.execute(
            "SELECT COUNT(*) FROM events WHERE event='compile_gate_hold_released'"
        ).fetchone()[0] == 3


def test_missing_or_invalid_compile_receipt_cannot_release(
    monkeypatch, tmp_path: Path
) -> None:
    root = tmp_path / "farm"
    _seed_compile_failure_cluster(root)
    monkeypatch.setenv(farmctl.COMPILE_GATE_HOLD_ENV, "1")
    farmctl.record_work_item_spawn_refusal(
        root,
        _active_trigger(root),
        "T2",
        {"reason": "compile_gate:COMPILE_FAILED"},
        failed_at=FAILED_AT,
    )
    invalid = tmp_path / "invalid_compile_evidence.json"
    invalid.write_text(
        json.dumps(
            {
                "schema_version": "qm.compile-ea-evidence/v1",
                "work_item_id": "compile-ok",
                "ea_id": EA_ID,
                "success": True,
                "compile_result": "FAIL",
                "build_check_result": "PASS",
            }
        ),
        encoding="utf-8",
    )
    with farmctl.connect(root) as conn:
        _insert_item(
            conn,
            "compile-ok",
            phase="COMPILE_EA",
            status="done",
            verdict="COMPILE_OK",
            evidence_path=str(invalid),
            updated_at="2026-09-12T10:05:00+00:00",
        )
        conn.commit()

    result = farmctl.reconcile_compile_gate_holds(root, apply=True)

    assert result["release_ready_count"] == 0
    assert result["released_count"] == 0
    with farmctl.connect(root) as conn:
        assert conn.execute(
            "SELECT COUNT(*) FROM work_item_holds WHERE active=1"
        ).fetchone()[0] == 3
