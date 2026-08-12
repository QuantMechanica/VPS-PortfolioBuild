#!/usr/bin/env python3
"""One-shot outcome-fenced NDX.DWX Model-4 prescreen for QM5_13209.

The module profiles the proven isolated-DEV2 controller from QM5_10834.  PRE
opens configuration, registry and tick-data evidence only.  The persistent
worker seals native artifacts as opaque path/size/hash bindings.  POST is the
first phase allowed to parse reports or economic outcomes.
"""

from __future__ import annotations

import argparse
import copy
import csv
import importlib.util
import json
import os
import re
import sqlite3
import subprocess
import sys
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Mapping, Sequence


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
BASE_TOOL_PATH = (
    REPO_ROOT
    / "framework"
    / "EAs"
    / "QM5_10834_tv-nq-ict-ob"
    / "tools"
    / "candidate_analysis"
    / "audit_tv_nq_ict_ob.py"
)
_BASE_SPEC = importlib.util.spec_from_file_location(
    "qm13209_ndx_private_dev2_base", BASE_TOOL_PATH
)
if _BASE_SPEC is None or _BASE_SPEC.loader is None:  # pragma: no cover
    raise RuntimeError(f"cannot load DEV2 base auditor: {BASE_TOOL_PATH}")
B = importlib.util.module_from_spec(_BASE_SPEC)
sys.modules[_BASE_SPEC.name] = B
_BASE_SPEC.loader.exec_module(B)


EA_ID = 13209
EA_LABEL = "QM5_13209"
EXPERT_NAME = "QM5_13209_mulham-pm-range-sweep"
EXPERT_PATH = rf"QM\{EXPERT_NAME}"
ANALYSIS_ID = "QM5_13209_MULHAM_PM_RANGE_SWEEP_NDX_PRESCREEN_NATIVE_001"
RESEARCH_SYMBOL = "NDX.DWX"
TIMEFRAME = "M5"
INITIAL_BALANCE = Decimal("100000")
DUPLICATES = 2
CELL_ID = "PRESCREEN_2022H2"
MAX_INFRA_WARMUPS = 2
MAX_ATTEMPTS = 4
COMMISSION_RT_PER_LOT = Decimal("5.50")
MAGIC_SLOT = 1
MAGIC = 132090001
WINDOWS = (
    B.Window("PRESCREEN_2022H2", "PRESCREEN", date(2022, 7, 1), date(2022, 12, 31)),
)
MERIT_GATES: dict[str, Any] = {
    "version": "QM5_13209_NDX_PRESCREEN_V1_20260721",
    "minimum_trades": 5,
    "minimum_native_profit_factor": "1.20",
    "minimum_cost_adjusted_profit_factor": "1.20",
    "cost_adjusted_net_must_be_strictly_positive": True,
    "lifecycle_and_session_invariants_required": True,
}

RUN_FAMILY_ROOT = Path(r"D:\QM\reports\candidate_analysis\QM5_13209")
RUN_NAMESPACE_ROOT = RUN_FAMILY_ROOT / "NDX_PM_RANGE_SWEEP_NATIVE_001"
RUN_ROOT = RUN_NAMESPACE_ROOT / "ATTEMPT_001"
PRE_RECEIPT_PATH = RUN_ROOT / "pre_receipt.json"
AUTHORIZATION_PATH = RUN_ROOT / "native_outcome_authorization.json"
STATE_PATH = RUN_ROOT / "launch_state.json"
JOB_PATH = RUN_ROOT / "launch_job.json"
POST_RECEIPT_PATH = RUN_ROOT / "post_receipt.json"
CLAIM_PATH = RUN_ROOT / "native_attempt_claim.json"
LOCK_PATH = RUN_ROOT / "native_launch.lock"
AUTHORIZATION_SCOPE = (
    "QM5_13209_NDX_PRESCREEN_NATIVE_001_ATTEMPT_001_"
    "ONE_CELL_2022H2_TWO_DUPLICATES_MAX_FOUR_STARTS_MODEL4_DEV2"
)
SCHEDULED_TASK_PREFIX = "QM_QM13209_NDX_AUDIT_"

DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
CONTRACT_PATH = DOC_ROOT / "ndx_prescreen_outcome_fenced_analysis_contract_20260721.json"
OLD_CLOSURE_PATH = DOC_ROOT / "ndx_factory_summary_missing_invalid_infrastructure_closure_20260721.json"
TERMINAL_CLOSURE_PATH = (
    DOC_ROOT / "ndx_attempt001_invalid_terminal_infrastructure_closure_20260721.json"
)
BUILD_RECEIPT_PATH = DOC_ROOT / "build_receipt_20260721.json"
BUILD_RESULT_PATH = DOC_ROOT / "build_result_superseding_20260721.json"
CANONICAL_BUILD_RESULT_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\builds\d54ae7b2-bed6-4c7d-85a2-5030944f3127.json"
)
REVIEW_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\verdicts\review_6154711f-fb6e-4900-a208-17fe7df355b2.json"
)
DATA_RECEIPT_PATH = Path(
    r"D:\QM\reports\candidate_analysis\QM5_10834\data\NDX_DWX_201807_202512_DEV2_backtest_data_receipt.json"
)
FACTORY_DB_PATH = Path(r"D:\QM\strategy_farm\state\farm_state.sqlite")
FACTORY_OFF_FLAG_PATH = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
OLD_WORKITEM_ID = "aff5d23f-fe44-43ef-a48f-f29737baf6ca"
DUPLICATE_WORKITEM_ID = "c9db50a1-8c0c-414f-ae16-36bd7e09985e"
SP500_RESULT_WORKITEM_ID = "f5b0237a-3be3-4064-9871-14b2da803118"
OLD_WORKITEM_ROOT = Path(r"D:\QM\reports\work_items") / OLD_WORKITEM_ID
SP500_EVIDENCE_PATH = (
    Path(r"D:\QM\reports\work_items")
    / SP500_RESULT_WORKITEM_ID
    / "QM5_13209"
    / "20260721_074932"
    / "summary.json"
)

CARD_PATH = Path(
    r"D:\QM\strategy_farm\artifacts\cards_approved\QM5_13209_mulham-pm-range-sweep.md"
)
SPEC_PATH = EA_ROOT / "SPEC.md"
MQ5_PATH = EA_ROOT / f"{EXPERT_NAME}.mq5"
EX5_PATH = EA_ROOT / f"{EXPERT_NAME}.ex5"
SET_PATH = EA_ROOT / "sets" / f"{EXPERT_NAME}_NDX.DWX_M5_backtest.set"
ALIASES_PATH = REPO_ROOT / "framework" / "registry" / "execution_symbol_aliases_v1.json"
MATRIX_PATH = REPO_ROOT / "framework" / "registry" / "dwx_symbol_matrix.csv"
COST_PATH = REPO_ROOT / "framework" / "registry" / "venue_cost_model.json"
MAGIC_REGISTRY_PATH = REPO_ROOT / "framework" / "registry" / "magic_numbers.csv"
EA_REGISTRY_PATH = REPO_ROOT / "framework" / "registry" / "ea_id_registry.csv"
TESTER_DEFAULTS_PATH = REPO_ROOT / "framework" / "registry" / "tester_defaults.json"
SCHEDULED_TASK_HELPER_PATH = TOOL_PATH.with_name("run_outcome_fenced_task.ps1")

EXPECTED_DATA_RECEIPT = {
    "path": str(DATA_RECEIPT_PATH),
    "size": 27870,
    "sha256": "b16fbc866b7e03a73b04fb5e67938eb7e290a0b31addcc6cc34736d1f554a66e",
}
EXPECTED_REVIEW = {
    "path": str(REVIEW_PATH),
    "size": 3390,
    "sha256": "7f59367de9c6dd826b059eeec843154610e2d3a4b3017b865d7886599940f45f",
}
EXPECTED_CANONICAL_BUILD = {
    "path": str(CANONICAL_BUILD_RESULT_PATH),
    "size": 2278,
    "sha256": "a6f60f690b5ec26293ea5e14f6e693d5a7d90ea5f4880d54f93997d881b27293",
}
EXPECTED_SP500_EVIDENCE = {
    "path": str(SP500_EVIDENCE_PATH),
    "size": 3305,
    "sha256": "5f5c9cc543648e9504326044f3c00a384e2cc561e3de315e86c327d91b0eedbe",
}
EXPECTED_TERMINAL_CLOSURE = {
    "path": str(TERMINAL_CLOSURE_PATH),
    "size": 7068,
    "sha256": "9de139536624a1e82fb1d80f38c6e774a080953fbd6de736277734f90135af40",
}
EXPECTED_INFRA_HASHES = {
    "runner": "d3d2bcbcd2d2d52bea4d0a50f501d86e35d48211b67066fad236d5c5d4efc485",
    "runner_child": "6602217a4c27636a9d4faa26086b6be5dfd3a4817b5fa8174640e5160922d6b1",
    "dev2_cleanup_helper": "617bbd95dfd1324bf70654a831ca6caec087df3cbaa8c1d064ddda3455e9f250",
    "dev2_machine_credential_probe": "103c9886c85e36650e3c0ac4c05fc3891ad019faab66c9d31ea961d0d93812d5",
    "dev2_machine_credential_helper": "bd3077f5ff671d80a377a820e35cd233cdf8ad1b25d376d579da4714c323ad2c",
    "dev2_lane_contract": "866e4e346187e47c33e32beb30bb96dc4085e98cc316819fb33f7925306dda06",
    "report_parser": "c9dc5106383073b50150f0edb091338181dc53470615839fb252f5bc96a46c03",
}


AuditError = B.AuditError
InvalidEvidence = B.InvalidEvidence
AuthorizationError = B.AuthorizationError
TradeRecord = B.TradeRecord

_BASE_RUNNER_COMMAND = B.runner_command

JOB_ARTIFACT_TYPE = "QM5_13209_NDX_PRESCREEN_NATIVE_LAUNCH_JOB"
STATE_ARTIFACT_TYPE = "QM5_13209_NDX_PRESCREEN_NATIVE_LAUNCH_STATE"
POST_ARTIFACT_TYPE = "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_POST_RECEIPT"
TERMINALLY_FORBIDDEN_OPERATIONS = frozenset(
    {"PRE", "LAUNCH", "RESUME", "WORKER", "POST", "RETRY", "ATTEMPT_002"}
)


def _exact_binding(path: Path, expected: Mapping[str, Any], label: str) -> dict[str, Any]:
    if path.resolve() != Path(str(expected["path"])).resolve():
        raise InvalidEvidence(f"{label} path drift")
    binding = B.file_binding(path, str(expected["sha256"]))
    if binding["size"] != int(expected["size"]):
        raise InvalidEvidence(f"{label} size drift")
    return binding


def validate_terminal_closure(
    path: Path = TERMINAL_CLOSURE_PATH,
) -> dict[str, Any]:
    """Validate the immutable terminal state without opening outcome files."""

    closure_binding = _exact_binding(
        path, EXPECTED_TERMINAL_CLOSURE, "terminal NDX attempt closure"
    )
    payload = B.load_json(path)
    expected_root_keys = {
        "schema_version",
        "artifact_type",
        "status",
        "analysis_id",
        "attempt_id",
        "closed_utc",
        "candidate",
        "run_namespace",
        "control_bindings",
        "terminal_state",
        "infrastructure_failure",
        "directory_metadata_closure",
        "outcome_fence",
        "terminal_disposition",
    }
    if set(payload) != expected_root_keys or any(
        (
            payload.get("schema_version") != 1,
            payload.get("artifact_type")
            != "QM5_13209_NDX_ATTEMPT001_INVALID_TERMINAL_INFRASTRUCTURE_CLOSURE",
            payload.get("status")
            != "INVALID_TERMINAL_INFRASTRUCTURE_CLOSED_NO_RETRY_NO_MERIT_VERDICT",
            payload.get("analysis_id") != ANALYSIS_ID,
            payload.get("attempt_id") != "ATTEMPT_001",
        )
    ):
        raise InvalidEvidence("terminal NDX closure identity drift")
    closed = B.parse_utc(str(payload.get("closed_utc", "")), "terminal closure closed_utc")
    if closed > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise InvalidEvidence("terminal NDX closure is future-dated")

    expected_candidate = {
        "ea_id": EA_LABEL,
        "research_symbol": RESEARCH_SYMBOL,
        "timeframe": TIMEFRAME,
        "model": 4,
        "cell_id": CELL_ID,
    }
    expected_namespace = {
        "namespace_root": str(RUN_NAMESPACE_ROOT.resolve()),
        "run_root": str(RUN_ROOT.resolve()),
        "attempt_directories_exact": ["ATTEMPT_001"],
        "attempt002_present": False,
    }
    if payload.get("candidate") != expected_candidate or payload.get(
        "run_namespace"
    ) != expected_namespace:
        raise InvalidEvidence("terminal NDX candidate/namespace closure drift")
    if sorted(item.name for item in RUN_NAMESPACE_ROOT.iterdir()) != ["ATTEMPT_001"]:
        raise InvalidEvidence("terminal NDX namespace was extended after ATTEMPT_001")

    expected_controls = {
        "pre_receipt": {
            "path": str(PRE_RECEIPT_PATH.resolve()),
            "size": 27490,
            "sha256": "c25e8b950163c221d00319df33ef960a24823215139f67f4633f3e6b710dd3b4",
        },
        "authorization": {
            "path": str(AUTHORIZATION_PATH.resolve()),
            "size": 812,
            "sha256": "1b0692d2a344ef5dfecddaaef2d4886b18cd38ab8a9cef5cffd25c158f74530c",
        },
        "launch_job": {
            "path": str(JOB_PATH.resolve()),
            "size": 2139,
            "sha256": "9e5ceb1a2f9a5e323d63a09f4651a1077d33623ae5103bd3fc1ec286e9012e8d",
        },
        "launch_state": {
            "path": str(STATE_PATH.resolve()),
            "size": 7817,
            "sha256": "73eb37d62eb3bbb7423cc38e90560bb87bb7884c863adf6c64f215a7b0ed1424",
        },
        "native_attempt_claim": {
            "path": str(CLAIM_PATH.resolve()),
            "size": 3592,
            "sha256": "f8a1d68ad5cfbdb551b2a1247d543daa43339d932927e0d904e3a9b0e704a5fc",
        },
    }
    controls = payload.get("control_bindings")
    if controls != expected_controls:
        raise InvalidEvidence("terminal NDX control-binding closure drift")
    for role, binding in expected_controls.items():
        B.assert_binding(binding, f"terminal NDX {role}")

    metadata = payload.get("directory_metadata_closure")
    if not isinstance(metadata, Mapping):
        raise InvalidEvidence("terminal NDX directory metadata is missing")
    actual_directories = sorted(
        str(item.relative_to(RUN_ROOT))
        for item in RUN_ROOT.rglob("*")
        if item.is_dir()
    )
    if actual_directories != metadata.get("directories_exact"):
        raise InvalidEvidence("terminal NDX directory closure drift")
    actual_files = []
    for item in sorted(RUN_ROOT.rglob("*"), key=lambda value: str(value).casefold()):
        if not item.is_file():
            continue
        binding = B.file_binding(item)
        actual_files.append(
            {
                "relative_path": str(item.relative_to(RUN_ROOT)),
                "size": binding["size"],
                "sha256": binding["sha256"],
            }
        )
    expected_files = metadata.get("files_exact")
    if not isinstance(expected_files, list):
        raise InvalidEvidence("terminal NDX file ledger is missing")
    expected_files = sorted(expected_files, key=lambda row: str(row["relative_path"]).casefold())
    actual_files = sorted(actual_files, key=lambda row: row["relative_path"].casefold())
    if actual_files != expected_files or any(
        (
            metadata.get("inspection_mode")
            != "PATH_TYPE_SIZE_SHA256_ONLY_EXCEPT_POST_FENCED_INFRASTRUCTURE_STDERR_DIAGNOSTIC",
            metadata.get("exact_file_closure") is not True,
            metadata.get("controller_stdout_size") != 0,
            metadata.get("controller_stderr_size") != 872,
            metadata.get("native_result_file_count") != 0,
            metadata.get("native_summary_file_count") != 0,
            metadata.get("native_report_file_count") != 0,
            metadata.get("post_receipt_present") is not False,
        )
    ):
        raise InvalidEvidence("terminal NDX exact file closure drift")

    state = B.load_json(STATE_PATH)
    cells = state.get("cells")
    if not isinstance(cells, list) or len(cells) != 1 or not isinstance(cells[0], Mapping):
        raise InvalidEvidence("terminal NDX state cell closure drift")
    cell = cells[0]
    attempts = cell.get("attempts")
    if not isinstance(attempts, list) or len(attempts) != 1 or not isinstance(
        attempts[0], Mapping
    ):
        raise InvalidEvidence("terminal NDX attempt count drift")
    attempt = attempts[0]
    cleanup = state.get("scheduler_cleanup")
    expected_cleanup = {
        "status": "PASS",
        "operation": "Unregister",
        "state": "Absent",
        "cleanup": "UNREGISTERED",
        "task_name": "QM_QM13209_NDX_AUDIT_9ea9e19e84280aaf42c2a3b4",
    }
    expected_terminal_state = {
        "status": "INVALID_TERMINAL",
        "cell_status": "INVALID_TERMINAL_OUTPUT",
        "controller_attempt_count": 1,
        "controller_exit_code": 1,
        "controller_started_utc": "2026-07-21T12:43:02.583261+00:00",
        "controller_finished_utc": "2026-07-21T12:43:16.814502+00:00",
        "outcome_possible_since_utc": "2026-07-21T12:43:02.583261+00:00",
        "worker_pid": None,
        "active_cell": None,
        "runner_result": None,
        "native_result": None,
        "native_root": None,
        "summary": None,
        "outcome_artifacts": [],
        "scheduler_cleanup": expected_cleanup,
    }
    if (
        payload.get("terminal_state") != expected_terminal_state
        or state.get("status") != "INVALID_TERMINAL"
        or state.get("worker_pid") is not None
        or state.get("active_cell") is not None
        or cell.get("cell_id") != CELL_ID
        or cell.get("status") != "INVALID_TERMINAL_OUTPUT"
        or attempt.get("exit_code") != 1
        or attempt.get("started_utc")
        != expected_terminal_state["controller_started_utc"]
        or attempt.get("finished_utc")
        != expected_terminal_state["controller_finished_utc"]
        or attempt.get("runner_result") is not None
        or attempt.get("native_result") is not None
        or attempt.get("native_root") is not None
        or attempt.get("summary") is not None
        or attempt.get("outcome_artifacts") != []
        or state.get("outcome_possible_since_utc")
        != expected_terminal_state["outcome_possible_since_utc"]
        or not isinstance(cleanup, Mapping)
        or {key: cleanup.get(key) for key in expected_cleanup} != expected_cleanup
    ):
        raise InvalidEvidence("terminal NDX state semantic closure drift")
    stdout_binding = {
        "path": str((RUN_ROOT / "native" / CELL_ID / "controller.stdout.log").resolve()),
        "size": 0,
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    }
    stderr_binding = {
        "path": str((RUN_ROOT / "native" / CELL_ID / "controller.stderr.log").resolve()),
        "size": 872,
        "sha256": "97f0ad0fb80bcc3c140a36ded78cdc71301422c15588a977531bc8d483e0844b",
    }
    if (
        attempt.get("stdout") != stdout_binding
        or attempt.get("stderr") != stderr_binding
        or attempt.get("sealed_artifacts") != [stderr_binding, stdout_binding]
        or attempt.get("controller_output_opened") is not False
        or attempt.get("native_output_opened") is not False
    ):
        raise InvalidEvidence("terminal NDX opaque controller binding drift")
    if state.get("outcome_fence") != {
        "post_is_first_controller_and_native_outcome_reader": True,
        "worker_opens_controller_stderr": False,
        "worker_opens_controller_stdout": False,
        "worker_opens_native_reports": False,
        "worker_parses_market_values": False,
        "worker_seals_paths_types_sizes_hashes_only": True,
    }:
        raise InvalidEvidence("terminal NDX worker outcome fence drift")

    expected_failure = {
        "classification": "DEV2_CUSTOM_HISTORY_TOPOLOGY_DRIFT",
        "failure_stage": "PRE_MT5_CUSTOM_HISTORY_TOPOLOGY_GATE",
        "mt5_terminal_started": False,
        "metatester_started": False,
        "native_run_root_created": False,
        "source": "CONTROLLER_STDERR_DIAGNOSTIC_OPENED_ONLY_AFTER_POST_FENCE",
        "expected_custom_history_symbols": [
            "EURUSD.DWX",
            "GBPUSD.DWX",
            "GDAXI.DWX",
            "NDX.DWX",
            "USDJPY.DWX",
            "XAUUSD.DWX",
        ],
        "unexpected_addition": "WS30.DWX",
        "strategy_merit_cause": False,
        "parameter_cause": False,
    }
    expected_fence = {
        "worker_opened_controller_stdout": False,
        "worker_opened_controller_stderr": False,
        "worker_opened_native_reports": False,
        "post_fence_crossed_before_infrastructure_diagnostic": True,
        "controller_stderr_diagnostic_opened_after_post_fence": True,
        "economic_report_present": False,
        "economic_report_opened": False,
        "native_result_opened": False,
        "deal_rows_parsed": False,
        "market_values_parsed": False,
        "strategy_merit_adjudicated": False,
        "merit_verdict": None,
    }
    expected_disposition = {
        "one_shot_attempt001_consumed": True,
        "pre_permitted": False,
        "launch_permitted": False,
        "resume_permitted": False,
        "worker_permitted": False,
        "post_permitted": False,
        "retry_permitted": False,
        "attempt002_permitted": False,
        "terminal_hopping_permitted": False,
        "remaining_attempt_budget": 0,
        "attempt001_controls_and_artifacts_must_remain_immutable": True,
    }
    if (
        payload.get("infrastructure_failure") != expected_failure
        or payload.get("outcome_fence") != expected_fence
        or payload.get("terminal_disposition") != expected_disposition
    ):
        raise InvalidEvidence("terminal NDX disposition/outcome-fence drift")
    _probe_task_absence(expected_cleanup["task_name"])
    authorization = B.load_json(AUTHORIZATION_PATH)
    claim = B.load_json(CLAIM_PATH)
    if (
        authorization.get("resume_relaunch_retry_forbidden") is not True
        or claim.get("resume_relaunch_retry_forbidden") is not True
        or claim.get("run_root") != str(RUN_ROOT.resolve())
    ):
        raise InvalidEvidence("terminal NDX one-shot claim/authorization drift")
    B.assert_binding(closure_binding, "stable terminal NDX closure")
    return {
        "binding": closure_binding,
        "status": payload["status"],
        "classification": expected_failure["classification"],
    }


def _block_terminal_operation(operation: str) -> None:
    normalized = operation.upper()
    if normalized not in TERMINALLY_FORBIDDEN_OPERATIONS:
        raise ValueError(f"unknown terminal operation: {operation}")
    closure = validate_terminal_closure()
    raise AuthorizationError(
        f"QM13209 NDX ATTEMPT_001 is terminal-invalid; {normalized} is permanently "
        f"forbidden by {closure['binding']['sha256']}"
    )


def _assert_exact_control(path: Path, expected: Path, label: str) -> Path:
    if path.resolve() != expected.resolve():
        raise InvalidEvidence(f"{label} must be exactly {expected.resolve()}")
    return path.resolve()


def enforce_symbol_policy(symbol: str) -> None:
    if symbol != RESEARCH_SYMBOL or not symbol.endswith(".DWX"):
        raise InvalidEvidence("prescreen symbol must be exactly NDX.DWX")


def _assert_run_root(path: Path) -> Path:
    if path.resolve() == (RUN_NAMESPACE_ROOT / "ATTEMPT_002").resolve():
        _block_terminal_operation("ATTEMPT_002")
    return _assert_exact_control(path, RUN_ROOT, "run root")


def validate_old_workitem_closure() -> dict[str, Any]:
    closure = B.load_json(OLD_CLOSURE_PATH)
    if (
        closure.get("status") != "INVALID_INFRASTRUCTURE_CLOSED_OUTCOME_BLIND_NO_MERIT_VERDICT"
        or closure.get("old_workitem", {}).get("workitem_id") != OLD_WORKITEM_ID
        or closure.get("old_workitem", {}).get("prior_failure") != "summary_missing"
        or closure.get("old_workitem", {}).get("evidence") is not None
        or closure.get("classification", {}).get("strategy_merit_adjudicated") is not False
        or closure.get("outcome_fence", {}).get("tester_ini_opened") is not False
    ):
        raise InvalidEvidence("old summary_missing closure drift")
    expected_file = {
        "relative_path": "QM5_13209/20260721_074735/raw/run_01/tester.ini",
        "size": 459,
        "sha256": "c330cb04599995fd999a58ff1ce9b440e3fc284478d1d678889ec6bc5cf7e416",
        "content_opened": False,
    }
    if closure.get("filesystem_inventory", {}).get("files") != [expected_file]:
        raise InvalidEvidence("old workitem outcome-blind inventory drift")
    path = OLD_WORKITEM_ROOT / Path(expected_file["relative_path"])
    _exact_binding(path, {**expected_file, "path": str(path)}, "old tester.ini opaque binding")
    actual_files = [item for item in OLD_WORKITEM_ROOT.rglob("*") if item.is_file()]
    if [item.resolve() for item in actual_files] != [path.resolve()]:
        raise InvalidEvidence("old workitem acquired an unregistered file")
    return {"binding": B.file_binding(OLD_CLOSURE_PATH), "status": closure["status"]}


def validate_factory_database_gate() -> dict[str, Any]:
    uri = f"file:{FACTORY_DB_PATH.as_posix()}?mode=ro"
    connection = sqlite3.connect(uri, uri=True, timeout=5)
    try:
        connection.row_factory = sqlite3.Row
        rows = {
            str(row["id"]): row
            for row in connection.execute(
                "SELECT id,status,verdict,attempt_count,evidence_path,claimed_by,payload_json "
                "FROM work_items WHERE ea_id='QM5_13209'"
            )
        }
    finally:
        connection.close()
    expected_ids = {OLD_WORKITEM_ID, DUPLICATE_WORKITEM_ID, SP500_RESULT_WORKITEM_ID}
    if set(rows) != expected_ids:
        raise InvalidEvidence("QM13209 Factory workitem identity set drift")
    old = rows[OLD_WORKITEM_ID]
    old_payload = json.loads(str(old["payload_json"] or "{}"))
    closure_binding = B.file_binding(OLD_CLOSURE_PATH)
    if (
        (
            old["status"], old["verdict"], old["attempt_count"],
            old["evidence_path"], old["claimed_by"],
        )
        != ("failed", "INFRA_FAIL", 1, None, None)
        or old_payload.get("final_failure") != "summary_missing"
        or old_payload.get("closure_artifact_path") != str(OLD_CLOSURE_PATH.resolve())
        or old_payload.get("closure_artifact_sha256") != closure_binding["sha256"]
        or old_payload.get("strategy_merit_adjudicated") is not False
    ):
        raise InvalidEvidence("aff5 Factory DB closure end-state drift")
    duplicate = rows[DUPLICATE_WORKITEM_ID]
    duplicate_payload = json.loads(str(duplicate["payload_json"] or "{}"))
    if (
        (
            duplicate["status"], duplicate["verdict"], duplicate["attempt_count"],
            duplicate["evidence_path"], duplicate["claimed_by"],
        )
        != ("failed", "INVALID", 0, None, None)
        or duplicate_payload.get("duplicate_of") != SP500_RESULT_WORKITEM_ID
        or duplicate_payload.get("superseded_by") != SP500_RESULT_WORKITEM_ID
    ):
        raise InvalidEvidence("auto-enqueued SP500 duplicate end-state drift")
    result = rows[SP500_RESULT_WORKITEM_ID]
    if (
        (
            result["status"], result["verdict"], result["attempt_count"],
            result["evidence_path"], result["claimed_by"],
        )
        != ("done", "FAIL", 0, str(SP500_EVIDENCE_PATH), None)
    ):
        raise InvalidEvidence("existing SP500 strategy-result row drift")
    _exact_binding(SP500_EVIDENCE_PATH, EXPECTED_SP500_EVIDENCE, "SP500 evidence opaque binding")
    active = [
        item_id
        for item_id, row in rows.items()
        if str(row["status"]) in {"pending", "active", "claimed", "running"}
    ]
    if active:
        raise InvalidEvidence(f"QM5_13209 Factory rows remain active: {active}")
    return {
        "status": "PASS",
        "database_path": str(FACTORY_DB_PATH.resolve()),
        "old_ndx": "failed/INFRA_FAIL/evidence_path_NULL",
        "sp500_duplicate": "failed/INVALID/evidence_path_NULL",
        "existing_sp500_result": "done/FAIL/unchanged_opaque_binding",
    }


def validate_build_receipt() -> dict[str, Any]:
    receipt = B.load_json(BUILD_RECEIPT_PATH)
    if (
        receipt.get("status") != "APPROVED_FOR_BACKTEST"
        or receipt.get("ea_id") != EA_LABEL
        or receipt.get("research_symbol") != RESEARCH_SYMBOL
        or receipt.get("timeframe") != TIMEFRAME
        or receipt.get("source_commit") != "8d762f66321ef9a2aa3503ae8b464ea378e5a34f"
    ):
        raise InvalidEvidence("build receipt is not exactly review-approved")
    artifacts = receipt.get("artifact_bindings")
    expected_paths = {
        "mq5": MQ5_PATH,
        "ex5": EX5_PATH,
        "spec": SPEC_PATH,
        "ndx_m5_set": SET_PATH,
    }
    if not isinstance(artifacts, Mapping) or set(artifacts) != set(expected_paths):
        raise InvalidEvidence("build artifact binding closure drift")
    for role, path in expected_paths.items():
        _exact_binding(path, artifacts[role], f"build {role}")
    _exact_binding(CANONICAL_BUILD_RESULT_PATH, EXPECTED_CANONICAL_BUILD, "canonical build result")
    review_binding = _exact_binding(REVIEW_PATH, EXPECTED_REVIEW, "review verdict")
    review = B.load_json(REVIEW_PATH)
    if (
        review.get("review_task_id") != "6154711f-fb6e-4900-a208-17fe7df355b2"
        or review.get("build_task_id") != "d54ae7b2-bed6-4c7d-85a2-5030944f3127"
        or review.get("ea_id") != EA_LABEL
        or review.get("verdict") != "APPROVE_FOR_BACKTEST"
        or review.get("rework_directives") is not None
    ):
        raise InvalidEvidence("review verdict semantic drift")
    return {
        "binding": B.file_binding(BUILD_RECEIPT_PATH),
        "source_commit": receipt["source_commit"],
        "review": review_binding,
        "canonical_build_result": B.file_binding(CANONICAL_BUILD_RESULT_PATH),
    }


def validate_analysis_contract() -> dict[str, Any]:
    contract = B.load_json(CONTRACT_PATH)
    if (
        contract.get("status") != "IMPLEMENTED_REVIEW_APPROVED_NOT_AUTHORIZED_NOT_LAUNCHED"
        or contract.get("analysis_id") != ANALYSIS_ID
        or contract.get("candidate", {}).get("research_symbol") != RESEARCH_SYMBOL
        or contract.get("candidate", {}).get("magic_slot") != MAGIC_SLOT
        or contract.get("candidate", {}).get("magic") != MAGIC
        or contract.get("scope", {}).get("run_root") != str(RUN_ROOT)
        or contract.get("scope", {}).get("attempts") != 1
        or any(contract.get("scope", {}).get(key) is not False for key in (
            "resume_permitted", "relaunch_permitted", "retry_permitted"
        ))
        or contract.get("cell", {}).get("cell_id") != CELL_ID
        or contract.get("cell", {}).get("accepted_deterministic_duplicates") != 2
        or contract.get("cell", {}).get("maximum_native_starts") != 4
        or contract.get("merit_gates") != {
            "minimum_trades": 5,
            "minimum_native_profit_factor": "1.20",
            "minimum_cost_adjusted_profit_factor": "1.20",
            "cost_adjusted_net_must_be_strictly_positive": True,
            "all_lifecycle_and_session_invariants_must_pass": True,
        }
    ):
        raise InvalidEvidence("NDX prescreen analysis contract drift")
    return {"binding": B.file_binding(CONTRACT_PATH), "status": contract["status"]}


def validate_backtest_data_receipt(
    path: Path = DATA_RECEIPT_PATH,
    symbol: str = RESEARCH_SYMBOL,
    *,
    verify_files: bool = True,
) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    receipt_binding = _exact_binding(path, EXPECTED_DATA_RECEIPT, "NDX data receipt")
    payload = B.load_json(path)
    coverage = payload.get("coverage", {})
    files = payload.get("files")
    if (
        payload.get("artifact_type") != "QM5_10834_BACKTEST_DATA_RECEIPT"
        or payload.get("symbol") != RESEARCH_SYMBOL
        or payload.get("terminal") != "DEV2"
        or coverage.get("from_date") != "2018-07-02"
        or coverage.get("to_date") != "2025-12-31"
        or coverage.get("history_file_count") != 8
        or coverage.get("tick_file_count") != 90
        or not isinstance(files, list)
        or len(files) != 98
        or payload.get("outcome_fence", {}).get("strategy_outcomes_read") is not False
    ):
        raise InvalidEvidence("frozen NDX data receipt semantic drift")
    periods = {(str(row.get("kind")), str(row.get("period"))) for row in files if isinstance(row, Mapping)}
    required = {("history", "2022"), *{("ticks", f"2022{month:02d}") for month in range(7, 13)}}
    if not required.issubset(periods):
        raise InvalidEvidence("NDX 2022H2 exact-tick coverage is incomplete")
    seen: set[Path] = set()
    if verify_files:
        for index, row in enumerate(files):
            if not isinstance(row, Mapping) or set(row) != {"kind", "path", "period", "sha256", "size"}:
                raise InvalidEvidence(f"data file ledger[{index}] malformed")
            file_path = Path(str(row["path"])).resolve()
            if file_path in seen:
                raise InvalidEvidence("duplicate data file path")
            seen.add(file_path)
            _exact_binding(file_path, {**row, "path": str(file_path)}, f"data file[{index}]")
    return {
        "receipt": receipt_binding,
        "file_count": 98,
        "history_files": 8,
        "tick_files": 90,
        "file_ledger_sha256": B.canonical_sha256(files),
        "historical_factory_bindings_replayed": False,
    }


def validate_current_ndx_semantics() -> dict[str, Any]:
    aliases = B.load_json(ALIASES_PATH)
    observed: dict[str, str] = {}
    for venue in aliases.get("venues", []):
        if not isinstance(venue, Mapping):
            continue
        matches = [
            row for row in venue.get("symbols", [])
            if isinstance(row, Mapping) and row.get("logical_symbol") == RESEARCH_SYMBOL
        ]
        if matches:
            if len(matches) != 1:
                raise InvalidEvidence("NDX alias is ambiguous within a venue")
            observed[str(venue.get("venue_id"))] = str(matches[0].get("raw_symbol"))
    if observed != {"DXZ_LIVE": "NDX", "FTMO_TRIAL": "US100.cash"}:
        raise InvalidEvidence(f"current exact NDX alias semantics drift: {observed}")

    with MATRIX_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        matrix = [row for row in csv.DictReader(handle) if row.get("symbol") == RESEARCH_SYMBOL]
    if len(matrix) != 1 or (
        matrix[0].get("asset_class") != "indices"
        or matrix[0].get("import_log_path") != "Custom/Indices/Index 3/NDX.DWX"
        or matrix[0].get("canonical_name_verified") != "true"
    ):
        raise InvalidEvidence("current NDX research-symbol matrix semantics drift")

    with MAGIC_REGISTRY_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        magic_rows = [row for row in csv.DictReader(handle) if row.get("ea_id") == str(EA_ID)]
    expected_magic = [
        row for row in magic_rows
        if row.get("symbol") == RESEARCH_SYMBOL and row.get("symbol_slot") == str(MAGIC_SLOT)
    ]
    if len(expected_magic) != 1 or expected_magic[0].get("magic") != str(MAGIC) or expected_magic[0].get("status") != "active":
        raise InvalidEvidence("NDX slot-1 magic semantics drift")

    costs = B.load_json(COST_PATH).get("symbols", {})
    if (
        not isinstance(costs, Mapping)
        or costs.get("NDX", {}).get("alias_of") != "US100"
        or Decimal(str(costs.get("US100", {}).get("worst_case_rt_per_lot_usd"))) != COMMISSION_RT_PER_LOT
    ):
        raise InvalidEvidence("current NDX venue-cost semantics drift")
    defaults = B.load_json(TESTER_DEFAULTS_PATH)
    if defaults.get("initial_deposit") != 100000 or defaults.get("deposit_currency") != "USD" or defaults.get("leverage") != 100:
        raise InvalidEvidence("tester 100k/USD/1:100 defaults drift")
    return {
        "aliases": observed,
        "matrix_row": matrix[0],
        "magic": MAGIC,
        "cost_rt_per_lot_usd": "5.50",
        "tester": {"deposit": 100000, "currency": "USD", "leverage": 100},
    }


def assert_dev2_quiescence() -> dict[str, Any]:
    if not FACTORY_OFF_FLAG_PATH.is_file():
        raise InvalidEvidence("Factory OFF flag is required")
    script = r"""
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath('D:\QM\mt5\DEV2')
$names=@('terminal64.exe','metatester64.exe','metaeditor64.exe')
$processes=@(Get-CimInstance Win32_Process | ForEach-Object {
  $p=[string]$_.ExecutablePath
  if($p -and $names -contains ([IO.Path]::GetFileName($p).ToLowerInvariant()) -and
     [IO.Path]::GetFullPath($p).StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) {
    [ordered]@{pid=[int]$_.ProcessId;name=[string]$_.Name;path=[IO.Path]::GetFullPath($p)}
  }
})
$tasks=@(Get-ScheduledTask -ErrorAction Stop | Where-Object {
  ($_.TaskName -like 'QM_DEV2_SMOKE_*' -or $_.TaskName -like 'QM_DEV2_CLEANUP_*' -or
   $_.TaskName -like 'QM_DEV2_PROFILE_INIT_*') -and $_.State.ToString() -in @('Running','Queued')
} | ForEach-Object {[ordered]@{task_name=$_.TaskName;state=$_.State.ToString()}})
$mutex=$null;$held=$false;$available=$false
try {
  try {$mutex=[Threading.Mutex]::OpenExisting('Global\QM_DEV2_SMOKE_CONTROLLER')}
  catch [Threading.WaitHandleCannotBeOpenedException] {$created=$false;$mutex=New-Object Threading.Mutex($false,'Global\QM_DEV2_SMOKE_CONTROLLER',[ref]$created)}
  try {$held=$mutex.WaitOne(0);$available=$held}
  catch [Threading.AbandonedMutexException] {$held=$true;$available=$true}
} finally {if($held){$mutex.ReleaseMutex()};if($null-ne$mutex){$mutex.Dispose()}}
[ordered]@{processes=$processes;active_tasks=$tasks;mutex_available=$available;command_lines_read=$false}|ConvertTo-Json -Depth 5 -Compress
"""
    completed = subprocess.run(
        [str(B.POWERSHELL_PATH), "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise InvalidEvidence("DEV2 quiescence probe failed closed")
    try:
        proof = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise InvalidEvidence("DEV2 quiescence probe returned invalid JSON") from exc
    if proof != {"processes": [], "active_tasks": [], "mutex_available": True, "command_lines_read": False}:
        raise InvalidEvidence(f"DEV2 is not quiescent: {proof}")
    return {
        "status": "PASS",
        "factory_off_flag": B.file_binding(FACTORY_OFF_FLAG_PATH),
        **proof,
    }


def _expected_binding_paths(symbol: str) -> dict[str, Path]:
    enforce_symbol_policy(symbol)
    return {
        "card": CARD_PATH,
        "spec": SPEC_PATH,
        "mq5": MQ5_PATH,
        "ex5": EX5_PATH,
        "set": SET_PATH,
        "analysis_contract": CONTRACT_PATH,
        "old_workitem_closure": OLD_CLOSURE_PATH,
        "build_receipt": BUILD_RECEIPT_PATH,
        "build_result": BUILD_RESULT_PATH,
        "canonical_build_result": CANONICAL_BUILD_RESULT_PATH,
        "review_verdict": REVIEW_PATH,
        "aliases": ALIASES_PATH,
        "matrix": MATRIX_PATH,
        "cost": COST_PATH,
        "magic_registry": MAGIC_REGISTRY_PATH,
        "ea_registry": EA_REGISTRY_PATH,
        "tester_defaults": TESTER_DEFAULTS_PATH,
        "runner": B.RUNNER_PATH,
        "runner_child": B.RUNNER_CHILD_PATH,
        "dev2_cleanup_helper": B.DEV2_CLEANUP_HELPER_PATH,
        "dev2_machine_credential_probe": B.CREDENTIAL_PROBE_PATH,
        "dev2_machine_credential_helper": B.CREDENTIAL_HELPER_PATH,
        "dev2_machine_credential": B.MACHINE_CREDENTIAL_PATH,
        "dev2_machine_credential_rotation_receipt": B.MACHINE_CREDENTIAL_ROTATION_RECEIPT_PATH,
        "runner_smoke": B.RUN_SMOKE_PATH,
        "dev2_lane_contract": B.DEV2_LANE_CONTRACT_PATH,
        "tester_groups_canonical": B.TESTER_GROUPS_CANONICAL_PATH,
        "tester_groups_dev2": B.TESTER_GROUPS_DEV2_PATH,
        "dev2_symbol_database": B.TERMINAL_SYMBOL_DATABASE_PATH,
        "report_parser": B.REPORT_CORE_PATH,
        "powershell": B.POWERSHELL_PATH,
        "python": B.PYTHON_PATH,
        "scheduled_task_helper": SCHEDULED_TASK_HELPER_PATH,
        "tool": TOOL_PATH,
    }


def _binding_map(symbol: str) -> dict[str, dict[str, Any]]:
    bindings: dict[str, dict[str, Any]] = {}
    for role, path in _expected_binding_paths(symbol).items():
        bindings[role] = B.file_binding(path, EXPECTED_INFRA_HASHES.get(role))
    if bindings["tester_groups_dev2"]["sha256"] != bindings["tester_groups_canonical"]["sha256"]:
        raise InvalidEvidence("DEV2 tester groups differ from canonical")
    return bindings


def _validate_set_contract(symbol: str, metadata: Mapping[str, str], inputs: Mapping[str, str]) -> None:
    enforce_symbol_policy(symbol)
    if metadata.get("ea_id") != "13209" or metadata.get("symbol") != symbol or metadata.get("timeframe") != TIMEFRAME or metadata.get("magic_slot") != "1":
        raise InvalidEvidence("NDX M5 set metadata drift")
    expected = {
        "qm_ea_id": "13209", "qm_magic_slot_offset": "1", "RISK_FIXED": "1000",
        "RISK_PERCENT": "0", "PORTFOLIO_WEIGHT": "1", "pm_start_hour": "20",
        "pm_start_min": "30", "pm_end_hour": "23", "pm_end_min": "0",
        "sweep_start_hour": "16", "sweep_start_min": "30", "sweep_end_hour": "18",
        "sweep_end_min": "0", "entry_cancel_hour": "19", "flatten_hour": "20",
        "strategy_tp_mode": "STRATEGY_TP_OPPOSITE_EXTREME",
    }
    drift = {key: (value, inputs.get(key)) for key, value in expected.items() if inputs.get(key) != value}
    if drift:
        raise InvalidEvidence(f"NDX set input drift: {drift}")


def execution_contract() -> dict[str, Any]:
    return {
        "terminal": "DEV2",
        "controller": "ISOLATED_DEV2_SCHEDULED_TASK_LANE",
        "controller_mutex": "Global\\QM_DEV2_SMOKE_CONTROLLER",
        "factory_off_required": True,
        "one_shot": True,
        "resume_relaunch_retry_forbidden": True,
        "accepted_duplicates": 2,
        "maximum_infrastructure_warmups": 2,
        "maximum_native_starts": 4,
        "model": 4,
        "deposit": 100000,
        "currency": "USD",
        "leverage": 100,
        "claim_path": str(CLAIM_PATH.resolve()),
        "authorization_scope": AUTHORIZATION_SCOPE,
    }


def build_plan(symbol: str, set_binding: Mapping[str, Any], run_root: Path) -> dict[str, Any]:
    enforce_symbol_policy(symbol)
    _assert_run_root(run_root)
    cell = {
        "cell_id": CELL_ID,
        "symbol": symbol,
        "cohort": "PRESCREEN",
        "from_date": "2022-07-01",
        "to_date": "2022-12-31",
        "timeframe": TIMEFRAME,
        "model": 4,
        "duplicates": 2,
        "maximum_postflight_acceptable_infrastructure_warmups": 2,
        "maximum_attempts": 4,
        "native_start_budget_is_outcome_independent": True,
        "set": dict(set_binding),
        "output_root": str((run_root / "native" / CELL_ID).resolve()),
    }
    basis = {
        "single_authorized_symbol": symbol,
        "cells": [cell],
        "accepted_duplicate_run_count": 2,
        "maximum_native_starts": 4,
        "technical_prescreen": {"authorized": True, "merit_eligible": True, "window": "2022H2"},
    }
    return {**basis, "plan_sha256": B.canonical_sha256(basis)}


def preflight(symbol: str, data_receipt_path: Path, build_receipt_path: Path, run_root: Path) -> dict[str, Any]:
    _block_terminal_operation("PRE")
    enforce_symbol_policy(symbol)
    _assert_run_root(run_root)
    _assert_exact_control(data_receipt_path, DATA_RECEIPT_PATH, "data receipt")
    _assert_exact_control(build_receipt_path, BUILD_RECEIPT_PATH, "build receipt")
    if RUN_ROOT.exists() and any(RUN_ROOT.iterdir()):
        raise InvalidEvidence("fresh one-shot run root is not empty")
    if CLAIM_PATH.exists() or STATE_PATH.exists() or JOB_PATH.exists():
        raise InvalidEvidence("one-shot analysis is already consumed")
    contract = validate_analysis_contract()
    closure = validate_old_workitem_closure()
    factory_db = validate_factory_database_gate()
    build = validate_build_receipt()
    data = validate_backtest_data_receipt(data_receipt_path, symbol)
    semantics = validate_current_ndx_semantics()
    quiescence = assert_dev2_quiescence()
    bindings = _binding_map(symbol)
    rotation = B.validate_machine_credential_rotation_receipt(bindings)
    card = CARD_PATH.read_text(encoding="utf-8-sig")
    if "ea_id: QM5_13209" not in card or "status: APPROVED" not in card or "g0_status: APPROVED" not in card:
        raise InvalidEvidence("Strategy Card approval drift")
    includes = B.include_closure(MQ5_PATH)
    metadata, set_inputs = B.parse_set(SET_PATH)
    _validate_set_contract(symbol, metadata, set_inputs)
    effective_inputs = B.effective_input_contract(MQ5_PATH, includes, set_inputs)
    if effective_inputs.get("InpQMSimCommissionPerLot", {}).get("canonical") != "0":
        raise InvalidEvidence("EA-side simulated commission must be zero")
    plan = build_plan(symbol, bindings["set"], run_root)
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_PRE_RECEIPT",
        "status": "PASS",
        "created_utc": B.utc_now(),
        "analysis_id": ANALYSIS_ID,
        "run_root": str(RUN_ROOT.resolve()),
        "symbol_policy": {
            "authorized_symbol": RESEARCH_SYMBOL,
            "dwx_research_backtest_required": True,
            "suffix_removed_only_at_deploy_packaging": True,
            "live_aliases": semantics["aliases"],
            "magic_slot": MAGIC_SLOT,
            "magic": MAGIC,
        },
        "outcome_fence": {
            "native_reports_opened": False,
            "deal_rows_parsed": False,
            "market_values_parsed": False,
            "mt5_terminal_started": False,
            "metatester_started": False,
        },
        "bindings": bindings,
        "analysis_contract": contract,
        "old_workitem_closure": closure,
        "factory_database_gate": factory_db,
        "build_review": build,
        "backtest_data_receipt": data,
        "current_ndx_semantics": semantics,
        "dev2_quiescence": quiescence,
        "machine_credential_rotation": rotation,
        "include_closure": includes,
        "effective_inputs": effective_inputs,
        "execution_contract": execution_contract(),
        "cost_schedule": {
            "symbol": RESEARCH_SYMBOL,
            "spread": "EMBEDDED_IN_BOUND_REAL_TICKS",
            "swap": "REQUIRED_ZERO_BY_INTRADAY_FLAT_INVARIANT",
            "worst_rt_per_lot_usd": "5.50",
        },
        "merit_contract": MERIT_GATES,
        "plan": plan,
    }


def assert_pre_receipt(path: Path, expected_sha256: str) -> dict[str, Any]:
    _assert_exact_control(path, PRE_RECEIPT_PATH, "PRE receipt")
    binding = B.file_binding(path, expected_sha256)
    pre = B.load_json(path)
    if (
        pre.get("artifact_type") != "QM5_13209_NDX_PRESCREEN_OUTCOME_FENCED_PRE_RECEIPT"
        or pre.get("status") != "PASS"
        or pre.get("analysis_id") != ANALYSIS_ID
        or pre.get("run_root") != str(RUN_ROOT.resolve())
        or pre.get("merit_contract") != MERIT_GATES
        or pre.get("execution_contract") != execution_contract()
        or pre.get("plan") != build_plan(RESEARCH_SYMBOL, pre.get("bindings", {}).get("set", {}), RUN_ROOT)
    ):
        raise InvalidEvidence("PRE identity/plan drift")
    bindings = pre.get("bindings")
    if not isinstance(bindings, Mapping) or set(bindings) != set(_expected_binding_paths(RESEARCH_SYMBOL)):
        raise InvalidEvidence("PRE binding-role closure drift")
    for role, item in bindings.items():
        B.assert_binding(item, f"PRE {role}")
    validate_analysis_contract()
    validate_old_workitem_closure()
    validate_build_receipt()
    if pre.get("backtest_data_receipt") != validate_backtest_data_receipt(DATA_RECEIPT_PATH, RESEARCH_SYMBOL):
        raise InvalidEvidence("PRE/data receipt drift")
    current = validate_current_ndx_semantics()
    if pre.get("current_ndx_semantics") != current:
        raise InvalidEvidence("PRE/current NDX semantics drift")
    B.assert_binding(binding, "stable PRE receipt")
    return pre


def validate_current_research_data_gate(pre: Mapping[str, Any]) -> None:
    validate_factory_database_gate()
    validate_current_ndx_semantics()
    validate_backtest_data_receipt(DATA_RECEIPT_PATH, RESEARCH_SYMBOL)
    assert_dev2_quiescence()
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("current DEV2 execution contract drift")


def validate_authorization(
    path: Path,
    pre_sha256: str,
    *,
    pre: Mapping[str, Any] | None = None,
    require_current: bool = True,
    now: datetime | None = None,
) -> dict[str, Any]:
    _assert_exact_control(path, AUTHORIZATION_PATH, "authorization")
    binding = B.file_binding(path)
    payload = B.load_json(path)
    expected = {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_NATIVE_OUTCOME_AUTHORIZATION",
        "status": "AUTHORIZED",
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_sha256": pre_sha256.lower(),
        "scope": AUTHORIZATION_SCOPE,
        "authorized_by": "OWNER",
        "authorized_symbol": RESEARCH_SYMBOL,
        "authorized_cells": [CELL_ID],
        "duplicates_per_cell": 2,
        "maximum_infrastructure_warmups_per_cell": 2,
        "maximum_native_starts": 4,
        "model": 4,
        "authorize_native_outcomes": True,
        "resume_relaunch_retry_forbidden": True,
    }
    if set(payload) != {*expected, "created_utc", "expires_utc"} or any(payload.get(key) != value for key, value in expected.items()):
        raise AuthorizationError("one-shot native authorization drift")
    if pre is not None:
        cells = pre.get("plan", {}).get("cells", [])
        plan_cell_ids = [
            str(cell.get("cell_id", ""))
            for cell in cells
            if isinstance(cell, Mapping)
        ]
        if len(plan_cell_ids) != len(cells) or payload["authorized_cells"] != plan_cell_ids:
            raise AuthorizationError("authorized cells do not exactly match PRE plan cells")
    created = B.parse_utc(str(payload["created_utc"]), "authorization created_utc")
    expires = B.parse_utc(str(payload["expires_utc"]), "authorization expires_utc")
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    if expires <= created or expires - created > timedelta(hours=24) or (require_current and not created - timedelta(minutes=5) <= current <= expires):
        raise AuthorizationError("authorization chronology/validity drift")
    return {"binding": binding, "payload_sha256": B.canonical_sha256(payload), "payload": payload}


def _native_attempt_claim_basis(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    state_path: Path,
    authorization: Mapping[str, Any],
    preclaim_probe: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": "QM5_13209_NDX_PRESCREEN_NATIVE_ATTEMPT_CLAIM",
        "analysis_id": ANALYSIS_ID,
        "classification": "ATOMIC_ONE_SHOT_OUTCOME_BLIND_DEV2_CLAIM",
        "authorization_scope": AUTHORIZATION_SCOPE,
        "accepted_duplicates_per_cell": 2,
        "maximum_infrastructure_warmups_per_cell": 2,
        "maximum_native_starts": 4,
        "resume_relaunch_retry_forbidden": True,
        "same_worker_machine_credential_preclaim_probe": dict(preclaim_probe),
        "pre_receipt": B.file_binding(pre_path, pre_sha256),
        "run_root": str(RUN_ROOT.resolve()),
        "launch_state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "analysis_contract": dict(pre["bindings"]["analysis_contract"]),
        "ea_binary": dict(pre["bindings"]["ex5"]),
        "set": dict(pre["bindings"]["set"]),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
    }


def _validate_launch_job(
    job: Mapping[str, Any],
    pre: Mapping[str, Any],
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
) -> None:
    scheduler = job.get("scheduler")
    if not isinstance(scheduler, Mapping):
        raise AuthorizationError("launch job scheduler is missing")
    expected_scheduler = {
        "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
        "task_name": B.scheduled_task_name(pre_sha256, state_path),
        "task_path": "\\",
        "principal_sid": str(scheduler.get("principal_sid", "")),
        "logon_type": "S4U",
        "run_level": "Highest",
        "multiple_instances": "IgnoreNew",
        "execution_limit_seconds": B.required_scheduled_task_timeout(pre),
        "helper": pre["bindings"]["scheduled_task_helper"],
        "python": pre["bindings"]["python"],
    }
    expected = {
        "schema_version": 1,
        "launcher_revision": 1320901,
        "artifact_type": JOB_ARTIFACT_TYPE,
        "analysis_id": ANALYSIS_ID,
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "state_path": str(state_path.resolve()),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "tool": pre["bindings"]["tool"],
        "scheduler": expected_scheduler,
    }
    if set(job) != {*expected, "created_utc", "authorization"} or any(
        job.get(key) != value for key, value in expected.items()
    ):
        raise AuthorizationError("QM13209 launch job identity drift")
    if not expected_scheduler["principal_sid"].startswith("S-1-"):
        raise AuthorizationError("launch principal SID is malformed")
    authorization = job.get("authorization")
    if (
        not isinstance(authorization, Mapping)
        or set(authorization) != {"binding", "payload_sha256"}
        or not isinstance(authorization.get("binding"), Mapping)
        or not re.fullmatch(r"[0-9a-f]{64}", str(authorization.get("payload_sha256", "")))
    ):
        raise AuthorizationError("launch authorization identity is malformed")
    created = B.parse_utc(str(job.get("created_utc", "")), "launch job created_utc")
    if created > datetime.now(timezone.utc) + timedelta(minutes=5):
        raise AuthorizationError("launch job is future-dated")


def initial_launch_state(
    pre_path: Path,
    pre_sha256: str,
    pre: Mapping[str, Any],
    job_binding: Mapping[str, Any],
    authorization: Mapping[str, Any],
    scheduler: Mapping[str, Any],
) -> dict[str, Any]:
    now = B.utc_now()
    return {
        "schema_version": 1,
        "launcher_revision": 1320901,
        "artifact_type": STATE_ARTIFACT_TYPE,
        "analysis_id": ANALYSIS_ID,
        "status": "PENDING",
        "created_utc": now,
        "updated_utc": now,
        "started_utc": None,
        "finished_utc": None,
        "pre_receipt_path": str(pre_path.resolve()),
        "pre_receipt_sha256": pre_sha256.lower(),
        "plan_sha256": pre["plan"]["plan_sha256"],
        "job": dict(job_binding),
        "authorization": {
            "binding": dict(authorization["binding"]),
            "payload_sha256": authorization["payload_sha256"],
        },
        "scheduler": dict(scheduler),
        "scheduler_cleanup": {"status": "PENDING", "operation": "Unregister"},
        "worker_pid": None,
        "active_cell": None,
        "attempt_claim": None,
        "preclaim_probe": None,
        "outcome_possible_since_utc": None,
        "launches": [],
        "outcome_fence": {
            "worker_opens_controller_stdout": False,
            "worker_opens_controller_stderr": False,
            "worker_opens_native_reports": False,
            "worker_parses_market_values": False,
            "worker_seals_paths_types_sizes_hashes_only": True,
            "post_is_first_controller_and_native_outcome_reader": True,
        },
        "cells": [
            {
                "cell_id": cell["cell_id"],
                "status": "PENDING",
                "command_sha256": B.canonical_sha256(runner_command(pre, cell)),
                "attempts": [],
            }
            for cell in pre["plan"]["cells"]
        ],
    }


def _unregister_scheduler(pre: Mapping[str, Any], job: Mapping[str, Any]) -> dict[str, Any]:
    try:
        result = B._scheduler_call(pre, "Unregister", job)
        if (
            result.get("state") != "Absent"
            or result.get("exists") is not False
            or result.get("cleanup") not in {"UNREGISTERED", "ALREADY_ABSENT"}
        ):
            raise InvalidEvidence("scheduler Unregister did not prove absence")
        return {
            "status": "PASS",
            "operation": "Unregister",
            "task_name": job["scheduler"]["task_name"],
            "state": "Absent",
            "cleanup": result["cleanup"],
            "completed_utc": B.utc_now(),
        }
    except (B.AuditError, OSError, subprocess.SubprocessError, KeyError, TypeError, ValueError) as exc:
        return {
            "status": "FAIL",
            "operation": "Unregister",
            "task_name": str(job.get("scheduler", {}).get("task_name", "")),
            "state": "UNKNOWN",
            "error_type": type(exc).__name__,
            "completed_utc": B.utc_now(),
        }


def _persist_scheduler_cleanup(
    state_path: Path,
    cleanup: Mapping[str, Any],
    *,
    launch_failure: bool,
) -> None:
    if not state_path.is_file():
        return
    state = B.load_json(state_path)
    state["scheduler_cleanup"] = dict(cleanup)
    state["worker_pid"] = None
    if cleanup.get("status") != "PASS":
        state["status"] = "INVALID_SCHEDULER_CLEANUP"
    elif launch_failure and state.get("status") in {"PENDING", "RUNNING"}:
        state["status"] = "INVALID_LAUNCH"
        state["finished_utc"] = state.get("finished_utc") or B.utc_now()
    state["updated_utc"] = B.utc_now()
    B.atomic_json(state_path, state, replace=True)


def launch_detached(
    pre_path: Path,
    pre_sha256: str,
    authorization_path: Path,
    state_path: Path,
    *,
    resume: bool,
) -> dict[str, Any]:
    _block_terminal_operation("RESUME" if resume else "LAUNCH")
    if resume:
        raise AuthorizationError("one-shot NDX prescreen never permits resume")
    for observed, expected, label in (
        (pre_path, PRE_RECEIPT_PATH, "PRE receipt"),
        (authorization_path, AUTHORIZATION_PATH, "authorization"),
        (state_path, STATE_PATH, "launch state"),
    ):
        _assert_exact_control(observed, expected, label)
    with B.native_launch_lock():
        if CLAIM_PATH.exists() or STATE_PATH.exists() or JOB_PATH.exists():
            raise AuthorizationError("one-shot NDX prescreen is already consumed")
        pre = assert_pre_receipt(pre_path, pre_sha256)
        validate_current_research_data_gate(pre)
        authorization = validate_authorization(
            authorization_path, pre_sha256, pre=pre
        )
        authorization_identity = {
            "binding": authorization["binding"],
            "payload_sha256": authorization["payload_sha256"],
        }
        identity = B._scheduler_call(pre, "Identity")
        scheduler = {
            "mode": "WINDOWS_TASK_SCHEDULER_S4U_ON_DEMAND",
            "task_name": B.scheduled_task_name(pre_sha256, state_path),
            "task_path": "\\",
            "principal_sid": identity["principal_sid"],
            "logon_type": "S4U",
            "run_level": "Highest",
            "multiple_instances": "IgnoreNew",
            "execution_limit_seconds": B.required_scheduled_task_timeout(pre),
            "helper": pre["bindings"]["scheduled_task_helper"],
            "python": pre["bindings"]["python"],
        }
        job = {
            "schema_version": 1,
            "launcher_revision": 1320901,
            "artifact_type": JOB_ARTIFACT_TYPE,
            "analysis_id": ANALYSIS_ID,
            "created_utc": B.utc_now(),
            "pre_receipt_path": str(pre_path.resolve()),
            "pre_receipt_sha256": pre_sha256.lower(),
            "state_path": str(state_path.resolve()),
            "plan_sha256": pre["plan"]["plan_sha256"],
            "authorization": authorization_identity,
            "tool": pre["bindings"]["tool"],
            "scheduler": scheduler,
        }
        _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
        B.atomic_json(JOB_PATH, job, replace=False)
        state = initial_launch_state(
            pre_path,
            pre_sha256,
            pre,
            B.file_binding(JOB_PATH),
            authorization,
            scheduler,
        )
        B.atomic_json(state_path, state, replace=False)
        try:
            B._scheduler_call(pre, "Register", job)
            started = B._scheduler_call(pre, "Start", job)
        except (B.AuditError, OSError, subprocess.SubprocessError, KeyError, TypeError, ValueError) as exc:
            cleanup = _unregister_scheduler(pre, job)
            _persist_scheduler_cleanup(state_path, cleanup, launch_failure=True)
            raise AuthorizationError("persistent one-shot task registration/start failed and cleanup was attempted") from exc
        observed = B.load_json(state_path)
        return {
            "status": "LAUNCHED_PERSISTED_ONE_SHOT_TASK",
            "task_name": scheduler["task_name"],
            "scheduler_state": started.get("state"),
            "worker_pid": observed.get("worker_pid"),
            "state": str(state_path.resolve()),
            "job": str(JOB_PATH.resolve()),
        }


def _dev2_run_directories() -> set[Path]:
    root = B.DEV2_RUNS_ROOT.resolve()
    if not root.is_dir():
        raise InvalidEvidence("DEV2 runs root is missing")
    return {item.resolve() for item in root.iterdir() if item.is_dir()}


def _opaque_native_root(before: set[Path]) -> Path:
    after = _dev2_run_directories()
    created = sorted(after - before, key=lambda item: str(item).casefold())
    if len(created) != 1 or not re.fullmatch(
        r"[0-9]{8}T[0-9]{6}Z_[0-9a-f]{32}", created[0].name
    ):
        raise InvalidEvidence("controller did not create exactly one opaque DEV2 run root")
    return created[0]


def _seal_controller_attempt(
    output_root: Path,
    native_root: Path,
    attempt: dict[str, Any],
) -> None:
    native_result_path = native_root / "output" / "result.json"
    summary_path = B._find_dev2_summary(native_root.name)
    if not native_result_path.is_file() or not summary_path.is_file():
        raise InvalidEvidence("opaque controller artifact topology is incomplete")
    outcome_files = [
        path
        for path in B._outcome_artifact_paths(native_root)
        if path.name.casefold() != "summary.json"
    ]
    attempt["native_root"] = str(native_root)
    attempt["native_result"] = B.file_binding(native_result_path)
    attempt["summary"] = B.file_binding(summary_path)
    attempt["outcome_artifacts"] = [B.file_binding(path) for path in outcome_files]
    attempt["sealed_artifacts"] = sorted(
        B._opaque_artifacts(output_root) + B._opaque_artifacts(native_root),
        key=lambda item: str(item["path"]).casefold(),
    )
    attempt["runner_result"] = None
    attempt["controller_output_opened"] = False
    attempt["native_output_opened"] = False


def _worker_run(job_path: Path) -> int:
    """Execute once and seal bytes without opening controller/native outputs."""

    _block_terminal_operation("WORKER")
    state_path = STATE_PATH
    pre: Mapping[str, Any] | None = None
    job: Mapping[str, Any] | None = None
    exit_code = 2
    try:
        _assert_exact_control(job_path, JOB_PATH, "launch job")
        job_binding = B.file_binding(job_path)
        job = B.load_json(job_path)
        pre_path = Path(str(job["pre_receipt_path"])).resolve()
        pre_sha256 = str(job["pre_receipt_sha256"]).lower()
        pre = assert_pre_receipt(pre_path, pre_sha256)
        validate_current_research_data_gate(pre)
        _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
        authorization = validate_authorization(
            Path(str(job["authorization"]["binding"]["path"])),
            pre_sha256,
            pre=pre,
        )
        authorization_identity = {
            "binding": authorization["binding"],
            "payload_sha256": authorization["payload_sha256"],
        }
        if authorization_identity != job["authorization"]:
            raise AuthorizationError("worker authorization differs from launch job")
        state = B.load_json(state_path)
        if (
            state.get("artifact_type") != STATE_ARTIFACT_TYPE
            or state.get("analysis_id") != ANALYSIS_ID
            or state.get("status") != "PENDING"
            or state.get("job") != job_binding
            or state.get("attempt_claim") is not None
            or state.get("outcome_possible_since_utc") is not None
        ):
            raise AuthorizationError("worker state was not exactly armed once")
        now = B.utc_now()
        state["status"] = "RUNNING"
        state["worker_pid"] = os.getpid()
        state["started_utc"] = now
        state["updated_utc"] = now
        state["launches"].append(
            {
                "worker_pid": os.getpid(),
                "started_utc": now,
                "resume": False,
                "authorization": authorization_identity,
                "scheduler": job["scheduler"],
            }
        )
        B.atomic_json(state_path, state, replace=True)

        probe_execution = B._execute_machine_credential_preclaim_probe(pre)
        preclaim_probe = B.validate_machine_credential_preclaim_probe(
            probe_execution, pre, str(job["scheduler"]["principal_sid"])
        )
        state["preclaim_probe"] = preclaim_probe
        state["updated_utc"] = B.utc_now()
        B.atomic_json(state_path, state, replace=True)

        assert_pre_receipt(pre_path, pre_sha256)
        validate_current_research_data_gate(pre)
        if B.file_binding(job_path) != job_binding:
            raise InvalidEvidence("immutable launch job drift before native claim")
        bound_probe = B.validate_bound_machine_credential_preclaim_probe(
            preclaim_probe,
            pre,
            str(job["scheduler"]["principal_sid"]),
            require_fresh=True,
        )
        state["attempt_claim"] = B.claim_native_attempt(
            pre_path,
            pre_sha256,
            pre,
            state_path,
            authorization_identity,
            bound_probe,
        )
        state["updated_utc"] = B.utc_now()
        B.atomic_json(state_path, state, replace=True)

        if len(state["cells"]) != 1 or len(pre["plan"]["cells"]) != 1:
            raise InvalidEvidence("one-shot worker cell closure drift")
        state_cell = state["cells"][0]
        cell = pre["plan"]["cells"][0]
        command = runner_command(pre, cell)
        if (
            state_cell.get("status") != "PENDING"
            or state_cell.get("attempts") != []
            or state_cell.get("command_sha256") != B.canonical_sha256(command)
        ):
            raise InvalidEvidence("one-shot worker command/state drift")
        output_root = Path(str(cell["output_root"])).resolve()
        if output_root.exists() and any(output_root.iterdir()):
            raise InvalidEvidence("native cell output root is not empty")
        output_root.mkdir(parents=True, exist_ok=True)
        stdout_path = output_root / "controller.stdout.log"
        stderr_path = output_root / "controller.stderr.log"
        before = _dev2_run_directories()
        started_utc = B.utc_now()
        attempt: dict[str, Any] = {
            "started_utc": started_utc,
            "finished_utc": None,
            "command_sha256": B.canonical_sha256(command),
            "exit_code": None,
            "stdout": None,
            "stderr": None,
            "summary": None,
            "outcome_artifacts": [],
            "native_root": None,
            "native_result": None,
            "runner_result": None,
            "sealed_artifacts": [],
            "controller_output_opened": False,
            "native_output_opened": False,
        }
        state_cell["status"] = "RUNNING"
        state_cell["attempts"].append(attempt)
        state["active_cell"] = {
            "cell_id": state_cell["cell_id"],
            "started_utc": started_utc,
            "status": "OUTCOME_POSSIBLE_NO_RESUME",
        }
        state["outcome_possible_since_utc"] = started_utc
        state["updated_utc"] = started_utc
        B.atomic_json(state_path, state, replace=True)
        with stdout_path.open("wb") as stdout_handle, stderr_path.open("wb") as stderr_handle:
            completed = subprocess.run(
                command,
                cwd=str(REPO_ROOT),
                stdin=subprocess.DEVNULL,
                stdout=stdout_handle,
                stderr=stderr_handle,
                check=False,
                timeout=B.CELL_CONTROLLER_TIMEOUT_SECONDS,
            )
        attempt["finished_utc"] = B.utc_now()
        attempt["exit_code"] = int(completed.returncode)
        attempt["stdout"] = B.file_binding(stdout_path)
        attempt["stderr"] = B.file_binding(stderr_path)
        if completed.returncode != 0:
            attempt["sealed_artifacts"] = sorted(
                B._opaque_artifacts(output_root),
                key=lambda item: str(item["path"]).casefold(),
            )
            state_cell["status"] = "INVALID_TERMINAL_OUTPUT"
            state["status"] = "INVALID_TERMINAL"
            state["finished_utc"] = B.utc_now()
            state["active_cell"] = None
            state["worker_pid"] = None
            state["updated_utc"] = B.utc_now()
            B.atomic_json(state_path, state, replace=True)
            return 2
        native_root = _opaque_native_root(before)
        _seal_controller_attempt(output_root, native_root, attempt)
        state_cell["status"] = "COMPLETE"
        state["status"] = "COMPLETE"
        state["active_cell"] = None
        state["worker_pid"] = None
        state["finished_utc"] = B.utc_now()
        state["updated_utc"] = B.utc_now()
        B.atomic_json(state_path, state, replace=True)
        exit_code = 0
    except (
        B.AuditError,
        OSError,
        sqlite3.Error,
        subprocess.SubprocessError,
        KeyError,
        TypeError,
        ValueError,
    ):
        if state_path.is_file():
            state = B.load_json(state_path)
            if state.get("status") not in {"COMPLETE", "INVALID_TERMINAL"}:
                state["status"] = "INVALID_WORKER_INFRASTRUCTURE"
                state["worker_pid"] = None
                state["active_cell"] = None
                state["finished_utc"] = state.get("finished_utc") or B.utc_now()
                state["worker_error"] = {
                    "type": "OPAQUE_WORKER_INFRASTRUCTURE_FAILURE",
                    "controller_or_native_content_read": False,
                }
                state["updated_utc"] = B.utc_now()
                B.atomic_json(state_path, state, replace=True)
        exit_code = 2
    finally:
        if pre is not None and job is not None:
            cleanup = _unregister_scheduler(pre, job)
            _persist_scheduler_cleanup(state_path, cleanup, launch_failure=False)
            if cleanup.get("status") != "PASS":
                exit_code = 2
    return exit_code


def runner_command(pre: Mapping[str, Any], cell: Mapping[str, Any]) -> list[str]:
    if pre.get("execution_contract") != execution_contract():
        raise InvalidEvidence("runner requires exact NDX DEV2 prescreen contract")
    return _BASE_RUNNER_COMMAND(pre, cell)


def validate_trade_semantics(trades: Sequence[TradeRecord]) -> dict[str, Any]:
    per_day: dict[str, int] = defaultdict(int)
    for trade in trades:
        if not time(16, 30) <= trade.entry_time_broker.time() < time(19, 0):
            raise InvalidEvidence("entry outside [16:30,19:00) broker window")
        if trade.entry_time_broker.date() != trade.exit_time_broker.date():
            raise InvalidEvidence("position was not flat on its broker entry day")
        if trade.exit_time_broker.time() >= time(20, 5):
            raise InvalidEvidence("position was not flat before 20:05 broker time")
        if trade.exit_time_broker < trade.entry_time_broker:
            raise InvalidEvidence("negative holding time")
        day = trade.entry_time_broker.date().isoformat()
        per_day[day] += 1
    if any(count > 1 for count in per_day.values()):
        raise InvalidEvidence("more than one completed trade per broker day")
    return {
        "status": "PASS",
        "entries_inside_1630_1900_half_open": True,
        "flat_same_broker_day": True,
        "flat_before_2005_execution_grace": True,
        "maximum_one_trade_per_broker_day": True,
        "trading_days": len(per_day),
    }


def _axis_metrics(trades: Sequence[TradeRecord], field: str) -> dict[str, Any]:
    values = [Decimal(getattr(row, field)) for row in trades]
    gross_profit = sum((max(value, Decimal("0")) for value in values), Decimal("0"))
    gross_loss = sum((min(value, Decimal("0")) for value in values), Decimal("0"))
    net = sum(values, Decimal("0"))
    if gross_loss < 0:
        pf: str | None = B._decimal_text(gross_profit / -gross_loss)
        state = "FINITE"
    elif gross_profit > 0:
        pf = None
        state = "INFINITE_NO_LOSSES"
    else:
        pf = None
        state = "UNDEFINED"
    return {"trades": len(values), "net_usd": B._money_text(net), "profit_factor": pf, "profit_factor_state": state}


def _pf_at_least(metrics: Mapping[str, Any], floor: Decimal) -> bool:
    return metrics["profit_factor_state"] == "INFINITE_NO_LOSSES" or (
        metrics["profit_factor_state"] == "FINITE"
        and metrics["profit_factor"] is not None
        and Decimal(str(metrics["profit_factor"])) >= floor
    )


def evaluate_merit(cells: Mapping[str, Sequence[TradeRecord]]) -> dict[str, Any]:
    if set(cells) != {"PRESCREEN_2022H2"}:
        raise InvalidEvidence("prescreen merit cell closure drift")
    trades = list(cells["PRESCREEN_2022H2"])
    lifecycle = validate_trade_semantics(trades)
    native = _axis_metrics(trades, "native_net_usd")
    adjusted = _axis_metrics(trades, "adjusted_net_usd")
    gates = [
        B._gate("MIN_TRADES", len(trades) >= 5, len(trades), ">=5"),
        B._gate("NATIVE_PF", _pf_at_least(native, Decimal("1.20")), native["profit_factor"], ">=1.20"),
        B._gate("ADJUSTED_PF", _pf_at_least(adjusted, Decimal("1.20")), adjusted["profit_factor"], ">=1.20"),
        B._gate("ADJUSTED_NET", Decimal(adjusted["net_usd"]) > 0, adjusted["net_usd"], ">0"),
        B._gate("LIFECYCLE", lifecycle["status"] == "PASS", lifecycle, "all invariants PASS"),
    ]
    return {
        "contract": MERIT_GATES,
        "native": native,
        "cost_adjusted": adjusted,
        "lifecycle": lifecycle,
        "gates": gates,
        "status": "PASS" if all(row["status"] == "PASS" for row in gates) else "FAIL",
    }


def _probe_task_absence(task_name: str) -> dict[str, Any]:
    script = (
        "$ErrorActionPreference='Stop';"
        f"$n='{task_name}';"
        "$t=@(Get-ScheduledTask -TaskName $n -TaskPath '\\' -ErrorAction SilentlyContinue);"
        "[ordered]@{task_name=$n;count=$t.Count;states=@($t|ForEach-Object{$_.State.ToString()})}"
        "|ConvertTo-Json -Depth 3 -Compress"
    )
    completed = subprocess.run(
        [
            str(B.POWERSHELL_PATH),
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            script,
        ],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )
    if completed.returncode != 0:
        raise InvalidEvidence("scheduled-task absence probe failed closed")
    try:
        result = json.loads(completed.stdout.strip())
    except json.JSONDecodeError as exc:
        raise InvalidEvidence("scheduled-task absence probe returned invalid JSON") from exc
    expected = {"task_name": task_name, "count": 0, "states": []}
    if result != expected:
        raise InvalidEvidence("one-shot scheduled task still exists")
    return result


def _validate_complete_state(
    pre_path: Path,
    pre_sha256: str,
    state_path: Path,
    pre: Mapping[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    state = B.load_json(state_path)
    if (
        state.get("schema_version") != 1
        or state.get("launcher_revision") != 1320901
        or state.get("artifact_type") != STATE_ARTIFACT_TYPE
        or state.get("analysis_id") != ANALYSIS_ID
        or state.get("status") != "COMPLETE"
        or state.get("worker_pid") is not None
        or state.get("active_cell") is not None
        or state.get("pre_receipt_path") != str(pre_path.resolve())
        or state.get("pre_receipt_sha256") != pre_sha256.lower()
        or state.get("plan_sha256") != pre["plan"]["plan_sha256"]
    ):
        raise InvalidEvidence("QM13209 launch state is not exactly COMPLETE/PRE-bound")
    expected_fence = {
        "worker_opens_controller_stdout": False,
        "worker_opens_controller_stderr": False,
        "worker_opens_native_reports": False,
        "worker_parses_market_values": False,
        "worker_seals_paths_types_sizes_hashes_only": True,
        "post_is_first_controller_and_native_outcome_reader": True,
    }
    if state.get("outcome_fence") != expected_fence:
        raise InvalidEvidence("worker outcome fence drift")
    cleanup = state.get("scheduler_cleanup")
    if (
        not isinstance(cleanup, Mapping)
        or cleanup.get("status") != "PASS"
        or cleanup.get("operation") != "Unregister"
        or cleanup.get("state") != "Absent"
        or cleanup.get("cleanup") not in {"UNREGISTERED", "ALREADY_ABSENT"}
    ):
        raise InvalidEvidence("scheduler cleanup is not a bound PASS")
    job_binding = state.get("job")
    if not isinstance(job_binding, Mapping):
        raise InvalidEvidence("launch job binding missing")
    B.assert_binding(job_binding, "QM13209 launch job")
    if Path(str(job_binding.get("path", ""))).resolve() != JOB_PATH.resolve():
        raise InvalidEvidence("launch job path drift")
    job = B.load_json(JOB_PATH)
    _validate_launch_job(job, pre, pre_path, pre_sha256, state_path)
    if state.get("scheduler") != job.get("scheduler"):
        raise InvalidEvidence("launch scheduler drift")
    _probe_task_absence(str(job["scheduler"]["task_name"]))
    authorization = validate_authorization(
        Path(str(job["authorization"]["binding"]["path"])),
        pre_sha256,
        pre=pre,
        require_current=False,
    )
    authorization_identity = {
        "binding": authorization["binding"],
        "payload_sha256": authorization["payload_sha256"],
    }
    if authorization_identity != job["authorization"] or state.get("authorization") != authorization_identity:
        raise InvalidEvidence("launch authorization lifecycle drift")
    preclaim_probe = state.get("preclaim_probe")
    if not isinstance(preclaim_probe, Mapping):
        raise InvalidEvidence("same-worker preclaim proof missing")
    B.validate_bound_machine_credential_preclaim_probe(
        preclaim_probe,
        pre,
        str(job["scheduler"]["principal_sid"]),
        require_fresh=False,
    )
    attempt_claim = state.get("attempt_claim")
    if not isinstance(attempt_claim, Mapping):
        raise InvalidEvidence("one-shot native claim missing")
    B.validate_native_attempt_claim(
        attempt_claim,
        pre_path,
        pre_sha256,
        pre,
        state_path,
        authorization_identity,
        preclaim_probe,
    )
    launches = state.get("launches")
    if (
        not isinstance(launches, list)
        or len(launches) != 1
        or not isinstance(launches[0], Mapping)
        or launches[0].get("resume") is not False
        or launches[0].get("authorization") != authorization_identity
        or launches[0].get("scheduler") != job["scheduler"]
    ):
        raise InvalidEvidence("one-shot launch audit chain drift")
    cells = state.get("cells")
    if not isinstance(cells, list) or len(cells) != 1 or not isinstance(cells[0], Mapping):
        raise InvalidEvidence("one-shot state cell closure drift")
    state_cell = cells[0]
    cell = pre["plan"]["cells"][0]
    attempts = state_cell.get("attempts")
    if (
        state_cell.get("cell_id") != cell["cell_id"]
        or state_cell.get("status") != "COMPLETE"
        or state_cell.get("command_sha256") != B.canonical_sha256(runner_command(pre, cell))
        or not isinstance(attempts, list)
        or len(attempts) != 1
        or not isinstance(attempts[0], Mapping)
    ):
        raise InvalidEvidence("COMPLETE cell/command closure drift")
    attempt = attempts[0]
    if (
        attempt.get("exit_code") != 0
        or attempt.get("runner_result") is not None
        or attempt.get("controller_output_opened") is not False
        or attempt.get("native_output_opened") is not False
        or not isinstance(attempt.get("stdout"), Mapping)
        or not isinstance(attempt.get("stderr"), Mapping)
        or not isinstance(attempt.get("native_result"), Mapping)
        or not isinstance(attempt.get("summary"), Mapping)
        or not isinstance(attempt.get("outcome_artifacts"), list)
        or not isinstance(attempt.get("sealed_artifacts"), list)
    ):
        raise InvalidEvidence("opaque worker attempt closure drift")
    for role in ("stdout", "stderr", "native_result", "summary"):
        B.assert_binding(attempt[role], f"opaque worker {role}")
    for index, binding in enumerate(attempt["outcome_artifacts"]):
        B.assert_binding(binding, f"opaque outcome[{index}]")
    return state, job, dict(state_cell)


def postflight(pre_path: Path, pre_sha256: str, state_path: Path) -> dict[str, Any]:
    _block_terminal_operation("POST")
    _assert_exact_control(pre_path, PRE_RECEIPT_PATH, "PRE receipt")
    _assert_exact_control(state_path, STATE_PATH, "launch state")
    pre = assert_pre_receipt(pre_path, pre_sha256)
    state_binding = B.file_binding(state_path)
    state, _job, state_cell = _validate_complete_state(
        pre_path, pre_sha256, state_path, pre
    )

    # This is intentionally the first controller-output read in the lifecycle.
    attempt = state_cell["attempts"][0]
    stdout_path = Path(str(attempt["stdout"]["path"])).resolve()
    controller_result = B._parse_dev2_controller_json(
        stdout_path.read_text(encoding="utf-8-sig", errors="replace")
    )
    B.validate_dev2_controller_result(controller_result, pre)
    hydrated_cell = copy.deepcopy(state_cell)
    hydrated_cell["attempts"][0]["runner_result"] = controller_result
    core = B._load_report_core(pre)
    cell_receipt, trades = B._audit_cell(
        pre,
        pre["plan"]["cells"][0],
        hydrated_cell,
        core,
    )
    merit = evaluate_merit({"PRESCREEN_2022H2": trades})
    B.assert_binding(state_binding, "stable COMPLETE opaque launch state")
    return {
        "schema_version": 1,
        "artifact_type": POST_ARTIFACT_TYPE,
        "analysis_id": ANALYSIS_ID,
        "created_utc": B.utc_now(),
        "status": merit["status"],
        "integrity_status": "PASS",
        "pre_receipt": B.file_binding(pre_path, pre_sha256),
        "launch_state": state_binding,
        "scheduler_cleanup": state["scheduler_cleanup"],
        "authorized_symbol": RESEARCH_SYMBOL,
        "accepted_duplicate_run_count": cell_receipt["accepted_duplicate_runs"],
        "infrastructure_warmup_count": cell_receipt["infrastructure_warmup_count"],
        "attempted_native_start_count": cell_receipt["attempted_runs"],
        "maximum_authorized_native_starts": 4,
        "cells": [cell_receipt],
        "merit": merit,
        "decision": (
            "ADVANCE_FAMILY_TO_FULL_VALIDATION"
            if merit["status"] == "PASS"
            else "STOP_FAMILY_ON_PRESCREEN_MERIT"
        ),
    }


def invalid_receipt(phase: str, exc: Exception) -> dict[str, Any]:
    return {
        "schema_version": 1,
        "artifact_type": f"QM5_13209_NDX_PRESCREEN_{phase}_INVALID",
        "analysis_id": ANALYSIS_ID,
        "created_utc": B.utc_now(),
        "status": "INVALID",
        "error_type": type(exc).__name__,
        "error": (
            "opaque native/controller failure; inspect only after an authorized POST"
            if phase == "WORKER"
            else str(exc)
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    pre = sub.add_parser("pre")
    pre.add_argument("--symbol", required=True)
    pre.add_argument("--data-receipt", type=Path, required=True)
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
    assignments = {
        "TOOL_PATH": TOOL_PATH, "EA_ROOT": EA_ROOT, "REPO_ROOT": REPO_ROOT,
        "EA_ID": EA_ID, "EA_LABEL": EA_LABEL, "EXPERT_NAME": EXPERT_NAME,
        "EXPERT_PATH": EXPERT_PATH, "ANALYSIS_ID": ANALYSIS_ID,
        "SCHEMA_VERSION": 1, "MERIT_CONTRACT_VERSION": MERIT_GATES["version"],
        "CARD_PATH": CARD_PATH, "SPEC_PATH": SPEC_PATH, "MQ5_PATH": MQ5_PATH,
        "EX5_PATH": EX5_PATH, "ALLOWED_RUN_ROOT": RUN_ROOT,
        "NATIVE_ATTEMPT_CLAIM_PATH": CLAIM_PATH, "NATIVE_LAUNCH_LOCK_PATH": LOCK_PATH,
        "CURRENT_CLAIM_SEQUENCE": 1, "RESERVED_COUNTED_ALTERNATE_ATTEMPT_NUMBER": 1,
        "PRIOR_CLAIM_SEQUENCES": 0, "MAXIMUM_COUNTED_ALTERNATE_ATTEMPTS": 1,
        "PRIOR_COUNTED_ALTERNATE_ATTEMPTS": 0,
        "ALTERNATE_ATTEMPT_COUNTING_BOUNDARY": "EXACT_DEV2_METATESTER_PROCESS_STARTED",
        "AUTHORIZATION_SCOPE": AUTHORIZATION_SCOPE, "TIMEFRAME": TIMEFRAME,
        "DUPLICATES": DUPLICATES, "MAX_POSTFLIGHT_INFRA_WARMUPS_PER_CELL": 2,
        "MAX_ATTEMPTS_PER_CELL": 4, "INITIAL_BALANCE": INITIAL_BALANCE,
        "WINDOWS": WINDOWS, "MERIT_GATES": MERIT_GATES, "RESEARCH_SYMBOL": RESEARCH_SYMBOL,
        "SCHEDULED_TASK_PREFIX": SCHEDULED_TASK_PREFIX, "LAUNCHER_REVISION": 1320901,
        "SCHEDULED_TASK_HELPER_PATH": SCHEDULED_TASK_HELPER_PATH,
        "REQUIRED_BINDING_ROLES": frozenset(_expected_binding_paths(RESEARCH_SYMBOL)),
    }
    for name, value in assignments.items():
        setattr(B, name, value)
    B._assert_run_root = _assert_run_root
    B.enforce_symbol_policy = enforce_symbol_policy
    B._expected_binding_paths = _expected_binding_paths
    B._binding_map = _binding_map
    B._validate_set_contract = _validate_set_contract
    B.execution_contract = execution_contract
    B.build_plan = build_plan
    B.preflight = preflight
    B.assert_pre_receipt = assert_pre_receipt
    B.validate_current_research_data_gate = validate_current_research_data_gate
    B.validate_authorization = validate_authorization
    B._native_attempt_claim_basis = _native_attempt_claim_basis
    B._validate_launch_job = _validate_launch_job
    B.initial_launch_state = initial_launch_state
    B.launch_detached = launch_detached
    B._worker_run = _worker_run
    B.runner_command = runner_command
    B.validate_trade_semantics = validate_trade_semantics
    B.evaluate_merit = evaluate_merit
    B.postflight = postflight
    B.invalid_receipt = invalid_receipt
    B.build_parser = build_parser


_configure_private_profile()


def main(argv: Sequence[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    args = build_parser().parse_args(arguments)
    try:
        if args.command == "status":
            _assert_exact_control(args.state, STATE_PATH, "launch state")
            state = B.load_json(args.state)
            if (
                state.get("artifact_type") != STATE_ARTIFACT_TYPE
                or state.get("analysis_id") != ANALYSIS_ID
            ):
                raise InvalidEvidence("QM13209 launch state identity drift")
            print(json.dumps({
                "status": state.get("status"),
                "worker_pid": state.get("worker_pid"),
                "cells": [
                    {"cell_id": row.get("cell_id"), "status": row.get("status")}
                    for row in state.get("cells", []) if isinstance(row, Mapping)
                ],
            }, indent=2, sort_keys=True))
            return 0
        if args.command == "_run-plan":
            _assert_exact_control(args.job, JOB_PATH, "launch job")
            return _worker_run(args.job)
        if args.command == "pre":
            _assert_exact_control(args.receipt, PRE_RECEIPT_PATH, "PRE receipt")
            payload = preflight(args.symbol, args.data_receipt, args.build_receipt, args.run_root)
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {"status": "PASS", "receipt": str(args.receipt.resolve()), "sha256": digest}
            code = 0
        elif args.command == "launch":
            output = launch_detached(args.pre_receipt, args.pre_sha256, args.authorization, args.state, resume=False)
            code = 0
        else:
            _assert_exact_control(args.receipt, POST_RECEIPT_PATH, "POST receipt")
            payload = postflight(args.pre_receipt, args.pre_sha256, args.state)
            digest = B.atomic_json(args.receipt, payload, replace=False)
            output = {"status": payload["status"], "receipt": str(args.receipt.resolve()), "sha256": digest, "decision": payload["decision"]}
            code = 0 if payload["status"] == "PASS" else 1
        print(json.dumps(output, indent=2, sort_keys=True))
        return code
    except (B.AuditError, OSError, sqlite3.Error, subprocess.SubprocessError, ValueError, KeyError, TypeError) as exc:
        print(json.dumps(invalid_receipt(args.command.upper(), exc), indent=2, sort_keys=True), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
