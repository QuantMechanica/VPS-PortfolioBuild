import json
import sqlite3
from pathlib import Path
from tools.strategy_farm import config_sweep as sweep


def _declaration(tmp_path, monkeypatch):
    card = tmp_path / "card.md"; card.write_text("approved\n")
    base = tmp_path / "base.set"; base.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\nqm_news_stale_max_hours=336\nstrategy_clock_mode=0\n")
    mq5 = tmp_path / "ea.mq5"; mq5.write_text("source")
    ex5 = tmp_path / "ea.ex5"; ex5.write_bytes(b"binary")
    monkeypatch.setattr(sweep, "_approved_card_commit", lambda *_: None)
    value = {"schema": sweep.SCHEMA, "engine": sweep.ENGINE, "program_id": "WINSWEEP_TEST", "ea_id": "QM5_41405", "ea_label": "test", "symbol": "USDJPY.DWX", "timeframe": "H1", "years": list(range(2019, 2026)), "arms": [{"arm": "control", "overrides": {"strategy_clock_mode": 0}}], "base_setfile_path": str(base), "base_setfile_sha256": sweep._hash(base), "artifact_identity": {"mq5_path": str(mq5), "mq5_sha256": sweep._hash(mq5), "ex5_path": str(ex5), "ex5_sha256": sweep._hash(ex5)}, "approved_card_path": str(card), "approved_card_commit": "0" * 40, "declared_trial_count": 7}
    value["declaration_sha256"] = sweep._seal(value); return value


def test_plan_has_seven_deterministic_controls(tmp_path, monkeypatch):
    declaration = _declaration(tmp_path, monkeypatch); path = tmp_path / "decl.json"; sweep._write(path, declaration)
    first = sweep.plan(path, tmp_path / "artifact", controls_only=True)
    second = sweep.plan(path, tmp_path / "artifact", controls_only=True)
    assert len(first["cells"]) == 7
    assert [cell["work_item_id"] for cell in first["cells"]] == [cell["work_item_id"] for cell in second["cells"]]


def test_tampered_declaration_and_unlisted_override_refuse(tmp_path, monkeypatch):
    declaration = _declaration(tmp_path, monkeypatch); declaration["arms"][0]["overrides"] = {"unlisted": 1}
    unsigned = dict(declaration); unsigned.pop("declaration_sha256")
    declaration["declaration_sha256"] = sweep._seal(unsigned)
    try: sweep.validate_declaration(declaration)
    except sweep.ConfigSweepError as exc: assert "override" in str(exc)
    else: assert False


def test_dry_run_does_not_write(tmp_path, monkeypatch):
    declaration = _declaration(tmp_path, monkeypatch); path = tmp_path / "decl.json"; sweep._write(path, declaration)
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE work_items(id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,status TEXT,attempt_count INT,payload_json TEXT,created_at TEXT,updated_at TEXT)")
        conn.execute("INSERT INTO work_items VALUES ('reference','x','OPT_CENSUS','QM5_41405','USDJPY.DWX','x','pending',0,?, 'x','x')", (json.dumps({"opt_census_frontier_priority": True}),))
    result = sweep.enqueue(sweep.plan(path, tmp_path / "artifact", controls_only=True), db=db)
    assert result["new_rows"] == 7 and not (tmp_path / "artifact").exists()
