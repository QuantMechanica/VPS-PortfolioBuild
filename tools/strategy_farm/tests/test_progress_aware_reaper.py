import datetime as dt
import json
import os
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
    def _active(
        self,
        root: Path,
        *,
        item_id: str,
        age_min: int,
        timeout_seconds: int = 7200,
        phase: str = "Q02",
        report_root: Path | None = None,
    ):
        farmctl.init_db(root)
        updated = self.now - dt.timedelta(minutes=age_min)
        payload = {"pid": None, "timeout_seconds": timeout_seconds}
        if report_root is not None:
            payload["report_root"] = str(report_root)
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, claimed_by, payload_json, created_at, updated_at)
                VALUES (?, 'backtest', ?, 'QM5_1', 'EURUSD.DWX', 'x.set',
                        'active', NULL, 0, 'T1', ?, ?, ?)
                """,
                (
                    item_id,
                    phase,
                    json.dumps(payload),
                    updated.isoformat(),
                    updated.isoformat(),
                ),
            )

    def _log(self, root: Path, item_id: str, entries: list[tuple[str, int]]):
        path = root / "T1" / "logs" / self.now.astimezone().strftime("%Y%m%d.log")
        path.parent.mkdir(parents=True)
        lines = [f"AA 0 18:00:00.000 Terminal launched with D:\\\\reports\\\\{item_id}\\\\tester.ini"]
        lines.extend(f"AA 0 {clock} AutoTesting processing {pct} %" for clock, pct in entries)
        path.write_text("\n".join(lines), encoding="utf-16")

    def _session_log(self, root: Path, item_id: str, clocks: list[str]):
        path = root / "T1" / "logs" / self.now.astimezone().strftime("%Y%m%d.log")
        path.parent.mkdir(parents=True)
        lines = [
            f"AA 0 {clock} Startup launched with D:\\\\reports\\\\{item_id}\\\\seed_{index}\\\\tester.ini"
            for index, clock in enumerate(clocks, start=1)
        ]
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

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_healthy_multisession_phase_runner_survives_past_stall_window(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._active(root, item_id="multi", age_min=45, phase="Q07")
            recent = (self.now.astimezone() - dt.timedelta(minutes=5)).strftime(
                "%H:%M:%S.000"
            )
            self._session_log(root, "multi", ["18:20:00.000", recent])
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
                status = conn.execute(
                    "SELECT status FROM work_items WHERE id='multi'"
                ).fetchone()[0]
            self.assertEqual(flagged, [])
            self.assertEqual(status, "active")

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_phase_runner_report_root_growth_counts_as_progress(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports" / "work_items" / "artifact"
            session_dir = report_root / "QM5_1" / "20260803_185500"
            session_dir.mkdir(parents=True)
            tester_ini = session_dir / "tester.ini"
            tester_ini.write_text("running", encoding="utf-8")
            recent_epoch = (self.now - dt.timedelta(minutes=5)).timestamp()
            os.utime(session_dir, (recent_epoch, recent_epoch))
            os.utime(tester_ini, (recent_epoch, recent_epoch))
            self._active(
                root,
                item_id="artifact",
                age_min=45,
                phase="Q07",
                report_root=report_root,
            )
            old = (self.now.astimezone() - dt.timedelta(minutes=30)).strftime(
                "%H:%M:%S.000"
            )
            self._session_log(root, "artifact", [old])
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
            self.assertEqual(flagged, [])

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_hung_multisession_phase_runner_is_still_reaped(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            self._active(root, item_id="multi_hung", age_min=45, phase="Q07")
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
            self.assertEqual(flagged[0]["reap_reason"], "NO_FORWARD_PROGRESS")
            evidence = flagged[0]["progress_evidence"]
            self.assertEqual(evidence["progress_contract"], "phase_runner_multisession_v1")
            self.assertEqual(evidence["reason"], "phase_runner_no_activity_since_claim")
            self.assertGreaterEqual(evidence["stalled_min"], 20)

    @mock.patch.object(farmctl, "_stop_pid", return_value=False)
    @mock.patch.object(farmctl, "_stop_terminal_slot", return_value=False)
    def test_single_session_phase_does_not_use_phase_runner_report_growth(self, *_):
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            report_root = root / "reports" / "work_items" / "single"
            session_dir = report_root / "QM5_1" / "20260803_185500"
            session_dir.mkdir(parents=True)
            tester_ini = session_dir / "tester.ini"
            tester_ini.write_text("running", encoding="utf-8")
            recent_epoch = (self.now - dt.timedelta(minutes=5)).timestamp()
            os.utime(session_dir, (recent_epoch, recent_epoch))
            os.utime(tester_ini, (recent_epoch, recent_epoch))
            self._active(
                root,
                item_id="single",
                age_min=45,
                phase="Q02",
                report_root=report_root,
            )
            old = (self.now.astimezone() - dt.timedelta(minutes=25)).strftime(
                "%H:%M:%S.000"
            )
            self._log(root, "single", [(old, 17)])
            with farmctl.connect(root) as conn:
                flagged = farmctl._detect_active_age_timeout(
                    conn, now_dt=self.now, mt5_root=root
                )
            self.assertEqual(flagged[0]["reap_reason"], "NO_FORWARD_PROGRESS")
            self.assertNotIn("progress_contract", flagged[0]["progress_evidence"])


if __name__ == "__main__":
    unittest.main()
