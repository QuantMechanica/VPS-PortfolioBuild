"""Tests for the shared-bases history-lock STORM transient-retry class.

Diagnosis: docs/ops/evidence/2026-07-21_qm20004_infra_diagnosis.md. A finished —
often profitable — tester pass whose result is discarded because the shared raw-history
store was locked at conversion re-sync ("history synchronization error" / "some error
after pass finished ... 0:00:00.000") produces NO summary. That summary_missing case
auto-heals on a SEPARATE transient counter that steers off the sick terminal and does
NOT consume the strategy MAX_WORK_ITEM_RETRIES budget, capped so it never loops forever.
"""
import json
import sqlite3
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


def _insert_work_item(
    root: Path,
    item_id: str,
    symbol: str,
    *,
    phase: str = "Q02",
    status: str = "active",
    claimed_by: str | None = "T9",
    verdict: str | None = None,
    attempt_count: int = 0,
    payload: dict | None = None,
    ea_id: str = "QM5_9999",
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
              (?, 'backtest', ?, ?, ?, 'dummy.set', ?, ?, ?, NULL, NULL, ?, ?, ?, ?)
            """,
            (
                item_id,
                phase,
                ea_id,
                symbol,
                status,
                verdict,
                attempt_count,
                claimed_by,
                json.dumps(payload or {}),
                now,
                now,
            ),
        )
        conn.commit()


class HistoryLockStormTransientRetryTests(unittest.TestCase):
    def _root(self) -> tempfile.TemporaryDirectory:
        return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)

    # (a) storm signature auto-requeues, accumulates the sick terminal, and does NOT
    #     consume the strategy retry budget (attempt_count untouched).
    def test_storm_signature_requeues_transient_without_consuming_retry_budget(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            _insert_work_item(
                root,
                "wi-storm",
                "GDAXI.DWX",
                claimed_by="T9",
                attempt_count=2,  # near the 3-strike strategy budget
                payload={"priority_track": True, "pid": 424242, "log_path": "old.log"},
            )

            old_default = terminal_worker.farmctl.DEFAULT_ROOT
            old_find = terminal_worker._find_work_item_summary_data
            old_detect = terminal_worker._detect_history_lock_storm
            old_stop = terminal_worker._stop_terminal_slot_for_release
            old_active = terminal_worker.farmctl.active_mt5_terminals
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker._find_work_item_summary_data = lambda *_a, **_k: None
                terminal_worker._detect_history_lock_storm = lambda *_a, **_k: {
                    "terminal": "T9",
                    "token": "some error after pass finished",
                    "log_path": r"D:\QM\mt5\T9\logs\20260721.log",
                }
                terminal_worker._stop_terminal_slot_for_release = lambda *_a, **_k: True
                terminal_worker.farmctl.active_mt5_terminals = lambda *_a, **_k: (
                    "T1", "T2", "T3", "T4", "T5", "T6", "T7", "T8", "T9", "T10",
                )
                result = terminal_worker._finish_work_item(root, "wi-storm", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default
                terminal_worker._find_work_item_summary_data = old_find
                terminal_worker._detect_history_lock_storm = old_detect
                terminal_worker._stop_terminal_slot_for_release = old_stop
                terminal_worker.farmctl.active_mt5_terminals = old_active

            self.assertEqual(result["status"], "pending")
            self.assertIsNone(result["verdict"])
            self.assertTrue(result["transient_infra"])
            self.assertEqual(result["transient_infra_attempts"], 1)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, claimed_by, attempt_count, payload_json "
                    "FROM work_items WHERE id='wi-storm'"
                ).fetchone()
            self.assertEqual(row[0], "pending")
            self.assertIsNone(row[1])
            self.assertIsNone(row[2])
            self.assertEqual(row[3], 2)  # strategy budget NOT consumed
            payload = json.loads(row[4])
            self.assertEqual(payload["transient_infra_attempts"], 1)
            self.assertEqual(payload["prior_failure"], "shared_bases_history_lock_storm")
            self.assertEqual(payload["avoid_terminals"], ["T9"])
            self.assertTrue(payload["priority_track"])  # preserved
            self.assertNotIn("pid", payload)  # stale runtime keys stripped
            self.assertNotIn("log_path", payload)
            self.assertGreater(
                datetime.fromisoformat(payload["launch_not_before_utc"]),
                datetime.now(timezone.utc),
            )

    # (a-cont) a second sick terminal accumulates into avoid_terminals.
    def test_storm_accumulates_multiple_terminals(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            _insert_work_item(
                root,
                "wi-storm2",
                "NDX.DWX",
                claimed_by="T4",
                attempt_count=0,
                payload={"transient_infra_attempts": 1, "avoid_terminals": ["T9"]},
            )

            old_default = terminal_worker.farmctl.DEFAULT_ROOT
            old_find = terminal_worker._find_work_item_summary_data
            old_detect = terminal_worker._detect_history_lock_storm
            old_stop = terminal_worker._stop_terminal_slot_for_release
            old_active = terminal_worker.farmctl.active_mt5_terminals
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker._find_work_item_summary_data = lambda *_a, **_k: None
                terminal_worker._detect_history_lock_storm = lambda *_a, **_k: {
                    "terminal": "T4", "token": "history synchronization error", "log_path": "x"}
                terminal_worker._stop_terminal_slot_for_release = lambda *_a, **_k: True
                terminal_worker.farmctl.active_mt5_terminals = lambda *_a, **_k: tuple(
                    f"T{i}" for i in range(1, 11))
                result = terminal_worker._finish_work_item(root, "wi-storm2", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default
                terminal_worker._find_work_item_summary_data = old_find
                terminal_worker._detect_history_lock_storm = old_detect
                terminal_worker._stop_terminal_slot_for_release = old_stop
                terminal_worker.farmctl.active_mt5_terminals = old_active

            self.assertEqual(result["transient_infra_attempts"], 2)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                payload = json.loads(
                    conn.execute("SELECT payload_json FROM work_items WHERE id='wi-storm2'").fetchone()[0]
                )
            self.assertEqual(payload["avoid_terminals"], ["T4", "T9"])

    # (b) a GENUINE strategy verdict (0-trade / fail) is classified from its real
    #     summary and is NEVER masked by the storm reclassification — even when the
    #     storm signature co-exists, the summary path wins because it is checked first.
    def test_genuine_zero_trade_summary_is_not_masked_as_transient(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            claim_time = datetime.now(timezone.utc)
            run_tag = (claim_time).strftime("%Y%m%d_%H%M%S")
            report_root = root / "reports" / "wi-zero"
            summary_path = report_root / "QM5_9999" / run_tag / "summary.json"
            summary_path.parent.mkdir(parents=True)
            summary_path.write_text(
                json.dumps({
                    "timestamp_utc": claim_time.isoformat(),
                    "run_tag": run_tag,
                    "result": "PASS",
                    "model4_log_marker_detected": True,
                    "min_trades_required": 5,
                    "runs": [{"total_trades": 0}],
                }),
                encoding="utf-8",
            )
            claim_iso = claim_time.isoformat().replace("+00:00", "Z")
            _insert_work_item(
                root,
                "wi-zero",
                "EURUSD.DWX",
                claimed_by="T9",
                payload={
                    "report_root": str(report_root),
                    "pid": 123456,
                    "claimed_at_iso": claim_iso,
                    "started_at_iso": claim_iso,
                },
            )

            old_default = terminal_worker.farmctl.DEFAULT_ROOT
            old_detect = terminal_worker._detect_history_lock_storm
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                # Even if a storm signature is present, a real summary must win.
                terminal_worker._detect_history_lock_storm = lambda *_a, **_k: {
                    "terminal": "T9", "token": "some error after pass finished", "log_path": "x"}
                result = terminal_worker._finish_work_item(root, "wi-zero", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default
                terminal_worker._detect_history_lock_storm = old_detect

            self.assertEqual(result["status"], "done")
            self.assertEqual(result["verdict"], "ZERO_TRADES")
            self.assertNotIn("transient_infra", result)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                payload = json.loads(
                    conn.execute("SELECT payload_json FROM work_items WHERE id='wi-zero'").fetchone()[0]
                )
            self.assertNotIn("transient_infra_attempts", payload)

    # (c) once the transient cap is exhausted, the item terminates into a real
    #     INFRA_FAIL for manual attention (never loops forever).
    def test_transient_cap_exhaustion_terminates_into_infra_fail(self) -> None:
        with self._root() as tmp:
            root = (Path(tmp) / "farm").resolve()
            _insert_work_item(
                root,
                "wi-cap",
                "GDAXI.DWX",
                claimed_by="T7",
                attempt_count=1,
                payload={"transient_infra_attempts": terminal_worker.TRANSIENT_INFRA_RETRY_CAP},
            )

            old_default = terminal_worker.farmctl.DEFAULT_ROOT
            old_find = terminal_worker._find_work_item_summary_data
            old_detect = terminal_worker._detect_history_lock_storm
            old_stop = terminal_worker._stop_terminal_slot_for_release
            old_active = terminal_worker.farmctl.active_mt5_terminals
            try:
                terminal_worker.farmctl.DEFAULT_ROOT = root
                terminal_worker._find_work_item_summary_data = lambda *_a, **_k: None
                terminal_worker._detect_history_lock_storm = lambda *_a, **_k: {
                    "terminal": "T7", "token": "some error after pass finished", "log_path": "x"}
                terminal_worker._stop_terminal_slot_for_release = lambda *_a, **_k: True
                terminal_worker.farmctl.active_mt5_terminals = lambda *_a, **_k: tuple(
                    f"T{i}" for i in range(1, 11))
                result = terminal_worker._finish_work_item(root, "wi-cap", exit_code=0)
            finally:
                terminal_worker.farmctl.DEFAULT_ROOT = old_default
                terminal_worker._find_work_item_summary_data = old_find
                terminal_worker._detect_history_lock_storm = old_detect
                terminal_worker._stop_terminal_slot_for_release = old_stop
                terminal_worker.farmctl.active_mt5_terminals = old_active

            self.assertEqual(result["status"], "failed")
            self.assertEqual(result["verdict"], "INFRA_FAIL")
            self.assertEqual(result["transient_infra_attempts"], terminal_worker.TRANSIENT_INFRA_RETRY_CAP + 1)
            with sqlite3.connect(root / farmctl.DB_REL) as conn:
                row = conn.execute(
                    "SELECT status, verdict, attempt_count, payload_json FROM work_items WHERE id='wi-cap'"
                ).fetchone()
            self.assertEqual(row[0], "failed")
            self.assertEqual(row[1], "INFRA_FAIL")
            self.assertEqual(row[2], 1)  # strategy budget still untouched
            payload = json.loads(row[3])
            self.assertEqual(
                payload["final_failure"], "shared_bases_history_lock_transient_cap_exhausted"
            )

    # (d) if avoiding the sick terminal would exclude EVERY enabled terminal, the
    #     avoid list is cleared so the item is not permanently unclaimable.
    def test_avoid_terminals_all_excluded_guard_clears_list(self) -> None:
        payload = {"avoid_terminals": ["T1", "T2"]}
        old_active = terminal_worker.farmctl.active_mt5_terminals
        try:
            terminal_worker.farmctl.active_mt5_terminals = lambda *_a, **_k: ("T1", "T2", "T3")
            result = terminal_worker._accumulate_avoid_terminal(payload, "T3")
        finally:
            terminal_worker.farmctl.active_mt5_terminals = old_active

        self.assertEqual(result, [])
        self.assertNotIn("avoid_terminals", payload)
        self.assertEqual(payload["avoid_terminals_cleared_reason"], "would_exclude_whole_fleet")

    def test_avoid_terminals_partial_exclusion_is_kept(self) -> None:
        payload: dict = {}
        old_active = terminal_worker.farmctl.active_mt5_terminals
        try:
            terminal_worker.farmctl.active_mt5_terminals = lambda *_a, **_k: tuple(
                f"T{i}" for i in range(1, 11))
            result = terminal_worker._accumulate_avoid_terminal(payload, "T9")
        finally:
            terminal_worker.farmctl.active_mt5_terminals = old_active
        self.assertEqual(result, ["T9"])
        self.assertEqual(payload["avoid_terminals"], ["T9"])
        self.assertNotIn("avoid_terminals_cleared_reason", payload)


class HistoryLockStormDetectionTests(unittest.TestCase):
    def _root(self) -> tempfile.TemporaryDirectory:
        return tempfile.TemporaryDirectory(ignore_cleanup_errors=True)

    def test_detects_token_in_utf16_terminal_log_tail(self) -> None:
        with self._root() as tmp:
            mt5_root = Path(tmp) / "mt5"
            logs = mt5_root / "T9" / "logs"
            logs.mkdir(parents=True)
            log = logs / "20260721.log"
            body = (
                "18:51:21 Tester OnTester result 1.58\r\n"
                "18:51:22 Tester last test passed with result "
                "\"some error after pass finished\" in 0:00:00.000\r\n"
            )
            log.write_bytes(body.encode("utf-16-le"))

            evidence = terminal_worker._detect_history_lock_storm("T9", mt5_root=mt5_root)
            self.assertIsNotNone(evidence)
            self.assertEqual(evidence["terminal"], "T9")
            self.assertEqual(evidence["token"], "some error after pass finished")

    def test_detects_sync_error_in_agent_log(self) -> None:
        with self._root() as tmp:
            mt5_root = Path(tmp) / "mt5"
            logs = mt5_root / "T4" / "Tester" / "Agent-127.0.0.1-3004" / "logs"
            logs.mkdir(parents=True)
            (logs / "20260721.log").write_bytes(
                "History NDX.DWX: history synchronization error [Not found]\r\n".encode("utf-8")
            )
            evidence = terminal_worker._detect_history_lock_storm("T4", mt5_root=mt5_root)
            self.assertIsNotNone(evidence)
            self.assertEqual(evidence["token"], "history synchronization error")

    def test_clean_log_is_not_a_storm(self) -> None:
        with self._root() as tmp:
            mt5_root = Path(tmp) / "mt5"
            logs = mt5_root / "T1" / "logs"
            logs.mkdir(parents=True)
            (logs / "20260721.log").write_bytes(
                "Tester final balance 101535 USD\r\nTester test passed\r\n".encode("utf-16-le")
            )
            self.assertIsNone(terminal_worker._detect_history_lock_storm("T1", mt5_root=mt5_root))

    def test_missing_terminal_dir_returns_none(self) -> None:
        with self._root() as tmp:
            mt5_root = Path(tmp) / "mt5"
            mt5_root.mkdir(parents=True)
            self.assertIsNone(terminal_worker._detect_history_lock_storm("T9", mt5_root=mt5_root))

    def test_backoff_is_exponential_and_capped(self) -> None:
        base = terminal_worker.TRANSIENT_INFRA_BACKOFF_BASE_SECONDS
        cap = terminal_worker.TRANSIENT_INFRA_BACKOFF_MAX_SECONDS
        self.assertEqual(terminal_worker._transient_infra_backoff_seconds(0), base)
        self.assertEqual(terminal_worker._transient_infra_backoff_seconds(1), base * 2)
        self.assertEqual(terminal_worker._transient_infra_backoff_seconds(3), base * 8)
        self.assertEqual(terminal_worker._transient_infra_backoff_seconds(99), cap)
        self.assertEqual(terminal_worker._transient_infra_backoff_seconds("bad"), base)

    def test_q03_default_year_is_bound_to_resolved_run_smoke_window(self) -> None:
        self.assertEqual(
            terminal_worker._resolved_evidence_window(
                {
                    "evidence_binding_required": True,
                    "expected_from_date": None,
                    "expected_to_date": None,
                }
            ),
            ("2024.01.01", "2024.12.31"),
        )

    def test_explicit_evidence_window_is_preserved(self) -> None:
        self.assertEqual(
            terminal_worker._resolved_evidence_window(
                {
                    "evidence_binding_required": True,
                    "expected_from_date": "2018.07.02",
                    "expected_to_date": "2022.12.31",
                }
            ),
            ("2018.07.02", "2022.12.31"),
        )


if __name__ == "__main__":
    unittest.main()
