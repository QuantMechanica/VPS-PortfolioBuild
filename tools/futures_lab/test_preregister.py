from __future__ import annotations

import copy
import tempfile
import unittest
from pathlib import Path

from preregister import (
    PreregistrationError,
    compile_plan,
    expanded_raw_contracts,
    load_config,
    validate_config,
    write_plan,
)


HERE = Path(__file__).resolve().parent
CONFIG_PATH = (
    HERE
    / "preregistrations"
    / "task_b86d2fbd-574d-4024-af9a-2e48ff84beb9"
    / "preregistration.json"
)


class FuturesPreregistrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = load_config(CONFIG_PATH)

    def test_frozen_task_config_is_valid_and_bounded(self) -> None:
        validate_config(self.config)
        self.assertEqual(len(self.config["hypotheses"]), 2)
        self.assertEqual(len(self.config["arms"]), 5)
        self.assertLessEqual(len(self.config["arms"]), 6)
        self.assertFalse(self.config["economic_results_viewed"])
        self.assertFalse(self.config["creates_mt5_ea_ids"])
        self.assertFalse(self.config["uses_cfd_gate_runner"])

    def test_plan_expansion_is_deterministic_and_contains_no_results(self) -> None:
        first = compile_plan(self.config, "a" * 64)
        second = compile_plan(copy.deepcopy(self.config), "a" * 64)
        self.assertEqual(first, second)
        self.assertEqual(first["trial_cell_count"], 5 * 4 * 3)
        self.assertEqual(len(first["cells"]), first["trial_cell_count"])
        self.assertTrue(all(cell["result_status"] == "NOT_RUN" for cell in first["cells"]))
        self.assertFalse(first["economic_results_included"])

    def test_emitted_plan_uses_hash_stable_lf_bytes(self) -> None:
        plan = compile_plan(self.config, "a" * 64)
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "plan.json"
            write_plan(path, plan)
            payload = path.read_bytes()
        self.assertTrue(payload.endswith(b"\n"))
        self.assertNotIn(b"\r\n", payload)

    def test_contract_candidates_are_raw_quarterlies(self) -> None:
        contracts = expanded_raw_contracts(self.config)
        self.assertEqual(len(contracts), 132)
        self.assertIn("MESM9", contracts)
        self.assertIn("NQM7", contracts)
        self.assertFalse(any(".DWX" in value or "c.0" in value for value in contracts))

    def test_mini_signal_and_micro_fill_identities_remain_distinct(self) -> None:
        arms = {arm["id"]: arm for arm in self.config["arms"]}
        self.assertEqual(arms["A2_ORB_ES_SIGNAL_MES_FILL"]["signal_instrument"]["root"], "ES")
        self.assertEqual(arms["A2_ORB_ES_SIGNAL_MES_FILL"]["fill_instrument"]["root"], "MES")
        self.assertEqual(arms["A5_ORB_NQ_SIGNAL_MNQ_FILL"]["signal_instrument"]["root"], "NQ")
        self.assertEqual(arms["A5_ORB_NQ_SIGNAL_MNQ_FILL"]["fill_instrument"]["root"], "MNQ")

    def test_qm_hypothesis_is_explicit_and_mechanically_complete(self) -> None:
        hypothesis = next(row for row in self.config["hypotheses"] if row["provenance"] == "QM_AUTHORED")
        self.assertEqual(hypothesis["external_source_claim"], "NONE_QM_AUTHORED")
        spec = self.config["strategy_specs"][hypothesis["mechanical_spec_id"]]
        for field in (
            "range_window_new_york",
            "entry_window_new_york",
            "minimum_excursion_ticks",
            "maximum_reentry_wait_bars",
            "long_trigger",
            "short_trigger",
            "initial_stop",
            "profit_target",
            "forced_flat",
        ):
            self.assertIn(field, spec)

    def test_prior_negative_cfd_rows_are_retained_without_promotion(self) -> None:
        rows = [
            row
            for group in self.config["prior_cfd_evidence"]
            for row in group.get("rows", [])
        ]
        target = next(row for row in rows if row["work_item_id"] == "da999340-17a7-4cae-bf36-c65252aa8ebf")
        self.assertEqual(target["verdict"], "FAIL")
        self.assertEqual(target["fold_net_profit_factors"], [0.98, 1.28, 0.51])
        self.assertNotIn("approval", target)

    def test_arm_cap_cannot_be_widened_by_existing_config(self) -> None:
        mutated = copy.deepcopy(self.config)
        mutated["arm_cap"] = 4
        with self.assertRaisesRegex(PreregistrationError, "exceeds the cap"):
            validate_config(mutated)

    def test_percent_risk_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.config)
        mutated["risk"]["risk_percent"] = 0.5
        with self.assertRaisesRegex(PreregistrationError, "risk_percent"):
            validate_config(mutated)

    def test_continuous_or_cfd_signal_identity_is_rejected(self) -> None:
        mutated = copy.deepcopy(self.config)
        mutated["arms"][0]["signal_instrument"]["root"] = "MES.c.0"
        with self.assertRaises(PreregistrationError):
            validate_config(mutated)

    def test_holdout_cannot_begin_before_freeze(self) -> None:
        mutated = copy.deepcopy(self.config)
        holdout = next(row for row in mutated["periods"] if row["id"] == "untouched_holdout")
        holdout["start"] = mutated["frozen_on"]
        with self.assertRaisesRegex(PreregistrationError, "after the freeze date"):
            validate_config(mutated)

    def test_news_staleness_guard_cannot_exceed_336_hours(self) -> None:
        mutated = copy.deepcopy(self.config)
        mutated["news_blackout"]["max_calendar_age_hours"] = 337
        with self.assertRaisesRegex(PreregistrationError, "336"):
            validate_config(mutated)


if __name__ == "__main__":
    unittest.main()
