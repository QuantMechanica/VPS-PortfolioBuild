from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
HELPER = REPO_ROOT / "framework" / "include" / "QM" / "QM_BasketOrder.mqh"


class BasketOrderHelperStaticTests(unittest.TestCase):
    def test_helper_trades_requested_symbol_not_host_symbol(self) -> None:
        text = HELPER.read_text(encoding="utf-8")
        self.assertIn("struct QM_BasketOrderRequest", text)
        self.assertIn("trade_req.symbol = req.symbol;", text)
        self.assertNotIn("trade_req.symbol = _Symbol;", text)

    def test_helper_uses_registered_magic_and_safety_gates(self) -> None:
        text = HELPER.read_text(encoding="utf-8")
        self.assertIn("QM_KillSwitchCheck()", text)
        self.assertIn("QM_NewsAllowsTrade(req.symbol", text)
        self.assertIn("QM_MagicChecked(ea_id, req.symbol_slot, req.symbol)", text)
        self.assertIn("QM_LotsForRisk(req.symbol", text)


if __name__ == "__main__":
    unittest.main()
