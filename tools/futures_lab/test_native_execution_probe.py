"""Real pinned native engine, synthetic prices; no network or economic trial."""
from dataclasses import replace
from decimal import Decimal
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import native_execution_probe as p


class NativeExecutionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with patch("socket.create_connection", side_effect=AssertionError("NETWORK_FORBIDDEN")), \
             patch("urllib.request.urlopen", side_effect=AssertionError("NETWORK_FORBIDDEN")):
            cls.report = p.run_probe()
        cls.rows = {(x["scenario"], x["fixture"]): x for x in cls.report["fixtures"]}

    def test_pinned_actual_definition_and_all_frozen_costs(self):
        self.assertEqual(self.report["engine_version"], "1.221.0")
        self.assertEqual(self.report["instrument"], "MESM9.GLBX")
        self.assertEqual(self.report["multiplier"], "5")
        self.assertEqual(self.report["tick_size"], "0.25")
        self.assertEqual(self.report["fixture_count"], 45)
        self.assertFalse(self.report["economic_pass"])
        self.assertEqual(self.report["full_frozen_trial"], "NOT_RUN")

    def test_buy_sell_prices_quantity_commission_and_native_accounting(self):
        for scenario, (rt, ticks, lag_ms) in p.EXPECTED_SCENARIOS.items():
            for side in ("buy", "sell"):
                for qty in (1, 2):
                    with self.subTest(scenario=scenario, side=side, quantity=qty):
                        row = self.rows[scenario, f"{side}_q{qty}"]
                        fills = row["actual_fills"]
                        self.assertEqual([Decimal(x["quantity"]) for x in fills], [qty, qty])
                        self.assertEqual(sum(Decimal(x["commission_usd"]) for x in fills), rt*qty)
                        self.assertEqual(fills[0]["timestamp_ns"], p.BASE_NS+lag_ms*1_000_000)
                        entry_expected = Decimal("5000.75")+ticks*p.TICK if side == "buy" else Decimal("5000.50")-ticks*p.TICK
                        self.assertEqual(Decimal(fills[0]["price"]), entry_expected)
                        self.assertEqual(row["ending_balance_usd"], row["independently_reconciled_balance_usd"])
                        self.assertTrue(row["ending_flat"])

    def test_lifecycle_submitted_precedes_filled_at_equal_time(self):
        for row in self.report["fixtures"]:
            events = row["lifecycle"]
            for fill in row["actual_fills"]:
                order_events = [x["kind"] for x in events if x.get("client_order_id") == fill["client_order_id"]]
                self.assertLess(order_events.index("OrderInitialized"), order_events.index("OrderSubmitted"))
                self.assertLess(order_events.index("OrderSubmitted"), order_events.index("OrderFilled"))

    def test_native_latency_is_not_fresh_quote_latency(self):
        for scenario, (_, ticks, lag_ms) in p.EXPECTED_SCENARIOS.items():
            native = self.rows[scenario, "native_latency_sparse"]["actual_fills"][0]
            gated = self.rows[scenario, "fresh_latency_sparse"]["actual_fills"][0]
            self.assertEqual(native["age_of_last_strategy_quote_ns"], lag_ms*1_000_000)
            self.assertEqual(native["timestamp_ns"], p.BASE_NS+lag_ms*1_000_000)
            self.assertEqual(gated["age_of_last_strategy_quote_ns"], 0)
            self.assertEqual(gated["timestamp_ns"], p.BASE_NS+p.NS)
            self.assertEqual(Decimal(gated["price"])-Decimal(native["price"]), Decimal("2.00"))

    def test_stop_gap_uses_quote_not_trigger_and_standing_stop_has_different_latency(self):
        for scenario, (_, ticks, lag_ms) in p.EXPECTED_SCENARIOS.items():
            gated = self.rows[scenario, "stop_gap_gated"]["actual_fills"][1]
            native = self.rows[scenario, "stop_gap_native_standing"]["actual_fills"][1]
            self.assertEqual(Decimal(gated["price"]), Decimal("4994.50")-ticks*p.TICK)
            self.assertEqual(Decimal(native["price"]), Decimal("4995.00")-ticks*p.TICK)
            self.assertEqual(gated["timestamp_ns"]-native["timestamp_ns"], lag_ms*1_000_000)
            self.assertLess(Decimal(gated["price"]), Decimal("4998.00"))
            self.assertFalse(self.rows[scenario, "stop_gap_native_standing"]["reference_parity_claim"])

    def test_raw_native_defaults_are_explicit_counterexamples(self):
        for scenario in p.EXPECTED_SCENARIOS:
            market = self.rows[scenario, "raw_defaults_market"]
            stop = self.rows[scenario, "raw_defaults_standing_stop"]
            self.assertEqual(market["actual_fills"][0]["price"], "5000.25")
            self.assertEqual(market["actual_fills"][0]["timestamp_ns"], p.BASE_NS)
            self.assertEqual(stop["actual_fills"][1]["price"], "4998.00")
            self.assertEqual(stop["fill_model"], "NATIVE_DEFAULT_NO_SLIPPAGE")
            self.assertFalse(stop["reference_parity_claim"])
            self.assertFalse(market["reference_parity_claim"])

    def test_native_forced_flat_clock_and_deadline_fail_closed(self):
        for scenario, (_, _, lag_ms) in p.EXPECTED_SCENARIOS.items():
            row = self.rows[scenario, "forced_flat"]
            self.assertEqual(row["decisions"][1]["decision_ns"], p.FLAT_NS)
            self.assertEqual(row["actual_fills"][1]["timestamp_ns"], p.FLAT_NS+lag_ms*1_000_000)
            failed = self.rows[scenario, "forced_flat_missing_quote"]
            self.assertFalse(failed["ending_flat"])
            self.assertEqual(len(failed["actual_fills"]), 1)
            self.assertIn("FORCED_FLAT_DEADLINE_MISSED", [x.get("reason") for x in failed["blocked"]])
            self.assertFalse(failed["reference_parity_claim"])

    def test_fixed_submitted_quantity_differs_from_reference_fill_sizing(self):
        for scenario, (rt, ticks, _) in p.EXPECTED_SCENARIOS.items():
            fixed = self.rows[scenario, "sizing_at_decision"]
            adapted = self.rows[scenario, "sizing_at_fill"]
            self.assertEqual(fixed["actual_fills"][0]["quantity"], "2")
            self.assertEqual(fixed["reference_quantity_at_first_eligible_quote"], 1)
            self.assertEqual(adapted["actual_fills"][0]["quantity"], "1")
            # Quoted fill distance 5007.25 - 4994.00, plus both-side costs.
            projected_risk = ((Decimal("13.25")*5)+rt+2*ticks*p.TICK*5)*2
            self.assertGreater(projected_risk, 100)
            self.assertFalse(fixed["reference_parity_claim"])

    def test_equal_receive_timestamp_keeps_first_quote_not_later_price(self):
        for scenario, (_, ticks, lag_ms) in p.EXPECTED_SCENARIOS.items():
            fill = self.rows[scenario, "equal_time_source_order"]["actual_fills"][0]
            self.assertEqual(fill["last_strategy_quote_ordinal"], 2)
            self.assertEqual(fill["timestamp_ns"], p.BASE_NS+lag_ms*1_000_000)
            self.assertEqual(Decimal(fill["price"]), Decimal("5001.25")+ticks*p.TICK)

    def test_slippage_model_rejects_unbound_costs_and_oversize(self):
        for invalid in (0, -1, 3, True, 4.0, "1"):
            with self.subTest(invalid=invalid), self.assertRaisesRegex(ValueError, "UNBOUND_SLIPPAGE"):
                p.FrozenSyntheticFillModel(invalid)
        model = p.FrozenSyntheticFillModel(1)
        instrument = p.load_instrument()
        order = SimpleNamespace(quantity=p.Quantity.from_int(3), side=p.OrderSide.BUY)
        with self.assertRaisesRegex(ValueError, "SYNTHETIC_QUANTITY_CAP"):
            model.get_orderbook_for_fill_simulation(instrument, order, p.Price.from_str("5000.00"), p.Price.from_str("5000.25"))

    def test_invalid_book_raises_instead_of_empty_book_native_fallback(self):
        model = p.FrozenSyntheticFillModel(1)
        instrument = p.load_instrument()
        order = SimpleNamespace(quantity=p.Quantity.from_int(1), side=p.OrderSide.BUY)
        for bid, ask in (("5000.25", "5000.00"), ("5000.00", "5000.00"), ("0.00", "0.25")):
            with self.subTest(bid=bid, ask=ask), self.assertRaisesRegex(ValueError, "INVALID_FILL_BBO"):
                model.get_orderbook_for_fill_simulation(instrument, order, p.Price.from_str(bid), p.Price.from_str(ask))

    def test_repeat_is_deterministic_and_input_order_is_checked(self):
        instrument = p.load_instrument()
        scenario = p.scenarios()[0]
        fixture = p.fixture_set(scenario)[0]
        one = p.run_fixture(instrument, scenario, fixture)
        two = p.run_fixture(instrument, scenario, fixture)
        self.assertEqual(p.digest(one), p.digest(two))
        with self.assertRaisesRegex(ValueError, "UNORDERED_FIXTURE"):
            p.run_fixture(instrument, scenario, replace(fixture, rows=tuple(reversed(fixture.rows))))


if __name__ == "__main__":
    unittest.main()
