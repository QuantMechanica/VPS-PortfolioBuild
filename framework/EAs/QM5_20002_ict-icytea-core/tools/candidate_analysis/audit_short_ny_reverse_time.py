#!/usr/bin/env python3
"""Fail-closed PRE/LAUNCH/POST evidence chain for the QM5_20002 short-NY screen.

PRE is outcome-blind.  It seals the preregistered contract, source/build, all
four set files, the exact DEV1 Model-4 data bytes, both news calendars, and the
runtime used by the persistent launcher.  LAUNCH requires a separate explicit
authorization receipt and starts a checkpointing worker through a triggerless
Windows Scheduled Task; this keeps the four-cell/two-duplicate screen independent
of an interactive Codex session and its Windows job object.
POST accepts only a COMPLETE launch state and audits native reports, tester
inputs, real-tick evidence, exact duplicate Deals, opening-fill semantics, and
the frozen cost/slippage merit gates.

This tool never parses market prices.  The PRE/POST data check is an opaque
SHA-256 identity check over the preregistered .hcc/.tkc files only.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import bisect
import copy
import csv
import hashlib
import importlib.util
import ipaddress
import json
import os
import re
import subprocess
import sys
import tempfile
from collections import defaultdict
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


getcontext().prec = 34

TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
CONTRACT_PATH = EA_ROOT / "docs" / "candidate-analysis" / "short_ny_reverse_time_contract.json"
COMPILE_BINDING_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "short_ny_reverse_time_compile_binding.json"
)
SET_MANIFEST_PATH = EA_ROOT / "sets" / "candidate-analysis" / "short_ny_reverse_time_manifest.json"
SOURCE_PATH = EA_ROOT / "QM5_20002_ict-icytea-core.mq5"
SOURCE_CORRECTION_PLAN_PATH = (
    EA_ROOT / "docs" / "candidate-analysis" / "source_correction_v3_plan.md"
)
PRIMARY_SOURCE_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\sources\ict_icy_tea_source_20260716"
    r"\MQL5_Strategie_Spezifikation_some_icy_tea.docx"
)
EX5_PATH = EA_ROOT / "QM5_20002_ict-icytea-core.ex5"
REPORT_CORE_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_20009_ict-liquidity-portfolio"
    / "tools"
    / "audit_mt5_report.py"
)
RUNNER_PATH = REPO_ROOT / "framework" / "scripts" / "run_dev1_smoke.ps1"
RUNNER_CHILD_PATH = REPO_ROOT / "framework" / "scripts" / "invoke_dev1_smoke_task.ps1"
DEV1_CLEANUP_HELPER_PATH = (
    REPO_ROOT / "framework" / "scripts" / "cleanup_dev1_account_lease.ps1"
)
CREDENTIAL_PROBE_PATH = (
    REPO_ROOT / "framework" / "scripts" / "probe_dev1_machine_credential.ps1"
)
CREDENTIAL_HELPER_PATH = (
    REPO_ROOT / "framework" / "scripts" / "dev1_machine_credential.ps1"
)
IDENTITY_PROBE_CHILD_PATH = (
    REPO_ROOT / "framework" / "scripts" / "invoke_dev1_identity_probe.ps1"
)
RUN_SMOKE_PATH = REPO_ROOT / "framework" / "scripts" / "run_smoke.ps1"
DEV1_LANE_CONTRACT_PATH = REPO_ROOT / "framework" / "registry" / "dev1_lane_contract.json"
MACHINE_CREDENTIAL_PATH = Path(
    r"C:\ProgramData\QM\DEV1\credential.machine-dpapi.json"
)
MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH = Path(
    r"C:\ProgramData\QM\DEV1\credential.machine-dpapi.rotation-receipt.json"
)
LEGACY_CREDENTIAL_PATH = Path(r"C:\ProgramData\QM\DEV1\credential.clixml")
DEV1_CREDENTIAL_ROTATION_ROOT = Path(r"D:\QM\reports\dev1\credential-rotation")
SCHEDULED_TASK_HELPER_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "run_outcome_fenced_task.ps1"
)
COMPILE_CONTROLLER_PATH = (
    EA_ROOT / "tools" / "candidate_analysis" / "compile_short_ny_v3.ps1"
)
GROUP_CANONICAL_PATH = (
    REPO_ROOT
    / "framework"
    / "registry"
    / "tester_groups"
    / "Darwinex-Live_real.canonical.txt"
)
GROUP_DEV1_PATH = Path(r"D:\QM\mt5\DEV1\MQL5\Profiles\Tester\Groups\Darwinex-Live_real.txt")
TERMINAL_PATH = Path(r"D:\QM\mt5\DEV1\terminal64.exe")
METATESTER_PATH = Path(r"D:\QM\mt5\DEV1\metatester64.exe")
POWERSHELL_PATH = Path(r"C:\Program Files\PowerShell\7\pwsh.exe")
DATA_ROOT = Path(r"D:\QM\mt5\DEV1\Bases")
DEV1_RUNS_ROOT = Path(r"D:\QM\reports\dev1\runs")
DEV1_COMMON_FILES_ROOT = Path(
    r"C:\Users\QMDev1\AppData\Roaming\MetaQuotes\Terminal\Common\Files"
)

ANALYSIS_ID = "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001"
CONTRACT_COMMIT = "d902b04932c340dd1212b9420077d7cec6b0d80d"
EXPECTED_CONTRACT_SHA256 = "6ee74c60a823fe87b03b40a2737ba67d113b2e52e7c09a05f42ba2084e17fefa"
EXPECTED_SOURCE_SHA256 = "3fd49f2cea7575e659f1b1cf9c24c752a4a8e11db5e0c17cae69629a6f207f83"
EXPECTED_SOURCE_COMMIT = "3f1039f0eeb56ee882b5c3451eed3ee71567d6bc"
COMPILE_BINDING_COMMIT = "d2aedce42af670b18b2518d5c25e468f11fcfd8c"
EXPECTED_COMPILE_BINDING_SHA256 = "2c6ed058f0152f90565830fb5d5a194d21830798ce1827b8ddb8e3c8ec050f32"
EXPECTED_COMPILE_EVIDENCE_SHA256 = "8c342e34ca9a23ffe01b0db02ae18e7c3b00e7bfc4b4090ec68b955bd2663064"
EXPECTED_COMPILED_EX5_SHA256 = "71d1715d1b403ed85e7261ec058b17e88c43ca5f61bb5be5fb81ebde87207a11"
COMPILED_EX5_COMMIT = "2d4e400849bd222aba3294aae6520edcbe478e87"
EXPECTED_SOURCE_CORRECTION_PLAN_SHA256 = "914e1b1c81c4352ee51e7ea1dc4f525739b4e16e1a866d86b759c8dafbbf8c9a"
EXPECTED_SOURCE_CORRECTION_PLAN_COMMIT = "4e94d4c6a84c9d7bc773344a2311a23cba927f46"
EXPECTED_PRIMARY_SOURCE_SHA256 = "8880629e924c7dee48e1d2cd0a5cd835020e057ee592b132b6fd0c7a438231af"
EXPECTED_STRATEGY_CARD_SHA256 = "230e59ae40179333a3c7790cc56f371bede8edd2b8fa53913557b20d8cb8bded"
EXPECTED_BUILD_BRIEF_SHA256 = "57c16befda21c6fb1cc8e44a24b715c92940faee70de9adc1b9351c46d9c92bb"

SCHEMA_VERSION = 2
ZERO = Decimal("0")
CENT = Decimal("0.01")
INITIAL_BALANCE = Decimal("100000")
POINT_VALUE_USD_PER_LOT = Decimal("1.00")  # USD-quoted 5-digit FX: 0.00001*100000
MODEL4_MARKER = "generating based on real ticks"
EXPECTED_EXPERT = "QM5_20002_ict-icytea-core"
RUNNER_OUTPUT_EA_DIRS = ("QM5_20002", EXPECTED_EXPERT)
EXPECTED_MARKETS = {"EURUSD.DWX", "GBPUSD.DWX"}
EXPECTED_ARMS = {"A_SHORT_NY_NO_HTF", "B_SHORT_NY_H1_BIAS"}
RUNTIME_ROLES = {
    "report_html_parser": REPORT_CORE_PATH,
    "runner_controller": RUNNER_PATH,
    "runner_child": RUNNER_CHILD_PATH,
    "dev1_cleanup_helper": DEV1_CLEANUP_HELPER_PATH,
    "dev1_machine_credential_probe": CREDENTIAL_PROBE_PATH,
    "dev1_machine_credential_helper": CREDENTIAL_HELPER_PATH,
    "dev1_identity_probe_child": IDENTITY_PROBE_CHILD_PATH,
    "dev1_machine_credential": MACHINE_CREDENTIAL_PATH,
    "dev1_machine_credential_rotation_receipt": MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH,
    "dev1_lane_contract": DEV1_LANE_CONTRACT_PATH,
    "runner_smoke": RUN_SMOKE_PATH,
    "tester_groups_canonical": GROUP_CANONICAL_PATH,
    "tester_groups_dev1": GROUP_DEV1_PATH,
    "terminal_binary": TERMINAL_PATH,
    "metatester_binary": METATESTER_PATH,
    "powershell_binary": POWERSHELL_PATH,
    "python_binary": Path(sys.executable).resolve(),
    "scheduled_task_helper": SCHEDULED_TASK_HELPER_PATH,
    "current_compile_controller": COMPILE_CONTROLLER_PATH,
}

LAUNCHER_REVISION = 4
SCHEDULED_TASK_PREFIX = "QM_QM20002_AUDIT_"
MAX_SCHEDULED_TASK_SECONDS = 777600
RUNNER_MAXIMUM_ATTEMPTS_CAP = 10
RUNNER_PER_ATTEMPT_OVERHEAD_SECONDS = 600
RUNNER_FINALIZATION_MARGIN_SECONDS = 600
OUTER_CONTROLLER_CLEANUP_MARGIN_SECONDS = 1800

LAUNCH_STATE_FIELDS = frozenset(
    {
        "schema_version",
        "launcher_revision",
        "artifact_type",
        "analysis_id",
        "status",
        "created_utc",
        "updated_utc",
        "started_utc",
        "finished_utc",
        "worker_pid",
        "job",
        "pre_receipt_path",
        "pre_receipt_sha256",
        "authorization",
        "scheduler",
        "resume_count",
        "active_cell",
        "outcome_possible_since_utc",
        "cells",
        "terminal",
    }
)
LAUNCH_JOB_FIELDS = frozenset(
    {
        "schema_version",
        "launcher_revision",
        "artifact_type",
        "analysis_id",
        "created_utc",
        "pre_receipt_path",
        "pre_receipt_sha256",
        "authorization",
        "state_path",
        "controller_timeout_seconds",
        "plan_sha256",
        "tool",
        "dev1_runs_before_launch",
        "scheduler",
    }
)
LEGACY_REV2_REJECT_FIELDS = frozenset(
    (LAUNCH_STATE_FIELDS - {"terminal"}) | {"error_type", "error"}
)
ACTIVE_CELL_FIELDS = frozenset(
    {"cell_id", "attempt_number", "command_sha256", "started_utc", "status"}
)
CELL_RECORD_FIELDS = frozenset({"cell_id", "status", "attempts"})
ATTEMPT_FIELDS = frozenset(
    {
        "attempt_number",
        "status",
        "started_utc",
        "finished_utc",
        "command_sha256",
        "outcome_fence_crossed",
        "no_resume",
        "runner_exit_code",
        "runner_result",
        "stdout",
        "stderr",
        "summary",
        "run_artifacts",
        "failure_stage",
        "controller_failure_class",
        "error_type",
        "error",
    }
)
TERMINAL_ERROR_FIELDS = frozenset(
    {
        "status",
        "error_type",
        "error",
        "failure_stage",
        "affected_cell_id",
        "outcome_fence_crossed",
        "no_resume",
        "controller_failure_class",
    }
)
BINDING_FIELDS = frozenset({"path", "size", "sha256"})
RUN_ARTIFACT_FIELDS = frozenset({"run", "report", "tester_log", "tester_ini"})
FAILURE_STAGES = frozenset(
    {
        "WORKER_VALIDATION",
        "RUNNING_STATE_PERSIST",
        "OUTCOME_FENCE_PERSISTED",
        "RUNNER_RETURNED",
        "RUNNER_STREAMS_PARTIALLY_BOUND",
        "RUNNER_STREAMS_BOUND",
        "RUNNER_RESULT_PARSED",
        "SUMMARY_BOUND",
        "RUN_ARTIFACTS_BOUND",
        "CELL_STATE_PERSIST",
        "FINAL_STATE_PERSIST",
    }
)
CONTROLLER_FAILURE_CLASSES = frozenset(
    {
        "RUNNER_CREDENTIAL_CLIXML_CRYPTOGRAPHIC_FAILURE_BEFORE_JSON",
        "RUNNER_EMPTY_STDOUT_NO_JSON",
        "RUNNER_MALFORMED_STDOUT_NO_JSON",
    }
)
DEV1_CONTROLLER_RESULT_FIELDS = frozenset(
    {
        "schema_version",
        "run_id",
        "nonce",
        "success",
        "error_code",
        "error_message",
        "run_smoke_exit_code",
        "identity_sid",
        "common_path",
        "expected_task_name",
        "controller_mutex",
        "lane_contract_sha256",
        "machine_credential_sha256",
        "machine_credential_helper_sha256",
        "child_sha256",
        "run_smoke_sha256",
        "program_sha256",
        "agent_port_proof",
        "started_utc",
        "finished_utc",
        "log_path",
        "tester_groups_post_child_sha256",
        "tester_groups_restored_sha256",
        "tester_groups_canonical_path",
        "tester_groups_dev1_path",
        "dev1_account_initially_enabled",
        "dev1_account_enabled_by_controller",
        "dev1_account_restored_disabled",
        "cleanup_helper_sha256",
        "cleanup_lease_registered",
        "cleanup_lease_disarmed",
    }
)


class AuditError(RuntimeError):
    """Base class for every fail-closed rejection."""


class PreflightError(AuditError):
    """PRE evidence is incomplete, stale, or inconsistent."""


class AuthorizationError(AuditError):
    """MT5 execution was requested without an exact authorization receipt."""


class PostflightError(AuditError):
    """Native run evidence is incomplete or violates the frozen contract."""


@dataclass
class NativeAudit:
    receipt: dict[str, Any]
    deals: list[Any]
    fragments: list[dict[str, Any]]
    trades: list[dict[str, Any]]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=True
    ).encode("ascii")


def canonical_sha256(value: Any) -> str:
    return hashlib.sha256(canonical_bytes(value)).hexdigest()


def _jsonable(value: Any) -> Any:
    if isinstance(value, Decimal):
        return decimal_text(value)
    if isinstance(value, datetime):
        return value.strftime("%Y-%m-%dT%H:%M:%S")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, Path):
        return str(value)
    if isinstance(value, Mapping):
        return {str(key): _jsonable(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_jsonable(item) for item in value]
    return value


def atomic_json(path: Path, payload: Mapping[str, Any], *, replace: bool = True) -> str:
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (
        json.dumps(_jsonable(payload), indent=2, sort_keys=True, ensure_ascii=False) + "\n"
    ).encode("utf-8")
    descriptor, temporary = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        if replace:
            os.replace(temporary, path)
            temporary = ""
        else:
            # A same-directory hard-link publishes the already complete, fsynced
            # inode with create-if-absent semantics.  Unlike exists()+replace(),
            # two writers cannot both win and immutable evidence is never visible
            # partially or overwritten by the loser.
            try:
                os.link(temporary, path)
            except FileExistsError as exc:
                raise AuditError(f"refusing to replace existing evidence: {path}") from exc
            os.unlink(temporary)
            temporary = ""
    except Exception:
        if temporary:
            try:
                os.unlink(temporary)
            except OSError:
                pass
        raise
    return hashlib.sha256(encoded).hexdigest()


@contextmanager
def _launch_state_lock(state_path: Path) -> Iterable[None]:
    """Serialize every cooperative launch-state transition on one durable lock."""

    state_path = state_path.resolve()
    # Keep the historical lock filename so already-running revision-3 terminal
    # publishers and revision-4 transitions cannot use disjoint lock domains.
    lock_path = state_path.with_name(f".{state_path.name}.terminal.lock")
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    with lock_path.open("a+b") as handle:
        handle.seek(0, os.SEEK_END)
        if handle.tell() == 0:
            handle.write(b"\0")
            handle.flush()
            os.fsync(handle.fileno())
        handle.seek(0)
        if os.name == "nt":
            import msvcrt

            msvcrt.locking(handle.fileno(), msvcrt.LK_LOCK, 1)
            try:
                yield
            finally:
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:  # pragma: no cover - exercised by non-Windows developer hosts.
            import fcntl

            fcntl.flock(handle.fileno(), fcntl.LOCK_EX)
            try:
                yield
            finally:
                fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


# Compatibility name for tests and any in-flight terminal publisher.  New code
# deliberately routes every state transition through the same lock function.
_terminal_state_lock = _launch_state_lock


def load_json(path: Path) -> dict[str, Any]:
    try:
        payload = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AuditError(f"invalid JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise AuditError(f"JSON root must be an object: {path}")
    return payload


def load_strict_json(path: Path, label: str) -> dict[str, Any]:
    """Load one finite JSON object while rejecting duplicate property names."""

    def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        payload: dict[str, Any] = {}
        for key, value in pairs:
            if key in payload:
                raise ValueError(f"duplicate JSON property: {key}")
            payload[key] = value
        return payload

    def reject_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON constant: {value}")

    try:
        payload = json.loads(
            path.read_text(encoding="utf-8-sig"),
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_constant,
        )
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        raise AuditError(f"invalid exact {label} JSON {path}: {exc}") from exc
    if not isinstance(payload, dict):
        raise AuditError(f"{label} JSON root must be an object: {path}")
    return payload


def file_binding(path: Path, expected_sha256: str | None = None) -> dict[str, Any]:
    path = path.resolve()
    if not path.is_file():
        raise AuditError(f"required file missing: {path}")
    observed = sha256_file(path)
    if expected_sha256 and observed != expected_sha256.lower():
        raise AuditError(f"SHA-256 drift for {path}: {observed} != {expected_sha256.lower()}")
    return {"path": str(path), "size": path.stat().st_size, "sha256": observed}


def assert_binding(binding: Mapping[str, Any], label: str) -> None:
    try:
        path = Path(str(binding["path"])).resolve()
        expected_size = int(binding["size"])
        expected_sha = str(binding["sha256"]).lower()
    except (KeyError, TypeError, ValueError) as exc:
        raise AuditError(f"malformed {label} binding") from exc
    if not path.is_file() or path.stat().st_size != expected_size:
        raise AuditError(f"{label} missing/size drift: {path}")
    observed = sha256_file(path)
    if observed != expected_sha:
        raise AuditError(f"{label} SHA drift: {observed} != {expected_sha}")


def _require_exact_fields(
    value: Any,
    expected: frozenset[str],
    label: str,
    exc_type: type[AuditError] = AuditError,
) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise exc_type(f"{label} must be an object")
    observed = set(value)
    if observed != expected:
        missing = sorted(expected - observed)
        extra = sorted(observed - expected)
        raise exc_type(f"{label} field closure drift: missing={missing}, extra={extra}")
    return value


def _validate_binding_shape(
    value: Any, label: str, exc_type: type[AuditError] = AuditError
) -> Mapping[str, Any]:
    binding = _require_exact_fields(value, BINDING_FIELDS, label, exc_type)
    if (
        type(binding["path"]) is not str
        or not binding["path"]
        or type(binding["size"]) is not int
        or binding["size"] < 0
        or type(binding["sha256"]) is not str
        or re.fullmatch(r"[0-9a-f]{64}", binding["sha256"]) is None
    ):
        raise exc_type(f"{label} has malformed typed binding fields")
    return binding


def _validate_optional_binding_shape(
    value: Any, label: str, exc_type: type[AuditError] = AuditError
) -> None:
    if value is not None:
        _validate_binding_shape(value, label, exc_type)


def _validate_attempt_shape(
    value: Any, label: str, exc_type: type[AuditError] = AuditError
) -> Mapping[str, Any]:
    attempt = _require_exact_fields(value, ATTEMPT_FIELDS, label, exc_type)
    if type(attempt["attempt_number"]) is not int or attempt["attempt_number"] != 1:
        raise exc_type(f"{label} attempt_number must be the exact integer 1")
    if attempt["status"] not in {"COMPLETE", "REJECT"}:
        raise exc_type(f"{label} has invalid status")
    if type(attempt["started_utc"]) is not str or type(attempt["finished_utc"]) is not str:
        raise exc_type(f"{label} timestamps must be strings")
    parse_utc(attempt["started_utc"], f"{label} started_utc")
    parse_utc(attempt["finished_utc"], f"{label} finished_utc")
    if (
        type(attempt["command_sha256"]) is not str
        or re.fullmatch(r"[0-9a-f]{64}", attempt["command_sha256"]) is None
    ):
        raise exc_type(f"{label} command_sha256 is malformed")
    if type(attempt["outcome_fence_crossed"]) is not bool or attempt["outcome_fence_crossed"] is not True:
        raise exc_type(f"{label} outcome_fence_crossed must be true")
    if type(attempt["no_resume"]) is not bool or attempt["no_resume"] is not True:
        raise exc_type(f"{label} no_resume must be true")
    exit_code = attempt["runner_exit_code"]
    if exit_code is not None and type(exit_code) is not int:
        raise exc_type(f"{label} runner_exit_code must be an integer or null")
    if attempt["runner_result"] is not None and not isinstance(attempt["runner_result"], Mapping):
        raise exc_type(f"{label} runner_result must be an object or null")
    for field in ("stdout", "stderr", "summary"):
        _validate_optional_binding_shape(attempt[field], f"{label} {field}", exc_type)
    artifacts = attempt["run_artifacts"]
    if not isinstance(artifacts, list):
        raise exc_type(f"{label} run_artifacts must be a list")
    for index, artifact_value in enumerate(artifacts):
        artifact = _require_exact_fields(
            artifact_value, RUN_ARTIFACT_FIELDS, f"{label} run_artifacts[{index}]", exc_type
        )
        if artifact["run"] not in {"run_01", "run_02"}:
            raise exc_type(f"{label} run artifact identity is malformed")
        for field in ("report", "tester_log", "tester_ini"):
            _validate_binding_shape(
                artifact[field], f"{label} {artifact['run']} {field}", exc_type
            )
    run_names = [artifact["run"] for artifact in artifacts]
    if run_names not in ([], ["run_01", "run_02"]):
        raise exc_type(f"{label} run artifact closure is incomplete or out of order")

    if attempt["status"] == "COMPLETE":
        if (
            type(exit_code) is not int
            or exit_code != 0
            or not isinstance(attempt["runner_result"], Mapping)
            or attempt["runner_result"].get("success") is not True
            or any(attempt[field] is None for field in ("stdout", "stderr", "summary"))
            or run_names != ["run_01", "run_02"]
            or any(
                attempt[field] is not None
                for field in ("failure_stage", "controller_failure_class", "error_type", "error")
            )
        ):
            raise exc_type(f"{label} COMPLETE evidence is not exactly closed")
    else:
        if (
            type(attempt["failure_stage"]) is not str
            or attempt["failure_stage"] not in FAILURE_STAGES
            or type(attempt["error_type"]) is not str
            or not attempt["error_type"]
            or type(attempt["error"]) is not str
            or not attempt["error"]
            or (
                attempt["controller_failure_class"] is not None
                and attempt["controller_failure_class"] not in CONTROLLER_FAILURE_CLASSES
            )
        ):
            raise exc_type(f"{label} REJECT evidence is malformed")
        if attempt["failure_stage"] == "RUNNER_STREAMS_PARTIALLY_BOUND" and not any(
            attempt[field] is not None for field in ("stdout", "stderr")
        ):
            raise exc_type(f"{label} partial stream stage has no bound stream")
        if attempt["failure_stage"] in {
            "RUNNER_STREAMS_BOUND",
            "RUNNER_RESULT_PARSED",
            "SUMMARY_BOUND",
            "RUN_ARTIFACTS_BOUND",
            "CELL_STATE_PERSIST",
        } and any(attempt[field] is None for field in ("stdout", "stderr")):
            raise exc_type(f"{label} stream bindings are incomplete for its failure stage")
    return attempt


def _validate_cell_record_shape(
    value: Any, label: str, exc_type: type[AuditError] = AuditError
) -> Mapping[str, Any]:
    cell = _require_exact_fields(value, CELL_RECORD_FIELDS, label, exc_type)
    if type(cell["cell_id"]) is not str or not cell["cell_id"]:
        raise exc_type(f"{label} cell_id is malformed")
    if cell["status"] not in {"COMPLETE", "REJECT"}:
        raise exc_type(f"{label} status is malformed")
    attempts = cell["attempts"]
    if not isinstance(attempts, list) or len(attempts) != 1:
        raise exc_type(f"{label} must contain exactly one outcome-fenced attempt")
    attempt = _validate_attempt_shape(attempts[0], f"{label} attempt", exc_type)
    if attempt["status"] != cell["status"]:
        raise exc_type(f"{label} cell/attempt status drift")
    return cell


def _validate_terminal_error_shape(
    value: Any, label: str, exc_type: type[AuditError] = AuditError
) -> Mapping[str, Any]:
    terminal = _require_exact_fields(value, TERMINAL_ERROR_FIELDS, label, exc_type)
    if (
        terminal["status"] != "REJECT"
        or type(terminal["error_type"]) is not str
        or not terminal["error_type"]
        or type(terminal["error"]) is not str
        or not terminal["error"]
        or type(terminal["failure_stage"]) is not str
        or terminal["failure_stage"] not in FAILURE_STAGES
        or (
            terminal["affected_cell_id"] is not None
            and (type(terminal["affected_cell_id"]) is not str or not terminal["affected_cell_id"])
        )
        or type(terminal["outcome_fence_crossed"]) is not bool
        or type(terminal["no_resume"]) is not bool
        or terminal["no_resume"] is not True
        or (
            terminal["controller_failure_class"] is not None
            and terminal["controller_failure_class"] not in CONTROLLER_FAILURE_CLASSES
        )
    ):
        raise exc_type(f"{label} is malformed")
    return terminal


def _validate_launch_state_shape(
    value: Any, exc_type: type[AuditError] = AuditError
) -> Mapping[str, Any]:
    state = _require_exact_fields(value, LAUNCH_STATE_FIELDS, "launch state", exc_type)
    if (
        type(state["schema_version"]) is not int
        or state["schema_version"] != SCHEMA_VERSION
        or type(state["launcher_revision"]) is not int
        or state["launcher_revision"] != LAUNCHER_REVISION
        or state["artifact_type"] != "QM5_20002_SHORT_NY_LAUNCH_STATE"
        or state["analysis_id"] != ANALYSIS_ID
    ):
        raise exc_type("launch state schema/identity drift")
    if state["status"] not in {"PENDING", "PENDING_RESUME", "RUNNING", "COMPLETE", "REJECT"}:
        raise exc_type("launch state status is malformed")
    for field in ("created_utc", "updated_utc"):
        if type(state[field]) is not str:
            raise exc_type(f"launch state {field} must be a string")
        parse_utc(state[field], f"launch state {field}")
    for field in ("started_utc", "finished_utc", "outcome_possible_since_utc"):
        if state[field] is not None:
            if type(state[field]) is not str:
                raise exc_type(f"launch state {field} must be a string or null")
            parse_utc(state[field], f"launch state {field}")
    if state["worker_pid"] is not None and (
        type(state["worker_pid"]) is not int or state["worker_pid"] <= 0
    ):
        raise exc_type("launch state worker_pid must be a positive integer or null")
    _validate_binding_shape(state["job"], "launch state job", exc_type)
    if (
        type(state["pre_receipt_path"]) is not str
        or not state["pre_receipt_path"]
        or type(state["pre_receipt_sha256"]) is not str
        or re.fullmatch(r"[0-9a-f]{64}", state["pre_receipt_sha256"]) is None
        or not isinstance(state["authorization"], Mapping)
        or not isinstance(state["scheduler"], Mapping)
        or type(state["resume_count"]) is not int
        or state["resume_count"] < 0
    ):
        raise exc_type("launch state immutable identity/types are malformed")
    active = state["active_cell"]
    if active is not None:
        active = _require_exact_fields(active, ACTIVE_CELL_FIELDS, "active cell", exc_type)
        if (
            type(active["cell_id"]) is not str
            or not active["cell_id"]
            or type(active["attempt_number"]) is not int
            or active["attempt_number"] != 1
            or type(active["command_sha256"]) is not str
            or re.fullmatch(r"[0-9a-f]{64}", active["command_sha256"]) is None
            or type(active["started_utc"]) is not str
            or active["status"] != "OUTCOME_POSSIBLE_NO_RESUME"
        ):
            raise exc_type("active cell is malformed")
        parse_utc(active["started_utc"], "active cell started_utc")
    cells = state["cells"]
    if not isinstance(cells, list):
        raise exc_type("launch state cells must be a list")
    for index, cell in enumerate(cells):
        _validate_cell_record_shape(cell, f"launch state cells[{index}]", exc_type)
    cell_ids = [cell["cell_id"] for cell in cells]
    if len(cell_ids) != len(set(cell_ids)):
        raise exc_type("launch state cell IDs are not unique")
    rejected = [cell for cell in cells if cell["status"] == "REJECT"]
    if len(rejected) > 1 or (rejected and cells[-1] is not rejected[0]):
        raise exc_type("launch state rejected cell must be unique and last")

    status = state["status"]
    if status in {"PENDING", "PENDING_RESUME"}:
        if (
            state["worker_pid"] is not None
            or state["finished_utc"] is not None
            or state["active_cell"] is not None
            or state["outcome_possible_since_utc"] is not None
            or cells != []
            or state["terminal"] is not None
        ):
            raise exc_type("pre-outcome launch state is not exactly open")
    elif status == "RUNNING":
        if (
            state["worker_pid"] is None
            or state["started_utc"] is None
            or state["finished_utc"] is not None
            or state["terminal"] is not None
            or rejected
        ):
            raise exc_type("RUNNING launch state is not exactly open")
        if (active is not None or cells) and state["outcome_possible_since_utc"] is None:
            raise exc_type("RUNNING launch state omitted its outcome fence")
    elif status == "COMPLETE":
        if (
            state["worker_pid"] is not None
            or state["active_cell"] is not None
            or state["started_utc"] is None
            or state["finished_utc"] is None
            or state["outcome_possible_since_utc"] is None
            or state["terminal"] is not None
            or not cells
            or any(cell["status"] != "COMPLETE" for cell in cells)
        ):
            raise exc_type("COMPLETE launch state is not exactly closed")
    else:
        terminal = _validate_terminal_error_shape(
            state["terminal"], "launch state terminal", exc_type
        )
        if (
            state["worker_pid"] is not None
            or state["active_cell"] is not None
            or state["finished_utc"] is None
        ):
            raise exc_type("REJECT launch state is not exactly closed")
        affected = terminal["affected_cell_id"]
        if affected is not None:
            if not rejected or rejected[0]["cell_id"] != affected:
                raise exc_type("terminal rejection/cell evidence drift")
            attempt = rejected[0]["attempts"][0]
            for field in (
                "error_type",
                "error",
                "failure_stage",
                "controller_failure_class",
                "outcome_fence_crossed",
                "no_resume",
            ):
                if terminal[field] != attempt[field]:
                    raise exc_type(f"terminal rejection/attempt {field} drift")
        elif rejected:
            raise exc_type("rejected cell exists without terminal affected_cell_id")
        if terminal["outcome_fence_crossed"] != (state["outcome_possible_since_utc"] is not None):
            raise exc_type("terminal outcome-fence closure drift")
    return state


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=REPO_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=check,
    )


def assert_committed_bytes(commit: str, path: Path, expected: bytes, label: str) -> None:
    relative = path.resolve().relative_to(REPO_ROOT).as_posix()
    result = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=REPO_ROOT,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0 or result.stdout != expected:
        raise PreflightError(f"{label} is not byte-identical at commit {commit}")


def assert_ancestor(ancestor: str, descendant: str, label: str) -> None:
    result = _git("merge-base", "--is-ancestor", ancestor, descendant, check=False)
    if result.returncode != 0:
        raise PreflightError(f"{label}: {ancestor} is not an ancestor of {descendant}")


def parse_utc(value: str, label: str) -> datetime:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise AuditError(f"invalid {label}: {value!r}") from exc
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def decimal_text(value: Decimal) -> str:
    if value == ZERO:
        return "0"
    return format(value.normalize(), "f")


def money(value: Decimal) -> Decimal:
    return value.quantize(CENT, rounding=ROUND_HALF_UP)


def money_text(value: Decimal) -> str:
    return format(money(value), ".2f")


def parse_decimal(value: str, label: str) -> Decimal:
    cleaned = value.strip().replace("\u00a0", " ").replace("\u202f", " ").replace(" ", "")
    if not cleaned:
        raise AuditError(f"missing numeric value: {label}")
    if "," in cleaned and "." in cleaned:
        if cleaned.rfind(",") > cleaned.rfind("."):
            cleaned = cleaned.replace(".", "").replace(",", ".")
        else:
            cleaned = cleaned.replace(",", "")
    elif "," in cleaned:
        cleaned = cleaned.replace(",", ".")
    try:
        result = Decimal(cleaned)
    except InvalidOperation as exc:
        raise AuditError(f"invalid numeric value for {label}: {value!r}") from exc
    if not result.is_finite():
        raise AuditError(f"non-finite numeric value for {label}")
    return result


def committed_blob_binding(
    commit: str, path: Path, expected_sha256: str, label: str
) -> dict[str, Any]:
    """Bind immutable historical tool bytes without conflating them with HEAD."""

    if re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise PreflightError(f"{label} commit is malformed")
    try:
        relative = path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError as exc:
        raise PreflightError(f"{label} path escaped repository") from exc
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "show", f"{commit}:{relative}"],
        capture_output=True,
        check=False,
    )
    if completed.returncode != 0:
        raise PreflightError(f"cannot resolve frozen {label} Git blob")
    observed = hashlib.sha256(completed.stdout).hexdigest()
    if observed != expected_sha256:
        raise PreflightError(
            f"frozen {label} Git blob SHA drift: {observed} != {expected_sha256}"
        )
    return {
        "repository_path": relative,
        "git_commit": commit,
        "size": len(completed.stdout),
        "sha256": observed,
    }


def load_contract() -> dict[str, Any]:
    raw = CONTRACT_PATH.read_bytes()
    observed = hashlib.sha256(raw).hexdigest()
    if observed != EXPECTED_CONTRACT_SHA256:
        raise PreflightError(f"contract SHA drift: {observed}")
    assert_committed_bytes(CONTRACT_COMMIT, CONTRACT_PATH, raw, "contract")
    contract = json.loads(raw.decode("utf-8"))
    if (
        contract.get("schema_version") != 2
        or contract.get("contract_revision") != 3
        or contract.get("analysis_id") != ANALYSIS_ID
    ):
        raise PreflightError("unexpected contract schema/revision/analysis id")
    calendars = contract.get("data_bindings", {}).get("news_calendars")
    if not isinstance(calendars, list) or len(calendars) != 2:
        raise PreflightError("contract must bind exactly both QM_NewsInit calendars")
    roles = {str(row.get("role")) for row in calendars if isinstance(row, Mapping)}
    if roles != {
        "PRIMARY_QM_NEWS_CALENDAR",
        "SECONDARY_QM_NEWS_CALENDAR_REQUIRED_BY_QM_NewsInit",
    }:
        raise PreflightError("contract news role closure drift")
    fill_gate = contract.get("execution_integrity_gates", {})
    if (
        fill_gate.get("opening_fill_new_york_window")
        != "07:00:00_INCLUSIVE_TO_10:00:00_EXCLUSIVE"
        or fill_gate.get("opening_fill_must_be_outside_news_blackout_union") is not True
        or fill_gate.get("violation_disposition") != "INVALID"
    ):
        raise PreflightError("contract opening-fill INVALID gates drifted")
    causal = contract.get("revision_3_causal_semantics", {})
    exact_causal = {
        "immediate_sweep_reclaim": "JUST_CLOSED_BAR_WICKS_STRICTLY_THROUGH_LEVEL_AND_CLOSES_STRICTLY_BACK_ACROSS_PREVIOUS_CLOSE_IRRELEVANT",
        "later_sweep_reclaim": "FIRST_SUBSEQUENT_CLOSE_BACK_ACROSS_WITHIN_SweepReturnBars_SUBSEQUENTLY_CLOSED_BARS_ALL_INTERVENING_CLOSES_REMAIN_ON_SWEPT_SIDE",
        "immediate_same_bar_mss": "FORBIDDEN_BECAUSE_OHLC_CANNOT_ESTABLISH_INTRABAR_SWEEP_BEFORE_MSS",
        "later_reclaim_bar_mss": "ALLOWED_WHEN_THE_RECORDED_SWEEP_BAR_IS_STRICTLY_EARLIER",
        "fvg_window": "ALL_THREE_FVG_CANDLES_STRICTLY_AFTER_RECORDED_SWEEP_AND_NO_LATER_THAN_MSS_BAR",
        "pre_sweep_fvg_may_satisfy_displacement": False,
        "sweep_to_mss_expiry_bars": 30,
    }
    for key, expected in exact_causal.items():
        if causal.get(key) != expected:
            raise PreflightError(f"contract causal semantics drift: {key}")
    runtime = contract.get("revision_3_calendar_and_runtime_safety", {})
    if (
        runtime.get("broker_d1_levels_forbidden") is not True
        or runtime.get("pending_order_policy")
        != "REMOVE_OWN_LIMITS_OUTSIDE_ENABLED_KILLZONE_OR_DURING_FRESH_TWO_CALENDAR_BLACKOUT"
        or runtime.get("fill_race_policy")
        != "VALIDATE_POSITION_TIME_AND_RETRY_IMMEDIATE_CLOSE_UNTIL_INVALID_FILL_IS_GONE"
        or runtime.get("tick_order_before_entry_news_gate")
        != [
            "KILL_SWITCH",
            "CANCEL_INVALID_PENDING_AND_CLOSE_RACING_INVALID_FILL",
            "FRIDAY_CLOSE",
            "PARTIAL_AND_BREAKEVEN_MANAGEMENT",
            "NEW_YORK_DAY_END_EXIT",
            "CUSTOM_AND_FRESH_TWO_AXIS_NEWS_ENTRY_GATE",
        ]
    ):
        raise PreflightError("contract calendar/runtime safety semantics drift")
    tester = contract.get("tester", {})
    exact_tester = {
        "terminal": "DEV1",
        "model": 4,
        "execution_mode": 0,
        "optimization": 0,
        "deposit": 100000,
        "currency": "USD",
        "leverage": 100,
        "duplicates_per_cell": 2,
    }
    for key, expected in exact_tester.items():
        if tester.get(key) != expected:
            raise PreflightError(f"tester contract drift: {key}")
    return contract


def _repo_bound_path(value: Any) -> Path:
    path = Path(str(value))
    return path.resolve() if path.is_absolute() else (REPO_ROOT / path).resolve()


def validate_compile_binding(evidence_path: Path) -> dict[str, Any]:
    """Close the frozen research binary, evidence, toolchain, and include provenance."""
    raw = COMPILE_BINDING_PATH.read_bytes()
    observed = hashlib.sha256(raw).hexdigest()
    if observed != EXPECTED_COMPILE_BINDING_SHA256:
        raise PreflightError(f"compile binding SHA drift: {observed}")
    assert_committed_bytes(
        COMPILE_BINDING_COMMIT, COMPILE_BINDING_PATH, raw, "compile binding"
    )
    binding = json.loads(raw.decode("utf-8"))
    contract = binding.get("contract", {})
    source = binding.get("source", {})
    compiled = binding.get("compiled_binary", {})
    compile_run = binding.get("compile", {})
    toolchain = binding.get("toolchain", {})
    closure = binding.get("closure_artifacts", {})
    cleanup = binding.get("cleanup", {})
    outcome_fence = binding.get("outcome_fence", {})
    if (
        binding.get("schema_version") != 1
        or binding.get("artifact_type") != "QM5_20002_SHORT_NY_COMPILE_BINDING"
        or binding.get("analysis_id") != ANALYSIS_ID
        or binding.get("research_status") != "CARD_INTAKE_NOT_APPROVED"
        or binding.get("approval_claim") != "NONE_RESEARCH_CANDIDATE_ONLY"
        or binding.get("release_state") != "RESEARCH_CANDIDATE_CARD_INTAKE_NOT_APPROVED"
        or binding.get("next_permitted_stage") != "OUTCOME_BLIND_PRE_ONLY"
        or contract.get("git_commit") != CONTRACT_COMMIT
        or contract.get("sha256") != EXPECTED_CONTRACT_SHA256
        or source.get("git_commit") != EXPECTED_SOURCE_COMMIT
        or source.get("sha256") != EXPECTED_SOURCE_SHA256
        or compiled.get("git_commit") != COMPILED_EX5_COMMIT
        or compiled.get("sha256") != EXPECTED_COMPILED_EX5_SHA256
        or compile_run.get("evidence_sha256") != EXPECTED_COMPILE_EVIDENCE_SHA256
        or compile_run.get("result") != "PASS"
        or compile_run.get("errors") != 0
        or compile_run.get("warnings") != 0
        or cleanup.get("active_dev1_processes_after") != 0
        or cleanup.get("ephemeral_compile_tasks_after") != 0
        or outcome_fence.get("mt5_terminal_started") is not False
        or outcome_fence.get("metatester_started") is not False
        or outcome_fence.get("native_reports_opened") is not False
        or outcome_fence.get("market_values_parsed") is not False
    ):
        raise PreflightError("compile binding identity/status/outcome fence drift")
    if _repo_bound_path(contract.get("path")) != CONTRACT_PATH.resolve():
        raise PreflightError("compile binding contract path drift")
    if _repo_bound_path(source.get("path")) != SOURCE_PATH.resolve():
        raise PreflightError("compile binding source path drift")
    if _repo_bound_path(compiled.get("path")) != EX5_PATH.resolve():
        raise PreflightError("compile binding EX5 path drift")

    compiled_binary = file_binding(EX5_PATH, EXPECTED_COMPILED_EX5_SHA256)
    if compiled_binary["size"] != int(compiled.get("bytes", -1)):
        raise PreflightError("compile binding EX5 size drift")
    assert_committed_bytes(
        COMPILED_EX5_COMMIT, EX5_PATH, EX5_PATH.read_bytes(), "compiled EX5"
    )

    expected_evidence_path = Path(str(compile_run.get("evidence_path", ""))).resolve()
    if evidence_path.resolve() != expected_evidence_path:
        raise PreflightError("compile evidence path does not match frozen compile binding")
    evidence = file_binding(evidence_path, EXPECTED_COMPILE_EVIDENCE_SHA256)

    closure_bindings: dict[str, Any] = {}
    for role in ("compile_log", "source_manifest", "include_sync_manifest", "include_path_audit"):
        closure_bindings[role] = file_binding(
            Path(str(closure.get(f"{role}_path", ""))),
            str(closure.get(f"{role}_sha256", "")),
        )
    if (
        int(closure.get("include_sync_rows", -1)) != 92
        or int(closure.get("included_paths", -1)) <= 0
        or int(closure.get("forbidden_include_paths", -1)) != 0
    ):
        raise PreflightError("compile binding include closure drift")

    metaeditor = file_binding(
        Path(str(toolchain.get("metaeditor_path", ""))),
        str(toolchain.get("metaeditor_sha256", "")),
    )
    compile_one_path = _repo_bound_path(toolchain.get("compile_one_path"))
    controller_path = _repo_bound_path(toolchain.get("compile_controller_path"))
    if controller_path != COMPILE_CONTROLLER_PATH.resolve():
        raise PreflightError("compile binding historical controller path drift")
    compile_one = file_binding(compile_one_path, str(toolchain.get("compile_one_sha256", "")))
    controller_commit = str(toolchain.get("compile_controller_git_commit", ""))
    controller_sha = str(toolchain.get("compile_controller_sha256", ""))
    if (
        re.fullmatch(r"[0-9a-f]{40}", controller_commit) is None
        or re.fullmatch(r"[0-9a-f]{64}", controller_sha) is None
    ):
        raise PreflightError("compile controller commit missing")
    historical_controller = committed_blob_binding(
        controller_commit,
        controller_path,
        controller_sha,
        "compile controller",
    )
    return {
        "document": {
            "commit": COMPILE_BINDING_COMMIT,
            "binding": file_binding(COMPILE_BINDING_PATH, EXPECTED_COMPILE_BINDING_SHA256),
        },
        "payload": binding,
        "evidence": evidence,
        "compiled_binary": compiled_binary,
        "closure_artifacts": closure_bindings,
        "toolchain": {
            "metaeditor": metaeditor,
            "compile_one": compile_one,
            "compile_controller_historical_blob": historical_controller,
            "compile_controller_current_runtime": file_binding(COMPILE_CONTROLLER_PATH),
        },
    }


def parse_set(path: Path) -> tuple[dict[str, str], dict[str, str]]:
    try:
        lines = path.read_text(encoding="ascii").splitlines()
    except OSError as exc:
        raise PreflightError(f"cannot read set {path}: {exc}") from exc
    metadata: dict[str, str] = {}
    inputs: dict[str, str] = {}
    for line in lines:
        if not line.strip():
            continue
        if line.startswith(";"):
            body = line[1:].strip()
            if "=" in body:
                key, value = body.split("=", 1)
                if key in metadata:
                    raise PreflightError(f"duplicate set metadata {key}: {path}")
                metadata[key] = value
            continue
        if "=" not in line:
            raise PreflightError(f"malformed set line {line!r}: {path}")
        key, value = line.split("=", 1)
        if key in inputs:
            raise PreflightError(f"duplicate set input {key}: {path}")
        inputs[key] = value
    return metadata, inputs


def render_contract_value(value: Any) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, float):
        return format(value, ".15g")
    return str(value)


def validate_sets(contract: Mapping[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    manifest_binding = file_binding(SET_MANIFEST_PATH)
    manifest = load_json(SET_MANIFEST_PATH)
    if (
        manifest.get("schema_version") != 2
        or manifest.get("artifact_type") != "QM5_20002_SHORT_NY_SET_MANIFEST"
        or manifest.get("analysis_id") != ANALYSIS_ID
        or manifest.get("contract_commit") != CONTRACT_COMMIT
        or manifest.get("contract_sha256") != EXPECTED_CONTRACT_SHA256
        or manifest.get("compile_binding_commit") != COMPILE_BINDING_COMMIT
        or manifest.get("compile_binding_sha256") != EXPECTED_COMPILE_BINDING_SHA256
        or manifest.get("compile_evidence_sha256") != EXPECTED_COMPILE_EVIDENCE_SHA256
        or manifest.get("compiled_ex5_git_commit") != COMPILED_EX5_COMMIT
        or manifest.get("compiled_ex5_sha256") != EXPECTED_COMPILED_EX5_SHA256
    ):
        raise PreflightError("set manifest contract/compile identity drift")
    rows = manifest.get("sets")
    if not isinstance(rows, list) or len(rows) != 4:
        raise PreflightError("set manifest must contain exactly four cells")
    common = dict(contract["common_inputs"])
    arm_bias = {str(row["id"]): bool(row["UseHTFBias"]) for row in contract["arms"]}
    expected_cells = {(arm, symbol) for arm in EXPECTED_ARMS for symbol in EXPECTED_MARKETS}
    observed_cells: set[tuple[str, str]] = set()
    result: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, Mapping):
            raise PreflightError("malformed set manifest row")
        arm, symbol = str(row.get("arm")), str(row.get("symbol"))
        observed_cells.add((arm, symbol))
        relative = Path(str(row.get("path")))
        path = (EA_ROOT / relative).resolve()
        if EA_ROOT.resolve() not in path.parents:
            raise PreflightError(f"set escaped EA root: {path}")
        binding = file_binding(path, str(row.get("sha256", "")))
        if binding["size"] != int(row.get("size", -1)):
            raise PreflightError(f"set size drift: {path}")
        metadata, inputs = parse_set(path)
        if len(inputs) != 52 or int(row.get("visible_input_count", -1)) != 52:
            raise PreflightError(f"set input count drift: {path}")
        expected_inputs = dict(common)
        expected_inputs["UseHTFBias"] = arm_bias[arm]
        expected_inputs["qm_magic_slot_offset"] = 0 if symbol == "EURUSD.DWX" else 1
        rendered = {key: render_contract_value(value) for key, value in expected_inputs.items()}
        if inputs != rendered:
            missing = sorted(set(rendered) - set(inputs))
            extra = sorted(set(inputs) - set(rendered))
            drift = sorted(key for key in set(inputs) & set(rendered) if inputs[key] != rendered[key])
            raise PreflightError(
                f"set/report input surface drift {path}: missing={missing}, extra={extra}, values={drift}"
            )
        if (
            metadata.get("analysis_id") != ANALYSIS_ID
            or metadata.get("contract_commit") != CONTRACT_COMMIT
            or metadata.get("contract_sha256") != EXPECTED_CONTRACT_SHA256
            or metadata.get("compile_binding_commit") != COMPILE_BINDING_COMMIT
            or metadata.get("compile_binding_sha256") != EXPECTED_COMPILE_BINDING_SHA256
            or metadata.get("compile_evidence_sha256") != EXPECTED_COMPILE_EVIDENCE_SHA256
            or metadata.get("compiled_ex5_sha256") != EXPECTED_COMPILED_EX5_SHA256
            or metadata.get("arm") != arm
            or metadata.get("symbol") != symbol
            or metadata.get("window") != "2017-10-01..2021-12-31"
        ):
            raise PreflightError(f"set metadata drift: {path}")
        result.append(
            {
                "arm": arm,
                "symbol": symbol,
                "timeframe": "M1",
                "magic_slot": int(row["magic_slot"]),
                "binding": binding,
                "inputs": inputs,
            }
        )
    if observed_cells != expected_cells:
        raise PreflightError(f"four-cell closure drift: {sorted(observed_cells)}")
    return sorted(result, key=lambda item: (item["arm"], item["symbol"])), manifest_binding


def validate_source_closure(contract: Mapping[str, Any]) -> dict[str, Any]:
    frozen = contract["frozen_implementation"]
    if (
        frozen.get("source_git_commit") != EXPECTED_SOURCE_COMMIT
        or frozen.get("source_sha256") != EXPECTED_SOURCE_SHA256
        or frozen.get("primary_source_path")
        != "D:/QM/strategy_farm/artifacts/sources/ict_icy_tea_source_20260716/MQL5_Strategie_Spezifikation_some_icy_tea.docx"
        or frozen.get("primary_source_sha256") != EXPECTED_PRIMARY_SOURCE_SHA256
        or frozen.get("source_correction_plan_path")
        != "framework/EAs/QM5_20002_ict-icytea-core/docs/candidate-analysis/source_correction_v3_plan.md"
        or frozen.get("source_correction_plan_git_commit")
        != EXPECTED_SOURCE_CORRECTION_PLAN_COMMIT
        or frozen.get("source_correction_plan_sha256")
        != EXPECTED_SOURCE_CORRECTION_PLAN_SHA256
        or frozen.get("strategy_card_status_at_revision_3") != "intake"
        or frozen.get("approval_claim") != "NONE_RESEARCH_SOURCE_CORRECTION_ONLY"
        or frozen.get("fresh_compile_required") is not True
        or frozen.get("compiled_binary_must_bind_source_manifest") is not True
    ):
        raise PreflightError("frozen implementation closure drift")
    source = file_binding(SOURCE_PATH, EXPECTED_SOURCE_SHA256)
    assert_committed_bytes(EXPECTED_SOURCE_COMMIT, SOURCE_PATH, SOURCE_PATH.read_bytes(), "source")
    card_path = REPO_ROOT / str(frozen["strategy_card_path"])
    brief_path = REPO_ROOT / str(frozen["build_brief_path"])
    card = file_binding(card_path, EXPECTED_STRATEGY_CARD_SHA256)
    brief = file_binding(brief_path, EXPECTED_BUILD_BRIEF_SHA256)
    plan = file_binding(
        SOURCE_CORRECTION_PLAN_PATH, EXPECTED_SOURCE_CORRECTION_PLAN_SHA256
    )
    assert_committed_bytes(
        EXPECTED_SOURCE_CORRECTION_PLAN_COMMIT,
        SOURCE_CORRECTION_PLAN_PATH,
        SOURCE_CORRECTION_PLAN_PATH.read_bytes(),
        "source correction plan",
    )
    primary_source = file_binding(PRIMARY_SOURCE_PATH, EXPECTED_PRIMARY_SOURCE_SHA256)
    return {
        "source": source,
        "strategy_card": card,
        "build_brief": brief,
        "source_correction_plan": plan,
        "primary_source": primary_source,
    }


def _csv_rows(path: Path) -> tuple[list[dict[str, str]], list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        fields = list(reader.fieldnames or [])
        return [dict(row) for row in reader], fields


def decode_compile_log(raw: bytes) -> str:
    if raw.startswith((b"\xff\xfe\x00\x00", b"\x00\x00\xfe\xff")):
        encoding = "utf-32"
    elif raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        encoding = "utf-16"
    else:
        encoding = "utf-8-sig"
    try:
        return raw.decode(encoding)
    except UnicodeDecodeError as exc:
        raise PreflightError(f"compile log encoding unsupported: {encoding}") from exc


def validate_compile_evidence(path: Path, contract: Mapping[str, Any]) -> dict[str, Any]:
    frozen_compile = validate_compile_binding(path)
    evidence_binding = frozen_compile["evidence"]
    evidence = load_json(path)
    bound_payload = frozen_compile["payload"]
    bound_run = bound_payload["compile"]
    if (
        evidence.get("result") != "PASS"
        or evidence.get("errors") != 0
        or evidence.get("warnings") != 0
        or evidence.get("research_status") != "CARD_INTAKE_NOT_APPROVED"
        or evidence.get("contract_commit") != CONTRACT_COMMIT
        or evidence.get("contract_sha256") != EXPECTED_CONTRACT_SHA256
        or evidence.get("source_git_commit") != EXPECTED_SOURCE_COMMIT
        or evidence.get("run_id") != bound_run["run_id"]
    ):
        raise PreflightError("fresh compile evidence is not PASS/0/0")
    if str(evidence.get("source_sha256", "")).lower() != EXPECTED_SOURCE_SHA256:
        raise PreflightError("compile source SHA does not bind frozen MQ5")
    source_evidence_path = Path(str(evidence.get("source_path", ""))).resolve()
    if source_evidence_path != SOURCE_PATH.resolve():
        raise PreflightError("compile source path does not bind repository MQ5")
    finished = parse_utc(str(evidence.get("finished_utc", "")), "compile finished_utc")
    if finished != parse_utc(str(bound_run.get("finished_utc", "")), "bound compile finished_utc"):
        raise PreflightError("compile finished_utc does not match frozen compile binding")
    revision = parse_utc(str(contract["revision_3_created_utc"]), "contract revision_3_created_utc")
    if finished <= revision:
        raise PreflightError("compile is not fresh after contract revision 3")
    if finished > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise PreflightError("compile finished_utc is implausibly in the future")
    git_head = str(evidence.get("git_head_after", ""))
    if not re.fullmatch(r"[0-9a-fA-F]{40}", git_head):
        raise PreflightError("compile evidence git_head_after is missing")
    assert_ancestor(CONTRACT_COMMIT, git_head, "fresh compile ancestry")
    assert_ancestor(EXPECTED_SOURCE_COMMIT, git_head, "frozen source ancestry")

    artifact_fields = {
        "compile_log": ("compile_log_path", "compile_log_sha256"),
        "stage_ex5": ("stage_ex5_path", "ex5_sha256"),
        "repo_ex5": ("repo_ex5_path", "ex5_sha256"),
        "include_sync_manifest": ("include_manifest_path", "include_sync_manifest_sha256"),
        "include_path_audit": ("include_path_audit_path", "include_path_audit_sha256"),
    }
    artifacts: dict[str, Any] = {}
    for role, (path_field, sha_field) in artifact_fields.items():
        raw_path, raw_sha = evidence.get(path_field), evidence.get(sha_field)
        if not raw_path or not raw_sha:
            raise PreflightError(f"compile evidence omitted {path_field}/{sha_field}")
        artifacts[role] = file_binding(Path(str(raw_path)), str(raw_sha))
    source_manifest_path = path.resolve().parent / "source_manifest.csv"
    artifacts["source_manifest"] = file_binding(
        source_manifest_path, str(evidence.get("source_manifest_sha256", ""))
    )
    if Path(artifacts["repo_ex5"]["path"]).resolve() != EX5_PATH.resolve():
        raise PreflightError("compile repo EX5 path drift")
    if artifacts["repo_ex5"]["sha256"] != artifacts["stage_ex5"]["sha256"]:
        raise PreflightError("staged/repository EX5 mismatch")
    if artifacts["repo_ex5"] != frozen_compile["compiled_binary"]:
        raise PreflightError("compile evidence EX5 does not match frozen compile binding")
    for role in ("compile_log", "source_manifest", "include_sync_manifest", "include_path_audit"):
        if artifacts[role] != frozen_compile["closure_artifacts"][role]:
            raise PreflightError(f"compile evidence {role} does not match frozen compile binding")
    compile_log = decode_compile_log(Path(artifacts["compile_log"]["path"]).read_bytes())
    if not re.search(r"Result:\s*0 errors,\s*0 warnings", compile_log, re.IGNORECASE):
        raise PreflightError("compile log lacks exact 0 errors / 0 warnings result")
    source_rows, source_fields = _csv_rows(Path(artifacts["source_manifest"]["path"]))
    if set(source_fields) != {"relative_path", "bytes", "sha256"} or len(source_rows) != 1:
        raise PreflightError("compile source_manifest must bind exactly one MQ5 source")
    source_row = source_rows[0]
    if (
        Path(source_row["relative_path"]).name != SOURCE_PATH.name
        or source_row["sha256"].lower() != EXPECTED_SOURCE_SHA256
        or int(source_row["bytes"]) != SOURCE_PATH.stat().st_size
    ):
        raise PreflightError("compile source_manifest MQ5 identity drift")
    sync_rows, sync_fields = _csv_rows(Path(artifacts["include_sync_manifest"]["path"]))
    required_sync = {"target_include_root", "relative_path", "bytes", "source_sha256", "destination_sha256"}
    if set(sync_fields) != required_sync or not sync_rows:
        raise PreflightError("compile include sync manifest malformed/empty")
    if any(row["source_sha256"].lower() != row["destination_sha256"].lower() for row in sync_rows):
        raise PreflightError("compile include sync manifest contains source/destination drift")
    if int(evidence.get("include_manifest_rows", -1)) != len(sync_rows):
        raise PreflightError("compile include manifest row count drift")
    audit_rows, audit_fields = _csv_rows(Path(artifacts["include_path_audit"]["path"]))
    if set(audit_fields) != {"included_path", "allowed"} or not audit_rows:
        raise PreflightError("compile include path audit malformed/empty")
    if any(row["allowed"].strip().casefold() != "true" for row in audit_rows):
        raise PreflightError("compile used a forbidden include path")
    if int(evidence.get("outside_include_paths_count", -1)) != 0:
        raise PreflightError("compile evidence reports outside include paths")
    if int(evidence.get("active_dev1_processes_after", -1)) != 0:
        raise PreflightError("compile left DEV1 processes active")
    if int(evidence.get("ephemeral_tasks_after", -1)) != 0:
        raise PreflightError("compile left ephemeral tasks active")
    metaeditor = file_binding(
        Path(str(evidence.get("metaeditor_path", ""))), str(evidence.get("metaeditor_sha256", ""))
    )
    compile_one = file_binding(
        Path(str(evidence.get("compile_one_path", ""))),
        str(evidence.get("compile_one_sha256", "")),
    )
    historical_controller = frozen_compile["toolchain"][
        "compile_controller_historical_blob"
    ]
    evidence_controller_path = Path(
        str(evidence.get("compile_controller_path", ""))
    ).resolve()
    evidence_controller_sha = str(evidence.get("compile_controller_sha256", ""))
    if (
        metaeditor != frozen_compile["toolchain"]["metaeditor"]
        or compile_one != frozen_compile["toolchain"]["compile_one"]
        or evidence_controller_path != COMPILE_CONTROLLER_PATH.resolve()
        or evidence_controller_sha != historical_controller["sha256"]
    ):
        raise PreflightError("compile evidence toolchain does not match frozen compile binding")
    return {
        "compile_binding": frozen_compile["document"],
        "evidence": evidence_binding,
        "finished_utc": finished.isoformat(),
        "git_head_after": git_head.lower(),
        "source_sha256": EXPECTED_SOURCE_SHA256,
        "ex5_sha256": artifacts["repo_ex5"]["sha256"],
        "metaeditor": metaeditor,
        "artifacts": artifacts,
    }


def _expected_data_paths() -> list[str]:
    expected = ["symbols.custom.dat"]
    for symbol in sorted(EXPECTED_MARKETS):
        expected.extend(f"Custom\\history\\{symbol}\\{year}.hcc" for year in range(2017, 2022))
        cursor = date(2017, 10, 1)
        while cursor <= date(2021, 12, 1):
            expected.append(f"Custom\\ticks\\{symbol}\\{cursor:%Y%m}.tkc")
            cursor = date(cursor.year + (1 if cursor.month == 12 else 0), 1 if cursor.month == 12 else cursor.month + 1, 1)
    return sorted(expected, key=str.casefold)


def validate_model4_data(contract: Mapping[str, Any], *, hash_actual: bool = True) -> dict[str, Any]:
    bindings = contract["data_bindings"]
    manifest_path = Path(str(bindings["provisioning_manifest"]))
    manifest_binding = file_binding(manifest_path, str(bindings["provisioning_manifest_sha256"]))
    rows, fields = _csv_rows(manifest_path)
    expected_fields = {
        "relative_path", "source_length", "dest_length", "source_sha256", "dest_sha256", "match"
    }
    if set(fields) != expected_fields:
        raise PreflightError("provisioning manifest header drift")
    by_path: dict[str, dict[str, str]] = {}
    for row in rows:
        key = row["relative_path"].replace("/", "\\")
        if key in by_path:
            raise PreflightError(f"duplicate provisioning row: {key}")
        by_path[key] = row
    expected_paths = _expected_data_paths()
    selected: list[dict[str, Any]] = []
    for relative in expected_paths:
        row = by_path.get(relative)
        if row is None:
            raise PreflightError(f"provisioning manifest missing Model-4 input: {relative}")
        if (
            row["match"].strip().casefold() != "true"
            or row["source_length"] != row["dest_length"]
            or row["source_sha256"].lower() != row["dest_sha256"].lower()
            or not re.fullmatch(r"[0-9a-fA-F]{64}", row["dest_sha256"])
        ):
            raise PreflightError(f"provisioning identity mismatch: {relative}")
        destination = DATA_ROOT / Path(relative.replace("\\", os.sep))
        item: dict[str, Any] = {
            "relative_path": relative,
            "bytes": int(row["dest_length"]),
            "sha256": row["dest_sha256"].lower(),
            "destination_path": str(destination.resolve()),
        }
        if hash_actual:
            actual = file_binding(destination, item["sha256"])
            if actual["size"] != item["bytes"]:
                raise PreflightError(f"actual Model-4 file size drift: {destination}")
            item["actual_binding"] = actual
        selected.append(item)
    return {
        "provisioning_manifest": manifest_binding,
        "destination_root": str(DATA_ROOT.resolve()),
        "selected_file_count": len(selected),
        "selected_files": selected,
        "selected_tree_sha256": canonical_sha256(selected),
        "opaque_hash_only_no_market_values_parsed": True,
        "future_months_after_202112_selected": False,
    }


def validate_news_bindings(contract: Mapping[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for row in contract["data_bindings"]["news_calendars"]:
        seed_path = Path(str(row["path"]))
        binding = file_binding(seed_path, str(row["sha256"]))
        # MT5 build 5833+ rejects these absolute drive-letter FileOpen calls.
        # QM_NewsFilter therefore consumes the basename from FILE_COMMON under
        # the scheduled QMDev1 account.  Bind that effective input as well as
        # the D:\ seed and require byte identity before any terminal launch.
        tester_common_path = DEV1_COMMON_FILES_ROOT / seed_path.name
        tester_common_binding = file_binding(tester_common_path, str(row["sha256"]))
        if tester_common_binding["sha256"] != binding["sha256"]:
            raise PreflightError(f"tester FILE_COMMON news mirror drift: {tester_common_path}")
        result.append(
            {
                "role": str(row["role"]),
                "binding": binding,
                "tester_common_binding": tester_common_binding,
                "effective_tester_read": "ABSOLUTE_OR_BYTE_IDENTICAL_FILE_COMMON_FALLBACK",
            }
        )
    return sorted(result, key=lambda item: item["role"])


def _assert_exact_binding_path(
    binding: Mapping[str, Any], expected_path: Path, label: str
) -> dict[str, Any]:
    if set(binding) != {"path", "size", "sha256"}:
        raise AuditError(f"{label} binding field closure drift")
    if Path(str(binding.get("path", ""))).resolve() != expected_path.resolve():
        raise AuditError(f"{label} binding path drift")
    expected_sha = binding.get("sha256")
    if type(expected_sha) is not str or re.fullmatch(r"[0-9a-f]{64}", expected_sha) is None:
        raise AuditError(f"{label} binding SHA-256 is not canonical lowercase")
    assert_binding(binding, label)
    return dict(binding)


def validate_machine_credential_rotation_receipt(
    runtime: Mapping[str, Any], *, now: datetime | None = None
) -> dict[str, Any]:
    """Validate the DEV1 V3 rotation proof without decrypting credential bytes."""

    required_roles = {
        "dev1_lane_contract",
        "dev1_machine_credential",
        "dev1_machine_credential_helper",
        "dev1_identity_probe_child",
        "dev1_machine_credential_rotation_receipt",
    }
    if not required_roles.issubset(runtime) or any(
        not isinstance(runtime.get(role), Mapping) for role in required_roles
    ):
        raise AuditError("DEV1 machine-credential rotation bindings are incomplete")

    receipt_binding = _assert_exact_binding_path(
        runtime["dev1_machine_credential_rotation_receipt"],
        MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH,
        "DEV1 machine-credential rotation receipt",
    )
    credential_binding = _assert_exact_binding_path(
        runtime["dev1_machine_credential"],
        MACHINE_CREDENTIAL_PATH,
        "DEV1 machine credential",
    )
    helper_binding = _assert_exact_binding_path(
        runtime["dev1_machine_credential_helper"],
        CREDENTIAL_HELPER_PATH,
        "DEV1 machine-credential helper",
    )
    child_binding = _assert_exact_binding_path(
        runtime["dev1_identity_probe_child"],
        IDENTITY_PROBE_CHILD_PATH,
        "DEV1 identity-probe child",
    )
    lane_binding = _assert_exact_binding_path(
        runtime["dev1_lane_contract"],
        DEV1_LANE_CONTRACT_PATH,
        "DEV1 lane contract",
    )

    lane = load_strict_json(Path(lane_binding["path"]), "DEV1 lane contract")
    identity = lane.get("identity")
    if (
        type(lane.get("schema_version")) is not int
        or lane.get("schema_version") != 3
        or lane.get("contract_id") != "QM_DEV1_ISOLATED_MT5_LANE_V3"
        or lane.get("lane") != "DEV1"
        or not isinstance(identity, Mapping)
        or identity.get("local_user") != "QMDev1"
        or Path(str(identity.get("profile", ""))).resolve()
        != Path(r"C:\Users\QMDev1").resolve()
        or Path(str(identity.get("credential", ""))).resolve()
        != MACHINE_CREDENTIAL_PATH.resolve()
        or Path(str(identity.get("legacy_credential", ""))).resolve()
        != LEGACY_CREDENTIAL_PATH.resolve()
        or identity.get("credential_format")
        != "QM_DEV1_MACHINE_DPAPI_CREDENTIAL"
        or identity.get("dpapi_scope") != "LocalMachine"
        or identity.get("limited_non_admin") is not True
    ):
        raise AuditError("DEV1 lane machine-credential identity contract drift")

    receipt_path = Path(receipt_binding["path"])
    receipt = load_strict_json(receipt_path, "DEV1 machine-credential rotation receipt")
    expected_receipt_keys = {
        "schema_version",
        "artifact_type",
        "status",
        "completed_utc",
        "contract_id",
        "target_account",
        "target_sid",
        "target_disabled_at_rest",
        "target_password_required_at_rest",
        "machine_credential_path",
        "machine_credential_sha256",
        "machine_credential_generation_id",
        "machine_credential_helper_path",
        "machine_credential_helper_sha256",
        "identity_probe_child_path",
        "identity_probe_child_sha256",
        "identity_probe_result_path",
        "identity_probe_result_sha256",
        "identity_probe_logon_type",
        "identity_probe_run_level",
        "machine_credential_matches_proved_password",
        "published_after_identity_proof",
        "legacy_credential_path",
        "legacy_credential_preserved",
        "cleanup_lease_disarmed",
        "owner_process_count",
        "dev1_root_process_count",
    }
    if set(receipt) != expected_receipt_keys:
        raise AuditError("DEV1 machine-credential rotation receipt field closure drift")
    target_account = str(receipt.get("target_account", ""))
    target_sid = str(receipt.get("target_sid", ""))
    generation_id = str(receipt.get("machine_credential_generation_id", ""))
    if (
        type(receipt.get("schema_version")) is not int
        or receipt.get("schema_version") != 1
        or receipt.get("artifact_type")
        != "QM_DEV1_MACHINE_CREDENTIAL_ROTATION_RECEIPT"
        or receipt.get("status") != "PASS"
        or receipt.get("contract_id") != lane["contract_id"]
        or re.fullmatch(r"[^\\]+\\QMDev1", target_account) is None
        or re.fullmatch(r"S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+", target_sid)
        is None
        or receipt.get("target_disabled_at_rest") is not True
        or receipt.get("target_password_required_at_rest") is not True
        or receipt.get("identity_probe_logon_type") != "Password"
        or receipt.get("identity_probe_run_level") != "Limited"
        or receipt.get("machine_credential_matches_proved_password") is not True
        or receipt.get("published_after_identity_proof") is not True
        or receipt.get("legacy_credential_preserved") is not True
        or receipt.get("cleanup_lease_disarmed") is not True
        or type(receipt.get("owner_process_count")) is not int
        or receipt.get("owner_process_count") != 0
        or type(receipt.get("dev1_root_process_count")) is not int
        or receipt.get("dev1_root_process_count") != 0
        or re.fullmatch(r"[0-9a-f]{32}", generation_id) is None
    ):
        raise AuditError("DEV1 machine-credential rotation receipt proof drift")
    for field in (
        "machine_credential_sha256",
        "machine_credential_helper_sha256",
        "identity_probe_child_sha256",
        "identity_probe_result_sha256",
    ):
        if re.fullmatch(r"[0-9a-f]{64}", str(receipt.get(field, ""))) is None:
            raise AuditError(f"DEV1 rotation receipt {field} is not canonical lowercase")
    if (
        Path(str(receipt.get("machine_credential_path", ""))).resolve()
        != Path(credential_binding["path"]).resolve()
        or receipt.get("machine_credential_sha256") != credential_binding["sha256"]
        or Path(str(receipt.get("machine_credential_helper_path", ""))).resolve()
        != Path(helper_binding["path"]).resolve()
        or receipt.get("machine_credential_helper_sha256") != helper_binding["sha256"]
        or Path(str(receipt.get("identity_probe_child_path", ""))).resolve()
        != Path(child_binding["path"]).resolve()
        or receipt.get("identity_probe_child_sha256") != child_binding["sha256"]
        or Path(str(receipt.get("legacy_credential_path", ""))).resolve()
        != LEGACY_CREDENTIAL_PATH.resolve()
    ):
        raise AuditError("DEV1 machine-credential rotation receipt path/hash drift")

    legacy_binding = file_binding(LEGACY_CREDENTIAL_PATH)
    identity_result_path = Path(str(receipt.get("identity_probe_result_path", ""))).resolve()
    rotation_root = DEV1_CREDENTIAL_ROTATION_ROOT.resolve()
    try:
        result_relative = identity_result_path.relative_to(rotation_root)
    except ValueError as exc:
        raise AuditError("DEV1 identity-probe result escaped credential-rotation root") from exc
    if (
        len(result_relative.parts) != 3
        or re.fullmatch(
            r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", result_relative.parts[0]
        )
        is None
        or result_relative.parts[1:] != ("output", "identity_probe_result.json")
    ):
        raise AuditError("DEV1 identity-probe result path/layout drift")
    identity_result_binding = file_binding(
        identity_result_path, str(receipt["identity_probe_result_sha256"])
    )
    identity_result = load_strict_json(identity_result_path, "DEV1 identity-probe result")
    if set(identity_result) != {
        "schema_version",
        "artifact_type",
        "status",
        "completed_utc",
        "nonce",
        "account",
        "sid",
        "profile",
        "limited_non_admin",
        "request_sha256",
    }:
        raise AuditError("DEV1 identity-probe result field closure drift")
    if (
        type(identity_result.get("schema_version")) is not int
        or identity_result.get("schema_version") != 1
        or identity_result.get("artifact_type") != "QM_DEV1_IDENTITY_PROBE_RESULT"
        or identity_result.get("status") != "PASS"
        or re.fullmatch(r"[0-9a-f]{32}", str(identity_result.get("nonce", "")))
        is None
        or identity_result.get("account") != target_account
        or identity_result.get("sid") != target_sid
        or Path(str(identity_result.get("profile", ""))).resolve()
        != Path(str(identity["profile"])).resolve()
        or identity_result.get("limited_non_admin") is not True
        or re.fullmatch(r"[0-9a-f]{64}", str(identity_result.get("request_sha256", "")))
        is None
    ):
        raise AuditError("DEV1 identity-probe result identity/proof drift")

    identity_request_path = (
        rotation_root
        / result_relative.parts[0]
        / "control"
        / "identity_probe_request.json"
    ).resolve()
    identity_request_binding = file_binding(
        identity_request_path, str(identity_result["request_sha256"])
    )
    identity_request = load_strict_json(identity_request_path, "DEV1 identity-probe request")
    if set(identity_request) != {
        "schema_version",
        "artifact_type",
        "nonce",
        "created_utc",
        "expires_utc",
        "expected_account",
        "expected_sid",
        "expected_profile",
        "expected_task_name",
        "result_path",
    }:
        raise AuditError("DEV1 identity-probe request field closure drift")
    if (
        type(identity_request.get("schema_version")) is not int
        or identity_request.get("schema_version") != 1
        or identity_request.get("artifact_type") != "QM_DEV1_IDENTITY_PROBE_REQUEST"
        or identity_request.get("nonce") != identity_result["nonce"]
        or identity_request.get("expected_account") != target_account
        or identity_request.get("expected_sid") != target_sid
        or Path(str(identity_request.get("expected_profile", ""))).resolve()
        != Path(str(identity["profile"])).resolve()
        or re.fullmatch(
            r"QM_DEV1_SMOKE_[0-9a-f]{32}",
            str(identity_request.get("expected_task_name", "")),
        )
        is None
        or Path(str(identity_request.get("result_path", ""))).resolve()
        != identity_result_path
    ):
        raise AuditError("DEV1 identity-probe request identity/proof drift")

    credential = load_strict_json(Path(credential_binding["path"]), "DEV1 machine credential")
    if set(credential) != {
        "schema_version",
        "artifact_type",
        "contract_id",
        "lane",
        "account",
        "target_sid",
        "host_account_domain_sid",
        "dpapi_scope",
        "text_encoding",
        "generation_id",
        "created_utc",
        "ciphertext_base64",
    }:
        raise AuditError("DEV1 machine-credential envelope field closure drift")
    expected_domain_sid = target_sid.rsplit("-", 1)[0]
    if (
        type(credential.get("schema_version")) is not int
        or credential.get("schema_version") != 1
        or credential.get("artifact_type") != "QM_DEV1_MACHINE_DPAPI_CREDENTIAL"
        or credential.get("contract_id") != lane["contract_id"]
        or credential.get("lane") != "DEV1"
        or credential.get("account") != target_account
        or credential.get("target_sid") != target_sid
        or credential.get("host_account_domain_sid") != expected_domain_sid
        or credential.get("dpapi_scope") != "LocalMachine"
        or credential.get("text_encoding") != "UTF-8"
        or credential.get("generation_id") != generation_id
    ):
        raise AuditError("DEV1 machine-credential envelope identity/scope drift")
    ciphertext_text = str(credential.get("ciphertext_base64", ""))
    try:
        ciphertext = base64.b64decode(ciphertext_text, validate=True)
    except (binascii.Error, ValueError) as exc:
        raise AuditError("DEV1 machine-credential ciphertext is not strict Base64") from exc
    if (
        not 32 <= len(ciphertext) <= 32768
        or base64.b64encode(ciphertext).decode("ascii") != ciphertext_text
    ):
        raise AuditError("DEV1 machine-credential ciphertext encoding/size drift")

    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    credential_created = parse_utc(
        str(credential.get("created_utc", "")), "DEV1 machine credential created_utc"
    )
    request_created = parse_utc(
        str(identity_request.get("created_utc", "")), "DEV1 identity request created_utc"
    )
    request_expires = parse_utc(
        str(identity_request.get("expires_utc", "")), "DEV1 identity request expires_utc"
    )
    identity_completed = parse_utc(
        str(identity_result.get("completed_utc", "")), "DEV1 identity result completed_utc"
    )
    receipt_completed = parse_utc(
        str(receipt.get("completed_utc", "")), "DEV1 rotation receipt completed_utc"
    )
    if (
        not credential_created <= request_created <= identity_completed <= receipt_completed
        or not identity_completed <= request_expires
        or request_expires <= request_created
        or request_expires > request_created + timedelta(minutes=15)
        or receipt_completed > current + timedelta(minutes=5)
    ):
        raise AuditError("DEV1 machine-credential rotation chronology drift")

    for binding, label in (
        (receipt_binding, "DEV1 machine-credential rotation receipt"),
        (credential_binding, "DEV1 machine credential"),
        (helper_binding, "DEV1 machine-credential helper"),
        (child_binding, "DEV1 identity-probe child"),
        (lane_binding, "DEV1 lane contract"),
        (identity_request_binding, "DEV1 identity-probe request"),
        (identity_result_binding, "DEV1 identity-probe result"),
        (legacy_binding, "DEV1 preserved legacy credential"),
    ):
        assert_binding(binding, label)
    return {
        "receipt": receipt_binding,
        "receipt_payload_sha256": canonical_sha256(receipt),
        "machine_credential": credential_binding,
        "machine_credential_payload_sha256": canonical_sha256(credential),
        "machine_credential_helper": helper_binding,
        "identity_probe_child": child_binding,
        "identity_probe_request": identity_request_binding,
        "identity_probe_request_payload_sha256": canonical_sha256(identity_request),
        "identity_probe_result": identity_result_binding,
        "identity_probe_result_payload_sha256": canonical_sha256(identity_result),
        "legacy_credential": legacy_binding,
        "contract_id": lane["contract_id"],
        "target_account": target_account,
        "target_sid": target_sid,
        "generation_id": generation_id,
        "completed_utc": receipt["completed_utc"],
    }


def validate_runtime() -> dict[str, Any]:
    result = {role: file_binding(path) for role, path in RUNTIME_ROLES.items()}
    if result["tester_groups_canonical"]["sha256"] != result["tester_groups_dev1"]["sha256"]:
        raise PreflightError("DEV1 tester groups are not canonical before PRE")
    # credential.clixml is retained only as forensic rotation ancestry.  It is
    # deliberately not a runnable role or a fallback: a legacy-only host fails
    # above because the canonical V3 envelope and receipt are mandatory files.
    if "legacy_credential" in result or any(
        Path(str(item["path"])).resolve() == LEGACY_CREDENTIAL_PATH.resolve()
        for item in result.values()
    ):
        raise PreflightError("legacy DEV1 CLIXML entered the runnable runtime closure")
    return result


def build_plan(
    cells: Sequence[Mapping[str, Any]],
    timeout_seconds: int,
    runtime: Mapping[str, Any],
) -> dict[str, Any]:
    if not 60 <= timeout_seconds <= 28800:
        raise PreflightError("timeout_seconds outside runner contract")
    credential = runtime.get("dev1_machine_credential")
    helper = runtime.get("dev1_machine_credential_helper")
    if not isinstance(credential, Mapping) or not isinstance(helper, Mapping):
        raise PreflightError("DEV1 V3 credential runtime bindings are missing")
    credential_sha = str(credential.get("sha256", ""))
    helper_sha = str(helper.get("sha256", ""))
    if (
        re.fullmatch(r"[0-9a-f]{64}", credential_sha) is None
        or re.fullmatch(r"[0-9a-f]{64}", helper_sha) is None
    ):
        raise PreflightError("DEV1 V3 credential runtime SHA-256 is not canonical")
    plan_cells: list[dict[str, Any]] = []
    maximum_attempts = min(RUNNER_MAXIMUM_ATTEMPTS_CAP, 2 + 2)
    inner_controller_timeout = (
        maximum_attempts * (timeout_seconds + RUNNER_PER_ATTEMPT_OVERHEAD_SECONDS)
        + RUNNER_FINALIZATION_MARGIN_SECONDS
    )
    for cell in cells:
        cell_id = f"{cell['arm']}__{cell['symbol'].replace('.', '_')}__M1"
        runner_arguments = [
            "-EAId", "20002",
            "-EALabel", "QM5_20002_ict-icytea-core",
            "-Symbol", str(cell["symbol"]),
            "-Year", "2017",
            "-FromDate", "2017.10.01",
            "-ToDate", "2021.12.31",
            "-Expert", r"QM\QM5_20002_ict-icytea-core",
            "-Period", "M1",
            "-Runs", "2",
            "-MinTrades", "0",
            "-Model", "4",
            "-TimeoutSeconds", str(timeout_seconds),
            "-ControllerTimeoutSeconds", str(inner_controller_timeout),
            "-SetFile", str(cell["binding"]["path"]),
            "-CommissionPerLot", "0",
            "-CommissionPerSideNative", "0",
            "-TesterCurrencyOverride", "USD",
            "-TesterDepositOverride", "100000",
            "-ExpectedCredentialSha256", credential_sha,
            "-ExpectedHelperSha256", helper_sha,
            "-SmokeMode",
        ]
        plan_cells.append(
            {
                "cell_id": cell_id,
                "arm": cell["arm"],
                "symbol": cell["symbol"],
                "timeframe": "M1",
                "set_binding": cell["binding"],
                "expected_report_inputs": cell["inputs"],
                "duplicates": ["run_01", "run_02"],
                "runner_arguments": runner_arguments,
            }
        )
    plan_cells.sort(key=lambda item: item["cell_id"])
    plan = {
        "cell_count": 4,
        "duplicates_per_cell": 2,
        "total_native_runs": 8,
        "execution": "SEQUENTIAL_SINGLE_DEV1_TERMINAL",
        "model": 4,
        "cells": plan_cells,
    }
    plan["plan_sha256"] = canonical_sha256(plan)
    return plan


def preflight(compile_evidence: Path, timeout_seconds: int = 28800) -> dict[str, Any]:
    contract = load_contract()
    sources = validate_source_closure(contract)
    compile_binding = validate_compile_evidence(compile_evidence, contract)
    cells, set_manifest = validate_sets(contract)
    data = validate_model4_data(contract)
    news = validate_news_bindings(contract)
    runtime = validate_runtime()
    machine_credential_rotation = validate_machine_credential_rotation_receipt(runtime)
    plan = build_plan(cells, timeout_seconds, runtime)
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "outcome_fence": {
            "market_values_parsed": False,
            "native_reports_opened": False,
            "mt5_started": False,
            "data_access": "OPAQUE_SHA256_ONLY",
        },
        "contract": {
            "commit": CONTRACT_COMMIT,
            "binding": file_binding(CONTRACT_PATH, EXPECTED_CONTRACT_SHA256),
        },
        "tool": file_binding(TOOL_PATH),
        "sources": sources,
        "compile": compile_binding,
        "set_manifest": set_manifest,
        "model4_data": data,
        "news_calendars": news,
        "runtime": runtime,
        "machine_credential_rotation": machine_credential_rotation,
        "plan": plan,
    }


def _iter_bindings(value: Any, prefix: str = "receipt") -> Iterable[tuple[str, Mapping[str, Any]]]:
    if isinstance(value, Mapping):
        if set(("path", "size", "sha256")).issubset(value):
            yield prefix, value
            return
        for key, child in value.items():
            yield from _iter_bindings(child, f"{prefix}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from _iter_bindings(child, f"{prefix}[{index}]")


def _validate_pre_semantics(receipt: Mapping[str, Any]) -> None:
    """Rebuild every outcome-blind PRE surface instead of trusting self-described JSON."""

    expected_fence = {
        "market_values_parsed": False,
        "native_reports_opened": False,
        "mt5_started": False,
        "data_access": "OPAQUE_SHA256_ONLY",
    }
    if receipt.get("schema_version") != SCHEMA_VERSION or receipt.get("outcome_fence") != expected_fence:
        raise AuditError("PRE schema/outcome fence drift")
    created = parse_utc(str(receipt.get("created_utc", "")), "PRE created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuditError("PRE created_utc is implausibly in the future")

    contract = load_contract()
    expected_contract = {
        "commit": CONTRACT_COMMIT,
        "binding": file_binding(CONTRACT_PATH, EXPECTED_CONTRACT_SHA256),
    }
    if receipt.get("contract") != expected_contract:
        raise AuditError("PRE contract binding drift")
    expected_tool = file_binding(TOOL_PATH)
    if receipt.get("tool") != expected_tool:
        raise AuditError("PRE tool binding does not identify the executing auditor")

    expected_sources = validate_source_closure(contract)
    if receipt.get("sources") != expected_sources:
        raise AuditError("PRE frozen source/card/brief closure drift")

    compile_receipt = receipt.get("compile")
    if not isinstance(compile_receipt, Mapping):
        raise AuditError("PRE compile receipt missing")
    evidence = compile_receipt.get("evidence")
    if not isinstance(evidence, Mapping) or not evidence.get("path"):
        raise AuditError("PRE compile evidence binding missing")
    expected_compile = validate_compile_evidence(Path(str(evidence["path"])), contract)
    if compile_receipt != expected_compile:
        raise AuditError("PRE fresh compile closure drift")
    expected_cells, expected_set_manifest = validate_sets(contract)
    if receipt.get("set_manifest") != expected_set_manifest:
        raise AuditError("PRE set manifest closure drift")

    stored_data = receipt.get("model4_data")
    if not isinstance(stored_data, Mapping):
        raise AuditError("PRE Model-4 data closure missing")
    expected_data = validate_model4_data(contract, hash_actual=False)
    scalar_keys = {
        "provisioning_manifest",
        "destination_root",
        "selected_file_count",
        "opaque_hash_only_no_market_values_parsed",
        "future_months_after_202112_selected",
    }
    for key in scalar_keys:
        if stored_data.get(key) != expected_data.get(key):
            raise AuditError(f"PRE Model-4 data field drift: {key}")
    selected = stored_data.get("selected_files")
    expected_selected = expected_data["selected_files"]
    if not isinstance(selected, list) or len(selected) != len(expected_selected):
        raise AuditError("PRE Model-4 selected-file closure drift")
    for observed, expected in zip(selected, expected_selected):
        if not isinstance(observed, Mapping):
            raise AuditError("PRE Model-4 selected-file row malformed")
        for key in ("relative_path", "bytes", "sha256", "destination_path"):
            if observed.get(key) != expected.get(key):
                raise AuditError(f"PRE Model-4 selected-file drift: {expected['relative_path']}/{key}")
        actual = observed.get("actual_binding")
        expected_actual = {
            "path": expected["destination_path"],
            "size": expected["bytes"],
            "sha256": expected["sha256"],
        }
        if actual != expected_actual:
            raise AuditError(f"PRE Model-4 actual binding drift: {expected['relative_path']}")
    if stored_data.get("selected_tree_sha256") != canonical_sha256(selected):
        raise AuditError("PRE Model-4 selected-tree SHA drift")

    expected_news = validate_news_bindings(contract)
    if receipt.get("news_calendars") != expected_news:
        raise AuditError("PRE seed/effective news input closure drift")
    expected_runtime = validate_runtime()
    if receipt.get("runtime") != expected_runtime:
        raise AuditError("PRE runtime closure drift")
    expected_rotation = validate_machine_credential_rotation_receipt(expected_runtime)
    if receipt.get("machine_credential_rotation") != expected_rotation:
        raise AuditError("PRE DEV1 machine-credential rotation proof drift")

    plan = receipt.get("plan")
    if not isinstance(plan, Mapping) or not isinstance(plan.get("cells"), list):
        raise AuditError("PRE plan missing/malformed")
    timeouts: set[int] = set()
    for cell in plan["cells"]:
        args = cell.get("runner_arguments") if isinstance(cell, Mapping) else None
        if not isinstance(args, list) or args.count("-TimeoutSeconds") != 1:
            raise AuditError("PRE runner timeout surface malformed")
        if (
            args.count("-ExpectedCredentialSha256") != 1
            or args.count("-ExpectedHelperSha256") != 1
        ):
            raise AuditError("PRE DEV1 V3 credential argument surface malformed")
        index = args.index("-TimeoutSeconds")
        if index + 1 >= len(args):
            raise AuditError("PRE runner timeout value missing")
        timeouts.add(int(args[index + 1]))
        credential_index = args.index("-ExpectedCredentialSha256")
        helper_index = args.index("-ExpectedHelperSha256")
        if (
            credential_index + 1 >= len(args)
            or args[credential_index + 1]
            != expected_runtime["dev1_machine_credential"]["sha256"]
            or helper_index + 1 >= len(args)
            or args[helper_index + 1]
            != expected_runtime["dev1_machine_credential_helper"]["sha256"]
        ):
            raise AuditError("PRE DEV1 V3 credential argument binding drift")
    if len(timeouts) != 1:
        raise AuditError("PRE runner timeouts are not uniform")
    expected_plan = build_plan(expected_cells, next(iter(timeouts)), expected_runtime)
    if plan != expected_plan:
        raise AuditError("PRE exact four-cell/two-duplicate plan drift")


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    binding = file_binding(path, expected_sha256)
    receipt = load_json(path)
    if (
        receipt.get("artifact_type") != "QM5_20002_SHORT_NY_PRE_RECEIPT"
        or receipt.get("status") != "PASS"
        or receipt.get("analysis_id") != ANALYSIS_ID
    ):
        raise AuditError("PRE receipt identity/status drift")
    if receipt.get("contract", {}).get("commit") != CONTRACT_COMMIT:
        raise AuditError("PRE receipt contract commit drift")
    if receipt.get("plan", {}).get("plan_sha256") != canonical_sha256(
        {key: value for key, value in receipt["plan"].items() if key != "plan_sha256"}
    ):
        raise AuditError("PRE plan canonical SHA drift")
    _validate_pre_semantics(receipt)
    for label, item in _iter_bindings(receipt):
        assert_binding(item, label)
    receipt["_receipt_binding"] = binding
    return receipt


def validate_authorization(path: Path, pre_sha256: str) -> dict[str, Any]:
    binding = file_binding(path)
    payload = load_json(path)
    required = {
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": "QM5_20002_4_CELLS_X_2_DUPLICATES_MODEL4",
        "mt5_execution_authorized": True,
    }
    for key, expected in required.items():
        actual = payload.get(key)
        if isinstance(expected, str):
            actual = str(actual).lower() if key.endswith("sha256") else actual
        if actual != expected:
            raise AuthorizationError(f"authorization field drift: {key}")
    if not str(payload.get("authorized_by", "")).strip():
        raise AuthorizationError("authorization lacks authorized_by")
    authorized = parse_utc(str(payload.get("authorized_utc", "")), "authorized_utc")
    if authorized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuthorizationError("authorization timestamp is in the future")
    return {"binding": binding, "payload": payload}


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    powershell = str(pre["runtime"]["powershell_binary"]["path"])
    runner = str(pre["runtime"]["runner_controller"]["path"])
    return [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        runner,
        *[str(item) for item in cell["runner_arguments"]],
    ]


def required_controller_timeout(pre: Mapping[str, Any]) -> int:
    """Keep Python outside the full V3 retry and containment deadline."""

    tester_timeouts: set[int] = set()
    controller_timeouts: set[int] = set()
    for cell in pre["plan"]["cells"]:
        args = cell["runner_arguments"]
        if (
            args.count("-TimeoutSeconds") != 1
            or args.count("-ControllerTimeoutSeconds") != 1
        ):
            raise AuthorizationError("PRE plan has malformed DEV1 V3 timeout arguments")
        tester_timeouts.add(int(args[args.index("-TimeoutSeconds") + 1]))
        controller_timeouts.add(int(args[args.index("-ControllerTimeoutSeconds") + 1]))
    if len(tester_timeouts) != 1 or len(controller_timeouts) != 1:
        raise AuthorizationError("PRE plan has non-uniform DEV1 V3 timeouts")
    runs = int(pre["plan"]["duplicates_per_cell"])
    maximum_attempts = min(RUNNER_MAXIMUM_ATTEMPTS_CAP, runs + 2)
    inner_minimum = (
        maximum_attempts
        * (next(iter(tester_timeouts)) + RUNNER_PER_ATTEMPT_OVERHEAD_SECONDS)
        + RUNNER_FINALIZATION_MARGIN_SECONDS
    )
    if next(iter(controller_timeouts)) != inner_minimum:
        raise AuthorizationError("PRE plan DEV1 controller timeout differs from V3 minimum")
    # run_dev1_smoke owns its bounded task/process/account/cleanup-lease finally.
    # The Python subprocess deadline stays beyond that entire inner deadline.
    return inner_minimum + OUTER_CONTROLLER_CLEANUP_MARGIN_SECONDS


def _parse_last_json(text: str) -> dict[str, Any]:
    decoder = json.JSONDecoder()
    candidates: list[dict[str, Any]] = []
    for match in re.finditer(r"\{", text):
        try:
            value, _ = decoder.raw_decode(text[match.start() :])
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict):
            candidates.append(value)
    if not candidates:
        raise AuditError("runner stdout contains no JSON object")
    return candidates[-1]


def _parse_single_json_envelope(text: str, label: str) -> dict[str, Any]:
    """Accept one complete JSON object and reject banners, trailers, and duplicates."""

    def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        value: dict[str, Any] = {}
        for key, item in pairs:
            if key in value:
                raise ValueError(f"duplicate JSON key: {key}")
            value[key] = item
        return value

    def reject_constant(value: str) -> None:
        raise ValueError(f"non-finite JSON constant: {value}")

    try:
        payload = json.loads(
            text,
            object_pairs_hook=reject_duplicate_keys,
            parse_constant=reject_constant,
        )
    except (json.JSONDecodeError, ValueError) as exc:
        raise PostflightError(
            f"{label} must contain exactly one complete JSON object envelope"
        ) from exc
    if not isinstance(payload, dict):
        raise PostflightError(
            f"{label} must contain exactly one complete JSON object envelope"
        )
    return payload


def validate_dev1_controller_result(
    result: Mapping[str, Any], pre: Mapping[str, Any]
) -> str:
    """Bind one successful V3 controller envelope to the PRE runtime bytes."""

    if set(result) != DEV1_CONTROLLER_RESULT_FIELDS:
        missing = sorted(DEV1_CONTROLLER_RESULT_FIELDS - set(result))
        extra = sorted(set(result) - DEV1_CONTROLLER_RESULT_FIELDS)
        raise AuditError(
            f"DEV1 controller result field closure drift: missing={missing}, extra={extra}"
        )
    if (
        type(result.get("schema_version")) is not int
        or result.get("schema_version") != 2
        or result.get("success") is not True
        or result.get("error_code") is not None
        or result.get("error_message") is not None
        or type(result.get("run_smoke_exit_code")) is not int
        or result.get("run_smoke_exit_code") != 0
    ):
        raise AuditError("DEV1 controller did not return an exact successful V3 result")
    run_id = str(result.get("run_id", ""))
    if re.fullmatch(r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", run_id) is None:
        raise AuditError("DEV1 controller returned a malformed run_id")
    if re.fullmatch(r"[0-9a-f]{32}", str(result.get("nonce", ""))) is None:
        raise AuditError("DEV1 controller returned a malformed nonce")

    runtime = pre.get("runtime")
    if not isinstance(runtime, Mapping):
        raise AuditError("PRE runtime closure is missing from controller validation")
    expected_hashes = {
        "lane_contract_sha256": runtime["dev1_lane_contract"]["sha256"],
        "machine_credential_sha256": runtime["dev1_machine_credential"]["sha256"],
        "machine_credential_helper_sha256": runtime[
            "dev1_machine_credential_helper"
        ]["sha256"],
        "child_sha256": runtime["runner_child"]["sha256"],
        "run_smoke_sha256": runtime["runner_smoke"]["sha256"],
        "cleanup_helper_sha256": runtime["dev1_cleanup_helper"]["sha256"],
    }
    for field, expected in expected_hashes.items():
        actual = result.get(field)
        if (
            type(actual) is not str
            or re.fullmatch(r"[0-9a-f]{64}", actual) is None
            or actual != expected
        ):
            raise AuditError(f"DEV1 controller runtime binding drift: {field}")
    expected_group_sha = runtime["tester_groups_canonical"]["sha256"]
    for field in (
        "tester_groups_post_child_sha256",
        "tester_groups_restored_sha256",
    ):
        actual = result.get(field)
        if (
            type(actual) is not str
            or re.fullmatch(r"[0-9a-f]{64}", actual) is None
            or actual != expected_group_sha
        ):
            raise AuditError(f"DEV1 tester-groups restore binding drift: {field}")

    lane_binding = runtime["dev1_lane_contract"]
    assert_binding(lane_binding, "DEV1 controller lane contract")
    lane = load_strict_json(Path(str(lane_binding["path"])), "DEV1 controller lane contract")
    coordination = lane.get("coordination")
    programs = lane.get("program_sha256")
    actual_programs = result.get("program_sha256")
    if (
        not isinstance(coordination, Mapping)
        or not isinstance(programs, Mapping)
        or not isinstance(actual_programs, Mapping)
        or set(actual_programs) != set(programs)
        or any(
            type(value) is not str or re.fullmatch(r"[0-9a-f]{64}", value) is None
            for value in actual_programs.values()
        )
        or dict(actual_programs) != dict(programs)
    ):
        raise AuditError("DEV1 controller program/lane proof drift")
    rotation = pre.get("machine_credential_rotation")
    if not isinstance(rotation, Mapping):
        raise AuditError("PRE DEV1 rotation proof missing from controller validation")
    if (
        result.get("identity_sid") != rotation.get("target_sid")
        or Path(str(result.get("common_path", ""))).resolve()
        != DEV1_COMMON_FILES_ROOT.parent.resolve()
        or re.fullmatch(
            r"QM_DEV1_SMOKE_[0-9a-f]{32}", str(result.get("expected_task_name", ""))
        )
        is None
        or result.get("controller_mutex") != coordination.get("controller_mutex")
        or Path(str(result.get("tester_groups_canonical_path", ""))).resolve()
        != GROUP_CANONICAL_PATH.resolve()
        or Path(str(result.get("tester_groups_dev1_path", ""))).resolve()
        != GROUP_DEV1_PATH.resolve()
        or result.get("dev1_account_initially_enabled") is not False
        or result.get("dev1_account_enabled_by_controller") is not True
        or result.get("dev1_account_restored_disabled") is not True
        or result.get("cleanup_lease_registered") is not True
        or result.get("cleanup_lease_disarmed") is not True
    ):
        raise AuditError("DEV1 disabled-at-rest controller lifecycle proof drift")
    expected_log = DEV1_RUNS_ROOT / run_id / "output" / "run.log"
    if Path(str(result.get("log_path", ""))).resolve() != expected_log.resolve():
        raise AuditError("DEV1 controller log path escaped the bound run identity")
    started = parse_utc(str(result.get("started_utc", "")), "DEV1 result started_utc")
    finished = parse_utc(str(result.get("finished_utc", "")), "DEV1 result finished_utc")
    if finished < started or finished > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuditError("DEV1 controller result chronology drift")
    _validate_dev1_agent_port_proof(result, pre, lane, started, finished)
    assert_binding(lane_binding, "DEV1 controller lane contract")
    return run_id


def _validate_dev1_agent_port_proof(
    result: Mapping[str, Any],
    pre: Mapping[str, Any],
    lane: Mapping[str, Any],
    started: datetime,
    finished: datetime,
) -> None:
    port_contract = lane.get("agent_port_contract")
    programs = lane.get("program_sha256")
    if (
        not isinstance(port_contract, Mapping)
        or not isinstance(programs, Mapping)
        or port_contract.get("require_runtime_listener_proof") is not True
        or port_contract.get("require_exact_dev1_metatester_path") is not True
        or port_contract.get("require_no_concurrent_overlapping_endpoint_owner")
        is not True
        or port_contract.get("allow_released_baseline_endpoint_reuse") is not True
        or type(port_contract.get("minimum_port")) is not int
        or type(port_contract.get("maximum_port")) is not int
    ):
        raise AuditError("DEV1 lane agent-port contract drift")
    minimum_port = int(port_contract["minimum_port"])
    maximum_port = int(port_contract["maximum_port"])
    if not 1 <= minimum_port <= maximum_port <= 65535:
        raise AuditError("DEV1 lane agent-port range is malformed")

    expected_path = METATESTER_PATH.resolve()
    expected_hash = programs.get("metatester64.exe")
    if type(expected_hash) is not str or re.fullmatch(r"[0-9a-f]{64}", expected_hash) is None:
        raise AuditError("DEV1 lane metatester hash is malformed")
    file_binding(expected_path, expected_hash)
    proof = result.get("agent_port_proof")
    expected_proof_keys = {
        "status",
        "preexisting_port_owner",
        "concurrent_port_owner",
        "exclusivity_semantics",
        "released_baseline_endpoint_reuse_allowed",
        "metatester_path",
        "metatester_sha256",
        "listeners",
    }
    if not isinstance(proof, Mapping) or set(proof) != expected_proof_keys:
        raise AuditError("DEV1 agent-port proof field closure drift")
    listeners = proof.get("listeners")
    if (
        proof.get("status") != "PASS"
        or proof.get("preexisting_port_owner") is not False
        or proof.get("concurrent_port_owner") is not False
        or proof.get("exclusivity_semantics")
        != "NO_CONCURRENT_OVERLAPPING_ENDPOINT_OWNER"
        or proof.get("released_baseline_endpoint_reuse_allowed") is not True
        or Path(str(proof.get("metatester_path", ""))).resolve() != expected_path
        or proof.get("metatester_sha256") != expected_hash
        or not isinstance(listeners, list)
        or not listeners
    ):
        raise AuditError("DEV1 exact-path runtime-exclusive listener proof drift")

    expected_listener_keys = {
        "local_address",
        "local_port",
        "process_id",
        "owner_sid",
        "executable_path",
        "creation_utc",
        "first_observed_utc",
        "preexisting_port_owner",
        "concurrent_port_owner",
        "exclusive_current_owner",
        "current_overlapping_owner_count",
        "baseline_endpoint_was_occupied",
        "released_baseline_owner_count",
    }
    expected_owner_sid = str(result.get("identity_sid", ""))
    rotation = pre.get("machine_credential_rotation")
    if (
        re.fullmatch(r"S-[0-9]+(?:-[0-9]+)+", expected_owner_sid) is None
        or not isinstance(rotation, Mapping)
        or expected_owner_sid != rotation.get("target_sid")
    ):
        raise AuditError("DEV1 listener owner SID/rotation proof drift")
    endpoint_keys: set[tuple[int, int, str]] = set()
    for index, listener in enumerate(listeners):
        if not isinstance(listener, Mapping) or set(listener) != expected_listener_keys:
            raise AuditError(f"DEV1 listener[{index}] field closure drift")
        local_address = str(listener.get("local_address", ""))
        try:
            ipaddress.ip_address(local_address.split("%", 1)[0])
        except ValueError as exc:
            raise AuditError(f"DEV1 listener[{index}] local address is malformed") from exc
        local_port = listener.get("local_port")
        process_id = listener.get("process_id")
        current_count = listener.get("current_overlapping_owner_count")
        released_count = listener.get("released_baseline_owner_count")
        baseline_occupied = listener.get("baseline_endpoint_was_occupied")
        if (
            type(local_port) is not int
            or not minimum_port <= local_port <= maximum_port
            or type(process_id) is not int
            or process_id <= 0
            or listener.get("owner_sid") != expected_owner_sid
            or Path(str(listener.get("executable_path", ""))).resolve() != expected_path
            or listener.get("preexisting_port_owner") is not False
            or listener.get("concurrent_port_owner") is not False
            or listener.get("exclusive_current_owner") is not True
            or type(current_count) is not int
            or current_count != 1
            or type(baseline_occupied) is not bool
            or type(released_count) is not int
            or released_count < 0
            or (baseline_occupied and released_count < 1)
            or (not baseline_occupied and released_count != 0)
        ):
            raise AuditError(f"DEV1 listener[{index}] exclusivity proof drift")
        creation = parse_utc(
            str(listener.get("creation_utc", "")),
            f"DEV1 listener[{index}] creation_utc",
        )
        observed = parse_utc(
            str(listener.get("first_observed_utc", "")),
            f"DEV1 listener[{index}] first_observed_utc",
        )
        if not started - timedelta(seconds=2) <= creation <= observed <= finished + timedelta(
            seconds=5
        ):
            raise AuditError(f"DEV1 listener[{index}] chronology drift")
        endpoint_key = (process_id, local_port, local_address.casefold())
        if endpoint_key in endpoint_keys:
            raise AuditError("DEV1 listener proof contains a duplicate endpoint")
        endpoint_keys.add(endpoint_key)


def _path_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def _runner_duplicate_exit_ok(value: Any) -> bool:
    """Canonical run_smoke records a natural terminal exit as JSON null."""

    return value is None or (type(value) is int and value == 0)


def _find_summary(run_id: str) -> Path:
    root = DEV1_RUNS_ROOT / run_id / "output" / "smoke"
    if not root.is_dir():
        raise AuditError(f"runner smoke root missing: {root}")
    # run_smoke stores evidence under the canonical EA-ID directory (QM5_20002),
    # while older runner revisions used the full EA label.  Accept only those two
    # explicit identities and still require a single, unambiguous summary.
    summaries = sorted(
        summary.resolve()
        for ea_dir in RUNNER_OUTPUT_EA_DIRS
        for summary in (root / ea_dir).glob("*/summary.json")
    )
    if len(summaries) != 1:
        raise AuditError(f"expected one QM5_20002 summary under {root}, found {len(summaries)}")
    return summaries[0]


def _seal_summary_artifacts(summary_path: Path) -> dict[str, Any]:
    """Hash every native run input/output while the detached worker owns the cell."""

    summary_path = summary_path.resolve()
    summary_binding = file_binding(summary_path)
    summary = load_json(summary_path)
    report_dir = Path(str(summary.get("report_dir", ""))).resolve()
    if report_dir != summary_path.parent or not report_dir.is_dir():
        raise AuditError("runner summary/report directory identity drift")
    runs = summary.get("runs")
    if (
        not isinstance(runs, list)
        or any(not isinstance(row, Mapping) for row in runs)
        or [row.get("run") for row in runs] != ["run_01", "run_02"]
    ):
        raise AuditError("runner did not produce exactly the two preregistered duplicates")
    artifacts: list[dict[str, Any]] = []
    for run in runs:
        run_name = str(run["run"])
        if run.get("status") != "OK" or not _runner_duplicate_exit_ok(run.get("exit_code")):
            raise AuditError(f"cannot seal non-OK runner duplicate: {run_name}")
        report_path = Path(str(run.get("report_canonical_path", ""))).resolve()
        log_path = Path(str(run.get("tester_log_path", ""))).resolve()
        ini_path = report_path.parent / "tester.ini"
        for label, path in (("report", report_path), ("tester_log", log_path), ("tester_ini", ini_path)):
            if not _path_within(path, report_dir):
                raise AuditError(f"{run_name} {label} escaped runner report directory: {path}")
        artifacts.append(
            {
                "run": run_name,
                "report": file_binding(report_path),
                "tester_log": file_binding(log_path),
                "tester_ini": file_binding(ini_path),
            }
        )
    return {"summary": summary_binding, "run_artifacts": artifacts}


def _dev1_run_inventory() -> dict[str, Any]:
    """Fingerprint DEV1 run-directory names without opening any outcome file."""

    if not DEV1_RUNS_ROOT.is_dir():
        names: list[str] = []
        exists = False
    else:
        names = sorted(
            entry.name for entry in DEV1_RUNS_ROOT.iterdir() if entry.is_dir()
        )
        exists = True
    return {
        "root": str(DEV1_RUNS_ROOT.resolve()),
        "exists": exists,
        "directory_count": len(names),
        "directory_names_sha256": canonical_sha256(names),
    }


def scheduled_task_name(pre_sha256: str, state_path: Path) -> str:
    digest = canonical_sha256(
        {
            "analysis_id": ANALYSIS_ID,
            "pre_receipt_sha256": pre_sha256.lower(),
            "state_path": str(state_path.resolve()),
        }
    )
    return f"{SCHEDULED_TASK_PREFIX}{digest[:24]}"


def required_scheduled_task_timeout(
    pre: Mapping[str, Any], controller_timeout_seconds: int
) -> int:
    cell_count = int(pre["plan"]["cell_count"])
    seconds = cell_count * controller_timeout_seconds + 3600
    if not 60 <= seconds <= MAX_SCHEDULED_TASK_SECONDS:
        raise AuthorizationError("scheduled-task execution limit outside launcher contract")
    return seconds


def _scheduler_call(
    pre: Mapping[str, Any],
    operation: str,
    job: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    """Invoke the bound scheduler helper and return only its safe metadata."""

    helper = Path(str(pre["runtime"]["scheduled_task_helper"]["path"])).resolve()
    powershell = str(pre["runtime"]["powershell_binary"]["path"])
    command = [
        powershell,
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(helper),
        "-Operation",
        operation,
    ]
    scheduler: Mapping[str, Any] | None = None
    if operation != "Identity":
        if job is None or not isinstance(job.get("scheduler"), Mapping):
            raise AuthorizationError("scheduled-task job contract is missing")
        scheduler = job["scheduler"]
        command.extend(
            [
                "-TaskName",
                str(scheduler["task_name"]),
                "-PythonExe",
                str(pre["runtime"]["python_binary"]["path"]),
                "-ToolPath",
                str(TOOL_PATH),
                "-JobPath",
                str(Path(str(job["state_path"])).with_name("launch_job.json")),
                "-RepoRoot",
                str(REPO_ROOT),
                "-ExecutionLimitSeconds",
                str(scheduler["execution_limit_seconds"]),
            ]
        )
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        timeout=30,
        check=False,
    )
    if completed.returncode != 0:
        raise AuthorizationError(
            f"persisted scheduler {operation!r} failed with exit {completed.returncode}"
        )
    payload = _parse_last_json(completed.stdout)
    if payload.get("operation") != operation:
        raise AuthorizationError("persisted scheduler returned an unexpected operation")
    if operation == "Identity":
        if (
            not str(payload.get("principal_sid", "")).startswith("S-1-")
            or payload.get("logon_type") != "S4U"
            or payload.get("run_level") != "Highest"
        ):
            raise AuthorizationError("persisted scheduler identity contract drift")
    elif operation == "Probe" and scheduler is not None:
        exists = payload.get("exists")
        if type(exists) is not bool or payload.get("task_name") != scheduler["task_name"]:
            raise AuthorizationError("persisted scheduler Probe returned malformed identity")
        if not exists:
            if set(payload) != {"operation", "task_name", "exists"}:
                raise AuthorizationError("absent scheduler Probe field closure drift")
        elif (
            payload.get("principal_sid") != scheduler["principal_sid"]
            or payload.get("logon_type") != "S4U"
            or payload.get("run_level") != "Highest"
            or payload.get("multiple_instances") != "IgnoreNew"
            or int(payload.get("execution_limit_seconds", 0))
            != int(scheduler["execution_limit_seconds"])
        ):
            raise AuthorizationError("existing scheduler Probe task metadata drift")
    elif scheduler is not None:
        if (
            payload.get("task_name") != scheduler["task_name"]
            or payload.get("principal_sid") != scheduler["principal_sid"]
            or payload.get("logon_type") != "S4U"
            or payload.get("run_level") != "Highest"
            or payload.get("multiple_instances") != "IgnoreNew"
            or int(payload.get("execution_limit_seconds", 0))
            != int(scheduler["execution_limit_seconds"])
        ):
            raise AuthorizationError("persisted scheduler task metadata drift")
    return payload


def _validate_launch_job(
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
) -> None:
    _require_exact_fields(job, LAUNCH_JOB_FIELDS, "launch job", AuthorizationError)
    controller_timeout = int(job.get("controller_timeout_seconds", 0))
    scheduler = job.get("scheduler")
    expected_scheduler = {
        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
        "task_name": scheduled_task_name(pre_sha256, state_path),
        "task_path": "\\",
        "principal_sid": str(scheduler.get("principal_sid", ""))
        if isinstance(scheduler, Mapping)
        else "",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": required_scheduled_task_timeout(
            pre, controller_timeout
        ),
        "helper": pre["runtime"]["scheduled_task_helper"],
        "python": pre["runtime"]["python_binary"],
    }
    expected = {
        "schema_version": SCHEMA_VERSION,
        "launcher_revision": LAUNCHER_REVISION,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_JOB",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "tool": pre["tool"],
        "scheduler": expected_scheduler,
    }
    drift = {key: (value, job.get(key)) for key, value in expected.items() if job.get(key) != value}
    if drift:
        raise AuthorizationError(f"persisted launch job identity/plan/tool drift: {sorted(drift)}")
    if (
        type(job.get("created_utc")) is not str
        or type(job.get("controller_timeout_seconds")) is not int
        or type(job.get("pre_receipt_sha256")) is not str
        or re.fullmatch(r"[0-9a-f]{64}", str(job.get("pre_receipt_sha256", ""))) is None
        or not isinstance(job.get("authorization"), Mapping)
        or not isinstance(job.get("tool"), Mapping)
        or not isinstance(job.get("scheduler"), Mapping)
    ):
        raise AuthorizationError("persisted launch job exact field types drift")
    parse_utc(str(job["created_utc"]), "launch job created_utc")
    if not expected_scheduler["principal_sid"].startswith("S-1-"):
        raise AuthorizationError("persisted launch job principal SID is malformed")
    if not required_controller_timeout(pre) <= controller_timeout <= 172800:
        raise AuthorizationError("persisted launch job controller timeout drift")
    baseline = job.get("dev1_runs_before_launch")
    if (
        not isinstance(baseline, Mapping)
        or baseline.get("root") != str(DEV1_RUNS_ROOT.resolve())
        or type(baseline.get("exists")) is not bool
        or type(baseline.get("directory_count")) is not int
        or not re.fullmatch(r"[0-9a-f]{64}", str(baseline.get("directory_names_sha256", "")))
    ):
        raise AuthorizationError("persisted launch job DEV1 inventory is malformed")


def _assert_resume_outcome_fence(
    state: Mapping[str, Any], job: Mapping[str, Any], state_path: Path
) -> None:
    """Allow a retry only when the prior worker could not have produced outcomes."""

    if state.get("launcher_revision") != LAUNCHER_REVISION:
        raise AuthorizationError("legacy launch state is not resumable")
    if state.get("status") not in {"PENDING", "PENDING_RESUME", "RUNNING"}:
        raise AuthorizationError("launch state status is not pre-outcome resumable")
    if state.get("finished_utc") or state.get("terminal") is not None:
        raise AuthorizationError("finished/rejected launch state is not resumable")
    cells = state.get("cells")
    if cells != []:
        raise AuthorizationError("sealed cell outcome exists; resume is forbidden")
    if state.get("active_cell") is not None or state.get("outcome_possible_since_utc") is not None:
        raise AuthorizationError("a cell launch crossed the outcome fence; resume is forbidden")
    try:
        _validate_launch_state_shape(state)
    except AuditError as exc:
        raise AuthorizationError(f"launch state schema is not resumable: {exc}") from exc
    work_root = state_path.resolve().parent / "worker"
    if work_root.exists() and next(work_root.iterdir(), None) is not None:
        raise AuthorizationError("worker artifact tree is non-empty; resume is forbidden")
    if _dev1_run_inventory() != job.get("dev1_runs_before_launch"):
        raise AuthorizationError("DEV1 run inventory changed; resume is forbidden")


def _initial_launch_state(
    pre_path: Path,
    pre_sha256: str,
    job_binding: Mapping[str, Any],
    job: Mapping[str, Any],
) -> dict[str, Any]:
    now = utc_now()
    return {
        "schema_version": SCHEMA_VERSION,
        "launcher_revision": LAUNCHER_REVISION,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_STATE",
        "analysis_id": ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": now,
        "updated_utc": now,
        "started_utc": None,
        "finished_utc": None,
        "worker_pid": None,
        "job": dict(job_binding),
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "authorization": job["authorization"],
        "scheduler": job["scheduler"],
        "resume_count": 0,
        "active_cell": None,
        "outcome_possible_since_utc": None,
        "cells": [],
        "terminal": None,
    }


def _classify_controller_failure(stdout: str, stderr: str) -> str | None:
    """Classify controller bootstrap failures without opening outcome artifacts."""

    if stdout.strip():
        try:
            _parse_last_json(stdout)
        except AuditError:
            return "RUNNER_MALFORMED_STDOUT_NO_JSON"
        return None
    folded = stderr.casefold()
    if "import-clixml" in folded and "cryptographic operation" in folded:
        return "RUNNER_CREDENTIAL_CLIXML_CRYPTOGRAPHIC_FAILURE_BEFORE_JSON"
    return "RUNNER_EMPTY_STDOUT_NO_JSON"


def _new_attempt_context(
    started_utc: str,
    command_sha256: str,
    stdout_path: Path,
    stderr_path: Path,
) -> dict[str, Any]:
    return {
        "attempt_number": 1,
        "started_utc": started_utc,
        "command_sha256": command_sha256,
        "runner_exit_code": None,
        "runner_result": None,
        "stdout": None,
        "stderr": None,
        "summary": None,
        "run_artifacts": [],
        "failure_stage": "OUTCOME_FENCE_PERSISTED",
        "stdout_path": stdout_path.resolve(),
        "stderr_path": stderr_path.resolve(),
        "stdout_text": "",
        "stderr_text": "",
    }


def _complete_cell_record(cell_id: str, context: Mapping[str, Any]) -> dict[str, Any]:
    attempt = {
        "attempt_number": 1,
        "status": "COMPLETE",
        "started_utc": context["started_utc"],
        "finished_utc": utc_now(),
        "command_sha256": context["command_sha256"],
        "outcome_fence_crossed": True,
        "no_resume": True,
        "runner_exit_code": context["runner_exit_code"],
        "runner_result": copy.deepcopy(context["runner_result"]),
        "stdout": copy.deepcopy(context["stdout"]),
        "stderr": copy.deepcopy(context["stderr"]),
        "summary": copy.deepcopy(context["summary"]),
        "run_artifacts": copy.deepcopy(context["run_artifacts"]),
        "failure_stage": None,
        "controller_failure_class": None,
        "error_type": None,
        "error": None,
    }
    _validate_attempt_shape(attempt, f"completed {cell_id} attempt")
    return {"cell_id": cell_id, "status": "COMPLETE", "attempts": [attempt]}


def _bind_existing_stream(path: Any) -> dict[str, Any] | None:
    if not isinstance(path, Path) or not path.is_file():
        return None
    return file_binding(path)


def _rejected_cell_record(
    cell_id: str,
    context: Mapping[str, Any],
    exc: Exception,
    finished_utc: str,
) -> dict[str, Any]:
    stdout_binding = _bind_existing_stream(context.get("stdout_path"))
    stderr_binding = _bind_existing_stream(context.get("stderr_path"))
    stage = str(context.get("failure_stage") or "OUTCOME_FENCE_PERSISTED")
    bound_count = sum(binding is not None for binding in (stdout_binding, stderr_binding))
    if bound_count == 2 and stage in {
        "OUTCOME_FENCE_PERSISTED",
        "RUNNER_RETURNED",
        "RUNNER_STREAMS_PARTIALLY_BOUND",
    }:
        stage = "RUNNER_STREAMS_BOUND"
    elif bound_count == 1 and stage in {"OUTCOME_FENCE_PERSISTED", "RUNNER_RETURNED"}:
        stage = "RUNNER_STREAMS_PARTIALLY_BOUND"
    if stage not in FAILURE_STAGES:
        stage = "OUTCOME_FENCE_PERSISTED"
    stdout_text = context.get("stdout_text")
    stderr_text = context.get("stderr_text")
    controller_class = (
        _classify_controller_failure(stdout_text, stderr_text)
        if isinstance(stdout_text, str) and isinstance(stderr_text, str)
        and isinstance(exc, AuditError)
        and (
            str(exc) == "runner stdout contains no JSON object"
            or "must contain exactly one complete JSON object envelope" in str(exc)
        )
        else None
    )
    exit_code = context.get("runner_exit_code")
    if exit_code is not None and type(exit_code) is not int:
        exit_code = None
    runner_result = context.get("runner_result")
    if not isinstance(runner_result, Mapping):
        runner_result = None
    summary = context.get("summary")
    if summary is not None:
        _validate_binding_shape(summary, f"rejected {cell_id} summary")
    artifacts = context.get("run_artifacts")
    if not isinstance(artifacts, list):
        artifacts = []
    attempt = {
        "attempt_number": 1,
        "status": "REJECT",
        "started_utc": str(context["started_utc"]),
        "finished_utc": finished_utc,
        "command_sha256": str(context["command_sha256"]),
        "outcome_fence_crossed": True,
        "no_resume": True,
        "runner_exit_code": exit_code,
        "runner_result": copy.deepcopy(runner_result),
        "stdout": stdout_binding,
        "stderr": stderr_binding,
        "summary": copy.deepcopy(summary),
        "run_artifacts": copy.deepcopy(artifacts),
        "failure_stage": stage,
        "controller_failure_class": controller_class,
        "error_type": type(exc).__name__,
        "error": str(exc) or repr(exc),
    }
    _validate_attempt_shape(attempt, f"rejected {cell_id} attempt")
    return {"cell_id": cell_id, "status": "REJECT", "attempts": [attempt]}


def _load_launch_state_snapshot(state_path: Path) -> tuple[dict[str, Any], str]:
    """Read one exact launch state and bind the precise bytes used for CAS."""

    state_path = state_path.resolve()
    before = sha256_file(state_path)
    state = load_strict_json(state_path, "launch state")
    after = sha256_file(state_path)
    if before != after:
        raise AuditError("launch state bytes changed during locked snapshot")
    _validate_launch_state_shape(state)
    return state, after


def _assert_worker_owner(
    state: Mapping[str, Any], worker_pid: int, resume_count: int
) -> None:
    if (
        state.get("status") != "RUNNING"
        or state.get("worker_pid") != worker_pid
        or state.get("resume_count") != resume_count
    ):
        raise AuditError("worker owner/generation compare-and-swap drift")


def _persist_owned_worker_transition(
    state_path: Path,
    expected_state: Mapping[str, Any],
    expected_sha256: str,
    next_state: Mapping[str, Any],
    worker_pid: int,
    resume_count: int,
) -> tuple[dict[str, Any], str]:
    """CAS one RUNNING worker transition without crossing the runtime call."""

    with _launch_state_lock(state_path):
        persisted, persisted_sha = _load_launch_state_snapshot(state_path)
        if (
            persisted_sha != expected_sha256
            or canonical_bytes(persisted) != canonical_bytes(expected_state)
        ):
            raise AuditError("worker state byte compare-and-swap drift")
        _assert_worker_owner(persisted, worker_pid, resume_count)
        candidate = copy.deepcopy(dict(next_state))
        _validate_launch_state_shape(candidate)
        _assert_worker_owner(candidate, worker_pid, resume_count)
        for field in (
            "schema_version",
            "launcher_revision",
            "artifact_type",
            "analysis_id",
            "created_utc",
            "started_utc",
            "job",
            "pre_receipt_path",
            "pre_receipt_sha256",
            "authorization",
            "scheduler",
            "resume_count",
        ):
            if candidate[field] != persisted[field]:
                raise AuditError(f"worker transition changed immutable field: {field}")
        old_cells = list(persisted["cells"])
        new_cells = list(candidate["cells"])
        if persisted["active_cell"] is None:
            if (
                candidate["active_cell"] is None
                or new_cells != old_cells
                or candidate["outcome_possible_since_utc"] is None
            ):
                raise AuditError("worker outcome-fence transition is not monotone")
        else:
            if (
                candidate["active_cell"] is not None
                or len(new_cells) != len(old_cells) + 1
                or new_cells[:-1] != old_cells
                or new_cells[-1].get("cell_id") != persisted["active_cell"].get("cell_id")
                or candidate["outcome_possible_since_utc"]
                != persisted["outcome_possible_since_utc"]
            ):
                raise AuditError("worker cell-seal transition is not monotone")
        published_sha = atomic_json(state_path, candidate)
        return candidate, published_sha


def _finalize_worker_complete(
    state_path: Path,
    expected_running_state: Mapping[str, Any],
    expected_sha256: str | None = None,
    expected_worker_pid: int | None = None,
    expected_resume_count: int | None = None,
) -> dict[str, Any]:
    """Publish COMPLETE only when the locked state still equals the caller's view."""

    with _launch_state_lock(state_path):
        persisted, persisted_sha = _load_launch_state_snapshot(state_path)
        if (
            (expected_sha256 is not None and persisted_sha != expected_sha256)
            or canonical_bytes(persisted) != canonical_bytes(expected_running_state)
        ):
            raise AuditError("terminal COMPLETE compare-and-swap state drift")
        owner_pid = (
            int(expected_worker_pid)
            if expected_worker_pid is not None
            else int(expected_running_state.get("worker_pid", 0))
        )
        owner_generation = (
            int(expected_resume_count)
            if expected_resume_count is not None
            else int(expected_running_state.get("resume_count", -1))
        )
        _assert_worker_owner(persisted, owner_pid, owner_generation)
        closed = copy.deepcopy(persisted)
        finished = utc_now()
        closed["status"] = "COMPLETE"
        closed["worker_pid"] = None
        closed["active_cell"] = None
        closed["finished_utc"] = finished
        closed["updated_utc"] = finished
        _validate_launch_state_shape(closed)
        atomic_json(state_path, closed)
        return closed


def _finalize_worker_rejection(
    state_path: Path,
    exc: Exception,
    context: Mapping[str, Any] | None,
    expected_worker_pid: int | None = None,
    expected_resume_count: int | None = None,
) -> bool:
    """Close only a failure still owned by the exact worker generation."""

    with _launch_state_lock(state_path):
        # This re-read is the compare-and-swap boundary.  A COMPLETE publisher
        # that won the lock is immutable; a prior REJECT is likewise terminal.
        persisted, _persisted_sha = _load_launch_state_snapshot(state_path)
        if persisted.get("status") in {"COMPLETE", "REJECT"}:
            return False
        if expected_worker_pid is None or expected_resume_count is None:
            return False
        if (
            persisted.get("status") != "RUNNING"
            or persisted.get("worker_pid") != expected_worker_pid
            or persisted.get("resume_count") != expected_resume_count
        ):
            return False
        if persisted.get("launcher_revision") != LAUNCHER_REVISION:
            raise AuditError("refusing to rewrite a legacy launch state during rejection closure")
        closed = {field: copy.deepcopy(persisted.get(field)) for field in LAUNCH_STATE_FIELDS}
        finished = utc_now()
        active = persisted.get("active_cell")
        if context is None and isinstance(active, Mapping):
            cell_root = state_path.resolve().parent / "worker" / str(active.get("cell_id", ""))
            context = _new_attempt_context(
                str(active.get("started_utc", finished)),
                str(active.get("command_sha256", "")),
                cell_root / "runner.stdout.txt",
                cell_root / "runner.stderr.txt",
            )
        affected_cell_id: str | None = None
        if context is not None and isinstance(active, Mapping):
            cell_id = str(active.get("cell_id", ""))
            if cell_id and all(
                not isinstance(row, Mapping) or row.get("cell_id") != cell_id
                for row in closed.get("cells", [])
            ):
                closed["cells"].append(_rejected_cell_record(cell_id, context, exc, finished))
                affected_cell_id = cell_id
        outcome_crossed = closed.get("outcome_possible_since_utc") is not None
        stage = (
            str(context.get("failure_stage"))
            if context is not None and context.get("failure_stage") in FAILURE_STAGES
            else "WORKER_VALIDATION"
        )
        controller_class = None
        if affected_cell_id is not None:
            rejected_attempt = closed["cells"][-1]["attempts"][0]
            stage = rejected_attempt["failure_stage"]
            controller_class = rejected_attempt["controller_failure_class"]
        closed["status"] = "REJECT"
        closed["worker_pid"] = None
        closed["active_cell"] = None
        closed["finished_utc"] = finished
        closed["updated_utc"] = finished
        closed["terminal"] = {
            "status": "REJECT",
            "error_type": type(exc).__name__,
            "error": str(exc) or repr(exc),
            "failure_stage": stage,
            "affected_cell_id": affected_cell_id,
            "outcome_fence_crossed": outcome_crossed,
            "no_resume": True,
            "controller_failure_class": controller_class,
        }
        _validate_launch_state_shape(closed)
        atomic_json(state_path, closed)
        return True


def _attempt_for_post(cell: Mapping[str, Any]) -> dict[str, Any]:
    attempt = dict(cell["attempts"][0])
    attempt["cell_id"] = cell["cell_id"]
    return attempt


def _worker_run(job_path: Path) -> int:
    state: dict[str, Any] | None = None
    state_path: Path | None = None
    state_sha256: str | None = None
    owner_pid = os.getpid()
    owner_resume_count: int | None = None
    ownership_acquired = False
    failure_context: Mapping[str, Any] | None = {"failure_stage": "WORKER_VALIDATION"}
    try:
        job_path = job_path.resolve()
        job_binding = file_binding(job_path)
        job = load_strict_json(job_path, "launch job")
        state_path = Path(str(job["state_path"])).resolve()
        pre_path = Path(str(job["pre_receipt_path"])).resolve()
        pre_sha = str(job["pre_receipt_sha256"])
        pre = assert_pre_receipt(pre_path, pre_sha)
        _validate_launch_job(job, pre, pre_path, pre_sha, state_path)
        auth_path = Path(str(job["authorization"]["binding"]["path"]))
        if validate_authorization(auth_path, pre_sha) != job["authorization"]:
            raise AuditError("persisted launch authorization drift")
        with _launch_state_lock(state_path):
            persisted, _persisted_sha = _load_launch_state_snapshot(state_path)
            if persisted.get("status") not in {"PENDING", "PENDING_RESUME"}:
                raise AuditError("scheduled worker was not armed by the launcher")
            if (
                persisted.get("job") != job_binding
                or persisted.get("authorization") != job["authorization"]
                or persisted.get("scheduler") != job["scheduler"]
                or Path(str(persisted.get("pre_receipt_path", ""))).resolve() != pre_path
                or str(persisted.get("pre_receipt_sha256", "")).lower() != pre_sha.lower()
            ):
                raise AuditError("persisted launch state/job binding drift")
            _assert_resume_outcome_fence(persisted, job, state_path)
            now = utc_now()
            claimed = copy.deepcopy(persisted)
            claimed["status"] = "RUNNING"
            claimed["worker_pid"] = owner_pid
            claimed["started_utc"] = claimed.get("started_utc") or now
            claimed["updated_utc"] = now
            failure_context = {"failure_stage": "RUNNING_STATE_PERSIST"}
            _validate_launch_state_shape(claimed)
            state_sha256 = atomic_json(state_path, claimed)
            state = claimed
            owner_resume_count = int(claimed["resume_count"])
            ownership_acquired = True

        work_root = state_path.parent / "worker"
        work_root.mkdir(parents=True, exist_ok=True)
        for cell in pre["plan"]["cells"]:
            # Seal all moving inputs again immediately before every terminal cell.
            assert_pre_receipt(pre_path, pre_sha)
            command = runner_command(pre, cell)
            started = utc_now()
            command_sha = canonical_sha256(command)
            cell_root = work_root / str(cell["cell_id"])
            stdout_path = cell_root / "runner.stdout.txt"
            stderr_path = cell_root / "runner.stderr.txt"
            attempt_context = _new_attempt_context(
                started, command_sha, stdout_path, stderr_path
            )
            attempt_context["failure_stage"] = "RUNNING_STATE_PERSIST"
            failure_context = attempt_context
            armed_state = copy.deepcopy(state)
            armed_state["active_cell"] = {
                "cell_id": cell["cell_id"],
                "attempt_number": 1,
                "command_sha256": command_sha,
                "started_utc": started,
                "status": "OUTCOME_POSSIBLE_NO_RESUME",
            }
            armed_state["outcome_possible_since_utc"] = (
                armed_state.get("outcome_possible_since_utc") or started
            )
            armed_state["updated_utc"] = started
            if state_sha256 is None or owner_resume_count is None:
                raise AuditError("worker lost its state CAS binding before outcome fence")
            state, state_sha256 = _persist_owned_worker_transition(
                state_path,
                state,
                state_sha256,
                armed_state,
                owner_pid,
                owner_resume_count,
            )

            attempt_context["failure_stage"] = "OUTCOME_FENCE_PERSISTED"
            cell_root.mkdir(parents=True, exist_ok=True)
            completed = subprocess.run(
                command,
                cwd=REPO_ROOT,
                text=True,
                encoding="utf-8",
                errors="replace",
                capture_output=True,
                timeout=int(job["controller_timeout_seconds"]),
                check=False,
            )
            attempt_context["runner_exit_code"] = completed.returncode
            attempt_context["stdout_text"] = completed.stdout
            attempt_context["stderr_text"] = completed.stderr
            attempt_context["failure_stage"] = "RUNNER_RETURNED"
            stdout_path.write_text(completed.stdout, encoding="utf-8")
            attempt_context["stdout"] = file_binding(stdout_path)
            attempt_context["failure_stage"] = "RUNNER_STREAMS_PARTIALLY_BOUND"
            stderr_path.write_text(completed.stderr, encoding="utf-8")
            attempt_context["stderr"] = file_binding(stderr_path)
            attempt_context["failure_stage"] = "RUNNER_STREAMS_BOUND"
            runner_result = _parse_single_json_envelope(
                completed.stdout, f"{cell['cell_id']} DEV1 controller stdout"
            )
            attempt_context["runner_result"] = runner_result
            attempt_context["failure_stage"] = "RUNNER_RESULT_PARSED"
            if completed.returncode != 0 or runner_result.get("success") is not True:
                raise AuditError(
                    f"runner rejected {cell['cell_id']} with exit {completed.returncode}"
                )
            run_id = validate_dev1_controller_result(runner_result, pre)
            summary_path = _find_summary(run_id)
            attempt_context["summary"] = file_binding(summary_path)
            attempt_context["failure_stage"] = "SUMMARY_BOUND"
            sealed = _seal_summary_artifacts(summary_path)
            attempt_context["summary"] = sealed["summary"]
            attempt_context["run_artifacts"] = sealed["run_artifacts"]
            attempt_context["failure_stage"] = "RUN_ARTIFACTS_BOUND"
            cell_result = _complete_cell_record(str(cell["cell_id"]), attempt_context)
            sealed_state = copy.deepcopy(state)
            sealed_state["cells"].append(cell_result)
            sealed_state["active_cell"] = None
            sealed_state["updated_utc"] = utc_now()
            attempt_context["failure_stage"] = "CELL_STATE_PERSIST"
            if state_sha256 is None or owner_resume_count is None:
                raise AuditError("worker lost its state CAS binding before cell seal")
            state, state_sha256 = _persist_owned_worker_transition(
                state_path,
                state,
                state_sha256,
                sealed_state,
                owner_pid,
                owner_resume_count,
            )
            failure_context = {"failure_stage": "WORKER_VALIDATION"}
        assert_pre_receipt(pre_path, pre_sha)
        failure_context = {"failure_stage": "FINAL_STATE_PERSIST"}
        if state_sha256 is None or owner_resume_count is None:
            raise AuditError("worker lost its state CAS binding before COMPLETE")
        state = _finalize_worker_complete(
            state_path,
            state,
            state_sha256,
            owner_pid,
            owner_resume_count,
        )
        return 0
    except Exception as exc:
        if ownership_acquired and state is not None and state_path is not None:
            try:
                _finalize_worker_rejection(
                    state_path,
                    exc,
                    failure_context,
                    owner_pid,
                    owner_resume_count,
                )
            except Exception as persistence_exc:
                print(
                    f"terminal rejection persistence failed: {type(persistence_exc).__name__}",
                    file=sys.stderr,
                )
        return 2


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    controller_timeout_seconds: int | None,
    *,
    resume: bool = False,
) -> dict[str, Any]:
    pre = assert_pre_receipt(pre_path, pre_sha256)
    authorization = validate_authorization(authorization_path, pre_sha256)
    minimum_timeout = required_controller_timeout(pre)
    if controller_timeout_seconds is None:
        controller_timeout_seconds = minimum_timeout
    if not minimum_timeout <= controller_timeout_seconds <= 172800:
        raise AuthorizationError("controller timeout outside persisted launcher contract")
    task_limit = required_scheduled_task_timeout(pre, controller_timeout_seconds)
    state_path = state_path.resolve()
    job_path = state_path.with_name("launch_job.json")
    response_status: str
    with _launch_state_lock(state_path):
        if resume:
            if not state_path.is_file() or not job_path.is_file():
                raise AuthorizationError("resume requires the existing state and immutable job")
            job = load_strict_json(job_path, "launch job")
            state, state_sha = _load_launch_state_snapshot(state_path)
            _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
            if job.get("authorization") != authorization:
                raise AuthorizationError("resume authorization differs from the immutable launch job")
            if state.get("job") != file_binding(job_path):
                raise AuthorizationError("resume state/job byte binding drift")
            _assert_resume_outcome_fence(state, job, state_path)
            _scheduler_call(pre, "Register", job)
            inspected = _scheduler_call(pre, "Inspect", job)
            if inspected.get("state") == "Running":
                raise AuthorizationError("persisted audit task is still running")
            rechecked, rechecked_sha = _load_launch_state_snapshot(state_path)
            if rechecked_sha != state_sha or canonical_bytes(rechecked) != canonical_bytes(state):
                raise AuthorizationError("resume state changed across scheduler inspection")
            if state["status"] != "PENDING_RESUME":
                pending = copy.deepcopy(state)
                pending["status"] = "PENDING_RESUME"
                pending["worker_pid"] = None
                pending["resume_count"] = int(state["resume_count"]) + 1
                pending["updated_utc"] = utc_now()
                _validate_launch_state_shape(pending)
                atomic_json(state_path, pending)
            started = _scheduler_call(pre, "Start", job)
            response_status = "RESUMED_PERSISTED_TASK"
            task_name = str(job["scheduler"]["task_name"])
            job_sha = sha256_file(job_path)
        else:
            if state_path.exists():
                raise AuthorizationError(f"refusing to replace launch state: {state_path}")
            identity = _scheduler_call(pre, "Identity")
            if job_path.exists():
                # A crash after immutable job publication but before state creation
                # is the sole recoverable PREPARED form.  Prove that no scheduler,
                # worker, or DEV1 side effect occurred before synthesizing state.
                job = load_strict_json(job_path, "prepared launch job")
                _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
                if job.get("authorization") != authorization:
                    raise AuthorizationError("prepared launch authorization drift")
                if job["scheduler"].get("principal_sid") != identity.get("principal_sid"):
                    raise AuthorizationError("prepared launch scheduler identity drift")
                work_root = state_path.parent / "worker"
                if work_root.exists() and next(work_root.iterdir(), None) is not None:
                    raise AuthorizationError("prepared launch has worker side effects")
                if _dev1_run_inventory() != job.get("dev1_runs_before_launch"):
                    raise AuthorizationError("prepared launch has DEV1 side effects")
                probe = _scheduler_call(pre, "Probe", job)
                if probe.get("exists") is not False:
                    raise AuthorizationError("prepared launch already has scheduler side effects")
                job_sha = sha256_file(job_path)
            else:
                task_name = scheduled_task_name(pre_sha256, state_path)
                job = {
                    "schema_version": SCHEMA_VERSION,
                    "launcher_revision": LAUNCHER_REVISION,
                    "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_JOB",
                    "analysis_id": ANALYSIS_ID,
                    "created_utc": utc_now(),
                    "pre_receipt_path": str(pre_path.resolve()),
                    "pre_receipt_sha256": pre_sha256.lower(),
                    "authorization": authorization,
                    "state_path": str(state_path),
                    "controller_timeout_seconds": controller_timeout_seconds,
                    "plan_sha256": pre["plan"]["plan_sha256"],
                    "tool": pre["tool"],
                    "dev1_runs_before_launch": _dev1_run_inventory(),
                    "scheduler": {
                        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
                        "task_name": task_name,
                        "task_path": "\\",
                        "principal_sid": identity["principal_sid"],
                        "logon_type": "S4U",
                        "run_level": "Highest",
                        "multiple_instances": "IgnoreNew",
                        "execution_limit_seconds": task_limit,
                        "helper": pre["runtime"]["scheduled_task_helper"],
                        "python": pre["runtime"]["python_binary"],
                    },
                }
                _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
                probe = _scheduler_call(pre, "Probe", job)
                if probe.get("exists") is not False:
                    raise AuthorizationError("new launch task name is already registered")
                job_sha = atomic_json(job_path, job, replace=False)
            state = _initial_launch_state(pre_path, pre_sha256, file_binding(job_path), job)
            _validate_launch_state_shape(state)
            atomic_json(state_path, state, replace=False)
            _scheduler_call(pre, "Register", job)
            started = _scheduler_call(pre, "Start", job)
            response_status = "LAUNCHED_PERSISTED_TASK"
            task_name = str(job["scheduler"]["task_name"])
    observed = load_strict_json(state_path, "launch state")
    return {
        "status": response_status,
        "task_name": task_name,
        "scheduler_state": started.get("state"),
        "worker_pid": observed.get("worker_pid"),
        "job_path": str(job_path),
        "job_sha256": job_sha,
        "state_path": str(state_path),
        "plan_sha256": pre["plan"]["plan_sha256"],
    }


def _load_report_core(pre: Mapping[str, Any]) -> Any:
    binding = pre["runtime"]["report_html_parser"]
    assert_binding(binding, "report HTML parser")
    path = Path(str(binding["path"]))
    name = f"qm20002_bound_report_core_{binding['sha256'][:12]}"
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise PostflightError("cannot load bound native report parser")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _report_inputs(core: Any, rows: Sequence[Sequence[str]]) -> tuple[list[str], dict[str, str]]:
    start: tuple[int, int] | None = None
    for row_index, row in enumerate(rows):
        for cell_index, cell in enumerate(row):
            if core._norm(cell) in core.FIELD_ALIASES["inputs"]:
                if start is not None:
                    raise PostflightError("multiple report Inputs sections")
                start = (row_index, cell_index)
    if start is None:
        raise PostflightError("report Inputs section missing")
    row_index, cell_index = start
    values = [core._clean_text(value) for value in rows[row_index][cell_index + 1 :] if core._clean_text(value)]
    for row in rows[row_index + 1 :]:
        if row and core._clean_text(row[0]):
            break
        values.extend(core._clean_text(value) for value in row[1:] if core._clean_text(value))
    mapping: dict[str, str] = {}
    for value in values:
        if "=" not in value:
            continue
        key, raw = value.split("=", 1)
        key, raw = key.strip(), raw.strip()
        if not raw:
            continue  # MT5 input-group heading; all 52 frozen inputs are non-empty.
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            continue
        if key in mapping:
            raise PostflightError(f"duplicate report input: {key}")
        mapping[key] = raw
    return values, mapping


def _input_equivalent(expected: str, actual: str) -> bool:
    if expected in {"true", "false"}:
        return actual.casefold() == expected
    try:
        return parse_decimal(expected, "expected input") == parse_decimal(actual, "actual input")
    except AuditError:
        return actual == expected


def _field_after(core: Any, rows: Sequence[Sequence[str]], aliases: Iterable[str]) -> str | None:
    normalized = {core._norm(value) for value in aliases}
    matches: list[str] = []
    for row in rows:
        for index, cell in enumerate(row[:-1]):
            if core._norm(cell) in normalized:
                value = core._clean_text(row[index + 1])
                if value:
                    matches.append(value)
    unique = list(dict.fromkeys(matches))
    if len(unique) > 1:
        raise PostflightError(f"ambiguous report field {sorted(normalized)}: {unique}")
    return unique[0] if unique else None


def _position_trades(fragments: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, dict[str, Any]] = {}
    order: list[str] = []
    for fragment in fragments:
        entry_ids = list(dict.fromkeys(str(value) for value in fragment["entry_deals"]))
        if len(entry_ids) != 1:
            raise PostflightError("candidate close fragment does not map to exactly one opening Deal")
        key = entry_ids[0]
        if key not in grouped:
            order.append(key)
            grouped[key] = {
                "entry_deal": key,
                "symbol": fragment["symbol"],
                "side": fragment["side"],
                "entry_time": min(fragment["entry_times"]),
                "exit_time": fragment["exit_time"],
                "volume": ZERO,
                "raw_net": ZERO,
                "swap": ZERO,
                "external_cost": ZERO,
                "exit_deals": [],
            }
        trade = grouped[key]
        if trade["symbol"] != fragment["symbol"] or trade["side"] != fragment["side"]:
            raise PostflightError("opening Deal maps to inconsistent close fragments")
        trade["exit_time"] = max(trade["exit_time"], fragment["exit_time"])
        trade["volume"] += fragment["volume"]
        trade["raw_net"] += fragment["raw_net"]
        trade["swap"] += fragment["swap"]
        trade["external_cost"] += fragment["external_cost"]
        trade["exit_deals"].append(fragment["exit_deal"])
    return [grouped[key] for key in order]


def audit_native_report(
    report_path: Path,
    expected_symbol: str,
    expected_inputs: Mapping[str, str],
    core: Any,
) -> NativeAudit:
    report_binding = file_binding(report_path)
    rows = core._rows(report_path)
    settings = core._settings_rows(rows)
    expert_raw = str(core._field_value(settings, "expert"))
    expert = core._canonical_expert(expert_raw)
    symbol = str(core._field_value(settings, "symbol")).upper()
    timeframe, from_date, to_date = core._parse_period(str(core._field_value(settings, "period")))
    currency = str(core._field_value(settings, "currency")).upper()
    deposit = core._parse_decimal(str(core._field_value(settings, "deposit")), "Initial Deposit")
    if (
        expert != EXPECTED_EXPERT
        or symbol != expected_symbol
        or timeframe != "M1"
        or from_date.isoformat() != "2017-10-01"
        or to_date.isoformat() != "2021-12-31"
        or currency != "USD"
        or deposit != INITIAL_BALANCE
    ):
        raise PostflightError(
            f"native header drift: expert={expert}, symbol={symbol}, tf={timeframe}, "
            f"window={from_date}..{to_date}, currency={currency}, deposit={deposit}"
        )
    inputs_raw, inputs = _report_inputs(core, settings)
    if set(inputs) != set(expected_inputs):
        raise PostflightError(
            f"report input map is not exact: missing={sorted(set(expected_inputs)-set(inputs))}, "
            f"extra={sorted(set(inputs)-set(expected_inputs))}"
        )
    drift = [key for key in expected_inputs if not _input_equivalent(str(expected_inputs[key]), inputs[key])]
    if drift:
        raise PostflightError(f"report input value drift: {drift}")
    if parse_decimal(inputs["InpQMSimCommissionPerLot"], "InpQMSimCommissionPerLot") != ZERO:
        raise PostflightError("DOUBLE_COUNT_REJECT: simulated commission is not zero")
    if parse_decimal(inputs["qm_ea_id"], "qm_ea_id") != Decimal("20002"):
        raise PostflightError("wrong qm_ea_id in native report")
    quality = _field_after(
        core, settings, ["History Quality", "Qualität der Historie", "Qualitaet der Historie"]
    )
    if quality is None or not re.fullmatch(r"100(?:\.0+)?%\s+real ticks", quality.strip(), re.I):
        raise PostflightError(f"native report is not 100% real ticks: {quality!r}")
    deals = core._parse_deals(rows)
    initial = deals[0]
    if initial.kind != "balance" or initial.direction or initial.symbol:
        raise PostflightError("first Deals row is not the sole initial balance row")
    if initial.commission != ZERO or initial.swap != ZERO:
        raise PostflightError("initial balance Deal has commission/swap")
    if money(initial.profit) != money(deposit) or money(initial.balance) != money(deposit):
        raise PostflightError("initial balance/deposit mismatch")
    running = deposit
    opening_deals = []
    for deal in deals[1:]:
        if not (from_date <= deal.time.date() <= to_date):
            raise PostflightError(f"Deal outside report window: {deal.deal}")
        if deal.symbol != symbol:
            raise PostflightError(f"cross-symbol Deal in single-cell report: {deal.deal}")
        if deal.commission != ZERO:
            raise PostflightError(
                f"DOUBLE_COUNT_REJECT: native Commission on Deal {deal.deal} is {deal.commission}"
            )
        running += deal.raw_net
        if money(running) != money(deal.balance):
            raise PostflightError(f"native balance recurrence drift on Deal {deal.deal}")
        if deal.direction == "in":
            opening_deals.append(deal)
            if deal.kind != "sell":
                raise PostflightError(f"short-only candidate opened non-sell Deal {deal.deal}")
    report_net = core._parse_decimal(
        str(core._field_value(settings, "net_profit")), "Total Net Profit"
    )
    ledger_net = sum((deal.raw_net for deal in deals[1:]), ZERO)
    if money(report_net) != money(ledger_net):
        raise PostflightError("native Total Net Profit/deal-ledger mismatch")
    family = "EURUSD" if symbol == "EURUSD.DWX" else "GBPUSD"
    fragments = core._reconstruct_closes(deals, family)
    trades = _position_trades(fragments)
    if len(opening_deals) != len(trades):
        raise PostflightError("opening Deal / closed position lifecycle mismatch")
    reported_trades_raw = core._field_value(settings, "total_trades", required=False)
    trade_count_basis = "MISSING"
    if reported_trades_raw is not None:
        reported = core._parse_decimal(str(reported_trades_raw), "Total Trades")
        if reported != reported.to_integral_value():
            raise PostflightError("native Total Trades is not an integer")
        if int(reported) == len(trades):
            trade_count_basis = "POSITION_LIFECYCLES"
        elif int(reported) == len(fragments):
            trade_count_basis = "CLOSE_FRAGMENTS"
        else:
            raise PostflightError(
                f"native Total Trades matches neither lifecycles nor close fragments: {reported}"
            )
    canonical_deals = [deal.canonical() for deal in deals]
    deals_sha = canonical_sha256(canonical_deals)
    fingerprint_payload = {
        "expert": expert,
        "symbol": symbol,
        "timeframe": timeframe,
        "from": from_date.isoformat(),
        "to": to_date.isoformat(),
        "deposit": decimal_text(deposit),
        "currency": currency,
        "inputs": dict(sorted(inputs.items())),
        "deals_sha256": deals_sha,
    }
    receipt = {
        "status": "PASS",
        "report": report_binding,
        "header": {
            "expert": expert,
            "symbol": symbol,
            "timeframe": timeframe,
            "from": from_date,
            "to": to_date,
            "deposit": deposit,
            "currency": currency,
            "history_quality": quality,
            "inputs_ordered": inputs_raw,
            "inputs": inputs,
            "parsed_input_count": len(inputs),
        },
        "identity": {
            "canonical_deal_sequence_sha256": deals_sha,
            "run_fingerprint_sha256": canonical_sha256(fingerprint_payload),
        },
        "native_integrity": {
            "commission_exactly_zero": True,
            "simulated_commission_exactly_zero": True,
            "balance_recurrence": "PASS_CENT_EXACT",
            "reported_total_net_profit": money_text(report_net),
            "deal_ledger_net_profit": money_text(ledger_net),
            "reported_total_trades": str(reported_trades_raw),
            "reported_total_trades_basis": trade_count_basis,
            "opening_deals": len(opening_deals),
            "close_fragments": len(fragments),
            "position_lifecycles": len(trades),
        },
    }
    return NativeAudit(receipt=receipt, deals=deals, fragments=fragments, trades=trades)


def _parse_ini(path: Path) -> dict[str, str]:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "cp1252"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    else:
        raise PostflightError(f"tester.ini encoding unsupported: {path}")
    values: dict[str, str] = {}
    section = ""
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith((";", "#")):
            continue
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            continue
        if section != "Tester" or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key in values:
            raise PostflightError(f"duplicate tester.ini key {key}: {path}")
        values[key] = value
    return values


def _nth_sunday(year: int, month: int, nth: int) -> date:
    cursor = date(year, month, 1)
    count = 0
    while True:
        if cursor.weekday() == 6:
            count += 1
            if count == nth:
                return cursor
        cursor += timedelta(days=1)


def _us_dst(utc_value: datetime) -> bool:
    start_day = _nth_sunday(utc_value.year, 3, 2)
    end_day = _nth_sunday(utc_value.year, 11, 1)
    start = datetime(utc_value.year, 3, start_day.day, 7)
    end = datetime(utc_value.year, 11, end_day.day, 6)
    return start <= utc_value < end


def broker_to_utc(broker: datetime) -> datetime:
    standard = broker - timedelta(hours=2)
    dst = broker - timedelta(hours=3)
    if not _us_dst(standard):
        return standard
    if _us_dst(dst):
        return dst
    return standard


def broker_to_new_york(broker: datetime) -> datetime:
    utc_value = broker_to_utc(broker)
    return utc_value - timedelta(hours=4 if _us_dst(utc_value) else 5)


def _parse_news_time(value: str) -> datetime | None:
    normalized = value.strip().replace("T", " ").rstrip("Z").replace("/", ".").replace("-", ".")
    for fmt in ("%Y.%m.%d %H:%M:%S", "%Y.%m.%d %H:%M", "%Y.%m.%d"):
        try:
            return datetime.strptime(normalized, fmt)
        except ValueError:
            continue
    return None


def load_news_events(news_bindings: Sequence[Mapping[str, Any]]) -> dict[str, Any]:
    events: list[tuple[datetime, str, str]] = []
    source_counts: dict[str, int] = {}
    skipped_counts: dict[str, int] = {}
    for item in news_bindings:
        seed_binding = item.get("binding")
        binding = item.get("tester_common_binding")
        if not isinstance(seed_binding, Mapping) or not isinstance(binding, Mapping):
            raise PostflightError("news seed/effective tester binding missing")
        assert_binding(seed_binding, f"{item['role']} seed")
        assert_binding(binding, str(item["role"]))
        if seed_binding.get("sha256") != binding.get("sha256"):
            raise PostflightError(f"news seed/effective tester bytes drift: {item['role']}")
        path = Path(str(binding["path"]))
        added = skipped = 0
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fields = {str(field).strip().casefold(): str(field) for field in (reader.fieldnames or [])}
            dt_key = next((fields[key] for key in ("datetime_utc", "utc_datetime", "datetime") if key in fields), None)
            date_key = fields.get("date")
            time_key = fields.get("time_utc") or fields.get("time")
            currency_key = fields.get("currency")
            impact_key = fields.get("impact")
            if (dt_key is None and date_key is None) or currency_key is None or impact_key is None:
                raise PostflightError(f"news CSV header unsupported: {path}")
            for row in reader:
                raw_time = str(row.get(dt_key, "")) if dt_key else str(row.get(date_key, ""))
                if not dt_key and time_key:
                    raw_time += " " + str(row.get(time_key, ""))
                event_time = _parse_news_time(raw_time)
                if event_time is None:
                    skipped += 1
                    continue
                impact_raw = str(row.get(impact_key, "")).strip().upper()
                impact = "HIGH" if ("HIGH" in impact_raw or "RED" in impact_raw) else "OTHER"
                currency = str(row.get(currency_key, "")).strip().strip('"').upper()
                events.append((event_time, currency, impact))
                added += 1
        source_counts[str(item["role"])] = added
        skipped_counts[str(item["role"])] = skipped
    events.sort(key=lambda row: row[0])
    if not events or events[0][0].date() > date(2017, 9, 30) or events[-1][0].date() < date(2022, 1, 1):
        raise PostflightError("bound news union does not cover the tester window")
    return {
        "events": events,
        "times": [row[0] for row in events],
        "source_rows": source_counts,
        "skipped_rows_like_mql": skipped_counts,
    }


def _news_affects(currency: str, symbol: str) -> bool:
    if not currency or currency == "ALL":
        return True
    normalized = symbol.split(".", 1)[0].upper()
    return normalized[:3] in currency or normalized[3:6] in currency


def news_blackout(news: Mapping[str, Any], utc_value: datetime, symbol: str) -> bool:
    times: Sequence[datetime] = news["times"]
    events: Sequence[tuple[datetime, str, str]] = news["events"]
    start = bisect.bisect_left(times, utc_value - timedelta(minutes=30))
    end = bisect.bisect_right(times, utc_value + timedelta(minutes=30))
    return any(
        impact == "HIGH" and _news_affects(currency, symbol)
        for _, currency, impact in events[start:end]
    )


def _validate_opening_fills(audit: NativeAudit, symbol: str, news: Mapping[str, Any]) -> dict[str, Any]:
    violations: list[dict[str, Any]] = []
    per_day: dict[str, int] = defaultdict(int)
    openings = [deal for deal in audit.deals if deal.direction == "in"]
    for deal in openings:
        ny = broker_to_new_york(deal.time)
        utc_value = broker_to_utc(deal.time)
        day_key = ny.date().isoformat()
        per_day[day_key] += 1
        reasons: list[str] = []
        if not (7 <= ny.hour < 10):
            reasons.append("OUTSIDE_NY_07_10")
        if news_blackout(news, utc_value, symbol):
            reasons.append("INSIDE_BOUND_NEWS_BLACKOUT_UNION")
        if reasons:
            violations.append(
                {
                    "deal": deal.deal,
                    "broker_time": deal.time,
                    "utc_time": utc_value,
                    "new_york_time": ny,
                    "reasons": reasons,
                }
            )
    for day_key, count in sorted(per_day.items()):
        if count > 2:
            violations.append({"new_york_day": day_key, "opening_deals": count, "reasons": ["MAX_TRADES_PER_KZ_EXCEEDED"]})
    if violations:
        raise PostflightError(f"INVALID opening-fill semantics for {symbol}: {_jsonable(violations)}")
    return {
        "status": "PASS",
        "opening_deals": len(openings),
        "all_inside_ny_07_10": True,
        "all_outside_both_calendar_blackouts": True,
        "maximum_opening_deals_per_ny_day": max(per_day.values(), default=0),
    }


def _validate_ini(values: Mapping[str, str], cell: Mapping[str, Any], run_name: str) -> None:
    expected = {
        "Expert": r"QM\QM5_20002_ict-icytea-core",
        "Symbol": str(cell["symbol"]),
        "Period": "M1",
        "Model": "4",
        "ExecutionMode": "0",
        "Optimization": "0",
        "FromDate": "2017.10.01",
        "ToDate": "2021.12.31",
        "Deposit": "100000",
        "Currency": "USD",
        "Leverage": "100",
        "Visual": "0",
        "ShutdownTerminal": "1",
    }
    drift = {key: (wanted, values.get(key)) for key, wanted in expected.items() if values.get(key) != wanted}
    if drift:
        raise PostflightError(f"tester.ini drift {cell['cell_id']}/{run_name}: {drift}")


def _expected_runner_summary(cell: Mapping[str, Any]) -> dict[str, Any]:
    return {
        "result": "PASS",
        "ea_id": 20002,
        "ea_label": RUNNER_OUTPUT_EA_DIRS[0],
        "expert": rf"QM\{EXPECTED_EXPERT}",
        "symbol": cell["symbol"],
        "terminal": "DEV1",
        "model": 4,
        "period": "M1",
        "requested_runs": 2,
        "deterministic": True,
        "oninit_failure_detected": False,
        "log_bomb_detected": False,
        "model4_log_marker_detected": True,
    }


def audit_cell(
    pre: Mapping[str, Any],
    cell: Mapping[str, Any],
    launch_cell: Mapping[str, Any],
    core: Any,
    news: Mapping[str, Any],
) -> tuple[dict[str, Any], NativeAudit]:
    if launch_cell.get("cell_id") != cell["cell_id"]:
        raise PostflightError(f"launch cell identity drift: {cell['cell_id']}")
    expected_command_sha = canonical_sha256(runner_command(pre, cell))
    if launch_cell.get("command_sha256") != expected_command_sha:
        raise PostflightError(f"bound runner command drift: {cell['cell_id']}")
    runner_result = launch_cell.get("runner_result")
    if not isinstance(runner_result, Mapping) or runner_result.get("success") is not True:
        raise PostflightError(f"runner result is not successful: {cell['cell_id']}")
    try:
        run_id = validate_dev1_controller_result(runner_result, pre)
    except AuditError as exc:
        raise PostflightError(str(exc)) from exc
    assert_binding(launch_cell["summary"], f"{cell['cell_id']} summary")
    summary_path = Path(str(launch_cell["summary"]["path"]))
    if summary_path.resolve() != _find_summary(run_id):
        raise PostflightError(f"runner run_id/summary path drift: {cell['cell_id']}")
    summary = load_json(summary_path)
    expected_summary = _expected_runner_summary(cell)
    drift = {key: (wanted, summary.get(key)) for key, wanted in expected_summary.items() if summary.get(key) != wanted}
    if drift:
        raise PostflightError(f"runner summary drift {cell['cell_id']}: {drift}")
    news_diag = summary.get("news_calendar")
    expected_seed_paths = {
        Path(str(item["binding"]["path"])).resolve() for item in pre["news_calendars"]
    }
    observed_seed_paths: set[Path] = set()
    if isinstance(news_diag, Mapping):
        for key in ("primary_path", "secondary_path"):
            if news_diag.get(key):
                observed_seed_paths.add(Path(str(news_diag[key])).resolve())
    if (
        not isinstance(news_diag, Mapping)
        or news_diag.get("status") != "OK"
        or news_diag.get("missing_paths")
        or observed_seed_paths != expected_seed_paths
    ):
        raise PostflightError(f"runner seed-news diagnostics drift: {cell['cell_id']}")
    commission = summary.get("commission_group", {})
    if (
        Decimal(str(commission.get("commission_per_lot", -1))) != ZERO
        or Decimal(str(commission.get("commission_per_side_native", -1))) != ZERO
        or commission.get("restored_to_canonical") is not True
        or str(commission.get("canonical_sha256", "")).lower()
        != pre["runtime"]["tester_groups_canonical"]["sha256"]
        or str(commission.get("restored_sha256", "")).lower()
        != pre["runtime"]["tester_groups_canonical"]["sha256"]
    ):
        raise PostflightError(f"native commission/group restore evidence drift: {cell['cell_id']}")
    runs = summary.get("runs")
    if (
        not isinstance(runs, list)
        or any(not isinstance(row, Mapping) for row in runs)
        or [row.get("run") for row in runs] != ["run_01", "run_02"]
    ):
        raise PostflightError(f"duplicate run closure drift: {cell['cell_id']}")
    artifacts = launch_cell.get("run_artifacts")
    if (
        not isinstance(artifacts, list)
        or any(not isinstance(row, Mapping) for row in artifacts)
        or [row.get("run") for row in artifacts] != ["run_01", "run_02"]
    ):
        raise PostflightError(f"sealed duplicate artifact closure drift: {cell['cell_id']}")
    artifact_by_run = {str(row["run"]): row for row in artifacts}
    native_audits: list[NativeAudit] = []
    run_receipts: list[dict[str, Any]] = []
    for run in runs:
        run_name = str(run["run"])
        if (
            run.get("status") != "OK"
            or not _runner_duplicate_exit_ok(run.get("exit_code"))
            or run.get("real_ticks_marker") is not True
        ):
            raise PostflightError(f"runner duplicate is not OK/Model4: {cell['cell_id']}/{run_name}")
        report_path = Path(str(run.get("report_canonical_path", ""))).resolve()
        log_path = Path(str(run.get("tester_log_path", ""))).resolve()
        report_dir = Path(str(summary.get("report_dir", ""))).resolve()
        if not _path_within(report_path, report_dir) or not _path_within(log_path, report_dir):
            raise PostflightError(f"run artifact escaped report directory: {cell['cell_id']}/{run_name}")
        ini_path = report_path.parent / "tester.ini"
        sealed = artifact_by_run[run_name]
        for label in ("report", "tester_log", "tester_ini"):
            if not isinstance(sealed.get(label), Mapping):
                raise PostflightError(f"sealed {label} binding missing: {cell['cell_id']}/{run_name}")
            assert_binding(sealed[label], f"{cell['cell_id']}/{run_name}/{label}")
        if (
            Path(str(sealed["report"]["path"])).resolve() != report_path
            or Path(str(sealed["tester_log"]["path"])).resolve() != log_path
            or Path(str(sealed["tester_ini"]["path"])).resolve() != ini_path.resolve()
        ):
            raise PostflightError(f"summary/sealed artifact path drift: {cell['cell_id']}/{run_name}")
        ini_binding = dict(sealed["tester_ini"])
        ini_values = _parse_ini(ini_path)
        _validate_ini(ini_values, cell, run_name)
        log_binding = dict(sealed["tester_log"])
        log_text = log_path.read_text(encoding="utf-8-sig", errors="replace")
        if MODEL4_MARKER not in log_text.casefold():
            raise PostflightError(f"raw tester log lacks Model-4 marker: {cell['cell_id']}/{run_name}")
        if re.search(r"OnInit.*(?:failed|error)|INIT_FAILED", log_text, re.I):
            raise PostflightError(f"raw tester log contains OnInit failure: {cell['cell_id']}/{run_name}")
        native = audit_native_report(
            report_path,
            str(cell["symbol"]),
            {str(key): str(value) for key, value in cell["expected_report_inputs"].items()},
            core,
        )
        fill = _validate_opening_fills(native, str(cell["symbol"]), news)
        native_audits.append(native)
        run_receipts.append(
            {
                "run": run_name,
                "tester_ini": ini_binding,
                "tester_log": log_binding,
                "model4_log_marker": True,
                "native_report_audit": native.receipt,
                "opening_fill_integrity": fill,
            }
        )
    baseline, duplicate = native_audits
    if (
        baseline.receipt["identity"]["canonical_deal_sequence_sha256"]
        != duplicate.receipt["identity"]["canonical_deal_sequence_sha256"]
        or baseline.receipt["identity"]["run_fingerprint_sha256"]
        != duplicate.receipt["identity"]["run_fingerprint_sha256"]
    ):
        raise PostflightError(f"duplicate Deal sequence drift: {cell['cell_id']}")
    return (
        {
            "cell_id": cell["cell_id"],
            "arm": cell["arm"],
            "symbol": cell["symbol"],
            "summary": launch_cell["summary"],
            "duplicate_deal_sequence_check": "PASS_EXACT",
            "runs": run_receipts,
        },
        baseline,
    )


def _scenario_net(row: Mapping[str, Any], points: int) -> Decimal:
    slippage = Decimal(2 * points) * Decimal(row["volume"]) * POINT_VALUE_USD_PER_LOT
    return Decimal(row["raw_net"]) - Decimal(row["external_cost"]) - slippage


def profit_factor(values: Sequence[Decimal]) -> tuple[Decimal | None, str]:
    gross_profit = sum((max(value, ZERO) for value in values), ZERO)
    gross_loss = sum((min(value, ZERO) for value in values), ZERO)
    if gross_loss < ZERO:
        return gross_profit / -gross_loss, "FINITE"
    if gross_profit > ZERO:
        return None, "INFINITE_NO_LOSSES"
    return None, "UNDEFINED"


def _pf_pass(value: Decimal | None, state: str, floor: Decimal) -> bool:
    return state == "INFINITE_NO_LOSSES" or (value is not None and value >= floor)


def _scenario_metrics(trades: Sequence[Mapping[str, Any]], points: int) -> dict[str, Any]:
    values = [_scenario_net(row, points) for row in trades]
    pf, state = profit_factor(values)
    return {
        "slippage_points_per_side": points,
        "closed_trades": len(values),
        "net_usd": money_text(sum(values, ZERO)),
        "gross_profit_usd": money_text(sum((max(value, ZERO) for value in values), ZERO)),
        "gross_loss_usd": money_text(sum((min(value, ZERO) for value in values), ZERO)),
        "profit_factor": None if pf is None else decimal_text(pf),
        "profit_factor_state": state,
    }


def _adjudicate_arm(
    arm: str,
    audits: Sequence[tuple[str, NativeAudit]],
    merit: Mapping[str, Any],
) -> dict[str, Any]:
    trades: list[dict[str, Any]] = []
    fragments: list[dict[str, Any]] = []
    swap_failures: list[str] = []
    for symbol, audit in audits:
        for trade in audit.trades:
            trades.append({**trade, "symbol": symbol})
            entry_ny = broker_to_new_york(trade["entry_time"]).date()
            exit_ny = broker_to_new_york(trade["exit_time"]).date()
            if entry_ny != exit_ny or Decimal(trade["swap"]) != ZERO:
                swap_failures.append(str(trade["entry_deal"]))
        for fragment in audit.fragments:
            fragments.append({**fragment, "symbol": symbol})
    scenarios = {str(points): _scenario_metrics(trades, points) for points in (0, 2, 5)}
    center_values = [_scenario_net(row, 2) for row in trades]
    adverse_values = [_scenario_net(row, 5) for row in trades]
    center_pf, center_state = profit_factor(center_values)
    adverse_pf, adverse_state = profit_factor(adverse_values)
    by_symbol: dict[str, list[dict[str, Any]]] = defaultdict(list)
    by_year: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for trade in trades:
        by_symbol[str(trade["symbol"])].append(trade)
        by_year[trade["exit_time"].year].append(trade)
    symbol_metrics: dict[str, Any] = {}
    for symbol in sorted(EXPECTED_MARKETS):
        rows = by_symbol[symbol]
        values = [_scenario_net(row, 2) for row in rows]
        pf, state = profit_factor(values)
        symbol_metrics[symbol] = {
            "trades": len(rows),
            "net_usd": money_text(sum(values, ZERO)),
            "profit_factor": None if pf is None else decimal_text(pf),
            "profit_factor_state": state,
        }
    years = [2018, 2019, 2020, 2021]
    year_net = {
        str(year): sum((_scenario_net(row, 2) for row in by_year[year]), ZERO) for year in years
    }
    positive_years = sum(value > ZERO for value in year_net.values())
    best_year = max(years, key=lambda year: year_net[str(year)])
    leave_best_year_net = sum(center_values, ZERO) - year_net[str(best_year)]
    best_five = sorted(center_values, reverse=True)[:5]
    leave_best_five_net = sum(center_values, ZERO) - sum(best_five, ZERO)

    ordered_fragments = sorted(
        fragments, key=lambda row: (row["exit_time"], str(row["symbol"]), int(row["sequence"]))
    )
    balance = peak = INITIAL_BALANCE
    max_dd_pct = ZERO
    daily: dict[str, Decimal] = defaultdict(Decimal)
    for fragment in ordered_fragments:
        value = _scenario_net(fragment, 2)
        balance += value
        peak = max(peak, balance)
        if peak > ZERO:
            max_dd_pct = max(max_dd_pct, (peak - balance) / peak * Decimal("100"))
        day_key = broker_to_new_york(fragment["exit_time"]).date().isoformat()
        daily[day_key] += value
    worst_day_loss_pct = (
        max((max(-value, ZERO) for value in daily.values()), default=ZERO)
        / INITIAL_BALANCE
        * Decimal("100")
    )
    gates = {
        "minimum_pooled_closed_trades": len(trades) >= int(merit["minimum_pooled_closed_trades"]),
        "minimum_closed_trades_per_symbol": all(
            symbol_metrics[symbol]["trades"] >= int(merit["minimum_closed_trades_per_symbol"])
            for symbol in EXPECTED_MARKETS
        ),
        "center_cost_adjusted_profit_factor": _pf_pass(
            center_pf, center_state, Decimal(str(merit["center_cost_adjusted_profit_factor_min"]))
        ),
        "adverse_cost_adjusted_profit_factor": _pf_pass(
            adverse_pf, adverse_state, Decimal(str(merit["adverse_cost_adjusted_profit_factor_min"]))
        ),
        "minimum_positive_full_calendar_years": positive_years
        >= int(merit["minimum_positive_full_calendar_years"]),
        "each_symbol_net_positive_center": all(
            Decimal(symbol_metrics[symbol]["net_usd"]) > ZERO for symbol in EXPECTED_MARKETS
        ),
        "each_symbol_profit_factor_min_center": all(
            _pf_pass(
                None
                if symbol_metrics[symbol]["profit_factor"] is None
                else Decimal(symbol_metrics[symbol]["profit_factor"]),
                symbol_metrics[symbol]["profit_factor_state"],
                Decimal(str(merit["each_symbol_profit_factor_min_center"])),
            )
            for symbol in EXPECTED_MARKETS
        ),
        "leave_best_year_out_net_positive_center": leave_best_year_net > ZERO,
        "leave_best_five_trades_out_net_positive_center": len(trades) >= 5 and leave_best_five_net > ZERO,
        "maximum_closed_balance_drawdown_percent": max_dd_pct
        <= Decimal(str(merit["maximum_closed_balance_drawdown_percent"])),
        "maximum_single_ny_day_loss_percent_initial_balance": worst_day_loss_pct
        <= Decimal(str(merit["maximum_single_ny_day_loss_percent_initial_balance"])),
        "zero_overnight_swap_or_exact_swap_cost_proof": not swap_failures,
        "duplicate_deal_sequence_must_match": True,
    }
    return {
        "arm": arm,
        "status": "PASS" if all(gates.values()) else "FAIL",
        "gates": gates,
        "scenarios": scenarios,
        "symbols_center": symbol_metrics,
        "full_calendar_year_net_center_usd": {key: money_text(value) for key, value in year_net.items()},
        "positive_full_calendar_years": positive_years,
        "leave_best_year": best_year,
        "leave_best_year_out_net_center_usd": money_text(leave_best_year_net),
        "leave_best_five_trades_out_net_center_usd": money_text(leave_best_five_net),
        "maximum_closed_balance_drawdown_percent_center": decimal_text(max_dd_pct),
        "maximum_single_ny_day_loss_percent_initial_balance_center": decimal_text(worst_day_loss_pct),
        "swap_proof": {
            "status": "PASS_ZERO_SAME_NY_DAY" if not swap_failures else "FAIL_EXACT_SWAP_PROOF_REQUIRED",
            "violating_entry_deals": swap_failures,
        },
    }


def _is_legacy_rev2_stdout_lifecycle_defect(state: Mapping[str, Any]) -> bool:
    active = state.get("active_cell")
    return bool(
        set(state) == LEGACY_REV2_REJECT_FIELDS
        and state.get("schema_version") == SCHEMA_VERSION
        and state.get("launcher_revision") == 2
        and state.get("artifact_type") == "QM5_20002_SHORT_NY_LAUNCH_STATE"
        and state.get("analysis_id") == ANALYSIS_ID
        and state.get("status") == "REJECT"
        and type(state.get("worker_pid")) is int
        and state["worker_pid"] > 0
        and isinstance(active, Mapping)
        and set(active) == (ACTIVE_CELL_FIELDS - {"attempt_number"})
        and active.get("status") == "OUTCOME_POSSIBLE_NO_RESUME"
        and state.get("finished_utc") is not None
        and state.get("outcome_possible_since_utc") is not None
        and isinstance(state.get("cells"), list)
        and len(state["cells"]) == 3
        and all(isinstance(cell, Mapping) for cell in state["cells"])
        and state.get("error_type") == "AuditError"
        and state.get("error") == "runner stdout contains no JSON object"
    )


def _inspect_launch_state_payload(
    state_path: Path, state: Mapping[str, Any], state_binding: Mapping[str, Any]
) -> dict[str, Any]:
    base = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_STATUS",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "launch_state": dict(state_binding),
        "state_status": state.get("status"),
        "post_allowed": False,
        "resume_allowed": False,
        "outcome_data_read": False,
    }
    if _is_legacy_rev2_stdout_lifecycle_defect(state):
        return {
            **base,
            "status": "REJECT",
            "classification": "LEGACY_REV2_RUNNER_STDOUT_REJECT_LIFECYCLE_UNCLOSED",
            "evidence_closed": False,
            "findings": [
                "TERMINAL_WORKER_PID_NOT_CLEARED",
                "TERMINAL_ACTIVE_CELL_NOT_CLEARED",
                "REJECTED_CELL_ATTEMPT_EVIDENCE_MISSING",
                "RUNNER_STDOUT_NO_JSON",
            ],
        }
    try:
        _validate_launch_state_shape(state)
    except AuditError as exc:
        status = state.get("status")
        classification = (
            "INVALID_TERMINAL_LAUNCH_STATE"
            if status in {"COMPLETE", "REJECT"}
            else "INVALID_OR_UNCLOSED_LAUNCH_STATE"
        )
        return {
            **base,
            "status": "REJECT",
            "classification": classification,
            "evidence_closed": False,
            "findings": ["EXACT_SCHEMA_VALIDATION_FAILED"],
            "validation_error": str(exc),
        }
    status = str(state["status"])
    if status == "COMPLETE":
        return {
            **base,
            "status": "PASS",
            "classification": "TERMINAL_COMPLETE_STRUCTURALLY_CLOSED",
            "evidence_closed": True,
            "post_precheck_required": True,
            "findings": [],
        }
    if status == "REJECT":
        terminal = state["terminal"]
        return {
            **base,
            "status": "REJECT",
            "classification": "TERMINAL_REJECT_EVIDENCE_CLOSED",
            "evidence_closed": True,
            "controller_failure_class": terminal["controller_failure_class"],
            "findings": ["TERMINAL_REJECT_NO_RESUME"],
        }
    outcome_crossed = state["outcome_possible_since_utc"] is not None
    return {
        **base,
        "status": "REJECT" if outcome_crossed else "OPEN",
        "classification": (
            "NONTERMINAL_OUTCOME_FENCE_OPEN_NO_RESUME"
            if outcome_crossed
            else "PRE_OUTCOME_STATE"
        ),
        "evidence_closed": False,
        "resume_allowed": not outcome_crossed,
        "findings": ["OUTCOME_FENCE_REQUIRES_TERMINAL_CLOSURE"] if outcome_crossed else [],
    }


def launch_status(state_path: Path) -> dict[str, Any]:
    """Inspect lifecycle metadata only; never open reports, trades, or metrics."""

    state_path = state_path.resolve()
    binding = file_binding(state_path)
    return _inspect_launch_state_payload(state_path, load_json(state_path), binding)


def _assert_complete_stream_binding(
    binding: Mapping[str, Any], expected_path: Path, label: str
) -> None:
    validated = _validate_binding_shape(binding, label, PostflightError)
    try:
        observed_path = Path(str(validated["path"])).resolve()
    except OSError as exc:
        raise PostflightError(f"{label} path is not resolvable") from exc
    if observed_path != expected_path.resolve():
        raise PostflightError(
            f"{label} path drift: {observed_path} != {expected_path.resolve()}"
        )
    try:
        assert_binding(validated, label)
    except (AuditError, OSError) as exc:
        raise PostflightError(str(exc)) from exc


def _validate_complete_runner_streams(
    state_path: Path, launch_cell: Mapping[str, Any], pre: Mapping[str, Any]
) -> list[tuple[Mapping[str, Any], Path, str]]:
    """Re-open exact COMPLETE streams and bind stdout JSON to state.runner_result."""

    cell_id = str(launch_cell.get("cell_id", ""))
    cell_root = state_path.resolve().parent / "worker" / cell_id
    expected = {
        "stdout": cell_root / "runner.stdout.txt",
        "stderr": cell_root / "runner.stderr.txt",
    }
    checked: list[tuple[Mapping[str, Any], Path, str]] = []
    for stream in ("stdout", "stderr"):
        binding = launch_cell.get(stream)
        label = f"{cell_id} runner {stream}"
        if not isinstance(binding, Mapping):
            raise PostflightError(f"{label} binding missing")
        _assert_complete_stream_binding(binding, expected[stream], label)
        checked.append((binding, expected[stream], label))
    try:
        stdout_text = expected["stdout"].read_bytes().decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise PostflightError(f"{cell_id} runner stdout is not strict UTF-8") from exc
    stdout_result = _parse_single_json_envelope(
        stdout_text, f"{cell_id} runner stdout"
    )
    state_result = launch_cell.get("runner_result")
    if not isinstance(state_result, Mapping):
        raise PostflightError(f"{cell_id} state runner_result is missing")
    if canonical_bytes(stdout_result) != canonical_bytes(state_result):
        raise PostflightError(f"{cell_id} stdout/state runner_result drift")
    try:
        validate_dev1_controller_result(stdout_result, pre)
    except AuditError as exc:
        raise PostflightError(str(exc)) from exc
    return checked


def _validate_launch_chain(
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
    state: Mapping[str, Any],
    pre: Mapping[str, Any],
) -> list[dict[str, Any]]:
    """Bind COMPLETE state back through its immutable job, authorization, and plan."""

    try:
        _validate_launch_state_shape(state, PostflightError)
    except AuditError as exc:
        raise PostflightError(str(exc)) from exc
    if state["status"] != "COMPLETE":
        raise PostflightError("launch state is not a closed COMPLETE state")
    job_binding = state.get("job")
    if not isinstance(job_binding, Mapping):
        raise PostflightError("launch state omitted immutable job binding")
    assert_binding(job_binding, "launch job")
    job_path = Path(str(job_binding["path"])).resolve()
    job = load_json(job_path)
    try:
        _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    except AuthorizationError as exc:
        raise PostflightError(str(exc)) from exc
    authorization = job.get("authorization")
    if (
        not isinstance(authorization, Mapping)
        or state.get("authorization") != authorization
        or state.get("scheduler") != job.get("scheduler")
        or state.get("launcher_revision") != LAUNCHER_REVISION
    ):
        raise PostflightError("launch state/job authorization drift")
    auth_binding = authorization.get("binding")
    if not isinstance(auth_binding, Mapping):
        raise PostflightError("launch authorization binding missing")
    expected_authorization = validate_authorization(Path(str(auth_binding["path"])), pre_sha256)
    if authorization != expected_authorization:
        raise PostflightError("launch authorization bytes/payload drift")
    if (
        Path(str(state.get("pre_receipt_path", ""))).resolve() != pre_path.resolve()
        or str(state.get("pre_receipt_sha256", "")).lower() != pre_sha256.lower()
        or state.get("worker_pid") is not None
        or state.get("active_cell") is not None
    ):
        raise PostflightError("launch state PRE/terminal worker closure drift")

    job_created = parse_utc(str(job.get("created_utc", "")), "launch job created_utc")
    state_started = parse_utc(str(state.get("started_utc", "")), "launch state started_utc")
    state_finished = parse_utc(str(state.get("finished_utc", "")), "launch state finished_utc")
    if not job_created <= state_started <= state_finished:
        raise PostflightError("launch job/state chronology drift")
    if state_finished > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise PostflightError("launch state finished_utc is implausibly in the future")
    outcome_possible = parse_utc(
        str(state.get("outcome_possible_since_utc", "")),
        "launch state outcome_possible_since_utc",
    )
    if not state_started <= outcome_possible <= state_finished:
        raise PostflightError("launch state outcome-fence chronology drift")
    cells = state.get("cells")
    expected_ids = [str(cell["cell_id"]) for cell in pre["plan"]["cells"]]
    if (
        not isinstance(cells, list)
        or any(not isinstance(cell, Mapping) for cell in cells)
        or [str(cell.get("cell_id")) for cell in cells] != expected_ids
    ):
        raise PostflightError("launch state cell order/closure drift")
    cursor = state_started
    attempts: list[dict[str, Any]] = []
    checked_streams: list[tuple[Mapping[str, Any], Path, str]] = []
    for cell_record, plan_cell in zip(cells, pre["plan"]["cells"]):
        launch_cell = _attempt_for_post(cell_record)
        attempts.append(launch_cell)
        started = parse_utc(str(launch_cell.get("started_utc", "")), "cell started_utc")
        finished = parse_utc(str(launch_cell.get("finished_utc", "")), "cell finished_utc")
        if not cursor <= started <= finished <= state_finished:
            raise PostflightError(f"launch cell chronology drift: {plan_cell['cell_id']}")
        if (
            type(launch_cell.get("runner_exit_code")) is not int
            or launch_cell.get("runner_exit_code") != 0
            or launch_cell.get("command_sha256") != canonical_sha256(runner_command(pre, plan_cell))
        ):
            raise PostflightError(f"launch cell command/exit drift: {plan_cell['cell_id']}")
        checked_streams.extend(
            _validate_complete_runner_streams(state_path, launch_cell, pre)
        )
        cursor = finished
    if attempts and outcome_possible != parse_utc(
        attempts[0]["started_utc"], "first cell started_utc"
    ):
        raise PostflightError("launch state first outcome-fence timestamp drift")
    # Reassert after the full chain validation to close stream-byte TOCTOU.
    for binding, expected_path, label in checked_streams:
        _assert_complete_stream_binding(binding, expected_path, label)
    return attempts


def _load_complete_launch_chain(
    pre_path: Path, pre_sha256: str, state_path: Path
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any], list[dict[str, Any]]]:
    """Outcome-blind POST fence: state/job/PRE metadata only."""

    state_path = state_path.resolve()
    state_binding = file_binding(state_path)
    state = load_json(state_path)
    inspection = _inspect_launch_state_payload(state_path, state, state_binding)
    if inspection["classification"] != "TERMINAL_COMPLETE_STRUCTURALLY_CLOSED":
        raise PostflightError(
            f"POST blocked by lifecycle classification: {inspection['classification']}"
        )
    pre = assert_pre_receipt(pre_path, pre_sha256)
    if state.get("pre_receipt_sha256") != pre_sha256.lower():
        raise PostflightError("launch state is not bound to the supplied PRE")
    launch_cells = _validate_launch_chain(pre_path, pre_sha256, state_path, state, pre)
    if (
        not isinstance(launch_cells, list)
        or len(launch_cells) != 4
        or any(not isinstance(row, Mapping) for row in launch_cells)
    ):
        raise PostflightError("launch state does not contain exactly four cells")
    launch_by_id = {str(row.get("cell_id")): row for row in launch_cells}
    if len(launch_by_id) != 4:
        raise PostflightError("launch state cell IDs are not unique")
    return pre, state, dict(state_binding), launch_cells


def post_precheck(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    """Return a read-only, outcome-blind POST eligibility decision."""

    try:
        _pre, _state, state_binding, launch_cells = _load_complete_launch_chain(
            pre_path, pre_sha256, state_path
        )
    except (AuditError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        try:
            status = launch_status(state_path)
            classification = str(status["classification"])
            state_binding = status["launch_state"]
        except (AuditError, OSError, ValueError, KeyError, TypeError):
            classification = "POST_PREFLIGHT_INVALID_OR_UNREADABLE_STATE"
            state_binding = None
        return {
            "schema_version": SCHEMA_VERSION,
            "artifact_type": "QM5_20002_SHORT_NY_POST_PRECHECK",
            "analysis_id": ANALYSIS_ID,
            "created_utc": utc_now(),
            "status": "REJECT",
            "classification": classification,
            "post_allowed": False,
            "outcome_data_read": False,
            "launch_state": state_binding,
            "error_type": type(exc).__name__,
            "error": str(exc),
        }
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_POST_PRECHECK",
        "analysis_id": ANALYSIS_ID,
        "created_utc": utc_now(),
        "status": "PASS",
        "classification": "POST_PREFLIGHT_PASS_COMPLETE_EVIDENCE",
        "post_allowed": True,
        "outcome_data_read": False,
        "launch_state": state_binding,
        "cell_count": len(launch_cells),
    }


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    pre, state, state_binding, launch_cells = _load_complete_launch_chain(
        pre_path, pre_sha256, state_path
    )
    launch_by_id = {str(row.get("cell_id")): row for row in launch_cells}
    core = _load_report_core(pre)
    news = load_news_events(pre["news_calendars"])
    cell_receipts: list[dict[str, Any]] = []
    arm_audits: dict[str, list[tuple[str, NativeAudit]]] = defaultdict(list)
    for cell in pre["plan"]["cells"]:
        cell_id = str(cell["cell_id"])
        if cell_id not in launch_by_id:
            raise PostflightError(f"launch state omitted preregistered cell: {cell_id}")
        receipt, baseline = audit_cell(pre, cell, launch_by_id[cell_id], core, news)
        cell_receipts.append(receipt)
        arm_audits[str(cell["arm"])].append((str(cell["symbol"]), baseline))
    if set(arm_audits) != EXPECTED_ARMS or any(len(rows) != 2 for rows in arm_audits.values()):
        raise PostflightError("arm/symbol familywise closure drift")
    contract = load_contract()
    arms = [
        _adjudicate_arm(arm, arm_audits[arm], contract["merit_gates"])
        for arm in sorted(EXPECTED_ARMS)
    ]
    passing = [row["arm"] for row in arms if row["status"] == "PASS"]
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "QM5_20002_SHORT_NY_POST_RECEIPT",
        "status": "PASS_CANDIDATE" if passing else "REJECT_NO_ARM_PASSED",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "pre_receipt": file_binding(pre_path, pre_sha256),
        "launch_state": state_binding,
        "integrity_status": "PASS",
        "outcome_window": "2017-10-01..2021-12-31",
        "native_run_count": 8,
        "cell_count": 4,
        "news_union": {
            "source_rows": news["source_rows"],
            "skipped_rows_like_mql": news["skipped_rows_like_mql"],
        },
        "cells": cell_receipts,
        "arms": arms,
        "passing_arms": passing,
        "decision": contract["decision"]["on_pass"] if passing else contract["decision"]["on_fail"],
    }


def _rejection(phase: str, exc: Exception) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": f"QM5_20002_SHORT_NY_{phase}_REJECTION",
        "status": "REJECT",
        "created_utc": utc_now(),
        "analysis_id": ANALYSIS_ID,
        "error_type": type(exc).__name__,
        "error": str(exc),
    }


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pre = sub.add_parser("pre", help="Outcome-blind PRE validation and receipt")
    pre.add_argument("--compile-evidence", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    pre.add_argument("--timeout-seconds", type=int, default=28800)
    launch = sub.add_parser(
        "launch", help="Start the authorized persistent scheduled four-cell worker"
    )
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.add_argument("--controller-timeout-seconds", type=int)
    launch.add_argument(
        "--resume",
        action="store_true",
        help="Retry only a proven pre-outcome launch using its immutable scheduled task",
    )
    post = sub.add_parser("post", help="Audit COMPLETE native evidence and merit gates")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    status = sub.add_parser(
        "status", help="Read-only lifecycle classification without outcome data"
    )
    status.add_argument("--state", type=Path, required=True)
    post_pre = sub.add_parser(
        "post-precheck", help="Read-only outcome-blind POST eligibility check"
    )
    post_pre.add_argument("--pre-receipt", type=Path, required=True)
    post_pre.add_argument("--pre-sha256", required=True)
    post_pre.add_argument("--state", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    if args.command == "_run-plan":
        return _worker_run(args.job)
    try:
        if args.command == "pre":
            payload = preflight(args.compile_evidence, args.timeout_seconds)
            receipt_sha = atomic_json(args.receipt, payload, replace=False)
            output = {"status": "PASS", "receipt": str(args.receipt.resolve()), "sha256": receipt_sha}
        elif args.command == "launch":
            output = launch_detached(
                args.pre_receipt,
                args.pre_sha256,
                args.authorization,
                args.state,
                args.controller_timeout_seconds,
                resume=args.resume,
            )
        elif args.command == "status":
            output = launch_status(args.state)
        elif args.command == "post-precheck":
            output = post_precheck(args.pre_receipt, args.pre_sha256, args.state)
        elif args.command == "post":
            payload = postflight(args.pre_receipt, args.pre_sha256, args.state)
            receipt_sha = atomic_json(args.receipt, payload, replace=False)
            output = {
                "status": payload["status"],
                "receipt": str(args.receipt.resolve()),
                "sha256": receipt_sha,
                "passing_arms": payload["passing_arms"],
            }
        else:
            raise AuditError(f"unsupported command: {args.command}")
        print(json.dumps(output, indent=2, sort_keys=True))
        return 2 if args.command == "post-precheck" and output.get("status") == "REJECT" else 0
    except (AuditError, OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        phase = args.command.upper()
        payload = _rejection(phase, exc)
        receipt = getattr(args, "receipt", None)
        if receipt:
            try:
                atomic_json(receipt, payload, replace=False)
            except (AuditError, OSError):
                pass
        print(json.dumps(payload, indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
