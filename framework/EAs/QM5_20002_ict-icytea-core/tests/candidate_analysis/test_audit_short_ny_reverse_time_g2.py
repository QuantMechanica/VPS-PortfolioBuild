from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
AUDITOR_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "audit_short_ny_reverse_time_g2.py"
)
BASE_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "audit_short_ny_reverse_time.py"
)


def load_auditor():
    name = f"qm20002_g2_test_{id(object())}"
    spec = importlib.util.spec_from_file_location(name, AUDITOR_PATH)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def test_private_adapter_keeps_historical_g1_globals_exact() -> None:
    auditor = load_auditor()

    assert auditor._G1_AUDITOR.TOOL_PATH == BASE_PATH.resolve()
    assert str(auditor._G1_AUDITOR.AUDIT_CONTROL_ROOT) == (
        r"D:\QM\reports\qm20002\short_ny_reverse_time"
    )
    assert auditor._G1_AUDITOR.SCHEDULED_TASK_PREFIX == "QM_QM20002_AUDIT_"
    assert auditor._G1_AUDITOR.LAUNCHER_REVISION == 4

    assert auditor._BASE is not auditor._G1_AUDITOR
    assert auditor._BASE.TOOL_PATH == AUDITOR_PATH.resolve()
    assert auditor._BASE.AUDIT_CONTROL_ROOT == auditor.G2_CONTROL_ROOT
    assert auditor._BASE.SCHEDULED_TASK_PREFIX == "QM_QM20002_G2_AUDIT_"
    assert auditor._BASE.LAUNCHER_REVISION == 5


def test_g2_profile_and_runtime_roles_are_exactly_isolated() -> None:
    auditor = load_auditor()
    profile = auditor.integration_profile()

    assert profile["generation"] == "G2"
    assert profile["analysis_id"] == "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001"
    assert profile["control_root"] == (
        r"D:\QM\reports\qm20002\short_ny_reverse_time_g2"
    )
    assert profile["scheduled_task_prefix"] == "QM_QM20002_G2_AUDIT_"
    assert profile["base_auditor"]["size"] == 249680
    assert profile["base_auditor"]["sha256"] == (
        "4f9068c710a34d7f0bd72ad0c93a856d966ca58943ca84fa48f4addc686b0a2f"
    )
    assert profile["runtime_freeze_required"] is True

    roles = auditor.RUNTIME_ROLES
    assert roles["scheduled_task_helper"] == auditor.G2_SCHEDULED_TASK_HELPER_PATH
    assert roles["audit_control_path_helper"] == auditor.G2_CONTROL_PATH_HELPER_PATH
    assert roles["g2_adapter"] == AUDITOR_PATH.resolve()
    assert roles["g2_private_base_auditor"] == BASE_PATH.resolve()
    assert "g1_closure_landed_manifest" in roles
    assert "g1_closure_utility" in roles
    assert "g2_runner_worktree_provenance" in roles


def test_contract_has_unambiguous_observed_action_prohibitions() -> None:
    auditor = load_auditor()
    contract = json.loads(auditor.G2_CONTRACT_PATH.read_text(encoding="utf-8"))

    assert contract["prohibitions"] == {
        "g1_frozen_bytes_modified": False,
        "pre_run_during_integration": False,
        "launch_run_during_integration": False,
        "native_reports_read_before_post": False,
        "process_arguments_inspected": False,
        "secrets_persisted": False,
    }


def test_immutable_byte_guard_rejects_size_or_digest_drift(tmp_path: Path) -> None:
    auditor = load_auditor()
    candidate = tmp_path / "candidate.bin"
    candidate.write_bytes(b"reviewed")

    with pytest.raises(auditor.G2IntegrationError, match="immutable byte guard"):
        auditor._exact_file_binding(
            candidate,
            expected_size=len(b"reviewed"),
            expected_sha256="0" * 64,
            label="candidate",
        )


def test_cli_requires_external_runtime_freeze_before_pre(
    capsys: pytest.CaptureFixture[str],
) -> None:
    auditor = load_auditor()

    code = auditor.main(
        [
            "pre",
            "--compile-evidence",
            "unused.json",
            "--receipt",
            "unused-pre.json",
        ]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert "requires exactly one --runtime-freeze-sha256" in captured.err
    assert '"outcome_data_read": false' in captured.err


def test_runtime_errors_enter_base_fail_closed_lifecycle() -> None:
    auditor = load_auditor()

    assert issubclass(auditor.G2IntegrationError, auditor._BASE.AuditError)
    assert auditor._BASE.preflight is auditor.preflight
    assert auditor._BASE._validate_pre_semantics is auditor._validate_pre_semantics


def test_runtime_freeze_option_is_pre_only(
    capsys: pytest.CaptureFixture[str],
) -> None:
    auditor = load_auditor()

    code = auditor.main(
        ["status", "--runtime-freeze-sha256", "0" * 64, "--state", "unused.json"]
    )
    captured = capsys.readouterr()
    assert code == 2
    assert "accepted only for PRE" in captured.err
