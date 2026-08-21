"""Tests for the Mission Control v2 data-contract emitter.

Two layers:
  * unit tests on the progress-counting definitions over fixture rows (the KPIs
    a renderer must be able to trust identically across windows);
  * an integration test that builds the whole contract from a fixture DB and
    proves it is schema-valid, plus a smoke test that the LIVE emitter output
    (if the preview file exists) validates against the embedded schema.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import mission_control_v2_data as mc


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY,
    kind TEXT,
    phase TEXT,
    ea_id TEXT,
    symbol TEXT,
    setfile_path TEXT,
    status TEXT,
    verdict TEXT,
    attempt_count INTEGER,
    parent_task_id TEXT,
    evidence_path TEXT,
    claimed_by TEXT,
    payload_json TEXT,
    created_at TEXT,
    updated_at TEXT
);
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY,
    task_type TEXT,
    state TEXT,
    priority INTEGER,
    verdict TEXT,
    updated_at TEXT
);
CREATE TABLE portfolio_candidates (
    ea_id TEXT,
    symbol TEXT,
    state TEXT,
    updated_at TEXT
);
"""

NOW = dt.datetime(2026, 8, 21, 14, 0, 0, tzinfo=dt.timezone.utc)


def _iso(days_ago: int = 0, *, base: dt.datetime = NOW) -> str:
    return (base - dt.timedelta(days=days_ago)).replace(microsecond=0).isoformat()


def _insert(con, row_id, phase, ea_id, symbol, status, verdict, *,
            claimed_by=None, updated=None, created=None):
    con.execute(
        "INSERT INTO work_items (id,phase,ea_id,symbol,status,verdict,claimed_by,"
        "created_at,updated_at) VALUES (?,?,?,?,?,?,?,?,?)",
        (row_id, phase, ea_id, symbol, status, verdict, claimed_by,
         created or updated or _iso(0), updated or _iso(0)),
    )


@pytest.fixture()
def fixture_db(tmp_path: Path) -> Path:
    path = tmp_path / "farm.sqlite"
    con = sqlite3.connect(path)
    con.executescript(WORK_ITEMS_DDL)

    # --- TODAY: Q04 completions covering every progress bucket ---
    _insert(con, "t-pass1", "Q04", "QM5_1", "EURUSD.DWX", "done", "PASS", updated=_iso(0))
    _insert(con, "t-pass2", "Q04", "QM5_2", "GBPUSD.DWX", "done", "PASS", updated=_iso(0))
    _insert(con, "t-fail", "Q04", "QM5_3", "USDJPY.DWX", "done", "FAIL", updated=_iso(0))
    _insert(con, "t-zero", "Q02", "QM5_4", "AUDUSD.DWX", "failed", "ZERO_TRADES", updated=_iso(0))
    # infra: on-disk done but INFRA_FAIL -> clean view restamps to failed/infra
    _insert(con, "t-infra", "Q04", "QM5_5", "NZDUSD.DWX", "done", "INFRA_FAIL", updated=_iso(0))
    # same pair touched twice today -> distinct pair counted once
    _insert(con, "t-pass1b", "Q06", "QM5_1", "EURUSD.DWX", "done", "PASS", updated=_iso(0))

    # --- YESTERDAY ---
    _insert(con, "y-pass", "Q04", "QM5_6", "EURUSD.DWX", "done", "PASS", updated=_iso(1))
    _insert(con, "y-fail", "Q05", "QM5_7", "GBPUSD.DWX", "done", "FAIL_HARD", updated=_iso(1))

    # --- older, still inside 7d ---
    _insert(con, "o-pass", "Q04", "QM5_8", "EURUSD.DWX", "done", "PASS", updated=_iso(3))

    # --- a NON-MT5 phase completion (Q09_NEWS) must NOT count as progress ---
    _insert(con, "news-done", "Q09_NEWS", "QM5_9", "EURUSD.DWX", "done", "CONFIG_LOCKED", updated=_iso(0))

    # --- ACTIVE claims for the terminal join ---
    _insert(con, "act-t1", "Q07", "QM5_11165", "AUDCAD.DWX", "active", None, claimed_by="T1", updated=_iso(0))
    _insert(con, "act-t4", "Q04", "QM5_20203", "EURUSD", "active", None, claimed_by="T4", updated=_iso(0))

    # --- PENDING backlog: executable (Q04) + parked (Q09_NEWS) ---
    for i in range(5):
        _insert(con, f"pend-q04-{i}", "Q04", f"QM5_p{i}", "EURUSD.DWX", "pending", None,
                created=_iso(2), updated=_iso(2))
    _insert(con, "pend-news", "Q09_NEWS", "QM5_pn", "EURUSD.DWX", "pending", None,
            created=_iso(2), updated=_iso(2))

    # --- owner decision inputs ---
    con.execute(
        "INSERT INTO agent_tasks (id,task_type,state,verdict,updated_at) VALUES "
        "(?,?,?,?,?)",
        ("blk-1", "deploy_gate", "BLOCKED", "waiting on OWNER sign-off", _iso(0)),
    )
    con.execute(
        "INSERT INTO agent_tasks (id,task_type,state,verdict,updated_at) VALUES "
        "(?,?,?,?,?)",
        ("blk-2", "old_gate", "BLOCKED", "OWNER decision superseded by DL-084", _iso(0)),
    )
    con.execute(
        "INSERT INTO portfolio_candidates (ea_id,symbol,state,updated_at) VALUES "
        "(?,?,?,?)",
        ("QM5_1", "EURUSD.DWX", "Q12_REVIEW_READY", _iso(0)),
    )
    con.commit()
    con.close()
    return path


# ---------------------------------------------------------------------------
# progress-definition unit tests
# ---------------------------------------------------------------------------
def test_classify_progress_buckets():
    rows = [
        {"ea_id": "A", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "PASS"},
        {"ea_id": "A", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "PASS_SOFT"},  # pass-family
        {"ea_id": "B", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "FAIL_HARD"},
        {"ea_id": "C", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "ZERO_TRADES"},
        {"ea_id": "D", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "MULTI_SEED_MIXED"},
        {"ea_id": "E", "symbol": "S", "verdict_taxonomy": "infra", "verdict": "INFRA_FAIL"},
        {"ea_id": "F", "symbol": "S", "verdict_taxonomy": "invalid", "verdict": "INVALID"},
        {"ea_id": "G", "symbol": "S", "verdict_taxonomy": "strategy", "verdict": "CONFIG_LOCKED"},
    ]
    kpi = mc._classify_progress(rows)
    assert kpi["completed"] == 8
    # PASS, PASS_SOFT, CONFIG_LOCKED = 3 pass-family
    assert kpi["gate_pass"] == 3
    # FAIL_HARD, ZERO_TRADES, MULTI_SEED_MIXED = 3 economic fails
    assert kpi["economic_fail"] == 3
    assert kpi["infra_transient"] == 2  # infra + invalid
    assert kpi["distinct_ea_symbol"] == 7  # A appears twice
    assert kpi["infra_rate"] == round(2 / 8, 4)


def test_progress_windows_and_mt5_scope(fixture_db):
    con = mc._connect_ro(fixture_db)
    try:
        prog = mc.build_progress(con, now=NOW)
    finally:
        con.close()

    today = prog["today"]
    # 6 MT5 rows today (2xPASS, FAIL, ZERO, INFRA, +second PASS for pair QM5_1);
    # the Q09_NEWS done row is NON-MT5 and excluded.
    assert today["completed"] == 6
    assert today["gate_pass"] == 3          # t-pass1, t-pass2, t-pass1b
    assert today["economic_fail"] == 2      # FAIL + ZERO_TRADES
    assert today["infra_transient"] == 1    # INFRA_FAIL restamped
    # QM5_1/EURUSD touched twice today -> one distinct pair
    assert today["distinct_ea_symbol"] == 5

    assert prog["yesterday"]["completed"] == 2
    assert prog["yesterday"]["gate_pass"] == 1
    assert prog["yesterday"]["economic_fail"] == 1

    # total 'since' present and mixed-era caveat documented
    assert prog["total"]["since"] is not None
    assert any("era" in c.lower() for c in prog["caveats"])
    # seven-day average is a true per-day mean (<= completed over window)
    assert prog["seven_day_average"]["_basis"].startswith("mean of the 7")


def test_queue_eta_excludes_parked(fixture_db):
    con = mc._connect_ro(fixture_db)
    try:
        q = mc.build_queue(con, now=NOW)
    finally:
        con.close()
    assert q["pending_executable"] == 5   # 5 Q04 pending
    assert q["pending_parked"] == 1       # Q09_NEWS pending excluded from ETA
    assert q["active"] == 2
    # throughput measured, ETA computed and positive
    assert q["eta_to_empty"]["throughput_per_hour_24h"] > 0
    assert q["eta_to_empty"]["eta_hours_p50"] is not None
    # parked phase surfaced separately, in Qxx display form
    parked_phases = {r["phase_qid"] for r in q["by_phase_parked"]}
    assert "Q09_NEWS" in parked_phases


def test_terminals_join_surfaces_assignment(fixture_db):
    con = mc._connect_ro(fixture_db)
    try:
        t = mc.build_terminals(
            con,
            {"QM5_11165": "weiss-rsi-ma"},
            now=NOW,
            reservations_override={},
        )
    finally:
        con.close()
    assert len(t["terminals"]) == 10
    by_name = {r["terminal"]: r for r in t["terminals"]}
    t1 = by_name["T1"]
    assert t1["state"] == "RUNNING"
    assert t1["ea_id"] == "QM5_11165"
    assert t1["ea_slug"] == "weiss-rsi-ma"
    assert t1["symbol"] == "AUDCAD.DWX"
    assert t1["phase_qid"] == "Q07"       # Qxx only, never a P-key
    assert t1["work_item_id"] == "act-t1"
    assert t1["elapsed_seconds"] is not None
    # T2 has no claim -> IDLE with a reason
    assert by_name["T2"]["state"] == "IDLE"
    assert by_name["T2"]["idle_reason"]
    assert t["counts"]["running"] == 2


def test_owner_decisions_excludes_superseded(fixture_db, monkeypatch, tmp_path):
    # point the curated feed at a fixture file
    feed = tmp_path / "owner_decisions.json"
    feed.write_text(json.dumps({
        "updated_at_utc": NOW.isoformat(),
        "items": [
            {"cat": "FTMO GO/NO-GO", "title": "Paid challenge", "detail": "gate",
             "due": "2026-07-12", "severity": "info"},
        ],
    }), encoding="utf-8")
    monkeypatch.setattr(mc, "OWNER_DECISIONS_FILE", feed)

    con = mc._connect_ro(fixture_db)
    try:
        o = mc.build_owner_decisions(con, now=NOW)
    finally:
        con.close()
    titles = [i["title"] for i in o["items"]]
    # curated item present
    assert "Paid challenge" in titles
    # BLOCKED naming OWNER present; superseded one excluded
    assert any(i["source"] == "blocked_agent_task" for i in o["items"])
    assert not any("superseded" in (i["detail"] or "").lower() for i in o["items"])
    # Q12 admission row injected (count from fixture = 1)
    assert o["q12_review_ready"] == 1
    assert any(i["category"] == "ADMISSION" for i in o["items"])


# ---------------------------------------------------------------------------
# whole-contract validation
# ---------------------------------------------------------------------------
def test_full_contract_is_schema_valid(fixture_db, monkeypatch, tmp_path):
    feed = tmp_path / "owner_decisions.json"
    feed.write_text(json.dumps({"updated_at_utc": NOW.isoformat(), "items": []}),
                    encoding="utf-8")
    monkeypatch.setattr(mc, "OWNER_DECISIONS_FILE", feed)
    monkeypatch.setattr(mc, "HEALTH_FILE", tmp_path / "missing_health.json")

    contract = mc.build_contract(fixture_db, now=NOW)
    # must not raise
    mc.validate_contract(contract)
    assert contract["schema_version"] == "qm.mission_control.v2"
    assert contract["control_strip"]["factory_state"] in (
        "NOMINAL", "DEGRADED", "MAINTENANCE", "CRITICAL")
    assert len(contract["terminals"]["terminals"]) == 10


def test_validator_rejects_bad_document():
    bad = {"schema_version": "wrong"}
    with pytest.raises(mc.ContractValidationError):
        mc.validate_contract(bad)


def test_live_preview_validates_if_present():
    """If a live emitter run has produced the preview file, it must validate."""
    preview = mc.OUTPUT_PATH
    if not preview.exists():
        pytest.skip("no live preview file present")
    doc = json.loads(preview.read_text(encoding="utf-8"))
    mc.validate_contract(doc)
    assert doc["schema_version"] == "qm.mission_control.v2"
