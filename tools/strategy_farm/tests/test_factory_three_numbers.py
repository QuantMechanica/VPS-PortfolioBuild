"""Tests for the factory three-numbers read-model (qm.factory-three-numbers/v1).

Deterministic, hermetic: an in-memory farm DB drives every count. The Q08 DSR
precheck is monkeypatched (dsr_cohort.claimability_precheck), so no live D:/QM
file is read and no real precheck runs. The canonical claim selector runs for
real against the fixture (the same farmctl.pending_claim_order_sql the workers
execute), so selector-level semantics (held/superseded/quarantined exclusion)
are covered end-to-end.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
import sys
import types
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from tools.strategy_farm import factory_three_numbers as tn


NOW = dt.datetime(2026, 9, 16, 12, 0, 0, tzinfo=dt.timezone.utc)


def _dsr_module(monkeypatch):
    """Return the importable dsr_cohort module, installing a stub when the
    module is absent from the checkout (main predates the DSR-cohort merge),
    so the precheck-fake tests run on every branch line."""
    try:
        import dsr_cohort
        return dsr_cohort
    except ImportError:
        stub = types.ModuleType("dsr_cohort")
        monkeypatch.setitem(sys.modules, "dsr_cohort", stub)
        return stub

# Columns pending_claim_order_sql() touches: id, ea_id, symbol, phase, status,
# kind, payload_json, verdict, created_at, updated_at. The NOT EXISTS arms need
# work_item_holds(active), work_item_supersedes, poison_pill_quarantine.
DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT, phase TEXT, status TEXT,
    kind TEXT, payload_json TEXT, verdict TEXT,
    created_at TEXT, updated_at TEXT
);
CREATE TABLE work_item_holds (
    work_item_id TEXT, hold_code TEXT, active INTEGER, released_at TEXT
);
CREATE TABLE work_item_supersedes (work_item_id TEXT);
CREATE TABLE poison_pill_quarantine (
    ea_id TEXT, symbol TEXT, phase TEXT, active INTEGER
);
"""


@pytest.fixture()
def con() -> sqlite3.Connection:
    c = sqlite3.connect(":memory:")
    c.row_factory = sqlite3.Row
    c.executescript(DDL)
    return c


def _item(c, i, *, phase="Q02", status="pending", ea="QM5_1", payload="{}"):
    c.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
        (i, ea, "EURUSD.DWX", phase, status, "run_smoke", payload, None,
         "2026-09-01T00:00:00+00:00", "2026-09-16T00:00:00+00:00"),
    )


def _seed_queue(c):
    _item(c, "act1", phase="Q04", status="active")
    _item(c, "act2", phase="Q04", status="active")
    _item(c, "pend1", phase="Q02")
    _item(c, "pend2", phase="Q08", ea="BAD8")
    _item(c, "pend3", phase="Q08", ea="GOOD8")
    _item(c, "pend4", phase="Q08", ea="ERR8")
    _item(c, "pend5", phase="Q02", ea="QM5_9")  # actively held -> selector drops it
    c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
              ("pend5", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914", 1, None))
    c.commit()


def _fake_precheck(_conn, row, _payload, **_kw):
    if row["ea_id"] == "ERR8":
        raise RuntimeError("ledger probe exploded")
    return {"claimable": row["ea_id"] != "BAD8", "reason": None}


# ---------------------------------------------------------------------------
# individual numbers
# ---------------------------------------------------------------------------
def test_active_economic_backtests_counts_status_active(con):
    _seed_queue(con)
    assert tn.count_active_economic_backtests(con) == 2


def test_true_claimable_mirrors_watchdog_v2(con, monkeypatch):
    _seed_queue(con)
    dsr = _dsr_module(monkeypatch)
    # raising=False: the attribute only exists once the DSR-cohort module is
    # present; the fake installs identically on every branch line.
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    res = tn.compute_true_claimable(con)
    # selector: pend1..pend4 (pend5 excluded by its active hold) = 4
    assert res["selector_claimable_rows"] == 4
    # BAD8 excluded by precheck; ERR8 raised -> counted (watchdog fail-open)
    assert res["q08_precheck_excluded"] == 1
    assert res["q08_precheck_error_rows"] == 1
    assert res["true_claimable_work"] == 3
    assert res["precheck_degraded_to_selector"] is False


def test_true_claimable_falls_back_to_selector_when_dsr_missing(
        con, monkeypatch):
    _seed_queue(con)
    monkeypatch.setitem(sys.modules, "dsr_cohort", None)  # import dsr_cohort fails
    res = tn.compute_true_claimable(con)
    assert res["precheck_degraded_to_selector"] is True
    assert res["true_claimable_work"] == res["selector_claimable_rows"] == 4
    assert "dsr_cohort import failed" in res["degraded_reason"]


def test_true_claimable_not_evaluable_when_farmctl_missing(
        con, monkeypatch):
    _seed_queue(con)
    monkeypatch.setitem(sys.modules, "farmctl", None)
    res = tn.compute_true_claimable(con)
    assert res["true_claimable_work"] is None
    assert res["selector_claimable_rows"] is None
    assert "farmctl import failed" in res["degraded_reason"]


def test_blocked_recoverable_counts_only_unreleased_matching_holds(con):
    c = con
    holds = [
        ("w1", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914", None),
        ("w2", "Q08_DSR_CONTEXT_UNAVAILABLE", None),
        ("w3", "ARTIFACT_BINDING_CONTENT_CHANGED", None),
        ("w4", "NEWS_CALENDAR_TAINTED", None),            # not a recoverable class
        ("w5", "RAM_RESERVATION_OLD", "2026-09-01T00:00:00+00:00"),  # released
        ("w6", "Q08_DSR_CANDIDATE_WINDOW_UNAVAILABLE", None),
    ]
    for wid, code, rel in holds:
        c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
                  (wid, code, 1 if rel is None else 0, rel))
    c.commit()
    res = tn.compute_blocked_recoverable(con)
    assert res["blocked_recoverable_work"] == 4
    assert res["blocked_recoverable_work_items_distinct"] == 4
    assert res["by_hold_code"]["RAM_RESERVATION_44GB_NOT_WINNABLE_20260914"] \
        == {"holds": 1, "work_items": 1}
    assert "NEWS_CALENDAR_TAINTED" not in res["by_hold_code"]
    assert "RAM_RESERVATION_OLD" not in res["by_hold_code"]


# ---------------------------------------------------------------------------
# health classification
# ---------------------------------------------------------------------------
def test_health_running_when_active():
    h = tn.classify_health(2, 0, None)
    assert h["classification"] == "RUNNING"
    assert h["consecutive_idle_with_work_runs"] == 0


def test_health_idle_with_work_first_run():
    h = tn.classify_health(0, 3, None)
    assert h["classification"] == "IDLE_WITH_WORK"
    assert h["consecutive_idle_with_work_runs"] == 1


def _prev_doc(classification, streak):
    return {
        "generated_at_utc": "2026-09-16T11:45:00+00:00",
        "health": {"classification": classification,
                   "consecutive_idle_with_work_runs": streak},
    }


def test_health_idle_red_requires_two_consecutive_runs():
    second = tn.classify_health(0, 3, _prev_doc("IDLE_WITH_WORK", 1))
    assert second["classification"] == "IDLE_RED"
    assert second["consecutive_idle_with_work_runs"] == 2
    assert second["previous_classification"] == "IDLE_WITH_WORK"
    third = tn.classify_health(0, 3, _prev_doc("IDLE_RED", 2))
    assert third["classification"] == "IDLE_RED"
    assert third["consecutive_idle_with_work_runs"] == 3


def test_health_idle_streak_resets_when_no_runnable_work():
    h = tn.classify_health(0, 0, _prev_doc("IDLE_RED", 5))
    assert h["classification"] == "NO_RUNNABLE_WORK"
    assert h["consecutive_idle_with_work_runs"] == 0


def test_health_running_resets_idle_streak():
    h = tn.classify_health(1, 0, _prev_doc("IDLE_RED", 5))
    assert h["classification"] == "RUNNING"
    assert h["consecutive_idle_with_work_runs"] == 0


def test_health_unknown_when_numbers_not_evaluable():
    h = tn.classify_health("NOT_EVALUATED", None, None)
    assert h["classification"] == "UNKNOWN"
    assert h["degraded_reason"]


# ---------------------------------------------------------------------------
# full document + CLI persistence
# ---------------------------------------------------------------------------
def test_build_document_full(con, monkeypatch):
    _seed_queue(con)
    dsr = _dsr_module(monkeypatch)
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    c = con
    c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
              ("act1", "ARTIFACT_BINDING_CONTENT_CHANGED", 1, None))
    c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
              ("act2", "Q08_DSR_CONTEXT_UNAVAILABLE", 1, None))
    c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
              ("act2", "RAM_RESERVATION_X", 1, None))  # second hold, same row
    c.commit()

    doc = tn.build_document(con, now=NOW, previous=None)
    assert doc["schema"] == "qm.factory-three-numbers/v1"
    assert doc["generated_at_utc"] == "2026-09-16T12:00:00+00:00"
    assert doc["numbers"] == {
        "active_economic_backtests": 2,
        "true_claimable_work": 3,
        "blocked_recoverable_work": 4,  # pend5's seed RAM hold + 3 added below
    }
    assert doc["detail"]["blocked_recoverable_work_items_distinct"] == 3
    assert doc["health"]["classification"] == "RUNNING"
    assert doc["degraded_reasons"] == []


def _file_db(tmp_path: Path, seed) -> Path:
    db = tmp_path / "farm.sqlite"
    c = sqlite3.connect(db)
    c.executescript(DDL)
    seed(c)
    c.commit()
    c.close()
    return db


def test_main_writes_json_and_second_run_flips_to_idle_red(tmp_path,
                                                           monkeypatch):
    def seed(c):
        _item(c, "pend1", phase="Q02")

    db = _file_db(tmp_path, seed)
    out = tmp_path / "state" / "factory_three_numbers.json"
    monkeypatch.setattr(tn, "DB", db)  # sources.db reflects the override

    assert tn.main(["--db", str(db), "--output", str(out)]) == 0
    first = json.loads(out.read_text(encoding="utf-8"))
    assert first["numbers"]["active_economic_backtests"] == 0
    assert first["numbers"]["true_claimable_work"] == 1
    assert first["health"]["classification"] == "IDLE_WITH_WORK"
    assert first["health"]["consecutive_idle_with_work_runs"] == 1

    assert tn.main(["--db", str(db), "--output", str(out)]) == 0
    second = json.loads(out.read_text(encoding="utf-8"))
    assert second["health"]["classification"] == "IDLE_RED"
    assert second["health"]["consecutive_idle_with_work_runs"] == 2
    assert second["health"]["previous_classification"] == "IDLE_WITH_WORK"


def test_main_stdout(tmp_path, capsys):
    db = _file_db(tmp_path, lambda c: _item(c, "act1", status="active"))
    out = tmp_path / "out.json"
    tn.main(["--db", str(db), "--output", str(out), "--stdout"])
    printed = json.loads(capsys.readouterr().out)
    assert printed["schema"] == "qm.factory-three-numbers/v1"
