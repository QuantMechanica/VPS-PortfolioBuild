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

    def test_material_effect_requires_expanded_matrix(self) -> None:
        payload = evidence()
        for cell in payload["cells"]:
            if cell["arm"] == "POLICY_ON" and cell["temporal_mode"] == "PRE60":
                cell["selection"]["affected_entries"] = 10
                cell["holdout"]["affected_entries"] = 10
                cell["full"]["affected_entries"] = 10
        review = contract.adjudicate(payload)
        self.assertEqual(review["verdict"], "REVIEW_REQUIRED")
        self.assertEqual(review["reason_codes"], ["expanded_7x4_matrix_required"])
        expand_all_compliances(payload)
        locked = contract.adjudicate(payload)
        self.assertEqual(locked["verdict"], "CONFIG_LOCKED")
        self.assertEqual(locked["matrix_scope"], "7x4")

    def test_prop_target_always_requires_7x4_but_selects_fixed_target_policy(self) -> None:
        payload = evidence("FTMO")
        review = contract.adjudicate(payload)
        self.assertEqual(review["verdict"], "REVIEW_REQUIRED")
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


if __name__ == "__main__":
    unittest.main()
