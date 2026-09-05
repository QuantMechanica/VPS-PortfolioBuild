from __future__ import annotations

import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
STRATEGY_FARM = REPO / "tools" / "strategy_farm"
sys.path.insert(0, str(STRATEGY_FARM))

from factory_mutation_lock import FactoryMutationLock  # noqa: E402
from pump_budget import PumpCycleBudget  # noqa: E402


def test_pump_stage_reports_only_factory_mutation_lock_holds(tmp_path: Path) -> None:
    budget = PumpCycleBudget(30.0)

    def stage() -> dict[str, bool]:
        with FactoryMutationLock(
            tmp_path / "FACTORY_MUTATION.lock",
            owner="pytest-short-write",
            hold_telemetry_path=tmp_path / "holds.jsonl",
        ):
            pass
        with FactoryMutationLock(
            tmp_path / "PROGRAM_LOCAL.lock",
            owner="pytest-local-lock",
            hold_telemetry_path=tmp_path / "holds.jsonl",
        ):
            pass
        return {"ok": True}

    assert budget.run("dispatch_tick", stage) == {"ok": True}
    snapshot = budget.snapshot()
    row = snapshot["stages"][0]
    assert row["lock_acquisitions"] == 1
    assert row["lock_owners"] == ["pytest-short-write"]
    assert row["lock_held_seconds"] >= 0.0
    assert snapshot["lock_held_seconds"] == row["lock_held_seconds"]


def test_read_only_stage_reports_zero_lock_hold() -> None:
    budget = PumpCycleBudget(30.0)
    budget.run("dispatch_tick", lambda: {"classification": "read_only"})
    row = budget.snapshot()["stages"][0]
    assert row["lock_held_seconds"] == 0.0
    assert row["lock_acquisitions"] == 0
    assert row["lock_owners"] == []
