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
from types import ModuleType, SimpleNamespace
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


def task_evidence(*, disabled: bool, started: bool = False) -> dict[str, Any]:
    evidence = {
        "state": "Disabled" if disabled else "Ready",
        "enabled": not disabled,
        "last_run_utc": "2026-07-21T03:00:01+00:00" if started else None,
        "last_task_result": 1 if started else 267011,
        "never_run": not started,
        "non_null_trigger_count": 0,
        "non_null_action_count": 1,
        "task_xml_sha256": hashlib.sha256(
            b"disabled" if disabled else b"ready"
        ).hexdigest(),
        "task_contract_sha256": hashlib.sha256(b"task-contract").hexdigest(),
        **process_fields(),
    }
    if started:
        evidence["matching_worker_process_count_basis"] = (
            "INFERRED_FROM_DURABLE_TERMINAL_REJECT_AND_NON_RUNNING_TASK_STATE"
        )
    return evidence


class FakeTaskRuntime:
    def __init__(self, contract: closure.ClosureContract) -> None:
        self.contract = contract
        self.exists = True
        self.enabled = True
        self.started_race = False
        self.preterminal_race_state: str | None = None
        self.preterminal_dev1_owner_count = 0
        self.preterminal_dev1_root_count = 0
        self.await_forgets_start_race = False
        self.crash_after_quiesce_side_effect_once = False
        self.last_preterminal_evidence: dict[str, Any] | None = None
        self.last_preterminal_probe: dict[str, Any] | None = None
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
        if operation == "InspectReadyOrRunning":
            if not self.exists or not self.enabled:
                raise closure.ClosureError("not enabled")
            evidence = task_evidence(disabled=False)
            if self.preterminal_race_state is not None:
                assert self.preterminal_race_state in {"Ready", "Running"}
                persisted = json.loads(
                    self.contract.state_path.read_text(encoding="utf-8")
                )
                assert persisted["status"] == "PENDING"
                assert persisted["terminal"] is None
                self.started_race = True
                evidence = task_evidence(disabled=False, started=True)
                evidence["state"] = self.preterminal_race_state
                evidence["matching_worker_process_count_basis"] = (
                    "INFERRED_FROM_CALLER_HELD_STATE_LOCK_AND_DIRECT_ZERO_DEV1_OWNER_OR_ROOT"
                )
            evidence["dev1_owner_process_count"] = (
                self.preterminal_dev1_owner_count
            )
            evidence["dev1_root_process_count"] = self.preterminal_dev1_root_count
            if (
                self.preterminal_dev1_owner_count > 0
                or self.preterminal_dev1_root_count > 0
            ):
                evidence["matching_worker_process_count_basis"] = (
                    "INFERRED_FROM_CALLER_HELD_STATE_LOCK_WITH_STABLE_COMMAND_LINE_FREE_DEV1_INVENTORY"
                )
            self.last_preterminal_evidence = copy.deepcopy(evidence)
            probe = {
                **common,
                "principal_sid": "S-1-5-21-1",
                "evidence": evidence,
                "absent": False,
            }
            self.last_preterminal_probe = copy.deepcopy(probe)
            return probe
        if operation == "Quiesce":
            if not self.exists:
                raise closure.ClosureError("absent")
            persisted = json.loads(
                self.contract.state_path.read_text(encoding="utf-8")
            )
            assert persisted["status"] == "REJECT"
            assert "closure_phase=QUIESCE_PENDING" in persisted["terminal"]["error"]
            before = task_evidence(disabled=not self.enabled)
            self.enabled = False
            if self.crash_after_quiesce_side_effect_once:
                self.crash_after_quiesce_side_effect_once = False
                raise RuntimeError("simulated crash after Disable-ScheduledTask")
            after = task_evidence(disabled=True, started=self.started_race)
            if self.started_race:
                after["state"] = "Running"
                after["matching_worker_process_count_basis"] = (
                    "INFERRED_FROM_CALLER_HELD_STATE_LOCK_AND_DIRECT_ZERO_DEV1_OWNER_OR_ROOT"
                )
            assert kwargs["expected_task_contract_sha256"] == after["task_contract_sha256"]
            return {
                **common,
                "principal_sid": "S-1-5-21-1",
                "before": before,
                "after": after,
                "start_race_observed": self.started_race,
                "absent": False,
            }
        if operation == "InspectQuiesced":
            if not self.exists or self.enabled:
                raise closure.ClosureError("not quiesced")
            return {**common, "principal_sid": "S-1-5-21-1", "evidence": task_evidence(disabled=True), "absent": False}
        if operation == "AwaitQuiesced":
            if not self.exists or self.enabled:
                raise closure.ClosureError("not disabled")
            await_started = self.started_race and not self.await_forgets_start_race
            evidence = task_evidence(disabled=True, started=await_started)
            return {
                **common,
                "principal_sid": "S-1-5-21-1",
                "evidence": evidence,
                "start_race_observed": await_started,
                "absent": False,
            }
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
                closure.ABSENT_START_RACE_BASIS
                if kwargs.get("allow_observed_start_race", False)
                else closure.ABSENT_NEVER_RUN_BASIS
            )
            return {**common, "absent": True, **absent}
        raise AssertionError(operation)


def restart_task_runtime(previous: FakeTaskRuntime) -> FakeTaskRuntime:
    """Simulate a new closure process from durable scheduler properties only."""

    restarted = FakeTaskRuntime(previous.contract)
    restarted.exists = previous.exists
    restarted.enabled = previous.enabled
    restarted.started_race = previous.started_race
    return restarted


class FakeAuditor:
    SCHEMA_VERSION = 2
    ANALYSIS_ID = closure.ANALYSIS_ID
    CONTRACT_COMMIT = "c" * 40
    RUNTIME_ROLES = {
        "audit_control_path_helper": object(),
        "scheduled_task_helper": object(),
        "python_binary": object(),
    }
    canonical_sha256 = staticmethod(auditor.canonical_sha256)

    def __init__(
        self,
        pre: Mapping[str, Any],
        authorization: Mapping[str, Any],
        inventory: Mapping[str, Any],
    ) -> None:
        self.pre = copy.deepcopy(dict(pre))
        self.authorization = copy.deepcopy(dict(authorization))
        self.inventory = copy.deepcopy(dict(inventory))

    def _assert_control_path_layout(
        self, path: Path, _role: str
    ) -> Path:
        return path.resolve()

    def _assert_control_file(
        self, path: Path, _helper_sha256: str | None = None
    ) -> None:
        assert path.is_file()

    def _audit_control_contract(self) -> dict[str, Any]:
        return {"fixture": "CONTROL_PATH_IS_SEALED"}

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

    def _dev1_run_inventory(self) -> dict[str, Any]:
        return copy.deepcopy(self.inventory)


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
    contract_path = repo / "contract.md"
    python_path = repo / "python.exe"
    utility_copy_marker = repo / "unused.py"
    for path, content in (
        (auditor_path, b"auditor"),
        (scheduler_path, b"scheduler"),
        (control_path, b"control"),
        (helper_path, b"closure-helper"),
        (freeze_path, b"freeze"),
        (contract_path, b"contract"),
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
    anchor_path = run / "g1_pre_outcome_quiescence_anchor.json"
    receipt_path = run / "g1_pre_outcome_closure_receipt.json"
    plan_without_sha = {
        "cell_count": 4,
        "duplicates_per_cell": 2,
        "total_native_runs": 8,
        "execution": "SEQUENTIAL_SINGLE_DEV1_TERMINAL",
        "model": 4,
        "cells": [{"fixture_cell": index} for index in range(4)],
    }
    pre = {
        "schema_version": FakeAuditor.SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": "2026-07-21T00:00:00+00:00",
        "analysis_id": closure.ANALYSIS_ID,
        "outcome_fence": copy.deepcopy(closure.PRE_OUTCOME_FENCE),
        "contract": {
            "commit": FakeAuditor.CONTRACT_COMMIT,
            "binding": bind(contract_path),
        },
        "tool": bind(auditor_path),
        "sources": [],
        "compile": {},
        "set_manifest": {},
        "model4_data": {},
        "news_calendars": [],
        "runtime": {
            "audit_control_path_helper": bind(control_path),
            "scheduled_task_helper": bind(scheduler_path),
            "python_binary": bind(python_path),
        },
        "machine_credential_rotation": {"target_sid": "S-1-5-21-2"},
        "audit_control": {"fixture": "CONTROL_PATH_IS_SEALED"},
        "plan": {
            **plan_without_sha,
            "plan_sha256": FakeAuditor.canonical_sha256(plan_without_sha),
        },
    }
    pre_sha = write_json(pre_path, pre)
    auth_payload = {"authorized_by": "OWNER"}
    write_json(authorization_path, auth_payload)
    authorization = {"binding": bind(authorization_path), "payload": auth_payload}
    consumption_payload = {"status": "CONSUMED"}
    write_json(consumption_path, consumption_payload)
    consumption = {"binding": bind(consumption_path), "payload": consumption_payload}
    inventory = {
        "root": str((tmp_path / "dev1_runs").resolve()),
        "exists": True,
        "directory_count": 0,
        "directory_names_sha256": hashlib.sha256(b"").hexdigest(),
    }
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
        "dev1_runs_before_launch": inventory,
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
        anchor_path=anchor_path,
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
    fake_auditor = FakeAuditor(pre, authorization, inventory)
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
        git_assert=lambda _contract, _pre: None,
        crash_hook=crash_hook,
    )


def test_every_pre_repo_binding_is_checked_against_its_freeze_blob(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    contract, _fake_auditor, _task, _utility_sha, _helper_sha = make_fixture(
        tmp_path
    )
    normal_path = contract.repo_root / "framework" / "normal.bin"
    smoke_path = contract.repo_root / "framework" / "scripts" / "run_smoke.ps1"
    outside_path = tmp_path / "outside.bin"
    for path, payload in (
        (normal_path, b"normal-at-freeze"),
        (outside_path, b"historically-sealed-outside-repo"),
    ):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)
    raw_run_smoke = closure._git_blob_at_commit(
        closure.default_contract(),
        closure.FROZEN_RUN_SMOKE_COMMIT,
        Path(closure.FROZEN_RUN_SMOKE_PATH),
    )
    filtered_run_smoke = closure._git_filtered_blob_at_commit(
        closure.default_contract(),
        closure.FROZEN_RUN_SMOKE_COMMIT,
        Path(closure.FROZEN_RUN_SMOKE_PATH),
    )
    freeze = {
        "shared_runtime": {
            "frozen_run_smoke_commit": closure.FROZEN_RUN_SMOKE_COMMIT,
            "frozen_run_smoke_size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
            "frozen_run_smoke_sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
        }
    }
    pre = {
        "runtime": {
            "runner_smoke": {
                "path": str(smoke_path.resolve()),
                "size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
                "sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
            }
        },
        "ordinary_repo_binding": bind(normal_path),
        "outside_repo_binding": bind(outside_path),
    }
    observed: list[tuple[str, str]] = []

    def fake_blob(
        _contract: closure.ClosureContract, commit: str, relative: Path
    ) -> bytes:
        observed.append((commit, relative.as_posix()))
        if relative.as_posix() == "framework/scripts/run_smoke.ps1":
            return raw_run_smoke
        if relative.as_posix() == "framework/normal.bin":
            return b"normal-at-freeze"
        raise AssertionError(relative)

    monkeypatch.setattr(closure, "_git_blob_at_commit", fake_blob)
    monkeypatch.setattr(
        closure,
        "_git_filtered_blob_at_commit",
        lambda *_args, **_kwargs: filtered_run_smoke,
    )
    monkeypatch.setattr(
        closure.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
    )
    closure._assert_pre_repo_bindings_at_freeze(contract, pre, freeze)
    assert observed == [
        (
            closure.FROZEN_RUN_SMOKE_COMMIT,
            "framework/scripts/run_smoke.ps1",
        ),
        (contract.freeze_commit, "framework/normal.bin"),
    ]

    drifted = copy.deepcopy(pre)
    drifted["ordinary_repo_binding"]["sha256"] = "0" * 64
    with pytest.raises(
        closure.ClosureError,
        match="repository binding differs from freeze blob",
    ):
        closure._assert_pre_repo_bindings_at_freeze(contract, drifted, freeze)


@pytest.mark.parametrize(
    ("target", "value", "message"),
    [
        ("pre_size", 1, "PRE run_smoke binding differs"),
        ("pre_sha", "0" * 64, "PRE run_smoke binding differs"),
        ("freeze_size", 1, "exact run_smoke provenance drift"),
        ("freeze_sha", "0" * 64, "exact run_smoke provenance drift"),
        ("freeze_commit", "e" * 40, "exact run_smoke provenance drift"),
    ],
)
def test_run_smoke_exception_rejects_any_pre_or_freeze_manifest_drift(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    target: str,
    value: Any,
    message: str,
) -> None:
    contract, _fake_auditor, _task, _utility_sha, _helper_sha = make_fixture(
        tmp_path
    )
    smoke_path = contract.repo_root / closure.FROZEN_RUN_SMOKE_PATH
    pre = {
        "runtime": {
            "runner_smoke": {
                "path": str(smoke_path.resolve()),
                "size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
                "sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
            }
        }
    }
    freeze = {
        "shared_runtime": {
            "frozen_run_smoke_commit": closure.FROZEN_RUN_SMOKE_COMMIT,
            "frozen_run_smoke_size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
            "frozen_run_smoke_sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
        }
    }
    if target == "pre_size":
        pre["runtime"]["runner_smoke"]["size"] = value
    elif target == "pre_sha":
        pre["runtime"]["runner_smoke"]["sha256"] = value
    elif target == "freeze_size":
        freeze["shared_runtime"]["frozen_run_smoke_size"] = value
    elif target == "freeze_sha":
        freeze["shared_runtime"]["frozen_run_smoke_sha256"] = value
    else:
        freeze["shared_runtime"]["frozen_run_smoke_commit"] = value
    monkeypatch.setattr(
        closure.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
    )
    with pytest.raises(closure.ClosureError, match=message):
        closure._assert_pre_repo_bindings_at_freeze(contract, pre, freeze)


def test_run_smoke_exception_rejects_normalized_raw_blob_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    contract, _fake_auditor, _task, _utility_sha, _helper_sha = make_fixture(
        tmp_path
    )
    smoke_path = contract.repo_root / closure.FROZEN_RUN_SMOKE_PATH
    pre = {
        "runtime": {
            "runner_smoke": {
                "path": str(smoke_path.resolve()),
                "size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
                "sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
            }
        }
    }
    freeze = {
        "shared_runtime": {
            "frozen_run_smoke_commit": closure.FROZEN_RUN_SMOKE_COMMIT,
            "frozen_run_smoke_size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
            "frozen_run_smoke_sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
        }
    }
    monkeypatch.setattr(
        closure.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
    )
    monkeypatch.setattr(
        closure,
        "_git_blob_at_commit",
        lambda *_args, **_kwargs: b"wrong-normalized-blob",
    )
    with pytest.raises(
        closure.ClosureError, match="normalized Git blob drift"
    ):
        closure._assert_pre_repo_bindings_at_freeze(contract, pre, freeze)


def test_run_smoke_exception_rejects_filtered_blob_drift(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    contract, _fake_auditor, _task, _utility_sha, _helper_sha = make_fixture(
        tmp_path
    )
    smoke_path = contract.repo_root / closure.FROZEN_RUN_SMOKE_PATH
    pre = {
        "runtime": {
            "runner_smoke": {
                "path": str(smoke_path.resolve()),
                "size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
                "sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
            }
        }
    }
    freeze = {
        "shared_runtime": {
            "frozen_run_smoke_commit": closure.FROZEN_RUN_SMOKE_COMMIT,
            "frozen_run_smoke_size": closure.FROZEN_RUN_SMOKE_WORKTREE_SIZE,
            "frozen_run_smoke_sha256": closure.FROZEN_RUN_SMOKE_WORKTREE_SHA256,
        }
    }
    raw_run_smoke = closure._git_blob_at_commit(
        closure.default_contract(),
        closure.FROZEN_RUN_SMOKE_COMMIT,
        Path(closure.FROZEN_RUN_SMOKE_PATH),
    )
    monkeypatch.setattr(
        closure.subprocess,
        "run",
        lambda *_args, **_kwargs: SimpleNamespace(returncode=0),
    )
    monkeypatch.setattr(
        closure,
        "_git_blob_at_commit",
        lambda *_args, **_kwargs: raw_run_smoke,
    )
    monkeypatch.setattr(
        closure,
        "_git_filtered_blob_at_commit",
        lambda *_args, **_kwargs: b"wrong-filtered-blob",
    )
    with pytest.raises(
        closure.ClosureError, match="filtered Git blob drift"
    ):
        closure._assert_pre_repo_bindings_at_freeze(contract, pre, freeze)


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
    ready_evidence = task_evidence(disabled=False)
    preterminal_probe = {
        "operation": "InspectReadyOrRunning",
        "evidence": ready_evidence,
    }
    intent = {
        "task": {
            "ready_task_xml_sha256": hashlib.sha256(b"ready").hexdigest(),
            "task_contract_sha256": evidence["task_contract_sha256"],
        }
    }
    preliminary = closure._preliminary_closed_state(
        state,
        "3" * 64,
        intent,
        preterminal_probe,
        ready_evidence,
        start_race_observed=False,
    )
    closed = closure._final_closed_state(
        preliminary,
        "3" * 64,
        evidence,
        {"path": r"C:\anchor.json", "size": 1, "sha256": "4" * 64},
        start_race_observed=False,
    )
    auditor._validate_launch_state_shape(closed)
    proof = closure._terminal_proof(closed, "3" * 64)
    assert proof["quiesced"] == closure.canonical_sha256(evidence)
    assert closed["terminal"]["outcome_fence_crossed"] is False
    assert closed["terminal"]["no_resume"] is True
    assert closed["cells"] == []


@pytest.mark.parametrize(
    ("evidence_started", "start_race_observed"),
    [(False, True), (True, False)],
)
def test_final_state_rejects_quiesced_never_run_race_mismatch(
    evidence_started: bool, start_race_observed: bool
) -> None:
    state = {
        "status": "REJECT",
        "terminal": {"error": "QUIESCE_PENDING"},
    }
    with pytest.raises(
        closure.ClosureError,
        match="race disposition drift",
    ):
        closure._final_closed_state(
            state,
            "3" * 64,
            task_evidence(disabled=True, started=evidence_started),
            {"path": r"C:\anchor.json", "size": 1, "sha256": "4" * 64},
            start_race_observed=start_race_observed,
        )


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
    [
        "after_intent",
        "after_preliminary_state",
        "after_quiesce",
        "after_anchor",
        "after_state",
        "after_unregister",
        "after_receipt",
    ],
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
    resumed_task = restart_task_runtime(task)
    result = invoke_fixture(
        contract, fake_auditor, resumed_task, utility_sha, helper_sha
    )
    assert result["status"] in {"CLOSED", "ALREADY_CLOSED"}
    assert result["outcome_data_read"] is False
    assert resumed_task.exists is False
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    assert state["status"] == "REJECT"
    assert state["terminal"]["outcome_fence_crossed"] is False
    assert state["terminal"]["no_resume"] is True
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    assert contract.anchor_path.is_file()
    assert receipt["quiescence_anchor"] == bind(contract.anchor_path)
    assert receipt["launch_state"]["task_start_race_observed"] is False
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "task_start_race_observed"
    ] is False
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "never_run"
    ] is True
    receipt_before = contract.receipt_path.read_bytes()
    replay_task = restart_task_runtime(resumed_task)
    again = invoke_fixture(
        contract, fake_auditor, replay_task, utility_sha, helper_sha
    )
    assert again["status"] == "ALREADY_CLOSED"
    assert contract.receipt_path.read_bytes() == receipt_before


def test_default_contract_is_exactly_run_local_and_frozen() -> None:
    contract = closure.default_contract()
    assert contract.intent_path.parent == contract.run_root
    assert contract.anchor_path.parent == contract.run_root
    assert contract.receipt_path.parent == contract.run_root
    assert contract.intent_path.name == "g1_pre_outcome_closure_intent.json"
    assert contract.anchor_path.name == "g1_pre_outcome_quiescence_anchor.json"
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


def test_production_auditor_loader_supports_dataclass_resolution() -> None:
    contract = replace(
        closure.default_contract(),
        auditor_path=AUDITOR_PATH,
        auditor_sha256=closure.sha256_file(AUDITOR_PATH),
    )
    loaded = closure._load_auditor(contract)
    assert loaded.ANALYSIS_ID == closure.ANALYSIS_ID
    assert sys.modules[loaded.__name__] is loaded


def test_owner_timestamp_parser_rejects_non_z_and_future() -> None:
    with pytest.raises(closure.ClosureError):
        closure.parse_owner_utc("2026-07-21T03:00:00+00:00")
    future = datetime.now(timezone.utc).replace(microsecond=0)
    future = future.replace(year=future.year + 1).isoformat().replace("+00:00", "Z")
    with pytest.raises(closure.ClosureError):
        closure.parse_owner_utc(future)


@pytest.mark.parametrize(
    "mutation",
    [
        "task_name",
        "extra_top_level",
        "nested_absent_count",
        "nested_state_after",
        "quiesced_never_run",
    ],
)
def test_mutated_receipt_is_never_accepted_as_already_closed(
    tmp_path: Path, mutation: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    if mutation == "task_name":
        receipt["scheduled_task"]["task_name"] = "QM_QM20002_AUDIT_" + "0" * 24
    elif mutation == "extra_top_level":
        receipt["unexpected"] = True
    elif mutation == "nested_absent_count":
        receipt["scheduled_task"]["absent_probe"]["dev1_owner_process_count"] = 1
    elif mutation == "nested_state_after":
        receipt["launch_state"]["after"]["sha256"] = "0" * 64
    else:
        receipt["scheduled_task"]["quiesced_probe_binding"]["never_run"] = False
    write_json(contract.receipt_path, receipt)
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)


@pytest.mark.parametrize(
    "mutation",
    ["task_name", "outcome_transition", "ready_helper", "extra_ready_evidence"],
)
def test_mutated_after_intent_is_rejected_before_task_or_state_mutation(
    tmp_path: Path, mutation: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterIntent(RuntimeError):
        pass

    with pytest.raises(StopAfterIntent):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterIntent())
                if point == "after_intent"
                else None
            ),
        )
    intent = json.loads(contract.intent_path.read_text(encoding="utf-8"))
    if mutation == "task_name":
        intent["task"]["task_name"] = "QM_QM20002_AUDIT_" + "0" * 24
    elif mutation == "outcome_transition":
        intent["expected_transition"]["outcome_fence_crossed"] = True
    elif mutation == "ready_helper":
        intent["task"]["ready_probe"]["helper_sha256"] = "0" * 64
    else:
        intent["task"]["ready_probe"]["evidence"]["unexpected"] = 1
    write_json(contract.intent_path, intent)
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert closure.sha256_file(contract.state_path) == contract.state_before_sha256
    assert task.enabled is True


def test_mutated_closed_state_scheduler_is_rejected_before_unregister_or_receipt(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterState(RuntimeError):
        pass

    with pytest.raises(StopAfterState):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterState())
                if point == "after_state"
                else None
            ),
        )
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    state["scheduler"] = {"arbitrary": "mutated"}
    write_json(contract.state_path, state)
    with pytest.raises(closure.ClosureError, match="immutable field drift"):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert task.exists is True
    assert not contract.receipt_path.exists()


def test_dev1_inventory_is_reasserted_during_recovery(tmp_path: Path) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterPreliminary(RuntimeError):
        pass

    with pytest.raises(StopAfterPreliminary):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterPreliminary())
                if point == "after_preliminary_state"
                else None
            ),
        )
    fake_auditor.inventory["directory_count"] = 1
    with pytest.raises(closure.ClosureError, match="DEV1 run inventory changed"):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert task.enabled is True
    assert not contract.receipt_path.exists()


def test_start_race_observes_durable_reject_before_disable_and_closes(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.started_race = True
    resumed_task = restart_task_runtime(task)
    result = invoke_fixture(
        contract, fake_auditor, resumed_task, utility_sha, helper_sha
    )
    assert result["status"] == "CLOSED"
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    assert "closure_phase=CLOSED" in state["terminal"]["error"]
    assert "task_start_race_observed=true" in state["terminal"]["error"]
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    assert receipt["launch_state"]["task_start_race_observed"] is True
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "task_start_race_observed"
    ] is True
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "never_run"
    ] is False
    assert resumed_task.exists is False


@pytest.mark.parametrize("preterminal_state", ["Running", "Ready"])
def test_start_between_intent_and_preterminal_probe_is_rejected_before_disable(
    tmp_path: Path, preterminal_state: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.preterminal_race_state = preterminal_state
    if preterminal_state == "Running":
        task.preterminal_dev1_owner_count = 1
        task.preterminal_dev1_root_count = 1

    class StopAfterPreliminary(RuntimeError):
        pass

    with pytest.raises(StopAfterPreliminary):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterPreliminary())
                if point == "after_preliminary_state"
                else None
            ),
        )
    pending = json.loads(contract.state_path.read_text(encoding="utf-8"))
    assert pending["status"] == "REJECT"
    assert "closure_phase=QUIESCE_PENDING" in pending["terminal"]["error"]
    assert "task_start_race_observed=true" in pending["terminal"]["error"]
    assert "preterminal_probe_payload_b64=" in pending["terminal"]["error"]
    assert "preterminal_probe_sha256=" in pending["terminal"]["error"]
    assert task.last_preterminal_evidence is not None
    assert task.last_preterminal_probe is not None
    pending_match = closure.TERMINAL_PENDING_ERROR.fullmatch(
        pending["terminal"]["error"]
    )
    assert pending_match is not None
    assert pending_match.group("preterminal") == closure.canonical_sha256(
        task.last_preterminal_probe
    )
    assert closure.decode_canonical_b64(
        pending_match.group("preterminal_payload"), "test pre-terminal probe"
    ) == task.last_preterminal_probe
    if preterminal_state == "Running":
        assert task.last_preterminal_evidence["dev1_owner_process_count"] == 1
        assert task.last_preterminal_evidence["dev1_root_process_count"] == 1
    assert task.enabled is True
    assert task.operations[:2] == ["InspectReady", "InspectReadyOrRunning"]

    resumed_task = restart_task_runtime(task)
    result = invoke_fixture(
        contract, fake_auditor, resumed_task, utility_sha, helper_sha
    )
    assert result["status"] == "CLOSED"
    final_state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    final_match = closure.TERMINAL_CLOSED_ERROR.fullmatch(
        final_state["terminal"]["error"]
    )
    assert final_match is not None
    assert final_match.group("preterminal") == pending_match.group("preterminal")
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    assert receipt["launch_state"]["task_start_race_observed"] is True
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "task_start_race_observed"
    ] is True
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "never_run"
    ] is False
    assert receipt["scheduled_task"]["quiesced_probe_binding"][
        "preterminal_probe_sha256"
    ] == pending_match.group("preterminal")
    assert resumed_task.exists is False


def test_preterminal_race_cannot_be_erased_by_later_never_run_evidence(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.preterminal_race_state = "Running"
    task.preterminal_dev1_owner_count = 1
    task.preterminal_dev1_root_count = 1
    task.await_forgets_start_race = True
    with pytest.raises(
        closure.ClosureError,
        match="race disposition drift",
    ):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    pending = json.loads(contract.state_path.read_text(encoding="utf-8"))
    assert pending["status"] == "REJECT"
    assert "closure_phase=QUIESCE_PENDING" in pending["terminal"]["error"]
    assert "task_start_race_observed=true" in pending["terminal"]["error"]
    assert task.enabled is False
    assert task.exists is True
    assert not contract.receipt_path.exists()


def test_non_preterminal_ready_probe_rejects_nonzero_dev1_inventory(
    tmp_path: Path,
) -> None:
    contract, _fake_auditor, _task, _utility_sha, helper_sha = make_fixture(
        tmp_path
    )
    evidence = task_evidence(disabled=False)
    evidence["dev1_owner_process_count"] = 1
    evidence["dev1_root_process_count"] = 1
    evidence["matching_worker_process_count_basis"] = (
        "INFERRED_FROM_STABLE_COMMAND_LINE_FREE_DEV1_INVENTORY"
    )
    probe = {
        "operation": "InspectReady",
        "helper_sha256": helper_sha,
        "task_name": contract.task_name,
        "task_path": "\\",
        "principal_sid": "S-1-5-21-1",
        "evidence": evidence,
        "absent": False,
    }
    with pytest.raises(
        closure.ClosureError,
        match="process evidence is not exact and command-line-free",
    ):
        closure._validate_task_probe(
            probe,
            contract,
            disabled=False,
            label="ordinary ready probe",
            expected_helper_sha256=helper_sha,
            expected_principal_sid="S-1-5-21-1",
        )


def test_quiesce_only_start_race_is_durable_before_crash_and_recovery(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.started_race = True

    class StopAfterQuiesce(RuntimeError):
        pass

    with pytest.raises(StopAfterQuiesce):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterQuiesce())
                if point == "after_quiesce"
                else None
            ),
        )
    pending = json.loads(contract.state_path.read_text(encoding="utf-8"))
    proof = closure._terminal_proof(
        pending, bind(contract.intent_path)["sha256"]
    )
    assert proof["phase"] == "QUIESCE_PENDING"
    assert proof["start_race"] == "true"
    assert proof["quiesce"] != "NONE"
    quiesce_probe = closure.decode_canonical_b64(
        proof["quiesce_payload"], "test quiesce transition"
    )
    assert quiesce_probe["operation"] == "Quiesce"
    assert quiesce_probe["start_race_observed"] is True
    assert closure.canonical_sha256(quiesce_probe) == proof["quiesce"]
    assert not contract.anchor_path.exists()
    assert not contract.receipt_path.exists()

    resumed_task = restart_task_runtime(task)
    result = invoke_fixture(
        contract, fake_auditor, resumed_task, utility_sha, helper_sha
    )
    assert result["status"] == "CLOSED"
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    assert receipt["launch_state"]["task_start_race_observed"] is True
    assert receipt["scheduled_task"]["absent_probe"][
        "matching_worker_process_count_basis"
    ] == closure.ABSENT_START_RACE_BASIS


def test_quiesce_race_cannot_be_forgotten_by_await_or_poison_anchor(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.started_race = True
    task.await_forgets_start_race = True
    with pytest.raises(closure.ClosureError, match="race disposition drift"):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    pending = json.loads(contract.state_path.read_text(encoding="utf-8"))
    proof = closure._terminal_proof(
        pending, bind(contract.intent_path)["sha256"]
    )
    assert proof["phase"] == "QUIESCE_PENDING"
    assert proof["start_race"] == "true"
    assert proof["quiesce"] != "NONE"
    assert task.exists is True
    assert task.enabled is False
    assert not contract.anchor_path.exists()
    assert not contract.receipt_path.exists()


def test_recovery_after_disable_side_effect_before_quiesce_proof_publication(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    task.crash_after_quiesce_side_effect_once = True
    with pytest.raises(RuntimeError, match="after Disable-ScheduledTask"):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    pending = json.loads(contract.state_path.read_text(encoding="utf-8"))
    proof = closure._terminal_proof(
        pending, bind(contract.intent_path)["sha256"]
    )
    assert proof["phase"] == "QUIESCE_PENDING"
    assert proof["quiesce"] == "NONE"
    assert task.enabled is False
    assert task.exists is True

    resumed_task = restart_task_runtime(task)
    result = invoke_fixture(
        contract, fake_auditor, resumed_task, utility_sha, helper_sha
    )
    assert result["status"] == "CLOSED"
    anchor = json.loads(contract.anchor_path.read_text(encoding="utf-8"))
    anchored_pending = anchor["pending_state_payload"]
    anchored_proof = closure._terminal_proof(
        anchored_pending, bind(contract.intent_path)["sha256"]
    )
    recovered_quiesce = closure.decode_canonical_b64(
        anchored_proof["quiesce_payload"], "recovered quiesce transition"
    )
    assert recovered_quiesce["before"]["state"] == "Disabled"
    assert recovered_quiesce["before"]["enabled"] is False
    assert resumed_task.exists is False


@pytest.mark.parametrize("expected_start_race", [False, True])
def test_absence_probe_basis_is_exactly_race_aware(
    tmp_path: Path, expected_start_race: bool
) -> None:
    contract, _fake_auditor, _task, _utility_sha, helper_sha = make_fixture(
        tmp_path
    )
    probe = {
        "operation": "ProbeAbsent",
        "helper_sha256": helper_sha,
        "task_name": contract.task_name,
        "task_path": "\\",
        "absent": True,
        **process_fields(),
    }
    expected_basis = (
        closure.ABSENT_START_RACE_BASIS
        if expected_start_race
        else closure.ABSENT_NEVER_RUN_BASIS
    )
    probe["matching_worker_process_count_basis"] = expected_basis
    closure._validate_absent_probe(
        probe,
        contract,
        expected_helper_sha256=helper_sha,
        expected_start_race=expected_start_race,
    )
    probe["matching_worker_process_count_basis"] = (
        closure.ABSENT_NEVER_RUN_BASIS
        if expected_start_race
        else closure.ABSENT_START_RACE_BASIS
    )
    with pytest.raises(closure.ClosureError, match="absence proof envelope drift"):
        closure._validate_absent_probe(
            probe,
            contract,
            expected_helper_sha256=helper_sha,
            expected_start_race=expected_start_race,
        )


def test_receipt_recomputed_absence_wrapper_cannot_replace_fresh_probe(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    receipt = json.loads(contract.receipt_path.read_text(encoding="utf-8"))
    absent = receipt["scheduled_task"]["absent_probe"]
    absent["relevant_process_identity_sha256"] = "f" * 64
    receipt["scheduled_task"]["absent_probe_sha256"] = closure.canonical_sha256(
        absent
    )
    write_json(contract.receipt_path, receipt)
    with pytest.raises(
        closure.ClosureError, match="absence proof differs from fresh proof"
    ):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)


@pytest.mark.parametrize(
    "terminal_field",
    ["task_contract_sha256", "disabled_task_xml_sha256", "quiesced_evidence_sha256"],
)
def test_post_unregister_final_state_rewrite_is_rejected_by_intent_or_anchor(
    tmp_path: Path, terminal_field: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterUnregister(RuntimeError):
        pass

    with pytest.raises(StopAfterUnregister):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterUnregister())
                if point == "after_unregister"
                else None
            ),
        )
    assert task.exists is False
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    error, count = __import__("re").subn(
        rf"({terminal_field}=)[^;]+",
        rf"\g<1>{'f' * 64}",
        state["terminal"]["error"],
        count=1,
    )
    assert count == 1
    state["terminal"]["error"] = error
    write_json(contract.state_path, state)
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert not contract.receipt_path.exists()


def test_mutated_quiescence_anchor_is_rejected_before_unregister(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterState(RuntimeError):
        pass

    with pytest.raises(StopAfterState):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterState())
                if point == "after_state"
                else None
            ),
        )
    anchor = json.loads(contract.anchor_path.read_text(encoding="utf-8"))
    anchor["task"]["disabled_task_xml_sha256"] = "f" * 64
    write_json(contract.anchor_path, anchor)
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert task.exists is True
    assert not contract.receipt_path.exists()


@pytest.mark.parametrize(
    ("payload_field", "sha_field", "group_name"),
    [
        ("preterminal_probe_payload_b64", "preterminal_probe_sha256", "preterminal_payload"),
        ("quiesce_transition_probe_payload_b64", "quiesce_transition_probe_sha256", "quiesce_payload"),
    ],
)
def test_rehashed_embedded_probe_semantic_mutation_is_rejected(
    tmp_path: Path, payload_field: str, sha_field: str, group_name: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterQuiesce(RuntimeError):
        pass

    with pytest.raises(StopAfterQuiesce):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterQuiesce())
                if point == "after_quiesce"
                else None
            ),
        )
    state = json.loads(contract.state_path.read_text(encoding="utf-8"))
    match = closure.TERMINAL_PENDING_ERROR.fullmatch(state["terminal"]["error"])
    assert match is not None
    probe = closure.decode_canonical_b64(
        match.group(group_name), "probe selected for semantic mutation"
    )
    probe["task_name"] = "QM_QM20002_AUDIT_" + "0" * 24
    replacements = {
        payload_field: closure.canonical_b64(probe),
        sha_field: closure.canonical_sha256(probe),
    }
    error = state["terminal"]["error"]
    for field, value in replacements.items():
        error, count = __import__("re").subn(
            rf"({field}=)[^;]+", rf"\g<1>{value}", error, count=1
        )
        assert count == 1
    state["terminal"]["error"] = error
    write_json(contract.state_path, state)
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert task.exists is True
    assert not contract.anchor_path.exists()
    assert not contract.receipt_path.exists()


@pytest.mark.parametrize("artifact_attribute", ["anchor_path", "receipt_path"])
@pytest.mark.parametrize("existing_intent", [False, True])
def test_pending_initial_state_rejects_later_phase_artifacts_before_mutation(
    tmp_path: Path, artifact_attribute: str, existing_intent: bool
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)
    if existing_intent:
        class StopAfterIntent(RuntimeError):
            pass

        with pytest.raises(StopAfterIntent):
            invoke_fixture(
                contract,
                fake_auditor,
                task,
                utility_sha,
                helper_sha,
                crash_hook=lambda point: (
                    (_ for _ in ()).throw(StopAfterIntent())
                    if point == "after_intent"
                    else None
                ),
            )
    state_before = contract.state_path.read_bytes()
    operation_count = len(task.operations)
    write_json(getattr(contract, artifact_attribute), {"stale": True})
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert contract.state_path.read_bytes() == state_before
    assert len(task.operations) == operation_count
    assert task.exists is True
    assert task.enabled is True


@pytest.mark.parametrize("artifact_attribute", ["anchor_path", "receipt_path"])
def test_quiesce_pending_rejects_stale_later_phase_artifact_before_disable(
    tmp_path: Path, artifact_attribute: str
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterPreliminary(RuntimeError):
        pass

    with pytest.raises(StopAfterPreliminary):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterPreliminary())
                if point == "after_preliminary_state"
                else None
            ),
        )
    state_before = contract.state_path.read_bytes()
    operation_count = len(task.operations)
    write_json(getattr(contract, artifact_attribute), {"stale": True})
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert contract.state_path.read_bytes() == state_before
    assert len(task.operations) == operation_count
    assert task.exists is True
    assert task.enabled is True
    assert not contract.receipt_path.exists() or artifact_attribute == "receipt_path"


def test_closed_state_rejects_preexisting_receipt_before_unregister(
    tmp_path: Path,
) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterState(RuntimeError):
        pass

    with pytest.raises(StopAfterState):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterState())
                if point == "after_state"
                else None
            ),
        )
    state_before = contract.state_path.read_bytes()
    write_json(contract.receipt_path, {"stale": True})
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert contract.state_path.read_bytes() == state_before
    assert task.exists is True
    assert task.enabled is False
    assert "Unregister" not in task.operations


def test_closed_state_requires_bound_anchor_before_unregister(tmp_path: Path) -> None:
    contract, fake_auditor, task, utility_sha, helper_sha = make_fixture(tmp_path)

    class StopAfterState(RuntimeError):
        pass

    with pytest.raises(StopAfterState):
        invoke_fixture(
            contract,
            fake_auditor,
            task,
            utility_sha,
            helper_sha,
            crash_hook=lambda point: (
                (_ for _ in ()).throw(StopAfterState())
                if point == "after_state"
                else None
            ),
        )
    contract.anchor_path.unlink()
    with pytest.raises(closure.ClosureError):
        invoke_fixture(contract, fake_auditor, task, utility_sha, helper_sha)
    assert task.exists is True
    assert task.enabled is False
    assert "Unregister" not in task.operations
