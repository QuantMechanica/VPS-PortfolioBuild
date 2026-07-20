"""Adversarial integration tests for the nested Freeze-v5 DEV verdict graph."""

from __future__ import annotations

import copy
import hashlib
import json
import sys
from pathlib import Path
from typing import Any

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import generate_research_sets as freeze  # noqa: E402
import validate_research_run as fence  # noqa: E402


CREATED_UTC = "2026-07-20T00:00:00Z"
FREEZE_SHA = "a" * 64
MANIFEST_SHA = "b" * 64


def _canonical(payload: dict[str, Any]) -> bytes:
    return (
        json.dumps(
            payload,
            indent=2,
            sort_keys=True,
            ensure_ascii=True,
            allow_nan=False,
        )
        + "\n"
    ).encode("ascii")


def _payload_sha(payload: Any) -> str:
    raw = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=True,
        allow_nan=False,
    ).encode("ascii")
    return hashlib.sha256(raw).hexdigest()


def _write_artifact(path: Path, payload: dict[str, Any]) -> dict[str, Any]:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = _canonical(payload)
    path.write_bytes(raw)
    digest = hashlib.sha256(raw).hexdigest()
    sidecar = Path(f"{path}.sha256")
    sidecar_raw = f"{digest}  {path.name}\n".encode("ascii")
    sidecar.write_bytes(sidecar_raw)
    return {
        "path": str(path.resolve()),
        "size_bytes": len(raw),
        "sha256": digest,
        "sidecar_path": str(sidecar.resolve()),
        "sidecar_file_sha256": hashlib.sha256(sidecar_raw).hexdigest(),
    }


def _write_verdict(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = _canonical(payload)
    path.write_bytes(raw)
    digest = hashlib.sha256(raw).hexdigest()
    Path(f"{path}.sha256").write_bytes(f"{digest}  {path.name}\n".encode("ascii"))


def _file_binding(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    return {
        "path": str(path.resolve()),
        "size_bytes": len(raw),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def _protocol() -> dict[str, Any]:
    return json.loads(freeze.PROTOCOL.read_text(encoding="utf-8"))


def _build_bundle(tmp_path: Path) -> dict[str, Any]:
    protocol = _protocol()
    root = tmp_path / "freeze_v5"
    evidence_root = root / "evidence"
    verdict_root = root / "verdicts"
    inventory_path = evidence_root / "DEV.receipt_inventory.json"
    evidence_path = evidence_root / "DEV.evidence.json"
    verdict_path = verdict_root / "DEV.verdict.json"
    freeze_identity = {
        "freeze_inputs_sha256": FREEZE_SHA,
        "manifest_sha256": MANIFEST_SHA,
    }
    toolchain = {"fixture": "nested-v5", "version": 1}
    inventory = {
        "schema_version": 1,
        "artifact_type": "QM5_20009_FREEZE_V5_DEV_RECEIPT_INVENTORY",
        "status": "COMPLETE",
        "created_utc": CREATED_UTC,
        "protocol_id": protocol["protocol_id"],
        "phase_id": "DEV",
        "freeze_identity": copy.deepcopy(freeze_identity),
        "matrix_contract": {
            "markets": ["NDX.DWX", "GDAXI.DWX", "GBPUSD.DWX", "EURUSD.DWX"],
            "variants": [
                "center",
                "pivot_low",
                "pivot_high",
                "reclaim_low",
                "reclaim_high",
                "mss_low",
                "mss_high",
                "fvg_low",
                "fvg_high",
                "stop_low",
                "stop_high",
                "rr_low",
                "rr_high",
            ],
            "expected_cells": 52,
            "observed_cells": 52,
            "required_semantic_duplicate_runs_per_cell": 2,
            "duplicate_runs_counted_for_merit": 1,
        },
        "common_toolchain_sha256": _payload_sha(toolchain),
        "common_toolchain": toolchain,
        "cells": [{"cell_id": f"fixture-{index:02d}"} for index in range(52)],
    }
    inventory_binding = _write_artifact(inventory_path, inventory)
    evidence = {
        "schema_version": 1,
        "artifact_type": "QM5_20009_FREEZE_V5_DEV_ADJUDICATION_EVIDENCE",
        "status": "PASS",
        "created_utc": CREATED_UTC,
        "phase_id": "DEV",
        "matrix_status": "COMPLETE_52_OF_52",
        "duplicate_counting_policy": (
            "REPORT_0_ONLY_AFTER_REPORT_0_REPORT_1_SEMANTIC_EQUALITY"
        ),
        "baseline_formula": {"fixture": True},
        "binding_gates": {
            "sleeve_a_center": {"status": "PASS"},
            "sleeve_b_center": {"status": "PASS"},
            "sleeve_a_plateau": {"status": "PASS"},
            "sleeve_b_plateau": {"status": "PASS"},
        },
        "transport_diagnostic": {"selection_effect": "NONE"},
        "mandatory_reported_cells": [
            {"cell_id": f"fixture-{index:02d}"} for index in range(52)
        ],
        "selected_configuration": {
            "sleeve_a": "center",
            "sleeve_b": "center",
            "neighbour_rescue_permitted": False,
        },
        "protocol_id": protocol["protocol_id"],
        "freeze_identity": copy.deepcopy(freeze_identity),
        "inventory_binding": copy.deepcopy(inventory_binding),
        "adjudicator_binding": _file_binding(TOOLS / "adjudicate_dev.py"),
    }
    evidence_binding = _write_artifact(evidence_path, evidence)
    verdict = {
        "schema_version": 1,
        "artifact_type": "QM5_20009_FREEZE_V5_DEV_VERDICT",
        "status": "PASS",
        "verdict": "PASS",
        "created_utc": CREATED_UTC,
        "protocol_id": protocol["protocol_id"],
        "phase_id": "DEV",
        "freeze_identity": copy.deepcopy(freeze_identity),
        "inventory_binding": copy.deepcopy(inventory_binding),
        "evidence_binding": copy.deepcopy(evidence_binding),
        "publication_contract": copy.deepcopy(
            protocol["phase_unlock"]["required_publication_contract"]
        ),
    }
    _write_verdict(verdict_path, verdict)
    return {
        "protocol": protocol,
        "verdict_root": verdict_root,
        "inventory_path": inventory_path,
        "evidence_path": evidence_path,
        "verdict_path": verdict_path,
        "inventory": inventory,
        "evidence": evidence,
        "verdict": verdict,
    }


def _validate(bundle: dict[str, Any]) -> list[dict[str, str]]:
    return fence.validate_phase_unlock(
        bundle["protocol"],
        phase_id="OOS_2023_H1",
        freeze_inputs_sha256=FREEZE_SHA,
        manifest_sha256=MANIFEST_SHA,
        verdict_root=bundle["verdict_root"],
    )


def _rewrite_verdict(bundle: dict[str, Any]) -> None:
    _write_verdict(bundle["verdict_path"], bundle["verdict"])


def _rewrite_evidence_and_rebind(bundle: dict[str, Any]) -> None:
    binding = _write_artifact(bundle["evidence_path"], bundle["evidence"])
    bundle["verdict"]["evidence_binding"] = binding
    _rewrite_verdict(bundle)


def _rewrite_inventory_and_rebind(bundle: dict[str, Any]) -> None:
    binding = _write_artifact(bundle["inventory_path"], bundle["inventory"])
    bundle["evidence"]["inventory_binding"] = copy.deepcopy(binding)
    bundle["verdict"]["inventory_binding"] = copy.deepcopy(binding)
    _rewrite_evidence_and_rebind(bundle)


def test_real_nested_dev_verdict_graph_unlocks_first_oos(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    assert _validate(bundle) == [
        {
            "phase_id": "DEV",
            "record_sha256": hashlib.sha256(bundle["verdict_path"].read_bytes()).hexdigest(),
        }
    ]


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("protocol_id", "WRONG", "identity/status mismatch"),
        ("phase_id", "OOS_2023_H1", "identity/status mismatch"),
        ("status", "FAIL", "identity/status mismatch"),
        ("verdict", "FAIL", "identity/status mismatch"),
        ("created_utc", "2026-07-20T00:00:00", "timestamp with timezone"),
    ],
)
def test_verdict_identity_status_and_timestamp_mismatch_fail_closed(
    tmp_path: Path, field: str, value: str, message: str
) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["verdict"][field] = value
    _rewrite_verdict(bundle)
    with pytest.raises(fence.FenceError, match=message):
        _validate(bundle)


def test_nested_freeze_and_manifest_mismatch_fail_closed(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["verdict"]["freeze_identity"]["manifest_sha256"] = "c" * 64
    _rewrite_verdict(bundle)
    with pytest.raises(fence.FenceError, match="active freeze/manifest"):
        _validate(bundle)


def test_legacy_flat_fields_and_other_schema_extras_are_rejected(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["verdict"]["binding"] = True
    bundle["verdict"]["completed_utc"] = CREATED_UTC
    _rewrite_verdict(bundle)
    with pytest.raises(fence.FenceError, match="fields mismatch"):
        _validate(bundle)


def test_bound_artifact_size_or_hash_drift_is_rejected(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["inventory_path"].write_bytes(bundle["inventory_path"].read_bytes() + b"drift")
    with pytest.raises(fence.FenceError, match="binding drift"):
        _validate(bundle)


def test_detached_sidecar_semantics_are_verified_even_when_its_hash_is_rebound(
    tmp_path: Path,
) -> None:
    bundle = _build_bundle(tmp_path)
    sidecar = Path(f"{bundle['inventory_path']}.sha256")
    sidecar.write_text("0" * 64 + f"  {bundle['inventory_path'].name}\n", encoding="ascii")
    rebound = hashlib.sha256(sidecar.read_bytes()).hexdigest()
    bundle["verdict"]["inventory_binding"]["sidecar_file_sha256"] = rebound
    bundle["evidence"]["inventory_binding"]["sidecar_file_sha256"] = rebound
    _rewrite_evidence_and_rebind(bundle)
    with pytest.raises(fence.FenceError, match="detached hash mismatch"):
        _validate(bundle)


def test_binding_paths_cannot_escape_the_adjudication_output_root(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    escaped = tmp_path / "escaped" / "DEV.receipt_inventory.json"
    escaped_binding = _write_artifact(escaped, bundle["inventory"])
    bundle["verdict"]["inventory_binding"] = copy.deepcopy(escaped_binding)
    bundle["evidence"]["inventory_binding"] = copy.deepcopy(escaped_binding)
    _rewrite_evidence_and_rebind(bundle)
    with pytest.raises(fence.FenceError, match="escapes"):
        _validate(bundle)


def test_bound_inventory_and_evidence_identity_are_revalidated(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["inventory"]["freeze_identity"]["freeze_inputs_sha256"] = "d" * 64
    _rewrite_inventory_and_rebind(bundle)
    with pytest.raises(fence.FenceError, match="active freeze/manifest"):
        _validate(bundle)

    bundle = _build_bundle(tmp_path / "evidence_case")
    bundle["evidence"]["protocol_id"] = "WRONG"
    _rewrite_evidence_and_rebind(bundle)
    with pytest.raises(fence.FenceError, match="evidence identity/status mismatch"):
        _validate(bundle)


def test_adjudicator_binding_and_publication_contract_are_enforced(tmp_path: Path) -> None:
    bundle = _build_bundle(tmp_path)
    bundle["evidence"]["adjudicator_binding"]["sha256"] = "e" * 64
    _rewrite_evidence_and_rebind(bundle)
    with pytest.raises(fence.FenceError, match="binding drift"):
        _validate(bundle)

    bundle = _build_bundle(tmp_path / "publication_case")
    bundle["verdict"]["publication_contract"]["verdict_json_is_final_commit_marker"] = False
    _rewrite_verdict(bundle)
    with pytest.raises(fence.FenceError, match="publication contract mismatch"):
        _validate(bundle)
