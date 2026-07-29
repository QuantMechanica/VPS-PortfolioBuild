from __future__ import annotations

import copy
import datetime as dt
import hashlib
import json
import shutil
from pathlib import Path

import pytest

from tools.strategy_farm.pipeline_books_dashboard_status import (
    DEFAULT_CONFIG,
    DEFAULT_REPO_ROOT,
    ProgramStatusError,
    load_program_status,
    program_status_snapshot,
)


NOW = dt.datetime(2026, 7, 29, 18, 0, tzinfo=dt.UTC)


def _payload() -> dict:
    return json.loads(DEFAULT_CONFIG.read_text(encoding="utf-8"))


def _materialize(tmp_path: Path, payload: dict | None = None) -> tuple[Path, Path, dict]:
    value = copy.deepcopy(payload or _payload())
    root = tmp_path / "repo"
    bindings = value["bindings"]
    rows = [bindings["plan"], bindings["evidence"], bindings["q08_policy"], bindings["test_lanes"]]
    rows.extend(bindings["rulepacks"])
    for binding in rows:
        rel = Path(binding["path"])
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(DEFAULT_REPO_ROOT / rel, target)
    config = root / "status.json"
    config.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    return config, root, value


def test_canonical_status_is_hash_bound_and_complete() -> None:
    status = load_program_status()

    assert [row["id"] for row in status["work_packages"]] == [f"W{i}" for i in range(9)]
    assert all(row["authority_status"] == "NO_RUNTIME_AUTHORITY" for row in status["work_packages"])
    assert status["q08_v3"]["verdict_states"] == [
        "SUPPORTED",
        "CONDITIONAL",
        "INSUFFICIENT",
        "CONTRADICTED",
        "INVALID",
    ]
    assert status["q08_v3"]["lifecycle"] == "SHADOW_ONLY"
    assert len(status["verification_lanes"]["external_residual"]["items"]) == 5
    assert len(status["owner_blockers"]) == 6


def test_snapshot_reports_fresh_with_orthogonal_status_fields() -> None:
    snapshot = program_status_snapshot(now_utc=NOW)

    assert snapshot["state"] == "FRESH"
    assert snapshot["valid"] is True
    assert snapshot["error"] == ""
    assert snapshot["generated_at_utc"] == "2026-07-29T18:00:00Z"
    assert snapshot["config_as_of_utc"] <= snapshot["generated_at_utc"]
    assert snapshot["work_packages"][6]["source_status"] == "PARTIAL_IMPLEMENTED"
    assert snapshot["work_packages"][6]["runtime_status"] == "MIGRATION_NOT_APPLIED"
    assert snapshot["work_packages"][7]["source_status"] == "DRY_RUN_IMPLEMENTED"
    assert snapshot["work_packages"][7]["runtime_status"] == "NOT_APPLIED"
    assert snapshot["work_packages"][8]["source_status"] == "SHADOW_EVALUATOR_IMPLEMENTED"
    assert snapshot["work_packages"][8]["runtime_status"] == "NO_TARGET_EVALUATION"
    assert all(
        row["state"] == "RESEARCH_EVALUATOR_SOURCE_IMPLEMENTED"
        for row in snapshot["target_lanes"]
    )


def test_missing_source_is_explicit_and_never_clear(tmp_path: Path) -> None:
    snapshot = program_status_snapshot(tmp_path / "absent.json", now_utc=NOW)

    assert snapshot["state"] == "MISSING"
    assert snapshot["valid"] is False
    assert "missing" in snapshot["error"]
    assert snapshot["work_packages"] == []
    assert snapshot["owner_blockers"] == []


def test_stale_source_keeps_verified_data_but_is_not_valid() -> None:
    snapshot = program_status_snapshot(
        now_utc=dt.datetime(2026, 8, 6, 15, 30, tzinfo=dt.UTC)
    )

    assert snapshot["state"] == "STALE"
    assert snapshot["valid"] is False
    assert len(snapshot["work_packages"]) == 9
    assert "maximum" in snapshot["error"]


def test_future_source_fails_closed() -> None:
    snapshot = program_status_snapshot(
        now_utc=dt.datetime(2026, 7, 29, 12, 0, tzinfo=dt.UTC)
    )

    assert snapshot["state"] == "INVALID"
    assert snapshot["valid"] is False
    assert "future" in snapshot["error"]
    assert snapshot["work_packages"] == []


def test_bound_plan_byte_drift_is_invalid(tmp_path: Path) -> None:
    config, root, value = _materialize(tmp_path)
    plan = root / value["bindings"]["plan"]["path"]
    plan.write_bytes(plan.read_bytes() + b"\n")

    with pytest.raises(ProgramStatusError, match="file hash mismatch"):
        load_program_status(config, repo_root=root)
    snapshot = program_status_snapshot(config, repo_root=root, now_utc=NOW)
    assert snapshot["state"] == "INVALID"
    assert "hash mismatch" in snapshot["error"]


def test_bound_text_hash_is_portable_across_lf_and_crlf_checkouts(tmp_path: Path) -> None:
    config, root, value = _materialize(tmp_path)
    bindings = value["bindings"]
    rows = [bindings["plan"], bindings["evidence"], bindings["q08_policy"], bindings["test_lanes"]]
    rows.extend(bindings["rulepacks"])

    for binding in rows:
        source = root / binding["path"]
        lf_bytes = source.read_bytes().replace(b"\r\n", b"\n")
        assert hashlib.sha256(lf_bytes).hexdigest() == binding["file_sha256"]
        source.write_bytes(lf_bytes.replace(b"\n", b"\r\n"))

    assert load_program_status(config, repo_root=root)["binding_hash_contract"] == (
        "TEXT_BYTES_CRLF_TO_LF_SHA256_V1"
    )

    for binding in rows:
        source = root / binding["path"]
        source.write_bytes(source.read_bytes().replace(b"\r\n", b"\n"))

    assert load_program_status(config, repo_root=root)["binding_hash_contract"] == (
        "TEXT_BYTES_CRLF_TO_LF_SHA256_V1"
    )


def test_bound_text_hash_keeps_non_eol_bytes_integrity_relevant(tmp_path: Path) -> None:
    config, root, value = _materialize(tmp_path)
    plan = root / value["bindings"]["plan"]["path"]
    plan.write_bytes(plan.read_bytes() + b"\r")

    with pytest.raises(ProgramStatusError, match="file hash mismatch"):
        load_program_status(config, repo_root=root)


def test_bound_text_hash_rejects_utf8_bom_drift(tmp_path: Path) -> None:
    config, root, value = _materialize(tmp_path)
    plan = root / value["bindings"]["plan"]["path"]
    plan.write_bytes(b"\xef\xbb\xbf" + plan.read_bytes())

    with pytest.raises(ProgramStatusError, match="file hash mismatch"):
        load_program_status(config, repo_root=root)


@pytest.mark.parametrize("contract", [None, "RAW_FILE_SHA256_V1"])
def test_binding_hash_contract_is_required_and_exact(
    tmp_path: Path, contract: str | None
) -> None:
    payload = _payload()
    if contract is None:
        payload.pop("binding_hash_contract")
        match = "key set mismatch"
    else:
        payload["binding_hash_contract"] = contract
        match = "must be TEXT_BYTES_CRLF_TO_LF_SHA256_V1"
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match=match):
        load_program_status(config, repo_root=root)


def test_rulepack_canonical_hash_must_match_lane_and_artifact(tmp_path: Path) -> None:
    payload = _payload()
    payload["target_lanes"][0]["rulepack_canonical_sha256"] = "0" * 64
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="lane hash"):
        load_program_status(config, repo_root=root)


def test_exact_residual_node_set_is_bound_to_test_lane_artifact(tmp_path: Path) -> None:
    payload = _payload()
    payload["verification_lanes"]["external_residual"]["items"][0]["node_id"] = "changed"
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="test-lane order"):
        load_program_status(config, repo_root=root)


@pytest.mark.parametrize(
    "key",
    [
        "factory_action_authorized",
        "scheduler_action_authorized",
        "mt5_action_authorized",
        "autotrading_action_authorized",
        "deployment_authorized",
    ],
)
def test_source_projection_cannot_grant_runtime_authority(tmp_path: Path, key: str) -> None:
    payload = _payload()
    payload["safety"][key] = True
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="must not grant authority"):
        load_program_status(config, repo_root=root)


def test_work_packages_must_be_exactly_ordered_w0_through_w8(tmp_path: Path) -> None:
    payload = _payload()
    payload["work_packages"][0], payload["work_packages"][1] = (
        payload["work_packages"][1],
        payload["work_packages"][0],
    )
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="expected W0"):
        load_program_status(config, repo_root=root)


def test_relative_binding_cannot_escape_repo(tmp_path: Path) -> None:
    payload = _payload()
    payload["bindings"]["plan"]["path"] = "../outside.md"
    root = tmp_path / "repo"
    root.mkdir()
    config = root / "status.json"
    config.write_text(json.dumps(payload), encoding="utf-8")

    with pytest.raises(ProgramStatusError, match="without '..'"):
        load_program_status(config, repo_root=root)


def test_duplicate_json_key_is_rejected(tmp_path: Path) -> None:
    config = tmp_path / "duplicate.json"
    config.write_text('{"schema_version":"one","schema_version":"two"}', encoding="utf-8")

    with pytest.raises(ProgramStatusError, match="duplicate JSON key"):
        load_program_status(config, repo_root=tmp_path)


def test_snapshot_requires_timezone_aware_utc_clock() -> None:
    with pytest.raises(ValueError, match="timezone-aware UTC"):
        program_status_snapshot(now_utc=dt.datetime(2026, 7, 29, 15, 30))
