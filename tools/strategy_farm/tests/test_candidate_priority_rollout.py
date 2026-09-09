import pytest
from tools.strategy_farm.session_tools import roll_candidate_priority_20260909 as rollout


def test_exact_targets_exclude_lab_and_live_terminal_names():
    assert rollout.targets(["T1=123", "T10=456"]) == {"T1": 123, "T10": 456}
    for values in (["T11=123"], ["T_Live=123"], ["T1=0"], ["T1=123", "T1=456"], []):
        with pytest.raises(ValueError):
            rollout.targets(values)


def test_only_unreserved_idle_worker_is_eligible():
    assert rollout.eligible("T1", {"T2"}, {"T3": {}})
    assert not rollout.eligible("T1", {"T1"}, {})
    assert not rollout.eligible("T1", set(), {"T1": {"reserved_by": "someone-else"}})


def test_rollout_uses_existing_reservation_controller():
    assert callable(rollout.farmctl.set_terminal_reservation)
    assert callable(rollout.farmctl.release_terminal_reservation)
