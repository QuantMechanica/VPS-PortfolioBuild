from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path

from framework.scripts.q08_v3_shadow import (
    EvidenceVerdict,
    PolicyValidationError,
    ShadowRoute,
    SubtestResult,
    SubtestStatus,
    aggregate_shadow,
    load_policy,
    parse_policy,
)
from framework.scripts.q08_v3_shadow.contracts import DECISION_SCHEMA_VERSION
from framework.scripts.q08_v3_shadow.policy import DEFAULT_POLICY_PATH


def _result(test_id: str, status: SubtestStatus | str = SubtestStatus.PASS) -> SubtestResult:
    resolved = status if isinstance(status, SubtestStatus) else SubtestStatus(status)
    return SubtestResult(test_id=test_id, status=resolved)


class Q08V3ShadowPolicyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.policy = load_policy()

    def _raw_policy(self) -> dict:
        return json.loads(DEFAULT_POLICY_PATH.read_text(encoding="utf-8"))

    def test_default_policy_loads_and_is_versioned(self) -> None:
        self.assertEqual(self.policy.schema_version, "q08_archetype_policy/v1")
        self.assertEqual(self.policy.policy_version, "q08-v3-shadow/1.0.0")
        self.assertRegex(self.policy.policy_sha256, r"^[0-9a-f]{64}$")
        self.assertEqual(len(self.policy.archetypes), 6)
        self.assertIn("portfolio_correlation", self.policy.portfolio_only_tests)

    def test_policy_hash_is_independent_of_json_object_key_order(self) -> None:
        raw = self._raw_policy()
        reordered = dict(reversed(list(raw.items())))
        self.assertEqual(
            parse_policy(raw).policy_sha256,
            parse_policy(reordered).policy_sha256,
        )

    def test_policy_hash_changes_when_policy_content_changes(self) -> None:
        raw = self._raw_policy()
        changed = copy.deepcopy(raw)
        changed["universal_tests"][0]["description"] += " Changed."
        self.assertNotEqual(
            parse_policy(raw).policy_sha256,
            parse_policy(changed).policy_sha256,
        )

    def test_alias_resolution_normalises_hyphens_and_case(self) -> None:
        resolved = self.policy.resolve_archetype("Volatility-Expansion")
        self.assertIsNotNone(resolved)
        self.assertEqual(resolved.name, "trend_breakout")

    def test_unknown_archetype_does_not_fall_back(self) -> None:
        self.assertIsNone(self.policy.resolve_archetype("mystery alpha"))

    def test_policy_rejects_unknown_schema(self) -> None:
        raw = self._raw_policy()
        raw["schema_version"] = "q08_archetype_policy/v999"
        with self.assertRaisesRegex(PolicyValidationError, "unsupported policy schema"):
            parse_policy(raw)

    def test_policy_rejects_pass_as_failure_effect(self) -> None:
        raw = self._raw_policy()
        raw["universal_tests"][0]["fail_verdict"] = "SUPPORTED"
        with self.assertRaisesRegex(PolicyValidationError, "unsupported fail_verdict"):
            parse_policy(raw)

    def test_policy_rejects_duplicate_alias_across_archetypes(self) -> None:
        raw = self._raw_policy()
        raw["archetypes"]["mean_reversion"]["aliases"].append("trend")
        with self.assertRaisesRegex(PolicyValidationError, "is shared"):
            parse_policy(raw)

    def test_policy_requires_explicit_portfolio_only_list(self) -> None:
        raw = self._raw_policy()
        del raw["portfolio_only_tests"]
        with self.assertRaisesRegex(PolicyValidationError, "portfolio_only_tests"):
            parse_policy(raw)

    def test_policy_rejects_extra_fields_and_noncanonical_enums(self) -> None:
        extra = self._raw_policy()
        extra["future_semantics"] = "fail closed"
        with self.assertRaisesRegex(PolicyValidationError, "key set mismatch"):
            parse_policy(extra)

        lower_case = self._raw_policy()
        lower_case["universal_tests"][0]["requirement"] = "required"
        with self.assertRaisesRegex(PolicyValidationError, "unsupported requirement"):
            parse_policy(lower_case)

    def test_policy_file_rejects_duplicate_keys(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "duplicate-policy.json"
            path.write_text(
                '{"schema_version":"q08_archetype_policy/v1",'
                '"schema_version":"q08_archetype_policy/v1"}',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(PolicyValidationError, "duplicate policy JSON key"):
                load_policy(path)

    def test_policy_rejects_portfolio_test_overlap_with_archetype(self) -> None:
        raw = self._raw_policy()
        raw["portfolio_only_tests"].append("trend_episode_robustness")
        with self.assertRaisesRegex(PolicyValidationError, "portfolio-only ids"):
            parse_policy(raw)

    def test_policy_is_immutable_at_top_level(self) -> None:
        with self.assertRaises(TypeError):
            self.policy.archetypes["new"] = self.policy.archetypes["intraday"]


class Q08V3ShadowAggregationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.policy = load_policy()

    def _all_required_pass(self, archetype: str = "trend_breakout") -> list[SubtestResult]:
        resolved = self.policy.resolve_archetype(archetype)
        self.assertIsNotNone(resolved)
        tests = list(self.policy.universal_tests) + list(resolved.tests)
        return [
            _result(test.test_id)
            for test in tests
            if test.requirement.value == "REQUIRED"
        ]

    def test_all_required_pass_is_supported(self) -> None:
        decision = aggregate_shadow(
            archetype="trend_breakout",
            results=self._all_required_pass(),
            policy=self.policy,
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.SUPPORTED)
        self.assertEqual(decision.route, ShadowRoute.PORTFOLIO_EVALUATION)
        self.assertEqual(decision.missing_test_ids, ())
        self.assertEqual(decision.policy_sha256, self.policy.policy_sha256)
        self.assertEqual(set(decision.supported_test_ids), set(decision.required_test_ids))

    def test_every_declared_archetype_has_a_complete_supported_path(self) -> None:
        for archetype in self.policy.archetypes:
            with self.subTest(archetype=archetype):
                decision = aggregate_shadow(
                    archetype=archetype,
                    results=self._all_required_pass(archetype),
                    policy=self.policy,
                )
                self.assertEqual(decision.verdict, EvidenceVerdict.SUPPORTED)

    def test_alias_uses_canonical_policy(self) -> None:
        decision = aggregate_shadow(
            archetype="breakout",
            results=self._all_required_pass("trend_breakout"),
            policy=self.policy,
        )
        self.assertEqual(decision.archetype_resolved, "trend_breakout")
        self.assertEqual(decision.verdict, EvidenceVerdict.SUPPORTED)

    def test_missing_required_evidence_is_insufficient(self) -> None:
        results = self._all_required_pass()
        results = [item for item in results if item.test_id != "selection_bias_control"]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INSUFFICIENT)
        self.assertEqual(decision.route, ShadowRoute.SHADOW_EVIDENCE)
        self.assertIn("selection_bias_control", decision.missing_test_ids)

    def test_low_sample_required_evidence_never_passes(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.INSUFFICIENT)
            if item.test_id == "independent_sample_coverage"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INSUFFICIENT)
        self.assertIn("independent_sample_coverage", decision.insufficient_test_ids)

    def test_not_applicable_required_evidence_never_passes(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.NOT_APPLICABLE)
            if item.test_id == "trend_episode_robustness"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INSUFFICIENT)
        self.assertIn("trend_episode_robustness", decision.insufficient_test_ids)

    def test_computed_soft_weakness_is_conditional(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.FAIL)
            if item.test_id == "temporal_stability"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.CONDITIONAL)
        self.assertEqual(
            decision.route, ShadowRoute.PORTFOLIO_EVALUATION_CONDITIONAL
        )
        self.assertIn("temporal_stability", decision.conditional_test_ids)

    def test_diagnostic_failure_can_create_conditional_without_being_required(self) -> None:
        results = self._all_required_pass()
        results.append(_result("whipsaw_tail_risk", SubtestStatus.FAIL))
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.CONDITIONAL)
        self.assertIn("whipsaw_tail_risk", decision.conditional_test_ids)
        self.assertNotIn("whipsaw_tail_risk", decision.required_test_ids)

    def test_computed_hard_failure_is_contradicted(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.FAIL)
            if item.test_id == "cost_adjusted_edge"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.CONTRADICTED)
        self.assertEqual(decision.route, ShadowRoute.REJECT)
        self.assertIn("cost_adjusted_edge", decision.contradicted_test_ids)

    def test_required_invalid_evidence_is_invalid(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.INVALID)
            if item.test_id == "identity_lineage"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertEqual(decision.route, ShadowRoute.RETRY)

    def test_computed_lineage_failure_is_invalid(self) -> None:
        results = self._all_required_pass()
        results = [
            _result(item.test_id, SubtestStatus.FAIL)
            if item.test_id == "identity_lineage"
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertIn("identity_lineage", decision.invalid_test_ids)

    def test_invalid_precedes_a_computed_contradiction(self) -> None:
        results = self._all_required_pass()
        replacements = {
            "identity_lineage": SubtestStatus.INVALID,
            "cost_adjusted_edge": SubtestStatus.FAIL,
        }
        results = [
            _result(item.test_id, replacements[item.test_id])
            if item.test_id in replacements
            else item
            for item in results
        ]
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertIn("cost_adjusted_edge", decision.contradicted_test_ids)

    def test_unknown_archetype_is_insufficient_even_when_universal_tests_pass(self) -> None:
        results = [_result(test.test_id) for test in self.policy.universal_tests]
        decision = aggregate_shadow(
            archetype="new_unreviewed_type", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INSUFFICIENT)
        self.assertIsNone(decision.archetype_resolved)
        self.assertIn("archetype_policy", decision.insufficient_test_ids)

    def test_declared_portfolio_metric_is_ignored_and_cannot_supply_support(self) -> None:
        decision = aggregate_shadow(
            archetype="trend_breakout",
            results=[_result("portfolio_correlation", SubtestStatus.FAIL)],
            policy=self.policy,
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INSUFFICIENT)
        self.assertIn("portfolio_correlation", decision.ignored_test_ids)
        self.assertNotIn("portfolio_correlation", decision.supported_test_ids)

    def test_other_declared_archetype_test_is_ignored(self) -> None:
        results = self._all_required_pass("trend_breakout")
        results.append(_result("tail_loss_amplification", SubtestStatus.FAIL))
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.SUPPORTED)
        self.assertIn("tail_loss_amplification", decision.ignored_test_ids)

    def test_arbitrary_unknown_result_id_is_fail_closed_invalid(self) -> None:
        results = self._all_required_pass("trend_breakout")
        results.append(_result("unregistered_magic_probe"))
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertIn("unknown:unregistered_magic_probe", decision.invalid_test_ids)
        self.assertNotIn("unregistered_magic_probe", decision.ignored_test_ids)

    def test_duplicate_result_is_invalid_not_last_write_wins(self) -> None:
        results = self._all_required_pass()
        results.append(_result("cost_adjusted_edge", SubtestStatus.FAIL))
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertIn("duplicate:cost_adjusted_edge", decision.invalid_test_ids)

    def test_invalid_input_contract_is_invalid(self) -> None:
        results: list = self._all_required_pass()
        results.append({"test_id": "bad_status", "status": "MAYBE"})
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)
        self.assertTrue(any(item.startswith("contract:") for item in decision.invalid_test_ids))

    def test_mapping_result_rejects_extra_fields(self) -> None:
        with self.assertRaisesRegex(ValueError, "unsupported keys"):
            SubtestResult.from_mapping(
                {
                    "test_id": "cost_adjusted_edge",
                    "status": "PASS",
                    "detail": "ok",
                    "evidence": {"pf": 1.2},
                }
            )

    def test_mapping_result_detail_is_optional_and_defaults_empty(self) -> None:
        result = SubtestResult.from_mapping(
            {"test_id": "cost_adjusted_edge", "status": "PASS"}
        )
        self.assertEqual(result.detail, "")

    def test_direct_result_construction_validates_and_normalises(self) -> None:
        result = SubtestResult(test_id="cost_adjusted_edge", status="pass")
        self.assertIs(result.status, SubtestStatus.PASS)
        with self.assertRaisesRegex(ValueError, "lower_snake_case"):
            SubtestResult(test_id="Cost-Edge", status=SubtestStatus.PASS)
        with self.assertRaisesRegex(ValueError, "unsupported status"):
            SubtestResult(test_id="cost_adjusted_edge", status="MAYBE")

    def test_mapping_result_requires_test_id_and_status_keys(self) -> None:
        with self.assertRaisesRegex(ValueError, "missing keys"):
            SubtestResult.from_mapping({"test_id": "cost_adjusted_edge"})

    def test_mapping_result_rejects_non_string_detail(self) -> None:
        with self.assertRaisesRegex(ValueError, "detail must be a string"):
            SubtestResult.from_mapping(
                {"test_id": "cost_adjusted_edge", "status": "PASS", "detail": None}
            )

    def test_mapping_result_rejects_non_string_test_id(self) -> None:
        with self.assertRaisesRegex(ValueError, "test_id must be a string"):
            SubtestResult.from_mapping({"test_id": 8, "status": "PASS"})

    def test_mapping_result_rejects_noncanonical_test_id(self) -> None:
        with self.assertRaisesRegex(ValueError, "lower_snake_case"):
            SubtestResult.from_mapping({"test_id": "Cost-Edge", "status": "PASS"})

    def test_non_object_input_contract_is_invalid(self) -> None:
        results: list = self._all_required_pass()
        results.append(17)
        decision = aggregate_shadow(
            archetype="trend_breakout", results=results, policy=self.policy
        )
        self.assertEqual(decision.verdict, EvidenceVerdict.INVALID)

    def test_same_input_produces_identical_serialised_decision(self) -> None:
        results = self._all_required_pass("basket_cointegration")
        first = aggregate_shadow(
            archetype="pairs", results=results, policy=self.policy
        ).to_dict()
        second = aggregate_shadow(
            archetype="pairs", results=list(reversed(results)), policy=self.policy
        ).to_dict()
        self.assertEqual(first, second)


class Q08V3ShadowSchemaTests(unittest.TestCase):
    def test_schema_contract_matches_python_enums(self) -> None:
        schema_path = (
            Path(__file__).resolve().parents[1]
            / "q08_v3_shadow"
            / "schemas"
            / "q08_shadow_decision_v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertEqual(
            schema["properties"]["schema_version"]["const"], DECISION_SCHEMA_VERSION
        )
        self.assertEqual(
            set(schema["properties"]["verdict"]["enum"]),
            {item.value for item in EvidenceVerdict},
        )
        self.assertEqual(
            set(schema["properties"]["route"]["enum"]),
            {item.value for item in ShadowRoute},
        )
        self.assertEqual(
            schema["properties"]["policy_sha256"]["pattern"],
            "^[0-9a-f]{64}$",
        )

        sample = aggregate_shadow(
            archetype="trend_breakout",
            results=[],
            policy=load_policy(),
        ).to_dict()
        self.assertEqual(set(sample), set(schema["required"]))

    def test_subtest_schema_matches_exact_mapping_contract(self) -> None:
        schema_path = (
            Path(__file__).resolve().parents[1]
            / "q08_v3_shadow"
            / "schemas"
            / "q08_shadow_subtest_result_v1.schema.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        self.assertFalse(schema["additionalProperties"])
        self.assertEqual(set(schema["required"]), {"test_id", "status"})
        self.assertEqual(
            set(schema["properties"]), {"test_id", "status", "detail"}
        )
        self.assertEqual(schema["properties"]["detail"]["default"], "")
        self.assertEqual(
            set(schema["properties"]["status"]["enum"]),
            {item.value for item in SubtestStatus},
        )


if __name__ == "__main__":
    unittest.main()
