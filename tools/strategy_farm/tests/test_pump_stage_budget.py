from __future__ import annotations

import pytest

from tools.strategy_farm.pump_budget import PumpCycleBudget


class FakeClock:
    def __init__(self) -> None:
        self.now = 100.0

    def __call__(self) -> float:
        return self.now


def test_dispatch_is_first_and_optional_stage_skips_after_cycle_budget() -> None:
    clock = FakeClock()
    budget = PumpCycleBudget(10.0, clock=clock)

    with pytest.raises(RuntimeError, match="dispatch_tick must be the first"):
        budget.run("stats", lambda: None)

    def dispatch() -> str:
        clock.now += 11.0
        return "dispatched"

    assert budget.run(
        "dispatch_tick", dispatch, budget_seconds=3.0, required=True
    ) == "dispatched"
    assert budget.run("stats", lambda: pytest.fail("must not run")) == {
        "skipped": "cycle_budget_exhausted"
    }

    snapshot = budget.snapshot()
    assert [row["name"] for row in snapshot["stages"]] == ["dispatch_tick", "stats"]
    assert snapshot["stages"][0]["over_budget"] is True
    assert snapshot["stages"][1]["skipped"] is True


def test_stage_deadline_is_capped_by_cycle_deadline() -> None:
    clock = FakeClock()
    budget = PumpCycleBudget(20.0, clock=clock)
    clock.now += 15.0
    assert budget.stage_deadline(30.0) == pytest.approx(120.0)
