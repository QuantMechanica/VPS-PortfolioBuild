import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _access_denied() -> OSError:
    exc = OSError("Access is denied")
    exc.winerror = 5
    return exc


class TerminalReservationReplaceRetryTests(unittest.TestCase):
    """Regression for the 2026-08-24 Q10_NEWS mass-transient-failure incident:
    Path.replace(terminal_reservations.json) transiently raised WinError 5 under
    concurrency and aborted run_smoke.ps1's admission gate before the tester ever
    launched, sinking 13 work items to REVIEW_REQUIRED with zero authenticated cells.
    """

    def test_replace_retries_past_transient_winerror5_then_succeeds(self) -> None:
        with TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            path = root / farmctl.TERMINAL_RESERVATIONS_REL
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"reservations": {}}\n', encoding="utf-8")
            tmp = path.with_suffix(path.suffix + ".9999.tmp")
            tmp.write_text('{"reservations": {"T5": {}}}\n', encoding="utf-8")

            attempts = {"count": 0}
            real_replace = Path.replace

            def flaky_replace(self, target):
                attempts["count"] += 1
                if attempts["count"] < 3:
                    raise _access_denied()
                return real_replace(self, target)

            orig_sleep = farmctl.time.sleep
            farmctl.time.sleep = lambda _seconds: None
            try:
                import unittest.mock as mock

                with mock.patch.object(Path, "replace", flaky_replace):
                    farmctl._replace_reservation_file(tmp, path)
            finally:
                farmctl.time.sleep = orig_sleep

            self.assertEqual(attempts["count"], 3)
            self.assertIn('"T5"', path.read_text(encoding="utf-8"))

    def test_replace_raises_after_exhausting_retry_budget(self) -> None:
        with TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            path = root / farmctl.TERMINAL_RESERVATIONS_REL
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('{"reservations": {}}\n', encoding="utf-8")
            tmp = path.with_suffix(path.suffix + ".9998.tmp")
            tmp.write_text('{"reservations": {}}\n', encoding="utf-8")

            def always_denied(self, target):
                raise _access_denied()

            orig_sleep = farmctl.time.sleep
            farmctl.time.sleep = lambda _seconds: None
            try:
                import unittest.mock as mock

                with mock.patch.object(Path, "replace", always_denied):
                    with self.assertRaises(OSError):
                        farmctl._replace_reservation_file(tmp, path)
            finally:
                farmctl.time.sleep = orig_sleep

    def test_non_transient_oserror_propagates_immediately(self) -> None:
        with TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            path = root / farmctl.TERMINAL_RESERVATIONS_REL
            path.parent.mkdir(parents=True, exist_ok=True)
            tmp = path.with_suffix(path.suffix + ".9997.tmp")
            tmp.write_text('{"reservations": {}}\n', encoding="utf-8")

            calls = {"count": 0}

            def not_found(self, target):
                calls["count"] += 1
                exc = OSError("The system cannot find the file specified")
                exc.winerror = 2
                raise exc

            import unittest.mock as mock

            with mock.patch.object(Path, "replace", not_found):
                with self.assertRaises(OSError):
                    farmctl._replace_reservation_file(tmp, path)
            self.assertEqual(calls["count"], 1)

    def test_set_terminal_reservation_survives_transient_replace_failure(self) -> None:
        with TemporaryDirectory() as tmp_dir:
            root = Path(tmp_dir)
            attempts = {"count": 0}
            real_replace = Path.replace

            def flaky_replace(self, target):
                attempts["count"] += 1
                if attempts["count"] < 2:
                    raise _access_denied()
                return real_replace(self, target)

            orig_sleep = farmctl.time.sleep
            farmctl.time.sleep = lambda _seconds: None
            try:
                import unittest.mock as mock

                with mock.patch.object(Path, "replace", flaky_replace):
                    reservation = farmctl.set_terminal_reservation(
                        root, "T5", reserved_by="test-runner", minutes=30, reason="unit-test"
                    )
            finally:
                farmctl.time.sleep = orig_sleep

            self.assertEqual(reservation["terminal"], "T5")
            self.assertGreaterEqual(attempts["count"], 2)
            live = farmctl.terminal_reservations(root)
            self.assertIn("T5", live)


if __name__ == "__main__":
    unittest.main()
