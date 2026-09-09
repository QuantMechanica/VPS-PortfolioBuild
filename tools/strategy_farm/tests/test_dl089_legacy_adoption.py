from __future__ import annotations

import hashlib
import json
import sqlite3

import pytest

from tools.strategy_farm import dl089_legacy_adoption as adoption
from tools.strategy_farm.recover_legacy_opt_census import _canonical_bytes, _done_row_digest


def _fixture(tmp_path, monkeypatch):
    base = tmp_path / adoption.PROGRAM_ID
    base.mkdir()

    def bind(name, content="fixture"):
        path = base / name
        path.write_text(content, encoding="utf-8")
        return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute("CREATE TABLE work_item_holds(work_item_id TEXT,hold_code TEXT,active INTEGER,released_at TEXT,release_note TEXT)")
    conn.execute("INSERT INTO work_item_holds VALUES(?,?,0,'2026-09-01','review approved')", (adoption.Q12_ID, adoption.REVIEW_HOLD))
    fields = "id status verdict claimed_by parent_task_id evidence_path payload_json gate_contract_version ex5_sha256 setfile_sha256 mq5_sha256 data_window_start data_window_end updated_at ea_id symbol phase".split()
    conn.execute("CREATE TABLE work_items(" + ",".join(f"{key} TEXT" for key in fields) + ")")
    records = []
    evidence = bind("adopted-evidence.json")
    for i in range(486):
        wid = f"adopted-{i}"
        row = {key: None for key in fields}
        row.update(id=wid, status="done", verdict="MEASURED", payload_json="{}", evidence_path=evidence["path"])
        conn.execute("INSERT INTO work_items VALUES(" + ",".join("?" * len(fields)) + ")", [row[key] for key in fields])
        records.append({"work_item_id": wid, "evidence_path": evidence["path"], "evidence_sha256": evidence["sha256"]})
    rows = conn.execute("SELECT * FROM work_items").fetchall()
    adopted = bind("legacy_done_adoption.json", json.dumps({"rows": records, "q12_work_item_id": adoption.Q12_ID, "done_rows_digest": _done_row_digest(rows)}))
    bindings = {role: bind(name) for role, name in (("source", "QM5_41097_test.mq5"), ("binary", "QM5_41097_test.ex5"), ("card", "card.md"), ("setfile", "base.set"))}
    q02_evidence = bind("q02.json")
    conn.execute("INSERT INTO work_items(id,ea_id,symbol,phase,status,verdict,ex5_sha256,mq5_sha256,evidence_path) VALUES('q02','QM5_41097','USDJPY.DWX','Q02','done','PASS',?,?,?)", (bindings["binary"]["sha256"], bindings["source"]["sha256"], q02_evidence["path"]))
    declaration = {"program_id": adoption.PROGRAM_ID, "annual_cells_sha256": "annual", "wf_cells_sha256": "wf"}
    declaration["declaration_sha256"] = hashlib.sha256(_canonical_bytes(declaration)).hexdigest()
    bind("q12_declaration.json", json.dumps(declaration))
    reg = {
        "q12_work_item_id": adoption.Q12_ID, "program_id": adoption.PROGRAM_ID,
        "subject_ea_id": "QM5_13213", "measurement_ea_id": "QM5_41097",
        **{key: declaration[key] for key in ("declaration_sha256", "annual_cells_sha256", "wf_cells_sha256")},
        "legacy_source_ledger": bind("legacy.json"), "measurement_bindings": bindings,
        "legacy_q02_work_item_id": "q02", "legacy_q02_evidence": q02_evidence,
        "done_adoption_path": adopted["path"], "done_adoption_sha256": adopted["sha256"],
    }
    registration = bind("runner_registration.json", json.dumps(reg))
    monkeypatch.setattr(adoption, "REGISTRATION_SHA", registration["sha256"])
    q12 = {"id": adoption.Q12_ID, "ea_id": "QM5_13213", "symbol": "USDJPY.DWX", "payload_json": json.dumps({"legacy_census_recovery": {"schema": "qm.dl089-legacy-census-recovery/v1"}, "pattern_filter_sweep": declaration})}
    return conn, q12, base


def test_reviewed_exact_legacy_program_authenticates_without_writes(tmp_path, monkeypatch):
    conn, q12, base = _fixture(tmp_path, monkeypatch)
    before = conn.total_changes
    result = adoption.authenticate(conn, q12, tmp_path)
    assert result["ea_id"] == "QM5_41097"
    assert len(result["legacy_adopted_ids"]) == 486
    assert result["legacy_q02"]["verdict"] == "PASS"
    assert conn.total_changes == before


@pytest.mark.parametrize("tamper", ["active_hold", "missing_hold", "wrong_scope", "registration", "source", "binary", "q02", "row", "evidence", "declaration"])
def test_legacy_adoption_remains_fail_closed(tmp_path, monkeypatch, tamper):
    conn, q12, base = _fixture(tmp_path, monkeypatch)
    if tamper == "active_hold":
        conn.execute("UPDATE work_item_holds SET active=1")
    elif tamper == "missing_hold":
        conn.execute("DELETE FROM work_item_holds")
    elif tamper == "wrong_scope":
        q12["ea_id"] = "QM5_21501"
    elif tamper == "q02":
        conn.execute("UPDATE work_items SET verdict='FAIL' WHERE id='q02'")
    elif tamper == "row":
        conn.execute("UPDATE work_items SET payload_json='changed' WHERE id='adopted-0'")
    elif tamper == "declaration":
        payload = json.loads(q12["payload_json"])
        payload["pattern_filter_sweep"]["extra_trial"] = 1
        q12["payload_json"] = json.dumps(payload)
    else:
        name = {"registration": "runner_registration.json", "source": "QM5_41097_test.mq5", "binary": "QM5_41097_test.ex5", "evidence": "adopted-evidence.json"}[tamper]
        (base / name).write_text("changed")
    with pytest.raises(ValueError):
        adoption.authenticate(conn, q12, tmp_path)
