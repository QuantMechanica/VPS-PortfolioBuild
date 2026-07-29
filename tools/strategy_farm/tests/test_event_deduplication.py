import datetime as dt
import json
import sqlite3
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


_SCHEMA = """
CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ts TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    event TEXT NOT NULL,
    detail_json TEXT NOT NULL
);
CREATE TABLE event_dedupe_state (
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    event TEXT NOT NULL,
    detail_sha256 TEXT NOT NULL,
    last_emitted_ts TEXT,
    last_seen_ts TEXT NOT NULL,
    suppressed_count INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY(entity_type, entity_id, event)
);
"""


def _db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.executescript(_SCHEMA)
    return con


def _at(hour: int) -> dt.datetime:
    return dt.datetime(2026, 7, 29, hour, 0, tzinfo=dt.UTC)


def test_init_db_installs_additive_dedupe_sidecar(tmp_path):
    farmctl.init_db(tmp_path)
    with farmctl.connect(tmp_path) as con:
        columns = {
            row[1] for row in con.execute("PRAGMA table_info(event_dedupe_state)")
        }
    assert {
        "entity_type",
        "entity_id",
        "event",
        "detail_sha256",
        "last_emitted_ts",
        "last_seen_ts",
        "suppressed_count",
    } <= columns


def test_first_observation_appends_and_identical_repeat_is_suppressed():
    con = _db()
    detail = {"verdict": "DEAD", "sample_size": 5}

    first = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=_at(0)
    )
    repeat = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=_at(1)
    )

    assert first == {
        "appended": True,
        "reason": "first_observation",
        "suppressed_since_previous": 0,
    }
    assert repeat == {
        "appended": False,
        "reason": "identical_within_rolling_window",
        "suppressed_since_previous": 1,
    }
    assert con.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1
    assert con.execute(
        "SELECT suppressed_count FROM event_dedupe_state"
    ).fetchone()[0] == 1


def test_state_change_is_preserved_immediately_inside_window():
    con = _db()
    farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", {"sample_size": 5}, dedupe_hours=24, now=_at(0)
    )
    farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", {"sample_size": 5}, dedupe_hours=24, now=_at(1)
    )
    changed = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", {"sample_size": 6}, dedupe_hours=24, now=_at(2)
    )

    assert changed["appended"] is True
    assert changed["reason"] == "state_changed"
    rows = con.execute("SELECT id, detail_json FROM events ORDER BY id").fetchall()
    assert len(rows) == 2
    assert json.loads(rows[0]["detail_json"])["sample_size"] == 5
    newest = json.loads(rows[1]["detail_json"])
    assert newest["sample_size"] == 6
    assert newest["_event_dedupe"]["suppressed_identical_observations"] == 1


def test_unchanged_signal_recurs_after_window_and_raw_history_is_append_only():
    con = _db()
    detail = {"sample_size": 5}
    farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=_at(0)
    )
    before = tuple(con.execute("SELECT id, ts, detail_json FROM events").fetchone())
    farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=_at(1)
    )
    recurring = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=dt.datetime(2026, 7, 30, tzinfo=dt.UTC)
    )

    assert recurring["appended"] is True
    assert recurring["reason"] == "recurrence_due"
    rows = con.execute("SELECT id, ts, detail_json FROM events ORDER BY id").fetchall()
    assert len(rows) == 2
    assert tuple(rows[0]) == before
    recurrence_detail = json.loads(rows[1]["detail_json"])
    assert recurrence_detail["_event_dedupe"] == {
        "rolling_window_hours": 24,
        "suppressed_identical_observations": 1,
    }


def test_existing_raw_event_bootstraps_sidecar_without_new_duplicate():
    con = _db()
    detail = {"sample_size": 5}
    con.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES (?,?,?,?,?)",
        (_at(0).isoformat(), "ea", "QM5_1", "dead_zero", json.dumps(detail)),
    )

    result = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", detail, dedupe_hours=24, now=_at(1)
    )

    assert result["appended"] is False
    assert con.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1
    state = con.execute(
        "SELECT last_emitted_ts, suppressed_count FROM event_dedupe_state"
    ).fetchone()
    assert state["last_emitted_ts"] == _at(0).isoformat()
    assert state["suppressed_count"] == 1


def test_concurrent_identical_observers_append_exactly_once(tmp_path):
    db_path = tmp_path / "events.sqlite"
    setup = sqlite3.connect(db_path)
    setup.executescript(_SCHEMA)
    setup.execute("PRAGMA journal_mode=WAL")
    setup.close()
    barrier = threading.Barrier(2)

    def observe() -> dict:
        con = sqlite3.connect(db_path, timeout=10)
        con.row_factory = sqlite3.Row
        try:
            barrier.wait(timeout=5)
            result = farmctl.event_deduped(
                con,
                "ea",
                "QM5_1",
                "dead_zero",
                {"sample_size": 5},
                dedupe_hours=24,
                now=_at(0),
            )
            con.commit()
            return result
        finally:
            con.close()

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _n: observe(), range(2)))

    check = sqlite3.connect(db_path)
    try:
        assert check.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 1
        assert check.execute(
            "SELECT suppressed_count FROM event_dedupe_state"
        ).fetchone()[0] == 1
    finally:
        check.close()
    assert sorted(result["appended"] for result in results) == [False, True]


def test_malformed_historic_payload_fails_open_and_preserves_current_signal():
    con = _db()
    con.execute(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES (?,?,?,?,?)",
        (_at(0).isoformat(), "ea", "QM5_1", "dead_zero", "{broken"),
    )

    result = farmctl.event_deduped(
        con, "ea", "QM5_1", "dead_zero", {"sample_size": 5},
        dedupe_hours=24, now=_at(1),
    )

    assert result["appended"] is True
    assert result["reason"] == "state_changed"
    assert con.execute("SELECT COUNT(*) FROM events").fetchone()[0] == 2


def test_census_separates_rolling_24h_from_lifetime():
    con = _db()
    rows = [
        (_at(0).isoformat(), "ea", "QM5_1", "dead_zero", "{}"),
        (_at(1).isoformat(), "ea", "QM5_2", "dead_zero", "{}"),
        (dt.datetime(2026, 7, 30, 5, tzinfo=dt.UTC).isoformat(), "ea", "QM5_1", "dead_zero", "{}"),
    ]
    con.executemany(
        "INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES (?,?,?,?,?)",
        rows,
    )

    census = farmctl.event_census(
        con,
        "dead_zero",
        rolling_hours=24,
        now=dt.datetime(2026, 7, 30, 6, tzinfo=dt.UTC),
    )

    assert census["measurement_windows"]["lifetime"] == {"rows": 3, "entities": 2}
    assert census["measurement_windows"]["rolling"]["rows"] == 1
    assert census["measurement_windows"]["rolling"]["entities"] == 1


def test_zero_trade_terminal_detector_uses_deduped_event(tmp_path):
    con = _db()
    con.executescript(
        """
        CREATE TABLE work_items (
            ea_id TEXT, verdict TEXT, payload_json TEXT, evidence_path TEXT,
            updated_at TEXT, phase TEXT, status TEXT
        );
        CREATE TABLE tasks (
            id TEXT, card_id TEXT, kind TEXT, payload_json TEXT,
            created_at TEXT, status TEXT
        );
        """
    )
    payload = json.dumps({"verdict_reason": "MIN_TRADES_NOT_MET"})
    con.executemany(
        "INSERT INTO work_items VALUES (?,?,?,?,?,'Q02','failed')",
        [("QM5_1", "FAIL", payload, None, _at(0).isoformat())] * 5,
    )
    con.executemany(
        "INSERT INTO tasks VALUES (?,?, 'build_ea', ?, ?, 'done')",
        [
            (f"task-{n}", "QM5_1", json.dumps({"rework_reason": "ZERO_TRADE_RECURRENT"}), "2000-01-01T00:00:00+00:00")
            for n in range(3)
        ],
    )

    assert farmctl._detect_zerotrade_dead_eas(con, tmp_path) == []
    assert farmctl._detect_zerotrade_dead_eas(con, tmp_path) == []

    assert con.execute(
        "SELECT COUNT(*) FROM events WHERE event=?",
        (farmctl.DEAD_ZERO_TRADE_EVENT,),
    ).fetchone()[0] == 1
    assert con.execute(
        "SELECT suppressed_count FROM event_dedupe_state WHERE event=?",
        (farmctl.DEAD_ZERO_TRADE_EVENT,),
    ).fetchone()[0] == 1
