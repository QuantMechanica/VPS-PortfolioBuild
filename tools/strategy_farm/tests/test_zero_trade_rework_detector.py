from __future__ import annotations

import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm.zero_trade_rework_detector import scan_for_rework_candidates


class ZeroTradeReworkDetectorTests(unittest.TestCase):
    def _db(self, root: Path) -> Path:
        db = root / "farm_state.sqlite"
        with sqlite3.connect(db) as conn:
            conn.execute(
                """
                CREATE TABLE work_items (
                    ea_id TEXT,
                    phase TEXT,
                    status TEXT,
                    verdict TEXT,
                    payload_json TEXT,
                    evidence_path TEXT
                )
                """
            )
        return db

    def _insert(
        self,
        db: Path,
        ea_id: str,
        *,
        verdict: str = "FAIL",
        trades: int = 0,
        status: str = "done",
        phase: str = "P2",
    ) -> None:
        payload = {"recovered_stats": {"total_trades": trades}, "slug": f"{ea_id.lower()}-slug"}
        with sqlite3.connect(db) as conn:
            conn.execute(
                """
                INSERT INTO work_items(ea_id, phase, status, verdict, payload_json, evidence_path)
                VALUES (?, ?, ?, ?, ?, '')
                """,
                (ea_id, phase, status, verdict, json.dumps(payload)),
            )

    def test_triggering_ea_produces_candidate(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            db = self._db(Path(tmp))
            for _ in range(10):
                self._insert(db, "QM5_9001", trades=0)

            candidates = scan_for_rework_candidates(db)

            self.assertEqual(len(candidates), 1)
            self.assertEqual(candidates[0]["ea_id"], "QM5_9001")
            self.assertEqual(candidates[0]["fail_count"], 10)
            self.assertEqual(candidates[0]["zero_trade_pct"], 1.0)

    def test_non_triggering_ea_with_pass_is_ignored(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            db = self._db(Path(tmp))
            for _ in range(9):
                self._insert(db, "QM5_9002", trades=0)
            self._insert(db, "QM5_9002", verdict="PASS", trades=12)

            self.assertEqual(scan_for_rework_candidates(db), [])


if __name__ == "__main__":
    unittest.main()
