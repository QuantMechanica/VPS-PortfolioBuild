"""Tests for the second-chance funnel read-model (qm.second-chance-funnel/v1).

Deterministic, hermetic: an in-memory farm DB plus tmp cards_review/ and
pipeline/ trees drive every stage. No live D:/QM surface is read (paths are
passed explicitly / monkeypatched). The suite also pins the READ-MODEL
contract: building the funnel must not write a single DB row.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.strategy_farm import second_chance_funnel as scf


NOW = dt.datetime(2026, 9, 16, 12, 0, 0, tzinfo=dt.timezone.utc)

DDL = """
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY, task_type TEXT, state TEXT, verdict TEXT,
    payload_json TEXT, created_at TEXT, updated_at TEXT
);
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, ea_id TEXT, phase TEXT, status TEXT,
    payload_json TEXT, created_at TEXT, updated_at TEXT
);
CREATE TABLE portfolio_candidates (
    ea_id TEXT, symbol TEXT, q11_work_item_id TEXT,
    state TEXT DEFAULT 'Q12_REVIEW_READY'
);
"""

TASK_ID = "b0ef5d66-5947-4d79-ad72-02f2caee04cb"
OTHER_ID = "27ae17d6-beb8-416c-9c25-fade17603fe9"


def _payload(task_id, origin, *, source="second_chance_wave1", reason="INFRA_FAIL",
             slug="connors-rsi2"):
    return json.dumps({
        "kind": "second_chance_retest",
        "origin_ea_id": origin,
        "origin_slug": slug,
        "second_chance_reason": reason,
        "lineage": "NEW",
        "provenance": {"source": source,
                       "commissioned_at_utc": "2026-09-15T20:51:04+00:00"},
    })


@pytest.fixture()
def con() -> sqlite3.Connection:
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    c.executescript(DDL)
    return c


def _task(c, task_id, state, payload, verdict=None):
    c.execute(
        "INSERT INTO agent_tasks VALUES (?,?,?,?,?,?,?)",
        (task_id, "research_strategy", state, verdict, payload,
         "2026-09-15T20:51:20+00:00", "2026-09-15T21:07:50+00:00"),
    )


def _cards(tmp_path: Path) -> Path:
    d = tmp_path / "cards_review"
    d.mkdir()
    return d


# ---------------------------------------------------------------------------
# candidate loading
# ---------------------------------------------------------------------------
def test_load_candidates_filters_exact_kind(con):
    _task(con, TASK_ID, "REVIEW", _payload(TASK_ID, "QM5_11563"))
    # mentions the marker string but is NOT a second-chance ticket
    _task(con, OTHER_ID, "TODO", json.dumps({
        "kind": "research_task",
        "notes": "see kind=second_chance_retest template",
    }))
    cands = scf.load_candidates(con)
    assert [c["task_id"] for c in cands] == [TASK_ID]
    assert cands[0]["payload"]["origin_ea_id"] == "QM5_11563"


# ---------------------------------------------------------------------------
# stage classification
# ---------------------------------------------------------------------------
def test_review_state_with_pending_card_reaches_card_stage(con, tmp_path):
    _task(con, TASK_ID, "REVIEW", _payload(TASK_ID, "QM5_11563"),
          verdict="REVIEW_READY: card drafted under PENDING_B0EF5D66")
    cards = _cards(tmp_path)
    (cards / "PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md"
     ).write_text("# card", encoding="utf-8")
    cands = scf.load_candidates(con)
    result = scf.classify_candidate(
        cands[0], con, cards_review_dir=cards, pipeline_dir=tmp_path / "pipe")
    assert result["furthest_stage"] == "new-lineage-card"
    assert result["stages"]["commissioned"]["reached"] is True
    assert result["stages"]["review"]["reached"] is True
    assert result["stages"]["new-lineage-card"]["reached"] is True
    assert result["stages"]["new-lineage-card"]["evidence"][0].endswith(
        "PENDING_B0EF5D66_connors-rsi2-sma200-mean-reversion-d1.md")
    for stage in ("intake-q00", "factory-work-item", "mt5-evidence",
                  "portfolio-evaluated"):
        assert result["stages"][stage]["reached"] is False
    assert result["wave"] == "second_chance_wave1"


def test_in_progress_without_card_stays_at_commissioned(con, tmp_path):
    _task(con, OTHER_ID, "IN_PROGRESS", _payload(
        OTHER_ID, "QM5_11373", source="second_chance_wave2",
        reason="MULTI_POSITION", slug="100pips"))
    cands = scf.load_candidates(con)
    result = scf.classify_candidate(
        cands[0], con, cards_review_dir=_cards(tmp_path),
        pipeline_dir=tmp_path / "pipe")
    assert result["furthest_stage"] == "commissioned"
    assert result["stages"]["review"]["reached"] is False
    assert result["stages"]["new-lineage-card"]["reached"] is False


def test_origin_history_never_advances_the_funnel(con, tmp_path):
    """The ORIGIN ea's historical work items and pipeline dirs are evidence,
    not retest progress — the retest mints a NEW ea_id (payload lineage=NEW)."""
    _task(con, TASK_ID, "REVIEW", _payload(TASK_ID, "QM5_11563"))
    c = con
    # origin's historical items carry NO task linkage in their payloads
    for i, phase in enumerate(("Q00", "Q02", "Q04", "Q08")):
        c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
                  (f"hist{i}", "QM5_11563", phase, "done", "{}",
                   "2026-05-01T00:00:00+00:00", "2026-05-02T00:00:00+00:00"))
    # origin's historical evidence dir exists on disk
    pipe = tmp_path / "pipe"
    (pipe / "QM5_11563" / "20260512_100657").mkdir(parents=True)
    cards = _cards(tmp_path)
    (cards / "PENDING_B0EF5D66_x.md").write_text("# card", encoding="utf-8")
    cands = scf.load_candidates(con)
    result = scf.classify_candidate(cands[0], con, cards_review_dir=cards,
                                    pipeline_dir=pipe)
    assert result["furthest_stage"] == "new-lineage-card"
    assert result["linked_work_item_ids"] == []
    assert result["linked_ea_ids"] == []
    assert result["stages"]["intake-q00"]["reached"] is False
    assert result["stages"]["factory-work-item"]["reached"] is False
    assert result["stages"]["mt5-evidence"]["reached"] is False


def test_full_advancement_through_portfolio_evaluated(con, tmp_path):
    _task(con, TASK_ID, "PIPELINE", _payload(TASK_ID, "QM5_11563"))
    c = con
    link = json.dumps({"second_chance_task_id": TASK_ID})
    c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
              ("wi-q00", "QM5_99999", "Q00", "done", link,
               "2026-09-16T06:00:00+00:00", "2026-09-16T06:10:00+00:00"))
    c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
              ("wi-q02", "QM5_99999", "Q02", "active", link,
               "2026-09-16T06:20:00+00:00", "2026-09-16T07:00:00+00:00"))
    c.execute("INSERT INTO portfolio_candidates VALUES (?,?,?,?)",
              ("QM5_99999", "EURUSD.DWX", "wi-q11", "Q12_REVIEW_READY"))
    pipe = tmp_path / "pipe"
    (pipe / "QM5_99999" / "20260916_120000").mkdir(parents=True)
    (pipe / "QM5_99999" / "20260916_120000" / "report.htm").write_text("x")
    (pipe / "QM5_11563-empty-would-not-count").mkdir(parents=True)  # empty

    cands = scf.load_candidates(con)
    result = scf.classify_candidate(cands[0], con,
                                    cards_review_dir=_cards(tmp_path),
                                    pipeline_dir=pipe)
    assert result["furthest_stage"] == "portfolio-evaluated"
    assert result["linked_ea_ids"] == ["QM5_99999"]
    assert result["stages"]["intake-q00"]["reached"] is True
    assert result["stages"]["factory-work-item"]["reached"] is True
    assert result["stages"]["mt5-evidence"]["reached"] is True
    assert result["stages"]["mt5-evidence"]["evidence"][0]["entries"] == 1
    assert result["stages"]["portfolio-evaluated"]["reached"] is True
    assert "Q12_REVIEW_READY" in \
        result["stages"]["portfolio-evaluated"]["evidence"][0]


def test_minted_ea_id_from_payload_is_honoured(con, tmp_path):
    """Once a lane records the minted ea_id in the payload, evidence dirs and
    portfolio rows for it count even before any linked work item exists."""
    payload = json.loads(_payload(TASK_ID, "QM5_11563"))
    payload["minted_ea_id"] = "QM5_77777"
    _task(con, TASK_ID, "APPROVED", json.dumps(payload))
    pipe = tmp_path / "pipe"
    (pipe / "QM5_77777" / "20260916_130000").mkdir(parents=True)
    con.execute("INSERT INTO portfolio_candidates VALUES (?,?,?,?)",
                ("QM5_77777", "EURUSD.DWX", "wi-q11", "Q12_REVIEW_READY"))

    cands = scf.load_candidates(con)
    result = scf.classify_candidate(cands[0], con,
                                    cards_review_dir=_cards(tmp_path),
                                    pipeline_dir=pipe)
    assert result["linked_ea_ids"] == ["QM5_77777"]
    assert result["furthest_stage"] == "portfolio-evaluated"


# ---------------------------------------------------------------------------
# read-model guarantee: zero DB writes
# ---------------------------------------------------------------------------
def test_build_funnel_writes_nothing_to_the_db(con, tmp_path):
    _task(con, TASK_ID, "REVIEW", _payload(TASK_ID, "QM5_11563"))
    c = con
    c.execute("INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
              ("wi-q00", "QM5_99999", "Q00", "pending",
               json.dumps({"second_chance_task_id": TASK_ID}),
               "2026-09-16T06:00:00+00:00", "2026-09-16T06:00:00+00:00"))
    c.commit()
    before = {
        "agent_tasks": [tuple(r) for r in c.execute("SELECT * FROM agent_tasks")],
        "work_items": [tuple(r) for r in c.execute("SELECT * FROM work_items")],
        "portfolio_candidates": [
            tuple(r) for r in c.execute("SELECT * FROM portfolio_candidates")],
    }

    # Drive main() against a FILE db so the CLI path itself is exercised; the
    # deny-triggers abort any write the read-model might attempt.
    db_path = tmp_path / "farm.sqlite"
    disk = sqlite3.connect(db_path)
    disk.executescript(DDL)
    for table, rows in before.items():
        cols = {
            "agent_tasks": "(id,task_type,state,verdict,payload_json,"
                           "created_at,updated_at)",
            "work_items": "(id,ea_id,phase,status,payload_json,"
                          "created_at,updated_at)",
            "portfolio_candidates": "(ea_id,symbol,q11_work_item_id,state)",
        }[table]
        marks = ",".join("?" for _ in cols.split(","))
        disk.executemany(
            f"INSERT INTO {table} {cols} VALUES ({marks})", rows)
    disk.commit()
    for table in before:
        disk.execute(
            f"CREATE TRIGGER deny_{table} BEFORE INSERT ON {table} "
            f"BEGIN SELECT RAISE(ABORT, 'read-model wrote to {table}'); END")
    disk.commit()
    disk.close()

    out = tmp_path / "state" / "second_chance_funnel.json"
    rc = scf.main(["--db", str(db_path), "--output", str(out),
                   "--cards-review-dir", str(_cards(tmp_path)),
                   "--pipeline-dir", str(tmp_path / "pipe")])
    assert rc == 0
    assert out.exists()

    check = sqlite3.connect(db_path)
    for table, rows in before.items():
        after = [tuple(r) for r in check.execute(f"SELECT * FROM {table}")]
        assert after == rows, f"{table} mutated by the read-model"
    check.close()


# ---------------------------------------------------------------------------
# full assembly + CLI
# ---------------------------------------------------------------------------
def _seed_two_candidates(c):
    _task(c, TASK_ID, "REVIEW", _payload(TASK_ID, "QM5_11563"),
          verdict="REVIEW_READY")
    _task(c, OTHER_ID, "IN_PROGRESS", _payload(
        OTHER_ID, "QM5_11373", source="second_chance_wave2",
        reason="MULTI_POSITION", slug="100pips"))


def test_build_funnel_schema_summary_and_table(con, tmp_path):
    _seed_two_candidates(con)
    cards = _cards(tmp_path)
    (cards / "PENDING_B0EF5D66_x.md").write_text("# card", encoding="utf-8")

    doc = scf.build_funnel(con, now=NOW, cards_review_dir=cards,
                           pipeline_dir=tmp_path / "pipe")
    assert doc["schema"] == "qm.second-chance-funnel/v1"
    assert doc["generated_at_utc"] == "2026-09-16T12:00:00+00:00"
    assert doc["stages"] == list(scf.STAGES)
    assert doc["summary"]["total"] == 2
    assert doc["summary"]["by_furthest_stage"] == {
        "commissioned": 1,
        "review": 0,
        "new-lineage-card": 1,
        "intake-q00": 0,
        "factory-work-item": 0,
        "mt5-evidence": 0,
        "portfolio-evaluated": 0,
    }
    table = scf.render_table(doc)
    assert "task" in table and "furthest stage" in table
    assert "b0ef5d66" in table and "27ae17d6" in table
    assert "new-lineage-card" in table and "commissioned" in table


def test_main_writes_json_prints_table(con, tmp_path, capsys):
    _seed_two_candidates(con)
    cards = _cards(tmp_path)
    (cards / "PENDING_B0EF5D66_x.md").write_text("# card", encoding="utf-8")
    db = tmp_path / "farm.sqlite"
    con.commit()
    con.backup(sqlite3.connect(db))

    out = tmp_path / "state" / "second_chance_funnel.json"
    rc = scf.main(["--db", str(db), "--output", str(out),
                   "--cards-review-dir", str(cards),
                   "--pipeline-dir", str(tmp_path / "pipe")])
    assert rc == 0
    on_disk = json.loads(out.read_text(encoding="utf-8"))
    assert on_disk["schema"] == "qm.second-chance-funnel/v1"
    assert on_disk["summary"]["total"] == 2
    stdout = capsys.readouterr().out
    assert "b0ef5d66" in stdout
