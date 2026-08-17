from __future__ import annotations
import json
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import poison_pill_quarantine as ppq  # noqa: E402


def db() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("""CREATE TABLE work_items(
      id TEXT,ea_id TEXT,symbol TEXT,phase TEXT,status TEXT,verdict TEXT,
      evidence_path TEXT,payload_json TEXT,updated_at TEXT)""")
    ppq.ensure_schema(conn)
    return conn


def add(conn: sqlite3.Connection, n: int, reason: str, verdict: str = "INFRA_FAIL") -> None:
    conn.execute("INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?)", (
        str(n), "QM5_1", "EURUSD.DWX", "Q02", "pending" if n >= 5 else "failed",
        verdict, f"evidence/{n}.json", json.dumps({"verdict_reason": reason}),
        f"2026-07-26T00:00:{n:02d}+00:00"))


def test_identical_five_quarantine() -> None:
    conn = db()
    for n in range(1, 6):
        add(conn, n, "ONINIT_FAILED")
    assert len(ppq.refresh_pending(conn)) == 1
    row = conn.execute("SELECT * FROM poison_pill_quarantine").fetchone()
    assert (row["active"], row["consecutive_failures"]) == (1, 5)


def test_changing_reason_does_not_quarantine() -> None:
    conn = db()
    for n, reason in enumerate(("A", "A", "A", "B", "B"), 1):
        add(conn, n, reason)
    assert ppq.refresh_pending(conn) == []


def test_merit_fail_counts_as_success() -> None:
    conn = db()
    add(conn, 0, "merit", "FAIL")
    for n in range(1, 6):
        add(conn, n, "ONINIT_FAILED")
    assert ppq.refresh_pending(conn) == []


def test_release_needs_five_new_failures() -> None:
    conn = db()
    for n in range(1, 6):
        add(conn, n, "ONINIT_FAILED")
    ppq.refresh_pending(conn)
    conn.execute("UPDATE poison_pill_quarantine SET active=0,released_at=?",
                 ("2026-07-26T00:00:05+00:00",))
    for n in range(6, 10):
        add(conn, n, "ONINIT_FAILED")
    assert ppq.refresh_pending(conn) == []
    add(conn, 10, "ONINIT_FAILED")
    assert len(ppq.refresh_pending(conn)) == 1


def test_single_observation_expires_after_new_start() -> None:
    conn = db()
    for n in range(1, 6):
        add(conn, n, "TIMEOUT;INCOMPLETE_RUNS")
    marker = {"protected_at": "2026-07-26T01:00:00+00:00", "note": "new budget"}
    conn.execute(
        "UPDATE work_items SET payload_json=? WHERE id='5'",
        (json.dumps({
            ppq.SINGLE_OBSERVATION_KEY: marker,
            "priority_track": True,
            "verdict_reason": "TIMEOUT;INCOMPLETE_RUNS",
        }),),
    )
    assert ppq.refresh_pending(conn) == []
    conn.execute(
        "UPDATE work_items SET payload_json=? WHERE id='5'",
        (json.dumps({
            ppq.SINGLE_OBSERVATION_KEY: marker,
            "started_at_iso": "2026-07-26T01:00:01+00:00",
            "priority_track": True,
            "verdict_reason": "TIMEOUT;INCOMPLETE_RUNS",
        }),),
    )
    assert len(ppq.refresh_pending(conn)) == 1


def test_summary_missing_is_sealed_invalid_not_merit() -> None:
    conn = db()
    for n in range(1, 6):
        add(conn, n, ppq.SUMMARY_MISSING_EXHAUSTED)
    found = ppq.refresh_pending(conn)
    assert found[0]["sealed_pending_rows"] == 1
    row = conn.execute("SELECT status,verdict,payload_json FROM work_items WHERE id='5'").fetchone()
    assert (row["status"], row["verdict"]) == ("failed", "INVALID")
    payload = json.loads(row["payload_json"])
    assert payload["poison_pill_disposition"]["verdict"] == "INVALID"
