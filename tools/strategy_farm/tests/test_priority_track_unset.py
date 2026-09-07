"""Single-row priority_track unset (CEO 2026-09-07): reversible queue-order lever."""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import farmctl  # noqa: E402


def _seed(root: Path) -> str:
    farmctl.init_db(root)
    wid = "wi-prio-1"
    values = {"id": wid, "phase": "Q10_NEWS", "ea_id": "QM5_11196", "symbol": "XAUUSD.DWX", "status": "pending",
              "payload_json": json.dumps({"host_symbol": "XAUUSD.DWX"}), "created_at": farmctl.utc_now(),
              "updated_at": farmctl.utc_now(), "setfile_path": "x.set", "kind": "backtest"}
    with farmctl.connect(root) as conn:
        for col in conn.execute("PRAGMA table_info(work_items)").fetchall():
            name, ctype, notnull, default = col[1], str(col[2]).upper(), col[3], col[4]
            if name not in values and notnull and default is None:
                values[name] = 0 if ("INT" in ctype or "REAL" in ctype) else "x"
        cols = ", ".join(values)
        marks = ", ".join("?" for _ in values)
        conn.execute(f"INSERT INTO work_items ({cols}) VALUES ({marks})", tuple(values.values()))
        conn.commit()
    return wid


def _payload(root: Path, wid: str) -> dict:
    with farmctl.connect(root) as conn:
        return json.loads(conn.execute("SELECT payload_json FROM work_items WHERE id=?", (wid,)).fetchone()["payload_json"])


def test_set_then_unset_is_reversible(tmp_path, monkeypatch):
    monkeypatch.setattr(farmctl, "PRIORITY_TRACK_MARK_LOG", tmp_path / "marks.jsonl")
    root = tmp_path / "farm"
    wid = _seed(root)
    assert farmctl.mark_work_item_priority_track(root, wid, "set", value=False)["reason"] == "not_priority_track"
    assert farmctl.mark_work_item_priority_track(root, wid, "set")["applied"] is True
    assert _payload(root, wid)["priority_track"] is True
    res = farmctl.mark_work_item_priority_track(root, wid, "unset", value=False)
    assert res["applied"] is True and res["mark"]["value"] is False
    pay = _payload(root, wid)
    assert pay["priority_track"] is False and len(pay["priority_track_marks"]) == 2
    assert farmctl.mark_work_item_priority_track(root, wid, "again", value=False)["reason"] == "not_priority_track"


def test_unset_dry_run_writes_nothing(tmp_path, monkeypatch):
    monkeypatch.setattr(farmctl, "PRIORITY_TRACK_MARK_LOG", tmp_path / "marks.jsonl")
    root = tmp_path / "farm"
    wid = _seed(root)
    farmctl.mark_work_item_priority_track(root, wid, "set")
    res = farmctl.mark_work_item_priority_track(root, wid, "unset", value=False, dry_run=True)
    assert res["applied"] is False and res["reason"] == "dry_run"
    assert _payload(root, wid)["priority_track"] is True
