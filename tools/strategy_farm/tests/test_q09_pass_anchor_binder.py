from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest

from tools.strategy_farm import q09_news_runner as runner
from tools.strategy_farm import q09_pass_anchor_binder as binder


def _basket_row(**overrides: object) -> dict[str, object]:
    payload = {
        "portfolio_scope": "basket",
        "logical_symbol": "QM5_12831_XTI_AUDUSD_BRK_D1",
        "host_symbol": "XTIUSD.DWX",
        "basket_manifest": r"C:\QM\repo\basket_manifest.json",
        "basket_symbols": ["XTIUSD.DWX", "AUDUSD.DWX"],
    }
    payload.update(overrides)
    return {"symbol": "QM5_12831_XTI_AUDUSD_BRK_D1", "payload_json": json.dumps(payload)}


def test_basket_execution_symbol_requires_matching_authenticated_context() -> None:
    source = _basket_row()
    pending = _basket_row()
    assert binder._execution_symbol(source, pending) == "XTIUSD.DWX"

    mismatched = _basket_row(host_symbol="AUDUSD.DWX")
    with pytest.raises(binder.BinderError, match="identity mismatch"):
        binder._execution_symbol(source, mismatched)


def test_q09_autoseal_scope_accepts_distinct_logical_and_execution_symbols(tmp_path: Path) -> None:
    source = tmp_path / "source.json"
    summary = tmp_path / "summary.json"
    baseline = tmp_path / "baseline.set"
    ex5 = tmp_path / "ea.ex5"
    baseline.write_bytes(b"set")
    ex5.write_bytes(b"ex5")
    source.write_bytes(runner.contract.canonical_json_bytes({
        "phase": "Q09", "verdict": "PASS", "symbol": "XTIUSD.DWX",
        "history_from": "2018.07.02", "history_to": "2025.12.31",
    }))
    summary.write_bytes(runner.contract.canonical_json_bytes({
        "result": "PASS", "symbol": "XTIUSD.DWX", "period": "D1",
        "from_date": "2018.07.02", "to_date": "2025.12.31",
        "execution_identity": {"expert_binary": {"source": {
            "sha256": hashlib.sha256(ex5.read_bytes()).hexdigest(),
        }}},
    }))
    material = {
        "schema_version": "qm.scoped-q10-q09-pass-execution-anchor/v1",
        "scope": binder.ANCHOR_SCOPE,
        "pipeline_verdict_created": False,
        "source_work_item_id": "source-q09",
        "source_evidence_path": str(source),
        "source_evidence_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "source_summary_path": str(summary),
        "source_summary_sha256": hashlib.sha256(summary.read_bytes()).hexdigest(),
        "baseline_run": {
            "period": "D1", "baseline_setfile_path": str(baseline),
            "baseline_setfile_sha256": hashlib.sha256(baseline.read_bytes()).hexdigest(),
            "baseline_ex5_sha256": hashlib.sha256(ex5.read_bytes()).hexdigest(),
        },
        "symbol": "QM5_12831_XTI_AUDUSD_BRK_D1",
        "execution_symbol": "XTIUSD.DWX",
    }
    unsigned_sha = hashlib.sha256(runner.contract.canonical_json_bytes(material)).hexdigest()
    anchor = tmp_path / "anchor.json"
    anchor.write_bytes(runner.contract.canonical_json_bytes({**material, "anchor_sha256": unsigned_sha}))
    anchor_sha = hashlib.sha256(anchor.read_bytes()).hexdigest()
    manifest = {
        "source_paths": {"baseline_setfile": str(baseline)},
        "identities": {
            "q08_work_item_id": "source-q09", "q08_evidence_sha256": anchor_sha,
            "baseline_setfile_sha256": material["baseline_run"]["baseline_setfile_sha256"],
            "ex5_sha256": material["baseline_run"]["baseline_ex5_sha256"],
        },
    }
    payload = {"scoped_q09_pass_execution_anchor": {
        "path": str(anchor), "sha256": anchor_sha, "source_work_item_id": "source-q09",
    }}
    assert runner.validate_scoped_q09_pass_execution_anchor(payload, manifest)["execution_symbol"] == "XTIUSD.DWX"
