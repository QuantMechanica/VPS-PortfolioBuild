import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import apply_q09_retire2_dispositions as subject


def _fixture(tmp_path: Path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    con = sqlite3.connect(db)
    con.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
          setfile_path TEXT,status TEXT,verdict TEXT,attempt_count INTEGER,
          parent_task_id TEXT,evidence_path TEXT,claimed_by TEXT,payload_json TEXT,
          created_at TEXT,updated_at TEXT,verdict_taxonomy_stored TEXT,
          clean_status_stored TEXT,gate_contract_version TEXT,verdict_taxonomy TEXT,
          sh3_enforced INTEGER NOT NULL DEFAULT 1);
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,reason TEXT,active INTEGER,
          release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT);
        CREATE TABLE work_item_supersedes(
          work_item_id TEXT,superseded_by_work_item_id TEXT,reason TEXT,
          source_encoding TEXT NOT NULL,evidence_path TEXT,recorded_by TEXT,recorded_at TEXT,
          PRIMARY KEY(work_item_id,source_encoding));
        CREATE TABLE events(id INTEGER PRIMARY KEY,ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT);
        CREATE TRIGGER sh3_insert AFTER INSERT ON work_items WHEN NEW.sh3_enforced=1 BEGIN
          UPDATE work_items SET status='failed',verdict='INFRA_FAIL',verdict_taxonomy='infra',
            payload_json=json_set(payload_json,'$.verdict_taxonomy','infra','$.verdict_reason','ARTIFACT_IDENTITY_MISSING')
          WHERE id=NEW.id AND status IN ('done','failed') AND verdict_taxonomy='strategy';
        END;
        """
    )
    now = "2026-08-30T00:00:00+00:00"
    for source_id, ea_id, symbol in subject.TARGETS:
        con.execute(
            "INSERT INTO work_items VALUES(?, 'backtest',?,?,?,?, 'pending',NULL,0,NULL,NULL,NULL,'{}',?,?,NULL,NULL,'v3',NULL,0)",
            (source_id, subject.NEWS_PHASE, ea_id, symbol, f"{ea_id}_{symbol}.set", now, now),
        )
        con.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,1,0,?,?,NULL,NULL)",
            (source_id, subject.HOLD_CODE, "held", now, now),
        )
    con.commit()
    con.close()

    decisions = tmp_path / "owner_decisions.json"
    decisions.write_text(json.dumps({"items": [{
        "id": subject.OWNER_DECISION_ID,
        "status": "DECIDED",
        "last_decision": "YES",
        "last_receipt_id": subject.OWNER_RECEIPT_ID + "-test",
    }]}), encoding="utf-8")
    evidence = tmp_path / "evidence.md"
    evidence.write_text("owner authorized\n", encoding="utf-8")
    monkeypatch.setattr(subject, "EVIDENCE_PATH", evidence)
    return db, decisions


def test_plan_apply_is_append_only_and_closes_exact_two(tmp_path: Path, monkeypatch) -> None:
    db, decisions = _fixture(tmp_path, monkeypatch)
    plan = subject.build_plan(db, decisions)
    assert len(plan["targets"]) == 2
    assert plan["active_news_holds_before"] == 2
    plan_path = tmp_path / "plan.json"
    plan_sha = subject.write_new_json(plan_path, plan)
    receipt = subject.apply_plan(
        db=db,
        decisions=decisions,
        plan_path=plan_path,
        expected_plan_sha256=plan_sha,
        receipt_out=tmp_path / "receipt.json",
        backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "mutation.lock",
    )
    assert receipt["active_news_hold_delta"] == -2
    assert receipt["historical_work_item_updates"] == 0
    assert receipt["quick_check"] == "ok"
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    try:
        originals = con.execute(
            "SELECT id,status,verdict,evidence_path FROM work_items WHERE id IN (?,?) ORDER BY id",
            [row[0] for row in subject.TARGETS],
        ).fetchall()
        assert [(r["status"], r["verdict"], r["evidence_path"]) for r in originals] == [
            ("pending", None, None), ("pending", None, None)
        ]
        dispositions = con.execute(
            "SELECT ea_id,symbol,status,verdict FROM work_items WHERE kind='disposition' ORDER BY ea_id"
        ).fetchall()
        assert [(r["ea_id"], r["symbol"], r["status"], r["verdict"]) for r in dispositions] == [
            ("QM5_10847", "GDAXI.DWX", "failed", "RETIRED_ARCHIVED"),
            ("QM5_13301", "GDAXI.DWX", "failed", "RETIRED_ARCHIVED"),
        ]
        assert con.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 2
        assert con.execute("SELECT COUNT(*) FROM work_item_holds WHERE active=0").fetchone()[0] == 2
    finally:
        con.close()


def test_plan_refuses_scope_or_hold_drift(tmp_path: Path, monkeypatch) -> None:
    db, decisions = _fixture(tmp_path, monkeypatch)
    con = sqlite3.connect(db)
    con.execute("UPDATE work_item_holds SET active=0 WHERE work_item_id=?", (subject.TARGETS[0][0],))
    con.commit()
    con.close()
    try:
        subject.build_plan(db, decisions)
    except subject.Retire2Error as exc:
        assert "target_prestate_mismatch" in str(exc)
    else:
        raise AssertionError("hold drift was accepted")


def test_sh3_repair_appends_retire_successors_without_updates(tmp_path: Path, monkeypatch) -> None:
    db, decisions = _fixture(tmp_path, monkeypatch)
    plan = subject.build_plan(db, decisions)
    first_plan_path = tmp_path / "first-plan.json"
    first_sha = subject.write_new_json(first_plan_path, plan)
    subject.apply_plan(
        db=db, decisions=decisions, plan_path=first_plan_path,
        expected_plan_sha256=first_sha, receipt_out=tmp_path / "first-receipt.json",
        backup_dir=tmp_path / "backups", mutation_lock=tmp_path / "mutation.lock",
    )
    con = sqlite3.connect(db)
    for source_id, _ea_id, _symbol in subject.TARGETS:
        first_id = subject.disposition_id(source_id)
        row = con.execute("SELECT payload_json FROM work_items WHERE id=?", (first_id,)).fetchone()
        payload = json.loads(row[0])
        payload["verdict_reason"] = "ARTIFACT_IDENTITY_MISSING"
        con.execute(
            "UPDATE work_items SET status='failed',verdict='INFRA_FAIL',payload_json=? WHERE id=?",
            (json.dumps(payload, sort_keys=True), first_id),
        )
    con.commit()
    con.close()
    repair = subject.build_repair_plan(db, decisions)
    repair_path = tmp_path / "repair-plan.json"
    repair_sha = subject.write_new_json(repair_path, repair)
    receipt = subject.apply_repair_plan(
        db=db, decisions=decisions, plan_path=repair_path,
        expected_plan_sha256=repair_sha, receipt_out=tmp_path / "repair-receipt.json",
        backup_dir=tmp_path / "backups", mutation_lock=tmp_path / "mutation.lock",
    )
    assert receipt["historical_work_item_updates"] == 0
    assert receipt["historical_hold_updates"] == 0
    con = sqlite3.connect(db)
    try:
        repaired = con.execute(
            "SELECT status,verdict,sh3_enforced FROM work_items WHERE id IN (?,?) ORDER BY id",
            [subject.repaired_disposition_id(row[0]) for row in subject.TARGETS],
        ).fetchall()
        assert repaired == [("done", "RETIRE", 0), ("done", "RETIRE", 0)]
        first = con.execute(
            "SELECT COUNT(*) FROM work_items WHERE kind='disposition' AND verdict='INFRA_FAIL'"
        ).fetchone()[0]
        assert first == 2
    finally:
        con.close()
