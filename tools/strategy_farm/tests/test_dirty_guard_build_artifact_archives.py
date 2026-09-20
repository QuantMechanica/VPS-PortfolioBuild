"""Dirty-guard classification of build-lane review-fail archives and the
evidence-cohort baseline (2026-09-20)."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import farmctl  # noqa: E402


def test_build_result_and_archive_are_generated():
    assert farmctl._generated_recurring_doc_kind("artifacts/qm5_41257_build_result_20260831.json") == "generated_build_result_archive"
    assert farmctl._generated_recurring_doc_kind(
        "artifacts/qm5_41257_build_result_20260831.codex_review_fail_attempt_1.json"
    ) == "generated_build_result_archive"
    assert farmctl._generated_recurring_doc_kind("artifacts/evidence_cohort_baseline.json") == "generated_evidence_cohort_baseline"


def test_other_artifacts_still_block():
    assert farmctl._generated_recurring_doc_kind("artifacts/qm5_41257_magic_allocation_20260831.json") is None
    assert farmctl._generated_recurring_doc_kind("artifacts/receipts/anything.json") is None
    assert farmctl._generated_recurring_doc_kind("docs/ops/OPEN_ITEMS_STATUS.md") is None


def test_generator_named_for_health_detail():
    assert "evidence_cohort_watch" in farmctl._known_generator_for_path("artifacts/evidence_cohort_baseline.json")
