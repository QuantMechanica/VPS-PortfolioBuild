import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import health


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _db() -> sqlite3.Connection:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute(
        """CREATE TABLE work_items(
        id TEXT,ea_id TEXT,symbol TEXT,phase TEXT,status TEXT,setfile_path TEXT,
        payload_json TEXT,created_at TEXT)"""
    )
    con.execute(
        "CREATE TABLE work_item_holds(work_item_id TEXT,active INTEGER)"
    )
    return con


def _insert(con: sqlite3.Connection, row_id: str, setfile: Path, payload: dict) -> None:
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?)",
        (row_id, "QM5_1", "EURUSD.DWX", "Q02", "pending", str(setfile),
         json.dumps(payload), "2026-01-01T00:00:00+00:00"),
    )


def test_detector_distinguishes_newlines_from_content(tmp_path: Path, monkeypatch) -> None:
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    monkeypatch.setattr(health, "FRAMEWORK_EAS_DIR", eas)
    (ea / "QM5_1_demo.ex5").write_bytes(b"binary")
    (ea / "QM5_1_demo.mq5").write_bytes(b"one\r\ntwo\r\n")
    setfile = sets / "demo.set"
    setfile.write_bytes(b"A=changed\r\n")
    payload = {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"one\ntwo\n"),
        "expected_setfile_sha256": _sha(b"A=old\n"),
    }
    con = _db()
    _insert(con, "drift-row", setfile, payload)
    result = health.chk_pending_artifact_binding_drift(con)
    assert result["status"] == "FAIL"
    assert "mq5:LINE_ENDINGS_ONLY" in result["detail"]
    assert "setfile:CONTENT_CHANGED" in result["detail"]
    assert "UNHELD" in result["detail"]


def test_detector_is_green_when_raw_bindings_match(tmp_path: Path, monkeypatch) -> None:
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    monkeypatch.setattr(health, "FRAMEWORK_EAS_DIR", eas)
    ex5 = ea / "QM5_1_demo.ex5"; ex5.write_bytes(b"binary")
    mq5 = ea / "QM5_1_demo.mq5"; mq5.write_bytes(b"source\n")
    setfile = sets / "demo.set"; setfile.write_bytes(b"A=1\n")
    con = _db()
    _insert(con, "clean-row", setfile, {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": _sha(ex5.read_bytes()),
        "expected_mq5_sha256": _sha(mq5.read_bytes()),
        "expected_setfile_sha256": _sha(setfile.read_bytes()),
    })
    result = health.chk_pending_artifact_binding_drift(con)
    assert result["status"] == "OK"
    assert result["value"] == 0
