from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import retry_compile_recheck_canary as retry


def _fixture(tmp_path: Path) -> tuple[Path, Path, Path]:
    db = tmp_path / "farm.sqlite"
    repo = tmp_path / "repo"
    label = "QM5_1009_lien-fade-double-zeros"
    source = repo / "framework" / "EAs" / label / f"{label}.mq5"
    source.parent.mkdir(parents=True)
    source.write_text("#property strict\n", encoding="utf-8")
    source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    evidence = (
        tmp_path / "reports" / retry.INCIDENT_WORK_ITEM_ID
        / "QM5_1009" / "COMPILE_EA" / "compile_evidence.json"
    )
    evidence.parent.mkdir(parents=True)
    evidence.write_text(json.dumps({
        "work_item_id": retry.INCIDENT_WORK_ITEM_ID,
        "success": False,
        "failure_classes": [retry.FAILURE_CLASS],
        "candidate_recheck": {"reasons": ["WORK_ITEMS_EXIST"]},
    }), encoding="utf-8")
    payload = {
        "compile_contract_version": retry.COMPILE_CONTRACT_VERSION,
        "compile_activation_state": "AWAITING_REVIEWED_WORKER_ROLLOUT",
        "compile_activation_hold_code": retry.ACTIVATION_HOLD_CODE,
        "ea_label": label,
        "ea_dir": str(source.parent),
        "mq5_path": str(source),
        "mq5_sha256": source_sha,
        "symbols": ["EURUSD.DWX"],
        "timeframe": {"timeframe": "H1"},
        "risk_contract": {"RISK_FIXED": 1000.0, "RISK_PERCENT": 0.0},
        "utility_phase": True,
        "no_gate_verdict": True,
        "revival_contract_version": retry.R11_REVIVAL_CONTRACT_VERSION,
        "revival_authority_task_id": retry.R11_REVIVAL_AUTHORITY_TASK_ID,
        "revived_from_work_item_id": "r11-old",
        "revival_reason": "R11_FALSE_INVALID_EX5_MISSING",
        "revival_source_mq5_sha256": source_sha,
        "append_only_revival": True,
        "verdict_reason": retry.FAILURE_CLASS,
        "compile_result": {"failure_classes": [retry.FAILURE_CLASS]},
    }
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
          setfile_path TEXT,status TEXT,verdict TEXT,attempt_count INTEGER,
          parent_task_id TEXT,evidence_path TEXT,claimed_by TEXT,payload_json TEXT,
          created_at TEXT,updated_at TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT);
        CREATE TABLE work_item_transition_ledger(
          seq INTEGER PRIMARY KEY AUTOINCREMENT,idempotency_key TEXT UNIQUE,ts TEXT,
          work_item_id TEXT,action TEXT,from_status TEXT,to_status TEXT,
          from_verdict TEXT,to_verdict TEXT,from_claimed_by TEXT,to_claimed_by TEXT,
          reason TEXT,run_id TEXT,detail_json TEXT);
        CREATE TABLE events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,ts TEXT,entity_type TEXT,
          entity_id TEXT,event TEXT,detail_json TEXT);
        CREATE TABLE work_item_supersedes(
          work_item_id TEXT PRIMARY KEY,superseded_by_work_item_id TEXT,reason TEXT,
          source_encoding TEXT,evidence_path TEXT,recorded_by TEXT,recorded_at TEXT);
        """
    )
    conn.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        (
            retry.INCIDENT_WORK_ITEM_ID, "compile", "COMPILE_EA", "QM5_1009",
            "", "", "failed", "COMPILE_FAIL", 0, None, str(evidence), None,
            json.dumps(payload), "2026-08-22T05:23:59+00:00",
            "2026-08-22T06:36:04+00:00",
        ),
    )
    conn.commit()
    conn.close()
    return db, repo, source


def _add_binding_incident(db: Path, tmp_path: Path) -> Path:
    evidence = (
        tmp_path / "reports" / retry.BINDING_INCIDENT_WORK_ITEM_ID
        / "QM5_1009" / "COMPILE_EA" / "compile_evidence.json"
    )
    evidence.parent.mkdir(parents=True)
    evidence.write_text(json.dumps({
        "work_item_id": retry.BINDING_INCIDENT_WORK_ITEM_ID,
        "success": False,
        "failure_classes": [retry.BINDING_FAILURE_CLASS],
        "candidate_recheck": {"eligible": True},
        "build_check_exit_code": 1,
        "build_check_result": None,
        "compile_result": None,
        "include_mirror_atomic_replace": None,
        "setfile_count": 1,
        "setfile_generation": [
            {"exit_code": 0, "setfile_exists": True, "symbol": "EURUSD.DWX"}
        ],
        "terminal_claim": "T5",
        "running_terminals_at_worker_start": ["T1", "T3"],
        "build_check_output_tail": (
            "Cannot validate argument on parameter 'ClaimedTerminal'. "
            'The argument "-ClaimedTerminal" does not match.'
        ),
    }), encoding="utf-8")
    with sqlite3.connect(db) as conn:
        predecessor = conn.execute(
            "SELECT payload_json FROM work_items WHERE id=?",
            (retry.INCIDENT_WORK_ITEM_ID,),
        ).fetchone()
        payload = json.loads(predecessor[0])
        payload.update({
            "compile_retry_contract_version": retry.RETRY_CONTRACT_VERSION,
            "compile_retry_authority_task_id": retry.AUTHORITY_TASK_ID,
            "retry_of_work_item_id": retry.INCIDENT_WORK_ITEM_ID,
            "append_only_retry": True,
            "verdict_reason": retry.BINDING_FAILURE_CLASS,
            "compile_result": {
                "failure_classes": [retry.BINDING_FAILURE_CLASS],
                "build_check_result": None,
                "setfile_count": 1,
            },
        })
        conn.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (
                retry.BINDING_INCIDENT_WORK_ITEM_ID,
                "compile",
                "COMPILE_EA",
                "QM5_1009",
                "",
                "",
                "failed",
                "COMPILE_FAIL",
                0,
                None,
                str(evidence),
                None,
                json.dumps(payload),
                "2026-08-22T06:55:08+00:00",
                "2026-08-22T07:17:51+00:00",
            ),
        )
        conn.execute(
            "INSERT INTO work_item_supersedes VALUES (?,?,?,?,?,?,?)",
            (
                retry.INCIDENT_WORK_ITEM_ID,
                retry.BINDING_INCIDENT_WORK_ITEM_ID,
                retry.RETRY_REASON,
                "operator:test",
                "candidate-evidence.json",
                "codex",
                "2026-08-22T06:55:08+00:00",
            ),
        )
        conn.commit()
    return evidence


def test_append_only_canary_retry_is_guarded_and_idempotent(tmp_path: Path) -> None:
    db, repo, _ = _fixture(tmp_path)
    dry_run = retry.inspect(db, repo)
    before = dry_run["item"]["old_preimage_sha256"]
    first = retry.apply_retry(db, repo, tmp_path / "backups", tmp_path / "mutation.lock")
    second = retry.apply_retry(db, repo, tmp_path / "backups", tmp_path / "mutation2.lock")

    assert dry_run["eligible_count"] == 1
    assert first["verification_ok"] is True
    assert first["applied_count"] == 1
    assert second["idempotent_noop"] is True
    assert second["applied_count"] == 0
    assert first["after"]["item"]["old_preimage_sha256"] == before
    new_id = first["applied"][0]["new_work_item_id"]
    conn = sqlite3.connect(db)
    row = conn.execute(
        "SELECT status,verdict,payload_json FROM work_items WHERE id=?", (new_id,)
    ).fetchone()
    hold = conn.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?", (new_id,)
    ).fetchone()
    link = conn.execute(
        "SELECT superseded_by_work_item_id FROM work_item_supersedes WHERE work_item_id=?",
        (retry.INCIDENT_WORK_ITEM_ID,),
    ).fetchone()
    conn.close()
    successor_payload = json.loads(row[2])
    assert row[:2] == ("pending", None)
    assert hold == (retry.ACTIVATION_HOLD_CODE, 1)
    assert link == (new_id,)
    assert successor_payload["retry_of_work_item_id"] == retry.INCIDENT_WORK_ITEM_ID
    assert successor_payload["avoid_terminals"] == ["T8"]
    assert successor_payload["risk_contract"] == {
        "RISK_FIXED": 1000.0,
        "RISK_PERCENT": 0.0,
    }


def test_retry_holds_when_source_sha_changes(tmp_path: Path) -> None:
    db, repo, source = _fixture(tmp_path)
    source.write_text("changed\n", encoding="utf-8")
    result = retry.inspect(db, repo)

    assert result["eligible_count"] == 0
    assert result["held_count"] == 1
    assert "MQ5_SHA_STALE" in result["item"]["hold_reasons"]


def test_append_only_binding_retry_is_exact_and_idempotent(tmp_path: Path) -> None:
    db, repo, _ = _fixture(tmp_path)
    _add_binding_incident(db, tmp_path)

    dry_run = retry.inspect(db, repo, retry.BINDING_INCIDENT_WORK_ITEM_ID)
    first = retry.apply_retry(
        db,
        repo,
        tmp_path / "backups",
        tmp_path / "mutation.lock",
        retry.BINDING_INCIDENT_WORK_ITEM_ID,
    )
    second = retry.apply_retry(
        db,
        repo,
        tmp_path / "backups",
        tmp_path / "mutation2.lock",
        retry.BINDING_INCIDENT_WORK_ITEM_ID,
    )

    assert dry_run["eligible_count"] == 1
    assert first["verification_ok"] is True
    assert second["idempotent_noop"] is True
    new_id = first["applied"][0]["new_work_item_id"]
    with sqlite3.connect(db) as conn:
        row = conn.execute(
            "SELECT status,verdict,payload_json FROM work_items WHERE id=?",
            (new_id,),
        ).fetchone()
    successor_payload = json.loads(row[2])
    assert row[:2] == ("pending", None)
    assert successor_payload["compile_retry_contract_version"] == (
        retry.BINDING_RETRY_CONTRACT_VERSION
    )
    assert successor_payload["retry_of_work_item_id"] == (
        retry.BINDING_INCIDENT_WORK_ITEM_ID
    )
    assert successor_payload["avoid_terminals"] == ["T5"]


def test_binding_retry_holds_if_exact_failure_evidence_drifts(tmp_path: Path) -> None:
    db, repo, _ = _fixture(tmp_path)
    evidence = _add_binding_incident(db, tmp_path)
    document = json.loads(evidence.read_text(encoding="utf-8"))
    document["build_check_output_tail"] = "different failure"
    evidence.write_text(json.dumps(document), encoding="utf-8")

    result = retry.inspect(db, repo, retry.BINDING_INCIDENT_WORK_ITEM_ID)

    assert result["eligible_count"] == 0
    assert "INCIDENT_EVIDENCE_CONTRACT_MISMATCH" in result["item"]["hold_reasons"]
