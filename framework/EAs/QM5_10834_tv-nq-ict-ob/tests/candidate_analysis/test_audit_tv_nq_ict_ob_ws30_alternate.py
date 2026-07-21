from __future__ import annotations

import base64
import copy
import importlib.util
import inspect
import json
import shutil
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = (
    EA_ROOT
    / "tools"
    / "candidate_analysis"
    / "audit_tv_nq_ict_ob_ws30_alternate.py"
)


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


subject = _load("audit_tv_nq_ict_ob_ws30_alternate_test", TOOL)


def _git_result(
    returncode: int, stdout: str = "", stderr: str = ""
) -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        args=["git"], returncode=returncode, stdout=stdout, stderr=stderr
    )


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def _relocated_rotation_receipt_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict[str, dict[str, object]], Path, dict[str, object], datetime]:
    main_root = tmp_path / "main"
    runtime_root = tmp_path / "runtime"
    origin_helper = main_root / subject.CREDENTIAL_HELPER_RELATIVE_PATH
    origin_child = main_root / subject.IDENTITY_PROBE_CHILD_RELATIVE_PATH
    runtime_helper = runtime_root / subject.CREDENTIAL_HELPER_RELATIVE_PATH
    runtime_child = runtime_root / subject.IDENTITY_PROBE_CHILD_RELATIVE_PATH
    for path, content in (
        (origin_helper, b"exact helper bytes\n"),
        (runtime_helper, b"exact helper bytes\n"),
        (origin_child, b"exact identity child bytes\n"),
        (runtime_child, b"exact identity child bytes\n"),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    external_root = tmp_path / "external"
    credential = external_root / "credential.machine-dpapi.json"
    receipt_path = external_root / "credential.rotation-receipt.json"
    legacy = external_root / "credential.clixml"
    legacy.parent.mkdir(parents=True, exist_ok=True)
    legacy.write_bytes(b"legacy credential")
    lane_path = runtime_root / "framework" / "registry" / "dev2_lane_contract.json"
    rotation_root = tmp_path / "credential-rotation"
    rotation_id = "20260720T120000Z_" + "a" * 32
    identity_request_path = (
        rotation_root / rotation_id / "control" / "identity_probe_request.json"
    )
    identity_result_path = (
        rotation_root / rotation_id / "output" / "identity_probe_result.json"
    )

    monkeypatch.setattr(subject, "MAIN_WORKTREE_ROOT", main_root)
    monkeypatch.setattr(subject, "REPO_ROOT", runtime_root)
    monkeypatch.setattr(subject.B, "MACHINE_CREDENTIAL_PATH", credential)
    monkeypatch.setattr(
        subject.B, "MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH", receipt_path
    )
    monkeypatch.setattr(subject.B, "CREDENTIAL_HELPER_PATH", runtime_helper)
    monkeypatch.setattr(subject.B, "IDENTITY_PROBE_CHILD_PATH", runtime_child)
    monkeypatch.setattr(subject.B, "LEGACY_CREDENTIAL_PATH", legacy)
    monkeypatch.setattr(subject.B, "DEV2_LANE_CONTRACT_PATH", lane_path)
    monkeypatch.setattr(subject.B, "DEV2_CREDENTIAL_ROTATION_ROOT", rotation_root)

    now = datetime.now(timezone.utc)
    target_account = r"TESTHOST\QMDev2"
    target_sid = "S-1-5-21-111-222-333-1001"
    generation_id = "b" * 32
    lane = {
        "schema_version": 3,
        "contract_id": "QM_DEV2_ISOLATED_MT5_LANE_V3",
        "lane": "DEV2",
        "identity": {
            "local_user": "QMDev2",
            "profile": r"C:\Users\QMDev2",
            "credential": str(credential.resolve()),
            "credential_format": "QM_DEV2_MACHINE_DPAPI_CREDENTIAL",
            "dpapi_scope": "LocalMachine",
            "limited_non_admin": True,
        },
    }
    _write_json(lane_path, lane)
    credential_payload = {
        "schema_version": 1,
        "artifact_type": "QM_DEV2_MACHINE_DPAPI_CREDENTIAL",
        "contract_id": lane["contract_id"],
        "lane": "DEV2",
        "account": target_account,
        "target_sid": target_sid,
        "host_account_domain_sid": "S-1-5-21-111-222-333",
        "dpapi_scope": "LocalMachine",
        "text_encoding": "UTF-8",
        "generation_id": generation_id,
        "created_utc": (now - timedelta(minutes=3)).isoformat(),
        "ciphertext_base64": base64.b64encode(b"x" * 64).decode("ascii"),
    }
    _write_json(credential, credential_payload)
    identity_request = {
        "schema_version": 1,
        "artifact_type": "QM_DEV2_IDENTITY_PROBE_REQUEST",
        "nonce": "c" * 32,
        "created_utc": (now - timedelta(minutes=2, seconds=30)).isoformat(),
        "expires_utc": (now + timedelta(minutes=7, seconds=30)).isoformat(),
        "expected_account": target_account,
        "expected_sid": target_sid,
        "expected_profile": r"C:\Users\QMDev2",
        "expected_task_name": "QM_DEV2_SMOKE_" + "e" * 32,
        "result_path": str(identity_result_path.resolve()),
    }
    _write_json(identity_request_path, identity_request)
    identity_result = {
        "schema_version": 1,
        "artifact_type": "QM_DEV2_IDENTITY_PROBE_RESULT",
        "status": "PASS",
        "completed_utc": (now - timedelta(minutes=2)).isoformat(),
        "nonce": "c" * 32,
        "account": target_account,
        "sid": target_sid,
        "profile": r"C:\Users\QMDev2",
        "limited_non_admin": True,
        "request_sha256": subject.B.sha256_file(identity_request_path),
    }
    _write_json(identity_result_path, identity_result)

    credential_binding = subject.B.file_binding(credential)
    helper_binding = subject.B.file_binding(runtime_helper)
    child_binding = subject.B.file_binding(runtime_child)
    receipt = {
        "schema_version": 1,
        "artifact_type": "QM_DEV2_MACHINE_CREDENTIAL_ROTATION_RECEIPT",
        "status": "PASS",
        "completed_utc": (now - timedelta(minutes=1)).isoformat(),
        "contract_id": lane["contract_id"],
        "target_account": target_account,
        "target_sid": target_sid,
        "target_disabled_at_rest": True,
        "target_password_required_at_rest": True,
        "machine_credential_path": credential_binding["path"],
        "machine_credential_sha256": credential_binding["sha256"],
        "machine_credential_generation_id": generation_id,
        "machine_credential_helper_path": str(origin_helper.resolve()),
        "machine_credential_helper_sha256": helper_binding["sha256"],
        "identity_probe_child_path": str(origin_child.resolve()),
        "identity_probe_child_sha256": child_binding["sha256"],
        "identity_probe_result_path": str(identity_result_path.resolve()),
        "identity_probe_result_sha256": subject.B.sha256_file(identity_result_path),
        "identity_probe_logon_type": "Password",
        "identity_probe_run_level": "Limited",
        "machine_credential_matches_proved_password": True,
        "published_after_identity_proof": True,
        "legacy_credential_path": str(legacy.resolve()),
        "legacy_credential_preserved": True,
        "cleanup_lease_disarmed": True,
        "owner_process_count": 0,
        "dev2_root_process_count": 0,
    }
    _write_json(receipt_path, receipt)
    bindings = {
        "dev2_lane_contract": subject.B.file_binding(lane_path),
        "dev2_machine_credential": credential_binding,
        "dev2_machine_credential_helper": helper_binding,
        "dev2_identity_probe_child": child_binding,
        "dev2_machine_credential_rotation_receipt": subject.B.file_binding(
            receipt_path
        ),
    }
    return bindings, receipt_path, receipt, now


def test_rotation_receipt_projects_signed_origins_to_runtime_and_runs_full_validator(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bindings, _receipt_path, receipt, now = _relocated_rotation_receipt_fixture(
        tmp_path, monkeypatch
    )
    opened: list[Path] = []
    saved_loader = subject.B.load_json
    saved_file_binding = subject.B.file_binding
    saved_sha256_file = subject.B.sha256_file

    def reject_main(path: Path) -> None:
        candidate = Path(path)
        if subject._main_repo_relative(candidate) is not None:
            raise AssertionError(f"main-worktree evidence was read: {candidate}")
        opened.append(candidate)

    def guarded_loader(path: Path):
        reject_main(path)
        return saved_loader(path)

    def guarded_file_binding(path: Path, expected_sha256: str | None = None):
        reject_main(path)
        return saved_file_binding(path, expected_sha256)

    def guarded_sha256_file(path: Path) -> str:
        reject_main(path)
        return saved_sha256_file(path)

    monkeypatch.setattr(subject.B, "load_json", guarded_loader)
    monkeypatch.setattr(subject.B, "file_binding", guarded_file_binding)
    monkeypatch.setattr(subject.B, "sha256_file", guarded_sha256_file)
    validated = subject.validate_relocated_machine_credential_rotation_receipt(
        bindings, now=now
    )

    projected = copy.deepcopy(receipt)
    projected["machine_credential_helper_path"] = bindings[
        "dev2_machine_credential_helper"
    ]["path"]
    projected["identity_probe_child_path"] = bindings[
        "dev2_identity_probe_child"
    ]["path"]
    assert validated["receipt_payload_sha256"] == subject.B.canonical_sha256(
        receipt
    )
    assert validated["receipt_payload_sha256"] != subject.B.canonical_sha256(
        projected
    )
    assert validated["machine_credential_helper"] == bindings[
        "dev2_machine_credential_helper"
    ]
    assert validated["identity_probe_child"] == bindings[
        "dev2_identity_probe_child"
    ]
    assert subject.B.load_json is guarded_loader
    assert opened
    assert all(subject._main_repo_relative(path) is None for path in opened)


@pytest.mark.parametrize(
    ("field", "mutation", "message"),
    (
        (
            "machine_credential_helper_path",
            "wrong_path",
            "helper origin path is not canonical",
        ),
        (
            "machine_credential_helper_sha256",
            "wrong_hash",
            "helper hash differs from runtime binding",
        ),
        (
            "machine_credential_helper_path",
            "normalized_alias",
            "helper origin path is not canonical",
        ),
        (
            "identity_probe_child_path",
            "wrong_path",
            "identity-child origin path is not canonical",
        ),
        (
            "identity_probe_child_sha256",
            "wrong_hash",
            "identity-child hash differs from runtime binding",
        ),
        (
            "identity_probe_child_path",
            "normalized_alias",
            "identity-child origin path is not canonical",
        ),
    ),
)
def test_rotation_receipt_rejects_wrong_signed_origin_or_runtime_hash(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    field: str,
    mutation: str,
    message: str,
) -> None:
    bindings, receipt_path, receipt, now = _relocated_rotation_receipt_fixture(
        tmp_path, monkeypatch
    )
    if mutation == "wrong_path":
        receipt[field] = str(
            (tmp_path / "wrong-origin" / f"{field}.ps1").resolve()
        )
    elif mutation == "normalized_alias":
        exact = Path(str(receipt[field]))
        receipt[field] = str(exact.parent / ".." / exact.parent.name / exact.name)
    else:
        receipt[field] = "0" * 64
    _write_json(receipt_path, receipt)
    bindings["dev2_machine_credential_rotation_receipt"] = subject.B.file_binding(
        receipt_path
    )

    def forbidden_base(*_args, **_kwargs):
        raise AssertionError("base validator must not see invalid signed provenance")

    monkeypatch.setattr(
        subject,
        "_BASE_VALIDATE_MACHINE_CREDENTIAL_ROTATION_RECEIPT",
        forbidden_base,
    )
    with pytest.raises(subject.B.InvalidEvidence, match=message):
        subject.validate_relocated_machine_credential_rotation_receipt(
            bindings, now=now
        )


@pytest.mark.parametrize(
    ("role", "relative_path", "message"),
    (
        (
            "dev2_machine_credential_helper",
            subject.CREDENTIAL_HELPER_RELATIVE_PATH,
            "helper bound path is not the exact runtime path",
        ),
        (
            "dev2_identity_probe_child",
            subject.IDENTITY_PROBE_CHILD_RELATIVE_PATH,
            "identity-probe child bound path is not the exact runtime path",
        ),
    ),
)
def test_rotation_receipt_rejects_main_origin_as_executable_binding(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    role: str,
    relative_path: Path,
    message: str,
) -> None:
    bindings, _receipt_path, _receipt, now = _relocated_rotation_receipt_fixture(
        tmp_path, monkeypatch
    )
    bindings[role] = {
        **bindings[role],
        "path": str((subject.MAIN_WORKTREE_ROOT / relative_path).resolve()),
    }
    with pytest.raises(subject.B.InvalidEvidence, match=message):
        subject.validate_relocated_machine_credential_rotation_receipt(
            bindings, now=now
        )


def test_rotation_receipt_loader_hook_is_restored_when_base_validation_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    bindings, _receipt_path, _receipt, now = _relocated_rotation_receipt_fixture(
        tmp_path, monkeypatch
    )
    saved_loader = subject.B.load_json

    def fail_after_projection(*_args, **_kwargs):
        raise subject.B.InvalidEvidence("later rotation proof drift")

    monkeypatch.setattr(
        subject,
        "_BASE_VALIDATE_MACHINE_CREDENTIAL_ROTATION_RECEIPT",
        fail_after_projection,
    )
    with pytest.raises(subject.B.InvalidEvidence, match="later rotation proof drift"):
        subject.validate_relocated_machine_credential_rotation_receipt(
            bindings, now=now
        )
    assert subject.B.load_json is saved_loader


def test_alternate_contract_is_hash_bound_and_semantically_valid() -> None:
    contract = subject.validate_alternate_contract()
    assert contract["status"] == (
        "IMPLEMENTED_NOT_MATERIALIZED_NOT_AUTHORIZED_NOT_LAUNCHED"
    )
    assert contract["attempt"] == {
        "type": "PREREGISTERED_SINGLE_INFRASTRUCTURE_ALTERNATE",
        "attempt_number": 2,
        "maximum_total_attempts": 2,
        "further_attempts_forbidden": True,
        "execution_lane": "DEV2",
        "resume_forbidden": True,
        "terminal_hopping_forbidden": True,
    }
    assert contract["identical_evidence_contract"]["gate_relaxation_forbidden"] is True
    assert contract["outcome_fence"][
        "primary_controller_stderr_content_must_not_be_read"
    ] is True
    assert contract["immutable_runtime"][
        "runtime_relocation_requires_byte_identical_repository_relative_files"
    ] is True
    assert contract["immutable_runtime"][
        "alternate_pre_and_worker_must_not_open_main_worktree_evidence_files"
    ] is True
    scoped = contract["immutable_runtime"]["main_worktree_scoped_path_policy"]
    assert scoped["path_count"] == subject.HISTORICAL_MAIN_SCOPED_PATH_COUNT == 53
    assert scoped["relative_path_list_canonical_sha256"] == (
        subject.HISTORICAL_MAIN_SCOPED_PATH_LIST_SHA256
    )
    assert contract["immutable_runtime"][
        "unrelated_main_worktree_paths_may_be_dirty"
    ] is True
    runtime_cleanliness = contract["immutable_runtime"][
        "runtime_worktree_cleanliness_policy"
    ]
    assert runtime_cleanliness == {
        "staged_diff": "GIT_DIFF_CACHED_QUIET_EXIT_ZERO_REQUIRED",
        "normalized_worktree_diff": "GIT_DIFF_QUIET_EXIT_ZERO_REQUIRED",
        "untracked_files": (
            "GIT_LS_FILES_OTHERS_INCLUDING_IGNORED_EMPTY_REQUIRED"
        ),
        "porcelain_status": (
            "NON_AUTHORITATIVE_DUE_TO_AUTOCRLF_INDEX_STAT_FALSE_POSITIVES"
        ),
        "raw_bound_file_bytes": (
            "EXACT_SOURCE_RUNTIME_SHA256_SIZE_LEDGER_REQUIRED"
        ),
    }
    assert contract["launch_gate"][
        "unrelated_main_worktree_dirt_does_not_block"
    ] is True


def test_invalid_runtime_materialization_is_closed_before_pre_without_consuming_attempt() -> None:
    closure = subject.validate_invalid_runtime_materialization_closure()
    assert closure["status"] == (
        "INVALID_RUNTIME_MATERIALIZATION_CLOSED_BEFORE_PRE_ATTEMPT_UNCONSUMED"
    )
    assert closure["native_attempt"] == {
        "attempt_number": 2,
        "claim_sequence": 2,
        "run_root": str(subject.ALTERNATE_RUN_ROOT),
        "claim_path": str(subject.ALTERNATE_CLAIM_PATH),
        "pre_receipt_created": False,
        "authorization_created": False,
        "claim_created": False,
        "launch_job_created": False,
        "launch_state_created": False,
        "native_process_started": False,
        "attempt_consumed": False,
    }
    invalid = closure["invalid_materialization"]
    assert invalid["runtime_worktree"] == str(subject.INVALID_RUNTIME_WORKTREE_ROOT)
    assert invalid["runtime_receipt"] == {
        "path": str(subject.INVALID_RUNTIME_RECEIPT_PATH),
        "size": 13053,
        "sha256": (
            "5877c55922fae1a57e975709fef606662137e480ed251ec30ba4f6d5d1a5149c"
        ),
    }
    assert closure["outcome_fence"]["native_reports_opened"] is False
    assert closure["outcome_fence"]["controller_logs_opened"] is False
    assert closure["outcome_fence"]["strategy_outcomes_read"] is False


def test_runtime_fix001_contract_separates_materialization_not_native_attempt() -> None:
    contract = subject.validate_runtime_fix_contract()
    attempt = contract["native_attempt_identity"]
    assert attempt["attempt_number"] == 2
    assert attempt["claim_sequence"] == 2
    assert attempt["run_root"] == str(subject.ALTERNATE_RUN_ROOT)
    assert attempt["claim_path"] == str(subject.ALTERNATE_CLAIM_PATH)
    assert attempt["attempt_consumed_before_fix"] is False
    assert attempt["same_native_attempt_not_a_retry"] is True
    runtime = contract["superseding_runtime_materialization"]
    assert runtime["invalid_runtime_worktree"] == str(
        subject.INVALID_RUNTIME_WORKTREE_ROOT
    )
    assert runtime["invalid_runtime_receipt"] == str(
        subject.INVALID_RUNTIME_RECEIPT_PATH
    )
    assert runtime["runtime_worktree_root"] == str(subject.RUNTIME_WORKTREE_ROOT)
    assert runtime["runtime_receipt_path"] == str(subject.RUNTIME_RECEIPT_PATH)
    assert subject.RUNTIME_WORKTREE_ROOT != subject.INVALID_RUNTIME_WORKTREE_ROOT
    assert subject.RUNTIME_RECEIPT_PATH != subject.INVALID_RUNTIME_RECEIPT_PATH
    dependency = contract["dependency_closure"]
    assert dependency["historical_materialization_path_count"] == 53
    assert dependency["technical_diagnosis_path_count"] == 54
    assert dependency["executable_fix001_path_count"] == 56
    assert dependency["executable_fix001_path_list_canonical_sha256"] == (
        subject.MAIN_SCOPED_PATH_LIST_SHA256
    )


def test_invalid_runtime_closure_rejects_any_claim_that_attempt_was_consumed(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    saved_loader = subject.B.load_json
    closure_lexical = subject.W._lexical_path(subject.INVALID_RUNTIME_CLOSURE_PATH)

    def drifted_loader(path: Path):
        payload = saved_loader(path)
        if subject.W._lexical_path(path) == closure_lexical:
            payload = copy.deepcopy(payload)
            payload["native_attempt"]["attempt_consumed"] = True
        return payload

    monkeypatch.setattr(subject.B, "load_json", drifted_loader)
    with pytest.raises(subject.B.InvalidEvidence, match="attempt-consumption drift"):
        subject.validate_invalid_runtime_materialization_closure()


def test_invalid_runtime_closure_reasserts_historical_files_after_validation(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    saved_assert_binding = subject.B.assert_binding
    observed: list[str] = []

    def replacement_race(binding, label: str):
        observed.append(label)
        if label == "historical runtime ledger[0]":
            raise subject.B.InvalidEvidence("simulated historical replacement race")
        return saved_assert_binding(binding, label)

    monkeypatch.setattr(subject.B, "assert_binding", replacement_race)
    with pytest.raises(subject.B.InvalidEvidence, match="historical replacement race"):
        subject.validate_invalid_runtime_materialization_closure()
    assert "signed machine-credential rotation receipt" in observed
    assert "historical invalid runtime receipt" in observed
    assert "historical runtime ledger[0]" in observed


def test_fix001_unconsumed_gate_is_limited_to_materialization_and_pre(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    run_root = tmp_path / "run"
    claim = tmp_path / "claims" / "attempt002.json"
    monkeypatch.setattr(subject, "ALTERNATE_RUN_ROOT", run_root)
    monkeypatch.setattr(subject, "ALTERNATE_PRE_RECEIPT_PATH", run_root / "pre.json")
    monkeypatch.setattr(
        subject, "ALTERNATE_AUTHORIZATION_PATH", run_root / "authorization.json"
    )
    monkeypatch.setattr(subject, "ALTERNATE_CLAIM_PATH", claim)
    monkeypatch.setattr(subject, "ALTERNATE_JOB_PATH", run_root / "job.json")
    monkeypatch.setattr(subject, "ALTERNATE_STATE_PATH", run_root / "state.json")
    monkeypatch.setattr(subject, "ALTERNATE_POST_RECEIPT_PATH", run_root / "post.json")
    subject._assert_fix001_native_attempt_still_unconsumed("PRE")
    run_root.mkdir(parents=True)
    subject.ALTERNATE_PRE_RECEIPT_PATH.write_text("sealed PRE", encoding="utf-8")
    with pytest.raises(subject.B.InvalidEvidence, match="PRE receipt exists"):
        subject._assert_fix001_native_attempt_still_unconsumed("materialization")
    assert "_assert_fix001_native_attempt_still_unconsumed" not in inspect.getsource(
        subject.validate_invalid_runtime_materialization_closure
    )


def test_materializer_can_only_publish_fix001_receipt_and_never_old_receipt() -> None:
    source = inspect.getsource(subject.materialize_runtime)
    assert "B.atomic_json(RUNTIME_RECEIPT_PATH" in source
    assert "B.atomic_json(INVALID_RUNTIME_RECEIPT_PATH" not in source
    assert "str(RUNTIME_WORKTREE_ROOT)" in source
    assert "str(INVALID_RUNTIME_WORKTREE_ROOT)" not in source


def test_primary_contract_absolute_origin_paths_are_parser_only_and_restored(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime_ea = tmp_path / "runtime" / "framework" / "EAs" / "candidate"
    runtime_build = (
        runtime_ea / "docs" / "candidate-analysis" / "build_receipt_20260720.json"
    )
    monkeypatch.setattr(subject, "EA_ROOT", runtime_ea)
    monkeypatch.setattr(subject.W, "EA_ROOT", runtime_ea)
    monkeypatch.setattr(subject.W, "BUILD_RECEIPT_PATH", runtime_build)
    monkeypatch.setattr(subject, "validate_alternate_contract", lambda: {})
    monkeypatch.setattr(
        subject, "validate_frozen_gate_and_auditor_identity", lambda: None
    )
    bound_paths: list[Path] = []

    def fake_binding(path: Path, _expected: str | None = None):
        bound_paths.append(Path(path))
        return {"path": str(path), "size": 1, "sha256": "0" * 64}

    def fake_primary_parser(path: Path):
        assert subject.W.EA_ROOT == subject.MAIN_EA_ROOT
        assert subject.W.BUILD_RECEIPT_PATH == (
            subject.MAIN_EA_ROOT
            / "docs"
            / "candidate-analysis"
            / "build_receipt_20260720.json"
        )
        assert path == subject.W.CONTRACT_PATH
        return {"status": "PREREGISTERED_UNTOUCHED_EVIDENCE"}

    monkeypatch.setattr(subject.B, "file_binding", fake_binding)
    monkeypatch.setattr(subject.W, "validate_transport_contract", fake_primary_parser)
    result = subject.validate_relocated_primary_transport_contract()
    assert result["status"] == "PREREGISTERED_UNTOUCHED_EVIDENCE"
    assert bound_paths == [
        runtime_build,
        runtime_ea
        / "sets"
        / "QM5_10834_tv-nq-ict-ob_WS30.DWX_M5_backtest.set",
    ]
    assert subject.W.EA_ROOT == runtime_ea
    assert subject.W.BUILD_RECEIPT_PATH == runtime_build


def test_frozen_merit_and_auditor_identity_is_enforced(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    subject.validate_frozen_gate_and_auditor_identity()
    changed = copy.deepcopy(subject.B.MERIT_GATES)
    changed["dev"]["minimum_trades"] += 1
    monkeypatch.setattr(subject.B, "MERIT_GATES", changed)
    with pytest.raises(subject.B.InvalidEvidence, match="merit contract drift"):
        subject.validate_frozen_gate_and_auditor_identity()


def test_actual_frozen_data_receipt_projects_only_six_approved_repo_bindings() -> None:
    raw = subject.B.load_json(subject.W.FUTURE_DATA_RECEIPT_PATH)
    projected = subject._project_data_receipt_repo_bindings(raw)
    assert projected["artifact_type"] == raw["artifact_type"]
    assert projected["factory_evidence"]["matrix"]["sha256"] == (
        raw["factory_evidence"]["matrix"]["sha256"]
    )
    assert projected["cost_schedule"]["supplemental_stress"]["slippage"][
        "source"
    ]["sha256"] == raw["cost_schedule"]["supplemental_stress"]["slippage"][
        "source"
    ]["sha256"]


def test_relocated_data_validator_binds_exact_attempt001_receipt() -> None:
    validated = subject.validate_relocated_backtest_data_receipt(
        subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
    )
    assert validated["receipt"] == {
        "path": str(subject.W.FUTURE_DATA_RECEIPT_PATH.resolve()),
        "size": subject.EXPECTED_DATA_RECEIPT_SIZE,
        "sha256": subject.EXPECTED_DATA_RECEIPT_SHA256,
    }


def test_relocated_data_validator_rejects_receipt_toctou(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        subject,
        "_BASE_VALIDATE_BACKTEST_DATA_RECEIPT",
        lambda *_args, **_kwargs: {
            "receipt": {
                "path": str(subject.W.FUTURE_DATA_RECEIPT_PATH.resolve()),
                "size": subject.EXPECTED_DATA_RECEIPT_SIZE,
                "sha256": "1" * 64,
            }
        },
    )
    with pytest.raises(subject.B.InvalidEvidence, match="changed during"):
        subject.validate_relocated_backtest_data_receipt(
            subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
        )


def test_data_receipt_validator_accepts_only_byte_identical_detached_projection(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime = tmp_path / "runtime"
    relative_paths = (
        Path("framework/V5_FRAMEWORK_DESIGN.md"),
        Path("framework/registry/execution_symbol_aliases_v1.json"),
        Path("framework/registry/venue_cost_model.json"),
        Path("framework/registry/dwx_symbol_matrix.csv"),
        Path("framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json"),
    )
    for relative in relative_paths:
        target = runtime / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(subject.MAIN_WORKTREE_ROOT / relative, target)
    monkeypatch.setattr(subject, "REPO_ROOT", runtime)
    monkeypatch.setattr(
        subject.B, "V5_FRAMEWORK_PATH", runtime / relative_paths[0]
    )
    monkeypatch.setattr(subject.B, "ALIASES_PATH", runtime / relative_paths[1])
    monkeypatch.setattr(subject.B, "COST_PATH", runtime / relative_paths[2])
    monkeypatch.setattr(subject.B, "MATRIX_PATH", runtime / relative_paths[3])
    monkeypatch.setattr(
        subject.W, "SLIPPAGE_CALIBRATION_PATH", runtime / relative_paths[4]
    )
    validated = subject.validate_relocated_backtest_data_receipt(
        subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
    )
    assert Path(validated["factory_evidence"]["matrix"]["path"]) == (
        runtime / relative_paths[3]
    )
    assert Path(
        validated["cost_schedule"]["supplemental_stress"]["slippage"][
            "source"
        ]["path"]
    ) == (runtime / relative_paths[4])

    (runtime / relative_paths[3]).write_bytes(b"tampered")
    with pytest.raises(subject.B.InvalidEvidence):
        subject.validate_relocated_backtest_data_receipt(
            subject.W.FUTURE_DATA_RECEIPT_PATH, "WS30.DWX"
        )


def test_data_receipt_projection_rejects_unapproved_main_repo_path() -> None:
    raw = subject.B.load_json(subject.W.FUTURE_DATA_RECEIPT_PATH)
    raw["unexpected_binding"] = {
        "path": str(subject.MAIN_WORKTREE_ROOT / "unexpected.txt"),
        "size": 1,
        "sha256": "0" * 64,
    }
    with pytest.raises(subject.B.InvalidEvidence, match="unapproved"):
        subject._project_data_receipt_repo_bindings(raw)


def test_bound_repository_byte_overlay_preserves_mixed_eol_exactly(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    source = tmp_path / "source"
    runtime = tmp_path / "runtime"
    source.mkdir()
    runtime.mkdir()
    (source / "a.txt").write_bytes(b"one\r\ntwo\r\n")
    (source / "b.txt").write_bytes(b"three\nfour\n")
    (runtime / "a.txt").write_bytes(b"one\ntwo\n")
    (runtime / "b.txt").write_bytes(b"three\r\nfour\r\n")
    relatives = ("a.txt", "b.txt")
    subject._overlay_exact_repository_binding_bytes(source, runtime, relatives)
    assert (runtime / "a.txt").read_bytes() == (source / "a.txt").read_bytes()
    assert (runtime / "b.txt").read_bytes() == (source / "b.txt").read_bytes()
    ledger = subject._build_repository_byte_identity_ledger(
        source, runtime, relatives
    )
    assert [row["relative_path"] for row in ledger] == list(relatives)

    monkeypatch.setattr(subject, "REPO_ROOT", runtime)
    monkeypatch.setattr(
        subject,
        "_repository_binding_relative_paths",
        lambda _root=runtime: relatives,
    )
    subject._validate_runtime_repository_binding_ledger(ledger)
    (runtime / "a.txt").write_bytes(b"one\ntwo\n")
    with pytest.raises(subject.B.InvalidEvidence):
        subject._validate_runtime_repository_binding_ledger(ledger)


def test_runtime_dependency_closure_includes_all_pre_and_recursive_include_roles() -> None:
    relatives = subject._repository_binding_relative_paths()
    assert len(relatives) == 56
    assert (
        "framework/EAs/QM5_10834_tv-nq-ict-ob/tools/candidate_analysis/"
        "audit_tv_nq_ict_ob_ws30_alternate.py"
    ) in relatives
    assert "framework/include/QM/QM_Common.mqh" in relatives
    assert "framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json" in relatives
    assert "framework/scripts/invoke_dev2_identity_probe.ps1" in relatives
    assert (
        "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
        "ws30_alt002_runtime_materialization_invalid_closure_20260721.json"
    ) in relatives
    assert (
        "framework/EAs/QM5_10834_tv-nq-ict-ob/docs/candidate-analysis/"
        "ws30_transport_infra_alternate002_runtime_fix001_contract_20260721.json"
    ) in relatives


def test_materializer_overlays_exact_bound_bytes_before_sealing_ledger() -> None:
    source = inspect.getsource(subject.materialize_runtime)
    checkout = source.index('"worktree"')
    overlay = source.index("_overlay_exact_repository_binding_bytes")
    final_clean = source.index(
        '"alternate runtime worktree after exact byte overlay"'
    )
    ledger = source.index("_build_repository_byte_identity_ledger")
    receipt = source.index("B.atomic_json")
    assert checkout < overlay < final_clean < ledger < receipt
    assert "core.autocrlf=false" not in source


@pytest.mark.skipif(
    not subject.PRIMARY_STATE_PATH.is_file(), reason="VPS primary control state absent"
)
def test_primary_invalid_infra_closure_revalidates_without_opening_any_log(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    opened_json: list[Path] = []
    original = subject.B.load_json

    def guarded_load_json(path: Path):
        observed = Path(path)
        if observed.suffix.casefold() == ".log":
            raise AssertionError("controller/probe log content must remain opaque")
        opened_json.append(observed.resolve())
        return original(path)

    monkeypatch.setattr(subject.B, "load_json", guarded_load_json)
    closure = subject.validate_primary_invalid_infra_closure()
    assert closure["status"] == "PRIMARY_INVALID_INFRA_CLOSED_NO_OUTCOME_READ"
    assert closure["allowed_alternate_cause_class"] == (
        "DEV2_CONTROLLER_FAILED_BEFORE_NATIVE_REPORT"
    )
    assert closure["directory_metadata_closure"]["native_report_file_count"] == 0
    assert closure["directory_metadata_closure"]["native_outcome_file_count"] == 0
    assert opened_json == [
        subject.PRIMARY_CLOSURE_PATH.resolve(),
        subject.PRIMARY_STATE_PATH.resolve(),
    ]


def test_primary_closure_implementation_never_semantically_reads_logs() -> None:
    source = inspect.getsource(subject.validate_primary_invalid_infra_closure)
    assert ".read_text(" not in source
    assert ".read_bytes(" not in source
    assert ".open(" not in source
    assert "B.load_json(PRIMARY_STATE_PATH)" in source
    assert "controller.stderr.log" not in source


def test_primary_closed_file_ledger_contains_only_control_and_opaque_logs() -> None:
    paths = [row[0] for row in subject.PRIMARY_EXPECTED_FILE_LEDGER]
    assert len(paths) == 9
    assert not any(Path(path).suffix.casefold() in {".htm", ".html"} for path in paths)
    assert not any(Path(path).name.casefold() == "summary.json" for path in paths)
    native = [path for path in paths if path.startswith("native\\")]
    assert native == [
        r"native\DEV\controller.stderr.log",
        r"native\DEV\controller.stdout.log",
    ]


def test_alternate_has_separate_one_shot_namespace_and_claim_profile() -> None:
    assert subject.ALTERNATE_RUN_ROOT != subject.W.PRIMARY_RUN_ROOT
    assert subject.ALTERNATE_PRE_RECEIPT_PATH.parent == subject.ALTERNATE_RUN_ROOT
    assert subject.ALTERNATE_CLAIM_PATH != subject.PRIMARY_CLAIM_PATH
    assert subject.ALTERNATE_CLAIM_PATH.name.endswith("ATTEMPT_002.json")
    assert subject.ALTERNATE_AUTHORIZATION_PATH.parent == subject.ALTERNATE_RUN_ROOT
    assert subject.B.CURRENT_CLAIM_SEQUENCE == 2
    assert subject.B.PRIOR_CLAIM_SEQUENCES == 1
    assert subject.B.PRIOR_COUNTED_ALTERNATE_ATTEMPTS == 0
    assert subject.B.AUTHORIZATION_SCOPE == subject.ALTERNATE_AUTHORIZATION_SCOPE
    contract = subject.execution_contract()
    assert contract["current_attempt_type"] == (
        "PREREGISTERED_INFRA_ALTERNATE_ONE_SHOT"
    )
    assert contract["current_attempt_number"] == 2
    assert contract["maximum_total_counted_attempts"] == 2
    assert contract["resume_permitted"] is False
    assert contract["further_attempts_forbidden"] is True
    assert contract["main_worktree_scoped_paths_clean_at_launch_required"] is True
    assert contract["main_worktree_scoped_path_count"] == 56
    assert contract["unrelated_main_worktree_dirt_ignored"] is True


def test_alternate_runtime_binds_every_imported_and_execution_dependency() -> None:
    paths = subject._expected_binding_paths("WS30.DWX")
    for role in (
        "tool",
        "base_tool",
        "ws30_primary_adapter",
        "alternate_contract",
        "runtime_fix_contract",
        "invalid_runtime_materialization_closure",
        "primary_invalid_infra_closure",
        "alternate_runtime_materialization_receipt",
        "dev2_identity_probe_child",
        "runner",
        "runner_child",
        "scheduled_task_helper",
    ):
        assert role in subject.B.REQUIRED_BINDING_ROLES
        assert role in paths
    assert paths["tool"].resolve() == subject.TOOL_PATH.resolve()
    assert paths["ws30_primary_adapter"].resolve() == (
        subject.PRIMARY_ADAPTER_PATH.resolve()
    )


def test_runtime_normalized_clean_head_rejects_staged_diff(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()
    head = "a" * 40

    def fake_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args == (
            "diff",
            "--cached",
            "--quiet",
            "--no-ext-diff",
            "--no-textconv",
            "--exit-code",
            "HEAD",
            "--",
        ):
            return _git_result(1)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", fake_git)
    with pytest.raises(subject.B.InvalidEvidence, match="staged diff"):
        subject._normalized_clean_head(root, "runtime", detached_required=True)


def test_runtime_normalized_clean_head_rejects_normalized_diff_untracked_or_attached(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()
    head = "b" * 40

    staged_args = (
        "diff",
        "--cached",
        "--quiet",
        "--no-ext-diff",
        "--no-textconv",
        "--exit-code",
        "HEAD",
        "--",
    )
    normalized_args = (
        "diff",
        "--quiet",
        "--no-ext-diff",
        "--no-textconv",
        "--exit-code",
        "--",
    )
    untracked_args = ("ls-files", "--others", "-z")

    def common(args: tuple[str, ...]):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args == staged_args:
            return _git_result(0)
        return None

    def normalized_dirty(_root: Path, *args: str, check: bool = True):
        result = common(args)
        if result is not None:
            return result
        if args == normalized_args:
            return _git_result(1)
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", normalized_dirty)
    with pytest.raises(subject.B.InvalidEvidence, match="normalized worktree diff"):
        subject._normalized_clean_head(root, "runtime", detached_required=True)

    def untracked_dirty(_root: Path, *args: str, check: bool = True):
        result = common(args)
        if result is not None:
            return result
        if args == normalized_args:
            return _git_result(0)
        if args == untracked_args:
            return _git_result(0, "ignored-cache.pyc\0")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", untracked_dirty)
    with pytest.raises(subject.B.InvalidEvidence, match="untracked files"):
        subject._normalized_clean_head(root, "runtime", detached_required=True)

    def attached_git(_root: Path, *args: str, check: bool = True):
        result = common(args)
        if result is not None:
            return result
        if args == normalized_args:
            return _git_result(0)
        if args == untracked_args:
            return _git_result(0)
        if args == ("symbolic-ref", "-q", "HEAD"):
            return _git_result(0, "refs/heads/main\n")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", attached_git)
    with pytest.raises(subject.B.InvalidEvidence, match="detached"):
        subject._normalized_clean_head(root, "runtime", detached_required=True)


def test_runtime_normalized_clean_head_accepts_diff_clean_even_if_porcelain_would_m(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()
    head = "c" * 40

    def fake_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args in {
            (
                "diff",
                "--cached",
                "--quiet",
                "--no-ext-diff",
                "--no-textconv",
                "--exit-code",
                "HEAD",
                "--",
            ),
            (
                "diff",
                "--quiet",
                "--no-ext-diff",
                "--no-textconv",
                "--exit-code",
                "--",
            ),
        }:
            return _git_result(0)
        if args == ("ls-files", "--others", "-z"):
            return _git_result(0)
        if args == ("symbolic-ref", "-q", "HEAD"):
            return _git_result(1)
        if args and args[0] == "status":
            raise AssertionError("porcelain status must not be queried")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", fake_git)
    assert subject._normalized_clean_head(root, "runtime", detached_required=True) == head


def test_runtime_normalized_clean_head_rejects_gitignored_untracked_real_repo(
    tmp_path: Path,
) -> None:
    root = tmp_path / "runtime"
    root.mkdir()

    def git(*args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            ["git", "-C", str(root), *args],
            check=True,
            capture_output=True,
            text=True,
            timeout=30,
        )

    git("init", "--quiet")
    git("config", "user.name", "QM test")
    git("config", "user.email", "qm-test@example.invalid")
    git("config", "commit.gpgsign", "false")
    git("config", "core.hooksPath", ".git/disabled-hooks")
    (root / ".gitignore").write_bytes(b"ignored-cache/\n")
    (root / "tracked.txt").write_bytes(b"bound\n")
    git("add", ".gitignore", "tracked.txt")
    git("commit", "--quiet", "-m", "fixture")
    git("checkout", "--quiet", "--detach", "HEAD")

    subject._normalized_clean_head(root, "runtime", detached_required=True)
    ignored = root / "ignored-cache"
    ignored.mkdir()
    (ignored / "worker.pyc").write_bytes(b"runtime mutation")

    with pytest.raises(subject.B.InvalidEvidence, match="untracked files"):
        subject._normalized_clean_head(root, "runtime", detached_required=True)


def test_main_scoped_clean_head_uses_only_literal_exact_pathspecs(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "main"
    root.mkdir()
    head = "c" * 40
    expected_status_args = (
        "status",
        "--porcelain=v1",
        "-z",
        "--untracked-files=all",
        "--",
        ":(literal)a.txt",
        ":(literal)dir/b.txt",
    )

    def fake_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args == expected_status_args:
            # An unrelated dirty path is deliberately absent from the literal
            # query and therefore cannot block this scoped gate.
            assert ":(literal)framework/registry/event_vocabulary.json" not in args
            return _git_result(0)
        if args == ("rev-parse", "HEAD^{commit}"):
            return _git_result(0, head + "\n")
        if args == ("symbolic-ref", "-q", "HEAD"):
            return _git_result(0, "refs/heads/main\n")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", fake_git)
    assert subject._scoped_clean_head(
        root,
        "main scope",
        ("a.txt", "dir/b.txt"),
        detached_required=False,
    ) == head


def test_main_scoped_clean_head_rejects_dirt_inside_exact_scope(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "main"
    root.mkdir()

    def fake_git(_root: Path, *args: str, check: bool = True):
        if args == ("rev-parse", "--show-toplevel"):
            return _git_result(0, str(root) + "\n")
        if args[:6] == (
            "status",
            "--porcelain=v1",
            "-z",
            "--untracked-files=all",
            "--",
            ":(literal)a.txt",
        ):
            return _git_result(0, " M a.txt\0")
        raise AssertionError(args)

    monkeypatch.setattr(subject, "_git_at", fake_git)
    with pytest.raises(subject.B.InvalidEvidence, match="exact scoped path set"):
        subject._scoped_clean_head(
            root, "main scope", ("a.txt",), detached_required=False
        )


def test_main_scope_identity_is_exact_56_file_dependency_closure() -> None:
    relatives = subject._main_scoped_relative_paths()
    assert len(relatives) == subject.MAIN_SCOPED_PATH_COUNT == 56
    assert subject.B.canonical_sha256(list(relatives)) == (
        subject.MAIN_SCOPED_PATH_LIST_SHA256
    )
    assert "framework/scripts/invoke_dev2_identity_probe.ps1" in relatives
    assert subject.B.canonical_sha256(list(relatives)) == (
        "b6f88751e1eb4345a48dc041d795c49fa2023da472abe59a115bcb7290ec31fd"
    )
    assert "framework/registry/event_vocabulary.json" not in relatives


def test_pre_fails_on_dirty_scoped_main_before_runtime_or_base_preflight(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    called = {"runtime": False, "base": False}

    def dirty(_stage: str):
        raise subject.B.InvalidEvidence("main scoped dependencies are dirty")

    def forbidden_runtime():
        called["runtime"] = True
        raise AssertionError("runtime inspection must follow clean-main gate")

    def forbidden_base(*_args, **_kwargs):
        called["base"] = True
        raise AssertionError("base PRE must follow clean-main gate")

    monkeypatch.setattr(subject, "assert_main_scoped_paths_clean", dirty)
    monkeypatch.setattr(subject, "_assert_runtime_location", forbidden_runtime)
    monkeypatch.setattr(subject, "_BASE_PREFLIGHT", forbidden_base)
    with pytest.raises(subject.B.InvalidEvidence, match="dirty"):
        subject.preflight(
            "WS30.DWX",
            subject.W.FUTURE_DATA_RECEIPT_PATH,
            subject.W.BUILD_RECEIPT_PATH,
            subject.ALTERNATE_RUN_ROOT,
        )
    assert called == {"runtime": False, "base": False}


def test_pre_readiness_failure_does_not_consume_canonical_receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    run_root = tmp_path / "alternate-run"
    receipt = run_root / "pre_receipt.json"
    data_receipt = tmp_path / "data.json"
    build_receipt = tmp_path / "build.json"
    monkeypatch.setattr(subject, "ALTERNATE_RUN_ROOT", run_root)
    monkeypatch.setattr(subject, "ALTERNATE_PRE_RECEIPT_PATH", receipt)
    monkeypatch.setattr(subject.W, "FUTURE_DATA_RECEIPT_PATH", data_receipt)
    monkeypatch.setattr(subject.W, "BUILD_RECEIPT_PATH", build_receipt)

    def fail_closed(*_args, **_kwargs):
        raise subject.B.InvalidEvidence("main worktree is dirty")

    monkeypatch.setattr(subject, "preflight", fail_closed)
    code = subject.main(
        [
            "pre",
            "--symbol",
            "WS30.DWX",
            "--data-receipt",
            str(data_receipt),
            "--build-receipt",
            str(build_receipt),
            "--run-root",
            str(run_root),
            "--receipt",
            str(receipt),
        ]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert "dirty" in captured.err
    assert not receipt.exists()
    assert not run_root.exists()


def test_materialization_refuses_dirty_scoped_main_before_git_worktree_add(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(subject, "RUNTIME_WORKTREE_ROOT", tmp_path / "runtime")
    monkeypatch.setattr(subject, "RUNTIME_RECEIPT_PATH", tmp_path / "receipt.json")

    def dirty(_stage: str):
        raise subject.B.InvalidEvidence("main worktree is dirty")

    def forbidden_run(*_args, **_kwargs):
        raise AssertionError("git worktree add must not run")

    monkeypatch.setattr(subject, "assert_main_scoped_paths_clean", dirty)
    monkeypatch.setattr(subject.subprocess, "run", forbidden_run)
    with pytest.raises(subject.B.InvalidEvidence, match="dirty"):
        subject.materialize_runtime()
    assert not (tmp_path / "runtime").exists()
    assert not (tmp_path / "receipt.json").exists()


def test_launch_resume_is_rejected_before_any_main_or_native_action(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        subject,
        "assert_main_scoped_paths_clean",
        lambda _stage: (_ for _ in ()).throw(AssertionError("must not inspect")),
    )
    monkeypatch.setattr(
        subject,
        "_BASE_LAUNCH_DETACHED",
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError("must not launch")
        ),
    )
    with pytest.raises(subject.B.AuthorizationError, match="never permits resume"):
        subject.launch_detached(
            subject.ALTERNATE_PRE_RECEIPT_PATH,
            "0" * 64,
            subject.ALTERNATE_AUTHORIZATION_PATH,
            subject.ALTERNATE_STATE_PATH,
            resume=True,
        )


@pytest.mark.parametrize(
    "arguments",
    [
        ["status", "--state", "{primary_state}"],
        [
            "launch",
            "--pre-receipt",
            "{primary_pre}",
            "--pre-sha256",
            "0" * 64,
            "--authorization",
            "{primary_auth}",
            "--state",
            "{primary_state}",
        ],
        ["_run-plan", "--job", "{primary_job}"],
    ],
)
def test_primary_control_paths_are_rejected_before_read_or_dispatch(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
    arguments: list[str],
) -> None:
    rendered = [
        value.format(
            primary_state=subject.W.PRIMARY_STATE_PATH,
            primary_pre=subject.W.PRIMARY_PRE_RECEIPT_PATH,
            primary_auth=subject.W.PRIMARY_AUTHORIZATION_PATH,
            primary_job=subject.W.PRIMARY_JOB_PATH,
        )
        for value in arguments
    ]
    called = {"load": False, "dispatch": False}

    def forbidden_load(*_args, **_kwargs):
        called["load"] = True
        raise AssertionError("primary control file must not be opened")

    def forbidden_dispatch(*_args, **_kwargs):
        called["dispatch"] = True
        raise AssertionError("invalid path must not dispatch")

    monkeypatch.setattr(subject.B, "load_json", forbidden_load)
    monkeypatch.setattr(subject.B, "main", forbidden_dispatch)
    code = subject.main(rendered)
    captured = capsys.readouterr()
    assert code == 2
    assert called == {"load": False, "dispatch": False}
    assert "lexically exact" in captured.err


def test_cli_exposes_no_gate_parameter_cost_or_attempt_override() -> None:
    parser = subject.B.build_parser()
    help_text = parser.format_help()
    assert "--minimum-trades" not in help_text
    assert "--profit-factor" not in help_text
    assert "--commission" not in help_text
    launch = next(
        action for action in parser._actions if action.dest == "command"
    ).choices["launch"]
    option_strings = {
        option for action in launch._actions for option in action.option_strings
    }
    assert option_strings == {
        "-h",
        "--help",
        "--pre-receipt",
        "--pre-sha256",
        "--authorization",
        "--state",
        "--resume",
    }
    assert subject.B.MERIT_GATES == subject.W.B.MERIT_GATES
