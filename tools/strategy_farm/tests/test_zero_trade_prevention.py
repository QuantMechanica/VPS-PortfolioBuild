from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.strategy_farm import farmctl


class ZeroTradePreventionTests(unittest.TestCase):
    def test_p2_fanout_respects_card_declared_universe(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            (approved / "QM5_999001_universe-test.md").write_text(
                """---
ea_id: QM5_999001
slug: universe-test
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
Universe: EURUSD.DWX, XAUUSD.DWX
Filters: news blackout only.
""",
                encoding="utf-8",
            )
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                with mock.patch.object(
                    farmctl,
                    "_ensure_p2_full_dwx_setfiles",
                    return_value=[
                        ("EURUSD.DWX", "eur.set"),
                        ("GBPUSD.DWX", "gbp.set"),
                        ("XAUUSD.DWX", "xau.set"),
                    ],
                ):
                    created, skipped = farmctl._create_backtest_work_items(
                        conn,
                        parent_task_id="parent",
                        root=root,
                        ea_id="QM5_999001",
                        phase="P2",
                        surviving_symbols=None,
                    )

            self.assertEqual([row["symbol"] for row in created], ["EURUSD.DWX", "XAUUSD.DWX"])
            self.assertEqual(skipped, [])

    def test_p2_enqueue_blocks_latest_zero_trade_build_smoke(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            with farmctl.connect(root) as conn:
                now = farmctl.utc_now()
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES ('build-zero', 'build_ea', 'done', 'QM5_999002', ?, ?, ?)
                    """,
                    (
                        json.dumps({"codex_result": {"smoke_result": "zero_trades"}}),
                        now,
                        now,
                    ),
                )
                conn.execute(
                    """
                    INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                    VALUES ('review-pass', 'ea_review', 'done', 'QM5_999002', ?, ?, ?)
                    """,
                    (
                        json.dumps({"ea_id": "QM5_999002", "verdict": {"verdict": "APPROVE_FOR_BACKTEST"}}),
                        now,
                        now,
                    ),
                )
                conn.commit()

            result = farmctl.enqueue_backtest(root, "review-pass", "P2")

            self.assertFalse(result["enqueued"])
            self.assertEqual(result["reason"], "q01_trade_generation_zero_trades")
            self.assertEqual(result["build_task_id"], "build-zero")


if __name__ == "__main__":
    unittest.main()
