import importlib.util
import json
import sqlite3
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "apply_q10_identity_mismatch_supersede.py"
SPEC = importlib.util.spec_from_file_location("q10_mismatch_batch", MODULE_PATH)
assert SPEC and SPEC.loader
mod = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mod)


def make_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
          setfile_path TEXT,status TEXT,verdict TEXT,claimed_by TEXT,
          payload_json TEXT,created_at TEXT
        );
        CREATE TABLE work_item_holds(
          work_item_id TEXT PRIMARY KEY,hold_code TEXT,active INTEGER
        );
        CREATE TABLE work_item_supersedes(
          work_item_id TEXT, superseded_by_work_item_id TEXT, reason TEXT,
          source_encoding TEXT, evidence_path TEXT, recorded_by TEXT, recorded_at TEXT,
          PRIMARY KEY(work_item_id,source_encoding)
        );
        CREATE TABLE events(
          ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT
        );
        """
    )
    for index, source_id in enumerate(mod.TARGET_IDS):
        parent_id = f"parent-{index}"
        ea_id = f"QM5_{10000 + index}"
        symbol = "XAUUSD.DWX"
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            (parent_id, "backtest", "Q09", ea_id, symbol, f"set-{index}",
             "done", "PASS", None, "{}", "2026-09-02T12:00:00+00:00"),
        )
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?,?)",
            (source_id, "backtest", "Q10_NEWS", ea_id, symbol, f"set-{index}",
             "pending", None, None, json.dumps({"promoted_from_work_item": parent_id}),
             "2026-09-02T12:10:00+00:00"),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,1)",
            (source_id, "Q09_AWAITING_SEALED_PLAN"),
        )
    conn.commit()
    conn.close()


def test_batch_is_append_only_and_uses_one_backup(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("authorized\n", encoding="utf-8")
    make_db(db)
    monkeypatch.setattr(mod, "EVIDENCE_PATH", evidence)
    plan = mod.build_plan(db)
    plan_path = tmp_path / "plan.json"
    plan_path.write_bytes(mod.canonical_bytes(plan))
    plan_sha = mod.sha256_file(plan_path)
    receipt_path = tmp_path / "receipt.json"
    receipt = mod.apply_plan(
        db=db, plan_path=plan_path, expected_plan_sha256=plan_sha,
        receipt_out=receipt_path, backup_dir=tmp_path / "backups",
        mutation_lock=tmp_path / "mutation.lock",
    )
    assert receipt["superseded_count"] == 16
    assert len(list((tmp_path / "backups").glob("*.sqlite"))) == 1
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 16
    assert conn.execute(
        "SELECT COUNT(*) FROM work_item_supersedes WHERE superseded_by_work_item_id IS NOT NULL"
    ).fetchone()[0] == 0
    assert conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE phase='Q10_NEWS' AND status='pending'"
    ).fetchone()[0] == 16
    assert conn.execute("SELECT COUNT(*) FROM work_item_holds WHERE active=1").fetchone()[0] == 16
    assert conn.execute("SELECT COUNT(*) FROM events WHERE event='work_item_superseded'").fetchone()[0] == 16
    conn.close()


def test_apply_fails_closed_on_identity_drift(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    evidence = tmp_path / "evidence.md"
    evidence.write_text("authorized\n", encoding="utf-8")
    make_db(db)
    monkeypatch.setattr(mod, "EVIDENCE_PATH", evidence)
    plan = mod.build_plan(db)
    plan_path = tmp_path / "plan.json"
    plan_path.write_bytes(mod.canonical_bytes(plan))
    conn = sqlite3.connect(db)
    conn.execute("UPDATE work_items SET setfile_path='drifted' WHERE id=?", (mod.TARGET_IDS[0],))
    conn.commit()
    conn.close()
    try:
        mod.apply_plan(
            db=db, plan_path=plan_path, expected_plan_sha256=mod.sha256_file(plan_path),
            receipt_out=tmp_path / "receipt.json", backup_dir=tmp_path / "backups",
            mutation_lock=tmp_path / "mutation.lock",
        )
    except mod.SupersedeBatchError as exc:
        assert "source_identity_drift" in str(exc)
    else:
        raise AssertionError("identity drift was not refused")
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT COUNT(*) FROM work_item_supersedes").fetchone()[0] == 0
    conn.close()
