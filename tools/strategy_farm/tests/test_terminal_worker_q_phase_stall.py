import os
import sys
import tempfile
import time
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

import terminal_worker  # noqa: E402


class TerminalWorkerQPhaseStallTests(unittest.TestCase):
    def test_report_handoff_is_not_killed_at_old_sixty_second_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_root = root / "report"
            raw = report_root / "QM5_20007" / "run" / "raw" / "run_01"
            raw.mkdir(parents=True)
            (raw / "report.htm").write_bytes(b"complete report fixture")
            log_path = root / "worker.log"
            log_path.write_text(
                "run_smoke.stage=terminal_start\n"
                "run_smoke.stage=valid_report_latched bytes=931900\n"
                "run_smoke.stage=terminal_exit\n",
                encoding="utf-8",
            )
            payload = {
                "log_path": str(log_path),
                "report_root": str(report_root),
            }

            # This exact shape was previously killed at 60 seconds even though
            # run_smoke owns a 240-second post-exit report-publish contract.
            old_boundary = time.time() - 61
            os.utime(log_path, (old_boundary, old_boundary))
            self.assertFalse(
                terminal_worker._smoke_terminal_exit_stalled(
                    {"phase": "Q02"}, payload
                )
            )

            stale_at = time.time() - terminal_worker.SMOKE_TERMINAL_EXIT_GRACE_SECONDS - 1
            os.utime(log_path, (stale_at, stale_at))

            for phase in ("Q02", "Q03", "P2", "P3"):
                with self.subTest(phase=phase):
                    self.assertTrue(
                        terminal_worker._smoke_terminal_exit_stalled(
                            {"phase": phase}, payload
                        )
                    )

            self.assertFalse(
                terminal_worker._smoke_terminal_exit_stalled(
                    {"phase": "Q04"}, payload
                )
            )

    def test_published_summary_always_wins_over_stale_terminal_exit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_root = root / "report"
            summary = report_root / "QM5_20007" / "run" / "summary.json"
            summary.parent.mkdir(parents=True)
            summary.write_text("{}", encoding="utf-8")
            log_path = root / "worker.log"
            log_path.write_text(
                "run_smoke.stage=terminal_start\nrun_smoke.stage=terminal_exit\n",
                encoding="utf-8",
            )
            stale_at = time.time() - terminal_worker.SMOKE_TERMINAL_EXIT_GRACE_SECONDS - 1
            os.utime(log_path, (stale_at, stale_at))

            self.assertFalse(terminal_worker._smoke_terminal_exit_stalled(
                {"phase": "Q02"},
                {"log_path": str(log_path), "report_root": str(report_root)},
            ))


if __name__ == "__main__":
    unittest.main()
