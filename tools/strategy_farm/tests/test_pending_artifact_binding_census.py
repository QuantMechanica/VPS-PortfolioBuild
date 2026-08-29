import hashlib
import json
import sqlite3
from pathlib import Path

from tools.strategy_farm import pending_artifact_binding_census as census


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _db(path: Path) -> None:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items(
          id TEXT,ea_id TEXT,symbol TEXT,phase TEXT,status TEXT,setfile_path TEXT,
          payload_json TEXT,created_at TEXT,updated_at TEXT,claimed_by TEXT);
        CREATE TABLE work_item_holds(
          work_item_id TEXT,hold_code TEXT,reason TEXT,active INTEGER,release_on_restart INTEGER);
        """
    )
    conn.commit()
    conn.close()


def _insert(db: Path, setfile: Path, payload: dict, *, hold: bool = False) -> None:
    conn = sqlite3.connect(db)
    conn.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("row-1", "QM5_1", "EURUSD.DWX", "Q02", "pending", str(setfile),
         json.dumps(payload), "2026-01-01", "2026-01-01", None),
    )
    if hold:
        conn.execute(
            "INSERT INTO work_item_holds VALUES(?,?,?,?,?)",
            ("row-1", "ARTIFACT_QUARANTINE", "test", 1, 0),
        )
    conn.commit()
    conn.close()


def test_full_census_classifies_missing_binary_and_reports_hold(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    setfile = sets / "demo.set"
    setfile.write_bytes(b"A=1\n")
    (ea / "QM5_1_demo.mq5").write_bytes(b"source\n")
    _db(db)
    _insert(db, setfile, {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": "a" * 64,
        "expected_mq5_sha256": _sha(b"source\n"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    }, hold=True)

    result = census.build_census(db, eas)

    assert result["drifted_rows"] == 1
    assert result["class_counts"] == {"MISSING": 1}
    assert result["rows"][0]["hold"]["hold_code"] == "ARTIFACT_QUARANTINE"
    assert result["rows"][0]["disposition"] == "WAIT_GOVERNED_ARTIFACT_RESTORE_OR_RECOMPILE"


def test_setfile_only_content_change_requires_append_only_successor(tmp_path: Path) -> None:
    db = tmp_path / "farm.sqlite"
    eas = tmp_path / "EAs"
    ea = eas / "QM5_1_demo"
    sets = ea / "sets"
    sets.mkdir(parents=True)
    ex5 = ea / "QM5_1_demo.ex5"; ex5.write_bytes(b"binary")
    mq5 = ea / "QM5_1_demo.mq5"; mq5.write_bytes(b"source\n")
    setfile = sets / "demo.set"; setfile.write_bytes(b"A=2\n")
    _db(db)
    _insert(db, setfile, {
        "ea_dir_name": "QM5_1_demo",
        "expected_ex5_sha256": _sha(b"binary"),
        "expected_mq5_sha256": _sha(b"source\n"),
        "expected_setfile_sha256": _sha(b"A=1\n"),
    })

    result = census.build_census(db, eas)

    assert result["mismatched_bindings"] == 1
    assert result["rows"][0]["findings"][0]["classification"] == "CONTENT_CHANGED"
    assert result["rows"][0]["disposition"] == "GOVERNED_APPEND_ONLY_SETFILE_SUCCESSOR_REQUIRED"
