import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import blocked_agent_task_sweeper as sweeper


def _db(root: Path) -> Path:
    path = root / "state" / "farm_state.sqlite"
    path.parent.mkdir(parents=True)
    con = sqlite3.connect(path)
    con.executescript(
        """
        CREATE TABLE agent_tasks(
          id TEXT PRIMARY KEY, task_type TEXT, state TEXT, priority INTEGER,
          required_capabilities_json TEXT, required_skills_json TEXT,
          assigned_agent TEXT, budget_class TEXT, parent_id TEXT,
          artifact_path TEXT, verdict TEXT, payload_json TEXT,
          created_at TEXT, updated_at TEXT
        );
        CREATE TABLE events(id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT,
          entity_type TEXT, entity_id TEXT,event TEXT,detail_json TEXT);
        CREATE TABLE leases(resource_key TEXT PRIMARY KEY, owner TEXT, expires_at TEXT, created_at TEXT, updated_at TEXT);
        """
    )
    con.commit(); con.close()
    return path


def _insert(db: Path, *, task_id="t1", verdict="PRECONDITION_HOLD_REGISTRY_AND_MAGIC_REQUIRED", skills=None, task_type="build_ea", agent="codex", state="BLOCKED", payload=None):
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO agent_tasks VALUES(?,?,?,50,'[]',?,?, 'standard',NULL,NULL,?,?,?,?)",
        (task_id, task_type, state, json.dumps(skills or []), agent, verdict,
         json.dumps(payload or {"ea_id":"QM5_9999","title":"fixture"}), "2026-08-01T00:00:00Z", "2026-08-01T00:00:00Z"),
    )
    con.commit(); con.close()


def test_plan_is_read_only_and_reports_fresh_ready_magic(tmp_path: Path):
    root = tmp_path / "farm"; db = _db(root); _insert(db)
    cards = tmp_path / "cards"; cards.mkdir(); (cards / "QM5_9999_fixture.md").write_text("x")
    plan = sweeper.build_plan(root, repo=tmp_path, cards_dir=cards,
                              precheck_fn=lambda card, repo: {"ready": True, "action": "NONE", "classification": "ready"})
    assert plan["counts"] == {"MAGIC_PRECONDITION:TODO": 1}
    con = sqlite3.connect(db)
    assert con.execute("SELECT state FROM agent_tasks").fetchone()[0] == "BLOCKED"
    con.close()


def test_apply_appends_journal_preserves_verdict_and_requeues(tmp_path: Path):
    root = tmp_path / "farm"; db = _db(root); _insert(db)
    finding = {"task_id":"t1","class":"MAGIC_PRECONDITION","disposition":"TODO","reason":"fresh_precheck_ready"}
    result = sweeper.apply_plan(root, {"rows":[finding]}, apply_classes={"MAGIC_PRECONDITION"}, limit=1, now="2026-09-12T00:00:00+00:00")
    assert result["applied_count"] == 1
    con = sqlite3.connect(db); con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM agent_tasks").fetchone(); payload = json.loads(row["payload_json"])
    assert row["state"] == "TODO" and row["assigned_agent"] is None
    assert row["verdict"] == "PRECONDITION_HOLD_REGISTRY_AND_MAGIC_REQUIRED"
    assert payload["decision_bound_agent"] == "codex"
    assert payload["blocked_backlog_journal"][0]["previous_verdict"] == row["verdict"]
    assert con.execute("SELECT event FROM events").fetchone()[0] == "blocked_backlog_disposition"
    con.close()


def test_video_is_never_selected_for_apply(tmp_path: Path):
    root = tmp_path / "farm"; db = _db(root)
    _insert(db, verdict="router_human_lane_hold", skills=["video_analysis"], task_type="research_strategy", agent=None)
    cards = tmp_path / "cards"; cards.mkdir()
    plan = sweeper.build_plan(root, repo=tmp_path, cards_dir=cards)
    assert plan["counts"] == {"VIDEO_HOLD:SKIP": 1}
    result = sweeper.apply_plan(root, plan, apply_classes={"LEGACY_RESEARCH"}, limit=1)
    assert result["applied_count"] == 0
    con = sqlite3.connect(db)
    assert con.execute("SELECT state FROM agent_tasks").fetchone()[0] == "BLOCKED"
    con.close()


def test_terminal_close_disposition_uses_close_text():
    row = {"id":"x","state":"BLOCKED","assigned_agent":"codex","task_type":"ops_issue","updated_at":"z",
           "payload_json":"{}","required_skills_json":"[]",
           "verdict":"CLAUDE CORRECTION: approval withdrawn; rework required"}
    class R(dict):
        __getattr__ = dict.__getitem__
    result = sweeper.classify_row(R(row))
    assert (result["class"], result["disposition"]) == ("TERMINAL_CLOSE", "RECYCLE")


def test_requeued_legacy_agy_is_included_only_with_explicit_switch(tmp_path: Path):
    root = tmp_path / "farm"; db = _db(root)
    payload = {"backlog_disposition_journal": [{
        "decision":"OWNER-DEC-BACKLOG-20260912", "from_state":"RECYCLE",
        "previous_assigned_agent":"gemini"}]}
    _insert(db, state="TODO", agent=None, payload=payload)
    cards = tmp_path / "cards"; cards.mkdir()
    assert sweeper.build_plan(root, repo=tmp_path, cards_dir=cards)["rows"] == []
    plan = sweeper.build_plan(root, repo=tmp_path, cards_dir=cards, include_requeued_legacy=True)
    assert plan["counts"] == {"LEGACY_RESEARCH:FAILED": 1}
    result = sweeper.apply_plan(root, plan, apply_classes={"LEGACY_RESEARCH"}, limit=1)
    assert result["applied_count"] == 1
    con = sqlite3.connect(db)
    assert con.execute("SELECT state FROM agent_tasks").fetchone()[0] == "FAILED"
    con.close()

    restore = sweeper.build_legacy_restore_plan(root)
    assert restore["counts"] == {"LEGACY_REQUEUE_RESTORE:TODO": 1}
    result = sweeper.apply_plan(root, restore, apply_classes={"LEGACY_REQUEUE_RESTORE"}, limit=1)
    assert result["applied_count"] == 1
    con = sqlite3.connect(db); con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM agent_tasks").fetchone()
    assert row["state"] == "TODO"
    assert len(json.loads(row["payload_json"])["blocked_backlog_journal"]) == 2
    con.close()
