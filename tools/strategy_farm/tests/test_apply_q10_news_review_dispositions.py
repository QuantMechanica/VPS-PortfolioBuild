"""Guard tests for the Q10_NEWS review-lane closure tool.

These exercise the parts that must refuse: plan identity, the derived
disposition id, the ``SUCCESSOR_SUPERSESSION`` class never inserting a row, and
the declared residual never acquiring a verdict.  No farm database is opened
and nothing is applied.
"""

import copy
import json
import sys
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import apply_q10_news_review_dispositions as tool  # noqa: E402
import q09_news_contract as contract  # noqa: E402


def _target(source_id: str, klass: str, **extra) -> dict:
    base = {
        "schema": tool.ROW_SCHEMA,
        "source_work_item_id": source_id,
        "source_identity_sha256": "0" * 64,
        "ea_id": "QM5_10000",
        "symbol": "EURUSD.DWX",
        "setfile_path": "x.set",
        "created_at": "2026-08-23T16:25:00+00:00",
        "gate_contract_version": "v4",
        "disposition_class": klass,
        "verdict": "INVALID_EVIDENCE",
        "verdict_reason": "Q10_NEWS_SEALED_READJUDICATION_INVALID_EVIDENCE",
        "disposition_work_item_id": tool.disposition_id(source_id),
    }
    base.update(extra)
    return base


def _residual(source_id: str) -> dict:
    return {
        "schema": tool.ROW_SCHEMA,
        "source_work_item_id": source_id,
        "source_identity_sha256": "0" * 64,
        "ea_id": "QM5_10000",
        "symbol": "EURUSD.DWX",
        "setfile_path": "x.set",
        "created_at": "2026-08-23T16:25:00+00:00",
        "gate_contract_version": "v4",
        "disposition_class": tool.RESIDUAL_CLASS,
        "verdict": None,
        "verdict_reason": "Q10_NEWS_CURRENT_RULE_STILL_REVIEW_REQUIRED",
    }


def _plan() -> dict:
    targets: list[dict] = []
    for index in range(tool.EXPECTED_CLASS_COUNTS[tool.CLASS_SUCCESSOR]):
        targets.append(_target(
            f"succ-{index}", tool.CLASS_SUCCESSOR,
            verdict="CONFIG_LOCKED",
            verdict_reason="Q10_NEWS_GOVERNED_READJUDICATION_SUCCESSOR",
            disposition_work_item_id=None,
            successor_work_item_id=f"successor-{index}",
        ))
    for index in range(tool.EXPECTED_CLASS_COUNTS[tool.CLASS_SEALED]):
        targets.append(_target(f"sealed-{index}", tool.CLASS_SEALED))
    for index in range(tool.EXPECTED_CLASS_COUNTS[tool.CLASS_AGED_OUT]):
        targets.append(_target(
            f"aged-{index}", tool.CLASS_AGED_OUT,
            verdict_reason="EVIDENCE_AGED_OUT_DL090",
        ))
    residuals = [_residual(f"residual-{i}") for i in range(tool.EXPECTED_RESIDUAL_COUNT)]
    plan = {
        "schema": tool.PLAN_SCHEMA,
        "disposition_id": tool.DISPOSITION_ID,
        "news_phase": tool.NEWS_PHASE,
        "evidence_path": str(tool.EVIDENCE_PATH),
        "evidence_sha256": tool.sha256_file(tool.EVIDENCE_PATH),
        "contract_module_sha256": tool.sha256_file(Path(contract.__file__).resolve()),
        "class_counts": dict(tool.EXPECTED_CLASS_COUNTS),
        "residual_class": tool.RESIDUAL_CLASS,
        "residual_count": len(residuals),
        "targets": targets,
        "residuals": residuals,
    }
    plan["targets_sha256"] = tool.sha256_bytes(tool.canonical_bytes(targets))
    plan["residuals_sha256"] = tool.sha256_bytes(tool.canonical_bytes(residuals))
    return plan


class PlanShapeTests(unittest.TestCase):
    def test_reference_plan_validates(self):
        tool.validate_plan(_plan())

    def test_scope_is_the_full_lane(self):
        self.assertEqual(
            tool.EXPECTED_TOTAL,
            sum(tool.EXPECTED_CLASS_COUNTS.values()) + tool.EXPECTED_RESIDUAL_COUNT,
        )
        self.assertEqual(tool.EXPECTED_TOTAL, 95)

    def test_evidence_document_exists(self):
        self.assertTrue(tool.EVIDENCE_PATH.is_file(), tool.EVIDENCE_PATH)

    def test_disposition_id_is_derived_and_stable(self):
        first = tool.disposition_id("abc")
        self.assertEqual(first, tool.disposition_id("abc"))
        self.assertNotEqual(first, tool.disposition_id("abd"))

    def test_tampered_target_manifest_is_refused(self):
        plan = _plan()
        plan["targets"][0]["verdict_reason"] = "tampered"
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_tampered_residual_manifest_is_refused(self):
        plan = _plan()
        plan["residuals"][0]["ea_id"] = "QM5_99999"
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_wrong_phase_is_refused(self):
        plan = _plan()
        plan["news_phase"] = "Q09_NEWS"
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_successor_class_may_not_insert_a_work_item(self):
        plan = _plan()
        for target in plan["targets"]:
            if target["disposition_class"] == tool.CLASS_SUCCESSOR:
                target["disposition_work_item_id"] = tool.disposition_id(
                    target["source_work_item_id"]
                )
                break
        plan["targets_sha256"] = tool.sha256_bytes(tool.canonical_bytes(plan["targets"]))
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_successor_class_needs_a_successor(self):
        plan = _plan()
        for target in plan["targets"]:
            if target["disposition_class"] == tool.CLASS_SUCCESSOR:
                target["successor_work_item_id"] = ""
                break
        plan["targets_sha256"] = tool.sha256_bytes(tool.canonical_bytes(plan["targets"]))
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_residual_may_never_carry_a_verdict(self):
        plan = _plan()
        plan["residuals"][0]["verdict"] = "INVALID_EVIDENCE"
        plan["residuals_sha256"] = tool.sha256_bytes(
            tool.canonical_bytes(plan["residuals"])
        )
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_residual_may_not_also_be_a_target(self):
        plan = _plan()
        plan["residuals"][0]["source_work_item_id"] = "sealed-0"
        plan["residuals_sha256"] = tool.sha256_bytes(
            tool.canonical_bytes(plan["residuals"])
        )
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_non_terminal_verdict_is_refused(self):
        plan = _plan()
        plan["targets"][-1]["verdict"] = "REVIEW_REQUIRED"
        plan["targets_sha256"] = tool.sha256_bytes(tool.canonical_bytes(plan["targets"]))
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_class_distribution_drift_is_refused(self):
        plan = _plan()
        plan["class_counts"] = {**tool.EXPECTED_CLASS_COUNTS, tool.CLASS_SEALED: 1}
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_adjudication_contract_drift_is_refused(self):
        plan = _plan()
        plan["contract_module_sha256"] = "f" * 64
        with self.assertRaises(tool.DispositionError):
            tool.validate_plan(plan)

    def test_apply_refuses_a_plan_whose_bytes_do_not_match_the_hash(self):
        with TemporaryDirectory() as tmp:
            plan_path = Path(tmp) / "plan.json"
            plan_path.write_text(json.dumps(_plan()), encoding="utf-8")
            with self.assertRaises(tool.DispositionError):
                tool.apply_plan(
                    db=Path(tmp) / "absent.sqlite",
                    plan_path=plan_path,
                    expected_plan_sha256="a" * 64,
                    receipt_out=Path(tmp) / "receipt.json",
                    backup_dir=Path(tmp),
                    mutation_lock=Path(tmp) / "lock",
                    artifact_root=Path(tmp) / "artifacts",
                )

    def test_write_new_json_never_overwrites(self):
        with TemporaryDirectory() as tmp:
            path = Path(tmp) / "out.json"
            tool.write_new_json(path, {"a": 1})
            with self.assertRaises(tool.DispositionError):
                tool.write_new_json(path, {"a": 2})
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), {"a": 1})

    def test_plan_copy_is_not_mutated_by_validation(self):
        plan = _plan()
        before = copy.deepcopy(plan)
        tool.validate_plan(plan)
        self.assertEqual(plan, before)


if __name__ == "__main__":
    unittest.main()
