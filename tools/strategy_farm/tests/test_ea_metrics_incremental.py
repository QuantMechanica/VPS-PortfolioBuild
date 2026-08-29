import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import ea_metrics


def _connection() -> sqlite3.Connection:
    conn = sqlite3.connect(":memory:")
    conn.execute(
        """CREATE TABLE work_items(
        id TEXT PRIMARY KEY,ea_id TEXT,phase TEXT,symbol TEXT,verdict TEXT,
        status TEXT,evidence_path TEXT,payload_json TEXT)"""
    )
    return conn


def test_missing_evidence_is_a_stable_incremental_watermark(
    tmp_path: Path, monkeypatch,
) -> None:
    conn = _connection()
    missing = tmp_path / "purged-summary.json"
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
        ("wi-1", "QM5_1", "Q02", "EURUSD.DWX", "PASS", "done",
         str(missing), json.dumps({})),
    )
    calls = []

    def fake_extract(phase, path):
        calls.append((phase, path))
        return ({}, {}, "missing")

    monkeypatch.setattr(ea_metrics, "extract_one", fake_extract)

    first = ea_metrics.build(conn)
    second = ea_metrics.build(conn)

    assert first["upserts"] == 1
    assert second == {"scanned": 1, "upserts": 0, "skipped": 1, "by_source": {}}
    assert calls == [("Q02", str(missing))]


def test_status_change_invalidates_incremental_watermark(
    tmp_path: Path, monkeypatch,
) -> None:
    conn = _connection()
    evidence = tmp_path / "summary.json"
    evidence.write_text("{}", encoding="utf-8")
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
        ("wi-1", "QM5_1", "Q02", "EURUSD.DWX", None, "active",
         str(evidence), json.dumps({})),
    )
    monkeypatch.setattr(ea_metrics, "extract_one", lambda *_: ({}, {}, "summary"))

    assert ea_metrics.build(conn, batch_size=1)["upserts"] == 1
    conn.execute("UPDATE work_items SET status='done',verdict='PASS' WHERE id='wi-1'")
    conn.commit()
    assert ea_metrics.build(conn, batch_size=1)["upserts"] == 1
    row = conn.execute(
        "SELECT status,verdict FROM ea_metrics WHERE work_item_id='wi-1'"
    ).fetchone()
    assert tuple(row) == ("done", "PASS")
