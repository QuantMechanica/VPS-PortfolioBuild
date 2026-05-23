import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl, ws0_notifier


class WS0NotifierTests(unittest.TestCase):
    def _insert_work_item(self, root: Path, *, verdict: str, updated_at: str, phase: str = "P2") -> None:
        with farmctl.connect(root) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   payload_json, created_at, updated_at)
                VALUES
                  ('wi-ws0', 'backtest', ?, 'QM5_9999', 'EURUSD.DWX', 'dummy.set',
                   'done', ?, '{}', ?, ?)
                """,
                (phase, verdict, updated_at, updated_at),
            )

    def test_sends_once_and_disarms_on_first_real_p2_verdict(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            self._insert_work_item(root, verdict="PASS", updated_at="2026-05-22T07:42:00+00:00")
            sent: list[tuple[str, str]] = []

            first = ws0_notifier.check_and_notify(
                root,
                send_mail=lambda subject, body: sent.append((subject, body)) or {"sent": True},
            )
            second = ws0_notifier.check_and_notify(
                root,
                send_mail=lambda subject, body: sent.append((subject, body)) or {"sent": True},
            )

            self.assertTrue(first["triggered"])
            self.assertEqual(first["work_item"]["ea_id"], "QM5_9999")
            self.assertEqual(len(sent), 1)
            self.assertEqual(sent[0][0], "WS-0 cleared")
            self.assertIn("Verdict: PASS", sent[0][1])
            self.assertFalse(second["triggered"])
            self.assertEqual(second["reason"], "already_disarmed")
            self.assertTrue((root / ws0_notifier.SENTINEL_REL).exists())

    def test_ignores_invalid_and_timeout_verdicts(self) -> None:
        for verdict in ("INVALID", "timeout", "PENDING_RUNNER"):
            with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
                root = Path(tmp)
                farmctl.init_db(root)
                self._insert_work_item(root, verdict=verdict, updated_at="2026-05-22T07:42:00+00:00")

                result = ws0_notifier.check_and_notify(
                    root,
                    send_mail=lambda subject, body: {"sent": True},
                )

                self.assertFalse(result["triggered"])
                self.assertEqual(result["reason"], "no_real_ws0_verdict_after_cutoff")
                self.assertFalse((root / ws0_notifier.SENTINEL_REL).exists())


if __name__ == "__main__":
    unittest.main()
