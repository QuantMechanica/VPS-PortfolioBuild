"""E1-C Option-B release marker: guard semantics tests (temporary DB/files only)."""
from __future__ import annotations

import json
import sqlite3

import pytest

from tools.strategy_farm import news_calendar_taint as taint

TAINTED = "a" * 64


def write_json(path, data):
    path.write_text(json.dumps(data), encoding="utf-8")
    return path


def make_record(tmp_path, *, wid="news", status="UNCHANGED_EQUIVALENT"):
    import hashlib
    record = {
        "schema": "qm.e1c-optionb-row-delta/v1",
        "work_item_id": wid,
        "delta_validation_status": status,
        "option_b_hold_release_eligible": status == "UNCHANGED_EQUIVALENT",
        "old_calendar": {"content_sha256": TAINTED},
    }
    canonical = (json.dumps(record, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n").encode()
    record["record_sha256"] = hashlib.sha256(canonical).hexdigest()
    path = tmp_path / f"{wid}.record.json"
    path.write_text(json.dumps(record, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    return path, record["record_sha256"]


@pytest.fixture
def env(tmp_path, monkeypatch):
    policy = {
        "schema": "qm.news-calendar-taint/v1",
        "enabled": True,
        "activation_evidence": "fixture-only CEO receipt",
        "tainted": [{"sha256": TAINTED, "evidence_path": "diagnostic.md",
                     "declared_at": "2026-09-05T15:12:29+00:00"}],
    }
    write_json(tmp_path / "policy.json", policy)
    monkeypatch.setattr(taint, "CONFIG", tmp_path / "policy.json")
    pin = write_json(tmp_path / "pin.json", {"content_sha256": TAINTED})
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.executescript(
        """
        CREATE TABLE work_items(id TEXT PRIMARY KEY,phase TEXT,status,
          ea_id TEXT,symbol TEXT,setfile_path TEXT,payload_json TEXT);
        CREATE TABLE work_item_holds(work_item_id TEXT PRIMARY KEY,
          hold_code TEXT,reason TEXT,active INTEGER,release_on_restart INTEGER,
          created_at TEXT,updated_at TEXT,released_at TEXT,release_note TEXT);
        CREATE TABLE events(id INTEGER PRIMARY KEY,ts TEXT,entity_type,
          entity_id TEXT,event TEXT,detail_json TEXT);
        """
    )
    yield conn, pin, tmp_path
    conn.close()


def insert(conn, item_id="news", phase="Q09_NEWS"):
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?)",
        (item_id, phase, "pending", "QM5_9999", "EURUSD.DWX", "x.set", "{}"),
    )
    conn.commit()


def sync(conn, pin, apply=True):
    conn.execute("BEGIN IMMEDIATE")
    rows = taint.synchronize(conn, taint.load_policy(taint.CONFIG), pin, apply=apply)
    conn.commit()
    return rows


def hold(conn, item_id="news"):
    return conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=?", (item_id,)
    ).fetchone()


def stamp_marker(conn, item_id, record_path, record_sha256):
    payload = {taint.E1C_MARKER_KEY: {
        "schema": taint.E1C_MARKER_SCHEMA,
        "decision_id": taint.E1C_DECISION_ID,
        "work_item_id": item_id,
        "record_path": str(record_path),
        "record_sha256": record_sha256,
        "tainted_sha256": TAINTED,
        "released_by": "fixture",
        "adjudicated_at": "2026-09-16T15:00:00+00:00",
    }}
    conn.execute("UPDATE work_items SET payload_json=? WHERE id=?",
                 (json.dumps(payload, sort_keys=True), item_id))
    conn.commit()


def test_release_e1c_item_releases_and_sweep_never_reapplies(env):
    conn, pin, tmp_path = env
    insert(conn)
    sync(conn, pin)
    assert hold(conn)["active"] == 1
    record_path, record_sha = make_record(tmp_path)
    conn.execute("BEGIN IMMEDIATE")
    marker = taint.release_e1c_item(
        conn, "news", pin, record_path=record_path, record_sha256=record_sha,
        released_by="fixture", adjudicated_at="2026-09-16T15:00:00+00:00",
    )
    conn.commit()
    assert marker["record_sha256"] == record_sha
    assert hold(conn)["active"] == 0
    assert "OWNER-E1C-OPTIONB-20260916" in hold(conn)["release_note"]
    # Guard + sweep keep the row released while the record stays intact.
    conn.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(conn, "news", pin) is None
    conn.commit()
    rows = sync(conn, pin)
    assert rows[0]["action"] == "NONE"
    assert hold(conn)["active"] == 0
    payload = json.loads(conn.execute(
        "SELECT payload_json FROM work_items WHERE id='news'").fetchone()[0])
    assert payload[taint.E1C_MARKER_KEY]["schema"] == taint.E1C_MARKER_SCHEMA
    assert conn.execute(
        "SELECT count(*) FROM events WHERE event='news_calendar_e1c_optionb_release'"
    ).fetchone()[0] == 1


def test_tampered_record_rearms_hold(env):
    conn, pin, tmp_path = env
    insert(conn)
    sync(conn, pin)
    record_path, record_sha = make_record(tmp_path)
    conn.execute("BEGIN IMMEDIATE")
    taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                           record_sha256=record_sha, released_by="fixture")
    conn.commit()
    assert hold(conn)["active"] == 0
    # Tamper with the record bytes after release.
    doc = json.loads(record_path.read_text(encoding="utf-8"))
    doc["delta_validation_status"] = "UNCHANGED_EQUIVALENT"  # same status, different bytes
    doc["tampered"] = True
    record_path.write_text(json.dumps(doc), encoding="utf-8")
    rows = sync(conn, pin)
    assert rows[0]["action"] == "HOLD"
    assert hold(conn)["active"] == 1


def test_wrong_status_record_never_releases(env):
    conn, pin, tmp_path = env
    insert(conn)
    sync(conn, pin)
    record_path, record_sha = make_record(tmp_path, status="DELTA_NOT_EXACT")
    conn.execute("BEGIN IMMEDIATE")
    with pytest.raises(ValueError, match="UNCHANGED_EQUIVALENT"):
        taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                               record_sha256=record_sha, released_by="fixture")
    conn.commit()
    assert hold(conn)["active"] == 1


def test_marker_for_other_row_or_other_pin_fails_closed(env):
    conn, pin, tmp_path = env
    insert(conn)
    sync(conn, pin)
    record_path, record_sha = make_record(tmp_path, wid="someone-else")
    conn.execute("BEGIN IMMEDIATE")
    with pytest.raises(ValueError):
        taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                               record_sha256=record_sha, released_by="fixture")
    conn.commit()
    # Hand-stamped marker with mismatched work_item_id is ignored by the guard.
    record_path2, record_sha2 = make_record(tmp_path, wid="news")
    stamp_marker(conn, "news", record_path, record_sha)  # wrong-id record
    conn.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(conn, "news", pin).startswith("PINNED_CALENDAR_TAINTED:")
    conn.commit()
    # And a correct marker is honored.
    stamp_marker(conn, "news", record_path2, record_sha2)
    conn.execute("BEGIN IMMEDIATE")
    assert taint.guard_claim(conn, "news", pin) is None
    conn.commit()


def test_release_requires_transaction_and_active_hold(env):
    conn, pin, tmp_path = env
    insert(conn)
    record_path, record_sha = make_record(tmp_path)
    with pytest.raises(ValueError, match="transaction required"):
        taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                               record_sha256=record_sha, released_by="fixture")
    conn.execute("BEGIN IMMEDIATE")
    with pytest.raises(ValueError, match="active NEWS_CALENDAR_TAINTED hold"):
        taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                               record_sha256=record_sha, released_by="fixture")
    conn.commit()


def test_double_release_race_fails(env):
    conn, pin, tmp_path = env
    insert(conn)
    sync(conn, pin)
    record_path, record_sha = make_record(tmp_path)
    conn.execute("BEGIN IMMEDIATE")
    taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                           record_sha256=record_sha, released_by="fixture")
    with pytest.raises(ValueError):  # marker already exists / hold already released
        taint.release_e1c_item(conn, "news", pin, record_path=record_path,
                               record_sha256=record_sha, released_by="fixture")
    conn.commit()
