"""Tests for the factory bottleneck read-model (qm.factory-bottleneck/v1).

Deterministic, hermetic: a fixture farm DB, a fixture pipeline_state.json,
drain_window.json, and synthetic worker logs drive the whole read-model. No live
D:/QM file is read (paths are passed explicitly / monkeypatched).
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import factory_bottleneck_readmodel as fb


NOW = dt.datetime(2026, 9, 15, 14, 0, 0, tzinfo=dt.timezone.utc)


DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, phase TEXT, status TEXT
);
CREATE TABLE work_item_holds (
    work_item_id TEXT, hold_code TEXT, released_at TEXT
);
"""


@pytest.fixture()
def fixture_db(tmp_path: Path) -> Path:
    path = tmp_path / "farm.sqlite"
    con = sqlite3.connect(path)
    con.executescript(DDL)
    # 4 active claims
    for i in range(4):
        con.execute("INSERT INTO work_items VALUES (?,?,?)", (f"act{i}", "Q04", "active"))
    # 10 pending; 3 of them held (2 RAM, 1 prescreen) -> 7 claimable
    for i in range(10):
        con.execute("INSERT INTO work_items VALUES (?,?,?)",
                    (f"pend{i}", "Q02" if i < 6 else "Q12", "pending"))
    con.execute("INSERT INTO work_item_holds VALUES (?,?,?)",
                ("pend0", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914", None))
    con.execute("INSERT INTO work_item_holds VALUES (?,?,?)",
                ("pend1", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914", None))
    con.execute("INSERT INTO work_item_holds VALUES (?,?,?)",
                ("pend2", "PRESCREEN_SKIPPED", None))
    con.execute("INSERT INTO work_item_holds VALUES (?,?,?)",
                ("pend3", "NEWS_CALENDAR_TAINTED", None))
    # a released hold must NOT count as active
    con.execute("INSERT INTO work_item_holds VALUES (?,?,?)",
                ("pend9", "OLD_HOLD", "2026-09-01T00:00:00+00:00"))
    con.commit()
    con.close()
    return path


def _pipeline_state(tmp_path: Path) -> Path:
    path = tmp_path / "pipeline_state.json"
    path.write_text(json.dumps({
        "generated_at": NOW.isoformat(),
        "by_gate_v4": {"Q01": 3, "Q02": 2089, "Q11": 51, "Q12": 2, "Q14": 29,
                       "Q15": 0},
        "operator_surface": {"book_guard": {"qualified_pairs": 26,
                                            "distinct_eas": 26,
                                            "strategy_families": 21}},
    }), encoding="utf-8")
    return path


def _drain_window(tmp_path: Path) -> Path:
    path = tmp_path / "drain_window.json"
    path.write_text(json.dumps({
        "pre_drain": {"ea_id": "QM5_1069", "reservation_gb": 44.0,
                      "opened_iso": NOW.isoformat()},
    }), encoding="utf-8")
    return path


def _worker_logs(tmp_path: Path, idle_terms, *, now=NOW) -> Path:
    log_dir = tmp_path / "logs"
    log_dir.mkdir()
    import os
    for term in fb.FLEET:
        path = log_dir / f"terminal_worker_{term}.log"
        if term in idle_terms:
            rec = {"stage_event": "claim_result", "reason": "no_pending_claimable",
                   "skips": {"ram_class_skipped": 236, "longrun_cap_skipped": 25},
                   "terminal": term}
        else:
            rec = {"stage_event": "claim_result", "reason": "claimed",
                   "skips": {"ram_class_skipped": 0, "longrun_cap_skipped": 0},
                   "terminal": term}
        # CR-delimited JSON, like the real worker logs
        path.write_text(json.dumps(rec) + "\r", encoding="utf-8")
        os.utime(path, (now.timestamp() - 60, now.timestamp() - 60))
    return log_dir


# ---------------------------------------------------------------------------
# queue state
# ---------------------------------------------------------------------------
def test_collect_queue_state_counts_claimable_excluding_active_holds(fixture_db):
    con = fb._connect_ro(fixture_db)
    try:
        q = fb.collect_queue_state(con)
    finally:
        con.close()
    assert q["active"] == 4
    assert q["pending_total"] == 10
    # 3 active holds on pending rows (RAM x2, PRESCREEN, NEWS = 4 actually)
    # pend0,pend1,pend2,pend3 held -> 6 claimable of 10
    assert q["claimable_pending"] == 6
    assert q["holds_by_class"]["RAM_RESERVATION_44GB_NOT_WINNABLE_20260914"] == 2
    assert "OLD_HOLD" not in q["holds_by_class"]  # released hold excluded


# ---------------------------------------------------------------------------
# idle-in-drain detection
# ---------------------------------------------------------------------------
def test_detect_idle_in_drain_counts_self_parked_terminals(tmp_path):
    log_dir = _worker_logs(tmp_path, {"T3", "T5", "T9"})
    idle = fb.detect_idle_in_drain(log_dir, now=NOW)
    assert idle["idle_in_drain"] == 3
    assert set(idle["idle_terminals"]) == {"T3", "T5", "T9"}


def test_detect_idle_in_drain_ignores_stale_logs(tmp_path):
    old = NOW - dt.timedelta(hours=3)
    log_dir = _worker_logs(tmp_path, {"T3", "T5"}, now=old)
    idle = fb.detect_idle_in_drain(log_dir, now=NOW)
    assert idle["idle_in_drain"] == 0        # logs too old to be live evidence
    assert idle["logs_scanned"] == []


# ---------------------------------------------------------------------------
# frontier
# ---------------------------------------------------------------------------
def test_load_frontier_and_largest_band(tmp_path):
    frontier = fb.load_frontier(_pipeline_state(tmp_path), now=NOW)
    assert frontier["by_gate_v4"]["Q02"] == 2089
    band = fb._largest_frontier_band(frontier["by_gate_v4"])
    assert band == {"gate": "Q02", "count": 2089}
    assert frontier["book_guard"]["qualified_pairs"] == 26


def test_load_frontier_absent_is_not_evaluated(tmp_path):
    frontier = fb.load_frontier(tmp_path / "nope.json", now=NOW)
    assert frontier["by_gate_v4"] == "NOT_EVALUATED"
    assert frontier["book_guard"] == "NOT_EVALUATED"


# ---------------------------------------------------------------------------
# bottleneck ranking
# ---------------------------------------------------------------------------
def test_head_of_line_block_ranks_first_when_idle_and_claimable(tmp_path):
    queue = {"claimable_pending": 732, "holds_by_class": {"NEWS_CALENDAR_TAINTED": 99}}
    frontier = {"by_gate_v4": {"Q02": 2089}}
    drain = {"reservation_gb": 44.0, "ea_id": "QM5_1069"}
    idle = {"idle_in_drain": 6}
    ranked = fb.rank_bottlenecks(queue=queue, frontier=frontier, drain=drain,
                                 idle=idle, resources={"d_free_gb": 200})
    assert ranked[0]["rank"] == 1
    assert ranked[0]["name"] == "unwinnable_reservation_head_of_line_block"
    assert ranked[1]["name"] == "frontier_band_Q02"
    assert any(b["name"].startswith("hold_backlog_") for b in ranked)


def test_no_head_of_line_block_when_no_idle(tmp_path):
    ranked = fb.rank_bottlenecks(
        queue={"claimable_pending": 10, "holds_by_class": {}},
        frontier={"by_gate_v4": {"Q11": 51}},
        drain={"reservation_gb": None, "ea_id": None},
        idle={"idle_in_drain": 0}, resources={"d_free_gb": 200})
    assert ranked[0]["name"] == "frontier_band_Q11"


def test_disk_near_lowwater_becomes_a_bottleneck_and_infra_problem():
    ranked = fb.rank_bottlenecks(
        queue={"claimable_pending": 0, "holds_by_class": {}},
        frontier={"by_gate_v4": {}}, drain={}, idle={"idle_in_drain": 0},
        resources={"d_free_gb": 61.0})
    assert any(b["name"] == "disk_free_near_lowwater" for b in ranked)
    problems = fb.collect_infra_problems(
        {"holds_by_class": {"NEWS_CALENDAR_TAINTED": 99}}, {"d_free_gb": 61.0})
    codes = {p["hold_code"] for p in problems}
    assert "NEWS_CALENDAR_TAINTED" in codes
    assert "DISK_FREE_NEAR_LOWWATER" in codes


# ---------------------------------------------------------------------------
# full assembly
# ---------------------------------------------------------------------------
def test_build_factory_bottleneck_full(fixture_db, tmp_path):
    doc = fb.build_factory_bottleneck(
        fixture_db, now=NOW,
        pipeline_state_path=_pipeline_state(tmp_path),
        drain_window_path=_drain_window(tmp_path),
        worker_log_dir=_worker_logs(tmp_path, {"T3", "T5", "T9", "T4", "T8", "T10"}),
    )
    assert doc["schema"] == "qm.factory-bottleneck/v1"
    assert doc["generated_at_utc"] == "2026-09-15T14:00:00+00:00"
    assert doc["terminals"]["active"] == 4
    assert doc["terminals"]["idle_in_drain"] == 6
    assert doc["terminals"]["claimable_pending"] == 6
    assert doc["bottlenecks"][0]["name"] == "unwinnable_reservation_head_of_line_block"
    assert doc["frontier"]["candidate_counts_diagnostic"]["qualified_pairs"] == 26
    assert doc["frontier"]["candidate_counts_diagnostic"]["note"] == "diagnostic, not a goal"
    # d_free comes from the real host (measured), but is numeric or UNKNOWN
    assert doc["resources"]["d_free_gb"] == "UNKNOWN" or isinstance(
        doc["resources"]["d_free_gb"], (int, float))


def test_build_factory_bottleneck_db_missing_is_not_evaluated(tmp_path):
    doc = fb.build_factory_bottleneck(
        tmp_path / "no.sqlite", now=NOW,
        pipeline_state_path=tmp_path / "no_ps.json",
        drain_window_path=tmp_path / "no_dw.json",
        worker_log_dir=tmp_path / "no_logs")
    assert doc["terminals"]["active"] == "NOT_EVALUATED"
    assert doc["degraded_reasons"]  # db-unavailable reason recorded
    assert doc["frontier"]["by_gate_v4"] == "NOT_EVALUATED"


# ---------------------------------------------------------------------------
# shared loader + health composer
# ---------------------------------------------------------------------------
def test_load_readmodel_present_absent_invalid(tmp_path):
    good = tmp_path / "good.json"
    good.write_text(json.dumps({"generated_at_utc": NOW.isoformat()}), encoding="utf-8")
    rm = fb.load_readmodel(good, now=NOW, sla_sec=3600)
    assert rm["present"] and rm["staleness"] == "FRESH"

    absent = fb.load_readmodel(tmp_path / "nope.json", now=NOW)
    assert absent["present"] is False
    assert absent["degraded_reason"] == "EVIDENCE_MISSING"

    bad = tmp_path / "bad.json"
    bad.write_text("{not json", encoding="utf-8")
    rm_bad = fb.load_readmodel(bad, now=NOW)
    assert rm_bad["present"] is False
    assert "invalid JSON" in rm_bad["degraded_reason"]


def test_compute_book_evolution_health_grades():
    def rm(present, staleness="FRESH", payload=None):
        return {"present": present, "staleness": staleness, "payload": payload or {}}

    all_fresh = {
        "book_evolution": {"dxz": rm(True), "ftmo": rm(True)},
        "ftmo_challenge_readiness": rm(True, payload={"recommendation": "READY_FOR_OWNER_REVIEW"}),
        "research_state": rm(True),
        "factory_bottleneck": rm(True, payload={"bottlenecks": [{"name": "top1"}]}),
    }
    h = fb.compute_book_evolution_health(all_fresh)
    assert h["book_evolution_readmodels"] == "GREEN"
    assert h["ftmo_readiness_recommendation"] == "READY_FOR_OWNER_REVIEW"
    assert h["research_state_freshness"] == "FRESH"
    assert h["factory_bottleneck_top"] == "top1"

    none_present = {
        "book_evolution": {"dxz": rm(False), "ftmo": rm(False)},
        "ftmo_challenge_readiness": rm(False), "research_state": rm(False),
        "factory_bottleneck": rm(False),
    }
    hr = fb.compute_book_evolution_health(none_present)
    assert hr["book_evolution_readmodels"] == "RED"
    assert hr["ftmo_readiness_recommendation"] == "EVIDENCE_MISSING"


def test_write_health_readmodel_persists_file(tmp_path, monkeypatch):
    out = tmp_path / "book_evolution_health.json"
    doc = fb.write_health_readmodel(now=NOW, output_path=out, paths={
        "dxz": tmp_path / "absent1.json", "ftmo": tmp_path / "absent2.json",
        "ftmo_readiness": tmp_path / "absent3.json",
        "research": tmp_path / "absent4.json", "bottleneck": tmp_path / "absent5.json",
    })
    assert out.exists()
    on_disk = json.loads(out.read_text(encoding="utf-8"))
    assert on_disk["schema"] == "qm.book-evolution-health/v1"
    assert on_disk["book_evolution_readmodels"] == "RED"
    assert doc["generated_at_utc"] == "2026-09-15T14:00:00+00:00"
