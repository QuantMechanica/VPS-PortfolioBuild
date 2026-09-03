"""Hardening tests for the Q09 claimed-terminal exit scan.

These cover the 2026-09-03 fix that stopped a single saturated-host
Get-CimInstance timeout from failing an in-flight Q10_NEWS expansion cell
without a retry.  They exercise the scan orchestrator in isolation with the
native walk, the pwsh probe, and the clock all injected -- no real process
enumeration and no real sleeping.
"""

import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_runner as runner  # noqa: E402


class ScanHardeningTests(unittest.TestCase):
    def test_native_toolhelp_result_is_used_without_pwsh_or_sleep(self) -> None:
        rows = [{"ProcessId": 1, "ExecutablePath": r"D:\QM\mt5\T1\terminal64.exe"}]
        sleeps: list[float] = []

        def pwsh(_timeout: float):
            raise AssertionError("pwsh must not run when the native walk succeeds")

        out = runner._scan_terminal64_processes(
            toolhelp_scan=lambda: rows,
            pwsh_scan=pwsh,
            sleeper=sleeps.append,
        )
        self.assertEqual(out, rows)
        self.assertEqual(sleeps, [])

    def test_native_empty_list_is_authoritative_not_a_fallback(self) -> None:
        sleeps: list[float] = []

        def pwsh(_timeout: float):
            raise AssertionError("an empty native result is a valid no-terminal state")

        out = runner._scan_terminal64_processes(
            toolhelp_scan=lambda: [],
            pwsh_scan=pwsh,
            sleeper=sleeps.append,
        )
        self.assertEqual(out, [])
        self.assertEqual(sleeps, [])

    def test_scan_succeeds_on_second_attempt_after_one_backoff(self) -> None:
        rows = [{"ProcessId": 42, "ExecutablePath": r"D:\QM\mt5\T3\terminal64.exe"}]
        calls = {"n": 0}
        timeouts: list[float] = []
        sleeps: list[float] = []

        def pwsh(timeout: float):
            timeouts.append(timeout)
            calls["n"] += 1
            if calls["n"] == 1:
                raise runner.RunnerError(
                    "Q09 terminal process scan failed: pwsh timed out"
                )
            return rows

        out = runner._scan_terminal64_processes(
            toolhelp_scan=lambda: None,  # native unavailable -> pwsh fallback
            pwsh_scan=pwsh,
            sleeper=sleeps.append,
        )
        self.assertEqual(out, rows)
        self.assertEqual(calls["n"], 2)
        # Exactly one backoff sleep between the first and second attempt.
        self.assertEqual(sleeps, [runner.TERMINAL_SCAN_BACKOFF_SEC[0]])
        # The widened 90 s per-attempt timeout is handed to every probe call.
        self.assertEqual(
            timeouts, [float(runner.TERMINAL_SCAN_TIMEOUT_SEC)] * 2
        )
        self.assertEqual(runner.TERMINAL_SCAN_TIMEOUT_SEC, 90)

    def test_all_attempts_fail_raise_transient_classification(self) -> None:
        sleeps: list[float] = []
        boom = runner.RunnerError("Q09 terminal process scan failed: host saturated")

        def pwsh(_timeout: float):
            raise boom

        with self.assertRaises(runner.TransientCellError) as ctx:
            runner._scan_terminal64_processes(
                toolhelp_scan=lambda: None,
                pwsh_scan=pwsh,
                sleeper=sleeps.append,
            )
        # The structured error carries the transient classification the
        # per-cell retry lane keys on: a RunnerError, but not a CapacityError.
        self.assertIsInstance(ctx.exception, runner.RunnerError)
        self.assertNotIsInstance(ctx.exception, runner.CapacityError)
        self.assertIn("transient", str(ctx.exception).lower())
        # The underlying pwsh failure is chained for forensics.
        self.assertIs(ctx.exception.__cause__, boom)
        # Default budget = 3 retries -> 4 attempts -> 3 backoff sleeps (5/15/30).
        self.assertEqual(sleeps, list(runner.TERMINAL_SCAN_BACKOFF_SEC))
        self.assertEqual(sleeps, [5.0, 15.0, 30.0])

    def test_transient_class_is_the_lane_routed_runner_error_subclass(self) -> None:
        # The bounded per-cell retry lane (proven in test_q09_news_runner_v2)
        # catches TransientCellError and retries; CapacityError re-raises to
        # requeue the whole item.  A scan miss must land in the former, so it
        # must be a TransientCellError that is not a CapacityError.
        self.assertTrue(issubclass(runner.TransientCellError, runner.RunnerError))
        self.assertFalse(issubclass(runner.TransientCellError, runner.CapacityError))

    def test_retry_budget_and_backoff_schedule_are_configurable(self) -> None:
        sleeps: list[float] = []

        def pwsh(_timeout: float):
            raise runner.RunnerError("boom")

        with self.assertRaises(runner.TransientCellError):
            runner._scan_terminal64_processes(
                toolhelp_scan=lambda: None,
                pwsh_scan=pwsh,
                sleeper=sleeps.append,
                retry_budget=1,
                backoff_sec=(0.25, 9.0, 9.0),
            )
        # budget 1 -> 2 attempts -> exactly 1 backoff sleep (schedule head).
        self.assertEqual(sleeps, [0.25])

    def test_zero_retry_budget_makes_a_single_attempt_with_no_sleep(self) -> None:
        sleeps: list[float] = []
        calls = {"n": 0}

        def pwsh(_timeout: float):
            calls["n"] += 1
            raise runner.RunnerError("boom")

        with self.assertRaises(runner.TransientCellError):
            runner._scan_terminal64_processes(
                toolhelp_scan=lambda: None,
                pwsh_scan=pwsh,
                sleeper=sleeps.append,
                retry_budget=0,
            )
        self.assertEqual(calls["n"], 1)
        self.assertEqual(sleeps, [])


if __name__ == "__main__":
    unittest.main()
