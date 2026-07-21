from __future__ import annotations

import importlib.util
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import pytest


EA_ROOT = Path(__file__).resolve().parents[2]
TOOL = (
    EA_ROOT
    / "tools"
    / "candidate_analysis"
    / "audit_mulham_asian_sweep_london_xau_testwindow.py"
)
SPEC = importlib.util.spec_from_file_location("qm13210_xau_testwindow_subject", TOOL)
assert SPEC is not None and SPEC.loader is not None
subject = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = subject
SPEC.loader.exec_module(subject)


def _write_json(path: Path, payload: object) -> None:
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _runtime_probe() -> dict[str, object]:
    return {
        "scheduled_tasks": [
            {"task_name": name, "count": 1, "state": "Disabled"}
            for name in subject.MANAGED_OFF_TASKS
        ],
        "exact_factory_mt5_processes": [],
        "registered_factory_python_workers": [],
    }


def _install_fake_quiescence_files(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    flag = tmp_path / "FACTORY_OFF.flag"
    parallel = tmp_path / "codex_parallel.txt"
    workers = tmp_path / "worker_pids.json"
    _write_json(
        flag,
        {
            "off_at": "2026-07-21T09:22:58Z",
            "codex_parallel_before": "6",
        },
    )
    parallel.write_text("0\n", encoding="ascii")
    _write_json(workers, {"T1": 111})
    monkeypatch.setattr(subject, "FACTORY_OFF_FLAG_PATH", flag)
    monkeypatch.setattr(subject, "CODEX_PARALLEL_PATH", parallel)
    monkeypatch.setattr(subject, "WORKER_PIDS_PATH", workers)
    monkeypatch.setattr(subject, "_probe_quiescence_runtime", _runtime_probe)


def test_closure_proves_one_controller_zero_outcomes_and_exact_t1_overlap() -> None:
    closure = subject.validate_attempt002_invalid_infrastructure_closure(
        probe_task_terminal=False
    )
    assert closure["status"] == "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND"
    assert closure["native_controller_start_count"] == 1
    assert closure["native_summary_count"] == 0
    assert closure["native_outcome_artifact_count"] == 0
    overlap = closure["t1_overlap_evidence"]
    assert overlap["terminal"] == "T1"
    assert overlap["xau_interval_fully_contained_in_t1_factory_occupancy_ledger"] is True
    assert set(closure["opaque_log_bindings"]) == {
        "controller_stdout",
        "controller_stderr",
        "overlapping_factory_work_item_log",
    }


@pytest.mark.parametrize(
    ("mutation", "match"),
    [
        (
            lambda payload: payload["t1_overlap_evidence"].__setitem__(
                "factory_terminal_release_ledger_utc", "2026-07-21T09:13:00Z"
            ),
            "overlap chronology",
        ),
        (
            lambda payload: payload["native_start_proof"].__setitem__(
                "outcome_artifacts", [{"path": "forbidden"}]
            ),
            "native-start proof",
        ),
        (
            lambda payload: payload["outcome_fence"].__setitem__(
                "controller_stderr_opened", True
            ),
            "outcome fence",
        ),
        (
            lambda payload: payload["recovery_contract"].__setitem__(
                "attempt003_plus_in_old_namespace_forbidden", False
            ),
            "recovery contract",
        ),
        (
            lambda payload: payload["t1_overlap_evidence"].__setitem__(
                "factory_claim_was_missed", False
            ),
            "overlap identity",
        ),
        (
            lambda payload: payload["outcome_fence"].__setitem__(
                "native_profit_opened", False
            ),
            "outcome fence",
        ),
        (
            lambda payload: payload["native_start_proof"].__setitem__(
                "profit", 0
            ),
            "native-start proof",
        ),
        (
            lambda payload: payload["scheduled_task_terminal_state"].__setitem__(
                "outcome", None
            ),
            "recorded task terminal-state",
        ),
        (
            lambda payload: payload["control_bindings"]["launch_state"].__setitem__(
                "note", "forbidden"
            ),
            "immutable launch_state key-set",
        ),
    ],
)
def test_closure_adversarial_tamper_fails_closed(
    tmp_path: Path,
    mutation,
    match: str,
) -> None:
    payload = subject.B.load_json(subject.ATTEMPT_002_CLOSURE_PATH)
    mutation(payload)
    path = tmp_path / "tampered_closure.json"
    _write_json(path, payload)
    with pytest.raises(subject.InvalidEvidence, match=match):
        subject.validate_attempt002_invalid_infrastructure_closure(
            path, probe_task_terminal=False
        )


@pytest.mark.parametrize(
    "mutation",
    [
        lambda state: state.__setitem__("finished_utc", "2026-07-21T09:13:32Z"),
        lambda state: state["initial_authorization"].__setitem__(
            "payload_sha256", "0" * 64
        ),
        lambda state: state["cells"][0]["attempts"][0].__setitem__("profit", 0.0),
        lambda state: state["cells"][0]["attempts"][0].__setitem__(
            "native_outcome", None
        ),
    ],
    ids=(
        "extra-state-root-field",
        "authorization-reference-mismatch",
        "extra-profit-field",
        "extra-outcome-field",
    ),
)
def test_launch_state_adversarial_schema_or_reference_drift_fails_closed(
    monkeypatch: pytest.MonkeyPatch,
    mutation,
) -> None:
    original_load_json = subject.B.load_json
    state_path = subject._attempt002_control_paths()["launch_state"].resolve()

    def load_with_tampered_state(path: Path) -> dict[str, object]:
        payload = original_load_json(path)
        if Path(path).resolve() == state_path:
            payload = json.loads(json.dumps(payload))
            mutation(payload)
        return payload

    monkeypatch.setattr(subject.B, "load_json", load_with_tampered_state)
    with pytest.raises(subject.InvalidEvidence):
        subject.validate_attempt002_invalid_infrastructure_closure(
            probe_task_terminal=False
        )


def test_closure_rejects_semantically_invalid_authorization(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    original_load_json = subject.B.load_json
    authorization_path = subject._attempt002_control_paths()["authorization"].resolve()

    def load_with_wrong_analysis(path: Path) -> dict[str, object]:
        payload = original_load_json(path)
        if Path(path).resolve() == authorization_path:
            payload = json.loads(json.dumps(payload))
            payload["analysis_id"] = "WRONG_ANALYSIS"
        return payload

    monkeypatch.setattr(subject.B, "load_json", load_with_wrong_analysis)
    with pytest.raises(subject.AuthorizationError, match="authorization drift"):
        subject.validate_attempt002_invalid_infrastructure_closure(
            probe_task_terminal=False
        )


def test_draft_freezes_same_strategy_build_data_windows_costs_and_gates() -> None:
    draft = subject.validate_draft_contract()
    frozen = draft["frozen_execution_identity"]
    assert draft["analysis_id"].endswith("XAUUSD_NATIVE_002")
    assert draft["candidate"] == subject.X._candidate_contract()
    assert draft["windows"] == subject.X._window_contract()
    assert frozen["source_build_commit"] == "9e6c17e1e954aa6854afcc93dc72b64926316fd1"
    assert frozen["input_bindings"] == subject.X.ATTEMPT_002_INPUT_BINDINGS
    assert frozen["cost_schedule_sha256"] == subject.B.canonical_sha256(
        subject.X.ATTEMPT_002_COST_SCHEDULE
    )
    assert frozen["merit_contract_sha256"] == subject.B.canonical_sha256(
        subject.X.MERIT_GATES
    )
    assert frozen["ea_ex5_set_data_parameters_windows_costs_and_gates_unchanged"] is True
    assert draft["supersession"]["new_namespace_is_separate_analysis_not_attempt003"] is True


def test_plan_is_only_new_namespace_and_still_t1_model4_two_duplicates(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    set_binding = {
        "path": str(tmp_path / "xau.set"),
        "size": 1,
        "sha256": "a" * 64,
    }
    plan = subject.build_plan(RESEARCH_SYMBOL := "XAUUSD.DWX", set_binding, subject.ALLOWED_RUN_ROOT)
    assert plan["single_authorized_symbol"] == RESEARCH_SYMBOL
    assert plan["native_run_count"] == 8
    assert all(cell["model"] == 4 and cell["duplicates"] == 2 for cell in plan["cells"])
    monkeypatch.setattr(subject, "assert_testwindow_off_quiescence", lambda *_args: {"status": "PASS"})
    pre = {
        "bindings": {
            "powershell": {"path": r"C:\pwsh.exe"},
            "runner": {"path": r"C:\run_smoke.ps1"},
        },
        "plan": plan,
        "testwindow_off_quiescence": {"status": "PASS"},
    }
    command = subject.runner_command(pre, plan["cells"][0])
    assert command[command.index("-Terminal") + 1] == "T1"
    assert command[command.index("-Model") + 1] == "4"
    assert command[command.index("-Runs") + 1] == "2"
    assert command[command.index("-Symbol") + 1] == "XAUUSD.DWX"
    with pytest.raises(subject.InvalidEvidence, match="exactly"):
        subject.build_plan("XAUUSD.DWX", set_binding, subject.RUN_NAMESPACE_ROOT / "ATTEMPT_002")


@pytest.mark.parametrize(
    ("field", "value", "match"),
    [
        (
            "scheduled_tasks",
            [{"task_name": "wrong", "count": 1, "state": "Disabled"}],
            "task probe closure",
        ),
        (
            "exact_factory_mt5_processes",
            [{"terminal": "T1", "image": "terminal64", "pid": 123}],
            "terminal/tester",
        ),
        (
            "registered_factory_python_workers",
            [{"terminal": "T1", "image": "python", "pid": 123}],
            "Python factory worker",
        ),
    ],
)
def test_quiescence_process_and_task_drift_fails_closed(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    field: str,
    value: object,
    match: str,
) -> None:
    _install_fake_quiescence_files(tmp_path, monkeypatch)
    runtime = _runtime_probe()
    runtime[field] = value
    monkeypatch.setattr(subject, "_probe_quiescence_runtime", lambda: runtime)
    with pytest.raises(subject.InvalidEvidence, match=match):
        subject.probe_testwindow_off_quiescence()


def test_quiescence_requires_flag_parallel_zero_and_stable_pre_binding(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _install_fake_quiescence_files(tmp_path, monkeypatch)
    proof = subject.probe_testwindow_off_quiescence()
    subject.assert_testwindow_off_quiescence(proof)
    subject.CODEX_PARALLEL_PATH.write_text("1\n", encoding="ascii")
    with pytest.raises(subject.InvalidEvidence, match="codex_parallel=0"):
        subject.assert_testwindow_off_quiescence(proof)


def test_quiescence_rejects_unregistered_terminal_worker_mutex(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _install_fake_quiescence_files(tmp_path, monkeypatch)
    monkeypatch.setattr(subject, "_probe_worker_mutexes", lambda: ["T1"])
    with pytest.raises(subject.InvalidEvidence, match="terminal-worker mutexes"):
        subject.probe_testwindow_off_quiescence()


def test_quiescence_expected_invariant_cannot_be_forged(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _install_fake_quiescence_files(tmp_path, monkeypatch)
    proof = subject.probe_testwindow_off_quiescence()
    forged = json.loads(json.dumps(proof))
    forged["invariant"]["contract_version"] = "FORGED"
    with pytest.raises(subject.InvalidEvidence, match="PRE-bound invariant drift"):
        subject.assert_testwindow_off_quiescence(forged)


def test_runner_rechecks_quiescence_before_every_cell(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    calls: list[str] = []

    def check(_expected=None):
        calls.append("quiescence")
        return {"status": "PASS"}

    monkeypatch.setattr(subject, "assert_testwindow_off_quiescence", check)
    monkeypatch.setattr(subject, "_BASE_RUNNER_COMMAND", lambda _pre, _cell: ["runner"])
    assert subject.runner_command(
        {"testwindow_off_quiescence": {"status": "PASS"}}, {"cell_id": "DEV"}
    ) == ["runner"]
    assert calls == ["quiescence"]


def test_worker_fails_before_base_worker_if_quiescence_is_lost(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    job = tmp_path / "launch_job.json"
    monkeypatch.setattr(subject, "JOB_PATH", job)
    base_called = False

    def base(_path: Path) -> int:
        nonlocal base_called
        base_called = True
        return 0

    monkeypatch.setattr(subject, "_BASE_WORKER_RUN", base)
    monkeypatch.setattr(
        subject,
        "assert_testwindow_off_quiescence",
        lambda *_args: (_ for _ in ()).throw(subject.InvalidEvidence("lost")),
    )
    with pytest.raises(subject.InvalidEvidence, match="lost"):
        subject._worker_run(job)
    assert base_called is False


def test_launch_resume_and_second_attempt_surfaces_are_forbidden(
    tmp_path: Path,
) -> None:
    with pytest.raises(subject.AuthorizationError, match="resume is forbidden"):
        subject.launch_persistent_task(
            subject.PRE_RECEIPT_PATH,
            "a" * 64,
            subject.AUTHORIZATION_PATH,
            subject.STATE_PATH,
            resume=True,
        )
    parser = subject.build_parser()
    subparsers = next(action for action in parser._actions if getattr(action, "choices", None))
    launch_options = {
        option
        for action in subparsers.choices["launch"]._actions
        for option in action.option_strings
    }
    assert "--resume" not in launch_options
    assert "--terminal" not in launch_options
    assert "--model" not in launch_options
    assert "--duplicates" not in launch_options
    with pytest.raises(subject.InvalidEvidence, match="launch state"):
        subject._assert_exact_control_path(tmp_path / "state.json", subject.STATE_PATH, "launch state")


def test_final_payload_binds_wrapper_predecessor_closures_and_testwindow_scripts() -> None:
    bindings = {
        role: {"path": f"C:/frozen/{role}", "size": 1, "sha256": "a" * 64}
        for role in subject.FINAL_ARTIFACT_ROLES
    }
    payload = subject._final_payload(
        "9e6c17e1e954aa6854afcc93dc72b64926316fd1",
        datetime.now(timezone.utc).isoformat(),
        bindings,
    )
    assert set(payload["artifact_bindings"]) == subject.FINAL_ARTIFACT_ROLES
    for role in (
        "adapter",
        "superseded_adapter",
        "superseded_contract",
        "attempt001_closure",
        "attempt002_closure",
        "testwindow_off",
        "factory_off",
        "task_manifest",
        "process_scope",
    ):
        assert role in payload["artifact_bindings"]
    assert payload["run_namespace"]["retry_or_attempt002_plus_forbidden"] is True


def test_authorization_is_new_analysis_only(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "authorization.json"
    monkeypatch.setattr(subject, "AUTHORIZATION_PATH", path)
    payload = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": subject.ANALYSIS_ID,
        "pre_receipt_sha256": "a" * 64,
        "scope": subject.AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": "XAUUSD.DWX",
        "authorized_cells": [window.cell_id for window in subject.WINDOWS],
        "duplicates_per_cell": 2,
        "model": 4,
        "authorize_native_outcomes": True,
        "created_utc": "2026-07-21T09:30:00Z",
        "expires_utc": "2026-07-21T21:30:00Z",
    }
    _write_json(path, payload)
    subject.validate_authorization(
        path,
        "a" * 64,
        now=datetime(2026, 7, 21, 10, 0, tzinfo=timezone.utc),
    )
    payload["analysis_id"] = subject.X.ANALYSIS_ID
    _write_json(path, payload)
    with pytest.raises(subject.AuthorizationError, match="authorization drift"):
        subject.validate_authorization(
            path,
            "a" * 64,
            now=datetime(2026, 7, 21, 10, 0, tzinfo=timezone.utc),
        )
