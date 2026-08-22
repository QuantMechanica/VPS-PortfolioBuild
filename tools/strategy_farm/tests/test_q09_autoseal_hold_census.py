from __future__ import annotations

import datetime as dt
import json
import sqlite3

from tools.strategy_farm import health
from tools.strategy_farm import mission_control_v2_data as mc
from tools.strategy_farm import q09_autoseal_hold_census as census


NOW = dt.datetime(2026, 8, 22, 20, 0, 0, tzinfo=dt.timezone.utc)


def _connection() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            phase TEXT,
            ea_id TEXT,
            symbol TEXT,
            status TEXT,
            payload_json TEXT,
            created_at TEXT
        );
        CREATE TABLE work_item_holds (
            work_item_id TEXT,
            hold_code TEXT,
            active INTEGER,
            created_at TEXT
        );
        """
    )
    return con


def _insert(
    con: sqlite3.Connection,
    row_id: str,
    *,
    age_hours: float,
    reason: str,
    activation_state: str = "AWAITING_SEALED_PLAN",
) -> None:
    observed = NOW - dt.timedelta(hours=age_hours)
    payload = {
        "q09_activation_state": activation_state,
        "q09_autoseal_failure": {
            "reason_code": reason,
            "observed_at": observed.isoformat(),
        },
    }
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
        (
            row_id,
            "Q09_NEWS",
            "QM5_12989",
            "XAUUSD.DWX",
            "pending",
            json.dumps(payload),
            observed.isoformat(),
        ),
    )
    con.execute(
        "INSERT INTO work_item_holds VALUES (?,?,?,?)",
        (row_id, census.HOLD_CODE, 1, observed.isoformat()),
    )


def test_warns_when_one_hold_is_older_than_one_hour() -> None:
    con = _connection()
    _insert(con, "warn-row", age_hours=1.01, reason="ONLY_ONCE")

    result = census.collect(con, now=NOW)

    assert result["status"] == "WARN"
    assert result["aged_over_warn_count"] == 1
    assert result["aged_over_fail_count"] == 0
    assert result["groups"][0]["oldest_observed_at"] == "2026-08-22T18:59:24+00:00"


def test_fails_when_three_holds_are_older_than_six_hours() -> None:
    con = _connection()
    for index in range(3):
        _insert(con, f"old-{index}", age_hours=6.01, reason=f"DISTINCT_{index}")

    result = census.collect(con, now=NOW)

    assert result["status"] == "FAIL"
    assert result["aged_over_fail_count"] == 3
    assert any("aged_over_6h=3" in reason for reason in result["status_reasons"])


def test_fails_on_three_rows_with_same_reason_even_when_fresh() -> None:
    con = _connection()
    for index in range(3):
        _insert(con, f"repeat-{index}", age_hours=0.25, reason="Q09_AUTOSEAL_INCLUDE_CLOSURE_FAILED")

    result = census.collect(con, now=NOW)

    assert result["status"] == "FAIL"
    assert result["aged_over_warn_count"] == 0
    assert result["reason_groups"][0]["count"] == 3
    assert result["reason_groups"][0]["example_ids"] == [
        "repeat-0", "repeat-1", "repeat-2"
    ]


def test_grouping_is_shared_by_health_and_mission_control(monkeypatch) -> None:
    con = _connection()
    _insert(con, "a", age_hours=0.5, reason="BIND_FAILED")
    _insert(con, "b", age_hours=0.75, reason="BIND_FAILED")
    _insert(
        con,
        "c",
        age_hours=0.25,
        reason="INCLUDE_FAILED",
        activation_state="AWAITING_RETRY",
    )
    expected = census.collect(con, now=NOW)

    monkeypatch.setattr(health, "_utc_now", lambda: NOW)
    health_row = health.chk_q09_autoseal_hold_census(con)
    panel = mc.build_q09_autoseal_holds(con, now=NOW)

    assert health_row["name"] == "q09_autoseal_hold_census"
    assert health_row["status"] == expected["status"]
    assert health_row["value"] == 3
    assert panel["groups"] == expected["groups"]
    assert panel["reason_groups"] == expected["reason_groups"]
    assert panel["status"] == expected["status"]
    assert any(name == "q09_autoseal_hold_census" for name, _, _ in health.ALL_CHECKS)


def test_no_active_holds_is_ok() -> None:
    con = _connection()
    _insert(con, "inactive", age_hours=10, reason="OLD")
    con.execute("UPDATE work_item_holds SET active=0")

    result = census.collect(con, now=NOW)

    assert result["status"] == "OK"
    assert result["total"] == 0
    assert result["groups"] == []
