import datetime as dt
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


class ProgressAwareReaperTests(unittest.TestCase):
    def _active(self, root: Path, *, item_id: str, age_min: int, timeout_seconds: int = 7200):
        farmctl.init_db(root)
        updated = self.now - dt.timedelta(minutes=age_min)
        payload = {"pid": None, "timeout_seconds": timeout_seconds}
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, claimed_by, payload_json, created_at, updated_at)
                VALUES (?, 'backtest', 'Q02', 'QM5_1', 'EURUSD.DWX', 'x.set',
                        'active', NULL, 0, 'T1', ?, ?, ?)
                """,
                (item_id, json.dumps(payload), updated.isoformat(), updated.isoformat()),
            )

    def _log(self, root: Path, item_id: str, entries: list[tuple[str, int]]):
        path = root / "T1" / "logs" / self.now.astimezone().strftime("%Y%m%d.log")
        path.parent.mkdir(parents=True)
        lines = [f"AA 0 18:00:00.000 Terminal launched with D:\\\\reports\\\\{item_id}\\\\tester.ini"]
        lines.extend(f"AA 0 {clock} AutoTesting processing {pct} %" for clock, pct in entries)
        path.write_text("\n".join(lines), encoding="utf-16")

    def setUp(self):
        self.now = dt.datetime.now().astimezone().replace(
            hour=19, minute=0, second=0, microsecond=0
        ).astimezone(dt.UTC)

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_recent_forward_progress_survives_old_fixed_ceiling(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._active(root, item_id="working", age_min=70)
            local_recent = (self.now.astimezone() - dt.timedelta(minutes=5)).strftime("%H:%M:%S.000")
            self._log(root, "working", [(local_recent, 42)])
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
                status = conn.execute(
                    "SELECT status FROM work_items WHERE id='working'"
                ).fetchone()[0]
            self.assertEqual(flagged, [])
            self.assertEqual(status, "active")

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_bound_stalled_progress_is_reaped_with_evidence(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._active(root, item_id="stalled", age_min=35)
            local_old = (self.now.astimezone() - dt.timedelta(minutes=25)).strftime("%H:%M:%S.000")
            self._log(root, "stalled", [(local_old, 17)])
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
            self.assertEqual(flagged[0]["reap_reason"], "NO_FORWARD_PROGRESS")
            self.assertEqual(flagged[0]["progress_evidence"]["progress_pct"], 17)

    def test_missing_signal_fails_open_inside_inner_budget(self):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._active(root, item_id="unknown", age_min=70)
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
                status = conn.execute(
                    "SELECT status FROM work_items WHERE id='unknown'"
                ).fetchone()[0]
            self.assertEqual(flagged, [])
            self.assertEqual(status, "active")

    def test_outer_ceiling_is_looser_than_inner(self):
        value = farmctl._active_timeout_min_for_work_item(
            "Q02", json.dumps({"timeout_seconds": 7200})
        )
        self.assertGreater(value, 120)


if __name__ == "__main__":
    unittest.main()
