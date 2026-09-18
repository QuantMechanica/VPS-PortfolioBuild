import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))
sys.path.insert(0, str(REPO / "tools" / "strategy_farm" / "portfolio"))

import card_intake_prescreen_g0_economics as prescreen  # noqa: E402
from commission import CommissionModel  # noqa: E402


_CARD_HEADER = """---
ea_id: QM5_99999
slug: unit-test-card
target_symbols: [EURUSD.DWX, GBPUSD.DWX]
timeframe: M15
expected_trades_per_year_per_symbol: 280
card_sha256: deadbeef
---

# Unit test card
"""

_PARAM_RANGES_NOOP = """
## Parameter ranges
- time_stop_bars: 8 .. 16
- max_trades_per_day: 2 .. 6
- london_start_hour_utc: 7 .. 8
- london_flat_min_utc: 660 .. 720

One entry per symbol per session window; at most max_trades_per_day entries.
"""

_PARAM_RANGES_REACHABLE = """
## Parameter ranges
- time_stop_bars: 8 .. 16
- max_trades_per_day: 1 .. 6
- london_start_hour_utc: 7 .. 8
- ny_start_hour_utc: 12 .. 13
- london_flat_min_utc: 660 .. 720
- ny_flat_min_utc: 960 .. 1020

One entry per symbol per session window; at most max_trades_per_day entries.
"""


def _write_card(tmp_path: Path, body: str, name: str = "QM5_99999_unit-test-card.md") -> Path:
    card_path = tmp_path / name
    card_path.write_text(_CARD_HEADER + body, encoding="utf-8")
    return card_path


class PilotFireCountEvidenceTests(unittest.TestCase):
    def test_missing_evidence_when_frequency_claim_unmeasured(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), "no measured field here")
            result = prescreen.check_pilot_fire_count_evidence(card_path)
        self.assertEqual(result.status, prescreen.STATUS_MISSING_EVIDENCE)

    def test_not_applicable_without_frequency_claim(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            card_path = Path(td) / "QM5_1_no-claim.md"
            card_path.write_text(
                "---\nea_id: QM5_1\nslug: no-claim\ntarget_symbols: [EURUSD.DWX]\n"
                "card_sha256: aa\n---\n\nbody\n",
                encoding="utf-8",
            )
            result = prescreen.check_pilot_fire_count_evidence(card_path)
        self.assertEqual(result.status, prescreen.STATUS_NOT_APPLICABLE)

    def test_pass_with_hash_pinned_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            evidence_path = tmp / "fire_count.json"
            evidence_path.write_text('{"entries": 42}', encoding="utf-8")
            digest = prescreen._sha256_file(evidence_path)
            body = (
                f"measured_fire_count_per_window: 0.089\n"
                f"measured_fire_count_evidence_path: {evidence_path}\n"
                f"measured_fire_count_evidence_sha256: {digest}\n"
            )
            card_path = tmp / "QM5_99999_unit-test-card.md"
            card_path.write_text(
                "---\nea_id: QM5_99999\nslug: unit-test-card\n"
                "target_symbols: [EURUSD.DWX]\nexpected_trades_per_year_per_symbol: 280\n"
                f"{body}card_sha256: deadbeef\n---\n\nbody\n",
                encoding="utf-8",
            )
            result = prescreen.check_pilot_fire_count_evidence(card_path)
        self.assertEqual(result.status, prescreen.STATUS_PASS)

    def test_fail_on_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            evidence_path = tmp / "fire_count.json"
            evidence_path.write_text('{"entries": 42}', encoding="utf-8")
            card_path = tmp / "QM5_99999_unit-test-card.md"
            card_path.write_text(
                "---\nea_id: QM5_99999\nslug: unit-test-card\n"
                "target_symbols: [EURUSD.DWX]\nexpected_trades_per_year_per_symbol: 280\n"
                "measured_fire_count_per_window: 0.089\n"
                f"measured_fire_count_evidence_path: {evidence_path}\n"
                "measured_fire_count_evidence_sha256: 0000000000000000000000000000000000000000000000000000000000000000\n"
                "card_sha256: deadbeef\n---\n\nbody\n",
                encoding="utf-8",
            )
            result = prescreen.check_pilot_fire_count_evidence(card_path)
        self.assertEqual(result.status, prescreen.STATUS_FAIL)
        self.assertIn("mismatch", result.detail)


class CostToTargetFloorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.model = CommissionModel()

    def test_missing_evidence_without_cost_floor_fields(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), "no cost floor fields")
            result = prescreen.check_cost_to_target_floor(card_path, self.model)
        self.assertEqual(result.status, prescreen.STATUS_MISSING_EVIDENCE)

    def test_pass_when_commission_r_within_floor(self) -> None:
        # forex flat_per_lot_rt = 5.0 (live_commission.json); a generous stop
        # of 100 pips at $10/pip keeps commission_R well under 0.03.
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            card_path = tmp / "QM5_99999_unit-test-card.md"
            card_path.write_text(
                "---\nea_id: QM5_99999\nslug: unit-test-card\n"
                "target_symbols: [EURUSD.DWX, GBPUSD.DWX]\n"
                "cost_floor_min_stop_units: 100\n"
                "cost_floor_unit_value_per_lot: 10\n"
                "card_sha256: deadbeef\n---\n\nbody\n",
                encoding="utf-8",
            )
            result = prescreen.check_cost_to_target_floor(card_path, self.model)
        self.assertEqual(result.status, prescreen.STATUS_PASS)
        # 5.0 / (100 * 10) = 0.005
        self.assertAlmostEqual(result.data["per_symbol_commission_r"]["EURUSD.DWX"], 0.005)

    def test_fail_reproduces_postmortem_reference_ratio(self) -> None:
        # Postmortem sec 2/5.2: stop ~11.1 pips at ~$10/pip pushes commission_R
        # to ~0.05, above the 0.03 floor, using the registry's forex flat fee
        # (5.0/lot round turn), not the postmortem's ad hoc Darwinex figure.
        with tempfile.TemporaryDirectory() as td:
            tmp = Path(td)
            card_path = tmp / "QM5_99999_unit-test-card.md"
            card_path.write_text(
                "---\nea_id: QM5_99999\nslug: unit-test-card\n"
                "target_symbols: [EURUSD.DWX]\n"
                "cost_floor_min_stop_units: 11.1\n"
                "cost_floor_unit_value_per_lot: 10\n"
                "card_sha256: deadbeef\n---\n\nbody\n",
                encoding="utf-8",
            )
            result = prescreen.check_cost_to_target_floor(card_path, self.model)
        self.assertEqual(result.status, prescreen.STATUS_FAIL)
        expected_r = 5.0 / (11.1 * 10)
        self.assertAlmostEqual(
            result.data["per_symbol_commission_r"]["EURUSD.DWX"], expected_r, places=6
        )
        self.assertGreater(expected_r, prescreen.COST_TO_TARGET_MAX_R)


class NoOpFilterLintTests(unittest.TestCase):
    def test_fail_on_trade_cap_unreachable_across_full_range(self) -> None:
        # This is the exact QM5_41477 defect: max_trades_per_day 2..6 behind
        # "one entry per session window" x 2 windows/day (London start only
        # here is enough to prove the mechanical rule fires).
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), _PARAM_RANGES_NOOP)
            result = prescreen.check_no_op_filter_lint(card_path)
        self.assertEqual(result.status, prescreen.STATUS_FAIL)
        self.assertIn("no-op", result.detail)

    def test_pass_when_trade_cap_reachable(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), _PARAM_RANGES_REACHABLE)
            result = prescreen.check_no_op_filter_lint(card_path)
        self.assertEqual(result.status, prescreen.STATUS_PASS)

    def test_not_applicable_without_parameter_ranges(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), "no parameter ranges section")
            result = prescreen.check_no_op_filter_lint(card_path)
        self.assertEqual(result.status, prescreen.STATUS_NOT_APPLICABLE)

    def test_fail_on_time_stop_structurally_unreachable_before_flat(self) -> None:
        body = """
## Parameter ranges
- time_stop_bars: 20 .. 30
- max_trades_per_day: 1 .. 2
- london_start_hour_utc: 10 .. 10
- london_flat_min_utc: 660 .. 660

One entry per symbol per session window.
"""
        with tempfile.TemporaryDirectory() as td:
            card_path = _write_card(Path(td), body)
            result = prescreen.check_no_op_filter_lint(card_path)
        # time_stop_bars min 20 * 15min(M15) = 300min runway required;
        # window runway = 660 - 10*60 = 60min possible => structurally impossible.
        self.assertEqual(result.status, prescreen.STATUS_FAIL)
        self.assertIn("time_stop_bars structurally unreachable", result.detail)


class SkipReasonLoggingTests(unittest.TestCase):
    def test_deferred_when_no_ea_built_yet(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "framework" / "EAs").mkdir(parents=True)
            card_path = _write_card(root, "body")
            result = prescreen.check_skip_reason_logging(card_path, root)
        self.assertEqual(result.status, prescreen.STATUS_DEFERRED_NO_BUILD_YET)

    def test_fail_when_ea_never_emits_strategy_entry_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ea_dir = root / "framework" / "EAs" / "QM5_99999_unit-test-card"
            ea_dir.mkdir(parents=True)
            (ea_dir / "QM5_99999_unit-test-card.mqh").write_text(
                "void Strategy_EntrySignal() { QM_LogEvent(QM_INFO, \"ENTRY_ACCEPTED\", \"\"); }",
                encoding="utf-8",
            )
            card_path = _write_card(root, "body")
            result = prescreen.check_skip_reason_logging(card_path, root)
        self.assertEqual(result.status, prescreen.STATUS_FAIL)

    def test_pass_when_ea_emits_strategy_entry_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ea_dir = root / "framework" / "EAs" / "QM5_99999_unit-test-card"
            ea_dir.mkdir(parents=True)
            (ea_dir / "QM5_99999_unit-test-card.mqh").write_text(
                "QM_LogEvent(QM_WARN, \"STRATEGY_ENTRY_REJECTED\", payload);",
                encoding="utf-8",
            )
            card_path = _write_card(root, "body")
            result = prescreen.check_skip_reason_logging(card_path, root)
        self.assertEqual(result.status, prescreen.STATUS_PASS)


class VerdictAssemblyTests(unittest.TestCase):
    def test_contract_version_stamped_and_overall_status(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "framework" / "EAs").mkdir(parents=True)
            card_path = _write_card(root, _PARAM_RANGES_NOOP)
            verdict = prescreen.evaluate_card(card_path, root)
        self.assertEqual(verdict.contract_version, prescreen.CONTRACT_VERSION)
        # missing cost floor + fire count evidence -> MISSING_EVIDENCE dominates
        # unless the no-op lint FAIL is present, which takes precedence.
        self.assertEqual(verdict.overall_status, prescreen.STATUS_FAIL)

    def test_old_verdict_object_is_never_mutated_by_a_later_evaluation(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "framework" / "EAs").mkdir(parents=True)
            card_path = _write_card(root, "plain body, no claims")
            first = prescreen.evaluate_card(card_path, root)
            first_dict_before = first.to_dict()
            # Mutate the card on disk and re-evaluate; the first verdict object
            # (already handed to a caller/ledger) must be byte-identical after.
            card_path.write_text(_CARD_HEADER + _PARAM_RANGES_NOOP, encoding="utf-8")
            _second = prescreen.evaluate_card(card_path, root)
        self.assertEqual(first.to_dict(), first_dict_before)

    def test_ledger_append_only_never_overwrites_prior_lines(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "framework" / "EAs").mkdir(parents=True)
            card_path = _write_card(root, "plain body")
            ledger_path = root / "ledger.jsonl"
            v1 = prescreen.evaluate_card(card_path, root)
            prescreen.append_verdict_to_ledger(v1, ledger_path)
            v2 = prescreen.evaluate_card(card_path, root)
            prescreen.append_verdict_to_ledger(v2, ledger_path)
            lines = ledger_path.read_text(encoding="utf-8").splitlines()
        self.assertEqual(len(lines), 2)


class ActivationGateTests(unittest.TestCase):
    def test_same_vendor_critique_raises(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ledger_path = Path(td) / "activation.jsonl"
            with self.assertRaises(ValueError):
                prescreen.record_cross_vendor_critique(
                    critic_agent="claude",
                    verdict="ACCEPT",
                    notes="self-approval attempt",
                    ledger_path=ledger_path,
                )

    def test_inactive_before_any_critique(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ledger_path = Path(td) / "activation.jsonl"
            self.assertFalse(prescreen.contract_is_active(ledger_path))

    def test_active_after_distinct_vendor_accept(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ledger_path = Path(td) / "activation.jsonl"
            prescreen.record_cross_vendor_critique(
                critic_agent="codex",
                verdict="ACCEPT",
                notes="independent review complete",
                ledger_path=ledger_path,
            )
            self.assertTrue(prescreen.contract_is_active(ledger_path))

    def test_still_inactive_after_reject(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            ledger_path = Path(td) / "activation.jsonl"
            prescreen.record_cross_vendor_critique(
                critic_agent="codex",
                verdict="REJECT",
                notes="found a gap",
                ledger_path=ledger_path,
            )
            self.assertFalse(prescreen.contract_is_active(ledger_path))


if __name__ == "__main__":
    unittest.main()
