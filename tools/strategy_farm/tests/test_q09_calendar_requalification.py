from pathlib import Path

import pytest

from tools.strategy_farm import q09_calendar_pin as pin
from tools.strategy_farm import q09_calendar_requalification as requal


def test_successor_id_is_deterministic_and_binds_target_identity() -> None:
    first = requal.successor_work_item_id(
        task_id=requal.TASK_ID,
        source_work_item_id="11111111-1111-4111-8111-111111111111",
        target_ea_id="QM5_41488",
    )
    repeat = requal.successor_work_item_id(
        task_id=requal.TASK_ID,
        source_work_item_id="11111111-1111-4111-8111-111111111111",
        target_ea_id="QM5_41488",
    )
    different_target = requal.successor_work_item_id(
        task_id=requal.TASK_ID,
        source_work_item_id="11111111-1111-4111-8111-111111111111",
        target_ea_id="QM5_12710",
    )
    assert first == repeat
    assert first != different_target


def test_priority_is_roster_then_followups_then_remaining() -> None:
    rows = [
        {"ea_id": "QM5_999", "verdict": "CONFIG_LOCKED", "phase": "Q10_NEWS", "symbol": "X", "work_item_id": "z"},
        {"ea_id": "QM5_20266", "verdict": "CONFIG_LOCKED", "phase": "Q10_NEWS", "symbol": "X", "work_item_id": "c"},
        {"ea_id": "QM5_11708", "verdict": "REVIEW_REQUIRED", "phase": "Q09_NEWS", "symbol": "X", "work_item_id": "b"},
        {"ea_id": "QM5_10706", "verdict": "REVIEW_REQUIRED", "phase": "Q09_NEWS", "symbol": "X", "work_item_id": "a"},
        {"ea_id": "QM5_13213", "verdict": "REVIEW_REQUIRED", "phase": "Q09_NEWS", "symbol": "X", "work_item_id": "d"},
    ]
    ordered = [row["ea_id"] for row in sorted(rows, key=requal._priority_key)]
    assert ordered == [
        "QM5_13213", "QM5_10706", "QM5_11708", "QM5_20266", "QM5_999"
    ]


def test_artifact_layout_is_task_scoped_and_windows_safe() -> None:
    entry = {
        "priority_rank": 128,
        "source_work_item_id": "11111111-1111-4111-8111-111111111111",
        "successor_work_item_id": "22222222-2222-4222-8222-222222222222",
    }
    root = requal._successor_artifact_root(requal.DEFAULT_ARTIFACT_ROOT, entry)
    assert f"task_{requal.TASK_ID}" in root.parts
    assert root.name == "slot128_11111111"
    longest_cell = root / "q09_plan" / "cells" / "policy_on__m3__c4__s2026" / "inputs.set"
    assert len(str(longest_cell)) < 260


def test_task_scoped_evidence_dir_is_enforced(tmp_path: Path) -> None:
    with pytest.raises(requal.RequalificationError):
        requal._require_task_scoped_dir(tmp_path / "not-scoped", requal.TASK_ID)
    expected = tmp_path / f"task_{requal.TASK_ID}"
    assert requal._require_task_scoped_dir(expected, requal.TASK_ID) == expected.resolve()


def test_contract_binds_approved_successor_and_replacement_map() -> None:
    binding = pin.payload_binding()
    assert binding["schema"] == "qm.q09-calendar-pin-contract/v2"
    assert binding["content_sha256"] == requal.calendar_pin.CONTENT_SHA256
    assert binding["historical_contracts_preserved"] is True
    assert requal.TARGET_REPLACEMENTS == {
        "QM5_12710": "QM5_41488",
        "QM5_20266": "QM5_41489",
    }
