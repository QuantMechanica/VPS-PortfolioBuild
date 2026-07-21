#!/usr/bin/env python3
"""One-shot TestWindow-OFF superseding XAU audit for QM5_13210.

This module is deliberately a thin profile over the already finalized XAU
auditor.  It changes no EA, set, data, dates, costs, merit gates or native
runner arguments.  It only closes the T1-overlapped old namespace and requires
the Factory TestWindow-OFF state before PRE, launch, worker bootstrap and every
native cell start.

No function in this module reads controller logs or native reports before POST.
The invalid predecessor is proved from control JSON, filesystem inventory,
opaque SHA-256 bindings and a read-only work-item row projection.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
SUPERSEDED_TOOL_PATH = TOOL_PATH.with_name("audit_mulham_asian_sweep_london_xau.py")
_X_SPEC = importlib.util.spec_from_file_location(
    "qm13210_xau_testwindow_private_superseded", SUPERSEDED_TOOL_PATH
)
if _X_SPEC is None or _X_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load superseded XAU auditor: {SUPERSEDED_TOOL_PATH}")
X = importlib.util.module_from_spec(_X_SPEC)
sys.modules[_X_SPEC.name] = X
_X_SPEC.loader.exec_module(X)
B = X.B

EA_ROOT = X.EA_ROOT
REPO_ROOT = X.REPO_ROOT
ANALYSIS_ID = "QM5_13210_MULHAM_ASIAN_SWEEP_LONDON_XAUUSD_NATIVE_002"
RESEARCH_SYMBOL = X.RESEARCH_SYMBOL
MERIT_CONTRACT_VERSION = X.MERIT_CONTRACT_VERSION
MERIT_GATES = X.MERIT_GATES
SYMBOL_POLICY = X.SYMBOL_POLICY
RUN_FAMILY_ROOT = X.RUN_FAMILY_ROOT
SUPERSEDED_NAMESPACE_ROOT = X.RUN_NAMESPACE_ROOT
SUPERSEDED_ATTEMPT_001_ROOT = X.ATTEMPT_001_RUN_ROOT
SUPERSEDED_ATTEMPT_002_ROOT = X.ATTEMPT_002_RUN_ROOT
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "XAUUSD_MULHAM_NATIVE_002"
ATTEMPT_001_RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
ALLOWED_RUN_ROOT = ATTEMPT_001_RUN_ROOT
SCHEDULED_TASK_PREFIX = X.SCHEDULED_TASK_PREFIX
LAUNCHER_REVISION = "QM13210_XAU_TESTWINDOW_OFF_SUPERSEDING_ANALYSIS_V1"
AUTHORIZATION_SCOPE = (
    "QM5_13210_XAUUSD_NATIVE_002_ATTEMPT_001_TESTWINDOW_OFF_"
    "4_CELLS_X_2_DUPLICATES_MODEL4_T1"
)

DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = DOC_ROOT / "xauusd_testwindow_outcome_fenced_analysis_contract_20260721.json"
SUPERSEDED_CONTRACT_PATH = X.CONTRACT_PATH
ATTEMPT_001_CLOSURE_PATH = X.ATTEMPT_001_CLOSURE_PATH
ATTEMPT_002_CLOSURE_PATH = (
    DOC_ROOT / "xauusd_attempt002_invalid_infrastructure_closure_20260721.json"
)
BUILD_RECEIPT_PATH = X.BUILD_RECEIPT_PATH
PRE_RECEIPT_PATH = ATTEMPT_001_RUN_ROOT / "pre_receipt.json"
AUTHORIZATION_PATH = ATTEMPT_001_RUN_ROOT / "native_outcome_authorization.json"
STATE_PATH = ATTEMPT_001_RUN_ROOT / "launch_state.json"
JOB_PATH = ATTEMPT_001_RUN_ROOT / "launch_job.json"
POST_RECEIPT_PATH = ATTEMPT_001_RUN_ROOT / "post_receipt.json"
RESEARCH_READINESS_PATH = X.ATTEMPT_002_RESEARCH_READINESS_PATH
DATA_MANIFEST_PATH = X.ATTEMPT_002_DATA_MANIFEST_PATH
INPUT_BINDINGS = X.ATTEMPT_002_INPUT_BINDINGS

FARM_STATE_ROOT = Path(r"D:\QM\strategy_farm\state")
FACTORY_OFF_FLAG_PATH = FARM_STATE_ROOT / "FACTORY_OFF.flag"
CODEX_PARALLEL_PATH = FARM_STATE_ROOT / "codex_parallel.txt"
WORKER_PIDS_PATH = FARM_STATE_ROOT / "worker_pids.json"
TESTWINDOW_OFF_PATH = REPO_ROOT / "tools" / "strategy_farm" / "TestWindow_OFF.ps1"
FACTORY_OFF_PATH = REPO_ROOT / "tools" / "strategy_farm" / "Factory_OFF.ps1"
TASK_MANIFEST_PATH = REPO_ROOT / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1"
PROCESS_SCOPE_PATH = REPO_ROOT / "tools" / "strategy_farm" / "factory_process_scope.ps1"

SUPERSEDED_TASK_NAME = "QM_QM13210_XAU_AUDIT_2ec4ba1e251eaf13ee140c8b"
MANAGED_OFF_TASKS = (
    "QM_StrategyFarm_Pump_5min",
    "QM_StrategyFarm_Tick_5min",
    "QM_StrategyFarm_AgentRouter_5min",
    "QM_StrategyFarm_CodexOrchestration_15min",
    "QM_StrategyFarm_GeminiOrchestration_15min",
    "QM_StrategyFarm_ClaudeOrchestration_15min",
    "QM_StrategyFarm_FactoryWatchdog_15min",
    "QM_StrategyFarm_FactoryON_AtLogon",
    "QM_StrategyFarm_ReconcileOrphans_Hourly",
    "QM_StrategyFarm_Repair_Hourly",
    "QM_StrategyFarm_TerminalWorkers_AT_STARTUP",
)

FINAL_ARTIFACT_ROLES = frozenset(
    {
        "adapter",
        "attempt001_closure",
        "attempt002_closure",
        "base_tool",
        "build_receipt",
        "card",
        "ex5",
        "factory_off",
        "mq5",
        "process_scope",
        "scheduled_task_helper",
        "set",
        "spec",
        "superseded_adapter",
        "superseded_contract",
        "task_manifest",
        "testwindow_off",
    }
)

_BASE_EXPECTED_BINDING_PATHS = X._BASE_EXPECTED_BINDING_PATHS
_BASE_PREFLIGHT = X._BASE_PREFLIGHT
_BASE_ASSERT_PRE_RECEIPT = X._BASE_ASSERT_PRE_RECEIPT
_BASE_LAUNCH_PERSISTENT_TASK = X._BASE_LAUNCH_PERSISTENT_TASK
_BASE_POSTFLIGHT = X._BASE_POSTFLIGHT
_BASE_WORKER_RUN = X._BASE_WORKER_RUN
_BASE_RUNNER_COMMAND = B.runner_command


def _assert_exact_run_root(path: Path) -> Path:
    observed = path.resolve()
    expected = ALLOWED_RUN_ROOT.resolve()
    if observed != expected:
        raise B.InvalidEvidence(
            f"superseding XAU run root must be exactly {expected}: {observed}"
        )
    return observed


def _assert_namespace_contract(*, pristine: bool) -> None:
    validate_attempt002_invalid_infrastructure_closure()
    if X.LEGACY_RUN_ROOT.resolve().exists():
        raise B.InvalidEvidence("legacy XAU namespace exists")
    if SUPERSEDED_NAMESPACE_ROOT.is_dir():
        observed = {item.name for item in SUPERSEDED_NAMESPACE_ROOT.iterdir()}
        if observed != {"ATTEMPT_001", "ATTEMPT_002"}:
            raise B.InvalidEvidence("old namespace was extended beyond ATTEMPT_002")
    else:
        raise B.InvalidEvidence("superseded XAU namespace is missing")
    if RUN_FAMILY_ROOT.is_dir():
        siblings = {
            item.name
            for item in RUN_FAMILY_ROOT.iterdir()
            if item.name.startswith("XAUUSD_MULHAM_NATIVE_")
        }
        if not siblings <= {SUPERSEDED_NAMESPACE_ROOT.name, RUN_NAMESPACE_ROOT.name}:
            raise B.InvalidEvidence(f"unregistered XAU analysis namespace: {sorted(siblings)}")
    if RUN_NAMESPACE_ROOT.is_dir():
        children = {item.name for item in RUN_NAMESPACE_ROOT.iterdir()}
        if not children <= {"ATTEMPT_001"}:
            raise B.InvalidEvidence("superseding analysis contains a retry/second attempt")
    if pristine and ALLOWED_RUN_ROOT.exists():
        if not ALLOWED_RUN_ROOT.is_dir() or any(ALLOWED_RUN_ROOT.iterdir()):
            raise B.InvalidEvidence("superseding ATTEMPT_001 root is not pristine")


def _attempt002_control_paths() -> dict[str, Path]:
    return {
        "pre_receipt": SUPERSEDED_ATTEMPT_002_ROOT / "pre_receipt.json",
        "authorization": SUPERSEDED_ATTEMPT_002_ROOT / "native_outcome_authorization.json",
        "launch_job": SUPERSEDED_ATTEMPT_002_ROOT / "launch_job.json",
        "launch_state": SUPERSEDED_ATTEMPT_002_ROOT / "launch_state.json",
    }


def _probe_superseded_task_terminal() -> dict[str, Any]:
    command = [
        str(B.POWERSHELL_PATH.resolve()),
        "-NoLogo",
        "-NoProfile",
        "-NonInteractive",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(B.SCHEDULED_TASK_HELPER_PATH.resolve()),
        "-Operation",
        "Probe",
        "-TaskName",
        SUPERSEDED_TASK_NAME,
        "-PythonExe",
        str(B.PYTHON_PATH.resolve()),
        "-ToolPath",
        str(SUPERSEDED_TOOL_PATH.resolve()),
        "-JobPath",
        str((SUPERSEDED_ATTEMPT_002_ROOT / "launch_job.json").resolve()),
        "-RepoRoot",
        str(REPO_ROOT.resolve()),
        "-ExecutionLimitSeconds",
        "241200",
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise B.InvalidEvidence("superseded scheduled-task probe failed closed")
    payload = B._parse_last_json(completed.stdout)
    common = {
        "operation": "Probe",
        "task_name": SUPERSEDED_TASK_NAME,
        "task_path": "\\",
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": 241200,
    }
    if any(payload.get(key) != value for key, value in common.items()):
        raise B.InvalidEvidence("superseded scheduled-task identity drift")
    if payload.get("exists") is False:
        if payload.get("state") != "Absent":
            raise B.InvalidEvidence("superseded task absence is malformed")
    elif not (
        payload.get("exists") is True
        and payload.get("state") == "Ready"
        and payload.get("last_task_result") == 2
    ):
        raise B.InvalidEvidence("superseded task is not terminal and non-running")
    return payload


def _relative_inventory(root: Path) -> list[str]:
    rows: list[str] = []
    for item in root.rglob("*"):
        relative = item.relative_to(root).as_posix()
        rows.append(relative + ("/" if item.is_dir() else ""))
    return sorted(rows)


def validate_attempt002_invalid_infrastructure_closure(
    path: Path = ATTEMPT_002_CLOSURE_PATH,
    *,
    probe_task_terminal: bool = True,
) -> dict[str, Any]:
    payload = B.load_json(path)
    required = {
        "schema_version",
        "artifact_type",
        "status",
        "analysis_id",
        "attempt_id",
        "classification",
        "closed_utc",
        "run_root",
        "control_bindings",
        "opaque_log_bindings",
        "native_start_proof",
        "scheduled_task_terminal_state",
        "t1_overlap_evidence",
        "outcome_fence",
        "recovery_contract",
    }
    if set(payload) != required:
        raise B.InvalidEvidence("ATTEMPT_002 closure field drift")
    expected_identity = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_ATTEMPT_INVALID_INFRASTRUCTURE_CLOSURE",
        "status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "analysis_id": X.ANALYSIS_ID,
        "attempt_id": "ATTEMPT_002",
        "classification": "T1_FACTORY_WORK_ITEM_OVERLAP_TESTWINDOW_NOT_QUIESCED_BEFORE_LAUNCH",
        "run_root": str(SUPERSEDED_ATTEMPT_002_ROOT.resolve()),
    }
    if any(payload.get(key) != value for key, value in expected_identity.items()):
        raise B.InvalidEvidence("ATTEMPT_002 closure identity drift")
    B.parse_utc(str(payload.get("closed_utc", "")), "ATTEMPT_002 closed_utc")
    controls = payload.get("control_bindings")
    paths = _attempt002_control_paths()
    if not isinstance(controls, Mapping) or set(controls) != set(paths):
        raise B.InvalidEvidence("ATTEMPT_002 control-binding closure drift")
    for role, expected_path in paths.items():
        row = controls[role]
        if not isinstance(row, Mapping) or Path(str(row.get("path", ""))).resolve() != expected_path.resolve():
            raise B.InvalidEvidence(f"ATTEMPT_002 control path drift: {role}")
        B.assert_binding(row, f"ATTEMPT_002 immutable {role}")

    logs = payload.get("opaque_log_bindings")
    expected_logs = {
        "controller_stdout": SUPERSEDED_ATTEMPT_002_ROOT / "native" / "DEV" / "controller.stdout.log",
        "controller_stderr": SUPERSEDED_ATTEMPT_002_ROOT / "native" / "DEV" / "controller.stderr.log",
        "overlapping_factory_work_item_log": Path(
            r"D:\QM\strategy_farm\logs\work_item_a1b0580e-fca3-41b5-a590-474dab4606bf.log"
        ),
    }
    if not isinstance(logs, Mapping) or set(logs) != set(expected_logs):
        raise B.InvalidEvidence("ATTEMPT_002 opaque-log binding closure drift")
    for role, expected_path in expected_logs.items():
        row = logs[role]
        if not isinstance(row, Mapping) or Path(str(row.get("path", ""))).resolve() != expected_path.resolve():
            raise B.InvalidEvidence(f"ATTEMPT_002 opaque log path drift: {role}")
        B.assert_binding(row, f"ATTEMPT_002 opaque {role}")

    state = B.load_json(paths["launch_state"])
    cells = state.get("cells")
    launches = state.get("launches")
    proof = payload.get("native_start_proof")
    expected_proof = {
        "native_controller_start_count": 1,
        "worker_pid": None,
        "launch_status": "INTERRUPTED_RESUMABLE",
        "first_cell_id": "XAUUSD_DWX_DEV",
        "first_cell_status": "INTERRUPTED_NO_OUTCOME",
        "controller_started_utc": "2026-07-21T09:13:30.993067+00:00",
        "controller_finished_utc": "2026-07-21T09:13:31.863899+00:00",
        "controller_exit_code": 1,
        "summary_binding": None,
        "outcome_artifacts": [],
        "remaining_cell_count": 3,
        "all_remaining_cells_pending_without_attempts": True,
    }
    if not isinstance(proof, Mapping) or any(
        proof.get(key) != value for key, value in expected_proof.items()
    ):
        raise B.InvalidEvidence("ATTEMPT_002 native-start proof drift")
    if (
        state.get("analysis_id") != X.ANALYSIS_ID
        or state.get("status") != "INTERRUPTED_RESUMABLE"
        or state.get("worker_pid") is not None
        or not isinstance(cells, list)
        or len(cells) != 4
        or not isinstance(launches, list)
        or len(launches) != 1
        or launches[0].get("resume") is not False
        or launches[0].get("status") != "WORKER_REGISTERED"
    ):
        raise B.InvalidEvidence("ATTEMPT_002 launch-state terminal closure drift")
    first = cells[0]
    attempts = first.get("attempts") if isinstance(first, Mapping) else None
    if (
        first.get("cell_id") != "XAUUSD_DWX_DEV"
        or first.get("status") != "INTERRUPTED_NO_OUTCOME"
        or not isinstance(attempts, list)
        or len(attempts) != 1
    ):
        raise B.InvalidEvidence("ATTEMPT_002 first-cell control drift")
    attempt = attempts[0]
    if (
        attempt.get("started_utc") != "2026-07-21T09:13:30.993067+00:00"
        or attempt.get("finished_utc") != "2026-07-21T09:13:31.863899+00:00"
        or attempt.get("exit_code") != 1
        or attempt.get("summary") is not None
        or attempt.get("outcome_artifacts") != []
        or attempt.get("stdout") != logs["controller_stdout"]
        or attempt.get("stderr") != logs["controller_stderr"]
    ):
        raise B.InvalidEvidence("ATTEMPT_002 controller outcome-free closure drift")
    if any(
        row.get("status") != "PENDING" or row.get("attempts") != []
        for row in cells[1:]
        if isinstance(row, Mapping)
    ) or any(not isinstance(row, Mapping) for row in cells[1:]):
        raise B.InvalidEvidence("ATTEMPT_002 later cell contains a native start")
    inventory = _relative_inventory(SUPERSEDED_ATTEMPT_002_ROOT)
    if inventory != proof.get("run_root_inventory"):
        raise B.InvalidEvidence("ATTEMPT_002 run-root inventory drift")

    overlap = payload.get("t1_overlap_evidence")
    expected_overlap = {
        "source": "READ_ONLY_WORK_ITEMS_ROW_PROJECTION_PLUS_OPAQUE_LOG_BINDING",
        "source_database_path": r"D:\QM\strategy_farm\state\farm_state.sqlite",
        "source_table": "work_items",
        "work_item_id": "a1b0580e-fca3-41b5-a590-474dab4606bf",
        "phase": "Q02",
        "ea_id": "QM5_1558",
        "symbol": "WS30.DWX",
        "terminal": "T1",
        "claimed_by_worker_pid": 4288,
        "controller_pid": 13500,
        "factory_started_before_xau": True,
        "factory_release_ledger_after_xau": True,
        "xau_interval_fully_contained_in_t1_factory_occupancy_ledger": True,
        "strategy_merit_inference_permitted": False,
    }
    if not isinstance(overlap, Mapping) or any(
        overlap.get(key) != value for key, value in expected_overlap.items()
    ):
        raise B.InvalidEvidence("ATTEMPT_002 T1 overlap identity drift")
    factory_start = B.parse_utc(str(overlap.get("factory_started_utc", "")), "factory start")
    factory_release = B.parse_utc(str(overlap.get("factory_terminal_release_ledger_utc", "")), "factory release")
    xau_start = B.parse_utc(str(overlap.get("xau_controller_started_utc", "")), "XAU start")
    xau_finish = B.parse_utc(str(overlap.get("xau_controller_finished_utc", "")), "XAU finish")
    if not (
        factory_start <= xau_start <= xau_finish <= factory_release
        and overlap.get("xau_interval_fully_contained_in_t1_factory_occupancy_ledger") is True
        and overlap.get("strategy_merit_inference_permitted") is False
    ):
        raise B.InvalidEvidence("ATTEMPT_002 exact T1 overlap chronology drift")
    fence = payload.get("outcome_fence")
    if not isinstance(fence, Mapping) or any(
        fence.get(key) is not False
        for key in (
            "native_reports_opened",
            "native_outcomes_opened",
            "controller_stdout_opened",
            "controller_stderr_opened",
            "overlapping_factory_work_item_log_opened",
        )
    ):
        raise B.InvalidEvidence("ATTEMPT_002 outcome fence drift")
    recovery = payload.get("recovery_contract")
    if not isinstance(recovery, Mapping) or any(
        recovery.get(key) is not True
        for key in (
            "old_analysis_namespace_final",
            "attempt002_resume_forbidden",
            "attempt003_plus_in_old_namespace_forbidden",
            "superseding_resume_or_retry_forbidden",
            "testwindow_off_required_before_pre_launch_and_worker",
            "same_build_data_parameters_windows_costs_and_gates_required",
            "strategy_or_parameter_change_forbidden",
        )
    ) or (
        recovery.get("superseding_analysis_id") != ANALYSIS_ID
        or recovery.get("superseding_namespace") != str(RUN_NAMESPACE_ROOT.resolve())
        or recovery.get("single_superseding_attempt") != "ATTEMPT_001"
    ):
        raise B.InvalidEvidence("ATTEMPT_002 recovery contract drift")
    recorded_task = payload.get("scheduled_task_terminal_state")
    expected_recorded_task = {
        "task_name": SUPERSEDED_TASK_NAME,
        "task_path": "\\",
        "exists": True,
        "state": "Ready",
        "last_task_result": 2,
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": 241200,
        "resume_or_restart_forbidden": True,
    }
    if not isinstance(recorded_task, Mapping) or any(
        recorded_task.get(key) != value for key, value in expected_recorded_task.items()
    ):
        raise B.InvalidEvidence("ATTEMPT_002 recorded task terminal-state drift")
    B.parse_utc(
        str(recorded_task.get("observed_utc", "")),
        "ATTEMPT_002 task-terminal observed_utc",
    )
    task = _probe_superseded_task_terminal() if probe_task_terminal else None
    return {
        "binding": B.file_binding(path),
        "status": payload["status"],
        "control_bindings": {key: dict(value) for key, value in controls.items()},
        "opaque_log_bindings": {key: dict(value) for key, value in logs.items()},
        "native_controller_start_count": 1,
        "native_summary_count": 0,
        "native_outcome_artifact_count": 0,
        "t1_overlap_evidence": dict(overlap),
        "task_terminal": task is None or task.get("state") in {"Ready", "Absent"},
    }


_QUIESCENCE_POWERSHELL = r"""
$ErrorActionPreference = 'Stop'
$taskNames = @(
  'QM_StrategyFarm_Pump_5min','QM_StrategyFarm_Tick_5min',
  'QM_StrategyFarm_AgentRouter_5min','QM_StrategyFarm_CodexOrchestration_15min',
  'QM_StrategyFarm_GeminiOrchestration_15min','QM_StrategyFarm_ClaudeOrchestration_15min',
  'QM_StrategyFarm_FactoryWatchdog_15min','QM_StrategyFarm_FactoryON_AtLogon',
  'QM_StrategyFarm_ReconcileOrphans_Hourly','QM_StrategyFarm_Repair_Hourly',
  'QM_StrategyFarm_TerminalWorkers_AT_STARTUP'
)
$tasks = @()
foreach ($name in $taskNames) {
  $task = @(Get-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue)
  $tasks += [ordered]@{ task_name=$name; count=$task.Count; state=$(if($task.Count -eq 1){[string]$task[0].State}else{$null}) }
}
$mt5 = @()
$images = @(Get-CimInstance Win32_Process -Filter "Name='terminal64.exe' OR Name='metatester64.exe'" -ErrorAction SilentlyContinue)
foreach ($process in $images) {
  $match = [regex]::Match([string]$process.ExecutablePath, '(?i)^D:\\QM\\mt5\\(T(?:[1-9]|10))\\(terminal64|metatester64)\.exe$')
  if ($match.Success) {
    $mt5 += [ordered]@{ terminal=$match.Groups[1].Value.ToUpperInvariant(); image=$match.Groups[2].Value.ToLowerInvariant(); pid=[int]$process.ProcessId }
  }
}
$workerRows = @()
$workerPath = 'D:\QM\strategy_farm\state\worker_pids.json'
if (Test-Path -LiteralPath $workerPath -PathType Leaf) {
  $workerMap = Get-Content -LiteralPath $workerPath -Raw | ConvertFrom-Json
  foreach ($property in $workerMap.PSObject.Properties) {
    $pidValue = [int]$property.Value
    $process = Get-Process -Id $pidValue -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.ProcessName -in @('python','pythonw')) {
      $workerRows += [ordered]@{ terminal=[string]$property.Name; pid=$pidValue; image=[string]$process.ProcessName }
    }
  }
}
[ordered]@{
  scheduled_tasks=@($tasks)
  exact_factory_mt5_processes=@($mt5)
  registered_factory_python_workers=@($workerRows)
} | ConvertTo-Json -Depth 6 -Compress
"""


def _probe_quiescence_runtime() -> dict[str, Any]:
    completed = subprocess.run(
        [
            str(B.POWERSHELL_PATH.resolve()),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            _QUIESCENCE_POWERSHELL,
        ],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise B.InvalidEvidence("TestWindow-OFF runtime probe failed closed")
    try:
        payload = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise B.InvalidEvidence("TestWindow-OFF runtime probe returned invalid JSON") from exc
    if not isinstance(payload, dict):
        raise B.InvalidEvidence("TestWindow-OFF runtime probe root is not an object")
    return payload


def _probe_worker_mutexes() -> list[str]:
    if sys.platform != "win32":  # pragma: no cover - this auditor is Windows-only
        raise B.InvalidEvidence("TestWindow worker-mutex probe requires Windows")
    import ctypes

    kernel32 = ctypes.windll.kernel32
    kernel32.OpenMutexW.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_wchar_p]
    kernel32.OpenMutexW.restype = ctypes.c_void_p
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    kernel32.CloseHandle.restype = ctypes.c_int
    synchronize = 0x00100000
    active: list[str] = []
    for index in range(1, 11):
        terminal = f"T{index}"
        handle = kernel32.OpenMutexW(
            synchronize,
            False,
            f"Global\\QM_TerminalWorker_{terminal}",
        )
        if handle:
            active.append(terminal)
            kernel32.CloseHandle(handle)
            continue
        error = int(kernel32.GetLastError())
        if error not in {0, 2}:
            raise B.InvalidEvidence(
                f"TestWindow worker-mutex probe failed closed: {terminal}/{error}"
            )
    return active


def probe_testwindow_off_quiescence() -> dict[str, Any]:
    if not FACTORY_OFF_FLAG_PATH.is_file():
        raise B.InvalidEvidence("TestWindow-OFF requires FACTORY_OFF.flag")
    flag_binding = B.file_binding(FACTORY_OFF_FLAG_PATH)
    flag = B.load_json(FACTORY_OFF_FLAG_PATH)
    if set(flag) != {"off_at", "codex_parallel_before"} or not str(flag.get("codex_parallel_before", "")).strip():
        raise B.InvalidEvidence("FACTORY_OFF.flag schema drift")
    off_at = B.parse_utc(str(flag.get("off_at", "")), "FACTORY_OFF off_at")
    observed = datetime.now(timezone.utc)
    if off_at > observed or observed - off_at < timedelta(seconds=3):
        raise B.InvalidEvidence("TestWindow-OFF flag is future-dated or not settled")
    if not CODEX_PARALLEL_PATH.is_file() or CODEX_PARALLEL_PATH.read_text(encoding="ascii").strip() != "0":
        raise B.InvalidEvidence("TestWindow-OFF requires codex_parallel=0")
    if not WORKER_PIDS_PATH.is_file():
        raise B.InvalidEvidence("TestWindow-OFF worker PID registry is missing")
    runtime = _probe_quiescence_runtime()
    tasks = runtime.get("scheduled_tasks")
    if not isinstance(tasks, list) or [row.get("task_name") for row in tasks if isinstance(row, Mapping)] != list(MANAGED_OFF_TASKS):
        raise B.InvalidEvidence("TestWindow-OFF scheduled-task probe closure drift")
    if any(
        not isinstance(row, Mapping) or row.get("count") != 1 or row.get("state") != "Disabled"
        for row in tasks
    ):
        raise B.InvalidEvidence("TestWindow-OFF managed tasks are not all disabled")
    if runtime.get("exact_factory_mt5_processes") != []:
        raise B.InvalidEvidence("TestWindow-OFF has a T1-T10 terminal/tester process")
    if runtime.get("registered_factory_python_workers") != []:
        raise B.InvalidEvidence("TestWindow-OFF has a registered Python factory worker")
    worker_mutexes = _probe_worker_mutexes()
    if worker_mutexes:
        raise B.InvalidEvidence(
            f"TestWindow-OFF has active terminal-worker mutexes: {worker_mutexes}"
        )
    invariant = {
        "contract_version": "QM13210_TESTWINDOW_OFF_QUIESCENCE_V1",
        "factory_off_flag": {"binding": flag_binding, "payload": flag},
        "codex_parallel": {
            "binding": B.file_binding(CODEX_PARALLEL_PATH),
            "value": "0",
        },
        "worker_pid_registry": B.file_binding(WORKER_PIDS_PATH),
        "managed_task_states": tasks,
        "exact_factory_mt5_processes": [],
        "registered_factory_python_workers": [],
        "active_terminal_worker_mutexes": [],
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
    }
    return {
        "status": "PASS",
        "observed_utc": observed.isoformat(),
        "invariant_sha256": B.canonical_sha256(invariant),
        "invariant": invariant,
    }


def assert_testwindow_off_quiescence(
    expected: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    observed = probe_testwindow_off_quiescence()
    if expected is not None:
        if (
            expected.get("status") != "PASS"
            or expected.get("invariant_sha256") != B.canonical_sha256(expected.get("invariant"))
            or expected.get("invariant") != observed["invariant"]
            or expected.get("invariant_sha256") != observed["invariant_sha256"]
        ):
            raise B.InvalidEvidence("TestWindow-OFF PRE-bound invariant drift")
        B.parse_utc(str(expected.get("observed_utc", "")), "PRE quiescence observed_utc")
    return observed


def enforce_symbol_policy(symbol: str) -> None:
    X.enforce_symbol_policy(symbol)


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths.update(
        {
            "base_tool": X.BASE_TOOL_PATH,
            "superseded_adapter": SUPERSEDED_TOOL_PATH,
            "superseded_contract": SUPERSEDED_CONTRACT_PATH,
            "attempt001_closure": ATTEMPT_001_CLOSURE_PATH,
            "attempt002_closure": ATTEMPT_002_CLOSURE_PATH,
            "xau_testwindow_contract": CONTRACT_PATH,
            "testwindow_off": TESTWINDOW_OFF_PATH,
            "factory_off": FACTORY_OFF_PATH,
            "task_manifest": TASK_MANIFEST_PATH,
            "process_scope": PROCESS_SCOPE_PATH,
        }
    )
    return paths


def _artifact_contract_paths() -> dict[str, Path]:
    return {
        "card": B.CARD_PATH,
        "spec": B.SPEC_PATH,
        "mq5": B.MQ5_PATH,
        "ex5": B.EX5_PATH,
        "set": EA_ROOT / "sets" / f"{B.EXPERT_NAME}_{RESEARCH_SYMBOL}_M5_backtest.set",
        "build_receipt": BUILD_RECEIPT_PATH,
        "adapter": TOOL_PATH,
        "superseded_adapter": SUPERSEDED_TOOL_PATH,
        "superseded_contract": SUPERSEDED_CONTRACT_PATH,
        "attempt001_closure": ATTEMPT_001_CLOSURE_PATH,
        "attempt002_closure": ATTEMPT_002_CLOSURE_PATH,
        "base_tool": X.BASE_TOOL_PATH,
        "scheduled_task_helper": B.SCHEDULED_TASK_HELPER_PATH,
        "testwindow_off": TESTWINDOW_OFF_PATH,
        "factory_off": FACTORY_OFF_PATH,
        "task_manifest": TASK_MANIFEST_PATH,
        "process_scope": PROCESS_SCOPE_PATH,
    }


def _candidate_contract() -> dict[str, Any]:
    return dict(X._candidate_contract())


def _windows_contract() -> list[dict[str, Any]]:
    return X._window_contract()


def _run_namespace_contract() -> dict[str, Any]:
    return {
        "family_root": str(RUN_FAMILY_ROOT.resolve()),
        "superseded_namespace": str(SUPERSEDED_NAMESPACE_ROOT.resolve()),
        "superseded_namespace_final_at_attempt002": True,
        "superseding_namespace": str(RUN_NAMESPACE_ROOT.resolve()),
        "attempt_id": "ATTEMPT_001",
        "single_run_root": str(ALLOWED_RUN_ROOT.resolve()),
        "resume_forbidden": True,
        "retry_or_attempt002_plus_forbidden": True,
        "exact_control_paths": {
            "pre": str(PRE_RECEIPT_PATH.resolve()),
            "authorization": str(AUTHORIZATION_PATH.resolve()),
            "state": str(STATE_PATH.resolve()),
            "job": str(JOB_PATH.resolve()),
            "post": str(POST_RECEIPT_PATH.resolve()),
        },
    }


def _testwindow_contract() -> dict[str, Any]:
    return {
        "version": "QM13210_TESTWINDOW_OFF_QUIESCENCE_V1",
        "required_at": ["PRE", "LAUNCH", "WORKER_BOOTSTRAP", "BEFORE_EACH_NATIVE_CELL", "POST"],
        "factory_off_flag_required": True,
        "codex_parallel_exact": "0",
        "managed_tasks_exactly_disabled": list(MANAGED_OFF_TASKS),
        "exact_t1_t10_terminal_and_metatester_count": 0,
        "registered_factory_python_worker_count": 0,
        "pre_invariant_must_remain_byte_identical": True,
        "live_process_command_line_reads_forbidden": True,
        "live_process_command_line_output_forbidden": True,
    }


def _supersession_contract() -> dict[str, Any]:
    return {
        "superseded_analysis_id": X.ANALYSIS_ID,
        "superseding_analysis_id": ANALYSIS_ID,
        "old_attempt001_status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "old_attempt002_status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "old_attempt002_cause": "T1_FACTORY_WORK_ITEM_OVERLAP_TESTWINDOW_NOT_QUIESCED_BEFORE_LAUNCH",
        "old_attempt002_native_summary_count": 0,
        "old_attempt002_native_outcome_artifact_count": 0,
        "old_namespace_attempt003_plus_forbidden": True,
        "new_namespace_is_separate_analysis_not_attempt003": True,
        "single_new_attempt_only": True,
        "same_ea_ex5_set_data_parameters_windows_costs_and_merit_gates": True,
        "parameter_tuning_forbidden": True,
    }


def _outcome_fence_contract() -> dict[str, bool]:
    return {
        "attempt002_controller_logs_opened": False,
        "attempt002_native_reports_opened": False,
        "attempt002_native_outcomes_opened": False,
        "superseding_native_reports_opened": False,
        "superseding_deal_rows_parsed": False,
        "mt5_started_by_contract_or_finalization": False,
    }


def _draft_contract_payload() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_TESTWINDOW_SUPERSEDING_ANALYSIS_CONTRACT",
        "status": "DRAFT_PENDING_FINAL_FREEZE",
        "analysis_id": ANALYSIS_ID,
        "candidate": _candidate_contract(),
        "windows": _windows_contract(),
        "frozen_execution_identity": {
            "source_build_commit": "9e6c17e1e954aa6854afcc93dc72b64926316fd1",
            "research_symbol": RESEARCH_SYMBOL,
            "timeframe": B.TIMEFRAME,
            "model": 4,
            "duplicates_per_cell": B.DUPLICATES,
            "input_bindings": INPUT_BINDINGS,
            "symbol_spec_sha256": B.canonical_sha256(X.XAU_SYMBOL_SPEC_CONTRACT),
            "xau_calibration_projection_sha256": B.canonical_sha256(
                X.XAU_CALIBRATION_PROJECTION
            ),
            "cost_schedule_sha256": B.canonical_sha256(X.ATTEMPT_002_COST_SCHEDULE),
            "merit_contract_sha256": B.canonical_sha256(MERIT_GATES),
            "ea_ex5_set_data_parameters_windows_costs_and_gates_unchanged": True,
        },
        "run_namespace": _run_namespace_contract(),
        "supersession": _supersession_contract(),
        "testwindow_off_quiescence": _testwindow_contract(),
        "outcome_fence": _outcome_fence_contract(),
        "finalization": {
            "required_command": (
                "audit_mulham_asian_sweep_london_xau_testwindow.py finalize-contract "
                "--source-commit <40_HEX_BUILD_COMMIT>"
            ),
            "requires_committed_clean_adapter_closures_and_draft": True,
            "requires_pristine_superseding_namespace": True,
            "pre_and_launch_forbidden_until_status": "FINALIZED_OUTCOME_BLIND",
            "final_contract_must_bind_roles": sorted(FINAL_ARTIFACT_ROLES),
        },
    }


def validate_draft_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    payload = B.load_json(path)
    if payload != _draft_contract_payload():
        raise B.InvalidEvidence("TestWindow XAU draft contract semantic drift")
    return payload


def _validate_artifact_bindings(bindings: Any) -> dict[str, dict[str, Any]]:
    paths = _artifact_contract_paths()
    if not isinstance(bindings, Mapping) or set(bindings) != set(paths):
        raise B.InvalidEvidence("TestWindow XAU artifact-role closure drift")
    result: dict[str, dict[str, Any]] = {}
    for role, path in paths.items():
        row = bindings.get(role)
        if not isinstance(row, Mapping) or set(row) != {"path", "size", "sha256"}:
            raise B.InvalidEvidence(f"malformed TestWindow artifact binding: {role}")
        if Path(str(row.get("path", ""))).resolve() != path.resolve():
            raise B.InvalidEvidence(f"TestWindow artifact path drift: {role}")
        B.assert_binding(row, f"TestWindow finalized {role}")
        result[role] = dict(row)
    return result


def _final_payload(
    source_commit: str,
    finalized_utc: str,
    bindings: Mapping[str, Mapping[str, Any]],
) -> dict[str, Any]:
    draft = _draft_contract_payload()
    draft.pop("finalization")
    return {
        **draft,
        "status": "FINALIZED_OUTCOME_BLIND",
        "finalized_utc": finalized_utc,
        "source_build_commit": source_commit,
        "artifact_bindings": {role: dict(bindings[role]) for role in sorted(FINAL_ARTIFACT_ROLES)},
    }


def validate_analysis_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected_fields = set(_draft_contract_payload()) - {"finalization"}
    expected_fields |= {"finalized_utc", "source_build_commit", "artifact_bindings"}
    if set(payload) != expected_fields:
        raise B.InvalidEvidence("TestWindow XAU analysis contract is not finalized")
    if (
        payload.get("status") != "FINALIZED_OUTCOME_BLIND"
        or payload.get("analysis_id") != ANALYSIS_ID
        or payload.get("artifact_type") != "QM5_13210_XAUUSD_TESTWINDOW_SUPERSEDING_ANALYSIS_CONTRACT"
    ):
        raise B.InvalidEvidence("TestWindow XAU finalized identity drift")
    finalized = B.parse_utc(str(payload.get("finalized_utc", "")), "TestWindow contract finalized_utc")
    if finalized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("TestWindow contract finalization is future-dated")
    source_commit = str(payload.get("source_build_commit", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise B.InvalidEvidence("TestWindow source build commit is malformed")
    expected_semantics = _draft_contract_payload()
    expected_semantics.pop("finalization")
    expected_semantics["status"] = "FINALIZED_OUTCOME_BLIND"
    drift = {key for key, value in expected_semantics.items() if payload.get(key) != value}
    if drift:
        raise B.InvalidEvidence(f"TestWindow finalized semantic drift: {sorted(drift)}")
    artifacts = _validate_artifact_bindings(payload.get("artifact_bindings"))
    old = X.validate_analysis_contract(SUPERSEDED_CONTRACT_PATH)
    if old["binding"] != artifacts["superseded_contract"]:
        raise B.InvalidEvidence("superseded finalized contract binding drift")
    validate_attempt002_invalid_infrastructure_closure()
    X._validate_bound_build_receipt(artifacts, source_commit)
    X._activate_finalized_contract({**payload, "artifact_bindings": artifacts})
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "source_build_commit": source_commit,
        "artifact_bindings": artifacts,
        "supersession": payload["supersession"],
        "testwindow_off_quiescence": payload["testwindow_off_quiescence"],
    }


def _git(arguments: Sequence[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="strict",
    )


def _repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError as exc:
        raise B.InvalidEvidence(f"finalized artifact outside repository: {path}") from exc


def _assert_source_freeze_ready(source_commit: str) -> None:
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise B.InvalidEvidence("finalize requires lowercase full source commit")
    resolved = _git(["rev-parse", "--verify", f"{source_commit}^{{commit}}"])
    if resolved.returncode != 0 or resolved.stdout.strip().lower() != source_commit:
        raise B.InvalidEvidence("source build commit does not resolve exactly")
    if _git(["merge-base", "--is-ancestor", source_commit, "HEAD"]).returncode != 0:
        raise B.InvalidEvidence("source build commit is not an ancestor of HEAD")
    paths = _artifact_contract_paths()
    repo_paths = [
        _repo_relative(path)
        for path in [*paths.values(), CONTRACT_PATH]
        if path.resolve().is_relative_to(REPO_ROOT.resolve())
    ]
    status = _git(["status", "--porcelain=v1", "--untracked-files=all", "--", *repo_paths])
    if status.returncode != 0 or status.stdout.strip():
        raise B.InvalidEvidence("finalize requires committed clean adapter, closures and draft")
    for role in ("mq5", "ex5", "spec", "set"):
        if _git(["diff", "--quiet", source_commit, "--", _repo_relative(paths[role])]).returncode != 0:
            raise B.InvalidEvidence(f"source artifact differs from build commit: {role}")


def _assert_finalized_contract_committed() -> None:
    relative = _repo_relative(CONTRACT_PATH)
    tracked = _git(["ls-files", "--error-unmatch", "--", relative])
    status = _git(["status", "--porcelain=v1", "--untracked-files=all", "--", relative])
    if tracked.returncode != 0 or status.returncode != 0 or status.stdout.strip():
        raise B.InvalidEvidence("PRE requires committed clean finalized TestWindow contract")


def finalize_analysis_contract(source_commit: str) -> dict[str, Any]:
    validate_draft_contract()
    _assert_namespace_contract(pristine=True)
    _assert_source_freeze_ready(source_commit)
    artifacts = {role: B.file_binding(path) for role, path in _artifact_contract_paths().items()}
    X._validate_bound_build_receipt(artifacts, source_commit)
    payload = _final_payload(source_commit, B.utc_now(), artifacts)
    digest = B.atomic_json(CONTRACT_PATH, payload, replace=True)
    result = validate_analysis_contract()
    if result["binding"]["sha256"] != digest:
        raise B.InvalidEvidence("finalized TestWindow contract write drift")
    return result


def _assert_exact_control_path(path: Path, expected: Path, label: str) -> Path:
    observed = path.resolve()
    if observed != expected.resolve():
        raise B.InvalidEvidence(f"superseding {label} must be {expected.resolve()}: {observed}")
    return observed


def preflight(
    symbol: str,
    research_readiness_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    closure = validate_attempt002_invalid_infrastructure_closure()
    _assert_namespace_contract(pristine=True)
    _assert_exact_run_root(run_root)
    for role, observed_path in {
        "research_readiness_receipt": research_readiness_receipt_path,
        "data_manifest": data_manifest_path,
    }.items():
        expected = INPUT_BINDINGS[role]
        if observed_path.resolve() != Path(str(expected["path"])).resolve():
            raise B.InvalidEvidence(f"superseding {role} path drift")
        B.file_binding(observed_path, str(expected["sha256"]))
        if observed_path.stat().st_size != int(expected["size"]):
            raise B.InvalidEvidence(f"superseding {role} size drift")
    if build_receipt_path.resolve() != BUILD_RECEIPT_PATH.resolve():
        raise B.InvalidEvidence("superseding PRE build receipt path drift")
    contract = validate_analysis_contract()
    _assert_finalized_contract_committed()
    quiescence = assert_testwindow_off_quiescence()
    pre = _BASE_PREFLIGHT(
        symbol,
        research_readiness_receipt_path,
        data_manifest_path,
        build_receipt_path,
        run_root,
    )
    if pre.get("cost_schedule") != X.ATTEMPT_002_COST_SCHEDULE or pre.get("merit_contract") != MERIT_GATES:
        raise B.InvalidEvidence("superseding costs or merit gates differ from old XAU run")
    role_map = {
        "tool": "adapter",
        "superseded_adapter": "superseded_adapter",
        "superseded_contract": "superseded_contract",
        "attempt001_closure": "attempt001_closure",
        "attempt002_closure": "attempt002_closure",
        "scheduled_task_helper": "scheduled_task_helper",
        "testwindow_off": "testwindow_off",
        "factory_off": "factory_off",
        "task_manifest": "task_manifest",
        "process_scope": "process_scope",
    }
    for pre_role, contract_role in role_map.items():
        if pre["bindings"].get(pre_role) != contract["artifact_bindings"].get(contract_role):
            raise B.InvalidEvidence(f"PRE binding differs from finalized {contract_role}")
    pre["attempt_id"] = "ATTEMPT_001"
    pre["supersession"] = contract["supersession"]
    pre["attempt002_invalid_infrastructure_closure"] = closure
    pre["testwindow_off_quiescence"] = quiescence
    pre["xau_testwindow_preregistration"] = contract
    return pre


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_exact_control_path(path, PRE_RECEIPT_PATH, "PRE receipt")
    contract = validate_analysis_contract()
    _assert_finalized_contract_committed()
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    if pre.get("attempt_id") != "ATTEMPT_001" or pre.get("supersession") != contract["supersession"]:
        raise B.InvalidEvidence("superseding PRE identity drift")
    closure = validate_attempt002_invalid_infrastructure_closure()
    if pre.get("attempt002_invalid_infrastructure_closure") != closure:
        raise B.InvalidEvidence("PRE ATTEMPT_002 closure binding drift")
    if pre.get("xau_testwindow_preregistration") != contract:
        raise B.InvalidEvidence("PRE finalized TestWindow contract drift")
    proof = pre.get("testwindow_off_quiescence")
    if not isinstance(proof, Mapping):
        raise B.InvalidEvidence("PRE TestWindow-OFF proof missing")
    assert_testwindow_off_quiescence(proof)
    _assert_namespace_contract(pristine=False)
    return pre


def validate_authorization(
    path: Path,
    pre_sha256: str,
    *,
    require_current: bool = True,
    now: datetime | None = None,
) -> dict[str, Any]:
    _assert_exact_control_path(path, AUTHORIZATION_PATH, "authorization")
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": RESEARCH_SYMBOL,
        "authorized_cells": [window.cell_id for window in B.WINDOWS],
        "duplicates_per_cell": B.DUPLICATES,
        "model": 4,
        "authorize_native_outcomes": True,
    }
    drift = {key: (value, payload.get(key)) for key, value in expected.items() if payload.get(key) != value}
    if drift:
        raise B.AuthorizationError(f"superseding authorization drift: {drift}")
    created = B.parse_utc(str(payload.get("created_utc", "")), "authorization created_utc")
    expires = B.parse_utc(str(payload.get("expires_utc", "")), "authorization expires_utc")
    if expires <= created or expires - created > timedelta(hours=24):
        raise B.AuthorizationError("authorization lifetime must be >0 and <=24h")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if require_current and not (created - timedelta(minutes=5) <= current <= expires):
        raise B.AuthorizationError("authorization is not currently valid")
    return {"binding": binding, "payload_sha256": B.canonical_sha256(payload), "payload": payload}


def launch_persistent_task(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    if resume:
        raise B.AuthorizationError("superseding analysis is one-shot; resume is forbidden")
    _assert_exact_control_path(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(authorization_path, AUTHORIZATION_PATH, "authorization")
    _assert_exact_control_path(state_path, STATE_PATH, "launch state")
    pre = assert_pre_receipt(pre_path, pre_sha256)
    assert_testwindow_off_quiescence(pre["testwindow_off_quiescence"])
    return _BASE_LAUNCH_PERSISTENT_TASK(
        pre_path,
        pre_sha256,
        authorization_path,
        state_path,
        resume=False,
    )


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    proof = pre.get("testwindow_off_quiescence")
    if not isinstance(proof, Mapping):
        raise B.InvalidEvidence("worker cell lacks PRE-bound TestWindow proof")
    assert_testwindow_off_quiescence(proof)
    return _BASE_RUNNER_COMMAND(pre, cell)


def _worker_run(job_path: Path) -> int:
    _assert_exact_control_path(job_path, JOB_PATH, "launch job")
    assert_testwindow_off_quiescence()
    validate_attempt002_invalid_infrastructure_closure()
    return _BASE_WORKER_RUN(job_path)


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    _assert_exact_control_path(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(state_path, STATE_PATH, "launch state")
    pre = assert_pre_receipt(pre_path, pre_sha256)
    assert_testwindow_off_quiescence(pre["testwindow_off_quiescence"])
    return _BASE_POSTFLIGHT(pre_path, pre_sha256, state_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    finalize = sub.add_parser("finalize-contract")
    finalize.add_argument("--source-commit", required=True)
    prepare = sub.add_parser("prepare-data")
    prepare.add_argument("--symbol", required=True)
    prepare.add_argument("--data-manifest", type=Path, required=True)
    prepare.add_argument("--research-data-receipt", type=Path, required=True)
    pre = sub.add_parser("pre")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--research-data-receipt", type=Path, required=True)
    pre.add_argument("--data-manifest", type=Path, required=True)
    pre.add_argument("--build-receipt", type=Path, required=True)
    pre.add_argument("--run-root", type=Path, required=True)
    pre.add_argument("--receipt", type=Path, required=True)
    launch = sub.add_parser("launch")
    launch.add_argument("--pre-receipt", type=Path, required=True)
    launch.add_argument("--pre-sha256", required=True)
    launch.add_argument("--authorization", type=Path, required=True)
    launch.add_argument("--state", type=Path, required=True)
    launch.set_defaults(resume=False)
    post = sub.add_parser("post")
    post.add_argument("--pre-receipt", type=Path, required=True)
    post.add_argument("--pre-sha256", required=True)
    post.add_argument("--state", type=Path, required=True)
    post.add_argument("--receipt", type=Path, required=True)
    status = sub.add_parser("status")
    status.add_argument("--state", type=Path, required=True)
    worker = sub.add_parser("_run-plan", help=argparse.SUPPRESS)
    worker.add_argument("--job", type=Path, required=True)
    return parser


def _configure_private_profile() -> None:
    B.__doc__ = __doc__
    B.TOOL_PATH = TOOL_PATH
    B.ANALYSIS_ID = ANALYSIS_ID
    B.MERIT_CONTRACT_VERSION = MERIT_CONTRACT_VERSION
    B.MERIT_GATES = MERIT_GATES
    B.SYMBOL_POLICY = SYMBOL_POLICY
    B.ALLOWED_RUN_ROOT = ALLOWED_RUN_ROOT
    B.SCHEDULED_TASK_PREFIX = SCHEDULED_TASK_PREFIX
    B.LAUNCHER_REVISION = LAUNCHER_REVISION
    B.REQUIRED_BINDING_ROLES = frozenset(_expected_binding_paths(RESEARCH_SYMBOL))
    B._assert_run_root = _assert_exact_run_root
    B.enforce_symbol_policy = enforce_symbol_policy
    B._validate_set_contract = X._validate_set_contract
    B._expected_binding_paths = _expected_binding_paths
    B.resolve_cost_schedule = X.resolve_cost_schedule
    B._reconstruct_trades = X._reconstruct_trades
    B.evaluate_merit = X.evaluate_merit
    B.load_bound_news_events = X.load_bound_news_events
    B.validate_trade_semantics = X.validate_trade_semantics
    B.preflight = preflight
    B.assert_pre_receipt = assert_pre_receipt
    B.validate_authorization = validate_authorization
    B.launch_persistent_task = launch_persistent_task
    B.runner_command = runner_command
    B.postflight = postflight
    B._worker_run = _worker_run
    B.build_parser = build_parser


_configure_private_profile()

AuditError = B.AuditError
InvalidEvidence = B.InvalidEvidence
AuthorizationError = B.AuthorizationError
TradeRecord = B.TradeRecord
NativeRunAudit = B.NativeRunAudit
NewsEvent = B.NewsEvent
Window = B.Window
WINDOWS = B.WINDOWS
DUPLICATES = B.DUPLICATES
TIMEFRAME = B.TIMEFRAME
REQUIRED_BINDING_ROLES = B.REQUIRED_BINDING_ROLES
XAU_CALIBRATION_PROJECTION = X.XAU_CALIBRATION_PROJECTION
XAU_SYMBOL_SPEC_CONTRACT = X.XAU_SYMBOL_SPEC_CONTRACT
ATTEMPT_COST_SCHEDULE = X.ATTEMPT_002_COST_SCHEDULE


def build_plan(symbol: str, set_binding: Mapping[str, Any], run_root: Path) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    _assert_exact_run_root(run_root)
    return B.build_plan(symbol, set_binding, run_root)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(argv) if argv is not None else sys.argv[1:]
    args = build_parser().parse_args(arguments)
    if arguments and arguments[0] == "finalize-contract":
        try:
            receipt = finalize_analysis_contract(args.source_commit)
            print(
                json.dumps(
                    {
                        "status": "FINALIZED_OUTCOME_BLIND",
                        "contract": str(CONTRACT_PATH.resolve()),
                        "sha256": receipt["binding"]["sha256"],
                        "source_build_commit": receipt["source_build_commit"],
                    },
                    indent=2,
                    sort_keys=True,
                )
            )
            return 0
        except (B.AuditError, OSError, ValueError, KeyError, TypeError) as exc:
            print(json.dumps(B.invalid_receipt("FINALIZE_CONTRACT", exc), sort_keys=True), file=sys.stderr)
            return 2
    try:
        if args.command == "pre":
            _assert_exact_control_path(args.receipt, PRE_RECEIPT_PATH, "PRE receipt")
        elif args.command == "launch":
            _assert_exact_control_path(args.pre_receipt, PRE_RECEIPT_PATH, "PRE receipt")
            _assert_exact_control_path(args.authorization, AUTHORIZATION_PATH, "authorization")
            _assert_exact_control_path(args.state, STATE_PATH, "launch state")
        elif args.command == "post":
            _assert_exact_control_path(args.pre_receipt, PRE_RECEIPT_PATH, "PRE receipt")
            _assert_exact_control_path(args.state, STATE_PATH, "launch state")
            _assert_exact_control_path(args.receipt, POST_RECEIPT_PATH, "POST receipt")
        elif args.command == "status":
            _assert_exact_control_path(args.state, STATE_PATH, "launch state")
        elif args.command == "_run-plan":
            _assert_exact_control_path(args.job, JOB_PATH, "launch job")
    except B.AuditError as exc:
        print(json.dumps(B.invalid_receipt(args.command.upper(), exc), sort_keys=True), file=sys.stderr)
        return 2
    return B.main(arguments)


def __getattr__(name: str) -> Any:
    return getattr(X, name)


if __name__ == "__main__":
    raise SystemExit(main())
