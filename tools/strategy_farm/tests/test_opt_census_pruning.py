"""DL-089 Amendment 1 deterministic dispatch-pruning tests."""
from __future__ import annotations

import hashlib
import inspect
import json
import sqlite3
from pathlib import Path

import pytest

from tools.strategy_farm import opt_census as census
from tools.strategy_farm import opt_census_pruning as pruning
from tools.strategy_farm import opt_census_select as selection


WORK_ITEMS_DDL = """
CREATE TABLE work_items (
    id TEXT PRIMARY KEY, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
    setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
    parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT, payload_json TEXT,
    created_at TEXT, updated_at TEXT
)
"""
ENABLED = {pruning.ENABLE_ENV: "1"}
STAMP = "2026-08-27T12:34:56+00:00"


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _fixture(tmp_path: Path) -> tuple[sqlite3.Connection, Path, dict]:
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(WORK_ITEMS_DDL)
    ledger_path = tmp_path / "ledger.json"
    cells = []
    rows = []
    for year in census.YEARS:
        work_item_id = f"arm50-{year}"
        cell_key = f"program-a:{year}:BUY:50"
        setfile_path = str(tmp_path / f"arm50-{year}.set")
        cell = {
            "work_item_id": work_item_id,
            "cell_key": cell_key,
            "year": year,
            "arm": "BUY:50",
            "direction": "BUY",
            "predicate_id": 50,
            "setfile_path": setfile_path,
            "from_date": f"{year}.01.01",
            "to_date": f"{year}.12.31",
        }
        cells.append(cell)
        payload = {
            "schema": census.SCHEMA,
            "program_id": "program-a",
            "cell_key": cell_key,
            "year": year,
            "arm": "BUY:50",
            "direction": "BUY",
            "predicate_id": 50,
            "from_date": f"{year}.01.01",
            "to_date": f"{year}.12.31",
            "declared_trial_count": census.DECLARED_TRIAL_COUNT,
            "ledger_path": str(ledger_path),
        }
        rows.append(
            (
                work_item_id,
                "backtest",
                census.PHASE,
                "QM5_TEST",
                "EURUSD",
                setfile_path,
                "pending",
                None,
                0,
                None,
                None,
                None,
                json.dumps(payload, sort_keys=True),
                STAMP,
                STAMP,
            )
        )
    ledger = {
        "schema": census.SCHEMA,
        "program_id": "program-a",
        "activity_floor": census.ACTIVITY_FLOOR,
        "years": list(census.YEARS),
        "wf_windows": [dict(window) for window in census.WF_WINDOWS],
        "declared_trial_count": census.DECLARED_TRIAL_COUNT,
        "cells": cells,
    }
    ledger_path.write_text(
        json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    conn.executemany(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows
    )
    return conn, ledger_path, ledger


def _complete_trigger(
    conn: sqlite3.Connection, tmp_path: Path, year: int = 2020
) -> str:
    work_item_id = f"arm50-{year}"
    evidence = tmp_path / f"trigger-{year}.json"
    evidence.write_text("{}\n", encoding="utf-8")
    conn.execute(
        """
        UPDATE work_items
        SET status='done',verdict='MEASURED',evidence_path=?
        WHERE id=?
        """,
        (str(evidence), work_item_id),
    )
    return work_item_id


def _metrics(entry_days: int):
    def read(_path: Path) -> dict:
        return {
            "report_reconciled": True,
            "entry_trading_days": entry_days,
            "return_to_maxdd": 1.0,
            "trades": entry_days,
        }

    return read


def test_amendment_is_authenticated_and_flag_defaults_off(tmp_path: Path) -> None:
    assert pruning.authenticate_amendment() == pruning.AMENDMENT_SHA256
    conn, ledger_path, _ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    before = ledger_path.read_bytes()

    result = pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now=STAMP,
        env={},
        metric_reader=_metrics(0),
    )

    assert result == {"enabled": False, "triggered": False, "skipped": 0}
    assert conn.execute(
        "SELECT COUNT(*) FROM work_items WHERE verdict='SKIPPED_EXCLUDED'"
    ).fetchone()[0] == 0
    assert ledger_path.read_bytes() == before
    assert not (tmp_path / "pruning_receipts").exists()


def test_floor_break_skips_entire_later_year_chain_with_receipts(
    tmp_path: Path,
) -> None:
    conn, ledger_path, ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    ledger_before = ledger_path.read_bytes()

    result = pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now=STAMP,
        env=ENABLED,
        metric_reader=_metrics(9),
    )

    expected = [f"arm50-{year}" for year in range(2021, 2026)]
    assert result["triggered"] is True
    assert result["skipped_ids"] == expected
    assert result["skipped"] == 5
    assert result["declared_trial_count"] == 154
    assert ledger_path.read_bytes() == ledger_before
    assert ledger["declared_trial_count"] == 154

    receipt_bytes = {}
    for year, work_item_id in zip(range(2021, 2026), expected, strict=True):
        row = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()
        assert (row["status"], row["verdict"], row["claimed_by"]) == (
            "done",
            pruning.SKIPPED_VERDICT,
            None,
        )
        receipt_path = Path(row["evidence_path"])
        receipt = pruning.validate_receipt(
            receipt_path,
            expected_cell_key=f"program-a:{year}:BUY:50",
            expected_trigger_cell_key="program-a:2020:BUY:50",
        )
        assert receipt["timestamp"] == STAMP
        assert receipt["arm"] == "BUY:50"
        assert receipt["trigger_year"] == 2020
        assert receipt["trigger_entry_trading_days"] == 9
        assert receipt["declared_trial_count"] == 154
        payload = json.loads(row["payload_json"])
        assert payload[pruning.DISPOSITION]["receipt_sha256"] == _sha(
            receipt_path.read_bytes()
        )
        receipt_bytes[work_item_id] = receipt_path.read_bytes()

    # Replaying the same completion creates no rows and never rewrites receipts.
    replay = pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now="2099-01-01T00:00:00+00:00",
        env=ENABLED,
        metric_reader=_metrics(9),
    )
    assert replay["skipped"] == 0
    for work_item_id, original in receipt_bytes.items():
        path = Path(
            conn.execute(
                "SELECT evidence_path FROM work_items WHERE id=?", (work_item_id,)
            ).fetchone()[0]
        )
        assert path.read_bytes() == original


def test_at_floor_does_not_prune(tmp_path: Path) -> None:
    conn, _ledger_path, _ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)

    result = pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        env=ENABLED,
        metric_reader=_metrics(census.ACTIVITY_FLOOR),
    )

    assert result["triggered"] is False
    assert result["skipped"] == 0


def test_active_downstream_cell_is_never_interrupted(tmp_path: Path) -> None:
    conn, _ledger_path, _ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    conn.execute(
        "UPDATE work_items SET status='active',claimed_by='T4' WHERE id='arm50-2023'"
    )

    result = pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now=STAMP,
        env=ENABLED,
        metric_reader=_metrics(0),
    )

    active = conn.execute(
        "SELECT status,verdict,claimed_by FROM work_items WHERE id='arm50-2023'"
    ).fetchone()
    assert tuple(active) == ("active", None, "T4")
    assert result["active_downstream_untouched"] == ["arm50-2023"]
    assert result["skipped"] == 4


def test_claim_boundary_backstop_catches_historical_break(tmp_path: Path) -> None:
    conn, _ledger_path, _ledger = _fixture(tmp_path)
    _complete_trigger(conn, tmp_path)
    candidate = conn.execute(
        "SELECT * FROM work_items WHERE id='arm50-2022'"
    ).fetchone()

    result = pruning.prune_candidate_if_excluded(
        conn,
        candidate,
        now=STAMP,
        env=ENABLED,
        metric_reader=_metrics(4),
    )

    assert result["skipped_current"] is True
    assert "arm50-2022" in result["skipped_ids"]
    assert conn.execute(
        "SELECT verdict FROM work_items WHERE id='arm50-2022'"
    ).fetchone()[0] == pruning.SKIPPED_VERDICT


def test_speculative_pruning_inspection_is_read_only(tmp_path: Path) -> None:
    conn, _ledger_path, _ledger = _fixture(tmp_path)
    _complete_trigger(conn, tmp_path)
    candidate = conn.execute(
        "SELECT * FROM work_items WHERE id='arm50-2022'"
    ).fetchone()
    before = conn.execute(
        "SELECT id,status,verdict,claimed_by,payload_json FROM work_items ORDER BY id"
    ).fetchall()

    result = pruning.inspect_candidate_exclusion(
        conn,
        candidate,
        env=ENABLED,
        metric_reader=_metrics(4),
    )

    after = conn.execute(
        "SELECT id,status,verdict,claimed_by,payload_json FROM work_items ORDER BY id"
    ).fetchall()
    assert result["would_skip_current"] is True
    assert result["trigger"]["work_item_id"] == "arm50-2020"
    assert before == after


def test_selector_resolves_skip_without_changing_selection_rules(
    tmp_path: Path,
) -> None:
    conn, _ledger_path, ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now=STAMP,
        env=ENABLED,
        metric_reader=_metrics(2),
    )

    status, metric = selection._default_metric_reader(conn)("arm50-2021")
    assert status == "SKIPPED_EXCLUDED"
    assert metric["receipt"]["trigger_cell_key"] == "program-a:2020:BUY:50"

    def matrix_reader(work_item_id: str):
        row = conn.execute(
            "SELECT verdict FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()
        if row[0] == pruning.SKIPPED_VERDICT:
            return ("SKIPPED_EXCLUDED", {})
        if work_item_id == trigger_id:
            return ("OK", {"entry_days": 2, "return_to_maxdd": 9.0})
        return ("PENDING", None)

    built = selection._build_matrix(ledger, selection.init_driver(), matrix_reader)
    assert built["skipped"] == 5
    assert built["pending"] == 1
    arm = built["matrix"]["BUY"][50]
    evaluation = selection.evaluate_arm(
        arm,
        {year: selection.YearCell(year, 20, 1.0) for year in census.YEARS},
        census.YEARS,
        activity_floor=census.ACTIVITY_FLOOR,
        min_rel=0.05,
    )
    assert evaluation.admissible is False
    assert selection.select_direction({50: evaluation}) == []

    # The amendment changes dispatch only. These sealed selection primitives,
    # anchored windows, and declared trial count remain byte-identical.
    assert _sha(inspect.getsource(selection.evaluate_arm).encode()) == (
        "36ffe328eb1091ed0795de8637b7a25a7631949886ef425d502ffdee3feb2602"
    )
    assert _sha(inspect.getsource(selection.select_direction).encode()) == (
        "3d9eae3eb33def1da1706fa541bfbe93d5c162192f723aaaae490ec441373b6e"
    )
    assert _sha(inspect.getsource(selection.wf_step_selection).encode()) == (
        "add2d896db8c7f941505367793404e55dbce7e45b2c5bdc595ae580d696608fc"
    )
    assert _sha(repr(census.WF_WINDOWS).encode()) == (
        "82304d27b36f64c7f8e331ee2c17739b44830e7d7ee80365be28ee881bc368c3"
    )
    assert census.DECLARED_TRIAL_COUNT == 154


def test_enabled_contract_fails_closed_on_ledger_drift(tmp_path: Path) -> None:
    conn, ledger_path, ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    ledger["declared_trial_count"] = 153
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")

    with pytest.raises(pruning.PruningError, match="declared_trial_count drifted"):
        pruning.prune_after_completed_measurement(
            conn,
            work_item_id=trigger_id,
            env=ENABLED,
            metric_reader=_metrics(0),
        )


def test_selector_fails_closed_if_bound_receipt_is_modified(tmp_path: Path) -> None:
    conn, _ledger_path, _ledger = _fixture(tmp_path)
    trigger_id = _complete_trigger(conn, tmp_path)
    pruning.prune_after_completed_measurement(
        conn,
        work_item_id=trigger_id,
        now=STAMP,
        env=ENABLED,
        metric_reader=_metrics(1),
    )
    receipt_path = Path(
        conn.execute(
            "SELECT evidence_path FROM work_items WHERE id='arm50-2021'"
        ).fetchone()[0]
    )
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["timestamp"] = "2099-01-01T00:00:00+00:00"
    receipt_path.write_text(json.dumps(receipt), encoding="utf-8")

    with pytest.raises(census.CensusError, match="receipt sha256 mismatch"):
        selection._default_metric_reader(conn)("arm50-2021")
