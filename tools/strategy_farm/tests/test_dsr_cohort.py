import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import dsr_cohort


def write_json(path: Path, value) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def fixture(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(dsr_cohort, "DL089_DECLARED_TRIALS", 2)
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute("""CREATE TABLE work_items(
        id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
        status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT, updated_at TEXT)""")
    source = write_json(tmp_path / "source.json", {"runs": []})
    common = ("QM5_42", "EURUSD.DWX", "x.set", "done")
    for phase in ("Q02", "Q03"):
        con.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
            (phase, phase, *common, "PASS", str(source),
             json.dumps({"expected_period": "D1", "expected_setfile_sha256": "b" * 64}),
             "2026-09-06T00:00:00+00:00"),
        )
    q12 = write_json(tmp_path / "q12.json", {"schema": "receipt"})
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("q12", "Q12", *common, "OPT_ELIGIBLE", str(q12), "{}",
         "2026-09-06T00:00:00+00:00"),
    )
    cells = []
    for arm in ("buy_001", "sell_001"):
        for year in (2024, 2025):
            key = f"P:{year}:{arm}"
            wid = f"{arm}-{year}"
            cells.append({"cell_key": key, "arm": arm, "year": year})
            con.execute(
                "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
                (wid, "OPT_CENSUS", *common, "MEASURED", str(source),
                 json.dumps({"program_id": "P", "cell_key": key, "arm": arm,
                             "year": year, "from_date": f"{year}.01.01",
                             "to_date": f"{year}.12.31"}),
                 "2026-09-06T00:00:00+00:00"),
            )
    ledger = {
        "schema": "qm.opt-census.v1", "authority": "DL-089", "program_id": "P",
        "subject_ea_id": "QM5_42", "symbol": "EURUSD.DWX", "timeframe": "D1",
        "years": [2024, 2025], "declared_trial_count": 2,
        "declared_trial_count_effective": 2, "sealed_rule_sha256": "a" * 64,
        "q12_work_item_id": "q12", "cells": cells,
        "driver": {"state": "PATTERN_SELECTION_READY", "numeric": {}},
    }
    write_json(tmp_path / "ledgers" / "P" / "ledger.json", ledger)
    candidate = {"id": "q07", "ea_id": "QM5_42", "symbol": "EURUSD.DWX",
                 "setfile_path": "x.set", "payload_json": "{}"}
    payload = {"expected_period": "D1", "from_date": "2024.01.01",
               "to_date": "2025.12.31"}
    monkeypatch.setattr(
        dsr_cohort, "_peer_metric",
        lambda trial_id, trial_index, rows, role: {
            "trial_index": trial_index, "trial_id": trial_id, "role": role,
            "frequency": "CALENDAR_DAY", "return_unit": "NET_CASH",
            "n_calendar_days": 731, "net_return_input": -1 if trial_index == 0 else 2,
            "sharpe_daily": -0.1 if trial_index == 0 else 0.2,
            "series_sha256": hashlib.sha256(trial_id.encode()).hexdigest(),
            "provenance": [],
        },
    )
    monkeypatch.setattr(
        dsr_cohort, "_pipeline_peer_metric",
        lambda row, trial_id, trial_index: {
            "trial_index": trial_index, "trial_id": trial_id, "role": "research",
            "frequency": "CALENDAR_DAY", "return_unit": "NET_CASH",
            "n_calendar_days": 731, "net_return_input": 1,
            "sharpe_daily": 0.05,
            "series_sha256": hashlib.sha256(trial_id.encode()).hexdigest(),
            "provenance": [],
        },
    )
    return con, candidate, payload


def test_complete_history_seals_and_attaches_deterministically(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    kwargs = {"ledger_root": tmp_path / "ledgers", "artifact_root": tmp_path / "out"}
    status = dsr_cohort.attach(con, candidate, payload, **kwargs)
    assert status["status"] == "SEALED"
    assert set(payload["dsr_context"]) == {"path", "sha256"}
    path = Path(payload["dsr_context"]["path"])
    assert hashlib.sha256(path.read_bytes()).hexdigest() == payload["dsr_context"]["sha256"]
    first = payload["dsr_context"]
    payload2 = {"expected_period": "D1", "from_date": "2024.01.01",
                "to_date": "2025.12.31"}
    dsr_cohort.attach(con, candidate, payload2, **kwargs)
    assert payload2["dsr_context"] == first


def test_incomplete_loser_history_refuses_without_context(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    con.execute("DELETE FROM work_items WHERE id='sell_001-2025'")
    status = dsr_cohort.attach(
        con, candidate, payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert status["status"] == "UNAVAILABLE"
    assert "MATRIX_CELL_MISSING" in status["reason"]
    assert "dsr_context" not in payload


def test_existing_payload_context_is_removed_on_refusal(tmp_path, monkeypatch):
    con, candidate, payload = fixture(tmp_path, monkeypatch)
    payload["dsr_context"] = {"path": "stale", "sha256": "0" * 64}
    con.execute("DELETE FROM work_items WHERE id='buy_001-2024'")
    dsr_cohort.attach(
        con, candidate, payload, ledger_root=tmp_path / "ledgers",
        artifact_root=tmp_path / "out",
    )
    assert "dsr_context" not in payload
    assert payload["dsr_context_status"]["status"] == "UNAVAILABLE"
