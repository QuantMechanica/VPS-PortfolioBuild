from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import activate_gate_manifest_v4 as activation
from tools.strategy_farm import farmctl
from tools.strategy_farm import repair_q12_cutover_provenance as repair


def _fixture(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[sqlite3.Connection, str, str]:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    conn = sqlite3.connect(str(farmctl.db_path(root)))
    conn.row_factory = sqlite3.Row
    conn.executescript(activation.GATE_CONTRACT_CUTOVER_DDL)

    parent_id = "parent-q10"
    old_id = "historic-q14-cutover"
    now = "2026-08-23T15:46:34+00:00"
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            evidence_path,payload_json,created_at,updated_at,gate_contract_version,
            verdict_taxonomy,sh3_enforced
        ) VALUES(?, 'backtest','Q10','QM5_TEST','EURUSD.DWX','base.set',
                 'done','PASS',0,'parent.json','{}',?,?,'v3','strategy',0)
        """,
        (parent_id, now, now),
    )
    payload = {
        "schema": "qm.opt-fork-routing/v1",
        "role": "PATTERN",
        "phase": "Q14",
        "gate_contract_version": "v3",
        "gate_manifest_sha256": repair.OLD_MANIFEST_SHA256,
        "parent_work_item_id": parent_id,
        "parent_phase": "Q10",
        "parent_verdict": "PASS",
        "expected_ex5_sha256": "a" * 64,
        "expected_setfile_sha256": "b" * 64,
        "expected_mq5_sha256": "c" * 64,
    }
    raw = json.dumps(payload, sort_keys=True)
    payload_sha = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    # Historical fixture: the old activator created this contradiction before
    # the new storage-boundary provenance triggers existed.
    conn.execute(
        f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_PAYLOAD_PROVENANCE_INSERT_TRIGGER}"
    )
    conn.execute(
        f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_PAYLOAD_PROVENANCE_UPDATE_TRIGGER}"
    )
    conn.execute(
        """
        INSERT INTO work_items(
            id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
            evidence_path,claimed_by,payload_json,created_at,updated_at,
            gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256,
            verdict_taxonomy,sh3_enforced
        ) VALUES(?,'analytic','Q12','QM5_TEST','EURUSD.DWX','base.set',
                 'pending',NULL,0,NULL,NULL,?,?,?,'v4',?,?,?,'open',0)
        """,
        (old_id, raw, now, now, "a" * 64, "b" * 64, "c" * 64),
    )
    conn.execute(
        "INSERT INTO gate_contract_cutover_log VALUES(?,?,?,?,?,?)",
        (old_id, "Q14", "Q12", "v3", "v4", "2026-08-23T15:52:50Z"),
    )
    conn.commit()
    monkeypatch.setattr(
        repair,
        "TARGETS",
        {
            old_id: {
                "ea_id": "QM5_TEST",
                "symbol": "EURUSD.DWX",
                "parent_work_item_id": parent_id,
                "payload_sha256": payload_sha,
            }
        },
    )
    return conn, old_id, raw


def test_repair_restores_source_payload_and_appends_native_v4_successor(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    conn, old_id, old_raw = _fixture(tmp_path, monkeypatch)
    try:
        plan = repair.build_plan(conn)
        assert plan["state"] == "READY"
        assert plan["pre_repair_payload_mismatch_count"] == 1
        assert len(repair.plan_sha256(plan)) == 64

        conn.execute("BEGIN IMMEDIATE")
        result = repair.apply_plan(conn, plan)
        conn.commit()
        assert result["applied"] is True
        assert result["post_repair_payload_mismatch_count"] == 0

        old = conn.execute(
            "SELECT phase,gate_contract_version,status,verdict,payload_json,evidence_path "
            "FROM work_items WHERE id=?",
            (old_id,),
        ).fetchone()
        assert tuple(old[:4]) == ("Q14", "v3", "failed", "INFRA_FAIL")
        assert old["payload_json"] == old_raw
        assert old["evidence_path"] == repair.EVIDENCE_PATH

        action = plan["actions"][0]
        new = conn.execute(
            "SELECT phase,gate_contract_version,status,verdict,payload_json "
            "FROM work_items WHERE id=?",
            (action["new_work_item_id"],),
        ).fetchone()
        assert tuple(new[:4]) == ("Q12", "v4", "pending", None)
        new_payload = json.loads(new["payload_json"])
        assert new_payload["migration_provenance"]["source_work_item_id"] == old_id
        assert new_payload["migration_provenance"]["source_payload_retained"] is True

        post = repair.build_plan(conn)
        assert post["state"] == "ALREADY_REPAIRED"
        assert post["pre_repair_payload_mismatch_count"] == 0
        again = repair.apply_plan(conn, post)
        assert again == {"applied": False, "idempotent": True, "repaired_at": None}

        with pytest.raises(sqlite3.IntegrityError, match="append-only"):
            conn.execute("DELETE FROM gate_contract_provenance_repairs")
        with pytest.raises(sqlite3.IntegrityError, match="payload provenance"):
            conn.execute(
                "UPDATE work_items SET payload_json=? WHERE id=?",
                (json.dumps({"phase": "Q14", "gate_contract_version": "v4"}), old_id),
            )
    finally:
        conn.close()


def test_repair_fails_closed_on_claim_or_payload_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    conn, old_id, _ = _fixture(tmp_path, monkeypatch)
    try:
        conn.execute(
            "UPDATE work_items SET status='active',claimed_by='T1' WHERE id=?",
            (old_id,),
        )
        conn.commit()
        with pytest.raises(repair.RepairError, match="neither exact pre-state"):
            repair.build_plan(conn)
    finally:
        conn.close()
