"""Adjudicator checks for the retained per-run runtime snapshot closure."""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import adjudicate_dev as adjudicator  # noqa: E402
import validate_research_run as fence  # noqa: E402


FREEZE_IDENTITY = {
    "freeze_inputs_sha256": "a" * 64,
    "manifest_sha256": "b" * 64,
}
REQUEST = {
    "phase": "DEV",
    "symbol": "NDX.DWX",
    "timeframe": "M1",
    "variant": "center",
    "from": "2021-01-01",
    "to": "2022-12-31",
}


def _binding(path: Path) -> dict[str, object]:
    payload = path.read_bytes()
    return {
        "path": str(path.resolve()),
        "size_bytes": len(payload),
        "sha256": hashlib.sha256(payload).hexdigest(),
    }


def _toolchain(
    tmp_path: Path,
    *,
    run_id: str,
    selected_name: str,
    selected_payload: bytes,
    external_rows: list[dict[str, object]],
) -> tuple[dict[str, object], Path]:
    source_root = tmp_path / f"source_{run_id}"
    specs: list[dict[str, object]] = []
    for role in sorted(adjudicator.RUNTIME_SNAPSHOT_ROLES):
        relative = adjudicator.RUNTIME_SNAPSHOT_PATHS[role]
        if role == "selected_set":
            relative = (
                "framework/EAs/QM5_20009_ict-liquidity-portfolio/sets/"
                + selected_name
            )
            payload = selected_payload
        else:
            assert relative is not None
            payload = f"fixed runtime role {role}\n".encode("ascii")
        path = source_root.joinpath(*str(relative).split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
        specs.append(
            {
                "role": role,
                "repo_relative_path": relative,
                "expected_size_bytes": len(payload),
                "expected_sha256": hashlib.sha256(payload).hexdigest(),
            }
        )

    receipt_root = tmp_path / run_id
    receipt_root.mkdir()
    snapshot_root = receipt_root / "runtime_snapshot"
    snapshot = fence.create_runtime_snapshot(
        source_repo_root=source_root,
        snapshot_root=snapshot_root,
        run_id=run_id,
        artifact_type="QM5_20009_RESEARCH_RUNTIME_SNAPSHOT",
        freeze_identity=FREEZE_IDENTITY,
        request=REQUEST,
        selected_set_repo_relative=(
            "framework/EAs/QM5_20009_ict-liquidity-portfolio/sets/" + selected_name
        ),
        file_specs=specs,
    )
    postflight = {
        "schema_version": 1,
        "artifact_type": "QM5_20009_RESEARCH_VALIDATOR_POST_RECEIPT",
        "status": "PASS",
        "run_id": run_id,
        "request": REQUEST,
        "preflight_receipt_sha256": "c" * 64,
        "freeze_inputs_sha256": FREEZE_IDENTITY["freeze_inputs_sha256"],
        "manifest_sha256": FREEZE_IDENTITY["manifest_sha256"],
        "set_sha256": snapshot["role_bindings"]["selected_set"]["sha256"],
        "selected_data_sha256": "d" * 64,
        "phase_unlock_records": [],
        "runtime_snapshot_manifest_sha256": snapshot["manifest_sha256"],
        "external_runtime_sha256": adjudicator.evidence_io.canonical_payload_sha256(
            external_rows
        ),
    }
    return (
        {
            "runtime_snapshot": snapshot,
            "external_runtime": external_rows,
            "postflight": postflight,
            "final_snapshot_verification": dict(postflight),
        },
        snapshot_root,
    )


def test_cell_specific_selected_set_does_not_drift_common_toolchain(tmp_path: Path) -> None:
    external_root = tmp_path / "external"
    external_root.mkdir()
    external_rows: list[dict[str, object]] = []
    for role in sorted(adjudicator.EXTERNAL_RUNTIME_ROLES):
        path = external_root / f"{role}.bin"
        path.write_bytes(f"external {role}\n".encode("ascii"))
        external_rows.append({"role": role, **_binding(path)})

    first_id = "20260720T120000Z_DEV_NDX_center_1111111111111111"
    second_id = "20260720T120001Z_DEV_NDX_pivot_low_2222222222222222"
    first, first_root = _toolchain(
        tmp_path,
        run_id=first_id,
        selected_name="QM5_20009_NDX_DWX_M1_index_center.set",
        selected_payload=b"center\n",
        external_rows=external_rows,
    )
    second, second_root = _toolchain(
        tmp_path,
        run_id=second_id,
        selected_name="QM5_20009_NDX_DWX_M1_index_pivot_low.set",
        selected_payload=b"pivot-low\n",
        external_rows=external_rows,
    )

    first_normalized, first_sha = adjudicator._validate_toolchain(
        first,
        "first.toolchain",
        expected_run_id=first_id,
        expected_snapshot_root=first_root,
    )
    second_normalized, second_sha = adjudicator._validate_toolchain(
        second,
        "second.toolchain",
        expected_run_id=second_id,
        expected_snapshot_root=second_root,
    )

    assert "selected_set" not in first_normalized["runtime_snapshot_roles"]
    assert first_normalized == second_normalized
    assert first_sha == second_sha


def test_adjudicator_rejects_cross_run_snapshot_root(tmp_path: Path) -> None:
    external_root = tmp_path / "external"
    external_root.mkdir()
    external_rows: list[dict[str, object]] = []
    for role in sorted(adjudicator.EXTERNAL_RUNTIME_ROLES):
        path = external_root / f"{role}.bin"
        path.write_bytes(f"external {role}\n".encode("ascii"))
        external_rows.append({"role": role, **_binding(path)})
    run_id = "20260720T120002Z_DEV_NDX_center_3333333333333333"
    toolchain, snapshot_root = _toolchain(
        tmp_path,
        run_id=run_id,
        selected_name="QM5_20009_NDX_DWX_M1_index_center.set",
        selected_payload=b"center\n",
        external_rows=external_rows,
    )

    with pytest.raises(adjudicator.AdjudicationError, match="root_path"):
        adjudicator._validate_toolchain(
            toolchain,
            "cross-run.toolchain",
            expected_run_id=run_id,
            expected_snapshot_root=snapshot_root.parent / "other_snapshot",
        )
