#!/usr/bin/env python3
"""Crash-recoverable, outcome-blind closure of the exact QM20002 G1 task."""

from __future__ import annotations

import argparse
import copy
import hashlib
import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import ModuleType
from typing import Any, Callable, Iterable, Mapping, Sequence


SCHEMA_VERSION = 1
ANALYSIS_ID = "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001"
RUN_ID = "20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5"
TASK_NAME = "QM_QM20002_AUDIT_d3fc294915f4ef4af1ed2795"
REASON_CODE = "SCHEDULER_TRIGGER_NULL_COLLECTION_CONTRACT_DEFECT"
FROZEN_COMMIT = "9f258f9fa2cc84746c34f76859888274ca60cf15"
PROCESS_PROBE_METHOD = (
    "NATIVE_PROCESS_HANDLE_TOKEN_SID_AND_IMAGE_PATH_"
    "STABLE_DOUBLE_SNAPSHOT_NO_COMMAND_LINE"
)

HEX64 = re.compile(r"[0-9a-f]{64}")
TERMINAL_PENDING_ERROR = re.compile(
    rf"^{REASON_CODE};"
    r"closure_phase=QUIESCE_PENDING;"
    r"closure_intent_sha256=(?P<intent>[0-9a-f]{64});"
    r"ready_task_xml_sha256=(?P<xml>[0-9a-f]{64});"
    r"task_contract_sha256=(?P<contract>[0-9a-f]{64})$"
)
TERMINAL_CLOSED_ERROR = re.compile(
    rf"^{REASON_CODE};"
    r"closure_phase=CLOSED;"
    r"closure_intent_sha256=(?P<intent>[0-9a-f]{64});"
    r"quiesced_evidence_sha256=(?P<quiesced>[0-9a-f]{64});"
    r"disabled_task_xml_sha256=(?P<xml>[0-9a-f]{64});"
    r"task_contract_sha256=(?P<contract>[0-9a-f]{64});"
    r"task_start_race_observed=(?P<start_race>true|false)$"
)

HISTORICAL_BINDING_KEYS = {
    "pre_receipt",
    "authorization",
    "authorization_consumption",
    "launch_job",
    "frozen_auditor",
    "frozen_scheduler",
    "frozen_control_helper",
    "runtime_freeze",
    "closure_utility",
    "closure_task_helper",
}
TASK_EVIDENCE_KEYS = {
    "state",
    "enabled",
    "last_run_utc",
    "last_task_result",
    "never_run",
    "non_null_trigger_count",
    "non_null_action_count",
    "task_xml_sha256",
    "task_contract_sha256",
    "matching_worker_process_count",
    "matching_worker_process_count_basis",
    "dev1_owner_process_count",
    "dev1_root_process_count",
    "relevant_process_identity_sha256",
    "stable_snapshot_count",
    "process_probe_method",
}
PROCESS_EVIDENCE_KEYS = {
    "matching_worker_process_count",
    "matching_worker_process_count_basis",
    "dev1_owner_process_count",
    "dev1_root_process_count",
    "relevant_process_identity_sha256",
    "stable_snapshot_count",
    "process_probe_method",
}


class ClosureError(RuntimeError):
    """The exact G1 pre-outcome closure contract was not provable."""


@dataclass(frozen=True)
class ClosureContract:
    repo_root: Path
    run_root: Path
    state_path: Path
    job_path: Path
    pre_path: Path
    authorization_path: Path
    consumption_path: Path
    intent_path: Path
    receipt_path: Path
    global_lock_path: Path
    state_lock_path: Path
    auditor_path: Path
    scheduler_path: Path
    control_helper_path: Path
    task_helper_path: Path
    freeze_path: Path
    powershell_path: Path
    state_before_sha256: str
    job_sha256: str
    pre_sha256: str
    authorization_sha256: str
    consumption_sha256: str
    auditor_sha256: str
    scheduler_sha256: str
    control_helper_sha256: str
    freeze_sha256: str
    freeze_commit: str
    task_name: str = TASK_NAME
    analysis_id: str = ANALYSIS_ID
    run_id: str = RUN_ID


def default_contract() -> ClosureContract:
    repo = Path(r"C:\QM\repo")
    ea = repo / "framework" / "EAs" / "QM5_20002_ict-icytea-core"
    tools = ea / "tools" / "candidate_analysis"
    run = Path(
        r"D:\QM\reports\qm20002\short_ny_reverse_time\runs"
    ) / "20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5"
    control = Path(r"D:\QM\reports\qm20002\short_ny_reverse_time")
    return ClosureContract(
        repo_root=repo,
        run_root=run,
        state_path=run / "launch_state.json",
        job_path=run / "launch_job.json",
        pre_path=control / "pre" / "pre_receipt.json",
        authorization_path=control / "authorization" / "authorization.json",
        consumption_path=(
            control
            / "authorization"
            / "consumptions"
            / "223d53e83a0d3b03f20af3b1b9c5730da365b414cad2f9f427f8b6e17ad46c6f.json"
        ),
        intent_path=run / "g1_pre_outcome_closure_intent.json",
        receipt_path=run / "g1_pre_outcome_closure_receipt.json",
        global_lock_path=control / "authorization" / ".launch.global.lock",
        state_lock_path=run / ".launch_state.json.terminal.lock",
        auditor_path=tools / "audit_short_ny_reverse_time.py",
        scheduler_path=tools / "run_outcome_fenced_task.ps1",
        control_helper_path=tools / "assert_qm20002_control_path.ps1",
        task_helper_path=tools / "close_qm20002_g1_task.ps1",
        freeze_path=(
            ea
            / "docs"
            / "candidate-analysis"
            / "short_ny_reverse_time_runtime_freeze_20260721.json"
        ),
        powershell_path=Path(r"C:\Program Files\PowerShell\7\pwsh.exe"),
        state_before_sha256="7aa51ce458420431db4cac94e500d3da07b82261312ba334cb80a7b420433ce7",
        job_sha256="ef4e247e2aefc6bd5e205df1b51296f40aac0c7401c1f64f9ab75fec69106f6b",
        pre_sha256="2ce641d3b0c0028eae3056958f09e8a28ee60d6f8ac6c621f0bde57f81161b94",
        authorization_sha256="223d53e83a0d3b03f20af3b1b9c5730da365b414cad2f9f427f8b6e17ad46c6f",
        consumption_sha256="c8f71626003e7a30635b0b054c80804e4343a414769ad888f892daabc098ad4a",
        auditor_sha256="4f9068c710a34d7f0bd72ad0c93a856d966ca58943ca84fa48f4addc686b0a2f",
        scheduler_sha256="a11e058453f362785a9c7f2d94b4194dd61de3dcadbeb0184884628e4dfe3bf2",
        control_helper_sha256="b3be96b0beb5b264390ba6087deacfd9fb3174537c2495d566e431d71089fc2f",
        freeze_sha256="3a1c86cc33db859d64ef4c611dbde6dd721372fd586ab375cfe45f9e0739a618",
        freeze_commit=FROZEN_COMMIT,
    )


def canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_binding(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    path = path.resolve()
    if not path.is_file():
        raise ClosureError(f"required file is absent: {path}")
    observed = sha256_file(path)
    if expected_sha256 is not None and observed != expected_sha256:
        raise ClosureError(f"SHA-256 drift for {path}")
    return {"path": str(path), "size": path.stat().st_size, "sha256": observed}


def load_strict_json(path: Path, label: str) -> dict[str, Any]:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate property {key}")
            result[key] = value
        return result

    try:
        value = json.loads(
            path.read_text(encoding="utf-8-sig"), object_pairs_hook=reject_duplicates
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise ClosureError(f"invalid {label}: {path}") from exc
    if not isinstance(value, dict):
        raise ClosureError(f"{label} root is not an object")
    return value


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def parse_owner_utc(value: str) -> datetime:
    if not value.endswith("Z"):
        raise ClosureError("OWNER authorization UTC must use a trailing Z")
    try:
        parsed = datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise ClosureError("OWNER authorization UTC is malformed") from exc
    if parsed > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise ClosureError("OWNER authorization UTC is implausibly in the future")
    return parsed


def _parse_single_json(text: str, label: str) -> dict[str, Any]:
    decoder = json.JSONDecoder(object_pairs_hook=lambda pairs: dict(pairs))
    stripped = text.strip()
    try:
        value, end = decoder.raw_decode(stripped)
    except json.JSONDecodeError as exc:
        raise ClosureError(f"{label} did not return one JSON object") from exc
    if stripped[end:].strip() or not isinstance(value, dict):
        raise ClosureError(f"{label} returned an ambiguous envelope")
    return value


def _control_call(contract: ClosureContract, operation: str, path: Path) -> dict[str, Any]:
    command = [
        str(contract.powershell_path),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(contract.control_helper_path),
        "-Operation",
        operation,
        "-Path",
        str(path.resolve()),
        "-ExpectedHelperSha256",
        contract.control_helper_sha256,
    ]
    completed = subprocess.run(
        command,
        cwd=contract.repo_root,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=60,
        check=False,
    )
    if completed.returncode != 0:
        raise ClosureError(f"control helper {operation} failed with exit {completed.returncode}")
    result = _parse_single_json(completed.stdout, f"control helper {operation}")
    if (
        result.get("status") != "PASS"
        or result.get("operation") != operation
        or Path(str(result.get("path", ""))).resolve() != path.resolve()
        or result.get("helper_sha256") != contract.control_helper_sha256
    ):
        raise ClosureError(f"control helper {operation} response drift")
    return result


def _task_call(
    contract: ClosureContract,
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    helper_sha256: str,
    operation: str,
    *,
    expected_task_contract_sha256: str | None = None,
    expected_disabled_xml_sha256: str | None = None,
    allow_observed_start_race: bool = False,
) -> dict[str, Any]:
    scheduler = job["scheduler"]
    command = [
        str(contract.powershell_path),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(contract.task_helper_path),
        "-Operation",
        operation,
        "-TaskName",
        contract.task_name,
        "-PythonExe",
        str(scheduler["python"]["path"]),
        "-ToolPath",
        str(job["tool"]["path"]),
        "-JobPath",
        str(contract.job_path),
        "-RepoRoot",
        str(contract.repo_root),
        "-ExecutionLimitSeconds",
        str(scheduler["execution_limit_seconds"]),
        "-ExpectedPrincipalSid",
        str(scheduler["principal_sid"]),
        "-ExpectedDev1Sid",
        str(pre["machine_credential_rotation"]["target_sid"]),
        "-ExpectedHelperSha256",
        helper_sha256,
    ]
    if expected_task_contract_sha256 is not None:
        command.extend(
            ["-ExpectedTaskContractSha256", expected_task_contract_sha256]
        )
    if expected_disabled_xml_sha256 is not None:
        command.extend(["-ExpectedDisabledXmlSha256", expected_disabled_xml_sha256])
    if allow_observed_start_race:
        command.append("-AllowObservedStartRace")
    completed = subprocess.run(
        command,
        cwd=contract.repo_root,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=60,
        check=False,
    )
    if completed.returncode != 0:
        raise ClosureError(f"task helper {operation} failed with exit {completed.returncode}")
    result = _parse_single_json(completed.stdout, f"task helper {operation}")
    if (
        result.get("operation") != operation
        or result.get("helper_sha256") != helper_sha256
    ):
        raise ClosureError(f"task helper {operation} response drift")
    if operation != "Identity" and (
        result.get("task_name") != contract.task_name
        or result.get("task_path") != "\\"
    ):
        raise ClosureError(f"task helper {operation} task identity drift")
    return result


@contextmanager
def _file_lock(path: Path, timeout_seconds: float = 30.0) -> Iterable[None]:
    if not path.is_file() or path.stat().st_size != 1:
        raise ClosureError(f"control lock is not an existing one-byte file: {path}")
    deadline = time.monotonic() + timeout_seconds
    with path.open("r+b") as handle:
        while True:
            try:
                handle.seek(0)
                if os.name == "nt":
                    import msvcrt

                    msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
                else:  # pragma: no cover
                    import fcntl

                    fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError as exc:
                if time.monotonic() >= deadline:
                    raise ClosureError(f"timed out acquiring control lock: {path}") from exc
                time.sleep(0.05)
        try:
            yield
        finally:
            handle.seek(0)
            if os.name == "nt":
                import msvcrt

                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
            else:  # pragma: no cover
                import fcntl

                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def _publish_json(
    contract: ClosureContract,
    path: Path,
    payload: Mapping[str, Any],
    *,
    replace: bool,
    control_call: Callable[[ClosureContract, str, Path], Mapping[str, Any]],
) -> str:
    if replace:
        control_call(contract, "AssertFile", path)
    else:
        control_call(contract, "AssertAbsentFile", path)
    encoded = canonical_bytes(payload)
    descriptor, temporary_text = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temporary = Path(temporary_text)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        control_call(contract, "SealFile", temporary)
        if replace:
            os.replace(temporary, path)
            temporary = Path()
        else:
            try:
                os.link(temporary, path)
            except FileExistsError as exc:
                raise ClosureError(f"refusing to replace immutable evidence: {path}") from exc
            temporary.unlink()
            temporary = Path()
    finally:
        if str(temporary) not in {"", "."}:
            try:
                temporary.unlink()
            except OSError:
                pass
    control_call(contract, "AssertFile", path)
    observed = sha256_file(path)
    expected = hashlib.sha256(encoded).hexdigest()
    if observed != expected:
        raise ClosureError(f"published JSON drifted after sealing: {path}")
    return observed


def _load_auditor(contract: ClosureContract) -> ModuleType:
    file_binding(contract.auditor_path, contract.auditor_sha256)
    module_name = "qm20002_frozen_g1_auditor"
    spec = importlib.util.spec_from_file_location(module_name, contract.auditor_path)
    if spec is None or spec.loader is None:
        raise ClosureError("could not load the frozen G1 auditor")
    module = importlib.util.module_from_spec(spec)
    sys.modules[module_name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(module_name, None)
        raise
    return module


def _git_assert_frozen_bytes(contract: ClosureContract) -> None:
    try:
        relative = contract.freeze_path.resolve().relative_to(contract.repo_root.resolve())
    except ValueError as exc:
        raise ClosureError("runtime freeze path escaped the repository") from exc
    completed = subprocess.run(
        ["git", "show", f"{contract.freeze_commit}:{relative.as_posix()}"],
        cwd=contract.repo_root,
        capture_output=True,
        timeout=30,
        check=False,
    )
    if completed.returncode != 0 or completed.stdout != contract.freeze_path.read_bytes():
        raise ClosureError("runtime freeze bytes differ from the exact committed freeze")


def _assert_exact_fields(value: Mapping[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        raise ClosureError(f"{label} exact fields drift")


def _validate_process_evidence(
    evidence: Mapping[str, Any], label: str, *, exact_fields: bool = False
) -> None:
    if exact_fields:
        _assert_exact_fields(evidence, PROCESS_EVIDENCE_KEYS, label)
    if (
        type(evidence.get("matching_worker_process_count")) is not int
        or evidence.get("matching_worker_process_count") != 0
        or not str(evidence.get("matching_worker_process_count_basis", "")).startswith(
            "INFERRED_FROM_"
        )
        or type(evidence.get("dev1_owner_process_count")) is not int
        or evidence.get("dev1_owner_process_count") != 0
        or type(evidence.get("dev1_root_process_count")) is not int
        or evidence.get("dev1_root_process_count") != 0
        or type(evidence.get("stable_snapshot_count")) is not int
        or evidence.get("stable_snapshot_count") != 2
        or evidence.get("process_probe_method") != PROCESS_PROBE_METHOD
        or not isinstance(evidence.get("relevant_process_identity_sha256"), str)
        or HEX64.fullmatch(str(evidence["relevant_process_identity_sha256"])) is None
    ):
        raise ClosureError(f"{label} process evidence is not exact and command-line-free")


def _validate_task_evidence(
    evidence: Mapping[str, Any],
    *,
    disabled: bool,
    label: str,
    require_never_run: bool = True,
    allow_running: bool = False,
) -> None:
    _assert_exact_fields(evidence, TASK_EVIDENCE_KEYS, label)
    expected_state = "Disabled" if disabled else "Ready"
    allowed_states = {expected_state, "Running"} if allow_running else {expected_state}
    if (
        evidence.get("state") not in allowed_states
        or evidence.get("enabled") is not (not disabled)
        or type(evidence.get("never_run")) is not bool
        or (require_never_run and evidence.get("never_run") is not True)
        or (require_never_run and evidence.get("last_run_utc") is not None)
        or (
            not require_never_run
            and evidence.get("last_run_utc") is not None
            and type(evidence.get("last_run_utc")) is not str
        )
        or type(evidence.get("last_task_result")) is not int
        or (
            require_never_run
            and evidence.get("last_task_result") not in {0, 267011}
        )
        or evidence.get("non_null_trigger_count") != 0
        or evidence.get("non_null_action_count") != 1
        or HEX64.fullmatch(str(evidence.get("task_xml_sha256", ""))) is None
        or HEX64.fullmatch(str(evidence.get("task_contract_sha256", ""))) is None
    ):
        raise ClosureError(f"{label} scheduled-task evidence drift")
    if evidence.get("last_run_utc") is not None:
        try:
            datetime.fromisoformat(str(evidence["last_run_utc"]).replace("Z", "+00:00"))
        except ValueError as exc:
            raise ClosureError(f"{label} last-run timestamp is malformed") from exc
    _validate_process_evidence(evidence, label)


def _validate_task_probe(
    probe: Mapping[str, Any],
    contract: ClosureContract,
    *,
    disabled: bool,
    label: str,
    expected_helper_sha256: str,
    expected_principal_sid: str,
    require_never_run: bool = True,
) -> Mapping[str, Any]:
    expected_operation = "InspectQuiesced" if disabled else "InspectReady"
    _assert_exact_fields(
        probe,
        {
            "operation",
            "helper_sha256",
            "task_name",
            "task_path",
            "principal_sid",
            "evidence",
            "absent",
        },
        label,
    )
    if (
        probe.get("operation") != expected_operation
        or probe.get("helper_sha256") != expected_helper_sha256
        or probe.get("task_name") != contract.task_name
        or probe.get("task_path") != "\\"
        or probe.get("principal_sid") != expected_principal_sid
        or probe.get("absent") is not False
        or not isinstance(probe.get("evidence"), Mapping)
    ):
        raise ClosureError(f"{label} task probe envelope drift")
    evidence = probe["evidence"]
    _validate_task_evidence(
        evidence,
        disabled=disabled,
        label=label,
        require_never_run=require_never_run,
    )
    return evidence


def _validate_quiesce_probe(
    probe: Mapping[str, Any],
    contract: ClosureContract,
    *,
    expected_helper_sha256: str,
    expected_principal_sid: str,
) -> tuple[Mapping[str, Any], bool]:
    _assert_exact_fields(
        probe,
        {
            "operation",
            "helper_sha256",
            "task_name",
            "task_path",
            "principal_sid",
            "before",
            "after",
            "start_race_observed",
            "absent",
        },
        "quiesce probe",
    )
    if (
        probe.get("operation") != "Quiesce"
        or probe.get("helper_sha256") != expected_helper_sha256
        or probe.get("task_name") != contract.task_name
        or probe.get("task_path") != "\\"
        or probe.get("principal_sid") != expected_principal_sid
        or probe.get("absent") is not False
        or type(probe.get("start_race_observed")) is not bool
        or not isinstance(probe.get("before"), Mapping)
        or not isinstance(probe.get("after"), Mapping)
    ):
        raise ClosureError("quiesce probe envelope drift")
    _validate_task_evidence(
        probe["before"],
        disabled=False,
        label="quiesce before",
        require_never_run=False,
        allow_running=True,
    )
    _validate_task_evidence(
        probe["after"],
        disabled=True,
        label="quiesce after",
        require_never_run=False,
        allow_running=True,
    )
    observed_race = (
        probe["before"].get("state") == "Running"
        or probe["before"].get("never_run") is not True
        or probe["after"].get("state") == "Running"
        or probe["after"].get("never_run") is not True
    )
    if probe["start_race_observed"] is not observed_race:
        raise ClosureError("quiesce start-race classification drift")
    return probe["after"], observed_race


def _validate_await_quiesced_probe(
    probe: Mapping[str, Any],
    contract: ClosureContract,
    *,
    expected_helper_sha256: str,
    expected_principal_sid: str,
) -> tuple[Mapping[str, Any], bool]:
    _assert_exact_fields(
        probe,
        {
            "operation",
            "helper_sha256",
            "task_name",
            "task_path",
            "principal_sid",
            "evidence",
            "start_race_observed",
            "absent",
        },
        "await-quiesced probe",
    )
    if (
        probe.get("operation") != "AwaitQuiesced"
        or probe.get("helper_sha256") != expected_helper_sha256
        or probe.get("task_name") != contract.task_name
        or probe.get("task_path") != "\\"
        or probe.get("principal_sid") != expected_principal_sid
        or probe.get("absent") is not False
        or type(probe.get("start_race_observed")) is not bool
        or not isinstance(probe.get("evidence"), Mapping)
    ):
        raise ClosureError("await-quiesced probe envelope drift")
    evidence = probe["evidence"]
    _validate_task_evidence(
        evidence,
        disabled=True,
        label="await-quiesced evidence",
        require_never_run=False,
    )
    observed_race = evidence.get("never_run") is not True
    if probe["start_race_observed"] is not observed_race:
        raise ClosureError("await-quiesced start-race classification drift")
    return evidence, observed_race


def _validate_absent_probe(
    probe: Mapping[str, Any], contract: ClosureContract, *, expected_helper_sha256: str
) -> None:
    _assert_exact_fields(
        probe,
        {
            "operation",
            "helper_sha256",
            "task_name",
            "task_path",
            "absent",
            *PROCESS_EVIDENCE_KEYS,
        },
        "task absence proof",
    )
    if (
        probe.get("operation") != "ProbeAbsent"
        or probe.get("helper_sha256") != expected_helper_sha256
        or probe.get("task_name") != contract.task_name
        or probe.get("task_path") != "\\"
        or probe.get("absent") is not True
    ):
        raise ClosureError("task absence proof envelope drift")
    _validate_process_evidence(probe, "task absence proof")


def _assert_initial_state(
    contract: ClosureContract,
    state: Mapping[str, Any],
    job_binding: Mapping[str, Any],
    authorization: Mapping[str, Any],
) -> None:
    if (
        state.get("status") != "PENDING"
        or state.get("resume_count") != 0
        or state.get("worker_pid") is not None
        or state.get("started_utc") is not None
        or state.get("finished_utc") is not None
        or state.get("active_cell") is not None
        or state.get("outcome_possible_since_utc") is not None
        or state.get("cells") != []
        or state.get("terminal") is not None
        or state.get("job") != job_binding
        or state.get("authorization") != authorization
        or state.get("pre_receipt_path") != str(contract.pre_path.resolve())
        or state.get("pre_receipt_sha256") != contract.pre_sha256
    ):
        raise ClosureError("G1 state is not the exact untouched PENDING resume_count=0 state")
    _assert_no_outcome_side_effects(contract)


def _assert_no_outcome_side_effects(contract: ClosureContract) -> None:
    """Prove absence by path metadata only; never enumerate or open outcome data."""

    if (contract.run_root / "worker").exists():
        raise ClosureError("G1 worker tree exists; outcome-blind closure is forbidden")
    if (contract.run_root / "post_receipt.json").exists():
        raise ClosureError("G1 POST receipt exists; pre-outcome closure is forbidden")


def _terminal_proof(state: Mapping[str, Any], intent_sha256: str) -> dict[str, str]:
    terminal = state.get("terminal")
    if not isinstance(terminal, Mapping):
        raise ClosureError("closed G1 state omitted terminal proof")
    _assert_exact_fields(
        terminal,
        {
            "status",
            "error_type",
            "error",
            "failure_stage",
            "affected_cell_id",
            "outcome_fence_crossed",
            "no_resume",
            "controller_failure_class",
        },
        "G1 terminal proof",
    )
    pending_match = TERMINAL_PENDING_ERROR.fullmatch(str(terminal.get("error", "")))
    closed_match = TERMINAL_CLOSED_ERROR.fullmatch(str(terminal.get("error", "")))
    match = closed_match or pending_match
    if (
        state.get("status") != "REJECT"
        or state.get("worker_pid") is not None
        or state.get("active_cell") is not None
        or state.get("outcome_possible_since_utc") is not None
        or state.get("cells") != []
        or terminal.get("status") != "REJECT"
        or terminal.get("error_type") != "G1PreOutcomeClosure"
        or terminal.get("failure_stage") != "WORKER_VALIDATION"
        or terminal.get("affected_cell_id") is not None
        or terminal.get("outcome_fence_crossed") is not False
        or terminal.get("no_resume") is not True
        or terminal.get("controller_failure_class") is not None
        or match is None
        or match.group("intent") != intent_sha256
    ):
        raise ClosureError("terminal G1 REJECT does not bind the exact pre-outcome intent")
    proof = match.groupdict()
    proof["phase"] = "CLOSED" if closed_match is not None else "QUIESCE_PENDING"
    return proof


def _terminal_payload(error: str) -> dict[str, Any]:
    return {
        "status": "REJECT",
        "error_type": "G1PreOutcomeClosure",
        "error": error,
        "failure_stage": "WORKER_VALIDATION",
        "affected_cell_id": None,
        "outcome_fence_crossed": False,
        "no_resume": True,
        "controller_failure_class": None,
    }


def _preliminary_closed_state(
    state: Mapping[str, Any], intent_sha256: str, intent: Mapping[str, Any]
) -> dict[str, Any]:
    finished = utc_now()
    terminal_error = (
        f"{REASON_CODE};closure_phase=QUIESCE_PENDING;"
        f"closure_intent_sha256={intent_sha256};"
        f"ready_task_xml_sha256={intent['task']['ready_task_xml_sha256']};"
        f"task_contract_sha256={intent['task']['task_contract_sha256']}"
    )
    closed = copy.deepcopy(dict(state))
    closed.update(
        {
            "status": "REJECT",
            "updated_utc": finished,
            "finished_utc": finished,
            "worker_pid": None,
            "active_cell": None,
            "outcome_possible_since_utc": None,
            "cells": [],
            "terminal": _terminal_payload(terminal_error),
        }
    )
    return closed


def _final_closed_state(
    state: Mapping[str, Any],
    intent_sha256: str,
    quiesced_evidence: Mapping[str, Any],
    *,
    start_race_observed: bool,
) -> dict[str, Any]:
    task_contract = str(quiesced_evidence["task_contract_sha256"])
    disabled_xml = str(quiesced_evidence["task_xml_sha256"])
    quiesced_sha = canonical_sha256(quiesced_evidence)
    terminal_error = (
        f"{REASON_CODE};closure_phase=CLOSED;"
        f"closure_intent_sha256={intent_sha256};"
        f"quiesced_evidence_sha256={quiesced_sha};"
        f"disabled_task_xml_sha256={disabled_xml};"
        f"task_contract_sha256={task_contract};"
        f"task_start_race_observed={'true' if start_race_observed else 'false'}"
    )
    closed = copy.deepcopy(dict(state))
    closed.update(
        {
            "status": "REJECT",
            "updated_utc": utc_now(),
            "worker_pid": None,
            "active_cell": None,
            "outcome_possible_since_utc": None,
            "cells": [],
            "terminal": _terminal_payload(terminal_error),
        }
    )
    return closed


def _validate_closed_state_historical_chain(
    contract: ClosureContract,
    state: Mapping[str, Any],
    intent: Mapping[str, Any],
    intent_sha256: str,
    chain: Mapping[str, Any],
    auditor: ModuleType,
    *,
    require_final: bool,
) -> dict[str, str]:
    auditor._validate_launch_state_shape(state)
    original = intent.get("state_before_payload")
    if not isinstance(original, Mapping):
        raise ClosureError("closure intent omitted original state payload")
    immutable_fields = set(original) - {"status", "updated_utc", "finished_utc", "terminal"}
    if set(state) != set(original):
        raise ClosureError("closed state exact fields drifted from original state")
    for field in sorted(immutable_fields):
        if state.get(field) != original.get(field):
            raise ClosureError(f"closed state immutable field drift: {field}")
    if (
        state.get("job") != chain["bindings"]["launch_job"]
        or state.get("authorization") != chain["authorization"]
        or state.get("scheduler") != chain["job"]["scheduler"]
        or state.get("pre_receipt_path") != str(contract.pre_path.resolve())
        or state.get("pre_receipt_sha256") != contract.pre_sha256
        or state.get("resume_count") != 0
        or state.get("started_utc") is not None
    ):
        raise ClosureError("closed state historical launch chain drift")
    original_updated = _parse_created_utc(
        original.get("updated_utc"), "original state updated_utc"
    )
    closed_updated = _parse_created_utc(
        state.get("updated_utc"), "closed state updated_utc"
    )
    closed_finished = _parse_created_utc(
        state.get("finished_utc"), "closed state finished_utc"
    )
    if not original_updated <= closed_finished <= closed_updated:
        raise ClosureError("closed state chronology drift")
    proof = _terminal_proof(state, intent_sha256)
    if require_final and proof["phase"] != "CLOSED":
        raise ClosureError("G1 closure remains in QUIESCE_PENDING phase")
    return proof


def _historical_chain(
    contract: ClosureContract,
    auditor: ModuleType,
    utility_sha256: str,
    task_helper_sha256: str,
    *,
    git_assert: Callable[[ClosureContract], None],
) -> dict[str, Any]:
    bindings = {
        "pre_receipt": file_binding(contract.pre_path, contract.pre_sha256),
        "authorization": file_binding(
            contract.authorization_path, contract.authorization_sha256
        ),
        "authorization_consumption": file_binding(
            contract.consumption_path, contract.consumption_sha256
        ),
        "launch_job": file_binding(contract.job_path, contract.job_sha256),
        "frozen_auditor": file_binding(contract.auditor_path, contract.auditor_sha256),
        "frozen_scheduler": file_binding(contract.scheduler_path, contract.scheduler_sha256),
        "frozen_control_helper": file_binding(
            contract.control_helper_path, contract.control_helper_sha256
        ),
        "runtime_freeze": file_binding(contract.freeze_path, contract.freeze_sha256),
        "closure_utility": file_binding(Path(__file__), utility_sha256),
        "closure_task_helper": file_binding(
            contract.task_helper_path, task_helper_sha256
        ),
    }
    git_assert(contract)
    pre = auditor.assert_pre_receipt(contract.pre_path, contract.pre_sha256)
    authorization = auditor.validate_authorization(
        contract.authorization_path, contract.pre_sha256, pre
    )
    job = load_strict_json(contract.job_path, "launch job")
    auditor._validate_launch_job(
        job, pre, contract.pre_path, contract.pre_sha256, contract.state_path
    )
    if job.get("authorization") != authorization:
        raise ClosureError("launch job authorization envelope drift")
    auditor._assert_authorization_consumption(
        job.get("authorization_consumption"),
        authorization,
        contract.pre_path,
        contract.pre_sha256,
        contract.state_path,
        contract.job_path,
        contract.task_name,
        contract.control_helper_sha256,
    )
    if job.get("authorization_consumption", {}).get("binding") != bindings[
        "authorization_consumption"
    ]:
        raise ClosureError("launch job consumption binding drift")
    if job.get("tool") != bindings["frozen_auditor"]:
        raise ClosureError("launch job frozen auditor binding drift")
    if job.get("scheduler", {}).get("helper") != bindings["frozen_scheduler"]:
        raise ClosureError("launch job frozen scheduler binding drift")
    if pre.get("runtime", {}).get("audit_control_path_helper") != bindings[
        "frozen_control_helper"
    ]:
        raise ClosureError("PRE frozen control helper binding drift")
    chain = {
        "bindings": bindings,
        "pre": pre,
        "authorization": authorization,
        "job": job,
        "runtime_freeze_commit": contract.freeze_commit,
    }
    _assert_dev1_inventory(chain, auditor)
    return chain


def _assert_dev1_inventory(chain: Mapping[str, Any], auditor: ModuleType) -> None:
    expected = chain.get("job", {}).get("dev1_runs_before_launch")
    if not isinstance(expected, Mapping):
        raise ClosureError("launch job omitted the pre-launch DEV1 run inventory")
    observed = auditor._dev1_run_inventory()
    if observed != expected:
        raise ClosureError("DEV1 run inventory changed from the exact pre-launch binding")


def _intent_payload(
    contract: ClosureContract,
    chain: Mapping[str, Any],
    state_before: Mapping[str, Any],
    state_before_binding: Mapping[str, Any],
    ready_probe: Mapping[str, Any],
    authorized_utc: str,
) -> dict[str, Any]:
    helper_sha256 = str(chain["bindings"]["closure_task_helper"]["sha256"])
    principal_sid = str(chain["job"]["scheduler"]["principal_sid"])
    ready_evidence = _validate_task_probe(
        ready_probe,
        contract,
        disabled=False,
        label="ready intent",
        expected_helper_sha256=helper_sha256,
        expected_principal_sid=principal_sid,
    )
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_G1_PRE_OUTCOME_CLOSURE_INTENT",
        "analysis_id": contract.analysis_id,
        "run_id": contract.run_id,
        "reason_code": REASON_CODE,
        "authorized_by": "OWNER",
        "authorized_utc": authorized_utc,
        "created_utc": utc_now(),
        "runtime_freeze_commit": chain["runtime_freeze_commit"],
        "bindings": chain["bindings"],
        "state_before": dict(state_before_binding),
        "state_before_payload": copy.deepcopy(dict(state_before)),
        "task": {
            "task_name": contract.task_name,
            "task_path": "\\",
            "ready_probe": copy.deepcopy(dict(ready_probe)),
            "ready_probe_sha256": canonical_sha256(ready_probe),
            "ready_task_xml_sha256": ready_evidence["task_xml_sha256"],
            "task_contract_sha256": ready_evidence["task_contract_sha256"],
            "actual_trigger_count": 0,
            "never_run": True,
        },
        "expected_transition": _expected_transition(),
        "outcome_data_read": False,
    }


def _expected_transition() -> dict[str, Any]:
    return {
        "state_status_before": "PENDING",
        "state_resume_count_before": 0,
        "state_status_after": "REJECT",
        "outcome_fence_crossed": False,
        "no_resume": True,
        "worker_tree_expected_absent": True,
        "task_transition": "READY_TO_DISABLED_TO_ABSENT",
        "terminal_reject_published_before_task_disable": True,
    }


def _parse_created_utc(value: Any, label: str) -> datetime:
    if type(value) is not str or not value.endswith("+00:00"):
        raise ClosureError(f"{label} must be an exact UTC +00:00 string")
    try:
        parsed = datetime.fromisoformat(value)
    except ValueError as exc:
        raise ClosureError(f"{label} is malformed") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timedelta(0):
        raise ClosureError(f"{label} is not UTC")
    return parsed.astimezone(timezone.utc)


def _validate_binding_object(
    value: Any, expected: Mapping[str, Any], label: str
) -> None:
    if not isinstance(value, Mapping):
        raise ClosureError(f"{label} is not a binding object")
    _assert_exact_fields(value, {"path", "size", "sha256"}, label)
    if (
        type(value.get("path")) is not str
        or type(value.get("size")) is not int
        or value.get("size", -1) < 0
        or type(value.get("sha256")) is not str
        or HEX64.fullmatch(str(value.get("sha256", ""))) is None
        or dict(value) != dict(expected)
    ):
        raise ClosureError(f"{label} exact value drift")


def _validate_intent(
    contract: ClosureContract,
    intent: Mapping[str, Any],
    chain: Mapping[str, Any],
    authorized_utc: str,
    auditor: ModuleType,
) -> None:
    _assert_exact_fields(
        intent,
        {
            "schema_version",
            "artifact_type",
            "analysis_id",
            "run_id",
            "reason_code",
            "authorized_by",
            "authorized_utc",
            "created_utc",
            "runtime_freeze_commit",
            "bindings",
            "state_before",
            "state_before_payload",
            "task",
            "expected_transition",
            "outcome_data_read",
        },
        "closure intent",
    )
    if (
        intent.get("schema_version") != SCHEMA_VERSION
        or intent.get("artifact_type")
        != "QM5_20002_G1_PRE_OUTCOME_CLOSURE_INTENT"
        or intent.get("analysis_id") != contract.analysis_id
        or intent.get("run_id") != contract.run_id
        or intent.get("reason_code") != REASON_CODE
        or intent.get("authorized_by") != "OWNER"
        or intent.get("authorized_utc") != authorized_utc
        or intent.get("runtime_freeze_commit") != contract.freeze_commit
        or intent.get("bindings") != chain["bindings"]
        or intent.get("outcome_data_read") is not False
    ):
        raise ClosureError("existing closure intent identity/bindings drift")
    authorized = parse_owner_utc(str(intent.get("authorized_utc", "")))
    created = _parse_created_utc(intent.get("created_utc"), "closure intent created_utc")
    if created < authorized or created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise ClosureError("closure intent chronology drift")
    bindings = intent.get("bindings")
    if not isinstance(bindings, Mapping):
        raise ClosureError("closure intent bindings are not an object")
    _assert_exact_fields(bindings, HISTORICAL_BINDING_KEYS, "closure intent bindings")
    for key in sorted(HISTORICAL_BINDING_KEYS):
        _validate_binding_object(
            bindings.get(key), chain["bindings"][key], f"closure intent {key}"
        )
    task = intent.get("task")
    if not isinstance(task, Mapping) or not isinstance(task.get("ready_probe"), Mapping):
        raise ClosureError("closure intent ready proof is absent")
    _assert_exact_fields(
        task,
        {
            "task_name",
            "task_path",
            "ready_probe",
            "ready_probe_sha256",
            "ready_task_xml_sha256",
            "task_contract_sha256",
            "actual_trigger_count",
            "never_run",
        },
        "closure intent task",
    )
    helper_sha256 = str(chain["bindings"]["closure_task_helper"]["sha256"])
    principal_sid = str(chain["job"]["scheduler"]["principal_sid"])
    evidence = _validate_task_probe(
        task["ready_probe"],
        contract,
        disabled=False,
        label="persisted ready intent",
        expected_helper_sha256=helper_sha256,
        expected_principal_sid=principal_sid,
    )
    if (
        task.get("task_name") != contract.task_name
        or task.get("task_path") != "\\"
        or task.get("ready_probe_sha256") != canonical_sha256(task["ready_probe"])
        or task.get("ready_task_xml_sha256") != evidence["task_xml_sha256"]
        or task.get("task_contract_sha256") != evidence["task_contract_sha256"]
        or task.get("actual_trigger_count") != 0
        or task.get("never_run") is not True
    ):
        raise ClosureError("closure intent task proof binding drift")
    state_before = intent.get("state_before")
    state_before_payload = intent.get("state_before_payload")
    if (
        not isinstance(state_before, Mapping)
        or not isinstance(state_before_payload, Mapping)
        or state_before.get("path") != str(contract.state_path.resolve())
        or state_before.get("sha256") != contract.state_before_sha256
        or type(state_before.get("size")) is not int
        or state_before.get("size") != len(canonical_bytes(state_before_payload))
        or hashlib.sha256(canonical_bytes(state_before_payload)).hexdigest()
        != contract.state_before_sha256
    ):
        raise ClosureError("closure intent state-before binding drift")
    _assert_exact_fields(state_before, {"path", "size", "sha256"}, "intent state_before")
    auditor._validate_launch_state_shape(state_before_payload)
    _assert_initial_state(
        contract,
        state_before_payload,
        chain["bindings"]["launch_job"],
        chain["authorization"],
    )
    if intent.get("expected_transition") != _expected_transition():
        raise ClosureError("closure intent expected transition drift")


def _receipt_payload(
    contract: ClosureContract,
    chain: Mapping[str, Any],
    intent_binding: Mapping[str, Any],
    intent: Mapping[str, Any],
    state_after_binding: Mapping[str, Any],
    terminal_proof: Mapping[str, str],
    absent_probe: Mapping[str, Any],
    *,
    created_utc: str | None = None,
) -> dict[str, Any]:
    if terminal_proof.get("phase") != "CLOSED":
        raise ClosureError("cannot receipt a QUIESCE_PENDING terminal state")
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_G1_PRE_OUTCOME_CLOSURE_RECEIPT",
        "analysis_id": contract.analysis_id,
        "run_id": contract.run_id,
        "status": "REJECT_CLOSED_PRE_OUTCOME",
        "reason_code": REASON_CODE,
        "created_utc": created_utc or utc_now(),
        "closure_intent": {
            "binding": dict(intent_binding),
            "authorized_by": intent["authorized_by"],
            "authorized_utc": intent["authorized_utc"],
        },
        "historical_bindings": chain["bindings"],
        "runtime_freeze_commit": chain["runtime_freeze_commit"],
        "launch_state": {
            "before": intent["state_before"],
            "after": dict(state_after_binding),
            "status_before": "PENDING",
            "resume_count_before": 0,
            "status_after": "REJECT",
            "outcome_fence_crossed": False,
                "no_resume": True,
                "terminal_error_binds_intent": True,
                "task_start_race_observed": terminal_proof["start_race"] == "true",
        },
        "scheduled_task": {
            "task_name": contract.task_name,
            "task_path": "\\",
            "ready_probe_binding": {
                "sha256": intent["task"]["ready_probe_sha256"],
                "task_xml_sha256": intent["task"]["ready_task_xml_sha256"],
                "task_contract_sha256": intent["task"]["task_contract_sha256"],
                "actual_trigger_count": 0,
                "never_run": True,
            },
            "quiesced_probe_binding": {
                "sha256": terminal_proof["quiesced"],
                "task_xml_sha256": terminal_proof["xml"],
                "task_contract_sha256": terminal_proof["contract"],
                "state": "Disabled",
                "never_run": True,
                "retention": "CANONICAL_EVIDENCE_SHA256_BOUND_IN_TERMINAL_ERROR",
                "task_start_race_observed": terminal_proof["start_race"] == "true",
            },
            "absent_probe": copy.deepcopy(dict(absent_probe)),
            "absent_probe_sha256": canonical_sha256(absent_probe),
            "unregistered_after_global_and_state_lock_release": True,
        },
        "outcome_data_read": False,
    }


def _validate_receipt(
    contract: ClosureContract,
    receipt: Mapping[str, Any],
    chain: Mapping[str, Any],
    intent_binding: Mapping[str, Any],
    intent: Mapping[str, Any],
    state_after_binding: Mapping[str, Any],
    terminal_proof: Mapping[str, str],
) -> None:
    _assert_exact_fields(
        receipt,
        {
            "schema_version",
            "artifact_type",
            "analysis_id",
            "run_id",
            "status",
            "reason_code",
            "created_utc",
            "closure_intent",
            "historical_bindings",
            "runtime_freeze_commit",
            "launch_state",
            "scheduled_task",
            "outcome_data_read",
        },
        "closure receipt",
    )
    scheduled_task = receipt.get("scheduled_task")
    if not isinstance(scheduled_task, Mapping):
        raise ClosureError("closure receipt scheduled_task is not an object")
    absent = scheduled_task.get("absent_probe")
    if not isinstance(absent, Mapping):
        raise ClosureError("closure receipt omitted task absence proof")
    helper_sha256 = str(chain["bindings"]["closure_task_helper"]["sha256"])
    _validate_absent_probe(
        absent, contract, expected_helper_sha256=helper_sha256
    )
    created = _parse_created_utc(receipt.get("created_utc"), "closure receipt created_utc")
    state_updated = _parse_created_utc(
        load_strict_json(contract.state_path, "receipt-bound state").get("updated_utc"),
        "receipt-bound state updated_utc",
    )
    if created < state_updated or created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise ClosureError("closure receipt chronology drift")
    expected = _receipt_payload(
        contract,
        chain,
        intent_binding,
        intent,
        state_after_binding,
        terminal_proof,
        absent,
        created_utc=str(receipt["created_utc"]),
    )
    if canonical_bytes(receipt) != canonical_bytes(expected):
        raise ClosureError("existing immutable closure receipt recursive value drift")


def close_g1(
    contract: ClosureContract,
    *,
    authorized_utc: str,
    expected_utility_sha256: str,
    expected_task_helper_sha256: str,
    auditor: ModuleType | None = None,
    task_call: Callable[..., Mapping[str, Any]] = _task_call,
    control_call: Callable[[ClosureContract, str, Path], Mapping[str, Any]] = _control_call,
    git_assert: Callable[[ClosureContract], None] = _git_assert_frozen_bytes,
    crash_hook: Callable[[str], None] = lambda _point: None,
) -> dict[str, Any]:
    """Close G1 exactly once; safely resume at every durable crash boundary."""

    owner_authorized = parse_owner_utc(authorized_utc)
    if HEX64.fullmatch(expected_utility_sha256) is None or HEX64.fullmatch(
        expected_task_helper_sha256
    ) is None:
        raise ClosureError("closure utility/helper expected SHA-256 is malformed")
    if auditor is None:
        auditor = _load_auditor(contract)
    chain = _historical_chain(
        contract,
        auditor,
        expected_utility_sha256,
        expected_task_helper_sha256,
        git_assert=git_assert,
    )
    helper_sha = expected_task_helper_sha256
    job = chain["job"]
    pre = chain["pre"]
    principal_sid = str(job["scheduler"]["principal_sid"])
    control_call(contract, "AssertFile", contract.global_lock_path)
    control_call(contract, "AssertFile", contract.state_lock_path)

    # Phase 1: bind OWNER intent, then publish a terminal no-resume REJECT
    # before disabling the task.  A racing task instance blocks on this same
    # state lock and can only observe REJECT after release.
    with _file_lock(contract.global_lock_path):
        with _file_lock(contract.state_lock_path):
            _assert_dev1_inventory(chain, auditor)
            state_binding = file_binding(contract.state_path)
            state = load_strict_json(contract.state_path, "launch state")
            auditor._validate_launch_state_shape(state)
            _assert_no_outcome_side_effects(contract)
            job_binding = chain["bindings"]["launch_job"]
            is_initial = state_binding["sha256"] == contract.state_before_sha256

            if contract.intent_path.exists():
                control_call(contract, "AssertFile", contract.intent_path)
                intent = load_strict_json(contract.intent_path, "closure intent")
                _validate_intent(
                    contract, intent, chain, authorized_utc, auditor
                )
                intent_binding = file_binding(contract.intent_path)
            else:
                if not is_initial:
                    raise ClosureError("closure intent is absent after launch-state mutation")
                if owner_authorized < datetime.now(timezone.utc) - timedelta(minutes=15):
                    raise ClosureError("new OWNER closure intent is older than 15 minutes")
                _assert_initial_state(
                    contract, state, job_binding, chain["authorization"]
                )
                ready_probe = task_call(
                    contract, job, pre, helper_sha, "InspectReady"
                )
                _validate_task_probe(
                    ready_probe,
                    contract,
                    disabled=False,
                    label="initial ready task",
                    expected_helper_sha256=helper_sha,
                    expected_principal_sid=principal_sid,
                )
                intent = _intent_payload(
                    contract,
                    chain,
                    state,
                    state_binding,
                    ready_probe,
                    authorized_utc,
                )
                _publish_json(
                    contract,
                    contract.intent_path,
                    intent,
                    replace=False,
                    control_call=control_call,
                )
                intent_binding = file_binding(contract.intent_path)
                crash_hook("after_intent")

            intent_sha = str(intent_binding["sha256"])
            if is_initial:
                _assert_initial_state(
                    contract, state, job_binding, chain["authorization"]
                )
                task_contract_sha = str(intent["task"]["task_contract_sha256"])
                ready_now = task_call(
                    contract, job, pre, helper_sha, "InspectReady"
                )
                ready_evidence = _validate_task_probe(
                    ready_now,
                    contract,
                    disabled=False,
                    label="pre-terminal ready task",
                    expected_helper_sha256=helper_sha,
                    expected_principal_sid=principal_sid,
                )
                if ready_evidence["task_contract_sha256"] != task_contract_sha:
                    raise ClosureError("ready task contract drifted from closure intent")
                closed = _preliminary_closed_state(state, intent_sha, intent)
                auditor._validate_launch_state_shape(closed)
                if sha256_file(contract.state_path) != contract.state_before_sha256:
                    raise ClosureError("launch-state CAS lost before terminal publication")
                _publish_json(
                    contract,
                    contract.state_path,
                    closed,
                    replace=True,
                    control_call=control_call,
                )
                state = closed
                crash_hook("after_preliminary_state")
            proof = _validate_closed_state_historical_chain(
                contract,
                state,
                intent,
                intent_sha,
                chain,
                auditor,
                require_final=False,
            )
            if proof["phase"] == "QUIESCE_PENDING":
                task_contract_sha = str(intent["task"]["task_contract_sha256"])
                try:
                    ready_now = task_call(
                        contract, job, pre, helper_sha, "InspectReady"
                    )
                    ready_evidence = _validate_task_probe(
                        ready_now,
                        contract,
                        disabled=False,
                        label="pre-disable ready task",
                        expected_helper_sha256=helper_sha,
                        expected_principal_sid=principal_sid,
                    )
                    if ready_evidence["task_contract_sha256"] != task_contract_sha:
                        raise ClosureError("ready task contract drifted before disable")
                except ClosureError:
                    # The exact task may have entered Running after the
                    # preliminary REJECT.  Quiesce still must disable it.
                    pass
                try:
                    quiesce = task_call(
                        contract,
                        job,
                        pre,
                        helper_sha,
                        "Quiesce",
                        expected_task_contract_sha256=task_contract_sha,
                    )
                    quiesced_under_lock, _race = _validate_quiesce_probe(
                        quiesce,
                        contract,
                        expected_helper_sha256=helper_sha,
                        expected_principal_sid=principal_sid,
                    )
                    if quiesced_under_lock["task_contract_sha256"] != task_contract_sha:
                        raise ClosureError("disabled task contract drifted under lock")
                except ClosureError:
                    # Recovery may find the task already disabled, or a racing
                    # exact instance may still be draining against REJECT.
                    # AwaitQuiesced below is the mandatory conclusive proof.
                    pass
                crash_hook("after_quiesce")
            _assert_dev1_inventory(chain, auditor)

    # Phase 2: after releasing both locks, wait for an exact disabled and
    # non-running task.  If an exact task instance raced, it can now drain but
    # cannot pass the already-durable terminal REJECT.
    if proof["phase"] == "QUIESCE_PENDING":
        awaited = task_call(
            contract,
            job,
            pre,
            helper_sha,
            "AwaitQuiesced",
            expected_task_contract_sha256=proof["contract"],
            allow_observed_start_race=True,
        )
        quiesced_evidence, start_race_observed = _validate_await_quiesced_probe(
            awaited,
            contract,
            expected_helper_sha256=helper_sha,
            expected_principal_sid=principal_sid,
        )
        if quiesced_evidence["task_contract_sha256"] != proof["contract"]:
            raise ClosureError("awaited task contract drifted from terminal REJECT")
        _assert_dev1_inventory(chain, auditor)
        with _file_lock(contract.global_lock_path):
            with _file_lock(contract.state_lock_path):
                _assert_dev1_inventory(chain, auditor)
                control_call(contract, "AssertFile", contract.intent_path)
                intent_binding = file_binding(contract.intent_path)
                intent = load_strict_json(contract.intent_path, "closure intent")
                _validate_intent(
                    contract, intent, chain, authorized_utc, auditor
                )
                state = load_strict_json(contract.state_path, "quiesce-pending state")
                current_proof = _validate_closed_state_historical_chain(
                    contract,
                    state,
                    intent,
                    str(intent_binding["sha256"]),
                    chain,
                    auditor,
                    require_final=False,
                )
                if current_proof["phase"] == "QUIESCE_PENDING":
                    before_sha = sha256_file(contract.state_path)
                    final_state = _final_closed_state(
                        state,
                        str(intent_binding["sha256"]),
                        quiesced_evidence,
                        start_race_observed=start_race_observed,
                    )
                    auditor._validate_launch_state_shape(final_state)
                    if sha256_file(contract.state_path) != before_sha:
                        raise ClosureError("launch-state finalization CAS lost")
                    _publish_json(
                        contract,
                        contract.state_path,
                        final_state,
                        replace=True,
                        control_call=control_call,
                    )
                    state = final_state
                    crash_hook("after_state")
                proof = _validate_closed_state_historical_chain(
                    contract,
                    state,
                    intent,
                    str(intent_binding["sha256"]),
                    chain,
                    auditor,
                    require_final=True,
                )

    # Revalidate every historical state binding immediately before task removal.
    with _file_lock(contract.global_lock_path):
        with _file_lock(contract.state_lock_path):
            _assert_dev1_inventory(chain, auditor)
            control_call(contract, "AssertFile", contract.intent_path)
            intent_binding = file_binding(contract.intent_path)
            intent = load_strict_json(contract.intent_path, "pre-unregister intent")
            _validate_intent(contract, intent, chain, authorized_utc, auditor)
            state = load_strict_json(contract.state_path, "pre-unregister state")
            proof = _validate_closed_state_historical_chain(
                contract,
                state,
                intent,
                str(intent_binding["sha256"]),
                chain,
                auditor,
                require_final=True,
            )

    # The exact lock order is released before unregistering the disabled task.
    allow_start_race = proof["start_race"] == "true"
    try:
        quiesced = task_call(
            contract,
            job,
            pre,
            helper_sha,
            "AwaitQuiesced",
            expected_task_contract_sha256=proof["contract"],
            allow_observed_start_race=allow_start_race,
        )
        current_quiesced, current_start_race = _validate_await_quiesced_probe(
            quiesced,
            contract,
            expected_helper_sha256=helper_sha,
            expected_principal_sid=principal_sid,
        )
        if (
            canonical_sha256(current_quiesced) != proof["quiesced"]
            or current_quiesced["task_xml_sha256"] != proof["xml"]
            or current_quiesced["task_contract_sha256"] != proof["contract"]
            or current_start_race is not allow_start_race
        ):
            raise ClosureError("disabled task drifted from terminal closure proof")
        try:
            task_call(
                contract,
                job,
                pre,
                helper_sha,
                "Unregister",
                expected_task_contract_sha256=proof["contract"],
                expected_disabled_xml_sha256=proof["xml"],
                allow_observed_start_race=allow_start_race,
            )
        except ClosureError:
            # A concurrent identical recovery may have removed it first.  Only
            # an exact absence proof may convert that race into success.
            raced_absent = task_call(contract, job, pre, helper_sha, "ProbeAbsent")
            _validate_absent_probe(
                raced_absent, contract, expected_helper_sha256=helper_sha
            )
    except ClosureError as inspect_error:
        try:
            raced_absent = task_call(contract, job, pre, helper_sha, "ProbeAbsent")
            _validate_absent_probe(
                raced_absent, contract, expected_helper_sha256=helper_sha
            )
        except ClosureError:
            raise inspect_error
    crash_hook("after_unregister")
    absent_probe = task_call(contract, job, pre, helper_sha, "ProbeAbsent")
    _validate_absent_probe(
        absent_probe, contract, expected_helper_sha256=helper_sha
    )
    _assert_dev1_inventory(chain, auditor)

    with _file_lock(contract.global_lock_path):
        with _file_lock(contract.state_lock_path):
            _assert_dev1_inventory(chain, auditor)
            control_call(contract, "AssertFile", contract.intent_path)
            intent_binding = file_binding(contract.intent_path)
            intent = load_strict_json(contract.intent_path, "closure intent")
            _validate_intent(contract, intent, chain, authorized_utc, auditor)
            state_after_binding = file_binding(contract.state_path)
            state_after = load_strict_json(contract.state_path, "closed launch state")
            _assert_no_outcome_side_effects(contract)
            proof = _validate_closed_state_historical_chain(
                contract,
                state_after,
                intent,
                str(intent_binding["sha256"]),
                chain,
                auditor,
                require_final=True,
            )
            fresh_absent = task_call(contract, job, pre, helper_sha, "ProbeAbsent")
            _validate_absent_probe(
                fresh_absent, contract, expected_helper_sha256=helper_sha
            )
            if contract.receipt_path.exists():
                control_call(contract, "AssertFile", contract.receipt_path)
                receipt = load_strict_json(contract.receipt_path, "closure receipt")
                _validate_receipt(
                    contract,
                    receipt,
                    chain,
                    intent_binding,
                    intent,
                    state_after_binding,
                    proof,
                )
                receipt_binding = file_binding(contract.receipt_path)
                status = "ALREADY_CLOSED"
            else:
                receipt = _receipt_payload(
                    contract,
                    chain,
                    intent_binding,
                    intent,
                    state_after_binding,
                    proof,
                    absent_probe,
                )
                _publish_json(
                    contract,
                    contract.receipt_path,
                    receipt,
                    replace=False,
                    control_call=control_call,
                )
                receipt_binding = file_binding(contract.receipt_path)
                status = "CLOSED"
                crash_hook("after_receipt")
    return {
        "status": status,
        "reason_code": REASON_CODE,
        "closure_intent": intent_binding,
        "closure_receipt": receipt_binding,
        "launch_state": state_after_binding,
        "task_absent": True,
        "outcome_fence_crossed": False,
        "no_resume": True,
        "outcome_data_read": False,
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--authorized-utc", required=True)
    parser.add_argument(
        "--expected-utility-sha256", required=True, choices=None
    )
    parser.add_argument("--expected-task-helper-sha256", required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        result = close_g1(
            default_contract(),
            authorized_utc=args.authorized_utc,
            expected_utility_sha256=args.expected_utility_sha256.lower(),
            expected_task_helper_sha256=args.expected_task_helper_sha256.lower(),
        )
    except (ClosureError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        print(
            json.dumps(
                {
                    "status": "REJECT",
                    "reason_code": REASON_CODE,
                    "error_type": type(exc).__name__,
                    "error": str(exc),
                    "outcome_data_read": False,
                },
                indent=2,
                sort_keys=True,
            ),
            file=sys.stderr,
        )
        return 2
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
