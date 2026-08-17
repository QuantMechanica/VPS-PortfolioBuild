import datetime as dt
import sqlite3

from tools.strategy_farm import health


def _db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE work_items(
          id TEXT PRIMARY KEY, ea_id TEXT, symbol TEXT, phase TEXT,
          status TEXT, created_at TEXT, updated_at TEXT
        );
        CREATE TABLE work_item_holds(
          work_item_id TEXT, hold_code TEXT, active INTEGER, created_at TEXT
        );
        """
    )
    return con


def _stamp(hours_ago: float) -> str:
    return (
        dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours_ago)
    ).isoformat(timespec="seconds")


def test_old_q09_sealed_plan_hold_is_health_failure() -> None:
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        ("row-old", "QM5_100", "EURUSD.DWX", "Q09_NEWS", "pending", _stamp(8), _stamp(8)),
    )
    con.execute(
        "INSERT INTO work_item_holds VALUES(?,?,?,?)",
        ("row-old", "Q09_AWAITING_SEALED_PLAN", 1, _stamp(8)),
    )
    result = health.chk_q09_sealed_plan_hold_age(con)
    assert result["status"] == "FAIL"
    assert result["value"] == 1
    assert "row-old" in result["detail"]
    assert "completions_24h=0; pending=1" in result["detail"]


def test_fresh_or_inactive_hold_does_not_alarm() -> None:
    con = _db()
    for row_id, age, active in (("fresh", 2, 1), ("released", 20, 0)):
        con.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
            (row_id, "QM5_101", "USDJPY.DWX", "Q09_NEWS", "pending", _stamp(age), _stamp(age)),
        )
        con.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?)",
            (row_id, "Q09_AWAITING_SEALED_PLAN", active, _stamp(age)),
        )
    result = health.chk_q09_sealed_plan_hold_age(con)
    assert result["status"] == "OK"
    assert result["value"] == 0
    assert "active_plan_holds=1" in result["detail"]


def test_other_hold_codes_are_not_misclassified() -> None:
    con = _db()
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        ("other", "QM5_102", "XAUUSD.DWX", "Q09_NEWS", "pending", _stamp(24), _stamp(24)),
    )
    con.execute(
        "INSERT INTO work_item_holds VALUES(?,?,?,?)",
        ("other", "MANUAL_REVIEW", 1, _stamp(24)),
    )
    assert health.chk_q09_sealed_plan_hold_age(con)["status"] == "OK"
