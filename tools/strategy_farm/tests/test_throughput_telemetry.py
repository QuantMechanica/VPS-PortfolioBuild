"""Tests for split throughput telemetry (router task 6e9a724b).

Core acceptance criterion #3: a fixture with both a real execution row and a
``disposition_only=true`` row must count only the former as an execution verdict.
The 182-row OWNER-DEC-STRANDED-182 batch (forensics 2026-08-24 §1) is the reason.
"""
import datetime as dt
import json
import sqlite3

from tools.strategy_farm import health, throughput_telemetry


NOW = dt.datetime(2026, 8, 24, 12, 0, 0, tzinfo=dt.timezone.utc)


def _con() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT,
          status TEXT, verdict TEXT, payload_json TEXT,
          created_at TEXT, updated_at TEXT, gate_contract_version TEXT,
          claimed_by TEXT
        );
        """
    )
    return con


def _iso(hours_ago: float) -> str:
    return (NOW - dt.timedelta(hours=hours_ago)).isoformat()


def _insert(con, **kw):
    cols = ("id", "phase", "ea_id", "symbol", "status", "verdict", "payload_json",
            "created_at", "updated_at", "gate_contract_version", "claimed_by")
    row = {c: kw.get(c) for c in cols}
    con.execute(
        f"INSERT INTO work_items({','.join(cols)}) VALUES({','.join('?' for _ in cols)})",
        tuple(row[c] for c in cols),
    )


# ---------------------------------------------------------------------------
# Acceptance criterion #3 — disposition_only exclusion
# ---------------------------------------------------------------------------

def test_execution_count_excludes_disposition_only_row():
    con = _con()
    # A real Q07 tester completion.
    _insert(con, id="exec", phase="Q07", ea_id="QM5_1", symbol="EURUSD.DWX",
            status="done", verdict="PASS",
            payload_json=json.dumps({"claimed_at_iso": _iso(2)}),
            updated_at=_iso(1), gate_contract_version="v4")
    # An administrative OWNER-DEC-STRANDED disposition (no tester ran).
    _insert(con, id="dispo", phase="Q02", ea_id="QM5_2", symbol="GBPUSD.DWX",
            status="failed", verdict="INVALID",
            payload_json=json.dumps({
                "disposition_only": True,
                "owner_decision_id": "OWNER-DEC-STRANDED-182",
            }),
            updated_at=_iso(1), gate_contract_version="v4")

    metrics = throughput_telemetry.execution_vs_raw_by_phase(con, now=NOW)
    assert metrics["raw_total"] == 2
    assert metrics["execution_total"] == 1
    assert metrics["disposition_total"] == 1
    # Only the execution row's phase carries an execution count.
    assert metrics["by_phase"]["Q07"]["execution"] == 1
    assert metrics["by_phase"]["Q02"]["execution"] == 0
    assert metrics["by_phase"]["Q02"]["raw"] == 1


def test_disposition_only_string_true_also_excluded():
    con = _con()
    _insert(con, id="dispo", phase="Q02", status="failed", verdict="INVALID",
            payload_json=json.dumps({"disposition_only": "true"}),
            updated_at=_iso(1))
    metrics = throughput_telemetry.execution_vs_raw_by_phase(con, now=NOW)
    assert metrics["raw_total"] == 1
    assert metrics["execution_total"] == 0


def test_is_disposition_only_helper():
    assert throughput_telemetry.is_disposition_only(json.dumps({"disposition_only": True}))
    assert throughput_telemetry.is_disposition_only(json.dumps({"disposition_only": "TRUE"}))
    assert not throughput_telemetry.is_disposition_only(json.dumps({"disposition_only": False}))
    assert not throughput_telemetry.is_disposition_only("{}")
    assert not throughput_telemetry.is_disposition_only(None)
    assert not throughput_telemetry.is_disposition_only("not json")


def test_phase_labels_are_qxx_never_p_keys():
    con = _con()
    # Legacy P-key storage row, marked legacy contract -> must display as Qxx.
    _insert(con, id="legacy", phase="P4", status="done", verdict="PASS",
            payload_json="{}", updated_at=_iso(1), gate_contract_version="legacy")
    metrics = throughput_telemetry.execution_vs_raw_by_phase(con, now=NOW)
    assert all(not qid.startswith("P") for qid in metrics["by_phase"])
    assert "Q04" in metrics["by_phase"]


# ---------------------------------------------------------------------------
# Latency percentiles
# ---------------------------------------------------------------------------

def test_percentiles_nearest_rank():
    values = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    p = throughput_telemetry.percentiles(values, (50, 90, 99))
    assert p["p50"] == 50
    assert p["p90"] == 90
    assert p["p99"] == 100
    assert throughput_telemetry.percentiles([], (50,))["p50"] is None


def test_claim_to_complete_latency_excludes_dispositions_and_no_claim():
    con = _con()
    # 60-min tester latency.
    _insert(con, id="a", phase="Q07", status="done", verdict="PASS",
            payload_json=json.dumps({"claimed_at_iso": _iso(3)}),
            updated_at=_iso(2))
    # Disposition row: excluded even though it has a (spurious) claim stamp.
    _insert(con, id="b", phase="Q02", status="failed", verdict="INVALID",
            payload_json=json.dumps({"disposition_only": True,
                                     "claimed_at_iso": _iso(3)}),
            updated_at=_iso(2))
    # No claim stamp: skipped.
    _insert(con, id="c", phase="Q07", status="done", verdict="PASS",
            payload_json="{}", updated_at=_iso(2))
    m = throughput_telemetry.claim_to_complete_latency(con, now=NOW)
    assert m["sample_count"] == 1
    assert m["skipped_no_claim"] == 1
    assert m["p50"] == 60.0


# ---------------------------------------------------------------------------
# Active terminal-minutes by phase
# ---------------------------------------------------------------------------

def test_active_terminal_minutes_by_phase():
    con = _con()
    _insert(con, id="act", phase="Q10_NEWS", status="active", claimed_by="T5",
            payload_json=json.dumps({"claimed_at_iso": _iso(2)}),
            updated_at=_iso(0.5))
    # Non-active rows ignored.
    _insert(con, id="done", phase="Q07", status="done", verdict="PASS",
            payload_json="{}", updated_at=_iso(1))
    m = throughput_telemetry.active_terminal_minutes_by_phase(con, now=NOW)
    assert m["active_rows"] == 1
    # Qxx-family storage lane label (never a P-key); 2h claim age -> 120 minutes.
    assert m["by_phase"]["Q10_NEWS"] == 120.0
    assert all(not qid.startswith("P") for qid in m["by_phase"])


# ---------------------------------------------------------------------------
# Q10 cell throughput (filesystem, temp reports root)
# ---------------------------------------------------------------------------

def test_q10_cell_throughput_separates_receipts_from_exhausted(tmp_path):
    con = _con()
    _insert(con, id="wid1", phase="Q10_NEWS", status="active", claimed_by="T1",
            payload_json="{}", updated_at=_iso(1))
    cells = tmp_path / "wid1" / "q09_contract_v3" / "cells"
    (cells / "cell_a").mkdir(parents=True)
    (cells / "cell_b").mkdir(parents=True)
    (cells / "cell_a" / "cell_receipt.json").write_text("{}", encoding="utf-8")
    # Retry-exhausted: cell_failure_3.json present (MAX_FAILURE_OCCURRENCE=3).
    (cells / "cell_b" / "cell_failure_3.json").write_text("{}", encoding="utf-8")

    m = throughput_telemetry.q10_cell_throughput(
        con, now=NOW, reports_root=tmp_path, window_hours=24
    )
    assert m["parents_scanned"] == 1
    assert m["receipts"] == 1
    assert m["retry_exhausted"] == 1


# ---------------------------------------------------------------------------
# Health check wrappers
# ---------------------------------------------------------------------------

def test_chk_execution_verdict_throughput_warns_on_only_dispositions():
    con = _con()
    _insert(con, id="d1", phase="Q02", status="failed", verdict="INVALID",
            payload_json=json.dumps({"disposition_only": True}),
            updated_at=dt.datetime.now(dt.timezone.utc).isoformat())
    res = health.chk_execution_verdict_throughput(con)
    assert res["status"] == "WARN"
    assert res["value"]["execution"] == 0
    assert res["value"]["raw"] == 1


def test_chk_execution_verdict_throughput_ok_with_real_verdict():
    con = _con()
    _insert(con, id="e1", phase="Q07", status="done", verdict="PASS",
            payload_json="{}",
            updated_at=dt.datetime.now(dt.timezone.utc).isoformat())
    res = health.chk_execution_verdict_throughput(con)
    assert res["status"] == "OK"
    assert res["value"]["execution"] == 1


def test_chk_latency_and_active_minutes_are_visibility_ok():
    con = _con()
    res_lat = health.chk_claim_to_complete_latency(con)
    res_act = health.chk_active_terminal_minutes_by_phase(con)
    assert res_lat["status"] == "OK"
    assert res_act["status"] == "OK"
