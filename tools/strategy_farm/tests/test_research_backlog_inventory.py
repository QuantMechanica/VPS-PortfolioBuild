from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from tools.strategy_farm import farmctl


class ResearchBacklogInventoryTests(unittest.TestCase):
    def _write_ready_card(self, path: Path, ea_id: str, slug: str) -> None:
        path.write_text(
            f"""---
ea_id: {ea_id}
slug: {slug}
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Ready Card

Thesis: monthly event drift.
Universe: XAUUSD.DWX
Timeframe: D1
Entry: enter on event window.
Exit: exit after window.
Risk: fixed fractional.
Filters: news blackout is mandatory; no optional regime or volatility filter.
Falsification: fail if PF below threshold.
Q08/Q11 risks: event concentration and news robustness.
Implementation notes: simple MQL5 date filter and narrow setfile.
""",
            encoding="utf-8",
        )

    def test_counts_only_prebuild_ready_approved_cards_as_research_reservoir(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            ready = approved / "QM5_777001_ready-card.md"
            self._write_ready_card(ready, "QM5_777001", "ready-card")
            blocked = approved / "QM5_777002_blocked-card.md"
            blocked.write_text(
                """---
ea_id: QM5_777002
slug: blocked-card
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Blocked Card
""",
                encoding="utf-8",
            )

            inventory = farmctl.research_backlog_inventory(root)

            self.assertEqual(inventory["approved_cards"], 2)
            self.assertEqual(inventory["ready_approved_cards"], 1)
            self.assertEqual(inventory["blocked_approved_cards"], 1)
            self.assertEqual(inventory["total"], 1)

    def test_missing_strategy_card_body_schema_blocks_ready_count(self) -> None:
        with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
            root = Path(tmp)
            approved = root / "artifacts" / "cards_approved"
            approved.mkdir(parents=True)
            blocked = approved / "QM5_777003_schema-blocked.md"
            blocked.write_text(
                """---
ea_id: QM5_777003
slug: schema-blocked
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_trades_per_year_per_symbol: 12
---
# Too Thin
""",
                encoding="utf-8",
            )

            ready = farmctl.ready_strategy_card_inventory(root)

            self.assertEqual(ready["ready_count"], 0)
            errors = ready["blocked_cards"][0]["errors"]
            self.assertIn("schema_missing_body:thesis", errors)


if __name__ == "__main__":
    unittest.main()
