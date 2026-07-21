from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import sys
import threading
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timezone
from pathlib import Path
from types import ModuleType
from typing import Any, Mapping

import pytest


HERE = Path(__file__).resolve()
EA_ROOT = HERE.parents[2]
TOOLS = EA_ROOT / "tools" / "candidate_analysis"
UTILITY_PATH = TOOLS / "close_qm20002_g1.py"
TASK_HELPER_PATH = TOOLS / "close_qm20002_g1_task.ps1"
AUDITOR_PATH = TOOLS / "audit_short_ny_reverse_time.py"


def load_module(path: Path, name: str) -> ModuleType:
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


closure = load_module(UTILITY_PATH, "qm20002_g1_closure_under_test")
auditor = load_module(AUDITOR_PATH, "qm20002_g1_frozen_auditor_for_closure_test")


def write_json(path: Path, value: Mapping[str, Any]) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = closure.canonical_bytes(value)
    path.write_bytes(encoded)
    return hashlib.sha256(encoded).hexdigest()


def bind(path: Path) -> dict[str, Any]:
    return {
        "path": str(path.resolve()),
        "size": path.stat().st_size,
        "sha256": closure.sha256_file(path),
    }


def process_fields() -> dict[str, Any]:
    return {
        "matching_worker_process_count": 0,
        "matching_worker_process_count_basis": (
            "INFERRED_FROM_EXACT_NEVER_RUN_TASK_HISTORY_AND_NON_RUNNING_TASK_STATE"
        ),
        "dev1_owner_process_count": 0,
        "dev1_root_process_count": 0,
        "relevant_process_identity_sha256": hashlib.sha256(b"").hexdigest(),
        "stable_snapshot_count": 2,
        "process_probe_method": closure.PROCESS_PROBE_METHOD,
    }


def task_evidence(*, disabled: bool) -> dict[str, Any]:
    return {
        "state": "Disabled" if disabled else "Ready",
        "enabled": not disabled,
        "last_run_utc": None,
        "last_task_result": 267011,
        "never_run": True,
        "non_null_trigger_count": 0,
        "non_null_action_count": 1,
        "task_xml_sha256": hashlib.sha256(
            b"disabled" if disabled else b"ready"
        ).hexdigest(),
        "task_contract_sha256": hashlib.sha256(b"task-contract").hexdigest(),
        **process_fields(),
    }


class FakeTaskRuntime:
    def __init__(self, contract: closure.ClosureContract) -> None:
        self.contract = contract
        self.exists = True
        self.enabled = True
        self.operations: list[str] = []

    def __call__(
        self,
        _contract: closure.ClosureContract,
        _job: Mapping[str, Any],
        _pre: Mapping[str, Any],
        helper_sha256: str,
        operation: str,
        **kwargs: Any,
    ) -> Mapping[str, Any]:
        self.operations.append(operation)
        common = {
            "operation": operation,
            "helper_sha256": helper_sha256,
            "task_name": self.contract.task_name,
            "task_path": "\\",
        }
        if operation == "InspectReady":
            if not self.exists or not self.enabled:
                raise closure.ClosureError("not ready")
            return {**common, "principal_sid": "S-1-5-21-1", "evidence": task_evidence(disabled=False), "absent": False}
        if operation == "Quiesce":
            if not self.exists:
                raise closure.ClosureError("absent")
            before = task_evidence(disabled=not self.enabled)
            self.enabled = False
            after = task_evidence(disabled=True)
            assert kwargs["expected_task_contract_sha256"] == after["task_contract_sha256"]
            return {**common, "principal_sid": "S-1-5-21-1", "before": before, "after": after, "absent": False}
        if operation == "InspectQuiesced":
            if not self.exists or self.enabled:
                raise closure.ClosureError("not quiesced")
            return {**common, "principal_sid": "S-1-5-21-1", "evidence": task_evidence(disabled=True), "absent": False}
        if operation == "Unregister":
            if not self.exists or self.enabled:
                raise closure.ClosureError("cannot unregister")
            assert kwargs["expected_disabled_xml_sha256"] == task_evidence(disabled=True)["task_xml_sha256"]
            self.exists = False
            absent = process_fields()
            absent["matching_worker_process_count_basis"] = (
                "INFERRED_FROM_EXACT_NEVER_RUN_TASK_HISTORY_AND_SUCCESSFUL_UNREGISTER"
            )
            return {**common, "principal_sid": "S-1-5-21-1", "before": task_evidence(disabled=True), "absent": True, **absent}
        if operation == "ProbeAbsent":
            if self.exists:
                raise closure.ClosureError("still exists")
            absent = process_fields()
            absent["matching_worker_process_count_basis"] = (
                "INFERRED_FROM_DURABLE_NEVER_RUN_CLOSURE_PROOF_REQUIRED_BY_CALLER"
            )
            return {**common, "absent": True, **absent}
        raise AssertionError(operation)


class FakeAuditor:
    def __init__(self, pre: Mapping[str, Any], authorization: Mapping[str, Any]) -> None:
        self.pre = copy.deepcopy(dict(pre))
        self.authorization = copy.deepcopy(dict(authorization))

    def assert_pre_receipt(self, _path: Path, _sha: str) -> dict[str, Any]:
        return copy.deepcopy(self.pre)

    def validate_authorization(
        self, _path: Path, _sha: str, _pre: Mapping[str, Any]
    ) -> dict[str, Any]:
        return copy.deepcopy(self.authorization)

    def _validate_launch_job(self, *_args: Any) -> None:
        return None

    def _assert_authorization_consumption(self, *_args: Any) -> None:
        return None

    def _validate_launch_state_shape(self, state: Mapping[str, Any]) -> None:
        assert state["status"] in {"PENDING", "REJECT"}
        if state["status"] == "REJECT":
            assert state["terminal"]["outcome_fence_crossed"] is False
            assert state["terminal"]["no_resume"] is True


def make_fixture(tmp_path: Path) -> tuple[
    closure.ClosureContract, FakeAuditor, FakeTaskRuntime, str, str
]:
    repo = tmp_path / "repo"
    run = tmp_path / "control" / "runs" / closure.RUN_ID
    auth_root = tmp_path / "control" / "authorization"
    run.mkdir(parents=True)
    auth_root.mkdir(parents=True)
    global_lock = auth_root / ".launch.global.lock"
    state_lock = run / ".launch_state.json.terminal.lock"
    global_lock.write_bytes(b"\0")
    state_lock.write_bytes(b"\0")

    auditor_path = repo / "audit.py"
    scheduler_path = repo / "scheduler.ps1"
    control_path = repo / "control.ps1"
    helper_path = repo / "close.ps1"
    freeze_path = repo / "freeze.json"
    python_path = repo / "python.exe"
    utility_copy_marker = repo / "unused.py"
    for path, content in (
        (auditor_path, b"auditor"),
        (scheduler_path, b"scheduler"),
        (control_path, b"control"),
        (helper_path, b"closure-helper"),
        (freeze_path, b"freeze"),
        (python_path, b"python"),
        (utility_copy_marker, b"unused"),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    pre_path = tmp_path / "control" / "pre" / "pre_receipt.json"
    authorization_path = auth_root / "authorization.json"
    consumption_path = auth_root / "consumptions" / "auth.json"
    job_path = run / "launch_job.json"
    state_path = run / "launch_state.json"
    intent_path = run / "g1_pre_outcome_closure_intent.json"
    receipt_path = run / "g1_pre_outcome_closure_receipt.json"
    pre = {
        "runtime": {"audit_control_path_helper": bind(control_path)},
        "machine_credential_rotation": {"target_sid": "S-1-5-21-2"},
    }
    pre_sha = write_json(pre_path, pre)
    auth_payload = {"authorized_by": "OWNER"}
    write_json(authorization_path, auth_payload)
    authorization = {"binding": bind(authorization_path), "payload": auth_payload}
    consumption_payload = {"status": "CONSUMED"}
    write_json(consumption_path, consumption_payload)
    consumption = {"binding": bind(consumption_path), "payload": consumption_payload}
    job = {
        "authorization": authorization,
        "authorization_consumption": consumption,
        "tool": bind(auditor_path),
        "scheduler": {
            "helper": bind(scheduler_path),
            "python": bind(python_path),
            "execution_limit_seconds": 60,
            "principal_sid": "S-1-5-21-1",
        },
    }
    job_sha = write_json(job_path, job)
    initial = {
        "schema_version": 2,
        "launcher_revision": 4,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_STATE",
        "analysis_id": closure.ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": "2026-07-21T00:00:00+00:00",
        "updated_utc": "2026-07-21T00:00:00+00:00",
        "started_utc": None,
        "finished_utc": None,
        "worker_pid": None,
        "job": bind(job_path),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha,
        "authorization": authorization,
        "scheduler": job["scheduler"],
        "resume_count": 0,
        "active_cell": None,
        "outcome_possible_since_utc": None,
        "cells": [],
        "terminal": None,
    }
    state_sha = write_json(state_path, initial)
    contract = closure.ClosureContract(
        repo_root=repo,
        run_root=run,
        state_path=state_path,
        job_path=job_path,
        pre_path=pre_path,
        authorization_path=authorization_path,
        consumption_path=consumption_path,
        intent_path=intent_path,
        receipt_path=receipt_path,
        global_lock_path=global_lock,
        state_lock_path=state_lock,
        auditor_path=auditor_path,
        scheduler_path=scheduler_path,
        control_helper_path=control_path,
        task_helper_path=helper_path,
        freeze_path=freeze_path,
        powershell_path=python_path,
        state_before_sha256=state_sha,
        job_sha256=job_sha,
        pre_sha256=pre_sha,
        authorization_sha256=closure.sha256_file(authorization_path),
        consumption_sha256=closure.sha256_file(consumption_path),
        auditor_sha256=closure.sha256_file(auditor_path),
        scheduler_sha256=closure.sha256_file(scheduler_path),
        control_helper_sha256=closure.sha256_file(control_path),
        freeze_sha256=closure.sha256_file(freeze_path),
        freeze_commit="f" * 40,
    )
    fake_auditor = FakeAuditor(pre, authorization)
    task = FakeTaskRuntime(contract)
    return (
        contract,
        fake_auditor,
        task,
        closure.sha256_file(UTILITY_PATH),
        closure.sha256_file(helper_path),
    )


def no_control_side_effect(
    _contract: closure.ClosureContract, operation: str, path: Path
) -> Mapping[str, Any]:
    if operation == "AssertAbsentFile" and path.exists():
        raise closure.ClosureError("expected absent")
    if operation == "AssertFile" and not path.is_file():
        raise closure.ClosureError("expected file")
    return {"status": "PASS", "operation": operation, "path": str(path)}


def invoke_fixture(
    contract: closure.ClosureContract,
    fake_auditor: FakeAuditor,
    task: FakeTaskRuntime,
    utility_sha: str,
    helper_sha: str,
    *,
    crash_hook=lambda _point: None,
) -> Mapping[str, Any]:
    authorized_utc = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    if contract.intent_path.exists():
        authorized_utc = json.loads(
            contract.intent_path.read_text(encoding="utf-8")
        )["authorized_utc"]
    return closure.close_g1(
        contract,
        authorized_utc=authorized_utc,
        expected_utility_sha256=utility_sha,
        expected_task_helper_sha256=helper_sha,
        auditor=fake_auditor,
        task_call=task,
        control_call=no_control_side_effect,
        git_assert=lambda _contract: None,
        crash_hook=crash_hook,
    )


def test_powershell_helper_has_no_forbidden_process_query_surface() -> None:
    source = TASK_HELPER_PATH.read_text(encoding="utf-8")
    folded = source.casefold()
    assert "win32_process" not in folded
    assert "commandline" not in folded
    assert "getownersid" not in folded
    assert "invoke-cimmethod" not in folded
    assert "openprocesstoken" in folded
    assert "queryfullprocessimagename" in folded
    assert "matching_worker_process_count_basis" in source


def test_closed_state_is_schema_valid_and_strictly_pre_outcome() -> None:
    state = {
        "schema_version": 2,
        "launcher_revision": 4,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_STATE",
        "analysis_id": closure.ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": "2026-07-21T00:00:00+00:00",
        "updated_utc": "2026-07-21T00:00:00+00:00",
        "started_utc": None,
        "finished_utc": None,
        "worker_pid": None,
        "job": {"path": "x", "size": 1, "sha256": "1" * 64},
        "pre_receipt_path": "p",
        "pre_receipt_sha256": "2" * 64,
        "authorization": {},
        "scheduler": {},
        "resume_count": 0,
        "active_cell": None,
        "outcome_possible_since_utc": None,
        "cells": [],
        "terminal": None,
    }
    evidence = task_evidence(disabled=True)
    closed = closure._closed_state(state, "3" * 64, evidence)
    auditor._validate_launch_state_shape(closed)
    proof = closure._terminal_proof(closed, "3" * 64)
    assert proof["quiesced"] == closure.canonical_sha256(evidence)
    assert closed["terminal"]["outcome_fence_crossed"] is False
    assert closed["terminal"]["no_resume"] is True
    assert closed["cells"] == []


def test_create_new_publication_has_one_winner_under_race(tmp_path: Path) -> None:
    contract = replace(closure.default_contract(), run_root=tmp_path)
    target = tmp_path / "immutable.json"
    barrier = threading.Barrier(2)

    def publish(value: int) -> tuple[str, int]:
        barrier.wait()
        try:
            closure._publish_json(
                contract,
                target,
                {"value": value},
                replace=False,
                control_call=no_control_side_effect,
            )
            return "PASS", value
        except closure.ClosureError:
            return "REJECT", value

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(publish, (1, 2)))
    assert sorted(status for status, _ in results) == ["PASS", "REJECT"]
    persisted = json.loads(target.read_text(encoding="utf-8"))
    winner = next(value for status, value in results if status == "PASS")
    assert persisted == {"value": winner}


@pytest.mark.parametrize(
    "crash_point",
    ["after_intent", "after_quiesce", "after_state", "after_unregister", "after_receipt"],
)
def test_each_durable_crash_point_recovers_idempotently(
    tmp_path: Path, crash_point: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class SimulatedCrash(RuntimeError):
        pass

    crashed = False

    def hook(point: str) -> None:
        nonlocal crashed
        if point == crash_point and not crashed:
            crashed = True
            raise SimulatedCrash(point)

    with pytest.raises(SimulatedCrash, match=crash_point):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=hook,
        )
    result = invoke_fixture(
        contract, fake_auditor, task, utility_sha, helper_sha
    )
    assert result["status"] in {"CLOSED", "ALREADY_CLOSED"}
    assert result["outcome_data_read"] is False
    assert task.exists is False
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    assert state["status"] == "REJECT"
    assert state["terminal"]["outcome_fence_crossed"] is False
    assert state["terminal"]["no_resume"] is True
    receipt_before = contract.receipt_path.read_bytes()
    again = invoke_fixture(
        contract, fake_auditor, task, utility_sha, helper_sha
    )
    assert again["status"] == "ALREADY_CLOSED"
    assert contract.receipt_path.read_bytes() == receipt_before


def test_default_contract_is_exactly_run_local_and_frozen() -> None:
    contract = closure.default_contract()
    assert contract.intent_path.parent == contract.run_root
    assert contract.receipt_path.parent == contract.run_root
    assert contract.intent_path.name == "g1_pre_outcome_closure_intent.json"
    assert contract.receipt_path.name == "g1_pre_outcome_closure_receipt.json"
    assert contract.state_before_sha256 == (
        "7aa51ce458420431db4cac94e500d3da07b82261312ba334cb80a7b420433ce7"
    )
    assert contract.pre_sha256 == (
        "2ce641d3b0c0028eae3056958f09e8a28ee60d6f8ac6c621f0bde57f81161b94"
    )
    assert contract.authorization_sha256 == (
        "223d53e83a0d3b03f20af3b1b9c5730da365b414cad2f9f427f8b6e17ad46c6f"
    )
    assert contract.control_helper_sha256 == (
        "b3be96b0beb5b264390ba6087deacfd9fb3174537c2495d566e431d71089fc2f"
    )
    assert contract.freeze_commit == closure.FROZEN_COMMIT


def test_owner_timestamp_parser_rejects_non_z_and_future() -> None:
    with pytest.raises(closure.ClosureError):
        closure.parse_owner_utc("2026-07-21T03:00:00+00:00")
    future = datetime.now(timezone.utc).replace(microsecond=0)
    future = future.replace(year=future.year + 1).isoformat().replace("+00:00", "Z")
    with pytest.raises(closure.ClosureError):
        closure.parse_owner_utc(future)
