import json
import sqlite3
import sys
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import farmctl
import health
import monitor_budget as mb
import terminal_worker as worker


@pytest.mark.parametrize("runtime,expected", [(5406.734, True), (5292, True), (5508, True),
                                              (5291.99, False), (5508.01, False), (5, False),
                                              (float("nan"), False), (float("inf"), False)])
def test_runtime_boundary_overrides_incomplete_launch_log(runtime, expected):
    payload = {"worker_exit_record": {"tester_runtime_seconds": runtime, "effective_monitor_budget_seconds": 5400}}
    r = farmctl.classify_summary_missing_run(payload, "run_smoke.stage=resolved_terminal")
    assert (r["failure_subclass"] == mb.SUBCLASS) is expected
    if expected:
        assert r["failure_class"] == mb.FAILURE_CLASS and r["deterministic"]
        assert r["retryable"] and r["retry_requires_budget_review"]


@pytest.mark.parametrize("budget", [None, 0, -1, "bad", float("nan"), float("inf")])
def test_unrecorded_or_bad_budget_is_not_inferred(budget):
    assert mb.classify({"tester_runtime_seconds": 5400, "effective_monitor_budget_seconds": budget}) is None


def test_explicit_kill_even_if_wall_clock_overshot_and_stale_attempt_rejected():
    marker = {"reason": mb.SUBCLASS, "started_at_iso": "2026-09-04T10:00:00Z",
              "tester_runtime_seconds": 7000, "effective_monitor_budget_seconds": 5400}
    assert mb.classify({"monitor_kill": marker})["failure_subclass"] == mb.SUBCLASS
    assert mb.classify({"monitor_kill": marker, "started_at_iso": "new attempt"}) is None
    assert mb.classify({"monitor_kill": {"reason": "post_exit_watchdog"}}) is None


def seeded_connection(path):
    conn = sqlite3.connect(path); conn.row_factory = sqlite3.Row
    conn.executescript("""
      CREATE TABLE work_items(id TEXT PRIMARY KEY,kind,phase,status,verdict,claimed_by,payload_json,updated_at,attempt_count);
      CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,hold_code,reason,active,release_on_restart,created_at,updated_at,released_at,release_note);
      CREATE TABLE events(ts,entity_type,entity_id,event,detail_json);
    """)
    conn.execute("INSERT INTO work_items VALUES('x','backtest','Q07','active',NULL,'T10','{}','old',2)")
    conn.commit()
    return conn


def test_finish_missing_summary_requeues_with_hold_without_burning_attempt(tmp_path):
    conn = seeded_connection(tmp_path / "test.sqlite")
    marker = {"monitor_kill": True, "reason": mb.SUBCLASS, "effective_monitor_budget_seconds": 5400,
              "tester_runtime_seconds": 5406.734}
    with patch.object(farmctl, "connect", return_value=conn), patch.object(worker, "_find_work_item_summary_data", return_value=None):
        result = worker._finish_work_item(tmp_path, "x", None, runtime_payload_updates={"worker_exit_record": marker})
    assert result["status"] == "pending" and result["retry_requires_budget_review"]
    row = conn.execute("SELECT * FROM work_items").fetchone()
    assert row["attempt_count"] == 2 and row["verdict"] is None and row["claimed_by"] is None
    assert json.loads(row["payload_json"])["monitor_budget_review"]["required"]
    hold = conn.execute("SELECT * FROM work_item_holds").fetchone()
    assert hold["active"] == 1 and hold["release_on_restart"] == 0 and hold["hold_code"] == mb.HOLD_CODE
    assert conn.execute("SELECT event FROM events").fetchone()[0] == mb.SUBCLASS
    conn.close()


def test_existing_owner_hold_is_preserved(tmp_path):
    conn = seeded_connection(tmp_path / "test.sqlite")
    conn.execute("INSERT INTO work_item_holds VALUES('x','OWNER_HOLD','retain',1,0,'old','old',NULL,NULL)")
    item = conn.execute("SELECT * FROM work_items").fetchone()
    worker._requeue_for_monitor_budget_review(conn, item, {}, farmctl.utc_now(), {"evidence": "test"})
    assert conn.execute("SELECT hold_code FROM work_item_holds").fetchone()[0] == "OWNER_HOLD"
    conn.close()


def test_monitor_kill_is_logged_before_stop_and_reaches_run_result(tmp_path):
    conn = seeded_connection(tmp_path / "test.sqlite")
    conn.execute("UPDATE work_items SET payload_json=?", (json.dumps({"pid": 999999}),))
    conn.commit()
    log = tmp_path / "work_item_x.log"
    clock = iter([0, 5406.734, 5406.734])
    observed = []

    def stop(_pid):
        observed.append(json.loads(log.read_text().strip())["monitor_kill"])
        stored = json.loads(conn.execute("SELECT payload_json FROM work_items").fetchone()[0])
        assert stored["monitor_kill"]["monitor_kill"] is True
        return True

    with (patch.object(worker.time, "monotonic", side_effect=lambda: next(clock)),
          patch.object(worker, "_monitor_deadline_monotonic", return_value=5400),
          patch.object(worker, "_monitor_timeout_seconds", return_value=5400),
          patch.object(worker, "_bound_runner_identity", return_value={"alive": True}),
          patch.object(farmctl, "connect", return_value=conn),
          patch.object(farmctl, "_stop_pid_tree", side_effect=stop),
          patch.object(worker, "_stop_terminal_slot_for_release", return_value=True),
          patch.object(worker, "_verify_and_record_staged_ex5"),
          patch.object(worker, "_find_work_item_summary_data", return_value=None)):
        result = worker._monitor_spawned_work_item(tmp_path, {"id": "x", "phase": "Q07"}, "T10",
                                                   {"pid": 999999, "log_path": str(log)}, {}, 5400)
    assert observed == [True]
    assert result["monitor_kill"]["tester_runtime_seconds"] == 5406.734
    assert result["worker_exit_record"]["effective_monitor_budget_seconds"] == 5400
    assert result["reason"] == mb.SUBCLASS
    check = health.chk_monitor_budget_exhausted(conn)
    assert check["value"] == 1 and check["budget_review_holds"] == 1
    conn.close()


def test_historical_inventory_is_read_only_and_legacy_budget_explicit(tmp_path):
    log = tmp_path / "T10.log"
    record = {"event": "next_cell_prestage", "stage_event": "current_child_exit", "terminal": "T10",
              "item_id": "old", "at_utc": "2026-09-04T13:04:11Z", "tester_runtime_seconds": 5406.734}
    log.write_text(json.dumps(record) + "\n")
    before = log.read_bytes()
    assert mb.inspect_logs([log])["count"] == 0
    result = mb.inspect_logs([log], 5400)
    assert result["count"] == 1 and result["rows"][0]["legacy_budget_assumed"]
    assert log.read_bytes() == before
