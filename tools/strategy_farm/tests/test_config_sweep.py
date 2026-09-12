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


def _prescreen_declaration(tmp_path, monkeypatch):
    value = _declaration(tmp_path, monkeypatch)
    value["arms"] = [
        {"arm": f"c{i:02d}", "overrides": {"strategy_clock_mode": i}}
        for i in range(4)
    ]
    value["declared_trial_count"] = 28
    value.update({
        "prescreen_model": 1,
        "prescreen_evidence_class": "PRESCREEN",
        "prescreen_keep_fraction": 0.5,
        "prescreen_control_fraction": 0.5,
        "prescreen_control_seed": "fixture-seed",
    })
    value.pop("declaration_sha256")
    value["declaration_sha256"] = sweep._seal(value)
    return value


def _summary(path, *, evidence_class, model, score):
    value = {
        "evidence_class": evidence_class,
        "model": model,
        "runs": [{"net_profit": score * 100.0, "drawdown": 100.0}],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def test_prescreen_promote_is_idempotent_and_fn_report_suspends(tmp_path, monkeypatch):
    declaration = _prescreen_declaration(tmp_path, monkeypatch)
    declaration_path = tmp_path / "prescreen_declaration.json"
    sweep._write(declaration_path, declaration)
    artifact = tmp_path / "artifact"
    plan = sweep.plan(declaration_path, artifact)
    assert len(plan["cells"]) == 28
    assert all(cell["evidence_class"] == "PRESCREEN" for cell in plan["cells"])
    assert all(cell["work_item_id"] != cell["real_work_item_id"] for cell in plan["cells"])

    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("""CREATE TABLE work_items(
            id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,
            setfile_path TEXT,status TEXT,verdict TEXT,attempt_count INT,
            payload_json TEXT,evidence_path TEXT,created_at TEXT,updated_at TEXT)""")
        conn.execute("INSERT INTO work_items VALUES ('reference','x','OPT_CENSUS','QM5_41405','USDJPY.DWX','x','pending',NULL,0,?,NULL,'x','x')", (json.dumps({"opt_census_frontier_priority": True}),))
    monkeypatch.setenv(sweep.PRESCREEN_ENABLE_ENV, "1")
    assert sweep.enqueue(plan, db=db, apply=True)["inserted"] == 28

    with sqlite3.connect(db) as conn:
        phase, payload_raw = conn.execute(
            "SELECT phase,payload_json FROM work_items WHERE id=?", (plan["cells"][0]["work_item_id"],)
        ).fetchone()
    claimed_payload = json.loads(payload_raw)
    assert phase == "OPT_CENSUS"
    assert claimed_payload["priority_track"] is True
    assert claimed_payload["sweep_engine"] == "config_sweep"
    assert claimed_payload["evidence_class"] == "PRESCREEN"

    with sqlite3.connect(db) as conn:
        for cell in plan["cells"]:
            score = 10.0 - float(cell["config"])
            evidence = _summary(tmp_path / "prescreen" / f"{cell['work_item_id']}.json",
                                evidence_class="PRESCREEN", model=1, score=score)
            conn.execute("UPDATE work_items SET status='done',verdict='PRESCREEN_MEASURED',evidence_path=? WHERE id=?",
                         (str(evidence), cell["work_item_id"]))
        conn.commit()

    dry = sweep.promote(plan, db=db, keep=0.5, control=0.5)
    assert dry["keep_arms"] == 2 and dry["control_arms"] == 1 and dry["real_cells"] == 21
    first = sweep.promote(plan, db=db, keep=0.5, control=0.5, apply=True)
    second = sweep.promote(plan, db=db, keep=0.5, control=0.5, apply=True)
    assert first["inserted"] == 21
    assert second["inserted"] == 0 and second["existing"] == 21

    amendment = sweep._read(Path(first["promotion_amendment_path"]))
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        for cell in amendment["real_cells"]:
            row = conn.execute("SELECT * FROM work_items WHERE id=?", (cell["work_item_id"],)).fetchone()
            payload = json.loads(row["payload_json"])
            assert payload["evidence_class"] == "REAL_TICKS"
            assert "prescreen_model" not in payload
            sweep.authenticate_ledger(payload)
            score = 100.0 if payload["promotion_role"] == "CONTROL" else 1.0
            evidence = _summary(tmp_path / "real" / f"{cell['work_item_id']}.json",
                                evidence_class="REAL_TICKS", model=4, score=score)
            conn.execute("UPDATE work_items SET status='done',verdict='MEASURED',evidence_path=? WHERE id=?",
                         (str(evidence), cell["work_item_id"]))
        conn.commit()
    result = sweep.prescreen_report(
        plan, promotion_amendment=Path(first["promotion_amendment_path"]),
        db=db, output=tmp_path / "fn_report.csv",
    )
    assert result["completed_control_arms"] == 1
    assert result["false_negative_rate"] == 1.0
    assert result["prescreen_suspended"] is True


def test_prescreen_apply_is_default_off(tmp_path, monkeypatch):
    declaration = _prescreen_declaration(tmp_path, monkeypatch)
    path = tmp_path / "decl.json"; sweep._write(path, declaration)
    db = tmp_path / "farm.sqlite"
    with sqlite3.connect(db) as conn:
        conn.execute("CREATE TABLE work_items(id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,setfile_path TEXT,status TEXT,attempt_count INT,payload_json TEXT,created_at TEXT,updated_at TEXT)")
        conn.execute("INSERT INTO work_items VALUES ('reference','x','OPT_CENSUS','QM5_41405','USDJPY.DWX','x','pending',0,?, 'x','x')", (json.dumps({"opt_census_frontier_priority": True}),))
    monkeypatch.delenv(sweep.PRESCREEN_ENABLE_ENV, raising=False)
    try:
        sweep.enqueue(sweep.plan(path, tmp_path / "artifact"), db=db, apply=True)
    except sweep.ConfigSweepError as exc:
        assert "default-off" in str(exc)
    else:
        assert False
