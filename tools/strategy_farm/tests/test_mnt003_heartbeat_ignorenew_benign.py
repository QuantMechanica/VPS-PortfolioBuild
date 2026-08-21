from __future__ import annotations

import json
from unittest import mock

from tools.strategy_farm import heartbeat_snapshot as hb


def _run_probe(rows: list[dict]) -> dict:
    out: dict = {"flags": []}
    fake = mock.Mock(stdout=json.dumps(rows), stderr="", returncode=0)
    with mock.patch.object(hb.subprocess, "run", return_value=fake):
        hb.probe_scheduled_tasks(out)
    return out


def test_pump_0x800710e0_is_expected_not_failing() -> None:
    # 2147946720 == 0x800710E0 on the SYSTEM/IgnoreNew Pump task is the benign
    # overlap-refusal; it must land in tasks_failing_expected, never tasks_failing,
    # and must raise no SCHEDULED_TASK_FAILING flag (MNT-003).
    out = _run_probe([{"n": "QM_StrategyFarm_Pump_5min", "rc": 2147946720,
                       "last": "2026-08-21T12:00:00Z"}])
    assert out["tasks_failing"] == []
    assert "QM_StrategyFarm_Pump_5min:rc=2147946720" in out["tasks_failing_expected"]
    assert not any(f.startswith("SCHEDULED_TASK_FAILING") for f in out["flags"])


def test_orchestration_siblings_0x800710e0_are_expected() -> None:
    rows = [{"n": name, "rc": 2147946720, "last": "2026-08-21T12:00:00Z"} for name in (
        "QM_StrategyFarm_CodexOrchestration_15min",
        "QM_StrategyFarm_ClaudeOrchestration_15min",
        "QM_StrategyFarm_GeminiOrchestration_15min",
        "QM_StrategyFarm_Dashboard_Hourly",
    )]
    out = _run_probe(rows)
    assert out["tasks_failing"] == []
    assert len(out["tasks_failing_expected"]) == 4


def test_pump_killed_at_time_limit_still_fails() -> None:
    # A real Pump failure (267014 killed@ExecutionTimeLimit) must NOT be masked
    # by the benign-overlap allowance -- it is code-scoped to 0x800710E0 only.
    out = _run_probe([{"n": "QM_StrategyFarm_Pump_5min", "rc": 267014,
                       "last": "2026-08-21T12:00:00Z"}])
    assert "QM_StrategyFarm_Pump_5min:rc=267014" in out["tasks_failing"]
    assert any(f.startswith("SCHEDULED_TASK_FAILING") for f in out["flags"])


def test_non_class_task_0x800710e0_still_fails() -> None:
    # 0x800710E0 on a task NOT in the benign SYSTEM/IgnoreNew class is still a
    # real failure and must surface.
    out = _run_probe([{"n": "QM_T_Live_AtLogon", "rc": 2147946720,
                       "last": "2026-08-21T12:00:00Z"}])
    assert "QM_T_Live_AtLogon:rc=2147946720" in out["tasks_failing"]
