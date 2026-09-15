"""Tests for the stale-task disposition classifier + gated applier (§18)."""
from __future__ import annotations

import datetime as dt
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm.session_tools import apply_stale_task_dispositions as ap


NOW = dt.datetime(2026, 9, 15, tzinfo=dt.timezone.utc)

DDL = """
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY, task_type TEXT, state TEXT, priority INTEGER,
    required_capabilities_json TEXT, required_skills_json TEXT,
    payload_json TEXT, verdict TEXT, created_at TEXT, updated_at TEXT
);
"""


def _iso(days_ago):
    return (NOW - dt.timedelta(days=days_ago)).replace(microsecond=0).isoformat()


@pytest.fixture()
def db(tmp_path):
    path = tmp_path / "f.sqlite"
    con = sqlite3.connect(path)
    con.executescript(DDL)

    def ins(tid, ttype, state, prio, payload, verdict, age, skills="[]"):
        con.execute(
            "INSERT INTO agent_tasks (id,task_type,state,priority,"
            "required_capabilities_json,required_skills_json,payload_json,verdict,"
            "created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
            (tid, ttype, state, prio, "[]", skills, payload, verdict,
             _iso(age), _iso(0)))

    ins("rev", "review_ea", "TODO", 40, "{}", None, 5)                       # COMMISSION claude
    ins("legacy", "build_ea", "TODO", 40, "{}", None, 70)                    # PARK legacy
    ins("recent", "build_ea", "TODO", 40, "{}", None, 3)                     # KEEP
    ins("hi", "build_ea", "TODO", 80, "{}", None, 70)                        # KEEP (prio)
    ins("magic", "build_ea", "BLOCKED", 40, "{}",
        "PRECONDITION_HOLD_MAGIC_ROWS_REQUIRED", 70)                          # PARK precondition
    ins("retired", "build_ea", "BLOCKED", 40, "{}",
        "PRECONDITION_HOLD: ea_id 2354 unregistered; related 12314 OWNER-retired", 70)  # CLOSE
    ins("drain", "ops_issue", "TODO", 40, '{"summary":"global drain first"}', None, 5)  # CLOSE superseded
    ins("ops", "ops_issue", "TODO", 40, "{}", None, 5)                       # COMMISSION codex
    ins("agedops", "ops_issue", "TODO", 40, "{}", None, 40)                  # PARK aged
    ins("vid", "ops_issue", "TODO", 40, "{}", None, 5, '["video_analysis"]')  # PARK owner
    ins("res", "research_strategy", "TODO", 40, "{}", None, 5)              # COMMISSION gemini
    ins("agedres", "research_strategy", "TODO", 40, "{}", None, 40)         # PARK throttled
    con.commit(); con.close()
    return path


def _by_id(records):
    return {r["id"]: r for r in records}


def test_classification_rules(db):
    recs = _by_id(ap.classify_all(db, now=NOW))
    assert recs["rev"]["disposition"] == "COMMISSION" and recs["rev"]["target_lane"] == "claude"
    assert recs["legacy"]["disposition"] == "PARK" and "legacy_build_backlog" in recs["legacy"]["reason"]
    assert recs["recent"]["disposition"] == "KEEP"
    assert recs["hi"]["disposition"] == "KEEP"
    assert recs["magic"]["disposition"] == "PARK" and "magic_registry" in recs["magic"]["reason"]
    assert recs["retired"]["disposition"] == "CLOSE" and "owner_retired" in recs["retired"]["reason"]
    assert recs["drain"]["disposition"] == "CLOSE" and "superseded_by_CBE" in recs["drain"]["reason"]
    assert recs["ops"]["disposition"] == "COMMISSION" and recs["ops"]["target_lane"] == "codex"
    assert recs["agedops"]["disposition"] == "PARK"
    assert recs["vid"]["disposition"] == "PARK" and recs["vid"]["target_lane"] == "owner"
    assert recs["res"]["disposition"] == "COMMISSION" and recs["res"]["target_lane"] == "gemini"
    assert recs["agedres"]["disposition"] == "PARK"


def test_candidate_guard_skips_build_ea_without_optin(db, tmp_path):
    recs = ap.classify_all(db, now=NOW)
    plan = tmp_path / "plan.csv"
    ap.write_plan_csv(recs, plan)
    # dry-run, no opt-in: every build_ea PARK/CLOSE is skipped by the guard
    summary = ap.run_plan(plan, apply=False, allow_park=False, allow_close=False)
    skipped_ids = {a["id"] for a in summary["actions"] if a["action"] == "SKIP"}
    assert {"legacy", "magic", "retired"}.issubset(skipped_ids)
    # non-candidate dispositions still produce a (dry-run) command
    dry_ids = {a["id"] for a in summary["actions"] if a["action"] == "DRY_RUN"}
    assert "rev" in dry_ids and "ops" in dry_ids


def test_candidate_guard_optin_allows_park(db, tmp_path):
    recs = ap.classify_all(db, now=NOW)
    plan = tmp_path / "plan.csv"
    ap.write_plan_csv(recs, plan)
    summary = ap.run_plan(plan, apply=False, allow_park=True, allow_close=False)
    dry_ids = {a["id"] for a in summary["actions"] if a["action"] == "DRY_RUN"}
    assert "legacy" in dry_ids and "magic" in dry_ids   # PARK now permitted
    skipped_ids = {a["id"] for a in summary["actions"] if a["action"] == "SKIP"}
    assert "retired" in skipped_ids                      # CLOSE still guarded


def test_router_command_shapes(db):
    recs = _by_id(ap.classify_all(db, now=NOW))
    close_cmd = ap._router_command(recs["retired"])
    assert close_cmd[2:5] == ["update-task", "retired", "--state"]
    assert "SUPERSEDED_CBE_DISPOSITION" in close_cmd[-1]
    park_cmd = ap._router_command(recs["magic"])
    assert "update-task" in park_cmd and "BLOCKED" in park_cmd
    keep_cmd = ap._router_command(recs["recent"])
    assert keep_cmd is None
