"""Reservation decay against measured usage (2026-07-26).

Regression cover for the starvation incident: holding a multisymbol job's full
44GB peak reservation for its whole balloon window double-counted memory the OS
commit measurement already reported, pushed effective headroom below the
admission threshold on a box with 64GB free, and pinned the entire worker fleet
(reverted in 347859ad3). The reservation must decay against what the job has
actually allocated.
"""

import json
import sqlite3
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


class CommitReservationDecayTests(unittest.TestCase):
    def setUp(self) -> None:
        self._orig_headroom = terminal_worker._commit_headroom_gb
        self._orig_measure = terminal_worker._measured_subtree_gb
        terminal_worker._commit_headroom_gb = lambda: 64.5

    def tearDown(self) -> None:
        terminal_worker._commit_headroom_gb = self._orig_headroom
        terminal_worker._measured_subtree_gb = self._orig_measure

    def _conn_with_active(self, payload: dict, ea_id: str = "QM5_13059"):
        tmp = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name) / "farm"
        farmctl.init_db(root)
        now = farmctl.utc_now()
        conn = sqlite3.connect(root / farmctl.DB_REL)
        conn.row_factory = sqlite3.Row
        conn.execute(
            """
            INSERT INTO work_items
              (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
               attempt_count, parent_task_id, evidence_path, claimed_by,
               payload_json, created_at, updated_at)
            VALUES (?, 'backtest', 'Q08', ?, 'SYMX', 'x.set', 'active', NULL,
                    0, NULL, NULL, 'T3', ?, ?, ?)
            """,
            ("wi-multisym", ea_id, json.dumps(payload), now, now),
        )
        conn.commit()
        self.addCleanup(conn.close)
        return conn, now

    def _payload(
        self,
        *,
        peak_gb: float,
        age_seconds: int,
        pid: int | None = 4242,
        multisymbol: bool = True,
    ) -> dict:
        """Build a claim payload through the real stamping function.

        Using ``_set_commit_reservation`` keeps the per-lineage window choice
        under test instead of hard-coding it in the fixture.
        """
        claimed = datetime.now(timezone.utc) - timedelta(seconds=age_seconds)
        payload: dict = {"claimed_at_iso": claimed.isoformat()}
        terminal_worker._set_commit_reservation(
            payload, claimed_at_iso=claimed.isoformat(), multisymbol=multisymbol
        )
        self.assertAlmostEqual(payload["commit_reservation_gb"], peak_gb, places=2)
        if pid is not None:
            payload["pid"] = pid
        return payload

    def _snapshot(self, conn, now):
        return terminal_worker._commit_admission_snapshot(
            conn, now, frozenset({"13059"})
        )

    def test_unspawned_job_reserves_its_full_peak(self):
        """No pid yet: the launch race is exactly what the reservation guards."""
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=30, pid=None))
        snap = self._snapshot(conn, now)
        self.assertAlmostEqual(snap["reserved_gb"], 44.0, places=2)
        self.assertEqual(snap["reservations"][0]["measured_gb"], None)

    def test_reservation_decays_by_measured_usage(self):
        """26GB already allocated -> only the unmaterialized 18GB stays reserved."""
        terminal_worker._measured_subtree_gb = lambda pid: 26.0
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=600))
        snap = self._snapshot(conn, now)
        self.assertAlmostEqual(snap["reserved_gb"], 18.0, places=2)
        self.assertAlmostEqual(snap["reservations"][0]["measured_gb"], 26.0, places=2)

    def test_job_at_or_above_peak_reserves_nothing(self):
        """This is the incident: the OS measurement already covers it."""
        terminal_worker._measured_subtree_gb = lambda pid: 47.0
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=1200))
        snap = self._snapshot(conn, now)
        self.assertEqual(snap["reserved_gb"], 0.0)
        # 64.5GB of real headroom must stay fully available to the fleet.
        self.assertAlmostEqual(snap["effective_headroom_gb"], 64.5, places=2)
        self.assertGreater(
            snap["effective_headroom_gb"], terminal_worker.COMMIT_MIN_FREE_GB
        )

    def test_unmeasurable_job_keeps_full_reservation(self):
        """Probe failure must stay conservative, never assume zero usage."""
        terminal_worker._measured_subtree_gb = lambda pid: None
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=600))
        snap = self._snapshot(conn, now)
        self.assertAlmostEqual(snap["reserved_gb"], 44.0, places=2)

    def test_vanished_process_tree_releases_the_reservation(self):
        """Lineage gone -> no future growth to reserve for."""
        terminal_worker._measured_subtree_gb = lambda pid: float("inf")
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=600))
        snap = self._snapshot(conn, now)
        self.assertEqual(snap["reserved_gb"], 0.0)
        self.assertIsNone(snap["reservations"][0]["measured_gb"])

    def test_multisym_window_outlives_the_ordinary_one(self):
        """A 40-minute-old multisym claim is still inside its window..."""
        terminal_worker._measured_subtree_gb = lambda pid: 5.0
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=2400))
        snap = self._snapshot(conn, now)
        self.assertEqual(len(snap["reservations"]), 1)
        self.assertAlmostEqual(snap["reserved_gb"], 39.0, places=2)

    def test_expired_window_drops_the_reservation_entirely(self):
        terminal_worker._measured_subtree_gb = lambda pid: 5.0
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=4000))
        snap = self._snapshot(conn, now)
        self.assertEqual(snap["reservations"], [])
        self.assertEqual(snap["reserved_gb"], 0.0)

    def test_ordinary_job_window_is_unchanged_at_300s(self):
        """Non-multisym lineage must keep its original short window."""
        terminal_worker._measured_subtree_gb = lambda pid: 1.0
        conn, now = self._conn_with_active(
            self._payload(peak_gb=8.0, age_seconds=400, multisymbol=False),
            ea_id="QM5_10150",
        )
        snap = self._snapshot(conn, now)
        self.assertEqual(snap["reservations"], [])

    def test_ordinary_job_inside_its_window_still_decays(self):
        terminal_worker._measured_subtree_gb = lambda pid: 3.0
        conn, now = self._conn_with_active(
            self._payload(peak_gb=8.0, age_seconds=60, multisymbol=False),
            ea_id="QM5_10150",
        )
        snap = self._snapshot(conn, now)
        self.assertAlmostEqual(snap["reserved_gb"], 5.0, places=2)

    def test_fleet_is_not_starved_while_a_grown_multisym_runs(self):
        """End-to-end shape of the incident, asserted on the admission verdict."""
        terminal_worker._measured_subtree_gb = lambda pid: 26.4
        conn, now = self._conn_with_active(self._payload(peak_gb=44.0, age_seconds=900))
        snap = self._snapshot(conn, now)
        # Pre-fix arithmetic would have been 64.5 - 44.0 = 20.5 -> below 24 -> fleet pinned.
        self.assertAlmostEqual(snap["reserved_gb"], 17.6, places=2)
        self.assertAlmostEqual(snap["effective_headroom_gb"], 46.9, places=2)
        self.assertGreater(
            snap["effective_headroom_gb"], terminal_worker.COMMIT_MIN_FREE_GB
        )


class MeasuredSubtreeTests(unittest.TestCase):
    def test_garbage_pid_is_unknown_not_zero(self):
        self.assertIsNone(terminal_worker._measured_subtree_gb("not-a-pid"))
        self.assertIsNone(terminal_worker._measured_subtree_gb(None))

    @unittest.skipUnless(sys.platform == "win32", "ctypes probe is Windows-only")
    def test_own_process_tree_is_measurable(self):
        import os

        measured = terminal_worker._measured_subtree_gb(os.getpid())
        self.assertIsNotNone(measured)
        self.assertNotEqual(measured, float("inf"))
        self.assertGreater(measured, 0.0)

    @unittest.skipUnless(sys.platform == "win32", "ctypes probe is Windows-only")
    def test_dead_pid_reports_gone(self):
        self.assertEqual(terminal_worker._measured_subtree_gb(999_999), float("inf"))


if __name__ == "__main__":
    unittest.main()
