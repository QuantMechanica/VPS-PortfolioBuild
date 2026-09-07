from __future__ import annotations

import hashlib
import json
from pathlib import Path

from tools.strategy_farm import news_calendar_scoped_activation as activation
from tools.strategy_farm import q09_news_runner as runner
from tools.strategy_farm import scoped_q10_wave2 as wave2


def _write(path: Path, value: object) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(runner.contract.canonical_json_bytes(value))
    return hashlib.sha256(path.read_bytes()).hexdigest()


def test_wave2_allowlist_is_exact_and_disjoint() -> None:
    assert len(wave2.SCOPED_IDS) == 8
    assert len(wave2.ABORT_IDS) == 2
    assert len(wave2.ALLOWLIST) == len(set(wave2.ALLOWLIST)) == 10


def test_converted_scoped_row_uses_ordinary_plan_window(tmp_path: Path) -> None:
    manifest = tmp_path / "input_manifest.json"
    manifest_sha = _write(
        manifest,
        {"windows": {
            "full_from_utc": "2015-01-01T00:00:00+00:00",
            "full_to_utc": "2025-12-31T23:59:59+00:00",
        }},
    )
    plan = tmp_path / "run_plan.json"
    plan_value = {"input_manifest_path": str(manifest)}
    plan_sha = _write(plan, plan_value)
    seal = {"seal_sha256": "a" * 64}
    payload = {
        "scoped_q10_window_seal": seal,
        "q09_run_plan_path": str(plan),
        "q09_run_plan_file_sha256": plan_sha,
        "q09_input_manifest_sha256": manifest_sha,
        "q09_activation_state": "RUNNABLE_BOUND",
        "terminal_claimable": True,
        "scoped_review_only": False,
    }
    payload["scoped_q10_plan_activation"] = wave2._activation_marker(payload, seal)
    start, end, bound = activation._sealed_window(payload, {})
    assert start.isoformat() == "2015-01-01T00:00:00+00:00"
    assert end.isoformat() == "2026-01-01T00:00:00+00:00"
    assert bound == manifest_sha

    payload["scoped_q10_plan_activation"]["run_plan_file_sha256"] = "b" * 64
    try:
        activation._sealed_window(payload, {})
    except activation.ActivationError as exc:
        assert "plan activation invalid" in str(exc)
    else:
        raise AssertionError("tampered conversion marker accepted")


def test_scoped_execution_anchor_authenticates_all_bound_files(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    summary = tmp_path / "summary.json"
    baseline = tmp_path / "baseline.set"
    ex5 = tmp_path / "ea.ex5"
    baseline.write_bytes(b"set")
    ex5.write_bytes(b"ex5")
    _write(source, {
        "phase": "Q09", "verdict": "PASS", "symbol": "XAUUSD.DWX",
        "history_from": "2017.01.01", "history_to": "2025.12.31",
    })
    _write(summary, {
        "result": "PASS", "symbol": "XAUUSD.DWX", "period": "D1",
        "from_date": "2017.01.01", "to_date": "2025.12.31",
        "execution_identity": {"expert_binary": {"source": {
            "sha256": hashlib.sha256(ex5.read_bytes()).hexdigest(),
        }}},
    })
    material = {
        "schema_version": "qm.scoped-q10-q09-pass-execution-anchor/v1",
        "scope": "OWNER_B_PRIME_EXACT_ALLOWLIST",
        "pipeline_verdict_created": False,
        "source_work_item_id": "source-q09",
        "source_evidence_path": str(source),
        "source_evidence_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_summary_path": str(summary),
        "source_summary_sha256": hashlib.sha256(summary.read_bytes()).hexdigest(),
        "baseline_run": {
            "period": "D1",
            "baseline_setfile_path": str(baseline),
            "baseline_setfile_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
            "baseline_ex5_sha256": hashlib.sha256(ex5.read_bytes()).hexdigest(),
        },
        "symbol": "XAUUSD.DWX",
    }
    unsigned_sha = hashlib.sha256(runner.contract.canonical_json_bytes(material)).hexdigest()
    anchor = tmp_path / "anchor.json"
    anchor_sha = _write(anchor, {**material, "anchor_sha256": unsigned_sha})
    manifest = {
        "source_paths": {"baseline_setfile": str(baseline)},
        "identities": {
            "q08_work_item_id": "source-q09",
            "q08_evidence_sha256": anchor_sha,
            "baseline_setfile_sha256": material["baseline_run"]["baseline_setfile_sha256"],
            "ex5_sha256": material["baseline_run"]["baseline_ex5_sha256"],
        },
    }
    payload = {"scoped_q09_pass_execution_anchor": {
        "path": str(anchor), "sha256": anchor_sha, "source_work_item_id": "source-q09",
    }}
    assert runner.validate_scoped_q09_pass_execution_anchor(payload, manifest)["source_work_item_id"] == "source-q09"

    source.write_bytes(b"tampered")
    try:
        runner.validate_scoped_q09_pass_execution_anchor(payload, manifest)
    except runner.RunnerError as exc:
        assert "aggregate SHA-256 mismatch" in str(exc)
    else:
        raise AssertionError("tampered source aggregate accepted")
