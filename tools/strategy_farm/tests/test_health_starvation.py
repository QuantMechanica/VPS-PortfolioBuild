"""Locks the RATIFIED starvation-check payload contract in health.py (2026-07-26,
batch-3 adversarial review): only valid JSON objects count, keys are read at top
level only, verdict comparison is case-sensitive. These tests pin the deliberate
divergences from the legacy SQL LIKE substring semantics (format-sensitive on
JSON spacing yet case-insensitive on the verdict)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from health import _count_starved_builds, _parse_task_payload  # noqa: E402


def _t(id_, kind, status, payload):
    return {"id": id_, "kind": kind, "status": status, "payload_json": payload}


BUILD = _t("b1", "build_ea", "done", "{}")
CODEX_PASS = _t("c1", "codex_review", "done", '{"build_task_id": "b1", "verdict": "PASS"}')


def test_canonical_pass_without_ea_review_is_starved():
    assert _count_starved_builds([BUILD, CODEX_PASS]) == 1


def test_ea_review_of_any_status_covers():
    for status in ("pending", "in_progress", "failed", "done"):
        rows = [BUILD, CODEX_PASS, _t("r1", "ea_review", status, '{"build_task_id": "b1"}')]
        assert _count_starved_builds(rows) == 0


def test_malformed_codex_json_is_ignored():
    # legacy LIKE counted raw substrings inside broken JSON; ratified contract drops it
    rows = [BUILD, _t("c1", "codex_review", "done",
                      '{"build_task_id": "b1", "verdict": "PASS"')]  # truncated JSON
    assert _count_starved_builds(rows) == 0


def test_compact_json_counts():
    # legacy LIKE missed compact separators; ratified contract parses any valid JSON
    rows = [BUILD, _t("c1", "codex_review", "done", '{"build_task_id":"b1","verdict":"PASS"}')]
    assert _count_starved_builds(rows) == 1


def test_lowercase_verdict_does_not_count():
    rows = [BUILD, _t("c1", "codex_review", "done", '{"build_task_id": "b1", "verdict": "pass"}')]
    assert _count_starved_builds(rows) == 0


def test_nested_build_task_id_does_not_count():
    rows = [BUILD, _t("c1", "codex_review", "done",
                      '{"verdict": "PASS", "meta": {"build_task_id": "b1"}}')]
    assert _count_starved_builds(rows) == 0


def test_malformed_ea_review_does_not_cover():
    rows = [BUILD, CODEX_PASS, _t("r1", "ea_review", "done", 'build_task_id: "b1"')]
    assert _count_starved_builds(rows) == 1


def test_pending_codex_review_does_not_count():
    rows = [BUILD, _t("c1", "codex_review", "pending",
                      '{"build_task_id": "b1", "verdict": "PASS"}')]
    assert _count_starved_builds(rows) == 0


def test_non_object_payloads_are_ignored():
    assert _parse_task_payload('["build_task_id", "b1"]') is None
    assert _parse_task_payload("") is None
    assert _parse_task_payload(None) is None
    assert _parse_task_payload('"PASS"') is None


def test_non_string_build_task_id_is_ignored_not_crash():
    # Batch-4 probe: list/dict-valued build_task_id raised TypeError (unhashable)
    # instead of not matching. Ratified: build_task_id must be a non-empty string.
    for bad in ('["b1"]', '{"id": "b1"}', "null", '""'):
        codex = _t("c1", "codex_review", "done",
                   '{"build_task_id": ' + bad + ', "verdict": "PASS"}')
        assert _count_starved_builds([BUILD, codex]) == 0
        review = _t("r1", "ea_review", "done", '{"build_task_id": ' + bad + "}")
        assert _count_starved_builds([BUILD, CODEX_PASS, review]) == 1


def test_compact_ea_review_json_covers():
    # Completes the batch-3 divergence table: compact ea_review JSON covers the
    # build under the ratified contract (the legacy LIKE missed it).
    rows = [BUILD, CODEX_PASS, _t("r1", "ea_review", "done", '{"build_task_id":"b1"}')]
    assert _count_starved_builds(rows) == 0
