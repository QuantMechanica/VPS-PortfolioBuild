from __future__ import annotations

import copy
import importlib.util
import inspect
import json
import sys
from pathlib import Path

import pytest


TOOL = (
    Path(__file__).resolve().parents[2]
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_asian_sweep_london_xau_testwindow_semantic.py"
)
SPEC = importlib.util.spec_from_file_location("qm13210_xau_testwindow_semantic_test", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _runtime(*, workers=None, mt5=None, task_state: str = "Disabled") -> dict:
    return {
        "scheduled_tasks": [
            {"task_name": name, "count": 1, "state": task_state}
            for name in subject.MANAGED_OFF_TASKS
        ],
        "exact_factory_mt5_processes": [] if mt5 is None else mt5,
        "registered_factory_python_workers": [] if workers is None else workers,
    }


def _install_fake_quiescence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, *, worker_bytes: str = "{}\n"
) -> Path:
    flag = tmp_path / "FACTORY_OFF.flag"
    parallel = tmp_path / "codex_parallel.txt"
    workers = tmp_path / "worker_pids.json"
    flag.write_text(
        json.dumps(
            {
                "off_at": "2026-07-21T00:00:00Z",
                "codex_parallel_before": "6",
            }
        ),
        encoding="utf-8",
    )
    parallel.write_text("0\n", encoding="ascii")
    workers.write_text(worker_bytes, encoding="utf-8")
    monkeypatch.setattr(subject, "FACTORY_OFF_FLAG_PATH", flag)
    monkeypatch.setattr(subject, "CODEX_PARALLEL_PATH", parallel)
    monkeypatch.setattr(subject, "WORKER_PIDS_PATH", workers)
    monkeypatch.setattr(subject, "_probe_quiescence_runtime", lambda: _runtime())
    monkeypatch.setattr(subject, "_probe_worker_mutexes", lambda: [])
    return workers


def test_real_native002_closure_is_pre_scheduler_and_outcome_blind() -> None:
    result = subject.validate_native002_invalid_prelaunch_closure(
        probe_task_absence=False
    )
    assert result["status"] == "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND"
    assert result["native_controller_start_count"] == 0
    assert result["native_outcome_artifact_count"] == 0
    assert result["registered_live_workers_before_and_after"] == []
    assert result["pre_bound_raw_registry_binding"] != result[
        "current_raw_registry_binding_at_closure"
    ]


def test_closure_inventory_namespace_task_and_claim_absence_are_exact() -> None:
    payload = subject.B.load_json(subject.NATIVE002_CLOSURE_PATH)
    assert [row["relative_path"] for row in payload["run_root_inventory"]] == [
        "native_outcome_authorization.json",
        "pre_receipt.json",
    ]
    absence = payload["absence_proof"]
    assert absence["launch_job"]["exists"] is False
    assert absence["launch_state"]["exists"] is False
    assert absence["native_directory"]["exists"] is False
    assert absence["native_attempt_claim"] == {
        "path": str(subject.SUPERSEDED_CLAIM_PATH.resolve()),
        "exists": False,
    }
    assert absence["scheduled_task"] == {
        "task_name": subject.SUPERSEDED_TASK_NAME,
        "count": 0,
        "states": [],
    }
    assert payload["run_root"] == str(subject.SUPERSEDED_RUN_ROOT.resolve())
    assert payload["recovery_contract"]["superseding_namespace"] == str(
        subject.RUN_NAMESPACE_ROOT.resolve()
    )


def test_native003_terminal_closure_binds_controls_and_consumes_family() -> None:
    closure = subject.validate_native003_invalid_terminal_closure(
        probe_task_absence=False
    )
    assert closure["status"] == subject.NATIVE003_TERMINAL_STATUS
    attempt = closure["attempt"]
    assert attempt["pre_receipt"]["sha256"] == (
        "43223cc742505d77374d331d65de9b1b89c4f11b3170059a1f3a19deed440a56"
    )
    assert attempt["launch_state"]["size"] == 23872
    assert attempt["launch_job"]["size"] == 2176
    assert attempt["post_receipt"]["size"] == 329
    assert attempt["native_attempt_claim"] == {
        "path": str(subject.CLAIM_PATH.resolve()),
        "exists": False,
    }
    assert closure["scheduled_task_absence"]["task_name"] == (
        subject.NATIVE003_TASK_NAME
    )
    assert closure["scheduled_task_absence"]["count"] == 0
    assert closure["terminal_trigger"] == {
        "classification": "POST_INVALID_RAW_TESTER_LOG_MISSING_MODEL4_MARKER",
        "cell_id": "XAUUSD_DWX_DEV",
        "duplicate_id": "run_01",
        "required_marker": "MODEL_4_EVERY_TICK_BASED_ON_REAL_TICKS",
        "fact_source": "POST_RECEIPT_INVALID_METADATA_READ_BY_ROOT",
        "post_invocation_completed": True,
        "post_returned_invalid": True,
        "raw_tester_log_content_opened_by_closure": False,
    }
    assert closure["lifecycle_facts"]["one_shot_attempt_consumed"] is True
    assert closure["lifecycle_facts"]["remaining_attempt_budget"] == 0
    disposition = closure["terminal_disposition"]
    assert disposition["strategy_merit_verdict"] == "NONE"
    assert disposition["post_retry_permitted"] is False
    assert disposition["resume_permitted"] is False
    assert disposition["relaunch_permitted"] is False
    assert disposition["attempt_002_permitted"] is False
    assert disposition["further_xau_audit_attempt_in_family_permitted"] is False


@pytest.mark.parametrize(
    ("section", "field", "replacement"),
    [
        ("terminal_trigger", "duplicate_id", "run_02"),
        ("lifecycle_facts", "remaining_attempt_budget", 1),
        ("outcome_fence", "strategy_merit_adjudicated", True),
        ("terminal_disposition", "relaunch_permitted", True),
    ],
)
def test_native003_terminal_closure_tamper_fails_closed(
    monkeypatch: pytest.MonkeyPatch,
    section: str,
    field: str,
    replacement: object,
) -> None:
    saved_loader = subject.B.load_json

    def drifted_loader(path: Path):
        payload = saved_loader(path)
        if Path(path).resolve() == subject.NATIVE003_TERMINAL_CLOSURE_PATH.resolve():
            payload = copy.deepcopy(payload)
            payload[section][field] = replacement
        return payload

    monkeypatch.setattr(subject.B, "load_json", drifted_loader)
    with pytest.raises(subject.InvalidEvidence):
        subject.validate_native003_invalid_terminal_closure(
            probe_task_absence=False
        )


def test_native003_terminal_validator_does_not_open_external_content_or_run_post() -> None:
    source = inspect.getsource(subject.validate_native003_invalid_terminal_closure)
    assert ".read_text(" not in source
    assert ".read_bytes(" not in source
    assert "_BASE_POSTFLIGHT(" not in source
    assert "launch_persistent_task(" not in source
    assert "subprocess.run(" not in source
    fence = subject.B.load_json(subject.NATIVE003_TERMINAL_CLOSURE_PATH)[
        "outcome_fence"
    ]
    assert fence["post_receipt_content_opened_by_closure_author"] is False
    assert fence["post_receipt_invalid_metadata_read_by_root"] is True
    assert fence["tester_or_controller_log_content_opened"] is False
    assert fence["native_report_content_opened"] is False
    assert fence["deal_rows_opened"] is False
    assert fence["economic_outcomes_opened"] is False
    assert fence["strategy_merit_adjudicated"] is False


@pytest.mark.parametrize(
    ("section", "field", "replacement"),
    [
        ("launch_validation_failure", "semantic_live_projection_equal", False),
        ("absence_proof", "native_controller_start_count", 1),
        ("outcome_fence", "native_reports_opened", True),
        ("recovery_contract", "strategy_or_parameter_change_forbidden", False),
    ],
)
def test_closure_tamper_fails_closed(
    tmp_path: Path, section: str, field: str, replacement: object
) -> None:
    payload = subject.B.load_json(subject.NATIVE002_CLOSURE_PATH)
    payload[section][field] = replacement
    path = tmp_path / "tampered_closure.json"
    path.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(subject.InvalidEvidence):
        subject.validate_native002_invalid_prelaunch_closure(
            path, probe_task_absence=False
        )


def test_recorded_registry_binding_is_historical_not_a_live_byte_lock(
    tmp_path: Path,
) -> None:
    registry = tmp_path / "worker_pids.json"
    registry.write_text('{"T5": 111}\n', encoding="utf-8")
    recorded = {
        "path": str(registry.resolve()),
        "size": 999,
        "sha256": "a" * 64,
    }
    assert subject._validate_recorded_binding(
        recorded, registry, "historical registry", assert_current=False
    ) == recorded
    with pytest.raises(subject.InvalidEvidence):
        subject._validate_recorded_binding(
            recorded, registry, "live registry", assert_current=True
        )


def test_raw_registry_byte_only_change_with_zero_live_workers_is_accepted(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    registry = _install_fake_quiescence(
        tmp_path, monkeypatch, worker_bytes='{"T5": 111}\n'
    )
    before = subject.probe_testwindow_off_quiescence()
    registry.write_text(
        '{\n  "T5": 222\n}\n',
        encoding="utf-8",
    )
    after = subject.assert_testwindow_off_quiescence(before)
    assert before["invariant"] == after["invariant"]
    assert before["invariant_sha256"] == after["invariant_sha256"]
    registry_contract = after["invariant"]["worker_pid_registry"]
    assert registry_contract["path"] == str(registry.resolve())
    assert registry_contract["raw_sha256_bound"] is False
    assert registry_contract["raw_size_bound"] is False


def test_semantically_live_registered_worker_is_rejected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _install_fake_quiescence(tmp_path, monkeypatch)
    monkeypatch.setattr(
        subject,
        "_probe_quiescence_runtime",
        lambda: _runtime(workers=[{"terminal": "T5", "pid": 123, "image": "python"}]),
    )
    with pytest.raises(subject.InvalidEvidence, match="semantically live"):
        subject.probe_testwindow_off_quiescence()


@pytest.mark.parametrize("image", ["terminal64", "metatester64"])
def test_any_exact_t1_t10_mt5_process_is_rejected(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    image: str,
) -> None:
    _install_fake_quiescence(tmp_path, monkeypatch)
    monkeypatch.setattr(
        subject,
        "_probe_quiescence_runtime",
        lambda: _runtime(mt5=[{"terminal": "T5", "pid": 456, "image": image}]),
    )
    with pytest.raises(subject.InvalidEvidence, match="T1-T10"):
        subject.probe_testwindow_off_quiescence()


def test_terminal_worker_mutex_is_rejected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _install_fake_quiescence(tmp_path, monkeypatch)
    monkeypatch.setattr(subject, "_probe_worker_mutexes", lambda: ["T5"])
    with pytest.raises(subject.InvalidEvidence, match="mutexes"):
        subject.probe_testwindow_off_quiescence()


def test_v2_contract_requires_all_five_probe_boundaries() -> None:
    contract = subject._testwindow_contract()
    assert contract["required_at"] == [
        "PRE",
        "LAUNCH",
        "WORKER_BOOTSTRAP",
        "BEFORE_EACH_NATIVE_CELL",
        "POST",
    ]
    assert contract["exact_t1_t10_terminal_and_metatester_count"] == 0
    assert contract["registered_live_factory_python_worker_count"] == 0
    assert contract["worker_registry_raw_sha256_bound"] is False
    assert contract["worker_registry_raw_size_bound"] is False


def test_runner_rechecks_quiescence_before_every_cell(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "assert_testwindow_off_quiescence",
        lambda *_args: calls.append("probe") or {"status": "PASS"},
    )
    monkeypatch.setattr(subject, "_BASE_RUNNER_COMMAND", lambda _pre, _cell: ["runner"])
    result = subject.runner_command(
        {"testwindow_off_quiescence": {"status": "PASS"}}, {"cell_id": "DEV"}
    )
    assert result == ["runner"]
    assert calls == ["probe"]


def test_terminal_closure_blocks_worker_before_delegating(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "validate_native003_invalid_terminal_closure",
        lambda *_args, **_kwargs: calls.append("terminal_closure")
        or {"status": subject.NATIVE003_TERMINAL_STATUS},
    )
    monkeypatch.setattr(
        subject, "_BASE_WORKER_RUN", lambda _job: calls.append("worker") or 0
    )
    with pytest.raises(subject.AuthorizationError, match="worker replay"):
        subject._worker_run(subject.JOB_PATH)
    assert calls == ["terminal_closure"]


def test_terminal_closure_blocks_resume_and_relaunch_before_base_launcher(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "validate_native003_invalid_terminal_closure",
        lambda *_args, **_kwargs: calls.append("terminal_closure")
        or {"status": subject.NATIVE003_TERMINAL_STATUS},
    )
    monkeypatch.setattr(
        subject,
        "_BASE_LAUNCH_PERSISTENT_TASK",
        lambda *_args, **_kwargs: calls.append("base_launch"),
    )
    for resume in (False, True):
        with pytest.raises(subject.AuthorizationError, match="permanently forbidden"):
            subject.launch_persistent_task(
                subject.PRE_RECEIPT_PATH,
                "a" * 64,
                subject.AUTHORIZATION_PATH,
                subject.STATE_PATH,
                resume=resume,
            )
    assert calls == ["terminal_closure", "terminal_closure"]


def test_terminal_closure_blocks_post_retry_before_base_postflight(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "validate_native003_invalid_terminal_closure",
        lambda *_args, **_kwargs: calls.append("terminal_closure")
        or {"status": subject.NATIVE003_TERMINAL_STATUS},
    )
    monkeypatch.setattr(
        subject,
        "_BASE_POSTFLIGHT",
        lambda *_args, **_kwargs: calls.append("base_post"),
    )
    with pytest.raises(subject.AuthorizationError, match="POST retry"):
        subject.postflight(
            subject.PRE_RECEIPT_PATH,
            "a" * 64,
            subject.STATE_PATH,
        )
    assert calls == ["terminal_closure"]


def test_terminal_closure_blocks_new_pre_before_base_preflight(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "validate_native003_invalid_terminal_closure",
        lambda *_args, **_kwargs: calls.append("terminal_closure")
        or {"status": subject.NATIVE003_TERMINAL_STATUS},
    )
    monkeypatch.setattr(
        subject,
        "_BASE_PREFLIGHT",
        lambda *_args, **_kwargs: calls.append("base_pre"),
    )
    with pytest.raises(subject.AuthorizationError, match="another audit attempt"):
        subject.preflight(
            subject.RESEARCH_SYMBOL,
            subject.RESEARCH_READINESS_PATH,
            subject.DATA_MANIFEST_PATH,
            subject.BUILD_RECEIPT_PATH,
            subject.ATTEMPT_001_RUN_ROOT,
        )
    assert calls == ["terminal_closure"]


def test_finalized_contract_and_namespace_are_distinct_and_exact() -> None:
    validated = subject.validate_analysis_contract()
    contract = subject.B.load_json(subject.CONTRACT_PATH)
    assert contract["status"] == "FINALIZED_OUTCOME_BLIND"
    assert validated["source_build_commit"] == contract["source_build_commit"]
    assert validated["terminal_closure"]["status"] == (
        subject.NATIVE003_TERMINAL_STATUS
    )
    assert contract["analysis_id"].endswith("XAUUSD_NATIVE_003")
    assert subject.RUN_NAMESPACE_ROOT.name == "XAUUSD_MULHAM_NATIVE_003"
    assert subject.RUN_NAMESPACE_ROOT != subject.SUPERSEDED_NAMESPACE_ROOT
    namespace = contract["run_namespace"]
    assert namespace["retry_or_attempt002_plus_forbidden"] is True
    assert namespace["native_attempt_claim"] == {
        "path": str(subject.CLAIM_PATH.resolve()),
        "must_remain_absent": True,
    }


def test_no_strategy_data_cost_window_or_merit_drift_from_native002() -> None:
    current = subject._draft_contract_payload()
    predecessor = subject.B.load_json(subject.SUPERSEDED_CONTRACT_PATH)
    frozen = current["frozen_execution_identity"]
    old_frozen = predecessor["frozen_execution_identity"]
    assert current["candidate"] == predecessor["candidate"]
    assert current["windows"] == predecessor["windows"]
    assert frozen["source_build_commit"] == predecessor["source_build_commit"]
    for key in (
        "research_symbol",
        "timeframe",
        "model",
        "duplicates_per_cell",
        "input_bindings",
        "symbol_spec_sha256",
        "xau_calibration_projection_sha256",
        "cost_schedule_sha256",
        "merit_contract_sha256",
    ):
        assert frozen[key] == old_frozen[key]
    assert frozen["ea_ex5_set_data_parameters_windows_costs_and_gates_unchanged"] is True


def test_final_artifact_roles_bind_full_predecessor_chain() -> None:
    required = {
        "adapter",
        "base_tool",
        "superseded_adapter",
        "superseded_contract",
        "attempt001_closure",
        "attempt002_closure",
        "superseded_testwindow_adapter",
        "superseded_testwindow_contract",
        "native002_prelaunch_closure",
        "card",
        "spec",
        "mq5",
        "ex5",
        "set",
        "build_receipt",
    }
    assert required <= subject.FINAL_ARTIFACT_ROLES
    assert set(subject._artifact_contract_paths()) == subject.FINAL_ARTIFACT_ROLES


def test_outcome_fence_forbids_logs_reports_outcomes_and_command_lines() -> None:
    closure = subject.B.load_json(subject.NATIVE002_CLOSURE_PATH)["outcome_fence"]
    contract = subject._outcome_fence_contract()
    assert closure["controller_logs_opened"] is False
    assert closure["native_reports_opened"] is False
    assert closure["native_outcomes_opened"] is False
    assert closure["live_process_command_lines_read"] is False
    assert closure["live_process_command_lines_emitted"] is False
    assert contract["native002_controller_logs_opened"] is False
    assert contract["live_process_command_lines_read"] is False
    assert contract["live_process_command_lines_emitted"] is False
