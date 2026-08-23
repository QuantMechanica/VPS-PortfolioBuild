"""Wall-clock accounting and admission budgets for one farm pump cycle."""

from __future__ import annotations

import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class StageTiming:
    name: str
    elapsed_seconds: float
    budget_seconds: float | None
    skipped: bool
    over_budget: bool
    skip_reason: str | None = None


class PumpCycleBudget:
    """Admit optional stages while reserving dispatch as the first stage.

    Python cannot safely pre-empt arbitrary stage code.  Budget-aware stages
    receive :meth:`stage_deadline`; all other stages are admitted only while the
    cycle has time left and are reported if they overrun their local allowance.
    """

    def __init__(
        self,
        total_seconds: float,
        *,
        clock: Callable[[], float] = time.monotonic,
        first_stage: str = "dispatch_tick",
    ) -> None:
        if total_seconds <= 0:
            raise ValueError("total_seconds must be greater than zero")
        self.total_seconds = float(total_seconds)
        self._clock = clock
        self._started = clock()
        self._first_stage = first_stage
        self._timings: list[StageTiming] = []

    @property
    def elapsed_seconds(self) -> float:
        return max(0.0, self._clock() - self._started)

    @property
    def remaining_seconds(self) -> float:
        return max(0.0, self.total_seconds - self.elapsed_seconds)

    def stage_deadline(self, stage_budget_seconds: float) -> float:
        allowance = max(0.0, float(stage_budget_seconds))
        return min(self._started + self.total_seconds, self._clock() + allowance)

    def run(
        self,
        name: str,
        operation: Callable[[], Any],
        *,
        budget_seconds: float | None = None,
        required: bool = False,
        minimum_start_seconds: float = 0.0,
    ) -> Any:
        if not self._timings and name != self._first_stage:
            raise RuntimeError(f"{self._first_stage} must be the first pump stage")
        if not required and self.remaining_seconds <= max(0.0, minimum_start_seconds):
            self._timings.append(StageTiming(
                name=name,
                elapsed_seconds=0.0,
                budget_seconds=budget_seconds,
                skipped=True,
                over_budget=False,
                skip_reason="cycle_budget_exhausted",
            ))
            return {"skipped": "cycle_budget_exhausted"}
        started = self._clock()
        value = operation()
        elapsed = max(0.0, self._clock() - started)
        self._timings.append(StageTiming(
            name=name,
            elapsed_seconds=elapsed,
            budget_seconds=budget_seconds,
            skipped=False,
            over_budget=budget_seconds is not None and elapsed > budget_seconds,
        ))
        return value

    def record_elapsed(
        self, name: str, started: float, *, budget_seconds: float | None = None
    ) -> None:
        """Record a legacy in-line stage that cannot yet be wrapped by ``run``."""

        elapsed = max(0.0, self._clock() - started)
        self._timings.append(StageTiming(
            name=name,
            elapsed_seconds=elapsed,
            budget_seconds=budget_seconds,
            skipped=False,
            over_budget=budget_seconds is not None and elapsed > budget_seconds,
        ))

    def snapshot(self) -> dict[str, Any]:
        return {
            "total_budget_seconds": self.total_seconds,
            "elapsed_seconds": round(self.elapsed_seconds, 6),
            "remaining_seconds": round(self.remaining_seconds, 6),
            "stages": [
                {
                    "name": row.name,
                    "elapsed_seconds": round(row.elapsed_seconds, 6),
                    "budget_seconds": row.budget_seconds,
                    "skipped": row.skipped,
                    "over_budget": row.over_budget,
                    "skip_reason": row.skip_reason,
                }
                for row in self._timings
            ],
        }
