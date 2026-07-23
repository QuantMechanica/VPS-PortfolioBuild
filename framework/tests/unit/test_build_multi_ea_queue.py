from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.build_multi_ea_queue import build_queue, load_source


class BuildMultiEAQueueTests(unittest.TestCase):
    def test_build_queue_prioritizes_transition_ready_and_dedups(self) -> None:
        approved = [
            {"ea_id": "QM5_1001", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "a1"},
            {"ea_id": "QM5_1002", "phase": "P0", "symbol": "GBPUSD.DWX", "config_hash": "a1"},
        ]
        transition = [
            {"ea_id": "QM5_1003", "phase": "P2", "symbol": "XAUUSD.DWX", "config_hash": "b1"},
            {"ea_id": "QM5_1001", "phase": "P0", "symbol": "EURUSD.DWX", "config_hash": "a1"},
        ]
        queue = build_queue(approved, transition)
        self.assertEqual(queue[0]["ea_id"], "QM5_1003")
        self.assertEqual(len(queue), 3)

    def test_load_source_validates_symbol_suffix(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "source.json"
            payload = {
                "approved_waiting_p0": [{"ea_id": "QM5_1001", "phase": "P0", "symbol": "EURUSD", "config_hash": "a1"}],
                "transition_ready": [],
            }
            path.write_text(json.dumps(payload), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, r"\.DWX"):
                load_source(path)


if __name__ == "__main__":
    unittest.main()
