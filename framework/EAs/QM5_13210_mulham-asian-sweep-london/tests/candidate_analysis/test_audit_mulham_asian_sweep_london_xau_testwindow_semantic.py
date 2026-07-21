from __future__ import annotations

import importlib.util
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


def test_worker_bootstrap_probes_before_delegating(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []
    monkeypatch.setattr(
        subject,
        "_assert_exact_control_path",
        lambda *_args: calls.append("path") or subject.JOB_PATH,
    )
    monkeypatch.setattr(
        subject,
        "assert_testwindow_off_quiescence",
        lambda *_args: calls.append("probe") or {"status": "PASS"},
    )
    monkeypatch.setattr(
        subject,
        "validate_native002_invalid_prelaunch_closure",
        lambda *_args, **_kwargs: calls.append("closure") or {"status": "PASS"},
    )
    monkeypatch.setattr(
        subject, "_BASE_WORKER_RUN", lambda _job: calls.append("worker") or 0
    )
    assert subject._worker_run(subject.JOB_PATH) == 0
    assert calls == ["path", "probe", "closure", "worker"]


def test_launch_is_one_shot_and_rechecks_pre_bound_quiescence(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    with pytest.raises(subject.AuthorizationError, match="one-shot"):
        subject.launch_persistent_task(
            subject.PRE_RECEIPT_PATH,
            "a" * 64,
            subject.AUTHORIZATION_PATH,
            subject.STATE_PATH,
            resume=True,
        )
    calls: list[str] = []
    monkeypatch.setattr(subject, "CLAIM_PATH", tmp_path / "absent_claim.json")
    monkeypatch.setattr(
        subject,
        "assert_pre_receipt",
        lambda *_args: {"testwindow_off_quiescence": {"status": "PASS"}},
    )
    monkeypatch.setattr(
        subject,
        "assert_testwindow_off_quiescence",
        lambda *_args: calls.append("probe") or {"status": "PASS"},
    )
    monkeypatch.setattr(
        subject,
        "_BASE_LAUNCH_PERSISTENT_TASK",
        lambda *_args, **kwargs: {"resume": kwargs["resume"]},
    )
    result = subject.launch_persistent_task(
        subject.PRE_RECEIPT_PATH,
        "a" * 64,
        subject.AUTHORIZATION_PATH,
        subject.STATE_PATH,
        resume=False,
    )
    assert result == {"resume": False}
    assert calls == ["probe"]


def test_draft_contract_and_namespace_are_distinct_and_exact() -> None:
    contract = subject.validate_draft_contract()
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
