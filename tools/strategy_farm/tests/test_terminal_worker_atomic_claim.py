import json
import sqlite3
import sys
import tempfile
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


class TerminalWorkerAtomicClaimTests(unittest.TestCase):
    def _root(self) -> tempfile.TemporaryDirectory:
        return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)

    def _insert_work_item(
        self,
        root: Path,
        item_id: str,
        symbol: str,
        *,
        phase: str = "P2",
        status: str = "pending",
        claimed_by: str | None = None,
        payload: dict[str, object] | None = None,
    ) -> None:
        farmctl.init_db(root)
        now = farmctl.utc_now()
        with sqlite3.connect(root / farmctl.DB_REL) as conn:
            conn.execute(
                """
                INSERT INTO work_items
                  (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                   attempt_count, parent_task_id, evidence_path, claimed_by,
                   payload_json, created_at, updated_at)
                VALUES
                  (?, 'backtest', ?, 'QM5_9999', ?, 'dummy.set', ?, NULL,
                   0, NULL, NULL, ?, ?, ?, ?)
                """,
                (item_id, phase, symbol, status, claimed_by, json.dumps(payload or {}), now, now),
            )
            conn.commit()

    def test_two_workers_race_claim_same_work_item_only_one_wins(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "wi-1", "EURUSD.DWX", phase="P3")

            with ThreadPoolExecutor(max_workers=2) as executor:
                results = list(executor.map(lambda t: terminal_worker.claim_atomic(root, t), ["T1", "T2"]))

            claimed = [r for r in results if r.get("claimed")]
            self.assertEqual(len(claimed), 1)
            self.assertEqual(claimed[0]["item"]["id"], "wi-1")

            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                rows = conn.execute("SELECT status, claimed_by FROM work_items WHERE id='wi-1'").fetchall()
            self.assertEqual(rows[0][0], "active")
            self.assertIn(rows[0][1], {"T1", "T2"})

    def test_per_symbol_lock_is_respected(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "active-1", "NDX.DWX", phase="P3", status="active", claimed_by="T1")
            self._insert_work_item(root, "pending-1", "NDX.DWX", phase="P3")
            self._insert_work_item(root, "pending-2", "SP500.DWX", phase="P3")

            result = terminal_worker.claim_atomic(root, "T2")

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "pending-2")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                statuses = dict(conn.execute("SELECT id, status FROM work_items").fetchall())
            self.assertEqual(statuses["pending-1"], "pending")
            self.assertEqual(statuses["pending-2"], "active")

    def test_dwx_history_range_registry_is_respected_for_p2_claims(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(root, "wi-no-history", "UNKNOWN.DWX", payload={"period": "D1"})

            old_window = terminal_worker.farmctl._p2_history_window_for_symbol
            try:
                terminal_worker.farmctl._p2_history_window_for_symbol = lambda *args, **kwargs: {
                    "skip": True,
                    "reason": farmctl.P2_SYMBOL_NO_HISTORY_REASON,
                    "symbol": "UNKNOWN.DWX",
                    "period": "D1",
                }
                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                terminal_worker.farmctl._p2_history_window_for_symbol = old_window

            self.assertFalse(result.get("claimed"))
            self.assertEqual(result.get("reason"), "no_pending_claimable")
            self.assertEqual(result["history_skipped"][0]["item_id"], "wi-no-history")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                status = conn.execute("SELECT status FROM work_items WHERE id='wi-no-history'").fetchone()[0]
            self.assertEqual(status, "pending")

    def test_stale_same_terminal_claim_is_released_before_next_claim(self) -> None:
        with self._root() as tmp:
            root = Path(tmp) / "farm"
            self._insert_work_item(
                root,
                "stale-1",
                "EURUSD.DWX",
                phase="P3",
                status="active",
                claimed_by="T1",
                payload={"pid": 999999999},
            )

            old_pid_exists = terminal_worker.farmctl._pid_exists
            try:
                terminal_worker.farmctl._pid_exists = lambda _pid: False
                result = terminal_worker.claim_atomic(root, "T1")
            finally:
                terminal_worker.farmctl._pid_exists = old_pid_exists

            self.assertTrue(result.get("claimed"))
            self.assertEqual(result["item"]["id"], "stale-1")
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute("SELECT status, claimed_by FROM work_items WHERE id='stale-1'").fetchone()
            self.assertEqual(row, ("active", "T1"))

    def test_summary_missing_release_stops_terminal_slot(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            report_root = root / "reports" / "wi-summary-missing"
            report_root.mkdir(parents=True)
            self._insert_work_item(
                root,
                "wi-summary-missing",
                "AUDUSD.DWX",
                phase="P2",
                status="active",
                claimed_by="T4",
                payload={"report_root": str(report_root), "pid": 424242},
            )

            stopped: list[str] = []
            old_default_root = terminal_worker.farmctl.DEFAULT_ROOT
            old_stop_terminal_slot = terminal_worker.farmctl._stop_terminal_slot
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker.farmctl._stop_terminal_slot = lambda terminal: stopped.append(terminal) or True
                result = terminal_worker._finish_work_item(root, "wi-summary-missing", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default_root
                terminal_worker.farmctl._stop_terminal_slot = old_stop_terminal_slot

            self.assertEqual(result["status"], "pending")
            self.assertEqual(stopped, ["T4"])
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, claimed_by, payload_json FROM work_items WHERE id='wi-summary-missing'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            payload = json.loads(row[2])
            self.assertEqual(payload["prior_failure"], "summary_missing")
            self.assertTrue(payload["terminal_stopped_on_release"])

    def test_run_claimed_item_stops_child_when_claim_is_externally_released(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            self._insert_work_item(
                root,
                "wi-external-release",
                "CADCHF.DWX",
                phase="P2",
                status="active",
                claimed_by="T5",
                payload={},
            )

            stopped_children: list[int] = []
            stopped_terminals: list[str] = []
            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            old_pid_exists = terminal_worker.farmctl._pid_exists
            old_stop_pid_tree = terminal_worker.farmctl._stop_pid_tree
            old_default_root = terminal_worker.farmctl.DEFAULT_ROOT
            old_stop_terminal_slot = terminal_worker.farmctl._stop_terminal_slot
            old_preflight = terminal_worker._work_item_preflight_failure

            def fake_pid_exists(_pid: int) -> bool:
                with sqlite3.connect(root / farmctl.DB_REL) as conn:
                    conn.execute(
                        "UPDATE work_items SET status='pending', claimed_by=NULL WHERE id='wi-external-release'"
                    )
                    conn.commit()
                return True

            try:
                terminal_worker.farmctl._spawn_work_item_runner = lambda _root, _row, _terminal: {
                    "spawned": True,
                    "pid": 123456,
                    "log_path": str(root / "runner.log"),
                    "report_root": str(root / "reports"),
                    "ea_dir_name": "QM5_9999",
                    "expected_trades_per_year_per_symbol": 10,
                    "smoke_year_count": 6,
                    "effective_min_trades": 5,
                    "phase_runner": "run_smoke.ps1",
                }
                terminal_worker.farmctl._pid_exists = fake_pid_exists
                terminal_worker.farmctl._stop_pid_tree = lambda pid: stopped_children.append(int(pid)) or True
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker.farmctl._stop_terminal_slot = lambda terminal: stopped_terminals.append(terminal) or True
                terminal_worker._work_item_preflight_failure = lambda _row: None

                result = terminal_worker._run_claimed_item(
                    root,
                    {"id": "wi-external-release"},
                    "T5",
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn
                terminal_worker.farmctl._pid_exists = old_pid_exists
                terminal_worker.farmctl._stop_pid_tree = old_stop_pid_tree
                terminal_worker.farmctl.DEFAULT_ROOT = old_default_root
                terminal_worker.farmctl._stop_terminal_slot = old_stop_terminal_slot
                terminal_worker._work_item_preflight_failure = old_preflight

            self.assertEqual(result["action"], "external_release_observed")
            self.assertEqual(result["reason"], "status_changed")
            self.assertEqual(stopped_children, [123456])
            self.assertEqual(stopped_terminals, ["T5"])

    def test_run_claimed_item_preflight_blocks_missing_ex5_without_spawn(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            repo = Path(tmp) / "repo"
            ea_dir = repo / "framework" / "EAs" / "QM5_9999_missing-ex5"
            sets = ea_dir / "sets"
            sets.mkdir(parents=True)
            setfile = sets / "QM5_9999_missing-ex5_EURUSD.DWX_H1_backtest.set"
            setfile.write_text("Symbol=EURUSD.DWX\n", encoding="utf-8")
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                conn.execute(
                    """
                    INSERT INTO work_items
                      (id, kind, phase, ea_id, symbol, setfile_path, status, verdict,
                       attempt_count, parent_task_id, evidence_path, claimed_by,
                       payload_json, created_at, updated_at)
                    VALUES
                      ('wi-missing-ex5', 'backtest', 'P2', 'QM5_9999', 'EURUSD.DWX', ?,
                       'active', NULL, 0, NULL, NULL, 'T1', '{}', ?, ?)
                    """,
                    (str(setfile), now, now),
                )
                conn.commit()

            old_repo_root = terminal_worker.farmctl.REPO_ROOT
            old_spawn = terminal_worker.farmctl._spawn_work_item_runner
            try:
                terminal_worker.farmctl.REPO_ROOT = repo
                terminal_worker.farmctl._spawn_work_item_runner = lambda *_args, **_kwargs: (_ for _ in ()).throw(
                    AssertionError("spawn must not be called")
                )
                result = terminal_worker._run_claimed_item(
                    root,
                    {"id": "wi-missing-ex5"},
                    "T1",
                    timeout_seconds=30,
                )
            finally:
                terminal_worker.farmctl.REPO_ROOT = old_repo_root
                terminal_worker.farmctl._spawn_work_item_runner = old_spawn

            self.assertEqual(result["action"], "preflight_failed")
            self.assertEqual(result["reason"], "ex5_missing")
            self.assertTrue(Path(result["evidence_path"]).exists())
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, evidence_path, payload_json FROM work_items WHERE id='wi-missing-ex5'"
                ).fetchone()
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "INVALID")
            self.assertIsNone(row[2])
            self.assertTrue(Path(row[3]).exists())
            self.assertEqual(json.loads(row[4])["verdict_reason"], "ex5_missing")


if __name__ == "__main__":
    unittest.main()
