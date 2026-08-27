"""Tests for the Q10 long-cell circuit breaker (router task cae3df77), following
docs/ops/evidence/2026-08-24_q10_long_cell_circuit_breaker.md (forensics
recommendation 2, case 13f41983).

Covers: pure threshold/telemetry logic, artifact-scan classification with real
temp dirs, the documented hold (work_item_holds) that stops re-claiming, the
health-surface entry, and the no-verdict + rollback-flag guarantees. No process
spawning, no live-DB mutation.
"""
import os
import sqlite3
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import q10_long_cell_breaker as breaker  # noqa: E402
import health  # noqa: E402


CT = breaker.CellTiming


# ---------------------------------------------------------------------------
# Pure threshold logic
# ---------------------------------------------------------------------------

def test_threshold_uses_3x_median_when_larger():
    # 3 * 3000 = 9000 > 7200 floor
    assert breaker.long_cell_threshold_seconds(3000.0, 7200.0) == 9000.0


def test_threshold_uses_floor_when_median_small():
    # 3 * 600 = 1800 < 7200 floor
    assert breaker.long_cell_threshold_seconds(600.0, 7200.0) == 7200.0


def test_threshold_falls_back_to_floor_when_no_median():
    # 13f41983 shape: 0 receipts -> no median -> configured timeout floor.
    assert breaker.long_cell_threshold_seconds(None, 7200.0) == 7200.0
    assert breaker.long_cell_threshold_seconds(0.0, 7200.0) == 7200.0


def test_cell_breaches_threshold_boundaries():
    assert breaker.cell_breaches_threshold(7201.0, 7200.0) is True
    assert breaker.cell_breaches_threshold(7200.0, 7200.0) is False
    assert breaker.cell_breaches_threshold(10.0, 7200.0) is False
    assert breaker.cell_breaches_threshold(None, 7200.0) is False


def test_parent_success_median_ignores_non_success():
    cells = [
        CT("a", "success", 600.0),
        CT("b", "success", 800.0),
        CT("c", "exhausted", 9000.0),
        CT("d", "inflight", 12000.0),
    ]
    assert breaker.parent_success_median_seconds(cells) == 700.0


def test_parent_success_median_none_when_no_success():
    cells = [CT("a", "exhausted", 9000.0), CT("b", "inflight", 12000.0)]
    assert breaker.parent_success_median_seconds(cells) is None


# ---------------------------------------------------------------------------
# Telemetry separation (acceptance criterion 3)
# ---------------------------------------------------------------------------

def test_telemetry_separates_success_from_exhaustion():
    cells = [
        CT("a", "success", 600.0),
        CT("b", "success", 720.0),
        CT("c", "exhausted", 15810.0),  # 263.5 min outlier from the case
        CT("d", "exhausted", 1842.0),
        CT("e", "inflight", 20130.0),
    ]
    tel = breaker.split_cell_telemetry(cells)
    assert tel["success_cell_seconds"] == [600.0, 720.0]
    assert tel["exhaustion_cell_seconds"] == [15810.0, 1842.0]
    assert tel["inflight_cell_seconds"] == [20130.0]
    # The two series must never be commingled.
    assert tel["success_cell_median_seconds"] == 660.0
    assert tel["exhaustion_cell_median_seconds"] == 8826.0
    assert set(tel["success_cell_seconds"]).isdisjoint(tel["exhaustion_cell_seconds"])


def test_telemetry_empty_series_have_none_medians():
    tel = breaker.split_cell_telemetry([CT("a", "inflight", 100.0)])
    assert tel["success_cell_seconds"] == []
    assert tel["exhaustion_cell_seconds"] == []
    assert tel["success_cell_median_seconds"] is None
    assert tel["exhaustion_cell_median_seconds"] is None


# ---------------------------------------------------------------------------
# evaluate_parent
# ---------------------------------------------------------------------------

def test_evaluate_flags_inflight_over_threshold_no_median():
    # No success -> threshold = floor (7200). One inflight cell at 3h breaches.
    cells = [
        CT("c0", "exhausted", 1842.0),
        CT("c1", "exhausted", 3000.0),
        CT("c2", "inflight", 10800.0),  # 3h > 7200
    ]
    ev = breaker.evaluate_parent("wid-1", cells, 7200.0)
    assert ev["breached"] is True
    assert ev["breaching_cells"] == ["c2"]
    assert ev["threshold_seconds"] == 7200.0


def test_evaluate_flags_exhausted_outlier_over_threshold():
    cells = [
        CT("c0", "exhausted", 15810.0),  # 263.5 min > floor
        CT("c1", "inflight", 100.0),
    ]
    ev = breaker.evaluate_parent("wid-2", cells, 7200.0)
    assert ev["breached"] is True
    assert "c0" in ev["breaching_cells"]


def test_evaluate_success_cells_never_breach():
    # A long-but-successful cell already produced a receipt; not occupying.
    cells = [CT("c0", "success", 99999.0), CT("c1", "success", 700.0)]
    ev = breaker.evaluate_parent("wid-3", cells, 7200.0)
    assert ev["breached"] is False
    assert ev["breaching_cells"] == []


def test_evaluate_healthy_parent_not_flagged():
    cells = [
        CT("c0", "success", 600.0),
        CT("c1", "success", 720.0),
        CT("c2", "inflight", 900.0),  # under 3x median (2160) and under floor
    ]
    ev = breaker.evaluate_parent("wid-4", cells, 7200.0)
    assert ev["breached"] is False


# ---------------------------------------------------------------------------
# Rollback flag + config
# ---------------------------------------------------------------------------

def test_breaker_enabled_default():
    assert breaker.breaker_enabled({}) is True


def test_breaker_disabled_via_rollback_flag():
    assert breaker.breaker_enabled({breaker.DISABLE_ENV: "1"}) is False
    assert breaker.breaker_enabled({breaker.DISABLE_ENV: "true"}) is False


def test_configured_cell_timeout_env_override():
    assert breaker.configured_cell_timeout_seconds({}) == breaker.DEFAULT_CELL_TIMEOUT_SECONDS
    assert breaker.configured_cell_timeout_seconds({breaker.CELL_TIMEOUT_ENV: "300"}) == 300.0
    # Invalid values fall back to default.
    assert breaker.configured_cell_timeout_seconds(
        {breaker.CELL_TIMEOUT_ENV: "nope"}
    ) == breaker.DEFAULT_CELL_TIMEOUT_SECONDS


# ---------------------------------------------------------------------------
# Artifact scanning (real temp dirs + mtimes)
# ---------------------------------------------------------------------------

def _make_run_dir(cell_dir: Path, window: str, ts: str, mtime: float) -> None:
    run_dir = cell_dir / "runs" / window / "QM5_1328" / ts
    run_dir.mkdir(parents=True, exist_ok=True)
    os.utime(run_dir, (mtime, mtime))


def _write_json(path: Path, mtime: float) -> None:
    path.write_text("{}", encoding="utf-8")
    os.utime(path, (mtime, mtime))


def test_scan_cell_success(tmp_path):
    now = 1_000_000.0
    cell = tmp_path / "control_off__m0__c0__s17"
    cell.mkdir()
    _make_run_dir(cell, "selection", "20260824_045951", now - 700.0)
    _write_json(cell / "cell_receipt.json", now - 100.0)
    timing = breaker.scan_cell_timing(cell, now)
    assert timing.status == "success"
    assert timing.wall_seconds == 600.0  # (now-100) - (now-700)


def test_scan_cell_exhausted(tmp_path):
    now = 1_000_000.0
    cell = tmp_path / "policy_on__m0__c1__s17"
    cell.mkdir()
    _make_run_dir(cell, "selection", "20260824_052707", now - 3600.0)
    for i in ("cell_failure.json", "cell_failure_2.json"):
        _write_json(cell / i, now - 3000.0)
    _write_json(cell / "cell_failure_3.json", now - 100.0)
    timing = breaker.scan_cell_timing(cell, now)
    assert timing.status == "exhausted"
    assert timing.wall_seconds == 3500.0  # (now-100) - (now-3600)


def test_scan_cell_inflight(tmp_path):
    now = 1_000_000.0
    cell = tmp_path / "policy_on__m1__c1__s17"
    cell.mkdir()
    _make_run_dir(cell, "selection", "20260824_053950", now - 12000.0)
    # Only two failures so far -> still within retry budget -> inflight.
    _write_json(cell / "cell_failure.json", now - 8000.0)
    _write_json(cell / "cell_failure_2.json", now - 4000.0)
    timing = breaker.scan_cell_timing(cell, now)
    assert timing.status == "inflight"
    assert timing.wall_seconds == 12000.0  # now - start


def test_scan_parent_cells_full_tree(tmp_path):
    now = 1_000_000.0
    cells_dir = tmp_path / "q09_contract_v3" / "cells"
    cells_dir.mkdir(parents=True)
    a = cells_dir / "control_off__m0__c0__s17"
    a.mkdir()
    _make_run_dir(a, "selection", "20260824_045951", now - 12000.0)
    _write_json(a / "cell_failure.json", now - 9000.0)
    _write_json(a / "cell_failure_2.json", now - 6000.0)
    _write_json(a / "cell_failure_3.json", now - 100.0)  # exhausted
    timings = breaker.scan_parent_cells(tmp_path, now)
    assert len(timings) == 1
    assert timings[0].status == "exhausted"


def test_inputs_mtime_fallback_before_current_claim_is_not_timed(tmp_path):
    now = 1_000_000.0
    cell = tmp_path / "control_off__m0__c0__s17"
    cell.mkdir()
    inputs = cell / "inputs.set"
    inputs.write_text("plan-only", encoding="utf-8")
    os.utime(inputs, (now - 20_000.0, now - 20_000.0))

    timing = breaker.scan_cell_timing(
        cell,
        now,
        claim_started_epoch=now - 600.0,
    )

    assert timing.status == "inflight"
    assert timing.wall_seconds is None


def test_inputs_mtime_fallback_within_current_claim_is_timed(tmp_path):
    now = 1_000_000.0
    cell = tmp_path / "control_off__m0__c0__s17"
    cell.mkdir()
    inputs = cell / "inputs.set"
    inputs.write_text("claim-local", encoding="utf-8")
    os.utime(inputs, (now - 300.0, now - 300.0))

    timing = breaker.scan_cell_timing(
        cell,
        now,
        claim_started_epoch=now - 600.0,
    )

    assert timing.status == "inflight"
    assert timing.wall_seconds == 300.0


# ---------------------------------------------------------------------------
# Database schema helpers
# ---------------------------------------------------------------------------

def _make_db(tmp_path: Path) -> Path:
    db = tmp_path / "farm_state.sqlite"
    con = sqlite3.connect(db)
    con.executescript(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT, phase TEXT,
            status TEXT, verdict TEXT, claimed_by TEXT, payload_json TEXT
        );
        CREATE TABLE work_item_holds (
            work_item_id TEXT PRIMARY KEY,
            hold_code TEXT NOT NULL,
            reason TEXT NOT NULL,
            active INTEGER NOT NULL DEFAULT 1,
            release_on_restart INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            released_at TEXT,
            release_note TEXT
        );
        """
    )
    con.commit()
    con.close()
    return db


def _claimable_ids(db: Path) -> set:
    """Mirror the ordinary claim predicate's hold filter (farmctl.py:1499)."""
    con = sqlite3.connect(db)
    rows = con.execute(
        """
        SELECT w.id FROM work_items w
        WHERE w.status='pending'
          AND NOT EXISTS (
            SELECT 1 FROM work_item_holds h
            WHERE h.work_item_id=w.id AND h.active=1
          )
        """
    ).fetchall()
    con.close()
    return {r[0] for r in rows}


# ---------------------------------------------------------------------------
# read_active_q10_parents
# ---------------------------------------------------------------------------

def test_read_active_q10_parents_real_db(tmp_path):
    db = _make_db(tmp_path)
    con = sqlite3.connect(db)
    con.executemany(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,claimed_by,payload_json) "
        "VALUES(?,?,?,?,?,?,?,?)",
        [
            ("p1", "QM5_1328", "EURJPY", "Q10_NEWS", "active", None, "T8", '{"claimed_at_iso":"2026-08-27T05:34:20Z"}'),
            ("p2", "QM5_1", "XAUUSD", "Q10", "pending", None, None, "{}"),
            ("p3", "QM5_2", "GBPUSD", "Q10_NEWS", "done", "PASS", None, "{}"),  # terminal
            ("p4", "QM5_3", "USDJPY", "Q09_NEWS", "active", None, "T4", '{"claimed_at_iso":"2026-08-27T05:34:20Z"}'),  # wrong phase
            ("p5", "QM5_4", "USDJPY", "Q10_NEWS", "active", None, None, '{"claimed_at_iso":"2026-08-27T05:34:20Z"}'),  # no holder
            ("p6", "QM5_5", "USDJPY", "Q10_NEWS", "active", None, "T5", "{}"),  # no claim time
        ],
    )
    con.commit()
    con.close()
    parents = breaker.read_active_q10_parents(db)
    ids = {p["id"] for p in parents}
    assert ids == {"p1"}
    assert parents[0]["claimed_by"] == "T8"
    assert parents[0]["claimed_at_epoch"] > 0


def test_read_active_q10_parents_missing_db_fails_open(tmp_path):
    assert breaker.read_active_q10_parents(tmp_path / "nope.sqlite") == []


# ---------------------------------------------------------------------------
# write_long_cell_hold — no verdict, no overwrite of a different hold
# ---------------------------------------------------------------------------

def test_write_long_cell_hold_writes_row_without_verdict(tmp_path):
    db = _make_db(tmp_path)
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,payload_json) "
        "VALUES('p1','QM5_1328','EURJPY','Q10_NEWS','active',NULL,'{}')"
    )
    con.commit()
    applied = breaker.write_long_cell_hold(con, "p1", reason="over threshold", now="2026-08-24T13:00:00Z")
    con.commit()
    assert applied is True
    hold = con.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id='p1'"
    ).fetchone()
    assert hold == (breaker.HOLD_CODE, 1)
    # Criterion 1: verdict + status untouched.
    row = con.execute("SELECT status,verdict FROM work_items WHERE id='p1'").fetchone()
    assert row == ("active", None)
    con.close()


def test_write_long_cell_hold_never_overwrites_different_hold(tmp_path):
    db = _make_db(tmp_path)
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,payload_json) "
        "VALUES('p1','QM5_1328','EURJPY','Q10_NEWS','pending',NULL,'{}')"
    )
    con.execute(
        "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
        "release_on_restart,created_at,updated_at) "
        "VALUES('p1','Q09_AWAITING_SEALED_PLAN','other',1,0,'t','t')"
    )
    con.commit()
    applied = breaker.write_long_cell_hold(con, "p1", reason="x")
    con.commit()
    assert applied is False
    hold_code = con.execute(
        "SELECT hold_code FROM work_item_holds WHERE work_item_id='p1'"
    ).fetchone()[0]
    assert hold_code == "Q09_AWAITING_SEALED_PLAN"
    con.close()


# ---------------------------------------------------------------------------
# Integration: run(apply=True) flags a breaching parent, stops re-claiming,
# writes no verdict; and the rollback flag suppresses all writes.
# ---------------------------------------------------------------------------

def _seed_breaching_parent(
    tmp_path: Path,
    *,
    status: str = "active",
    claimed_by: str | None = "T8",
    claim_age_seconds: float = 18_000.0,
    plan_only: bool = False,
) -> Path:
    db = _make_db(tmp_path)
    now = time.time()
    claimed_at = time.strftime(
        "%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - claim_age_seconds)
    )
    payload = '{"claimed_at_iso":"' + claimed_at + '"}'
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,claimed_by,payload_json) "
        "VALUES('13f41983','QM5_1328','EURJPY','Q10_NEWS',?,NULL,?,?)",
        (status, claimed_by, payload),
    )
    con.commit()
    con.close()
    # Artifacts: a parent with 0 receipts, one exhausted cell far over floor.
    cells_dir = tmp_path / "reports" / "13f41983" / "q09_contract_v3" / "cells"
    cells_dir.mkdir(parents=True)
    cell = cells_dir / "control_off__m0__c0__s17"
    cell.mkdir()
    if plan_only:
        inputs = cell / "inputs.set"
        inputs.write_text("old plan", encoding="utf-8")
        os.utime(inputs, (now - 20_000.0, now - 20_000.0))
        return db
    _make_run_dir(cell, "selection", "20260824_052707", now - 16000.0)
    for i in ("cell_failure.json", "cell_failure_2.json"):
        _write_json(cell / i, now - 12000.0)
    _write_json(cell / "cell_failure_3.json", now - 100.0)  # ~4.4h wall, exhausted
    return db


def test_run_apply_flags_parent_writes_hold_no_verdict_stops_reclaim(tmp_path):
    db = _seed_breaching_parent(tmp_path)
    reports_root = tmp_path / "reports"

    result = breaker.run(
        db_path=db, reports_root=reports_root, apply=True, env={}
    )
    assert result.parents_scanned == 1
    assert result.parents_breached == 1
    assert result.holds_written == 1

    # Criterion 1: no verdict written, status untouched.
    con = sqlite3.connect(db)
    row = con.execute(
        "SELECT status,verdict FROM work_items WHERE id='13f41983'"
    ).fetchone()
    assert row == ("active", None)
    hold = con.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id='13f41983'"
    ).fetchone()
    con.execute(
        "UPDATE work_items SET status='pending', claimed_by=NULL "
        "WHERE id='13f41983'"
    )
    con.commit()
    con.close()
    assert hold == (breaker.HOLD_CODE, 1)

    # Once the worker releases the parent back to pending, the documented hold
    # prevents another claim without mutating the pipeline verdict.
    assert "13f41983" not in _claimable_ids(db)

    # Criterion 3: telemetry separates the (empty) success series from the
    # exhaustion series.
    tel = result.parents[0]["telemetry"]
    assert tel["success_cell_seconds"] == []
    assert len(tel["exhaustion_cell_seconds"]) == 1
    assert tel["exhaustion_cell_seconds"][0] > breaker.DEFAULT_CELL_TIMEOUT_SECONDS


def test_run_dry_run_writes_no_hold(tmp_path):
    db = _seed_breaching_parent(tmp_path)
    result = breaker.run(
        db_path=db, reports_root=tmp_path / "reports", apply=False, env={}
    )
    assert result.parents_breached == 1
    assert result.holds_written == 0
    con = sqlite3.connect(db)
    assert con.execute(
        "SELECT COUNT(*) FROM work_item_holds WHERE work_item_id='13f41983'"
    ).fetchone()[0] == 0
    con.close()


def test_run_excludes_never_claimed_pending_parent(tmp_path):
    db = _seed_breaching_parent(
        tmp_path,
        status="pending",
        claimed_by=None,
    )
    result = breaker.run(
        db_path=db,
        reports_root=tmp_path / "reports",
        apply=True,
        env={},
    )
    assert result.parents_scanned == 0
    assert result.parents_breached == 0
    assert result.holds_written == 0


def test_run_old_plan_mtime_does_not_age_new_active_claim(tmp_path):
    db = _seed_breaching_parent(
        tmp_path,
        claim_age_seconds=600.0,
        plan_only=True,
    )
    result = breaker.run(
        db_path=db,
        reports_root=tmp_path / "reports",
        apply=True,
        env={},
    )
    assert result.parents_scanned == 1
    assert result.parents_breached == 0
    assert result.holds_written == 0


def test_run_disabled_via_rollback_flag_writes_nothing(tmp_path):
    db = _seed_breaching_parent(tmp_path)
    result = breaker.run(
        db_path=db,
        reports_root=tmp_path / "reports",
        apply=True,
        env={breaker.DISABLE_ENV: "1"},
    )
    assert result.enabled is False
    assert result.parents_scanned == 0
    assert result.holds_written == 0
    con = sqlite3.connect(db)
    assert con.execute(
        "SELECT COUNT(*) FROM work_item_holds WHERE work_item_id='13f41983'"
    ).fetchone()[0] == 0
    con.close()


# ---------------------------------------------------------------------------
# Health surface (criterion 1: a health-check entry, no verdict)
# ---------------------------------------------------------------------------

def _health_con(db: Path) -> sqlite3.Connection:
    con = sqlite3.connect(db)
    con.row_factory = sqlite3.Row
    return con


def test_health_check_ok_when_no_holds(tmp_path):
    db = _make_db(tmp_path)
    con = _health_con(db)
    out = health.chk_q10_long_cell_breaker_holds(con)
    con.close()
    assert out["name"] == "q10_long_cell_breaker_holds"
    assert out["status"] == "OK"
    assert out["value"] == 0


def test_health_check_warns_when_hold_present(tmp_path):
    db = _make_db(tmp_path)
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,payload_json) "
        "VALUES('13f41983','QM5_1328','EURJPY','Q10_NEWS','pending',NULL,'{}')"
    )
    breaker.write_long_cell_hold(con, "13f41983", reason="over threshold")
    con.commit()
    con.close()

    con = _health_con(db)
    out = health.chk_q10_long_cell_breaker_holds(con)
    con.close()
    assert out["status"] == "WARN"
    assert out["value"] == 1
    # The health entry is a status/detail row, never a pipeline verdict field.
    assert "verdict" not in out
    assert out["status"] in {"OK", "WARN", "FAIL"}


def test_health_check_fails_when_hold_aged(tmp_path):
    db = _make_db(tmp_path)
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,payload_json) "
        "VALUES('13f41983','QM5_1328','EURJPY','Q10_NEWS','pending',NULL,'{}')"
    )
    # Held 10h ago -> beyond the 6h fail window.
    old = "2026-08-24T00:00:00Z"
    con.execute(
        "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
        "release_on_restart,created_at,updated_at) VALUES(?,?,?,1,0,?,?)",
        ("13f41983", breaker.HOLD_CODE, "aged", old, old),
    )
    con.commit()
    con.close()

    con = _health_con(db)
    # Freeze "now" well past the 6h window relative to the hold timestamp.
    import datetime as dt

    orig = health._utc_now
    health._utc_now = lambda: dt.datetime(2026, 8, 24, 12, 0, 0, tzinfo=dt.timezone.utc)
    try:
        out = health.chk_q10_long_cell_breaker_holds(con)
    finally:
        health._utc_now = orig
    con.close()
    assert out["status"] == "FAIL"
