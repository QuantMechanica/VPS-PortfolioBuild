"""Fixture tests for the stale COMPILE_EA rollout re-issue planner.

Covers the disposition matrix on a temp sqlite fixture + temp EA sources:
  * stale held eligible clean            -> reissue (planned successor)
  * fresh row (pinned == on-disk)        -> untouched (absent from plan)
  * stale held eligible but DIRTY source -> skip (uncommitted, excluded)
  * stale held but library not-eligible  -> skip (not eligible)
  * stale held but predecessor superseded-> skip (would refuse at apply)
  * non-held stale, done at current      -> skip (vestigial)
  * non-held stale, not done at current  -> skip (orphan, separate path)
Plus direct unit tests of the pure decision function.
"""
from __future__ import annotations

import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm.session_tools import reissue_stale_compile_rows_0913 as tool

PHASE = "COMPILE_EA"


def _init_db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(
            id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, status TEXT,
            claimed_by TEXT, verdict TEXT, payload_json TEXT, created_at TEXT);
        CREATE TABLE work_item_holds(
            work_item_id TEXT, hold_code TEXT, active INTEGER);
        CREATE TABLE work_item_supersedes(
            work_item_id TEXT, superseded_by_work_item_id TEXT);
        """
    )
    conn.commit()
    conn.close()


def _add_row(conn, wid, ea_id, label, pinned_sha, *, status="pending",
             verdict=None, claimed=None, held=False, superseded_by=None, created="2026-01-01"):
    payload = json.dumps({"ea_label": label, "mq5_sha256": pinned_sha})
    conn.execute(
        "INSERT INTO work_items(id,ea_id,phase,status,claimed_by,verdict,payload_json,created_at)"
        " VALUES(?,?,?,?,?,?,?,?)",
        (wid, ea_id, PHASE, status, claimed, verdict, payload, created),
    )
    if held:
        conn.execute(
            "INSERT INTO work_item_holds(work_item_id,hold_code,active) VALUES(?,?,1)",
            (wid, tool.ROLLOUT_HOLD_CODE),
        )
    if superseded_by:
        conn.execute(
            "INSERT INTO work_item_supersedes(work_item_id,superseded_by_work_item_id) VALUES(?,?)",
            (wid, superseded_by),
        )


def _write_source(repo: Path, label: str, content: str) -> str:
    p = repo / "framework" / "EAs" / label / f"{label}.mq5"
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(content, encoding="utf-8")
    return tool.sha256_file(p)


@pytest.fixture()
def fixture(tmp_path):
    repo = tmp_path / "repo"
    db = tmp_path / "farm.sqlite"
    _init_db(db)

    labels = {
        "stale": "QM5_90001_stale",
        "fresh": "QM5_90002_fresh",
        "dirty": "QM5_90003_dirty",
        "notelig": "QM5_90005_notelig",
        "superseded": "QM5_90006_superseded",
        "vestigial": "QM5_90007_vestigial",
        "orphan": "QM5_90008_orphan",
    }
    # On-disk content -> current sha for each EA.
    cur = {k: _write_source(repo, lab, f"// current source for {lab}\n") for k, lab in labels.items()}
    old = tool.sha256_bytes(b"// stale pinned content\n")

    conn = sqlite3.connect(db)
    # stale held eligible clean -> reissue
    _add_row(conn, "w-stale", "QM5_90001", labels["stale"], old, held=True)
    # fresh -> pinned equals on-disk
    _add_row(conn, "w-fresh", "QM5_90002", labels["fresh"], cur["fresh"], held=True)
    # dirty source (git stub reports dirty) -> skip uncommitted
    _add_row(conn, "w-dirty", "QM5_90003", labels["dirty"], old, held=True)
    # library not eligible -> skip
    _add_row(conn, "w-notelig", "QM5_90005", labels["notelig"], old, held=True)
    # predecessor already superseded -> skip
    _add_row(conn, "w-sup", "QM5_90006", labels["superseded"], old, held=True,
             superseded_by="some-successor")
    # non-held stale, EA has done COMPILE_OK at current -> vestigial
    _add_row(conn, "w-vest", "QM5_90007", labels["vestigial"], old, held=False)
    _add_row(conn, "w-vest-ok", "QM5_90007", labels["vestigial"], cur["vestigial"],
             status="done", verdict="COMPILE_OK")
    # non-held stale, no done at current -> orphan
    _add_row(conn, "w-orphan", "QM5_90008", labels["orphan"], old, held=False)
    conn.commit()
    conn.close()

    def governed(lab_list):
        table = {
            labels["stale"]: {"eligible": True, "reasons": [], "new_sha": cur["stale"], "predecessor_ids": ["w-stale"]},
            labels["dirty"]: {"eligible": True, "reasons": [], "new_sha": cur["dirty"], "predecessor_ids": ["w-dirty"]},
            labels["notelig"]: {"eligible": False, "reasons": ["USABLE_CURRENT_COMPILE_VERDICT_EXISTS"], "new_sha": cur["notelig"], "predecessor_ids": ["w-notelig"]},
            labels["superseded"]: {"eligible": True, "reasons": [], "new_sha": cur["superseded"], "predecessor_ids": ["w-sup"]},
            labels["fresh"]: {"eligible": True, "reasons": [], "new_sha": cur["fresh"], "predecessor_ids": []},
        }
        return {lab: table[lab] for lab in lab_list if lab in table}

    def git_clean(lab):
        return lab != labels["dirty"]

    def commit_info(lab):
        return {"commit": "deadbeef" * 5, "short": "deadbeef", "date": "2026-09-13 00:00:00 +0000",
                "subject": f"patch {lab}"}

    doc = tool.plan(
        repo_root=repo, db_path=db,
        governed_eligibility_fn=governed, git_clean_fn=git_clean, commit_info_fn=commit_info,
    )
    return {"doc": doc, "labels": labels, "db": db, "repo": repo, "cur": cur}


def _row(doc, wid):
    return next((r for r in doc["rows"] if r["work_item_id"] == wid), None)


def test_stale_held_eligible_clean_is_reissued(fixture):
    doc, labels, cur = fixture["doc"], fixture["labels"], fixture["cur"]
    row = _row(doc, "w-stale")
    assert row is not None and row["action"] == "reissue"
    assert row["new_sha"] == cur["stale"]
    entry = next(e for e in doc["reissue_labels"] if e["ea_label"] == labels["stale"])
    assert entry["action"] == "reissue"
    assert entry["predecessor_work_item_ids"] == ["w-stale"]
    assert entry["rerun_reason"].startswith("source refreshed after enqueue: deadbeef")


def test_fresh_row_is_untouched(fixture):
    doc = fixture["doc"]
    assert _row(doc, "w-fresh") is None  # not stale -> not in dispositions
    assert doc["counts"]["fresh_untouched"] >= 1
    assert all(e["ea_label"] != fixture["labels"]["fresh"] for e in doc["reissue_labels"])


def test_uncommitted_source_is_skipped(fixture):
    row = _row(fixture["doc"], "w-dirty")
    assert row["action"] == "skip"
    assert row["reason"] == tool.R_UNCOMMITTED
    assert all(e["ea_label"] != fixture["labels"]["dirty"] for e in fixture["doc"]["reissue_labels"])


def test_not_eligible_is_skipped(fixture):
    row = _row(fixture["doc"], "w-notelig")
    assert row["action"] == "skip"
    assert row["reason"].startswith(tool.R_NOT_ELIGIBLE)
    assert "USABLE_CURRENT_COMPILE_VERDICT_EXISTS" in row["reason"]


def test_already_superseded_predecessor_is_skipped(fixture):
    row = _row(fixture["doc"], "w-sup")
    assert row["action"] == "skip"
    assert row["reason"] == tool.R_PRED_SUPERSEDED


def test_non_held_vestigial_and_orphan(fixture):
    assert _row(fixture["doc"], "w-vest")["reason"] == tool.R_VESTIGIAL
    assert _row(fixture["doc"], "w-orphan")["reason"] == tool.R_ORPHAN


def test_plan_sha256_is_stable_and_content_addressed(fixture):
    doc = fixture["doc"]
    assert len(doc["plan_sha256"]) == 64
    assert doc["plan_sha256"] == tool._plan_sha256(doc)


def test_plan_is_read_only(fixture):
    conn = sqlite3.connect(fixture["db"])
    n = conn.execute("SELECT count(*) FROM work_items").fetchone()[0]
    conn.close()
    assert n == 8  # unchanged by planning


def test_decide_label_action_matrix():
    assert tool.decide_label_action(governed_eligible=True, governed_reasons=[],
                                    any_predecessor_superseded=False, is_clean=True) == ("reissue", tool.R_REISSUE)
    assert tool.decide_label_action(governed_eligible=False, governed_reasons=["X"],
                                    any_predecessor_superseded=False, is_clean=True)[0] == "skip"
    assert tool.decide_label_action(governed_eligible=True, governed_reasons=[],
                                    any_predecessor_superseded=True, is_clean=True) == ("skip", tool.R_PRED_SUPERSEDED)
    assert tool.decide_label_action(governed_eligible=True, governed_reasons=[],
                                    any_predecessor_superseded=False, is_clean=False) == ("skip", tool.R_UNCOMMITTED)
