"""Evidence-class-aware DL-089 annual lane view for PRESCREEN promotions (2026-09-14, ticket 4d915807).

config_sweep.authenticate_ledger appends the promoted REAL_TICKS cells to the ledger view
under the same program/arm/year as the PRESCREEN cells, so dl089_scheduling.arm_frontier saw
every year twice ("declared arm c00 is missing, duplicate, or out of year order") and the 259
promoted cells of WINSWEEP_QM5_41405_PRESCREEN_DRYRUN_2019_2025 could never be claimed.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import dl089_scheduling  # noqa: E402
import terminal_worker as tw  # noqa: E402

PROGRAM = "WINSWEEP_TEST_PROMO_2019_2021"
YEARS = [2019, 2020, 2021]


def _cell(arm: str, year: int, klass: str, role: str | None = None) -> dict:
    suffix = "real" if klass == "REAL_TICKS" else "pre"
    cell = {
        "cell_key": f"{PROGRAM}:{arm}:{year}:{suffix}",
        "work_item_id": f"{arm}-{year}-{suffix}",
        "arm": arm, "year": year, "direction": "LONG", "predicate_id": "p1",
        "from_date": f"{year}.01.01", "to_date": f"{year}.12.31",
        "setfile_path": f"D:/fake/{arm}.set", "overrides": {}, "evidence_class": klass,
    }
    if role:
        cell["promotion_role"] = role
    return cell


def _ledger(with_promotion: bool) -> dict:
    cells = [_cell(arm, y, "PRESCREEN") for arm in ("c00", "c01") for y in YEARS]
    if with_promotion:
        cells += [_cell("c00", y, "REAL_TICKS", "KEEP") for y in YEARS]
        cells += [_cell("c01", y, "REAL_TICKS", "CONTROL") for y in YEARS]
    return {
        "schema": "qm.window-sweep.v1", "program_id": PROGRAM, "years": list(YEARS), "cells": cells,
        "prescreen_contract": {"x": 1}, "prescreen_admitted_cell_keys": [c["cell_key"] for c in cells if c["evidence_class"] == "PRESCREEN"],
        "driver": {"reruns": {}},
    }


def _row(cell: dict, status: str = "pending") -> dict:
    payload = {k: cell[k] for k in ("cell_key", "arm", "year", "direction", "predicate_id", "from_date", "to_date", "evidence_class")}
    payload["program_id"] = PROGRAM
    if cell.get("promotion_role"):
        payload["promotion_role"] = cell["promotion_role"]
        payload["promotion_amendment_path"] = "D:/fake/promotion_amendment.json"
    return {"id": cell["work_item_id"], "status": status, "verdict": None, "claimed_by": None,
            "setfile_path": cell["setfile_path"], "payload_json": json.dumps(payload)}


def test_promoted_real_candidate_sees_only_the_real_lane_and_no_prescreen_admission():
    ledger = _ledger(with_promotion=True)
    real_payload = json.loads(_row(_cell("c00", 2019, "REAL_TICKS", "KEEP"))["payload_json"])
    real_payload["schema"] = "qm.window-sweep.v1"
    cells, lane = tw._dl089_declared_lane(ledger, real_payload)
    assert len(cells) == 6 and all(c.get("promotion_role") for c in cells)
    assert "prescreen_admitted_cell_keys" not in lane and "prescreen_contract" not in lane
    rows = [_row(c) for c in cells]
    frontier = dl089_scheduling.arm_frontier(rows, lane)
    assert {k[1] for k in frontier} == {"c00", "c01"}
    assert frontier[(PROGRAM, "c00")]["id"] == "c00-2019-real"


def test_without_the_fix_the_mixed_view_fails_closed():
    ledger = _ledger(with_promotion=True)
    rows = [_row(c) for c in ledger["cells"]]
    with pytest.raises(dl089_scheduling.SchedulingError, match="missing, duplicate, or out of year order"):
        dl089_scheduling.arm_frontier(rows, {**ledger})


def test_prescreen_candidate_never_sees_promoted_cells():
    ledger = _ledger(with_promotion=True)
    pre_payload = json.loads(_row(_cell("c00", 2019, "PRESCREEN"))["payload_json"])
    pre_payload["schema"] = "qm.window-sweep.v1"
    cells, lane = tw._dl089_declared_lane(ledger, pre_payload)
    assert len(cells) == 6 and not any(c.get("promotion_role") for c in cells)
    assert lane.get("prescreen_admitted_cell_keys") == ledger["prescreen_admitted_cell_keys"]


def test_program_without_promotion_is_byte_identical():
    ledger = _ledger(with_promotion=False)
    payload = json.loads(_row(_cell("c00", 2019, "PRESCREEN"))["payload_json"])
    payload["schema"] = "qm.window-sweep.v1"
    cells, lane = tw._dl089_declared_lane(ledger, payload)
    assert cells == ledger["cells"]
    assert lane == ledger
