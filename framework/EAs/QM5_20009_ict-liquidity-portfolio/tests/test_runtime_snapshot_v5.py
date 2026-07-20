"""Tamper tests for the immutable per-run Freeze-v5 runtime snapshot."""

from __future__ import annotations

import copy
import hashlib
import json
import os
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[1]
TOOLS = EA_ROOT / "tools"
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import validate_research_run as fence  # noqa: E402


RUN_ID = "20260720T120000Z_DEV_NDX_DWX_center_0123456789abcdef0123456789abcdef"
ARTIFACT_TYPE = "QM5_20009_RESEARCH_RUNTIME_SNAPSHOT"
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


def _snapshot_fixture(tmp_path: Path) -> tuple[Path, Path, list[dict[str, object]], dict]:
    source_root = tmp_path / "moving_workspace"
    source_payloads = {
        "framework/scripts/run_smoke.ps1": b"runner-v1\n",
        "framework/EAs/QM5_20009/EA.ex5": b"binary-v1\n",
        "framework/EAs/QM5_20009/sets/selected.set": b"set-v1\n",
    }
    specs: list[dict[str, object]] = []
    roles = ("runner_smoke", "ea_binary", "selected_set")
    for role, (relative, payload) in zip(roles, source_payloads.items(), strict=True):
        path = source_root / relative
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
    run_root = tmp_path / RUN_ID
    run_root.mkdir()
    snapshot_root = run_root / "runtime_snapshot"
    binding = fence.create_runtime_snapshot(
        source_repo_root=source_root,
        snapshot_root=snapshot_root,
        run_id=RUN_ID,
        artifact_type=ARTIFACT_TYPE,
        freeze_identity=FREEZE_IDENTITY,
        request=REQUEST,
        selected_set_repo_relative="framework/EAs/QM5_20009/sets/selected.set",
        file_specs=specs,
    )
    return source_root, snapshot_root, specs, binding


def _expected_files(specs: list[dict[str, object]]) -> list[dict[str, str]]:
    return [
        {
            "role": str(row["role"]),
            "repo_relative_path": str(row["repo_relative_path"]),
        }
        for row in specs
    ]


def _verify(snapshot_root: Path, specs: list[dict[str, object]], binding: dict) -> dict:
    return fence.verify_runtime_snapshot(
        binding,
        expected_snapshot_root=snapshot_root,
        run_id=RUN_ID,
        artifact_type=ARTIFACT_TYPE,
        freeze_identity=FREEZE_IDENTITY,
        request=REQUEST,
        expected_files=_expected_files(specs),
    )


def test_workspace_mutation_after_pre_does_not_change_bound_execution(tmp_path: Path) -> None:
    source_root, snapshot_root, specs, binding = _snapshot_fixture(tmp_path)
    moving_runner = source_root / "framework/scripts/run_smoke.ps1"
    moving_runner.write_bytes(b"legitimate-concurrent-workspace-edit\n")

    manifest = _verify(snapshot_root, specs, binding)
    snapshot_runner = Path(binding["role_bindings"]["runner_smoke"]["path"])
    assert snapshot_runner.read_bytes() == b"runner-v1\n"
    assert Path(manifest["snapshot_repo_root"]) == snapshot_root / "repo"
    assert snapshot_runner != moving_runner


def test_snapshot_mutation_is_rejected_even_if_workspace_is_unchanged(tmp_path: Path) -> None:
    _source_root, snapshot_root, specs, binding = _snapshot_fixture(tmp_path)
    snapshot_runner = Path(binding["role_bindings"]["runner_smoke"]["path"])
    snapshot_runner.write_bytes(b"tampered-snapshot\n")
    with pytest.raises(fence.FenceError, match="runtime snapshot file mutation"):
        _verify(snapshot_root, specs, binding)


def test_noncanonical_rebound_snapshot_manifest_is_rejected(tmp_path: Path) -> None:
    _source_root, snapshot_root, specs, binding = _snapshot_fixture(tmp_path)
    manifest_path = Path(binding["manifest_path"])
    payload = json.loads(manifest_path.read_text(encoding="ascii"))
    noncanonical = json.dumps(payload, separators=(",", ":")).encode("ascii")
    manifest_path.write_bytes(noncanonical)
    digest = hashlib.sha256(noncanonical).hexdigest()
    sidecar_path = Path(binding["manifest_sidecar_path"])
    sidecar = f"{digest}  {manifest_path.name}\n".encode("ascii")
    sidecar_path.write_bytes(sidecar)
    rebound = copy.deepcopy(binding)
    rebound["manifest_size_bytes"] = len(noncanonical)
    rebound["manifest_sha256"] = digest
    rebound["manifest_sidecar_sha256"] = hashlib.sha256(sidecar).hexdigest()
    with pytest.raises(fence.FenceError, match="not canonical JSON"):
        _verify(snapshot_root, specs, rebound)


def test_cross_run_snapshot_and_path_escape_are_rejected(tmp_path: Path) -> None:
    source_root, snapshot_root, specs, binding = _snapshot_fixture(tmp_path)
    with pytest.raises(fence.FenceError, match="cross-run runtime snapshot root"):
        fence.verify_runtime_snapshot(
            binding,
            expected_snapshot_root=tmp_path / "different_run" / "runtime_snapshot",
            run_id=RUN_ID,
            artifact_type=ARTIFACT_TYPE,
            freeze_identity=FREEZE_IDENTITY,
            request=REQUEST,
            expected_files=_expected_files(specs),
        )

    escaped_root = tmp_path / "escape_case"
    escaped_root.mkdir()
    with pytest.raises(fence.FenceError, match="escapes its root"):
        fence.create_runtime_snapshot(
            source_repo_root=source_root,
            snapshot_root=escaped_root / "runtime_snapshot",
            run_id=RUN_ID,
            artifact_type=ARTIFACT_TYPE,
            freeze_identity=FREEZE_IDENTITY,
            request=REQUEST,
            selected_set_repo_relative="framework/EAs/QM5_20009/sets/selected.set",
            file_specs=[
                {
                    "role": "selected_set",
                    "repo_relative_path": "../selected.set",
                    "expected_size_bytes": 1,
                    "expected_sha256": "c" * 64,
                },
                {
                    "role": "ea_binary",
                    "repo_relative_path": "framework/EA.ex5",
                    "expected_size_bytes": 1,
                    "expected_sha256": "d" * 64,
                },
            ],
        )


def test_reparse_source_is_rejected_when_supported(tmp_path: Path) -> None:
    source_root = tmp_path / "source"
    source_root.mkdir()
    real = source_root / "real.ps1"
    real.write_bytes(b"real\n")
    linked = source_root / "linked.ps1"
    try:
        os.symlink(real, linked)
    except (OSError, NotImplementedError):
        pytest.skip("symlink creation is unavailable for this Windows account")
    run_root = tmp_path / "symlink_run"
    run_root.mkdir()
    with pytest.raises(fence.FenceError, match="symlink/reparse"):
        fence.create_runtime_snapshot(
            source_repo_root=source_root,
            snapshot_root=run_root / "runtime_snapshot",
            run_id=RUN_ID,
            artifact_type=ARTIFACT_TYPE,
            freeze_identity=FREEZE_IDENTITY,
            request=REQUEST,
            selected_set_repo_relative="linked.ps1",
            file_specs=[
                {
                    "role": "selected_set",
                    "repo_relative_path": "linked.ps1",
                    "expected_size_bytes": len(b"real\n"),
                    "expected_sha256": hashlib.sha256(b"real\n").hexdigest(),
                }
            ],
        )


def test_noncanonical_pre_receipt_is_rejected_even_with_rebound_sidecar(
    tmp_path: Path,
) -> None:
    receipt = tmp_path / "validator_pre.json"
    raw = b'{"status":"PASS", "schema_version":1}\n'
    receipt.write_bytes(raw)
    digest = hashlib.sha256(raw).hexdigest()
    Path(f"{receipt}.sha256").write_bytes(
        f"{digest}  {receipt.name}\n".encode("ascii")
    )
    with pytest.raises(fence.FenceError, match="not canonical JSON"):
        fence._read_canonical_detached(receipt, "PRE validator receipt")


def test_post_pre_receipt_sha_stays_bound_to_launcher_memory(tmp_path: Path) -> None:
    receipt = tmp_path / "validator_pre.json"
    original = {"schema_version": 1, "status": "PASS", "value": "original"}
    fence._write_receipt_atomic(receipt, original)
    original_sha = hashlib.sha256(receipt.read_bytes()).hexdigest()

    receipt.unlink()
    Path(f"{receipt}.sha256").unlink()
    rebound = {"schema_version": 1, "status": "PASS", "value": "rebound"}
    fence._write_receipt_atomic(receipt, rebound)
    with pytest.raises(fence.FenceError, match="PRE validator receipt identity drift"):
        fence._read_preflight_receipt(receipt, original_sha)
