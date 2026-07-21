#!/usr/bin/env python3
"""One-shot semantic-quiescence TestWindow EURUSD audit for QM5_13210.

This is a thin execution profile over the original EURUSD.DWX auditor.  It
changes no strategy code, EX5, set, parameters, windows, costs, merit gates or
native runner arguments.  It adds an exact, unused EUR-only namespace and the
semantic TestWindow quiescence fence proven by the XAU NATIVE_003 audit:
``worker_pids.json`` is identified by exact path while only its live registered
Python-worker projection is invariant; its mutable raw bytes are not bound.

The terminal-invalid XAU NATIVE_003 closure is immutable and XAU-family-only.
This EUR profile binds that closure as a boundary marker but never imports,
resumes, retries, launches or otherwise delegates to an XAU auditor.

No function here reads controller logs, native reports, native outcomes or live
process command lines before fenced POST.
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
BASE_TOOL_PATH = TOOL_PATH.with_name("audit_mulham_asian_sweep_london.py")
_B_SPEC = importlib.util.spec_from_file_location(
    "qm13210_eur_semantic_private_base", BASE_TOOL_PATH
)
if _B_SPEC is None or _B_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load EUR base auditor: {BASE_TOOL_PATH}")
B = importlib.util.module_from_spec(_B_SPEC)
sys.modules[_B_SPEC.name] = B
_B_SPEC.loader.exec_module(B)

EA_ROOT = B.EA_ROOT
REPO_ROOT = B.REPO_ROOT
ANALYSIS_ID = "QM5_13210_MULHAM_ASIAN_SWEEP_LONDON_EURUSD_NATIVE_001"
RESEARCH_SYMBOL = "EURUSD.DWX"
MERIT_CONTRACT_VERSION = B.MERIT_CONTRACT_VERSION
MERIT_GATES = B.MERIT_GATES
SYMBOL_POLICY = B.SYMBOL_POLICY

RUN_FAMILY_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_13210")
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "EURUSD_MULHAM_NATIVE_001"
ATTEMPT_001_RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
ALLOWED_RUN_ROOT = ATTEMPT_001_RUN_ROOT
PRE_RECEIPT_PATH = ALLOWED_RUN_ROOT / "pre_receipt.json"
AUTHORIZATION_PATH = ALLOWED_RUN_ROOT / "native_outcome_authorization.json"
STATE_PATH = ALLOWED_RUN_ROOT / "launch_state.json"
JOB_PATH = ALLOWED_RUN_ROOT / "launch_job.json"
POST_RECEIPT_PATH = ALLOWED_RUN_ROOT / "post_receipt.json"
CLAIM_PATH = ALLOWED_RUN_ROOT / "native_attempt_claim.json"

SCHEDULED_TASK_PREFIX = "QM_QM13210_EUR_AUDIT_"
LAUNCHER_REVISION = "QM13210_EUR_TESTWINDOW_SEMANTIC_QUIESCENCE_V1"
AUTHORIZATION_SCOPE = (
    "QM5_13210_EURUSD_NATIVE_001_ATTEMPT_001_TESTWINDOW_OFF_"
    "SEMANTIC_QUIESCENCE_4_CELLS_X_2_DUPLICATES_MODEL4_T1"
)

DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = (
    DOC_ROOT
    / "eurusd_testwindow_semantic_outcome_fenced_analysis_contract_20260721.json"
)
BUILD_RECEIPT_PATH = DOC_ROOT / "build_receipt_20260720.json"
DATA_ROOT = RUN_FAMILY_ROOT / "data"
DATA_MANIFEST_PATH = DATA_ROOT / "EURUSD_DWX_201807_202512_T1_manifest.json"
RESEARCH_READINESS_PATH = DATA_ROOT / "EURUSD_DWX_201807_202512_T1_receipt.json"

XAU_NATIVE003_TERMINAL_CLOSURE_PATH = (
    DOC_ROOT / "xauusd_native003_invalid_terminal_closure_20260721.json"
)
EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SHA256 = (
    "6ed181536f5d1e4ebdc5b1789021d3b8562d2bd3762330d9d0e101699b789cfe"
)
EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SIZE = 4159

EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_PATH = (
    DOC_ROOT / "eurusd_native001_invalid_prelaunch_closure_20260721.json"
)
EXPECTED_EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_SHA256 = (
    "bfee1882e9d84594fe7c6d68d68935112889570888c48dabf910cd89ac345e16"
)
EXPECTED_EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_SIZE = 5478
EUR_NATIVE001_TERMINAL_STATUS = (
    "NATIVE001_INVALID_PRELAUNCH_CLOSED_OUTCOME_BLIND_FAMILY_FINAL"
)

FARM_STATE_ROOT = Path(r"D:\QM\strategy_farm\state")
FACTORY_OFF_FLAG_PATH = FARM_STATE_ROOT / "FACTORY_OFF.flag"
CODEX_PARALLEL_PATH = FARM_STATE_ROOT / "codex_parallel.txt"
WORKER_PIDS_PATH = FARM_STATE_ROOT / "worker_pids.json"
TESTWINDOW_OFF_PATH = REPO_ROOT / "tools" / "strategy_farm" / "TestWindow_OFF.ps1"
FACTORY_OFF_PATH = REPO_ROOT / "tools" / "strategy_farm" / "Factory_OFF.ps1"
TASK_MANIFEST_PATH = REPO_ROOT / "tools" / "strategy_farm" / "qm_tasks.manifest.ps1"
PROCESS_SCOPE_PATH = REPO_ROOT / "tools" / "strategy_farm" / "factory_process_scope.ps1"

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

_BASE_EXPECTED_BINDING_PATHS = B._expected_binding_paths
_BASE_PREFLIGHT = B.preflight
_BASE_ASSERT_PRE_RECEIPT = B.assert_pre_receipt
_BASE_LAUNCH_PERSISTENT_TASK = B.launch_persistent_task
_BASE_POSTFLIGHT = B.postflight
_BASE_WORKER_RUN = B._worker_run
_BASE_RUNNER_COMMAND = B.runner_command


def _assert_exact_run_root(path: Path) -> Path:
    observed = path.resolve()
    expected = ALLOWED_RUN_ROOT.resolve()
    if observed != expected:
        raise B.InvalidEvidence(
            f"semantic-quiescence EUR run root must be exactly {expected}: {observed}"
        )
    return observed


def _assert_exact_control_path(path: Path, expected: Path, label: str) -> Path:
    observed = path.resolve()
    if observed != expected.resolve():
        raise B.InvalidEvidence(f"{label} must be exactly {expected.resolve()}: {observed}")
    return observed


def _assert_namespace_contract(*, pristine: bool) -> None:
    if RUN_FAMILY_ROOT.is_dir():
        siblings = {
            item.name
            for item in RUN_FAMILY_ROOT.iterdir()
            if item.name.startswith("EURUSD_MULHAM_NATIVE_")
        }
        if not siblings <= {RUN_NAMESPACE_ROOT.name}:
            raise B.InvalidEvidence(
                f"unregistered EURUSD analysis namespace: {sorted(siblings)}"
            )
    if RUN_NAMESPACE_ROOT.is_dir():
        children = {item.name for item in RUN_NAMESPACE_ROOT.iterdir()}
        if not children <= {"ATTEMPT_001"}:
            raise B.InvalidEvidence("EUR semantic analysis contains a retry/second attempt")
    if CLAIM_PATH.exists():
        raise B.InvalidEvidence("EUR semantic native-attempt claim must remain absent")
    if pristine and ALLOWED_RUN_ROOT.exists():
        if not ALLOWED_RUN_ROOT.is_dir() or any(ALLOWED_RUN_ROOT.iterdir()):
            raise B.InvalidEvidence("EUR semantic ATTEMPT_001 root is not pristine")


def _assert_xau_family_boundary() -> dict[str, Any]:
    binding = B.file_binding(
        XAU_NATIVE003_TERMINAL_CLOSURE_PATH,
        EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SHA256,
    )
    if binding["size"] != EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SIZE:
        raise B.InvalidEvidence("XAU NATIVE_003 terminal closure size drift")
    return binding


def _require_exact_mapping(value: Any, keys: set[str], label: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping) or set(value) != keys:
        raise B.InvalidEvidence(f"{label} schema drift")
    return value


def _validate_recorded_binding(
    value: Any, expected_path: Path, label: str, *, assert_current: bool
) -> dict[str, Any]:
    row = _require_exact_mapping(value, {"path", "size", "sha256"}, label)
    if Path(str(row.get("path", ""))).resolve() != expected_path.resolve():
        raise B.InvalidEvidence(f"{label} path drift")
    if (
        not isinstance(row.get("size"), int)
        or int(row["size"]) < 0
        or not re.fullmatch(r"[0-9a-f]{64}", str(row.get("sha256", "")))
    ):
        raise B.InvalidEvidence(f"{label} binding drift")
    result = dict(row)
    if assert_current:
        B.assert_binding(result, label)
    return result


def _probe_eur_task_prefix_absence() -> dict[str, Any]:
    script = (
        "$ErrorActionPreference='Stop';"
        f"$p='{SCHEDULED_TASK_PREFIX}';"
        "$t=@(Get-ScheduledTask -TaskName ($p+'*') -ErrorAction SilentlyContinue);"
        "[ordered]@{task_name_prefix=$p;matching_task_count=$t.Count;"
        "task_names=@($t|ForEach-Object{[string]$_.TaskName});"
        "states=@($t|ForEach-Object{[string]$_.State})}"
        "|ConvertTo-Json -Depth 4 -Compress"
    )
    completed = subprocess.run(
        [
            str(B.POWERSHELL_PATH.resolve()),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
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
        raise B.InvalidEvidence("EUR scheduled-task prefix absence probe failed closed")
    try:
        payload = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise B.InvalidEvidence("EUR task-prefix probe returned invalid JSON") from exc
    expected = {
        "task_name_prefix": SCHEDULED_TASK_PREFIX,
        "matching_task_count": 0,
        "task_names": [],
        "states": [],
    }
    if payload != expected:
        raise B.InvalidEvidence("EUR audit scheduled task exists or probe schema drifted")
    return payload


def validate_eur_native001_invalid_prelaunch_closure(
    path: Path = EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_PATH,
    *,
    probe_task_absence: bool = True,
) -> dict[str, Any]:
    """Validate terminal EUR lifecycle closure without opening control content."""

    closure_binding = B.file_binding(
        path, EXPECTED_EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_SHA256
    )
    if closure_binding["size"] != EXPECTED_EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_SIZE:
        raise B.InvalidEvidence("EUR NATIVE_001 invalid-prelaunch closure size drift")
    payload = B.load_json(path)
    _require_exact_mapping(
        payload,
        {
            "schema_version",
            "artifact_type",
            "status",
            "created_utc",
            "analysis_id",
            "candidate",
            "governing_contract",
            "attempt",
            "scheduled_task_absence",
            "terminal_trigger",
            "supplied_safe_state_projection",
            "lifecycle_facts",
            "outcome_fence",
            "terminal_disposition",
        },
        "EUR NATIVE_001 invalid-prelaunch closure",
    )
    expected_identity = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_EURUSD_NATIVE001_INVALID_PRELAUNCH_CLOSURE",
        "status": EUR_NATIVE001_TERMINAL_STATUS,
        "analysis_id": ANALYSIS_ID,
    }
    if any(payload.get(key) != value for key, value in expected_identity.items()):
        raise B.InvalidEvidence("EUR NATIVE_001 closure identity drift")
    created = B.parse_utc(
        str(payload.get("created_utc", "")), "EUR NATIVE_001 closure created_utc"
    )
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("EUR NATIVE_001 closure is future-dated")
    if payload.get("candidate") != {
        "ea_id": "QM5_13210",
        "research_symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
        "magic_slot": 0,
        "magic": 132100000,
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 terminal candidate drift")

    governing = _validate_recorded_binding(
        payload.get("governing_contract"),
        CONTRACT_PATH,
        "EUR NATIVE_001 governing contract",
        assert_current=True,
    )
    if governing != {
        "path": str(CONTRACT_PATH.resolve()),
        "size": 13774,
        "sha256": "1962f3b81fbc5e070597a731749a44bb59f44b64ff7bd56f7f4b825bda864a6c",
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 governing contract binding drift")

    attempt = _require_exact_mapping(
        payload.get("attempt"),
        {
            "attempt_id",
            "run_root",
            "pre_receipt",
            "authorization",
            "launch_job",
            "launch_state",
            "native_attempt_claim",
            "post_receipt",
            "native_root",
        },
        "EUR NATIVE_001 terminal attempt",
    )
    if (
        attempt.get("attempt_id") != "ATTEMPT_001"
        or Path(str(attempt.get("run_root", ""))).resolve()
        != ATTEMPT_001_RUN_ROOT.resolve()
    ):
        raise B.InvalidEvidence("EUR NATIVE_001 terminal attempt identity drift")
    expected_bindings = {
        "pre_receipt": {
            "path": str(PRE_RECEIPT_PATH.resolve()),
            "size": 56811,
            "sha256": "f5604ea9c95598af47fb4ce97f3021ed3a8397ffa0f7e6b28153ccb8f9963eb3",
        },
        "authorization": {
            "path": str(AUTHORIZATION_PATH.resolve()),
            "size": 714,
            "sha256": "51c8e4e63f8928cfded9d338136897f4a79b75b6a157e67fce6f9aa7ea5e6829",
        },
        "launch_job": {
            "path": str(JOB_PATH.resolve()),
            "size": 2176,
            "sha256": "9892bb23a875bada40ff2a3ca381116937897d833c72e5ebe76e596190a1a4c6",
        },
        "launch_state": {
            "path": str(STATE_PATH.resolve()),
            "size": 3707,
            "sha256": "a01cc40c27b0c64bcf80f5b223ac11075665c5ba8b0f63aabe072053e89a8c30",
        },
    }
    for role, expected in expected_bindings.items():
        observed = _validate_recorded_binding(
            attempt.get(role),
            Path(expected["path"]),
            f"EUR NATIVE_001 terminal {role}",
            assert_current=True,
        )
        if observed != expected:
            raise B.InvalidEvidence(f"EUR NATIVE_001 terminal {role} binding drift")

    claim = _require_exact_mapping(
        attempt.get("native_attempt_claim"),
        {"path", "exists"},
        "EUR NATIVE_001 claim absence",
    )
    if claim != {"path": str(CLAIM_PATH.resolve()), "exists": False} or CLAIM_PATH.exists():
        raise B.InvalidEvidence("EUR NATIVE_001 optional claim appeared after closure")
    post = _require_exact_mapping(
        attempt.get("post_receipt"), {"path", "exists"}, "EUR NATIVE_001 POST absence"
    )
    if post != {"path": str(POST_RECEIPT_PATH.resolve()), "exists": False} or POST_RECEIPT_PATH.exists():
        raise B.InvalidEvidence("EUR NATIVE_001 POST appeared after closure")
    native_path = ATTEMPT_001_RUN_ROOT / "native"
    native = _require_exact_mapping(
        attempt.get("native_root"),
        {"path", "exists", "entries"},
        "EUR NATIVE_001 native-root absence",
    )
    if native != {
        "path": str(native_path.resolve()),
        "exists": False,
        "entries": [],
    } or native_path.exists():
        raise B.InvalidEvidence("EUR NATIVE_001 native root appeared after closure")

    task_absence = _require_exact_mapping(
        payload.get("scheduled_task_absence"),
        {
            "inspection_mode",
            "task_name_prefix",
            "matching_task_count",
            "task_names",
            "states",
        },
        "EUR NATIVE_001 scheduled-task absence",
    )
    if task_absence != {
        "inspection_mode": "TASK_NAME_PREFIX_AND_STATE_ONLY_NO_ACTION_OR_LOG_CONTENT_READ",
        "task_name_prefix": SCHEDULED_TASK_PREFIX,
        "matching_task_count": 0,
        "task_names": [],
        "states": [],
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 scheduled-task absence drift")
    if probe_task_absence:
        _probe_eur_task_prefix_absence()

    if payload.get("terminal_trigger") != {
        "phase": "LAUNCH",
        "classification": "SCHEDULED_TASK_HELPER_REGISTER_FAILED_BEFORE_REGISTRATION",
        "exception_type": "AuthorizationError",
        "safe_error": "scheduled-task helper 'Register' failed with exit 1",
        "scheduler_registration_completed": False,
        "scheduled_task_materialized": False,
        "worker_registered": False,
        "native_controller_started": False,
        "fact_source": "ROOT_SUPPLIED_SAFE_METADATA_PLUS_TASK_NAME_PREFIX_ABSENCE",
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 terminal trigger drift")
    if payload.get("supplied_safe_state_projection") != {
        "source": "ROOT_SUPPLIED_SAFE_METADATA",
        "launch_state_status": "PENDING_SCHEDULED",
        "worker_pid": None,
        "cell_status_counts": {"PENDING": 4},
        "state_or_job_content_opened_by_closure_author": False,
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 supplied state projection drift")
    if payload.get("lifecycle_facts") != {
        "pre_receipt_materialized": True,
        "authorization_materialized": True,
        "launch_job_materialized": True,
        "launch_state_materialized": True,
        "scheduled_task_materialized": False,
        "scheduler_worker_started": False,
        "native_root_materialized": False,
        "native_controller_start_count": 0,
        "native_summary_count": 0,
        "native_outcome_artifact_count": 0,
        "optional_native_attempt_claim_materialized": False,
        "post_receipt_materialized": False,
        "claim_absence_does_not_restore_attempt_budget": True,
        "one_shot_attempt_consumed": True,
        "remaining_attempt_budget": 0,
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 lifecycle-consumption drift")
    if payload.get("outcome_fence") != {
        "pre_receipt_content_opened_by_closure_author": False,
        "authorization_content_opened_by_closure_author": False,
        "launch_job_content_opened_by_closure_author": False,
        "launch_state_content_opened_by_closure_author": False,
        "supplied_safe_state_projection_used": True,
        "controller_or_scheduler_log_content_opened": False,
        "native_report_content_opened": False,
        "tester_log_content_opened": False,
        "deal_rows_opened": False,
        "economic_outcomes_opened": False,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
        "control_artifacts_bound_by_path_size_sha256_only": True,
        "filesystem_and_task_absence_checked_by_name_type_only": True,
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 outcome fence drift")
    if payload.get("terminal_disposition") != {
        "classification": "INVALID_INFRASTRUCTURE_PRELAUNCH_NO_STRATEGY_MERIT_ADJUDICATION",
        "strategy_merit_verdict": "NONE",
        "family_final": True,
        "post_permitted": False,
        "post_retry_permitted": False,
        "resume_permitted": False,
        "relaunch_permitted": False,
        "attempt_002_permitted": False,
        "further_eurusd_audit_attempt_in_family_permitted": False,
        "all_bound_controls_must_remain_immutable": True,
    }:
        raise B.InvalidEvidence("EUR NATIVE_001 terminal disposition drift")
    return payload


def _raise_eur_native001_family_closed(operation: str) -> None:
    validate_eur_native001_invalid_prelaunch_closure()
    raise B.AuthorizationError(
        f"NATIVE_001 EUR family is terminal-invalid; {operation} is permanently forbidden"
    )


def enforce_symbol_policy(symbol: str) -> None:
    B.enforce_symbol_policy(symbol)


def _assert_exact_data_paths(manifest: Path, readiness: Path) -> None:
    _assert_exact_control_path(manifest, DATA_MANIFEST_PATH, "EUR data manifest")
    _assert_exact_control_path(
        readiness, RESEARCH_READINESS_PATH, "EUR research-readiness receipt"
    )


def _require_preregistered_eur_data_artifacts() -> dict[str, dict[str, Any]]:
    missing = [
        path
        for path in (DATA_MANIFEST_PATH, RESEARCH_READINESS_PATH)
        if not path.is_file()
    ]
    if missing:
        rendered = ", ".join(str(path.resolve()) for path in missing)
        raise B.InvalidEvidence(
            "EURUSD.DWX PRE blocked: preregistered tick-data manifest/readiness "
            f"artifact(s) missing at exact path(s): {rendered}; run prepare-data "
            "with the adapter's exact canonical paths before finalization and PRE"
        )
    manifest = B.validate_data_manifest(DATA_MANIFEST_PATH, RESEARCH_SYMBOL)
    readiness = B.validate_research_readiness_receipt(
        RESEARCH_READINESS_PATH,
        RESEARCH_SYMBOL,
        manifest["manifest"]["sha256"],
    )
    if readiness.get("scope") != {
        "hcc_years": "2018..2025",
        "tkc_months": "201807..202512",
        "model": 4,
        "live_parity_required": False,
        "deployment_routing_evaluated": False,
    }:
        raise B.InvalidEvidence("EURUSD.DWX readiness scope drift")
    return {
        "research_data_manifest": B.file_binding(DATA_MANIFEST_PATH),
        "research_readiness_receipt": B.file_binding(RESEARCH_READINESS_PATH),
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
        raise B.InvalidEvidence(
            "TestWindow-OFF runtime probe returned invalid JSON"
        ) from exc
    if not isinstance(payload, dict):
        raise B.InvalidEvidence("TestWindow-OFF runtime probe root is not an object")
    return payload


def _probe_worker_mutexes() -> list[str]:
    if sys.platform != "win32":  # pragma: no cover - Windows-only auditor
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
            synchronize, False, f"Global\\QM_TerminalWorker_{terminal}"
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
    if set(flag) != {"off_at", "codex_parallel_before"} or not str(
        flag.get("codex_parallel_before", "")
    ).strip():
        raise B.InvalidEvidence("FACTORY_OFF.flag schema drift")
    off_at = B.parse_utc(str(flag.get("off_at", "")), "FACTORY_OFF off_at")
    observed = datetime.now(timezone.utc)
    if off_at > observed or observed - off_at < timedelta(seconds=3):
        raise B.InvalidEvidence("TestWindow-OFF flag is future-dated or not settled")
    if (
        not CODEX_PARALLEL_PATH.is_file()
        or CODEX_PARALLEL_PATH.read_text(encoding="ascii").strip() != "0"
    ):
        raise B.InvalidEvidence("TestWindow-OFF requires codex_parallel=0")
    if not WORKER_PIDS_PATH.is_file():
        raise B.InvalidEvidence("TestWindow-OFF worker PID registry is missing")

    runtime = _probe_quiescence_runtime()
    tasks = runtime.get("scheduled_tasks")
    if (
        not isinstance(tasks, list)
        or [row.get("task_name") for row in tasks if isinstance(row, Mapping)]
        != list(MANAGED_OFF_TASKS)
    ):
        raise B.InvalidEvidence("TestWindow-OFF scheduled-task probe closure drift")
    if any(
        not isinstance(row, Mapping)
        or row.get("count") != 1
        or row.get("state") != "Disabled"
        for row in tasks
    ):
        raise B.InvalidEvidence("TestWindow-OFF managed tasks are not all disabled")
    if runtime.get("exact_factory_mt5_processes") != []:
        raise B.InvalidEvidence(
            "TestWindow-OFF has an exact T1-T10 terminal/metatester process"
        )
    if runtime.get("registered_factory_python_workers") != []:
        raise B.InvalidEvidence(
            "TestWindow-OFF has a semantically live registered Python worker"
        )
    worker_mutexes = _probe_worker_mutexes()
    if worker_mutexes:
        raise B.InvalidEvidence(
            f"TestWindow-OFF has active terminal-worker mutexes: {worker_mutexes}"
        )
    invariant = {
        "contract_version": "QM13210_TESTWINDOW_OFF_QUIESCENCE_V2_SEMANTIC_WORKERS",
        "factory_off_flag": {"binding": flag_binding, "payload": flag},
        "codex_parallel": {
            "binding": B.file_binding(CODEX_PARALLEL_PATH),
            "value": "0",
        },
        "worker_pid_registry": {
            "path": str(WORKER_PIDS_PATH.resolve()),
            "binding_mode": "SEMANTIC_LIVE_REGISTERED_WORKER_PROJECTION",
            "raw_sha256_bound": False,
            "raw_size_bound": False,
        },
        "managed_task_states": tasks,
        "exact_factory_mt5_processes": [],
        "registered_factory_python_workers": [],
        "active_terminal_worker_mutexes": [],
        "live_process_projection": "REGISTRY_PID_LIVENESS_PLUS_PYTHON_IMAGE_NAME_ONLY",
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
            or expected.get("invariant_sha256")
            != B.canonical_sha256(expected.get("invariant"))
            or expected.get("invariant") != observed["invariant"]
            or expected.get("invariant_sha256") != observed["invariant_sha256"]
        ):
            raise B.InvalidEvidence("TestWindow-OFF semantic PRE invariant drift")
        B.parse_utc(str(expected.get("observed_utc", "")), "PRE quiescence observed_utc")
    return observed


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths["tool"] = TOOL_PATH
    paths.update(
        {
            "base_tool": BASE_TOOL_PATH,
            "eur_semantic_contract": CONTRACT_PATH,
            "xau_native003_terminal_closure": XAU_NATIVE003_TERMINAL_CLOSURE_PATH,
            "testwindow_off": TESTWINDOW_OFF_PATH,
            "factory_off": FACTORY_OFF_PATH,
            "task_manifest": TASK_MANIFEST_PATH,
            "process_scope": PROCESS_SCOPE_PATH,
        }
    )
    return paths


def _artifact_contract_paths() -> dict[str, Path]:
    paths = _BASE_EXPECTED_BINDING_PATHS(RESEARCH_SYMBOL)
    paths.pop("tool", None)
    paths.update(
        {
            "adapter": TOOL_PATH,
            "base_tool": BASE_TOOL_PATH,
            "build_receipt": BUILD_RECEIPT_PATH,
            "research_data_manifest": DATA_MANIFEST_PATH,
            "research_readiness_receipt": RESEARCH_READINESS_PATH,
            "xau_native003_terminal_closure": XAU_NATIVE003_TERMINAL_CLOSURE_PATH,
            "testwindow_off": TESTWINDOW_OFF_PATH,
            "factory_off": FACTORY_OFF_PATH,
            "task_manifest": TASK_MANIFEST_PATH,
            "process_scope": PROCESS_SCOPE_PATH,
        }
    )
    return paths


FINAL_ARTIFACT_ROLES = frozenset(_artifact_contract_paths())


def _candidate_contract() -> dict[str, Any]:
    return {
        "ea_id": "QM5_13210",
        "strategy": (
            "Mulham Asian liquidity sweep, M5 MSS/displacement and "
            "FVG midpoint mitigation"
        ),
        "research_symbol": RESEARCH_SYMBOL,
        "research_namespace": ".DWX",
        "live_symbol_alias_policy": "DEPLOY_PACKAGING_ONLY_EXACT_VENUE_ALIAS",
        "timeframe": "M5",
        "model": 4,
        "magic_slot": 0,
        "magic": 132100000,
        "duplicates_per_cell": B.DUPLICATES,
        "source_build_commit": B.EXPECTED_BUILD_COMMIT,
        "set_sha256": B.EXPECTED_BUILD_HASHES["set"],
        "registry_worst_case_rt_per_lot_usd": "5.85",
        "cost_application": "UNCHANGED_BASE_MAX_DXZ_PCT_NOTIONAL_OR_FTMO_FLAT",
        "merit_contract_version": MERIT_CONTRACT_VERSION,
        "merit_gates": MERIT_GATES,
    }


def _windows_contract() -> list[dict[str, Any]]:
    return [
        {
            "cell_id": window.cell_id,
            "cohort": window.cohort,
            "from_date": window.from_date.isoformat(),
            "to_date": window.to_date.isoformat(),
        }
        for window in B.WINDOWS
    ]


def _run_namespace_contract() -> dict[str, Any]:
    return {
        "family_root": str(RUN_FAMILY_ROOT.resolve()),
        "namespace": str(RUN_NAMESPACE_ROOT.resolve()),
        "attempt_id": "ATTEMPT_001",
        "single_run_root": str(ALLOWED_RUN_ROOT.resolve()),
        "resume_forbidden": True,
        "retry_or_attempt002_plus_forbidden": True,
        "native_attempt_claim": {
            "path": str(CLAIM_PATH.resolve()),
            "must_remain_absent": True,
        },
        "exact_control_paths": {
            "pre": str(PRE_RECEIPT_PATH.resolve()),
            "authorization": str(AUTHORIZATION_PATH.resolve()),
            "state": str(STATE_PATH.resolve()),
            "job": str(JOB_PATH.resolve()),
            "post": str(POST_RECEIPT_PATH.resolve()),
        },
    }


def _data_contract() -> dict[str, Any]:
    return {
        "symbol": RESEARCH_SYMBOL,
        "research_store": "T1_CUSTOM_SYMBOL_STORE",
        "purpose": "RESEARCH_BACKTEST_ONLY",
        "manifest_path": str(DATA_MANIFEST_PATH.resolve()),
        "readiness_path": str(RESEARCH_READINESS_PATH.resolve()),
        "coverage": {"from_date": "2018-07-02", "to_date": "2025-12-31"},
        "required_file_closure": {"hcc_years": 8, "tkc_months": 90},
        "model": 4,
        "live_parity_required": False,
        "deployment_routing_evaluated": False,
        "both_artifacts_must_exist_and_validate_before_finalization_and_pre": True,
    }


def _testwindow_contract() -> dict[str, Any]:
    return {
        "version": "QM13210_TESTWINDOW_OFF_QUIESCENCE_V2_SEMANTIC_WORKERS",
        "required_at": [
            "PRE",
            "LAUNCH",
            "WORKER_BOOTSTRAP",
            "BEFORE_EACH_NATIVE_CELL",
            "POST",
        ],
        "factory_off_flag_binding_required": True,
        "codex_parallel_binding_and_value_exact": "0",
        "managed_tasks_exactly_disabled": list(MANAGED_OFF_TASKS),
        "exact_t1_t10_terminal_and_metatester_count": 0,
        "registered_live_factory_python_worker_count": 0,
        "worker_registry_exact_path": str(WORKER_PIDS_PATH.resolve()),
        "worker_registry_raw_sha256_bound": False,
        "worker_registry_raw_size_bound": False,
        "worker_registry_live_projection": "REGISTRY_PID_LIVENESS_PLUS_PYTHON_IMAGE_NAME_ONLY",
        "factory_flag_codex_tasks_processes_mutexes_and_semantic_workers_must_match_pre": True,
        "live_process_command_line_reads_forbidden": True,
        "live_process_command_line_output_forbidden": True,
    }


def _xau_family_boundary_contract() -> dict[str, Any]:
    return {
        "terminal_closure_path": str(XAU_NATIVE003_TERMINAL_CLOSURE_PATH.resolve()),
        "terminal_closure_sha256": EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SHA256,
        "terminal_closure_size": EXPECTED_XAU_NATIVE003_TERMINAL_CLOSURE_SIZE,
        "closure_scope": "XAUUSD.DWX_XAUUSD_MULHAM_NATIVE_003_ONLY",
        "xau_family_is_terminal_and_must_never_resume_retry_or_relaunch": True,
        "eurusd_analysis_is_a_distinct_unused_symbol_slot_family": True,
        "eurusd_adapter_imports_or_delegates_to_xau_auditors": False,
    }


def _outcome_fence_contract() -> dict[str, bool]:
    return {
        "native_reports_opened_before_post": False,
        "deal_rows_parsed_before_post": False,
        "controller_logs_opened_before_post": False,
        "native_outcomes_opened_before_post": False,
        "mt5_started_by_prepare_pre_or_contract_finalization": False,
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
    }


def _draft_contract_payload() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13210_EURUSD_SEMANTIC_TESTWINDOW_ANALYSIS_CONTRACT",
        "status": "DRAFT_PENDING_FINAL_FREEZE",
        "analysis_id": ANALYSIS_ID,
        "candidate": _candidate_contract(),
        "windows": _windows_contract(),
        "data": _data_contract(),
        "run_namespace": _run_namespace_contract(),
        "testwindow_off_quiescence": _testwindow_contract(),
        "xau_family_boundary": _xau_family_boundary_contract(),
        "outcome_fence": _outcome_fence_contract(),
        "finalization": {
            "required_command": (
                "audit_mulham_asian_sweep_london_eur_testwindow_semantic.py "
                "finalize-contract --source-commit "
                f"{B.EXPECTED_BUILD_COMMIT}"
            ),
            "requires_committed_clean_adapter_and_draft": True,
            "requires_pristine_eur_namespace": True,
            "requires_valid_exact_eur_manifest_and_readiness": True,
            "pre_and_launch_forbidden_until_status": "FINALIZED_OUTCOME_BLIND",
            "final_contract_must_bind_roles": sorted(FINAL_ARTIFACT_ROLES),
        },
    }


def validate_draft_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    payload = B.load_json(path)
    if payload != _draft_contract_payload():
        raise B.InvalidEvidence("semantic TestWindow EUR draft contract drift")
    return payload


def _validate_artifact_bindings(
    bindings: Any, *, allow_historical_executed_adapter: bool = False
) -> dict[str, dict[str, Any]]:
    paths = _artifact_contract_paths()
    if not isinstance(bindings, Mapping) or set(bindings) != set(paths):
        raise B.InvalidEvidence("semantic TestWindow EUR artifact-role closure drift")
    result: dict[str, dict[str, Any]] = {}
    for role, path in paths.items():
        row = bindings.get(role)
        if not isinstance(row, Mapping) or set(row) != {"path", "size", "sha256"}:
            raise B.InvalidEvidence(f"malformed finalized artifact binding: {role}")
        if Path(str(row.get("path", ""))).resolve() != path.resolve():
            raise B.InvalidEvidence(f"finalized artifact path drift: {role}")
        if role == "adapter" and allow_historical_executed_adapter:
            if (
                not isinstance(row.get("size"), int)
                or int(row["size"]) < 0
                or not re.fullmatch(r"[0-9a-f]{64}", str(row.get("sha256", "")))
            ):
                raise B.InvalidEvidence("historical executed EUR adapter binding drift")
        else:
            B.assert_binding(row, f"semantic TestWindow EUR finalized {role}")
        result[role] = dict(row)
    closure = result["xau_native003_terminal_closure"]
    if closure != _assert_xau_family_boundary():
        raise B.InvalidEvidence("finalized XAU family-boundary binding drift")
    return result


def _validate_frozen_eur_execution_identity(
    artifacts: Mapping[str, Mapping[str, Any]], source_commit: str
) -> None:
    build = B.validate_build_receipt(
        BUILD_RECEIPT_PATH, RESEARCH_SYMBOL, artifacts
    )
    if build.get("build_commit") != source_commit:
        raise B.InvalidEvidence("finalized EUR build receipt/source commit drift")
    metadata, set_inputs = B.parse_set(Path(str(artifacts["set"]["path"])))
    B._validate_set_contract(RESEARCH_SYMBOL, metadata, set_inputs)
    cost = B.resolve_cost_schedule(
        Path(str(artifacts["cost"]["path"])),
        RESEARCH_SYMBOL,
        Path(str(artifacts["live_commission"]["path"])),
    )
    if (
        cost.get("registry_indicative_rt_per_lot_usd") != "5.85"
        or cost.get("ftmo_rt_per_lot_usd") != "5"
        or cost.get("dxz_pct_notional_rt") != "0.00005"
    ):
        raise B.InvalidEvidence("finalized EUR cost identity drift")


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
        "artifact_bindings": {
            role: dict(bindings[role]) for role in sorted(FINAL_ARTIFACT_ROLES)
        },
    }


def validate_analysis_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    terminal_closure = validate_eur_native001_invalid_prelaunch_closure()
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected_fields = set(_draft_contract_payload()) - {"finalization"}
    expected_fields |= {"finalized_utc", "source_build_commit", "artifact_bindings"}
    if set(payload) != expected_fields:
        raise B.InvalidEvidence("semantic TestWindow EUR contract is not finalized")
    if (
        payload.get("status") != "FINALIZED_OUTCOME_BLIND"
        or payload.get("analysis_id") != ANALYSIS_ID
        or payload.get("artifact_type")
        != "QM5_13210_EURUSD_SEMANTIC_TESTWINDOW_ANALYSIS_CONTRACT"
    ):
        raise B.InvalidEvidence("semantic TestWindow EUR finalized identity drift")
    finalized = B.parse_utc(
        str(payload.get("finalized_utc", "")), "semantic TestWindow EUR finalized_utc"
    )
    if finalized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("semantic TestWindow EUR finalization time is in the future")
    source_commit = str(payload.get("source_build_commit", ""))
    if source_commit != B.EXPECTED_BUILD_COMMIT:
        raise B.InvalidEvidence("EUR source build commit drift")
    semantic = _draft_contract_payload()
    semantic.pop("finalization")
    semantic["status"] = "FINALIZED_OUTCOME_BLIND"
    drift = {
        key: (value, payload.get(key))
        for key, value in semantic.items()
        if payload.get(key) != value
    }
    if drift:
        raise B.InvalidEvidence(
            f"semantic TestWindow EUR finalized drift: {sorted(drift)}"
        )
    artifacts = _validate_artifact_bindings(
        payload.get("artifact_bindings"), allow_historical_executed_adapter=True
    )
    _validate_frozen_eur_execution_identity(artifacts, source_commit)
    _require_preregistered_eur_data_artifacts()
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "source_build_commit": source_commit,
        "artifact_bindings": artifacts,
        "testwindow_off_quiescence": payload["testwindow_off_quiescence"],
        "xau_family_boundary": payload["xau_family_boundary"],
        "eur_native001_terminal_closure": {
            "binding": B.file_binding(
                EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_PATH,
                EXPECTED_EUR_NATIVE001_INVALID_PRELAUNCH_CLOSURE_SHA256,
            ),
            "status": terminal_closure["status"],
        },
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
    if source_commit != B.EXPECTED_BUILD_COMMIT:
        raise B.InvalidEvidence(
            f"finalize requires exact build commit {B.EXPECTED_BUILD_COMMIT}"
        )
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
        raise B.InvalidEvidence("finalize requires committed clean EUR adapter and draft")
    for role in ("mq5", "ex5", "spec", "set"):
        if _git(
            ["diff", "--quiet", source_commit, "--", _repo_relative(paths[role])]
        ).returncode != 0:
            raise B.InvalidEvidence(f"source artifact differs from build commit: {role}")


def _assert_finalized_contract_committed() -> None:
    relative = _repo_relative(CONTRACT_PATH)
    tracked = _git(["ls-files", "--error-unmatch", "--", relative])
    status = _git(["status", "--porcelain=v1", "--untracked-files=all", "--", relative])
    if tracked.returncode != 0 or status.returncode != 0 or status.stdout.strip():
        raise B.InvalidEvidence("PRE requires committed clean finalized EUR contract")


def finalize_analysis_contract(source_commit: str) -> dict[str, Any]:
    _raise_eur_native001_family_closed("contract finalization or replacement")
    validate_draft_contract()
    _assert_namespace_contract(pristine=True)
    _assert_source_freeze_ready(source_commit)
    _require_preregistered_eur_data_artifacts()
    _assert_xau_family_boundary()
    artifacts = {
        role: B.file_binding(path) for role, path in _artifact_contract_paths().items()
    }
    _validate_frozen_eur_execution_identity(artifacts, source_commit)
    payload = _final_payload(source_commit, B.utc_now(), artifacts)
    digest = B.atomic_json(CONTRACT_PATH, payload, replace=True)
    result = validate_analysis_contract()
    if result["binding"]["sha256"] != digest:
        raise B.InvalidEvidence("finalized EUR semantic contract write drift")
    return result


def preflight(
    symbol: str,
    research_readiness_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    _raise_eur_native001_family_closed("PRE or another audit attempt")
    enforce_symbol_policy(symbol)
    _assert_exact_data_paths(data_manifest_path, research_readiness_receipt_path)
    _require_preregistered_eur_data_artifacts()
    _assert_xau_family_boundary()
    _assert_namespace_contract(pristine=True)
    _assert_exact_run_root(run_root)
    if build_receipt_path.resolve() != BUILD_RECEIPT_PATH.resolve():
        raise B.InvalidEvidence("EUR semantic PRE build receipt path drift")
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
    cost = pre.get("cost_schedule")
    if (
        not isinstance(cost, Mapping)
        or cost.get("registry_indicative_rt_per_lot_usd") != "5.85"
        or cost.get("ftmo_rt_per_lot_usd") != "5"
        or cost.get("dxz_pct_notional_rt") != "0.00005"
        or pre.get("merit_contract") != MERIT_GATES
    ):
        raise B.InvalidEvidence("EUR semantic costs or merit gates drifted")
    for pre_role, item in pre["bindings"].items():
        if pre_role == "eur_semantic_contract":
            if item != contract["binding"]:
                raise B.InvalidEvidence("PRE binding differs from finalized EUR contract")
            continue
        contract_role = "adapter" if pre_role == "tool" else pre_role
        if item != contract["artifact_bindings"].get(contract_role):
            raise B.InvalidEvidence(
                f"PRE binding differs from finalized artifact: {contract_role}"
            )
    if pre.get("build_receipt") != contract["artifact_bindings"]["build_receipt"]:
        raise B.InvalidEvidence("PRE build receipt differs from finalized artifact")
    if pre.get("research_readiness_receipt") != contract["artifact_bindings"][
        "research_readiness_receipt"
    ]:
        raise B.InvalidEvidence("PRE readiness receipt differs from finalized artifact")
    if pre.get("data", {}).get("manifest") != contract["artifact_bindings"][
        "research_data_manifest"
    ]:
        raise B.InvalidEvidence("PRE data manifest differs from finalized artifact")
    pre["attempt_id"] = "ATTEMPT_001"
    pre["testwindow_off_quiescence"] = quiescence
    pre["eur_semantic_testwindow_preregistration"] = contract
    pre["xau_family_boundary"] = contract["xau_family_boundary"]
    return pre


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _raise_eur_native001_family_closed("PRE reuse or continuation")
    _assert_exact_control_path(path, PRE_RECEIPT_PATH, "PRE receipt")
    contract = validate_analysis_contract()
    _assert_finalized_contract_committed()
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    if pre.get("attempt_id") != "ATTEMPT_001":
        raise B.InvalidEvidence("EUR semantic PRE attempt identity drift")
    if pre.get("eur_semantic_testwindow_preregistration") != contract:
        raise B.InvalidEvidence("PRE finalized EUR semantic contract drift")
    if pre.get("xau_family_boundary") != contract["xau_family_boundary"]:
        raise B.InvalidEvidence("PRE XAU family boundary drift")
    proof = pre.get("testwindow_off_quiescence")
    if not isinstance(proof, Mapping):
        raise B.InvalidEvidence("PRE semantic TestWindow proof missing")
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
    if set(payload) != set(expected) | {"created_utc", "expires_utc"}:
        raise B.AuthorizationError("EUR semantic authorization schema drift")
    drift = {
        key: (value, payload.get(key))
        for key, value in expected.items()
        if payload.get(key) != value
    }
    if drift:
        raise B.AuthorizationError(f"EUR semantic authorization drift: {drift}")
    created = B.parse_utc(str(payload.get("created_utc", "")), "authorization created_utc")
    expires = B.parse_utc(str(payload.get("expires_utc", "")), "authorization expires_utc")
    if expires <= created or expires - created > timedelta(hours=24):
        raise B.AuthorizationError("authorization lifetime must be >0 and <=24h")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if require_current and not (created - timedelta(minutes=5) <= current <= expires):
        raise B.AuthorizationError("authorization is not currently valid")
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "payload": payload,
    }


def launch_persistent_task(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    _raise_eur_native001_family_closed("resume, relaunch, or another audit attempt")
    if resume:
        raise B.AuthorizationError("EUR semantic analysis is one-shot; resume is forbidden")
    _assert_exact_control_path(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(authorization_path, AUTHORIZATION_PATH, "authorization")
    _assert_exact_control_path(state_path, STATE_PATH, "launch state")
    if CLAIM_PATH.exists():
        raise B.AuthorizationError("native-attempt claim is forbidden for this EUR profile")
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
    _raise_eur_native001_family_closed("native cell continuation")
    proof = pre.get("testwindow_off_quiescence")
    if not isinstance(proof, Mapping):
        raise B.InvalidEvidence("worker cell lacks PRE-bound semantic TestWindow proof")
    assert_testwindow_off_quiescence(proof)
    return _BASE_RUNNER_COMMAND(pre, cell)


def _worker_run(job_path: Path) -> int:
    _raise_eur_native001_family_closed("worker replay or continuation")
    _assert_exact_control_path(job_path, JOB_PATH, "launch job")
    assert_testwindow_off_quiescence()
    _assert_xau_family_boundary()
    return _BASE_WORKER_RUN(job_path)


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    _raise_eur_native001_family_closed("POST or POST retry")
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
    B._expected_binding_paths = _expected_binding_paths
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
            print(
                json.dumps(B.invalid_receipt("FINALIZE_CONTRACT", exc), sort_keys=True),
                file=sys.stderr,
            )
            return 2
    try:
        if args.command == "prepare-data":
            enforce_symbol_policy(args.symbol)
            _assert_exact_data_paths(args.data_manifest, args.research_data_receipt)
        elif args.command == "pre":
            _assert_exact_control_path(args.receipt, PRE_RECEIPT_PATH, "PRE receipt")
            _assert_exact_data_paths(args.data_manifest, args.research_data_receipt)
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
        print(
            json.dumps(B.invalid_receipt(args.command.upper(), exc), sort_keys=True),
            file=sys.stderr,
        )
        return 2
    return B.main(arguments)


def __getattr__(name: str) -> Any:
    return getattr(B, name)


if __name__ == "__main__":
    raise SystemExit(main())
