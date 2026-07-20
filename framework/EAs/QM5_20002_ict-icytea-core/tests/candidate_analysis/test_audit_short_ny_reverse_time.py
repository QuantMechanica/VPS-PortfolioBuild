from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import threading
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from types import SimpleNamespace

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_short_ny_reverse_time.py"
)
SPEC = importlib.util.spec_from_file_location("audit_short_ny_reverse_time", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _plan_runtime() -> dict:
    return {
        "dev1_machine_credential": {"sha256": "c" * 64},
        "dev1_machine_credential_helper": {"sha256": "d" * 64},
    }


def test_contract_v3_binds_source_corrections_news_and_fill_invalid_gate() -> None:
    contract = subject.load_contract()
    assert contract["schema_version"] == 2
    assert contract["contract_revision"] == 3
    assert len(contract["data_bindings"]["news_calendars"]) == 2
    assert contract["execution_integrity_gates"]["violation_disposition"] == "INVALID"
    assert contract["revision_3_causal_semantics"][
        "pre_sweep_fvg_may_satisfy_displacement"
    ] is False
    assert contract["revision_3_calendar_and_runtime_safety"][
        "broker_d1_levels_forbidden"
    ] is True


@pytest.mark.parametrize("encoding", ["utf-8", "utf-8-sig", "utf-16", "utf-32"])
def test_compile_log_decoder_accepts_metaeditor_bom_formats(encoding: str) -> None:
    text = "Result: 0 errors, 0 warnings\r\n"
    assert subject.decode_compile_log(text.encode(encoding)) == text


def test_compile_log_decoder_rejects_unsupported_bytes() -> None:
    with pytest.raises(subject.PreflightError, match="encoding unsupported"):
        subject.decode_compile_log(b"\x80\x81\x82")


def test_compile_binding_closes_exact_evidence_binary_and_toolchain() -> None:
    payload = json.loads(subject.COMPILE_BINDING_PATH.read_text(encoding="utf-8"))
    closure = subject.validate_compile_binding(Path(payload["compile"]["evidence_path"]))
    assert closure["document"]["commit"] == subject.COMPILE_BINDING_COMMIT
    assert closure["document"]["binding"]["sha256"] == subject.EXPECTED_COMPILE_BINDING_SHA256
    assert closure["evidence"]["sha256"] == subject.EXPECTED_COMPILE_EVIDENCE_SHA256
    assert closure["compiled_binary"]["sha256"] == subject.EXPECTED_COMPILED_EX5_SHA256
    historical = closure["toolchain"]["compile_controller_historical_blob"]
    assert historical["git_commit"] == payload["toolchain"]["compile_controller_git_commit"]
    assert historical["sha256"] == payload["toolchain"]["compile_controller_sha256"]
    assert closure["toolchain"]["compile_controller_current_runtime"]["sha256"] == subject.sha256_file(
        subject.COMPILE_CONTROLLER_PATH
    )


@pytest.mark.parametrize("mutation", ["missing", "drift"])
def test_preflight_rejects_manifest_compile_binding_omission_or_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, mutation: str
) -> None:
    manifest = json.loads(subject.SET_MANIFEST_PATH.read_text(encoding="utf-8"))
    if mutation == "missing":
        manifest.pop("compile_binding_sha256", None)
    else:
        manifest["compile_binding_sha256"] = "0" * 64
    adversarial = tmp_path / "manifest.json"
    adversarial.write_text(json.dumps(manifest), encoding="utf-8")
    monkeypatch.setattr(subject, "SET_MANIFEST_PATH", adversarial)
    monkeypatch.setattr(subject, "validate_source_closure", lambda _contract: {})
    monkeypatch.setattr(subject, "validate_compile_evidence", lambda *_args: {})
    with pytest.raises(subject.PreflightError, match="set manifest contract/compile identity drift"):
        subject.preflight(tmp_path / "unused-evidence.json")


def test_set_metadata_cannot_claim_a_different_compiled_binary(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    contract = subject.load_contract()
    original_root = subject.EA_ROOT
    manifest = json.loads(subject.SET_MANIFEST_PATH.read_text(encoding="utf-8"))
    for row in manifest["sets"]:
        relative = Path(row["path"])
        target = tmp_path / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((original_root / relative).read_bytes())
    first = manifest["sets"][0]
    first_path = tmp_path / first["path"]
    tampered = first_path.read_bytes().replace(
        subject.EXPECTED_COMPILED_EX5_SHA256.encode("ascii"), b"0" * 64, 1
    )
    first_path.write_bytes(tampered)
    first["size"] = len(tampered)
    first["sha256"] = subject.sha256_file(first_path)
    manifest_path = tmp_path / "sets" / "candidate-analysis" / "manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    monkeypatch.setattr(subject, "EA_ROOT", tmp_path)
    monkeypatch.setattr(subject, "SET_MANIFEST_PATH", manifest_path)
    with pytest.raises(subject.PreflightError, match="set metadata drift"):
        subject.validate_sets(contract)


def test_four_cell_plan_is_exact_and_model4() -> None:
    contract = subject.load_contract()
    cells, _ = subject.validate_sets(contract)
    runtime = _plan_runtime()
    plan = subject.build_plan(cells, 28800, runtime)
    assert plan["cell_count"] == 4
    assert plan["total_native_runs"] == 8
    assert plan["model"] == 4
    assert len({cell["cell_id"] for cell in plan["cells"]}) == 4
    for cell in plan["cells"]:
        args = cell["runner_arguments"]
        assert args[args.index("-Model") + 1] == "4"
        assert args[args.index("-Runs") + 1] == "2"
        assert args[args.index("-CommissionPerLot") + 1] == "0"
        assert args[args.index("-CommissionPerSideNative") + 1] == "0"
        assert args.count("-ExpectedCredentialSha256") == 1
        assert args[args.index("-ExpectedCredentialSha256") + 1] == "c" * 64
        assert args.count("-ExpectedHelperSha256") == 1
        assert args[args.index("-ExpectedHelperSha256") + 1] == "d" * 64
        assert args[args.index("-ControllerTimeoutSeconds") + 1] == "118200"


def _rotation_receipt_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict, Path, dict]:
    lane_path = tmp_path / "repo" / "dev1_lane_contract.json"
    credential_path = tmp_path / "programdata" / "credential.machine-dpapi.json"
    receipt_path = tmp_path / "programdata" / "credential.machine-dpapi.rotation-receipt.json"
    helper_path = tmp_path / "repo" / "dev1_machine_credential.ps1"
    child_path = tmp_path / "repo" / "invoke_dev1_identity_probe.ps1"
    legacy_path = tmp_path / "programdata" / "credential.clixml"
    rotation_root = tmp_path / "reports" / "credential-rotation"
    rotation_id = "20260721T010000Z_" + "a" * 32
    request_path = rotation_root / rotation_id / "control" / "identity_probe_request.json"
    result_path = rotation_root / rotation_id / "output" / "identity_probe_result.json"
    for path, payload in (
        (helper_path, b"credential helper"),
        (child_path, b"identity child"),
        (legacy_path, b"preserved legacy"),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)

    target_sid = "S-1-5-21-100-200-300-1005"
    target_account = "TESTHOST\\QMDev1"
    generation_id = "b" * 32
    current = datetime.now(timezone.utc)
    credential = {
        "schema_version": 1,
        "artifact_type": "QM_DEV1_MACHINE_DPAPI_CREDENTIAL",
        "contract_id": "QM_DEV1_ISOLATED_MT5_LANE_V3",
        "lane": "DEV1",
        "account": target_account,
        "target_sid": target_sid,
        "host_account_domain_sid": "S-1-5-21-100-200-300",
        "dpapi_scope": "LocalMachine",
        "text_encoding": "UTF-8",
        "generation_id": generation_id,
        "created_utc": (current - timedelta(minutes=4)).isoformat(),
        "ciphertext_base64": "YWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFhYWE=",
    }
    credential_path.parent.mkdir(parents=True, exist_ok=True)
    credential_path.write_text(json.dumps(credential), encoding="utf-8")
    request = {
        "schema_version": 1,
        "artifact_type": "QM_DEV1_IDENTITY_PROBE_REQUEST",
        "nonce": "c" * 32,
        "created_utc": (current - timedelta(minutes=3)).isoformat(),
        "expires_utc": (current + timedelta(minutes=7)).isoformat(),
        "expected_account": target_account,
        "expected_sid": target_sid,
        "expected_profile": r"C:\Users\QMDev1",
        "expected_task_name": "QM_DEV1_SMOKE_" + "d" * 32,
        "result_path": str(result_path.resolve()),
    }
    request_path.parent.mkdir(parents=True, exist_ok=True)
    request_path.write_text(json.dumps(request), encoding="utf-8")
    result = {
        "schema_version": 1,
        "artifact_type": "QM_DEV1_IDENTITY_PROBE_RESULT",
        "status": "PASS",
        "completed_utc": (current - timedelta(minutes=2)).isoformat(),
        "nonce": request["nonce"],
        "account": target_account,
        "sid": target_sid,
        "profile": r"C:\Users\QMDev1",
        "limited_non_admin": True,
        "request_sha256": subject.sha256_file(request_path),
    }
    result_path.parent.mkdir(parents=True, exist_ok=True)
    result_path.write_text(json.dumps(result), encoding="utf-8")
    lane = {
        "schema_version": 3,
        "contract_id": "QM_DEV1_ISOLATED_MT5_LANE_V3",
        "lane": "DEV1",
        "identity": {
            "local_user": "QMDev1",
            "profile": r"C:\Users\QMDev1",
            "credential": str(credential_path.resolve()),
            "legacy_credential": str(legacy_path.resolve()),
            "credential_format": "QM_DEV1_MACHINE_DPAPI_CREDENTIAL",
            "dpapi_scope": "LocalMachine",
            "limited_non_admin": True,
        },
    }
    lane_path.parent.mkdir(parents=True, exist_ok=True)
    lane_path.write_text(json.dumps(lane), encoding="utf-8")
    receipt = {
        "schema_version": 1,
        "artifact_type": "QM_DEV1_MACHINE_CREDENTIAL_ROTATION_RECEIPT",
        "status": "PASS",
        "completed_utc": (current - timedelta(minutes=1)).isoformat(),
        "contract_id": lane["contract_id"],
        "target_account": target_account,
        "target_sid": target_sid,
        "target_disabled_at_rest": True,
        "target_password_required_at_rest": True,
        "machine_credential_path": str(credential_path.resolve()),
        "machine_credential_sha256": subject.sha256_file(credential_path),
        "machine_credential_generation_id": generation_id,
        "machine_credential_helper_path": str(helper_path.resolve()),
        "machine_credential_helper_sha256": subject.sha256_file(helper_path),
        "identity_probe_child_path": str(child_path.resolve()),
        "identity_probe_child_sha256": subject.sha256_file(child_path),
        "identity_probe_result_path": str(result_path.resolve()),
        "identity_probe_result_sha256": subject.sha256_file(result_path),
        "identity_probe_logon_type": "Password",
        "identity_probe_run_level": "Limited",
        "machine_credential_matches_proved_password": True,
        "published_after_identity_proof": True,
        "legacy_credential_path": str(legacy_path.resolve()),
        "legacy_credential_preserved": True,
        "cleanup_lease_disarmed": True,
        "owner_process_count": 0,
        "dev1_root_process_count": 0,
    }
    receipt_path.write_text(json.dumps(receipt), encoding="utf-8")
    monkeypatch.setattr(subject, "DEV1_LANE_CONTRACT_PATH", lane_path)
    monkeypatch.setattr(subject, "MACHINE_CREDENTIAL_PATH", credential_path)
    monkeypatch.setattr(subject, "MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH", receipt_path)
    monkeypatch.setattr(subject, "CREDENTIAL_HELPER_PATH", helper_path)
    monkeypatch.setattr(subject, "IDENTITY_PROBE_CHILD_PATH", child_path)
    monkeypatch.setattr(subject, "LEGACY_CREDENTIAL_PATH", legacy_path)
    monkeypatch.setattr(subject, "DEV1_CREDENTIAL_ROTATION_ROOT", rotation_root)
    runtime = {
        "dev1_lane_contract": subject.file_binding(lane_path),
        "dev1_machine_credential": subject.file_binding(credential_path),
        "dev1_machine_credential_helper": subject.file_binding(helper_path),
        "dev1_identity_probe_child": subject.file_binding(child_path),
        "dev1_machine_credential_rotation_receipt": subject.file_binding(receipt_path),
    }
    return runtime, receipt_path, receipt


def test_rotation_receipt_semantically_binds_v3_credential_and_identity_proof(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime, _path, receipt = _rotation_receipt_fixture(tmp_path, monkeypatch)
    validated = subject.validate_machine_credential_rotation_receipt(runtime)
    assert validated["generation_id"] == receipt["machine_credential_generation_id"]
    assert validated["target_sid"] == receipt["target_sid"]
    assert validated["receipt"] == runtime["dev1_machine_credential_rotation_receipt"]


def test_rotation_receipt_rejects_uppercase_hash_and_duplicate_property(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime, path, receipt = _rotation_receipt_fixture(tmp_path, monkeypatch)
    receipt["machine_credential_sha256"] = receipt["machine_credential_sha256"].upper()
    path.write_text(json.dumps(receipt), encoding="utf-8")
    runtime["dev1_machine_credential_rotation_receipt"] = subject.file_binding(path)
    with pytest.raises(subject.AuditError, match="canonical lowercase"):
        subject.validate_machine_credential_rotation_receipt(runtime)

    raw = json.dumps(receipt | {"machine_credential_sha256": receipt["machine_credential_sha256"].lower()})
    path.write_text(raw[:-1] + ',"status":"PASS"}', encoding="utf-8")
    runtime["dev1_machine_credential_rotation_receipt"] = subject.file_binding(path)
    with pytest.raises(subject.AuditError, match="duplicate JSON property"):
        subject.validate_machine_credential_rotation_receipt(runtime)


def test_rotation_receipt_rejects_legacy_only_runtime(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    runtime, _path, _receipt = _rotation_receipt_fixture(tmp_path, monkeypatch)
    runtime.pop("dev1_machine_credential")
    with pytest.raises(subject.AuditError, match="bindings are incomplete"):
        subject.validate_machine_credential_rotation_receipt(runtime)


def test_expected_model4_data_fence_stops_at_202112() -> None:
    paths = subject._expected_data_paths()
    ticks = [path for path in paths if "\\ticks\\" in path]
    assert len(paths) == 113
    assert len(ticks) == 102
    assert all("2022" not in path for path in paths)
    assert any(path.endswith("201710.tkc") for path in ticks)
    assert any(path.endswith("202112.tkc") for path in ticks)


def test_news_binding_seals_effective_qmdev1_file_common(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    seed_root = tmp_path / "seed"
    common_root = tmp_path / "common"
    seed_root.mkdir()
    common_root.mkdir()
    seed = seed_root / "calendar.csv"
    mirror = common_root / seed.name
    seed.write_bytes(b"datetime,currency,impact\n2020.01.01 12:00,USD,High\n")
    mirror.write_bytes(seed.read_bytes())
    digest = subject.sha256_file(seed)
    monkeypatch.setattr(subject, "DEV1_COMMON_FILES_ROOT", common_root)
    result = subject.validate_news_bindings(
        {
            "data_bindings": {
                "news_calendars": [
                    {"role": "TEST", "path": str(seed), "sha256": digest}
                ]
            }
        }
    )
    assert result[0]["binding"]["sha256"] == digest
    assert result[0]["tester_common_binding"]["sha256"] == digest


def test_news_binding_rejects_effective_mirror_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    seed_root = tmp_path / "seed"
    common_root = tmp_path / "common"
    seed_root.mkdir()
    common_root.mkdir()
    seed = seed_root / "calendar.csv"
    seed.write_bytes(b"seed")
    (common_root / seed.name).write_bytes(b"drift")
    monkeypatch.setattr(subject, "DEV1_COMMON_FILES_ROOT", common_root)
    with pytest.raises(subject.AuditError, match="SHA-256 drift"):
        subject.validate_news_bindings(
            {
                "data_bindings": {
                    "news_calendars": [
                        {
                            "role": "TEST",
                            "path": str(seed),
                            "sha256": subject.sha256_file(seed),
                        }
                    ]
                }
            }
        )


def test_broker_new_york_conversion_matches_frozen_minus_seven_hours() -> None:
    for broker in (
        datetime(2019, 1, 15, 14, 0),
        datetime(2019, 7, 15, 14, 0),
        datetime(2020, 3, 8, 14, 0),
        datetime(2020, 11, 1, 14, 0),
    ):
        assert subject.broker_to_new_york(broker) == broker.replace(hour=7)


def test_news_blackout_is_inclusive_and_symbol_specific() -> None:
    events = [
        (datetime(2020, 1, 2, 13, 30), "USD", "HIGH"),
        (datetime(2020, 1, 2, 15, 0), "JPY", "HIGH"),
    ]
    news = {"events": events, "times": [row[0] for row in events]}
    assert subject.news_blackout(news, datetime(2020, 1, 2, 13, 0), "EURUSD.DWX")
    assert subject.news_blackout(news, datetime(2020, 1, 2, 14, 0), "GBPUSD.DWX")
    assert not subject.news_blackout(news, datetime(2020, 1, 2, 14, 1), "EURUSD.DWX")
    assert not subject.news_blackout(news, datetime(2020, 1, 2, 15, 0), "EURUSD.DWX")


def test_opening_fill_gate_rejects_outside_kz_and_bound_news() -> None:
    outside = subject.NativeAudit(
        receipt={},
        deals=[SimpleNamespace(direction="in", time=datetime(2020, 1, 2, 13, 59), deal="1")],
        fragments=[],
        trades=[],
    )
    with pytest.raises(subject.PostflightError, match="OUTSIDE_NY_07_10"):
        subject._validate_opening_fills(
            outside, "EURUSD.DWX", {"events": [], "times": []}
        )

    news_time = datetime(2020, 1, 2, 12, 0)
    inside_news = subject.NativeAudit(
        receipt={},
        deals=[SimpleNamespace(direction="in", time=datetime(2020, 1, 2, 14, 0), deal="2")],
        fragments=[],
        trades=[],
    )
    with pytest.raises(subject.PostflightError, match="INSIDE_BOUND_NEWS_BLACKOUT_UNION"):
        subject._validate_opening_fills(
            inside_news,
            "EURUSD.DWX",
            {"events": [(news_time, "USD", "HIGH")], "times": [news_time]},
        )


def test_input_equivalence_is_typed_but_not_permissive() -> None:
    assert subject._input_equivalent("0.0", "0,00")
    assert subject._input_equivalent("true", "TRUE")
    assert subject._input_equivalent("16385", "16385")
    assert not subject._input_equivalent("true", "1")
    assert not subject._input_equivalent("high", "HIGH")


def test_cost_and_slippage_are_applied_per_side_volume() -> None:
    row = {
        "volume": Decimal("1.25"),
        "raw_net": Decimal("100.00"),
        "external_cost": Decimal("7.50"),
    }
    assert subject._scenario_net(row, 0) == Decimal("92.50")
    assert subject._scenario_net(row, 2) == Decimal("87.50")
    assert subject._scenario_net(row, 5) == Decimal("80.00")


def test_duplicate_fingerprint_includes_deal_and_run_identity() -> None:
    payload = [{"time": "2020-01-01T12:00:00", "deal": "2", "price": "1.1"}]
    baseline = subject.canonical_sha256(payload)
    assert baseline == subject.canonical_sha256(json.loads(json.dumps(payload)))
    payload[0]["price"] = "1.10001"
    assert baseline != subject.canonical_sha256(payload)


def test_authorization_rejects_wrong_pre_binding(tmp_path: Path) -> None:
    auth = tmp_path / "authorization.json"
    auth.write_text(
        json.dumps(
            {
                "analysis_id": subject.ANALYSIS_ID,
                "pre_receipt_sha256": "a" * 64,
                "scope": "QM5_20002_4_CELLS_X_2_DUPLICATES_MODEL4",
                "mt5_execution_authorized": True,
                "authorized_by": "OWNER",
                "authorized_utc": "2026-07-20T02:00:00Z",
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(subject.AuthorizationError, match="pre_receipt_sha256"):
        subject.validate_authorization(auth, "b" * 64)


def test_detached_timeout_leaves_inner_controller_cleanup_margin() -> None:
    pre = {
        "plan": {
            "duplicates_per_cell": 2,
            "cells": [
                {
                    "runner_arguments": [
                        "-TimeoutSeconds", "28800", "-ControllerTimeoutSeconds", "118200"
                    ]
                },
                {
                    "runner_arguments": [
                        "-TimeoutSeconds", "28800", "-ControllerTimeoutSeconds", "118200"
                    ]
                },
            ],
        }
    }
    assert subject.required_controller_timeout(pre) == 120000


@pytest.mark.parametrize(
    ("tester_timeout", "inner_timeout", "outer_timeout"),
    [(60, 3240, 5040), (28800, 118200, 120000)],
)
def test_v3_timeout_boundaries_are_exact(
    tester_timeout: int, inner_timeout: int, outer_timeout: int
) -> None:
    pre = {
        "plan": {
            "duplicates_per_cell": 2,
            "cells": [
                {
                    "runner_arguments": [
                        "-TimeoutSeconds",
                        str(tester_timeout),
                        "-ControllerTimeoutSeconds",
                        str(inner_timeout),
                    ]
                }
            ],
        }
    }
    assert subject.required_controller_timeout(pre) == outer_timeout


def test_v3_timeout_rejects_duplicate_or_stale_inner_argument() -> None:
    duplicate = {
        "plan": {
            "duplicates_per_cell": 2,
            "cells": [
                {
                    "runner_arguments": [
                        "-TimeoutSeconds", "28800", "-ControllerTimeoutSeconds", "118200",
                        "-ControllerTimeoutSeconds", "118200",
                    ]
                }
            ],
        }
    }
    with pytest.raises(subject.AuthorizationError, match="malformed"):
        subject.required_controller_timeout(duplicate)
    duplicate["plan"]["cells"][0]["runner_arguments"] = [
        "-TimeoutSeconds", "28800", "-ControllerTimeoutSeconds", "118199"
    ]
    with pytest.raises(subject.AuthorizationError, match="differs from V3 minimum"):
        subject.required_controller_timeout(duplicate)


def _controller_result_fixture(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[dict, dict]:
    sid = "S-1-5-21-100-200-300-1005"
    now = datetime.now(timezone.utc)
    lane_path = tmp_path / "dev1_lane_contract.json"
    metatester = tmp_path / "DEV1" / "metatester64.exe"
    metatester.parent.mkdir(parents=True)
    metatester.write_bytes(b"metatester")
    metatester_sha = subject.sha256_file(metatester)
    lane = {
        "coordination": {"controller_mutex": r"Global\QM_DEV1_SMOKE_CONTROLLER"},
        "program_sha256": {"metatester64.exe": metatester_sha},
        "agent_port_contract": {
            "minimum_port": 3000,
            "maximum_port": 65535,
            "require_runtime_listener_proof": True,
            "require_exact_dev1_metatester_path": True,
            "require_no_concurrent_overlapping_endpoint_owner": True,
            "allow_released_baseline_endpoint_reuse": True,
        },
    }
    lane_path.write_text(json.dumps(lane), encoding="utf-8")
    bindings: dict[str, dict] = {"dev1_lane_contract": subject.file_binding(lane_path)}
    for role in (
        "dev1_machine_credential",
        "dev1_machine_credential_helper",
        "runner_child",
        "runner_smoke",
        "dev1_cleanup_helper",
        "tester_groups_canonical",
    ):
        path = tmp_path / f"{role}.bin"
        path.write_bytes(role.encode("ascii"))
        bindings[role] = subject.file_binding(path)
    groups_dev1 = tmp_path / "DEV1" / "Groups" / "Darwinex-Live_real.txt"
    groups_dev1.parent.mkdir(parents=True)
    groups_dev1.write_bytes(Path(bindings["tester_groups_canonical"]["path"]).read_bytes())
    common_files = tmp_path / "QMDev1" / "Common" / "Files"
    common_files.mkdir(parents=True)
    run_root = tmp_path / "runs"
    run_id = "20260721T010000Z_" + "e" * 32
    monkeypatch.setattr(subject, "METATESTER_PATH", metatester)
    monkeypatch.setattr(subject, "GROUP_CANONICAL_PATH", Path(bindings["tester_groups_canonical"]["path"]))
    monkeypatch.setattr(subject, "GROUP_DEV1_PATH", groups_dev1)
    monkeypatch.setattr(subject, "DEV1_COMMON_FILES_ROOT", common_files)
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", run_root)
    started = now - timedelta(minutes=1)
    finished = now
    listener = {
        "local_address": "127.0.0.1",
        "local_port": 3001,
        "process_id": 4321,
        "owner_sid": sid,
        "executable_path": str(metatester.resolve()),
        "creation_utc": started.isoformat(),
        "first_observed_utc": (started + timedelta(seconds=1)).isoformat(),
        "preexisting_port_owner": False,
        "concurrent_port_owner": False,
        "exclusive_current_owner": True,
        "current_overlapping_owner_count": 1,
        "baseline_endpoint_was_occupied": False,
        "released_baseline_owner_count": 0,
    }
    result = {
        "schema_version": 2,
        "run_id": run_id,
        "nonce": "f" * 32,
        "success": True,
        "error_code": None,
        "error_message": None,
        "run_smoke_exit_code": 0,
        "identity_sid": sid,
        "common_path": str(common_files.parent.resolve()),
        "expected_task_name": "QM_DEV1_SMOKE_" + "1" * 32,
        "controller_mutex": lane["coordination"]["controller_mutex"],
        "lane_contract_sha256": bindings["dev1_lane_contract"]["sha256"],
        "machine_credential_sha256": bindings["dev1_machine_credential"]["sha256"],
        "machine_credential_helper_sha256": bindings["dev1_machine_credential_helper"]["sha256"],
        "child_sha256": bindings["runner_child"]["sha256"],
        "run_smoke_sha256": bindings["runner_smoke"]["sha256"],
        "program_sha256": lane["program_sha256"],
        "agent_port_proof": {
            "status": "PASS",
            "preexisting_port_owner": False,
            "concurrent_port_owner": False,
            "exclusivity_semantics": "NO_CONCURRENT_OVERLAPPING_ENDPOINT_OWNER",
            "released_baseline_endpoint_reuse_allowed": True,
            "metatester_path": str(metatester.resolve()),
            "metatester_sha256": metatester_sha,
            "listeners": [listener],
        },
        "started_utc": started.isoformat(),
        "finished_utc": finished.isoformat(),
        "log_path": str((run_root / run_id / "output" / "run.log").resolve()),
        "tester_groups_post_child_sha256": bindings["tester_groups_canonical"]["sha256"],
        "tester_groups_restored_sha256": bindings["tester_groups_canonical"]["sha256"],
        "tester_groups_canonical_path": str(Path(bindings["tester_groups_canonical"]["path"]).resolve()),
        "tester_groups_dev1_path": str(groups_dev1.resolve()),
        "dev1_account_initially_enabled": False,
        "dev1_account_enabled_by_controller": True,
        "dev1_account_restored_disabled": True,
        "cleanup_helper_sha256": bindings["dev1_cleanup_helper"]["sha256"],
        "cleanup_lease_registered": True,
        "cleanup_lease_disarmed": True,
    }
    pre = {"runtime": bindings, "machine_credential_rotation": {"target_sid": sid}}
    return result, pre


def test_controller_result_exactly_binds_v3_runtime_and_cleanup(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    result, pre = _controller_result_fixture(tmp_path, monkeypatch)
    assert subject.validate_dev1_controller_result(result, pre) == result["run_id"]


@pytest.mark.parametrize(
    ("field", "mutation", "message"),
    [
        ("machine_credential_sha256", lambda value: value.upper(), "runtime binding drift"),
        ("cleanup_helper_sha256", lambda _value: "0" * 64, "runtime binding drift"),
        ("dev1_account_restored_disabled", lambda _value: False, "lifecycle proof drift"),
        ("tester_groups_restored_sha256", lambda _value: "0" * 64, "restore binding drift"),
    ],
)
def test_controller_result_rejects_v3_runtime_or_lifecycle_drift(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    field: str,
    mutation,
    message: str,
) -> None:
    result, pre = _controller_result_fixture(tmp_path, monkeypatch)
    result[field] = mutation(result[field])
    with pytest.raises(subject.AuditError, match=message):
        subject.validate_dev1_controller_result(result, pre)


def test_controller_result_rejects_missing_extra_and_duplicate_json_fields(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    result, pre = _controller_result_fixture(tmp_path, monkeypatch)
    missing = dict(result)
    missing.pop("cleanup_lease_disarmed")
    with pytest.raises(subject.AuditError, match="field closure drift"):
        subject.validate_dev1_controller_result(missing, pre)
    extra = dict(result, legacy_credential_sha256="0" * 64)
    with pytest.raises(subject.AuditError, match="field closure drift"):
        subject.validate_dev1_controller_result(extra, pre)
    raw = json.dumps(result)
    duplicate = raw[:-1] + ',"success":true}'
    with pytest.raises(subject.PostflightError, match="exactly one complete JSON"):
        subject._parse_single_json_envelope(duplicate, "DEV1 controller stdout")


def _minimal_launcher_pre() -> dict:
    return {
        "tool": subject.file_binding(subject.TOOL_PATH),
        "runtime": {
            "scheduled_task_helper": subject.file_binding(
                subject.SCHEDULED_TASK_HELPER_PATH
            ),
            "python_binary": subject.file_binding(Path(sys.executable)),
            "powershell_binary": {"path": str(subject.POWERSHELL_PATH)},
        },
        "plan": {
            "cell_count": 4,
            "duplicates_per_cell": 2,
            "plan_sha256": "a" * 64,
            "cells": [
                {
                    "runner_arguments": [
                        "-TimeoutSeconds", "28800", "-ControllerTimeoutSeconds", "118200"
                    ]
                }
                for _ in range(4)
            ],
        },
    }


def _minimal_running_state(tmp_path: Path) -> dict:
    job_path = tmp_path / "launch_job.json"
    job = {"authorization": {}, "scheduler": {}}
    job_path.write_text(json.dumps(job), encoding="utf-8")
    state = subject._initial_launch_state(
        tmp_path / "pre_receipt.json",
        "c" * 64,
        subject.file_binding(job_path),
        job,
    )
    state["status"] = "RUNNING"
    state["worker_pid"] = 1234
    state["started_utc"] = state["created_utc"]
    return state


def test_persisted_task_timeout_covers_all_cells_and_cleanup_margin() -> None:
    pre = _minimal_launcher_pre()
    assert subject.required_scheduled_task_timeout(pre, 120000) == 483600


def test_persisted_helper_is_s4u_triggerless_and_never_overwrites_task() -> None:
    helper = subject.SCHEDULED_TASK_HELPER_PATH.read_text(encoding="utf-8")
    tool = subject.TOOL_PATH.read_text(encoding="utf-8")
    assert "-LogonType S4U" in helper
    assert "-RunLevel Highest" in helper
    assert "-MultipleInstances IgnoreNew" in helper
    assert "New-ScheduledTaskTrigger" not in helper
    assert "Register-ScheduledTask" in helper
    assert " -Force" not in helper
    assert "DETACHED_PROCESS" not in tool
    assert "CREATE_NEW_PROCESS_GROUP" not in tool


def test_resume_fence_rejects_any_worker_entry_or_dev1_inventory_change(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    dev1_runs = tmp_path / "dev1-runs"
    dev1_runs.mkdir()
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", dev1_runs)
    state_path = tmp_path / "attempt" / "launch_state.json"
    state = _minimal_running_state(tmp_path)
    job = {"dev1_runs_before_launch": subject._dev1_run_inventory()}
    subject._assert_resume_outcome_fence(state, job, state_path)

    worker_entry = state_path.parent / "worker" / "cell-started"
    worker_entry.mkdir(parents=True)
    with pytest.raises(subject.AuthorizationError, match="worker artifact tree"):
        subject._assert_resume_outcome_fence(state, job, state_path)
    worker_entry.rmdir()
    worker_entry.parent.rmdir()

    (dev1_runs / "new-controller-run").mkdir()
    with pytest.raises(subject.AuthorizationError, match="DEV1 run inventory changed"):
        subject._assert_resume_outcome_fence(state, job, state_path)


@pytest.mark.parametrize(
    ("patch", "message"),
    [
        ({"cells": [{"cell_id": "sealed"}]}, "sealed cell outcome"),
        (
            {"active_cell": {"cell_id": "started"}},
            "crossed the outcome fence",
        ),
        ({"outcome_possible_since_utc": "2026-07-20T09:00:00Z"}, "crossed"),
        ({"launcher_revision": 1}, "legacy launch state"),
    ],
)
def test_resume_fence_rejects_every_outcome_or_legacy_surface(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    patch: dict,
    message: str,
) -> None:
    dev1_runs = tmp_path / "dev1-runs"
    dev1_runs.mkdir()
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", dev1_runs)
    state = _minimal_running_state(tmp_path)
    state.update(patch)
    job = {"dev1_runs_before_launch": subject._dev1_run_inventory()}
    with pytest.raises(subject.AuthorizationError, match=message):
        subject._assert_resume_outcome_fence(
            state, job, tmp_path / "attempt" / "launch_state.json"
        )


def test_launch_uses_persisted_scheduler_and_resume_refuses_worker_artifact(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    dev1_runs = tmp_path / "dev1-runs"
    dev1_runs.mkdir()
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", dev1_runs)
    pre = _minimal_launcher_pre()
    authorization = {
        "binding": {"path": str(tmp_path / "authorization.json"), "size": 1, "sha256": "b" * 64},
        "payload": {"authorized": True},
    }
    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_: pre)
    monkeypatch.setattr(subject, "validate_authorization", lambda *_: authorization)
    calls: list[str] = []

    def fake_scheduler(_pre, operation, job=None):
        calls.append(operation)
        if operation == "Identity":
            return {
                "operation": "Identity",
                "principal_sid": "S-1-5-21-500",
                "logon_type": "S4U",
                "run_level": "Highest",
            }
        scheduler = job["scheduler"]
        return {
            "operation": operation,
            "task_name": scheduler["task_name"],
            "principal_sid": scheduler["principal_sid"],
            "logon_type": "S4U",
            "run_level": "Highest",
            "multiple_instances": "IgnoreNew",
            "execution_limit_seconds": scheduler["execution_limit_seconds"],
            "state": "Ready" if operation != "Start" else "Running",
        }

    monkeypatch.setattr(subject, "_scheduler_call", fake_scheduler)
    state_path = tmp_path / "attempt" / "launch_state.json"
    launched = subject.launch_detached(
        tmp_path / "pre_receipt.json",
        "c" * 64,
        tmp_path / "authorization.json",
        state_path,
        None,
    )
    assert launched["status"] == "LAUNCHED_PERSISTED_TASK"
    assert calls == ["Identity", "Register", "Start"]
    job = subject.load_json(state_path.with_name("launch_job.json"))
    assert job["scheduler"]["mode"] == "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND"
    assert job["controller_timeout_seconds"] == 120000
    assert job["scheduler"]["execution_limit_seconds"] == 483600

    (state_path.parent / "worker" / "cell-started").mkdir(parents=True)
    with pytest.raises(subject.AuthorizationError, match="worker artifact tree"):
        subject.launch_detached(
            tmp_path / "pre_receipt.json",
            "c" * 64,
            tmp_path / "authorization.json",
            state_path,
            None,
            resume=True,
        )
    assert calls == ["Identity", "Register", "Start"]


def _arm_one_cell_worker(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, Path]:
    state_path = tmp_path / "attempt" / "launch_state.json"
    job_path = state_path.with_name("launch_job.json")
    pre_path = tmp_path / "pre_receipt.json"
    auth_path = tmp_path / "authorization.json"
    pre_path.write_text("{}", encoding="utf-8")
    auth_path.write_text("{}", encoding="utf-8")
    authorization = {
        "binding": subject.file_binding(auth_path),
        "payload": {"mt5_execution_authorized": True},
    }
    job = {
        "state_path": str(state_path.resolve()),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": "d" * 64,
        "authorization": authorization,
        "scheduler": {"mode": "TEST"},
        "controller_timeout_seconds": 60,
    }
    job_path.parent.mkdir(parents=True)
    job_path.write_text(json.dumps(job), encoding="utf-8")
    state = subject._initial_launch_state(
        pre_path, "d" * 64, subject.file_binding(job_path), job
    )
    subject.atomic_json(state_path, state)
    pre = {"plan": {"cells": [{"cell_id": "CELL_04", "runner_arguments": []}]}}
    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: pre)
    monkeypatch.setattr(subject, "_validate_launch_job", lambda *_args: None)
    monkeypatch.setattr(subject, "validate_authorization", lambda *_args: authorization)
    monkeypatch.setattr(subject, "_assert_resume_outcome_fence", lambda *_args: None)
    monkeypatch.setattr(subject, "runner_command", lambda *_args: ["controller", "CELL_04"])
    monkeypatch.setattr(
        subject,
        "validate_dev1_controller_result",
        lambda result, _pre: str(result["run_id"]),
    )
    return job_path, state_path


def _write_complete_post_chain(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[Path, str, Path, dict]:
    state_path = tmp_path / "attempt" / "launch_state.json"
    job_path = state_path.with_name("launch_job.json")
    pre_path = tmp_path / "pre_receipt.json"
    auth_path = tmp_path / "authorization.json"
    pre_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    pre_path.write_text("{}", encoding="utf-8")
    auth_path.write_text("{}", encoding="utf-8")
    authorization = {
        "binding": subject.file_binding(auth_path),
        "payload": {"mt5_execution_authorized": True},
    }
    scheduler = {"mode": "TEST"}
    job = {
        "created_utc": subject.utc_now(),
        "authorization": authorization,
        "scheduler": scheduler,
    }
    job_path.write_text(json.dumps(job), encoding="utf-8")
    pre_sha = "d" * 64
    cells = [{"cell_id": f"CELL_{index:02d}"} for index in range(1, 5)]
    pre = {"plan": {"cells": cells}}
    monkeypatch.setattr(subject, "assert_pre_receipt", lambda *_args: pre)
    monkeypatch.setattr(subject, "_validate_launch_job", lambda *_args: None)
    monkeypatch.setattr(subject, "validate_authorization", lambda *_args: authorization)
    monkeypatch.setattr(
        subject,
        "runner_command",
        lambda _pre, cell: ["controller", str(cell["cell_id"])],
    )
    monkeypatch.setattr(
        subject,
        "validate_dev1_controller_result",
        lambda result, _pre: str(result["run_id"]),
    )
    monkeypatch.setattr(
        subject,
        "_load_report_core",
        lambda *_args: pytest.fail("post-precheck must not open reports"),
    )
    state = subject._initial_launch_state(
        pre_path, pre_sha, subject.file_binding(job_path), job
    )
    state["status"] = "COMPLETE"
    state["started_utc"] = state["created_utc"]
    state["worker_pid"] = None
    opaque = tmp_path / "opaque.bin"
    opaque.write_bytes(b"opaque")
    opaque_binding = subject.file_binding(opaque)
    first_started = None
    for index, cell in enumerate(cells, start=1):
        started = subject.utc_now()
        first_started = first_started or started
        cell_root = state_path.parent / "worker" / cell["cell_id"]
        cell_root.mkdir(parents=True)
        run_id = f"20260720T21{index:02d}00Z_" + f"{index:x}" * 32
        runner_result = {"success": True, "run_id": run_id}
        stdout_path = cell_root / "runner.stdout.txt"
        stderr_path = cell_root / "runner.stderr.txt"
        stdout_path.write_text(json.dumps(runner_result), encoding="utf-8")
        stderr_path.write_text("", encoding="utf-8")
        context = {
            "started_utc": started,
            "command_sha256": subject.canonical_sha256(
                subject.runner_command(pre, cell)
            ),
            "runner_exit_code": 0,
            "runner_result": runner_result,
            "stdout": subject.file_binding(stdout_path),
            "stderr": subject.file_binding(stderr_path),
            "summary": opaque_binding,
            "run_artifacts": [
                {
                    "run": run,
                    "report": opaque_binding,
                    "tester_log": opaque_binding,
                    "tester_ini": opaque_binding,
                }
                for run in ("run_01", "run_02")
            ],
        }
        state["cells"].append(subject._complete_cell_record(cell["cell_id"], context))
    state["outcome_possible_since_utc"] = first_started
    state["finished_utc"] = subject.utc_now()
    state["updated_utc"] = state["finished_utc"]
    subject._validate_launch_state_shape(state)
    subject.atomic_json(state_path, state)
    return pre_path, pre_sha, state_path, pre


@pytest.mark.parametrize(
    ("stdout", "stderr", "failure_class"),
    [
        (
            "",
            "Import-Clixml: run_dev1_smoke.ps1:531\n"
            "Error occurred during a cryptographic operation.\n",
            "RUNNER_CREDENTIAL_CLIXML_CRYPTOGRAPHIC_FAILURE_BEFORE_JSON",
        ),
        (
            "PowerShell controller banner without a JSON object",
            "controller failed",
            "RUNNER_MALFORMED_STDOUT_NO_JSON",
        ),
    ],
)
def test_worker_closes_empty_or_malformed_stdout_with_bound_reject_attempt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    stdout: str,
    stderr: str,
    failure_class: str,
) -> None:
    job_path, state_path = _arm_one_cell_worker(tmp_path, monkeypatch)
    monkeypatch.setattr(
        subject.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(
            stdout=stdout, stderr=stderr, returncode=1
        ),
    )

    assert subject._worker_run(job_path) == 2
    state = subject.load_json(state_path)
    subject._validate_launch_state_shape(state)
    assert state["status"] == "REJECT"
    assert state["worker_pid"] is None
    assert state["active_cell"] is None
    assert state["terminal"]["no_resume"] is True
    assert state["terminal"]["controller_failure_class"] == failure_class
    assert len(state["cells"]) == 1
    cell = state["cells"][0]
    assert cell["status"] == "REJECT"
    attempt = cell["attempts"][0]
    assert attempt["failure_stage"] == "RUNNER_STREAMS_BOUND"
    assert attempt["runner_exit_code"] == 1
    assert attempt["controller_failure_class"] == failure_class
    subject.assert_binding(attempt["stdout"], "test stdout")
    subject.assert_binding(attempt["stderr"], "test stderr")


def test_worker_closes_exception_before_stream_bindings(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    job_path, state_path = _arm_one_cell_worker(tmp_path, monkeypatch)

    def timeout(*_args, **_kwargs):
        raise subprocess.TimeoutExpired(cmd="controller", timeout=60)

    monkeypatch.setattr(subject.subprocess, "run", timeout)
    assert subject._worker_run(job_path) == 2
    state = subject.load_json(state_path)
    subject._validate_launch_state_shape(state)
    attempt = state["cells"][0]["attempts"][0]
    assert attempt["failure_stage"] == "OUTCOME_FENCE_PERSISTED"
    assert attempt["stdout"] is None
    assert attempt["stderr"] is None
    assert attempt["runner_exit_code"] is None
    assert state["worker_pid"] is None and state["active_cell"] is None


def test_worker_complete_state_is_exactly_closed_and_clears_worker_identity(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    job_path, state_path = _arm_one_cell_worker(tmp_path, monkeypatch)
    run_id = "20260720T210000Z_" + "a" * 32
    summary_path = tmp_path / "summary.json"
    artifact_path = tmp_path / "opaque-artifact.bin"
    summary_path.write_text("{}", encoding="utf-8")
    artifact_path.write_bytes(b"opaque")
    binding = subject.file_binding(artifact_path)
    sealed = {
        "summary": subject.file_binding(summary_path),
        "run_artifacts": [
            {
                "run": run,
                "report": binding,
                "tester_log": binding,
                "tester_ini": binding,
            }
            for run in ("run_01", "run_02")
        ],
    }
    monkeypatch.setattr(
        subject.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(
            stdout=json.dumps({"success": True, "run_id": run_id}),
            stderr="",
            returncode=0,
        ),
    )
    monkeypatch.setattr(subject, "_find_summary", lambda _run_id: summary_path)
    monkeypatch.setattr(subject, "_seal_summary_artifacts", lambda _path: sealed)

    assert subject._worker_run(job_path) == 0
    state = subject.load_json(state_path)
    subject._validate_launch_state_shape(state)
    assert state["status"] == "COMPLETE"
    assert state["worker_pid"] is None
    assert state["active_cell"] is None
    assert state["terminal"] is None
    assert state["cells"][0]["attempts"][0]["status"] == "COMPLETE"


def test_complete_post_precheck_accepts_exact_bound_runner_streams(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre_path, pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    result = subject.post_precheck(pre_path, pre_sha, state_path)
    assert result["status"] == "PASS"
    assert result["post_allowed"] is True
    assert result["outcome_data_read"] is False


def test_complete_post_precheck_rejects_runner_stdout_byte_tamper(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre_path, pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    stdout_path = state_path.parent / "worker" / "CELL_01" / "runner.stdout.txt"
    tampered = bytearray(stdout_path.read_bytes())
    tampered[0] = ord("[")
    stdout_path.write_bytes(tampered)

    result = subject.post_precheck(pre_path, pre_sha, state_path)
    assert result["status"] == "REJECT"
    assert result["post_allowed"] is False
    assert result["outcome_data_read"] is False
    assert "SHA drift" in result["error"]


def test_complete_post_precheck_rejects_byte_identical_stream_path_copy(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre_path, pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    state = subject.load_json(state_path)
    original = state_path.parent / "worker" / "CELL_01" / "runner.stdout.txt"
    copied = tmp_path / "copied-runner.stdout.txt"
    copied.write_bytes(original.read_bytes())
    state["cells"][0]["attempts"][0]["stdout"] = subject.file_binding(copied)
    subject.atomic_json(state_path, state)

    result = subject.post_precheck(pre_path, pre_sha, state_path)
    assert result["status"] == "REJECT"
    assert result["post_allowed"] is False
    assert "runner stdout path drift" in result["error"]


def test_complete_post_precheck_rejects_state_runner_result_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre_path, pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    state = subject.load_json(state_path)
    state["cells"][0]["attempts"][0]["runner_result"]["substituted"] = True
    subject.atomic_json(state_path, state)

    result = subject.post_precheck(pre_path, pre_sha, state_path)
    assert result["status"] == "REJECT"
    assert result["post_allowed"] is False
    assert "stdout/state runner_result drift" in result["error"]


def test_complete_post_precheck_rejects_multiple_stdout_json_envelopes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    pre_path, pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    state = subject.load_json(state_path)
    attempt = state["cells"][0]["attempts"][0]
    stdout_path = state_path.parent / "worker" / "CELL_01" / "runner.stdout.txt"
    envelope = json.dumps(attempt["runner_result"])
    stdout_path.write_text(f"{envelope}\n{envelope}", encoding="utf-8")
    attempt["stdout"] = subject.file_binding(stdout_path)
    subject.atomic_json(state_path, state)

    result = subject.post_precheck(pre_path, pre_sha, state_path)
    assert result["status"] == "REJECT"
    assert result["post_allowed"] is False
    assert "exactly one complete JSON object envelope" in result["error"]


def test_terminal_rejection_persistence_failure_does_not_publish_false_reject(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    job_path, state_path = _arm_one_cell_worker(tmp_path, monkeypatch)
    monkeypatch.setattr(
        subject.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(stdout="", stderr="failed", returncode=1),
    )
    real_atomic_json = subject.atomic_json

    def fail_reject(path, payload, *, replace=True):
        if payload.get("status") == "REJECT":
            raise OSError("simulated terminal persistence failure")
        return real_atomic_json(path, payload, replace=replace)

    monkeypatch.setattr(subject, "atomic_json", fail_reject)
    assert subject._worker_run(job_path) == 2
    persisted = subject.load_json(state_path)
    assert persisted["status"] == "RUNNING"
    assert persisted["active_cell"]["status"] == "OUTCOME_POSSIBLE_NO_RESUME"
    status = subject.launch_status(state_path)
    assert status["classification"] == "NONTERMINAL_OUTCOME_FENCE_OPEN_NO_RESUME"
    assert status["post_allowed"] is False
    assert status["resume_allowed"] is False


def test_rejection_finalizer_never_overwrites_existing_complete_bytes(tmp_path: Path) -> None:
    state_path = tmp_path / "launch_state.json"
    state = _minimal_running_state(tmp_path)
    state["status"] = "COMPLETE"
    state_path.write_text(json.dumps(state, sort_keys=True), encoding="utf-8")
    before = state_path.read_bytes()
    assert not subject._finalize_worker_rejection(
        state_path, subject.AuditError("late failure"), None
    )
    assert state_path.read_bytes() == before


def test_terminal_state_lock_race_preserves_complete_bytes(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _pre_path, _pre_sha, state_path, _pre = _write_complete_post_chain(
        tmp_path, monkeypatch
    )
    running = subject.load_json(state_path)
    running["status"] = "RUNNING"
    running["worker_pid"] = 4321
    running["finished_utc"] = None
    running["updated_utc"] = subject.utc_now()
    subject._validate_launch_state_shape(running)
    subject.atomic_json(state_path, running)
    expected_running = subject.load_json(state_path)

    real_atomic_json = subject.atomic_json
    complete_write_entered = threading.Event()
    allow_complete_write = threading.Event()
    rejection_started = threading.Event()
    published_complete_bytes: list[bytes] = []
    results: dict[str, object] = {}
    errors: list[BaseException] = []

    def gated_atomic_json(path, payload, *, replace=True):
        if payload.get("status") == "COMPLETE":
            complete_write_entered.set()
            if not allow_complete_write.wait(5):
                raise AssertionError("timed out coordinating terminal-state race")
        result = real_atomic_json(path, payload, replace=replace)
        if payload.get("status") == "COMPLETE":
            published_complete_bytes.append(Path(path).read_bytes())
        return result

    monkeypatch.setattr(subject, "atomic_json", gated_atomic_json)

    def publish_complete() -> None:
        try:
            results["complete"] = subject._finalize_worker_complete(
                state_path, expected_running
            )
        except BaseException as exc:  # pragma: no cover - asserted below.
            errors.append(exc)

    def publish_reject() -> None:
        rejection_started.set()
        try:
            results["reject"] = subject._finalize_worker_rejection(
                state_path, subject.AuditError("concurrent late failure"), None
            )
        except BaseException as exc:  # pragma: no cover - asserted below.
            errors.append(exc)

    complete_thread = threading.Thread(target=publish_complete)
    reject_thread = threading.Thread(target=publish_reject)
    complete_thread.start()
    assert complete_write_entered.wait(5)
    reject_thread.start()
    assert rejection_started.wait(5)
    allow_complete_write.set()
    complete_thread.join(10)
    reject_thread.join(10)

    assert not complete_thread.is_alive() and not reject_thread.is_alive()
    assert errors == []
    assert isinstance(results["complete"], dict)
    assert results["complete"]["status"] == "COMPLETE"
    assert results["reject"] is False
    assert len(published_complete_bytes) == 1
    assert state_path.read_bytes() == published_complete_bytes[0]
    assert subject.load_json(state_path)["status"] == "COMPLETE"


def test_legacy_stdout_reject_is_uniquely_classified_and_post_blocked(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    state = _minimal_running_state(tmp_path)
    state["launcher_revision"] = 2
    state["status"] = "REJECT"
    state["worker_pid"] = 17764
    state["active_cell"] = {
        "cell_id": "B_SHORT_NY_H1_BIAS__GBPUSD_DWX__M1",
        "command_sha256": "e" * 64,
        "started_utc": state["created_utc"],
        "status": "OUTCOME_POSSIBLE_NO_RESUME",
    }
    state["outcome_possible_since_utc"] = state["created_utc"]
    state["finished_utc"] = state["created_utc"]
    state["updated_utc"] = state["created_utc"]
    state["cells"] = [{"cell_id": f"completed-{index}"} for index in range(3)]
    state.pop("terminal")
    state["error_type"] = "AuditError"
    state["error"] = "runner stdout contains no JSON object"
    state_path = tmp_path / "legacy_launch_state.json"
    state_path.write_text(json.dumps(state), encoding="utf-8")
    monkeypatch.setattr(
        subject, "assert_pre_receipt", lambda *_args: pytest.fail("PRE must not be opened")
    )
    monkeypatch.setattr(
        subject, "_load_report_core", lambda *_args: pytest.fail("reports must not be opened")
    )

    status = subject.launch_status(state_path)
    assert status["classification"] == "LEGACY_REV2_RUNNER_STDOUT_REJECT_LIFECYCLE_UNCLOSED"
    assert status["outcome_data_read"] is False
    precheck = subject.post_precheck(tmp_path / "unused-pre.json", "f" * 64, state_path)
    assert precheck["status"] == "REJECT"
    assert precheck["post_allowed"] is False
    with pytest.raises(subject.PostflightError, match="lifecycle classification"):
        subject.postflight(tmp_path / "unused-pre.json", "f" * 64, state_path)


@pytest.mark.parametrize("tamper", ["worker_bool", "exit_bool", "no_resume_int", "extra_field"])
def test_status_rejects_bool_type_and_field_closure_tamper(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    tamper: str,
) -> None:
    job_path, state_path = _arm_one_cell_worker(tmp_path, monkeypatch)
    monkeypatch.setattr(
        subject.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(stdout="", stderr="failed", returncode=1),
    )
    assert subject._worker_run(job_path) == 2
    state = subject.load_json(state_path)
    if tamper == "worker_bool":
        state["worker_pid"] = False
    elif tamper == "exit_bool":
        state["cells"][0]["attempts"][0]["runner_exit_code"] = False
    elif tamper == "no_resume_int":
        state["cells"][0]["attempts"][0]["no_resume"] = 1
    else:
        state["unexpected"] = "field"
    tampered = tmp_path / f"tampered-{tamper}.json"
    tampered.write_text(json.dumps(state), encoding="utf-8")
    status = subject.launch_status(tampered)
    assert status["classification"] == "INVALID_TERMINAL_LAUNCH_STATE"
    assert status["post_allowed"] is False
    assert status["resume_allowed"] is False


def test_worker_seals_exactly_two_native_artifact_sets(tmp_path: Path) -> None:
    report_dir = tmp_path / "report"
    runs = []
    for name in ("run_01", "run_02"):
        run_dir = report_dir / "raw" / name
        run_dir.mkdir(parents=True)
        report = run_dir / "report.htm"
        log = run_dir / "tester.log"
        ini = run_dir / "tester.ini"
        report.write_text("report", encoding="utf-8")
        log.write_text("log", encoding="utf-8")
        ini.write_text("[Tester]", encoding="utf-8")
        runs.append(
            {
                "run": name,
                "status": "OK",
                "exit_code": 0,
                "report_canonical_path": str(report),
                "tester_log_path": str(log),
            }
        )
    summary = report_dir / "summary.json"
    summary.write_text(
        json.dumps({"report_dir": str(report_dir), "runs": runs}), encoding="utf-8"
    )
    sealed = subject._seal_summary_artifacts(summary)
    assert [row["run"] for row in sealed["run_artifacts"]] == ["run_01", "run_02"]
    assert all(row["report"]["sha256"] for row in sealed["run_artifacts"])

    runs.append(dict(runs[-1], run="run_03"))
    summary.write_text(
        json.dumps({"report_dir": str(report_dir), "runs": runs}), encoding="utf-8"
    )
    with pytest.raises(subject.AuditError, match="exactly the two"):
        subject._seal_summary_artifacts(summary)


@pytest.mark.parametrize("exit_code", [None, 0])
def test_runner_duplicate_accepts_canonical_natural_or_explicit_zero_exit(exit_code) -> None:
    assert subject._runner_duplicate_exit_ok(exit_code)


@pytest.mark.parametrize("exit_code", [False, True, -1, 1, "0"])
def test_runner_duplicate_rejects_noninteger_or_nonzero_exit(exit_code) -> None:
    assert not subject._runner_duplicate_exit_ok(exit_code)


@pytest.mark.parametrize("ea_dir", ["QM5_20002", "QM5_20002_ict-icytea-core"])
def test_find_summary_accepts_only_bound_runner_ea_directories(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, ea_dir: str
) -> None:
    run_id = "20260720T072811Z_" + "a" * 32
    summary = tmp_path / run_id / "output" / "smoke" / ea_dir / "stamp" / "summary.json"
    summary.parent.mkdir(parents=True)
    summary.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", tmp_path)
    assert subject._find_summary(run_id) == summary.resolve()


def test_find_summary_rejects_unbound_or_ambiguous_output(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    run_id = "20260720T072811Z_" + "b" * 32
    smoke = tmp_path / run_id / "output" / "smoke"
    unbound = smoke / "QM5_99999" / "stamp" / "summary.json"
    unbound.parent.mkdir(parents=True)
    unbound.write_text("{}", encoding="utf-8")
    monkeypatch.setattr(subject, "DEV1_RUNS_ROOT", tmp_path)
    with pytest.raises(subject.AuditError, match="found 0"):
        subject._find_summary(run_id)

    for ea_dir in subject.RUNNER_OUTPUT_EA_DIRS:
        summary = smoke / ea_dir / "stamp" / "summary.json"
        summary.parent.mkdir(parents=True)
        summary.write_text("{}", encoding="utf-8")
    with pytest.raises(subject.AuditError, match="found 2"):
        subject._find_summary(run_id)


def test_expected_summary_separates_canonical_ea_label_from_expert_path() -> None:
    expected = subject._expected_runner_summary({"symbol": "EURUSD.DWX"})
    assert expected["ea_label"] == "QM5_20002"
    assert expected["expert"] == r"QM\QM5_20002_ict-icytea-core"


def test_pre_cli_fails_closed_before_any_launch_when_compile_missing(tmp_path: Path) -> None:
    receipt = tmp_path / "pre_reject.json"
    rc = subject.main(
        [
            "pre",
            "--compile-evidence",
            str(tmp_path / "missing.json"),
            "--receipt",
            str(receipt),
        ]
    )
    assert rc == 2
    payload = json.loads(receipt.read_text(encoding="utf-8"))
    assert payload["status"] == "REJECT"
    assert payload["artifact_type"] == "QM5_20002_SHORT_NY_PRE_REJECTION"


def test_profit_factor_states_are_fail_closed() -> None:
    pf, state = subject.profit_factor([Decimal("2"), Decimal("-1")])
    assert pf == Decimal("2") and state == "FINITE"
    assert subject._pf_pass(pf, state, Decimal("1.35"))
    pf, state = subject.profit_factor([Decimal("2"), Decimal("1")])
    assert pf is None and state == "INFINITE_NO_LOSSES"
    assert subject._pf_pass(pf, state, Decimal("100"))
    pf, state = subject.profit_factor([])
    assert not subject._pf_pass(pf, state, Decimal("1"))
