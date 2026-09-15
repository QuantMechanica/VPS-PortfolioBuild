"""Hermetic tests for the AI orchestration-health read-model.

Every input is a temp fixture (sqlite DB, flag dir, state files, receipt dir);
the research-guard measurement and routing import are the only live seams, and
the determinism test stubs the guard so the output is a pure function of the
fixtures + a fixed ``now``.
"""
from __future__ import annotations

import datetime as dt
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import orchestration_health_readmodel as oh


NOW = dt.datetime(2026, 9, 15, 18, 0, 0, tzinfo=dt.timezone.utc)

AGENT_TASKS_DDL = """
CREATE TABLE agent_tasks (
    id TEXT PRIMARY KEY,
    task_type TEXT,
    state TEXT,
    priority INTEGER,
    required_capabilities_json TEXT,
    assigned_agent TEXT,
    verdict TEXT,
    payload_json TEXT,
    created_at TEXT,
    updated_at TEXT
);
CREATE TABLE spawn_leases (
    task_key TEXT PRIMARY KEY,
    agent_id TEXT,
    acquired_at TEXT,
    expires_at TEXT,
    owner_token TEXT,
    owner_pid INTEGER,
    owner_host TEXT,
    renewed_at TEXT
);
CREATE TABLE agent_task_transition_ledger (
    seq INTEGER PRIMARY KEY,
    idempotency_key TEXT,
    ts TEXT,
    task_id TEXT,
    action TEXT,
    from_state TEXT,
    to_state TEXT,
    reason TEXT,
    detail_json TEXT
);
"""


def _iso(days_ago=0.0, *, base=NOW):
    return (base - dt.timedelta(days=days_ago)).replace(microsecond=0).isoformat()


@pytest.fixture()
def fixture_db(tmp_path: Path) -> Path:
    path = tmp_path / "farm.sqlite"
    con = sqlite3.connect(path)
    con.executescript(AGENT_TASKS_DDL)

    def ins(tid, ttype, state, lane, *, prio=50, created=None, updated=None,
            req="[]"):
        con.execute(
            "INSERT INTO agent_tasks (id,task_type,state,priority,"
            "required_capabilities_json,assigned_agent,created_at,updated_at) "
            "VALUES (?,?,?,?,?,?,?,?)",
            (tid, ttype, state, prio, req, lane, created or _iso(0),
             updated or _iso(0)))

    # claude: 1 IN_PROGRESS with an expired lease (stale), 1 APPROVED today
    ins("ip-stale", "ops_issue", "IN_PROGRESS", "claude", created=_iso(0.02),
        updated=_iso(0.3))
    ins("appr-today", "ops_issue", "APPROVED", "claude", updated=_iso(0))
    # codex: an APPROVED 2 days ago (in window) + a stale TODO (>14d) + fresh TODO
    ins("appr-codex", "ops_issue", "APPROVED", "codex", updated=_iso(2))
    ins("todo-old", "ops_issue", "TODO", "codex", created=_iso(40), updated=_iso(40))
    ins("todo-new", "ops_issue", "TODO", "codex", created=_iso(1), updated=_iso(1))
    # gemini: research task (routing check: gemini has 'research','strategy')
    ins("gem-1", "research_strategy", "PASSED", "gemini", updated=_iso(3))
    # unassigned TODO older than 14d
    ins("todo-unassigned", "ops_issue", "TODO", None, created=_iso(30),
        updated=_iso(30))

    # exec-lease NOT present for ip-stale -> uncovered; router lease present + expired
    con.execute(
        "INSERT INTO spawn_leases (task_key,agent_id,owner_pid,acquired_at,expires_at) "
        "VALUES (?,?,?,?,?)",
        ("agent_task:ip-stale", "claude", None, _iso(0.3),
         (NOW - dt.timedelta(hours=6)).replace(microsecond=0).isoformat()))
    con.execute(
        "INSERT INTO agent_task_transition_ledger "
        "(seq,idempotency_key,ts,task_id,action,from_state,to_state) "
        "VALUES (1,'k','2026-09-14T00:00:00+00:00','x','claim','TODO','IN_PROGRESS')")
    con.commit()
    con.close()
    return path


def _write_state_fixtures(tmp_path, monkeypatch, *, with_kimi=True):
    """Point the module at hermetic flag + state files."""
    flag_dir = tmp_path / "farm"
    flag_dir.mkdir(exist_ok=True)
    state_dir = tmp_path / "state"
    state_dir.mkdir(exist_ok=True)
    monkeypatch.setattr(oh, "FLAG_DIR", flag_dir)
    monkeypatch.setattr(oh, "REPORTS_STATE", state_dir)
    # lane-gate flags: claude disabled, codex low tokens present
    (flag_dir / "CLAUDE_DISABLED.flag").write_text("throttle", encoding="utf-8")
    (flag_dir / "CODEX_LOW_TOKENS.flag").write_text("low", encoding="utf-8")
    # governor state
    monkeypatch.setattr(oh, "QUOTA_GOVERNOR_STATE", state_dir / "qg.json")
    (state_dir / "qg.json").write_text(json.dumps({
        "agents": {"claude": {"used_pct": 96.0, "action": "hold"},
                   "codex": {"used_pct": 80.0, "action": "hold"}}}), encoding="utf-8")
    for attr, name in (("CODEX_BUDGET_LINE", "cbl.json"), ("AGY_QUOTA", "agy.json"),
                       ("AGY_GOVERNOR_STATE", "agyg.json")):
        monkeypatch.setattr(oh, attr, state_dir / name)
        (state_dir / name).write_text("{}", encoding="utf-8")
    monkeypatch.setattr(oh, "KIMI_GOVERNOR_STATE", state_dir / "kg.json")
    monkeypatch.setattr(oh, "KIMI_QUOTA_STATE", state_dir / "kq.json")
    if with_kimi:
        (state_dir / "kg.json").write_text(json.dumps({
            "state": "NORMAL", "usage_source": "managed_usage_endpoint",
            "quota_fetch_status": "ok", "counts": {"day": 6, "week": 6}}),
            encoding="utf-8")
        (state_dir / "kq.json").write_text(json.dumps({
            "fetch_status": "ok", "source": "api.kimi.com/coding/v1/usages",
            "refresh_calls": 1, "last_ok": {"plan": "Allegro"}, "plan": "Allegro",
            "rolling_5h": {"used_ratio": 0.0}, "rolling_7d": {"used_ratio": 0.0}}),
            encoding="utf-8")


def _write_receipts(tmp_path, monkeypatch):
    rdir = tmp_path / "receipts"
    rdir.mkdir(exist_ok=True)
    monkeypatch.setattr(oh, "AGENT_CHAIN_RECEIPT_DIR", rdir)
    # same-vendor critic (independence reduced)
    (rdir / "a.json").write_text(json.dumps({
        "chain_id": "a", "task_id": "a", "status": "ok", "critic_verdict": "GAPS",
        "critic_fallback_used": False, "generated_at_utc": "2026-09-15T10:00:00Z",
        "plan": {"creator": {"vendor": "claude"}, "critic": {"vendor": "claude",
                 "cross_vendor": False}},
        "critic_seat_final": {"vendor": "claude"},
        "stages": [{"role": "creator", "status": "reused"},
                   {"role": "critic", "status": "ok", "cross_vendor": False}]}),
        encoding="utf-8")
    # cross-vendor critic (independent)
    (rdir / "b.json").write_text(json.dumps({
        "chain_id": "b", "task_id": "b", "status": "ok", "critic_verdict": "PASS",
        "critic_fallback_used": True, "generated_at_utc": "2026-09-15T11:00:00Z",
        "plan": {"creator": {"vendor": "claude"}, "critic": {"vendor": "agy",
                 "cross_vendor": True}},
        "critic_seat_final": {"vendor": "agy"},
        "stages": [{"role": "creator", "status": "reused"},
                   {"role": "critic", "status": "ok", "cross_vendor": True}]}),
        encoding="utf-8")
    return rdir


def _stub_guard(monkeypatch):
    monkeypatch.setattr(oh, "_research_guard_state", lambda: {
        "available": True, "allowed": True, "reasons": [],
        "scratch_free_gb": 46.0, "scratch_min_free_gb": 20.0})


def test_task_states_and_throughput(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    assert doc["schema"] == "qm.orchestration-health/v1"
    claude = doc["task_states_by_lane"]["claude"]
    assert claude["IN_PROGRESS"] == 1 and claude["APPROVED"] == 1
    tp = doc["throughput"]["approved_by_lane_day"]
    assert tp["claude"][_iso(0)[:10]] == 1
    assert tp["codex"][_iso(2)[:10]] == 1
    assert "updated_at_last_transition_proxy" in doc["throughput"]["method"]


def test_stale_detection(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    stale = doc["stale_tasks"]
    ids = [r["id"] for r in stale["in_progress_beyond_ttl"]]
    assert ids == ["ip-stale"]
    assert stale["in_progress_beyond_ttl"][0]["lease_expired"] is True
    # todo-old (codex, 40d) + todo-unassigned (30d) are stale; todo-new (1d) not
    assert stale["todo_stale_by_lane"]["codex"] == 1
    assert stale["todo_stale_by_lane"]["(unassigned)"] == 1
    assert stale["todo_stale_total"] == 2


def test_double_claim_guard(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    dc = doc["double_claim_guard"]
    assert dc["exec_lease_scheme_present"] is False
    assert dc["in_progress_without_exec_lease"] == ["ip-stale"]
    assert dc["router_leases_null_owner"] == 1


def test_critic_independence(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    cc = doc["critic_chain"]
    assert cc["completed"] == 2
    assert cc["cross_vendor_false"] == 1  # only receipt "a"
    assert cc["critic_fallback_used"] == 1  # only receipt "b"
    assert cc["same_vendor_share"] == 0.5
    assert cc["independence_degraded"] is True
    # most-recent first
    assert cc["recent"][0]["chain_id"] == "b"


def test_routing_correctness_clean(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    routing = doc["routing"]
    assert routing["available"] is True
    assert routing["mismatch"] == 0
    assert routing["ok"] == routing["sampled"]


def test_quota_flags_and_kimi(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    assert doc["quota_flags"]["CLAUDE_DISABLED.flag"]["present"] is True
    assert doc["lanes"]["claude"]["quota"]["flag_on"] is True
    assert doc["lanes"]["codex"]["quota"]["flag_on"] is True
    assert doc["lanes"]["gemini"]["quota"]["flag_on"] is False
    k = doc["kimi_telemetry"]
    assert k["usage_source"] == "managed_usage_endpoint"
    assert k["quota_fetch_status"] == "ok"
    assert k["refresh_calls"] == 1
    assert k["last_ok_present"] is True


def test_health_rollup_amber(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    assert doc["health"]["status"] == "AMBER"
    flags = doc["health"]["flags"]
    assert any(f.startswith("critic_same_vendor") for f in flags)
    assert "quota_flag_on:claude" in flags
    assert any(f.startswith("stale_in_progress") for f in flags)


def test_deterministic_byte_identical(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    a = oh.build_orchestration_health(fixture_db, now=NOW)
    b = oh.build_orchestration_health(fixture_db, now=NOW)
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)


def test_missing_db_fails_soft(tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    _write_receipts(tmp_path, monkeypatch)
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(tmp_path / "absent.sqlite", now=NOW)
    assert doc["db_error"] is not None
    assert doc["schema"] == "qm.orchestration-health/v1"
    # quota + kimi still populated from the state files
    assert doc["kimi_telemetry"]["present"] is True


def test_missing_receipts_evidence_missing(fixture_db, tmp_path, monkeypatch):
    _write_state_fixtures(tmp_path, monkeypatch)
    monkeypatch.setattr(oh, "AGENT_CHAIN_RECEIPT_DIR", tmp_path / "no_receipts")
    _stub_guard(monkeypatch)
    doc = oh.build_orchestration_health(fixture_db, now=NOW)
    assert doc["critic_chain"]["present"] is False
    assert doc["critic_chain"]["degraded_reason"] == "EVIDENCE_MISSING"
