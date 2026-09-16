"""Tests for the factory population reconciliation read-model
(qm.factory-population/v1).

Deterministic and hermetic: an in-memory farm DB drives every count and every
classification. The Q08 DSR precheck is monkeypatched (dsr_cohort module, same
idiom as test_factory_three_numbers.py) and the terminal_worker RAM resolver is
replaced by a fake module, so no live D:/QM file is read and no real
reservation runs. The canonical claim selector (farmctl.pending_claim_order_sql)
runs for real against the fixture, so selector-level semantics (held /
superseded / quarantined / governed-analytic exclusion) are covered end-to-end.
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

from tools.strategy_farm import factory_population as fp


NOW = dt.datetime(2026, 9, 16, 12, 0, 0, tzinfo=dt.timezone.utc)

# Same minimal column set test_factory_three_numbers.py uses: the canonical
# selector only needs these columns plus the holds/supersedes/quarantine arms.
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


def _item(c, i, *, phase="Q02", status="pending", ea="QM5_1", kind="run_smoke",
          payload=None, symbol="EURUSD.DWX"):
    c.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?)",
        (i, ea, symbol, phase, status, kind,
         json.dumps(payload or {}), None,
         "2026-09-15T00:00:00+00:00", "2026-09-16T00:00:00+00:00"),
    )


def _hold(c, wid, code, active=1):
    c.execute("INSERT INTO work_item_holds VALUES (?,?,?,?)",
              (wid, code, active, None))


def _fake_precheck(_conn, row, _payload, **_kw):
    """ERR8 raises (watchdog fail-open -> counted); BAD8 is rejected."""
    if row["ea_id"] == "ERR8":
        raise RuntimeError("ledger probe exploded")
    if row["ea_id"] == "BAD8":
        return {"claimable": False,
                "reason": "SINGLE_CONFIGURATION_UNAVAILABLE:"
                          "BUILD_IDENTITY_MISMATCH:mq5"}
    if row["ea_id"] == "NODECL8":
        return {"claimable": False,
                "reason": "SINGLE_CONFIGURATION_UNAVAILABLE:"
                          "EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED"}
    return {"claimable": True, "reason": None}


def _dsr_module(monkeypatch):
    try:
        import dsr_cohort
        return dsr_cohort
    except ImportError:
        stub = types.ModuleType("dsr_cohort")
        monkeypatch.setitem(sys.modules, "dsr_cohort", stub)
        return stub


class FakeTW:
    """Minimal terminal_worker stand-in for RAM reservation logic."""

    def __init__(self, reservation_gb: float, floor_gb: float = 14.0,
                 fail: bool = False):
        self._res = reservation_gb
        self._floor = floor_gb
        self._fail = fail

    def _multisymbol_ea_ids(self):
        return frozenset()

    def _work_item_is_multisymbol(self, _item, _payload, _ms):
        return False

    def _ram_reservation_detail_for_candidate(self, _item, _payload, _ms):
        if self._fail:
            raise RuntimeError("registry exploded")
        return "fake_class", float(self._res), "flat"

    def _ram_floor_for_class(self, _cls):
        return float(self._floor)


# ---------------------------------------------------------------------------
# classifier units
# ---------------------------------------------------------------------------
def test_precheck_reason_mapping():
    assert fp._bucket_from_precheck_reason(
        "SINGLE_CONFIGURATION_UNAVAILABLE:BUILD_IDENTITY_MISMATCH:mq5") \
        == "BUILD_IDENTITY_BLOCKED"
    assert fp._bucket_from_precheck_reason(
        "SINGLE_CONFIGURATION_UNAVAILABLE:"
        "EXPLICIT_SINGLE_CONFIGURATION_DECLARATION_REQUIRED") \
        == "GOVERNANCE_BLOCKED"
    assert fp._bucket_from_precheck_reason(
        "SINGLE_CONFIGURATION_UNAVAILABLE:SINGLE_CONFIG_CANDIDATE_MISMATCH") \
        == "DSR_CONTEXT_BLOCKED"
    assert fp._bucket_from_precheck_reason("CANDIDATE_IDENTITY_UNAVAILABLE") \
        == "DSR_CONTEXT_BLOCKED"


def _ctx_for(c, rows):
    return fp.load_row_context(c, rows)


def test_open_classification_exactly_once(con, monkeypatch):
    _item(con, "run1", phase="Q06", ea="GOOD6")
    _item(con, "ram1", phase="Q02", ea="QM5_9")
    _hold(con, "ram1", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914")
    _item(con, "bad8", phase="Q08", ea="BAD8")
    _item(con, "nodecl8", phase="Q08", ea="NODECL8")
    _item(con, "err8", phase="Q08", ea="ERR8")
    _item(con, "sup1", phase="Q04", ea="QM5_7")
    con.execute("INSERT INTO work_item_supersedes VALUES ('sup1')")
    _item(con, "quar1", phase="Q02", ea="QM5_8")
    con.execute(
        "INSERT INTO poison_pill_quarantine VALUES ('QM5_8','EURUSD.DWX',"
        "'Q02',1)")
    _item(con, "bind1", phase="Q03", ea="QM5_10")
    _hold(con, "bind1", "ARTIFACT_BINDING_CONTENT_CHANGED")
    _item(con, "dsr1", phase="Q08", ea="QM5_11")
    _hold(con, "dsr1", "Q08_DSR_CONTEXT_UNAVAILABLE")
    _item(con, "gov1", phase="Q02", ea="QM5_12")
    _hold(con, "gov1", "REVIEW_FAIL_PIPELINE_ENTRY_BLOCKED")
    con.commit()

    dsr = _dsr_module(monkeypatch)
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    claimability = fp.compute_selector_claimable(con)
    rows = fp.fetch_population_rows(con)
    open_rows, parked_rows = fp.split_mc_populations(rows)
    assert len(open_rows) == 10 and parked_rows == []
    ctx = _ctx_for(con, rows)
    ram = {r["id"]: {"reservation_gb": 12.0, "floor_gb": 14.0,
                     "feasible": True, "ram_class": "c", "source": "flat"}
           for r in rows}
    classified = fp.classify_population(
        open_rows, parked_rows, claimability=claimability, ram=ram, ctx=ctx,
        receipt={})
    counts = classified["open_counts"]
    # every row exactly once
    assert sum(counts.values()) == len(open_rows) == 10
    seen = [r["id"] for r in classified["open_rows"]]
    assert len(seen) == len(set(seen))
    # expected buckets
    by_id = {r["id"]: r["bucket"] for r in classified["open_rows"]}
    assert by_id["run1"] == "RUNNABLE_NOW"
    assert by_id["bad8"] == "BUILD_IDENTITY_BLOCKED"
    assert by_id["nodecl8"] == "GOVERNANCE_BLOCKED"
    assert by_id["err8"] == "RUNNABLE_NOW"  # precheck raised -> fail-open
    assert by_id["sup1"] == "SUPERSEDED_REPAIR"
    assert by_id["quar1"] == "REQUEUE_EXCLUDED"
    assert by_id["bind1"] == "ARTIFACT_BINDING_BLOCKED"
    assert by_id["dsr1"] == "DSR_CONTEXT_BLOCKED"
    assert by_id["gov1"] == "GOVERNANCE_BLOCKED"
    assert counts["RESOURCE_BLOCKED"] == 1


def test_open_ram_infeasible_selector_row(con, monkeypatch):
    _item(con, "heavy6", phase="Q06", ea="GOOD6")
    c = con.commit() or con
    dsr = _dsr_module(monkeypatch)
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    claimability = fp.compute_selector_claimable(con)
    rows = fp.fetch_population_rows(con)
    open_rows, _ = fp.split_mc_populations(rows)
    ctx = _ctx_for(con, rows)
    ram = {"heavy6": {"reservation_gb": 37.9, "floor_gb": 14.0,
                      "feasible": False, "ram_class": "single_index_tick",
                      "source": "measured"}}
    classified = fp.classify_population(
        open_rows, [], claimability=claimability, ram=ram, ctx=ctx,
        receipt={})
    row = classified["open_rows"][0]
    assert row["bucket"] == "RESOURCE_BLOCKED"
    assert row["subcategory"] == "ram_infeasible_now"


def test_parked_classification(con):
    # governed analytic rows classified from the receipt
    _item(con, "q12dup", phase="Q12", kind="analytic",
          payload={"execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
                   "program_id": "DL089_QM5_10706_GBPUSD_DWX_2019_2025"})
    _item(con, "q12sib", phase="Q12", kind="analytic", ea="QM5_10911",
          payload={"execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
                   "program_id": "DL089_QM5_10911_GDAXI_DWX_2019_2025"})
    _item(con, "q12bind", phase="Q12", kind="analytic", ea="QM5_20086",
          payload={"execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
                   "program_id": "DL089_QM5_20086_NDX_DWX_2019_2025"})
    _item(con, "census1", phase="OPT_CENSUS", ea="QM5_41097")
    _hold(con, "census1", "PRESCREEN_SKIPPED")
    _item(con, "news1", phase="Q10_NEWS", ea="QM5_21505")
    _hold(con, "news1", "NEWS_CALENDAR_TAINTED")
    _item(con, "diag1", phase="Q09_NEWS", ea="QM5_13301",
          payload={"diagnostic_non_admission": True})
    _hold(con, "diag1", "NEWS_CALENDAR_TAINTED")
    _item(con, "comp1", phase="COMPILE_EA", ea="QM5_41097")
    _hold(con, "comp1", "COMPILE_EA_WORKER_ROLLOUT_PENDING")
    _item(con, "spawn1", phase="Q10_NEWS", ea="QM5_21507")
    _hold(con, "spawn1", "NEWS_RUNNER_SPAWN_SILENT_ABORT")
    _item(con, "sup2", phase="COMPILE_EA", ea="QM5_1")
    con.execute("INSERT INTO work_item_supersedes VALUES ('sup2')")
    con.commit()

    receipt = {
        "q12dup": "PROGRAM_Q12_REBIND_REFUSED: program=X requested=Y",
        "q12sib": "expected one approved _opt sibling for QM5_10911/GDAXI.DWX,"
                  " found 0",
        "q12bind": "blocking hold: ARTIFACT_BINDING_CONTENT_CHANGED",
    }
    rows = fp.fetch_population_rows(con)
    _, parked_rows = fp.split_mc_populations(rows)
    assert len(parked_rows) == 9
    ctx = _ctx_for(con, rows)
    classified = fp.classify_population(
        [], parked_rows, claimability={"selector_ids": set(),
                                       "true_claimable_ids": set()},
        ram={}, ctx=ctx, receipt=receipt)
    counts = classified["parked_counts"]
    assert sum(counts.values()) == 9
    by_id = {r["id"]: r for r in classified["parked_rows"]}
    assert by_id["q12dup"]["bucket"] == "INTENTIONALLY_INERT"
    assert by_id["q12dup"]["subcategory"] == "duplicate_declaration_rebind_refused"
    assert by_id["q12sib"]["bucket"] == "REQUIRES_NEW_OWNER_DECISION"
    assert by_id["q12sib"]["subcategory"] == "sibling_build_commission"
    assert by_id["q12bind"]["bucket"] == "RECOVERABLE_WITH_EXISTING_AUTHORITY"
    assert by_id["census1"]["bucket"] == "INTENTIONALLY_INERT"
    assert by_id["news1"]["bucket"] == "REQUIRES_NEW_OWNER_DECISION"
    assert by_id["diag1"]["bucket"] == "INTENTIONALLY_INERT"
    assert by_id["comp1"]["bucket"] == "RECOVERABLE_WITHOUT_OWNER"
    assert by_id["spawn1"]["bucket"] == "RECOVERABLE_WITHOUT_OWNER"
    assert by_id["sup2"]["bucket"] == "INTENTIONALLY_INERT"


def test_parked_claimable_unheld_row_is_no_repair(con):
    # Freshly materialized OPT_CENSUS cells carry no hold and are admitted by
    # the canonical selector: no OWNER decision or repair is missing at all.
    _item(con, "cell1", phase="OPT_CENSUS", ea="QM5_41478",
          payload={"schema": "qm.opt-census.v1"})
    con.commit()
    rows = fp.fetch_population_rows(con)
    _, parked_rows = fp.split_mc_populations(rows)
    ctx = _ctx_for(con, rows)
    claimability = {"selector_ids": {"cell1"}, "true_claimable_ids": {"cell1"}}
    classified = fp.classify_population(
        [], parked_rows, claimability=claimability, ram={}, ctx=ctx,
        receipt={})
    row = classified["parked_rows"][0]
    assert row["bucket"] == "RECOVERABLE_WITHOUT_OWNER"
    assert row["subcategory"] == "claimable_now_no_repair_needed"
    # not in the selector -> loud catch-all, never silently dropped
    classified2 = fp.classify_population(
        [], parked_rows, claimability={"selector_ids": set(),
                                       "true_claimable_ids": set()},
        ram={}, ctx=ctx, receipt={})
    assert classified2["parked_rows"][0]["subcategory"] == "unmapped_parked_row"


# ---------------------------------------------------------------------------
# RAM feasibility
# ---------------------------------------------------------------------------
def test_ram_feasibility_with_fake_tw(con):
    _item(con, "w1")
    con.commit()
    rows = fp.fetch_population_rows(con)
    tw = FakeTW(reservation_gb=12.0, floor_gb=14.0)
    ram = fp.compute_ram_feasibility(rows, free_ram_gb=30.0, tw_module=tw)
    assert ram["w1"]["feasible"] is True
    ram = fp.compute_ram_feasibility(rows, free_ram_gb=25.0, tw_module=tw)
    assert ram["w1"]["feasible"] is False  # 25 - 12 < 14
    ram = fp.compute_ram_feasibility(rows, free_ram_gb=None, tw_module=tw)
    assert ram["w1"]["feasible"] is None
    assert ram["w1"]["degraded_reason"]
    tw_fail = FakeTW(reservation_gb=12.0, fail=True)
    ram = fp.compute_ram_feasibility(rows, free_ram_gb=30.0,
                                     tw_module=tw_fail)
    assert ram["w1"]["feasible"] is None


def test_runtime_medians_and_forecast_helpers(tmp_path):
    ledger = tmp_path / "ledger.jsonl"
    rows = [
        {"outcome": "finished", "run_seconds": 300, "phase": "Q02"},
        {"outcome": "finished", "run_seconds": 420, "phase": "Q02"},
        {"outcome": "finished", "run_seconds": 600, "phase": "Q08"},
        {"outcome": "killed", "run_seconds": 100, "phase": "Q02"},
        {"outcome": "finished", "run_seconds": -5, "phase": "Q02"},
    ]
    ledger.write_text("\n".join(json.dumps(r) for r in rows), encoding="utf-8")
    med = fp.load_runtime_medians_minutes(ledger)
    assert med["degraded_reason"] is None
    assert med["by_phase"]["Q02"] == 6.0
    assert med["by_phase"]["Q08"] == 10.0
    assert fp.runtime_minutes_for("Q02", None, med) == 6.0
    assert fp.runtime_minutes_for("COMPILE_EA", None, med) == \
        fp.COMPILE_ESTIMATE_MINUTES
    assert fp.runtime_minutes_for("Q99", None, med) is None
    missing = fp.load_runtime_medians_minutes(tmp_path / "absent.jsonl")
    assert missing["by_phase"] == {}
    assert missing["degraded_reason"]


# ---------------------------------------------------------------------------
# health
# ---------------------------------------------------------------------------
def test_health_running():
    h = fp.classify_health(
        active=2, resource_feasible=0, forecast_hours=0.0,
        recoverable_high_value_rows=10, blocked_by=[], previous=None)
    assert h["classification"] == "RUNNING"
    assert h["FACTORY_IDLE_WITH_RUNNABLE_WORK"] == "GREEN"


def test_health_idle_red_requires_two_consecutive_runs():
    prev = {"health": {"classification": "IDLE_WITH_RUNNABLE_WORK",
                       "consecutive_idle_resource_feasible_runs": 1}}
    h = fp.classify_health(
        active=0, resource_feasible=3, forecast_hours=5.0,
        recoverable_high_value_rows=10, blocked_by=[], previous=prev)
    assert h["classification"] == "IDLE_RED"
    assert h["consecutive_idle_resource_feasible_runs"] == 2
    assert h["FACTORY_IDLE_WITH_RUNNABLE_WORK"] == "RED"
    first = fp.classify_health(
        active=0, resource_feasible=3, forecast_hours=5.0,
        recoverable_high_value_rows=10, blocked_by=[], previous=None)
    assert first["classification"] == "IDLE_WITH_RUNNABLE_WORK"
    assert first["FACTORY_IDLE_WITH_RUNNABLE_WORK"] == "GREEN"


def test_health_idle_resource_gated_names_blocker():
    blocked = [{"blocker": "ram_infeasible_now", "rows": 1,
                "reservation_gb": 37.9, "free_ram_gb": 43.2}]
    h = fp.classify_health(
        active=0, resource_feasible=0, forecast_hours=6.0,
        recoverable_high_value_rows=100, blocked_by=blocked, previous=None)
    # NO_RUNNABLE_WORK is forbidden while recoverable high-value work exists:
    # the classification must name what blocks.
    assert h["classification"] == "IDLE_RESOURCE_GATED"
    assert h["blocked_by"] == blocked
    assert h["FACTORY_BUFFER_LOW"] == "GREEN"


def test_health_buffer_low_and_no_runnable_work():
    low = fp.classify_health(
        active=0, resource_feasible=0, forecast_hours=1.5,
        recoverable_high_value_rows=5, blocked_by=[], previous=None)
    assert low["classification"] == "BUFFER_LOW"
    assert low["FACTORY_BUFFER_LOW"] == "AMBER"
    none = fp.classify_health(
        active=0, resource_feasible=0, forecast_hours=0.0,
        recoverable_high_value_rows=0, blocked_by=[], previous=None)
    assert none["classification"] == "NO_RUNNABLE_WORK"
    assert none["FACTORY_BUFFER_LOW"] == "GREEN"


# ---------------------------------------------------------------------------
# full document + persistence
# ---------------------------------------------------------------------------
def _seed_full(con):
    _item(con, "act1", phase="Q08", status="active", ea="QM5_5")
    _item(con, "run1", phase="Q06", ea="GOOD6")
    _item(con, "bad8", phase="Q08", ea="BAD8")
    _item(con, "ram1", phase="Q02", ea="QM5_9")
    _hold(con, "ram1", "RAM_RESERVATION_44GB_NOT_WINNABLE_20260914")
    _item(con, "sup1", phase="Q04", ea="QM5_7")
    con.execute("INSERT INTO work_item_supersedes VALUES ('sup1')")
    _item(con, "news1", phase="Q10_NEWS", ea="QM5_21505")
    _hold(con, "news1", "NEWS_CALENDAR_TAINTED")
    _item(con, "census1", phase="OPT_CENSUS", ea="QM5_41097")
    _hold(con, "census1", "PRESCREEN_SKIPPED")
    _item(con, "q12a", phase="Q12", kind="analytic", ea="QM5_10706",
          payload={"execution_lane": "GOVERNED_ANALYTIC_DISPATCH",
                   "program_id": "DL089_QM5_10706_GBPUSD_DWX_2019_2025"})
    con.commit()


def _patch_side_inputs(monkeypatch, tmp_path):
    monkeypatch.setattr(fp, "load_q12_receipt", lambda *a, **k: {
        "q12a": "PROGRAM_Q12_REBIND_REFUSED: program=X requested=Y",
    })
    monkeypatch.setattr(fp, "load_venue_eas",
                        lambda *a, **k: {"FTMO": {"QM5_21505"}, "DXZ": set()})
    ledger = tmp_path / "ledger.jsonl"
    ledger.write_text("\n".join(json.dumps(r) for r in [
        {"outcome": "finished", "run_seconds": 240, "phase": "Q02"},
        {"outcome": "finished", "run_seconds": 360, "phase": "Q06"},
        {"outcome": "finished", "run_seconds": 1590, "phase": "Q08"},
        {"outcome": "finished", "run_seconds": 600,
         "phase": "Q10_NEWS"},
    ]), encoding="utf-8")
    monkeypatch.setattr(fp, "TESTER_MEMORY_LEDGER", ledger)
    monkeypatch.setattr(fp, "second_chance_eligible_count", lambda *a, **k: 542)


def test_build_document_partitions_match_mc_counts(con, monkeypatch, tmp_path):
    _seed_full(con)
    _patch_side_inputs(monkeypatch, tmp_path)
    dsr = _dsr_module(monkeypatch)
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    doc = fp.build_document(
        con, now=NOW, previous=None, free_ram_gb=60.0, host_total_gb=63.1,
        tw_module=FakeTW(reservation_gb=12.0, floor_gb=14.0))
    assert doc["schema"] == "qm.factory-population/v1"
    fc = doc["four_counts"]
    # open pipeline = pending MT5-phase rows (act1 is active -> excluded)
    assert fc["OPEN_PIPELINE_ROWS"] == 4
    assert fc["ACTIVE_ECONOMIC_BACKTESTS"] == 1
    assert fc["TRUE_CLAIMABLE_WORK"] == 1  # run1 only; bad8 precheck-rejected
    assert fc["RESOURCE_FEASIBLE_RUNNABLE_WORK"] == 1
    open_part = doc["report_mapping"]["open_table"]
    assert open_part["partition_total"] == open_part["mission_control_open"]
    parked_part = doc["report_mapping"]["parked_table"]
    assert parked_part["partition_total"] == 3  # news1, census1, q12a
    assert parked_part["requires_new_owner_decision"] == 1
    assert parked_part["intentionally_inert"] == 2
    health = doc["health"]
    assert health["classification"] == "RUNNING"  # active=1
    # every classified row appears exactly once
    rows = doc["classification"]["open"]["rows"]
    assert len(rows) == len({r["id"] for r in rows}) == 4
    prows = doc["classification"]["parked"]["rows"]
    assert len(prows) == len({r["id"] for r in prows}) == 3
    # forecast: runnable row (Q06, 6 min) + authorized backlog components
    assert doc["forecast"]["RUNNABLE_NOW_HOURS"] == 0.1
    assert doc["forecast"]["FORECAST_RUNNABLE_HOURS"] > 0.1
    # backlog ranks are dense and unique
    ranks = [e["economic_priority_rank"] for e in doc["recoverable_backlog"]]
    assert ranks == sorted(ranks) and len(set(ranks)) == len(ranks)


def test_main_writes_population_and_legacy_outputs(tmp_path, monkeypatch):
    db = tmp_path / "farm.sqlite"
    c = sqlite3.connect(db)
    c.executescript(DDL)
    _seed_full(c)
    c.commit()
    c.close()
    out = tmp_path / "state" / "factory_population.json"
    legacy = tmp_path / "state" / "factory_three_numbers.json"
    dsr = _dsr_module(monkeypatch)
    monkeypatch.setattr(dsr, "claimability_precheck", _fake_precheck,
                        raising=False)
    monkeypatch.setattr(
        fp, "compute_ram_feasibility",
        lambda rows, *, free_ram_gb, tw_module=None: {
            r["id"]: {"reservation_gb": 12.0, "floor_gb": 14.0,
                      "feasible": True, "ram_class": "c", "source": "flat",
                      "degraded_reason": None} for r in rows})
    _patch_side_inputs(monkeypatch, tmp_path)
    monkeypatch.setattr(fp, "host_memory_gb", lambda: (63.1, 60.0))

    assert fp.main(["--db", str(db), "--output", str(out),
                    "--legacy-output", str(legacy)]) == 0
    doc = json.loads(out.read_text(encoding="utf-8"))
    assert doc["schema"] == "qm.factory-population/v1"
    old = json.loads(legacy.read_text(encoding="utf-8"))
    # legacy contract shape kept working for existing consumers
    assert old["schema"] == "qm.factory-three-numbers/v1"
    assert set(old["numbers"]) == {
        "active_economic_backtests", "true_claimable_work",
        "blocked_recoverable_work"}
    assert old["numbers"]["active_economic_backtests"] == 1

    # second consecutive idle run flips FACTORY_IDLE_WITH_RUNNABLE_WORK RED
    # when active=0 and resource-feasible>0.
    c = sqlite3.connect(db)
    c.execute("UPDATE work_items SET status='done', verdict='PASS' "
              "WHERE id='act1'")
    c.commit()
    c.close()
    assert fp.main(["--db", str(db), "--output", str(out),
                    "--legacy-output", str(legacy)]) == 0
    second = json.loads(out.read_text(encoding="utf-8"))
    assert second["four_counts"]["ACTIVE_ECONOMIC_BACKTESTS"] == 0
    assert second["four_counts"]["RESOURCE_FEASIBLE_RUNNABLE_WORK"] >= 1
    assert second["health"]["classification"] == "IDLE_WITH_RUNNABLE_WORK"
    assert second["health"]["FACTORY_IDLE_WITH_RUNNABLE_WORK"] == "GREEN"
    assert fp.main(["--db", str(db), "--output", str(out),
                    "--legacy-output", str(legacy)]) == 0
    third = json.loads(out.read_text(encoding="utf-8"))
    assert third["health"]["classification"] == "IDLE_RED"
    assert third["health"]["FACTORY_IDLE_WITH_RUNNABLE_WORK"] == "RED"
