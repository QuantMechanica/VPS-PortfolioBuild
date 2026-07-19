from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
HELPER = REPO_ROOT / "framework" / "include" / "QM" / "QM_BasketOrder.mqh"
ENTRY = REPO_ROOT / "framework" / "include" / "QM" / "QM_Entry.mqh"
TRADE_CONTEXT = REPO_ROOT / "framework" / "include" / "QM" / "QM_TradeContext.mqh"


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


class PendingFillingPolicyStaticTests(unittest.TestCase):
    def test_pending_requests_force_return_and_deals_keep_symbol_resolver(self) -> None:
        text = TRADE_CONTEXT.read_text(encoding="utf-8")
        policy_start = text.index(
            "ENUM_ORDER_TYPE_FILLING QM_TradeContextResolveRequestFilling"
        )
        policy_end = text.index("bool QM_TradeContextOpensExposure", policy_start)
        policy = text[policy_start:policy_end]

        self.assertIn("request.action == TRADE_ACTION_PENDING", policy)
        self.assertIn("return ORDER_FILLING_RETURN;", policy)
        self.assertIn("return QM_TradeContextResolveFilling(request.symbol);", policy)
        self.assertLess(
            policy.index("request.action == TRADE_ACTION_PENDING"),
            policy.index("return QM_TradeContextResolveFilling(request.symbol);"),
        )

    def test_entry_and_basket_builders_use_request_filling_policy(self) -> None:
        expected = (
            "trade_req.type_filling = "
            "QM_TradeContextResolveRequestFilling(trade_req);"
        )
        for path in (ENTRY, HELPER):
            with self.subTest(path=path):
                text = path.read_text(encoding="utf-8")
                self.assertIn("TRADE_ACTION_PENDING : TRADE_ACTION_DEAL", text)
                self.assertIn(expected, text)


if __name__ == "__main__":
    unittest.main()
