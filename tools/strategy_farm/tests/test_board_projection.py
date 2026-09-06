"""Tests for board_projection.py (M15 action-guiding board).

A temp SQLite fixture stands in for the production farm DB and exercises every
class (actionable / waiting / parked / superseded / complete), the waiting-reason
mapping, the lane split, deterministic ordering, and the UNKNOWN-never-zero KPI
strip. Nothing here touches D:/QM production state — all IO is under tmp_path.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import board_projection as bp  # noqa: E402

NOW = datetime(2026, 9, 6, 12, 0, 0, tzinfo=timezone.utc)

_SCHEMA = """
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY,
    task_type TEXT,
    state TEXT,
    priority INTEGER,
    required_capabilities_json TEXT,
    assigned_agent TEXT,
    budget_class TEXT,
    parent_id TEXT,
    artifact_path TEXT,
    verdict TEXT,
    payload_json TEXT,
    created_at TEXT,
    updated_at TEXT,
    required_skills_json TEXT
);
"""


def _row(
    id, state, *, agent=None, priority=50, task_type="ops_issue",
    payload=None, created="2026-09-01T00:00:00+00:00",
):
    return {
        "id": id,
        "task_type": task_type,
        "state": state,
        "priority": priority,
        "assigned_agent": agent,
        "payload_json": json.dumps(payload or {}),
        "created_at": created,
        "updated_at": created,
    }


# Rows: at least one per class, spread across every lane.
ROWS = [
    # --- actionable ---
    _row("a-todo-unassigned", "TODO", agent=None, priority=70,
         payload={"title": "unassigned todo needs routing"}),
    _row("a-inprogress-claude", "IN_PROGRESS", agent="claude",
         payload={"title": "claude work in flight"}),
    _row("a-recycle-gemini", "RECYCLE", agent="gemini",
         payload={"title": "recycle needs rework"}),
    _row("a-opsfix-codexwt", "OPS_FIX_REQUIRED", agent="codex:agents/board-advisor",
         payload={"title": "ops fix required"}),
    _row("a-failed-claude", "FAILED", agent="claude",
         payload={"title": "failed, not superseded"}),
    # --- waiting ---
    _row("w-ownerhold", "BLOCKED", agent=None,
         payload={"title": "owner video lane hold",
                  "router_human_lane_hold": {"code": "ROUTER_AWAITING_HUMAN_LANE",
                                             "lane": "owner"}}),
    _row("w-review", "REVIEW", agent="codex",
         payload={"title": "in review"}),
    _row("w-pipeline", "PIPELINE", agent="codex",
         payload={"title": "in the automated pipeline"}),
    _row("w-dependency", "TODO", agent="claude",
         payload={"title": "depends on another task",
                  "depends_on": ["some-other-id"]}),
    _row("w-decision-todo", "TODO", agent="claude",
         payload={"title": "blocked on an open owner decision",
                  "owner_decision": {"question": "Do X?"}}),
    _row("w-decision-blocked", "BLOCKED", agent="codex",
         payload={"title": "blocked pending owner decision",
                  "owner_decision": {"question": "Approve Y?"}}),
    _row("w-codexlane", "TODO", agent="codex",
         payload={"title": "commissioned to codex, queued"}),
    # --- parked ---
    _row("p-deprioritised", "BLOCKED", agent="gemini",
         payload={"title": "deprioritised build",
                  "orchestrator_deprioritised": {"reason": "registry precondition missing",
                                                 "by": "claude-orchestrator"}}),
    _row("p-blockedreason", "BLOCKED", agent="codex",
         payload={"title": "hard precondition block",
                  "blocked_reason": "host CPU ceiling exceeded"}),
    _row("p-todo-deprioritised", "TODO", agent="gemini",
         payload={"title": "todo but deprioritised",
                  "orchestrator_deprioritised": {"reason": "reservoir full"}}),
    _row("p-blocked-noreason", "BLOCKED", agent="codex",
         payload={"title": "blocked, no explicit reason"}),
    # --- superseded ---
    _row("s-old", "FAILED", agent="codex",
         payload={"title": "old attempt, replaced"}),
    _row("s-new", "IN_PROGRESS", agent="codex",
         payload={"title": "successor", "supersedes": "s-old"}),
    # --- complete ---
    _row("c-passed", "PASSED", agent="codex",
         payload={"title": "passed"}),
    _row("c-approved-decision", "APPROVED", agent="codex",
         payload={"title": "approved decision execution (complete beats decision)",
                  "owner_decision": {"choice": "YES", "decision_id": "OWNER-DEC-X"}}),
    # --- owner lane, explicitly assigned ---
    _row("o-owner-todo", "TODO", agent="owner", priority=90,
         payload={"title": "owner-assigned task"}),
]


def _make_db(tmp_path: Path) -> Path:
    db = tmp_path / "farm_state.sqlite"
    con = sqlite3.connect(db)
    con.executescript(_SCHEMA)
    cols = ["id", "task_type", "state", "priority", "assigned_agent",
            "payload_json", "created_at", "updated_at"]
    con.executemany(
        f"INSERT INTO agent_tasks ({','.join(cols)}) VALUES ({','.join('?' * len(cols))})",
        [tuple(r[c] for c in cols) for r in ROWS],
    )
    con.commit()
    con.close()
    return db


def _proj(tmp_path):
    return bp.build_from_db(_make_db(tmp_path), now=NOW)


# ---------------------------------------------------------------------------
def test_every_class_populated(tmp_path):
    counts = _proj(tmp_path)["task_projection"]["counts"]
    for cls in bp.CLASSES:
        assert counts[cls] > 0, f"{cls} should have at least one row"
    assert sum(counts.values()) == len(ROWS)


def test_class_counts_exact(tmp_path):
    counts = _proj(tmp_path)["task_projection"]["counts"]
    assert counts == {
        # todo-unassigned, inprogress, recycle, opsfix, failed, s-new successor, owner-todo
        "actionable": 7,
        "waiting": 7,      # ownerhold, review, pipeline, dependency, decision-todo,
                           # decision-blocked, codexlane
        "parked": 4,       # deprioritised, blockedreason, todo-deprioritised, blocked-noreason
        "superseded": 1,   # s-old
        "complete": 2,     # passed, approved
    }, counts


def test_superseded_beats_actionable(tmp_path):
    # s-old is FAILED (would be actionable) but is replaced -> superseded.
    rows = _proj(tmp_path)["task_projection"]["rows"]
    superseded_ids = {v["id"] for v in rows["superseded"]}
    actionable_ids = {v["id"] for v in rows["actionable"]}
    assert "s-old" in superseded_ids
    assert "s-old" not in actionable_ids


def test_complete_beats_decision_marker(tmp_path):
    # APPROVED row carrying an owner_decision must be complete, not waiting.
    proj = _proj(tmp_path)
    waiting_ids = {v["id"] for v in proj["task_projection"]["rows"]["waiting"]}
    assert "c-approved-decision" not in waiting_ids
    assert proj["task_projection"]["counts"]["complete"] == 2


def test_waiting_reasons_mapping(tmp_path):
    wr = _proj(tmp_path)["task_projection"]["waiting_reasons"]
    assert wr["awaiting_owner_receipt"] == 1   # w-ownerhold
    assert wr["awaiting_review"] == 1          # w-review
    assert wr["awaiting_pipeline"] == 1        # w-pipeline
    assert wr["awaiting_dependency"] == 1      # w-dependency
    assert wr["decision-bound"] == 2           # w-decision-todo + w-decision-blocked
    assert wr["awaiting_codex_lane"] == 1      # w-codexlane
    assert sum(wr.values()) == 7


def test_lane_split(tmp_path):
    by_lane = _proj(tmp_path)["task_projection"]["by_lane"]
    for lane in bp.LANES:
        assert lane in by_lane
    # codex:agents/board-advisor normalises to codex.
    assert by_lane["codex"]["actionable"] >= 1  # a-opsfix-codexwt
    # gemini -> agy/gemini.
    assert by_lane["agy/gemini"]["actionable"] == 1   # a-recycle-gemini
    assert by_lane["agy/gemini"]["parked"] == 2       # p-deprioritised + p-todo-deprioritised
    # owner via explicit assignment AND via human-lane hold on an unassigned row.
    assert by_lane["owner"]["actionable"] == 1        # o-owner-todo
    assert by_lane["owner"]["waiting"] == 1           # w-ownerhold (unassigned, owner hold)
    assert by_lane["claude"]["actionable"] >= 2       # inprogress + failed


def test_next_action_only_on_actionable(tmp_path):
    rows = _proj(tmp_path)["task_projection"]["rows"]
    for v in rows["actionable"]:
        assert v.get("next_action")
        assert "reason" not in v
    for cls in ("waiting", "parked", "superseded"):
        for v in rows[cls]:
            assert v.get("reason")
            assert "next_action" not in v


def test_park_reason_surfaced_or_unknown(tmp_path):
    rows = {v["id"]: v for v in _proj(tmp_path)["task_projection"]["rows"]["parked"]}
    assert "registry precondition missing" in rows["p-deprioritised"]["reason"]
    assert rows["p-blockedreason"]["reason"] == "host CPU ceiling exceeded"
    assert rows["p-blocked-noreason"]["reason"] == "UNKNOWN"


def test_deterministic_ordering(tmp_path):
    actionable = _proj(tmp_path)["task_projection"]["rows"]["actionable"]
    keys = [(-v["priority"], -v["age_days"], v["id"]) for v in actionable]
    assert keys == sorted(keys)
    # Highest priority first: o-owner-todo (90) leads the actionable list.
    assert actionable[0]["id"] == "o-owner-todo"


def test_age_days_from_created(tmp_path):
    rows = {v["id"]: v for v in _proj(tmp_path)["task_projection"]["rows"]["actionable"]}
    # created 2026-09-01T00:00 -> NOW 2026-09-06T12:00 == 5.5 days.
    assert rows["a-todo-unassigned"]["age_days"] == 5.5


def test_kpi_strip_all_unknown_never_zero(tmp_path):
    kpis = _proj(tmp_path)["company_kpis"]
    assert set(kpis) == set(bp.KPI_SOURCES)
    for name, kpi in kpis.items():
        assert kpi["value"] == "UNKNOWN"
        assert kpi["value"] != 0
        assert kpi["source"]


def test_diagnostics_present(tmp_path):
    diag = _proj(tmp_path)["diagnostics"]
    assert diag["total_tasks"] == len(ROWS)
    assert diag["by_state"]  # per-state counts
    assert diag["tester_utilisation"]["value"] == "UNKNOWN"


def test_markdown_renders(tmp_path):
    md = bp.render_markdown(_proj(tmp_path))
    assert "# Action-guiding board" in md
    assert "Net KPIs" in md
    assert "UNKNOWN" in md
    for cls in bp.CLASSES:
        assert cls in md


def test_atomic_write_roundtrip(tmp_path):
    proj = _proj(tmp_path)
    out = tmp_path / "sub" / "board_projection.json"
    bp._atomic_write_json(out, proj)
    assert out.exists()
    reloaded = json.loads(out.read_text(encoding="utf-8"))
    assert reloaded["schema"] == bp.SCHEMA
    assert reloaded["task_projection"]["counts"] == proj["task_projection"]["counts"]


def test_read_only_open_does_not_mutate(tmp_path):
    db = _make_db(tmp_path)
    conn = bp.open_ro(db)
    try:
        with_error = False
        try:
            conn.execute("INSERT INTO agent_tasks (id) VALUES ('x')")
            conn.commit()
        except sqlite3.OperationalError:
            with_error = True
        assert with_error, "read-only connection must refuse writes"
    finally:
        conn.close()
