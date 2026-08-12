from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
HELPER = REPO_ROOT / "framework" / "include" / "QM" / "QM_BasketOrder.mqh"
ENTRY = REPO_ROOT / "framework" / "include" / "QM" / "QM_Entry.mqh"
TRADE_CONTEXT = REPO_ROOT / "framework" / "include" / "QM" / "QM_TradeContext.mqh"
EA_20123 = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20123_dailyopen-h1-basket"
    / "QM5_20123_dailyopen-h1-basket.mq5"
)


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

    def _stress_block(self, text: str) -> str:
        # The WP-9 stress-rejection hook, isolated from the surrounding helper so
        # the assertions below cannot be satisfied by unrelated code.
        start = text.index(
            "Q06 HARSH stress trade-rejection simulation, basket path"
        )
        end = text.index("const double entry_price = QM_BasketResolvePrice(req);", start)
        return text[start:end]

    def test_basket_stress_reject_is_memoized_per_transaction(self) -> None:
        # WP-9 (revised after Codex CHANGES-REQUIRED): the stress rejection must be
        # ONE draw per basket transaction, memoized in static state keyed on
        # (ea_id, TimeCurrent()), not an unconditional per-leg draw. A per-leg draw
        # leaves corrupted partial packages for callers that do not roll back
        # (QM5_10009 / QM5_10025).
        block = self._stress_block(HELPER.read_text(encoding="utf-8"))
        normalized = "".join(block.split())

        # Exactly one draw in the basket path, and it is STORED (memoized), not
        # consumed inline like the old `&& QM_RandBoolTagged(...)` per-leg pattern.
        self.assertEqual(block.count("QM_RandBoolTagged"), 1)
        self.assertIn('=QM_RandBoolTagged("entry_reject"', normalized)
        self.assertNotIn("&&QM_RandBoolTagged(", normalized)

        # Memo state exists and is keyed on the per-transaction identity
        # (ea_id + tick time), never on the per-leg symbol/slot.
        self.assertIn("static", block)
        self.assertIn("TimeCurrent()", block)
        self.assertIn("ea_id", block)
        self.assertNotIn("req.symbol_slot", block)

        # Reject decision is driven by the memoized verdict, and it still logs the
        # canonical reject event.
        self.assertIn("QM_BASKET_REJECTED_STRESS", block)

    def test_memo_key_is_exact_two_field_ea_id_and_tick_time(self) -> None:
        # The redraw guard compares EXACTLY the two memo fields — the EA-level
        # identity and the tick time — joined by `||`, and the time field is
        # bound to TimeCurrent() (cached in `now`). Keying on anything else
        # (per-leg magic/symbol/slot) would re-introduce the per-leg bug.
        block = self._stress_block(HELPER.read_text(encoding="utf-8"))
        normalized = "".join(block.split())

        self.assertIn("constdatetimenow=TimeCurrent();", normalized)
        self.assertIn(
            "if(s_memo_ea_id!=ea_id||s_memo_time!=now)", normalized
        )
        # The tick-time half of the key is TimeCurrent()-derived, never a
        # per-leg/per-symbol field.
        self.assertNotIn("s_memo_time!=req.", normalized)

    def test_first_call_cannot_collide_with_zero_initialized_memo(self) -> None:
        # Non-colliding first-call state: the memo EA id zero-inits to 0, and the
        # helper refuses any non-positive ea_id BEFORE the stress block, so the
        # first real (ea_id > 0) basket can never match the zero-initialized memo
        # key — it always redraws.
        full = HELPER.read_text(encoding="utf-8")
        block = self._stress_block(full)
        normalized = "".join(block.split())

        self.assertIn("staticints_memo_ea_id=0;", normalized)

        # Non-positive ea_id is rejected, and that guard precedes the stress block.
        self.assertIn("if(ea_id <= 0)", full)
        self.assertIn('"ea_id_not_configured"', full)
        self.assertLess(
            full.index("if(ea_id <= 0)"),
            full.index("Q06 HARSH stress trade-rejection simulation"),
        )

    def test_later_legs_reuse_verdict_from_single_draw_site(self) -> None:
        # Single draw site: the draw lives INSIDE the key-mismatch branch and
        # stores s_memo_reject; the reject decision then reads that memoized
        # verdict. Later legs of the same basket (same ea_id + tick) skip the
        # branch and reuse the stored verdict — exactly one RNG advance/basket.
        block = self._stress_block(HELPER.read_text(encoding="utf-8"))
        normalized = "".join(block.split())

        self.assertEqual(block.count("QM_RandBoolTagged"), 1)
        self.assertIn(
            's_memo_reject=QM_RandBoolTagged("entry_reject",', normalized
        )
        self.assertIn("if(s_memo_reject)", normalized)
        # Store happens within the redraw branch, then a separate check consumes it.
        self.assertLess(
            normalized.index("if(s_memo_ea_id!=ea_id||s_memo_time!=now)"),
            normalized.index('s_memo_reject=QM_RandBoolTagged("entry_reject",'),
        )
        self.assertLess(
            normalized.index('s_memo_reject=QM_RandBoolTagged("entry_reject",'),
            normalized.index("if(s_memo_reject)"),
        )

    def test_p_zero_bypasses_draw_and_static_state(self) -> None:
        # Complete p=0.0 bypass: the whole hook — static declarations, the draw,
        # and the memo writes — is nested inside `if(prob > 0.0)`, so at p=0.0
        # nothing is drawn and no static is touched (byte-identical RNG cursor to
        # a no-hook build for Q05 MED / live determinism).
        block = self._stress_block(HELPER.read_text(encoding="utf-8"))
        normalized = "".join(block.split())

        self.assertIn("if(g_qm_entry_stress_reject_prob>0.0)", normalized)
        guard = normalized.index("if(g_qm_entry_stress_reject_prob>0.0)")
        self.assertLess(guard, normalized.index("staticints_memo_ea_id=0;"))
        self.assertLess(
            guard, normalized.index('s_memo_reject=QM_RandBoolTagged("entry_reject",')
        )
        self.assertLess(guard, normalized.index("if(s_memo_reject)"))


class BasketMemberPreflightRemovedStaticTests(unittest.TestCase):
    def test_qm5_20123_duplicate_stress_preflight_is_removed(self) -> None:
        # WP-9: QM_BasketOpenPosition now owns the single memoized stress draw, so
        # QM5_20123's per-member "entry_reject" preflight — which stacked the
        # rejection to 0.9^3 = 72.9% accept (27.1% reject) for a two-member
        # package instead of the intended single-draw 90% — was removed.
        text = EA_20123.read_text(encoding="utf-8")

        # The duplicate stress rail is gone entirely from the EA source.
        self.assertNotIn("QM_RandBoolTagged", text)
        self.assertNotIn("QM_BASKET_REJECTED_STRESS", text)

        # Member planning / news-preflight / rollback logic must NOT have been
        # disturbed: the all-or-nothing news gate and the partial-abort rollback
        # are retained.
        self.assertIn("Strategy069_NewsAllowsMember", text)
        self.assertIn("BASKET_PARTIAL_ABORT", text)

    def test_qm5_20123_entry_history_checks_are_closed_bar_gated(self) -> None:
        # Q02 runtime repair: Strategy_NoTradeFilter runs before QM_IsNewBar on
        # every real tick. Cross-symbol SeriesInfoInteger calls therefore belong
        # in Strategy_EntrySignal, which is reached only after the framework H1
        # gate. Moving them back to NoTradeFilter recreates the timeout hot path.
        text = EA_20123.read_text(encoding="utf-8")
        no_trade_start = text.index("bool Strategy_NoTradeFilter()")
        entry_start = text.index("bool Strategy_EntrySignal", no_trade_start)
        manage_start = text.index("void Strategy_ManageOpenPosition", entry_start)
        no_trade = text[no_trade_start:entry_start]
        entry = text[entry_start:manage_start]

        self.assertNotIn("SeriesInfoInteger", no_trade)
        self.assertNotIn("Strategy069_HasAnyMemberPosition", no_trade)
        self.assertIn("Strategy069_MembersReadyForEntry()", entry)

    def test_qm5_20123_flat_ticks_skip_position_scans(self) -> None:
        # A flat basket is the common state. Keep explicit zero-position fast
        # paths in both the shared membership query and per-tick management.
        text = EA_20123.read_text(encoding="utf-8")
        has_start = text.index("bool Strategy069_HasAnyMemberPosition()")
        has_end = text.index("bool Strategy069_BuildRequest", has_start)
        manage_start = text.index("void Strategy_ManageOpenPosition()")
        manage_end = text.index("bool Strategy_ExitSignal()", manage_start)

        self.assertIn("if(PositionsTotal() <= 0)", text[has_start:has_end])
        self.assertIn("if(PositionsTotal() <= 0)", text[manage_start:manage_end])


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
