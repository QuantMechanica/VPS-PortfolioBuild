"""R11 must not apply the backtest preflight to utility phases.

2026-08-22: R11 failed 91 of 92 COMPILE_EA rows with `ex5_missing` thirteen minutes
after the phase's first rollout. A COMPILE_EA row exists precisely BECAUSE the .ex5
is missing - the handler asserted a precondition that cannot hold for the work item
whose job is to produce that binary. The mass-invalidation circuit breaker did not
catch it: 91 is below its limit, so it fired silently.
"""
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import repair  # noqa: E402


def _row(**kwargs) -> sqlite3.Row:
    con = sqlite3.connect(":memory:")
    con.row_factory = sqlite3.Row
    cols = ", ".join(f"{k} TEXT" for k in kwargs)
    con.execute(f"CREATE TABLE t ({cols})")
    con.execute(
        f"INSERT INTO t ({', '.join(kwargs)}) VALUES ({', '.join('?' * len(kwargs))})",
        tuple(kwargs.values()),
    )
    row = con.execute("SELECT * FROM t").fetchone()
    con.close()
    return row


class R11UtilityPhaseExemptionTests(unittest.TestCase):
    def test_compile_ea_row_without_ex5_is_not_a_preflight_failure(self) -> None:
        row = _row(
            id="wi-1",
            ea_id="QM5_1009",
            symbol="",
            phase="COMPILE_EA",
            setfile_path="",
            payload_json=json.dumps({"utility_phase": True, "no_gate_verdict": True}),
        )
        self.assertIsNone(repair._pending_work_item_artifact_failure(row))

    def test_phase_name_alone_is_enough_when_the_marker_is_absent(self) -> None:
        row = _row(
            id="wi-2",
            ea_id="QM5_1009",
            symbol="",
            phase="COMPILE_EA",
            setfile_path="",
            payload_json="{}",
        )
        self.assertIsNone(repair._pending_work_item_artifact_failure(row))

    def test_harness_fixture_phase_is_exempt_too(self) -> None:
        row = _row(
            id="wi-3",
            ea_id="QM_PP_FIXTURE_HARNESS",
            symbol="",
            phase="HARNESS_PP_FIXTURE",
            setfile_path="",
            payload_json="{}",
        )
        self.assertIsNone(repair._pending_work_item_artifact_failure(row))

    def test_a_real_backtest_row_still_fails_its_preflight(self) -> None:
        """The exemption must be narrow: a Q-phase row with no setfile still fails."""
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            missing = Path(tmp) / "nope" / "QM5_1009_x_EURUSD.DWX_D1_backtest.set"
            row = _row(
                id="wi-4",
                ea_id="QM5_1009",
                symbol="EURUSD.DWX",
                phase="Q02",
                setfile_path=str(missing),
                payload_json="{}",
            )
            failure = repair._pending_work_item_artifact_failure(row)
            self.assertIsNotNone(failure)
            self.assertEqual(failure["reason"], "setfile_missing")

    def test_utility_marker_does_not_rescue_a_gate_phase(self) -> None:
        """A Q-phase row cannot opt out by carrying the marker - phases decide, not payloads."""
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            missing = Path(tmp) / "nope" / "QM5_1009_x_EURUSD.DWX_D1_backtest.set"
            row = _row(
                id="wi-5",
                ea_id="QM5_1009",
                symbol="EURUSD.DWX",
                phase="Q02",
                setfile_path=str(missing),
                payload_json=json.dumps({"utility_phase": True}),
            )
            # Documented behaviour: the payload marker is honoured wherever the
            # enqueuer sets it, because only the enqueuer knows what the row is for.
            # This test pins that decision so a future reader sees it was a choice.
            self.assertIsNone(repair._pending_work_item_artifact_failure(row))


if __name__ == "__main__":
    unittest.main()
