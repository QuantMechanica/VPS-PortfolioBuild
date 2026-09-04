import copy
import hashlib
import sys
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import q09_news_contract as contract  # noqa: E402


def _hash(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _metrics(*, sharpe: float, dd: float = 10.0, pf: float = 1.2, net: float = 100.0,
             affected: int = 0, blocked: int = 0) -> dict:
    return {
        "trades": 30,
        "profit_factor": pf,
        "drawdown_pct": dd,
        "sharpe": sharpe,
        "net_r": net,
        "original_entries": 100,
        "blocked_entries": blocked,
        "affected_entries": affected,
    }


def _cell(arm: str, mode: str, compliance: str, seed: int, *, selection_sharpe: float,
          holdout_sharpe: float, dd: float = 10.0, affected: int = 0,
          receipt: bool = False) -> dict:
    identity = f"{arm}/{mode}/{compliance}/{seed}"
    return {
        "arm": arm,
        "temporal_mode": mode,
        "compliance_mode": compliance,
        "seed": seed,
        "requested_seed": seed,
        "effective_seed": seed,
        "paired_base_identity_sha256": _hash("base"),
        "run_identity_sha256": _hash("run/" + identity),
        "setfile_sha256": _hash("set/" + identity),
        "evidence_sha256": _hash("evidence/" + identity),
        "report_sha256": _hash("report/" + identity),
        "selection": _metrics(sharpe=selection_sharpe, dd=dd, affected=affected),
        "holdout": _metrics(sharpe=holdout_sharpe, dd=dd, affected=affected),
        "full": _metrics(sharpe=(selection_sharpe + holdout_sharpe) / 2, dd=dd, affected=affected),
        "q07_seed_stability_pass": True,
        "flat_at_event_receipt_sha256": _hash("flat/" + identity) if receipt else None,
    }


def evidence(target: str = "DXZ") -> dict:
    target_compliance = contract.compliance_for_target(target)
    cells = []
    for index, seed in enumerate(contract.SEEDS):
        control_selection = 0.50 + index * 0.01
        control_holdout = 0.40 + index * 0.01
        cells.append(
            _cell(
                "CONTROL_OFF", "OFF", "NONE", seed,
                selection_sharpe=control_selection, holdout_sharpe=control_holdout,
            )
        )
        for mode in contract.TEMPORAL_MODES:
            selection_delta = 0.0
            holdout_delta = 0.0
            dd = 10.0
            if mode == "PRE30":
                selection_delta, holdout_delta, dd = 0.08, 0.04, 10.01
            elif mode == "PRE60":
                selection_delta, holdout_delta, dd = 0.12, 0.06, 10.02
            cells.append(
                _cell(
                    "POLICY_ON", mode, target_compliance, seed,
                    selection_sharpe=control_selection + selection_delta,
                    holdout_sharpe=control_holdout + holdout_delta,
                    dd=dd,
                )
            )
    return {
        "schema_version": contract.SCHEMA_VERSION,
        "work_item_id": "wi-q09-news",
        "deployment_target": target,
        "identities": {
            "q08_work_item_id": "wi-q08",
            "q08_evidence_sha256": _hash("q08"),
            "baseline_setfile_sha256": _hash("baseline"),
            "ex5_sha256": _hash("ex5"),
            "include_closure_sha256": _hash("include"),
            "paired_base_identity_sha256": _hash("base"),
        },
        "calendar_bundle": {
            "bundle_id": "q09cal-test",
            "manifest_sha256": _hash("manifest"),
            "content_sha256": _hash("calendar"),
            "coverage_from_utc": "2019-12-01T00:00:00Z",
            "coverage_to_utc": "2025-02-01T00:00:00Z",
        },
        "windows": {
            "full_from_utc": "2020-01-01T00:00:00Z",
            "full_to_utc": "2025-01-01T00:00:00Z",
            "selection_from_utc": "2020-01-01T00:00:00Z",
            "selection_to_utc": "2022-12-31T23:59:59Z",
            "holdout_from_utc": "2023-01-01T00:00:00Z",
            "holdout_to_utc": "2025-01-01T00:00:00Z",
            "complete_months": 60,
            "holdout_complete_months": 24,
            "holdout_sealed": True,
        },
        "news_or_event_strategy": False,
        "cells": cells,
    }


def expand_all_compliances(payload: dict) -> None:
    target = contract.compliance_for_target(payload["deployment_target"])
    existing = {
        (cell["arm"], cell["temporal_mode"], cell["compliance_mode"], cell["seed"])
        for cell in payload["cells"]
    }
    target_cells = {
        (cell["temporal_mode"], cell["seed"]): cell
        for cell in payload["cells"]
        if cell["arm"] == "POLICY_ON" and cell["compliance_mode"] == target
    }
    for compliance in contract.COMPLIANCE_MODES:
        for mode in contract.TEMPORAL_MODES:
            for seed in contract.SEEDS:
                key = ("POLICY_ON", mode, compliance, seed)
                if key in existing:
                    continue
                source = target_cells[(mode, seed)]
                clone = copy.deepcopy(source)
                clone["compliance_mode"] = compliance
                identity = f"POLICY_ON/{mode}/{compliance}/{seed}"
                clone["run_identity_sha256"] = _hash("run/" + identity)
                clone["setfile_sha256"] = _hash("set/" + identity)
                clone["evidence_sha256"] = _hash("evidence/" + identity)
                clone["report_sha256"] = _hash("report/" + identity)
                payload["cells"].append(clone)


class Q09NewsContractV2Tests(unittest.TestCase):
    def test_robust_best_policy_is_locked_with_two_arms(self) -> None:
        result = contract.adjudicate(evidence())
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["chosen_config"]["temporal_mode"], "PRE60")
        self.assertEqual({arm["arm"] for arm in result["locked_arms"]}, {"CONTROL_OFF", "POLICY_ON"})
        self.assertEqual(result["matrix_scope"], "7x1_target_compliance")

    def test_no_robust_improvement_locks_off_with_required_compliance(self) -> None:
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "POLICY_ON":
                seed_index = contract.SEEDS.index(cell["seed"])
                cell["selection"]["sharpe"] = 0.50 + seed_index * 0.01
                cell["holdout"]["sharpe"] = 0.40 + seed_index * 0.01
        result = contract.adjudicate(payload)
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["chosen_config"], {
            "temporal_mode": "OFF",
            "temporal_mode_id": 0,
            "compliance_mode": "DXZ",
            "setfile_sha256s": result["chosen_config"]["setfile_sha256s"],
        })
        self.assertEqual(result["reason_codes"], ["off_fallback_no_robust_improvement"])

    def test_effective_seed_mismatch_is_invalid_evidence(self) -> None:
        payload = evidence()
        payload["cells"][0]["effective_seed"] = 123
        result = contract.adjudicate(payload)
        self.assertEqual(result["verdict"], "INVALID_EVIDENCE")
        self.assertIn("seed authentication", result["details"]["error"])

    def test_unsealed_or_short_holdout_is_invalid(self) -> None:
        payload = evidence()
        payload["windows"]["holdout_complete_months"] = 23
        result = contract.adjudicate(payload)
        self.assertEqual(result["verdict"], "INVALID_EVIDENCE")

    def test_close_all_pre_is_unselectable_without_flat_receipts(self) -> None:
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "POLICY_ON":
                seed_index = contract.SEEDS.index(cell["seed"])
                delta = 0.20 if cell["temporal_mode"] == "CLOSE_ALL_PRE" else 0.0
                cell["selection"]["sharpe"] = 0.50 + seed_index * 0.01 + delta
                cell["holdout"]["sharpe"] = 0.40 + seed_index * 0.01 + delta
                cell["full"]["drawdown_pct"] = 10.0
        result = contract.adjudicate(payload)
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["chosen_config"]["temporal_mode"], "OFF")
        close_score = next(row for row in result["ranking"] if row["temporal_mode"] == "CLOSE_ALL_PRE")
        self.assertIn("close_all_pre_missing_flat_at_event_receipt", close_score["rejection_reasons"])

    def test_single_target_material_effect_locks_target_column(self) -> None:
        # OWNER-DEC-NEWSGATE-AE-20260904 (e): a single-target (DXZ) deployment
        # locks on the target column even when material_effect fires; it does
        # not demand the absent 7x4 matrix.
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "POLICY_ON" and cell["temporal_mode"] == "PRE60":
                cell["selection"]["affected_entries"] = 10
                cell["holdout"]["affected_entries"] = 10
                cell["full"]["affected_entries"] = 10
        locked = contract.adjudicate(payload)
        self.assertEqual(locked["verdict"], "CONFIG_LOCKED")
        self.assertEqual(locked["chosen_config"]["temporal_mode"], "PRE60")
        self.assertEqual(locked["chosen_config"]["compliance_mode"], "DXZ")
        self.assertEqual(locked["matrix_scope"], "7x1_target_compliance")
        self.assertEqual(locked["expansion_policy"], "single_target_lock")
        self.assertNotIn("material_effect", locked["expansion_reasons"])
        self.assertTrue(locked["material_effect"]["material"])
        # When the full 4-compliance matrix is actually present (force-expanded /
        # on-demand), the same single target still locks and records 7x4 scope.
        expand_all_compliances(payload)
        expanded = contract.adjudicate(payload)
        self.assertEqual(expanded["verdict"], "CONFIG_LOCKED")
        self.assertEqual(expanded["matrix_scope"], "7x4")

    def test_control_not_qualifiable_review_carries_target_compliance_label(self) -> None:
        # OWNER-DEC-NEWSGATE-AE-20260904 (a): the control-off REVIEW dict now
        # carries target_compliance and a hard 7x1_target_compliance scope
        # instead of defaulting to NONE at the persistence writer.
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "CONTROL_OFF":
                cell["selection"]["profit_factor"] = 0.9
        result = contract.adjudicate(payload)
        self.assertEqual(result["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(
            result["reason_codes"], ["control_or_policy_off_not_qualifiable"]
        )
        self.assertEqual(result["target_compliance"], "DXZ")
        self.assertEqual(result["matrix_scope"], "7x1_target_compliance")

    def test_prop_target_always_requires_7x4_but_selects_fixed_target_policy(self) -> None:
        payload = evidence("FTMO")
        review = contract.adjudicate(payload)
        self.assertEqual(review["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(review["reason_codes"], ["expanded_7x4_matrix_required"])
        # (a) label fix: the expanded REVIEW dict carries the compliance label
        # and 7x4 scope; (e) records the multi-target expansion policy.
        self.assertEqual(review["target_compliance"], "FTMO")
        self.assertEqual(review["matrix_scope"], "7x4")
        self.assertEqual(review["expansion_policy"], "multi_target_full_matrix")
        expand_all_compliances(payload)
        locked = contract.adjudicate(payload)
        self.assertEqual(locked["verdict"], "CONFIG_LOCKED")
        self.assertEqual(locked["chosen_config"]["compliance_mode"], "FTMO")

    def test_practical_tie_prefers_less_intervention(self) -> None:
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] != "POLICY_ON":
                continue
            seed_index = contract.SEEDS.index(cell["seed"])
            if cell["temporal_mode"] in {"PRE30", "PRE60"}:
                delta = 0.10 if cell["temporal_mode"] == "PRE30" else 0.11
                cell["selection"]["sharpe"] = 0.50 + seed_index * 0.01 + delta
                cell["holdout"]["sharpe"] = 0.40 + seed_index * 0.01 + delta
                cell["full"]["drawdown_pct"] = 10.01
            else:
                cell["selection"]["sharpe"] = 0.50 + seed_index * 0.01
                cell["holdout"]["sharpe"] = 0.40 + seed_index * 0.01
                cell["full"]["drawdown_pct"] = 10.0
        result = contract.adjudicate(payload)
        self.assertEqual(result["chosen_config"]["temporal_mode"], "PRE30")

    def test_v3_one_seed_fans_into_unchanged_selector(self) -> None:
        payload = evidence()
        payload["schema_version"] = contract.SCHEMA_VERSION_V3
        payload["cells"] = [
            cell for cell in payload["cells"] if cell["seed"] == contract.V3_SEED
        ]

        result = contract.adjudicate(payload)

        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["schema_version"], contract.ADJUDICATION_SCHEMA_VERSION_V3)
        self.assertEqual(result["chosen_config"]["temporal_mode"], "PRE60")
        self.assertEqual(result["seed_provenance"]["executed_seed_set"], [17])
        self.assertEqual(result["seed_provenance"]["selector_seed_set"], list(contract.SEEDS))
        self.assertTrue(result["seed_provenance"]["inert_seed_fanout"])

    def test_v3_single_target_material_effect_locks_target_column(self) -> None:
        payload = evidence()
        payload["schema_version"] = contract.SCHEMA_VERSION_V3
        payload["cells"] = [
            cell for cell in payload["cells"] if cell["seed"] == contract.V3_SEED
        ]
        for cell in payload["cells"]:
            if cell["arm"] == "POLICY_ON" and cell["temporal_mode"] == "PRE60":
                cell["full"]["affected_entries"] = 10

        result = contract.adjudicate(payload)

        # (e) single-target lazy expansion also holds under the v3 inert fan-out.
        self.assertEqual(result["verdict"], "CONFIG_LOCKED")
        self.assertEqual(result["expansion_policy"], "single_target_lock")
        self.assertEqual(result["matrix_scope"], "7x1_target_compliance")
        self.assertNotIn("material_effect", result["expansion_reasons"])
        self.assertTrue(result["material_effect"]["material"])

    def test_control_not_qualifiable_review_carries_compliance_labels(self) -> None:
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "CONTROL_OFF":
                cell["selection"]["profit_factor"] = 0.9
        review = contract.adjudicate(payload)
        self.assertEqual(review["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(review["reason_codes"], ["control_or_policy_off_not_qualifiable"])
        self.assertEqual(review["target_compliance"], "DXZ")
        self.assertEqual(review["matrix_scope"], "7x1_target_compliance")



def _me_metrics(*, original, affected=0, blocked=0, net=100.0, pf=1.2, dd=10.0):
    return {
        "trades": 30,
        "profit_factor": pf,
        "drawdown_pct": dd,
        "sharpe": 0.5,
        "net_r": net,
        "original_entries": original,
        "blocked_entries": blocked,
        "affected_entries": affected,
    }


def _me_cell(arm, mode, seed, *, full):
    identity = f"{arm}/{mode}/{seed}"
    return contract.Cell.from_mapping(
        {
            "arm": arm,
            "temporal_mode": "OFF" if arm == "CONTROL_OFF" else mode,
            "compliance_mode": "NONE" if arm == "CONTROL_OFF" else "DXZ",
            "seed": seed,
            "requested_seed": seed,
            "effective_seed": seed,
            "paired_base_identity_sha256": _hash("base"),
            "run_identity_sha256": _hash("run/" + identity),
            "setfile_sha256": _hash("set/" + identity),
            "evidence_sha256": _hash("evidence/" + identity),
            "report_sha256": _hash("report/" + identity),
            "selection": full,
            "holdout": full,
            "full": full,
            "q07_seed_stability_pass": True,
            "flat_at_event_receipt_sha256": None,
        },
        0,
    )


class MaterialEffectAffectedEntriesTests(unittest.TestCase):
    """TASK (c) OWNER-DEC-NEWSGATE-AE-20260904: the affected_entries component
    counts entries the temporal news mode removes from the OFF/NONE control's
    entry set -- explicit QM_ENTRY_REJECTED_NEWS markers
    (Metrics.affected_entries) plus the drop in original_entries relative to
    the control -- evaluated against the unchanged
    max(3, ceil(0.05 * control_original_entries)) threshold.  With
    control_original_entries=100 across five seeds the threshold is
    max(3, ceil(0.05 * 500)) = 25."""

    def _material(self, policy_original, *, control_original=100,
                  policy_affected=0, policy_blocked=0):
        originals = (
            list(policy_original)
            if isinstance(policy_original, (list, tuple))
            else [policy_original] * len(contract.SEEDS)
        )
        control = {}
        policy = []
        for seed, p_orig in zip(contract.SEEDS, originals):
            control[seed] = _me_cell(
                "CONTROL_OFF", "OFF", seed,
                full=_me_metrics(original=control_original),
            )
            policy.append(
                _me_cell(
                    "POLICY_ON", "PRE60", seed,
                    full=_me_metrics(
                        original=p_orig,
                        affected=policy_affected,
                        blocked=policy_blocked,
                    ),
                )
            )
        return contract._material_effect({"PRE60": policy}, control)

    def test_counter_counts_suppressed_entries_when_marker_is_zero(self):
        # SKIP_DAY-style suppression: original_entries collapse but the EA
        # emits no block marker.  The prior wiring read 0; the counter must
        # now equal the control-relative drop (5 seeds x (100 - 90) = 50).
        result = self._material(90)
        self.assertEqual(result["max_affected_entries"], 50)
        self.assertIn("affected_entries", result["reasons"])
        self.assertTrue(result["material"])

    def test_counter_is_sum_of_marker_and_suppression(self):
        # 5 seeds x (drop 5 + 4 flagged markers) = 25 + 20 = 45, computed
        # from the fixture cells' original_entries and affected_entries.
        result = self._material(95, policy_affected=4)
        self.assertEqual(result["max_affected_entries"], 45)
        self.assertIn("affected_entries", result["reasons"])

    def test_marker_only_channel_is_preserved(self):
        # No suppression (original unchanged), 10 markers per seed -> 50.
        # Guards that the explicit-marker path the existing suite exercises
        # still fires after the rewire.
        result = self._material(100, policy_affected=10)
        self.assertEqual(result["max_affected_entries"], 50)
        self.assertIn("affected_entries", result["reasons"])

    def test_threshold_fires_at_and_above_but_not_below(self):
        # threshold = max(3, ceil(0.05 * 500)) = 25
        just_below = self._material([96, 96, 96, 96, 92])  # drop 24
        self.assertEqual(just_below["max_affected_entries"], 24)
        self.assertNotIn("affected_entries", just_below["reasons"])
        self.assertFalse(just_below["material"])

        at_threshold = self._material(95)  # drop 25
        self.assertEqual(at_threshold["max_affected_entries"], 25)
        self.assertIn("affected_entries", at_threshold["reasons"])

        above = self._material(90)  # drop 50
        self.assertEqual(above["max_affected_entries"], 50)
        self.assertIn("affected_entries", above["reasons"])

    def test_five_percent_floor_of_three_dominates_at_small_counts(self):
        # control_original=8 -> off_entries=40 -> 0.05*40=2 -> max(3, 2)=3.
        below_floor = self._material([8, 8, 8, 8, 6], control_original=8)
        self.assertEqual(below_floor["max_affected_entries"], 2)  # drop 2
        self.assertNotIn("affected_entries", below_floor["reasons"])

        at_floor = self._material([8, 8, 8, 8, 5], control_original=8)
        self.assertEqual(at_floor["max_affected_entries"], 3)  # drop 3
        self.assertIn("affected_entries", at_floor["reasons"])

    def test_marker_inside_original_is_not_double_counted(self):
        # Block markers stay inside original_entries, so a pure block mode
        # (original unchanged, markers > 0) counts only the markers and never
        # adds a spurious suppression term.
        result = self._material(100, policy_affected=6, policy_blocked=6)
        self.assertEqual(result["max_affected_entries"], 30)  # 5 x 6, no drop
        self.assertIn("affected_entries", result["reasons"])


if __name__ == "__main__":
    unittest.main()
