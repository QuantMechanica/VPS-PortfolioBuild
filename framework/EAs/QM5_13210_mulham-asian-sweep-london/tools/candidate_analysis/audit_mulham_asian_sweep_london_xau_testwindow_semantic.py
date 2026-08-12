#!/usr/bin/env python3
"""One-shot semantic-quiescence TestWindow XAU audit for QM5_13210.

This is a thin profile over the finalized NATIVE_002 TestWindow auditor.  It
changes no EA, EX5, set, data, parameters, windows, costs, runner arguments or
merit gates.  The only execution-contract change is that worker_pids.json is
identified by its exact path and evaluated as a live-process projection; its
mutable raw bytes are not part of the PRE invariant.

The predecessor closure is outcome-blind.  No controller log, native report,
native outcome or live process command line is read or emitted here.
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
SUPERSEDED_TOOL_PATH = TOOL_PATH.with_name(
    "audit_mulham_asian_sweep_london_xau_testwindow.py"
)
_T_SPEC = importlib.util.spec_from_file_location(
    "qm13210_xau_semantic_private_superseded", SUPERSEDED_TOOL_PATH
)
if _T_SPEC is None or _T_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load superseded TestWindow auditor: {SUPERSEDED_TOOL_PATH}")
T = importlib.util.module_from_spec(_T_SPEC)
sys.modules[_T_SPEC.name] = T
_T_SPEC.loader.exec_module(T)
B = T.B

EA_ROOT = T.EA_ROOT
REPO_ROOT = T.REPO_ROOT
ANALYSIS_ID = "QM5_13210_MULHAM_ASIAN_SWEEP_LONDON_XAUUSD_NATIVE_003"
RESEARCH_SYMBOL = T.RESEARCH_SYMBOL
MERIT_CONTRACT_VERSION = T.MERIT_CONTRACT_VERSION
MERIT_GATES = T.MERIT_GATES
SYMBOL_POLICY = T.SYMBOL_POLICY
RUN_FAMILY_ROOT = T.RUN_FAMILY_ROOT
ORIGINAL_NAMESPACE_ROOT = T.SUPERSEDED_NAMESPACE_ROOT
SUPERSEDED_NAMESPACE_ROOT = T.RUN_NAMESPACE_ROOT
SUPERSEDED_RUN_ROOT = T.ALLOWED_RUN_ROOT
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "XAUUSD_MULHAM_NATIVE_003"
ATTEMPT_001_RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
ALLOWED_RUN_ROOT = ATTEMPT_001_RUN_ROOT
SCHEDULED_TASK_PREFIX = T.SCHEDULED_TASK_PREFIX
LAUNCHER_REVISION = "QM13210_XAU_TESTWINDOW_SEMANTIC_QUIESCENCE_V2"
AUTHORIZATION_SCOPE = (
    "QM5_13210_XAUUSD_NATIVE_003_ATTEMPT_001_TESTWINDOW_OFF_"
    "SEMANTIC_QUIESCENCE_4_CELLS_X_2_DUPLICATES_MODEL4_T1"
)

DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = (
    DOC_ROOT
    / "xauusd_testwindow_semantic_outcome_fenced_analysis_contract_20260721.json"
)
SUPERSEDED_CONTRACT_PATH = T.CONTRACT_PATH
NATIVE002_CLOSURE_PATH = (
    DOC_ROOT / "xauusd_native002_invalid_prelaunch_closure_20260721.json"
)
NATIVE003_TERMINAL_CLOSURE_PATH = (
    DOC_ROOT / "xauusd_native003_invalid_terminal_closure_20260721.json"
)
EXPECTED_NATIVE003_TERMINAL_CLOSURE_SHA256 = (
    "6ed181536f5d1e4ebdc5b1789021d3b8562d2bd3762330d9d0e101699b789cfe"
)
EXPECTED_NATIVE003_TERMINAL_CLOSURE_SIZE = 4159
NATIVE003_TASK_NAME = "QM_QM13210_XAU_AUDIT_38fba6991891c72ac46912d0"
NATIVE003_TERMINAL_STATUS = (
    "NATIVE003_INVALID_TERMINAL_CLOSED_OUTCOME_BLIND_NO_FURTHER_ATTEMPTS"
)
BUILD_RECEIPT_PATH = T.BUILD_RECEIPT_PATH
PRE_RECEIPT_PATH = ATTEMPT_001_RUN_ROOT / "pre_receipt.json"
AUTHORIZATION_PATH = ATTEMPT_001_RUN_ROOT / "native_outcome_authorization.json"
STATE_PATH = ATTEMPT_001_RUN_ROOT / "launch_state.json"
JOB_PATH = ATTEMPT_001_RUN_ROOT / "launch_job.json"
POST_RECEIPT_PATH = ATTEMPT_001_RUN_ROOT / "post_receipt.json"
CLAIM_PATH = ATTEMPT_001_RUN_ROOT / "native_attempt_claim.json"
RESEARCH_READINESS_PATH = T.RESEARCH_READINESS_PATH
DATA_MANIFEST_PATH = T.DATA_MANIFEST_PATH
INPUT_BINDINGS = T.INPUT_BINDINGS

SUPERSEDED_PRE_PATH = SUPERSEDED_RUN_ROOT / "pre_receipt.json"
SUPERSEDED_AUTHORIZATION_PATH = (
    SUPERSEDED_RUN_ROOT / "native_outcome_authorization.json"
)
SUPERSEDED_JOB_PATH = SUPERSEDED_RUN_ROOT / "launch_job.json"
SUPERSEDED_STATE_PATH = SUPERSEDED_RUN_ROOT / "launch_state.json"
SUPERSEDED_NATIVE_PATH = SUPERSEDED_RUN_ROOT / "native"
SUPERSEDED_CLAIM_PATH = SUPERSEDED_RUN_ROOT / "native_attempt_claim.json"
SUPERSEDED_PRE_SHA256 = "c86987146e1b4d3884441291dc033beae5f6dceb77f94f013a6cebd80e8211c3"
SUPERSEDED_TASK_NAME = "QM_QM13210_XAU_AUDIT_2e3ba2fbe3b235b61eb8b962"

FARM_STATE_ROOT = T.FARM_STATE_ROOT
FACTORY_OFF_FLAG_PATH = T.FACTORY_OFF_FLAG_PATH
CODEX_PARALLEL_PATH = T.CODEX_PARALLEL_PATH
WORKER_PIDS_PATH = T.WORKER_PIDS_PATH
TESTWINDOW_OFF_PATH = T.TESTWINDOW_OFF_PATH
FACTORY_OFF_PATH = T.FACTORY_OFF_PATH
TASK_MANIFEST_PATH = T.TASK_MANIFEST_PATH
PROCESS_SCOPE_PATH = T.PROCESS_SCOPE_PATH
MANAGED_OFF_TASKS = T.MANAGED_OFF_TASKS

_BASE_EXPECTED_BINDING_PATHS = T._BASE_EXPECTED_BINDING_PATHS
_BASE_PREFLIGHT = T._BASE_PREFLIGHT
_BASE_ASSERT_PRE_RECEIPT = T._BASE_ASSERT_PRE_RECEIPT
_BASE_LAUNCH_PERSISTENT_TASK = T._BASE_LAUNCH_PERSISTENT_TASK
_BASE_POSTFLIGHT = T._BASE_POSTFLIGHT
_BASE_WORKER_RUN = T._BASE_WORKER_RUN
_BASE_RUNNER_COMMAND = T._BASE_RUNNER_COMMAND


def _assert_exact_run_root(path: Path) -> Path:
    observed = path.resolve()
    expected = ALLOWED_RUN_ROOT.resolve()
    if observed != expected:
        raise B.InvalidEvidence(
            f"semantic-quiescence XAU run root must be exactly {expected}: {observed}"
        )
    return observed


def _assert_exact_control_path(path: Path, expected: Path, label: str) -> Path:
    observed = path.resolve()
    if observed != expected.resolve():
        raise B.InvalidEvidence(f"{label} must be exactly {expected.resolve()}: {observed}")
    return observed


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


def _relative_control_inventory(root: Path) -> list[dict[str, Any]]:
    if not root.is_dir():
        raise B.InvalidEvidence(f"missing predecessor run root: {root}")
    rows: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*"), key=lambda candidate: candidate.as_posix().lower()):
        relative = path.relative_to(root).as_posix()
        if path.is_dir():
            rows.append({"relative_path": relative, "kind": "directory"})
        elif path.is_file():
            binding = B.file_binding(path)
            rows.append(
                {
                    "relative_path": relative,
                    "kind": "file",
                    "size": binding["size"],
                    "sha256": binding["sha256"],
                }
            )
        else:
            raise B.InvalidEvidence(f"unsupported predecessor filesystem entry: {path}")
    return rows


def _probe_exact_task_absence(task_name: str) -> dict[str, Any]:
    script = (
        "$ErrorActionPreference='Stop';"
        f"$n='{task_name}';"
        "$t=@(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue);"
        "[ordered]@{task_name=$n;count=$t.Count;states=@($t|ForEach-Object{[string]$_.State})}"
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
        raise B.InvalidEvidence("predecessor scheduled-task absence probe failed closed")
    try:
        payload = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise B.InvalidEvidence("predecessor task probe returned invalid JSON") from exc
    expected = {"task_name": task_name, "count": 0, "states": []}
    if payload != expected:
        raise B.InvalidEvidence("predecessor scheduler task exists or probe schema drifted")
    return payload


def validate_native002_invalid_prelaunch_closure(
    path: Path = NATIVE002_CLOSURE_PATH,
    *,
    probe_task_absence: bool = True,
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
        "run_root_inventory",
        "launch_validation_failure",
        "absence_proof",
        "outcome_fence",
        "recovery_contract",
    }
    _require_exact_mapping(payload, required, "NATIVE_002 prelaunch closure")
    expected_identity = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_INVALID_PRELAUNCH_INFRASTRUCTURE_CLOSURE",
        "status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "analysis_id": T.ANALYSIS_ID,
        "attempt_id": "ATTEMPT_001",
        "classification": "RAW_WORKER_REGISTRY_BINDING_DRIFT_BEFORE_SCHEDULER_WITH_EMPTY_LIVE_PROJECTION",
        "run_root": str(SUPERSEDED_RUN_ROOT.resolve()),
    }
    if any(payload.get(key) != value for key, value in expected_identity.items()):
        raise B.InvalidEvidence("NATIVE_002 prelaunch closure identity drift")
    closed = B.parse_utc(str(payload.get("closed_utc", "")), "NATIVE_002 closed_utc")
    if closed > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("NATIVE_002 closure is implausibly future-dated")

    controls = _require_exact_mapping(
        payload.get("control_bindings"),
        {"pre_receipt", "corrected_native_outcome_authorization"},
        "NATIVE_002 control bindings",
    )
    pre_binding = _validate_recorded_binding(
        controls["pre_receipt"], SUPERSEDED_PRE_PATH, "NATIVE_002 PRE", assert_current=True
    )
    authorization_binding = _validate_recorded_binding(
        controls["corrected_native_outcome_authorization"],
        SUPERSEDED_AUTHORIZATION_PATH,
        "NATIVE_002 corrected authorization",
        assert_current=True,
    )
    if pre_binding["sha256"] != SUPERSEDED_PRE_SHA256:
        raise B.InvalidEvidence("NATIVE_002 PRE hash drift")

    inventory = _relative_control_inventory(SUPERSEDED_RUN_ROOT)
    if inventory != payload.get("run_root_inventory"):
        raise B.InvalidEvidence("NATIVE_002 exact run-root inventory drift")
    if [row.get("relative_path") for row in inventory] != [
        "native_outcome_authorization.json",
        "pre_receipt.json",
    ]:
        raise B.InvalidEvidence("NATIVE_002 contains files beyond PRE and authorization")

    pre = B.load_json(SUPERSEDED_PRE_PATH)
    if (
        pre.get("analysis_id") != T.ANALYSIS_ID
        or pre.get("status") != "PASS"
        or pre.get("attempt_id") != "ATTEMPT_001"
        or Path(str(pre.get("run_root", ""))).resolve() != SUPERSEDED_RUN_ROOT.resolve()
    ):
        raise B.InvalidEvidence("NATIVE_002 PRE identity drift")
    proof = _require_exact_mapping(
        pre.get("testwindow_off_quiescence"),
        {"status", "observed_utc", "invariant_sha256", "invariant"},
        "NATIVE_002 PRE quiescence",
    )
    if proof.get("status") != "PASS" or proof.get("invariant_sha256") != B.canonical_sha256(
        proof.get("invariant")
    ):
        raise B.InvalidEvidence("NATIVE_002 PRE quiescence digest drift")
    pre_invariant = proof["invariant"]
    if not isinstance(pre_invariant, Mapping):
        raise B.InvalidEvidence("NATIVE_002 PRE invariant missing")
    pre_registry = _validate_recorded_binding(
        pre_invariant.get("worker_pid_registry"),
        WORKER_PIDS_PATH,
        "NATIVE_002 PRE-bound worker registry",
        assert_current=False,
    )
    if pre_invariant.get("registered_factory_python_workers") != []:
        raise B.InvalidEvidence("NATIVE_002 PRE had a semantically live registered worker")

    authorization = T.validate_authorization(
        SUPERSEDED_AUTHORIZATION_PATH,
        pre_binding["sha256"],
        require_current=False,
    )
    if authorization.get("binding") != authorization_binding:
        raise B.InvalidEvidence("NATIVE_002 corrected authorization binding drift")

    failure = _require_exact_mapping(
        payload.get("launch_validation_failure"),
        {
            "stage",
            "scheduler_registration_requested",
            "native_start_requested",
            "worker_registry_path",
            "pre_bound_raw_registry_binding",
            "current_raw_registry_binding_at_closure",
            "raw_registry_binding_equal",
            "pre_registered_live_factory_python_workers",
            "current_registered_live_factory_python_workers",
            "semantic_live_projection_equal",
            "live_process_projection",
            "raw_registry_bytes_are_strategy_evidence",
            "strategy_merit_inference_permitted",
        },
        "NATIVE_002 launch-validation failure",
    )
    current_registry = _validate_recorded_binding(
        failure.get("current_raw_registry_binding_at_closure"),
        WORKER_PIDS_PATH,
        "NATIVE_002 registry at closure",
        assert_current=False,
    )
    expected_failure = {
        "stage": "LAUNCH_VALIDATION_PRE_SCHEDULER",
        "scheduler_registration_requested": False,
        "native_start_requested": False,
        "worker_registry_path": str(WORKER_PIDS_PATH.resolve()),
        "pre_bound_raw_registry_binding": pre_registry,
        "raw_registry_binding_equal": False,
        "pre_registered_live_factory_python_workers": [],
        "current_registered_live_factory_python_workers": [],
        "semantic_live_projection_equal": True,
        "live_process_projection": "REGISTRY_PID_LIVENESS_PLUS_PYTHON_IMAGE_NAME_ONLY",
        "raw_registry_bytes_are_strategy_evidence": False,
        "strategy_merit_inference_permitted": False,
    }
    if any(failure.get(key) != value for key, value in expected_failure.items()):
        raise B.InvalidEvidence("NATIVE_002 launch-validation classification drift")
    if current_registry == pre_registry:
        raise B.InvalidEvidence("NATIVE_002 raw registry mismatch is not proved")

    absence = _require_exact_mapping(
        payload.get("absence_proof"),
        {
            "launch_job",
            "launch_state",
            "native_directory",
            "native_attempt_claim",
            "scheduled_task",
            "worker_bootstrap_count",
            "native_controller_start_count",
            "native_summary_count",
            "native_outcome_artifact_count",
        },
        "NATIVE_002 absence proof",
    )
    expected_absent_paths = {
        "launch_job": SUPERSEDED_JOB_PATH,
        "launch_state": SUPERSEDED_STATE_PATH,
        "native_directory": SUPERSEDED_NATIVE_PATH,
        "native_attempt_claim": SUPERSEDED_CLAIM_PATH,
    }
    for role, expected_path in expected_absent_paths.items():
        row = _require_exact_mapping(absence.get(role), {"path", "exists"}, f"absence {role}")
        if Path(str(row.get("path", ""))).resolve() != expected_path.resolve() or row.get(
            "exists"
        ) is not False:
            raise B.InvalidEvidence(f"NATIVE_002 {role} absence drift")
        if expected_path.exists():
            raise B.InvalidEvidence(f"NATIVE_002 absent artifact now exists: {role}")
    task = _require_exact_mapping(
        absence.get("scheduled_task"), {"task_name", "count", "states"}, "task absence"
    )
    if task != {"task_name": SUPERSEDED_TASK_NAME, "count": 0, "states": []}:
        raise B.InvalidEvidence("NATIVE_002 scheduled-task absence drift")
    if probe_task_absence and _probe_exact_task_absence(SUPERSEDED_TASK_NAME) != task:
        raise B.InvalidEvidence("NATIVE_002 task appeared after closure")
    for key in (
        "worker_bootstrap_count",
        "native_controller_start_count",
        "native_summary_count",
        "native_outcome_artifact_count",
    ):
        if absence.get(key) != 0:
            raise B.InvalidEvidence(f"NATIVE_002 {key} must be zero")

    expected_fence = {
        "controller_logs_exist": False,
        "controller_logs_opened": False,
        "native_reports_exist": False,
        "native_reports_opened": False,
        "native_outcomes_exist": False,
        "native_outcomes_opened": False,
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
        "closure_uses_control_files_inventory_and_semantic_live_projection_only": True,
    }
    if payload.get("outcome_fence") != expected_fence:
        raise B.InvalidEvidence("NATIVE_002 outcome fence drift")
    expected_recovery = {
        "native002_namespace_final": True,
        "native002_resume_forbidden": True,
        "native002_retry_or_attempt002_plus_forbidden": True,
        "superseding_analysis_id": ANALYSIS_ID,
        "superseding_namespace": str(RUN_NAMESPACE_ROOT.resolve()),
        "single_superseding_attempt": "ATTEMPT_001",
        "superseding_resume_or_retry_forbidden": True,
        "semantic_worker_projection_replaces_raw_registry_byte_binding": True,
        "same_ea_ex5_set_data_parameters_windows_costs_and_gates_required": True,
        "strategy_or_parameter_change_forbidden": True,
    }
    if payload.get("recovery_contract") != expected_recovery:
        raise B.InvalidEvidence("NATIVE_002 recovery contract drift")
    return {
        "binding": B.file_binding(path),
        "status": payload["status"],
        "control_bindings": {key: dict(value) for key, value in controls.items()},
        "pre_bound_raw_registry_binding": pre_registry,
        "current_raw_registry_binding_at_closure": current_registry,
        "registered_live_workers_before_and_after": [],
        "scheduler_task_absent": True,
        "native_controller_start_count": 0,
        "native_outcome_artifact_count": 0,
    }


def validate_native003_invalid_terminal_closure(
    path: Path = NATIVE003_TERMINAL_CLOSURE_PATH,
    *,
    probe_task_absence: bool = True,
) -> dict[str, Any]:
    """Validate the final NATIVE_003 lifecycle closure without opening outcomes.

    External PRE/state/job/POST controls are immutable opaque bindings only.
    The optional claim is bound as exact absence.  No tester/controller log,
    report, deal row, economic outcome, or control JSON content is opened here.
    """

    closure_binding = B.file_binding(
        path, EXPECTED_NATIVE003_TERMINAL_CLOSURE_SHA256
    )
    if closure_binding["size"] != EXPECTED_NATIVE003_TERMINAL_CLOSURE_SIZE:
        raise B.InvalidEvidence("NATIVE_003 terminal closure size drift")
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
            "lifecycle_facts",
            "outcome_fence",
            "terminal_disposition",
        },
        "NATIVE_003 terminal closure",
    )
    expected_identity = {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_NATIVE003_INVALID_TERMINAL_CLOSURE",
        "status": NATIVE003_TERMINAL_STATUS,
        "analysis_id": ANALYSIS_ID,
    }
    if any(payload.get(key) != value for key, value in expected_identity.items()):
        raise B.InvalidEvidence("NATIVE_003 terminal closure identity drift")
    created = B.parse_utc(
        str(payload.get("created_utc", "")), "NATIVE_003 terminal closure created_utc"
    )
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("NATIVE_003 terminal closure is future-dated")
    if payload.get("candidate") != {
        "ea_id": "QM5_13210",
        "research_symbol": RESEARCH_SYMBOL,
        "timeframe": "M5",
        "model": 4,
        "duplicates_per_cell": 2,
    }:
        raise B.InvalidEvidence("NATIVE_003 terminal candidate drift")

    governing = _validate_recorded_binding(
        payload.get("governing_contract"),
        CONTRACT_PATH,
        "NATIVE_003 governing contract",
        assert_current=True,
    )
    if governing != {
        "path": str(CONTRACT_PATH.resolve()),
        "size": 11984,
        "sha256": "ba73a0631ae2c8f438c6a7506003178e959e7d78a1e26e1763a10995201e53e5",
    }:
        raise B.InvalidEvidence("NATIVE_003 governing contract binding drift")

    attempt = _require_exact_mapping(
        payload.get("attempt"),
        {
            "attempt_id",
            "run_root",
            "pre_receipt",
            "launch_state",
            "launch_job",
            "native_attempt_claim",
            "post_receipt",
        },
        "NATIVE_003 terminal attempt",
    )
    if (
        attempt.get("attempt_id") != "ATTEMPT_001"
        or Path(str(attempt.get("run_root", ""))).resolve()
        != ATTEMPT_001_RUN_ROOT.resolve()
    ):
        raise B.InvalidEvidence("NATIVE_003 terminal attempt identity drift")
    expected_bindings = {
        "pre_receipt": {
            "path": str(PRE_RECEIPT_PATH.resolve()),
            "size": 61749,
            "sha256": "43223cc742505d77374d331d65de9b1b89c4f11b3170059a1f3a19deed440a56",
        },
        "launch_state": {
            "path": str(STATE_PATH.resolve()),
            "size": 23872,
            "sha256": "6bd59a0d11186648be5214310efdb4ca20025c989e058dfb064a27e0032c3848",
        },
        "launch_job": {
            "path": str(JOB_PATH.resolve()),
            "size": 2176,
            "sha256": "e7ec738628884b7fef83d70080e66bf4f1e1f271c5229ce71734e51e2bad2e84",
        },
        "post_receipt": {
            "path": str(POST_RECEIPT_PATH.resolve()),
            "size": 329,
            "sha256": "fcb1ce882bf52c55db70c4c721fa9332267ca0aabdaa05c3eb1d40219b24f0e6",
        },
    }
    for role, expected in expected_bindings.items():
        observed = _validate_recorded_binding(
            attempt.get(role), expected_path=Path(expected["path"]),
            label=f"NATIVE_003 terminal {role}", assert_current=True
        )
        if observed != expected:
            raise B.InvalidEvidence(f"NATIVE_003 terminal {role} binding drift")
    claim = _require_exact_mapping(
        attempt.get("native_attempt_claim"),
        {"path", "exists"},
        "NATIVE_003 terminal claim absence",
    )
    if claim != {"path": str(CLAIM_PATH.resolve()), "exists": False}:
        raise B.InvalidEvidence("NATIVE_003 terminal claim-absence binding drift")
    if CLAIM_PATH.exists():
        raise B.InvalidEvidence("NATIVE_003 optional claim appeared after closure")

    task_absence = _require_exact_mapping(
        payload.get("scheduled_task_absence"),
        {"inspection_mode", "task_name", "count", "states"},
        "NATIVE_003 terminal task absence",
    )
    expected_task_absence = {
        "inspection_mode": (
            "EXACT_GET_SCHEDULED_TASK_NAME_ONLY_NO_ACTION_OR_LOG_CONTENT_READ"
        ),
        "task_name": NATIVE003_TASK_NAME,
        "count": 0,
        "states": [],
    }
    if task_absence != expected_task_absence:
        raise B.InvalidEvidence("NATIVE_003 terminal scheduled-task absence drift")
    if probe_task_absence:
        live_absence = _probe_exact_task_absence(NATIVE003_TASK_NAME)
        if live_absence != {
            "task_name": NATIVE003_TASK_NAME,
            "count": 0,
            "states": [],
        }:
            raise B.InvalidEvidence("NATIVE_003 scheduled task appeared after closure")

    if payload.get("terminal_trigger") != {
        "classification": "POST_INVALID_RAW_TESTER_LOG_MISSING_MODEL4_MARKER",
        "cell_id": "XAUUSD_DWX_DEV",
        "duplicate_id": "run_01",
        "required_marker": "MODEL_4_EVERY_TICK_BASED_ON_REAL_TICKS",
        "fact_source": "POST_RECEIPT_INVALID_METADATA_READ_BY_ROOT",
        "post_invocation_completed": True,
        "post_returned_invalid": True,
        "raw_tester_log_content_opened_by_closure": False,
    }:
        raise B.InvalidEvidence("NATIVE_003 terminal trigger drift")
    if payload.get("lifecycle_facts") != {
        "scheduler_worker_completed": True,
        "post_receipt_materialized": True,
        "optional_native_attempt_claim_materialized": False,
        "claim_absence_does_not_restore_attempt_budget": True,
        "one_shot_attempt_consumed": True,
        "remaining_attempt_budget": 0,
    }:
        raise B.InvalidEvidence("NATIVE_003 lifecycle-consumption drift")
    if payload.get("outcome_fence") != {
        "pre_receipt_content_opened": False,
        "launch_state_content_opened": False,
        "launch_job_content_opened": False,
        "post_receipt_content_opened_by_closure_author": False,
        "post_receipt_invalid_metadata_read_by_root": True,
        "tester_or_controller_log_content_opened": False,
        "native_report_content_opened": False,
        "deal_rows_opened": False,
        "economic_outcomes_opened": False,
        "strategy_outcomes_read": False,
        "strategy_merit_adjudicated": False,
        "control_artifacts_bound_by_path_size_sha256_only": True,
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
    }:
        raise B.InvalidEvidence("NATIVE_003 outcome fence drift")
    if payload.get("terminal_disposition") != {
        "classification": "INVALID_TERMINAL_NO_STRATEGY_MERIT_ADJUDICATION",
        "strategy_merit_verdict": "NONE",
        "family_final": True,
        "post_retry_permitted": False,
        "resume_permitted": False,
        "relaunch_permitted": False,
        "attempt_002_permitted": False,
        "further_xau_audit_attempt_in_family_permitted": False,
        "all_bound_controls_must_remain_immutable": True,
    }:
        raise B.InvalidEvidence("NATIVE_003 terminal disposition drift")
    return payload


def _raise_native003_family_closed(operation: str) -> None:
    validate_native003_invalid_terminal_closure()
    raise B.AuthorizationError(
        f"NATIVE_003 XAU family is terminal-invalid; {operation} is permanently forbidden"
    )


_QUIESCENCE_POWERSHELL = T._QUIESCENCE_POWERSHELL


def _probe_quiescence_runtime() -> dict[str, Any]:
    return T._probe_quiescence_runtime()


def _probe_worker_mutexes() -> list[str]:
    return T._probe_worker_mutexes()


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
        raise B.InvalidEvidence("TestWindow-OFF has an exact T1-T10 terminal/metatester process")
    if runtime.get("registered_factory_python_workers") != []:
        raise B.InvalidEvidence("TestWindow-OFF has a semantically live registered Python worker")
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


def enforce_symbol_policy(symbol: str) -> None:
    T.enforce_symbol_policy(symbol)


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    paths = _BASE_EXPECTED_BINDING_PATHS(symbol)
    paths.update(
        {
            "base_tool": T.X.BASE_TOOL_PATH,
            "superseded_adapter": T.SUPERSEDED_TOOL_PATH,
            "superseded_contract": T.SUPERSEDED_CONTRACT_PATH,
            "attempt001_closure": T.ATTEMPT_001_CLOSURE_PATH,
            "attempt002_closure": T.ATTEMPT_002_CLOSURE_PATH,
            "superseded_testwindow_adapter": SUPERSEDED_TOOL_PATH,
            "superseded_testwindow_contract": SUPERSEDED_CONTRACT_PATH,
            "native002_prelaunch_closure": NATIVE002_CLOSURE_PATH,
            "xau_testwindow_semantic_contract": CONTRACT_PATH,
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
        "base_tool": T.X.BASE_TOOL_PATH,
        "superseded_adapter": T.SUPERSEDED_TOOL_PATH,
        "superseded_contract": T.SUPERSEDED_CONTRACT_PATH,
        "attempt001_closure": T.ATTEMPT_001_CLOSURE_PATH,
        "attempt002_closure": T.ATTEMPT_002_CLOSURE_PATH,
        "superseded_testwindow_adapter": SUPERSEDED_TOOL_PATH,
        "superseded_testwindow_contract": SUPERSEDED_CONTRACT_PATH,
        "native002_prelaunch_closure": NATIVE002_CLOSURE_PATH,
        "scheduled_task_helper": B.SCHEDULED_TASK_HELPER_PATH,
        "testwindow_off": TESTWINDOW_OFF_PATH,
        "factory_off": FACTORY_OFF_PATH,
        "task_manifest": TASK_MANIFEST_PATH,
        "process_scope": PROCESS_SCOPE_PATH,
    }


FINAL_ARTIFACT_ROLES = frozenset(_artifact_contract_paths())


def _candidate_contract() -> dict[str, Any]:
    return dict(T._candidate_contract())


def _windows_contract() -> list[dict[str, Any]]:
    return T._windows_contract()


def _run_namespace_contract() -> dict[str, Any]:
    return {
        "family_root": str(RUN_FAMILY_ROOT.resolve()),
        "original_namespace": str(ORIGINAL_NAMESPACE_ROOT.resolve()),
        "superseded_namespace": str(SUPERSEDED_NAMESPACE_ROOT.resolve()),
        "superseded_namespace_final_at_attempt001_prelaunch": True,
        "superseding_namespace": str(RUN_NAMESPACE_ROOT.resolve()),
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


def _testwindow_contract() -> dict[str, Any]:
    return {
        "version": "QM13210_TESTWINDOW_OFF_QUIESCENCE_V2_SEMANTIC_WORKERS",
        "required_at": ["PRE", "LAUNCH", "WORKER_BOOTSTRAP", "BEFORE_EACH_NATIVE_CELL", "POST"],
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


def _supersession_contract() -> dict[str, Any]:
    return {
        "superseded_analysis_id": T.ANALYSIS_ID,
        "superseding_analysis_id": ANALYSIS_ID,
        "old_status": "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND",
        "old_cause": "RAW_WORKER_REGISTRY_BINDING_DRIFT_BEFORE_SCHEDULER_WITH_EMPTY_LIVE_PROJECTION",
        "old_job_state_native_claim_and_task_absent": True,
        "old_native_controller_start_count": 0,
        "old_native_summary_count": 0,
        "old_native_outcome_artifact_count": 0,
        "old_namespace_attempt002_plus_forbidden": True,
        "new_namespace_is_separate_analysis_not_retry": True,
        "single_new_attempt_only": True,
        "same_ea_ex5_set_data_parameters_windows_costs_and_merit_gates": True,
        "parameter_tuning_forbidden": True,
    }


def _outcome_fence_contract() -> dict[str, bool]:
    return {
        "native002_controller_logs_opened": False,
        "native002_native_reports_opened": False,
        "native002_native_outcomes_opened": False,
        "superseding_native_reports_opened": False,
        "superseding_deal_rows_parsed": False,
        "mt5_started_by_contract_or_finalization": False,
        "live_process_command_lines_read": False,
        "live_process_command_lines_emitted": False,
    }


def _draft_contract_payload() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13210_XAUUSD_SEMANTIC_TESTWINDOW_SUPERSEDING_ANALYSIS_CONTRACT",
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
            "symbol_spec_sha256": B.canonical_sha256(T.XAU_SYMBOL_SPEC_CONTRACT),
            "xau_calibration_projection_sha256": B.canonical_sha256(
                T.XAU_CALIBRATION_PROJECTION
            ),
            "cost_schedule_sha256": B.canonical_sha256(T.ATTEMPT_COST_SCHEDULE),
            "merit_contract_sha256": B.canonical_sha256(MERIT_GATES),
            "ea_ex5_set_data_parameters_windows_costs_and_gates_unchanged": True,
        },
        "run_namespace": _run_namespace_contract(),
        "supersession": _supersession_contract(),
        "testwindow_off_quiescence": _testwindow_contract(),
        "outcome_fence": _outcome_fence_contract(),
        "finalization": {
            "required_command": (
                "audit_mulham_asian_sweep_london_xau_testwindow_semantic.py "
                "finalize-contract --source-commit <40_HEX_BUILD_COMMIT>"
            ),
            "requires_committed_clean_adapter_closure_and_draft": True,
            "requires_pristine_superseding_namespace": True,
            "pre_and_launch_forbidden_until_status": "FINALIZED_OUTCOME_BLIND",
            "final_contract_must_bind_roles": sorted(FINAL_ARTIFACT_ROLES),
        },
    }


def validate_draft_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    payload = B.load_json(path)
    if payload != _draft_contract_payload():
        raise B.InvalidEvidence("semantic TestWindow XAU draft contract drift")
    return payload


def _validate_artifact_bindings(
    bindings: Any, *, allow_historical_executed_adapter: bool = False
) -> dict[str, dict[str, Any]]:
    paths = _artifact_contract_paths()
    if not isinstance(bindings, Mapping) or set(bindings) != set(paths):
        raise B.InvalidEvidence("semantic TestWindow artifact-role closure drift")
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
                raise B.InvalidEvidence("historical executed adapter binding drift")
        else:
            B.assert_binding(row, f"semantic TestWindow finalized {role}")
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
        "artifact_bindings": {
            role: dict(bindings[role]) for role in sorted(FINAL_ARTIFACT_ROLES)
        },
    }


def validate_analysis_contract(path: Path = CONTRACT_PATH) -> dict[str, Any]:
    terminal_closure = validate_native003_invalid_terminal_closure()
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected_fields = set(_draft_contract_payload()) - {"finalization"}
    expected_fields |= {"finalized_utc", "source_build_commit", "artifact_bindings"}
    if set(payload) != expected_fields:
        raise B.InvalidEvidence("semantic TestWindow XAU contract is not finalized")
    if (
        payload.get("status") != "FINALIZED_OUTCOME_BLIND"
        or payload.get("analysis_id") != ANALYSIS_ID
        or payload.get("artifact_type")
        != "QM5_13210_XAUUSD_SEMANTIC_TESTWINDOW_SUPERSEDING_ANALYSIS_CONTRACT"
    ):
        raise B.InvalidEvidence("semantic TestWindow finalized identity drift")
    finalized = B.parse_utc(
        str(payload.get("finalized_utc", "")), "semantic TestWindow finalized_utc"
    )
    if finalized > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise B.InvalidEvidence("semantic TestWindow finalization time is in the future")
    source_commit = str(payload.get("source_build_commit", ""))
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise B.InvalidEvidence("source build commit must be lowercase full SHA-1")
    semantic = _draft_contract_payload()
    semantic.pop("finalization")
    semantic["status"] = "FINALIZED_OUTCOME_BLIND"
    drift = {
        key: (value, payload.get(key))
        for key, value in semantic.items()
        if payload.get(key) != value
    }
    if drift:
        raise B.InvalidEvidence(f"semantic TestWindow finalized drift: {sorted(drift)}")
    artifacts = _validate_artifact_bindings(
        payload.get("artifact_bindings"), allow_historical_executed_adapter=True
    )
    predecessor = T.validate_analysis_contract(SUPERSEDED_CONTRACT_PATH)
    if predecessor["binding"] != artifacts["superseded_testwindow_contract"]:
        raise B.InvalidEvidence("superseded TestWindow contract binding drift")
    validate_native002_invalid_prelaunch_closure()
    T.X._validate_bound_build_receipt(artifacts, source_commit)
    T.X._activate_finalized_contract({**payload, "artifact_bindings": artifacts})
    return {
        "binding": binding,
        "payload_sha256": B.canonical_sha256(payload),
        "source_build_commit": source_commit,
        "artifact_bindings": artifacts,
        "supersession": payload["supersession"],
        "testwindow_off_quiescence": payload["testwindow_off_quiescence"],
        "terminal_closure": {
            "binding": B.file_binding(
                NATIVE003_TERMINAL_CLOSURE_PATH,
                EXPECTED_NATIVE003_TERMINAL_CLOSURE_SHA256,
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


def _assert_namespace_contract(*, pristine: bool) -> None:
    validate_native002_invalid_prelaunch_closure()
    allowed_siblings = {
        ORIGINAL_NAMESPACE_ROOT.name,
        SUPERSEDED_NAMESPACE_ROOT.name,
        RUN_NAMESPACE_ROOT.name,
    }
    if RUN_FAMILY_ROOT.is_dir():
        siblings = {
            item.name
            for item in RUN_FAMILY_ROOT.iterdir()
            if item.name.startswith("XAUUSD_MULHAM_NATIVE_")
        }
        if not siblings <= allowed_siblings:
            raise B.InvalidEvidence(f"unregistered XAU analysis namespace: {sorted(siblings)}")
    if RUN_NAMESPACE_ROOT.is_dir():
        children = {item.name for item in RUN_NAMESPACE_ROOT.iterdir()}
        if not children <= {"ATTEMPT_001"}:
            raise B.InvalidEvidence("semantic analysis contains a retry/second attempt")
    if CLAIM_PATH.exists():
        raise B.InvalidEvidence("semantic analysis native-attempt claim must remain absent")
    if pristine and ALLOWED_RUN_ROOT.exists():
        if not ALLOWED_RUN_ROOT.is_dir() or any(ALLOWED_RUN_ROOT.iterdir()):
            raise B.InvalidEvidence("semantic ATTEMPT_001 root is not pristine")


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
        raise B.InvalidEvidence("finalize requires committed clean adapter, closure and draft")
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
        raise B.InvalidEvidence("PRE requires committed clean finalized semantic contract")


def finalize_analysis_contract(source_commit: str) -> dict[str, Any]:
    _raise_native003_family_closed("contract finalization or replacement")
    validate_draft_contract()
    _assert_namespace_contract(pristine=True)
    _assert_source_freeze_ready(source_commit)
    artifacts = {
        role: B.file_binding(path) for role, path in _artifact_contract_paths().items()
    }
    T.X._validate_bound_build_receipt(artifacts, source_commit)
    payload = _final_payload(source_commit, B.utc_now(), artifacts)
    digest = B.atomic_json(CONTRACT_PATH, payload, replace=True)
    result = validate_analysis_contract()
    if result["binding"]["sha256"] != digest:
        raise B.InvalidEvidence("finalized semantic contract write drift")
    return result


def preflight(
    symbol: str,
    research_readiness_receipt_path: Path,
    data_manifest_path: Path,
    build_receipt_path: Path,
    run_root: Path,
) -> dict[str, Any]:
    _raise_native003_family_closed("PRE or another audit attempt")
    enforce_symbol_policy(symbol)
    closure = validate_native002_invalid_prelaunch_closure()
    _assert_namespace_contract(pristine=True)
    _assert_exact_run_root(run_root)
    for role, observed_path in {
        "research_readiness_receipt": research_readiness_receipt_path,
        "data_manifest": data_manifest_path,
    }.items():
        expected = INPUT_BINDINGS[role]
        if observed_path.resolve() != Path(str(expected["path"])).resolve():
            raise B.InvalidEvidence(f"semantic {role} path drift")
        B.file_binding(observed_path, str(expected["sha256"]))
        if observed_path.stat().st_size != int(expected["size"]):
            raise B.InvalidEvidence(f"semantic {role} size drift")
    if build_receipt_path.resolve() != BUILD_RECEIPT_PATH.resolve():
        raise B.InvalidEvidence("semantic PRE build receipt path drift")
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
    if pre.get("cost_schedule") != T.ATTEMPT_COST_SCHEDULE or pre.get(
        "merit_contract"
    ) != MERIT_GATES:
        raise B.InvalidEvidence("semantic analysis costs or merit gates drifted")
    role_map = {
        "tool": "adapter",
        "base_tool": "base_tool",
        "superseded_adapter": "superseded_adapter",
        "superseded_contract": "superseded_contract",
        "attempt001_closure": "attempt001_closure",
        "attempt002_closure": "attempt002_closure",
        "superseded_testwindow_adapter": "superseded_testwindow_adapter",
        "superseded_testwindow_contract": "superseded_testwindow_contract",
        "native002_prelaunch_closure": "native002_prelaunch_closure",
        "scheduled_task_helper": "scheduled_task_helper",
        "testwindow_off": "testwindow_off",
        "factory_off": "factory_off",
        "task_manifest": "task_manifest",
        "process_scope": "process_scope",
    }
    for pre_role, contract_role in role_map.items():
        if pre["bindings"].get(pre_role) != contract["artifact_bindings"].get(
            contract_role
        ):
            raise B.InvalidEvidence(f"PRE binding differs from finalized {contract_role}")
    pre["attempt_id"] = "ATTEMPT_001"
    pre["supersession"] = contract["supersession"]
    pre["native002_invalid_prelaunch_closure"] = closure
    pre["testwindow_off_quiescence"] = quiescence
    pre["xau_semantic_testwindow_preregistration"] = contract
    return pre


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_exact_control_path(path, PRE_RECEIPT_PATH, "PRE receipt")
    contract = validate_analysis_contract()
    _assert_finalized_contract_committed()
    pre = _BASE_ASSERT_PRE_RECEIPT(path, expected_sha256)
    if pre.get("attempt_id") != "ATTEMPT_001" or pre.get("supersession") != contract[
        "supersession"
    ]:
        raise B.InvalidEvidence("semantic PRE identity drift")
    closure = validate_native002_invalid_prelaunch_closure()
    if pre.get("native002_invalid_prelaunch_closure") != closure:
        raise B.InvalidEvidence("PRE NATIVE_002 closure binding drift")
    if pre.get("xau_semantic_testwindow_preregistration") != contract:
        raise B.InvalidEvidence("PRE finalized semantic contract drift")
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
    drift = {
        key: (value, payload.get(key))
        for key, value in expected.items()
        if payload.get(key) != value
    }
    if drift:
        raise B.AuthorizationError(f"semantic authorization drift: {drift}")
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
    _raise_native003_family_closed("resume, relaunch, or another audit attempt")
    if resume:
        raise B.AuthorizationError("semantic analysis is one-shot; resume is forbidden")
    _assert_exact_control_path(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control_path(authorization_path, AUTHORIZATION_PATH, "authorization")
    _assert_exact_control_path(state_path, STATE_PATH, "launch state")
    if CLAIM_PATH.exists():
        raise B.AuthorizationError("native-attempt claim is forbidden for this one-shot profile")
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
        raise B.InvalidEvidence("worker cell lacks PRE-bound semantic TestWindow proof")
    assert_testwindow_off_quiescence(proof)
    return _BASE_RUNNER_COMMAND(pre, cell)


def _worker_run(job_path: Path) -> int:
    _raise_native003_family_closed("worker replay or relaunch")
    _assert_exact_control_path(job_path, JOB_PATH, "launch job")
    assert_testwindow_off_quiescence()
    validate_native002_invalid_prelaunch_closure()
    return _BASE_WORKER_RUN(job_path)


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    _raise_native003_family_closed("POST retry")
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
    B._validate_set_contract = T.X._validate_set_contract
    B._expected_binding_paths = _expected_binding_paths
    B.resolve_cost_schedule = T.X.resolve_cost_schedule
    B._reconstruct_trades = T.X._reconstruct_trades
    B.evaluate_merit = T.X.evaluate_merit
    B.load_bound_news_events = T.X.load_bound_news_events
    B.validate_trade_semantics = T.X.validate_trade_semantics
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
XAU_CALIBRATION_PROJECTION = T.XAU_CALIBRATION_PROJECTION
XAU_SYMBOL_SPEC_CONTRACT = T.XAU_SYMBOL_SPEC_CONTRACT
ATTEMPT_COST_SCHEDULE = T.ATTEMPT_COST_SCHEDULE


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
    return getattr(T, name)


if __name__ == "__main__":
    raise SystemExit(main())
