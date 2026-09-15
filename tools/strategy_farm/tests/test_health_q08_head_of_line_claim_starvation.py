import datetime as dt
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import health  # noqa: E402


def _db():
    con = sqlite3.connect(":memory:")
    con.execute(
        "CREATE TABLE work_items "
        "(id TEXT, ea_id TEXT, symbol TEXT, phase TEXT, status TEXT)"
    )
    con.execute(
        "CREATE TABLE work_item_holds (work_item_id TEXT, active INTEGER)"
    )
    con.execute("CREATE TABLE work_item_supersedes (work_item_id TEXT)")
    con.execute(
        "CREATE TABLE poison_pill_quarantine "
        "(ea_id TEXT, symbol TEXT, phase TEXT, active INTEGER)"
    )
    return con


NOW = dt.datetime(2026, 9, 15, 9, 40, tzinfo=dt.timezone.utc)


def _write_log(path: Path, entries: list[dict]) -> None:
    path.write_text(
        "\n".join(json.dumps(e) for e in entries) + "\n", encoding="utf-8"
    )


def _idle_entry(at_utc: str) -> dict:
    return {
        "stage_event": "claim_result", "claimed": False,
        "reason": "no_pending_claimable", "at_utc": at_utc,
    }


def _claimed_entry(at_utc: str) -> dict:
    return {"stage_event": "claim_result", "claimed": True, "at_utc": at_utc}


def test_ok_when_no_claimable_backlog(tmp_path, monkeypatch):
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES ('w1','QM5_1','EURUSD.DWX','Q02','done')"
    )
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    result = health.chk_q08_head_of_line_claim_starvation(con)
    assert result["status"] == "OK"
    assert result["value"] == 0


def test_fail_when_eight_terminals_idle_ten_minutes_with_claimable_backlog(
    tmp_path, monkeypatch
):
    con = _db()
    for i in range(20):
        con.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?)",
            (f"w{i}", f"QM5_{i}", "EURUSD.DWX", "Q02", "pending"),
        )
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    recent = (NOW - dt.timedelta(minutes=2)).isoformat()
    for i in range(1, 9):
        _write_log(
            tmp_path / f"terminal_worker_T{i}.log",
            [_idle_entry(recent), _idle_entry(recent)],
        )
    result = health.chk_q08_head_of_line_claim_starvation(con)
    assert result["status"] == "FAIL"
    assert result["value"] == 8


def test_ok_when_a_claim_succeeded_recently_on_enough_terminals(
    tmp_path, monkeypatch
):
    """The same 8 idle-looking terminals as the FAIL case, but one worker
    actually claimed something in the window -- not a starvation deadlock,
    just an ordinary quiet queue."""
    con = _db()
    for i in range(20):
        con.execute(
            "INSERT INTO work_items VALUES (?,?,?,?,?)",
            (f"w{i}", f"QM5_{i}", "EURUSD.DWX", "Q02", "pending"),
        )
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    recent = (NOW - dt.timedelta(minutes=2)).isoformat()
    for i in range(1, 8):
        _write_log(tmp_path / f"terminal_worker_T{i}.log", [_idle_entry(recent)])
    _write_log(
        tmp_path / "terminal_worker_T8.log",
        [_idle_entry(recent), _claimed_entry(recent)],
    )
    result = health.chk_q08_head_of_line_claim_starvation(con)
    assert result["status"] == "OK"
    assert result["value"] == 7


def test_stale_claim_results_outside_the_ten_minute_window_do_not_count(
    tmp_path, monkeypatch
):
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES ('w1','QM5_1','EURUSD.DWX','Q02','pending')"
    )
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    stale = (NOW - dt.timedelta(minutes=45)).isoformat()
    for i in range(1, 9):
        _write_log(tmp_path / f"terminal_worker_T{i}.log", [_idle_entry(stale)])
    result = health.chk_q08_head_of_line_claim_starvation(con)
    # No terminal has a claim_result inside the window at all -- this check
    # only alerts on freshly-idle terminals, not on an absence of logging.
    assert result["status"] == "OK"
    assert result["value"] == 0


def test_active_hold_removes_a_row_from_the_claimable_backlog(tmp_path, monkeypatch):
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES ('w1','QM5_1','EURUSD.DWX','Q08','pending')"
    )
    con.execute("INSERT INTO work_item_holds VALUES ('w1', 1)")
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    result = health.chk_q08_head_of_line_claim_starvation(con)
    assert result["status"] == "OK"
    assert result["value"] == 0


def test_fewer_than_eight_idle_terminals_is_ok(tmp_path, monkeypatch):
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES ('w1','QM5_1','EURUSD.DWX','Q02','pending')"
    )
    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    monkeypatch.setattr(health, "LOG_DIR", tmp_path)
    recent = (NOW - dt.timedelta(minutes=2)).isoformat()
    for i in range(1, 8):  # only 7 idle terminals
        _write_log(tmp_path / f"terminal_worker_T{i}.log", [_idle_entry(recent)])
    result = health.chk_q08_head_of_line_claim_starvation(con)
    assert result["status"] == "OK"
    assert result["value"] == 7
