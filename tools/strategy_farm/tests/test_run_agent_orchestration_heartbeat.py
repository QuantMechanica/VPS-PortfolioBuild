import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import run_agent_orchestration_task as orch  # noqa: E402


class _FakeProc:
    """Simulates a process whose wait() times out N times before completing."""

    def __init__(self, timeouts_before_exit: int, returncode: int = 0):
        self._timeouts_left = timeouts_before_exit
        self.returncode = returncode
        self.wait_calls = 0

    def wait(self, timeout=None):
        self.wait_calls += 1
        if self._timeouts_left > 0:
            self._timeouts_left -= 1
            raise subprocess.TimeoutExpired(cmd="fake", timeout=timeout)
        return self.returncode


def test_refreshes_heartbeat_between_slices_until_process_exits():
    proc = _FakeProc(timeouts_before_exit=3, returncode=0)
    refresh_calls = []

    rc = orch._wait_with_heartbeat_refresh(
        proc,
        timeout_seconds=10_000,  # generous overall budget
        refresh_interval_seconds=0,  # instant slices so the loop doesn't sleep in the test
        refresh_fn=lambda: refresh_calls.append(True),
    )

    assert rc == 0
    # One refresh per TimeoutExpired iteration before the process finally exits.
    assert len(refresh_calls) == 3
    assert proc.wait_calls == 4


def test_returns_immediately_without_refresh_when_process_exits_first_poll():
    proc = _FakeProc(timeouts_before_exit=0, returncode=0)
    refresh_calls = []

    rc = orch._wait_with_heartbeat_refresh(
        proc, timeout_seconds=10_000, refresh_interval_seconds=600, refresh_fn=lambda: refresh_calls.append(True)
    )

    assert rc == 0
    assert refresh_calls == []


def test_raises_timeout_expired_once_overall_budget_is_exhausted():
    proc = _FakeProc(timeouts_before_exit=10_000, returncode=0)

    def slow_refresh():
        # Each refresh call "spends" wall-clock time by faking monotonic advance
        # is not needed here: refresh_interval_seconds=0 plus a tiny overall
        # budget forces the deadline check to trip after the first slice.
        pass

    try:
        orch._wait_with_heartbeat_refresh(
            proc, timeout_seconds=0, refresh_interval_seconds=0, refresh_fn=slow_refresh
        )
        assert False, "expected TimeoutExpired"
    except subprocess.TimeoutExpired:
        pass


def test_regression_plain_wait_never_refreshes_during_a_long_run():
    """Documents the pre-fix behaviour this ticket closes: a bare proc.wait(timeout=...)
    call (what run_agent_slot used before MNT-003) gives the caller no chance to refresh
    the lane heartbeat while the process is still legitimately running."""
    proc = _FakeProc(timeouts_before_exit=3, returncode=0)
    try:
        proc.wait(timeout=10_000)
        assert False, "fake proc should still be 'running' on the first bare wait()"
    except subprocess.TimeoutExpired:
        pass
    # No refresh hook exists in this call shape at all -- that absence is the bug.
