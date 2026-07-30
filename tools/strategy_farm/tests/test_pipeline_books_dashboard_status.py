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


NOW = dt.datetime(2026, 7, 30, 5, 30, tzinfo=dt.UTC)


def _payload() -> dict:
    return json.loads(DEFAULT_CONFIG.read_text(encoding="utf-8"))


def _materialize(tmp_path: Path, payload: dict | None = None) -> tuple[Path, Path, dict]:
    value = copy.deepcopy(payload or _payload())
    root = tmp_path / "repo"
    bindings = value["bindings"]
    rows = [
        bindings["plan"],
        bindings["evidence"],
        bindings["ftmo_book3_runtime_projection"],
        bindings["q08_policy"],
        bindings["test_lanes"],
    ]
    rows.extend(bindings["rulepacks"])
    for binding in rows:
        rel = Path(binding["path"])
        target = root / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(DEFAULT_REPO_ROOT / rel, target)
    config = root / "status.json"
    config.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")
    return config, root, value


def _text_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def _write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def _materialize_resolved_v2(
    tmp_path: Path,
) -> tuple[Path, Path, dict, Path, dict]:
    config, root, value = _materialize(tmp_path)
    v1_manifest_path = root / value["bindings"]["test_lanes"]["path"]
    manifest = json.loads(v1_manifest_path.read_text(encoding="utf-8"))
    manifest["schema_version"] = "qm.test-lanes/v2"
    manifest["green_lane"] = {
        "policy": "RUN_ALL_INCLUDING_RESOLVED_EXTERNAL_REGRESSIONS"
    }
    manifest["external_residual_lane"]["state"] = "RESOLVED_PASS"
    manifest["external_residual_lane"]["policy"] = "RESOLVED_PASS"
    manifest["external_residual_lane"]["exit_condition"] = (
        "All five node IDs PASS without skip, xfail, assertion weakening or silent rebinding."
    )
    manifest_rel = Path("tools/strategy_farm/config/test_lanes.v2.fixture.json")
    manifest_path = root / manifest_rel
    _write_json(manifest_path, manifest)
    value["bindings"]["test_lanes"] = {
        "path": manifest_rel.as_posix(),
        "file_sha256": _text_sha256(manifest_path),
    }

    value["as_of_utc"] = "2026-07-30T06:00:00Z"
    green = value["verification_lanes"]["green"]
    green["deselected"] = 0
    green["statement"] = (
        "All tests, including the exact five resolved external sentinels, passed."
    )
    residual = value["verification_lanes"]["external_residual"]
    residual["state"] = "RESOLVED_PASS"
    residual["pass_count"] = 5
    residual["exit_condition"] = manifest["external_residual_lane"]["exit_condition"]
    value["owner_blockers"] = value["owner_blockers"][:4]

    node_ids = [row["node_id"] for row in residual["items"]]
    receipt = {
        "schema_version": "qm.external-residual-exit-receipt/v1",
        "status": "RESOLVED_PASS",
        "recorded_at_utc": "2026-07-30T05:55:00Z",
        "test_lanes_binding": {
            **value["bindings"]["test_lanes"],
            "schema_version": "qm.test-lanes/v2",
            "sentinel_node_ids": node_ids,
        },
        "publication_plan": {
            "schema": "qm-news-calendar-multi-principal-publication-plan/v1",
            "plan_sha256": "1" * 64,
            "target_count": 4,
        },
        "calendar_publication": {
            "status": "PUBLISHED_VERIFIED",
            "plan_sha256": "1" * 64,
            "receipt_sha256": "2" * 64,
            "bundle_id": "news-calendar-" + "3" * 64,
            "target_count": 4,
            "verified_target_count": 4,
            "source_verified": True,
            "common_targets_verified": True,
            "factory_mode": "OFF_HASH_BOUND",
            "lock_release_succeeded": True,
        },
        "test_results": {
            "green": {
                key: green[key]
                for key in (
                    "state",
                    "passed",
                    "skipped",
                    "deselected",
                    "subtests_passed",
                )
            },
            "external_residual": {
                "state": "RESOLVED_PASS",
                "expected_count": 5,
                "pass_count": 5,
                "failed": 0,
                "skipped": 0,
                "xfailed": 0,
                "deselected": 0,
                "node_ids": node_ids,
            },
        },
        "safety": {
            "factory_off_flag_unchanged": True,
            "factory_mutation_lock_absent_after": True,
            "factory_activation_authorized": False,
            "scheduler_action_authorized": False,
            "mt5_action_authorized": False,
            "autotrading_action_authorized": False,
            "deployment_authorized": False,
            "paid_challenge_purchase_authorized": False,
        },
    }
    receipt_rel = Path("docs/ops/evidence/external_residual_exit_receipt.fixture.json")
    receipt_path = root / receipt_rel
    _write_json(receipt_path, receipt)
    value["bindings"]["external_residual_exit_receipt"] = {
        "path": receipt_rel.as_posix(),
        "file_sha256": _text_sha256(receipt_path),
    }
    _write_json(config, value)
    return config, root, value, receipt_path, receipt


def _rewrite_bound_receipt(
    config: Path,
    value: dict,
    receipt_path: Path,
    receipt: dict,
) -> None:
    _write_json(receipt_path, receipt)
    value["bindings"]["external_residual_exit_receipt"]["file_sha256"] = (
        _text_sha256(receipt_path)
    )
    _write_json(config, value)


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
    ftmo = status["ftmo_book3_runtime_evaluation"]
    assert ftmo["status"] == "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED"
    assert ftmo["readiness"]["paid_challenge"] == "NO_GO"
    assert [row["trades"] for row in ftmo["native_runs"]] == [1143, 291, 548]
    assert all(row["lifecycle_mismatches"] == 0 for row in ftmo["native_runs"])
    assert ftmo["policy_bootstrap"]["gate_eligible"] is False
    assert ftmo["temporal_holdout_diagnostic"]["gate_eligible"] is False
    assert not any(ftmo["authorization"].values())
    assert len(status["verification_lanes"]["external_residual"]["items"]) == 5
    assert len(status["owner_blockers"]) == 6


def test_snapshot_reports_fresh_with_orthogonal_status_fields() -> None:
    snapshot = program_status_snapshot(now_utc=NOW)

    assert snapshot["state"] == "FRESH"
    assert snapshot["valid"] is True
    assert snapshot["error"] == ""
    assert snapshot["generated_at_utc"] == "2026-07-30T05:30:00Z"
    assert snapshot["config_as_of_utc"] <= snapshot["generated_at_utc"]
    assert snapshot["work_packages"][6]["source_status"] == "PARTIAL_IMPLEMENTED"
    assert snapshot["work_packages"][6]["runtime_status"] == "MIGRATION_NOT_APPLIED"
    assert snapshot["work_packages"][7]["source_status"] == "DRY_RUN_IMPLEMENTED"
    assert snapshot["work_packages"][7]["runtime_status"] == "NOT_APPLIED"
    assert snapshot["work_packages"][8]["source_status"] == "EVALUATOR_IMPLEMENTED"
    assert snapshot["work_packages"][8]["runtime_status"] == (
        "RESEARCH_MODEL_COMPLETE_STRICT_QUALIFICATION_UNVERIFIED"
    )
    assert snapshot["target_lanes"][0]["eligibility"] == "NOT_EVALUATED"
    assert snapshot["target_lanes"][1]["eligibility"] == (
        "STRICT_QUALIFICATION_UNVERIFIED"
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
    rows = [
        bindings["plan"],
        bindings["evidence"],
        bindings["ftmo_book3_runtime_projection"],
        bindings["q08_policy"],
        bindings["test_lanes"],
    ]
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


def test_ftmo_runtime_projection_is_bound_to_repo_evidence_record(tmp_path: Path) -> None:
    config, root, value = _materialize(tmp_path)
    evidence = root / value["bindings"]["ftmo_book3_runtime_projection"]["path"]
    evidence.write_bytes(evidence.read_bytes() + b"\n")

    with pytest.raises(ProgramStatusError, match="file hash mismatch"):
        load_program_status(config, repo_root=root)


def test_ftmo_runtime_projection_cannot_grant_authority(tmp_path: Path) -> None:
    payload = _payload()
    payload["ftmo_book3_runtime_evaluation"]["authorization"][
        "paid_challenge_purchase_authorized"
    ] = True
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="grants no authority"):
        load_program_status(config, repo_root=root)


def test_ftmo_research_statistics_cannot_be_marked_gate_eligible(tmp_path: Path) -> None:
    payload = _payload()
    payload["ftmo_book3_runtime_evaluation"]["temporal_holdout_diagnostic"][
        "gate_eligible"
    ] = True
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="must be false"):
        load_program_status(config, repo_root=root)


def test_ftmo_percentages_cannot_exceed_one_hundred(tmp_path: Path) -> None:
    payload = _payload()
    payload["ftmo_book3_runtime_evaluation"]["policy_bootstrap"][
        "phase1_pass_percent"
    ] = "100.999%"
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="explicit percentage"):
        load_program_status(config, repo_root=root)


def test_config_freshness_cannot_predate_bound_projection_record(tmp_path: Path) -> None:
    payload = _payload()
    payload["as_of_utc"] = "2026-07-30T05:00:00Z"
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="must not predate the hash-bound FTMO projection"):
        load_program_status(config, repo_root=root)


def test_config_freshness_may_follow_bound_projection_record(tmp_path: Path) -> None:
    payload = _payload()
    payload["as_of_utc"] = "2026-07-30T05:30:00Z"
    config, root, _ = _materialize(tmp_path, payload)

    assert load_program_status(config, repo_root=root)["as_of_utc"] == (
        "2026-07-30T05:30:00Z"
    )


def test_exact_residual_node_set_is_bound_to_test_lane_artifact(tmp_path: Path) -> None:
    payload = _payload()
    payload["verification_lanes"]["external_residual"]["items"][0]["node_id"] = "changed"
    config, root, _ = _materialize(tmp_path, payload)

    with pytest.raises(ProgramStatusError, match="test-lane order"):
        load_program_status(config, repo_root=root)


def test_resolved_v2_requires_and_accepts_strict_bound_exit_receipt(
    tmp_path: Path,
) -> None:
    config, root, _value, _receipt_path, _receipt = _materialize_resolved_v2(
        tmp_path
    )

    status = load_program_status(config, repo_root=root)

    assert status["bindings"]["test_lanes"]["path"].endswith(
        "test_lanes.v2.fixture.json"
    )
    assert "external_residual_exit_receipt" in status["bindings"]
    assert status["verification_lanes"]["green"]["deselected"] == 0
    assert status["verification_lanes"]["external_residual"]["state"] == (
        "RESOLVED_PASS"
    )
    assert status["verification_lanes"]["external_residual"]["pass_count"] == 5
    assert len(status["owner_blockers"]) == 4
    assert not any(status["safety"][key] for key in (
        "factory_action_authorized",
        "scheduler_action_authorized",
        "mt5_action_authorized",
        "autotrading_action_authorized",
        "deployment_authorized",
    ))
    assert not any(status["ftmo_book3_runtime_evaluation"]["authorization"].values())


def test_fake_resolved_v2_without_exit_receipt_fails_closed(tmp_path: Path) -> None:
    config, root, value, _receipt_path, _receipt = _materialize_resolved_v2(
        tmp_path
    )
    value["bindings"].pop("external_residual_exit_receipt")
    _write_json(config, value)

    with pytest.raises(ProgramStatusError, match="is required for a V2 RESOLVED_PASS"):
        load_program_status(config, repo_root=root)


def test_resolved_v2_rejects_wrong_exit_receipt_hash(tmp_path: Path) -> None:
    config, root, value, _receipt_path, _receipt = _materialize_resolved_v2(
        tmp_path
    )
    value["bindings"]["external_residual_exit_receipt"]["file_sha256"] = "0" * 64
    _write_json(config, value)

    with pytest.raises(ProgramStatusError, match="file hash mismatch"):
        load_program_status(config, repo_root=root)


def test_resolved_v2_status_timestamp_cannot_predate_exit_receipt(
    tmp_path: Path,
) -> None:
    config, root, value, _receipt_path, _receipt = _materialize_resolved_v2(
        tmp_path
    )
    value["as_of_utc"] = "2026-07-30T05:50:00Z"
    _write_json(config, value)

    with pytest.raises(ProgramStatusError, match="must not predate the bound exit receipt"):
        load_program_status(config, repo_root=root)


@pytest.mark.parametrize(
    ("field", "bad_value", "message"),
    [
        ("green_deselected", 5, "must be exactly 0"),
        ("residual_expected_count", 4, "must be exactly 5"),
        ("residual_pass_count", 4, "must be exactly 5"),
    ],
)
def test_resolved_v2_rejects_count_or_deselection_mismatch(
    tmp_path: Path,
    field: str,
    bad_value: int,
    message: str,
) -> None:
    config, root, value, _receipt_path, _receipt = _materialize_resolved_v2(
        tmp_path
    )
    if field == "green_deselected":
        value["verification_lanes"]["green"]["deselected"] = bad_value
    elif field == "residual_expected_count":
        value["verification_lanes"]["external_residual"]["expected_count"] = bad_value
    else:
        value["verification_lanes"]["external_residual"]["pass_count"] = bad_value
    _write_json(config, value)

    with pytest.raises(ProgramStatusError, match=message):
        load_program_status(config, repo_root=root)


@pytest.mark.parametrize(
    ("claim", "message"),
    [
        ("schema", "unsupported exit-receipt schema"),
        ("plan", "does not match publication_plan"),
        ("calendar", "must be true"),
        ("test_result", "must match the status at exactly 5"),
        ("authority", "must not grant authority"),
    ],
)
def test_resolved_v2_rejects_false_exit_receipt_claims(
    tmp_path: Path,
    claim: str,
    message: str,
) -> None:
    config, root, value, receipt_path, receipt = _materialize_resolved_v2(
        tmp_path
    )
    if claim == "schema":
        receipt["schema_version"] = "qm.external-residual-exit-receipt/v0"
    elif claim == "plan":
        receipt["calendar_publication"]["plan_sha256"] = "4" * 64
    elif claim == "calendar":
        receipt["calendar_publication"]["source_verified"] = False
    elif claim == "test_result":
        receipt["test_results"]["external_residual"]["pass_count"] = 4
    else:
        receipt["safety"]["factory_activation_authorized"] = True
    _rewrite_bound_receipt(config, value, receipt_path, receipt)

    with pytest.raises(ProgramStatusError, match=message):
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
