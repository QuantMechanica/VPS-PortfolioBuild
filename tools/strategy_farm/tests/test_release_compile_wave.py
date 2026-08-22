import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import release_compile_wave as rollout


def _fixture(tmp_path: Path):
    db = tmp_path / "farm.sqlite"
    repo = tmp_path / "repo"
    ea_label = "QM5_1001_example"
    source = repo / "framework" / "EAs" / ea_label / f"{ea_label}.mq5"
    source.parent.mkdir(parents=True)
    source.write_text("void OnTick() {}\n", encoding="utf-8")
    source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    conn = sqlite3.connect(db)
    conn.executescript(
        """
        CREATE TABLE work_items(id TEXT PRIMARY KEY,ea_id TEXT,phase TEXT,status TEXT,
          claimed_by TEXT,verdict TEXT,payload_json TEXT,created_at TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,hold_code TEXT,
          active INTEGER,release_on_restart INTEGER,created_at TEXT,updated_at TEXT,
          released_at TEXT,release_note TEXT);
        CREATE TABLE work_item_transition_ledger(seq INTEGER PRIMARY KEY AUTOINCREMENT,
          idempotency_key TEXT UNIQUE,ts TEXT,work_item_id TEXT,action TEXT,reason TEXT,
          run_id TEXT,detail_json TEXT);
        CREATE TABLE events(ts TEXT,entity_type TEXT,entity_id TEXT,event TEXT,detail_json TEXT);
        """
    )
    payload = json.dumps({"ea_label": ea_label, "mq5_sha256": source_sha})
    conn.execute("INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)", ("one", "QM5_1001", "COMPILE_EA", "pending", None, None, payload, "2026-01-01"))
    conn.execute("INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?,?)", ("one", rollout.HOLD_CODE, 1, 1, "2026-01-01", "2026-01-01", None, None))
    conn.commit()
    conn.close()
    return db, repo, source


def test_apply_releases_only_hold_and_records_audit(tmp_path):
    db, repo, _ = _fixture(tmp_path)
    result = rollout.apply_wave(db, repo, tmp_path / "backups", 1, "canary")
    assert result["applied"] == 1
    conn = sqlite3.connect(db)
    assert conn.execute("SELECT status FROM work_items WHERE id='one'").fetchone()[0] == "pending"
    assert conn.execute("SELECT active FROM work_item_holds WHERE work_item_id='one'").fetchone()[0] == 0
    assert conn.execute("SELECT action FROM work_item_transition_ledger").fetchone()[0] == "release_hold"
    conn.close()


def test_stale_source_is_deferred(tmp_path):
    db, repo, source = _fixture(tmp_path)
    source.write_text("changed\n", encoding="utf-8")
    plan = rollout.inspect(db, repo, 1)
    assert plan["release_count"] == 0
    assert plan["deferred"][0]["reason"] == "SOURCE_SHA_STALE_OR_MISSING"


def test_exact_selector_releases_only_requested_item(tmp_path):
    db, repo, _ = _fixture(tmp_path)
    with sqlite3.connect(db) as conn:
        payload = conn.execute(
            "SELECT payload_json FROM work_items WHERE id='one'"
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
            ("two", "QM5_1001", "COMPILE_EA", "pending", None, None, payload, "2026-01-02"),
        )
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?,?,?,?,?)",
            (
                "two",
                rollout.HOLD_CODE,
                1,
                1,
                "2026-01-02",
                "2026-01-02",
                None,
                None,
            ),
        )

    plan = rollout.inspect(db, repo, 1, "two")
    assert plan["work_item_id_selector"] == "two"
    assert [item["work_item_id"] for item in plan["release"]] == ["two"]

    result = rollout.apply_wave(db, repo, tmp_path / "backups", 1, "retry canary", "two")
    assert result["applied_work_item_ids"] == ["two"]
    with sqlite3.connect(db) as conn:
        holds = dict(conn.execute("SELECT work_item_id,active FROM work_item_holds"))
        detail = json.loads(
            conn.execute("SELECT detail_json FROM work_item_transition_ledger").fetchone()[0]
        )
    assert holds == {"one": 1, "two": 0}
    assert detail["work_item_id_selector"] == "two"
