"""Contract for OWNER-DEC-Q08-SWEEP-ARM-CONTEXT-20260914 (ticket 7d9dd3b5): a
PRESCREEN_SKIPPED census cell whose skip authority re-authenticates is a validly
measured year with zero trades, not a missing trial -- the arm stays in the DSR
cohort. Any other non-terminal cell (no hold, or a hold that fails
re-authentication) is unaffected: the ordinary INCOMPLETE_TRIAL path applies
unchanged, or an authentication gap fails closed under its own named reason.

These tests exercise ``_matrix_trial_groups``/``_peer_metric`` directly (the real,
unmonkeypatched functions) with ``dsr_cohort._prescreen_skip_disposition`` replaced by a
stub -- the same boundary the real function calls at
(``dl089_prescreen_retro.disposition``), so these tests verify dsr_cohort's own new
integration logic without re-deriving that module's receipt/contract authentication
stack (which is a separate, already-governed component).
"""
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import dsr_cohort


def write_json(path: Path, value) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


def _fixture(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(dsr_cohort, "DL089_DECLARED_TRIALS", 2)
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    con.execute("""CREATE TABLE work_items(
        id TEXT PRIMARY KEY, phase TEXT, ea_id TEXT, symbol TEXT, setfile_path TEXT,
        status TEXT, verdict TEXT, evidence_path TEXT, payload_json TEXT, updated_at TEXT)""")
    report_path = tmp_path / "report.txt"
    report_path.write_text("native report", encoding="utf-8")
    source = write_json(tmp_path / "source.json", {
        "runs": [{"status": "OK", "report_canonical_path": str(report_path), "total_trades": 0}],
    })
    common = ("QM5_42", "EURUSD.DWX", "x.set")

    # buy_001: both years MEASURED/done (ordinary path, unaffected by this ticket).
    for year in (2024, 2025):
        con.execute(
            "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
            (f"buy_001-{year}", "OPT_CENSUS", *common, "done", "MEASURED", str(source),
             json.dumps({"program_id": "P", "cell_key": f"P:{year}:buy_001", "arm": "buy_001",
                         "year": year, "from_date": f"{year}.01.01", "to_date": f"{year}.12.31"}),
             "2026-09-06T00:00:00+00:00"),
        )
    # sell_001/2024: MEASURED/done. sell_001/2025: pending/None -- the held cell.
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("sell_001-2024", "OPT_CENSUS", *common, "done", "MEASURED", str(source),
         json.dumps({"program_id": "P", "cell_key": "P:2024:sell_001", "arm": "sell_001",
                     "year": 2024, "from_date": "2024.01.01", "to_date": "2024.12.31"}),
         "2026-09-06T00:00:00+00:00"),
    )
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("sell_001-2025", "OPT_CENSUS", *common, "pending", None, str(source),
         json.dumps({"program_id": "P", "cell_key": "P:2025:sell_001", "arm": "sell_001",
                     "year": 2025, "from_date": "2025.01.01", "to_date": "2025.12.31"}),
         "2026-09-06T00:00:00+00:00"),
    )

    q12 = write_json(tmp_path / "q12.json", {"schema": "receipt"})
    con.execute(
        "INSERT INTO work_items VALUES(?,?,?,?,?,?,?,?,?,?)",
        ("q12", "Q12", *common, "done", "OPT_ELIGIBLE", str(q12), "{}",
         "2026-09-06T00:00:00+00:00"),
    )

    cells = [
        {"cell_key": "P:2024:buy_001", "arm": "buy_001", "year": 2024},
        {"cell_key": "P:2025:buy_001", "arm": "buy_001", "year": 2025},
        {"cell_key": "P:2024:sell_001", "arm": "sell_001", "year": 2024},
        {"cell_key": "P:2025:sell_001", "arm": "sell_001", "year": 2025},
    ]
    ledger = {
        "schema": "qm.opt-census.v1", "authority": "DL-089", "program_id": "P",
        "subject_ea_id": "QM5_42", "symbol": "EURUSD.DWX", "timeframe": "D1",
        "years": [2024, 2025], "declared_trial_count": 2,
        "declared_trial_count_effective": 2, "sealed_rule_sha256": "a" * 64,
        "q12_work_item_id": "q12", "cells": cells,
        "driver": {"state": "PATTERN_SELECTION_READY", "numeric": {}},
    }
    ledger_path = write_json(tmp_path / "ledgers" / "P" / "ledger.json", ledger)
    candidate = {"id": "q07", "ea_id": "QM5_42", "symbol": "EURUSD.DWX",
                 "setfile_path": "x.set", "payload_json": "{}"}
    payload = {"expected_period": "D1", "from_date": "2024.01.01",
               "to_date": "2025.12.31"}
    return con, candidate, payload, ledger, ledger_path


def _current_rows(con):
    return dsr_cohort._current_matrix_rows(con, "P")


def test_valid_skip_authority_keeps_the_arm_with_a_zero_return_year(tmp_path, monkeypatch):
    con, candidate, payload, ledger, ledger_path = _fixture(tmp_path, monkeypatch)
    receipt_path = tmp_path / "receipt.json"
    receipt_path.write_text("{}", encoding="utf-8")

    def fake_skip(conn, row):
        if row.get("id") == "sell_001-2025":
            return {"receipt_path": str(receipt_path), "receipt_sha256": "x" * 64,
                     "program_id": "P", "unmeasured": True}
        return None

    monkeypatch.setattr(dsr_cohort, "_prescreen_skip_disposition", fake_skip)
    current = _current_rows(con)
    groups = dsr_cohort._matrix_trial_groups(ledger, current, con)
    by_trial = {trial_id: rows for trial_id, role, rows in groups}
    sell_rows = by_trial["DL089:PATTERN:sell_001"]
    assert len(sell_rows) == 2
    skipped_row = next(r for r in sell_rows if r["id"] == "sell_001-2025")
    assert skipped_row["_dsr_prescreen_skip"]["program_id"] == "P"

    # _peer_metric must not raise INCOMPLETE_TRIAL for the held-but-authenticated cell,
    # and must fold in a full zero-filled calendar year (2025 = 365 days) for it.
    peer = dsr_cohort._peer_metric("DL089:PATTERN:sell_001", 0, sell_rows, role="selection")
    assert peer["n_calendar_days"] == 366 + 365  # 2024 (leap) MEASURED + 2025 zero-filled
    assert peer["net_return_input"] == 0.0  # the MEASURED 2024 row's own source.json has no runs -> 0 trades


def test_no_hold_at_all_still_raises_incomplete_trial(tmp_path, monkeypatch):
    con, candidate, payload, ledger, ledger_path = _fixture(tmp_path, monkeypatch)
    monkeypatch.setattr(dsr_cohort, "_prescreen_skip_disposition", lambda conn, row: None)
    current = _current_rows(con)
    groups = dsr_cohort._matrix_trial_groups(ledger, current, con)
    by_trial = {trial_id: rows for trial_id, role, rows in groups}
    sell_rows = by_trial["DL089:PATTERN:sell_001"]
    with pytest.raises(dsr_cohort.CohortUnavailable, match="INCOMPLETE_TRIAL"):
        dsr_cohort._peer_metric("DL089:PATTERN:sell_001", 0, sell_rows, role="selection")


def test_hold_present_but_authentication_fails_closed_with_named_reason(tmp_path, monkeypatch):
    con, candidate, payload, ledger, ledger_path = _fixture(tmp_path, monkeypatch)

    def failing_skip(conn, row):
        if row.get("id") == "sell_001-2025":
            raise dsr_cohort.CohortUnavailable(
                "PRESCREEN_SKIP_AUTHORITY_INVALID:sell_001-2025:retro held-cell receipt identity mismatch"
            )
        return None

    monkeypatch.setattr(dsr_cohort, "_prescreen_skip_disposition", failing_skip)
    current = _current_rows(con)
    with pytest.raises(dsr_cohort.CohortUnavailable, match="PRESCREEN_SKIP_AUTHORITY_INVALID"):
        dsr_cohort._matrix_trial_groups(ledger, current, con)


def test_prescreen_skip_disposition_delegates_to_retro_and_wraps_value_error(monkeypatch):
    """The real (unstubbed) _prescreen_skip_disposition: None passes through, a
    ValueError from dl089_prescreen_retro.disposition becomes a named CohortUnavailable."""
    from tools.strategy_farm import dl089_prescreen_retro as retro

    monkeypatch.setattr(retro, "disposition", lambda conn, row: None)
    assert dsr_cohort._prescreen_skip_disposition(object(), {"id": "x"}) is None

    def raising(conn, row):
        raise ValueError("boom")

    monkeypatch.setattr(retro, "disposition", raising)
    with pytest.raises(dsr_cohort.CohortUnavailable, match=r"PRESCREEN_SKIP_AUTHORITY_INVALID:x:boom"):
        dsr_cohort._prescreen_skip_disposition(object(), {"id": "x"})
