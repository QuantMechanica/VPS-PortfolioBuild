"""Fixture tests for the repair-successor planner (no real hashes baked in).

Every disposition is driven by synthetic fixture rows + injected governed / git /
card stubs, so the test stays valid while live sources are re-patched.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm.session_tools import repair_successor_stale_compile_rows_0913 as tool

PHASE = "COMPILE_EA"


def _init_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, status TEXT,
            claimed_by TEXT, verdict TEXT, payload_json TEXT, created_at TEXT);
        CREATE TABLE work_item_supersedes(work_item_id TEXT, superseded_by_work_item_id TEXT);
        """
    )
    conn.commit()
    conn.close()


def _add(conn, wid, ea_id, label, pinned, *, status="pending", verdict=None,
         superseded_by=None, created="2026-01-01"):
    conn.execute(
        "INSERT INTO work_items(id,ea_id,phase,status,claimed_by,verdict,payload_json,created_at)"
        " VALUES(?,?,?,?,?,?,?,?)",
        (wid, ea_id, PHASE, status, None, verdict,
         json.dumps({"ea_label": label, "mq5_sha256": pinned}), created),
    )
    if superseded_by:
        conn.execute("INSERT INTO work_item_supersedes VALUES(?,?)", (wid, superseded_by))


def _src(repo: Path, label: str) -> str:
    p = repo / "framework" / "EAs" / label / f"{label}.mq5"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(f"// source {label}\n", encoding="utf-8")
    return tool.sha256_file(p)


@pytest.fixture()
def fx(tmp_path):
    repo = tmp_path / "repo"
    db = tmp_path / "farm.sqlite"
    _init_db(db)
    L = {
        "repair": "QM5_90101_repair", "snr": "QM5_90102_snr", "nbt": "QM5_90103_nbt",
        "noterm": "QM5_90104_noterm", "done": "QM5_90105_done",
        "pending": "QM5_90106_pending", "dirty": "QM5_90107_dirty",
    }
    cur = {k: _src(repo, v) for k, v in L.items()}
    OLD = tool.sha256_bytes(b"// old pinned\n")

    conn = sqlite3.connect(db)
    _add(conn, "f-repair", "QM5_90101", L["repair"], OLD, status="failed", verdict="COMPILE_FAIL")
    _add(conn, "f-snr", "QM5_90102", L["snr"], cur["snr"], status="failed", verdict="COMPILE_FAIL")
    _add(conn, "f-nbt", "QM5_90103", L["nbt"], OLD, status="failed", verdict="COMPILE_FAIL")
    # no terminal failure: superseded pending + done at OLD hash
    _add(conn, "p-noterm", "QM5_90104", L["noterm"], OLD, status="pending", superseded_by="x")
    _add(conn, "d-noterm", "QM5_90104", L["noterm"], OLD, status="done", verdict="COMPILE_OK")
    _add(conn, "d-done", "QM5_90105", L["done"], cur["done"], status="done", verdict="COMPILE_OK")
    _add(conn, "p-pending", "QM5_90106", L["pending"], cur["pending"], status="pending")
    _add(conn, "f-dirty", "QM5_90107", L["dirty"], OLD, status="failed", verdict="COMPILE_FAIL")
    conn.commit()
    conn.close()

    stub = {
        "f-repair": {"eligible": True, "reasons": [], "old_sha": OLD, "new_sha": cur["repair"], "build_task_id": "bt-1"},
        "f-snr": {"eligible": False, "reasons": ["SOURCE_NOT_REPAIRED", "BUILD_TASK_BINDING_NOT_REQUESTED"],
                  "old_sha": cur["snr"], "new_sha": cur["snr"], "build_task_id": None},
        "f-nbt": {"eligible": False, "reasons": ["BUILD_TASK_BINDING_NOT_OPEN"],
                  "old_sha": OLD, "new_sha": cur["nbt"], "build_task_id": "bt-closed"},
        "f-dirty": {"eligible": True, "reasons": [], "old_sha": OLD, "new_sha": cur["dirty"], "build_task_id": "bt-2"},
    }

    doc = tool.plan(
        repo_root=repo, db_path=db, targets=list(L.values() and [f"QM5_{n}" for n in
            ("90101", "90102", "90103", "90104", "90105", "90106", "90107")]),
        governed_repair_fn=lambda pid, ea: stub[pid],
        git_clean_fn=lambda lab: lab != L["dirty"],
        commit_info_fn=lambda lab: {"commit": "c" * 40, "short": "cccccccc",
                                    "date": "2026-09-13 00:00:00 +0000", "subject": f"fix {lab}"},
        card_fn=lambda lab, ea: ea == "QM5_90101",
    )
    return {"doc": doc, "L": L}


def _t(doc, ea_id):
    return next(t for t in doc["targets"] if t["ea_id"] == ea_id)


def test_repairable_is_planned(fx):
    t = _t(fx["doc"], "QM5_90101")
    assert t["action"] == "repair_successor" and t["reason"] == tool.R_REPAIR
    assert t["predecessor_work_item_id"] == "f-repair"
    assert t["build_task_id"] == "bt-1"
    assert t["rerun_reason"].startswith("source refreshed after enqueue: cccccccc")
    assert t["has_approved_card"] is True


def test_source_not_repaired_skipped(fx):
    assert _t(fx["doc"], "QM5_90102")["reason"] == tool.R_SOURCE_NOT_REPAIRED


def test_needs_build_task_flagged(fx):
    t = _t(fx["doc"], "QM5_90103")
    assert t["reason"] == tool.R_NEEDS_BUILD_TASK and t["needs_commission"] is True


def test_no_terminal_failure_needs_fresh_build(fx):
    t = _t(fx["doc"], "QM5_90104")
    assert t["reason"] == tool.R_NEEDS_FRESH_BUILD and t["needs_commission"] is True


def test_already_compiled_skipped(fx):
    assert _t(fx["doc"], "QM5_90105")["reason"] == tool.R_ALREADY_COMPILED


def test_already_pending_skipped(fx):
    assert _t(fx["doc"], "QM5_90106")["reason"] == tool.R_ALREADY_PENDING


def test_uncommitted_source_skipped(fx):
    assert _t(fx["doc"], "QM5_90107")["reason"] == tool.R_UNCOMMITTED


def test_plan_sha256_stable(fx):
    doc = fx["doc"]
    assert len(doc["plan_sha256"]) == 64 and doc["plan_sha256"] == tool._plan_sha256(doc)


def test_decision_matrix():
    d = tool.decide_ea_action
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=False, repairable=True,
             is_clean=True, has_terminal_failure=True, source_repaired=True) == ("repair_successor", tool.R_REPAIR)
    assert d(has_done_ok_at_current=True, has_fresh_pending_at_current=False, repairable=True,
             is_clean=True, has_terminal_failure=True, source_repaired=True) == ("skip", tool.R_ALREADY_COMPILED)
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=True, repairable=True,
             is_clean=True, has_terminal_failure=True, source_repaired=True) == ("skip", tool.R_ALREADY_PENDING)
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=False, repairable=True,
             is_clean=False, has_terminal_failure=True, source_repaired=True) == ("skip", tool.R_UNCOMMITTED)
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=False, repairable=False,
             is_clean=True, has_terminal_failure=False, source_repaired=False) == ("skip", tool.R_NEEDS_FRESH_BUILD)
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=False, repairable=False,
             is_clean=True, has_terminal_failure=True, source_repaired=False) == ("skip", tool.R_SOURCE_NOT_REPAIRED)
    assert d(has_done_ok_at_current=False, has_fresh_pending_at_current=False, repairable=False,
             is_clean=True, has_terminal_failure=True, source_repaired=True) == ("skip", tool.R_NEEDS_BUILD_TASK)
