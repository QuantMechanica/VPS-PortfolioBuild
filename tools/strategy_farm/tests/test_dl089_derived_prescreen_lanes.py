"""Annual prescreen admission must not leak into sealed derived-run lanes."""
from __future__ import annotations

import copy
import json
import sqlite3

import pytest

from tools.strategy_farm import dl089_prescreen as prescreen
from tools.strategy_farm.tests.test_opt_census_select import (
    WORK_ITEMS_DDL, _governed_derived_ledger, scheduling, sel, terminal_worker,
)


def _fixture(tmp_path, stage="WF_COMBO"):
    ledger = _governed_derived_ledger(tmp_path)
    contract = {
        "schema": prescreen.SCHEMA, "decision_id": prescreen.DECISION,
        "stage1_years": [2019, 2020], "threshold": 5,
        "net_profit_relative_uplift": "0.05",
        "relative_base_rule": "STRICTLY_POSITIVE_BASELINE_AS_EXISTING_SELECTOR",
        "declared_trial_count": 154, "protected_years": [],
        "manifest_path": str(tmp_path / "fixture-manifest.json"),
        "manifest_sha256": "a" * 64,
    }
    contract["contract_sha256"] = prescreen.digest(contract)
    ledger.update(
        cells=[{"cell_key": "PROG:2019:baseline", "arm": "baseline", "year": 2019}],
        years=[2019], prescreen_contract=contract,
        prescreen_admitted_cell_keys=["PROG:2019:baseline"],
    )
    if stage == "WF_COMBO":
        key, extra, section, run_key = "PROG:wf1:combo:2022", {"wf_step": 1, "test_year": 2022}, "wf", "combo_runs"
    elif stage == "NUMERIC_BASELINE":
        key, extra, section, run_key = "PROG:numeric:baseline:2019", {"year": 2019}, "numeric", "runs"
    elif stage == "NUMERIC":
        key, extra, section, run_key = "PROG:numeric:strategy_alpha:0.5:2019", {"year": 2019, "param": "strategy_alpha", "value": 0.5}, "numeric", "runs"
    else:
        key, extra, section, run_key = "PROG:final_fullwindow:final", {"role": "final"}, "final_fullwindow", "runs"
    path = str(tmp_path / "derived.set")
    spec = {"cell_key": key, "work_item_id": "derived", "setfile_path": path, "stage": stage, **extra}
    ledger["driver"] = {section: {run_key: [spec]}, "reruns": {}}
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    conn.execute(WORK_ITEMS_DDL)
    sel._insert_run(conn, ledger, work_item_id="derived", cell_key=key, setfile_path=path,
                    from_date="2022.01.01" if stage == "WF_COMBO" else "2019.01.01",
                    to_date="2022.12.31", stage=stage, extra=extra)
    row = dict(conn.execute("SELECT * FROM work_items WHERE id='derived'").fetchone())
    conn.close()
    return ledger, row, json.loads(row["payload_json"])


@pytest.mark.parametrize("stage", ["WF_COMBO", "NUMERIC_BASELINE", "NUMERIC", "FINAL_FULLWINDOW"])
def test_derived_lane_validates_annual_contract_without_inheriting_admissions(tmp_path, stage):
    ledger, row, payload = _fixture(tmp_path, stage)
    before = copy.deepcopy(ledger)
    cells, lane = terminal_worker._dl089_declared_lane(ledger, payload)
    assert ledger == before
    assert cells[0]["work_item_id"] == "derived"
    assert "prescreen_contract" not in lane
    assert "prescreen_admitted_cell_keys" not in lane
    frontier = scheduling.arm_frontier([row], lane)
    assert frontier[("PROG", payload["arm"])]["id"] == "derived"
    with pytest.raises(scheduling.SchedulingError, match="coverage"):
        scheduling.arm_frontier([], lane)


@pytest.mark.parametrize("tamper", ["contract", "undeclared", "duplicate"])
def test_bad_annual_admission_still_blocks_derived_lane(tmp_path, tamper):
    ledger, row, payload = _fixture(tmp_path)
    if tamper == "contract":
        ledger["prescreen_contract"]["threshold"] = 0
    elif tamper == "undeclared":
        ledger["prescreen_admitted_cell_keys"].append("FOREIGN:2019:baseline")
    else:
        ledger["prescreen_admitted_cell_keys"] *= 2
    with pytest.raises(ValueError):
        terminal_worker._dl089_declared_lane(ledger, payload)


def test_undeclared_derived_arm_remains_blocked(tmp_path):
    ledger, row, payload = _fixture(tmp_path)
    payload["arm"] = "wf2_combo"
    with pytest.raises(Exception, match="derived lane absent"):
        terminal_worker._dl089_declared_lane(ledger, payload)


def test_annual_lane_keeps_prescreen_contract_unchanged(tmp_path):
    ledger, row, payload = _fixture(tmp_path)
    payload.pop("opt_census_stage")
    _, lane = terminal_worker._dl089_declared_lane(ledger, payload)
    assert lane == ledger
