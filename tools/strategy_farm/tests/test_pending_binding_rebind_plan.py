"""pending_binding_rebind_plan is a dry-run planner and must never mutate.

Covers the three classifications the governed apply path keys off:
  * DRIFT   -> current on-disk SHA differs from the pinned SHA on a pending row
              => rebind-eligible with a proposed successor command.
  * MISSING -> the bound artifact is gone => blocked (lost-file, not stale bind).
  * OK      -> already current => not eligible.
And that ``--apply`` is refused (no mutation authority).
"""

import hashlib
import json
import sqlite3
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import pending_binding_rebind_plan as pbr  # noqa: E402


def _sha(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def _mk_ea(repo_root: Path, ea_dir: str, ex5: bytes, mq5: bytes):
    d = repo_root / "framework" / "EAs" / ea_dir
    d.mkdir(parents=True, exist_ok=True)
    (d / f"{ea_dir}.ex5").write_bytes(ex5)
    (d / f"{ea_dir}.mq5").write_bytes(mq5)
    sets = d / "sets"
    sets.mkdir(exist_ok=True)
    setfile = sets / f"{ea_dir}_EURUSD.DWX_H1_backtest.set"
    setfile.write_bytes(b"key=1\n")
    return setfile


def _db(tmp: Path) -> Path:
    p = tmp / "farm.sqlite"
    con = sqlite3.connect(p)
    con.execute(
        "CREATE TABLE work_items (id TEXT, ea_id TEXT, symbol TEXT, phase TEXT,"
        " status TEXT, verdict TEXT, setfile_path TEXT, payload_json TEXT)"
    )
    con.commit()
    con.close()
    return p


def _insert(db: Path, wi_id, ea, setfile, payload):
    con = sqlite3.connect(db)
    con.execute(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?)",
        (wi_id, ea, "EURUSD.DWX", "Q02", "pending", None, str(setfile),
         json.dumps(payload)),
    )
    con.commit()
    con.close()


def test_drift_is_rebind_eligible(tmp_path):
    ea_dir = "QM5_10203_x"
    ex5, mq5 = b"NEW-EX5-BYTES", b"NEW-MQ5-BYTES"
    setfile = _mk_ea(tmp_path, ea_dir, ex5, mq5)
    db = _db(tmp_path)
    payload = {
        "ea_dir_name": ea_dir,
        "expected_ex5_sha256": _sha(b"OLD-EX5"),   # stale -> DRIFT
        "expected_mq5_sha256": _sha(mq5),          # current -> OK
        "expected_setfile_sha256": _sha(b"key=1\n"),
    }
    _insert(db, "wi-1", "QM5_10203", setfile, payload)

    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM work_items WHERE id='wi-1'").fetchone()
    meta = {"id": "wi-1", "ea": "QM5_10203", "phase": "Q02",
            "cause_cluster": pbr.C2A_CLUSTER}
    out = pbr.build_plan_row(meta, row, tmp_path, with_git=False)

    assert out["bindings"]["ex5"]["classification"] == "DRIFT"
    assert out["bindings"]["ex5"]["current_sha256"] == _sha(ex5)
    assert out["bindings"]["mq5"]["classification"] == "OK"
    assert out["rebind_eligible"] is True
    assert out["proposed_successor_commands"]


def test_missing_artifact_blocks(tmp_path):
    db = _db(tmp_path)
    setfile = tmp_path / "framework" / "EAs" / "QM5_9_x" / "sets" / "s.set"
    payload = {"ea_dir_name": "QM5_9_x",
               "expected_ex5_sha256": _sha(b"whatever")}  # file does not exist
    _insert(db, "wi-2", "QM5_9", setfile, payload)
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM work_items WHERE id='wi-2'").fetchone()
    out = pbr.build_plan_row({"id": "wi-2"}, row, tmp_path, with_git=False)
    assert out["bindings"]["ex5"]["classification"] == "MISSING"
    assert out["rebind_eligible"] is False
    assert out["blocked_reason"] == "artifact_missing_on_disk"


def test_already_current_not_eligible(tmp_path):
    ea_dir = "QM5_7_x"
    ex5, mq5 = b"EX5", b"MQ5"
    setfile = _mk_ea(tmp_path, ea_dir, ex5, mq5)
    db = _db(tmp_path)
    payload = {"ea_dir_name": ea_dir, "expected_ex5_sha256": _sha(ex5)}
    _insert(db, "wi-3", "QM5_7", setfile, payload)
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    row = con.execute("SELECT * FROM work_items WHERE id='wi-3'").fetchone()
    out = pbr.build_plan_row({"id": "wi-3"}, row, tmp_path, with_git=False)
    assert out["bindings"]["ex5"]["classification"] == "OK"
    assert out["rebind_eligible"] is False
    assert out["blocked_reason"] == "no_drift_already_current"


def test_apply_is_refused():
    rc = pbr.main(["--plan", "x", "--db", "y", "--apply"])
    assert rc == 2


def test_build_plan_is_read_only(tmp_path):
    """The planner opens the DB immutable; a plan run must not change its mtime."""
    ea_dir = "QM5_5_x"
    setfile = _mk_ea(tmp_path, ea_dir, b"E", b"M")
    db = _db(tmp_path)
    payload = {"ea_dir_name": ea_dir, "expected_ex5_sha256": _sha(b"OLD")}
    _insert(db, "wi-9", "QM5_5", setfile, payload)
    plan = {"rows": [{"id": "wi-9", "ea": "QM5_5",
                      "cause_cluster": pbr.C2A_CLUSTER}]}
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(json.dumps(plan), encoding="utf-8")
    before = db.stat().st_mtime_ns
    out = pbr.build_plan(plan_path, db, tmp_path, with_git=False)
    assert db.stat().st_mtime_ns == before
    assert out["c2a_rows_total"] == 1
    assert out["plan_sha256"]
