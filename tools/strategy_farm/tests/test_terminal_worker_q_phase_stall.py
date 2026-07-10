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
    def test_run_smoke_q_phase_aliases_detect_stale_terminal_exit(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            report_root = root / "report"
            report_root.mkdir()
            log_path = root / "worker.log"
            log_path.write_text(
                "run_smoke.stage=terminal_start\n"
                "run_smoke.stage=terminal_exit\n",
                encoding="utf-8",
            )
            stale_at = (
                time.time()
                - terminal_worker.SMOKE_TERMINAL_EXIT_GRACE_SECONDS
                - 1
            )
            os.utime(log_path, (stale_at, stale_at))
            payload = {
                "log_path": str(log_path),
                "report_root": str(report_root),
            }

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


if __name__ == "__main__":
    unittest.main()
