from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

from tools.strategy_farm import farmctl


class MT5FeedDepthTests(unittest.TestCase):
    def test_expand_pending_p2_parents_stops_at_feed_target(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            farmctl.init_db(root)
            now = farmctl.utc_now()
            with farmctl.connect(root) as conn:
                for task_id, ea_id in (("p2-a", "QM5_991001"), ("p2-b", "QM5_991002")):
                    conn.execute(
                        """
                        INSERT INTO tasks(id, kind, status, card_id, payload_json, created_at, updated_at)
                        VALUES (?, 'backtest_p2', 'pending', ?, ?, ?, ?)
                        """,
                        (task_id, ea_id, json.dumps({"ea_id": ea_id, "phase": "P2"}), now, now),
                    )
                conn.commit()

            def fake_setfiles(repo_root: Path, ea_id: str) -> list[tuple[str, str]]:
                return [
                    ("EURUSD.DWX", f"{ea_id}_EURUSD.set"),
                    ("XAUUSD.DWX", f"{ea_id}_XAUUSD.set"),
                ]

            with farmctl.connect(root) as conn:
                with mock.patch.object(farmctl, "_ensure_p2_target_setfiles", side_effect=fake_setfiles):
                    expanded = farmctl._expand_pending_backtest_p2_parents(root, conn, target_depth=3)
                rows = conn.execute(
                    """
                    SELECT parent_task_id, COUNT(*) AS n
                    FROM work_items
                    GROUP BY parent_task_id
                    ORDER BY parent_task_id
                    """
                ).fetchall()

            self.assertEqual(
                [(row["task_id"], row["created"]) for row in expanded],
                [("p2-a", 2), ("p2-b", 2)],
            )
            self.assertEqual([(row["parent_task_id"], row["n"]) for row in rows], [("p2-a", 2), ("p2-b", 2)])

    def test_feed_target_uses_two_per_terminal_floor(self) -> None:
        with mock.patch.object(farmctl, "active_mt5_terminals", return_value=tuple(f"T{i}" for i in range(1, 11))):
            self.assertEqual(farmctl._mt5_work_item_feed_target(), 20)


if __name__ == "__main__":
    unittest.main()
